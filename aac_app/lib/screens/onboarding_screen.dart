import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/app_strings.dart';
import '../services/local_ai_manager.dart';
import 'sessions_screen.dart';

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
  String _aiMode = 'gemini';   // 'gemini' or 'ollama'
  final Map<String, String> _preferences = {};

  // Questions are rebuilt when _uiLanguage changes (via setState).
  List<_OnboardingQuestion> get _questions => [
        // ── 1. UI Language ────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'ui_language',
          title: AppStrings.get('ui_lang', _uiLanguage),
          type: _QuestionType.selection,
          options: {'en': 'English', 'ar': 'العربية'},
        ),
        // ── 2. Name ───────────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'name',
          title: AppStrings.get('onboarding_name', _uiLanguage),
          hint: 'Your name',
          type: _QuestionType.text,
        ),
        // ── 3–6. Info screens ─────────────────────────────────────────
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
        // ── 7. AI mode choice ─────────────────────────────────────────
        _OnboardingQuestion(
          id: 'ai_mode',
          title: 'How do you want the AI to work?',
          type: _QuestionType.aiMode,
        ),
        // ── 8. Reply language ─────────────────────────────────────────
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
        // ── 8. Tone ───────────────────────────────────────────────────
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
        // ── 9. Favorite protein ───────────────────────────────────────
        _OnboardingQuestion(
          id: 'protein',
          title: AppStrings.get('pref_protein', _uiLanguage),
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. chicken',
          choices: ['Chicken', 'Beef', 'Fish', 'Lamb', 'Vegetarian'],
        ),
        // ── 10. Allergens (multi-select) ──────────────────────────────
        _OnboardingQuestion(
          id: 'allergens',
          title: 'Do you have any food allergens?',
          type: _QuestionType.multiSelect,
          choices: ['Nuts', 'Gluten', 'Dairy', 'Shellfish', 'Eggs', 'None'],
        ),
        // ── 11. Dislikes (multi-select) ───────────────────────────────
        _OnboardingQuestion(
          id: 'dislikes',
          title: 'Are there foods you dislike?',
          type: _QuestionType.multiSelect,
          choices: ['Spicy food', 'Fish', 'Vegetables', 'Liver', 'Onions', 'None'],
        ),
        // ── 12. Drink ─────────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'drink',
          title: AppStrings.get('pref_drink', _uiLanguage),
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. tea',
          choices: ['Tea', 'Coffee', 'Water', 'Juice', 'Soft drink'],
        ),
        // ── 13. Hot drink preference ──────────────────────────────────
        _OnboardingQuestion(
          id: 'coffee_pref',
          title: 'How do you take your coffee or tea?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. two sugars, black',
          choices: ['Black', 'With milk', 'One sugar', 'Two sugars', 'Very sweet'],
        ),
        // ── 14. Breakfast ─────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'breakfast',
          title: 'What is your typical breakfast?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. eggs, ful, toast',
          choices: ['Eggs', 'Ful (fava beans)', 'Toast', 'Foul medames', 'I skip breakfast'],
        ),
        // ── 15. Hobbies ───────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'hobbies',
          title: 'What do you enjoy doing in your free time?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. reading, gaming',
          choices: ['Reading', 'Gaming', 'Walking', 'Cooking', 'Watching TV'],
        ),
        // ── 16. Music ─────────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'music',
          title: 'What kind of music do you like?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. pop, classical, umm kulthum',
          choices: ['Arabic pop', 'Classical', 'Western pop', 'Jazz', 'None'],
        ),
        // ── 17. Movie genre ───────────────────────────────────────────
        _OnboardingQuestion(
          id: 'movies',
          title: 'Do you have a favorite movie genre?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. action, comedy',
          choices: ['Action', 'Drama', 'Comedy', 'Horror', 'Documentaries'],
        ),
        // ── 18. Sleep ─────────────────────────────────────────────────
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
        // ── 19. Social ────────────────────────────────────────────────
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
        // ── 20. Sport ─────────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'sport',
          title: 'Do you follow any sports?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. football, tennis',
          choices: ['Football', 'Tennis', 'Basketball', 'Swimming', 'None'],
        ),
        // ── 21. Team ──────────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'team',
          title: 'Which team do you support?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. Al Ahly, Liverpool',
          choices: ['Al Ahly', 'Zamalek', 'Liverpool', 'Barcelona', 'None'],
        ),
        // ── 22. Transport ─────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'transport',
          title: 'How do you usually get around?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. car, metro',
          choices: ['Car', 'Bus', 'Walk', 'Metro', 'Taxi / Uber'],
        ),
        // ── 23. Weather ───────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'weather',
          title: 'What is your favorite type of weather?',
          type: _QuestionType.selection,
          options: {
            'sunny': '☀️ Sunny',
            'cloudy': '⛅ Cloudy',
            'rainy': '🌧️ Rainy',
            'cold': '❄️ Cold',
          },
        ),
        // ── 24. Season ────────────────────────────────────────────────
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
        // ── 25. Tech ──────────────────────────────────────────────────
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
        // ── 26. News ──────────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'news',
          title: 'Where do you get your news?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. TV, apps',
          choices: ['TV', 'Social media', 'News apps', 'Newspaper', 'I don\'t follow news'],
        ),
        // ── 27. Family ────────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'family',
          title: 'Tell us a bit about your family context.',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. live alone, married',
          choices: ['Live alone', 'With parents', 'Married', 'Have kids', 'Live with siblings'],
        ),
        // ── 28. Work/study ────────────────────────────────────────────
        _OnboardingQuestion(
          id: 'work_status',
          title: 'What is your current work or study status?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. student, retired',
          choices: ['Student', 'Working', 'Retired', 'Stay at home', 'Looking for work'],
        ),
        // ── 29. Main helper ───────────────────────────────────────────
        _OnboardingQuestion(
          id: 'emergency_contact',
          title: 'Who is your main contact for daily help?',
          type: _QuestionType.choiceWithCustom,
          hint: 'e.g. my daughter, my nurse',
          choices: ['My daughter', 'My son', 'My wife', 'My husband', 'My nurse / caregiver'],
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
        setState(() => _uiLanguage = value);
      } else if (currentQ.id == 'ai_mode') {
        setState(() => _aiMode = value);
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

  void _skipCurrent() => _next();
  void _skipAll() => _finish();

  Future<void> _finish() async {
    if (_aiMode == 'local_on_device') {
      final manager = LocalAiManager();
      final hasSpecs = await manager.checkHardwareSpecs();
      if (!hasSpecs) {
        // Fallback to cloud
        _aiMode = 'gemini';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Device does not meet hardware requirements for local AI. Falling back to Cloud.')),
          );
        }
      } else {
        final isDownloaded = await manager.isModelDownloaded();
        if (!isDownloaded) {
          if (mounted) {
            final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Downloading Local AI'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: progressNotifier,
                      builder: (context, progress, child) {
                        return Column(
                          children: [
                            LinearProgressIndicator(value: progress > 0 ? progress : null),
                            const SizedBox(height: 16),
                            Text(progress > 0 
                              ? 'Downloading... ${(progress * 100).toStringAsFixed(1)}%'
                              : 'Starting download (~400MB)...'),
                          ],
                        );
                      }
                    ),
                  ],
                ),
              ),
            );
            try {
              await manager.downloadModel(onProgress: (p) {
                progressNotifier.value = p;
              });
            } catch (e) {
              // Error downloading
              _aiMode = 'gemini';
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to download local model. Falling back to Cloud.')),
                );
              }
            }
            if (mounted) {
              Navigator.of(context).pop(); // dismiss dialog
            }
          }
        }
      }
    }

    final profile = UserProfile(
      name: _name.isEmpty ? 'Friend' : _name,
      languagePreference: _language,
      tonePreference: _tone,
      preferences: _preferences,
      uiLanguage: _uiLanguage,
      aiMode: _aiMode,
      onboardingComplete: true,
    );
    await widget.storage.saveProfile(profile);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionsScreen(storage: widget.storage),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get('onboarding_title', _uiLanguage)),
        leading: _step > 0
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back)
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
                '${AppStrings.get('step', _uiLanguage)} ${_step + 1} '
                '${AppStrings.get('of', _uiLanguage)} $_totalSteps',
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
                  } else {
                    initialValue = _preferences[q.id];
                  }

                  switch (q.type) {
                    case _QuestionType.text:
                      return _PreferenceStep(
                        key: ValueKey(q.id),
                        title: q.title,
                        hint: q.hint ?? '',
                        initialValue: initialValue ?? '',
                        onSubmitted: (v) => _next(value: v),
                        isLastStep: index == _totalSteps - 1,
                        uiLanguage: _uiLanguage,
                      );
                    case _QuestionType.info:
                      return _InfoStep(
                        title: q.title,
                        description: q.hint ?? '',
                        onNext: () => _next(),
                        uiLanguage: _uiLanguage,
                      );
                    case _QuestionType.selection:
                      return _SelectionStep(
                        key: ValueKey(q.id),
                        title: q.title,
                        options: q.options ?? {},
                        initialValue: initialValue,
                        onSelected: (v) => _next(value: v),
                        uiLanguage: _uiLanguage,
                      );
                    case _QuestionType.choiceWithCustom:
                      return _ChoiceWithCustomStep(
                        key: ValueKey(q.id),
                        title: q.title,
                        choices: q.choices ?? [],
                        customHint: q.hint ?? 'Type your answer…',
                        initialValue: initialValue,
                        onSelected: (v) => _next(value: v),
                        isLastStep: index == _totalSteps - 1,
                        uiLanguage: _uiLanguage,
                      );
                    case _QuestionType.multiSelect:
                      return _MultiSelectStep(
                        key: ValueKey(q.id),
                        title: q.title,
                        choices: q.choices ?? [],
                        initialValue: initialValue,
                        onSelected: (v) => _next(value: v),
                        uiLanguage: _uiLanguage,
                      );
                    case _QuestionType.aiMode:
                      return _AiModeStep(
                        key: ValueKey(q.id),
                        currentValue: _aiMode,
                        onSelected: (v) => _next(value: v),
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

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

enum _QuestionType { text, selection, info, choiceWithCustom, multiSelect, aiMode }

class _OnboardingQuestion {
  final String id;
  final String title;
  final String? hint;
  final _QuestionType type;
  final Map<String, String>? options; // for selection type
  final List<String>? choices;        // for choiceWithCustom / multiSelect

  _OnboardingQuestion({
    required this.id,
    required this.title,
    this.hint,
    required this.type,
    this.options,
    this.choices,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice cards + "Other – type it yourself" widget
// ─────────────────────────────────────────────────────────────────────────────

class _ChoiceWithCustomStep extends StatefulWidget {
  final String title;
  final List<String> choices;
  final String customHint;
  final String? initialValue;
  final void Function(String) onSelected;
  final bool isLastStep;
  final String uiLanguage;

  const _ChoiceWithCustomStep({
    super.key,
    required this.title,
    required this.choices,
    required this.customHint,
    this.initialValue,
    required this.onSelected,
    this.isLastStep = false,
    required this.uiLanguage,
  });

  @override
  State<_ChoiceWithCustomStep> createState() => _ChoiceWithCustomStepState();
}

class _ChoiceWithCustomStepState extends State<_ChoiceWithCustomStep> {
  String? _selected;
  bool _showCustom = false;
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initialValue;
    if (init != null && init.isNotEmpty) {
      if (widget.choices.contains(init)) {
        _selected = init;
      } else {
        _showCustom = true;
        _selected = 'Other';
        _customController.text = init;
      }
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_showCustom) {
      final text = _customController.text.trim();
      if (text.isEmpty) return;
      widget.onSelected(text);
    } else if (_selected != null) {
      widget.onSelected(_selected!);
    }
  }

  bool get _canSubmit {
    if (_showCustom) return _customController.text.trim().isNotEmpty;
    return _selected != null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allChoices = [...widget.choices, 'Other – type it yourself'];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: allChoices.map((choice) {
                      final isOther = choice == 'Other – type it yourself';
                      final isSelected =
                          isOther ? _showCustom : _selected == choice && !_showCustom;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isOther) {
                              _showCustom = true;
                              _selected = 'Other';
                            } else {
                              _showCustom = false;
                              _selected = choice;
                              _customController.clear();
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          child: Text(
                            isOther ? '✏️  Other – type it yourself' : choice,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_showCustom) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _customController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 18),
                      decoration: InputDecoration(
                        hintText: widget.customHint,
                        border: const OutlineInputBorder(),
                        labelText: 'Your answer',
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _canSubmit ? _submit : null,
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

// ─────────────────────────────────────────────────────────────────────────────
// Multi-select chips (for allergens, dislikes)
// ─────────────────────────────────────────────────────────────────────────────

class _MultiSelectStep extends StatefulWidget {
  final String title;
  final List<String> choices;
  final String? initialValue; // comma-separated
  final void Function(String) onSelected;
  final String uiLanguage;

  const _MultiSelectStep({
    super.key,
    required this.title,
    required this.choices,
    this.initialValue,
    required this.onSelected,
    required this.uiLanguage,
  });

  @override
  State<_MultiSelectStep> createState() => _MultiSelectStepState();
}

class _MultiSelectStepState extends State<_MultiSelectStep> {
  late final Set<String> _selected;
  bool _noneSelected = false;
  bool _showCustom = false;
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final init = widget.initialValue;
    if (init != null && init.isNotEmpty) {
      final parts = init.split(',').map((s) => s.trim()).toSet();
      _noneSelected = parts.contains('None');
      _selected = _noneSelected ? {} : parts;
      
      final customParts = _selected.where((p) => !widget.choices.contains(p)).toList();
      if (customParts.isNotEmpty) {
        _showCustom = true;
        _customController.text = customParts.join(', ');
        _selected.removeAll(customParts);
      }
    } else {
      _selected = {};
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _toggle(String choice) {
    setState(() {
      if (choice == 'None') {
        _noneSelected = !_noneSelected;
        _selected.clear();
        _showCustom = false;
        _customController.clear();
      } else if (choice == 'Other - type it yourself') {
        _showCustom = !_showCustom;
        if (_noneSelected) _noneSelected = false;
        if (!_showCustom) _customController.clear();
      } else {
        _noneSelected = false;
        if (_selected.contains(choice)) {
          _selected.remove(choice);
        } else {
          _selected.add(choice);
        }
      }
    });
  }

  void _submit() {
    if (_noneSelected) {
      widget.onSelected('None');
    } else {
      final allSelected = _selected.toList();
      if (_showCustom && _customController.text.trim().isNotEmpty) {
        allSelected.add(_customController.text.trim());
      }
      
      if (allSelected.isNotEmpty) {
        widget.onSelected(allSelected.join(', '));
      } else {
        widget.onSelected('');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final renderChoices = widget.choices.where((c) => c != 'None').toList();
    renderChoices.add('Other - type it yourself');
    if (widget.choices.contains('None')) {
      renderChoices.add('None');
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Select all that apply',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: renderChoices.map((choice) {
                      final isNone = choice == 'None';
                      final isOther = choice == 'Other - type it yourself';
                      final isSelected = isNone 
                          ? _noneSelected 
                          : isOther 
                              ? _showCustom 
                              : _selected.contains(choice);
                      
                      return GestureDetector(
                        onTap: () => _toggle(choice),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 18,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.outline,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isOther ? '✏️  Other – type it yourself' : choice,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_showCustom) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: _customController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        hintText: 'e.g. peanuts, soy...',
                        border: OutlineInputBorder(),
                        labelText: 'Your answer',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _submit,
            child: Text(AppStrings.get('next', widget.uiLanguage)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info screen (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Icon(Icons.info_outline, size: 80, color: Colors.blue),
                  const SizedBox(height: 24),
                  Text(title,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  Text(description,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onNext,
            child: Text(AppStrings.get('next', uiLanguage)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selection (radio list) — used for language, tone, sleep, season, etc.
// ─────────────────────────────────────────────────────────────────────────────

class _SelectionStep extends StatefulWidget {
  final String title;
  final Map<String, String> options;
  final String? initialValue;
  final void Function(String) onSelected;
  final String uiLanguage;

  const _SelectionStep({
    super.key,
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
            child: RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              child: ListView(
                children: widget.options.entries.map((e) {
                  return RadioListTile(
                    title: Text(e.value, style: const TextStyle(fontSize: 18)),
                    value: e.key,
                  );
                }).toList(),
              ),
            ),
          ),
          ElevatedButton(
            onPressed:
                _selected == null ? null : () => widget.onSelected(_selected!),
            child: Text(AppStrings.get('next', widget.uiLanguage)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Free-text step — used for name only
// ─────────────────────────────────────────────────────────────────────────────

class _PreferenceStep extends StatefulWidget {
  final String title;
  final String hint;
  final String initialValue;
  final void Function(String) onSubmitted;
  final bool isLastStep;
  final String uiLanguage;

  const _PreferenceStep({
    super.key,
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

// ─────────────────────────────────────────────────────────────────────────────
// AI Mode Step — lets users pick Cloud (Gemini) or Local (Ollama)
// ─────────────────────────────────────────────────────────────────────────────

class _AiModeStep extends StatefulWidget {
  final String currentValue;
  final void Function(String) onSelected;

  const _AiModeStep({
    super.key,
    required this.currentValue,
    required this.onSelected,
  });

  @override
  State<_AiModeStep> createState() => _AiModeStepState();
}

class _AiModeStepState extends State<_AiModeStep> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentValue;
  }

  static const _options = [
    _AiOption(
      id: 'gemini',
      icon: Icons.cloud_rounded,
      title: 'Cloud AI (Groq)',
      subtitle: 'Uses cloud AI via the internet.\nExtremely fast — works on any device.',
      badge: 'Recommended',
      badgeColor: Color(0xFF2196F3),
    ),
    _AiOption(
      id: 'local_on_device',
      icon: Icons.phone_android_rounded,
      title: 'On-Device AI (Qwen2.5-0.5b)',
      subtitle:
          'Truly offline on your phone.\nRequires good hardware & ~400MB download later.',
      badge: null,
      badgeColor: Colors.transparent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How do you want the AI to work?',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'You can always change this in Settings later.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: _options.map((opt) {
                final isSelected = _selected == opt.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = opt.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            opt.icon,
                            size: 40,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      opt.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? colorScheme.primary
                                                : colorScheme.onSurface,
                                          ),
                                    ),
                                    if (opt.badge != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: opt.badgeColor,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          opt.badge!,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  opt.subtitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        height: 1.5,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: isSelected
                                ? Icon(Icons.check_circle,
                                    key: const ValueKey('checked'),
                                    color: colorScheme.primary)
                                : Icon(Icons.radio_button_unchecked,
                                    key: const ValueKey('unchecked'),
                                    color: colorScheme.outlineVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          ElevatedButton(
            onPressed: () => widget.onSelected(_selected),
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _AiOption {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final Color badgeColor;

  const _AiOption({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
  });
}
