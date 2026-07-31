# AAC Suggestion Backend (Gemini)

Small server that the Flutter app's `LlmFallbackService` calls only when
the on-device rule engine can't classify a sentence (genuinely
open-ended text). Holds the Gemini API key server-side - never put it
in the mobile app itself.

## Why this is cheap and fast

- **`gemini-2.0-flash-lite`** by default - the smallest/cheapest Gemini
  tier, more than enough for short reply suggestions.
- **`responseSchema`** forces Gemini to return exactly
  `{"suggestions": ["...", ...]}` - no prompt tokens spent telling it
  "respond only in JSON", no retries for malformed output.
- **`maxOutputTokens: 150`** hard-caps generation length - suggestions
  are short by design, so this is rarely a real constraint but stops
  any runaway output.
- **History is trimmed to the last 2 turns**, each capped to ~60/40
  characters. This is the biggest token-cost lever if left unchecked -
  full conversation history would grow every request.
- **The system instruction is fixed and short** - it defines the
  model's job once (nonverbal AAC user, give short reply options,
  match tone, language-mix rule) rather than repeating instructions in
  every user turn.

Rough cost per open-ended sentence: a few hundred tokens in, under 150
out. At Gemini Flash-Lite pricing this is a fraction of a cent per
fallback call - and remember, the fast path (rule engine) handles most
traffic and never reaches this server at all.

## Setup
his project uses Node.js v24+ built-in environment variable loading. 

1. Copy the example configuration:
   ```powershell
   copy .env.example .env

```
npm install
cp .env.example .env
# edit .env: paste your Gemini API key from https://aistudio.google.com/apikey
npm start
```

Test it directly:

```bash
curl -X POST http://localhost:8080/suggest \
  -H "Content-Type: application/json" \
  -d '{
    "other_person_text": "So are we still doing the thing Saturday or should we push it since your cousin is coming?",
    "language_preference": "mixed",
    "tone_preference": "casual",
    "preferences": {"protein": "chicken"},
    "recent_history": []
  }'
```

Expected shape back:

```json
{ "suggestions": ["Let's push it to Sunday / يلا نأجلها للحد", "Saturday still works for me / السبت لسه تمام", "..."] }
```

## Deploy (Cloud Run example)

```bash
gcloud run deploy aac-suggestion-backend \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY=your_key_here,APP_SHARED_SECRET=some_random_string
```

Any container host works the same way (Render, Railway, Fly.io, AWS App
Runner) - it's just a plain Express app reading `PORT` from the
environment.

## Locking it down

Set `APP_SHARED_SECRET` to a random string in your deployed environment,
and send the same value from the Flutter app as the `x-app-key` header
(already wired up in `LlmFallbackService` - see `headers` in
`lib/services/llm_fallback_service.dart`). Without this, anyone who
finds your backend URL could call it and spend your Gemini quota.

## Request/response contract

```
POST /suggest
{
  "other_person_text": "string - what the other person said",
  "language_preference": "english | arabicMSA | egyptianArabic | mixed",
  "tone_preference": "casual | formal | mixed",
  "preferences": { "protein": "chicken", "drink": "tea" },
  "recent_history": [{ "said": "...", "replied": "..." }]
}

200 -> { "suggestions": ["...", "...", "..."] }
```

Always returns a (possibly empty) `suggestions` array with HTTP 200 on
recoverable failures, and non-200 only for auth/config errors - matching
what `LlmFallbackService` expects on the Flutter side (fail soft, never
throw mid-conversation).
