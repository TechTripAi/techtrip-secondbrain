# techtrip-secondbrain

<p align="center">
  <img src="img/FellowshipOfTheAgents.png" alt="techtrip-secondbrain: LLM Wiki Build and Enhancement of AgriciDaniel Claude Code and Obsidian" width="100%" />
</p>

**One-command bootstrapper for a generic, out-of-the-box LLM Wiki "second brain" on a
fresh Mac.** It installs Obsidian and a select set of community plugins, pulls the
[**`claude-obsidian`**](https://github.com/AgriciDaniel/claude-obsidian) plugin — by
[**AgriciDaniel**](https://github.com/AgriciDaniel) — from its own marketplace,
scaffolds a clean vault, wires the Obsidian MCP server, ships the `yt-fetch` and
`notebooklm-ingest` source skills, and sets up git + optional Syncthing sync — all
interactive and idempotent.

> **Orchestrator, not a fork.** It installs the
> [`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian) LLM Wiki runtime
> ([AgriciDaniel](https://github.com/AgriciDaniel), MIT) from his marketplace at setup
> time and fills only the OS-level and sync gaps that plugin leaves to you — nothing of
> his is copied here. The MVP produces a **generic empty scaffold** (no personal
> content) that you grow yourself. Credits: [ATTRIBUTION.md](ATTRIBUTION.md).

## What it adds

`claude-obsidian` gives you the wiki runtime but leaves the machine setup to you.
`techtrip-secondbrain` closes that gap:

- **Zero-touch OS setup** — installs Obsidian, the community plugins, and every binary
  dependency (`uv`, `yt-dlp`, `node`) via Homebrew, all idempotent.
- **Turnkey MCP wiring** — generates the Local REST API key and registers the `obsidian`
  MCP server so Claude can read and write the vault out of the box — no hand-editing
  `~/.claude.json`.
- **Source-ingestion skills** — ships `yt-fetch` (YouTube) and `notebooklm-ingest`
  (NotebookLM) as first-class skills for pulling material into the vault.
- **Cross-machine sync** — git remote by default, with optional Syncthing and a safe
  `.stignore` so real-time sync and git auto-commit don't fight.
- **Health & repair tooling** — `precheck` audits the machine against a manifest, and the
  `secondbrain-doctor` skill diagnoses and repairs the common "MCP registered globally
  but won't connect" failure.
- **One command** — `/secondbrain` drives the whole interactive setup end to end.

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

Wiki runtime: **[`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian)**
by **[AgriciDaniel](https://github.com/AgriciDaniel)** (MIT). Community plugins and the
Karpathy LLM-Wiki pattern are credited in [ATTRIBUTION.md](ATTRIBUTION.md).

## License

**FSL-1.1-MIT** (Functional Source License) © 2026 Terry Trippany (Try AI Solutions).
See [LICENSE.md](LICENSE.md). Source-available with a Competing-Use restriction that
**automatically converts to MIT two years after each release**. Internal use,
non-commercial education/research, and professional services for licensees are
permitted; reselling a substantially similar product is not (until the MIT conversion).
