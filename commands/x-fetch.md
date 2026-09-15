---
description: Fetch an X (Twitter) post — text + metadata, plus an on-device transcript when the post carries video — and ingest it into the wiki — /x-fetch <url>. Reads X only; transcription never leaves the machine.
---

Read the `x-fetch` skill, then run its flow for the given X post URL.

- **Short forms are the point.** `/x-fetch <url>` (or `ingest this tweet <url>`,
  or a bare `x.com`/`twitter.com` status link aimed at ingest) is the whole
  request — fetch, then proceed to the ingest handoff. Never ask the user to
  rephrase into a longer sentence.
- **Fetch via the skill's `scripts/x-fetch.sh`** (resolve the path next to the
  skill file) → post text + metadata land in `.raw/posts/<slug>.md` → hand off
  to the normal `ingest`.
- **Video posts get the yt-fetch treatment:** the script downloads the clip to a
  temp dir, transcribes it on-device with `whisperkit-cli`, and files the
  transcript in the same doc. The media is deleted on exit — nothing but
  markdown enters the vault.
- If `yt-dlp` is missing, **don't work around it** — the YouTube feature (which
  x-fetch shares) was declined at setup; point at `/secondbrain` to enable it.
  If only `whisperkit-cli` is missing, the fetch still succeeds with the post
  text and a warning where the transcript would go — say that enabling the
  Voice feature via `/secondbrain` and re-running fills it in. This command
  never installs anything.
- **One post per fetch.** Threads and quoted posts are not followed; run it once
  per status URL the user wants.
- **Fetches are anonymous by default** — no browser, no cookies, no dialogs. If
  a protected or age-gated post fails, tell the user the opt-in exists
  (`X_FETCH_COOKIES_BROWSER=firefox`, ideally a spare X account) and what it
  means; **never set it yourself**, and never retry with it unasked.
