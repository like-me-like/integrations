# Grok (xAI) — function calling

Grok's API at `api.x.ai` is OpenAI-compatible. Function calling
works with the same `tools` array shape used by OpenAI's Chat
Completions endpoint, so any OpenAI SDK works as long as you point
`baseURL` at `https://api.x.ai/v1`.

Grok doesn't support MCP natively. Like Gemini, the integration is
a function-calling shim — your code dispatches the actual HTTP call
to Like Me Like when Grok emits a tool call.

## Files

- [`tools.json`](tools.json) — function declarations to pass on
  Grok chat-completions requests.
- [`example.mjs`](example.mjs) — minimal Node loop using the OpenAI
  SDK pointed at xAI.

## How it works

1. Send a chat completion to Grok with `tools` set from `tools.json`
   plus the user's message.
2. Grok decides whether to call a function. If yes, it returns a
   `tool_calls` array on the message.
3. Your code dispatches the matching HTTP call to
   `https://likemelike.com/api/v1/...` with the `X-LML-Agent-Id`
   header.
4. Append a tool-result message and call Grok again. Grok composes
   the final natural-language reply.

## Why no native MCP

xAI's API is currently OpenAI-compatible at the chat-completions
level. There's no MCP server URL parameter equivalent. Until xAI
adds first-class MCP support, function-calling is the canonical
path.

## Environment

- `XAI_API_KEY` — your xAI API key
- `LML_AGENT_ID` — stable end-user identifier (8–256 ASCII chars)

## Cost & free tier

Like Me Like is a paid API. Each `X-LML-Agent-Id` gets **10 free
calls one-time**, then x402 USDC top-ups gate further calls.

Because your code dispatches the HTTP call (not Grok directly),
**you control the agent ID per request** — derive it from the
end-user's identifier (`sha256(user_id)`) so each user gets their
own free tier and clean billing. That's the right shape for any
multi-user app.

See [Payments in docs/agents.md](../../docs/agents.md#payments-x402-via-coinbase-cdp).
