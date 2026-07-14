---
name: voice-fetch
description: "Front door for local audio going into the wiki: whenever a voice memo or audio file (m4a, mp3, wav, …) should be ingested, this transcribes it on-device via WhisperKit (CoreML/Neural Engine — no cloud, no credentials), lands a wiki-ingest-ready doc (source_type: transcript) in .raw/audio/, then hands off to ingest. An audio file has no text for ingest to read, so a bare ingest of the path would miss everything — route ANY audio-file path aimed at ingest here first, including audio the user dropped into .raw/ directly. Triggers on: voice-fetch, /voice-fetch, transcribe this, transcribe <path>, ingest this audio, ingest <anything>.m4a/.mp3/.wav, add this voice memo to my wiki, ingest this recording, voice memo to wiki, transcribe and ingest, add this m4a, an audio file path to add/ingest, save this recording to the wiki, there's an audio file in .raw."
allowed-tools: Read Bash
---

# voice-fetch: On-Device Audio Transcriber

The audio counterpart to `yt-fetch`. `yt-fetch` pulls a caption track because a
YouTube page's HTML holds no spoken content; `voice-fetch` runs local speech-to-text
because an audio file holds no text at all. Output is clean markdown with
frontmatter that matches the raw-source schema, so `/wiki-ingest` consumes it with
zero changes.

Transcription is **fully on-device** (WhisperKit, CoreML on the Neural Engine):
nothing leaves the machine, nothing is metered, and no AI messages are spent until
the `ingest` itself.

Like `defuddle` and `yt-fetch`, this skill **only writes to `.raw/`** (via stdout
redirect). It never touches `wiki/`. `/wiki-ingest` remains the single mutation
path into the knowledge graph.

---

## Front door for audio sources

You are the **audio adapter** for the wiki. Whenever the user wants a recording in
their wiki — "transcribe this", "add this voice memo", or an audio-file path aimed
at ingest — **do the transcription here first**, then hand off to `ingest`. A bare
`ingest <file>.m4a` would read bytes, not speech; audio must become text first.

The handoff is fixed, and you do **not** reimplement it:
1. `voice-fetch` the file → transcript + metadata land in `.raw/audio/<slug>.md`.
2. Then trigger the normal `ingest .raw/audio/<slug>.md` — that is `wiki-ingest`'s
   job. You only produce the raw file; you never write into `wiki/`.

**Short forms are first-class.** `transcribe <path>`, `ingest <path>.m4a`, and
`/voice-fetch <path>` all mean the same thing — never make the user say the long
sentence. If they name an audio file in an ingest-shaped request, that IS the
request: run the flow (transcribe, then proceed to or offer the ingest per their
phrasing) without asking them to rephrase.

**Audio inside `.raw/` is an anti-pattern — support it once, then clean it up.**
The transcript is the raw source of record (the defuddle precedent: the cleaned
markdown is stored, never the web page's HTML), and `.raw/` is git-committed and
synced — a committed audio blob bloats every clone of the vault permanently. So
when the user drops `memo.m4a` into `.raw/` and asks to ingest it:
1. Transcribe it to a sibling `.md` and ingest that — the normal flow.
2. Then **always offer cleanup of the audio original** — never silently leave it,
   never silently remove it. Two choices, theirs to make:
   - **move it out** of the vault (they name where — `~/Downloads/`, an external
     folder, wherever), or
   - **delete it** (it's their copy of their own recording).
   One-line why: `.raw/` is committed + synced; git never forgets a blob.
   `doctor` flags any audio living under `.raw/` until it's gone.

If `whisperkit-cli` is missing, **do not work around it** — say so and point the
user at `/secondbrain-doctor` (or `/secondbrain`) to enable the voice feature. This
skill transcribes; it does not install or replace techtrip-secondbrain's setup
tooling.

---

## Install

```bash
brew install whisperkit-cli      # on-device transcription (CoreML/Neural Engine)
```

Verify: `whisperkit-cli --help`

**First-run note (tell the user once):** the first transcription downloads a CoreML
model (can be GBs, one time). After that everything is local and offline-capable.

---

## Usage

Run the script from the `scripts/` directory **next to this SKILL.md** (resolve
the path from wherever you read this file — installs live in the plugin cache /
harness symlink dirs, not `.claude/skills/`).

### Transcribe to stdout (inspect first)
```bash
<skill-dir>/scripts/voice-fetch.sh ~/Downloads/memo.m4a
```

### Save to .raw/ then ingest (the normal path)
```bash
mkdir -p .raw/audio
SLUG="memo-slug-$(date +%Y-%m-%d)"
<skill-dir>/scripts/voice-fetch.sh ~/Downloads/memo.m4a > ".raw/audio/$SLUG.md"
# then:
ingest .raw/audio/$SLUG.md
```

The script already emits full frontmatter (`title`, `source_type: transcript`,
`source_file`, `date_recorded`, `fetched`, `transcriber`) — do **not** hand-add a
header the way you would after a bare `defuddle` run.

### Getting the audio out of Voice Memos

Voice Memos doesn't expose files in Finder directly; either **drag the memo out of
the app** into a folder (it lands as `.m4a`), or use the app's share sheet →
"Save to Files". On macOS Sequoia+ the app also shows its own on-device transcript —
copying that text straight into `.raw/audio/<name>.md` is a fine zero-install
alternative when whisperkit isn't set up.

---

## What it does

1. Validates the path (rejects option-looking args; requires a real file with a
   known audio extension: m4a, mp3, wav, aiff, flac, mp4, mov, caf, ogg, opus, webm).
2. Runs `whisperkit-cli transcribe --audio-path <file>` — progress and any one-time
   model download go to stderr; stdout stays clean.
3. Derives metadata from the file itself: title from the basename, `date_recorded`
   from the file's modification time (Voice Memos stamps recording time there).
4. Prints frontmatter + `# Title` + transcript to **stdout**.

Model choice: set `VOICE_FETCH_MODEL` in the environment to pin a specific
WhisperKit model — no script edit needed. **Never edit the shipped script** — for
marketplace installs it lives in the plugin cache, which is read-only by convention.

---

## When to use

**Use voice-fetch when:** the source is a local audio or A/V file and you want its
spoken content in the wiki — Mac Voice Memos, meeting recordings, dictated notes,
downloaded podcast episodes, screen recordings with narration.

**Skip / use something else when:**
- The source is a YouTube URL → use `yt-fetch` (captions beat re-transcribing).
- The source is an article or blog post → use `defuddle`.
- You want a *synthesis of many* sources at once → use `/notebooklm-ingest`
  (note: that sends content to Google; voice-fetch alone never does).
- The audio is silent or music-only — the script warns and emits metadata only;
  add a manual summary before ingesting.

---

## Notes / limitations

- Machine transcription is imperfect: no speaker labels, occasional mis-hearings,
  and rambly voice memos transcribe as rambly text. Good enough for the wiki's
  purpose (meaning, not verbatim quotes). Quote carefully.
- Long recordings take real time even on the Neural Engine — mention it for
  hour-plus files rather than looking hung.
- Non-English audio: WhisperKit's models are multilingual; if results are poor,
  pin a larger model via `VOICE_FETCH_MODEL`.

---

## Integration with /wiki-ingest

Same handoff as `defuddle` and `yt-fetch`: the file lands in `.raw/audio/`, then
`ingest .raw/audio/<slug>.md` files the source summary, entities, and concepts
into the shared substrate and appends to `wiki/log.md`.
