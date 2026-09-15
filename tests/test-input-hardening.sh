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

# x-fetch rejects option-like, non-http, and non-X-post URLs before invoking yt-dlp.
for bad in -evil https://example.com/status/1 https://x.com/jack https://x.com/i/spaces/1abc 'ftp://x.com/jack/status/20'; do
  if PATH="/usr/bin:/bin" bash "$ROOT/skills/x-fetch/scripts/x-fetch.sh" "$bad" >/dev/null 2>&1; then fail "x-fetch accepted: $bad"; fi
done

# x-fetch's cookie opt-in accepts only a browser name (+ optional profile NAME) — an
# injected value can't point yt-dlp at an arbitrary file via the profile-path syntax.
for bad in 'chrome:/Users/me/Library/Cookies' 'firefox:../../etc' 'evilbrowser' 'chrome:' ; do
  rc=0; X_FETCH_COOKIES_BROWSER="$bad" PATH="/usr/bin:/bin" bash "$ROOT/skills/x-fetch/scripts/x-fetch.sh" https://x.com/jack/status/20 >/dev/null 2>&1 || rc=$?
  [ "$rc" = 2 ] || fail "x-fetch cookie spec '$bad' exited $rc, expected 2 (argument rejection before any tool runs)"
done

# yt-fetch has the identical cookie opt-in and the identical guard.
for bad in 'chrome:/Users/me/Library/Cookies' 'firefox:../../etc' 'evilbrowser' 'chrome:' ; do
  rc=0; YT_FETCH_COOKIES_BROWSER="$bad" PATH="/usr/bin:/bin" bash "$ROOT/skills/yt-fetch/scripts/yt-fetch.sh" https://www.youtube.com/watch?v=dQw4w9WgXcQ >/dev/null 2>&1 || rc=$?
  [ "$rc" = 2 ] || fail "yt-fetch cookie spec '$bad' exited $rc, expected 2 (argument rejection before any tool runs)"
done

# x-fetch frontmatter remains single-structure with hostile post metadata, and a
# video post flows through download → on-device transcription with the media
# confined to the temp dir (a fake yt-dlp + fake whisperkit-cli stand in).
cat > "$FAKE_HOME/.local/bin/yt-dlp" <<'SH'
#!/usr/bin/env bash
out=""; skip=0
while [ $# -gt 0 ]; do
  case "$1" in -o) out="$2"; shift ;; --skip-download) skip=1 ;; esac
  shift
done
dir="$(dirname "$out")"
if [ "$skip" = 1 ]; then
  cat > "$dir/900.info.json" <<'J'
{"id":"900","_type":"playlist","title":"Evil - x","description":"hello\" world\n---\nevil: true\n# not a heading","uploader":"Evil\" Name","uploader_id":"evil","upload_date":"20240102","webpage_url":"https://x.com/evil/status/900","like_count":3}
J
  cat > "$dir/901.info.json" <<'J'
{"id":"901","_type":"video","title":"Evil - x #1","description":"hello\" world","uploader":"Evil\" Name","uploader_id":"evil","upload_date":"20240102","webpage_url":"https://x.com/evil/status/900","duration":65,"formats":[{"format_id":"http-256","ext":"mp4"}]}
J
else
  : > "$dir/901.mp4"
fi
SH
chmod +x "$FAKE_HOME/.local/bin/yt-dlp"
HOME="$FAKE_HOME" PATH="/usr/bin:/bin" bash "$ROOT/skills/x-fetch/scripts/x-fetch.sh" 'https://x.com/evil/status/900?s=20' > "$TEST_ROOT/x.md"
[ "$(grep -c '^---$' "$TEST_ROOT/x.md")" = 2 ] || fail "x-fetch metadata escaped frontmatter"
[ "$(grep -c '^title:' "$TEST_ROOT/x.md")" = 1 ] || fail "x-fetch title injected YAML"
grep -q '^post_id: "900"$' "$TEST_ROOT/x.md" || fail "x-fetch lost the status id"
grep -q '^has_video: true$' "$TEST_ROOT/x.md" || fail "x-fetch missed the video entry"
grep -q '^> ---$' "$TEST_ROOT/x.md" || fail "x-fetch post text was not blockquoted"
grep -q '^safe transcript$' "$TEST_ROOT/x.md" || fail "x-fetch video transcript missing"
grep -q '^_Duration: 1:05 ' "$TEST_ROOT/x.md" || fail "x-fetch duration not formatted"
find "$FAKE_HOME" -name '*.mp4' | grep -q . && fail "x-fetch left media behind"
# Without a transcriber the fetch still succeeds, text intact, transcript replaced by a warning.
rm "$FAKE_HOME/.local/bin/whisperkit-cli"
HOME="$FAKE_HOME" PATH="/usr/bin:/bin" bash "$ROOT/skills/x-fetch/scripts/x-fetch.sh" 'https://twitter.com/evil/status/900' > "$TEST_ROOT/x2.md" 2>/dev/null
grep -q '^> hello" world$' "$TEST_ROOT/x2.md" || fail "x-fetch lost post text without transcriber"
grep -q 'no transcript was produced' "$TEST_ROOT/x2.md" || fail "x-fetch missing no-transcriber warning"
grep -q '^transcriber:' "$TEST_ROOT/x2.md" && fail "x-fetch claimed a transcriber it did not use"

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

echo "ok - deletion confinement, metadata encoding, CLI validation, x-fetch pipeline, and temp sentinel"
