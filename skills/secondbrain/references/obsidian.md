# reference: Obsidian + dependencies

## Dependencies (`bin/setup-deps.sh`)

Installs the CLI tools in `manifest.json.binaries` via Homebrew:

- **Homebrew** — base for everything. If missing, the script stops and prints the
  official install one-liner (we never auto-run a remote `curl | bash`); re-run after.
- **uv / uvx** (`brew install uv`) — runs `mcp-obsidian` (the MCP server) and
  `notebooklm-py`.
- **node** — required by Claude Code and by our own `manifest.json` reader.

`yt-dlp` (powers `yt-fetch`) is deliberately **not** installed here — it's an
optional feature, consent-gated and installed by `bin/setup-features.sh` when
the user says yes to YouTube during setup.

## Obsidian app (`bin/setup-obsidian.sh`)

`brew install --cask obsidian`. Skips if `/Applications/Obsidian.app` exists.
If the user declines brew, point them to https://obsidian.md/download.

Obsidian does **not** need to be running during install — but it **does** need to be
opened once at the end so it (a) generates the Local REST API self-signed cert from
the key we wrote, and (b) lets the user enable community plugins. The REST API /
MCP handshake only works while Obsidian is open with the plugin enabled.
