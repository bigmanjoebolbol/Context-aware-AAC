# Context-Aware AAC

An AAC (Augmentative and Alternative Communication) app for people who
can't hear or speak but can read and understand. Listens to the other
party, classifies what they said, and offers ranked reply suggestions
the user taps to have spoken aloud. English + Arabic (MSA + Egyptian).

## Architecture: hybrid, not full-AI

This app deliberately does **not** route every sentence through an LLM.

1. **Fast path (offline, instant, free)** — `lib/services/rule_engine.dart`
   - Either/or detection ("chicken or meat?" → two options + a personalized
     third option if relevant)
   - Yes/No detection (starters like "do you" / "هل" / "تحب")
   - Phrasebook matching against known recurring questions
     (`lib/services/phrasebook_seed.dart`), ranked by a simple score that
     increases every time the user picks a given reply — this is the
     entire "learning" mechanism: on-device frequency reinforcement, no
     model training, fully explainable, works with zero connectivity.

2. **LLM fallback (only for genuinely open-ended text)** —
   `lib/services/llm_fallback_service.dart`. Only called when the rule
   engine can't classify the sentence. Fails soft (returns no suggestions,
   never hangs) if the network is unavailable, since a live conversation
   can't wait on a stalled API call.

Every reply the user picks is logged (`lib/services/storage_service.dart`)
and used to reinforce the phrasebook, so the app's suggestions get more
personalized the more it's used — without ever needing an LLM for that.

## Project structure

```
lib/
  models/            UserProfile, ConversationEntry, PhraseEntry (+ hand-written Hive adapters)
  services/
    rule_engine.dart          fast offline classification + suggestions
    storage_service.dart      Hive-backed local persistence + scoring
    phrasebook_seed.dart      default known-question set (EN/MSA/Egyptian Arabic)
    llm_fallback_service.dart calls YOUR backend, not Anthropic directly
    tts_service.dart          speaks replies, auto-detects Arabic vs English segments
    stt_service.dart          streams mic transcription
  screens/
    onboarding_screen.dart    initial preference questionnaire
    conversation_screen.dart  main loop: hear -> classify -> suggest -> speak
    settings_screen.dart      edit preferences, auto-reply toggle (gated by confirmation)
  theme/app_theme.dart        large touch targets, high contrast
```

## Setup

```
flutter pub get
flutter run
```

No API keys are needed to run the fast path at all — the app is fully
usable offline for either/or, yes/no, and known phrasebook questions
with zero setup.

## LLM fallback backend (Gemini)

The `aac_backend/` folder (sibling to this project, delivered alongside
it) is a small Node/Express server that implements the fallback:
receives `{ other_person_text, language_preference, tone_preference,
preferences, recent_history }`, calls the Gemini API with a fixed short
system instruction and a schema-constrained response (so output is
always exactly `{ "suggestions": [...] }`), and returns that. It holds
your `GEMINI_API_KEY` server-side — **never put that key in the Flutter
app itself**, since anything in the compiled binary can be extracted.

Deploy it (Cloud Run, Render, Railway, Fly.io — see `aac_backend/README.md`
for a Cloud Run example), then set in `conversation_screen.dart`:

```dart
final LlmFallbackService _llm = LlmFallbackService(
  backendEndpoint: 'https://<your-deployed-backend>/suggest',
  sharedSecret: '<same value as APP_SHARED_SECRET on the backend>',
);
```

The backend is tuned to minimize token spend: `gemini-2.0-flash-lite` by
default, history trimmed to the last 2 turns, `maxOutputTokens: 150`, and
a `responseSchema` so no tokens are spent on formatting instructions.
Full rationale in `aac_backend/README.md`.

## Known limitation: live phone calls

True "read what the other person is saying during a normal cellular
call" is not something either iOS or Android allows a third-party app
to do — there's no API that exposes raw call audio to apps, and Android
has locked this down further release over release.

The realistic path is to build **in-app VoIP calling** (Twilio, Agora,
or raw WebRTC) so calls happen through this app instead of the native
dialer — then the app legitimately owns both audio streams and can
transcribe + suggest replies during a live call. That's a separate,
larger feature (`CallScreen` + a signaling/media service) that isn't
in this initial scaffold; the STT/TTS/rule-engine/LLM pieces above are
written so a future `CallScreen` can reuse them directly.

## Accessibility notes baked in

- Large tap targets (56px min button height), high-contrast theme
- "None, write my own message" always present as a suggestion
- Auto-reply mode is off by default and gated behind an explicit
  warning dialog before it can be turned on
- Every suggestion shows its source (phrasebook / detected pattern /
  AI / your own) so the user always knows why something was suggested
