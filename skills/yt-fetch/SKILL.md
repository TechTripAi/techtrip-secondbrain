---
name: yt-fetch
description: "Fetch a YouTube video's transcript and metadata as clean markdown before ingesting into the wiki. Pulls auto-captions via yt-dlp, strips caption cruft, and emits a wiki-ingest-ready doc (source_type: video) to stdout. Triggers on: yt-fetch, fetch youtube, youtube transcript, ingest youtube, grab this video, transcript from url, pull captions."
allowed-tools: Read Bash
---

# yt-fetch: YouTube Transcript Fetcher

The YouTube counterpart to `defuddle`. `defuddle` cleans article pages; `yt-fetch`
turns a video URL into a transcript because a YouTube watch page's HTML contains
almost no spoken content — you need the caption track. Output is clean markdown
with frontmatter that matches the raw-source schema, so `/wiki-ingest` consumes
it with zero changes.

Like `defuddle`, this skill **only writes to `.raw/`** (via stdout redirect). It
never touches `wiki/`. `/wiki-ingest` remains the single mutation path into the
knowledge graph.

---

## Install

```bash
brew install yt-dlp      # transcript + metadata fetcher
```

Verify: `yt-dlp --version`

---

## Usage

### Fetch to stdout (inspect first)
```bash
.claude/skills/yt-fetch/scripts/yt-fetch.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Save to .raw/ then ingest (the normal path)
```bash
mkdir -p .raw/videos
SLUG="video-slug-$(date +%Y-%m-%d)"
.claude/skills/yt-fetch/scripts/yt-fetch.sh "https://www.youtube.com/watch?v=VIDEO_ID" > ".raw/videos/$SLUG.md"
# then:
ingest .raw/videos/$SLUG.md
```

The script already emits full frontmatter (`source_url`, `url`, `source_type:
video`, `title`, `author`, `date_published`, `fetched`) — do **not** hand-add a
header the way you would after a bare `defuddle` run.

---

## What it does

1. `yt-dlp --skip-download --write-auto-sub --write-sub --sub-lang "en.*"
   --sub-format vtt --write-info-json` into a temp dir (all chatter to stderr).
2. Reads title / channel / upload date / canonical URL from the info JSON.
3. Cleans the `.vtt`: strips WEBVTT headers, timestamps, and inline word-timing
   tags, and collapses YouTube's rolling-caption repeats into readable prose.
4. Prints frontmatter + `# Title` + transcript to **stdout**.

---

## When to use

**Use yt-fetch when:** the source is a YouTube video and you want its spoken
content in the wiki (talks, interviews, tutorials, conference sessions).

**Skip / use something else when:**
- The source is an article or blog post → use `defuddle`.
- You want a *synthesis of many* videos at once, or a deliverable (audio
  overview, infographic, flashcards) → use `/notebooklm-ingest`.
- The video has **no captions** — the script emits a warning and empty body;
  ingest metadata only, or add a manual summary before ingesting.

---

## Notes / limitations

- Auto-captions are imperfect (no speaker labels, occasional mis-hearings).
  Good enough for the wiki's purpose (meaning, not verbatim quotes). Quote
  carefully.
- Non-English videos: change `--sub-lang` in `scripts/yt-fetch.sh` or fetch a
  specific track.
- Age/region-restricted videos may need cookies: add
  `--cookies-from-browser chrome` to the `yt-dlp` invocation in the script.

---

## Integration with /wiki-ingest

Same handoff as `defuddle`: the file lands in `.raw/videos/`, then
`ingest .raw/videos/<slug>.md` files the source summary, entities, and concepts
into the shared substrate and appends to `wiki/log.md`.
