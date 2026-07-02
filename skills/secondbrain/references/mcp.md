# reference: Obsidian MCP server

`bin/setup-mcp.sh` wires the `obsidian` MCP server so Claude can read/write the vault
through the Local REST API plugin.

## The key handshake

There is one secret shared between two places:

1. **`<vault>/.obsidian/plugins/obsidian-local-rest-api/data.json`** → `apiKey`
   (64-hex). We generate it with `openssl rand -hex 32` if the vault has none, and
   write `data.json` with just `apiKey` (+ `enableInsecureServer:false`). Obsidian
   regenerates the self-signed TLS cert from this on first launch.
2. **`~/.claude.json`** → `mcpServers.obsidian.env.OBSIDIAN_API_KEY` — set to the
   **same** value.

`bin/doctor.sh` verifies these two match.

## MCP registration

Registered at **user scope** (works from any directory) via `claude mcp add`, using
the settings from `manifest.json.mcpServers[0]`:

```
command: uvx      args: mcp-obsidian
env: OBSIDIAN_HOST=127.0.0.1  OBSIDIAN_PORT=27124
     NODE_TLS_REJECT_UNAUTHORIZED=0  OBSIDIAN_API_KEY=<generated>
```

- Port **27124** is the Local REST API plugin's HTTPS port; the self-signed cert is
  why `NODE_TLS_REJECT_UNAUTHORIZED=0` is needed.
- `uvx` (not `npx`) runs the tested Python `mcp-obsidian` — requires `uv`.

## Gotchas to tell the user

- The MCP server only becomes callable **after a Claude session reload**.
- It only answers while **Obsidian is running** with the Local REST API plugin
  **enabled**. Until then, `curl` probes and MCP calls will fail — that's expected.
- To rotate the key: delete the server (`claude mcp remove obsidian`), delete
  `apiKey` from `data.json`, and re-run `bin/setup-mcp.sh`.
