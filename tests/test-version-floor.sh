#!/usr/bin/env bash
# manifest binaries[].minVersion: precheck/doctor/setup-deps treat a present-but-older
# binary as outdated. macOS ships /usr/bin/python3 3.9; the lint engine needs 3.11.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tsb-version-floor.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# shellcheck source=../scripts/common.sh
source "$ROOT/scripts/common.sh"

# version_ge: component-wise numeric compare.
version_ge 3.15.2 3.11 || fail "3.15.2 >= 3.11"
version_ge 3.11 3.11   || fail "3.11 >= 3.11"
version_ge 3.11.0 3.11 || fail "3.11.0 >= 3.11"
version_ge 4.0 3.11    || fail "4.0 >= 3.11"
! version_ge 3.9.6 3.11 || fail "3.9.6 < 3.11 (not a string compare)"
! version_ge 3.10 3.11  || fail "3.10 < 3.11"
! version_ge 3.1.9 3.11 || fail "3.1.9 < 3.11"
! version_ge abc 3.11   || fail "garbage must not pass"

# A shim python3 that reports a chosen version, placed first on PATH.
shim() {  # <dir> <version>
  mkdir -p "$1"
  printf '#!/bin/sh\ncase "$*" in *version_info*) echo "%s" ;; *) echo "Python %s" ;; esac\n' "$2" "$2" > "$1/python3"
  chmod +x "$1/python3"
}
shim "$TEST_ROOT/old" 3.9.6
shim "$TEST_ROOT/new" 3.12.4

# binary_version_ok + cmdver probe honor the floor.
( PATH="$TEST_ROOT/old:$PATH"; binary_version_ok python3 3.11 && exit 1; [ "$TSB_HAVE_VERSION" = 3.9.6 ] ) || fail "3.9.6 shim passed the 3.11 floor"
( PATH="$TEST_ROOT/new:$PATH"; binary_version_ok python3 3.11 ) || fail "3.12.4 shim failed the 3.11 floor"
( PATH="$TEST_ROOT/old:$PATH"; _probe_ok cmdver:python3:3.11 && exit 1; true ) || fail "cmdver probe passed an old binary"
( PATH="$TEST_ROOT/new:$PATH"; _probe_ok cmdver:python3:3.11 ) || fail "cmdver probe failed a new binary"
binary_version_ok python3 "" || fail "no floor declared must mean present-is-enough"

# manifest declares the floor for python3.
[ "$(manifest_get 'm.binaries.find(b=>b.cmd==="python3").minVersion')" = "3.11" ] || fail "manifest python3.minVersion != 3.11"

# precheck reports the old shim as outdated (and counts it missing), the new one as present.
out_old="$(PATH="$TEST_ROOT/old:$PATH" NO_COLOR=1 bash "$ROOT/bin/precheck.sh" 2>&1 || true)"
printf '%s' "$out_old" | grep -E 'Python 3 \(python3\).*outdated.*v3\.9\.6.*3\.11.*brew install python' >/dev/null || fail "precheck did not flag 3.9.6 as outdated:
$out_old"
out_new="$(PATH="$TEST_ROOT/new:$PATH" NO_COLOR=1 bash "$ROOT/bin/precheck.sh" 2>&1 || true)"
printf '%s' "$out_new" | grep -E 'Python 3 \(python3\).*present v3\.12\.4' >/dev/null || fail "precheck did not accept 3.12.4:
$out_new"

# setup-deps (dry-run, no TTY) must offer the upgrade rather than say 'already installed'.
out_deps="$(PATH="$TEST_ROOT/old:$PATH" NO_COLOR=1 bash "$ROOT/bin/setup-deps.sh" --dry-run 2>&1 || true)"
printf '%s' "$out_deps" | grep -q 'Python 3 (python3) is v3.9.6; 3.11+ is required' || fail "setup-deps did not warn about the floor:
$out_deps"
printf '%s' "$out_deps" | grep -q 'brew install python' || fail "setup-deps did not surface the install command"
! printf '%s' "$out_deps" | grep -q 'Python 3 (python3) already installed' || fail "setup-deps called 3.9.6 'already installed'"

echo "PASS: version floor"
