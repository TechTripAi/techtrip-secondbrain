# hooks

`techtrip-secondbrain` is a **bootstrapper**, so it ships no runtime hooks of its own
in the MVP. The vault's live automation comes from the **`claude-obsidian`** plugin
that this project installs:

- `SessionStart` — print `wiki/hot.md` (recent-context cache) + clear stale locks
- `PostToolUse` (Write|Edit) — git auto-commit of `wiki/ .raw/ .vault-meta/`
- `Stop` — prompt to refresh `wiki/hot.md` if wiki pages changed
- `PostCompact` — re-inject `wiki/hot.md` after compaction

`hooks.json` here is intentionally empty (structural parity + future extension
point). If `techtrip-secondbrain` later needs its own install-time hook, define it
here.
