import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import 'conversation_screen.dart';

/// A short, one-time questionnaire that seeds the personalization engine
/// before the user ever starts a conversation. Every answer here maps
/// directly into UserProfile.preferences / tonePreference /
/// languagePreference, which the rule engine and LLM fallback both read.
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
  String _protein = '';
  String _drink = '';

  static const _totalSteps = 5;

  void _next() {
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

  Future<void> _finish() async {
    final profile = UserProfile(
      name: _name.isEmpty ? 'Friend' : _name,
      languagePreference: _language,
      tonePreference: _tone,
      preferences: {
        if (_protein.isNotEmpty) 'protein': _protein,
        if (_drink.isNotEmpty) 'drink': _drink,
      },
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
      appBar: AppBar(title: const Text('Let\'s set things up')),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / _totalSteps),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _NameStep(onChanged: (v) => _name = v, onNext: _next),
                  _LanguageStep(
                    selected: _language,
                    onSelected: (v) => setState(() => _language = v),
                    onNext: _next,
                  ),
                  _ToneStep(
                    selected: _tone,
                    onSelected: (v) => setState(() => _tone = v),
                    onNext: _next,
                  ),
                  _PreferenceStep(
                    title: 'Do you have a preferred protein?\n(chicken, meat, fish...)',
                    hint: 'e.g. chicken',
                    onChanged: (v) => _protein = v,
                    onNext: _next,
                  ),
                  _PreferenceStep(
                    title: 'What do you usually like to drink?',
                    hint: 'e.g. tea, water',
                    onChanged: (v) => _drink = v,
                    onNext: _next,
                    isLastStep: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final String title;
  final Widget content;
  final VoidCallback onNext;
  final String buttonLabel;

  const _StepScaffold({
    required this.title,
    required this.content,
    required this.onNext,
    this.buttonLabel = 'Next',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          Expanded(child: content),
          ElevatedButton(onPressed: onNext, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  final void Function(String) onChanged;
  final VoidCallback onNext;
  const _NameStep({required this.onChanged, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'What should we call you?',
      onNext: onNext,
      content: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 20),
        decoration: const InputDecoration(
          hintText: 'Your name',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  final String selected;
  final void Function(String) onSelected;
  final VoidCallback onNext;
  const _LanguageStep({
    required this.selected,
    required this.onSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final options = {
      'english': 'English only',
      'arabicMSA': 'Arabic (Modern Standard)',
      'egyptianArabic': 'Egyptian Arabic',
      'mixed': 'Mix of Arabic and English',
    };
    return _StepScaffold(
      title: 'Which language do you want replies in?',
      onNext: onNext,
      content: ListView(
        children: options.entries.map((e) {
          return RadioListTile<String>(
            title: Text(e.value, style: const TextStyle(fontSize: 18)),
            value: e.key,
            groupValue: selected,
            onChanged: (v) => onSelected(v!),
          );
        }).toList(),
      ),
    );
  }
}

class _ToneStep extends StatelessWidget {
  final String selected;
  final void Function(String) onSelected;
  final VoidCallback onNext;
  const _ToneStep({
    required this.selected,
    required this.onSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final options = {
      'casual': 'Casual / relaxed',
      'formal': 'Formal / polite',
      'mixed': 'Depends on who I\'m talking to',
    };
    return _StepScaffold(
      title: 'How do you usually like to talk?',
      onNext: onNext,
      content: ListView(
        children: options.entries.map((e) {
          return RadioListTile<String>(
            title: Text(e.value, style: const TextStyle(fontSize: 18)),
            value: e.key,
            groupValue: selected,
            onChanged: (v) => onSelected(v!),
          );
        }).toList(),
      ),
    );
  }
}

class _PreferenceStep extends StatelessWidget {
  final String title;
  final String hint;
  final void Function(String) onChanged;
  final VoidCallback onNext;
  final bool isLastStep;

  const _PreferenceStep({
    required this.title,
    required this.hint,
    required this.onChanged,
    required this.onNext,
    this.isLastStep = false,
  });

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: title,
      onNext: onNext,
      buttonLabel: isLastStep ? 'Finish setup' : 'Next',
      content: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 20),
        decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
      ),
    );
  }
}
