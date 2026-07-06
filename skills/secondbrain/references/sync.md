# reference: sync

`bin/setup-sync.sh` sets up how the vault travels between machines.

## Git (default, always — on the PRIMARY machine)

The `claude-obsidian` plugin already **auto-commits** `wiki/ .raw/ .vault-meta/` on
every write (its `PostToolUse` hook). So git is the zero-extra-dependency backbone:
the script just `git init`s the vault (if needed), makes an initial commit, and
prompts the user to add an `origin` remote, e.g.:

```
git -C <vault> remote add origin git@github.com:TechTripAi/<vault-repo>.git
git -C <vault> push -u origin main
```

Versioned, portable, works off-LAN.

## Syncthing (optional, real-time LAN)

For live multi-Mac sync without a cloud service, the script installs Syncthing
(`brew install syncthing`, `brew services start`) and writes a vault `.stignore` so
Syncthing and git don't fight, and machine-local state stays home:

```
.git
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash
.DS_Store
.vault-meta/locks
.vault-meta/transport.json
```

`.vault-meta/locks` and `transport.json` are per-machine state — syncing locks would
let one machine's stale-lock clear or `release` kill the other's in-flight lock;
`transport.json` is a local transport-detection snapshot. `mode.json` (vault
methodology) is vault config and **does** sync. The script is upgrade-idempotent: on
an existing `.stignore` it appends only missing entries.

Pair devices in the UI at http://127.0.0.1:8384 (exchange Device IDs, share the
vault folder), and **set a GUI password** (Settings → GUI → User/Password): the UI
controls what syncs where, and without one any local process can reconfigure it.
**`.stignore` itself is never synced by Syncthing** — run `setup-sync.sh` on each
machine so each has its own.

**Single-writer rule:** edit on one machine at a time. Concurrent edits to the same
file produce `.sync-conflict-*` copies (Syncthing does not merge). Git history stays
authoritative on whichever machine runs the auto-commit hook.

## Second machine (SECONDARY — Syncthing mirror, no git)

The two-machine model: the **primary** keeps the vault's git repo; a **secondary**
is a Syncthing mirror with **no `.git`** — claude-obsidian's auto-commit hook exits
silently without `.git`, so histories can never diverge. Ingest works from either
machine (pure filesystem). Steps on the new Mac (full detail in README
"Add a second machine"):

1. Machine-level setup only: `precheck` → `setup-deps` → `setup-obsidian` →
   `setup-claude-obsidian`. **Do NOT run `setup-vault.sh`** — content (including
   `.obsidian` community plugins) arrives via Syncthing.
2. `mkdir` the empty vault folder, then `setup-sync.sh <path>`: **decline git init**,
   accept Syncthing (writes this machine's own `.stignore`).
3. Pair + share the folder from the primary; **wait for the first full sync**.
4. Open the vault in Obsidian; enable community plugins (synced from the primary).
5. `setup-mcp.sh <path>` — it **reuses the synced Local REST API key** (the two
   machines deliberately share one key; `setup-mcp` never regenerates an existing
   key). Ordering matters: running it *before* the first full sync generates a
   fresh key that syncs back and breaks the primary's MCP until `repair-mcp.sh`.
6. `doctor.sh <path>` — green; no git on a secondary is expected and correct.

Secondary caveats: no per-edit auto-commit (Syncthing is the live safety net), and
the git-gated `Stop` hot-cache nudge never fires there — tell the user to end heavy
sessions on the secondary with "update the hot cache".

## Which to pick

- Your own Macs on a LAN, want instant propagation → **primary/secondary**:
  git + Syncthing on the primary, Syncthing-only (no git) on secondaries.
- Off-network access / a durable versioned backup / one machine only → **git only**;
  another machine can also `git clone` the remote and push/pull manually, but then
  keep Syncthing OFF for that clone (git-on-both plus Syncthing is the combination
  that fights).
