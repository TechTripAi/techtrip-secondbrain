#!/usr/bin/env bash
# voice-fetch: transcribe a local audio file (Voice Memos .m4a, mp3, wav, …)
# on-device via WhisperKit and print a wiki-ingest-ready markdown doc to stdout
# (mirrors the yt-fetch/defuddle contract — caller redirects it).
#
#   voice-fetch.sh <audio-file>            # -> stdout
#   voice-fetch.sh <audio-file> > .raw/audio/slug.md
#
# Requires: whisperkit-cli (brew install whisperkit-cli).
# Optional: VOICE_FETCH_MODEL to pin a WhisperKit model (default: CLI default,
# downloaded once on first run, fully local thereafter).
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"

FILE="${1:-}"
if [ -z "$FILE" ]; then
  echo "usage: voice-fetch.sh <audio-file>" >&2
  exit 2
fi
# The path can originate from untrusted content (a prompt-injected page telling
# the agent to "transcribe" something). Refuse dash-prefixed args so nothing can
# smuggle whisperkit-cli options, and require a real file.
case "$FILE" in
  -*) echo "error: not a file path: $FILE" >&2; exit 2 ;;
esac
if [ ! -f "$FILE" ]; then
  echo "error: no such file: $FILE" >&2
  exit 2
fi
case "$FILE" in
  *.m4a|*.mp3|*.wav|*.aiff|*.aif|*.flac|*.mp4|*.mov|*.caf|*.ogg|*.opus|*.webm) ;;
  *) echo "error: unrecognized audio extension: $FILE" >&2
     echo "supported: m4a mp3 wav aiff flac mp4 mov caf ogg opus webm" >&2
     exit 2 ;;
esac
if ! command -v whisperkit-cli >/dev/null 2>&1; then
  echo "whisperkit-cli not installed. Run: brew install whisperkit-cli" >&2
  echo "(or enable the voice feature: bash bin/setup-features.sh voice)" >&2
  exit 3
fi

# Metadata from the file itself: title from the basename, recorded date from
# the file's modification time (Voice Memos stamps this with the recording time).
BASE="$(basename "$FILE")"
TITLE="${BASE%.*}"
RECORDED="$(stat -f '%Sm' -t '%Y-%m-%d' -- "$FILE" 2>/dev/null || date +%Y-%m-%d)"
FETCHED="$(date +%Y-%m-%d)"

WK_OPTS=( transcribe --audio-path "$FILE" )
[ -n "${VOICE_FETCH_MODEL:-}" ] && WK_OPTS+=( --model "$VOICE_FETCH_MODEL" )

# WhisperKit prints the transcription to stdout; progress/model-download chatter
# goes to stderr on its own. Capture the text so stdout stays clean markdown.
# First run may download a CoreML model (large, one-time, then fully local).
if ! TRANSCRIPT="$(whisperkit-cli "${WK_OPTS[@]}")"; then
  echo "whisperkit-cli failed for: $FILE" >&2
  echo "If this is the first run, the model download may have been interrupted —" >&2
  echo "re-run to resume. Check available disk space and network." >&2
  exit 4
fi

# Collapse leading/trailing blank lines; warn (stderr) if the result is empty.
TRANSCRIPT="$(printf '%s\n' "$TRANSCRIPT" | sed -e 's/[[:space:]]*$//')"
if [ -z "$(printf '%s' "$TRANSCRIPT" | tr -d '[:space:]')" ]; then
  echo "warning: empty transcription (silent audio, or unsupported speech) — emitting metadata only" >&2
fi

cat <<EOF
---
title: "$TITLE"
source_type: transcript
source_file: "$BASE"
date_recorded: $RECORDED
fetched: $FETCHED
transcriber: whisperkit-cli (on-device)
---

# $TITLE

$TRANSCRIPT
EOF
