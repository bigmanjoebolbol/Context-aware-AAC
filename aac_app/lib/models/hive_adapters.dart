import 'package:hive/hive.dart';
import 'user_profile.dart';
import 'conversation_entry.dart';
import 'phrase_entry.dart';

/// Manual adapters (no build_runner needed). Registered once in main.dart
/// via [registerHiveAdapters]. If you later prefer generated adapters,
/// swap these out for `part 'x.g.dart'` + `flutter pub run build_runner build`.

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 0;

  @override
  UserProfile read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      name: fields[0] as String,
      languagePreference: fields[1] as String,
      tonePreference: fields[2] as String,
      preferences: Map<String, String>.from(fields[3] as Map),
      relationshipTones: Map<String, String>.from(fields[4] as Map),
      autoReplyEnabled: fields[5] as bool,
      onboardingComplete: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.languagePreference)
      ..writeByte(2)
      ..write(obj.tonePreference)
      ..writeByte(3)
      ..write(obj.preferences)
      ..writeByte(4)
      ..write(obj.relationshipTones)
      ..writeByte(5)
      ..write(obj.autoReplyEnabled)
      ..writeByte(6)
      ..write(obj.onboardingComplete);
  }
}

class ConversationEntryAdapter extends TypeAdapter<ConversationEntry> {
  @override
  final int typeId = 1;

  @override
  ConversationEntry read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationEntry(
      otherPersonText: fields[0] as String,
      chosenReply: fields[1] as String?,
      questionType: fields[2] as String,
      contactRelationship: fields[3] as String?,
      timestamp: fields[4] as DateTime,
      wasAutoReplied: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ConversationEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.otherPersonText)
      ..writeByte(1)
      ..write(obj.chosenReply)
      ..writeByte(2)
      ..write(obj.questionType)
      ..writeByte(3)
      ..write(obj.contactRelationship)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.wasAutoReplied);
  }
}

class PhraseEntryAdapter extends TypeAdapter<PhraseEntry> {
  @override
  final int typeId = 2;

  @override
  PhraseEntry read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return PhraseEntry(
      triggerKey: fields[0] as String,
      variants: List<String>.from(fields[1] as List),
      replyScores: Map<String, double>.from(fields[2] as Map),
      injectPreference: fields[3] as bool,
      preferenceKey: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PhraseEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.triggerKey)
      ..writeByte(1)
      ..write(obj.variants)
      ..writeByte(2)
      ..write(obj.replyScores)
      ..writeByte(3)
      ..write(obj.injectPreference)
      ..writeByte(4)
      ..write(obj.preferenceKey);
  }
}

void registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(ConversationEntryAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(PhraseEntryAdapter());
}
