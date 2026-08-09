import 'package:hive/hive.dart';
import 'user_profile.dart';
import 'conversation_entry.dart';
import 'conversation_session.dart';
import 'phrase_entry.dart';
import 'contact_entry.dart';

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
      name: fields[0] as String? ?? 'Friend',
      languagePreference: fields[1] as String? ?? 'mixed',
      tonePreference: fields[2] as String? ?? 'mixed',
      preferences: (fields[3] as Map?)?.cast<String, String>() ?? {},
      relationshipTones: (fields[4] as Map?)?.cast<String, String>() ?? {},
      autoReplyEnabled: fields[5] as bool? ?? false,
      onboardingComplete: fields[6] as bool? ?? false,
      uiLanguage: fields[8] as String? ?? 'en',
      themeMode: fields[9] as String? ?? 'light',
      selectedAiProvider: fields[10] as String? ?? 'default',
      contacts: (fields[11] as List?)?.cast<ContactEntry>() ?? [],
      shareLocationWithAi: fields[12] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(12)
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
      ..write(obj.onboardingComplete)
      ..writeByte(8)
      ..write(obj.uiLanguage)
      ..writeByte(9)
      ..write(obj.themeMode)
      ..writeByte(10)
      ..write(obj.selectedAiProvider)
      ..writeByte(11)
      ..write(obj.contacts)
      ..writeByte(12)
      ..write(obj.shareLocationWithAi);
  }
}

class ContactEntryAdapter extends TypeAdapter<ContactEntry> {
  @override
  final int typeId = 3;

  @override
  ContactEntry read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return ContactEntry(
      id: fields[0] as String,
      name: fields[1] as String,
      relationship: fields[2] as String,
      preferredTone: fields[3] as String? ?? 'mixed',
    );
  }

  @override
  void write(BinaryWriter writer, ContactEntry obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.relationship)
      ..writeByte(3)
      ..write(obj.preferredTone);
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
      otherPersonText: fields[0] as String? ?? '',
      chosenReply: fields[1] as String?,
      questionType: fields[2] as String? ?? 'openEnded',
      contactRelationship: fields[3] as String?,
      timestamp: fields[4] as DateTime? ?? DateTime.now(),
      wasAutoReplied: fields[5] as bool? ?? false,
      sessionId: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ConversationEntry obj) {
    writer
      ..writeByte(7)
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
      ..write(obj.wasAutoReplied)
      ..writeByte(6)
      ..write(obj.sessionId);
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
    // Hive returns nested maps as Map<dynamic, dynamic>.
    // We must rebuild the structure manually to get Map<String, Map<String, String>>.
    Map<String, Map<String, String>> _parseTranslations(dynamic raw) {
      if (raw == null) return {};
      final outer = raw as Map;
      return {
        for (final outerEntry in outer.entries)
          outerEntry.key.toString(): {
            for (final innerEntry in (outerEntry.value as Map).entries)
              innerEntry.key.toString(): innerEntry.value.toString(),
          },
      };
    }

    return PhraseEntry(
      triggerKey: fields[0] as String? ?? '',
      variants: (fields[1] as List?)?.cast<String>() ?? [],
      replyScores: (fields[2] as Map?)?.cast<String, double>() ?? {},
      injectPreference: fields[3] as bool? ?? false,
      preferenceKey: fields[4] as String?,
      pinned: fields[5] as bool? ?? false,
      replyTranslations: _parseTranslations(fields[6]),
    );
  }

  @override
  void write(BinaryWriter writer, PhraseEntry obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.triggerKey)
      ..writeByte(1)
      ..write(obj.variants)
      ..writeByte(2)
      ..write(obj.replyScores)
      ..writeByte(3)
      ..write(obj.injectPreference)
      ..writeByte(4)
      ..write(obj.preferenceKey)
      ..writeByte(5)
      ..write(obj.pinned)
      ..writeByte(6)
      ..write(obj.replyTranslations);
  }
}

class ConversationSessionAdapter extends TypeAdapter<ConversationSession> {
  @override
  final int typeId = 4;

  @override
  ConversationSession read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return ConversationSession(
      id: fields[0] as String,
      displayName: fields[1] as String,
      contactId: fields[2] as String?,
      isStranger: fields[3] as bool? ?? false,
      createdAt: fields[4] as DateTime?,
      lastMessageAt: fields[5] as DateTime?,
      notes: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ConversationSession obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.displayName)
      ..writeByte(2)
      ..write(obj.contactId)
      ..writeByte(3)
      ..write(obj.isStranger)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.lastMessageAt)
      ..writeByte(6)
      ..write(obj.notes);
  }
}

void registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(UserProfileAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ConversationEntryAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(PhraseEntryAdapter());
  if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ContactEntryAdapter());
  if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(ConversationSessionAdapter());
}