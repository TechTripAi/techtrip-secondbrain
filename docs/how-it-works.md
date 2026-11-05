# How it works

What `techtrip-secondbrain` installs, why Obsidian is the home for it, and what each setup script does. Back to the [README](../README.md).

## New to Obsidian?

[**Obsidian**](https://obsidian.md) is a free, local-first note-taking app that stores
everything as plain **Markdown files in a folder on your disk** — that folder is called a
**vault**. There's no proprietary database and no mandatory cloud: your notes are just
`.md` files you fully own, readable and editable by any tool (including Claude). Obsidian
treats `[[wikilinks]]` between notes as first-class, so a vault naturally becomes a
**graph of interconnected pages** rather than a flat pile of documents — exactly the
shape an LLM Wiki wants.

Two things make it the right home for a second brain: **it's just files** (so Claude can
read and write pages directly, and git can version every change), and **it's extensible**
via community plugins and a Local REST API. `techtrip-secondbrain` leans on both — it
installs Obsidian plus a curated set of community plugins, then wires the REST API so the
`obsidian` MCP server lets Claude operate on the vault. In this stack Obsidian is the
**human-facing surface** (you read, browse, and edit notes there) while `claude-obsidian`
is the LLM that maintains them behind the scenes.

## How TechTrip-SecondBrain Makes Life Easy

`claude-obsidian` gives you the wiki runtime but leaves the machine setup to you.
`techtrip-secondbrain` closes that gap:

- **Zero-touch OS setup** — installs Obsidian, the community plugins, and every binary
  dependency (`uv`, `node`, `flock`, `python3` 3.11+, optional `yt-dlp`/`whisperkit-cli`) via Homebrew, all idempotent.
  Version floors come from the manifest: macOS ships Python 3.9, which precheck reports as
  outdated and setup-deps offers to upgrade, so the lint engine never fails on it later.
- **Turnkey MCP wiring** — generates the Local REST API key and registers the `obsidian`
  MCP server so Claude can read and write the vault out of the box — no hand-editing
  `~/.claude.json`.
- **Source-ingestion skills** — ships `yt-fetch` (YouTube), `x-fetch` (X/Twitter
  posts — text + metadata, video posts transcribed on-device), `voice-fetch` (voice
  memos / local audio, transcribed on-device), `code-fetch` (codebases — the
  agent reads the code and distills one semantic digest, never file-by-file),
  and `notebooklm-ingest` (NotebookLM) as first-class skills for pulling
  material into the vault.
- **Origination skill** — ships `/new-idea`, which scaffolds a greenfield project
  (`wiki/projects/<slug>/`: tracker, thesis workbench, open questions, append-only
  decisions log, spec) from a seeded template for the ideas you originate yourself;
  the seeded `origination-workflow` page documents the loop
  (Frame → Mull → Decide → Reconcile → Log → Graduate), including an
  end-of-session check that every changed content page has an honest `updated:`
  date; `doctor` reports incomplete project metadata and nudges stale projects
  toward graduate-or-archive.
- **Guided onboarding** — ships `/brain-dump`, an instructional tutorial that walks you
  through every ingestion type, `.raw/`, the hot cache, starting a new idea, keeping
  the vault lean, and turning optional features on or off, and hands you the exact
  prompts to run yourself. It teaches; it never changes your vault. Re-runnable any time.
- **Cross-machine sync** — git remote: auto-commit gives history and recovery, the
  remote gives backup, and a second machine is just a `git clone`.
- **Health & repair tooling** — `precheck` audits the machine against a manifest, and the
  `secondbrain-doctor` skill diagnoses and repairs the common "MCP registered globally
  but won't connect" failure.
- **One command** — `/secondbrain` drives the whole interactive setup end to end.

## What it does

| Step | Script | Result |
|------|--------|--------|
| Precheck | `bin/precheck.sh` | audit machine vs `manifest.json` (report-only) |
| Dependencies | `bin/setup-deps.sh` | Homebrew + `uv`, `node`, `flock`, `python3` (3.11+; upgrades the macOS 3.9) |
| Obsidian | `bin/setup-obsidian.sh` | `brew install --cask obsidian` |
| claude-obsidian | `bin/setup-claude-obsidian.sh` | marketplace add + plugin install |
| Vault | `bin/setup-vault.sh <path>` | scaffold vault + install community plugins |
| MCP | `bin/setup-mcp.sh <path>` | generate REST key, register `obsidian` MCP server |
| Sync | `bin/setup-sync.sh <path>` | git init + remote guidance (offers to remove a legacy vault `.stignore`) |
| Optional features | `bin/setup-features.sh <path>` | YouTube (default-yes freebie) / NotebookLM (explicit opt-in); asked inline during setup, re-runnable any time |
| Verify | `bin/doctor.sh <path>` | health check |
| Update | `bin/update.sh <path>` | update both plugins + re-pin community plugins + doctor |
| DragonScale disarm | `bin/disarm-dragonscale.sh <path>` | turn off claude-obsidian's opt-in DragonScale addressing in the vault (default-no confirm, backed up); doctor and update surface it |
| Vault reset | `bin/reset-vault.sh <path> [--scorch]` | empty a vault back to nothing after a verified backup — default clears the knowledge but keeps the wiring (MCP keeps working); `--scorch` retires the whole vault and re-scaffolds (needs an MCP re-key). Typed-phrase consent |

Everything is driven by **`manifest.json`** — the single source of truth for the
binaries, apps, plugins, community plugins, MCP server, and skills. Edit it to change
what gets audited and installed.

These scripts are what the skills drive for you: `/secondbrain` runs the setup
steps, `/secondbrain-doctor` runs doctor and the MCP repair. **If you installed
from the marketplace, the skills are your interface — use them.** Running the
scripts by hand is for git-clone users only (the marketplace install buries them
in the plugin cache; there's no repo to `cd` into).

### Running it manually on the command line (git clone only)

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
bash bin/setup-features.sh ~/LLM-Wiki    # optional: YouTube / NotebookLM
bash bin/doctor.sh      ~/LLM-Wiki
```

Flags: `--dry-run` (preview, mutates nothing), `--yes` (unattended, auto-confirm).

> [!NOTE]
> **`~/LLM-Wiki` is the example default — your vault path may differ** (you
> choose it during setup, e.g. `~/TechTrip.AI`). Substitute your own path in
> every example in these docs. The scripts also remember the path from setup:
> omit the argument and they fall back to the saved vault path before the
> `~/LLM-Wiki` default.
