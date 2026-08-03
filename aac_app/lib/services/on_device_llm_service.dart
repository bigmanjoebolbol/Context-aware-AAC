import 'dart:async';
import 'package:fllama/fllama.dart';
import 'llm_fallback_service.dart';
import '../models/user_profile.dart';
import '../models/conversation_entry.dart';

class OnDeviceLlmService {
  bool _isInitialized = false;
  double? _contextId;
  bool _isBusy = false;

  /// Initialize the local model using fllama in a native background thread.
  Future<void> initialize(String modelPath) async {
    if (_isInitialized && _contextId != null) return;
    
    // Fallback to nGpuLayers = 0 for highest compatibility on Android
    final res = await Fllama.instance()?.initContext(
      modelPath,
      nCtx: 2048,
      nGpuLayers: 0,
    );
    
    if (res != null && res["contextId"] != null) {
      _contextId = (res["contextId"] as num).toDouble();
      _isInitialized = true;
    } else {
      throw Exception('fllama failed to initialize context or load model.');
    }
  }

  /// Generate replies entirely on-device
  Future<SuggestResult> suggestReplies({
    required String otherPersonText,
    required UserProfile profile,
    required List<ConversationEntry> history,
    String? otherPersonName,
    String? sessionNotes,
  }) async {
    if (!_isInitialized || _contextId == null) {
      throw Exception('OnDeviceLlmService not initialized. Call initialize() first.');
    }

    if (_isBusy) {
      await Fllama.instance()?.stopCompletion(contextId: _contextId!);
      // Wait slightly for native side to clean up
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _isBusy = true;

    final prefsStr = profile.preferences.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    // History in chronological order (oldest→newest) so the model follows conversation flow
    final chronologicalHistory = history.reversed.take(10).toList();
    final historyStr = chronologicalHistory
        .map((e) => 'Them: ${e.otherPersonText}\nMe: ${e.chosenReply ?? ""}')
        .join('\n');
    final toneStr = profile.tonePreference;
    final langStr = profile.languagePreference;
    final nameStr = profile.name;

    final systemPrompt = '''You are an AAC communication assistant for $nameStr.
Language: $langStr
Tone: $toneStr
${otherPersonName != null ? 'Talking to: $otherPersonName' : ''}

Recent Conversation:
$historyStr

Suggest 3 short, natural replies for YOU ($nameStr) to say next to them. DO NOT continue the conversation as the other person.
CRITICAL: You must output ONLY a numbered list, one reply per line (e.g. 1. Hello\n2. Yes). Do not include any other text, explanations, or chat.''';

    final formattedPrompt = '<|im_start|>system\n$systemPrompt<|im_end|>\n<|im_start|>user\n$otherPersonText<|im_end|>\n<|im_start|>assistant\n';

    try {
      // Start completion inference
      final res = await Fllama.instance()?.completion(
        _contextId!,
        prompt: formattedPrompt,
        emitRealtimeCompletion: false,
        stop: ['<|im_end|>', '<|im_start|>', 'user\n'],
        nPredict: 150,
      );

      final generatedText = res?["text"] as String? ?? "";

      List<String> suggestions = _parseNumberedList(generatedText);
      if (suggestions.isEmpty) {
        suggestions.add(generatedText.trim().isNotEmpty ? generatedText.trim() : "Yes.");
        suggestions.add("No.");
        suggestions.add("I don't know.");
      }

      return SuggestResult(
        suggestions: suggestions.take(5).toList(),
        provider: 'local_on_device',
        model: 'qwen2.5-1.5b-gguf',
      );
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('Context is busy') || errStr.contains('cancel')) {
        // Suppress expected cancellation errors
        return SuggestResult(
          suggestions: ["Thinking..."],
          provider: 'local_on_device',
          model: 'qwen2.5-1.5b-gguf',
        );
      }
      rethrow;
    } finally {
      _isBusy = false;
    }
  }

  List<String> _parseNumberedList(String text) {
    final options = <String>[];
    final lines = text.split('\n');
    
    for (var line in lines) {
      line = line.trim();
      if (line.isNotEmpty && RegExp(r'^\d+[\.\)]').hasMatch(line)) {
        options.add(line.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '').trim());
      }
    }

    if (options.isEmpty) {
      final matches = RegExp(r'\d+[\.\)]\s*([^\d]+)').allMatches(text);
      for (final match in matches) {
        final opt = match.group(1)?.trim();
        if (opt != null && opt.isNotEmpty) {
          options.add(opt);
        }
      }
    }
    
    return options;
  }

  void dispose() {
    if (_contextId != null) {
      Fllama.instance()?.releaseContext(_contextId!);
      _contextId = null;
    }
    _isInitialized = false;
  }
}
