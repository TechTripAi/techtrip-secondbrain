#!/usr/bin/env bash
# techtrip-secondbrain — refresh the obsidianPlugins pins in manifest.json.
# For every plugin with a repo: resolve the latest GitHub release tag, download its
# assets, compute sha256 hashes, and write tag + sha256 back into manifest.json.
# Run this deliberately when you WANT to move to new upstream releases; review the
# manifest diff before committing (the hashes are the supply-chain trust anchor).
#
# Usage: bash scripts/pin-obsidian-plugins.sh [--dry-run] [--yes]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"

have_cmd curl || die "curl is required."
have_cmd shasum || die "shasum is required."

step "Re-pin Obsidian community plugins (tags + sha256) in $MANIFEST"
confirm "Resolve latest releases and rewrite tag/sha256 for every plugin?" \
  || die "Aborted — manifest.json unchanged."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PINS="$TMP/pins.tsv"   # id \t tag \t asset \t sha256  (one line per verified asset)
: > "$PINS"

while IFS=$'\t' read -r id repo; do
  [ -n "$id" ] && [ -n "$repo" ] || continue
  tag="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
    | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.stdout.write(JSON.parse(s).tag_name||""))')"
  [ -n "$tag" ] || { warn "$id: could not resolve latest release for $repo — skipping"; continue; }
  info "$id → $repo@$tag"
  for asset in manifest.json main.js styles.css; do
    f="$TMP/$id-$asset"
    if curl -fsSL "https://github.com/$repo/releases/download/$tag/$asset" -o "$f" 2>/dev/null; then
      printf '%s\t%s\t%s\t%s\n' "$id" "$tag" "$asset" "$(shasum -a 256 "$f" | cut -d' ' -f1)" >> "$PINS"
    elif [ "$asset" != "styles.css" ]; then
      warn "$id: required asset $asset missing from $repo@$tag"
    fi
  done
done < <(manifest_get 'm.obsidianPlugins.map(p=>[p.id,p.repo||""].join("\t")).join("\n")')

if [ "$TSB_DRY_RUN" = "1" ]; then
  info "[dry-run] would write these pins into $MANIFEST:"
  column -t -s$'\t' "$PINS" | sed 's/^/     /'
  exit 0
fi

node -e '
  const fs = require("fs");
  const manifest = process.argv[1], pinsFile = process.argv[2];
  const m = JSON.parse(fs.readFileSync(manifest, "utf8"));
  const pins = {};
  for (const line of fs.readFileSync(pinsFile, "utf8").split("\n")) {
    if (!line.trim()) continue;
    const [id, tag, asset, sha] = line.split("\t");
    (pins[id] ||= { tag, sha256: {} }).sha256[asset] = sha;
  }
  for (const p of m.obsidianPlugins || []) {
    const pin = pins[p.id];
    if (!pin) continue;
    p.tag = pin.tag;
    p.sha256 = pin.sha256;
  }
  fs.writeFileSync(manifest, JSON.stringify(m, null, 2) + "\n");
' "$MANIFEST" "$PINS"

ok "manifest.json re-pinned. Review the diff before committing:"
info "  git -C '$REPO_ROOT' diff -- manifest.json"
