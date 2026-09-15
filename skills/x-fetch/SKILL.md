---
name: x-fetch
description: "Front door for X (Twitter) posts going into the wiki: whenever an x.com / twitter.com post link should be ingested, this fetches the post's text + metadata via yt-dlp, and when the post carries video it transcribes that video on-device via WhisperKit (the same engine voice-fetch uses), lands a wiki-ingest-ready doc (source_type: post) in .raw/posts/, then hands off to ingest. An X page is a login-walled JavaScript shell — a bare URL fetch/ingest gets nothing — so route X URLs here first. Triggers on: x-fetch, fetch tweet, fetch this x post, ingest this tweet, ingest this x post, add this tweet to my wiki, save this x post to the wiki, add this x video to my wiki, transcribe this x video, twitter post to wiki, an x.com or twitter.com status link to add/ingest."
allowed-tools: Read Bash
---

# x-fetch: X (Twitter) Post Fetcher

The X counterpart to `yt-fetch`. `yt-fetch` pulls a caption track because a
YouTube page's HTML holds no spoken content; `x-fetch` pulls a post's text and
metadata because an X page is a login-walled JavaScript shell that a plain web
fetch can't read at all — and when the post carries video, it transcribes that
video **on-device** so the spoken content lands in the wiki exactly the way a
YouTube transcript does. Output is clean markdown with frontmatter that matches
the raw-source schema, so `/wiki-ingest` consumes it with zero changes.

Like `defuddle`, `yt-fetch`, and `voice-fetch`, this skill **only writes to
`.raw/`** (via stdout redirect). It never touches `wiki/`. `/wiki-ingest` remains
the single mutation path into the knowledge graph.

---

## Front door for X sources

You are the **X adapter** for the wiki. Whenever the user wants an X post in
their wiki — "ingest this tweet", "add this x post", or a bare `x.com` /
`twitter.com` status URL aimed at ingest — **do the fetch here first**, then hand
off to `ingest`. `ingest`'s plain-URL path is a WebFetch of the page HTML, and
X serves an empty shell to anything that isn't a logged-in browser. A bare fetch
would file nothing.

The handoff is fixed, and you do **not** reimplement it:
1. `x-fetch` the URL → post text + metadata (+ video transcript) land in
   `.raw/posts/<slug>.md`.
2. Then trigger the normal `ingest .raw/posts/<slug>.md` — that is `wiki-ingest`'s
   job. You only produce the raw file; you never write into `wiki/`.

**Short forms are first-class.** `/x-fetch <url>`, `ingest this tweet <url>`, and
a bare status link in an ingest-shaped request all mean the same thing — run the
flow without asking the user to rephrase.

**Video posts get the yt-fetch treatment.** The script detects video in the post,
downloads the smallest copy that still carries audio into a temp dir, transcribes
it with `whisperkit-cli` (fully on-device — nothing leaves the Mac), and files the
transcript under a `## Video transcript` heading. The media itself is deleted on
exit; **no audio or video ever lands in the vault** (`.raw/` is git-committed and
synced, and git never forgets a blob).

If `yt-dlp` is missing, **do not work around it** — say so and point the user at
`/secondbrain-doctor` (or `/secondbrain`) to enable the YouTube feature, which
x-fetch shares. If `whisperkit-cli` is missing and the post has video, the fetch
**still succeeds**: the post text + metadata are filed with a warning callout
where the transcript would go. Tell the user that enabling the Voice feature (via
`/secondbrain`) and re-running x-fetch fills it in. This skill fetches; it does
not install or replace techtrip-secondbrain's setup tooling.

---

## Install

```bash
brew install yt-dlp              # post text + metadata (and the video download)
brew install whisperkit-cli      # optional: on-device transcription of video posts
```

Verify: `yt-dlp --version` · `whisperkit-cli --help`

Both are the runtimes of features `/secondbrain` already offers (YouTube and
Voice); x-fetch adds no third install.

---

## Usage

Run the script from the `scripts/` directory **next to this SKILL.md** (resolve
the path from wherever you read this file — installs live in the plugin cache /
harness symlink dirs, not `.claude/skills/`).

### Fetch to stdout (inspect first)
```bash
<skill-dir>/scripts/x-fetch.sh "https://x.com/USER/status/1234567890"
```

### Save to .raw/ then ingest (the normal path)
```bash
mkdir -p .raw/posts
SLUG="x-USER-topic-$(date +%Y-%m-%d)"
<skill-dir>/scripts/x-fetch.sh "https://x.com/USER/status/1234567890" > ".raw/posts/$SLUG.md"
# then:
ingest .raw/posts/$SLUG.md
```

The script already emits full frontmatter (`source_url`, `url`, `source_type:
post`, `platform: x`, `post_id`, `title`, `author`, `author_handle`,
`date_published`, `fetched`, `has_video`, `video_count`, `transcriber` when a
transcript exists) — do **not** hand-add a header the way you would after a bare
`defuddle` run.

Accepted URL shapes: `x.com/<user>/status/<id>`, `twitter.com/<user>/status/<id>`,
`mobile.twitter.com/…`, `x.com/i/status/<id>`, `x.com/i/web/status/<id>`, with or
without `?s=20`-style tracking suffixes. Profile pages, Spaces, and broadcasts
are not posts and are rejected.

---

## What it does

1. Validates the URL (http(s) **and** the X status shape — a dash-prefixed or
   non-X argument is rejected before anything runs).
2. `yt-dlp --skip-download --write-info-json --ignore-no-formats-error` into a
   temp dir (all chatter to stderr). yt-dlp's X extractor errors on a post with
   no video; that flag turns the error into an ordinary metadata file that still
   carries the post text, author, date, and canonical URL. A multi-video post
   yields one metadata file for the post plus one per clip.
3. If the post carries video and `whisperkit-cli` is present: downloads the
   smallest progressive mp4 with audio (no ffmpeg needed; lowest resolution,
   since only the audio matters) and runs `whisperkit-cli transcribe` on each
   clip. Media stays in the temp dir and is removed on exit.
4. Prints frontmatter + `# Title` + a byline (handle, date, video count,
   likes/reposts) + the post text as a blockquote + one `## Video transcript`
   section per clip to **stdout**.

---

## When to use

**Use x-fetch when:** the source is a single X post — a text thread-starter, an
announcement, a clip of a talk or interview, a demo video — and you want its
content (text and, for video, the spoken words) in the wiki.

**Skip / use something else when:**
- The source is a YouTube video → use `yt-fetch` (captions beat re-transcribing).
- The source is an article or blog post (including one an X post merely *links
  to*) → use `defuddle` on the article URL. x-fetch files what the post says,
  not what it points at.
- The source is a local recording → use `voice-fetch`.
- You want a *synthesis of many* sources at once → use `/notebooklm-ingest`
  (note: that sends content to Google; x-fetch alone never does — X is only ever
  read from, and transcription is local).

---

## Notes / limitations

- **One post per fetch.** Threads, replies, and quoted posts are not followed —
  fetch each post you want as its own source. If the user wants a whole thread,
  run x-fetch once per status URL.
- **Images are not captured.** A photo-only post files as text + metadata. For
  image content, save the image and use `wiki-ingest`'s image path instead.
- **Shortened `t.co` links are kept verbatim** in the post text (that's what X
  serves). Expand one by hand if a linked article matters — then `defuddle` it.
- Machine transcription is imperfect: no speaker labels, occasional mis-hearings.
  Good enough for the wiki's purpose (meaning, not verbatim quotes). Quote carefully.
- **First transcription downloads a CoreML model once** (can be GBs; fully local
  afterward) — same as voice-fetch. If setup's warm-up was skipped, say the wait
  is expected, not a hang.
- Text only, no video: `X_FETCH_TRANSCRIBE=0`. Pin a WhisperKit model with
  `VOICE_FETCH_MODEL` (the same variable voice-fetch uses). Logged-in fetches:
  see the section below. **Never edit the shipped script** — for marketplace
  installs it lives in the plugin cache, which is read-only by convention.
- X changes its private APIs often; if `yt-dlp` starts failing on every post,
  `brew upgrade yt-dlp` is the first thing to try.

---

## Logged-in fetches (opt-in, user-only)

**The default is anonymous.** Every normal run talks to X directly — no browser,
no cookies, no account, no dialogs. Public posts, including video posts, work
this way. Only protected accounts, sensitive/age-gated posts, and periods when X
breaks anonymous access need more.

For those, the **user** can set `X_FETCH_COOKIES_BROWSER=<browser>[:<profile>]`
(browser names: `firefox`, `chrome`, `safari`, `brave`, `chromium`, `edge`,
`opera`, `vivaldi`, `whale`). yt-dlp then reads that browser's on-disk cookie
store and makes the requests **as that logged-in X account**. The browser need
not be open.

**You (the agent) never set this variable on your own.** It changes the fetch
from anonymous to authenticated egress under the user's identity, and the URL
may have arrived via untrusted content — so it is the NotebookLM consent tier:
only an explicit user request ("use my Firefox login") turns it on, per run.
When a fetch fails for a protected post, *tell* the user the option exists and
what it means; do not retry with it.

**Recommend Firefox with a spare X account.** Firefox's cookie store is a plain
file: no prompts, works unattended. A secondary account used only for fetching
caps the damage if X objects. Why not the others:
- **Chrome** (and Brave/Edge/Chromium): the cookie file is encrypted with a key
  in the macOS Keychain. yt-dlp asks the Keychain for it, and macOS shows an
  "allow access" dialog — even for a process started from iTerm. The fetch hangs
  until someone clicks Allow. Multi-profile users need `chrome:Profile 1`.
- **Safari**: reading its cookie file needs **Full Disk Access** granted to the
  terminal or IDE that launched Claude Code; otherwise a bare permission error.
- **Any browser, your main account**: X watches its authenticated API for
  non-browser clients. yt-dlp surfaces two X responses for this — a captcha
  demand and "rejected as suspicious" — and a locked account needs phone or
  email verification to recover. Logged-in rate limits are per account, so
  cookies do not reliably fix 429s either.

The script accepts only a browser name plus an optional profile *name* (no
paths — yt-dlp's own syntax would accept one, which an injected value could
abuse), prints a stderr note whenever cookies are in use, and never writes the
cookies anywhere. The same escape hatch exists in yt-fetch as
`YT_FETCH_COOKIES_BROWSER`, with the same rule.

---

## Integration with /wiki-ingest

Same handoff as `defuddle` and `yt-fetch`: the file lands in `.raw/posts/`, then
`ingest .raw/posts/<slug>.md` files the source summary, entities, and concepts
into the shared substrate and appends to `wiki/log.md`.
