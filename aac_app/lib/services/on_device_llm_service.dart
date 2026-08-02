import 'dart:async';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'llm_fallback_service.dart';
import '../models/user_profile.dart';
import '../models/conversation_entry.dart';

class OnDeviceLlmService {
  LlamaParent? _llamaParent;
  bool _isInitialized = false;

  /// Initialize the local model in a background isolate. 
  /// Call this before suggestReplies.
  Future<void> initialize(String modelPath) async {
    if (_isInitialized) return;
    
    _llamaParent = LlamaParent(
      LlamaLoad(
        path: modelPath,
        modelParams: ModelParams()..nGpuLayers = 99, // Use GPU if available
        contextParams: ContextParams()..nCtx = 2048,
        samplingParams: SamplerParams(),
      ),
    );

    await _llamaParent!.init();
    _isInitialized = true;
  }

  /// Generate replies entirely on-device
  Future<SuggestResult> suggestReplies({
    required String otherPersonText,
    required UserProfile profile,
    required List<ConversationEntry> history,
    String? otherPersonName,
    String? sessionNotes,
  }) async {
    if (!_isInitialized || _llamaParent == null) {
      throw Exception('OnDeviceLlmService not initialized. Call initialize() first.');
    }

    final prefsStr = profile.preferences.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    // History in chronological order (oldest→newest) so the model follows conversation flow
    final chronologicalHistory = history.reversed.take(10).toList();
    final historyStr = chronologicalHistory
        .map((e) => 'Them: ${e.otherPersonText}\nMe: ${e.chosenReply ?? ""}')
        .join('\n');
    final toneStr = profile.tonePreference;
    final langStr = profile.languagePreference;
    final nameStr = profile.name;

    final systemPrompt = '''You help a nonverbal AAC user reply in a back-and-forth conversation.
User Name: $nameStr
${otherPersonName != null ? 'Talking TO: $otherPersonName (use their name naturally in some replies)' : ''}
${sessionNotes != null && sessionNotes.isNotEmpty ? 'Notes about this person: $sessionNotes' : ''}
Tone Preference: $toneStr
Language Preference: $langStr
User Preferences: $prefsStr

CONVERSATION SO FAR (oldest first, read carefully for context):
$historyStr

YOUR TASK: Give 3-5 reply options the user could plausibly want to say back.
LENGTH RULES: Adapt the length to context.
TONE RULES: Strictly enforce the requested tone.
CONTEXT RULES: If the current message is a follow-up (e.g. "What are they?" after discussing hobbies), infer from history and use the user's saved preferences to answer.
PERSONALIZATION RULES: Use the user's preferences if relevant.${otherPersonName != null ? ' Address $otherPersonName by name in some replies.' : ''}
EGYPTIAN ARABIC RULES (CRITICAL): When language preference is 'egyptianArabic' or 'mixed', ALWAYS use colloquial Egyptian Arabic (عامية مصرية), NOT formal MSA.
Use: أيوه/لأ/عايز/مش/كويس/إزيك/تمام/ماشي. Never use فصحى equivalents (نعم/لا/أريد/ليس/جيد/كيف حالك/حسناً).
SCRIPT: Always use Arabic script. Never use Franco-Arabic/Latin for Arabic words.
OUTPUT FORMAT: Format your options as a numbered list (1., 2., 3.). No other text.''';

    final formattedPrompt = '<|im_start|>system\n$systemPrompt<|im_end|>\n<|im_start|>user\n$otherPersonText<|im_end|>\n<|im_start|>assistant\n';

    // Start generating
    _llamaParent!.sendPrompt(formattedPrompt);
    
    final buffer = StringBuffer();
    await for (final token in _llamaParent!.stream) {
      buffer.write(token);
    }

    // Parse the numbered list output
    final generatedText = buffer.toString().trim();
    final suggestions = _parseNumberedList(generatedText);

    // Fallback if the model failed to follow instructions
    if (suggestions.isEmpty) {
      suggestions.add(generatedText.isNotEmpty ? generatedText : "Yes.");
      suggestions.add("No.");
      suggestions.add("I don't know.");
    }

    return SuggestResult(
      suggestions: suggestions.take(3).toList(),
      provider: 'local_on_device',
      model: 'qwen2.5-0.5b-gguf',
    );
  }

  List<String> _parseNumberedList(String text) {
    final lines = text.split('\n');
    final options = <String>[];
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty && RegExp(r'^\d+[\.\)]').hasMatch(line)) {
        // Remove the "1. " prefix
        options.add(line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim());
      }
    }
    return options;
  }

  void dispose() {
    _llamaParent?.dispose();
    _isInitialized = false;
  }
}


