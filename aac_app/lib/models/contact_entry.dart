import 'package:hive/hive.dart';

@HiveType(typeId: 3)
class ContactEntry extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String relationship; // e.g. "Mom", "Doctor", "Friend"

  @HiveField(3)
  String preferredTone; // e.g. "casual", "formal"

  ContactEntry({
    required this.id,
    required this.name,
    required this.relationship,
    this.preferredTone = 'mixed',
  });
}
