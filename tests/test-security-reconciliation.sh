#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tsb-security-reconcile.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# Build a hermetic copy so manifest hashes can point at tiny local fixtures.
FIX_REPO="$TEST_ROOT/repo"
mkdir -p "$FIX_REPO/scripts" "$TEST_ROOT/bin" "$TEST_ROOT/fixtures"
cp "$ROOT/scripts/common.sh" "$ROOT/scripts/install-obsidian-plugin.sh" "$FIX_REPO/scripts/"
printf '{"id":"fixture-plugin","version":"1.0.0"}\n' > "$TEST_ROOT/fixtures/manifest.json"
printf 'console.log("verified fixture");\n' > "$TEST_ROOT/fixtures/main.js"
printf '.fixture { color: green; }\n' > "$TEST_ROOT/fixtures/styles.css"
mh="$(shasum -a 256 "$TEST_ROOT/fixtures/manifest.json" | cut -d' ' -f1)"
jh="$(shasum -a 256 "$TEST_ROOT/fixtures/main.js" | cut -d' ' -f1)"
sh="$(shasum -a 256 "$TEST_ROOT/fixtures/styles.css" | cut -d' ' -f1)"
node -e '
  const fs=require("fs"),[f,m,j,s]=process.argv.slice(1);
  fs.writeFileSync(f,JSON.stringify({obsidianPlugins:[{id:"fixture-plugin",repo:"owner/repo",tag:"1.0.0",sha256:{"manifest.json":m,"main.js":j,"styles.css":s}}]},null,2)+"\n")
' "$FIX_REPO/manifest.json" "$mh" "$jh" "$sh"

cat > "$TEST_ROOT/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[ "${TSB_CURL_MUST_NOT_RUN:-0}" != 1 ] || exit 99
out=""; url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    http*) url="$1"; shift ;;
    *) shift ;;
  esac
done
asset="${url##*/}"
[ -n "$out" ] && [ -f "$TSB_FIXTURES/$asset" ] || exit 22
if [ "$asset" = main.js ] && [ "${TSB_BAD_MAIN:-0}" = 1 ]; then
  printf 'tampered download\n' > "$out"
else
  cp "$TSB_FIXTURES/$asset" "$out"
fi
SH
chmod +x "$TEST_ROOT/bin/curl"
export PATH="$TEST_ROOT/bin:$PATH" TSB_FIXTURES="$TEST_ROOT/fixtures"

VAULT="$TEST_ROOT/vault"
PD="$VAULT/.obsidian/plugins/fixture-plugin"
mkdir -p "$PD"
cp "$TEST_ROOT/fixtures/"* "$PD/"
printf '{"apiKey":"preserve-me","custom":true}\n' > "$PD/data.json"
printf 'custom\n' > "$PD/custom-user-file.txt"

# Matching assets are a true no-op for the plugin directory.
before="$(find "$PD" -type f -exec shasum -a 256 {} \; | sort)"
bash "$FIX_REPO/scripts/install-obsidian-plugin.sh" "$VAULT" fixture-plugin owner/repo 1.0.0 --yes >/dev/null
after="$(find "$PD" -type f -exec shasum -a 256 {} \; | sort)"
[ "$before" = "$after" ] || fail "matching plugin mutated"

# Drift is repaired while settings and unknown files survive.
printf 'local drift\n' > "$PD/main.js"
bash "$FIX_REPO/scripts/install-obsidian-plugin.sh" "$VAULT" fixture-plugin owner/repo 1.0.0 --yes >/dev/null
cmp "$PD/main.js" "$TEST_ROOT/fixtures/main.js"
grep -q 'preserve-me' "$PD/data.json" || fail "data.json was not preserved"
grep -q '^custom$' "$PD/custom-user-file.txt" || fail "custom file was not preserved"

# A bad staged download leaves the live plugin byte-for-byte unchanged.
printf 'local drift two\n' > "$PD/main.js"
live_before="$(find "$PD" -type f -exec shasum -a 256 {} \; | sort)"
if TSB_BAD_MAIN=1 bash "$FIX_REPO/scripts/install-obsidian-plugin.sh" "$VAULT" fixture-plugin owner/repo 1.0.0 --yes >/dev/null 2>&1; then
  fail "bad download was accepted"
fi
live_after="$(find "$PD" -type f -exec shasum -a 256 {} \; | sort)"
[ "$live_before" = "$live_after" ] || fail "failed verification changed live files"

# Dry-run detects drift without network or filesystem mutation.
TSB_CURL_MUST_NOT_RUN=1 bash "$FIX_REPO/scripts/install-obsidian-plugin.sh" "$VAULT" fixture-plugin owner/repo 1.0.0 --dry-run --yes >/dev/null
[ "$live_before" = "$(find "$PD" -type f -exec shasum -a 256 {} \; | sort)" ] || fail "dry-run mutated plugin"

# Custom repositories require a deliberate flag.
if bash "$FIX_REPO/scripts/install-obsidian-plugin.sh" "$VAULT" custom-plugin owner/custom latest --yes >/dev/null 2>&1; then
  fail "unverified custom plugin installed without opt-in"
fi
bash "$FIX_REPO/scripts/install-obsidian-plugin.sh" "$VAULT" custom-plugin owner/custom latest --allow-unverified --yes >/dev/null 2>&1
[ -f "$VAULT/.obsidian/plugins/custom-plugin/main.js" ] || fail "explicit custom plugin install failed"

# Fake Claude CLI for hermetic registration/rollback tests.
cat > "$TEST_ROOT/bin/claude" <<'JS'
#!/usr/bin/env node
const fs=require("fs"),path=require("path"),a=process.argv.slice(2),home=process.env.HOME;
const f=path.join(home,".claude.json");
const read=()=>{try{return JSON.parse(fs.readFileSync(f,"utf8"))}catch{return {mcpServers:{}}}};
const write=j=>fs.writeFileSync(f,JSON.stringify(j,null,2)+"\n");
if(a[0]==="mcp"&&a[1]==="list"){
  const j=read();for(const [n,s] of Object.entries(j.mcpServers||{}))console.log(`${n}: ${s.command||""}`);process.exit(0);
}
if(a[0]==="mcp"&&a[1]==="remove"){
  const j=read();delete (j.mcpServers||{})[a[2]];write(j);process.exit(0);
}
if(a[0]==="mcp"&&a[1]==="add"){
  if(process.env.TSB_FAIL_ADD==="1")process.exit(9);
  const name=a[2],env={},cut=a.indexOf("--");
  for(let i=3;i<cut;i++)if((a[i]==="-e"||a[i]==="--env")&&a[i+1]){const p=a[++i].indexOf("=");env[a[i].slice(0,p)]=a[i].slice(p+1)}
  const cmd=a.slice(cut+1),j=read();j.mcpServers||={};j.mcpServers[name]={type:"stdio",command:cmd[0],args:cmd.slice(1),env};write(j);process.exit(0);
}
if(a[0]==="plugin"&&a[1]==="list")process.exit(0);
process.exit(0);
JS
chmod +x "$TEST_ROOT/bin/claude"

FAKE_HOME="$TEST_ROOT/home"; mkdir -p "$FAKE_HOME"
MCP_VAULT="$TEST_ROOT/mcp-vault"; REST="$MCP_VAULT/.obsidian/plugins/obsidian-local-rest-api"
mkdir -p "$REST"
KEY="fixture-secret-key-never-print"
printf '{"apiKey":"%s","enableInsecureServer":false}\n' "$KEY" > "$REST/data.json"
chmod 600 "$REST/data.json"
printf '.obsidian/plugins/obsidian-local-rest-api/\n' > "$MCP_VAULT/.gitignore"
node -e '
  const fs=require("fs"),f=process.argv[1],key=process.argv[2];
  fs.writeFileSync(f,JSON.stringify({mcpServers:{obsidian:{type:"stdio",command:"uvx",args:["mcp-obsidian"],env:{OBSIDIAN_HOST:"127.0.0.1",OBSIDIAN_PORT:"27124",NODE_TLS_REJECT_UNAUTHORIZED:"0",OBSIDIAN_API_KEY:key}},unrelated:{command:"other",args:[],env:{KEEP:"yes"}}}},null,2)+"\n")
' "$FAKE_HOME/.claude.json" "$KEY"

out="$(HOME="$FAKE_HOME" bash "$ROOT/bin/setup-mcp.sh" "$MCP_VAULT" --yes)"
printf '%s' "$out" | grep -qF "$KEY" && fail "MCP key leaked to setup output"
node -e '
  const c=require(process.argv[1]),key=process.argv[2],s=c.mcpServers.obsidian;
  if(s.command!=="uvx"||JSON.stringify(s.args)!==JSON.stringify(["--from","mcp-obsidian==0.2.2","mcp-obsidian"]))process.exit(1);
  if(s.env.OBSIDIAN_API_KEY!==key||"NODE_TLS_REJECT_UNAUTHORIZED" in s.env)process.exit(2);
  if(c.mcpServers.unrelated.env.KEEP!=="yes")process.exit(3);
' "$FAKE_HOME/.claude.json" "$KEY" || fail "MCP reconciliation produced wrong config"

stable="$(shasum -a 256 "$FAKE_HOME/.claude.json")"
HOME="$FAKE_HOME" bash "$ROOT/bin/setup-mcp.sh" "$MCP_VAULT" --yes >/dev/null
[ "$stable" = "$(shasum -a 256 "$FAKE_HOME/.claude.json")" ] || fail "second MCP setup mutated config"

# Doctor reports pin + secret posture without revealing the key.
git -C "$MCP_VAULT" init -q
git -C "$MCP_VAULT" config user.email test@example.com
git -C "$MCP_VAULT" config user.name "Doctor Test"
git -C "$MCP_VAULT" add .gitignore
git -C "$MCP_VAULT" commit -qm baseline
doctor_out="$(HOME="$FAKE_HOME" bash "$ROOT/bin/doctor.sh" "$MCP_VAULT")"
printf '%s' "$doctor_out" | grep -qF "$KEY" && fail "Doctor printed the MCP key"
printf '%s' "$doctor_out" | grep -q 'MCP command pin.*ok' || fail "Doctor missed valid MCP pin"
printf '%s' "$doctor_out" | grep -q 'REST API config mode.*ok (600)' || fail "Doctor missed secure file mode"
printf '%s' "$doctor_out" | grep -q 'REST API config ignored.*ok' || fail "Doctor missed Git ignore"
chmod 644 "$REST/data.json"
mode_out="$(HOME="$FAKE_HOME" bash "$ROOT/bin/doctor.sh" "$MCP_VAULT")"
printf '%s' "$mode_out" | grep -q 'REST API config mode.*check.*expected 600' || fail "Doctor missed insecure mode"
chmod 600 "$REST/data.json"
git -C "$MCP_VAULT" add -f .obsidian/plugins/obsidian-local-rest-api/data.json
tracked_out="$(HOME="$FAKE_HOME" bash "$ROOT/bin/doctor.sh" "$MCP_VAULT")"
printf '%s' "$tracked_out" | grep -q 'REST API config tracked.*SECRET IS TRACKED' || fail "Doctor missed tracked secret"
git -C "$MCP_VAULT" reset -q

# Restore a legacy config, force add failure, and require byte-exact rollback.
node -e '
  const fs=require("fs"),f=process.argv[1],key=process.argv[2];
  fs.writeFileSync(f,JSON.stringify({mcpServers:{obsidian:{command:"uvx",args:["mcp-obsidian"],env:{OBSIDIAN_API_KEY:key}},unrelated:{command:"other",args:[]}}},null,2)+"\n")
' "$FAKE_HOME/.claude.json" "$KEY"
rollback_before="$(shasum -a 256 "$FAKE_HOME/.claude.json")"
if HOME="$FAKE_HOME" TSB_FAIL_ADD=1 bash "$ROOT/bin/setup-mcp.sh" "$MCP_VAULT" --yes >/dev/null 2>&1; then
  fail "forced MCP add failure returned success"
fi
[ "$rollback_before" = "$(shasum -a 256 "$FAKE_HOME/.claude.json")" ] || fail "MCP config rollback was not byte-identical"

echo "ok - plugin integrity reconciliation and transactional MCP pinning"
