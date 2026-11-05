# Safety, limitations and scope

Read this before pointing any AI agent at a vault you care about. Back to the [README](../README.md).

## Before you run any AI against your vault

This project has Claude read and write files on your machine. Before running
`/secondbrain` (or any AI agent) against a real vault, set up a proper set of
guardrails in Claude Code — permissions, hooks, and directory scoping — so you know
what it's allowed to touch. Start here: [Claude Code security
docs](https://docs.claude.com/en/docs/claude-code/security) and
`claude-obsidian`'s [SECURITY.md](https://github.com/AgriciDaniel/claude-obsidian/blob/main/SECURITY.md).

Also remember that **ingested content is untrusted input**: YouTube transcripts, web
pages, and NotebookLM reports land in the vault and are later read by Claude sessions
with tool access, so a malicious source can try to smuggle instructions in (prompt
injection). Don't grant destructive or wide-open permissions to sessions that browse
the wiki, and be pickier about what you ingest than about what you read.

## Design note: claude-obsidian's hooks run machine-wide

Claude Code plugin hooks can't be scoped to a directory, so once `claude-obsidian`
is installed its hooks (hot-cache injection, git auto-commit, hot-cache refresh
nudge) fire in **every** Claude session on the machine — they stay inert outside the
vault only via sentinel checks on generic names like `wiki/`. Practical rules:
**launch Claude from the vault root** (from a subdirectory the hooks silently
no-op); avoid keeping `wiki/` directories in unrelated git repos you open with
Claude (they'd get hot-cache injection and `wiki: auto-commit` commits); and a
`.vault-meta/auto-commit.disabled` file opts any repo out of auto-commit. Full
write-up: [`hooks/README.md`](../hooks/README.md).

## Limitations

**Single-tenant by design: one user, one vault, one trust boundary.** The wiki
runtime this project installs —
[`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian) by
[AgriciDaniel](https://github.com/AgriciDaniel) — documents a **single-tenant threat
model** in its SECURITY.md, and `techtrip-secondbrain` inherits it: standard
macOS/Linux **filesystem permissions are the only trust boundary**; there are no
application-layer identity checks anywhere in the stack.

Why that is: the vault's advisory lock release is unconditional (any process able to
write `.vault-meta/locks/` can release another's in-flight lock — intentional, since
acquire and release are separate bash invocations); the git auto-commit hook runs as
whoever invokes Claude Code; and cross-process resources (lockfiles, transport
snapshots) are plain files.

In practice:

- **Don't** put the vault on a shared or multi-user host, or a shared-CI runner.
- **Don't** grant other OS users write access to the vault directory.
- **Do** note what single-tenant does *not* forbid: one user across multiple
  machines (the git-clone model in [Add a second machine](sync.md#add-a-second-machine))
  is the same human and the same trust boundary — the single-writer rule covers
  the rest.

Related: [`hooks/README.md`](../hooks/README.md) for the machine-global-hooks design
note, and claude-obsidian's
[SECURITY.md](https://github.com/AgriciDaniel/claude-obsidian/blob/main/SECURITY.md)
for the upstream threat model.

## Out of scope (MVP)

Windows/Linux; cloning personal content (`wiki/`, `.raw/`, Pocket); `pocket-sync`;
`claude-obsidian`'s optional DragonScale / hybrid-retrieval extensions (run those from
`claude-obsidian` after setup); auto-installing Claude Code or Homebrew.

DragonScale gets one extra courtesy because it is *silently self-arming*: its
addressing (Mechanism 2) feature-detects from vault files, and its allocator
counter uses machine-local locking — duplicate-address and merge-conflict bait
under the two-machine git model. `doctor` reports whether a vault is armed, and
`update` / `bin/disarm-dragonscale.sh` offer to disarm it (default-no confirm,
backed up, notes untouched). Vaults that want DragonScale just answer no.

## No warranty

This software is provided **as is**, with no warranty of any kind — see
[LICENSE.md](../LICENSE.md) for the full disclaimer. Run it at your own risk and review
what it does before pointing it at a machine or vault you care about.
