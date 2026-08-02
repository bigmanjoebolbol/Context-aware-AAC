import express from 'express';
import cors from 'cors';
import { SYSTEM_INSTRUCTION, buildCompactPrompt } from './prompt.js';
import {
  getAvailableProviders,
  getProvider,
  getDefaultProviderId,
  getModelFor,
} from './providers/registry.js';

const app = express();
app.use(cors());
app.use(express.json({ limit: '20kb' }));

const APP_SHARED_SECRET = process.env.APP_SHARED_SECRET;
const MAX_TOKENS = Number(process.env.MAX_TOKENS || 150);
const TIMEOUT_MS = Number(process.env.PROVIDER_TIMEOUT_MS || 7000);

function requireAppKey(req, res) {
  if (APP_SHARED_SECRET) {
    const provided = req.get('x-app-key');
    if (provided !== APP_SHARED_SECRET) {
      res.status(401).json({ suggestions: [] });
      return false;
    }
  }
  return true;
}

// Returns which providers are configured on this server.
// The Flutter app uses this to know if Ollama / Gemini is available.
app.get('/providers', (req, res) => {
  if (!requireAppKey(req, res)) return;
  res.status(200).json({
    providers: getAvailableProviders(),
    default: getDefaultProviderId(),
  });
});

/**
 * Tries a single provider. Returns { suggestions, model } on success,
 * throws on failure so the caller can try the next provider.
 */
async function tryProvider(provider, userPrompt) {
  const apiKey = process.env[provider.envKey];
  if (!apiKey) throw new Error(`${provider.id}: not configured`);

  const model = getModelFor(provider);
  const suggestions = await provider.generate({
    apiKey,
    model,
    systemInstruction: SYSTEM_INSTRUCTION,
    userPrompt,
    maxTokens: MAX_TOKENS,
    timeoutMs: TIMEOUT_MS,
  });
  return { suggestions, model };
}

app.post('/suggest', async (req, res) => {
  if (!requireAppKey(req, res)) return;

  const otherPersonText = (req.body?.other_person_text || '').trim();
  if (!otherPersonText) {
    return res.status(400).json({ suggestions: [] });
  }

  const userPrompt = buildCompactPrompt(req.body);

  // Build the provider attempt order:
  //   1. The provider the user chose in the app (e.g. 'ollama' or 'gemini')
  //   2. The server DEFAULT_PROVIDER
  //   3. Any other configured providers as last-resort fallback
  const requestedId = req.body?.provider;
  const availableIds = getAvailableProviders().map((p) => p.id);

  const orderedIds = [
    requestedId,
    getDefaultProviderId(),
    ...availableIds,
  ].filter(Boolean);

  // Deduplicate while preserving order
  const seen = new Set();
  const candidates = orderedIds
    .filter((id) => { if (seen.has(id)) return false; seen.add(id); return true; })
    .map((id) => getProvider(id))
    .filter(Boolean);

  if (candidates.length === 0) {
    console.error('No providers are configured.');
    return res.status(503).json({ suggestions: [], error: 'no_providers_configured' });
  }

  for (const provider of candidates) {
    try {
      const { suggestions, model } = await tryProvider(provider, userPrompt);
      if (suggestions.length > 0) {
        return res.status(200).json({
          suggestions: suggestions.slice(0, 5),
          provider: provider.id,
          model,
          // Tell the app if it fell back so it can show a notice
          used_fallback: provider.id !== requestedId && requestedId != null,
        });
      }
      console.warn(`${provider.id} returned no suggestions — trying next...`);
    } catch (err) {
      // e.g. Ollama not running → silently try next
      console.warn(`${provider.id} failed (${err.message}) — trying next provider...`);
    }
  }

  console.error('All configured providers failed.');
  return res.status(502).json({ suggestions: [] });
});

app.get('/health', (_req, res) => res.status(200).send('ok'));

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  const available = getAvailableProviders().map((p) => p.id).join(', ') || 'none configured';
  console.log(`AAC suggestion backend listening on port ${PORT}`);
  console.log(`Available providers: ${available}`);
});
