# Updating

How to update an existing second brain, plus release and upgrade notes for versions that changed behavior. Back to the [README](../README.md).

## Updating an existing secondbrain

Already bootstrapped this machine? How you update depends on how you installed —
pick your path.

### If you installed via the marketplace (most people)

The orchestrator handles everything downstream — including updating
`claude-obsidian` (installed from TechTrip's maintained fork) and re-pinning
the community plugins. The only thing you update by hand is the orchestrator
itself. **Recommended route** — refresh the catalog in the terminal, then
update from inside Claude Code:

```
claude plugin marketplace update          # terminal: refresh every registered catalog
```

The plugin id is `techtrip-secondbrain@TechTrip-AI-plugins`; `claude plugin list` shows it.

then in Claude Code: **`/plugin` → Manage plugins → update
`techtrip-secondbrain`**. The in-app manager resolves the installed plugin
from Claude Code's own registry, so it works the same on every Claude Code
version — unlike the CLI form below.

**Both steps are required — they update two different things.** `marketplace update`
only git-pulls the marketplace *catalog* (a clone under
`~/.claude/plugins/marketplaces/`); you'll see new files arrive there, but Claude
Code doesn't run from that clone. Installed plugins run from a **versioned snapshot**
under `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`, pinned by the
registry (`~/.claude/plugins/installed_plugins.json`). Only the plugin update
copies the new version into the cache and re-points that pin — skip it and the
marketplace has fresh scripts while you keep running the old ones.

The CLI alternative is `claude plugin update techtrip-secondbrain` — but which
spec it accepts depends on your Claude Code version: newer CLIs take the bare
plugin name and reject `techtrip-secondbrain@TechTrip-AI-plugins`
("marketplace not found"), while older CLIs — e.g. 2.1.x — are the exact
opposite ("Plugin not found" on the bare name). If one form errors, use the
other (`bin/update.sh` tries both), or just use the in-app route above. Also
note the updater goes by the manifest's `version` field: if a release changed
scripts without bumping the version, the update reports "already current" and
the pin doesn't move.

Then **restart Claude Code** (or `/reload-plugins` + `/reload-skills`) so the new
version loads, and run:

```
/secondbrain
```

It re-runs the idempotent setup scripts from the plugin: `setup-claude-obsidian.sh`
updates `claude-obsidian` (and migrates an upstream install over to the fork if
needed), the vault scaffold re-pins the community plugins to this release's
manifest tags (each asset re-verified against its `sha256`), the cross-harness
skill links (Cursor/Codex) are re-pointed at the new plugin version, the MCP
registration is reconciled to the tested `mcp-obsidian==0.2.2` without rotating
its key, and it
finishes with a health check — without touching your notes, git history, MCP key,
or optional-feature choices. (Skip the `/secondbrain` re-run and those harness
links silently keep serving the *old* skills — `doctor` flags this as stale.)

The re-run **ends with the doctor health check automatically** — you don't have to
run it separately after an update. That said, `/secondbrain-doctor` is read-only,
takes seconds, and is safe to run **any time**: a periodic check (say, monthly, or
whenever something feels off) catches drift early — stale harness links, a key
mismatch, a disabled community plugin — before it costs you a debugging session. **Do not run `claude plugin update claude-obsidian`
yourself** — the orchestrator owns that plugin's lifecycle: a bare plugin update
can't migrate an upstream install to the fork, only the orchestrator can.

### If you cloned the git repo

You have the scripts locally, so one command does everything above:

```bash
cd techtrip-secondbrain
git pull                       # get the latest scripts + manifest
bash bin/update.sh ~/LLM-Wiki  # substitute your vault path (or omit — the saved setup path is used)
```

`update.sh` refreshes the catalog, updates the `techtrip-secondbrain` **and**
`claude-obsidian` plugins, re-runs the idempotent vault scaffold so community plugins
are re-pinned to the manifest's tags (each asset re-verified against its `sha256`),
reconciles the pinned MCP command with rollback on failure, and finishes with
`bin/doctor.sh`. It **does not** touch your notes, git history, MCP
key, or optional-feature choices. Every prompt is confirm-gated; `--dry-run` previews
without changing anything. **Restart Claude Code** afterward so the new plugin, skill,
and hook versions load.

## Release and upgrade notes

> [!IMPORTANT]
> **Release and upgrade notes for v0.2.17 (2026-08-10).** Setup no longer
> installs external software behind a plain yes/no: it prints the exact command
> (`brew install --cask obsidian`, `brew install yt-dlp`, …) and asks whether to
> run it for you or wait while you install it yourself, then re-checks either
> way. Declining never blocks — precheck flags the gap and `/secondbrain`
> re-offers on any re-run. The maintained fork is pinned to **1.9.6**: updates
> stop overwriting user-tuned `.obsidian` settings, and the fork's own installs
> (Excalidraw download, home-directory symlinks) now ask first.
>
> Since v0.2.16, `/new-idea` makes
> freshness metadata part of Reconcile and the end-of-session ritual. Existing
> vault-local templates gain the missing `project.md` field through a narrow,
> idempotent migration; customized workflows that cannot be patched safely are
> preserved with a manual-merge warning. Existing project content is never
> bulk-stamped with a misleading current date.
>
> Since v0.2.15, `code-fetch` is an
> agent reading pass: its script stages the codebase (a shallow clone for git URLs,
> local paths read in place, plus an inventory), then the agent reads the README,
> entry points, API surface, and tests and writes one semantic digest to `.raw/code/`.
> It needs only `git`, so it is always available rather than an optional feature.
>
> Also since v0.2.7, **`bin/reset-vault.sh`** can empty a vault after a verified
> backup (keeping MCP wiring by default, or retiring and re-scaffolding with
> `--scorch`), **`doctor`** audits the manifest's skill list against the installed
> plugin cache, and claude-obsidian is pinned to **1.9.6**.
>
> **Still on 0.1.0?** v0.2.0 removed Syncthing support; git is now the only sync
> path. See [Updating an existing secondbrain](#updating-an-existing-secondbrain),
> using either the [plugin marketplace](#if-you-installed-via-the-marketplace-most-people)
> or a [local git clone](#if-you-cloned-the-git-repo). The update does not uninstall
> anything from your machine or rewrite content notes; it can surgically migrate
> techtrip-secondbrain's managed origination workflow/template metadata. If the
> vault still has a `.stignore`, setup offers to
> remove that project-created artifact. Full details are in the
> [CHANGELOG](../CHANGELOG.md).
