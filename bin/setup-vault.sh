#!/usr/bin/env bash
# techtrip-secondbrain — scaffold a generic LLM Wiki vault.
#   1. resolve/create the vault dir
#   2. run claude-obsidian's own bin/setup-vault.sh (if the plugin is installed)
#   3. install + enable the community plugins from manifest.json
#   4. seed our own starter canvas
# Idempotent + interactive.
# Usage: bash bin/setup-vault.sh [/path/to/vault] [--yes] [--dry-run]
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)"
source "$SCRIPTS_DIR/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"
require_macos

VAULT="$(default_vault_path "${1:-}")"
step "Scaffold vault"
info "Vault path: $VAULT"
if ! confirm "Create / use the vault at '$VAULT' ?"; then
  die "Aborted. Re-run with an explicit path: bin/setup-vault.sh /path/to/vault"
fi
run "Create vault directory" -- mkdir -p "$VAULT/.obsidian"
save_vault_path "$VAULT"

# ── 1. Delegate base scaffold to claude-obsidian's own setup-vault.sh ─────────
# claude-obsidian is by AgriciDaniel (MIT): https://github.com/AgriciDaniel/claude-obsidian
step "Base scaffold (claude-obsidian, by AgriciDaniel)"
if co_setup="$(find_claude_obsidian_setup)"; then
  info "Using $co_setup"
  run "Running claude-obsidian setup-vault.sh" -- bash "$co_setup" "$VAULT"
  ok "Base .obsidian config + wiki/ tree created by claude-obsidian"
else
  warn "claude-obsidian plugin not found — creating a minimal wiki/ tree ourselves."
  warn "Install it first (bin/setup-claude-obsidian.sh) for the full scaffold + hooks."
  run "Create minimal wiki dirs" -- mkdir -p \
    "$VAULT/wiki/concepts" "$VAULT/wiki/entities" "$VAULT/wiki/sources" \
    "$VAULT/wiki/meta" "$VAULT/.raw" "$VAULT/_templates"
fi

# ── 2. Install community plugins from the manifest ───────────────────────────
step "Community plugins"
while IFS=$'\t' read -r id repo tag; do
  [ -n "$id" ] || continue
  if [ -z "$repo" ]; then warn "$id has no repo in manifest; skipping"; continue; fi
  bash "$SCRIPTS_DIR/install-obsidian-plugin.sh" "$VAULT" "$id" "$repo" "${tag:-latest}" \
    || warn "Could not install $id (continuing)"
done < <(manifest_get 'm.obsidianPlugins.map(p=>[p.id,p.repo||"",p.tag||""].join("\t")).join("\n")')

# ── 3. Seed our own starter canvas (never AgriciDaniel content) ──────────────
step "Starter content"
STARTER="$REPO_ROOT/assets/canvases/starter.canvas"
if [ -f "$STARTER" ]; then
  run "Copy starter canvas" -- cp -n "$STARTER" "$VAULT/wiki/canvases-starter.canvas" 2>/dev/null || true
  ok "Starter canvas seeded (wiki/canvases-starter.canvas)"
fi

step "Vault scaffold complete"
ok "Vault ready at: $VAULT"
info "Next: bin/setup-mcp.sh (wire the Obsidian MCP server) then bin/setup-sync.sh."
info "Then open the vault in Obsidian, enable community plugins if prompted, and run /wiki in Claude Code to scaffold content."
