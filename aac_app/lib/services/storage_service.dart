import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_profile.dart';
import '../models/conversation_entry.dart';
import '../models/phrase_entry.dart';
import '../models/hive_adapters.dart';
import 'phrasebook_seed.dart';

/// Single access point for all local, on-device storage. Everything here
/// is offline - no network call is ever made from this class. This is
/// deliberate: the user's profile and phrasebook must always be readable
/// and writable even with zero connectivity.
class StorageService extends ChangeNotifier {
  static const _profileBoxName = 'profile_box';
  static const _phrasebookBoxName = 'phrasebook_box';
  static const _historyBoxName = 'history_box';

  late Box<UserProfile> _profileBox;
  late Box<PhraseEntry> _phrasebookBox;
  late Box<ConversationEntry> _historyBox;

  Future<void> init() async {
    await Hive.initFlutter();
    registerHiveAdapters();
    _profileBox = await Hive.openBox<UserProfile>(_profileBoxName);
    _phrasebookBox = await Hive.openBox<PhraseEntry>(_phrasebookBoxName);
    _historyBox = await Hive.openBox<ConversationEntry>(_historyBoxName);

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

  /// Bumps the score for [chosenReply] under the matched [entry], so that
  /// next time this same question type comes up, the user's actual habits
  /// are reflected in the ranking. This is the entirety of the
  /// "personalization learning" - simple frequency reinforcement, fully
  /// on-device and fully explainable.
  Future<void> reinforcePhraseChoice(PhraseEntry entry, String chosenReply) async {
    entry.replyScores[chosenReply] = (entry.replyScores[chosenReply] ?? 0) + 1;
    await entry.save();
  }

  /// Called when the user picks a reply that isn't in the phrasebook yet
  /// (e.g. from an LLM suggestion, or their own custom text) for a
  /// recurring-looking question. Creates a new learned phrase entry so
  /// the fast path can catch this question next time.
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

  // ---------- Conversation history ----------

  Future<void> logEntry(ConversationEntry entry) async {
    await _historyBox.add(entry);
  }

  List<ConversationEntry> recentHistory({int limit = 20}) {
    final all = _historyBox.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.take(limit).toList();
  }
}
