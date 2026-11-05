# Use with any harness

Back to the [README](../README.md).

## Use with any Harness: Claude Code, Cursor, Copilot CLI, and other harnesses

Claude Code is the **install vehicle** (the plugin marketplace is how
`claude-obsidian` and this orchestrator land on disk). That is **not** a runtime
lock-in. The wiki is plain Markdown in a vault folder, and every skill is an
ordinary `SKILL.md` under the Claude plugin cache. Any agent harness that can
read those files and edit the vault — Cursor, GitHub Copilot CLI, Codex, and
others — can drive the
same ingest / query / lint workflow. Using multiple harnesses against one vault
is expected, not a workaround.

Example — after setup, tell Cursor something like:

```
Read the skills under
~/.claude/plugins/cache/TechTrip-AI-plugins/claude-obsidian/<version>/skills/
and
~/.claude/plugins/cache/TechTrip-AI-plugins/techtrip-secondbrain/<version>/skills/.
Update yourself to use them against my vault at ~/LLM-Wiki — treat wiki-ingest,
wiki-query, wiki-lint, yt-fetch, x-fetch, voice-fetch, code-fetch, notebooklm-ingest, and new-idea as first-class
workflows, the same way Claude Code would.
```

Replace `<version>` with the installed version directory (e.g. `1.9.2`) and
`~/LLM-Wiki` with your vault path. Claude Code–specific hooks (auto-commit,
hot-cache injection) only fire inside Claude Code sessions; other harnesses get
the skills and the vault.

**Or automate all of that** with the harness setup step. **Installed from the
marketplace?** It's a step inside `/secondbrain` — run that; you never touch
`bin/` directly. **Cloned the git repo?** The direct door is:

```bash
bash bin/setup-harnesses.sh ~/LLM-Wiki
```

It symlinks the installed skills into the cross-vendor discovery dirs
(`~/.agents/skills/`, and `~/.codex/skills/` when Codex is present) and stamps
harness-parity artifacts into the vault: a root `AGENTS.md` (the operating
contract every agent reads), plus hook ports of the claude-obsidian hooks
(auto-commit, stale-lock cleanup, hot-cache injection/refresh nudge) for
**Cursor** (`.cursor/hooks.json` + scripts) and **GitHub Copilot CLI**
(`.github/hooks/wiki-vault.json` + scripts — Copilot even gets `wiki/hot.md`
injected at session start, same as Claude Code). Idempotent; never overwrites
files you've customized. It must
re-run after every plugin update so the skill links re-point at the new version —
both update paths do this for you (`bin/update.sh` for clones, the `/secondbrain`
re-run for marketplace installs).
