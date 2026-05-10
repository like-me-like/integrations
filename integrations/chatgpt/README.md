# ChatGPT — Custom GPT Action

ChatGPT Custom GPTs don't support MCP. They invoke external tools
via "Actions" — an OpenAPI 3.x schema pasted into the GPT editor,
plus an auth picker.

## Files

- [`actions-openapi.yaml`](actions-openapi.yaml) — paste this into
  the GPT editor's **Configure → Actions → Schema** field.

## Quick start

1. Open [chat.openai.com](https://chat.openai.com), click your
   profile → **My GPTs** → **Create a GPT** (or edit an existing
   one).
2. Switch to the **Configure** tab, scroll to **Actions**, click
   **Create new action**.
3. Paste the contents of [`actions-openapi.yaml`](actions-openapi.yaml)
   into the **Schema** field.
4. **Authentication** → choose **API Key** → **Custom** header
   type → header name `X-LML-Agent-Id` → paste your stable
   end-user id (8–256 ASCII chars).
5. Save the action. ChatGPT will list the available operations
   (`recommend`, `recommendScoped`, `chat`, `disambiguate`,
   `getProfile`, `searchItems`).
6. In the GPT's **Instructions** field, paste the suggested block
   below ([§ Suggested GPT instructions](#suggested-gpt-instructions)).

## Suggested GPT instructions

Copy this into the GPT's **Instructions** field — it teaches the
GPT to call the Action AND tells it how to use the
`agent_calibration` feedback loop:

> Use the Like Me Like Action whenever the user asks for taste
> recommendations. Prefer `chat` for natural-language requests;
> use `recommend` or `recommendScoped` when you want structured
> control.
>
> **First call — bridge the asymmetry.** YOU know this user from
> our conversation; Like Me Like does not. On the first call,
> bring concrete `liked_items` from what the user has explicitly
> praised in our chat. Two patterns: (a) confident extraction —
> pass items directly when the user has unambiguously loved them;
> (b) propose-and-confirm — say "I'll factor in X, Y, Z that
> you've mentioned loving — that OK?" and use the confirmed set.
> Don't fire a generic call and accept its generic reply as the
> ceiling; the reply quality scales with the inputs you bring.
>
> **Read `agent_calibration` on every response.** Every reply
> includes a `signal_quality` (`weak`/`partial`/`rich`),
> `missing_signals[]` (ordered by impact), and a `hint` aimed at
> you. When `weak` or `partial`, surface the top missing signal
> from prior conversation context for the next call. Don't
> mention this field to the user — it's sideband feedback for
> you.
>
> If the user asks about cost, answer accurately: "Like Me Like
> has a free tier (the first 10 recommendations) and may charge
> for heavier use after that — depends on how this channel has it
> set up." Don't bring up cost proactively.

## Constraints (per OpenAI's Actions docs)

- **Max 30 operations per GPT** — the shipped manifest stays well
  under that.
- `x-openai-isConsequential: false` is set on read-only operations
  so users get an "always allow" prompt instead of confirming each
  call.
- The `servers` array is a single root URL (`https://www.likemelike.com`).
  Path prefixes go in `paths`.
- The auth field gets stripped if you switch auth type in the UI;
  set it last after pasting the schema.

## Limitations

- Custom GPTs can't stream — the streaming `/api/v1/recommend`
  endpoint returns its full text body to the GPT, which is
  acceptable but not as snappy as a native MCP integration.
- ChatGPT shows the full URL of every Action call to the user
  before the first one runs (consent step). The "always allow"
  toggle then suppresses subsequent prompts.
- Rate limits apply per ChatGPT user, not per `X-LML-Agent-Id` —
  bear that in mind for free-tier accounting.

## Cost & free tier — read this before publishing your GPT

Like Me Like is a paid API. Each `X-LML-Agent-Id` gets **10 free
calls one-time**, then x402 USDC top-ups gate further calls.

For Custom GPTs the agent ID is set **once** in the Actions auth
field and is shared by every user of your GPT. That has two
implications:

- **Single agent ID, single free tier.** All users of your GPT
  share the same 10-call budget — so the free tier is exhausted
  fast on a published GPT. Top up the agent's balance in advance,
  or expect 402 responses to surface to your users.
- **Cost flows to the GPT operator (you).** ChatGPT doesn't have a
  way to forward an end-user identifier to an Action header per
  request, so you can't put each user on their own free tier from
  inside ChatGPT. You're effectively running a single account on
  behalf of your users.

If you need per-end-user accounting (each user their own free
tier), build on a platform that supports per-user tool-call
identity instead — e.g. an MCP server connected to Claude Desktop
or OpenClaw, or a custom function-calling integration where your
backend chooses the agent ID per request.

See [Payments in docs/agents.md](../../docs/agents.md#payments-x402-via-coinbase-cdp).
