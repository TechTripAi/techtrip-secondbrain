# hooks

`techtrip-secondbrain` is a bootstrapper, so it ships almost no hooks. Vault
*runtime* automation belongs to
[`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian) by
AgriciDaniel — duplicating its hooks here would double-fire hot-cache injection
and auto-commits, and that rule stands.

## The one shipped hook: `doctor-reminder.sh` (SessionStart)

The single exception is plugin-owned, not vault-runtime: a periodic reminder to
run `/secondbrain-doctor`. `bin/doctor.sh` stamps each completed run in
`${XDG_CONFIG_HOME:-~/.config}/techtrip-secondbrain/last-doctor-run`; at session
start this hook compares that stamp against a threshold (default **14 days**,
`TSB_DOCTOR_REMIND_DAYS`) and, when due, prints one context block instructing
the agent to **offer** the health check — never to run it unprompted.

Because plugin hooks are machine-global, the hook confines itself hard and is
silent unless **all** of these hold:

1. a vault was set up on this machine (saved `vault-path` state exists and
   points at a directory containing `wiki/`);
2. the session starts **inside** that vault (`CLAUDE_PROJECT_DIR`/cwd);
3. the reminder is due, not snoozed (one reminder per
   `TSB_DOCTOR_REMIND_SNOOZE_DAYS`, default 3 — declining doesn't nag), and
   not disabled.

It writes only its own state files in the config dir, never the vault or any
machine config, and always exits 0 so it can never break session start. Kill
switch: `touch ~/.config/techtrip-secondbrain/doctor-reminder.disabled`.

Covered by `tests/test-doctor-reminder.sh`.

## Machine-global confinement

Claude Code plugin hooks are machine-global. Maintained fork **1.9.5** confines
that scope in source:

- command hooks execute only the bundled
  `${CLAUDE_PLUGIN_ROOT}/scripts/vault-hook.sh` dispatcher;
- the current repository can no longer provide a `scripts/wiki-lock.sh` for the
  plugin to execute;
- setup seeds `.vault-meta/claude-obsidian-vault.json` with schema/kind fields;
- pre-1.9.5 vaults remain compatible through a strict complete-scaffold
  signature, while generic repositories containing `wiki/` stay inert;
- `CLAUDE_PROJECT_DIR` resolves the vault root even when the session starts in a
  subdirectory;
- auto-commit remains limited to `wiki/`, `.raw/`, and `.vault-meta/`, and
  `.vault-meta/auto-commit.disabled` remains the per-vault kill switch.

The four behaviors remain SessionStart hot-cache/lock cleanup, PostCompact
hot-cache restoration, PostToolUse path-scoped auto-commit, and the Stop refresh
reminder. The fix lives in the maintained fork and is proposed upstream; installed
plugin caches are never patched in place. `doctor-reminder.sh` follows the same
discipline this project asks of claude-obsidian: strict confinement, own-state
only, silent everywhere else.
