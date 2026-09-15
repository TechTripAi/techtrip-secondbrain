#!/usr/bin/env bash
# x-fetch: fetch an X (Twitter) post — its text + metadata, and when the post
# carries video, an on-device transcript of that video — and print a
# wiki-ingest-ready markdown doc to stdout (mirrors the yt-fetch/defuddle
# contract — caller redirects it).
#
#   x-fetch.sh <x-post-url>            # -> stdout
#   x-fetch.sh <x-post-url> > .raw/posts/slug.md
#
# Requires: yt-dlp (its X extractor supplies the post text + metadata, not just
#           video — this is the same "youtube" feature yt-fetch uses), python3.
# Optional: whisperkit-cli (the "voice" feature) — transcribes video posts
#           fully on-device. Without it a video post still lands as text +
#           metadata, with a warning callout where the transcript would go.
#
# Environment knobs (no script edit ever needed):
#   X_FETCH_COOKIES_BROWSER=firefox[:profile]      OPT-IN ONLY, set by the user, never
#                                                  by the agent: reuse a browser's
#                                                  logged-in X session for posts that
#                                                  refuse anonymous access. Default
#                                                  runs are anonymous — no browser,
#                                                  no cookies, no dialogs.
#   X_FETCH_TRANSCRIBE=0                           post text only, skip any video
#   VOICE_FETCH_MODEL=<model>                      pin the WhisperKit model (same
#                                                  variable voice-fetch honors)
set -euo pipefail
# Preserve caller-provided shims first (tests and managed environments), then
# add the standard macOS install locations.
export PATH="$PATH:$HOME/.local/bin:/opt/homebrew/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "usage: x-fetch.sh <x-post-url>" >&2
  exit 2
fi
# The URL can originate from untrusted content (a prompt-injected page telling
# the agent to "fetch" something). Require a real http(s) URL so a dash-prefixed
# argument can't smuggle yt-dlp options (--config-location/--exec = code exec),
# and require the X post shape so this stays an X adapter, not a generic downloader.
case "$URL" in
  http://*|https://*) ;;
  *) echo "error: not an http(s) URL: $URL" >&2; exit 2 ;;
esac
STATUS_ID="$(printf '%s' "$URL" \
  | sed -nE 's#^https?://((www|m|mobile)\.)?(x|twitter)\.com/([^/?#]+/status|i/web/status|statuses)/([0-9]+)([/?#].*)?$#\5#p')"
if [ -z "$STATUS_ID" ]; then
  echo "error: not an X / Twitter post URL: $URL" >&2
  echo "expected: https://x.com/<user>/status/<id>   (twitter.com works too)" >&2
  exit 2
fi
# Opt-in only: reuse a browser's logged-in X session. The value is restricted to
# yt-dlp's browser names plus an optional profile NAME — yt-dlp's own syntax also
# accepts a profile *path*, which would let an injected value point it at an
# arbitrary file, so slashes are refused. Validated here, with the other
# arguments, before anything runs; only the user ever sets it.
if [ -n "${X_FETCH_COOKIES_BROWSER:-}" ]; then
  case "$X_FETCH_COOKIES_BROWSER" in
    brave|chrome|chromium|edge|firefox|opera|safari|vivaldi|whale) ;;
    brave:*|chrome:*|chromium:*|edge:*|firefox:*|opera:*|safari:*|vivaldi:*|whale:*)
      case "${X_FETCH_COOKIES_BROWSER#*:}" in
        */*|*..*|'') echo "error: X_FETCH_COOKIES_BROWSER profile must be a name, not a path: $X_FETCH_COOKIES_BROWSER" >&2; exit 2 ;;
      esac ;;
    *) echo "error: X_FETCH_COOKIES_BROWSER must be a browser name (firefox, chrome, safari, …) optionally followed by :profile — got: $X_FETCH_COOKIES_BROWSER" >&2; exit 2 ;;
  esac
fi
if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "yt-dlp not installed. Run: brew install yt-dlp" >&2
  echo "(or enable the YouTube/X feature: bash bin/setup-features.sh youtube)" >&2
  exit 3
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/meta" "$TMP/media" "$TMP/tx"

# All yt-dlp chatter goes to stderr so stdout stays clean markdown.
COMMON_OPTS=(
  --retries 3 --extractor-retries 3 --sleep-requests 1
  --no-warnings --no-progress --quiet
)
if [ -n "${X_FETCH_COOKIES_BROWSER:-}" ]; then
  echo "note: using the logged-in X session from $X_FETCH_COOKIES_BROWSER (opt-in); requests are made as that account." >&2
  COMMON_OPTS+=(--cookies-from-browser "$X_FETCH_COOKIES_BROWSER")
fi

# Pass 1 — metadata only. yt-dlp's X extractor errors on a post with no video
# ("No video could be found in this tweet"); --ignore-no-formats-error turns
# that into an ordinary info.json that still carries the post text
# (description), author, date, and canonical URL — exactly what we need.
# A multi-video post yields one playlist info.json plus one per clip.
META_OPTS=(
  "${COMMON_OPTS[@]}"
  --skip-download --write-info-json --ignore-no-formats-error
  -o "$TMP/meta/%(id)s.%(ext)s"
)
if ! yt-dlp "${META_OPTS[@]}" -- "$URL" 1>&2; then
  echo "yt-dlp failed for: $URL" >&2
  echo "Deleted posts can't be fetched. Protected or age-restricted posts need a logged-in" >&2
  echo "session: the USER can opt in with X_FETCH_COOKIES_BROWSER=firefox (see the skill's" >&2
  echo "'Logged-in fetches' notes — agents must not set it on their own)." >&2
  if [ -n "${X_FETCH_COOKIES_BROWSER:-}" ]; then
    echo "Cookies were in use. If X answered 'captcha' or 'suspicious', stop and open X in the" >&2
    echo "browser to clear the check; if Chrome hung, a macOS Keychain dialog is waiting; if Safari" >&2
    echo "said permission denied, the terminal needs Full Disk Access." >&2
  fi
  exit 4
fi
if ! ls "$TMP"/meta/*.info.json >/dev/null 2>&1; then
  echo "yt-dlp produced no metadata for: $URL" >&2
  exit 5
fi

# Pass 2 — video posts: pull the smallest mp4 that still carries audio and
# transcribe it on-device. Progressive (http) mp4 is preferred over HLS so no
# ffmpeg is needed; lowest resolution because only the audio matters. Media
# lives in the temp dir only and is removed on exit — nothing lands in .raw/.
VIDEO_IDS="$(python3 "$SCRIPT_DIR/x_emit.py" --videos "$TMP/meta")"
if [ -n "$VIDEO_IDS" ] && [ "${X_FETCH_TRANSCRIBE:-1}" != 0 ]; then
  if command -v whisperkit-cli >/dev/null 2>&1; then
    DL_OPTS=(
      "${COMMON_OPTS[@]}"
      -f 'b[ext=mp4][acodec!=none]/b[acodec!=none]/b' -S '+res'
      -o "$TMP/media/%(id)s.%(ext)s"
    )
    if yt-dlp "${DL_OPTS[@]}" -- "$URL" 1>&2; then
      for f in "$TMP"/media/*; do
        [ -f "$f" ] || continue
        id="$(basename "${f%.*}")"
        WK_OPTS=( transcribe --audio-path "$f" )
        [ -n "${VOICE_FETCH_MODEL:-}" ] && WK_OPTS+=( --model "$VOICE_FETCH_MODEL" )
        # WhisperKit prints the transcription to stdout; progress and any
        # one-time model download go to stderr on their own.
        if ! whisperkit-cli "${WK_OPTS[@]}" > "$TMP/tx/$id.txt"; then
          echo "warning: whisperkit-cli failed on video $id — its transcript will be missing." >&2
          echo "If this is the first run, the model download may have been interrupted; re-run to resume." >&2
          rm -f "$TMP/tx/$id.txt"
        fi
      done
    else
      echo "warning: video download failed — emitting the post text without a transcript." >&2
    fi
  else
    echo "note: this post carries video, but whisperkit-cli (the Voice feature) is not installed —" >&2
    echo "emitting post text + metadata only. Enable Voice via /secondbrain (brew install whisperkit-cli)." >&2
  fi
fi

python3 "$SCRIPT_DIR/x_emit.py" "$TMP/meta" "$TMP/tx" "$STATUS_ID"
