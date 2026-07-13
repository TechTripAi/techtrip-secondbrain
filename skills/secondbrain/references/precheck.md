# reference: precheck

`bin/precheck.sh` audits this machine against `manifest.json` and prints a
PRESENT / MISSING table. It **mutates nothing** and always exits 0 — safe to run
anytime.

It checks four groups:

- **binaries** — `brew`, `git`, `node`, `uvx`, `flock`, `python3` (required);
  `yt-dlp` is reported as `optional (off)`, never `missing` — setup-features
  installs it on consent
- **apps** — Obsidian (`/Applications/Obsidian.app`)
- **claudePlugins** — `claude-obsidian` (via `claude plugin list`)
- **mcpServers** — `obsidian` (via `claude mcp list`)

For each MISSING item it prints the exact remediation (the `bin/setup-*.sh` to run,
or the manual command). Use it as the map for the rest of the workflow: run only the
setup scripts for the gaps it reports.

Notes:
- If the `claude` CLI is absent, plugin/MCP rows can't be checked — Claude Code is a
  prerequisite, so install it first.
- `manifest.json` is the single source of truth; edit it to change what is audited
  and installed (every `setup-*.sh` reads it too).
