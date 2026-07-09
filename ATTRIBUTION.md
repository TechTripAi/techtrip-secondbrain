# Attribution

`techtrip-secondbrain` is an **orchestrator/enhancement layer**. It stands on the
work of others and does not vendor or copy their code into this repository — it
installs their published artifacts at setup time. Where a dependency needs a bug fix
its upstream hasn't shipped yet, we install from a transparent, attributed **fork**
that retains the original author's copyright and license (see below), and we file the
fix upstream.

## claude-obsidian — by AgriciDaniel

The core LLM Wiki runtime (skills, hooks, vault scaffold) is provided entirely by the
**`claude-obsidian`** Claude Code plugin:

- **Author:** AgriciDaniel — <https://github.com/AgriciDaniel>
- **Repository:** <https://github.com/AgriciDaniel/claude-obsidian>
- **License:** MIT
- **Citation:** the upstream repo provides a
  [`CITATION.cff`](https://github.com/AgriciDaniel/claude-obsidian/blob/main/CITATION.cff);
  if you cite this second-brain system in writing or research, cite `claude-obsidian`
  using that file's metadata.
- **How we use it:** installed at setup time from a **lightly-patched fork we maintain**
  — [`TechTripAi/claude-obsidian`](https://github.com/TechTripAi/claude-obsidian)
  (`claude plugin marketplace add TechTripAi/claude-obsidian`). The fork carries **bug
  fixes only** (no feature divergence) that upstream is backlogged on — e.g. removing an
  invalid `SessionStart` hook, [upstream issue #116](https://github.com/AgriciDaniel/claude-obsidian/issues/116)
  — and tracks AgriciDaniel's repo via a git remote for periodic sync. Per its MIT
  license, the fork **retains AgriciDaniel's copyright and `LICENSE`** and is
  redistributed under those same terms. None of his code is copied or vendored into
  *this* (`techtrip-secondbrain`) repository. All of the plugin's skills, hooks,
  `bin/setup-vault.sh` scaffold, and `WIKI.md`/`CLAUDE.md` schema are his work and
  remain under his copyright and MIT license.

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
