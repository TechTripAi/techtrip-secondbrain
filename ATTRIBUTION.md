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
git/Syncthing sync setup, and our own `yt-fetch` / `notebooklm-ingest` source skills
(original work — see the tool-dependency note below for the runtime tools they invoke).
Full credit for the second-brain wiki system itself goes to AgriciDaniel.

## Obsidian community plugins

Installed from each plugin's own GitHub releases (see `manifest.json`), each under its
own author and license — e.g. `obsidian-local-rest-api` (coddingtonbear),
`dataview` (blacksmithgu), `templater-obsidian` (SilentVoid13),
`obsidian-excalidraw-plugin` (zsviczian), `calendar` (liamcain),
`obsidian-banners` (noatpad), `obsidian-memos` (Quorafind),
`list-to-table` (kepano). Not vendored here.

## Tool dependencies invoked by our skills

Our source skills are our own code, but they shell out to third-party command-line
tools at runtime (exactly as they invoke `git`, `yt-dlp`, or `curl`). These tools are
**installed on the user's machine, not vendored or redistributed here**; each remains
under its own author and license.

- **`notebooklm-py`** — by **teng-lin** — <https://github.com/teng-lin/notebooklm-py>.
  An unofficial NotebookLM client. Our `notebooklm-ingest` skill installs it from PyPI
  (`uv tool install notebooklm-py`) and drives its `notebooklm` CLI; none of its source
  lives in this repository. License: see the upstream repository.
- **`yt-dlp`** — <https://github.com/yt-dlp/yt-dlp> (Unlicense). Our `yt-fetch` skill
  calls it to pull captions and metadata.

## Defuddle — by kepano

The `defuddle` article-extraction workflow our skills reference is powered by
**Defuddle**, by **kepano** (Steph Ango) — <https://github.com/kepano/defuddle>. It is
his work; we do not vendor it. kepano also authors the `list-to-table` community plugin
credited above.

## Pattern

Based on Andrej Karpathy's "LLM Wiki" pattern, as implemented by `claude-obsidian`.
