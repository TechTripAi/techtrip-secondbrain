#!/usr/bin/env bash
# The pages secondbrain ships into a vault (origination workflow page + project
# templates) and a freshly stamped project must lint clean under claude-obsidian
# 1.9.7's deterministic engine (scripts/wiki-lint.py). Hermetic: builds the vault
# from the shipped assets with cp, touches no network, no user state, no $HOME.
# Skips when no engine is available or python3 < 3.11.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tsb-lint-clean.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# Engine lookup: explicit override, then sibling checkout, then newest plugin cache.
ENGINE=""
if [ -n "${CLAUDE_OBSIDIAN_ROOT:-}" ] && [ -f "$CLAUDE_OBSIDIAN_ROOT/scripts/wiki-lint.py" ]; then
  ENGINE="$CLAUDE_OBSIDIAN_ROOT/scripts/wiki-lint.py"
elif [ -f "$ROOT/../claude-obsidian/scripts/wiki-lint.py" ]; then
  ENGINE="$ROOT/../claude-obsidian/scripts/wiki-lint.py"
else
  hit="$(ls -1d "$HOME"/.claude/plugins/cache/*/claude-obsidian/*/scripts/wiki-lint.py 2>/dev/null | sort -V | tail -1 || true)"
  [ -n "$hit" ] && ENGINE="$hit"
fi
if [ -z "$ENGINE" ]; then echo "SKIP: no claude-obsidian 1.9.7 engine found (set CLAUDE_OBSIDIAN_ROOT)"; exit 0; fi
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3,11) else 1)' || { echo "SKIP: python3 < 3.11"; exit 0; }

# Isolate every state path a script might touch, then build the vault from assets
# exactly as setup-vault's existence-guarded seeding does (cp of the same files).
export XDG_CONFIG_HOME="$TEST_ROOT/config" HOME="$TEST_ROOT/home"
mkdir -p "$HOME"
VAULT="$TEST_ROOT/vault"
mkdir -p "$VAULT/.obsidian" "$VAULT/wiki/meta/templates" "$VAULT/wiki/projects" "$VAULT/.vault-meta"
cp "$ROOT/assets/vault/wiki/meta/origination-workflow.md" "$VAULT/wiki/meta/origination-workflow.md"
cp -R "$ROOT/assets/vault/wiki/meta/templates/origination-project" "$VAULT/wiki/meta/templates/origination-project"
# Same lint config setup-vault seeds (templates share basenames with stamped projects).
printf '{\n  "exclude": ["wiki/meta/templates/*"],\n  "dangling_links": []\n}\n' > "$VAULT/.vault-meta/lint-allowlist.json"
# /wiki creates index.md and log.md on first run; the workflow page links to them.
for p in index log; do
  printf -- '---\ntype: meta\ntitle: "%s"\nstatus: evergreen\ncreated: 2026-01-01\nupdated: 2026-01-01\ntags: [meta]\n---\n\n# %s\n\nSee [[origination-workflow]].\n' "$p" "$p" > "$VAULT/wiki/$p.md"
done

lint_json() { python3 "$ENGINE" --vault "$VAULT" --format json; }
count() { python3 -c 'import json,sys; r=json.load(sys.stdin); s=r["summary"]; print(s["issues_found"], {k:v for k,v in s["category_counts"].items() if v})'; }

read -r issues rest <<<"$(lint_json | count)"
[ "$issues" = "0" ] || { python3 "$ENGINE" --vault "$VAULT" >&2 || true; fail "shipped pages have $issues lint findings: $rest"; }

# Stamp a project (new-idea.sh locates the vault by walking up from $PWD).
(cd "$VAULT" && bash "$ROOT/skills/new-idea/scripts/new-idea.sh" demo-idea --title "Demo" --claim "x" --outcome "y") >"$TEST_ROOT/stamp.log" 2>&1 \
  || { cat "$TEST_ROOT/stamp.log" >&2; fail "new-idea.sh failed"; }
[ -d "$VAULT/wiki/projects/demo-idea" ] || fail "new-idea.sh did not create wiki/projects/demo-idea"
# The /new-idea skill registers the project in index.md after stamping; mirror that.
printf -- '\n- [[projects/demo-idea/project|Demo]]\n' >> "$VAULT/wiki/index.md"

read -r issues rest <<<"$(lint_json | count)"
[ "$issues" = "0" ] || { python3 "$ENGINE" --vault "$VAULT" >&2 || true; fail "stamped project left $issues lint findings: $rest"; }
echo "PASS: shipped pages + stamped project lint clean"
