#!/usr/bin/env bash
# techtrip-secondbrain — post-install health check for a scaffolded vault.
# Report-only; always exits 0. Usage: bash bin/doctor.sh [/path/to/vault]
set -uo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"

VAULT="$(default_vault_path "${1:-}")"
OKM="${_C_GRN}ok${_C_RESET}"; BADM="${_C_YEL}check${_C_RESET}"
row() { printf '   %-40s %s\n' "$1" "$2"; }

step "techtrip-secondbrain doctor"
info "Vault: $VAULT"

# Vault scaffold
[ -d "$VAULT/wiki" ] && row "wiki/ tree" "$OKM" || row "wiki/ tree" "$BADM  → bin/setup-vault.sh"

# Required binaries (manifest-driven; includes claude-obsidian runtime deps like flock).
# Optional binaries are reported by the optional-features section below, not here.
step "Required binaries"
while IFS=$'\t' read -r cmd label install; do
  [ -n "$cmd" ] || continue
  have_cmd "$cmd" && row "$label ($cmd)" "$OKM" \
    || row "$label ($cmd)" "$BADM  → $install"
done < <(manifest_get 'm.binaries.filter(b=>!b.optional).map(b=>[b.cmd,b.label||b.cmd,b.install||""].join("\t")).join("\n")')

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
  if claude plugin list 2>/dev/null | grep -q claude-obsidian; then
    cov="$(claude_obsidian_installed_version 2>/dev/null || true)"
    tested="$(manifest_get 'm.claudePlugins[0].testedVersion')"
    if [ -n "$cov" ] && [ -n "$tested" ] && [ "$cov" != "$tested" ]; then
      row "claude-obsidian plugin" "$BADM  v$cov ≠ tested v$tested (AgriciDaniel; version drift)"
    else
      row "claude-obsidian plugin" "$OKM${cov:+ v$cov} (by AgriciDaniel)"
    fi
    # Upstream bug (≤1.9.2): SessionStart supports only command/mcp_tool hooks, but
    # the plugin ships a type:"prompt" hook there → harmless startup validation
    # warning on stricter clients. REPORT-ONLY: secondbrain never patches
    # claude-obsidian's files (AGENTS.md invariant) — the fix is upstream; advise
    # `claude plugin update` once it ships.
    coh="$(ls -1 "$HOME"/.claude/plugins/cache/*/claude-obsidian/*/hooks/hooks.json 2>/dev/null | sort -V | tail -1)"
    if [ -n "$coh" ]; then
      bad="$(node -e 'try{const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const ss=(j.hooks&&j.hooks.SessionStart)||[];let n=0;for(const g of ss)if(g&&Array.isArray(g.hooks))for(const h of g.hooks)if(h&&h.type==="prompt")n++;process.stdout.write(String(n))}catch(e){process.stdout.write("0")}' "$coh" 2>/dev/null)"
      if [ "${bad:-0}" != 0 ]; then
        row "SessionStart hooks valid" "$BADM  ($bad unsupported prompt hook(s); upstream ≤1.9.2 bug → update claude-obsidian once fixed)"
      else
        row "SessionStart hooks valid" "$OKM"
      fi
    fi
  else row "claude-obsidian plugin" "$BADM  → bin/setup-claude-obsidian.sh"; fi
  claude mcp list 2>/dev/null | grep -q obsidian \
    && row "obsidian MCP server" "$OKM" || row "obsidian MCP server" "$BADM  → bin/setup-mcp.sh"
else
  row "claude CLI" "$BADM  (install Claude Code)"
fi

# Optional features (informational — never a failure; enable via setup-features.sh)
step "Optional features (off by default)"
ONM="${_C_GRN}on${_C_RESET}"; OFFM="${_C_DIM}off${_C_RESET}"
while IFS=$'\t' read -r id label binary; do
  [ -n "$id" ] || continue
  if [ "$id" = notebooklm ]; then
    # 'on' = CLI installed; auth is a separate one-time step.
    have_cmd notebooklm && row "$label" "$ONM (run 'notebooklm login' once if unauthed)" \
      || row "$label" "$OFFM  → bin/setup-features.sh notebooklm"
  elif [ "$id" = syncthing ]; then
    { have_cmd syncthing && [ -f "$VAULT/.stignore" ]; } && row "$label" "$ONM" \
      || row "$label" "$OFFM  → bin/setup-features.sh syncthing"
  else
    have_cmd "$binary" && row "$label" "$ONM" \
      || row "$label" "$OFFM  → bin/setup-features.sh $id"
  fi
done < <(manifest_get 'm.optionalFeatures.map(f=>[f.id,f.label,f.binary||""].join("\t")).join("\n")')

# Live REST API probe (only meaningful if Obsidian is running)
step "Live REST API probe (optional)"
if [ -f "$DATA" ]; then
  KEY="$(node -e 'try{process.stdout.write(require(process.argv[1]).apiKey||"")}catch(e){}' "$DATA" 2>/dev/null)"
  # Probe an AUTHENTICATED endpoint (/vault/) — the root / is unauthenticated and
  # 200s with any/no key, so it can't validate the handshake.
  if [ -n "$KEY" ] && curl -fsk -m 3 -H "Authorization: Bearer $KEY" https://127.0.0.1:27124/vault/ >/dev/null 2>&1; then
    row "https://127.0.0.1:27124/vault/" "$OKM (authenticated — key valid)"
  else
    row "https://127.0.0.1:27124/vault/" "$BADM  (no auth: Obsidian closed, plugin off, or key mismatch)"
  fi
fi

step "Doctor complete"
exit 0
