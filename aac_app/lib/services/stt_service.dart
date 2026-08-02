import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Listens to the other party via the microphone and streams back
/// transcribed text. Locale defaults to Egyptian Arabic first since
/// that's this app's primary focus, with English as the other
/// commonly-needed option; the on-device speech recognizer picks
/// whichever locale is passed in per listen session.
class SttService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  void Function(String error)? _errorCallback;

  Future<bool> init({void Function(String error)? onError}) async {
    _errorCallback = onError;
    _available = await _speech.initialize(
      onError: (e) {
        _errorCallback?.call(e.errorMsg);
      },
    );
    return _available;
  }

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  /// Starts a single listen session. [localeId] should be 'ar-EG' or
  /// 'en-US' (device-dependent availability - some Android builds only
  /// ship 'ar-SA' for Arabic; the app should let the user pick whichever
  /// is actually installed in Settings).
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String error) onError,
    void Function(double level)? onSoundLevelChange,
    String localeId = 'ar-EG',
  }) async {
    _errorCallback = onError;
    if (!_available) {
      final ok = await init(onError: onError);
      if (!ok) {
        onError('Speech recognition not available on this device.');
        return;
      }
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevelChange,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 30),
      listenMode: stt.ListenMode.dictation,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        localeId: localeId,
        onDevice: true,
      ),
    );
  }

  Future<void> stopListening() => _speech.stop();

  /// Normalizes raw decibel levels (typically -2 to 10+) to a [0, 1] range
  /// for UI components like volume bars or waveforms.
  static double normalizeLevel(double level) {
    return ((level + 2) / 12.0).clamp(0.0, 1.0);
  }
}
