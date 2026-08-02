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

// Lets the Flutter app build a "pick a model" UI dynamically, based on
// which API keys are actually configured on the server.
app.get('/providers', (req, res) => {
  if (!requireAppKey(req, res)) return;
  res.status(200).json({
    providers: getAvailableProviders(),
    default: getDefaultProviderId(),
  });
});

app.post('/suggest', async (req, res) => {
  if (!requireAppKey(req, res)) return;

  const otherPersonText = (req.body?.other_person_text || '').trim();
  if (!otherPersonText) {
    return res.status(400).json({ suggestions: [] });
  }

  const requestedId = req.body?.provider || getDefaultProviderId();
  const provider = getProvider(requestedId);
  const apiKey = provider && process.env[provider.envKey];

  if (!provider || !apiKey) {
    console.error(`Provider "${requestedId}" is not configured`);
    return res.status(400).json({ suggestions: [], error: 'unknown_or_unconfigured_provider' });
  }

  const model = getModelFor(provider);
  const userPrompt = buildCompactPrompt(req.body);

  try {
    const suggestions = await provider.generate({
      apiKey,
      model,
      systemInstruction: SYSTEM_INSTRUCTION,
      userPrompt,
      maxTokens: MAX_TOKENS,
      timeoutMs: TIMEOUT_MS,
    });

    return res.status(200).json({
      suggestions: suggestions.slice(0, 5),
      provider: provider.id,
      model,
    });
  } catch (err) {
    console.error(`${provider.id} suggest handler failed:`, err.message);
    return res.status(502).json({ suggestions: [] });
  }
});

app.get('/health', (_req, res) => res.status(200).send('ok'));

const PORT = process.env.PORT || 8080;
app.listen(PORT, () => {
  const available = getAvailableProviders().map((p) => p.id).join(', ') || 'none configured';
  console.log(`AAC suggestion backend listening on port ${PORT}`);
  console.log(`Available providers: ${available}`);
});
