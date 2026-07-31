import '../models/phrase_entry.dart';

/// Seed data loaded once on first app launch. This is the starting
/// "phrasebook" the rule engine matches against before ever touching an
/// LLM. Egyptian Arabic variants are included alongside MSA and English
/// since day-to-day speech will most often be Egyptian colloquial.
List<PhraseEntry> defaultPhrasebook() {
  return [
    PhraseEntry(
      triggerKey: 'what_eat',
      variants: [
        'what do you want to eat',
        'what would you like to eat',
        'عايز تاكل ايه',
        'عاوز تاكل ايه',
        'ماذا تريد أن تأكل',
        'تحب تاكل ايه',
      ],
      replyScores: {
        'Whatever you\'re having / زي ما تحب': 1,
        'Something light / حاجة خفيفة': 1,
        'I\'m not hungry right now / مش جعان دلوقتي': 1,
      },
      injectPreference: true,
      preferenceKey: 'protein',
    ),
    PhraseEntry(
      triggerKey: 'what_drink',
      variants: [
        'what do you want to drink',
        'what would you like to drink',
        'عايز تشرب ايه',
        'تحب تشرب ايه',
        'ماذا تريد أن تشرب',
      ],
      replyScores: {
        'Water please / مية لو سمحت': 1,
        'Whatever you\'re having / زي ما تحب': 1,
      },
      injectPreference: true,
      preferenceKey: 'drink',
    ),
    PhraseEntry(
      triggerKey: 'how_are_you',
      variants: [
        'how are you',
        'how are you doing',
        'ازيك',
        'عامل ايه',
        'كيف حالك',
      ],
      replyScores: {
        'I\'m good, thanks / كويس الحمد لله': 3,
        'A bit tired today / تعبان شوية النهاردة': 1,
        'Not great / مش تمام أوي': 1,
      },
    ),
    PhraseEntry(
      triggerKey: 'ready_to_go',
      variants: [
        'are you ready',
        'ready to go',
        'جاهز',
        'مستعد',
        'خلصت',
      ],
      replyScores: {
        'Yes, ready / أيوة جاهز': 2,
        'Give me a few minutes / اديني دقيقة': 1,
        'Not yet / لسه لأ': 1,
      },
    ),
    PhraseEntry(
      triggerKey: 'what_time',
      variants: [
        'what time',
        'what time works',
        'امتى',
        'الساعة كام',
      ],
      replyScores: {
        'Whenever suits you / اي وقت يناسبك': 1,
        'Morning is better / الصبح أحسن': 1,
        'Evening is better / بالليل أحسن': 1,
      },
    ),
    PhraseEntry(
      triggerKey: 'need_help',
      variants: [
        'do you need help',
        'need anything',
        'محتاج حاجة',
        'عايز مساعدة',
      ],
      replyScores: {
        'No, I\'m okay / لأ أنا تمام': 2,
        'Yes please / أيوة لو سمحت': 1,
      },
    ),
    PhraseEntry(
      triggerKey: 'pain_check',
      variants: [
        'are you in pain',
        'does it hurt',
        'وجعك',
        'بيوجعك',
      ],
      replyScores: {
        'No / لأ': 2,
        'A little / شوية': 1,
        'Yes, quite a bit / أيوة كتير': 1,
      },
    ),
  ];
}
