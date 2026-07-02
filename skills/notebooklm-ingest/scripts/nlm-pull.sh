#!/usr/bin/env bash
# notebooklm pull: selectively pull ONE existing NotebookLM notebook's report
# into .raw/notebooklm/ as a wiki-ingest-ready markdown doc. Complements
# nlm-ingest.sh (which creates a new notebook) — this one targets a notebook you
# already curated in the NotebookLM UI.
#
#   nlm-pull.sh <notebook-id-or-name> [--fresh]
#
#   --fresh   regenerate the report before downloading (default: reuse the
#             latest existing report; only generate if none exists yet).
#
# Prints the produced .raw file path on success.
# Requires: notebooklm (notebooklm-py), python3, and a completed `notebooklm login`.
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SELECTOR=""
FRESH=0
for arg in "$@"; do
  case "$arg" in
    --fresh) FRESH=1 ;;
    -*) echo "unknown flag: $arg" >&2; exit 2 ;;
    *) [ -z "$SELECTOR" ] && SELECTOR="$arg" || { echo "unexpected arg: $arg" >&2; exit 2; } ;;
  esac
done
if [ -z "$SELECTOR" ]; then
  echo 'usage: nlm-pull.sh <notebook-id-or-name> [--fresh]' >&2
  exit 2
fi
if ! command -v notebooklm >/dev/null 2>&1; then
  echo "notebooklm not installed. Run: uv tool install notebooklm-py" >&2
  exit 3
fi
if ! notebooklm list >/dev/null 2>&1; then
  echo "NotebookLM is not authenticated. Run once:  notebooklm login" >&2
  exit 4
fi

# Resolve selector -> unique notebook id.
NB_ID="$(notebooklm list --json | python3 "$SCRIPT_DIR/resolve_nb.py" "$SELECTOR")" || exit 5
echo "==> Notebook: $NB_ID" >&2

# Pull title + real source list from metadata.
mapfile -t META < <(notebooklm metadata -n "$NB_ID" --json | python3 "$SCRIPT_DIR/nb_meta.py")
SLUG="${META[0]:-notebooklm}"
TITLE="${META[1]:-$SELECTOR}"
SOURCES=("${META[@]:2}")

# Decide reuse vs. regenerate.
NEED_GEN=$FRESH
if [ "$NEED_GEN" -eq 0 ]; then
  N_REPORTS="$(notebooklm artifact list -n "$NB_ID" --type report --json 2>/dev/null \
               | python3 "$SCRIPT_DIR/count_reports.py")"
  [ "${N_REPORTS:-0}" -eq 0 ] && NEED_GEN=1
fi
if [ "$NEED_GEN" -eq 1 ]; then
  echo "==> Generating a fresh report (blocking)..." >&2
  notebooklm generate report "$TITLE" -n "$NB_ID" --wait 1>&2
else
  echo "==> Reusing latest existing report (pass --fresh to regenerate)." >&2
fi

DATE="$(date +%Y-%m-%d)"
OUTDIR=".raw/notebooklm"
mkdir -p "$OUTDIR"
OUT="$OUTDIR/${SLUG}-${DATE}.md"
BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT

echo "==> Downloading report markdown..." >&2
notebooklm download report "$BODY" -n "$NB_ID" --force 1>&2

{
  echo "---"
  echo "source_type: research-report"
  printf 'title: "%s"\n' "${TITLE//\"/\'}"
  echo "fetched: $DATE"
  echo "notebook_id: $NB_ID"
  if [ "${#SOURCES[@]}" -gt 0 ]; then
    echo "sources:"
    for s in "${SOURCES[@]}"; do
      [ -n "$s" ] && printf '  - "%s"\n' "$s"
    done
  fi
  echo "tags:"
  echo "  - source"
  echo "  - notebooklm"
  echo "---"
  echo ""
  cat "$BODY"
} > "$OUT"

echo "$OUT"
