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
        'reply_eat_1': 1,
        'reply_eat_2': 1,
        'reply_eat_3': 1,
      },
      injectPreference: true,
      preferenceKey: 'protein',
      replyTranslations: {
        'reply_eat_1': {
          'english': 'Whatever you\'re having',
          'msa': 'كما تريد', // TODO: verify MSA
          'egyptian': 'زي ما تحب',
        },
        'reply_eat_2': {
          'english': 'Something light',
          'msa': 'شيء خفيف',
          'egyptian': 'حاجة خفيفة',
        },
        'reply_eat_3': {
          'english': 'I\'m not hungry right now',
          'msa': 'لست جائعاً الآن',
          'egyptian': 'مش جعان دلوقتي',
        },
      },
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
        'reply_drink_1': 1,
        'reply_drink_2': 1,
      },
      injectPreference: true,
      preferenceKey: 'drink',
      replyTranslations: {
        'reply_drink_1': {
          'english': 'Water please',
          'msa': 'ماء من فضلك',
          'egyptian': 'مية لو سمحت',
        },
        'reply_drink_2': {
          'english': 'Whatever you\'re having',
          'msa': 'كما تريد',
          'egyptian': 'زي ما تحب',
        },
      },
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
        'reply_how_1': 3,
        'reply_how_2': 1,
        'reply_how_3': 1,
      },
      replyTranslations: {
        'reply_how_1': {
          'english': 'I\'m good, thanks',
          'msa': 'أنا بخير، شكراً',
          'egyptian': 'كويس الحمد لله',
        },
        'reply_how_2': {
          'english': 'A bit tired today',
          'msa': 'متعب قليلاً اليوم',
          'egyptian': 'تعبان شوية النهاردة',
        },
        'reply_how_3': {
          'english': 'Not great',
          'msa': 'ليس جيداً',
          'egyptian': 'مش تمام أوي',
        },
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
        'reply_ready_1': 2,
        'reply_ready_2': 1,
        'reply_ready_3': 1,
      },
      replyTranslations: {
        'reply_ready_1': {
          'english': 'Yes, ready',
          'msa': 'نعم، جاهز',
          'egyptian': 'أيوة جاهز',
        },
        'reply_ready_2': {
          'english': 'Give me a few minutes',
          'msa': 'أعطني بضع دقائق',
          'egyptian': 'اديني دقيقة',
        },
        'reply_ready_3': {
          'english': 'Not yet',
          'msa': 'ليس بعد',
          'egyptian': 'لسه لأ',
        },
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
        'reply_time_1': 1,
        'reply_time_2': 1,
        'reply_time_3': 1,
      },
      replyTranslations: {
        'reply_time_1': {
          'english': 'Whenever suits you',
          'msa': 'في أي وقت يناسبك',
          'egyptian': 'اي وقت يناسبك',
        },
        'reply_time_2': {
          'english': 'Morning is better',
          'msa': 'الصباح أفضل',
          'egyptian': 'الصبح أحسن',
        },
        'reply_time_3': {
          'english': 'Evening is better',
          'msa': 'المساء أفضل',
          'egyptian': 'بالليل أحسن',
        },
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
        'reply_help_1': 2,
        'reply_help_2': 1,
      },
      replyTranslations: {
        'reply_help_1': {
          'english': 'No, I\'m okay',
          'msa': 'لا، أنا بخير',
          'egyptian': 'لأ أنا تمام',
        },
        'reply_help_2': {
          'english': 'Yes please',
          'msa': 'نعم من فضلك',
          'egyptian': 'أيوة لو سمحت',
        },
      },
    ),
    PhraseEntry(
      triggerKey: 'greetings_general',
      variants: [
        'hello',
        'hi',
        'hey',
        'أهلا',
        'اهلاً',
        'مرحبا',
        'سلام عليكم',
        'السلام عليكم',
        'أهلاً وسهلاً',
      ],
      replyScores: {
        'reply_greeting_1': 3,
        'reply_greeting_2': 2,
        'reply_greeting_3': 2,
      },
      pinned: true,
      replyTranslations: {
        'reply_greeting_1': {
          'english': 'Hello!',
          'msa': 'مرحباً!',
          'egyptian': 'أهلاً وسهلاً',
        },
        'reply_greeting_2': {
          'english': 'Hi there!',
          'msa': 'أهلاً بك',
          'egyptian': 'أهلاً بك',
        },
        'reply_greeting_3': {
          'english': 'Peace be upon you',
          'msa': 'وعليكم السلام',
          'egyptian': 'وعليكم السلام',
        },
      },
    ),
    PhraseEntry(
      triggerKey: 'good_morning',
      variants: [
        'good morning',
        'morning',
        'صباح الخير',
        'صباح النور',
        'صباح الفل',
      ],
      replyScores: {
        'reply_morning_1': 3,
        'reply_morning_2': 2,
      },
      pinned: true,
      replyTranslations: {
        'reply_morning_1': {
          'english': 'Good morning!',
          'msa': 'صباح الخير!',
          'egyptian': 'صباح النور',
        },
        'reply_morning_2': {
          'english': 'Morning!',
          'msa': 'صباح الفل',
          'egyptian': 'صباح الفل',
        },
      },
    ),
    PhraseEntry(
      triggerKey: 'good_evening',
      variants: [
        'good evening',
        'evening',
        'مساء الخير',
        'مساء النور',
        'مساء الفل',
      ],
      replyScores: {
        'reply_evening_1': 3,
        'reply_evening_2': 2,
      },
      pinned: true,
      replyTranslations: {
        'reply_evening_1': {
          'english': 'Good evening!',
          'msa': 'مساء الخير!',
          'egyptian': 'مساء النور',
        },
        'reply_evening_2': {
          'english': 'Evening!',
          'msa': 'مساء الفل',
          'egyptian': 'مساء الفل',
        },
      },
    ),
    PhraseEntry(
      triggerKey: 'thank_you',
      variants: [
        'thank you',
        'thanks',
        'شكرا',
        'شكراً',
        'تسلم',
        'شكرا جزيلا',
      ],
      replyScores: {
        'reply_thanks_1': 3,
        'reply_thanks_2': 2,
      },
      pinned: true,
      replyTranslations: {
        'reply_thanks_1': {
          'english': 'You\'re welcome!',
          'msa': 'العفو!',
          'egyptian': 'العفو',
        },
        'reply_thanks_2': {
          'english': 'Anytime!',
          'msa': 'في أي وقت!',
          'egyptian': 'حبيبي تسلم',
        },
      },
    ),
  ];
}