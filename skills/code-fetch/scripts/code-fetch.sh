#!/usr/bin/env bash
# code-fetch: minimize a codebase (local path or git URL) into ONE
# wiki-ingest-ready markdown digest on stdout (mirrors the defuddle/yt-fetch
# contract — caller redirects it). Ingesting a codebase file-by-file is the
# anti-pattern this exists to prevent: graphify's local AST pass distills
# thousands of files into a structural digest the wiki can actually hold.
#
#   code-fetch.sh <local-path|git-url>            # -> stdout
#   code-fetch.sh <local-path|git-url> > .raw/code/slug.md
#
# Requires: graphify (uv tool install graphifyy), git (for URL sources).
# Analysis is 100% local (tree-sitter AST, --code-only): no API key, no LLM
# call, no data egress. Clones and graph workdirs live in temp dirs and are
# deleted on exit — only the digest markdown survives.
#
# graphify by Graphify-Labs (Apache-2.0): https://github.com/Graphify-Labs/graphify
#
# Env knobs (never edit this shipped script):
#   CODE_FETCH_BRANCH=<branch>   clone a specific branch for git-URL sources
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "usage: code-fetch.sh <local-path|git-url>" >&2
  exit 2
fi
# The target can originate from untrusted content (a prompt-injected page
# telling the agent to "ingest" something). Refuse dash-prefixed arguments so
# nothing can smuggle options into git/graphify.
case "$TARGET" in
  -*) echo "error: refusing option-like argument: $TARGET" >&2; exit 2 ;;
esac

if ! command -v graphify >/dev/null 2>&1; then
  echo "graphify not installed. Run: uv tool install graphifyy" >&2
  echo "(or re-run /secondbrain to enable the Code feature; git-clone users can" >&2
  echo " also run: bash bin/setup-features.sh code)" >&2
  exit 3
fi

CLEANUP_DIRS=()
cleanup() {
  # Guarded so an empty array can't turn the EXIT trap into a bogus exit 1.
  if [ "${#CLEANUP_DIRS[@]}" -gt 0 ]; then rm -rf "${CLEANUP_DIRS[@]}"; fi
}
trap cleanup EXIT

# ── Resolve source: git URL -> shallow clone into temp; path -> as-is ────────
SOURCE_URL="" SOURCE_PATH=""
case "$TARGET" in
  http://*|https://*|git@*|ssh://*)
    command -v git >/dev/null 2>&1 || { echo "git required for URL sources" >&2; exit 3; }
    SOURCE_URL="$TARGET"
    CLONE_DIR="$(mktemp -d)"; CLEANUP_DIRS+=("$CLONE_DIR")
    CLONE_OPTS=(--depth 1 --quiet)
    [ -n "${CODE_FETCH_BRANCH:-}" ] && CLONE_OPTS+=(--branch "$CODE_FETCH_BRANCH")
    if ! git clone "${CLONE_OPTS[@]}" -- "$TARGET" "$CLONE_DIR/repo" 1>&2; then
      echo "git clone failed for: $TARGET" >&2
      exit 4
    fi
    SRC="$CLONE_DIR/repo"
    ;;
  *)
    if [ ! -d "$TARGET" ]; then
      echo "error: not a directory or recognized git URL: $TARGET" >&2
      exit 2
    fi
    SRC="$(cd "$TARGET" && pwd)"
    SOURCE_PATH="$SRC"
    ;;
esac

NAME="$(basename "$SRC")"
[ "$NAME" = repo ] && [ -n "$SOURCE_URL" ] && NAME="$(basename "$SOURCE_URL" .git)"
# Strip double quotes so the value can't break the double-quoted YAML fields.
NAME="${NAME//\"/}"
COMMIT="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null || true)"

# ── Run graphify headlessly: local AST only, no LLM, no API key ──────────────
WORK="$(mktemp -d)"; CLEANUP_DIRS+=("$WORK")
if ! graphify extract "$SRC" --code-only --out "$WORK" 1>&2; then
  echo "graphify extract failed for: $SRC" >&2
  exit 5
fi
# --no-label keeps deterministic placeholders instead of an LLM naming pass;
# --no-viz skips the graph.html nobody will see. Report only.
graphify cluster-only "$WORK" --no-label --no-viz 1>&2 || true
REPORT="$WORK/graphify-out/graphify-out/GRAPH_REPORT.md"
[ -f "$REPORT" ] || REPORT="$WORK/graphify-out/GRAPH_REPORT.md"
if [ ! -f "$REPORT" ]; then
  echo "graphify produced no GRAPH_REPORT.md under $WORK" >&2
  exit 5
fi

# ── Metadata: file count + top languages by extension ────────────────────────
list_files() {
  git -C "$SRC" ls-files 2>/dev/null \
    || (cd "$SRC" && find . -type f -not -path '*/.git/*' | sed 's|^\./||')
}
FILE_COUNT="$(list_files | wc -l | tr -d ' ')"
LANGS="$(list_files | awk -F. 'NF>1 && $NF !~ /\// {print tolower($NF)}' \
  | sort | uniq -c | sort -rn | head -6 \
  | awk '{printf "%s%s (%s)", sep, $2, $1; sep=", "} END {print ""}')"

# ── Emit digest to stdout ─────────────────────────────────────────────────────
printf -- '---\n'
printf 'title: "%s — codebase digest"\n' "$NAME"
printf 'source_type: codebase\n'
[ -n "$SOURCE_URL" ]  && printf 'source_url: "%s"\n' "$SOURCE_URL"
[ -n "$SOURCE_PATH" ] && printf 'source_path: "%s"\n' "$SOURCE_PATH"
[ -n "$COMMIT" ]      && printf 'commit: "%s"\n' "$COMMIT"
printf 'file_count: %s\n' "$FILE_COUNT"
[ -n "$LANGS" ] && printf 'languages: "%s"\n' "$LANGS"
printf 'fetched: %s\n' "$(date +%Y-%m-%d)"
printf 'generator: "graphify (Graphify-Labs, Apache-2.0)"\n'
printf -- '---\n\n'

printf '# %s — codebase digest\n\n' "$NAME"
printf '> Structural digest produced by graphify (local tree-sitter AST, no LLM).\n'
printf '> This is the context of the codebase, not the code: ingest THIS page,\n'
printf '> never the repository files themselves.\n\n'

# Top-level layout for orientation (directories only, two levels, capped).
# grep exits 1 on flat repos with no subdirectories — don't let pipefail kill us.
printf '## Layout\n\n```\n'
(cd "$SRC" && find . -maxdepth 2 -type d \
    -not -path '*/.git*' -not -path '*/node_modules*' -not -path '*/.venv*' \
  | sed 's|^\./||' | grep -v '^\.$' | sort | head -40) || printf '(flat — no subdirectories)\n'
printf '```\n\n'

# README first lines, when present — the author's own framing of the project.
README="$(find "$SRC" -maxdepth 1 -iname 'readme.md' | head -1 || true)"
if [ -n "$README" ]; then
  printf '## README (excerpt)\n\n'
  # Demote the README's own headings so they don't compete with digest sections.
  head -40 "$README" | sed 's/^#/###/'
  printf '\n'
fi

# Pull the load-bearing report sections; skip the temp-path header, the
# freshness boilerplate, the unlabeled community listings, and Suggested
# Questions (placeholder "Community N" names — noise without the LLM pass).
awk '
  /^## (Summary|God Nodes|Surprising Connections|Import Cycles)/ {keep=1}
  /^## (Corpus Check|Graph Freshness|Community Hubs|Communities|Suggested Questions)/ {keep=0}
  keep {print}
' "$REPORT" | awk '
  /^## Import Cycles/ {cycles=1; n=0}
  /^## / && !/^## Import Cycles/ {cycles=0}
  cycles && /^- / { n++; if (n==16) {print "- … (more cycles omitted)"}; if (n>=16) next }
  {print}
'
