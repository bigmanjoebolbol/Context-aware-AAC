import 'package:flutter/material.dart';
import '../models/conversation_entry.dart';
import '../models/phrase_entry.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/rule_engine.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../services/llm_fallback_service.dart';
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
  // Deploy aac_backend/ (see its README) and put its URL + your chosen
  // APP_SHARED_SECRET here. Never embed a raw Gemini API key in the client.
  final LlmFallbackService _llm = LlmFallbackService(
    backendEndpoint: 'https://canopy-vision-alive.ngrok-free.dev/suggest',
    sharedSecret: null, // set to match APP_SHARED_SECRET on the backend
  );

  final TextEditingController _inputController = TextEditingController();

  String _heardText = '';
  List<Suggestion> _suggestions = [];
  QuestionType? _lastType;
  PhraseEntry? _matchedPhrase;
  bool _loadingLlm = false;
  bool _listening = false;

  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.storage.getProfile()!;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _process(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _heardText = text;
      _suggestions = [];
      _matchedPhrase = null;
      _loadingLlm = false;
    });

    final phrasebook = widget.storage.getPhrasebook();
    final result = _ruleEngine.process(
      text: text,
      profile: _profile,
      phrasebook: phrasebook,
    );

    if (result.handled) {
      setState(() {
        _suggestions = result.suggestions;
        _lastType = result.type;
        if (result.type == QuestionType.knownPhrase) {
          _matchedPhrase = phrasebook.firstWhere(
            (e) => e.variants.any((v) => text.toLowerCase().contains(v.toLowerCase())),
            orElse: () => phrasebook.first,
          );
        }
      });

      if (_profile.autoReplyEnabled && _suggestions.isNotEmpty) {
        await _choose(_suggestions.first, auto: true);
      }
      return;
    }

    // Fast path couldn't handle it - fall back to the LLM.
    setState(() {
      _lastType = QuestionType.openEnded;
      _loadingLlm = true;
    });

    final history = widget.storage.recentHistory(limit: 5);
    final llmReplies = await _llm.getSuggestions(
      otherPersonText: text,
      profile: _profile,
      history: history,
    );

    setState(() {
      _loadingLlm = false;
      _suggestions = llmReplies
          .map((r) => Suggestion(text: r, source: SuggestionSource.llm))
          .toList();
    });

    if (_profile.autoReplyEnabled && _suggestions.isNotEmpty) {
      await _choose(_suggestions.first, auto: true);
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
    } else if (suggestion.source == SuggestionSource.llm) {
      // Learn from repeated open-ended questions too: naive key from the
      // first 3 words, so if this phrasing recurs it graduates into the
      // fast path over time instead of hitting the LLM every time.
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

    if (!auto) {
      setState(() {
        _heardText = '';
        _suggestions = [];
        _matchedPhrase = null;
      });
      _inputController.clear();
    }
  }

  Future<void> _writeOwnMessage() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write your own reply'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Say it'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _choose(Suggestion(text: result.trim(), source: SuggestionSource.custom));
    }
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _stt.stopListening();
      setState(() => _listening = false);
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
    setState(() => _listening = true);
    await _stt.startListening(
      localeId: _profile.languagePreference == 'english' ? 'en-US' : 'ar-EG',
      onResult: (text, isFinal) {
        setState(() => _inputController.text = text);
        if (isFinal) {
          setState(() => _listening = false);
          _process(text);
        }
      },
      onError: (err) {
        setState(() => _listening = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hi, ${_profile.name}'),
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_profile.autoReplyEnabled) _AutoReplyBanner(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'What did the other person say?',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: _process,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                    onPressed: _toggleListening,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_lastType != null) _QuestionTypeBadge(type: _lastType!),
              const SizedBox(height: 12),
              if (_loadingLlm) const LinearProgressIndicator(),
              Expanded(
                child: ListView(
                  children: [
                    ..._suggestions.map(
                      (s) => Card(
                        child: ListTile(
                          title: Text(s.text, style: const TextStyle(fontSize: 18)),
                          subtitle: Text(_sourceLabel(s.source)),
                          onTap: () => _choose(s),
                        ),
                      ),
                    ),
                    Card(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('None, write my own message'),
                        onTap: _writeOwnMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sourceLabel(SuggestionSource source) {
    switch (source) {
      case SuggestionSource.phrasebook:
        return 'From your usual replies';
      case SuggestionSource.eitherOr:
        return 'Detected choice';
      case SuggestionSource.yesNo:
        return 'Yes/No';
      case SuggestionSource.userPreferenceFill:
        return 'Based on your preference';
      case SuggestionSource.llm:
        return 'AI suggestion';
      case SuggestionSource.custom:
        return 'Your own message';
    }
  }
}

class _QuestionTypeBadge extends StatelessWidget {
  final QuestionType type;
  const _QuestionTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      QuestionType.eitherOr => 'Either/or question',
      QuestionType.yesNo => 'Yes/No question',
      QuestionType.knownPhrase => 'Recognized question',
      QuestionType.openEnded => 'Open-ended (using AI)',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(label: Text(label)),
    );
  }
}

class _AutoReplyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.orange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Auto-reply is ON: the app will respond for you automatically. Turn this off in Settings if you want to choose replies yourself.',
            ),
          ),
        ],
      ),
    );
  }
}
