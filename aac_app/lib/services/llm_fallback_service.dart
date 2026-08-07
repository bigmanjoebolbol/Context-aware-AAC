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

  /// True when the backend fell back to a different provider than requested
  /// (e.g. user chose Ollama but it wasn't running, so Gemini was used).
  final bool usedFallback;

  SuggestResult({
    required this.suggestions,
    this.provider,
    this.model,
    this.error,
    this.usedFallback = false,
  });

  factory SuggestResult.fromJson(Map<String, dynamic> json) {
    return SuggestResult(
      suggestions: (json['suggestions'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      error: json['error'] as String?,
      usedFallback: json['used_fallback'] as bool? ?? false,
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
  static const String _groqApiKey =
      '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';
  static const String _groqModel = 'llama-3.3-70b-versatile';

  final Duration timeout;

  LlmFallbackService({
    this.timeout = const Duration(seconds: 15),
  });

  /// Hardcode provider since we removed the backend
  Future<ProviderList?> getProviders() async {
    return ProviderList(
      providers: [
        AiProvider(id: 'groq', label: 'Cloud AI (Groq)', model: _groqModel),
      ],
      defaultId: 'groq',
    );
  }

  String _buildSystemInstruction() {
    return "You help a nonverbal AAC user reply in a back-and-forth conversation. You receive what "
        "the other person just said, the user's name, the other person's name and notes (if known), their language/tone preferences, their saved facts/preferences, and "
        "the full recent conversation history in chronological order.\n\n"
        "IMPORTANT: The user message will contain a 'personalization' field at the very start. "
        "This field is a plain sentence summarizing the user's name and their most relevant preferences. "
        "READ THIS FIELD FIRST and use it to tailor every reply appropriately.\n\n"
        "YOUR TASK: Give 3-5 reply options the user could plausibly want to say back.\n"
        "LENGTH RULES: Adapt the length of your replies to the context. If it's a simple greeting, keep it short. If they ask a complex question, provide a detailed, natural-sounding sentence or two. Do not limit yourself to 10 words if the context demands more.\n\n"
        "TONE RULES: You MUST strictly enforce the requested tone.\n"
        "- If 'casual', use slang, relaxed phrasing, and friendly terms.\n"
        "- If 'formal', use highly polite language, sir/madam, and respectful phrasing.\n\n"
        "PERSONALIZATION RULES:\n"
        "- Use the user's name and preferences (like their favorite foods, hobbies, allergies, or learned facts) if they are relevant to the conversation.\n"
        "- If 'other_person_name' is provided, address the other person by that name naturally in some replies (e.g. 'Thanks Youssef!', 'Of course, Youssef.').\n"
        "- If 'session_notes' is provided, use those notes as additional context about the other person (e.g. if notes say 'my cardiologist', frame replies appropriately for a doctor visit).\n\n"
        "CONVERSATION CONTEXT RULES (CRITICAL):\n"
        "- The 'hist' field contains the FULL conversation so far in order (oldest first, newest last).\n"
        "- READ IT CAREFULLY. If the other person is following up on something earlier (e.g. first asked 'Do you have hobbies?' and user said 'Yes', then now asks 'What are they?'), "
        "you MUST infer that 'they' refers to the hobbies and generate responses about the user's hobbies from their preferences.\n"
        "- Always use the full conversation thread to understand what the current question is REALLY asking about.\n\n"
        "EGYPTIAN ARABIC RULES (CRITICAL — read carefully):\n"
        "- DEFAULT: When the user preference is 'egyptianArabic' or 'mixed', ALWAYS write in Egyptian Arabic (عامية مصرية), even if the incoming message is in Modern Standard Arabic (MSA/فصحى) or English.\n"
        "- DIALECT: Use real colloquial Egyptian expressions, NOT formal/MSA Arabic. Examples:\n"
        "  • Say 'إيه رأيك؟' not 'ما رأيك؟'\n"
        "  • Say 'عايز' not 'أريد'\n"
        "  • Say 'مش' not 'لست' or 'ليس'\n"
        "  • Say 'كويس' not 'جيد'\n"
        "  • Say 'إزيك؟' not 'كيف حالك؟'\n"
        "  • Say 'تمام' not 'حسناً'\n"
        "  • Say 'ماشي' not 'حسناً' for 'okay'\n"
        "  • Say 'أيوه' not 'نعم'\n"
        "  • Say 'لأ' not 'لا'\n"
        "- SCRIPT: ALWAYS use Arabic script (حروف عربية). NEVER use Franco-Arabic, Arabizi, or Latin letters for Arabic.\n"
        "- PURE ENGLISH MODE: Only switch to English if the language preference is explicitly 'english'.\n"
        "- MIXED MODE: If preference is 'mixed', blend Egyptian Arabic with English naturally (e.g. 'ماشي, sounds good!').\n\n"
        "Order suggestions from most to least likely. No explanations. "
        "You MUST return valid JSON in this exact format: {\"suggestions\": [\"option 1\", \"option 2\"]}";
  }

  String _buildCompactPrompt(
      String otherPersonText,
      String languagePreference,
      String tonePreference,
      Map<String, String> preferences,
      List<ConversationEntry> history,
      String userName,
      {String? otherPersonName, String? sessionNotes}) {
    final langCodes = {
      'english': 'en',
      'arabicMSA': 'ar',
      'egyptianArabic': 'eg',
      'mixed': 'mix',
    };

    // Build a plain‑language personalization sentence.
    final prefStrings = <String>[];
    // Include only non‑empty preferences
    preferences.forEach((key, value) {
      if (value.trim().isNotEmpty) {
        // Convert camelCase or underscore keys to readable labels.
        final label = key
            .replaceAll('_', ' ')
            .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
        prefStrings.add('$label: $value');
      }
    });
    final prefSummary = prefStrings.isEmpty
        ? 'no specific preferences saved'
        : prefStrings.join('; ');

    final personalization = 'You are helping $userName. $userName\'s preferences: $prefSummary.';

    // History in chronological order (oldest first) so the AI reads conversation flow correctly.
    // This is critical for understanding follow-up questions ("What are they?" after "Do you have hobbies?").
    final chronologicalHistory = history.reversed.toList();
    final trimmedHistory = chronologicalHistory
        .take(10)
        .map((h) => {
              'them': h.otherPersonText.length > 200
                  ? h.otherPersonText.substring(0, 200)
                  : h.otherPersonText,
              'me': h.chosenReply != null && h.chosenReply!.length > 200
                  ? h.chosenReply!.substring(0, 200)
                  : (h.chosenReply ?? ''),
            })
        .toList();

    // Build the JSON payload with 'personalization' as the first field.
    final compact = {
      'personalization': personalization, // placed first
      'user_name': userName,
      'msg': otherPersonText.length > 500
          ? otherPersonText.substring(0, 500)
          : otherPersonText,
      'lang': langCodes[languagePreference] ?? 'mix',
      'tone': tonePreference,
      'prefs': preferences,
      // Full conversation thread — AI MUST read this to understand context
      'hist': trimmedHistory,
      if (otherPersonName != null) 'other_person_name': otherPersonName,
      if (sessionNotes != null && sessionNotes.isNotEmpty)
        'session_notes': sessionNotes,
    };

    return jsonEncode(compact);
  }

  /// Requests short reply suggestions directly from Groq.
  Future<SuggestResult> getSuggestions({
    required String otherPersonText,
    required UserProfile profile,
    required List<ConversationEntry> history,
    ContactEntry? currentContact,
    String? locationContext,
    String? otherPersonName,
    String? sessionNotes,
  }) async {
    try {
      final userPrompt = _buildCompactPrompt(
        otherPersonText,
        profile.languagePreference,
        currentContact?.preferredTone ?? profile.tonePreference,
        profile.preferences,
        history,
        profile.name,
        otherPersonName: otherPersonName,
        sessionNotes: sessionNotes,
      );

      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      final payload = {
        "model": _groqModel,
        "messages": [
          {"role": "system", "content": _buildSystemInstruction()},
          {"role": "user", "content": userPrompt}
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.4,
        "max_tokens": 1024
      };

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_groqApiKey'
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        String errorMsg = 'Groq API Error: ${response.statusCode}';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded['error']?['message'] != null) {
            errorMsg = decoded['error']['message'];
          }
        } catch (_) {}
        return SuggestResult(suggestions: [], error: errorMsg);
      }

      final decodedBody = utf8.decode(response.bodyBytes);
      final decoded = jsonDecode(decodedBody);

      String rawText = decoded['choices']?[0]?['message']?['content'] ?? '';
      if (rawText.isEmpty) {
        return SuggestResult(
            suggestions: [], error: 'Empty response: $decodedBody');
      }

      rawText = rawText.trim();
      final startIndex = rawText.indexOf('{');
      final endIndex = rawText.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
        rawText = rawText.substring(startIndex, endIndex + 1);
      } else {
        return SuggestResult(
            suggestions: [], error: 'Invalid JSON from Groq: $rawText');
      }

      try {
        final parsed = jsonDecode(rawText);
        final suggestions = (parsed['suggestions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        return SuggestResult(
          suggestions: suggestions,
          provider: 'groq',
          model: _groqModel,
        );
      } catch (e) {
        return SuggestResult(
            suggestions: [], error: 'JSON Parse Error: $e\nData: $rawText');
      }
    } catch (e) {
      return SuggestResult(suggestions: [], error: e.toString());
    }
  }
}