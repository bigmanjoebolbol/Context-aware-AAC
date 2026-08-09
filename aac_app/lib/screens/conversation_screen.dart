import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation_entry.dart';
import '../models/conversation_session.dart';
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
import '../services/local_ai_manager.dart';
import '../services/on_device_llm_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_screen.dart';

class ConversationScreen extends StatefulWidget {
  final StorageService storage;
  final ConversationSession? session;
  const ConversationScreen({super.key, required this.storage, this.session});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final RuleEngine _ruleEngine = RuleEngine();
  final TtsService _tts = TtsService();
  final SttService _stt = SttService();
  final LocationService _location = LocationService();
  late LlmFallbackService _llm;
  final OnDeviceLlmService _onDeviceLlm = OnDeviceLlmService();

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
  Timer? _replyDebounce;
  bool _suppressInputListener = false; // prevents double-process when STT writes to _inputController
  String _lastProcessedText = ''; // guard against processing the same text twice

  // Map suggestion text → reply key (for phrasebook replies)
  final Map<String, String> _replyKeyMap = {};

  // Autocomplete suggestions for custom reply field
  List<String> _autocompleteSuggestions = [];

  List<ConversationEntry> _history = [];
  final ScrollController _scrollController = ScrollController();

  void _loadHistory() {
    if (!mounted) return;
    setState(() {
      _history = widget.storage
          .recentHistory(limit: 50, sessionId: widget.session?.id)
          .toList()
          .reversed
          .toList();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _editEntry(ConversationEntry entry, bool isOtherPerson) async {
    final controller = TextEditingController(text: isOtherPerson ? entry.otherPersonText : (entry.chosenReply ?? ''));
    final newText = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Save')),
        ],
      )
    );
    if (newText != null && newText.trim().isNotEmpty) {
      if (isOtherPerson) {
        entry.otherPersonText = newText.trim();
        await entry.save();
        if (entry == _history.last && (entry.chosenReply == null || entry.chosenReply!.isEmpty)) {
          _process(entry.otherPersonText);
        }
      } else {
        entry.chosenReply = newText.trim();
        await entry.save();
      }
      _loadHistory();
    }
  }

  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.getProfile()!;
    _llm = LlmFallbackService();
    _inputController.addListener(_onInputChanged);
    _replyController.addListener(_onReplyChanged);
    _initLocation();
    // Load persisted history immediately so the chat is visible on open
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _initLocation() async {
    if (_profile.shareLocationWithAi) {
      final name = await _location.getLocationName();
      if (mounted) setState(() => _currentLocation = name);
    }
  }

  void _onInputChanged() {
    if (_suppressInputListener) return; // STT is writing — skip to avoid double-process
    _inputDebounce?.cancel();
    _inputDebounce = Timer(const Duration(milliseconds: 150), () {
      _process(_inputController.text, isRealTime: true);
    });
  }

  void _onReplyChanged() {
    _replyDebounce?.cancel();
    _replyDebounce = Timer(const Duration(milliseconds: 150), () {
      final partial = _replyController.text.trim();
      if (partial.isEmpty) {
        setState(() => _autocompleteSuggestions = []);
        return;
      }
      final suggestions = widget.storage.autocompleteSuggestions(partial, limit: 3);
      setState(() => _autocompleteSuggestions = suggestions);
    });
  }

  @override
  void dispose() {
    _manuallyStopped = true;
    _stt.stopListening();
    _inputController.removeListener(_onInputChanged);
    _replyController.removeListener(_onReplyChanged);
    _inputController.dispose();
    _replyController.dispose();
    _debounceTimer?.cancel();
    _inputDebounce?.cancel();
    _replyDebounce?.cancel();
    _soundLevelNotifier.dispose();
    super.dispose();
  }

  Future<void> _process(String text, {bool isRealTime = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      if (!isRealTime) {
        setState(() => _heardText = '');
      }
      return;
    }

    _debounceTimer?.cancel();

    if (trimmed != _heardText) {
      setState(() {
        _suggestions = [];
        _modelName = null;
        _replyKeyMap.clear();
      });
    }

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
        // Build reply key map from embedded replyKey on each suggestion.
        // This is reliable because the rule engine now stores the stable key.
        if (_matchedPhrase != null) {
          _replyKeyMap.clear();
          for (final s in result.suggestions) {
            if (s.replyKey != null) {
              _replyKeyMap[s.text] = s.replyKey!;
            }
          }
        }
      });

      if (!isRealTime && _profile.autoReplyEnabled && _suggestions.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await _choose(_suggestions.first, auto: true);
        return;
      }

      if (!isRealTime) {
        _fetchLlmSuggestions(trimmed);
      } else {
        _debounceTimer = Timer(const Duration(milliseconds: 800), () {
          _fetchLlmSuggestions(trimmed);
        });
      }
      return;
    }

    setState(() {
      _heardText = text;
      _lastType = QuestionType.openEnded;
      _matchedPhrase = null;
      _replyKeyMap.clear();
    });

    if (isRealTime) {
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
      final history = widget.storage.recentHistory(
        limit: 10,
        sessionId: widget.session?.id,
      );
      
      SuggestResult llmResult;
      
      if (_profile.aiMode == 'local_on_device') {
        final manager = LocalAiManager();
        final isDownloaded = await manager.isModelDownloaded();
        if (isDownloaded) {
          final modelPath = await manager.getModelPath();
          await _onDeviceLlm.initialize(modelPath);
          llmResult = await _onDeviceLlm.suggestReplies(
            otherPersonText: text,
            profile: _profile,
            history: history,
            otherPersonName: widget.session?.displayName,
            sessionNotes: widget.session?.notes,
          );
        } else {
          llmResult = await _llm.getSuggestions(
            otherPersonText: text,
            profile: _profile,
            history: history,
            currentContact: _activeContact,
            locationContext: _currentLocation,
            otherPersonName: widget.session?.displayName,
            sessionNotes: widget.session?.notes,
          );
        }
      } else {
        llmResult = await _llm.getSuggestions(
          otherPersonText: text,
          profile: _profile,
          history: history,
          currentContact: _activeContact,
          locationContext: _currentLocation,
          otherPersonName: widget.session?.displayName,
          sessionNotes: widget.session?.notes,
        );
      }

      if (!mounted) return;

      if (llmResult.error != null && llmResult.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI Error: ${llmResult.error}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      setState(() {
        _modelName = llmResult.model;
        final existing = _suggestions.map((s) => s.text.toLowerCase()).toSet();
        final newSuggestions = llmResult.suggestions
            .where((r) => !existing.contains(r.toLowerCase()))
            .map((r) => Suggestion(text: r, source: SuggestionSource.llm))
            .toList();
        _suggestions = [..._suggestions, ...newSuggestions];
      });

      if (_profile.autoReplyEnabled && _suggestions.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 1000));
        await _choose(_suggestions.first, auto: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Local AI Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLlm = false);
    }
  }

  // ----------------------------------------------------------------------
  // _choose: now uses translation lookup when a PhraseEntry is available.
  // ----------------------------------------------------------------------
  Future<void> _choose(Suggestion suggestion, {bool auto = false, String? heardTextOverride}) async {
    final heardText = heardTextOverride ?? _heardText;

    // If we have a matched phrase and this suggestion is from phrasebook, use translations.
    if (_matchedPhrase != null && suggestion.source == SuggestionSource.phrasebook) {
      // Prefer the replyKey embedded on the suggestion by the rule engine;
      // fall back to the text-based map for legacy/custom entries.
      String? replyKey = suggestion.replyKey ?? _replyKeyMap[suggestion.text];
      // Last resort: scan all translations for any matching value.
      if (replyKey == null) {
        for (final entry in _matchedPhrase!.replyTranslations.entries) {
          if (entry.value.values.contains(suggestion.text)) {
            replyKey = entry.key;
            break;
          }
        }
      }
      if (replyKey != null) {
        await _tts.speakTranslated(
          _matchedPhrase!,
          replyKey,
          languagePreference: _profile.languagePreference,
          ttsGender: _profile.preferences['tts_gender'] ?? 'female',
        );
        // Log with the language-appropriate translation text.
        final displayText = _getDisplayText(_matchedPhrase!, replyKey, _heardText);
        await widget.storage.logEntry(ConversationEntry(
          otherPersonText: heardText,
          chosenReply: displayText,
          questionType: (_lastType ?? QuestionType.openEnded).name,
          wasAutoReplied: auto,
          sessionId: widget.session?.id,
        ));
        // Reinforce the choice.
        await widget.storage.reinforcePhraseChoice(_matchedPhrase!, replyKey);
        // Clear and return.
        setState(() {
          _heardText = '';
          _suggestions = [];
          _modelName = null;
          _replyKeyMap.clear();
        });
        _lastProcessedText = '';
        _loadHistory();
        _inputController.clear();
        _replyController.clear();
        if (!auto) await Future.delayed(const Duration(milliseconds: 1000));
        return;
      }
    }

    // Fallback: use the old plain‑text speak method (for LLM/custom replies).
    await _tts.speak(
      suggestion.text,
      languagePreference: _profile.languagePreference,
      ttsGender: _profile.preferences['tts_gender'] ?? 'female',
    );

    await widget.storage.logEntry(ConversationEntry(
      otherPersonText: heardText,
      chosenReply: suggestion.text,
      questionType: (_lastType ?? QuestionType.openEnded).name,
      wasAutoReplied: auto,
      sessionId: widget.session?.id,
    ));

    if (_matchedPhrase != null) {
      // This shouldn't happen if we handled above, but keep for safety.
      await widget.storage.reinforcePhraseChoice(_matchedPhrase!, suggestion.text);
    } else if (suggestion.source == SuggestionSource.llm && _modelName != 'Offline Fallback') {
      final key = heardText
          .toLowerCase()
          .split(' ')
          .take(3)
          .join('_')
          .replaceAll(RegExp(r'[^\w_]'), '');
      if (key.isNotEmpty) {
        await widget.storage.learnNewPhrase(
          triggerKey: key,
          variants: [heardText],
          chosenReply: suggestion.text,
        );
      }
    } else if (suggestion.source == SuggestionSource.custom && heardText.isNotEmpty) {
      final currentFacts = _profile.preferences['learned_facts'] ?? '';
      final newFact = "When asked '$heardText', user replied: '${suggestion.text}'";
      final factsList = currentFacts.isNotEmpty ? currentFacts.split('\n') : <String>[];
      factsList.add('- $newFact');
      if (factsList.length > 15) {
        factsList.removeRange(0, factsList.length - 15);
      }
      _profile.preferences['learned_facts'] = factsList.join('\n');
      await widget.storage.saveProfile(_profile);
    }

    setState(() {
      _heardText = '';
      _suggestions = [];
      _modelName = null;
      _replyKeyMap.clear();
    });
    _lastProcessedText = '';
    _loadHistory();
    _inputController.clear();
    _replyController.clear();

    if (!auto) {
      await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  // ----------------------------------------------------------------------
  // Pinned replies – also use translation lookup.
  // ----------------------------------------------------------------------
  String _getTopReplyKey(PhraseEntry entry) {
    if (entry.replyScores.isEmpty) return '';
    return entry.replyScores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  String _getDisplayText(PhraseEntry entry, String replyKey, String incomingText) {
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(incomingText);
    final langKey = hasArabic ? 'egyptian' : 'english';
    return entry.replyTranslations[replyKey]?[langKey] ??
        entry.replyTranslations[replyKey]?['egyptian'] ??
        entry.replyTranslations[replyKey]?['english'] ??
        entry.replyTranslations[replyKey]?['msa'] ??
        replyKey;
  }

  Future<void> _sendPinnedReply(PhraseEntry entry) async {
    final topKey = _getTopReplyKey(entry);
    if (topKey.isEmpty) return;

    // Speak using translation.
    await _tts.speakTranslated(
      entry,
      topKey,
      languagePreference: _profile.languagePreference,
      ttsGender: _profile.preferences['tts_gender'] ?? 'female',
    );

    final displayText = _getDisplayText(entry, topKey, _heardText);

    await widget.storage.logEntry(ConversationEntry(
      otherPersonText: '',
      chosenReply: displayText,
      questionType: 'pinned',
      wasAutoReplied: false,
      sessionId: widget.session?.id,
    ));

    await widget.storage.reinforcePhraseChoice(entry, topKey);

    _loadHistory();
    setState(() {
      _heardText = '';
      _suggestions = [];
      _modelName = null;
      _replyKeyMap.clear();
    });
    _inputController.clear();
    _replyController.clear();
  }

  // ----------------------------------------------------------------------
  // (Rest of the file unchanged – build, helpers, etc.)
  // ----------------------------------------------------------------------

  Widget _buildChatBubble(String text, {required bool isOtherPerson, void Function()? onEdit}) {
    final theme = Theme.of(context);
    return Align(
      alignment: isOtherPerson ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onLongPress: onEdit,
        onDoubleTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isOtherPerson
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primary,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isOtherPerson ? const Radius.circular(4) : const Radius.circular(20),
              bottomRight: !isOtherPerson ? const Radius.circular(4) : const Radius.circular(20),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: isOtherPerson
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
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
          // Suppress _onInputChanged so we don't double-call _process.
          _suppressInputListener = true;
          setState(() => _inputController.text = trimmed);
          _suppressInputListener = false;
        }

        // Process only if we have new text that wasn't already processed.
        if (trimmed.isNotEmpty && trimmed != _lastProcessedText && mounted) {
          _lastProcessedText = trimmed;
          _process(trimmed, isRealTime: !isFinal);
        }

        if (isFinal) {
          if (mounted) {
            setState(() => _listening = false);
            _soundLevelNotifier.value = -2.0;
          }
          if (!_manuallyStopped) {
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
    final pinnedEntries = widget.storage.pinnedPhrases();

    return Scaffold(
      appBar: AppBar(
        title: widget.session != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.session!.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${AppStrings.get('hi', lang)}, ${_profile.name}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                ],
              )
            : Text('${AppStrings.get('hi', lang)}, ${_profile.name}'),
        actions: [
          DropdownButton<String>(
            value: _profile.tonePreference,
            icon: const Padding(
              padding: EdgeInsets.only(left: 4.0),
              child: Icon(Icons.mood, size: 20),
            ),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'casual', child: Text('Casual')),
              DropdownMenuItem(value: 'formal', child: Text('Formal')),
              DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
            ],
            onChanged: (v) async {
              if (v != null) {
                setState(() => _profile.tonePreference = v);
                await widget.storage.saveProfile(_profile);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(storage: widget.storage),
                ),
              );
              setState(() {
                _profile = widget.storage.getProfile()!;
                _llm = LlmFallbackService();
              });
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
              child: Column(
                children: [
                  if (_profile.autoReplyEnabled) _AutoReplyBanner(uiLanguage: lang),
                  // Chat History
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _history.length + (_heardText.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < _history.length) {
                          final entry = _history[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (entry.otherPersonText.isNotEmpty)
                                _buildChatBubble(entry.otherPersonText, isOtherPerson: true, onEdit: () => _editEntry(entry, true)),
                              if (entry.chosenReply != null && entry.chosenReply!.isNotEmpty)
                                _buildChatBubble(entry.chosenReply!, isOtherPerson: false, onEdit: () => _editEntry(entry, false)),
                            ],
                          );
                        } else {
                          return _buildChatBubble(_heardText, isOtherPerson: true, onEdit: null);
                        }
                      },
                    ),
                  ),
                  
                  // Waveform and Status
                  if (_listening || _loadingLlm || _lastType != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          if (_listening) ...([
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _inputController.text.isNotEmpty
                                  ? Container(
                                      key: const ValueKey('stt_preview'),
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                            .withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.hearing,
                                              size: 16,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _inputController.text,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontStyle: FontStyle.italic,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('stt_empty')),
                            ),
                            SizedBox(
                              height: 60,
                              child: Center(
                                child: RepaintBoundary(
                                  child: ValueListenableBuilder<double>(
                                    valueListenable: _soundLevelNotifier,
                                    builder: (context, level, _) =>
                                        _WaveformIndicator(
                                            listening: _listening, level: level),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                          if (_lastType != null || _modelName != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_lastType != null) Flexible(child: _QuestionTypeBadge(type: _lastType!, uiLanguage: lang)),
                                if (_modelName != null) Flexible(child: _AiStatusBadge(modelName: _modelName!, uiLanguage: lang)),
                              ],
                            ),
                          if (_loadingLlm) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
                        ],
                      ),
                    ),

                  // PINNED QUICK PHRASES BAR
                  if (pinnedEntries.isNotEmpty)
                    Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pinnedEntries.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final entry = pinnedEntries[index];
                          final topKey = _getTopReplyKey(entry);
                          if (topKey.isEmpty) return const SizedBox.shrink();
                          final display = _getDisplayText(entry, topKey, _heardText);
                          return ActionChip(
                            label: Text(display, style: const TextStyle(fontSize: 14)),
                            onPressed: () => _sendPinnedReply(entry),
                            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                            side: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1),
                            avatar: const Icon(Icons.push_pin, size: 16),
                          );
                        },
                      ),
                    ),

                  // Suggestions
                  if (_suggestions.isNotEmpty)
                    Container(
                      height: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _suggestions.map((s) {
                          final isPinned = _matchedPhrase?.pinned == true && s.source == SuggestionSource.phrasebook;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8, bottom: 8),
                            child: GestureDetector(
                              onTap: () => _choose(s),
                              onLongPress: () async {
                                if (_matchedPhrase != null && s.source == SuggestionSource.phrasebook) {
                                  await widget.storage.togglePinned(_matchedPhrase!);
                                  setState(() {});
                                }
                              },
                              child: Stack(
                                children: [
                                  Container(
                                    width: 220,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: Text(s.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                                        Text(_sourceLabel(s.source, lang), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary)),
                                      ],
                                    ),
                                  ),
                                  if (isPinned)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Icon(Icons.push_pin, size: 16, color: Theme.of(context).colorScheme.primary),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // Input row with autocomplete chips below
                  Column(
                    children: [
                      // Autocomplete chips (if any)
                      if (_autocompleteSuggestions.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _autocompleteSuggestions.map((text) {
                              return ActionChip(
                                label: Text(text, style: const TextStyle(fontSize: 13)),
                                onPressed: () {
                                  setState(() {
                                    _replyController.text = text;
                                    _replyController.selection = TextSelection.fromPosition(
                                      TextPosition(offset: text.length),
                                    );
                                    _autocompleteSuggestions.clear();
                                  });
                                },
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                              );
                            }).toList(),
                          ),
                        ),
                      // Main input row
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            IconButton.filled(
                              icon: Icon(_listening ? Icons.stop : Icons.mic),
                              onPressed: _toggleListening,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _replyController,
                                decoration: InputDecoration(
                                  hintText: AppStrings.get('my_reply_hint', lang),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onSubmitted: (v) {
                                  if (v.trim().isNotEmpty) {
                                    _choose(Suggestion(text: v.trim(), source: SuggestionSource.custom));
                                    setState(() => _autocompleteSuggestions = []);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              icon: const Icon(Icons.send),
                              onPressed: () {
                                if (_replyController.text.trim().isNotEmpty) {
                                  _choose(Suggestion(text: _replyController.text.trim(), source: SuggestionSource.custom));
                                  setState(() => _autocompleteSuggestions = []);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOffline ? Icons.cloud_off : Icons.auto_awesome, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              isOffline ? 'Offline Mode' : '${AppStrings.get('ai_active', uiLanguage)}: $modelName',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
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
          level: listening ? level : -2.0,
          color: listening 
              ? Theme.of(context).colorScheme.primary 
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
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

    final normalized = SttService.normalizeLevel(level);

    for (int i = 0; i < barCount; i++) {
      final x = i * spacing + (spacing / 2);
      final distFromCenter = (i - (barCount / 2)).abs() / (barCount / 2);
      final scale = 1.0 - distFromCenter;
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