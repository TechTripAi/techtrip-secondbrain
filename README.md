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

> **TechTrip Second Brain is an Orchestrator, not a fork.** It installs the
> [`claude-obsidian`](https://github.com/AgriciDaniel/claude-obsidian) LLM Wiki runtime
> ([AgriciDaniel](https://github.com/AgriciDaniel), MIT) from his marketplace at setup
> time and fills only the OS-level and sync gaps that the Agrici Claude Obsidian plugin leaves to you — nothing of
> his is copied here. The MVP produces a **generic empty scaffold** (no personal
> content) that you grow yourself. Credits: [ATTRIBUTION.md](ATTRIBUTION.md).

## Why this exists

`techtrip-secondbrain` does exactly four things — it makes `claude-obsidian` easy to
install and use, with some added functionality:

1. **Automates installation** of `claude-obsidian` and everything around it
   (Obsidian, community plugins, dependencies, MCP wiring, sync).
2. **Prechecks and post-checks** — `precheck` audits the machine before setup, and
   `doctor`/`repair-mcp` diagnose and fix anything broken after.
3. **Adds two ingest options** claude-obsidian doesn't ship: `yt-fetch` (YouTube
   transcripts) and `notebooklm-ingest` (NotebookLM synthesis).
4. **Teaches you the wiki** — `/brain-dump`, a guided tutorial that walks a new user
   through every ingestion type and the maintenance workflow.

## What is a "second brain"?

The pattern comes from Andrej Karpathy's [**LLM Wiki**](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f):
instead of dumping documents into a store and re-searching the raw pile on every
question, an LLM **incrementally maintains a persistent wiki** — a compounding artifact
of your own knowledge. Three layers: **raw sources** you curate, the **wiki** of
LLM-written, cross-linked markdown pages, and a **schema** that governs how it's
organized. You *ingest* a source (the model reads it and updates a handful of pages),
*query* it (the model synthesizes an answer and files anything worth keeping back into
the wiki), and *lint* it (health-checks for contradictions, staleness, and orphans).

Karpathy's insight is why this only works now: knowledge bases have always failed
because "the maintenance burden grows faster than the value" — humans abandon them out
of tedium. An LLM doesn't. It does the bookkeeping so the knowledge compounds instead of
being re-derived each time; you curate sources and direct the analysis. `claude-obsidian`
implements this pattern in Obsidian, and `techtrip-secondbrain` stands the whole thing
up for you. *(See Karpathy's gist for the original write-up.)*

## What is Obsidian?

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
  dependency (`uv`, `yt-dlp`, `node`) via Homebrew, all idempotent.
- **Turnkey MCP wiring** — generates the Local REST API key and registers the `obsidian`
  MCP server so Claude can read and write the vault out of the box — no hand-editing
  `~/.claude.json`.
- **Source-ingestion skills** — ships `yt-fetch` (YouTube) and `notebooklm-ingest`
  (NotebookLM) as first-class skills for pulling material into the vault.
- **Guided onboarding** — ships `/brain-dump`, an instructional tutorial that walks you
  through every ingestion type, `.raw/`, the hot cache, keeping the vault lean, and
  turning optional features on or off, and hands you the exact prompts to run yourself.
  It teaches; it never changes your vault. Re-runnable any time.
- **Cross-machine sync** — git remote by default, with optional Syncthing between two machines and a safe
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
| Optional features | `bin/setup-features.sh <path>` | YouTube (default-yes freebie) / NotebookLM + Syncthing (explicit opt-in); asked inline during setup, re-runnable any time |
| Verify | `bin/doctor.sh <path>` | health check |
| Update | `bin/update.sh <path>` | update both plugins + re-pin community plugins + doctor |

Everything is driven by **`manifest.json`** — the single source of truth for the
binaries, apps, plugins, community plugins, MCP server, and skills. Edit it to change
what gets audited and installed.

### Although TechTrip Second Brain is designed to run via Claude you may Run it manually on the command line as follows:

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
bash bin/setup-features.sh ~/LLM-Wiki    # optional: YouTube / NotebookLM / Syncthing
bash bin/doctor.sh      ~/LLM-Wiki
```

Flags: `--dry-run` (preview, mutates nothing), `--yes` (unattended, auto-confirm).

## After setup — there are some manual follow-ups

These can't be automated:

1. **Open the vault in Obsidian** and, when prompted, trust it and enable community
   plugins (Settings → Community plugins). This also generates the REST API TLS cert.
2. **Reload Claude Code** so the `claude-obsidian` skills/hooks and the `obsidian` MCP
   server activate. (/exit and then run `claude --resume`, alternatively you may do a `/reload-skills` followed by `/reload-plugins`)
3. Run **`/wiki`** to scaffold content from a one-sentence description of the vault.
4. If you enabled **NotebookLM**, run the one-time **`notebooklm login`** OAuth (setup
   offers it, but it's interactive so you may have deferred it). Any feature you
   declined during setup can be enabled later — see below.
5. New to the wiki? Run **`/brain-dump`** for a guided tour of how to feed sources in,
   keep the vault healthy, and turn optional features on or off. `/secondbrain` offers
   to launch it once setup is green.

## Optional features

The base second brain ships **lean**, and setup asks about each optional feature
**inline** — you answer three quick questions during `/secondbrain` instead of being
told to run a script later. The three are deliberately not treated the same, because
they don't carry the same risk:

| Feature | Skill | What it adds | Runtime installed | Setup default |
|---------|-------|--------------|-------------------|---------------|
| **YouTube** | `yt-fetch` | pull a video's transcript + metadata into `.raw/videos/` | `yt-dlp` (Homebrew) | **yes** — a passive CLI binary: no daemon, no credentials, no data leaving your machine |
| **NotebookLM** | `notebooklm-ingest` | offload multi-source synthesis to Google NotebookLM, then ingest the report | `notebooklm-py` (via `uv`) + one-time `notebooklm login` | **no — explicit opt-in**: it sends your sources to Google, and the login is an interactive OAuth |
| **Syncthing** | — | real-time LAN mirror of the vault across your Macs | `syncthing` (Homebrew) + vault `.stignore` | **no — explicit opt-in**: it's a background network daemon (autostart, listening ports) that only pays off with a second Mac |

Their *skills* always ship with the plugin; the questions only govern the runtime
each needs. Declining costs nothing — enable any feature later by re-running
`/secondbrain` (idempotent; everything already installed is skipped), or directly:

```bash
bash bin/setup-features.sh ~/LLM-Wiki                 # walk all three
bash bin/setup-features.sh ~/LLM-Wiki youtube         # just one
bash bin/setup-features.sh ~/LLM-Wiki notebooklm
bash bin/setup-features.sh ~/LLM-Wiki syncthing
```

To turn a feature **off**, uninstall its runtime — the vault, skills, and your notes
are untouched:

```bash
brew uninstall yt-dlp                                      # YouTube
uv tool uninstall notebooklm-py                            # NotebookLM
brew services stop syncthing && brew uninstall syncthing   # Syncthing (stops the daemon too)
```

The script is **idempotent**: already-enabled features report green and change
nothing. `bin/doctor.sh` shows each feature's on/off state (off is reported, never
failed). **`/brain-dump` is the standing reference for all of this** — its
optional-features section walks through checking, enabling, and disabling each one,
and it's re-runnable any time. (Syncthing is also offered by `bin/setup-sync.sh`;
`setup-features.sh` is the standalone/later door to the same setup.)

## Updating an existing secondbrain

Already bootstrapped this machine? How you update depends on how you installed —
pick your path.

### If you installed via the marketplace (most people)

You don't have the `bin/` scripts checked out anywhere convenient — no git, no
`bash` needed. Update the two plugins from Claude Code, then re-run the setup skill:

```
claude plugin marketplace update            # refresh listings
claude plugin update techtrip-secondbrain   # this plugin
claude plugin update claude-obsidian        # AgriciDaniel's runtime
```

Then **restart Claude Code** (or `/reload-plugins` + `/reload-skills`) so the new
versions load, and run:

```
/secondbrain
```

It's idempotent — it re-pins the community plugins to this release's manifest tags
(each asset re-verified against its `sha256`) and finishes with a health check,
without touching your notes, git history, MCP key, or optional-feature choices.

### If you cloned the git repo

You have the scripts locally, so one command does everything above:

```bash
cd techtrip-secondbrain
git pull                       # get the latest scripts + manifest
bash bin/update.sh ~/LLM-Wiki
```

`update.sh` refreshes both marketplaces, updates the `techtrip-secondbrain` **and**
`claude-obsidian` plugins, re-runs the idempotent vault scaffold so community plugins
are re-pinned to the manifest's tags (each asset re-verified against its `sha256`),
and finishes with `bin/doctor.sh`. It **does not** touch your notes, git history, MCP
key, or optional-feature choices. Every prompt is confirm-gated; `--dry-run` previews
without changing anything. **Restart Claude Code** afterward so the new plugin, skill,
and hook versions load.

## Sync model

The vault has two different sync needs, so it uses two tools:

**Git — history and backup.** The `claude-obsidian` plugin auto-commits on every write,
so every change is versioned and recoverable, and a remote gives you an off-machine
backup. But git is *commit-and-push* by design: it's a snapshot ledger, not a live
mirror. Nothing lands on your other Mac until you push there and pull here, and it has
no answer for "I just typed a sentence on the laptop and want it on the desktop now."

**Syncthing — the live layer (optional).** A second brain you actually work in is
useless if the note you wrote thirty seconds ago on one machine isn't already on the
other. Syncthing closes that gap: it watches the vault folder and continuously mirrors
changes between your machines within seconds — no commit, no push, no thinking about
it. Two properties make it the right fit for a *personal* vault: it's **peer-to-peer
over your own LAN** (your knowledge never passes through anyone's cloud), and it needs
**no server or account**. Git still runs underneath for history; Syncthing just keeps
the working files in step between commits.

`setup-sync.sh` wires this up and writes a `.stignore` so the two don't fight —
Syncthing skips `.git/`, `workspace.json`, machine-local `.vault-meta` state
(locks, transport detection), and the like, leaving version control to git.
**Caveat: edit on one machine at a time.** Both tools sync files, not intent, so
truly concurrent edits to the same note produce `.sync-conflict` copies you'd merge by
hand. See `skills/secondbrain/references/sync.md`.

## Add a second machine

One wiki, two Macs, in sync — the **primary/secondary model**: the primary (A) keeps
the vault's git repo (history, backup, auto-commit); the secondary (B) is a Syncthing
mirror with **no `.git`**. That absence is the point — claude-obsidian's auto-commit
hook exits silently without `.git`, so the two machines can never grow divergent
histories. You can read, query, and **ingest from either machine**; changes mirror
within seconds and get committed on A.

On the new Mac (B):

1. **Prereqs** — Claude Code installed; Homebrew present.
2. **Install this plugin:**
   ```
   claude plugin marketplace add TechTripAi/techtrip-secondbrain
   claude plugin install techtrip-secondbrain@techtrip-secondbrain
   ```
3. **Machine-level setup** (everything *except* the vault scaffold — the vault
   content, including the `.obsidian` community plugins, arrives via Syncthing):
   ```bash
   bash bin/precheck.sh
   bash bin/setup-deps.sh
   bash bin/setup-obsidian.sh
   bash bin/setup-claude-obsidian.sh
   ```
   **Do NOT run `setup-vault.sh` on B.**
4. **Create the empty vault folder** (same path as on A is simplest, e.g.
   `~/LLM-Wiki`), then:
   ```bash
   mkdir -p ~/LLM-Wiki
   bash bin/setup-sync.sh ~/LLM-Wiki
   ```
   **Decline git init** (B is a secondary); accept Syncthing (installs it, starts the
   service, writes B's own `.stignore` — Syncthing never syncs `.stignore` itself, so
   each machine needs one).
5. **On A:** run/re-run `bash bin/setup-sync.sh <vault>` so A has a current
   `.stignore` too, then pair the devices in the Syncthing UI
   (http://127.0.0.1:8384): exchange Device IDs, share the vault folder from A,
   accept on B. **Wait for the first full sync to finish before continuing.**
6. **Open the vault in Obsidian on B**; trust it and enable community plugins (they
   synced over from A). This activates the Local REST API plugin with A's key —
   the two machines deliberately share one key.
7. **Wire MCP on B:**
   ```bash
   bash bin/setup-mcp.sh ~/LLM-Wiki
   ```
   It detects the synced key (`Reusing existing Local REST API key`) and registers
   the `obsidian` MCP server in B's `~/.claude.json`. Reload Claude Code. (Order
   matters: if you run this *before* the first full sync, it generates a fresh key
   that syncs back and breaks A's MCP until you run `repair-mcp.sh` there.)
8. **Verify:** `bash bin/doctor.sh ~/LLM-Wiki` — green. No git on B is expected and
   correct.

**Living with two machines:**

- **Work from one machine at a time** — the single-writer rule. Breaking it costs
  you `.sync-conflict` copies (usually of `wiki/hot.md`), not data.
- **Ingest from either machine** — ingestion is pure filesystem and needs no git.
- **On B, end heavy sessions with "update the hot cache"** — the automatic
  hot-cache refresh nudge is git-gated, and B has no git.
- **History and `git push` live on A only.** B's safety net during a session is
  Syncthing itself (changes land on A within seconds).

## Design note: claude-obsidian's hooks run machine-wide

Claude Code plugin hooks can't be scoped to a directory, so once `claude-obsidian`
is installed its hooks (hot-cache injection, git auto-commit, hot-cache refresh
nudge) fire in **every** Claude session on the machine — they stay inert outside the
vault only via sentinel checks on generic names like `wiki/`. Practical rules:
**launch Claude from the vault root** (from a subdirectory the hooks silently
no-op); avoid keeping `wiki/` directories in unrelated git repos you open with
Claude (they'd get hot-cache injection and `wiki: auto-commit` commits); and a
`.vault-meta/auto-commit.disabled` file opts any repo out of auto-commit. Full
write-up: [`hooks/README.md`](hooks/README.md).

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
  machines (the Syncthing model in [Add a second machine](#add-a-second-machine))
  is the same human and the same trust boundary — the single-writer rule covers
  the rest.

Related: [`hooks/README.md`](hooks/README.md) for the machine-global-hooks design
note, and claude-obsidian's
[SECURITY.md](https://github.com/AgriciDaniel/claude-obsidian/blob/main/SECURITY.md)
for the upstream threat model.

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

## No warranty

This software is provided **as is**, with no warranty of any kind — see
[LICENSE.md](LICENSE.md) for the full disclaimer. Run it at your own risk and review
what it does before pointing it at a machine or vault you care about.

## Questions / issues

Open an issue at
[TechTripAi/techtrip-secondbrain](https://github.com/TechTripAi/techtrip-secondbrain/issues),
or reach out directly: **terry.trippany@techtrip.ai**.

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
