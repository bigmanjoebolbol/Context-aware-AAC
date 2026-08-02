import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/app_strings.dart';
import '../services/llm_fallback_service.dart';
import 'conversation_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final StorageService storage;
  const OnboardingScreen({super.key, required this.storage});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _step = 0;

  String _name = '';
  String _language = 'mixed';
  String _tone = 'mixed';
  String _uiLanguage = 'en';
  String _selectedAiProvider = 'default';
  final Map<String, String> _preferences = {};

  List<_OnboardingQuestion> get _questions => [
        _OnboardingQuestion(
          id: 'ui_language',
          title: AppStrings.get('ui_lang', _uiLanguage),
          type: _QuestionType.selection,
          options: {
            'en': 'English',
            'ar': 'العربية',
          },
        ),
        _OnboardingQuestion(
          id: 'name',
          title: AppStrings.get('onboarding_name', _uiLanguage),
          hint: 'Your name',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'fast_path',
          title: AppStrings.get('fast_path_title', _uiLanguage),
          type: _QuestionType.info,
          hint: AppStrings.get('fast_path_desc', _uiLanguage),
        ),
        _OnboardingQuestion(
          id: 'offline_info',
          title: AppStrings.get('offline_title', _uiLanguage),
          type: _QuestionType.info,
          hint: AppStrings.get('offline_desc', _uiLanguage),
        ),
        _OnboardingQuestion(
          id: 'ai_info',
          title: AppStrings.get('ai_fallback_title', _uiLanguage),
          type: _QuestionType.info,
          hint: AppStrings.get('ai_fallback_desc', _uiLanguage),
        ),
        _OnboardingQuestion(
          id: 'privacy_info',
          title: AppStrings.get('privacy_title', _uiLanguage),
          type: _QuestionType.info,
          hint: AppStrings.get('privacy_desc', _uiLanguage),
        ),
        _OnboardingQuestion(
          id: 'ai_provider',
          title: AppStrings.get('select_ai', _uiLanguage),
          type: _QuestionType.aiPicker,
          hint: AppStrings.get('select_ai_desc', _uiLanguage),
        ),
        _OnboardingQuestion(
          id: 'language',
          title: 'Which language do you want replies in?',
          type: _QuestionType.selection,
          options: {
            'english': 'English only',
            'arabicMSA': 'Arabic (Modern Standard)',
            'egyptianArabic': 'Egyptian Arabic',
            'mixed': 'Mix of Arabic and English',
          },
        ),
        _OnboardingQuestion(
          id: 'tone',
          title: 'How do you usually like to talk?',
          type: _QuestionType.selection,
          options: {
            'casual': 'Casual / relaxed',
            'formal': 'Formal / polite',
            'mixed': 'Depends on who I\'m talking to',
          },
        ),
        _OnboardingQuestion(
          id: 'protein',
          title: AppStrings.get('pref_protein', _uiLanguage),
          hint: 'e.g. chicken',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'drink',
          title: AppStrings.get('pref_drink', _uiLanguage),
          hint: 'e.g. tea, water',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'coffee_pref',
          title: 'How do you take your coffee or tea?',
          hint: 'e.g. two sugars, black',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'breakfast',
          title: 'What is your typical breakfast?',
          hint: 'e.g. eggs, ful, toast',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'hobbies',
          title: 'What do you enjoy doing in your free time?',
          hint: 'e.g. reading, walking, gaming',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'music',
          title: 'What kind of music do you like?',
          hint: 'e.g. pop, classical, umm kulthum',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'movies',
          title: 'Do you have a favorite movie genre?',
          hint: 'e.g. action, drama, comedy',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'sleep',
          title: 'Are you a morning person or a night owl?',
          type: _QuestionType.selection,
          options: {
            'morning': 'Morning person',
            'night': 'Night owl',
            'neither': 'Somewhere in between',
          },
        ),
        _OnboardingQuestion(
          id: 'social',
          title: 'Do you prefer small groups or large parties?',
          type: _QuestionType.selection,
          options: {
            'small': 'Small groups',
            'large': 'Large parties',
            'both': 'I enjoy both',
          },
        ),
        _OnboardingQuestion(
          id: 'sport',
          title: 'Do you follow any sports?',
          hint: 'e.g. football, tennis, none',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'team',
          title: 'Which team do you support?',
          hint: 'e.g. Al Ahly, Zamalek, Liverpool',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'transport',
          title: 'How do you usually get around?',
          hint: 'e.g. car, bus, walking',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'weather',
          title: 'What is your favorite type of weather?',
          hint: 'e.g. sunny, rainy, cold',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'season',
          title: 'Which season do you like most?',
          type: _QuestionType.selection,
          options: {
            'summer': 'Summer',
            'winter': 'Winter',
            'spring': 'Spring',
            'autumn': 'Autumn',
          },
        ),
        _OnboardingQuestion(
          id: 'tech',
          title: 'Do you consider yourself tech-savvy?',
          type: _QuestionType.selection,
          options: {
            'yes': 'Yes, very',
            'some': 'A little bit',
            'no': 'Not really',
          },
        ),
        _OnboardingQuestion(
          id: 'news',
          title: 'Where do you get your news?',
          hint: 'e.g. TV, social media, apps',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'family',
          title: 'Tell us a bit about your family context.',
          hint: 'e.g. live with parents, married, kids',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'work_status',
          title: 'What is your current work or study status?',
          hint: 'e.g. student, retired, working',
          type: _QuestionType.text,
        ),
        _OnboardingQuestion(
          id: 'emergency_contact',
          title: 'Who is your main contact for daily help?',
          hint: 'e.g. my daughter, my wife, my nurse',
          type: _QuestionType.text,
        ),
      ];

  int get _totalSteps => _questions.length;

  void _next({String? value}) {
    final currentQ = _questions[_step];
    if (value != null && value.isNotEmpty) {
      if (currentQ.id == 'name') {
        _name = value;
      } else if (currentQ.id == 'language') {
        _language = value;
      } else if (currentQ.id == 'tone') {
        _tone = value;
      } else if (currentQ.id == 'ui_language') {
        _uiLanguage = value;
      } else if (currentQ.id == 'ai_provider') {
        _selectedAiProvider = value;
      } else {
        _preferences[currentQ.id] = value;
      }
    }

    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _skipCurrent() {
    _next();
  }

  void _skipAll() {
    _finish();
  }

  Future<void> _finish() async {
    final profile = UserProfile(
      name: _name.isEmpty ? 'Friend' : _name,
      languagePreference: _language,
      tonePreference: _tone,
      preferences: _preferences,
      uiLanguage: _uiLanguage,
      selectedAiProvider: _selectedAiProvider,
      onboardingComplete: true,
    );
    await widget.storage.saveProfile(profile);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(storage: widget.storage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('onboarding_title', _uiLanguage)),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              )
            : null,
        actions: [
          TextButton(
            onPressed: _skipCurrent,
            child: Text(AppStrings.get('skip', _uiLanguage)),
          ),
          TextButton(
            onPressed: _skipAll,
            child: Text(
              AppStrings.get('skip_all', _uiLanguage),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / _totalSteps),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '${AppStrings.get('step', _uiLanguage)} ${_step + 1} ${AppStrings.get('of', _uiLanguage)} $_totalSteps',
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _totalSteps,
                itemBuilder: (context, index) {
                  final q = _questions[index];
                  String? initialValue;
                  if (q.id == 'name') {
                    initialValue = _name;
                  } else if (q.id == 'language') {
                    initialValue = _language;
                  } else if (q.id == 'tone') {
                    initialValue = _tone;
                  } else if (q.id == 'ui_language') {
                    initialValue = _uiLanguage;
                  } else if (q.id == 'ai_provider') {
                    initialValue = _selectedAiProvider;
                  } else {
                    initialValue = _preferences[q.id];
                  }

                  if (q.type == _QuestionType.text) {
                    return _PreferenceStep(
                      title: q.title,
                      hint: q.hint ?? '',
                      initialValue: initialValue ?? '',
                      onSubmitted: (v) => _next(value: v),
                      isLastStep: index == _totalSteps - 1,
                      uiLanguage: _uiLanguage,
                    );
                  } else if (q.type == _QuestionType.info) {
                    return _InfoStep(
                      title: q.title,
                      description: q.hint ?? '',
                      onNext: () => _next(),
                      uiLanguage: _uiLanguage,
                    );
                  } else if (q.type == _QuestionType.aiPicker) {
                    return _AiPickerStep(
                      storage: widget.storage,
                      title: q.title,
                      description: q.hint ?? '',
                      initialValue: initialValue,
                      onSelected: (v) => _next(value: v),
                      uiLanguage: _uiLanguage,
                    );
                  } else {
                    return _SelectionStep(
                      title: q.title,
                      options: q.options ?? {},
                      initialValue: initialValue,
                      onSelected: (v) => _next(value: v),
                      uiLanguage: _uiLanguage,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _QuestionType { text, selection, info, aiPicker }

class _OnboardingQuestion {
  final String id;
  final String title;
  final String? hint;
  final _QuestionType type;
  final Map<String, String>? options;

  _OnboardingQuestion({
    required this.id,
    required this.title,
    this.hint,
    required this.type,
    this.options,
  });
}

class _AiPickerStep extends StatefulWidget {
  final StorageService storage;
  final String title;
  final String description;
  final String? initialValue;
  final void Function(String) onSelected;
  final String uiLanguage;

  const _AiPickerStep({
    required this.storage,
    required this.title,
    required this.description,
    this.initialValue,
    required this.onSelected,
    required this.uiLanguage,
  });

  @override
  State<_AiPickerStep> createState() => _AiPickerStepState();
}

class _AiPickerStepState extends State<_AiPickerStep> {
  String? _selected;
  List<AiProvider> _providers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final service = LlmFallbackService(
        backendEndpoint: LlmFallbackService.defaultBackendUrl,
      );
      final result = await service.getProviders();
      if (mounted) {
        setState(() {
          _providers = result?.providers ?? [];
          if (_selected == null && result != null) {
            _selected = result.defaultId;
          }
        });
      }
    } catch (_) {
      // Fail silently, list stays empty
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(widget.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_providers.isEmpty)
             const Center(child: Text('No providers found. Using system default.'))
          else
            Expanded(
              child: ListView(
                children: _providers.map((p) {
                  return RadioListTile<String>(
                    title: Text(p.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    subtitle: Text(p.model),
                    value: p.id,
                    groupValue: _selected,
                    onChanged: (v) => setState(() => _selected = v),
                  );
                }).toList(),
              ),
            ),
          const Spacer(),
          ElevatedButton(
            onPressed: _loading ? null : () => widget.onSelected(_selected ?? 'default'),
            child: Text(AppStrings.get('next', widget.uiLanguage)),
          ),
        ],
      ),
    );
  }
}

class _InfoStep extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onNext;
  final String uiLanguage;

  const _InfoStep({
    required this.title,
    required this.description,
    required this.onNext,
    required this.uiLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.info_outline, size: 80, color: Colors.blue),
          const SizedBox(height: 24),
          Text(title, style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Text(description, style: Theme.of(context).textTheme.bodyLarge, textAlign: TextAlign.center),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            child: Text(AppStrings.get('next', uiLanguage)),
          ),
        ],
      ),
    );
  }
}
class _SelectionStep extends StatefulWidget {
  final String title;
  final Map<String, String> options;
  final String? initialValue;
  final void Function(String) onSelected;
  final String uiLanguage;

  const _SelectionStep({
    required this.title,
    required this.options,
    this.initialValue,
    required this.onSelected,
    required this.uiLanguage,
  });

  @override
  State<_SelectionStep> createState() => _SelectionStepState();
}

class _SelectionStepState extends State<_SelectionStep> {
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _SelectionStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _selected = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: widget.options.entries.map((e) {
                return RadioListTile<String>(
                  title: Text(e.value, style: const TextStyle(fontSize: 18)),
                  value: e.key,
                  groupValue: _selected,
                  onChanged: (v) => setState(() => _selected = v),
                );
              }).toList(),
            ),
          ),
          ElevatedButton(
            onPressed: _selected == null ? null : () => widget.onSelected(_selected!),
            child: Text(AppStrings.get('next', widget.uiLanguage)),
          ),
        ],
      ),
    );
  }
}

class _PreferenceStep extends StatefulWidget {
  final String title;
  final String hint;
  final String initialValue;
  final void Function(String) onSubmitted;
  final bool isLastStep;
  final String uiLanguage;

  const _PreferenceStep({
    required this.title,
    required this.hint,
    required this.initialValue,
    required this.onSubmitted,
    this.isLastStep = false,
    required this.uiLanguage,
  });

  @override
  State<_PreferenceStep> createState() => _PreferenceStepState();
}

class _PreferenceStepState extends State<_PreferenceStep> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue;
  }

  @override
  void didUpdateWidget(covariant _PreferenceStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 20),
              decoration: InputDecoration(
                hintText: widget.hint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: widget.onSubmitted,
            ),
          ),
          ElevatedButton(
            onPressed: () => widget.onSubmitted(_controller.text),
            child: Text(AppStrings.get(
              widget.isLastStep ? 'finish' : 'next',
              widget.uiLanguage,
            )),
          ),
        ],
      ),
    );
  }
}
