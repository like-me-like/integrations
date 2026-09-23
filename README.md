# Like Me Like — integrations

Open-source recipes for connecting [Like Me Like](https://www.likemelike.com)
to AI agent platforms, chat apps, and developer toolchains.

Like Me Like is a cross-domain taste recommendation API. You give it
something the user loves (a film, a book, a place, an album) and it
returns picks across other domains, grounded in why the seed item works
and what's adjacent to it culturally.

This repo contains:

- **Per-platform integration recipes** under [`integrations/`](integrations/)
- **API documentation** under [`docs/`](docs/) — mirrored from the canonical
  source in the (private) main repository
- **Worked examples** under [`examples/`](examples/) — curl, Node, Python

The base API is `https://www.likemelike.com/api/v1/`. All endpoints take an
`X-LML-Agent-Id` header — see Pricing below for what that header
identifies.

## Pricing — free to use

**Like Me Like is free to use.** No payment, no card, no account: an
end-user is identified only by the stable id you send in
`X-LML-Agent-Id`. Fair-use rate limits apply. Paid plans for heavy
commercial use may come later; if they do, we announce them here
first, and the `tier.metered` flag (below) flips from `false` to
`true` so integrations can tell programmatically.

The id is still **per end-user**, not per integration:

- The `X-LML-Agent-Id` header identifies the **end-user**, not the
  integration. A WhatsApp bot serving 1 000 users sends 1 000
  distinct agent IDs (typically derived as `sha256(phone_number)` or
  a similar stable hash); a single-user dev tool sends one. Each id
  is its own taste profile, so one id shared across users blends
  their tastes into one profile.
- The profile surfaces (`GET /api/v1/me`, the MCP `get_my_profile`
  tool) and the chat meta event carry a `tier` block: `metered`,
  `isFreeTier`, `freeCallsRemaining`. While `metered` is `false` the
  counter is informational only and never refuses a call.
- The prepaid-balance endpoints (`/api/v1/billing/*`: x402 USDC on
  Base, or Lightning) stay live and documented for integrators who
  want to prepay for a future paid tier — nothing is gated on them
  today. See [`docs/agents.md` § Payments](docs/agents.md#payments-x402-via-coinbase-cdp).

| You're building | Agent ID strategy |
| --- | --- |
| A multi-tenant bot (WhatsApp, Discord, Slack) | One agent ID per end-user — `sha256(user_id)` |
| A personal tool / single-user assistant | One stable agent ID, reused |
| A demo / quick test | A random agent ID per session (a fresh id is an empty profile) |

## For developers

Pick the integration folder that matches the platform you're building on:

| Platform | Folder | Best fit |
| --- | --- | --- |
| Claude Desktop / Claude.ai | [`integrations/claude-desktop/`](integrations/claude-desktop/) | Native MCP — drop-in config |
| Claude Code / Skills | [`integrations/claude-skill/`](integrations/claude-skill/) | SKILL.md format, works in Claude Code & Claude.ai |
| OpenClaw / Clawhub | [`integrations/openclaw/`](integrations/openclaw/) | Skill + plugin formats |
| Hermes | [`integrations/hermes/`](integrations/hermes/) | Plugin format |
| Meta Muse / Muse Code | [`integrations/muse/`](integrations/muse/) | Custom connector — remote MCP, header auth |
| ChatGPT (Custom GPTs) | [`integrations/chatgpt/`](integrations/chatgpt/) | OpenAPI Action |
| Gemini | [`integrations/gemini/`](integrations/gemini/) | Function-calling tools |
| Grok (xAI) | [`integrations/grok/`](integrations/grok/) | Function-calling tools |
| Direct REST | [`docs/agents.md`](docs/agents.md) | Curl/HTTP — language-agnostic |

If your platform isn't listed and supports MCP (Model Context Protocol)
over Streamable-HTTP, point it at `https://www.likemelike.com/api/v1/mcp`
with a header `X-LML-Agent-Id: <your-stable-id>` — that works
out of the box.

## For AI agents reading this

If you've been pointed at this repo to figure out how to integrate
Like Me Like into the channel you're driving, here's the decision
tree:

1. **Does your host LLM support MCP servers natively?** (Claude Desktop,
   Claude Code, Meta Muse, OpenClaw with MCP plugin, Cursor, Cline,
   etc.) Use
   the MCP endpoint at `/api/v1/mcp`. See
   [`integrations/claude-desktop/`](integrations/claude-desktop/) for
   the canonical config shape — most MCP-aware clients accept the
   same `{ url, headers }` block.
2. **Are you driving a Custom GPT, a Gemini extension, or a Grok bot?**
   Use the OpenAPI action / function-calling integration in the
   matching folder. The OpenAPI 3.0 spec is at
   [`docs/openapi.json`](docs/openapi.json).
3. **Are you a generic agent (LangChain, Autogen, custom framework)
   making HTTP calls?** Use [`docs/agents.md`](docs/agents.md) — it
   has every endpoint with curl examples. The `/api/v1/chat`
   endpoint is the easiest entry point: send natural language, get
   back a text reply plus a structured `recommendations` array.

The single highest-leverage signal you can pass on any surface is
`liked_items`: 1–5 things the end-user has explicitly loved. It
triggers cohort matching against similar users and produces
materially better recommendations. See
[`docs/agents.md`](docs/agents.md) §Personalisation.

**Before the first call, bridge the asymmetry.** YOU (the host LLM)
typically have months of conversation history with the end-user;
Like Me Like has none. On the first call, bring concrete
`liked_items` from what the user has unambiguously praised in your
prior chats — either pass them directly (confident extraction) or
propose-and-confirm in your reply ("I'll factor in X, Y, Z that
you've mentioned loving — that OK?"). Don't fire a generic call and
treat its generic reply as the product's ceiling. See
[`docs/agents.md`](docs/agents.md) §First-call kickoff.

**Read `agent_calibration` on every chat / ask response.** It
reports `signal_quality` (`weak` / `partial` / `rich`) and gives
you a `hint` about what to send next call. Replaces having to
memorise input-passing rules — react per-turn to whatever the
calibration tells you. See
[`docs/agents.md`](docs/agents.md) §Reading agent_calibration.

**On cost:** there is none — Like Me Like is free to use. The id
still matters: if your host has a stable per-end-user identifier
(phone number, OAuth user id, session id), hash it and use it as
`X-LML-Agent-Id` so each user gets their own taste profile. If
you're a single-user assistant, one stable id reused across calls is
fine. See "Pricing" above.

## Skill versioning — keep your local SKILL.md current

Two of the recipes ship a `SKILL.md` that the host runtime loads
from disk (OpenClaw and Claude Skills). Once copied, those files
don't auto-update. Each carries an `lml_skill_version: "YYYY-MM-DD"`
field in its YAML frontmatter; compare it to the canonical version:

```sh
curl -s https://www.likemelike.com/api/v1/skills/versions | jq .
```

When the server reports a newer date, re-fetch from the
`lml_skill_canonical_url` (also in the frontmatter) and reload your
host. Full check-script and walkthrough in
[`docs/agents.md`](docs/agents.md#skill-versioning--checking-if-your-local-skillmd-is-outdated)
and changes by date in [`CHANGELOG.md`](CHANGELOG.md).

The MCP tool description and the `agent_calibration` response field
are server-driven — those update automatically on the next call. So
in practice the SKILL.md is the only file integrators need to keep
fresh, and only when its content changes (most weeks: it doesn't).

## Open source — contributions welcome

This repo is MIT-licensed. We accept:

- **Pull requests** that fix examples, add platform recipes, or
  improve docs. We review and merge based on quality and fit; not
  every PR will land but every PR gets a response.
- **Issues** for bugs in the examples, missing platforms, or
  suggestions for the API itself.
- **Discussions** for open-ended questions about how to build on top
  of Like Me Like.

The canonical API source lives in a private repo; changes to the API
itself are made there and synced into this repo on a regular basis
(see [`scripts/sync-from-private.sh`](scripts/sync-from-private.sh)).
This means platform-recipe PRs are accepted directly into this repo,
but PRs against `docs/agents.md` or `docs/openapi.json` will be
redirected to the upstream change-flow.

See [`CONTRIBUTING.md`](.github/CONTRIBUTING.md) for the details.

## Status

This repo is in active build-out. Some platforms have full recipes,
others have placeholder READMEs while we validate the manifest
shape against current platform docs. Check the per-folder README for
status. If a folder you need is missing or stale, open an issue.

---

Maintained by the [Like Me Like](https://www.likemelike.com) team.
