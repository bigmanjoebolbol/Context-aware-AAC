import 'package:hive/hive.dart';

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

  UserProfile({
    required this.name,
    this.languagePreference = 'mixed',
    this.tonePreference = 'mixed',
    Map<String, String>? preferences,
    Map<String, String>? relationshipTones,
    this.autoReplyEnabled = false,
    this.onboardingComplete = false,
  })  : preferences = preferences ?? {},
        relationshipTones = relationshipTones ?? {};
}
