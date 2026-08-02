import { fetchWithTimeout } from '../utils.js';

export const id = 'ollama';
export const label = 'Local LLM (Ollama)';

// The env var that must be set for this provider to show up.
// We reuse the model var as both the sentinel and the model name
// so no separate API key is needed for a local service.
export const envKey = 'OLLAMA_MODEL';
export const defaultModel = 'qwen2.5:1.5b';

// Ollama exposes an OpenAI-compatible endpoint on localhost by default.
const OLLAMA_BASE = process.env.OLLAMA_BASE_URL || 'http://localhost:11434';
const OLLAMA_URL = `${OLLAMA_BASE}/v1/chat/completions`;

export async function generate({ model, systemInstruction, userPrompt, maxTokens, timeoutMs }) {
  // Ollama doesn't need an API key — it's a local service.
  const payload = {
    model,
    messages: [
      { role: 'system', content: systemInstruction },
      { role: 'user', content: userPrompt },
    ],
    // Ask for JSON output if the model supports it; falls back gracefully
    response_format: { type: 'json_object' },
    max_tokens: maxTokens,
    temperature: 0.4,
    stream: false,
  };

  const res = await fetchWithTimeout(
    OLLAMA_URL,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    },
    timeoutMs,
  );

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Ollama error ${res.status}: ${errText}`);
  }

  const data = await res.json();
  const rawText = data?.choices?.[0]?.message?.content;
  if (!rawText) return [];

  // Some small models wrap their answer in markdown fences — strip them.
  const cleaned = rawText.replace(/```(?:json)?/gi, '').replace(/```/g, '').trim();

  try {
    const parsed = JSON.parse(cleaned);
    return Array.isArray(parsed.suggestions) ? parsed.suggestions : [];
  } catch {
    // If the model didn't produce valid JSON, extract quoted strings as fallback.
    const matches = cleaned.match(/"([^"]{3,80})"/g);
    if (matches && matches.length > 0) {
      return matches.slice(0, 5).map((m) => m.replace(/"/g, ''));
    }
    return [];
  }
}
