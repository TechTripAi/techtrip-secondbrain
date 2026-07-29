#!/usr/bin/env bash
# Install or reconcile an Obsidian community plugin from a pinned GitHub release.
# Usage: install-obsidian-plugin.sh <vault> <plugin-id> <owner/repo> [tag]
#        [--allow-unverified] [--dry-run] [--yes]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ALLOW_UNVERIFIED=0
filtered=()
for arg in "$@"; do
  case "$arg" in
    --allow-unverified) ALLOW_UNVERIFIED=1 ;;
    *) filtered+=("$arg") ;;
  esac
done
parse_common_flags "${filtered[@]}"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}

VAULT="${1:?vault path required}"
PLUGIN_ID="${2:?plugin id required}"
REPO="${3:-}"
TAG="${4:-latest}"

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
  if [ "$TSB_DRY_RUN" = "1" ]; then
    info "[dry-run] would enable $PLUGIN_ID in community-plugins.json"
    return 0
  fi
  run "Create Obsidian config directory" -- mkdir -p "$VAULT/.obsidian"
  if [ ! -f "$CP_JSON" ]; then
    run "Initialize community-plugins.json" -- node -e \
      'require("fs").writeFileSync(process.argv[1], "[]\n")' "$CP_JSON"
  fi
  MANIFEST="" node -e '
    const fs=require("fs"), f=process.argv[1], id=process.argv[2];
    let a=[]; try{a=JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){}
    if(!Array.isArray(a)) a=[];
    if(!a.includes(id)){a.push(id);fs.writeFileSync(f,JSON.stringify(a,null,2)+"\n")}
  ' "$CP_JSON" "$PLUGIN_ID"
}

in_manifest="$(TSB_PLUGIN_ID="$PLUGIN_ID" manifest_get \
  '(m.obsidianPlugins||[]).some(p=>p.id===process.env.TSB_PLUGIN_ID) ? "1" : ""')"
if [ -z "$in_manifest" ] && [ "$ALLOW_UNVERIFIED" != "1" ]; then
  die "$PLUGIN_ID is not pinned in manifest.json — pass --allow-unverified to install a custom plugin deliberately"
fi

expected_hash() {
  TSB_PLUGIN_ID="$PLUGIN_ID" TSB_ASSET="$1" manifest_get \
    '(((m.obsidianPlugins||[]).find(p=>p.id===process.env.TSB_PLUGIN_ID)||{}).sha256||{})[process.env.TSB_ASSET]||""'
}

verify_sha256() {
  local file="$1" asset="$2" want got
  want="$(expected_hash "$asset")"
  if [ -z "$want" ]; then
    [ "$ALLOW_UNVERIFIED" = "1" ] || \
      die "$PLUGIN_ID/$asset has no pinned sha256 — refusing an unverified manifest install"
    warn "$PLUGIN_ID/$asset is custom and unverified by explicit request"
    return 0
  fi
  got="$(shasum -a 256 "$file" | cut -d' ' -f1)"
  [ "$got" = "$want" ] || \
    die "sha256 mismatch for $PLUGIN_ID/$asset (expected $want, got $got) — live files were not changed"
  ok "$PLUGIN_ID/$asset sha256 verified"
}

# A manifest plugin must pin both executable metadata assets. styles.css is
# expected only when the manifest carries its hash.
if [ -n "$in_manifest" ]; then
  [ -n "$(expected_hash manifest.json)" ] || die "$PLUGIN_ID/manifest.json has no pinned sha256"
  [ -n "$(expected_hash main.js)" ] || die "$PLUGIN_ID/main.js has no pinned sha256"
fi

installed_matches=1
if [ ! -d "$PLUGIN_DIR" ]; then
  installed_matches=0
elif [ -n "$in_manifest" ]; then
  for asset in manifest.json main.js styles.css; do
    want="$(expected_hash "$asset")"
    if [ -n "$want" ]; then
      if [ ! -f "$PLUGIN_DIR/$asset" ] || \
         [ "$(shasum -a 256 "$PLUGIN_DIR/$asset" | cut -d' ' -f1)" != "$want" ]; then
        installed_matches=0
      fi
    elif [ "$asset" = styles.css ] && [ -e "$PLUGIN_DIR/styles.css" ]; then
      installed_matches=0
    fi
  done
else
  [ -f "$PLUGIN_DIR/main.js" ] && [ -f "$PLUGIN_DIR/manifest.json" ] || installed_matches=0
fi

if [ "$installed_matches" = "1" ]; then
  ok "$PLUGIN_ID installed assets match the pinned release"
  enable_in_community_plugins
  exit 0
fi

[ -n "$REPO" ] || die "no repo given for $PLUGIN_ID and its installed assets do not match"
if [ "$TSB_DRY_RUN" = "1" ]; then
  info "[dry-run] would stage, verify, and transactionally reconcile $PLUGIN_ID"
  enable_in_community_plugins
  exit 0
fi

base="https://github.com/$REPO/releases/$( [ "$TAG" = latest ] && echo latest/download || echo "download/$TAG" )"
DOWNLOADS="$(mktemp -d "${TMPDIR:-/tmp}/tsb-plugin-download.XXXXXX")"
LIVE_STAGE=""
BACKUP=""
cleanup() {
  rc=$?
  if [ -n "$BACKUP" ] && [ -d "$BACKUP" ] && [ ! -d "$PLUGIN_DIR" ]; then
    mv "$BACKUP" "$PLUGIN_DIR" 2>/dev/null || true
  fi
  [ -n "$LIVE_STAGE" ] && [ -d "$LIVE_STAGE" ] && rm -rf "$LIVE_STAGE"
  [ -n "$BACKUP" ] && [ -d "$BACKUP" ] && rm -rf "$BACKUP"
  rm -rf "$DOWNLOADS"
  exit "$rc"
}
trap cleanup EXIT

assets=(manifest.json main.js)
for asset in manifest.json main.js; do
  run "Download $PLUGIN_ID/$asset" -- curl -fsSL "$base/$asset" -o "$DOWNLOADS/$asset" \
    || die "failed to download $asset for $PLUGIN_ID from $REPO ($TAG)"
  verify_sha256 "$DOWNLOADS/$asset" "$asset"
done

style_hash="$(expected_hash styles.css)"
if [ -n "$style_hash" ]; then
  run "Download $PLUGIN_ID/styles.css" -- curl -fsSL "$base/styles.css" -o "$DOWNLOADS/styles.css" \
    || die "failed to download pinned styles.css for $PLUGIN_ID"
  verify_sha256 "$DOWNLOADS/styles.css" styles.css
  assets+=(styles.css)
elif [ "$ALLOW_UNVERIFIED" = "1" ] && curl -fsSL "$base/styles.css" -o "$DOWNLOADS/styles.css" 2>/dev/null; then
  verify_sha256 "$DOWNLOADS/styles.css" styles.css
  assets+=(styles.css)
fi

run "Create Obsidian staging parent" -- mkdir -p "$VAULT/.obsidian"
LIVE_STAGE="$(mktemp -d "$VAULT/.obsidian/.tsb-plugin-stage.XXXXXX")"
if [ -d "$PLUGIN_DIR" ]; then
  run "Preserve $PLUGIN_ID settings and custom files in staging" -- cp -pR "$PLUGIN_DIR/." "$LIVE_STAGE/"
fi
for asset in "${assets[@]}"; do
  run "Stage verified $PLUGIN_ID/$asset" -- cp -p "$DOWNLOADS/$asset" "$LIVE_STAGE/$asset"
done
if [ -z "$style_hash" ] && [ "$ALLOW_UNVERIFIED" != "1" ] && [ -e "$LIVE_STAGE/styles.css" ]; then
  run "Remove stale unpinned $PLUGIN_ID/styles.css from staging" -- rm -f "$LIVE_STAGE/styles.css"
fi

if [ -d "$PLUGIN_DIR" ]; then
  BACKUP="$VAULT/.obsidian/.tsb-plugin-backup.$PLUGIN_ID.$$"
  run "Move current $PLUGIN_ID aside for rollback" -- mv "$PLUGIN_DIR" "$BACKUP"
fi
run "Activate verified $PLUGIN_ID release" -- mv "$LIVE_STAGE" "$PLUGIN_DIR"
LIVE_STAGE=""
if [ -n "$BACKUP" ]; then
  run "Remove superseded $PLUGIN_ID release after successful swap" -- rm -rf "$BACKUP"
  BACKUP=""
fi

enable_in_community_plugins
ok "$PLUGIN_ID reconciled to pinned release; settings and custom files preserved"
