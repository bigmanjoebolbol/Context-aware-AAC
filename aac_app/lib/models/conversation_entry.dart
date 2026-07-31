import 'package:hive/hive.dart';

/// How a reply suggestion was produced. Used for transparency (the user
/// can always tell whether a reply came from the fast rule path or the
/// LLM fallback) and for scoring/personalization bookkeeping.
enum SuggestionSource { phrasebook, eitherOr, yesNo, userPreferenceFill, llm, custom }

class Suggestion {
  final String text;
  final SuggestionSource source;
  double score;

  Suggestion({
    required this.text,
    required this.source,
    this.score = 0,
  });
}

/// The type of question/utterance detected by the rule engine.
/// Kept as a string context key so scoring buckets stay stable in storage.
enum QuestionType { eitherOr, yesNo, knownPhrase, openEnded }

@HiveType(typeId: 1)
class ConversationEntry extends HiveObject {
  @HiveField(0)
  String otherPersonText;

  @HiveField(1)
  String? chosenReply;

  @HiveField(2)
  String questionType; // stores QuestionType.name

  @HiveField(3)
  String? contactRelationship; // e.g. "mom", "coworker", null if unknown

  @HiveField(4)
  DateTime timestamp;

  @HiveField(5)
  bool wasAutoReplied;

  ConversationEntry({
    required this.otherPersonText,
    this.chosenReply,
    required this.questionType,
    this.contactRelationship,
    DateTime? timestamp,
    this.wasAutoReplied = false,
  }) : timestamp = timestamp ?? DateTime.now();
}
