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
# the TSB_ARGS array. Usage: parse_common_flags "$@"; set -- "${TSB_ARGS[@]}"
parse_common_flags() {
  TSB_ARGS=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --dry-run) TSB_DRY_RUN=1 ;;
      --yes|-y)  TSB_ASSUME_YES=1 ;;
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
# Echoes the last saved vault path (empty if none).
load_vault_path() { [ -f "$TSB_VAULT_FILE" ] && cat "$TSB_VAULT_FILE" || true; }

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

# ── Action wrapper: honors --dry-run, prints intent ──────────────────────────
# Usage: run <human description> -- <command...>
run() {
  local desc="$1"; shift
  [ "$1" = "--" ] && shift
  if [ "$TSB_DRY_RUN" = "1" ]; then
    printf '%s  [dry-run]%s %s\n' "$_C_YEL" "$_C_RESET" "$desc"
    printf '%s            $ %s%s\n' "$_C_DIM" "$*" "$_C_RESET"
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
  read -r reply </dev/tty || reply=""
  case "$reply" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

# Default-YES variant: Enter accepts, only an explicit n/no declines. Reserve for
# low-risk "freebie" installs (no daemon, no credentials, no data egress) — anything
# needing real consent keeps the default-no confirm above.
confirm_yes() {
  local prompt="$1"
  if [ "$TSB_ASSUME_YES" = "1" ] || [ "$TSB_DRY_RUN" = "1" ]; then
    printf '%s  ?%s %s %s[auto-yes]%s\n' "$_C_BLU" "$_C_RESET" "$prompt" "$_C_DIM" "$_C_RESET"
    return 0
  fi
  local reply
  printf '%s  ?%s %s [Y/n] ' "$_C_BLU" "$_C_RESET" "$prompt"
  read -r reply </dev/tty || reply=""
  case "$reply" in [nN]|[nN][oO]) return 1 ;; *) return 0 ;; esac
}

# ── manifest.json reader (node is a hard dependency of the whole system) ──────
# Usage: manifest_get '<js expression over the parsed object `m`>'
# e.g.   manifest_get 'm.obsidianPlugins.map(p=>p.id).join("\n")'
manifest_get() {
  have_cmd node || die "node is required to read manifest.json (brew install node)."
  node -e '
    const fs = require("fs");
    const m = JSON.parse(fs.readFileSync(process.env.MANIFEST, "utf8"));
    const out = eval(process.argv[1]);
    const s = out == null ? "" : String(out);
    // Always newline-terminate non-empty output so bash `while read` keeps the
    // last line. Command substitution $(...) strips it for scalar callers.
    process.stdout.write(s === "" ? "" : s + "\n");
  ' "$1"
}
