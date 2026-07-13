#!/usr/bin/env bash
# new-idea — stamp a greenfield origination project from the template.
#
# Usage:
#   new-idea.sh <slug> [--title "Title"] [--claim "One-line claim"]
#
# Copies wiki/meta/templates/origination-project/ -> wiki/projects/<slug>/,
# fills {{title}}/{{date}} tokens, and (if given) seeds the thesis blockquote
# with the one-line claim. It does NOT touch index.md/log.md — the agent does
# those graph updates (see SKILL.md), keeping the single-mutation-path
# discipline that yt-fetch and wiki-ingest follow.
#
# Requires: node (already a hard dependency of techtrip-secondbrain).
set -euo pipefail
export PATH="/opt/homebrew/bin:$HOME/.local/bin:$PATH"

# pwd -P: resolve through symlinks — the harness dirs (~/.agents/skills etc.)
# link to the plugin cache, and a logical pwd would walk ../ from the link's
# parent instead of the real plugin root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
# Bundled copy of the templates, shipped with the plugin (fallback for vaults
# scaffolded before this skill existed).
BUNDLED_SRC="$(cd "$SCRIPT_DIR/../../.." && pwd -P)/assets/vault/wiki/meta/templates/origination-project"

# --- locate vault root (dir containing wiki/) --------------------------------
find_vault_root() {
  local d="$PWD"
  while [[ "$d" != "/" ]]; do
    [[ -d "$d/wiki" && -d "$d/.obsidian" ]] && { echo "$d"; return 0; }
    d="$(dirname "$d")"
  done
  return 1
}

VAULT="$(find_vault_root)" || {
  echo "error: run this from inside the vault (no wiki/ + .obsidian/ found in any parent dir)" >&2
  exit 1
}

# --- parse args --------------------------------------------------------------
SLUG=""; TITLE=""; CLAIM=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) [ $# -ge 2 ] || { echo "error: $1 needs a value" >&2; exit 1; }; TITLE="$2"; shift 2 ;;
    --claim) [ $# -ge 2 ] || { echo "error: $1 needs a value" >&2; exit 1; }; CLAIM="$2"; shift 2 ;;
    -*) echo "error: unknown flag $1" >&2; exit 1 ;;
    *) [[ -z "$SLUG" ]] && SLUG="$1" || { echo "error: unexpected arg $1" >&2; exit 1; }; shift ;;
  esac
done

[[ -z "$SLUG" ]] && { echo "usage: new-idea.sh <slug> [--title \"Title\"] [--claim \"...\"]" >&2; exit 1; }
# normalize slug: lowercase, spaces->hyphens; then reject anything that isn't a
# plain folder name (no /, .., etc. — the slug becomes a path segment)
SLUG="$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
case "$SLUG" in
  *[!a-z0-9-]*|-*|"") echo "error: slug must be lowercase letters, digits, and hyphens (got '$SLUG')" >&2; exit 1 ;;
esac

# derive a title from slug if none supplied (hyphens->spaces, Title Case)
if [[ -z "$TITLE" ]]; then
  TITLE="$(printf '%s' "$SLUG" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++){$i=toupper(substr($i,1,1)) substr($i,2)}}1')"
fi

DATE="$(date +%F)"
SRC="$VAULT/wiki/meta/templates/origination-project"
DEST="$VAULT/wiki/projects/$SLUG"

# Vault scaffolded before this skill existed? Seed the vault copy from the
# plugin's bundled templates so the Obsidian Templates plugin (and this script)
# can use it from now on.
if [[ ! -d "$SRC" ]]; then
  [[ -d "$BUNDLED_SRC" ]] || { echo "error: templates missing from both vault ($SRC) and plugin ($BUNDLED_SRC)" >&2; exit 1; }
  echo "Seeding vault templates from the plugin (wiki/meta/templates/origination-project/)…"
  mkdir -p "$(dirname "$SRC")"
  cp -R "$BUNDLED_SRC" "$SRC"
fi

[[ -e "$DEST" ]] && { echo "error: $DEST already exists — pick another slug" >&2; exit 1; }

# --- stamp -------------------------------------------------------------------
mkdir -p "$VAULT/wiki/projects"
cp -R "$SRC" "$DEST"

TITLE="$TITLE" DATE="$DATE" CLAIM="$CLAIM" node - "$DEST" <<'JS'
const fs = require("fs");
const path = require("path");
const dest = process.argv[2];
const { TITLE: title, DATE: date, CLAIM: claim } = process.env;
for (const name of fs.readdirSync(dest)) {
  if (!name.endsWith(".md")) continue;
  const f = path.join(dest, name);
  let s = fs.readFileSync(f, "utf8");
  s = s.split("{{title}}").join(title).split("{{date}}").join(date);
  if (claim && name === "thesis.md") {
    // replace the multi-line placeholder blockquote with the real claim
    s = s.replace(/> \*\*Working claim:\*\* <[\s\S]*?>\n/, `> **Working claim:** ${claim}\n`);
  }
  fs.writeFileSync(f, s);
}
JS

echo "✓ created wiki/projects/$SLUG/"
ls -1 "$DEST"
echo
echo "Next (agent does the graph updates — see SKILL.md):"
echo "  1. Add under '## Active projects' in wiki/index.md:"
echo "     - [[projects/$SLUG/project|$TITLE]] — <one-line> ; see [[projects/$SLUG/thesis|thesis]]"
echo "  2. Append a 'scaffold' entry to wiki/log.md."
echo "  3. Start the loop: fill the thesis claim + seed open-questions ([[origination-workflow]])."
