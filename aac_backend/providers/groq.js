import { fetchWithTimeout } from '../utils.js';

export const id = 'groq';
export const label = 'Groq (Llama)';
export const envKey = 'GROQ_API_KEY';
export const defaultModel = 'llama-3.3-70b-versatile';

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';

export async function generate({ apiKey, model, systemInstruction, userPrompt, maxTokens, timeoutMs }) {
  const payload = {
    model,
    messages: [
      { role: 'system', content: systemInstruction },
      { role: 'user', content: userPrompt },
    ],
    response_format: { type: 'json_object' },
    max_tokens: maxTokens,
    temperature: 0.4,
  };

  const res = await fetchWithTimeout(
    GROQ_URL,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(payload),
    },
    timeoutMs,
  );

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Groq API error ${res.status}: ${errText}`);
  }

  const data = await res.json();
  const rawText = data?.choices?.[0]?.message?.content;
  if (!rawText) return [];

  const parsed = JSON.parse(rawText);
  return Array.isArray(parsed.suggestions) ? parsed.suggestions : [];
}
