# After setup

Manual follow-ups once `/secondbrain` finishes, and the optional features you can turn on or off at any time. Back to the [README](../README.md).

## After setup — there are some manual follow-ups

These can't be automated:

1. **Open the vault in Obsidian** and, when prompted, trust it and enable community
   plugins (Settings → Community plugins). This also generates the REST API TLS cert.
2. **Reload Claude Code** so the `claude-obsidian` skills/hooks and the `obsidian` MCP
   server activate. (/exit and then run `claude --resume`, alternatively you may do a `/reload-skills` followed by `/reload-plugins`)
3. Run **`/wiki`** to scaffold content from a one-sentence description of the vault.
   It shows the six wiki modes side by side first; a mode is a folder set plus filing
   rules, not an Obsidian feature, and custom modes are normal.
4. Run **`/mode-fit`** (also the last step of `/secondbrain`): three questions about
   what you will feed in and what you want out, then a verdict on whether the mode
   fits, with missing folders added or a rebuild prompt handed over. Cheapest now,
   while the vault is empty.
5. If you enabled **NotebookLM**, run the one-time **`notebooklm login`** OAuth (setup
   offers it, but it's interactive so you may have deferred it). Any feature you
   declined during setup can be enabled later — see [Optional features](#optional-features) below.
6. New to the wiki? Run **`/brain-dump`** for a guided tour of how to feed sources in,
   start a new idea with `/new-idea`, keep the vault healthy, and turn optional
   features on or off. `/secondbrain` offers to launch it once setup is green.

## Optional features

The base second brain ships **lean**, and setup asks about each optional feature
**inline** — you answer two quick questions during `/secondbrain` instead of being
told to run a script later. The two are deliberately not treated the same, because
they don't carry the same risk:

| Feature | Skill | What it adds | Runtime installed | Setup default |
|---------|-------|--------------|-------------------|---------------|
| **YouTube + X** | `yt-fetch`, `x-fetch` | pull a YouTube video's transcript + metadata into `.raw/videos/`; pull an X (Twitter) post's text + metadata into `.raw/posts/` — x-fetch also transcribes video posts on-device when Voice is enabled | `yt-dlp` (Homebrew) | **yes** — a passive CLI binary: no daemon, no credentials, no data leaving your machine |
| **Voice / audio** | `voice-fetch` | transcribe voice memos & local audio into `.raw/audio/`, fully on-device (WhisperKit / Neural Engine); also powers x-fetch's video transcripts | `whisperkit-cli` (Homebrew) | **yes** — no cloud, no credentials; first transcription downloads a CoreML model once |
| **NotebookLM** | `notebooklm-ingest` | offload multi-source synthesis to Google NotebookLM, then ingest the report | `notebooklm-py` (via `uv`) + one-time `notebooklm login` | **no — explicit opt-in**: it sends your sources to Google, and the login is an interactive OAuth |

`yt-fetch` and `x-fetch` fetch **anonymously** — no browser, no cookies, no account,
no dialogs. For the rare age-gated, members-only, or protected item, *you* can opt in
per run with `YT_FETCH_COOKIES_BROWSER=firefox` / `X_FETCH_COOKIES_BROWSER=firefox`,
which reuses that browser's logged-in session (ideally a spare account; Chrome
triggers a macOS Keychain dialog, Safari needs Full Disk Access). The agent is
forbidden from setting those on its own, and neither is a fix for rate limits.

Their *skills* always ship with the plugin; the questions only govern the runtime
each needs. Declining costs nothing — enable any feature later by re-running
`/secondbrain` (idempotent; everything already installed is skipped). That's the
whole answer for marketplace installs; git-clone users can also go in directly:

```bash
bash bin/setup-features.sh ~/LLM-Wiki                 # walk all three (git clone only)
bash bin/setup-features.sh ~/LLM-Wiki youtube         # just one
bash bin/setup-features.sh ~/LLM-Wiki voice
bash bin/setup-features.sh ~/LLM-Wiki notebooklm
```

To turn a feature **off**, uninstall its runtime — the vault, skills, and your notes
are untouched:

```bash
brew uninstall yt-dlp                                      # YouTube + X
brew uninstall whisperkit-cli                              # Voice / audio
uv tool uninstall notebooklm-py                            # NotebookLM
```

The script is **idempotent**: already-enabled features report green and change
nothing. `/secondbrain-doctor` (or `bin/doctor.sh` from a clone) shows each
feature's on/off state (off is reported, never failed). **`/brain-dump` is the standing reference for all of this** — its
optional-features section walks through checking, enabling, and disabling each one,
and it's re-runnable any time.
