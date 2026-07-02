# reference: sync

`bin/setup-sync.sh` sets up how the vault travels between machines.

## Git (default, always)

The `claude-obsidian` plugin already **auto-commits** `wiki/ .raw/ .vault-meta/` on
every write (its `PostToolUse` hook). So git is the zero-extra-dependency backbone:
the script just `git init`s the vault (if needed), makes an initial commit, and
prompts the user to add an `origin` remote, e.g.:

```
git -C <vault> remote add origin git@github.com:TechTripAi/<vault-repo>.git
git -C <vault> push -u origin main
```

Versioned, portable, works off-LAN. On another machine: clone the repo, then run the
rest of the bootstrap (deps, Obsidian, plugins, MCP) against the clone.

## Syncthing (optional, real-time LAN)

For live multi-Mac sync without a cloud service, the script installs Syncthing
(`brew install syncthing`, `brew services start`) and writes a vault `.stignore` so
Syncthing and git don't fight:

```
.git
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.trash
.DS_Store
```

Pair devices in the UI at http://127.0.0.1:8384 (exchange Device IDs, share the
vault folder).

**Single-writer rule:** edit on one machine at a time. Concurrent edits to the same
file produce `.sync-conflict-*` copies (Syncthing does not merge). Git history stays
authoritative on whichever machine runs the auto-commit hook.

## Which to pick

- Only your own Macs on a LAN, want instant propagation → **git + Syncthing**.
- Want off-network access / a durable versioned backup / simplest setup → **git only**.
