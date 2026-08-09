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
    final detectedLang = _detectLanguage(text, profile.languagePreference);

    // 1. Either/or & multi-choice processing takes priority.
    final options = _extractOptions(normalized);
    if (options.isNotEmpty && options.length >= 2) {
      final suggestions = options
          .map((opt) => Suggestion(text: _capitalize(opt), source: SuggestionSource.eitherOr))
          .toList();

      final preferredThird = _thirdOptionFromPreference(options, profile);
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

    // 2. Known phrasebook entries - checked before generic yes/no because
    //    a stored phrase is more specific/personalized than a generic answer.
    final phraseMatch = _matchPhrasebook(normalized, phrasebook);
    if (phraseMatch != null) {
      return RuleEngineResult(
        handled: true,
        type: QuestionType.knownPhrase,
        suggestions: _rankedSuggestionsFromPhrase(phraseMatch, profile, detectedLang),
        matchedPhrase: phraseMatch,
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

  /// Detects the language of the incoming text based on its script.
  /// Returns 'egyptian', 'msa', or 'english'. Falls back to the user's
  /// language preference if the text is ambiguous (e.g. very short).
  String _detectLanguage(String text, String userLangPref) {
    // Check for Arabic script characters
    final hasArabic = RegExp(r'[\u0600-\u06FF]').hasMatch(text);
    if (hasArabic) {
      // Treat all Arabic input as Egyptian since that's the colloquial default
      return 'egyptian';
    }
    // Latin script — it's English
    return 'english';
  }

  /// Maps a detected language string to the key used in replyTranslations.
  String _translationKey(String detectedLang) {
    switch (detectedLang) {
      case 'egyptian':
        return 'egyptian';
      case 'msa':
        return 'msa';
      default:
        return 'english';
    }
  }

  List<Suggestion> _rankedSuggestionsFromPhrase(
      PhraseEntry entry, UserProfile profile, String detectedLang) {
    final sortedKeys = entry.replyScores.keys.toList()
      ..sort((a, b) => entry.replyScores[b]!.compareTo(entry.replyScores[a]!));

    final primaryKey = _translationKey(detectedLang);
    // Fallback chain: primary detected lang → opposite language → raw key
    String _resolveText(String replyKey) {
      final translations = entry.replyTranslations[replyKey];
      if (translations == null) return replyKey;
      return translations[primaryKey] ??
          translations['egyptian'] ??
          translations['english'] ??
          translations['msa'] ??
          replyKey;
    }

    final suggestions = sortedKeys
        .take(4)
        .map((k) => Suggestion(
              text: _resolveText(k),
              source: SuggestionSource.phrasebook,
              score: entry.replyScores[k]!,
              replyKey: k,
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

  static const List<String> _leadInStarters = [
    'do you want', 'do you like', 'would you like', 'would you prefer',
    'do you prefer', 'do you have', 'do you take', 'is it', 'are you',
    'should we', 'shall we', 'do we get', 'which do you like', 'which one',
    'هل ترغب في', 'هل تريد', 'هل تحب', 'تحب تاكل', 'تحب تشرب', 'تحب', 'عايز',
    'عاوز', 'حابب', 'ممكن', 'انتا عايز', 'انت عاوز', 'تحب تاخد',
  ];

  List<String> _extractOptions(String text) {
    String clean = text.trim();
    if (clean.endsWith('?') || clean.endsWith('؟')) {
      clean = clean.substring(0, clean.length - 1).trim();
    }

    for (final starter in _leadInStarters) {
      if (clean.toLowerCase().startsWith(starter)) {
        clean = clean.substring(starter.length).trim();
        break;
      }
    }

    final hasConnector = RegExp(r'\b(?:or|ولا|او|أو)\b|[,،]', caseSensitive: false).hasMatch(clean);
    if (!hasConnector) return [];

    final rawParts = clean.split(RegExp(r'[,،]|\s+\b(?:or|ولا|او|أو)\b\s+', caseSensitive: false));
    final result = <String>[];

    for (var part in rawParts) {
      var trimmed = part.trim();
      trimmed = trimmed.replaceAll(RegExp(r'^\b(?:or|ولا|او|أو)\b\s*', caseSensitive: false), '').trim();
      if (trimmed.isNotEmpty && trimmed.split(' ').length <= 4) {
        result.add(trimmed);
      }
    }

    return result.length >= 2 ? result : [];
  }

  String? _thirdOptionFromPreference(List<String> options, UserProfile profile) {
    final protein = profile.preferences['protein'];
    if (protein == null || protein.isEmpty) return null;
    final proteinLower = protein.toLowerCase();
    
    final alreadyContains = options.any((opt) => opt.toLowerCase().contains(proteinLower));
    if (alreadyContains) return null;

    const proteinRelatedWords = [
      'chicken', 'meat', 'fish', 'beef', 'lamb', 'protein',
      'فراخ', 'لحمة', 'سمك', 'بروتين',
    ];
    final isProteinContext = options.any(
      (opt) => proteinRelatedWords.any((w) => opt.toLowerCase().contains(w)),
    );
    if (!isProteinContext) return null;

    return _capitalize(protein);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
