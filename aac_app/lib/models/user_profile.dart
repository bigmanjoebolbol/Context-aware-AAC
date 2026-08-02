import 'package:hive/hive.dart';
import 'contact_entry.dart';

/// The user's language preference for suggestion generation and TTS output.
enum AppLanguage { english, arabicMSA, egyptianArabic, mixed }

/// The tone the user prefers their generated replies to carry.
enum ReplyTone { casual, formal, mixed }

@HiveType(typeId: 0)
class UserProfile extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String languagePreference; // stores AppLanguage.name

  @HiveField(2)
  String tonePreference; // stores ReplyTone.name

  /// Free-form preference tags collected during onboarding, e.g.
  /// {"protein": "chicken", "drink": "tea", "topic_family": "close"}
  @HiveField(3)
  Map<String, String> preferences;

  /// Per-contact-relationship tone overrides, e.g. {"mom": "casual", "boss": "formal"}
  @HiveField(4)
  Map<String, String> relationshipTones;

  /// Whether "Auto-reply" mode is enabled (off by default, discouraged).
  @HiveField(5)
  bool autoReplyEnabled;

  /// Whether onboarding questionnaire has been completed.
  @HiveField(6)
  bool onboardingComplete;

  /// The language of the app UI (en, ar).
  @HiveField(8)
  String uiLanguage;

  /// The theme mode of the app (light, dark, highContrast).
  @HiveField(9)
  String themeMode;

  /// The selected AI provider ID (groq, gemini, claude, or 'default').
  @HiveField(10)
  String selectedAiProvider;

  /// User's key contacts for context.
  @HiveField(11)
  List<ContactEntry> contacts;

  /// Whether to automatically share location context with AI.
  @HiveField(12)
  bool shareLocationWithAi;

  /// The user's preferred AI backend: 'gemini' (cloud) or 'ollama' (local).
  /// The backend will try this first and fall back gracefully if unavailable.
  @HiveField(13)
  String aiMode;

  UserProfile({
    required this.name,
    this.languagePreference = 'mixed',
    this.tonePreference = 'mixed',
    Map<String, String>? preferences,
    Map<String, String>? relationshipTones,
    this.autoReplyEnabled = false,
    this.onboardingComplete = false,
    this.uiLanguage = 'en',
    this.themeMode = 'light',
    this.selectedAiProvider = 'default',
    List<ContactEntry>? contacts,
    this.shareLocationWithAi = false,
    this.aiMode = '',         // '' means "use server default"
  })  : preferences = preferences ?? {},
        relationshipTones = relationshipTones ?? {},
        contacts = contacts ?? [];
}
