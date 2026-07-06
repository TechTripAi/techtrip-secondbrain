# hooks

`techtrip-secondbrain` is a **bootstrapper**, so it ships no runtime hooks of its own
in the MVP. The vault's live automation comes from the **`claude-obsidian`** plugin
that this project installs:

- `SessionStart` — print `wiki/hot.md` (recent-context cache) + clear stale locks
- `PostToolUse` (Write|Edit) — git auto-commit of `wiki/ .raw/ .vault-meta/`
- `Stop` — prompt to refresh `wiki/hot.md` if wiki pages changed
- `PostCompact` — re-inject `wiki/hot.md` after compaction

`hooks.json` here is intentionally `{ "hooks": {} }` — the schema-valid "no hooks"
form (the `hooks` key must exist or the plugin loader errors). If
`techtrip-secondbrain` later needs its own install-time hook, define it here. Never
duplicate claude-obsidian's vault hooks — both copies would fire (double hot-cache
injection, double auto-commits).

## Design consideration: claude-obsidian's hooks are machine-global

Claude Code **plugin hooks cannot be directory-scoped** — once
[`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian) (AgriciDaniel)
is installed, its four hooks fire in **every Claude session on the machine**, not
just inside the vault. They stay inert elsewhere only through convention-based
guards: each command starts with a cwd-relative sentinel check and always exits 0
(e.g. `[ -f wiki/hot.md ] && cat wiki/hot.md || true`, `[ -d .git ] || exit 0`,
auto-commit path-scoped to `wiki/ .raw/ .vault-meta/`).

Because those sentinels are **generic names** (`wiki/`, `wiki/hot.md`, `.git`), the
guards hold by convention, not guarantee. Ramifications to be aware of:

- **Blast radius.** Any unrelated git repo containing a `wiki/` directory is inside
  it: a `wiki/hot.md` there gets injected into session context at startup (a mild
  prompt-injection surface for third-party clones), the `Stop` hook emits
  `WIKI_CHANGED` nudges when its `wiki/` files change, and the `PostToolUse` hook
  makes `wiki: auto-commit` commits in that repo.
- **Fail-silent in the vault.** Launch Claude from a vault *subdirectory* and the
  sentinels don't resolve, so every hook silently no-ops. **Always launch Claude
  from the vault root.**
- **Precedent.** claude-obsidian's own v1.9.0 audit logged a BLOCKER (B1) in this
  class — the auto-commit hook originally swept user-staged unrelated files into
  wiki commits. Upstream fixed that instance by path-scoping the git commands.

Mitigations you control:

- **One vault per machine** — already this project's design assumption.
- **Opt a repo out of auto-commit** with a `.vault-meta/auto-commit.disabled` file
  (documented in claude-obsidian's SECURITY.md).
- **Avoid `wiki/` directories in non-vault repos** you open with Claude, or accept
  the behaviors above.

Why `techtrip-secondbrain` doesn't fix this: we are an orchestrator, not a fork —
we never patch `~/.claude/plugins/cache/**`. The proper fix (guarding each hook on
a scaffold-unique sentinel such as the vault's `WIKI.md`) belongs upstream in
claude-obsidian.
