# OpenClaw + ClawHub

[OpenClaw](https://docs.openclaw.ai) supports MCP servers natively
via Streamable-HTTP transport with header auth. Connecting Like Me
Like is a config-snippet, not a custom plugin.

## Files

- [`openclaw.config.json`](openclaw.config.json) — the MCP server
  block to merge into your OpenClaw config.
- [`SKILL.md`](SKILL.md) — optional ClawHub skill that nudges the
  agent toward Like Me Like for taste questions.
- [`clawmanifest.json`](clawmanifest.json) — capability declaration
  matching the skill (per OpenClaw 2026 spec).

## Quick start

1. Copy the `mcp.servers.like-me-like` block from
   [`openclaw.config.json`](openclaw.config.json) into your OpenClaw
   config.
2. Replace `replace-with-your-stable-id` with a stable end-user
   identifier (8–256 ASCII chars; reuse it across calls).
3. Restart OpenClaw. The Like Me Like tools should appear in the
   tool list.
4. (Optional) Drop the `SKILL.md` + `clawmanifest.json` into a
   ClawHub skill folder so the agent prefers Like Me Like for
   taste-recommendation patterns.

## Config snippet

```json
{
  "mcp": {
    "servers": {
      "like-me-like": {
        "url": "https://likemelike.com/api/v1/mcp",
        "transport": "streamable-http",
        "headers": {
          "X-LML-Agent-Id": "replace-with-your-stable-id"
        }
      }
    }
  }
}
```

## Tools exposed

Once connected, OpenClaw sees seven MCP tools:

| Tool | Use |
| --- | --- |
| `ask` | Natural-language one-shot — easiest entry point |
| `recommend_cross` | Multi-category recommendations from a seed |
| `recommend_scoped` | One pick in a single category |
| `disambiguate` | Resolve "Dune" → 1965 novel / 2021 film / etc. |
| `get_item` | Item detail by id |
| `search_items` | Title-prefix browse |
| `get_profile` | Public taste profile by slug |

## Using in a WhatsApp / Discord channel

OpenClaw wired into WhatsApp (or any messaging channel) is the
canonical use-case for Like Me Like. The agent translates inbound
messages into `ask` tool calls and renders the structured
`recommendations` array as the outbound reply.

When the host channel knows useful end-user signals (name from
contact, language from phone settings, country from phone code),
pass them through the `ask` tool's optional fields:

```json
{
  "name": "ask",
  "arguments": {
    "message": "Wat moet ik nu lezen?",
    "locale": "nl",
    "display_name": "Sam",
    "first_touch": {
      "country": "NL",
      "timezone": "Europe/Amsterdam",
      "device": "mobile",
      "referrer": "whatsapp"
    },
    "liked_items": [
      {"title":"Interstellar","category":"movie"},
      {"title":"Stoner","category":"book"}
    ]
  }
}
```

The first call with `liked_items` triggers cohort matching against
similar users (~10–30 s extra latency). Subsequent calls under the
same `X-LML-Agent-Id` skip the prep — cohort signal stays warm.

For WhatsApp specifically, derive the `X-LML-Agent-Id` from the
end-user's phone number — `sha256(phone_number)` works well — so
each end-user gets their own shadow profile that builds up across
conversations.

## Known issue

OpenClaw issue #66940 reports that older Streamable-HTTP clients
sometimes omit the `Accept: application/json, text/event-stream`
header. Like Me Like's `/api/v1/mcp` server tolerates a single
`Accept` value, so this shouldn't bite you, but flag it to the
OpenClaw team if you see odd 406 responses.
