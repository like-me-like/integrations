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
`X-LML-Agent-Id` header — see Pricing below for what that header means
for cost.

## Pricing — paid API with per-end-user free tier

**Like Me Like is a paid API.** You pay per call once the free tier is
exhausted; payments settle on a public crypto network — no account
required, no card on file. Two payment rails are supported, both
non-custodial:

- **[x402](https://www.x402.org)** — USDC on Base. Stable USD pricing,
  EVM-wallet sign flow. Works with EOA wallets (MetaMask, Rainbow,
  Trust, Coinbase Wallet legacy, programmatic agents using
  `privateKeyToAccount`). Smart Wallets (Coinbase Smart Wallet /
  Base Wallet, ERC-4337) are temporarily blocked by an upstream
  CDP facilitator bug — see the wallet-compatibility table in
  [`docs/agents.md`](docs/agents.md#hosted-payment-page-pattern-c-lite).
- **[L402](https://docs.lightning.engineering/the-lightning-network/l402)
  / Lightning** — BOLT11 invoices, sub-second settle, scan-and-go
  wallet UX. Better consumer-facing flow if your end-users hold
  Bitcoin / Lightning wallets (Phoenix, Wallet of Satoshi, Zeus,
  Strike, Cash App, Alby, etc.). Works with every wallet type
  including Smart Wallets.

The free tier and the billing key are **per end-user**, not per
integration:

- The `X-LML-Agent-Id` header identifies the **end-user**, not the
  integration. A WhatsApp bot serving 1 000 users sends 1 000
  distinct agent IDs (typically derived as `sha256(phone_number)` or
  similar stable hash). A single-user dev tool sends one.
- **Each agent ID gets 10 free calls** (one-time, no monthly reset)
  before payment is required.
- **After that, calls deduct from the agent's balance** — top up via
  either rail. The agent's balance is shared across rails: you can
  top up with USDC once and lightning later, or vice versa.

That economic shape is important for how you wire up the integration:

| You're building | Agent ID strategy | Cost note |
| --- | --- | --- |
| A multi-tenant bot (WhatsApp, Discord, Slack) | One agent ID per end-user — `sha256(user_id)` | Each user gets their own free tier; you decide whether to top them up or pass the cost through |
| A personal tool / single-user assistant | One stable agent ID, reused | 10 free calls then top up your own balance |
| A demo / quick test | A random agent ID per session | Each session burns one of the 10-call budget; reuse the same id while testing |

See [`docs/agents.md` § Payments](docs/agents.md#payments-x402-via-coinbase-cdp)
for the full top-up flow (both x402 and Lightning), and the
per-platform README for the header-config snippet.

## For developers

Pick the integration folder that matches the platform you're building on:

| Platform | Folder | Best fit |
| --- | --- | --- |
| Claude Desktop / Claude.ai | [`integrations/claude-desktop/`](integrations/claude-desktop/) | Native MCP — drop-in config |
| Claude Code / Skills | [`integrations/claude-skill/`](integrations/claude-skill/) | SKILL.md format, works in Claude Code & Claude.ai |
| OpenClaw / Clawhub | [`integrations/openclaw/`](integrations/openclaw/) | Skill + plugin formats |
| Hermes | [`integrations/hermes/`](integrations/hermes/) | Plugin format |
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
   Claude Code, OpenClaw with MCP plugin, Cursor, Cline, etc.) Use
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

**On cost:** every call you make decrements either the end-user's
10-call free tier or the agent's USDC balance. If your host has a
stable per-end-user identifier (phone number, OAuth user id,
session id), hash it and use it as `X-LML-Agent-Id` so each user
gets their own free tier and a clean billing identity. If you're a
single-user assistant, one stable id reused across calls is fine.
See "Pricing" above.

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
