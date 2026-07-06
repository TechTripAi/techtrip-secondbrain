#!/usr/bin/env bash
# Download an Obsidian community plugin's release assets into a vault and enable it.
# There is no official Obsidian plugin CLI, so we fetch the release assets directly
# (the same pattern already used in TechTrip.AI/.claude/settings.local.json).
#
# Usage: install-obsidian-plugin.sh <vault> <plugin-id> <owner/repo> [tag]
#   tag defaults to "latest". Idempotent: skips download if main.js already present.
#
# Supply-chain guard: when manifest.json carries a sha256 map for <plugin-id>,
# every downloaded asset is verified against it and a mismatch aborts the install
# (a hijacked upstream release fails loudly instead of landing in the vault).
# Refresh pins/hashes with: bash scripts/pin-obsidian-plugins.sh
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

VAULT="${1:?vault path required}"
PLUGIN_ID="${2:?plugin id required}"
REPO="${3:-}"            # owner/repo on GitHub; empty => caller must pre-place files
TAG="${4:-latest}"

PLUGIN_DIR="$VAULT/.obsidian/plugins/$PLUGIN_ID"
CP_JSON="$VAULT/.obsidian/community-plugins.json"

enable_in_community_plugins() {
  # Ensure PLUGIN_ID is present in .obsidian/community-plugins.json (a JSON array).
  if [ "$TSB_DRY_RUN" = "1" ]; then
    printf '%s  [dry-run]%s enable %s in community-plugins.json\n' "$_C_YEL" "$_C_RESET" "$PLUGIN_ID"
    return 0
  fi
  mkdir -p "$VAULT/.obsidian"
  [ -f "$CP_JSON" ] || echo "[]" > "$CP_JSON"
  MANIFEST="" node -e '
    const fs=require("fs"), f=process.argv[1], id=process.argv[2];
    let a=[]; try{a=JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){}
    if(!Array.isArray(a)) a=[];
    if(!a.includes(id)){ a.push(id); fs.writeFileSync(f, JSON.stringify(a,null,2)+"\n"); }
  ' "$CP_JSON" "$PLUGIN_ID"
}

if [ -f "$PLUGIN_DIR/main.js" ] && [ -f "$PLUGIN_DIR/manifest.json" ]; then
  ok "$PLUGIN_ID already installed"
  enable_in_community_plugins
  ok "$PLUGIN_ID enabled in community-plugins.json"
  exit 0
fi

[ -n "$REPO" ] || die "no repo given for $PLUGIN_ID and it isn't already present"

# Verify a downloaded asset against the manifest's pinned sha256 (if one exists).
# No hash in the manifest (e.g. a caller-supplied custom repo) => warn and accept.
verify_sha256() {
  local file="$1" asset="$2" want got
  want="$(TSB_PLUGIN_ID="$PLUGIN_ID" TSB_ASSET="$asset" manifest_get \
    '(((m.obsidianPlugins||[]).find(p=>p.id===process.env.TSB_PLUGIN_ID)||{}).sha256||{})[process.env.TSB_ASSET]||""')"
  if [ -z "$want" ]; then
    warn "$PLUGIN_ID/$asset has no pinned sha256 in manifest.json — installing unverified"
    return 0
  fi
  got="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  if [ "$got" != "$want" ]; then
    rm -f "$file"
    die "sha256 mismatch for $PLUGIN_ID/$asset (expected $want, got $got) — refusing to install. If upstream released a new version, re-pin with scripts/pin-obsidian-plugins.sh."
  fi
  ok "$PLUGIN_ID/$asset sha256 verified"
}

base="https://github.com/$REPO/releases/$( [ "$TAG" = latest ] && echo latest/download || echo "download/$TAG" )"
run "Create plugin dir $PLUGIN_DIR" -- mkdir -p "$PLUGIN_DIR"

# manifest.json and main.js are required; styles.css is optional (404 tolerated).
for asset in manifest.json main.js; do
  run "Download $PLUGIN_ID/$asset" -- \
    curl -fsSL "$base/$asset" -o "$PLUGIN_DIR/$asset" \
    || die "failed to download $asset for $PLUGIN_ID from $REPO ($TAG)"
  [ "$TSB_DRY_RUN" = "1" ] || verify_sha256 "$PLUGIN_DIR/$asset" "$asset"
done
if [ "$TSB_DRY_RUN" != "1" ]; then
  if curl -fsSL "$base/styles.css" -o "$PLUGIN_DIR/styles.css" 2>/dev/null; then
    verify_sha256 "$PLUGIN_DIR/styles.css" "styles.css"
  else
    info "$PLUGIN_ID has no styles.css (fine)"
  fi
fi

enable_in_community_plugins
ok "$PLUGIN_ID installed + enabled"
