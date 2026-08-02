export const SYSTEM_INSTRUCTION =
  "You help a nonverbal AAC user reply in conversation. You get what " +
  "the other person just said, the user's language/tone prefs, and " +
  "recent exchanges. Give 3-5 short reply options (max ~10 words " +
  "each) the user could plausibly want to say back. Match their tone.\n\n" +
  "DYNAMIC LANGUAGE MATCHING RULES:\n" +
  "- DYNAMIC MATCHING: Respond in the SAME language the other person used. " +
  "If they talk in English, respond ONLY in English. " +
  "If they talk in Egyptian Arabic (Arabic script or Franco), respond ONLY in Egyptian Arabic.\n" +
  "- SCRIPT: ALWAYS use actual Arabic script (حروف عربية) for Egyptian Arabic. NEVER use Franco-Arabic, Arabizi, or Latin letters for Arabic words.\n" +
  "- OVERRIDES: Only output mixed 'English / Egyptian Arabic' if the incoming text is English AND the user preference explicitly forces 'mix'. Otherwise, strictly match the speaker's language.\n\n" +
  "Order from most to least likely. No explanations. " +
  "Return ONLY valid JSON with this exact key: {\"suggestions\": [\"option 1\", \"option 2\"]}";

const LANG_CODES = {
  english: 'en',
  arabicMSA: 'ar',
  egyptianArabic: 'eg',
  mixed: 'mix',
};

export function buildCompactPrompt(body) {
  const {
    other_person_text = '',
    language_preference = 'mixed',
    tone_preference = 'mixed',
    preferences = {},
    recent_history = [],
  } = body;

  const trimmedHistory = recent_history.slice(0, 2).map((h) => ({
    said: String(h.said || '').slice(0, 60),
    replied: String(h.replied || '').slice(0, 40),
  }));

  const compact = {
    msg: String(other_person_text).slice(0, 300),
    lang: LANG_CODES[language_preference] || 'mix',
    tone: tone_preference,
    prefs: preferences,
    hist: trimmedHistory,
  };

  return JSON.stringify(compact);
}
