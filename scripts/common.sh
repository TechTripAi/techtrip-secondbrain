#!/usr/bin/env bash
# techtrip-secondbrain — shared helpers sourced by every bin/ and scripts/ file.
# Not meant to be executed directly.

# ── Strictness (callers may already set these; harmless to repeat) ────────────
set -o pipefail

# ── Paths ─────────────────────────────────────────────────────────────────────
# REPO_ROOT = the techtrip-secondbrain checkout (one level up from scripts/).
COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$COMMON_DIR/.." && pwd)"
export MANIFEST="${MANIFEST:-$REPO_ROOT/manifest.json}"

# ── Flags (env-overridable; parsed by parse_common_flags) ────────────────────
# Exported so child scripts (e.g. install-obsidian-plugin.sh spawned by
# setup-vault.sh) inherit dry-run / assume-yes. `export` persists across the
# later assignments in parse_common_flags.
export TSB_DRY_RUN="${TSB_DRY_RUN:-0}"      # 1 = print actions, mutate nothing
export TSB_ASSUME_YES="${TSB_ASSUME_YES:-0}" # 1 = auto-confirm every prompt

# Parse --dry-run / --yes / -y out of "$@"; leaves other args untouched via
# the TSB_ARGS array. `--` ends flag parsing (an arg literally named --dry-run
# is then kept as an arg). Usage:
#   parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}
# (The ${arr[@]+...} idiom expands to *nothing* when the array is empty; the
# older "${TSB_ARGS[@]:-}" injected one phantom empty positional.)
parse_common_flags() {
  TSB_ARGS=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) TSB_DRY_RUN=1 ;;
      --yes|-y)  TSB_ASSUME_YES=1 ;;
      --)        shift; TSB_ARGS+=("$@"); break ;;
      *)         TSB_ARGS+=("$1") ;;
    esac
    shift
  done
}

# ── Colored logging (auto-disabled when not a TTY) ───────────────────────────
if [ -t 1 ]; then
  _C_RESET=$'\033[0m'; _C_DIM=$'\033[2m'; _C_RED=$'\033[31m'
  _C_GRN=$'\033[32m'; _C_YEL=$'\033[33m'; _C_BLU=$'\033[34m'; _C_BLD=$'\033[1m'
else
  _C_RESET=""; _C_DIM=""; _C_RED=""; _C_GRN=""; _C_YEL=""; _C_BLU=""; _C_BLD=""
fi

step() { printf '\n%s==>%s %s%s%s\n' "$_C_BLU" "$_C_RESET" "$_C_BLD" "$*" "$_C_RESET"; }
info() { printf '%s   %s\n' "$_C_DIM" "$*$_C_RESET"; }
ok()   { printf '%s  ✓%s %s\n' "$_C_GRN" "$_C_RESET" "$*"; }
warn() { printf '%s  !%s %s\n' "$_C_YEL" "$_C_RESET" "$*" >&2; }
err()  { printf '%s  ✗%s %s\n' "$_C_RED" "$_C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ── Guards ───────────────────────────────────────────────────────────────────
require_macos() {
  [ "$(uname -s)" = "Darwin" ] || die "techtrip-secondbrain MVP supports macOS only (found $(uname -s))."
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# ── Cross-script state: remember the chosen vault path ───────────────────────
TSB_STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/techtrip-secondbrain"
TSB_VAULT_FILE="$TSB_STATE_DIR/vault-path"

save_vault_path() {
  [ "$TSB_DRY_RUN" = "1" ] && return 0
  mkdir -p "$TSB_STATE_DIR"; printf '%s\n' "$1" > "$TSB_VAULT_FILE"
}
# Echoes the last saved vault path (empty if none). The state file is
# validated on read-back — it must be a single absolute path — so a corrupted
# or tampered file can't silently redirect later mutations.
load_vault_path() {
  local saved
  [ -f "$TSB_VAULT_FILE" ] || return 0
  saved="$(head -n1 "$TSB_VAULT_FILE" 2>/dev/null)"
  case "$saved" in
    /*) printf '%s' "$saved" ;;
    "") ;;
    *)  warn "Ignoring invalid saved vault path in $TSB_VAULT_FILE (not absolute)." ;;
  esac
}

# Resolve a vault path from: $1 (explicit) → saved state → default ~/LLM-Wiki.
default_vault_path() {
  local explicit="${1:-}" saved
  if [ -n "$explicit" ]; then printf '%s' "$explicit"; return; fi
  saved="$(load_vault_path)"
  if [ -n "$saved" ]; then printf '%s' "$saved"; return; fi
  printf '%s' "$HOME/LLM-Wiki"
}

# Locate the installed claude-obsidian plugin's bin/setup-vault.sh (newest version).
find_claude_obsidian_setup() {
  local hit
  hit="$(ls -1d "$HOME"/.claude/plugins/cache/*/claude-obsidian/*/bin/setup-vault.sh 2>/dev/null | sort -V | tail -1)"
  [ -n "$hit" ] && printf '%s' "$hit" || return 1
}

# Echo the installed claude-obsidian version (the version dir under the plugin cache).
# claude-obsidian is by AgriciDaniel: https://github.com/AgriciDaniel/claude-obsidian
claude_obsidian_installed_version() {
  local dir
  dir="$(ls -1d "$HOME"/.claude/plugins/cache/*/claude-obsidian/*/ 2>/dev/null | sort -V | tail -1)"
  [ -n "$dir" ] && basename "$dir" || return 1
}

# ── Dead plugin-cache permission rules (report-only detector) ─────────────────
# Claude Code saves approved permission rules into settings.local.json with the
# versioned plugin-cache path baked in (…/plugins/cache/<mp>/<plugin>/<ver>/…).
# Every plugin update moves that root, stranding the old rules: they can never
# match a command again, the user gets re-prompted, and Claude's built-in
# /doctor flags them as invalid. A rule is dead when its glob-free cache path's
# version dir is missing OR superseded by a newer installed version (old dirs
# can linger in the cache after an update). Glob rules (…/cache/**) and rules
# whose version is still the newest are left alone.
# Echoes one "<list>\t<rule>" line per dead rule (list = allow|deny|ask).
stale_permission_rules() {  # <settings.local.json>
  local f="$1"
  [ -f "$f" ] || return 0
  have_cmd node || return 0
  node -e '
    const fs=require("fs");
    let j;try{j=JSON.parse(fs.readFileSync(process.argv[1],"utf8"))}catch(e){process.exit(0)}
    const p=(j&&j.permissions)||{};
    const marker=".claude/plugins/cache/";
    // Path chars stop at whitespace, parens, or any quote (0022/0027/0060 =
    // double quote / single quote / backtick — escaped so this survives the
    // bash single-quoted heredoc-style embedding).
    const stop="\\u0022\\u0027\\u0060\\s()";
    const re=new RegExp("/[^"+stop+"]*\\.claude/plugins/cache/[^"+stop+"]+","g");
    const newest=(dir)=>{ // newest version-dir name under <cache>/<mp>/<plugin>, or ""
      try{
        const v=fs.readdirSync(dir,{withFileTypes:true}).filter(d=>d.isDirectory()).map(d=>d.name);
        return v.sort((a,b)=>a.localeCompare(b,undefined,{numeric:true})).pop()||"";
      }catch(e){return ""}
    };
    for(const list of ["allow","deny","ask"]){
      const rules=Array.isArray(p[list])?p[list]:[];
      const seen=new Set();
      for(const rule of rules){
        if(typeof rule!=="string"||seen.has(rule))continue;
        seen.add(rule);
        let dead=false;
        for(const m of rule.match(re)||[]){
          const base=m.slice(0,m.indexOf(marker)+marker.length);
          const segs=m.slice(base.length).split("/");
          if(segs.length<3)continue;                    // no version segment
          const [mp,plug,ver]=segs;
          if([mp,plug,ver].some(s=>s.includes("*")))continue; // glob — leave alone
          if(!fs.existsSync(base+[mp,plug,ver].join("/"))){dead=true;break}
          const top=newest(base+mp+"/"+plug);
          if(top&&top!==ver){dead=true;break}           // superseded version
        }
        if(dead)console.log(list+"\t"+rule);
      }
    }
  ' "$f" 2>/dev/null
}

# ── Action wrapper: honors --dry-run, prints intent ──────────────────────────
# Usage: run <human description> -- <command...>
# The dry-run echo redacts values of KEY=/TOKEN=/SECRET=/PASSWORD= args so a
# pasted --dry-run transcript never leaks a credential.
run() {
  local desc="$1"; shift
  [ "$1" = "--" ] && shift
  if [ "$TSB_DRY_RUN" = "1" ]; then
    local shown=() a
    for a in "$@"; do
      case "$a" in
        *KEY=*|*TOKEN=*|*SECRET=*|*PASSWORD=*) shown+=("${a%%=*}=<redacted>") ;;
        *) shown+=("$a") ;;
      esac
    done
    printf '%s  [dry-run]%s %s\n' "$_C_YEL" "$_C_RESET" "$desc"
    printf '%s            $ %s%s\n' "$_C_DIM" "${shown[*]}" "$_C_RESET"
    return 0
  fi
  info "$desc"
  "$@"
}

# ── Interactive confirm gate ─────────────────────────────────────────────────
# Usage: confirm "Install Obsidian?" && do_it
# Returns 0 (yes) / 1 (no). Auto-yes under --yes; auto-yes-preview under --dry-run.
confirm() {
  local prompt="$1"
  if [ "$TSB_ASSUME_YES" = "1" ] || [ "$TSB_DRY_RUN" = "1" ]; then
    printf '%s  ?%s %s %s[auto-yes]%s\n' "$_C_BLU" "$_C_RESET" "$prompt" "$_C_DIM" "$_C_RESET"
    return 0
  fi
  local reply
  printf '%s  ?%s %s [y/N] ' "$_C_BLU" "$_C_RESET" "$prompt"
  if ! read -r reply </dev/tty; then
    warn "No TTY to ask on — declining. Pass --yes to auto-confirm."
    return 1
  fi
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# Default-YES variant: Enter accepts, only an explicit n/no declines. Reserve for
# (a) low-risk "freebie" installs (no daemon, no credentials, no data egress) and
# (b) provably-safe cleanups whose worst case is a re-prompt or re-run (e.g.
# prune-permissions.sh removing dead rules, backed up first) — anything
# needing real consent keeps the default-no confirm above.
confirm_yes() {
  local prompt="$1"
  if [ "$TSB_ASSUME_YES" = "1" ] || [ "$TSB_DRY_RUN" = "1" ]; then
    printf '%s  ?%s %s %s[auto-yes]%s\n' "$_C_BLU" "$_C_RESET" "$prompt" "$_C_DIM" "$_C_RESET"
    return 0
  fi
  local reply
  printf '%s  ?%s %s [Y/n] ' "$_C_BLU" "$_C_RESET" "$prompt"
  # Default-yes applies only to a real Enter keypress. A failed read (no TTY:
  # cron/CI/headless agent) must NOT consent on the user's behalf.
  if ! read -r reply </dev/tty; then
    warn "No TTY to ask on — declining. Pass --yes to auto-confirm."
    return 1
  fi
  case "$reply" in [nN]|[nN][oO]) return 1 ;; *) return 0 ;; esac
}

# ── Manifest command strings → argv (never `bash -c`) ────────────────────────
# manifest.json declares install/probe/login commands as strings ("brew install
# yt-dlp"). Executing those via a shell would turn the manifest into an
# arbitrary-code channel; instead split into argv with NO shell interpretation,
# reject metacharacters outright, and require an allowlisted first token.
# Usage: manifest_argv "brew uv" "$install"  → populates TSB_CMD_ARGV array.
manifest_argv() {
  local allow="$1" str="$2"
  case "$str" in
    *[\;\&\|\<\>\$\`\\\'\"]*|*'('*|*')'*|*$'\n'*)
      die "manifest command contains shell metacharacters — refusing: $str" ;;
  esac
  read -r -a TSB_CMD_ARGV <<<"$str"
  [ "${#TSB_CMD_ARGV[@]}" -gt 0 ] || die "manifest command is empty"
  case " $allow " in
    *" ${TSB_CMD_ARGV[0]} "*) ;;
    *) die "manifest command '$str' must start with one of: $allow" ;;
  esac
}

# ── manifest.json reader (node is a hard dependency of the whole system) ──────
# Usage: manifest_get '<js expression over the parsed object `m`>'
# e.g.   manifest_get 'm.obsidianPlugins.map(p=>p.id).join("\n")'
# SECURITY: the expression is evaluated as JS. Call sites MUST pass a literal,
# single-quoted expression — never interpolate a shell variable into it (that
# would be code injection). Pass dynamic values via env/argv instead.
manifest_get() {
  have_cmd node || die "node is required to read manifest.json (brew install node)."
  node -e '
    const fs = require("fs");
    let m;
    try {
      m = JSON.parse(fs.readFileSync(process.env.MANIFEST, "utf8"));
    } catch (e) {
      process.stderr.write("manifest.json unreadable or invalid JSON: " + e.message + "\n");
      process.exit(1);
    }
    const out = eval(process.argv[1]);
    const s = out == null ? "" : String(out);
    // Always newline-terminate non-empty output so bash `while read` keeps the
    // last line. Command substitution $(...) strips it for scalar callers.
    process.stdout.write(s === "" ? "" : s + "\n");
  ' "$1" || die "manifest_get failed (see error above; manifest: $MANIFEST)"
}
