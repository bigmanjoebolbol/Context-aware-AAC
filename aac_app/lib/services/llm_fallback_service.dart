import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation_entry.dart';
import '../models/user_profile.dart';

/// Handles the "slow path": only called when [RuleEngine.process] returns
/// handled=false, i.e. genuinely novel/open-ended sentences.
///
/// IMPORTANT (security): never ship a raw Gemini API key inside a mobile
/// app binary - it can be extracted from the compiled app. [backendEndpoint]
/// should point at the small Node/Express server in `aac_backend/`, which
/// holds the key server-side and calls Gemini on your behalf. See
/// `aac_backend/README.md` for setup and deployment.
class LlmFallbackService {
  final String backendEndpoint;
  final Duration timeout;

  /// Must match APP_SHARED_SECRET on the backend, if set. Prevents random
  /// clients from calling your deployed backend and spending your Gemini
  /// quota. Leave null while testing against a local server with no
  /// APP_SHARED_SECRET configured.
  final String? sharedSecret;

  LlmFallbackService({
    required this.backendEndpoint,
    this.timeout = const Duration(seconds: 8),
    this.sharedSecret,
  });

  /// Requests 3-5 short reply suggestions for [otherPersonText] given the
  /// user's [profile] and recent [history] for context. Returns an empty
  /// list on any failure so the UI can gracefully fall back to a manual
  /// "write my own message" prompt rather than hanging.
  Future<List<String>> getSuggestions({
    required String otherPersonText,
    required UserProfile profile,
    required List<ConversationEntry> history,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(backendEndpoint),
            headers: {
              'Content-Type': 'application/json',
              if (sharedSecret != null) 'x-app-key': sharedSecret!,
            },
            body: jsonEncode({
              'other_person_text': otherPersonText,
              'language_preference': profile.languagePreference,
              'tone_preference': profile.tonePreference,
              'preferences': profile.preferences,
              'recent_history': history
                  .take(5)
                  .map((h) => {
                        'said': h.otherPersonText,
                        'replied': h.chosenReply,
                      })
                  .toList(),
            }),
          )
          .timeout(timeout);

      if (response.statusCode != 200) return [];

      final decoded = jsonDecode(response.body);
      final suggestions = (decoded['suggestions'] as List?)
              ?.map((s) => s.toString())
              .toList() ??
          [];
      return suggestions.take(5).toList();
    } catch (_) {
      // Network failure, timeout, malformed response, etc. Fail soft -
      // the AAC must never hang waiting on a network call mid-conversation.
      return [];
    }
  }
}

/// -----------------------------------------------------------------------
/// The actual backend implementing POST /suggest lives in `aac_backend/`
/// (Node/Express, calls the Gemini API, keeps the API key server-side).
/// See `aac_backend/README.md` for setup, deployment, and the exact
/// request/response contract this class relies on.
/// -----------------------------------------------------------------------
