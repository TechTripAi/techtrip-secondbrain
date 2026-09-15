#!/usr/bin/env bash
# yt-fetch: fetch a YouTube transcript + metadata and print a wiki-ingest-ready
# markdown doc to stdout (mirrors the defuddle contract — caller redirects it).
#
#   yt-fetch.sh <youtube-url>            # -> stdout
#   yt-fetch.sh <youtube-url> > .raw/videos/slug.md
#
# Requires: yt-dlp, python3.
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "usage: yt-fetch.sh <youtube-url>" >&2
  exit 2
fi
# The URL can originate from untrusted content (a prompt-injected page telling
# the agent to "fetch" something). Require a real http(s) URL so a dash-prefixed
# argument can't smuggle yt-dlp options (--config-location/--exec = code exec).
case "$URL" in
  http://*|https://*) ;;
  *) echo "error: not an http(s) URL: $URL" >&2; exit 2 ;;
esac
# Opt-in only: reuse a browser's logged-in YouTube session. The value is
# restricted to yt-dlp's browser names plus an optional profile NAME — yt-dlp's
# own syntax also accepts a profile *path*, which would let an injected value
# point it at an arbitrary file, so slashes are refused. Validated here, with
# the other arguments, before anything runs; only the user ever sets it.
if [ -n "${YT_FETCH_COOKIES_BROWSER:-}" ]; then
  case "$YT_FETCH_COOKIES_BROWSER" in
    brave|chrome|chromium|edge|firefox|opera|safari|vivaldi|whale) ;;
    brave:*|chrome:*|chromium:*|edge:*|firefox:*|opera:*|safari:*|vivaldi:*|whale:*)
      case "${YT_FETCH_COOKIES_BROWSER#*:}" in
        */*|*..*|'') echo "error: YT_FETCH_COOKIES_BROWSER profile must be a name, not a path: $YT_FETCH_COOKIES_BROWSER" >&2; exit 2 ;;
      esac ;;
    *) echo "error: YT_FETCH_COOKIES_BROWSER must be a browser name (firefox, chrome, safari, …) optionally followed by :profile — got: $YT_FETCH_COOKIES_BROWSER" >&2; exit 2 ;;
  esac
fi
if ! command -v yt-dlp >/dev/null 2>&1; then
  echo "yt-dlp not installed. Run: brew install yt-dlp" >&2
  exit 3
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# All yt-dlp chatter goes to stderr so stdout stays clean markdown.
# Language is restricted to the ORIGINAL English track ("en", "en-orig") — the
# "en.*" wildcard also matches auto-TRANSLATED tracks (en-bn, en-fr, ...), which
# multiplies subtitle requests and quickly trips YouTube's 429 rate limit.
# Retries + request spacing further blunt 429s.
YTDLP_OPTS=(
  --skip-download
  --write-auto-sub --write-sub
  --sub-lang "en,en-orig,en-US"
  --sub-format vtt
  --write-info-json
  --retries 3 --extractor-retries 3 --sleep-requests 1
  --no-warnings --no-progress --quiet
  -o "$TMP/%(id)s.%(ext)s"
)
# Opt-in only (validated above): reuse a browser's logged-in YouTube session.
if [ -n "${YT_FETCH_COOKIES_BROWSER:-}" ]; then
  echo "note: using the logged-in YouTube session from $YT_FETCH_COOKIES_BROWSER (opt-in); requests are made as that account." >&2
  YTDLP_OPTS+=(--cookies-from-browser "$YT_FETCH_COOKIES_BROWSER")
fi

if ! yt-dlp "${YTDLP_OPTS[@]}" -- "$URL" 1>&2; then
  echo "yt-dlp failed for: $URL" >&2
  echo "If this is HTTP 429 (rate limit), wait a few minutes and retry — do NOT reach for" >&2
  echo "cookies to get past it (logged-in limits are per account, and yt-dlp warns that" >&2
  echo "cookies with YouTube risk the account). Age-gated / members-only videos are the one" >&2
  echo "case for the USER to opt in with YT_FETCH_COOKIES_BROWSER=firefox (see the skill's" >&2
  echo "'Logged-in fetches' notes — agents must not set it on their own)." >&2
  if [ -n "${YT_FETCH_COOKIES_BROWSER:-}" ]; then
    echo "Cookies were in use. If Chrome hung, a macOS Keychain dialog is waiting; if Safari" >&2
    echo "said permission denied, the terminal needs Full Disk Access." >&2
  fi
  exit 4
fi

INFO="$(ls "$TMP"/*.info.json 2>/dev/null | head -1 || true)"
if [ -z "$INFO" ]; then
  echo "yt-dlp produced no metadata for: $URL" >&2
  exit 5
fi
# Prefer a manual/en subtitle track; fall back to whatever .vtt exists.
VTT="$(ls "$TMP"/*.en.vtt 2>/dev/null | head -1 || true)"
[ -z "$VTT" ] && VTT="$(ls "$TMP"/*.vtt 2>/dev/null | head -1 || true)"

python3 "$SCRIPT_DIR/yt_emit.py" "$INFO" "$VTT"
