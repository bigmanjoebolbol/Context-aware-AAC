import 'package:flutter_tts/flutter_tts.dart';
import '../models/phrase_entry.dart';

/// Speaks the user's chosen reply out loud. Supports language‑specific
/// translations stored in [PhraseEntry.replyTranslations].
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

  // ----------------------------------------------------------------------
  // New: speak a reply from a PhraseEntry using its translations.
  // ----------------------------------------------------------------------
  Future<void> speakTranslated(
    PhraseEntry entry,
    String replyKey, {
    String languagePreference = 'mixed',
    String ttsGender = 'female',
  }) async {
    await init();

    final translations = entry.replyTranslations[replyKey];
    if (translations == null || translations.isEmpty) {
      // Fallback: speak the key itself (or we could use the English key)
      await speak(replyKey, languagePreference: languagePreference, ttsGender: ttsGender);
      return;
    }

    final english = translations['english'] ?? '';
    final msa = translations['msa'] ?? '';
    final egyptian = translations['egyptian'] ?? '';

    // Decide which segment(s) to speak based on languagePreference.
    switch (languagePreference) {
      case 'english':
        if (english.isNotEmpty) {
          await _speakLocalized(english, 'en-US', ttsGender);
        } else {
          // Fallback to any Arabic if English missing.
          final fallback = msa.isNotEmpty ? msa : egyptian;
          if (fallback.isNotEmpty) await _speakLocalized(fallback, 'ar-EG', ttsGender);
        }
        break;

      case 'arabicMSA':
        if (msa.isNotEmpty) {
          await _speakLocalized(msa, 'ar-EG', ttsGender);
        } else {
          // Fallback to Egyptian if MSA missing.
          final fallback = egyptian.isNotEmpty ? egyptian : english;
          if (fallback.isNotEmpty) {
            await _speakLocalized(fallback, _looksArabic(fallback) ? 'ar-EG' : 'en-US', ttsGender);
          }
        }
        break;

      case 'egyptianArabic':
        if (egyptian.isNotEmpty) {
          await _speakLocalized(egyptian, 'ar-EG', ttsGender);
        } else {
          // Fallback to MSA or English.
          final fallback = msa.isNotEmpty ? msa : english;
          if (fallback.isNotEmpty) {
            await _speakLocalized(fallback, _looksArabic(fallback) ? 'ar-EG' : 'en-US', ttsGender);
          }
        }
        break;

      case 'mixed':
      default:
        // Speak both English and Egyptian (colloquial) – matches old behavior.
        if (english.isNotEmpty) {
          await _speakLocalized(english, 'en-US', ttsGender);
        }
        if (egyptian.isNotEmpty) {
          await _speakLocalized(egyptian, 'ar-EG', ttsGender);
        } else if (msa.isNotEmpty) {
          // If Egyptian missing, fallback to MSA.
          await _speakLocalized(msa, 'ar-EG', ttsGender);
        }
        break;
    }
  }

  // ----------------------------------------------------------------------
  // Legacy speak method – kept for custom/LLM replies that have no PhraseEntry.
  // ----------------------------------------------------------------------
  Future<void> speak(String text, {String languagePreference = 'mixed', String ttsGender = 'female'}) async {
    await init();

    final parts = text.contains(' / ') ? text.split(' / ') : [text];

    if (parts.length == 2 && languagePreference != 'mixed') {
      final englishPart = _looksArabic(parts[0]) ? parts[1] : parts[0];
      final arabicPart = _looksArabic(parts[0]) ? parts[0] : parts[1];

      if (languagePreference == 'english') {
        await _speakLocalized(englishPart, 'en-US', ttsGender);
        return;
      }
      if (languagePreference == 'arabicMSA' || languagePreference == 'egyptianArabic') {
        await _speakLocalized(arabicPart, 'ar-EG', ttsGender);
        return;
      }
    }

    // Mixed preference, or plain single‑language text: speak each detected segment.
    for (final part in parts) {
      await _speakLocalized(part.trim(), _looksArabic(part) ? 'ar-EG' : 'en-US', ttsGender);
    }
  }

  // ----------------------------------------------------------------------
  // Low‑level TTS with voice selection.
  // ----------------------------------------------------------------------
  Future<void> _speakLocalized(String text, String locale, String gender) async {
    if (text.isEmpty) return;
    await _tts.setLanguage(locale);

    // Known male/female voice identifiers.
    final List<String> knownMaleIds = ['-iom-', '-tpd-', '-rjs-', '-zgh-', '-c-', '-b-', 'male', 'samed'];
    final List<String> knownFemaleIds = ['-sfg-', '-tpf-', '-rba-', '-a-', '-d-', 'female'];

    bool foundVoice = false;
    try {
      final voices = await _tts.getVoices;
      if (voices != null && voices is List) {
        final targetVoices = voices.where((v) {
          if (v is Map) {
            final loc = v['locale']?.toString() ?? '';
            final name = v['name']?.toString().toLowerCase() ?? '';
            if (!loc.startsWith(locale.split('-').first)) return false;
            if (gender == 'male') {
              return knownMaleIds.any((id) => name.contains(id)) && !name.contains('female');
            } else {
              return knownFemaleIds.any((id) => name.contains(id)) && !name.contains('male');
            }
          }
          return false;
        }).toList();

        if (targetVoices.isNotEmpty) {
          targetVoices.sort((a, b) {
            final aNet = (a['name']?.toString() ?? '').contains('network');
            final bNet = (b['name']?.toString() ?? '').contains('network');
            if (aNet && !bNet) return -1;
            if (!aNet && bNet) return 1;
            return 0;
          });
          await _tts.setVoice({"name": targetVoices.first["name"], "locale": targetVoices.first["locale"]});
          foundVoice = true;
        }
      }
    } catch (_) {
      // Ignore voice fetching errors.
    }

    await _tts.setPitch(1.0);
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}