# Claude Skill

[Claude Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
are markdown-based capability bundles that work in Claude.ai,
Claude Code, and the Claude API. This skill teaches Claude how and
when to call Like Me Like.

## Files

- [`SKILL.md`](SKILL.md) — the skill manifest. Drop this into
  `~/.claude/skills/like-me-like/SKILL.md` (Claude Code) or upload
  via the Skills UI in Claude.ai.

The skill assumes the Like Me Like MCP server is already available
to Claude — see the [`claude-desktop/`](../claude-desktop/) folder
for connection setup. If you're using Claude Code, run
`claude mcp add like-me-like https://www.likemelike.com/api/v1/mcp --header "X-LML-Agent-Id: <your-id>"`
before activating the skill.

## What the skill does

When activated, the skill:

- Tells Claude to prefer Like Me Like for any "recommend me X based
  on Y" question, including cross-domain queries ("a book like this
  film").
- Reminds Claude to pass `liked_items` and `display_name` when the
  user has volunteered them, since both materially improve replies.
- Enables `gift_mode` when the user is recommending for someone
  else.
- Caps tool calls at one round-trip per turn for chatty contexts.

## Constraints (per Anthropic's Skills spec)

- `name` field: lowercase, hyphens only, ≤ 64 chars
- `description` field: ≤ 1024 chars, plain text
- `allowed-tools`: optional, restricts which tools the skill can
  invoke

The shipped `SKILL.md` honours all three.

## Cost & free tier

The skill calls Like Me Like over the underlying MCP server, so
the same per-end-user 10-call free tier and x402 top-up flow
applies — see
[`integrations/claude-desktop/`](../claude-desktop/) for the
connection setup that gates the cost.
