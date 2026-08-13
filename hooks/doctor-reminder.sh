#!/usr/bin/env bash
# techtrip-secondbrain — SessionStart doctor reminder (the plugin's one hook).
#
# Prints a single context block telling the agent to OFFER a /secondbrain-doctor
# run (read-only) when the last recorded run is REMIND_DAYS+ old — never to run
# it unprompted.
#
# Plugin hooks are machine-global, so this script confines itself hard:
#   1. silent unless a vault was set up on this machine (saved vault-path), AND
#   2. the session starts inside that vault, AND
#   3. the reminder is due, not snoozed, and not disabled.
# It writes only its own state under ${XDG_CONFIG_HOME:-~/.config}/techtrip-secondbrain/
# and always exits 0 — a reminder must never break session start.
#
# Intentionally does NOT source scripts/common.sh: this runs at every session
# start on the machine, so it stays dependency-free, prompt-free, and fast.
#
# State files (all in the config dir above):
#   last-doctor-run           epoch stamp, written by bin/doctor.sh on each run
#   last-doctor-reminder      epoch stamp, written here (snooze window)
#   doctor-reminder.disabled  kill switch — touch it to silence permanently
# Tunables: TSB_DOCTOR_REMIND_DAYS (default 14), TSB_DOCTOR_REMIND_SNOOZE_DAYS (3).

set -u

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/techtrip-secondbrain"
[ -f "$STATE_DIR/doctor-reminder.disabled" ] && exit 0

# Confinement 1: a vault must have been set up on this machine. Same read-back
# validation as common.sh load_vault_path — a non-absolute path is ignored.
vault="$(head -n1 "$STATE_DIR/vault-path" 2>/dev/null)"
case "$vault" in /*) ;; *) exit 0 ;; esac
[ -d "$vault/wiki" ] || exit 0

# Confinement 2: only speak in sessions that start inside that vault.
here="${CLAUDE_PROJECT_DIR:-$PWD}"
case "$here/" in "$vault"/*) ;; *) exit 0 ;; esac

remind_days="${TSB_DOCTOR_REMIND_DAYS:-14}"
snooze_days="${TSB_DOCTOR_REMIND_SNOOZE_DAYS:-3}"
case "$remind_days" in ''|*[!0-9]*) remind_days=14 ;; esac
case "$snooze_days" in ''|*[!0-9]*) snooze_days=3 ;; esac

now="$(date +%s)"

# Snooze: at most one reminder per snooze window, even across many sessions.
last_reminder="$(head -n1 "$STATE_DIR/last-doctor-reminder" 2>/dev/null)"
case "$last_reminder" in
  ''|*[!0-9]*) ;;
  *) [ $(( (now - last_reminder) / 86400 )) -lt "$snooze_days" ] && exit 0 ;;
esac

last_run="$(head -n1 "$STATE_DIR/last-doctor-run" 2>/dev/null)"
age_line="no /secondbrain-doctor run is recorded on this machine yet"
case "$last_run" in
  ''|*[!0-9]*) ;;
  *)
    age_days=$(( (now - last_run) / 86400 ))
    [ "$age_days" -lt "$remind_days" ] && exit 0
    age_line="the last /secondbrain-doctor run was $age_days days ago"
    ;;
esac

{ mkdir -p "$STATE_DIR" && printf '%s\n' "$now" > "$STATE_DIR/last-doctor-reminder"; } 2>/dev/null || true

cat <<EOF
techtrip-secondbrain: periodic health check due — $age_line (threshold: $remind_days days).
Agent: offer to run /secondbrain-doctor now (read-only, takes seconds); run it only if the user says yes. If they decline, drop the subject — this reminder snoozes itself for $snooze_days days. To silence it permanently: touch "$STATE_DIR/doctor-reminder.disabled"
EOF
exit 0
