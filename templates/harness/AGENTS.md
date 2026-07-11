# LLM Wiki Vault — Agent Operating Contract

Operating contract for any AI agent (Claude Code, Cursor, Codex, etc.) working
in this vault. This repo IS the Obsidian vault. The wiki is the product; chat
is just the interface. Deep reference: `WIKI.md` (if present).

## Session start

1. Read `wiki/hot.md` first — recent state, active threads, next actions.
   Re-read it after any context compaction. Do this silently.
2. Query path is hot → `wiki/index.md` → individual pages. Read 3–5 pages per
   query, not 10+.

## Layout

- `.raw/` — Layer 1: immutable sources. **Never modify anything under `.raw/`**
  (exception: `.raw/.manifest.json`, the ingest delta tracker).
- `wiki/` — Layer 2: the knowledge base.
  - `index.md` (master catalog) · `log.md` (append-only, newest entries at the
    TOP) · `hot.md` (cache — overwrite completely, keep under 500 words)
- `AGENTS.md` (+ `WIKI.md`) — Layer 3: the schema.

## Operations — use the skills

Vault operations are implemented as portable `SKILL.md` skills (the
claude-obsidian plugin suite plus the techtrip-secondbrain source skills). Use
them instead of improvising:

- Ingest a source → `wiki-ingest` (YouTube URLs → `yt-fetch` first;
  multi-source synthesis → `notebooklm-ingest`)
- Answer from the vault → `wiki-query` · health check → `wiki-lint` ·
  log rollup → `wiki-fold` · save a conversation → `save`

Every ingest MUST update: `wiki/index.md`, `wiki/log.md`, `wiki/hot.md`, and
`.raw/.manifest.json`. Flag conflicts with `> [!contradiction]` callouts on
both pages — never silently overwrite a claim.

## Hard rules

- Single writer: one agent session mutates the vault at a time.
- Keep pages 100–300 lines; atomic (one concept per page); wikilinks
  (`[[Page]]`) over paths; every page gets YAML frontmatter.
- Before finishing any session that changed `wiki/`, refresh `wiki/hot.md`
  (format: Last Updated / Key Recent Facts / Recent Changes / Active Threads).

## Git

- Auto-commit of `wiki/`, `.raw/`, `.vault-meta/` after edits is sanctioned
  automation (Claude Code: plugin PostToolUse hook; Cursor:
  `.cursor/hooks/wiki-autocommit.sh`). Kill switch:
  `touch .vault-meta/auto-commit.disabled`.
- Never push from an agent session unless the owner explicitly asks.

## Per-harness notes

| Harness | Automation available | What you must do manually |
|---|---|---|
| Claude Code | plugin hooks: hot-cache injection, auto-commit, hot-cache nudge | nothing |
| Cursor | `.cursor/hooks/` ports of the same + `.cursor/rules/wiki-vault.mdc` | nothing |
| Codex / other | none | follow this file: read `hot.md` at start, refresh it at end; skills discoverable via `~/.agents/skills/` |

The vault is harness-agnostic by design: plain Markdown, filesystem access is
always sufficient (MCP/CLI transports are optional accelerators).
