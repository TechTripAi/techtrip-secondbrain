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
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
ENCODER="$PLUGIN_ROOT/scripts/encode-text.js"
# Bundled copy of the templates, shipped with the plugin (fallback for vaults
# scaffolded before this skill existed).
BUNDLED_SRC="$PLUGIN_ROOT/assets/vault/wiki/meta/templates/origination-project"

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

for required in project.md thesis.md open-questions.md decisions.md spec.md; do
  [[ -f "$SRC/$required" ]] || {
    echo "error: canonical template file missing: $SRC/$required" >&2
    exit 1
  }
done

# --- stamp -------------------------------------------------------------------
mkdir -p "$VAULT/wiki/projects"
cp -R "$SRC" "$DEST"

TITLE="$TITLE" DATE="$DATE" CLAIM="$CLAIM" node - "$DEST" "$ENCODER" <<'JS'
const fs = require("fs");
const path = require("path");
const dest = process.argv[2];
const encoder = require(process.argv[3]);
const { TITLE: rawTitle, DATE: date, CLAIM: rawClaim } = process.env;
const titleYaml = encoder.yamlInner(rawTitle);
const titleMarkdown = encoder.markdownInline(rawTitle);
const claimMarkdown = encoder.markdownInline(rawClaim);
const projectFiles = new Set([
  "project.md", "thesis.md", "open-questions.md", "decisions.md", "spec.md"
]);
for (const name of fs.readdirSync(dest)) {
  if (!name.endsWith(".md")) continue;
  const f = path.join(dest, name);
  let s = fs.readFileSync(f, "utf8");
  const closeBeforeStamp = s.startsWith("---\n") ? s.indexOf("\n---", 4) : -1;
  if (closeBeforeStamp >= 0) {
    const fm = s.slice(0, closeBeforeStamp).split("{{title}}").join(titleYaml);
    const body = s.slice(closeBeforeStamp).split("{{title}}").join(titleMarkdown);
    s = fm + body;
  } else {
    s = s.split("{{title}}").join(titleMarkdown);
  }
  s = s.split("{{date}}").join(date);
  if (claimMarkdown && name === "thesis.md") {
    // Replace the multi-line placeholder blockquote with the real claim.
    // Function replacement: a string 2nd arg treats $&/$'/$` as special
    // sequences and would corrupt a claim containing them.
    s = s.replace(/> \*\*Working claim:\*\* <[\s\S]*?>\n/, () => `> **Working claim:** ${claimMarkdown}\n`);
  }
  // Vault-local templates are intentionally user-editable and are not
  // overwritten on plugin updates. Repair the one metadata invariant needed
  // by every generated project page, even when an old local template predates
  // it. Restrict this to the five canonical files so custom README/supporting
  // files are left alone.
  if (projectFiles.has(name)) {
    const close = s.indexOf("\n---", 4);
    if (!s.startsWith("---\n") || close < 0) {
      throw new Error(`${name}: missing YAML frontmatter`);
    }
    const fm = s.slice(4, close);
    if (!/^updated:\s*["']?\d{4}-\d{2}-\d{2}["']?\s*$/m.test(fm)) {
      if (/^updated:\s*.*$/m.test(fm)) {
        s = s.replace(/^updated:\s*.*$/m, `updated: "${date}"`);
      } else {
        if (!/^created:\s*.*$/m.test(fm)) {
          throw new Error(`${name}: frontmatter has neither updated nor created`);
        }
        s = s.replace(/^(created:\s*.*)$/m, `$1\nupdated: "${date}"`);
      }
    }
  }
  fs.writeFileSync(f, s);
}
for (const name of projectFiles) {
  if (!fs.existsSync(path.join(dest, name))) {
    throw new Error(`canonical template file missing: ${name}`);
  }
}
JS

TITLE="$(node "$ENCODER" markdown "$TITLE")"

echo "✓ created wiki/projects/$SLUG/"
ls -1 "$DEST"
echo
echo "Next (agent does the graph updates — see SKILL.md):"
echo "  1. Add under '## Active projects' in wiki/index.md:"
echo "     - [[projects/$SLUG/project|$TITLE]] — <one-line> ; see [[projects/$SLUG/thesis|thesis]]"
echo "  2. Append a 'scaffold' entry to wiki/log.md."
echo "  3. Start the loop: fill the thesis claim + seed open-questions ([[origination-workflow]])."
echo "  4. Verify every changed content page has updated: $(date +%F)."
