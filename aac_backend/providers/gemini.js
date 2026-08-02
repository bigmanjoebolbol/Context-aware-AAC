import { fetchWithTimeout } from '../utils.js';

export const id = 'gemini';
export const label = 'Gemini';
export const envKey = 'GEMINI_API_KEY';
export const defaultModel = 'gemini-2.5-flash-lite';

export async function generate({ apiKey, model, systemInstruction, userPrompt, maxTokens, timeoutMs }) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const payload = {
    system_instruction: { parts: [{ text: systemInstruction }] },
    contents: [{ role: 'user', parts: [{ text: userPrompt }] }],
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: {
        type: 'OBJECT',
        properties: {
          suggestions: {
            type: 'ARRAY',
            items: { type: 'STRING' },
          },
        },
        required: ['suggestions'],
      },
      maxOutputTokens: maxTokens,
      temperature: 0.4,
    },
  };

  const res = await fetchWithTimeout(
    url,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    },
    timeoutMs,
  );

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API error ${res.status}: ${errText}`);
  }

  const data = await res.json();
  const rawText = data?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!rawText) return [];

  const parsed = JSON.parse(rawText);
  return Array.isArray(parsed.suggestions) ? parsed.suggestions : [];
}
