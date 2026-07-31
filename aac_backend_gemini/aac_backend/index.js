import express from 'express';
import cors from 'cors';

const app = express();
app.use(cors());
app.use(express.json({ limit: '20kb' }));

const GROQ_API_KEY = process.env.GROQ_API_KEY;
const GROQ_MODEL = process.env.GROQ_MODEL || 'llama-3.3-70b-versatile';
const APP_SHARED_SECRET = process.env.APP_SHARED_SECRET;

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

const SYSTEM_INSTRUCTION =
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

function buildCompactPrompt(body) {
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

app.post('/suggest', async (req, res) => {
  if (APP_SHARED_SECRET) {
    const provided = req.get('x-app-key');
    if (provided !== APP_SHARED_SECRET) {
      return res.status(401).json({ suggestions: [] });
    }
  }

  if (!GROQ_API_KEY) {
    console.error('GROQ_API_KEY is not set');
    return res.status(500).json({ suggestions: [] });
  }

  const otherPersonText = (req.body?.other_person_text || '').trim();
  if (!otherPersonText) {
    return res.status(400).json({ suggestions: [] });
  }

  const promptText = buildCompactPrompt(req.body);

  const payload = {
    model: GROQ_MODEL,
    messages: [
      { role: 'system', content: SYSTEM_INSTRUCTION },
      { role: 'user', content: promptText },
    ],
    response_format: { type: 'json_object' },
    max_tokens: 150,
    temperature: 0.4,
  };

  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 7000);

    const groqResponse = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!groqResponse.ok) {
      const errText = await groqResponse.text();
      console.error('Groq API error:', groqResponse.status, errText);
      return res.status(502).json({ suggestions: [] });
    }

    const data = await groqResponse.json();
    const rawText = data?.choices?.[0]?.message?.content;
    if (!rawText) {
      return res.status(200).json({ suggestions: [] });
    }

    let parsed;
    try {
      parsed = JSON.parse(rawText);
    } catch {
      return res.status(200).json({ suggestions: [] });
    }

    const suggestions = Array.isArray(parsed.suggestions)
      ? parsed.suggestions.slice(0, 5)
      : [];

    return res.status(200).json({ suggestions });
  } catch (err) {
    console.error('Suggest handler failed:', err.message);
    return res.status(500).json({ suggestions: [] });
  }
});

app.get('/health', (_req, res) => res.status(200).send('ok'));

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  console.log(`AAC suggestion backend (Groq) listening on port ${PORT}`);
});