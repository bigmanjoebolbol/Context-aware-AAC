import 'package:flutter_tts/flutter_tts.dart';

/// Speaks the user's chosen reply out loud, as if they were speaking
/// normally. Picks a voice locale based on whether the text looks like
/// it contains Arabic script, so mixed English/Arabic replies (common
/// in the "Whatever you're having / زي ما تحب" style suggestions) still
/// sound natural by speaking the matching half in the matching voice.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  static final RegExp _arabicScript = RegExp(r'[\u0600-\u06FF]');

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _initialized = true;
  }

  bool _looksArabic(String text) => _arabicScript.hasMatch(text);

  /// Speaks [text]. If it's a combined "English / Arabic" suggestion
  /// (the seed phrasebook stores replies this way), splits on the slash
  /// and speaks only the half matching the user's language preference,
  /// unless preference is "mixed", in which case it speaks both.
  Future<void> speak(String text, {String languagePreference = 'mixed'}) async {
    await init();

    final parts = text.contains(' / ') ? text.split(' / ') : [text];

    if (parts.length == 2 && languagePreference != 'mixed') {
      final englishPart = _looksArabic(parts[0]) ? parts[1] : parts[0];
      final arabicPart = _looksArabic(parts[0]) ? parts[0] : parts[1];

      if (languagePreference == 'english') {
        await _speakLocalized(englishPart, 'en-US');
        return;
      }
      if (languagePreference == 'arabicMSA' || languagePreference == 'egyptianArabic') {
        await _speakLocalized(arabicPart, 'ar-EG');
        return;
      }
    }

    // Mixed preference, or plain single-language text: speak each
    // detected segment with its matching voice, in order.
    for (final part in parts) {
      await _speakLocalized(part.trim(), _looksArabic(part) ? 'ar-EG' : 'en-US');
    }
  }

  Future<void> _speakLocalized(String text, String locale) async {
    if (text.isEmpty) return;
    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
