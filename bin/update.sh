#!/usr/bin/env bash
# techtrip-secondbrain — update an existing second brain in place.
#
# Brings a machine that already ran the bootstrapper up to current:
#   1. Refresh both marketplaces (techtrip-secondbrain + claude-obsidian).
#   2. Update both Claude Code plugins to their latest versions.
#   3. Re-run the idempotent vault scaffold so community plugins are re-pinned to
#      this manifest's tags (verified by sha256) and any new plugins get added.
#   4. Doctor the result.
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
# Update this plugin, plus claude-obsidian (by AgriciDaniel — pulled from his
# marketplace, never vendored): https://github.com/AgriciDaniel/claude-obsidian
step "Update Claude Code plugins"
plist="$(claude plugin list 2>/dev/null || true)"
update_plugin() {
  local name="$1" label="$2"
  if ! printf '%s' "$plist" | grep -q "$name"; then
    warn "$label not installed — skipping (run the /secondbrain setup to install it)."
    return
  fi
  if confirm "Update $label to the latest version?"; then
    run "Updating $label" -- claude plugin update "$name" || \
      warn "Update for $label reported an issue (continuing)."
  else info "Skipped $label."; fi
}
update_plugin "techtrip-secondbrain" "techtrip-secondbrain (this plugin)"
update_plugin "claude-obsidian" "claude-obsidian (by AgriciDaniel)"

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

# ── 4. Doctor ────────────────────────────────────────────────────────────────
step "Post-update health check"
run "Running doctor" -- bash "$BIN_DIR/doctor.sh" "$VAULT" || true

step "Update complete"
info "Restart Claude Code (or /reload-plugins + /reload-skills) to load the new"
info "plugin, skill, and hook versions."
info "To add optional features (YouTube / NotebookLM / Syncthing): bin/setup-features.sh"
