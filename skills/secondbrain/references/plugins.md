# reference: community plugins + vault scaffold

## Vault scaffold (`bin/setup-vault.sh`)

1. Resolves the vault path (arg → saved state → default `~/LLM-Wiki`) and creates it.
2. Delegates the **base scaffold** to `claude-obsidian`'s own
   `bin/setup-vault.sh` (found in its plugin cache). That writes `.obsidian/`
   config (`graph.json`, `app.json`, `appearance.json`), creates the `wiki/` tree +
   `_templates/` + `.raw/`. If the plugin isn't installed yet, we create a minimal
   `wiki/` tree ourselves and warn — install `claude-obsidian` first for the full
   scaffold + hooks.
3. Installs the community plugins.
4. Seeds our own empty starter canvas (never AgriciDaniel content).

## Community-plugin install mechanism (`scripts/install-obsidian-plugin.sh`)

Obsidian has **no official plugin CLI**, so we install plugins the same way
`TechTrip.AI/.claude/settings.local.json` already does: download `manifest.json`,
`main.js`, and (optional) `styles.css` from the plugin's GitHub **release** into
`<vault>/.obsidian/plugins/<id>/`, then add `<id>` to
`.obsidian/community-plugins.json`. Idempotent: skips if `main.js` already present.

Plugins from `manifest.json.obsidianPlugins`:

| id | repo | why |
|----|------|-----|
| `obsidian-local-rest-api` | coddingtonbear/obsidian-local-rest-api | **required** — the MCP server talks to this |
| `obsidian-excalidraw-plugin` | zsviczian/obsidian-excalidraw-plugin | drawing/canvas; ~8MB main.js pulled from release |
| `dataview` | blacksmithgu/obsidian-dataview | queries/dashboards |
| `templater-obsidian` | SilentVoid13/Templater | note templates |
| `calendar` | liamcain/obsidian-calendar-plugin | daily-note calendar |
| `obsidian-banners` | noatpad/obsidian-banners | header images |
| `obsidian-memos` | Quorafind/Obsidian-Memos | quick capture |
| `list-to-table` | kepano/list-to-table | list→table |

`pocket-sync` is intentionally excluded (personal integration). Add/remove plugins by
editing `manifest.json` — the scaffold loops over whatever is listed.

Community plugins land **disabled until trusted**: on first launch Obsidian asks the
user to turn on community plugins. That's expected and can't be scripted away.
