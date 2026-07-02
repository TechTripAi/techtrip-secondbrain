# techtrip-secondbrain

**One-command bootstrapper for a generic, out-of-the-box LLM Wiki "second brain" on a
fresh Mac.** It installs Obsidian and the community plugins, pulls the
[**`claude-obsidian`**](https://github.com/AgriciDaniel/claude-obsidian) plugin — by
[**AgriciDaniel**](https://github.com/AgriciDaniel) — from its own marketplace,
scaffolds a clean vault, wires the Obsidian MCP server, ships the `yt-fetch` and
`notebooklm-ingest` source skills, and sets up git + optional Syncthing sync — all
interactive and idempotent.

> `techtrip-secondbrain` is an **orchestrator / enhancement layer, not a fork**. The
> entire LLM Wiki runtime is [`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian)
> by [AgriciDaniel](https://github.com/AgriciDaniel) (MIT) — this project installs it
> from his marketplace at setup time and only fills the OS-level / sync gaps that
> plugin leaves to you. Nothing of his is copied here. Full credit to AgriciDaniel;
> see [ATTRIBUTION.md](ATTRIBUTION.md). The MVP produces a **generic empty scaffold**
> — no personal content — that you grow yourself.

## Requirements

- **macOS** (MVP is macOS-only; Windows/Linux deferred).
- **Claude Code** already installed — a Claude plugin can't install Claude itself.
- **Homebrew** — the bootstrapper installs the rest, but if brew is missing it prints
  the official one-liner for you to run once.

## Install

Install it like any Claude Code plugin:

```
claude plugin marketplace add TechTripAi/techtrip-secondbrain
claude plugin install techtrip-secondbrain@techtrip-secondbrain
```

Then, in Claude Code:

```
/secondbrain
```

…and follow the interactive workflow. Or run the scripts directly (see below).

## What it does

| Step | Script | Result |
|------|--------|--------|
| Precheck | `bin/precheck.sh` | audit machine vs `manifest.json` (report-only) |
| Dependencies | `bin/setup-deps.sh` | Homebrew + `uv`, `yt-dlp`, `node` |
| Obsidian | `bin/setup-obsidian.sh` | `brew install --cask obsidian` |
| claude-obsidian | `bin/setup-claude-obsidian.sh` | marketplace add + plugin install |
| Vault | `bin/setup-vault.sh <path>` | scaffold vault + install community plugins |
| MCP | `bin/setup-mcp.sh <path>` | generate REST key, register `obsidian` MCP server |
| Sync | `bin/setup-sync.sh <path>` | git remote (default) + optional Syncthing |
| Verify | `bin/doctor.sh <path>` | health check |

Everything is driven by **`manifest.json`** — the single source of truth for the
binaries, apps, plugins, community plugins, MCP server, and skills. Edit it to change
what gets audited and installed.

### Run manually (without the skill)

```bash
git clone https://github.com/TechTripAi/techtrip-secondbrain
cd techtrip-secondbrain
bash bin/precheck.sh                       # see what's missing
bash bin/setup-deps.sh
bash bin/setup-obsidian.sh
bash bin/setup-claude-obsidian.sh
bash bin/setup-vault.sh ~/LLM-Wiki
bash bin/setup-mcp.sh   ~/LLM-Wiki
bash bin/setup-sync.sh  ~/LLM-Wiki
bash bin/doctor.sh      ~/LLM-Wiki
```

Flags: `--dry-run` (preview, mutates nothing), `--yes` (unattended, auto-confirm).

## After setup — manual follow-ups

These can't be automated:

1. **Open the vault in Obsidian** and, when prompted, trust it and enable community
   plugins (Settings → Community plugins). This also generates the REST API TLS cert.
2. **Reload Claude Code** so the `claude-obsidian` skills/hooks and the `obsidian` MCP
   server activate.
3. Run **`/wiki`** to scaffold content from a one-sentence description of the vault.
4. If you'll use `notebooklm-ingest`, run **`notebooklm login`** once (interactive OAuth).

## Sync model

Git is the backbone — the `claude-obsidian` plugin auto-commits on every write. Add a
remote to back up / move between machines. For real-time multi-Mac sync, opt into
**Syncthing** during `setup-sync.sh`; it writes a `.stignore` that keeps Syncthing and
git from fighting. **Edit on one machine at a time** — concurrent edits create
`.sync-conflict` copies. See `skills/secondbrain/references/sync.md`.

## Out of scope (MVP)

Windows/Linux; cloning personal content (`wiki/`, `.raw/`, Pocket); `pocket-sync`;
`claude-obsidian`'s optional DragonScale / hybrid-retrieval extensions (run those from
`claude-obsidian` after setup); auto-installing Claude Code or Homebrew.

## Credits

The LLM Wiki runtime this project bootstraps is **[`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian)**,
created by **[AgriciDaniel](https://github.com/AgriciDaniel)** (MIT). It is installed
from his own Claude Code marketplace at setup time — **not vendored or forked here** —
so you always receive his upstream updates. Full credit for the second-brain wiki
system goes to AgriciDaniel. Community plugins and the Karpathy LLM-Wiki pattern are
credited in [ATTRIBUTION.md](ATTRIBUTION.md).

- Author: <https://github.com/AgriciDaniel>
- Repository: <https://github.com/AgriciDaniel/claude-obsidian>

## License

MIT © 2026 Terry Trippany (Try AI Solutions). See [LICENSE](LICENSE).
