# Attribution

`techtrip-secondbrain` is an **orchestrator/enhancement layer**. It stands on the
work of others and does not vendor or fork their code — it installs their published
artifacts at setup time so you always get their upstream updates.

## claude-obsidian — by AgriciDaniel

The core LLM Wiki runtime (skills, hooks, vault scaffold) is provided entirely by the
**`claude-obsidian`** Claude Code plugin:

- **Author:** AgriciDaniel — <https://github.com/AgriciDaniel>
- **Repository:** <https://github.com/AgriciDaniel/claude-obsidian>
- **License:** MIT
- **How we use it:** installed from AgriciDaniel's own Claude Code marketplace
  (`claude plugin marketplace add AgriciDaniel/claude-obsidian`) at setup time. It is
  **not** copied, vendored, forked, or redistributed in this repository. All of its
  skills, hooks, `bin/setup-vault.sh` scaffold, and `WIKI.md`/`CLAUDE.md` schema are
  his work and remain under his repository and license.

`techtrip-secondbrain` only adds the pieces AgriciDaniel's plugin leaves to the user:
a macOS bootstrapper (install Obsidian + community plugins), MCP wiring + repair,
git/Syncthing sync setup, and the ported `yt-fetch` / `notebooklm-ingest` source
skills. Full credit for the second-brain wiki system itself goes to AgriciDaniel.

## Obsidian community plugins

Installed from each plugin's own GitHub releases (see `manifest.json`), each under its
own author and license — e.g. `obsidian-local-rest-api` (coddingtonbear),
`dataview` (blacksmithgu), `templater-obsidian` (SilentVoid13),
`obsidian-excalidraw-plugin` (zsviczian), `calendar` (liamcain),
`obsidian-banners` (noatpad), `obsidian-memos` (Quorafind),
`list-to-table` (kepano). Not vendored here.

## Pattern

Based on Andrej Karpathy's "LLM Wiki" pattern, as implemented by `claude-obsidian`.
