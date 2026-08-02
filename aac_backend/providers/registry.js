import * as groq from './groq.js';
import * as gemini from './gemini.js';
import * as claude from './claude.js';
import * as ollama from './ollama.js';

// To add another provider: write a module with the same shape
// (id, label, envKey, defaultModel, generate()) and add it here.
// Ollama uses OLLAMA_MODEL as its sentinel — set it in .env to enable local LLM.
const ALL_PROVIDERS = [groq, gemini, claude, ollama];

function modelEnvVar(providerId) {
  return `${providerId.toUpperCase()}_MODEL`;
}

export function getAvailableProviders() {
  return ALL_PROVIDERS.filter((p) => Boolean(process.env[p.envKey])).map((p) => ({
    id: p.id,
    label: p.label,
    model: process.env[modelEnvVar(p.id)] || p.defaultModel,
  }));
}

export function getProvider(id) {
  return ALL_PROVIDERS.find((p) => p.id === id);
}

export function getDefaultProviderId() {
  const preferred = process.env.DEFAULT_PROVIDER;
  const preferredProvider = preferred && getProvider(preferred);
  if (preferredProvider && process.env[preferredProvider.envKey]) {
    return preferred;
  }
  return getAvailableProviders()[0]?.id;
}

export function getModelFor(provider) {
  return process.env[modelEnvVar(provider.id)] || provider.defaultModel;
}
