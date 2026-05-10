# Claude Desktop

Claude Desktop (the macOS / Windows app) connects to Like Me Like as
a remote MCP server.

## Recommended path: Connectors UI

The current MCP spec routes remote (HTTP) servers through Claude
Desktop's **Settings → Connectors → Add custom connector**. Paste
the URL, choose header-based auth, and add the `X-LML-Agent-Id`
header value when prompted.

- **URL:** `https://www.likemelike.com/api/v1/mcp`
- **Transport:** Streamable HTTP (auto-detected)
- **Header:** `X-LML-Agent-Id: <your-stable-id>`

The "stable id" is any 8–256 char ASCII string that uniquely
identifies the end-user across sessions. Reuse the same value across
calls so the shadow profile builds up — see
[`docs/agents.md`](../../docs/agents.md).

## Alternative: stdio bridge for `claude_desktop_config.json`

If you prefer to manage servers via the JSON config file (or the
Connectors UI isn't available in your build), wrap the remote server
with [`mcp-remote`](https://www.npmjs.com/package/mcp-remote):

```json
{
  "mcpServers": {
    "like-me-like": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://www.likemelike.com/api/v1/mcp",
        "--header",
        "X-LML-Agent-Id:${LML_AGENT_ID}"
      ],
      "env": {
        "LML_AGENT_ID": "your-stable-id-here"
      }
    }
  }
}
```

Config locations:

- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

Restart Claude Desktop after editing. You should see seven Like Me
Like tools listed in the tool inspector: `recommend_cross`,
`recommend_scoped`, `disambiguate`, `get_item`, `search_items`,
`get_profile`, `ask`.

## How Claude uses the tools

The MCP `ask` tool's description (served fresh from the LMLM
server every time Claude Desktop connects) carries explicit
guidance:

- **First-call kickoff** — Claude bridges the asymmetry by bringing
  concrete `liked_items` from your prior conversation history on
  the first call, either as confident extraction (passes them
  directly) or propose-and-confirm ("I'll factor in X, Y, Z that
  you've mentioned loving — that OK?").
- **`agent_calibration`** — every response includes a programmatic
  feedback block (`signal_quality`, `missing_signals[]`, `hint`)
  that tells Claude per-turn what would help on the next call.
  Claude reads this automatically; you don't need to.

No extra setup needed — the tool description carries the
instructions, so Claude sees them when MCP tools are listed.

## What you can ask

Once connected, just ask Claude things like:

- "Based on Interstellar, what's a great book to read next?"
- "I love Stoner, Past Lives, and Joni Mitchell. Recommend a
  restaurant in Amsterdam."
- "My friend's birthday is next week — she's into 90s indie films.
  Suggest a gift book." (this triggers gift mode)

The brain orchestrates the atomic tools on your behalf. For
fine-grained control you can address tools directly ("use
`disambiguate` on Dune first").

## Cost & free tier

Like Me Like is a paid API. Each `X-LML-Agent-Id` (one per
end-user) gets **10 free calls one-time**, then `POST /api/v1/billing/topup`
gates further calls via x402 USDC on Base. For a personal Claude
Desktop install where you're the only user, one stable id reused
across sessions is the right shape — you'll get 10 free calls on
that id, then top up. See
[Payments in docs/agents.md](../../docs/agents.md#payments-x402-via-coinbase-cdp).

## Verification

If Claude can't see the tools, run `tools/list` from the inspector
or check the Claude Desktop logs (`~/Library/Logs/Claude/` on macOS).
A 401 response means the `X-LML-Agent-Id` header is missing or
malformed; a 402 means you've exhausted the 10-call free tier and
need to top up.
