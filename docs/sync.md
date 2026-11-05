# Sync and second machines

Back to the [README](../README.md).

## Sync model

**Git only.** The `claude-obsidian` plugin auto-commits on every write, so every
change is versioned and recoverable, and a remote gives you an off-machine backup.
Since you already edit one machine at a time (the single-writer rule), a `pull`
before you start and a `push` when you finish covers multi-machine use — no
daemons, no pairing, no conflict copies.

Why nothing else:

- **No Syncthing** (removed): a background daemon with listening ports, per-device
  pairing in a web UI, a per-machine `.stignore`, and `.sync-conflict` files when
  the single-writer rule slips — standing complexity that real-time mirroring
  doesn't earn in a single-writer workflow. It also forced both machines to share
  one REST API key with fragile setup ordering; with git-only, the key stays
  gitignored and each machine mints its **own**.
- **No cloud file-sync (iCloud/Dropbox)**: putting a `.git` dir under a cloud
  syncer risks repo corruption and conflict noise, and it sends the vault off
  your machine — git to a remote you control is simpler and private.

> [!TIP]
> **Not comfortable with git?** [Obsidian Sync](https://obsidian.md/sync) (the
> official paid service) is a reasonable multi-device alternative — it's
> end-to-end encrypted and, unlike iCloud/Dropbox, it ignores hidden folders, so
> it won't corrupt the vault's `.git` directory. Caveats:
>
> - **Hidden folders don't sync.** `.raw/` (your immutable source inbox) and
>   `.vault-meta/` stay on the machine where they were created — other devices
>   get the wiki pages but not the raw sources behind them.
> - **Git history stays per-machine.** Auto-commit still runs locally wherever
>   you edit, but histories on different machines will diverge; treat one
>   machine as the keeper of record (or skip git entirely and rely on Obsidian
>   Sync's own version history).
> - **The single-writer rule still applies** — edit on one device at a time or
>   you'll be merging conflicting versions by hand.
> - It's a subscription, and your (encrypted) vault transits Obsidian's cloud.

Machine-local state (`.vault-meta/locks/`, `transport.json`) stays out of git via
the vault `.gitignore`. See `skills/secondbrain/references/sync.md`.

Upgrading from an earlier release that set up Syncthing? The sync step (run via
`/secondbrain` for marketplace installs, or `bash bin/setup-sync.sh` from a clone)
offers to remove the vault `.stignore` it wrote back then — and only that. The
Syncthing install itself is never touched (you may use it for other folders);
if you don't, the script prints the manual removal commands for you to run.

## Add a second machine

One wiki, two Macs, plain git. Two separate things land on the new machine:
the **tooling** (this plugin + its dependencies — installed fresh, one of two
ways) and the **vault content** (your notes — never reinstalled, always a
`git clone` of your vault remote).

**Step 1 — tooling.** Pick ONE install path, same as on the first machine:

- **Marketplace (most people):** install the plugin and let `/secondbrain`
  drive the setup — you never touch `bin/` directly:
  ```
  claude plugin marketplace add TechTripAi/TechTrip-AI-plugins
  claude plugin install techtrip-secondbrain@TechTrip-AI-plugins
  ```
  Then run `/secondbrain` and tell it this is a second machine — **skip the
  vault scaffold** (`setup-vault.sh`); the vault arrives in step 2.
- **Git checkout (developers):** clone *this orchestrator repo* and run the
  machine-level scripts yourself:
  ```bash
  bash bin/precheck.sh
  bash bin/setup-deps.sh
  bash bin/setup-obsidian.sh
  bash bin/setup-claude-obsidian.sh
  ```
  **Do NOT run `setup-vault.sh` on the new machine.**

**Step 2 — vault content.** Clone your *vault repo* (not this repo) from your
remote, to whatever path you use for the vault:

```bash
git clone git@github.com:TechTripAi/<vault-repo>.git ~/LLM-Wiki   # your path may differ
```

**Step 3 — wire up and verify:**

1. **Open the vault in Obsidian**; trust it and enable community plugins (they
   came with the clone).
2. **Wire MCP:** `setup-mcp.sh <vault>` (via `/secondbrain` or `bin/`) — it
   reuses the committed plugin config and mints this machine's own Local REST
   API key. Reload Claude Code.
3. **Verify:** `doctor.sh <vault>` (via `/secondbrain-doctor` or `bin/`) — green.

**Living with two machines:** work from one machine at a time (the single-writer
rule), `git pull` before you start, `git push` when you finish. Auto-commit runs
wherever the edit happens, so an unpushed machine is simply behind — never
conflicted — as long as you follow that rhythm.
