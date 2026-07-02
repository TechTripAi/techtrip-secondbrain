#!/usr/bin/env bash
# claude-secondbrain — post-install health check for a scaffolded vault.
# Report-only; always exits 0. Usage: bash bin/doctor.sh [/path/to/vault]
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"

VAULT="$(default_vault_path "${1:-}")"
OKM="${_C_GRN}ok${_C_RESET}"; BADM="${_C_YEL}check${_C_RESET}"
row() { printf '   %-40s %s\n' "$1" "$2"; }

step "claude-secondbrain doctor"
info "Vault: $VAULT"

# Vault scaffold
[ -d "$VAULT/wiki" ] && row "wiki/ tree" "$OKM" || row "wiki/ tree" "$BADM  → bin/setup-vault.sh"

# Community plugins present + enabled
step "Community plugins"
CP="$VAULT/.obsidian/community-plugins.json"
while IFS= read -r id; do
  [ -n "$id" ] || continue
  present=0; enabled=0
  [ -f "$VAULT/.obsidian/plugins/$id/main.js" ] && present=1
  [ -f "$CP" ] && grep -q "\"$id\"" "$CP" && enabled=1
  if [ "$present" = 1 ] && [ "$enabled" = 1 ]; then row "$id" "$OKM"
  else row "$id" "$BADM  (files:$present enabled:$enabled)"; fi
done < <(manifest_get 'm.obsidianPlugins.map(p=>p.id).join("\n")')

# MCP key handshake: data.json apiKey == ~/.claude.json OBSIDIAN_API_KEY
step "MCP key handshake"
DATA="$VAULT/.obsidian/plugins/obsidian-local-rest-api/data.json"
CLAUDE_JSON="$HOME/.claude.json"
if [ -f "$DATA" ] && [ -f "$CLAUDE_JSON" ]; then
  match="$(node -e '
    try{
      const d=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      const c=JSON.parse(require("fs").readFileSync(process.argv[2],"utf8"));
      const s=(c.mcpServers&&c.mcpServers.obsidian)||{};
      const envKey=(s.env&&s.env.OBSIDIAN_API_KEY)||"";
      process.stdout.write(d.apiKey && envKey && d.apiKey===envKey ? "yes":"no");
    }catch(e){process.stdout.write("no")}
  ' "$DATA" "$CLAUDE_JSON" 2>/dev/null)"
  [ "$match" = yes ] && row "REST API key == MCP env key" "$OKM" \
    || row "REST API key == MCP env key" "$BADM  → bin/setup-mcp.sh"
else
  row "REST API key == MCP env key" "$BADM  (data.json or ~/.claude.json missing)"
fi

# claude-obsidian plugin + skills
step "Claude Code"
if have_cmd claude; then
  claude plugin list 2>/dev/null | grep -q claude-obsidian \
    && row "claude-obsidian plugin" "$OKM" || row "claude-obsidian plugin" "$BADM  → bin/setup-claude-obsidian.sh"
  claude mcp list 2>/dev/null | grep -q obsidian \
    && row "obsidian MCP server" "$OKM" || row "obsidian MCP server" "$BADM  → bin/setup-mcp.sh"
else
  row "claude CLI" "$BADM  (install Claude Code)"
fi

# Live REST API probe (only meaningful if Obsidian is running)
step "Live REST API probe (optional)"
if [ -f "$DATA" ]; then
  KEY="$(node -e 'try{process.stdout.write(require(process.argv[1]).apiKey||"")}catch(e){}' "$DATA" 2>/dev/null)"
  if [ -n "$KEY" ] && curl -fsk -m 3 -H "Authorization: Bearer $KEY" https://127.0.0.1:27124/ >/dev/null 2>&1; then
    row "https://127.0.0.1:27124" "$OKM (Obsidian + REST API live)"
  else
    row "https://127.0.0.1:27124" "$BADM  (open the vault in Obsidian + enable Local REST API)"
  fi
fi

step "Doctor complete"
exit 0
