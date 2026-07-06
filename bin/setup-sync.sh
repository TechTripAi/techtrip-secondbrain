#!/usr/bin/env bash
# techtrip-secondbrain — set up vault sync.
#   Default: git (already auto-committed by claude-obsidian's PostToolUse hook) —
#            just init the repo and optionally add a remote.
#   Optional: Syncthing for real-time LAN sync, with a .stignore that keeps it from
#            fighting git (.git, workspace.json, .trash, .DS_Store excluded) and
#            keeps machine-local state home (.vault-meta/locks, transport.json).
#   Two-machine model: PRIMARY keeps the vault git repo; a SECONDARY is a Syncthing
#            mirror with NO .git (decline git init there) — see README
#            "Add a second machine".
# Idempotent + interactive.
# Usage: bash bin/setup-sync.sh [/path/to/vault] [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"
require_macos

VAULT="$(default_vault_path "${1:-}")"
step "Vault sync"
info "Vault: $VAULT"
[ -d "$VAULT" ] || die "Vault not found at $VAULT — run bin/setup-vault.sh first."

# ── Git (default) ────────────────────────────────────────────────────────────
step "Git"
if [ -d "$VAULT/.git" ]; then
  ok "Git repo already initialized"
else
  info "Two-machine model: the PRIMARY machine keeps the vault's git repo (history,"
  info "backup, auto-commit). A SECONDARY machine is a Syncthing mirror with NO .git —"
  info "DECLINE git init there; claude-obsidian's auto-commit stays inert without .git"
  info "and history lives on the primary. See README: 'Add a second machine'."
  if confirm "Initialize a git repo in the vault (recommended — enables auto-commit + backup)?"; then
    run "git init" -- git -C "$VAULT" init -q
    run "initial commit" -- bash -c "cd '$VAULT' && git add -A && git commit -qm 'chore: initial vault scaffold' || true"
    ok "Git initialized"
  fi
fi
if [ -d "$VAULT/.git" ] && ! git -C "$VAULT" remote get-url origin >/dev/null 2>&1; then
  info "No 'origin' remote set. Add one to sync/back up off-machine, e.g.:"
  info "  git -C '$VAULT' remote add origin git@github.com:TechTripAi/<vault-repo>.git"
  info "  git -C '$VAULT' push -u origin main"
fi

# ── Syncthing (optional) ─────────────────────────────────────────────────────
step "Syncthing (optional real-time LAN sync)"
if confirm "Set up Syncthing for real-time sync across your Macs?"; then
  if ! have_cmd syncthing; then
    have_cmd brew || die "Homebrew required for Syncthing. Run bin/setup-deps.sh."
    run "Install Syncthing" -- brew install syncthing
  else ok "Syncthing already installed"; fi
  run "Start Syncthing service" -- brew services start syncthing || true

  STIGNORE="$VAULT/.stignore"
  # Required exclusions: version control, per-machine Obsidian UI state, junk,
  # and machine-local vault state (locks + transport detection must never sync —
  # syncing locks lets one machine release the other's in-flight lock).
  STIGNORE_PATTERNS=(
    ".git"
    ".obsidian/workspace.json"
    ".obsidian/workspace-mobile.json"
    ".trash"
    ".DS_Store"
    ".vault-meta/locks"
    ".vault-meta/transport.json"
  )
  if [ ! -f "$STIGNORE" ]; then
    if [ "$TSB_DRY_RUN" = "1" ]; then info "[dry-run] would write $STIGNORE"
    else
      {
        echo "// techtrip-secondbrain: keep Syncthing and git from fighting,"
        echo "// and keep machine-local state (locks, transport detection) home."
        printf '%s\n' "${STIGNORE_PATTERNS[@]}"
      } > "$STIGNORE"
      ok "Wrote .stignore (excludes .git, workspace state, junk, .vault-meta locks/transport)"
    fi
  else
    MISSING=()
    for p in "${STIGNORE_PATTERNS[@]}"; do
      grep -qxF "$p" "$STIGNORE" || MISSING+=("$p")
    done
    if [ "${#MISSING[@]}" -eq 0 ]; then
      ok ".stignore already complete"
    elif [ "$TSB_DRY_RUN" = "1" ]; then
      info "[dry-run] would append to $STIGNORE: ${MISSING[*]}"
    else
      printf '%s\n' "${MISSING[@]}" >> "$STIGNORE"
      ok "Added ${#MISSING[@]} missing .stignore entr$( [ "${#MISSING[@]}" -eq 1 ] && echo y || echo ies): ${MISSING[*]}"
    fi
  fi

  info "Finish pairing in the Syncthing UI: http://127.0.0.1:8384"
  info "  1. On each Mac: brew install syncthing && brew services start syncthing"
  info "  2. Add Remote Device (exchange Device IDs), then share the vault folder."
  info "Adding a second Mac? Follow README: 'Add a second machine' (run this script"
  info "there too — .stignore is per-device; Syncthing does not sync it)."
  warn "Single-writer rule: edit on one machine at a time; concurrent edits create"
  warn ".sync-conflict copies. Git history stays authoritative on the committing machine."
else
  info "Skipping Syncthing. Git remains the sync/backup path."
fi

step "Sync setup complete"
