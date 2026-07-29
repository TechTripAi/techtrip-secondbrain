# hooks

`techtrip-secondbrain` is a bootstrapper and intentionally ships an empty,
schema-valid `hooks/hooks.json`. Vault automation belongs to
[`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian) by
AgriciDaniel; duplicating its hooks here would double-fire hot-cache injection
and auto-commits.

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
plugin caches are never patched in place.
