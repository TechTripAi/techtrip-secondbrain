#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/hooks/doctor-reminder.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tsb-doctor-reminder-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

# Isolate all state reads/writes (the hook and common.sh both honor this).
export XDG_CONFIG_HOME="$TEST_ROOT/config"
STATE="$XDG_CONFIG_HOME/techtrip-secondbrain"
VAULT="$TEST_ROOT/vault"
mkdir -p "$STATE" "$VAULT/wiki"

run_hook() { CLAUDE_PROJECT_DIR="$1" bash "$HOOK"; }

# 1. No vault set up on this machine → silent.
out="$(run_hook "$VAULT")"
[ -z "$out" ]

printf '%s\n' "$VAULT" > "$STATE/vault-path"

# 2. Session starting outside the vault → silent (machine-global confinement).
out="$(run_hook "$TEST_ROOT")"
[ -z "$out" ]

# 3. Inside the vault with no doctor run recorded → reminds (offer, not run)
#    and stamps its own snooze.
out="$(run_hook "$VAULT")"
printf '%s' "$out" | grep -q 'secondbrain-doctor'
printf '%s' "$out" | grep -q 'offer to run'
printf '%s' "$out" | grep -q 'no /secondbrain-doctor run is recorded'
[ -f "$STATE/last-doctor-reminder" ]

# 4. Snoozed → silent on the very next session start.
out="$(run_hook "$VAULT")"
[ -z "$out" ]

# 5. Fresh doctor run → silent even after the snooze is gone.
rm -f "$STATE/last-doctor-reminder"
date +%s > "$STATE/last-doctor-run"
out="$(run_hook "$VAULT")"
[ -z "$out" ]

# 6. Stale doctor run (20 days) → reminds with the age; subdirectory sessions
#    count as inside the vault.
rm -f "$STATE/last-doctor-reminder"
printf '%s\n' "$(( $(date +%s) - 20 * 86400 ))" > "$STATE/last-doctor-run"
out="$(run_hook "$VAULT/wiki")"
printf '%s' "$out" | grep -q '20 days ago'

# 7. Kill switch → silent no matter how stale.
rm -f "$STATE/last-doctor-reminder"
touch "$STATE/doctor-reminder.disabled"
out="$(run_hook "$VAULT")"
[ -z "$out" ]
rm -f "$STATE/doctor-reminder.disabled"

# 8. A corrupted stamp is treated as never-run, not an error.
rm -f "$STATE/last-doctor-reminder"
printf 'not-a-number\n' > "$STATE/last-doctor-run"
out="$(run_hook "$VAULT")"
printf '%s' "$out" | grep -q 'no /secondbrain-doctor run is recorded'

# 9. doctor.sh stamps a completed run for the hook to measure.
rm -f "$STATE/last-doctor-run"
bash "$ROOT/bin/doctor.sh" "$VAULT" >/dev/null
grep -Eq '^[0-9]+$' "$STATE/last-doctor-run"

printf 'ok - doctor reminder confinement, throttling, and run stamping\n'
