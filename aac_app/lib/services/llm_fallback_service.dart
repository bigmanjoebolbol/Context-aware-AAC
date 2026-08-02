import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation_entry.dart';
import '../models/user_profile.dart';
import '../models/contact_entry.dart';

/// Handles the "slow path": only called when [RuleEngine.process] returns
/// handled=false, i.e. genuinely novel/open-ended sentences.
///
/// IMPORTANT (security): never ship a raw Claude API key inside a mobile
/// app binary - it can be extracted from the compiled app. [backendEndpoint]
/// should point at the small Node/Express server in `aac_backend/`, which
/// holds the key server-side and calls Claude on your behalf. See
/// `aac_backend/README.md` for setup and deployment.

class SuggestResult {
  final List<String> suggestions;
  final String? provider;
  final String? model;
  final String? error;

  SuggestResult({
    required this.suggestions,
    this.provider,
    this.model,
    this.error,
  });

  factory SuggestResult.fromJson(Map<String, dynamic> json) {
    return SuggestResult(
      suggestions: (json['suggestions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      error: json['error'] as String?,
    );
  }
}

class AiProvider {
  final String id;
  final String label;
  final String model;

  AiProvider({required this.id, required this.label, required this.model});

  factory AiProvider.fromJson(Map<String, dynamic> json) {
    return AiProvider(
      id: json['id'] as String,
      label: json['label'] as String,
      model: json['model'] as String,
    );
  }
}

class ProviderList {
  final List<AiProvider> providers;
  final String defaultId;

  ProviderList({required this.providers, required this.defaultId});
}

class LlmFallbackService {
  static const String defaultBackendUrl = 'https://your-deployed-backend.example.com/suggest';
  
  final String backendEndpoint;
  final Duration timeout;

  /// Must match APP_SHARED_SECRET on the backend, if set. Prevents random
  /// clients from calling your deployed backend and spending your Claude
  /// quota. Leave null while testing against a local server with no
  /// APP_SHARED_SECRET configured.
  final String? sharedSecret;

  LlmFallbackService({
    required this.backendEndpoint,
    this.timeout = const Duration(seconds: 10), // server times out providers at 7s, give buffer
    this.sharedSecret,
  });

  /// Fetches available AI providers from the backend.
  Future<ProviderList?> getProviders() async {
    try {
      final uri = Uri.parse(backendEndpoint).replace(path: '/providers');
      final response = await http.get(
        uri,
        headers: {
          if (sharedSecret != null) 'x-app-key': sharedSecret!,
        },
      ).timeout(timeout);

      if (response.statusCode != 200) return null;

      // FIX: Always decode response.bodyBytes as UTF-8 explicitly for Arabic support
      final decodedBody = utf8.decode(response.bodyBytes);
      final decoded = jsonDecode(decodedBody) as Map<String, dynamic>;
      
      final list = (decoded['providers'] as List)
          .map((p) => AiProvider.fromJson(p as Map<String, dynamic>))
          .toList();
      final defaultId = decoded['default'] as String? ?? 'groq';
      
      return ProviderList(providers: list, defaultId: defaultId);
    } catch (_) {
      return null;
    }
  }

  /// Requests short reply suggestions. Returns fallback suggestions if
  /// the network call fails.
  Future<SuggestResult> getSuggestions({
    required String otherPersonText,
    required UserProfile profile,
    required List<ConversationEntry> history,
    ContactEntry? currentContact,
    String? locationContext,
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
              'tone_preference': currentContact?.preferredTone ?? profile.tonePreference,
              'preferences': profile.preferences,
              'provider': profile.selectedAiProvider == 'default' ? null : profile.selectedAiProvider,
              'context': {
                if (currentContact != null) 'talking_to': {
                  'name': currentContact.name,
                  'relationship': currentContact.relationship,
                },
                if (locationContext != null) 'at_location': locationContext,
              },
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

      // FIX: Always decode response.bodyBytes as UTF-8 explicitly for Arabic support
      final decodedBody = utf8.decode(response.bodyBytes);
      final Map<String, dynamic> json = jsonDecode(decodedBody);
      final result = SuggestResult.fromJson(json);

      if (response.statusCode == 200) {
        if (result.suggestions.isEmpty) {
          // Expected "no good answer" behavior
          return result;
        }
        return result;
      }

      if (response.statusCode == 400 && result.error == "unknown_or_unconfigured_provider") {
        // Fallback to default if requested provider is unavailable on server
        return _fallback(profile.uiLanguage, modelName: 'Fallback (Provider Unavailable)');
      }

      // 401, 502, or any other error -> fail soft (Silent)
      return SuggestResult(suggestions: []);
    } catch (_) {
      // Network failure, timeout, etc. -> fail soft (Silent)
      return SuggestResult(suggestions: []);
    }
  }

  SuggestResult _fallback(String uiLanguage, {String? modelName}) {
    // Basic emergency replies were here, but we are moving to a silent approach.
    // Keeping the method for possible internal use, but it now returns empty list.
    return SuggestResult(suggestions: []);
  }
}
