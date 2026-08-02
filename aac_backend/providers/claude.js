import { fetchWithTimeout } from '../utils.js';

export const id = 'claude';
export const label = 'Claude';
export const envKey = 'CLAUDE_API_KEY';
export const defaultModel = 'claude-haiku-4-5-20251001';

const CLAUDE_URL = 'https://api.anthropic.com/v1/messages';
const CLAUDE_VERSION = '2023-06-01';

export async function generate({ apiKey, model, systemInstruction, userPrompt, maxTokens, timeoutMs }) {
  const payload = {
    model,
    max_tokens: maxTokens,
    system: systemInstruction,
    messages: [{ role: 'user', content: userPrompt }],
    // Forcing a tool call gets guaranteed structured JSON instead of
    // trusting the model to emit valid JSON in free text.
    tools: [
      {
        name: 'return_suggestions',
        description: 'Return the reply suggestions for the AAC user.',
        input_schema: {
          type: 'object',
          properties: {
            suggestions: {
              type: 'array',
              items: { type: 'string' },
              minItems: 1,
              maxItems: 5,
            },
          },
          required: ['suggestions'],
        },
      },
    ],
    tool_choice: { type: 'tool', name: 'return_suggestions' },
  };

  const res = await fetchWithTimeout(
    CLAUDE_URL,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': CLAUDE_VERSION,
      },
      body: JSON.stringify(payload),
    },
    timeoutMs,
  );

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Claude API error ${res.status}: ${errText}`);
  }

  const data = await res.json();
  const toolBlock = data?.content?.find((block) => block.type === 'tool_use');
  const suggestions = toolBlock?.input?.suggestions;
  return Array.isArray(suggestions) ? suggestions : [];
}
