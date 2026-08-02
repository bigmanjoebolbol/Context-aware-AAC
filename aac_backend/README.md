# AAC Suggestion Backend (multi-provider)

Small server that the Flutter app's `LlmFallbackService` calls only when
the on-device rule engine can't classify a sentence (genuinely
open-ended text). Holds every LLM API key server-side - never put them
in the mobile app itself.

Supports **Groq, Gemini, and Claude** behind one interface. The user
(or the app) picks which model to use per request; the server only
exposes providers that actually have an API key configured.

## How provider selection works

- `providers/registry.js` scans env vars at startup. A provider only
  becomes "available" if its API key (`GROQ_API_KEY`, `GEMINI_API_KEY`,
  `CLAUDE_API_KEY`) is set.
- `GET /providers` returns the available providers + which one is the
  default, so the Flutter app can render a picker without hardcoding
  anything.
- `POST /suggest` accepts an optional `"provider": "groq" | "gemini" | "claude"`
  field. If omitted, it uses `DEFAULT_PROVIDER` (or the first configured
  provider if that's unset/misconfigured).
- Each provider is a small adapter module (`providers/groq.js`,
  `providers/gemini.js`, `providers/claude.js`) that all implement the
  same `generate({ apiKey, model, systemInstruction, userPrompt, maxTokens, timeoutMs })`
  signature and return a plain `string[]` of suggestions. Adding another
  provider (e.g. xAI's Grok, OpenAI) means writing one more file in that
  shape and adding it to the `ALL_PROVIDERS` list in `registry.js` -
  nothing else changes.
- Each provider forces structured JSON output using whatever mechanism
  it supports natively (Groq/OpenAI-style `response_format:
  json_object`, Gemini `responseSchema`, Claude forced tool-use) so
  there's no fragile "please respond in JSON" parsing.

## Setup

This project uses Node.js v18+ built-in environment variable loading.

```bash
npm install
cp .env.example .env
# edit .env: add a key for any providers you want to enable
npm start
```

You don't need all three keys - configure just Groq, just Claude,
whichever combination you want. `GET /providers` will only list what's
configured.

Test it directly:

```bash
curl -X POST http://localhost:8080/suggest \
  -H "Content-Type: application/json" \
  -d '{
    "other_person_text": "So are we still doing the thing Saturday or should we push it since your cousin is coming?",
    "language_preference": "mixed",
    "tone_preference": "casual",
    "preferences": {"protein": "chicken"},
    "recent_history": [],
    "provider": "claude"
  }'
```

Expected shape back:

```json
{ "suggestions": ["Let's push it to Sunday", "Saturday still works for me", "..."], "provider": "claude", "model": "claude-haiku-4-5-20251001" }
```

Check what's available before building a picker UI:

```bash
curl http://localhost:8080/providers
```

```json
{ "providers": [{"id":"groq","label":"Groq (Llama)","model":"llama-3.3-70b-versatile"}, {"id":"claude","label":"Claude","model":"claude-haiku-4-5-20251001"}], "default": "groq" }
```

## Deploy (Cloud Run example)

```bash
gcloud run deploy aac-suggestion-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GROQ_API_KEY=your_key,CLAUDE_API_KEY=your_key,GEMINI_API_KEY=your_key,APP_SHARED_SECRET=some_random_string
```

Any container host works the same way (Render, Railway, Fly.io, AWS App
Runner) - it's just a plain Express app reading `PORT` from the
environment.

## Locking it down

Set `APP_SHARED_SECRET` to a random string in your deployed environment,
and send the same value from the Flutter app as the `x-app-key` header
(already wired up in `LlmFallbackService` - see `headers` in
`lib/services/llm_fallback_service.dart`). Without this, anyone who
finds your backend URL could call it and spend your API quota on any
of the configured providers. It also gates `GET /providers` now, not
just `/suggest`.

**Rotate any key that's ever been shared outside your own machine** -
e.g. pasted into a chat, committed to git, or included in a bug report.

## Request/response contract

```
POST /suggest
{
  "other_person_text": "string - what the other person said",
  "language_preference": "english | arabicMSA | egyptianArabic | mixed",
  "tone_preference": "casual | formal | mixed",
  "preferences": { "protein": "chicken", "drink": "tea" },
  "recent_history": [{ "said": "...", "replied": "..." }],
  "provider": "groq | gemini | claude"   // optional, defaults to DEFAULT_PROVIDER
}

200 -> { "suggestions": ["...", "...", "..."], "provider": "groq", "model": "llama-3.3-70b-versatile" }
```

```
GET /providers
200 -> { "providers": [{ "id", "label", "model" }, ...], "default": "groq" }
```

Always returns a (possibly empty) `suggestions` array with HTTP 200 on
recoverable failures, and non-200 only for auth/config errors - matching
what `LlmFallbackService` expects on the Flutter side (fail soft, never
throw mid-conversation).

## On the Flutter side

`LlmFallbackService` just needs two small additions to use this:

1. Call `GET /providers` once (e.g. at app start or in settings) and
   store the list + default for a picker.
2. When calling `POST /suggest`, include `"provider": selectedProviderId`
   in the JSON body - or omit it to use the server's default.

No other change to the request/response shape is required.
