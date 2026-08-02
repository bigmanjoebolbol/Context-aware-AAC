import 'package:hive/hive.dart';

/// Represents a named conversation session (e.g. "Mom", "Doctor", "Stranger").
/// Each session groups a set of [ConversationEntry] items under one named context.
///
/// Quick / anonymous conversations are NOT stored as sessions — they are
/// transient and discarded when the screen is closed.
@HiveType(typeId: 4)
class ConversationSession extends HiveObject {
  @HiveField(0)
  String id; // UUID

  @HiveField(1)
  String displayName; // e.g. "Mom", "Dr. Ahmed", "Stranger at café"

  @HiveField(2)
  String? contactId; // links to ContactEntry.id if a known contact, else null

  @HiveField(3)
  bool isStranger; // true = one-off unnamed/stranger session

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  DateTime lastMessageAt;

  @HiveField(6)
  String? notes; // optional user notes about the person

  ConversationSession({
    required this.id,
    required this.displayName,
    this.contactId,
    this.isStranger = false,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    this.notes,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastMessageAt = lastMessageAt ?? DateTime.now();
}
