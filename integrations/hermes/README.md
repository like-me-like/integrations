# Hermes Agent

[Hermes Agent](https://hermes-agent.nousresearch.com) supports MCP
servers natively as a first-class config block. Connecting Like Me
Like is a YAML snippet — no Python plugin required.

## Files

- [`config.yaml`](config.yaml) — the `mcp_servers.like-me-like`
  block to merge into your `~/.hermes/config.yaml`.

## Quick start

1. Copy the snippet from [`config.yaml`](config.yaml) into your
   `~/.hermes/config.yaml`, merging under `mcp_servers:`.
2. Replace `replace-with-your-stable-id` with a stable end-user
   identifier (8–256 ASCII chars; reuse it across calls).
3. Restart Hermes. The Like Me Like tools should appear when you
   list MCP tools.

## Config snippet

```yaml
mcp_servers:
  like-me-like:
    url: "https://likemelike.com/api/v1/mcp"
    headers:
      X-LML-Agent-Id: "replace-with-your-stable-id"
    timeout: 120
    connect_timeout: 60
```

The 120 s timeout is generous — the first call with `liked_items`
triggers cohort matching that can take ~10–30 s, and a chained
`recommend_*` call adds another 10–20 s of LLM work on top.

## Tools exposed

Same seven tools as every other MCP integration: `ask` (one-shot
natural language), `recommend_cross`, `recommend_scoped`,
`disambiguate`, `get_item`, `search_items`, `get_profile`. See the
[OpenAPI spec](../../docs/openapi.json) or
[`docs/agents.md`](../../docs/agents.md) for argument shapes.

## Per-server tool filtering

Hermes supports allow-listing tools per MCP server. If you only
want the `ask` tool exposed (cleanest UX for natural-language
agents), restrict it:

```yaml
mcp_servers:
  like-me-like:
    url: "https://likemelike.com/api/v1/mcp"
    headers:
      X-LML-Agent-Id: "replace-with-your-stable-id"
    enabled_tools:
      - ask
```

For agents that want fine control, expose all tools and let the
host LLM choose.

## Cost & free tier

Like Me Like is a paid API. Each `X-LML-Agent-Id` gets **10 free
calls one-time**, then `POST /api/v1/billing/topup` gates further
calls via x402 USDC on Base. For a personal Hermes setup with one
end-user, reuse a single stable id across calls; for multi-tenant
deployments derive the id from the end-user (`sha256(user_id)`)
so each user gets their own free tier. See
[Payments in docs/agents.md](../../docs/agents.md#payments-x402-via-coinbase-cdp).
