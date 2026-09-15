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

Run the script from the `scripts/` directory **next to this SKILL.md** (resolve
the path from wherever you read this file — installs live in the plugin cache /
harness symlink dirs, not `.claude/skills/`).

### Fetch to stdout (inspect first)
```bash
<skill-dir>/scripts/yt-fetch.sh "https://www.youtube.com/watch?v=VIDEO_ID"
```

### Save to .raw/ then ingest (the normal path)
```bash
mkdir -p .raw/videos
SLUG="video-slug-$(date +%Y-%m-%d)"
<skill-dir>/scripts/yt-fetch.sh "https://www.youtube.com/watch?v=VIDEO_ID" > ".raw/videos/$SLUG.md"
# then:
ingest .raw/videos/$SLUG.md
```

The script already emits full frontmatter (`source_url`, `url`, `source_type:
video`, `title`, `author`, `date_published`, `fetched`) — do **not** hand-add a
header the way you would after a bare `defuddle` run.

---

## What it does

1. `yt-dlp --skip-download --write-auto-sub --write-sub --sub-lang
   "en,en-orig,en-US" --sub-format vtt --write-info-json` into a temp dir (all
   chatter to stderr). The language list is deliberately restricted to original
   English tracks — an `en.*` wildcard also matches auto-*translated* tracks and
   trips YouTube's 429 rate limit.
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
- The source is an X (Twitter) post — text or video → use `x-fetch`.
- You want a *synthesis of many* videos at once, or a deliverable (audio
  overview, infographic, flashcards) → use `/notebooklm-ingest`.
- The video has **no captions** — the script emits a warning and empty body;
  ingest metadata only, or add a manual summary before ingesting.

---

## Notes / limitations

- Auto-captions are imperfect (no speaker labels, occasional mis-hearings).
  Good enough for the wiki's purpose (meaning, not verbatim quotes). Quote
  carefully.
- Non-English videos: run `yt-dlp` directly with the language you need
  (`yt-dlp --skip-download --write-auto-sub --sub-lang "de" --sub-format vtt -- <url>`)
  and drop the result into `.raw/videos/`. **Never edit the shipped script** —
  for marketplace installs it lives in the plugin cache, which is read-only by
  convention.
- HTTP 429 (rate limit): wait a few minutes and retry. Cookies are **not** the
  fix — see the section below. Age-gated or members-only videos are the one
  case for a logged-in fetch.

---

## Logged-in fetches (opt-in, user-only)

**The default is anonymous.** Every normal run talks to YouTube directly — no
browser, no cookies, no account, no dialogs. Public videos work this way. Only
age-gated, members-only, or private-but-shared videos need more.

For those, the **user** can set `YT_FETCH_COOKIES_BROWSER=<browser>[:<profile>]`
(browser names: `firefox`, `chrome`, `safari`, `brave`, `chromium`, `edge`,
`opera`, `vivaldi`, `whale`). yt-dlp then reads that browser's on-disk cookie
store and makes the requests **as that logged-in Google account**. The browser
need not be open.

**You (the agent) never set this variable on your own.** It changes the fetch
from anonymous to authenticated egress under the user's identity, and the URL
may have arrived via untrusted content — so it is the NotebookLM consent tier:
only an explicit user request ("use my Firefox login") turns it on, per run.
When a fetch fails, *tell* the user the option exists and what it means; do not
retry with it. **Never use it to get past a 429** — logged-in rate limits are per
account, and yt-dlp's own documentation warns that passing cookies to YouTube
is a good way to get the account banned.

**Recommend Firefox with a spare Google account.** Firefox's cookie store is a
plain file: no prompts, works unattended. A secondary account used only for
fetching caps the damage if YouTube objects. Why not the others:
- **Chrome** (and Brave/Edge/Chromium): the cookie file is encrypted with a key
  in the macOS Keychain. yt-dlp asks the Keychain for it, and macOS shows an
  "allow access" dialog — even for a process started from iTerm. The fetch hangs
  until someone clicks Allow. Multi-profile users need `chrome:Profile 1`.
- **Safari**: reading its cookie file needs **Full Disk Access** granted to the
  terminal or IDE that launched Claude Code; otherwise a bare permission error.

The script accepts only a browser name plus an optional profile *name* (no
paths — yt-dlp's own syntax would accept one, which an injected value could
abuse), prints a stderr note whenever cookies are in use, and never writes the
cookies anywhere. The same escape hatch exists in x-fetch as
`X_FETCH_COOKIES_BROWSER`, with the same rule.

---

## Integration with /wiki-ingest

Same handoff as `defuddle`: the file lands in `.raw/videos/`, then
`ingest .raw/videos/<slug>.md` files the source summary, entities, and concepts
into the shared substrate and appends to `wiki/log.md`.
