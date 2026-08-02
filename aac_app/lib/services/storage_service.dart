import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_profile.dart';
import '../models/conversation_entry.dart';
import '../models/conversation_session.dart';
import '../models/phrase_entry.dart';
import '../models/hive_adapters.dart';
import 'phrasebook_seed.dart';

/// Single access point for all local, on-device storage.
class StorageService extends ChangeNotifier {
  static const _profileBoxName = 'profile_box';
  static const _phrasebookBoxName = 'phrasebook_box';
  static const _historyBoxName = 'history_box';
  static const _sessionBoxName = 'session_box';

  late Box<UserProfile> _profileBox;
  late Box<PhraseEntry> _phrasebookBox;
  late Box<ConversationEntry> _historyBox;
  late Box<ConversationSession> _sessionBox;

  Future<void> init() async {
    await Hive.initFlutter();
    registerHiveAdapters();
    _profileBox = await Hive.openBox<UserProfile>(_profileBoxName);
    _phrasebookBox = await Hive.openBox<PhraseEntry>(_phrasebookBoxName);
    _historyBox = await Hive.openBox<ConversationEntry>(_historyBoxName);
    _sessionBox = await Hive.openBox<ConversationSession>(_sessionBoxName);

    if (_phrasebookBox.isEmpty) {
      for (final entry in defaultPhrasebook()) {
        await _phrasebookBox.add(entry);
      }
    }
  }

  // ---------- Profile ----------

  UserProfile? getProfile() {
    if (_profileBox.isEmpty) return null;
    return _profileBox.getAt(0);
  }

  Future<void> saveProfile(UserProfile profile) async {
    if (_profileBox.isEmpty) {
      await _profileBox.add(profile);
    } else {
      await _profileBox.putAt(0, profile);
    }
    notifyListeners();
  }

  // ---------- Phrasebook ----------

  List<PhraseEntry> getPhrasebook() => _phrasebookBox.values.toList();

  Future<void> addPhraseEntry(PhraseEntry entry) async {
    await _phrasebookBox.add(entry);
  }

  Future<void> reinforcePhraseChoice(PhraseEntry entry, String chosenReply) async {
    entry.replyScores[chosenReply] = (entry.replyScores[chosenReply] ?? 0) + 1;
    await entry.save();
  }

  Future<void> learnNewPhrase({
    required String triggerKey,
    required List<String> variants,
    required String chosenReply,
  }) async {
    final existing = _phrasebookBox.values
        .where((e) => e.triggerKey == triggerKey)
        .toList();
    if (existing.isNotEmpty) {
      await reinforcePhraseChoice(existing.first, chosenReply);
      return;
    }
    final entry = PhraseEntry(
      triggerKey: triggerKey,
      variants: variants,
      replyScores: {chosenReply: 1},
    );
    await addPhraseEntry(entry);
  }

  // ---------- Conversation Sessions ----------

  /// Returns all saved sessions sorted newest first.
  List<ConversationSession> getSessions() {
    return _sessionBox.values.toList()
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
  }

  Future<ConversationSession> createSession(ConversationSession session) async {
    await _sessionBox.put(session.id, session);
    notifyListeners();
    return session;
  }

  Future<void> updateSession(ConversationSession session) async {
    await _sessionBox.put(session.id, session);
    notifyListeners();
  }

  /// Deletes a session AND all its associated conversation entries.
  Future<void> deleteSession(String sessionId) async {
    // Remove all entries belonging to this session
    final toDelete = _historyBox.values
        .where((e) => e.sessionId == sessionId)
        .toList();
    for (final entry in toDelete) {
      await entry.delete();
    }
    await _sessionBox.delete(sessionId);
    notifyListeners();
  }

  ConversationSession? getSession(String sessionId) {
    return _sessionBox.get(sessionId);
  }

  // ---------- Conversation history ----------

  Future<void> logEntry(ConversationEntry entry) async {
    await _historyBox.add(entry);
    // Update the session's lastMessageAt timestamp
    if (entry.sessionId != null) {
      final session = _sessionBox.get(entry.sessionId!);
      if (session != null) {
        session.lastMessageAt = entry.timestamp;
        await session.save();
        notifyListeners();
      }
    }
  }

  /// Returns recent history. If [sessionId] is provided, filters to that session only.
  List<ConversationEntry> recentHistory({int limit = 20, String? sessionId}) {
    final all = _historyBox.values
        .where((e) => sessionId == null || e.sessionId == sessionId)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.take(limit).toList();
  }

  /// Deletes all conversation entries for a session (used for "clear chat").
  Future<void> clearSessionHistory(String sessionId) async {
    final toDelete = _historyBox.values
        .where((e) => e.sessionId == sessionId)
        .toList();
    for (final entry in toDelete) {
      await entry.delete();
    }
    notifyListeners();
  }
}



