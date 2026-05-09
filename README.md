# Like Me Like — integrations

Open-source recipes for connecting [Like Me Like](https://likemelike.com)
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

The base API is `https://likemelike.com/api/v1/`. All endpoints take an
`X-LML-Agent-Id` header carrying a stable third-party-supplied end-user
identifier (8–256 ASCII chars). First call from a new identifier gets
10 free calls; after that an x402 top-up is required (see
[`docs/agents.md`](docs/agents.md)).

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
over Streamable-HTTP, point it at `https://likemelike.com/api/v1/mcp`
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

Maintained by the [Like Me Like](https://likemelike.com) team.
