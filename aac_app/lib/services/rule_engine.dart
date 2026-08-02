import '../models/conversation_entry.dart';
import '../models/phrase_entry.dart';
import '../models/user_profile.dart';

/// Result of classifying + answering an incoming sentence via the fast,
/// offline rule path. If [handled] is false, the caller should fall back
/// to the LLM service - this only happens for genuinely open-ended text.
class RuleEngineResult {
  final bool handled;
  final QuestionType type;
  final List<Suggestion> suggestions;
  final PhraseEntry? matchedPhrase;

  RuleEngineResult({
    required this.handled,
    required this.type,
    required this.suggestions,
    this.matchedPhrase,
  });
}

class RuleEngine {
  // Egyptian Arabic + MSA "or" connectors, and English "or".
  static final RegExp _eitherOrPattern = RegExp(
    r'(.+?)\s+(?:or|ولا|او|أو)\s+(.+?)\??$',
    caseSensitive: false,
  );

  // Starters that strongly indicate a yes/no question.
  static const List<String> _yesNoStarters = [
    'do you', 'does he', 'does she', 'did you', 'can you', 'could you',
    'would you', 'will you', 'is it', 'are you', 'have you',
    'هل', 'عايز', 'عاوز', 'تحب', 'حابب', 'ممكن',
  ];

  String _normalize(String s) => s.trim().toLowerCase();

  /// Attempts to answer [text] using the fast path. [profile] supplies
  /// preference-fill data (e.g. protein choice). [phrasebook] is the
  /// user's current, personalized set of known phrase entries.
  RuleEngineResult process({
    required String text,
    required UserProfile profile,
    required List<PhraseEntry> phrasebook,
  }) {
    final normalized = _normalize(text);

    // 1. Either/or takes priority - it's the most specific pattern and
    //    the most valuable to catch fast (e.g. "chicken or meat?").
    final eitherOrMatch = _eitherOrPattern.firstMatch(normalized);
    if (eitherOrMatch != null) {
      final optionA = eitherOrMatch.group(1)?.trim() ?? '';
      final optionB = eitherOrMatch.group(2)?.trim() ?? '';
      if (optionA.isNotEmpty && optionB.isNotEmpty && optionA.split(' ').length <= 4) {
        final suggestions = <Suggestion>[
          Suggestion(text: _capitalize(optionA), source: SuggestionSource.eitherOr),
          Suggestion(text: _capitalize(optionB), source: SuggestionSource.eitherOr),
        ];
        final preferredThird = _thirdOptionFromPreference(optionA, optionB, profile);
        if (preferredThird != null) {
          suggestions.add(Suggestion(
            text: preferredThird,
            source: SuggestionSource.userPreferenceFill,
          ));
        }
        return RuleEngineResult(
          handled: true,
          type: QuestionType.eitherOr,
          suggestions: suggestions,
        );
      }
    }

    // 2. Known phrasebook entries - checked before generic yes/no because
    //    a stored phrase is more specific/personalized than a generic answer.
    final phraseMatch = _matchPhrasebook(normalized, phrasebook);
    if (phraseMatch != null) {
      return RuleEngineResult(
        handled: true,
        type: QuestionType.knownPhrase,
        suggestions: _rankedSuggestionsFromPhrase(phraseMatch, profile),
        matchedPhrase: phraseMatch,
      );
    }

    // 3. Generic yes/no.
    final whStarters = ['how', 'what', 'why', 'who', 'where', 'when', 'إزاي', 'فين', 'ليه', 'مين', 'متى'];
    final isWhQuestion = whStarters.any((s) => normalized.startsWith(s));

    final looksYesNo = !isWhQuestion &&
        (_yesNoStarters.any((s) => normalized.startsWith(s)) ||
            (normalized.endsWith('?') && normalized.split(' ').length <= 6));

    if (looksYesNo) {
      return RuleEngineResult(
        handled: true,
        type: QuestionType.yesNo,
        suggestions: [
          Suggestion(text: 'Yes / أيوة', source: SuggestionSource.yesNo, score: 2),
          Suggestion(text: 'No / لأ', source: SuggestionSource.yesNo, score: 2),
          Suggestion(text: 'Maybe / يمكن', source: SuggestionSource.yesNo, score: 1),
        ],
      );
    }

    // 4. Nothing matched - hand off to the LLM fallback.
    return RuleEngineResult(
      handled: false,
      type: QuestionType.openEnded,
      suggestions: [],
    );
  }

  PhraseEntry? _matchPhrasebook(String normalized, List<PhraseEntry> phrasebook) {
    for (final entry in phrasebook) {
      for (final variant in entry.variants) {
        if (normalized.contains(_normalize(variant))) {
          return entry;
        }
      }
    }
    return null;
  }

  List<Suggestion> _rankedSuggestionsFromPhrase(PhraseEntry entry, UserProfile profile) {
    final sortedKeys = entry.replyScores.keys.toList()
      ..sort((a, b) => entry.replyScores[b]!.compareTo(entry.replyScores[a]!));

    final suggestions = sortedKeys
        .take(4)
        .map((k) => Suggestion(
              text: k,
              source: SuggestionSource.phrasebook,
              score: entry.replyScores[k]!,
            ))
        .toList();

    if (entry.injectPreference && entry.preferenceKey != null) {
      final pref = profile.preferences[entry.preferenceKey];
      if (pref != null && pref.isNotEmpty) {
        final alreadyPresent = suggestions.any(
          (s) => s.text.toLowerCase().contains(pref.toLowerCase()),
        );
        if (!alreadyPresent) {
          suggestions.add(Suggestion(
            text: _capitalize(pref),
            source: SuggestionSource.userPreferenceFill,
          ));
        }
      }
    }

    return suggestions.take(5).toList();
  }

  /// If the other person offered two options and neither matches the
  /// user's saved preference for that category, and the preference is a
  /// plausible third option, surface it (e.g. "chicken or meat?" -> add
  /// user's saved protein choice like "fish" as a third option).
  String? _thirdOptionFromPreference(String optionA, String optionB, UserProfile profile) {
    final protein = profile.preferences['protein'];
    if (protein == null || protein.isEmpty) return null;
    final proteinLower = protein.toLowerCase();
    if (optionA.contains(proteinLower) || optionB.contains(proteinLower)) return null;

    // Only offer this when the either/or options look food/protein related,
    // to avoid injecting "chicken" into an unrelated either/or question.
    const proteinRelatedWords = [
      'chicken', 'meat', 'fish', 'beef', 'lamb', 'protein',
      'فراخ', 'لحمة', 'سمك', 'بروتين',
    ];
    final isProteinContext = proteinRelatedWords.any(
      (w) => optionA.contains(w) || optionB.contains(w),
    );
    if (!isProteinContext) return null;

    return _capitalize(protein);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
