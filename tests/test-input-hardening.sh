#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tsb-input-hardening.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# Encoder collapses structure-breaking controls and context-escapes output.
yaml="$(node "$ROOT/scripts/encode-text.js" yaml $'bad"\n---\nevil: true')"
[ "$(printf '%s' "$yaml" | wc -l | tr -d ' ')" = 0 ] || fail "YAML encoder emitted a newline"
printf '%s' "$yaml" | grep -q '\\"' || fail "YAML quote was not escaped"
md="$(node "$ROOT/scripts/encode-text.js" markdown $'<tag>\n[next]')"
printf '%s' "$md" | grep -q '&lt;tag&gt;' || fail "Markdown HTML was not escaped"
printf '%s' "$md" | grep -q '\\\[next\\\]' || fail "Markdown link syntax was not escaped"

# code-fetch cleanup is confined to a direct canonical temp child.
TMPROOT="$TEST_ROOT/tmp"; mkdir -p "$TMPROOT"
GOOD="$(TMPDIR="$TMPROOT" mktemp -d "$TMPROOT/code-fetch.XXXXXX")"
mkdir -p "$GOOD/repo/.git"
CANON_GOOD="$(cd "$GOOD" && pwd -P)"
printf '{"schema":1,"kind":"code-fetch-workdir","path":"%s"}\n' "$CANON_GOOD" > "$GOOD/.code-fetch-workdir"
TMPDIR="$TMPROOT" bash "$ROOT/skills/code-fetch/scripts/code-fetch.sh" cleanup "$GOOD" >/dev/null
[ ! -e "$GOOD" ] || fail "valid code-fetch workdir was not removed"

OUTSIDE="$TEST_ROOT/code-fetch.outside"; mkdir -p "$OUTSIDE/repo/.git"
printf '{"schema":1,"kind":"code-fetch-workdir","path":"%s"}\n' "$(cd "$OUTSIDE" && pwd -P)" > "$OUTSIDE/.code-fetch-workdir"
if TMPDIR="$TMPROOT" bash "$ROOT/skills/code-fetch/scripts/code-fetch.sh" cleanup "$OUTSIDE" >/dev/null 2>&1; then
  fail "cleanup accepted an outside path"
fi
[ -d "$OUTSIDE" ] || fail "outside path was deleted"

FORGED="$(TMPDIR="$TMPROOT" mktemp -d "$TMPROOT/code-fetch.XXXXXX")"; mkdir -p "$FORGED/repo/.git"
printf '{"schema":1,"kind":"code-fetch-workdir","path":"wrong"}\n' > "$FORGED/.code-fetch-workdir"
if TMPDIR="$TMPROOT" bash "$ROOT/skills/code-fetch/scripts/code-fetch.sh" cleanup "$FORGED" >/dev/null 2>&1; then
  fail "cleanup accepted a forged marker"
fi
[ -d "$FORGED" ] || fail "forged-marker path was deleted"

ln -s "$FORGED" "$TMPROOT/code-fetch.symlink"
if TMPDIR="$TMPROOT" bash "$ROOT/skills/code-fetch/scripts/code-fetch.sh" cleanup "$TMPROOT/code-fetch.symlink" >/dev/null 2>&1; then
  fail "cleanup accepted a symlink"
fi

# NotebookLM rejects option-like and non-URL inputs before invoking the CLI.
if bash "$ROOT/skills/notebooklm-ingest/scripts/nlm-ingest.sh" -topic https://example.com >/dev/null 2>&1; then fail "option-like topic accepted"; fi
if bash "$ROOT/skills/notebooklm-ingest/scripts/nlm-ingest.sh" topic --evil >/dev/null 2>&1; then fail "option-like source accepted"; fi
if bash "$ROOT/skills/notebooklm-ingest/scripts/nlm-ingest.sh" topic file:///tmp/source >/dev/null 2>&1; then fail "non-http source accepted"; fi

# Voice frontmatter remains single-structure even with a hostile filename.
FAKE_HOME="$TEST_ROOT/home"; mkdir -p "$FAKE_HOME/.local/bin"
cat > "$FAKE_HOME/.local/bin/whisperkit-cli" <<'SH'
#!/usr/bin/env bash
printf 'safe transcript\n'
SH
chmod +x "$FAKE_HOME/.local/bin/whisperkit-cli"
AUDIO="$TEST_ROOT/voice\""$'\n'"--- evil: true.wav"; : > "$AUDIO"
HOME="$FAKE_HOME" PATH="/usr/bin:/bin" bash "$ROOT/skills/voice-fetch/scripts/voice-fetch.sh" "$AUDIO" > "$TEST_ROOT/voice.md"
[ "$(grep -c '^---$' "$TEST_ROOT/voice.md")" = 2 ] || fail "voice metadata escaped frontmatter"
[ "$(grep -c '^title:' "$TEST_ROOT/voice.md")" = 1 ] || fail "voice title injected YAML"

# Copilot's owner-only sentinel refuses a pre-existing symlink without touching it.
REPO="$TEST_ROOT/copilot"; mkdir -p "$REPO/wiki"; git -C "$REPO" init -q
git -C "$REPO" config user.email test@example.com; git -C "$REPO" config user.name Test
printf base > "$REPO/wiki/page.md"; git -C "$REPO" add wiki/page.md; git -C "$REPO" commit -qm base
printf changed >> "$REPO/wiki/page.md"
TARGET="$TEST_ROOT/sentinel-target"; printf preserve > "$TARGET"
ln -s "$TARGET" "$TEST_ROOT/tsb-stop-reminders-$(id -u)"
copilot_out="$(cd "$REPO" && TMPDIR="$TEST_ROOT" bash "$ROOT/templates/harness/copilot/hooks/wiki-stop-reminder.sh" <<<'{"sessionId":"abc"}')"
printf '%s' "$copilot_out" | grep -q '"decision":"allow"' || fail "unsafe sentinel did not fail open"
[ "$(cat "$TARGET")" = preserve ] || fail "sentinel symlink target was modified"

echo "ok - deletion confinement, metadata encoding, CLI validation, and temp sentinel"
