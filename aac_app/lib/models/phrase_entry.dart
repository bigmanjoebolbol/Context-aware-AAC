import 'package:hive/hive.dart';

/// A single known question pattern (e.g. "what do you want to eat") together
/// with a scored list of replies. Scores go up every time the user picks a
/// reply for a matching question, so the ranking adapts over time without
/// any model training - just frequency-weighted personalization.
@HiveType(typeId: 2)
class PhraseEntry extends HiveObject {
  @HiveField(0)
  String triggerKey; // normalized canonical form, e.g. "what_eat"

  /// Surface-form variants that should match this trigger, in English,
  /// MSA, and Egyptian Arabic. Matching is substring/keyword based, not
  /// exact-string, so small variations still hit.
  @HiveField(1)
  List<String> variants;

  /// reply key -> score. The key is a stable identifier (e.g. "reply_1")
  /// that maps to a translation object in [replyTranslations].
  @HiveField(2)
  Map<String, double> replyScores;

  /// If true, replies here should also have the user's saved preference
  /// (e.g. protein, drink) appended as an extra option when relevant.
  @HiveField(3)
  bool injectPreference;

  /// Which preferences key to pull from UserProfile.preferences if
  /// injectPreference is true (e.g. "protein", "drink").
  @HiveField(4)
  String? preferenceKey;

  /// If true, this phrase entry appears as a pinned quick phrase chip
  /// in the conversation screen, usable without waiting for a question.
  @HiveField(5)
  bool pinned;

  /// Maps a reply key (same as in replyScores) to its translations:
  /// {'english': '...', 'msa': '...', 'egyptian': '...'}.
  /// At least one of these must be non‑empty.
  @HiveField(6)
  Map<String, Map<String, String>> replyTranslations;

  PhraseEntry({
    required this.triggerKey,
    required this.variants,
    Map<String, double>? replyScores,
    this.injectPreference = false,
    this.preferenceKey,
    this.pinned = false,
    Map<String, Map<String, String>>? replyTranslations,
  })  : replyScores = replyScores ?? {},
        replyTranslations = replyTranslations ?? {};
}