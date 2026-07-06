---
name: yt-fetch
description: "Front door for YouTube sources going into the wiki: whenever a YouTube link (youtube.com / youtu.be) should be ingested, this fetches its transcript + metadata via yt-dlp, lands a wiki-ingest-ready doc (source_type: video) in .raw/videos/, then hands off to ingest. A YouTube watch page's HTML holds no spoken content, so a bare URL fetch/ingest would miss it — route YouTube URLs here first. Triggers on: yt-fetch, fetch youtube, youtube transcript, ingest youtube, ingest this youtube url, add this youtube video to my wiki, save this video to the wiki, put this video in the wiki, grab this video, transcript from url, pull captions, a youtube.com or youtu.be link to add/ingest."
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

## Front door for YouTube sources

You are the **YouTube adapter** for the wiki. Whenever the user wants a YouTube
link in their wiki — "ingest this video", "add this youtube video", or a bare
`youtube.com`/`youtu.be` URL aimed at ingest — **do the fetch here first**, then
hand off to `ingest`. This matters because `ingest`'s plain-URL path is a WebFetch
of the page HTML, and a YouTube watch page carries no spoken content — only the
caption track does. A bare fetch would file an empty shell.

The handoff is fixed, and you do **not** reimplement it:
1. `yt-fetch` the URL → transcript + metadata land in `.raw/videos/<slug>.md`.
2. Then trigger the normal `ingest .raw/videos/<slug>.md` — that is `wiki-ingest`'s
   job. You only produce the raw file; you never write into `wiki/`.

Note: this is techtrip-secondbrain's interim adapter for YouTube. If upstream
`claude-obsidian` later ships native multimodal ingest (its v1.9 roadmap folds
YouTube into `ingest` directly), a bare `ingest <youtube-url>` will work on its
own and this front-door step becomes redundant.

If `yt-dlp` is missing, **do not work around it** — say so and point the user at
`/secondbrain-doctor` (or `/secondbrain`) to install it. This skill fetches; it
does not install or replace techtrip-secondbrain's setup tooling.

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
