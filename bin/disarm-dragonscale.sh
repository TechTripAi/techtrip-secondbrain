#!/usr/bin/env bash
# techtrip-secondbrain — disarm DragonScale addressing (claude-obsidian
# Mechanism 2) in a vault, with consent + backup.
#
# WHY: claude-obsidian's wiki-ingest/wiki-lint skills feature-detect DragonScale
# from files INSIDE the vault — an executable scripts/allocate-address.sh plus a
# .vault-meta/ dir (which techtrip-secondbrain creates for its own state, e.g.
# mode.json/transport.json). A vault that ever got claude-obsidian's scripts
# copied in is therefore silently armed: every ingest starts assigning
# `address:` fields from a monotonic counter in .vault-meta/address-counter.txt.
# That counter is guarded by machine-local flock only, so on this project's
# two-machine git model it can mint duplicate addresses and becomes a recurring
# merge conflict. DragonScale is out of scope for techtrip-secondbrain (see
# README) — this script turns the addressing OFF for vaults that don't want it.
#
# WHAT IT REMOVES (confirm-gated, default-NO, backed up first):
#   <vault>/scripts/allocate-address.sh      — the Mechanism 2 arming gate
#   <vault>/.vault-meta/address-counter.txt  — the allocator counter
#   <vault>/.vault-meta/tiling-thresholds.json — DragonScale setup state
#   <vault>/.vault-meta/legacy-pages.txt     — DragonScale setup state
#
# WHAT IT NEVER TOUCHES:
#   - `address:` frontmatter already on pages (with detection off, both skills
#     pass them through as user-managed metadata — no rewrite of your notes)
#   - scripts/tiling-check.py / boundary-score.py (read-only, invoke-on-demand
#     diagnostics; no cross-machine hazard)
#   - .raw/.manifest.json (also carries ingest delta tracking)
#   - the .vault-meta/ dir itself (holds this project's own state)
#   - the installed claude-obsidian plugin cache (AGENTS.md invariant)
#
# Backups land in ~/.config/techtrip-secondbrain/dragonscale-backups/<ts>/.
# Re-arm any time: bash bin/setup-dragonscale.sh from the claude-obsidian repo.
#
# Idempotent + interactive. Exits 0 when nothing is armed.
# Usage: bash bin/disarm-dragonscale.sh [/path/to/vault] [--yes] [--dry-run]
set -euo pipefail
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BIN_DIR/../scripts/common.sh"
parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}
require_macos

VAULT="$(default_vault_path "${1:-}")"
[ -d "$VAULT" ] || die "Vault not found at $VAULT — pass the right path."

# The arming files, vault-relative. allocate-address.sh first: it is the gate
# both skills test, so removing it alone already disarms detection.
CANDIDATES=(
  "scripts/allocate-address.sh"
  ".vault-meta/address-counter.txt"
  ".vault-meta/tiling-thresholds.json"
  ".vault-meta/legacy-pages.txt"
)

FOUND=()
for rel in "${CANDIDATES[@]}"; do
  [ -e "$VAULT/$rel" ] && FOUND+=("$rel")
done

step "DragonScale addressing (claude-obsidian Mechanism 2)"
info "Vault: $VAULT"

if [ "${#FOUND[@]}" = 0 ]; then
  ok "Not armed — no DragonScale addressing artifacts in this vault."
  exit 0
fi

# Armed vs residue: detection needs the allocator script; counter/state files
# without it are inert leftovers (still worth clearing, still merge-conflict
# fodder for the counter).
if [ -x "$VAULT/scripts/allocate-address.sh" ]; then
  warn "This vault is ARMED: claude-obsidian's ingest/lint skills will detect"
  warn "DragonScale and assign address fields on every new page."
else
  info "Allocator script absent/non-executable — detection is off, but stale"
  info "DragonScale state files remain (the counter is git merge-conflict bait)."
fi
info "Artifacts found:"
for rel in "${FOUND[@]}"; do info "  $rel"; done
info "Removal is backed up and reversible; page frontmatter and the tiling/"
info "boundary scripts are left untouched. Keep DragonScale? Just answer no."

# Default-NO: these files were created by claude-obsidian's opt-in
# setup-dragonscale.sh (or its vault scaffold), not by this project — someone
# may be using DragonScale deliberately, so disarming needs real consent.
if ! confirm "Disarm DragonScale addressing in '$VAULT' (backup first)?"; then
  info "Left as-is. Disarm later: bash bin/disarm-dragonscale.sh $VAULT"
  exit 0
fi

BACKUP_DIR="$TSB_STATE_DIR/dragonscale-backups/$(date +%Y%m%d-%H%M%S)"
run "Backing up ${#FOUND[@]} artifact(s) to $BACKUP_DIR" -- mkdir -p "$BACKUP_DIR"
for rel in "${FOUND[@]}"; do
  if [ "$TSB_DRY_RUN" != 1 ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -p "$VAULT/$rel" "$BACKUP_DIR/$rel"
  fi
  run "Removing $rel" -- rm "$VAULT/$rel"
done

ok "DragonScale addressing disarmed. Backup: $BACKUP_DIR"
info "Existing 'address:' fields on pages were kept (now inert metadata)."
info "If the vault is a git repo, commit the removal so other clones of THIS"
info "vault pick it up — and run this script once per machine/vault that has"
info "its own DragonScale state."
