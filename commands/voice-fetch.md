---
description: Transcribe a local audio file (Voice Memos .m4a, mp3, wav, …) fully on-device via WhisperKit and ingest it into the wiki — /voice-fetch <path>. No cloud, no credentials; the audio never leaves the machine.
---

Read the `voice-fetch` skill, then run its flow for the given audio file.

- **Short forms are the point.** `/voice-fetch <path>` (or `transcribe <path>`, or
  `ingest <path>.m4a`) is the whole request — transcribe, then proceed to the
  ingest handoff. Never ask the user to rephrase into a longer sentence.
- **Transcribe on-device** via the skill's `scripts/voice-fetch.sh` (resolve the
  path next to the skill file) → transcript lands in `.raw/audio/<slug>.md` →
  hand off to the normal `ingest`.
- **Audio sitting inside `.raw/` is an anti-pattern** — the transcript is the raw
  source of record; `.raw/` is git-committed + synced and git never forgets a
  blob. If the given path (or any audio you encounter) lives under `.raw/`:
  after ingesting the transcript, **always offer cleanup** of the original —
  move it out of the vault (user names where) or delete it. Confirm-gated,
  never silent either way. `doctor` flags audio under `.raw/` until it's gone.
- **First run only:** WhisperKit downloads its CoreML model once (can be GBs;
  fully local afterward). Setup offers to pre-download; if that was skipped,
  say the wait is expected, not a hang.
- If `whisperkit-cli` is missing, **don't work around it** — the Voice feature
  was declined at setup; point at `/secondbrain` to enable it (or
  `/secondbrain-doctor` to check state). This command never installs anything.
