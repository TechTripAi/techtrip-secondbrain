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

# These three values become path segments (PLUGIN_DIR) and URL segments (the
# release download). Whitelist their shape so a hostile/typo'd manifest entry
# can't traverse out of the vault ("../..") or redirect the URL path.
case "$PLUGIN_ID" in
  *[!A-Za-z0-9._-]*|.*|"") die "invalid plugin id '$PLUGIN_ID' (allowed: A-Za-z0-9._- ; must not start with '.')" ;;
esac
if [ -n "$REPO" ]; then
  case "$REPO" in
    */*/*|*..*|*[!A-Za-z0-9./_-]*|/*|*/) die "invalid repo '$REPO' (expected owner/repo)" ;;
    */*) ;;
    *) die "invalid repo '$REPO' (expected owner/repo)" ;;
  esac
fi
case "$TAG" in
  *[!A-Za-z0-9._-]*|"") die "invalid tag '$TAG' (allowed: A-Za-z0-9._-)" ;;
esac

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

# Is this plugin id declared in manifest.json's obsidianPlugins at all?
in_manifest="$(TSB_PLUGIN_ID="$PLUGIN_ID" manifest_get \
  '(m.obsidianPlugins||[]).some(p=>p.id===process.env.TSB_PLUGIN_ID) ? "1" : ""')"

# Verify a downloaded asset against the manifest's pinned sha256.
# - Plugin listed in the manifest: a missing hash is a HARD FAIL — otherwise
#   deleting one sha256 key (or upstream adding a new asset) silently bypasses
#   the supply-chain guard the manifest advertises.
# - Plugin not in the manifest (caller-supplied custom repo): warn and accept.
verify_sha256() {
  local file="$1" asset="$2" want got
  want="$(TSB_PLUGIN_ID="$PLUGIN_ID" TSB_ASSET="$asset" manifest_get \
    '(((m.obsidianPlugins||[]).find(p=>p.id===process.env.TSB_PLUGIN_ID)||{}).sha256||{})[process.env.TSB_ASSET]||""')"
  if [ -z "$want" ]; then
    if [ -n "$in_manifest" ]; then
      die "$PLUGIN_ID/$asset has no pinned sha256 in manifest.json — refusing to install a manifest plugin unverified. Re-pin with scripts/pin-obsidian-plugins.sh."
    fi
    warn "$PLUGIN_ID/$asset is not manifest-pinned (custom repo) — installing unverified"
    return 0
  fi
  got="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  if [ "$got" != "$want" ]; then
    die "sha256 mismatch for $PLUGIN_ID/$asset (expected $want, got $got) — refusing to install. If upstream released a new version, re-pin with scripts/pin-obsidian-plugins.sh."
  fi
  ok "$PLUGIN_ID/$asset sha256 verified"
}

base="https://github.com/$REPO/releases/$( [ "$TAG" = latest ] && echo latest/download || echo "download/$TAG" )"

# Download into a throwaway staging dir and verify EVERYTHING there before any
# file lands in the live plugin dir — Obsidian may be running with the vault
# open, and an unverified main.js must never be loadable; a late mismatch must
# not leave a half-install behind.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# manifest.json and main.js are required; styles.css is optional (404 tolerated).
assets=(manifest.json main.js)
for asset in manifest.json main.js; do
  run "Download $PLUGIN_ID/$asset" -- \
    curl -fsSL "$base/$asset" -o "$STAGE/$asset" \
    || die "failed to download $asset for $PLUGIN_ID from $REPO ($TAG)"
  [ "$TSB_DRY_RUN" = "1" ] || verify_sha256 "$STAGE/$asset" "$asset"
done
if [ "$TSB_DRY_RUN" != "1" ]; then
  if curl -fsSL "$base/styles.css" -o "$STAGE/styles.css" 2>/dev/null; then
    verify_sha256 "$STAGE/styles.css" "styles.css"
    assets+=(styles.css)
  else
    info "$PLUGIN_ID has no styles.css (fine)"
  fi
fi

# All verified — move into place as the last step.
run "Create plugin dir $PLUGIN_DIR" -- mkdir -p "$PLUGIN_DIR"
if [ "$TSB_DRY_RUN" != "1" ]; then
  for asset in "${assets[@]}"; do
    mv -f "$STAGE/$asset" "$PLUGIN_DIR/$asset"
  done
fi

enable_in_community_plugins
ok "$PLUGIN_ID installed + enabled"
