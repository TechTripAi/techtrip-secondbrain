#!/usr/bin/env bash
# code-fetch: stage a codebase (local path or git URL) for the agent's reading
# pass. This script is the MECHANICAL half only — it resolves the source
# (shallow clone for URLs, in-place read-only for local paths) and prints an
# INVENTORY to stdout: ready-to-use digest frontmatter, directory layout,
# language stats, high-signal files (manifests / entry points / API specs),
# and the README. The agent then reads the code itself and writes the
# semantic digest to .raw/code/<slug>.md — this script never analyzes code.
#
#   code-fetch.sh <local-path|git-url>     # stage + print inventory
#   code-fetch.sh cleanup <workdir>        # remove a temp clone made above
#
# Requires: git (a core dependency — for URL sources). No other runtime:
# comprehension is the agent's job, so there is nothing to install.
#
# For URL sources the clone lands in a PERSISTENT temp workdir (printed in the
# inventory) so the agent can read files from it; run the cleanup subcommand
# when the digest is written. Local paths are used in place and never cleaned.
#
# Env knobs (never edit this shipped script):
#   CODE_FETCH_BRANCH=<branch>   clone a specific branch for git-URL sources
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"

WORKDIR_MARKER=".code-fetch-workdir"

# ── cleanup subcommand: remove a temp workdir this script created ────────────
if [ "${1:-}" = "cleanup" ]; then
  WD="${2:-}"
  if [ -z "$WD" ]; then echo "usage: code-fetch.sh cleanup <workdir>" >&2; exit 2; fi
  # Only delete dirs we provably created (marker file), never arbitrary paths.
  if [ ! -f "$WD/$WORKDIR_MARKER" ]; then
    echo "error: $WD is not a code-fetch workdir (no $WORKDIR_MARKER marker) — refusing to delete" >&2
    exit 2
  fi
  rm -rf -- "$WD"
  echo "removed $WD" >&2
  exit 0
fi

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "usage: code-fetch.sh <local-path|git-url>  |  code-fetch.sh cleanup <workdir>" >&2
  exit 2
fi
# The target can originate from untrusted content (a prompt-injected page
# telling the agent to "ingest" something). Refuse dash-prefixed arguments so
# nothing can smuggle options into git.
case "$TARGET" in
  -*) echo "error: refusing option-like argument: $TARGET" >&2; exit 2 ;;
esac

# ── Resolve source: git URL -> shallow clone into persistent temp; path as-is ─
SOURCE_URL="" SOURCE_PATH="" WORKDIR=""
case "$TARGET" in
  http://*|https://*|git@*|ssh://*)
    command -v git >/dev/null 2>&1 || { echo "git required for URL sources" >&2; exit 3; }
    SOURCE_URL="$TARGET"
    WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/code-fetch.XXXXXX")"
    : > "$WORKDIR/$WORKDIR_MARKER"
    CLONE_OPTS=(--depth 1 --quiet)
    [ -n "${CODE_FETCH_BRANCH:-}" ] && CLONE_OPTS+=(--branch "$CODE_FETCH_BRANCH")
    if ! git clone "${CLONE_OPTS[@]}" -- "$TARGET" "$WORKDIR/repo" 1>&2; then
      rm -rf -- "$WORKDIR"
      echo "git clone failed for: $TARGET" >&2
      exit 4
    fi
    SRC="$WORKDIR/repo"
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

# ── File listing (git-aware; falls back to find, skipping vendored dirs) ─────
# In a git repo, ls-files deliberately shows tracked files only — untracked
# files are unreviewed scratch; the inventory reflects what the repo intends.
list_files() {
  git -C "$SRC" ls-files 2>/dev/null \
    || (cd "$SRC" && find . -type f \
          -not -path '*/.git/*' -not -path '*/node_modules/*' \
          -not -path '*/.venv/*' -not -path '*/vendor/*' \
        | sed 's|^\./||')
}
FILES="$(list_files)"
FILE_COUNT="$(printf '%s\n' "$FILES" | sed '/^$/d' | wc -l | tr -d ' ')"
LANGS="$(printf '%s\n' "$FILES" | awk -F. 'NF>1 && $NF !~ /\// {print tolower($NF)}' \
  | sort | uniq -c | sort -rn | head -6 \
  | awk '{printf "%s%s (%s)", sep, $2, $1; sep=", "} END {print ""}')"

# ── Emit inventory to stdout ──────────────────────────────────────────────────
echo "# code-fetch inventory: $NAME"
echo
echo "Source root (read files from here): $SRC"
if [ -n "$WORKDIR" ]; then
  echo "Temp workdir (REMOVE after the digest is written):"
  echo "  code-fetch.sh cleanup $WORKDIR"
else
  echo "Local path used in place — read-only, nothing to clean up."
fi
echo

echo "## Frontmatter (paste into the digest as-is)"
echo
printf -- '---\n'
printf 'title: "%s — codebase digest"\n' "$NAME"
printf 'source_type: codebase\n'
[ -n "$SOURCE_URL" ]  && printf 'source_url: "%s"\n' "$SOURCE_URL"
[ -n "$SOURCE_PATH" ] && printf 'source_path: "%s"\n' "$SOURCE_PATH"
[ -n "$COMMIT" ]      && printf 'commit: "%s"\n' "$COMMIT"
printf 'file_count: %s\n' "$FILE_COUNT"
[ -n "$LANGS" ] && printf 'languages: "%s"\n' "$LANGS"
printf 'fetched: %s\n' "$(date +%Y-%m-%d)"
printf -- '---\n\n'

# Top-level layout for orientation (directories only, two levels, capped).
# Pipelines are captured into variables and the fallback printed only when the
# result is empty: an "|| fallback" on the pipeline itself would ALSO fire on a
# head-induced SIGPIPE in a large repo (pipefail), appending the fallback after
# real output. The trailing "|| true" absorbs both that SIGPIPE and grep's
# exit-1 on flat repos with no subdirectories.
echo "## Layout (directories, 2 levels, capped)"
echo
LAYOUT="$( (cd "$SRC" && find . -maxdepth 2 -type d \
    -not -path '*/.git*' -not -path '*/node_modules*' -not -path '*/.venv*' \
    -not -path '*/vendor*' ) \
  | sed 's|^\./||' | grep -v '^\.$' | sort | head -60 || true)"
printf '```\n'
if [ -n "$LAYOUT" ]; then printf '%s\n' "$LAYOUT"; else printf '(flat — no subdirectories)\n'; fi
printf '```\n\n'

echo "## High-signal files (read these first)"
echo
# Build manifests, entry points, API specs, CI, docs — the priority reading list.
HIGH_SIGNAL="$(printf '%s\n' "$FILES" | grep -Ei \
  '(^|/)(readme[^/]*|package\.json|pyproject\.toml|setup\.(py|cfg)|requirements[^/]*\.txt|cargo\.toml|go\.mod|pom\.xml|build\.gradle[^/]*|makefile|justfile|dockerfile[^/]*|docker-compose[^/]*|gemfile|composer\.json|[^/]*\.csproj|[^/]*\.sln|main\.[a-z]+|index\.[a-z]+|app\.[a-z]+|cli\.[a-z]+|__main__\.py|server\.[a-z]+|manifest\.json)$|(^|/)(openapi|swagger)[^/]*\.(ya?ml|json)$|\.(proto|graphql|graphqls)$|(^|/)\.github/workflows/[^/]+$|(^|/)cmd/[^/]+/main\.go$' \
  | sort | head -40 || true)"
echo '```'
if [ -n "$HIGH_SIGNAL" ]; then printf '%s\n' "$HIGH_SIGNAL"; else echo '(none matched — start from the layout above)'; fi
echo '```'
echo

echo "## Largest source files (core-module candidates, by line count)"
echo
echo '```'
# Skip lockfiles/minified/data blobs; they are size without signal. The final
# awk keeps everything after the count so paths with spaces stay intact.
printf '%s\n' "$FILES" | grep -Ev \
  '(-lock\.(json|ya?ml)|\.lock|\.min\.(js|css)|\.(svg|png|jpe?g|gif|ico|pdf|csv|tsv|snap|sum|map))$' \
  | while IFS= read -r f; do
      [ -f "$SRC/$f" ] && printf '%s %s\n' "$(wc -l < "$SRC/$f" | tr -d ' ')" "$f"
    done | sort -rn | head -15 \
  | awk '{c=$1; $1=""; sub(/^ /,""); printf "%6s  %s\n", c, $0}' || true
echo '```'
echo

# README in full, when present — the author's own framing of the project.
# Prefer readme.md; fall back to any README.* variant (rst, txt, extensionless).
README="$(find "$SRC" -maxdepth 1 -iname 'readme.md' | head -1 || true)"
[ -z "$README" ] && README="$(find "$SRC" -maxdepth 1 -iname 'readme*' -type f | sort | head -1 || true)"
if [ -n "$README" ]; then
  echo "## README"
  echo
  # Demote the README's own headings so they don't compete with inventory sections.
  sed 's/^#/###/' "$README"
  echo
fi
