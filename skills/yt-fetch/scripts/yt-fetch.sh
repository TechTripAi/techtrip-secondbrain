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
# Optional: honor cookies for age/region-restricted videos.
[ -n "${YT_FETCH_COOKIES_BROWSER:-}" ] && YTDLP_OPTS+=(--cookies-from-browser "$YT_FETCH_COOKIES_BROWSER")

if ! yt-dlp "${YTDLP_OPTS[@]}" -- "$URL" 1>&2; then
  echo "yt-dlp failed for: $URL" >&2
  echo "If this is HTTP 429 (rate limit), wait a few minutes and retry, or set" >&2
  echo "  YT_FETCH_COOKIES_BROWSER=chrome  to authenticate the requests." >&2
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
