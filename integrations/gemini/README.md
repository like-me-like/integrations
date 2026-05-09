# Gemini — function calling

Gemini doesn't support MCP natively as of mid-2026. The clean
integration path is **function calling** through the Gemini API or
Vertex AI: declare the Like Me Like endpoints as tools, your client
code dispatches the actual HTTP call when Gemini emits a function
call.

## Files

- [`tools.json`](tools.json) — function declarations to pass in
  the `tools` array on `generateContent` requests.
- [`example.py`](example.py) — minimal Python loop that wires
  Gemini ↔ Like Me Like.
- [`example.mjs`](example.mjs) — same in Node, using
  `@google/genai`.

## How it works

1. Your code sends a `generateContent` request to Gemini with the
   user's prompt + the function declarations from `tools.json`.
2. Gemini decides whether to call a function. If yes, it returns a
   `functionCall` part with `name` and `args`.
3. Your code dispatches the corresponding HTTP request to
   `https://www.likemelike.com/api/v1/...` with the `X-LML-Agent-Id`
   header.
4. Pass the response back to Gemini as a `functionResponse` part.
   Gemini then composes the final natural-language reply.

## Why no native MCP

Google's Gemini API doesn't currently accept MCP server URLs as a
direct tool source. There's a
[feature request](https://github.com/google-gemini/gemini-api/issues)
from the community but no shipped support. Until that lands, the
function-calling shim is the canonical path.

If you're driving Gemini through Vertex AI, the same pattern applies
— the function declaration shape is identical.

## Gems (Gemini's "Custom Assistants")

Gems are Gemini's no-code custom assistants — you set
instructions and personality, but they have no tool/function
calling. They're unsuitable for Like Me Like beyond a "tell the
user to visit likemelike.com" persona. We don't ship a Gem
manifest in this repo.

## Cost & free tier

Like Me Like is a paid API. Each `X-LML-Agent-Id` gets **10 free
calls one-time**, then x402 USDC top-ups gate further calls.

Because your code dispatches the HTTP call (not Gemini directly),
**you control the agent ID per request** — derive it from the
end-user's identifier (`sha256(user_id)`) so each user gets their
own free tier and clean billing. That's the right shape for any
multi-user app.

See [Payments in docs/agents.md](../../docs/agents.md#payments-x402-via-coinbase-cdp).
