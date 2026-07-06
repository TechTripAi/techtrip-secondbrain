#!/usr/bin/env bash
# notebooklm-ingest: create a NotebookLM notebook from one or more source URLs,
# generate a synthesis report, and land it in .raw/notebooklm/ as a
# wiki-ingest-ready markdown doc. Eliminates the manual "copy the deliverable
# out of the NotebookLM UI into Obsidian" step.
#
#   nlm-ingest.sh "<topic>" <url1> [url2 ...]
#
# Prints the path of the produced .raw file to stdout on success.
# Requires: notebooklm (notebooklm-py), python3, and a completed
#   `notebooklm login` (auth is the user's one-time step).
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOPIC="${1:-}"
if [ -z "$TOPIC" ]; then
  echo 'usage: nlm-ingest.sh "<topic>" <url1> [url2 ...]' >&2
  exit 2
fi
shift
if [ "$#" -lt 1 ]; then
  echo "need at least one source URL" >&2
  exit 2
fi
if ! command -v notebooklm >/dev/null 2>&1; then
  echo "notebooklm not installed. Run: uv tool install notebooklm-py" >&2
  exit 3
fi

# Auth guard — `list` fails (nonzero) when not logged in.
if ! notebooklm list >/dev/null 2>&1; then
  echo "NotebookLM is not authenticated. Run once:  notebooklm login" >&2
  exit 4
fi

# Tolerant id extraction from any --json payload (reads stdin — kept in its own
# helper file so the heredoc program source can't collide with the piped JSON).
extract_id() { python3 "$SCRIPT_DIR/find_id.py"; }

# Emit $1 as a safely escaped YAML double-quoted scalar (collapses newlines,
# escapes quotes/backslashes) so untrusted text can't break out of frontmatter.
yaml_str() { python3 -c 'import json,sys; print(json.dumps(" ".join(sys.argv[1].split())))' "$1"; }

DATE="$(date +%Y-%m-%d)"
SLUG="$(printf '%s' "$TOPIC" | tr '[:upper:]' '[:lower:]' \
        | tr -cs 'a-z0-9' '-' | sed 's/^-*//; s/-*$//')"
[ -z "$SLUG" ] && SLUG="notebooklm"
OUTDIR=".raw/notebooklm"
mkdir -p "$OUTDIR"
OUT="$OUTDIR/${SLUG}-${DATE}.md"

echo "==> Creating notebook: $TOPIC" >&2
NB_ID="$(notebooklm create "$TOPIC" --json | extract_id)"
if [ -z "$NB_ID" ]; then
  echo "failed to create notebook (could not parse id)" >&2
  exit 5
fi
echo "    notebook id: $NB_ID" >&2

for u in "$@"; do
  echo "==> Adding source: $u" >&2
  notebooklm source add "$u" -n "$NB_ID" 1>&2
done

echo "==> Generating report (blocking until done)..." >&2
notebooklm generate report "$TOPIC" -n "$NB_ID" --wait 1>&2

echo "==> Downloading report markdown..." >&2
BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT
notebooklm download report "$BODY" -n "$NB_ID" --force 1>&2

# Prepend wiki-ingest frontmatter, then the report body.
{
  echo "---"
  echo "source_type: research-report"
  printf 'title: %s\n' "$(yaml_str "$TOPIC")"
  echo "fetched: $DATE"
  echo "notebook_id: $NB_ID"
  echo "sources:"
  for u in "$@"; do
    printf '  - %s\n' "$(yaml_str "$u")"
  done
  echo "tags:"
  echo "  - source"
  echo "  - notebooklm"
  echo "---"
  echo ""
  cat "$BODY"
} > "$OUT"

echo "$OUT"
