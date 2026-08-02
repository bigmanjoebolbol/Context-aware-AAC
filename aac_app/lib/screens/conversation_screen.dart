import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation_entry.dart';
import '../models/phrase_entry.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/rule_engine.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/llm_fallback_service.dart';
import '../services/app_strings.dart';
import '../services/location_service.dart';
import '../models/contact_entry.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_screen.dart';

class ConversationScreen extends StatefulWidget {
  final StorageService storage;
  const ConversationScreen({super.key, required this.storage});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final RuleEngine _ruleEngine = RuleEngine();
  final TtsService _tts = TtsService();
  final SttService _stt = SttService();
  final LocationService _location = LocationService();
  final LlmFallbackService _llm = LlmFallbackService(
    backendEndpoint: LlmFallbackService.defaultBackendUrl,
    sharedSecret: null, // set to match APP_SHARED_SECRET on the backend
  );

  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();

  String _heardText = '';
  List<Suggestion> _suggestions = [];
  QuestionType? _lastType;
  PhraseEntry? _matchedPhrase;
  String? _modelName;
  ContactEntry? _activeContact;
  String? _currentLocation;
  bool _loadingLlm = false;
  bool _listening = false;
  bool _manuallyStopped = false;
  final ValueNotifier<double> _soundLevelNotifier = ValueNotifier(-2.0);
  Timer? _debounceTimer;
  Timer? _inputDebounce;

  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.getProfile()!;
    _inputController.addListener(_onInputChanged);
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (_profile.shareLocationWithAi) {
      final name = await _location.getLocationName();
      if (mounted) setState(() => _currentLocation = name);
    }
  }

  void _onInputChanged() {
    _inputDebounce?.cancel();
    _inputDebounce = Timer(const Duration(milliseconds: 150), () {
      _process(_inputController.text, isRealTime: true);
    });
  }

  @override
  void dispose() {
    _manuallyStopped = true;
    _stt.stopListening();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _replyController.dispose();
    _debounceTimer?.cancel();
    _inputDebounce?.cancel();
    _soundLevelNotifier.dispose();
    super.dispose();
  }

  Future<void> _process(String text, {bool isRealTime = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      // Don't clear suggestions immediately on empty text,
      // just clear the "Other person said" display if not real-time.
      if (!isRealTime) {
        setState(() => _heardText = '');
      }
      return;
    }

    // Always clear the debounce timer when new text arrives
    _debounceTimer?.cancel();

    final phrasebook = widget.storage.getPhrasebook();
    final result = _ruleEngine.process(
      text: trimmed,
      profile: _profile,
      phrasebook: phrasebook,
    );

    if (result.handled) {
      setState(() {
        _heardText = trimmed;
        _suggestions = result.suggestions;
        _lastType = result.type;
        _matchedPhrase = result.matchedPhrase;
        _modelName = null;
        _loadingLlm = false;
      });

      if (!isRealTime && _profile.autoReplyEnabled && _suggestions.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await _choose(_suggestions.first, auto: true);
      }
      return;
    }

    // Fast path couldn't handle it - plan to fall back to the LLM.
    setState(() {
      _heardText = text;
      _lastType = QuestionType.openEnded;
      _matchedPhrase = null;
    });

    if (isRealTime) {
      // Debounce LLM calls to avoid flickering and excessive API usage
      _debounceTimer = Timer(const Duration(milliseconds: 800), () {
        _fetchLlmSuggestions(text);
      });
    } else {
      await _fetchLlmSuggestions(text);
    }
  }

  Future<void> _fetchLlmSuggestions(String text) async {
    setState(() => _loadingLlm = true);

    try {
      final history = widget.storage.recentHistory(limit: 5);
      final llmResult = await _llm.getSuggestions(
        otherPersonText: text,
        profile: _profile,
        history: history,
        currentContact: _activeContact,
        locationContext: _currentLocation,
      );

      if (!mounted) return;

      setState(() {
        _modelName = llmResult.model;
        _suggestions = llmResult.suggestions
            .map((r) => Suggestion(text: r, source: SuggestionSource.llm))
            .toList();
      });

      if (_profile.autoReplyEnabled && _suggestions.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await _choose(_suggestions.first, auto: true);
      }
    } catch (_) {
      // getSuggestions handles its own errors
    } finally {
      if (mounted) setState(() => _loadingLlm = false);
    }
  }

  Future<void> _choose(Suggestion suggestion, {bool auto = false}) async {
    await _tts.speak(suggestion.text, languagePreference: _profile.languagePreference);

    await widget.storage.logEntry(ConversationEntry(
      otherPersonText: _heardText,
      chosenReply: suggestion.text,
      questionType: (_lastType ?? QuestionType.openEnded).name,
      wasAutoReplied: auto,
    ));

    if (_matchedPhrase != null) {
      await widget.storage.reinforcePhraseChoice(_matchedPhrase!, suggestion.text);
    } else if (suggestion.source == SuggestionSource.llm && _modelName != 'Offline Fallback') {
      final key = _heardText
          .toLowerCase()
          .split(' ')
          .take(3)
          .join('_')
          .replaceAll(RegExp(r'[^\w_]'), '');
      if (key.isNotEmpty) {
        await widget.storage.learnNewPhrase(
          triggerKey: key,
          variants: [_heardText],
          chosenReply: suggestion.text,
        );
      }
    }

    // After choosing, we clear the INPUT but keep the HEARD TEXT and SUGGESTIONS
    // so the user can still see them if needed. They will be replaced on next input.
    _inputController.clear();
    _replyController.clear();

    if (!auto) {
      // Small pause to allow TTS to start without mic picking up self-voice
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      _manuallyStopped = true;
      await _stt.stopListening();
      _soundLevelNotifier.value = -2.0;
      setState(() {
        _listening = false;
      });
      return;
    }

    _manuallyStopped = false;

    // Check permissions explicitly
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (!mounted) return;
      final lang = _profile.uiLanguage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('mic_permission_denied', lang)),
          action: SnackBarAction(
            label: AppStrings.get('open_settings', lang),
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    final ok = await _stt.init();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone/speech recognition unavailable.')),
      );
      return;
    }
    
    _startListeningLoop();
  }

  Future<void> _startListeningLoop() async {
    if (_manuallyStopped) return;
    
    if (mounted) setState(() => _listening = true);
    
    await _stt.startListening(
      localeId: _profile.languagePreference == 'english' ? 'en-US' : 'ar-EG',
      onSoundLevelChange: (level) {
        _soundLevelNotifier.value = level;
      },
      onResult: (text, isFinal) {
        final trimmed = text.trim();
        if (trimmed.isNotEmpty && mounted && _inputController.text != trimmed) {
           setState(() => _inputController.text = trimmed);
        }
        
        if (isFinal) {
          if (mounted) {
            setState(() => _listening = false);
            _soundLevelNotifier.value = -2.0;
          }
          if (!_manuallyStopped) {
            // Delay restart slightly for stability
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!_manuallyStopped && mounted) _startListeningLoop();
            });
          }
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _listening = false;
          });
          _soundLevelNotifier.value = -2.0;
        }
        if (!_manuallyStopped) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (!_manuallyStopped && mounted) _startListeningLoop();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = _profile.uiLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text('${AppStrings.get('hi', lang)}, ${_profile.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(storage: widget.storage),
                ),
              );
              setState(() => _profile = widget.storage.getProfile()!);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_profile.contacts.isNotEmpty)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    const SizedBox(width: 16),
                    ChoiceChip(
                      label: const Text('Everyone'),
                      selected: _activeContact == null,
                      onSelected: (s) => setState(() => _activeContact = null),
                    ),
                    ..._profile.contacts.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(c.name),
                        selected: _activeContact?.id == c.id,
                        onSelected: (s) => setState(() => _activeContact = s ? c : null),
                      ),
                    )),
                  ],
                ),
              ),
            if (_currentLocation != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _currentLocation!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_profile.autoReplyEnabled) _AutoReplyBanner(uiLanguage: lang),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            decoration: InputDecoration(
                              hintText: AppStrings.get('mic_hint', lang),
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            IconButton.filled(
                              icon: Icon(_listening ? Icons.stop : Icons.mic),
                              onPressed: _toggleListening,
                            ),
                            Text(
                              _profile.languagePreference == 'english' ? 'EN' : 'AR',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _soundLevelNotifier,
                          builder: (context, level, _) {
                            return _WaveformIndicator(listening: _listening, level: level);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_lastType != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _QuestionTypeBadge(type: _lastType!, uiLanguage: lang),
                          if (_modelName != null) _AiStatusBadge(modelName: _modelName!, uiLanguage: lang),
                        ],
                      ),
                    const SizedBox(height: 12),
                    if (_loadingLlm) const LinearProgressIndicator(),
                    Expanded(
                      child: ListView(
                        children: [
                          ..._suggestions.map(
                            (s) => Card(
                              child: ListTile(
                                title: Text(s.text, style: const TextStyle(fontSize: 18)),
                                subtitle: Text(_sourceLabel(s.source, lang)),
                                onTap: () => _choose(s),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            decoration: InputDecoration(
                              hintText: AppStrings.get('my_reply_hint', lang),
                              border: const OutlineInputBorder(),
                            ),
                            onSubmitted: (v) => _choose(Suggestion(text: v, source: SuggestionSource.custom)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            if (_replyController.text.trim().isNotEmpty) {
                              _choose(Suggestion(
                                text: _replyController.text.trim(),
                                source: SuggestionSource.custom,
                              ));
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(SuggestionSource source, String lang) {
    switch (source) {
      case SuggestionSource.phrasebook:
        return AppStrings.get('source_phrasebook', lang);
      case SuggestionSource.eitherOr:
        return AppStrings.get('source_either_or', lang);
      case SuggestionSource.yesNo:
        return AppStrings.get('source_yes_no', lang);
      case SuggestionSource.userPreferenceFill:
        return AppStrings.get('source_pref', lang);
      case SuggestionSource.llm:
        return AppStrings.get('source_llm', lang);
      case SuggestionSource.custom:
        return AppStrings.get('source_custom', lang);
    }
  }
}

class _QuestionTypeBadge extends StatelessWidget {
  final QuestionType type;
  final String uiLanguage;
  const _QuestionTypeBadge({required this.type, required this.uiLanguage});

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      QuestionType.eitherOr => AppStrings.get('type_either_or', uiLanguage),
      QuestionType.yesNo => AppStrings.get('type_yes_no', uiLanguage),
      QuestionType.knownPhrase => AppStrings.get('type_known', uiLanguage),
      QuestionType.openEnded => AppStrings.get('type_open', uiLanguage),
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(label: Text(label)),
    );
  }
}

class _AutoReplyBanner extends StatelessWidget {
  final String uiLanguage;
  const _AutoReplyBanner({required this.uiLanguage});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppStrings.get('auto_reply_on', uiLanguage)}: ${AppStrings.get('auto_reply_warning', uiLanguage)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _AiStatusBadge extends StatelessWidget {
  final String modelName;
  final String uiLanguage;
  const _AiStatusBadge({required this.modelName, required this.uiLanguage});

  @override
  Widget build(BuildContext context) {
    final isOffline = modelName == 'Offline Fallback';
    final color = isOffline ? Colors.orange : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOffline ? Icons.cloud_off : Icons.auto_awesome, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            isOffline ? 'Offline Mode' : '${AppStrings.get('ai_active', uiLanguage)}: $modelName',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _WaveformIndicator extends StatelessWidget {
  final bool listening;
  final double level;
  const _WaveformIndicator({required this.listening, required this.level});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          level: listening ? level : -2.0, // Show a flat line when not listening
          color: listening 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double level;
  final Color color;
  _WaveformPainter({required this.level, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const barCount = 40;
    final spacing = size.width / barCount;
    final centerY = size.height / 2;

    // Use standardized normalization
    final normalized = SttService.normalizeLevel(level);

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + (spacing / 2);
      
      // Fixed pattern for symmetry
      final distFromCenter = (i - (barCount / 2)).abs() / (barCount / 2);
      final scale = 1.0 - distFromCenter;
      
      // Jitter based on index to look "live"
      final wave = 0.4 + (0.6 * (0.5 + 0.5 * (i % 5 == 0 ? 1 : (i % 3 == 0 ? 0.7 : 0.5))));
      
      final height = size.height * normalized * scale * wave;
      
      canvas.drawLine(
        Offset(x, centerY - height / 2),
        Offset(x, centerY + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) => 
      oldDelegate.level != level || oldDelegate.color != color;
}
