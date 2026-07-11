#!/usr/bin/env bash
# techtrip-secondbrain — update an existing second brain in place.
#
# Brings a machine that already ran the bootstrapper up to current:
#   1. Refresh both marketplaces (techtrip-secondbrain + claude-obsidian).
#   2. Update both Claude Code plugins to their latest versions.
#   3. Re-run the idempotent vault scaffold so community plugins are re-pinned to
#      this manifest's tags (verified by sha256) and any new plugins get added.
#   4. Re-run setup-harnesses.sh so cross-harness skill symlinks re-point at the
#      newly installed plugin versions (they go stale on version-dir changes).
#   5. Warn if the vault still has a legacy .stignore (Syncthing support was
#      removed in 0.2.0) and point at setup-sync.sh to clean it up. We never
#      touch the Syncthing install itself — it's external software.
#   6. Doctor the result.
#
# Does NOT touch your notes, git history, MCP key, or optional-feature choices.
# Community-plugin downloads stay pinned + hash-verified (see scripts/
# install-obsidian-plugin.sh). Restart Claude Code afterward to load new
# plugin/skill/hook versions.
#
# Idempotent + interactive.
# Usage: bash bin/update.sh [/path/to/vault] [--yes] [--dry-run]
set -euo pipefail
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$BIN_DIR/../scripts/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"
require_macos

VAULT="$(default_vault_path "${1:-}")"
step "Update techtrip-secondbrain"
info "Vault: $VAULT"

have_cmd claude || die "claude CLI not found — install Claude Code first."

# ── 1. Refresh marketplaces ──────────────────────────────────────────────────
step "Refresh marketplaces"
if confirm "Refresh Claude Code marketplaces (pull latest plugin listings)?"; then
  run "Updating all marketplaces" -- claude plugin marketplace update || \
    warn "Marketplace refresh reported an issue (continuing)."
else
  info "Skipped marketplace refresh."
fi

# ── 2. Update the Claude Code plugins ────────────────────────────────────────
# Update this plugin. claude-obsidian is handled separately below: a bare
# `claude plugin update claude-obsidian` only refreshes it within whatever
# marketplace it's currently on, so it can never migrate an upstream
# (AgriciDaniel) install over to TechTripAi's maintained fork. Only
# setup-claude-obsidian.sh has that migrate-or-install logic, so delegate to it.
step "Update Claude Code plugins"
plist="$(claude plugin list 2>/dev/null || true)"
if printf '%s' "$plist" | grep -q "techtrip-secondbrain"; then
  if confirm "Update techtrip-secondbrain (this plugin) to the latest version?"; then
    run "Updating techtrip-secondbrain (this plugin)" -- claude plugin update techtrip-secondbrain || \
      warn "Update for techtrip-secondbrain (this plugin) reported an issue (continuing)."
  else info "Skipped techtrip-secondbrain (this plugin)."; fi
else
  warn "techtrip-secondbrain (this plugin) not installed — skipping (run the /secondbrain setup to install it)."
fi

step "Update claude-obsidian (by AgriciDaniel — installed from TechTrip's maintained fork)"
run "Checking claude-obsidian install / migrating to the fork if needed" -- \
  bash "$BIN_DIR/setup-claude-obsidian.sh"

# ── 3. Re-pin community plugins via the idempotent scaffold ───────────────────
step "Re-pin community plugins"
if [ -d "$VAULT" ]; then
  info "Re-running setup-vault.sh so community plugins match this manifest's pinned"
  info "tags (each asset re-verified against its sha256). Existing notes untouched."
  if confirm "Re-run the vault scaffold against '$VAULT'?"; then
    run "Refreshing vault plugins" -- bash "$BIN_DIR/setup-vault.sh" "$VAULT"
  else info "Skipped vault refresh."; fi
else
  warn "Vault not found at $VAULT — skipping plugin re-pin. Pass the right path:"
  warn "  bash bin/update.sh /path/to/vault"
fi

# ── 4. Re-point cross-harness skill links ────────────────────────────────────
# Skill symlinks in ~/.agents/skills (and ~/.codex/skills) point at versioned
# plugin-cache dirs, so a plugin update strands them. Only refresh when the
# machine-level links already exist — update never introduces new surface area.
step "Refresh cross-harness skill links"
if [ -d "$HOME/.agents/skills" ] || [ -d "$HOME/.codex/skills" ]; then
  run "Re-pointing skill symlinks at the updated plugins" -- \
    bash "$BIN_DIR/setup-harnesses.sh" "$VAULT" || \
    warn "setup-harnesses.sh reported an issue (continuing)."
else
  info "Cross-harness links not set up on this machine — skipping."
  info "(Enable any time: bash bin/setup-harnesses.sh)"
fi

# ── 5. Legacy Syncthing (removed in 0.2.0) ────────────────────────────────────
# Syncthing support was dropped. Only flag the vault-side leftover we created
# (.stignore); the Syncthing install itself is external software the user may
# use for other purposes — never stop or uninstall it.
if [ -f "$VAULT/.stignore" ]; then
  step "Legacy Syncthing config detected"
  warn "Syncthing support was removed in 0.2.0 — git is the only sync path."
  info "The vault still has the .stignore an earlier release wrote. Clean it up:"
  info "  bash bin/setup-sync.sh $VAULT"
fi

# ── 6. Doctor ────────────────────────────────────────────────────────────────
step "Post-update health check"
run "Running doctor" -- bash "$BIN_DIR/doctor.sh" "$VAULT" || true

step "Update complete"
info "Restart Claude Code (or /reload-plugins + /reload-skills) to load the new"
info "plugin, skill, and hook versions."
info "To add optional features (YouTube / NotebookLM): bin/setup-features.sh"
