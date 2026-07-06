#!/usr/bin/env bash
# techtrip-secondbrain — wire the Obsidian MCP server.
#   1. generate a Local REST API key (if the vault doesn't have one)
#   2. write .obsidian/plugins/obsidian-local-rest-api/data.json with that key
#      (the plugin regenerates its self-signed cert on first Obsidian launch)
#   3. register the `obsidian` MCP server (uvx mcp-obsidian) at user scope with the
#      SAME key as OBSIDIAN_API_KEY
# Idempotent + interactive.
# Usage: bash bin/setup-mcp.sh [/path/to/vault] [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- "${TSB_ARGS[@]:-}"

VAULT="$(default_vault_path "${1:-}")"
RESTDIR="$VAULT/.obsidian/plugins/obsidian-local-rest-api"
DATA="$RESTDIR/data.json"

step "Obsidian MCP server"
info "Vault: $VAULT"
[ -d "$RESTDIR" ] || warn "Local REST API plugin not installed in this vault yet — run bin/setup-vault.sh first."

# ── 1 + 2. Key + data.json ───────────────────────────────────────────────────
if [ -f "$DATA" ] && node -e 'const d=require(process.argv[1]); process.exit(d.apiKey?0:1)' "$DATA" 2>/dev/null; then
  KEY="$(node -e 'process.stdout.write(require(process.argv[1]).apiKey)' "$DATA")"
  ok "Reusing existing Local REST API key from data.json"
else
  KEY="$(openssl rand -hex 32)"
  if [ "$TSB_DRY_RUN" = "1" ]; then
    info "[dry-run] would generate key + write $DATA"
  else
    mkdir -p "$RESTDIR"
    MANIFEST="" node -e '
      const fs=require("fs"), f=process.argv[1], key=process.argv[2];
      let d={}; try{d=JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){}
      d.apiKey=key; if(d.enableInsecureServer===undefined) d.enableInsecureServer=false;
      fs.writeFileSync(f, JSON.stringify(d,null,2)+"\n");
    ' "$DATA" "$KEY"
    ok "Wrote Local REST API key to data.json (self-signed cert added by Obsidian on first launch)"
  fi
fi

# ── 2b. Keep the key out of git ──────────────────────────────────────────────
# setup-mcp creates data.json (REST key + cert) AFTER the vault's initial scaffold
# commit, so nothing gitignores it by default — one `git add -A` later and the key
# is in history. Seed the vault .gitignore here, idempotently.
GITIGNORE="$VAULT/.gitignore"
IGNORE_LINE=".obsidian/plugins/obsidian-local-rest-api/"
if [ -f "$GITIGNORE" ] && grep -qxF "$IGNORE_LINE" "$GITIGNORE"; then
  ok ".gitignore already excludes the Local REST API plugin dir"
elif [ "$TSB_DRY_RUN" = "1" ]; then
  info "[dry-run] would append '$IGNORE_LINE' to $GITIGNORE"
else
  printf '%s\n' "$IGNORE_LINE" >> "$GITIGNORE"
  ok "Added '$IGNORE_LINE' to vault .gitignore (REST key + cert stay out of git)"
fi

# ── 3. Register the MCP server ───────────────────────────────────────────────
step "Register MCP server (user scope)"
have_cmd claude || die "claude CLI not found — install Claude Code first."
NAME="$(manifest_get 'm.mcpServers[0].name')"

if claude mcp list 2>/dev/null | grep -q "^${NAME}\b\|[[:space:]]${NAME}[[:space:]]"; then
  ok "MCP server '$NAME' already registered (leaving as-is; delete + re-run to rotate key)"
  exit 0
fi

# Build -e KEY=VAL args from manifest env, then inject the API key.
env_args=()
while IFS=$'\t' read -r k v; do
  [ -n "$k" ] || continue
  env_args+=( -e "$k=$v" )
done < <(manifest_get 'Object.entries(m.mcpServers[0].env).map(([k,v])=>[k,v].join("\t")).join("\n")')
env_args+=( -e "OBSIDIAN_API_KEY=$KEY" )

CMD="$(manifest_get 'm.mcpServers[0].command')"
ARGS="$(manifest_get 'm.mcpServers[0].args.join(" ")')"

if confirm "Register MCP server '$NAME' ($CMD $ARGS) at user scope?"; then
  # shellcheck disable=SC2086
  run "Registering $NAME MCP server" -- \
    claude mcp add "$NAME" --scope user "${env_args[@]}" -- $CMD $ARGS
  ok "MCP server '$NAME' registered"
  info "It becomes callable after a Claude session reload, and answers only once Obsidian"
  info "is running with the Local REST API plugin enabled (Settings → Community plugins)."
else
  warn "Skipped MCP registration. yt-fetch/ingest still work; direct Obsidian API access won't."
fi
