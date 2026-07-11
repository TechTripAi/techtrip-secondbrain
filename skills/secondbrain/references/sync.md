# reference: sync

`bin/setup-sync.sh` sets up how the vault travels between machines. **Git is the
only sync path.** (Syncthing support was removed — a background network daemon
and `.sync-conflict` merge copies were complexity the second brain doesn't need.
The script detects a legacy Syncthing install and offers a teardown.)

## Git (always)

The `claude-obsidian` plugin already **auto-commits** `wiki/ .raw/ .vault-meta/` on
every write (its `PostToolUse` hook). So git is the zero-extra-dependency backbone:
the script just `git init`s the vault (if needed), makes an initial commit, and
prompts the user to add an `origin` remote, e.g.:

```
git -C <vault> remote add origin git@github.com:TechTripAi/<vault-repo>.git
git -C <vault> push -u origin main
```

Versioned, portable, works off-LAN.

## Machine-local state stays out of git

`.vault-meta/locks/` and `transport.json` are per-machine state — sharing locks
would let one machine's stale-lock clear or `release` kill another's in-flight
lock; `transport.json` is a local transport-detection snapshot. Keep them in the
vault's `.gitignore`. `mode.json` (vault methodology) is vault config and **is**
versioned.

## Second machine

Clone the remote and work with normal git flow:

1. Machine-level setup: `precheck` → `setup-deps` → `setup-obsidian` →
   `setup-claude-obsidian`. **Do NOT run `setup-vault.sh`** — content (including
   `.obsidian` community plugins) arrives via the clone.
2. `git clone <remote> <vault-path>`, then open the vault in Obsidian and enable
   community plugins.
3. `setup-mcp.sh <path>` — it **reuses the cloned Local REST API key** (machines
   deliberately share one key; `setup-mcp` never regenerates an existing key).
4. `doctor.sh <path>` — green.

**Single-writer rule still applies:** edit on one machine at a time and
push/pull between switches. Auto-commit runs wherever the edit happens, so an
unpushed machine is simply behind — `git pull` before starting, `git push` when
done.
