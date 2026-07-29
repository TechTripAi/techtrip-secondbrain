#!/usr/bin/env bash
# Wire and reconcile the machine-global Obsidian MCP server without rotating a
# healthy vault key. Existing drifted registrations are replaced transactionally.
# Usage: bash bin/setup-mcp.sh [/path/to/vault] [--yes] [--dry-run]
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/common.sh"
parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}

VAULT="$(default_vault_path "${1:-}")"
RESTDIR="$VAULT/.obsidian/plugins/obsidian-local-rest-api"
DATA="$RESTDIR/data.json"
CLAUDE_JSON="$HOME/.claude.json"

step "Obsidian MCP server"
info "Vault: $VAULT"
[ -d "$RESTDIR" ] || warn "Local REST API plugin not installed yet — run bin/setup-vault.sh first."

if [ -f "$DATA" ] && node -e 'const d=require(process.argv[1]);process.exit(d.apiKey?0:1)' "$DATA" 2>/dev/null; then
  KEY="$(node -e 'process.stdout.write(require(process.argv[1]).apiKey)' "$DATA")"
  [ "$TSB_DRY_RUN" = "1" ] || chmod 600 "$DATA" 2>/dev/null || true
  ok "Reusing existing Local REST API key from data.json"
else
  KEY="$(openssl rand -hex 32)"
  if [ "$TSB_DRY_RUN" = "1" ]; then
    info "[dry-run] would generate key + write $DATA"
  else
    run "Create Local REST API config directory" -- mkdir -p "$RESTDIR"
    run "Write Local REST API key without exposing it on argv output" -- \
      env MANIFEST="" TSB_NEW_KEY="$KEY" node -e '
      const fs=require("fs"),f=process.argv[1],key=process.env.TSB_NEW_KEY;
      let d={};try{d=JSON.parse(fs.readFileSync(f,"utf8"))}catch(e){}
      d.apiKey=key;if(d.enableInsecureServer===undefined)d.enableInsecureServer=false;
      fs.writeFileSync(f,JSON.stringify(d,null,2)+"\n");
    ' "$DATA"
    run "Restrict Local REST API config permissions" -- chmod 600 "$DATA"
    ok "Wrote Local REST API key to data.json, mode 600"
  fi
fi

GITIGNORE="$VAULT/.gitignore"
IGNORE_LINE=".obsidian/plugins/obsidian-local-rest-api/"
if [ -f "$GITIGNORE" ] && grep -qxF "$IGNORE_LINE" "$GITIGNORE"; then
  ok ".gitignore already excludes the Local REST API plugin dir"
elif [ "$TSB_DRY_RUN" = "1" ]; then
  info "[dry-run] would append '$IGNORE_LINE' to $GITIGNORE"
else
  run "Create vault root for .gitignore" -- mkdir -p "$VAULT"
  run "Append REST plugin exclusion to vault .gitignore" -- node -e '
    require("fs").appendFileSync(process.argv[1],process.argv[2]+"\n")
  ' "$GITIGNORE" "$IGNORE_LINE"
  ok "Added REST plugin directory to vault .gitignore"
fi

step "Register MCP server (user scope)"
have_cmd claude || die "claude CLI not found — install Claude Code first."
NAME="$(manifest_get 'm.mcpServers[0].name')"
SCOPE="$(manifest_get 'm.mcpServers[0].scope')"
CMD="$(manifest_get 'm.mcpServers[0].command')"
cmd_args=()
while IFS= read -r arg; do [ -n "$arg" ] && cmd_args+=("$arg"); done \
  < <(manifest_get 'm.mcpServers[0].args.join("\n")')
env_args=()
while IFS=$'\t' read -r k v; do
  [ -n "$k" ] && env_args+=( -e "$k=$v" )
done < <(manifest_get 'Object.entries(m.mcpServers[0].env).map(([k,v])=>`${k}\t${v}`).join("\n")')
env_args+=( -e "OBSIDIAN_API_KEY=$KEY" )

registered=0
if [ -f "$CLAUDE_JSON" ] && TSB_MCP_NAME="$NAME" node -e '
  try{const c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
  process.exit(c.mcpServers&&c.mcpServers[process.env.TSB_MCP_NAME]?0:1)}catch(e){process.exit(1)}
' "$CLAUDE_JSON" 2>/dev/null; then
  registered=1
fi

matches=0
if [ "$registered" = "1" ] && \
   TSB_MCP_NAME="$NAME" TSB_MCP_KEY="$KEY" node -e '
    const fs=require("fs");
    try{
      const c=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
      const m=JSON.parse(fs.readFileSync(process.argv[2],"utf8")).mcpServers[0];
      const s=c.mcpServers[process.env.TSB_MCP_NAME]||{};
      const wantEnv={...(m.env||{}),OBSIDIAN_API_KEY:process.env.TSB_MCP_KEY};
      const eq=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
      const sameEnv=Object.keys(wantEnv).sort().every(k=>s.env&&s.env[k]===wantEnv[k]) &&
        Object.keys(s.env||{}).sort().every(k=>Object.hasOwn(wantEnv,k));
      process.exit(s.command===m.command&&eq(s.args||[],m.args||[])&&sameEnv?0:1);
    }catch(e){process.exit(1)}
  ' "$CLAUDE_JSON" "$MANIFEST" 2>/dev/null; then
  matches=1
fi

if [ "$matches" = "1" ]; then
  ok "MCP server '$NAME' matches the pinned command, environment, and vault key"
  exit 0
fi

desired="$CMD ${cmd_args[*]}"
if [ "$registered" = "1" ]; then
  warn "MCP server '$NAME' is registered but differs from the pinned configuration."
  if ! confirm "Back up its config and reconcile '$NAME' to '$desired' without rotating the key?"; then
    warn "Left the existing MCP registration unchanged."
    exit 0
  fi
else
  confirm "Register MCP server '$NAME' ($desired) at user scope?" || {
    warn "Skipped MCP registration."; exit 0;
  }
fi

if [ "$TSB_DRY_RUN" = "1" ]; then
  [ "$registered" = "1" ] && run "Remove drifted $NAME registration" -- claude mcp remove "$NAME" --scope "$SCOPE"
  run "Register pinned $NAME MCP server" -- \
    claude mcp add "$NAME" --scope "$SCOPE" "${env_args[@]}" -- "$CMD" "${cmd_args[@]}"
  exit 0
fi

BACKUP=""
RESTORE_PENDING=0
restore_registration_on_exit() {
  rc=$?
  trap - EXIT
  if [ "$RESTORE_PENDING" = "1" ] && [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
    cp -p "$BACKUP" "$CLAUDE_JSON" 2>/dev/null || true
    chmod 600 "$CLAUDE_JSON" 2>/dev/null || true
    warn "Restored the previous Claude configuration after interrupted/failed MCP reconciliation."
  fi
  [ -n "$BACKUP" ] && [ -f "$BACKUP" ] && rm -f "$BACKUP"
  exit "$rc"
}
if [ "$registered" = "1" ]; then
  old_umask="$(umask)"; umask 077
  BACKUP="$(mktemp "${TMPDIR:-/tmp}/tsb-claude-config.XXXXXX")"
  umask "$old_umask"
  run "Create transactional Claude config backup" -- cp -p "$CLAUDE_JSON" "$BACKUP"
  run "Restrict transactional config backup" -- chmod 600 "$BACKUP"
  RESTORE_PENDING=1
  trap restore_registration_on_exit EXIT
  if ! run "Remove drifted $NAME registration" -- claude mcp remove "$NAME" --scope "$SCOPE"; then
    die "could not remove the drifted registration; original config remains active"
  fi
fi

if ! run "Register pinned $NAME MCP server" -- \
  claude mcp add "$NAME" --scope "$SCOPE" "${env_args[@]}" -- "$CMD" "${cmd_args[@]}"; then
  die "MCP registration failed; previous Claude configuration will be restored"
fi

RESTORE_PENDING=0
if [ -n "$BACKUP" ]; then
  run "Remove successful transactional config backup" -- rm -f "$BACKUP"
  BACKUP=""
fi
trap - EXIT
ok "MCP server '$NAME' registered with pinned mcp-obsidian 0.2.2; vault key preserved"
info "Reload the Claude session to activate the reconciled MCP process."
