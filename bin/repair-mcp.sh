#!/usr/bin/env bash
# techtrip-secondbrain — diagnose + repair the Obsidian MCP connection.
#
# Targets the common failure: the `obsidian` MCP server is registered globally but
# fails to connect. Runs a battery of checks, prints a diagnosis, and offers
# interactive repairs. Safe to run anytime (integrity check).
#
# Usage: bash bin/repair-mcp.sh [/path/to/vault] [--yes] [--dry-run]
set -uo pipefail
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "$BIN_DIR/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}

VAULT="$(default_vault_path "${1:-}")"
NAME="$(manifest_get 'm.mcpServers[0].name')"
HOST="$(manifest_get 'm.mcpServers[0].env.OBSIDIAN_HOST')"
PORT="$(manifest_get 'm.mcpServers[0].env.OBSIDIAN_PORT')"
DATA="$VAULT/.obsidian/plugins/obsidian-local-rest-api/data.json"
CLAUDE_JSON="$HOME/.claude.json"

OKM="${_C_GRN}ok${_C_RESET}"; BADM="${_C_RED}fail${_C_RESET}"; WARNM="${_C_YEL}warn${_C_RESET}"
row() { printf '   %-34s %s\n' "$1" "$2"; }

# ── Diagnostics (set *_ok flags) ─────────────────────────────────────────────
step "Diagnose: $NAME MCP → $HOST:$PORT (vault: $VAULT)"

uvx_ok=1; have_cmd uvx && row "uvx present" "$OKM" || { uvx_ok=0; row "uvx present" "$BADM  → brew install uv"; }

claude_ok=1
if have_cmd claude; then row "claude CLI" "$OKM"; else claude_ok=0; row "claude CLI" "$BADM  (install Claude Code)"; fi

registered=0
# Anchor to the server-name column ("name: command…") — a bare substring match
# would false-positive on any server whose *command* mentions the name.
if [ "$claude_ok" = 1 ] && claude mcp list 2>/dev/null | grep -qE "^${NAME}:"; then
  registered=1; row "registered in Claude" "$OKM"
else row "registered in Claude" "$BADM  → bin/setup-mcp.sh"; fi

# API key present in the vault plugin data.json?
vault_key=""; datakey_ok=0
if [ -f "$DATA" ]; then
  vault_key="$(node -e 'try{process.stdout.write(require(process.argv[1]).apiKey||"")}catch(e){}' "$DATA" 2>/dev/null)"
  [ -n "$vault_key" ] && { datakey_ok=1; row "vault REST API key" "$OKM"; } || row "vault REST API key" "$BADM  (data.json has no apiKey)"
else row "vault REST API key" "$BADM  ($DATA missing → bin/setup-mcp.sh)"; fi

# Does the registered env key match the vault key?
env_key=""; keymatch_ok=0
if [ -f "$CLAUDE_JSON" ]; then
  env_key="$(node -e '
    try{const c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
    const s=(c.mcpServers&&c.mcpServers[process.argv[2]])||{};
    process.stdout.write((s.env&&s.env.OBSIDIAN_API_KEY)||"")}catch(e){}' "$CLAUDE_JSON" "$NAME" 2>/dev/null)"
  if [ -n "$env_key" ] && [ -n "$vault_key" ] && [ "$env_key" = "$vault_key" ]; then
    keymatch_ok=1; row "MCP env key == vault key" "$OKM"
  elif [ -z "$env_key" ]; then row "MCP env key == vault key" "$WARNM  (no OBSIDIAN_API_KEY in registration)"
  else row "MCP env key == vault key" "$BADM  (MISMATCH → key rotated?)"; fi
fi

# Is the REST API port actually listening? (Obsidian running + plugin enabled)
port_ok=0
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then port_ok=1; row "port $PORT listening" "$OKM"
else row "port $PORT listening" "$BADM  (Obsidian not running / REST API disabled)"; fi

# Live authenticated probe. Hit /vault/ (requires auth), NOT / (which is public and
# 200s with any key — it can't validate the handshake).
probe_ok=0
if [ "$port_ok" = 1 ] && [ -n "$vault_key" ]; then
  # Key rides in a curl config via process substitution, not argv (ps-visible).
  if curl -fsk -m 4 --config <(printf 'header = "Authorization: Bearer %s"\n' "$vault_key") "https://$HOST:$PORT/vault/" >/dev/null 2>&1; then
    probe_ok=1; row "authenticated probe (/vault/)" "$OKM"
  else row "authenticated probe (/vault/)" "$BADM  (listening but key rejected / TLS failed)"; fi
else row "authenticated probe (/vault/)" "$WARNM  (skipped: port down or no key)"; fi

# ── Verdict ──────────────────────────────────────────────────────────────────
step "Verdict"
if [ "$registered" = 1 ] && [ "$keymatch_ok" = 1 ] && [ "$probe_ok" = 1 ]; then
  ok "$NAME MCP is healthy end-to-end. If tools still don't resolve in Claude, reload the session."
  exit 0
fi

# ── Repairs (interactive) ────────────────────────────────────────────────────
step "Repair"

if [ "$uvx_ok" = 0 ]; then
  confirm "Install uv (provides uvx, needed to launch the MCP server)?" && \
    run "brew install uv" -- brew install uv || warn "uvx still missing — MCP server can't launch."
fi

# Key missing/mismatch, or not registered → (re)register with the correct key.
if [ "$registered" = 0 ] || [ "$keymatch_ok" = 0 ]; then
  warn "Registration is missing or its key doesn't match the vault's REST API key."
  info "This is the usual cause of 'registered globally but fails to connect' after a key rotation or a fresh vault."
  if confirm "Re-register '$NAME' with the vault's current key (via bin/setup-mcp.sh)?"; then
    if [ "$registered" = 1 ]; then run "Remove stale registration" -- claude mcp remove "$NAME" 2>/dev/null || true; fi
    # TSB_DRY_RUN / TSB_ASSUME_YES are exported — the child inherits them.
    # (Never rebuild them via ${VAR:+--flag}: the vars are always set to "0"/"1",
    # so :+ expands the flag unconditionally and forces a permanent dry-run.)
    run "Re-register with correct key" -- bash "$BIN_DIR/setup-mcp.sh" "$VAULT"
    info "Reload the Claude session afterward so the new registration takes effect."
  fi
fi

# Port down → Obsidian isn't serving the REST API.
if [ "$port_ok" = 0 ]; then
  warn "Nothing is listening on $HOST:$PORT — the Local REST API only runs while Obsidian is open with the plugin enabled."
  if confirm "Open Obsidian now?"; then
    run "Open Obsidian" -- open -a Obsidian "$VAULT" 2>/dev/null || open -a Obsidian || warn "Could not open Obsidian automatically."
    info "In Obsidian: Settings → Community plugins → enable 'Local REST API'. Then re-run this check."
  else
    info "Open the vault in Obsidian and enable Local REST API, then re-run: bin/repair-mcp.sh $VAULT"
  fi
fi

# Everything structurally fine but probe failed despite listening → likely reload/TLS.
if [ "$registered" = 1 ] && [ "$keymatch_ok" = 1 ] && [ "$port_ok" = 1 ] && [ "$probe_ok" = 0 ]; then
  warn "Registered + keys match + port up, but the authenticated probe failed."
  info "Check that NODE_TLS_REJECT_UNAUTHORIZED=0 is set in the registration (self-signed cert),"
  info "then fully reload/restart Claude Code — a stale MCP connection won't reconnect on its own."
fi

step "Repair pass complete — re-run bin/repair-mcp.sh to confirm green."
exit 0
