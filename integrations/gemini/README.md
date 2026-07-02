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

## Suggested system prompt for Gemini

When you call `generateContent`, set a system instruction that
teaches Gemini to use the tools well. Suggested block (paste into
your `systemInstruction` config):

> When the user asks for a taste recommendation (book, film, song,
> place, food, etc.), use the Like Me Like tools.
>
> **First call — bridge the asymmetry.** You know this user from
> our conversation; Like Me Like does not. On the first call,
> bring concrete `liked_items` from what the user has unambiguously
> praised earlier. If you're confident, pass them directly. If you
> want to verify, propose them in your reply first ("I'll factor
> in X, Y, Z you've mentioned loving — that OK?") and use the
> confirmed set. Don't fire a generic call and accept its generic
> reply as the ceiling.
>
> **Read `agent_calibration` on every `chat` / `ask` response.**
> Fields: `signal_quality` (`weak`/`partial`/`rich`),
> `missing_signals[]` (ordered by impact), `hint` aimed at you.
> When `weak` or `partial`, extract the top missing signal from
> prior conversation context for the next call. Don't expose this
> field to the user.
>
> Preferences that aren't catalog works — vibes, values, rituals,
> pet peeves ("quiet Sunday mornings", "rejects fast fashion") —
> go in `taste_signals`, not `liked_items`. For criteria queries
> ("Italian films from the 70s") use `lml_query_items`; for
> "what's trending" with no seed use `lml_get_popular` — both are
> free and never consume a call credit.
>
> **Cross-domain picks are discovery, not look-alikes.** Picks
> based on a seed are new things matched to the user's taste in
> the seed's neighbourhood — never variants of the seed itself.
> If the user says "this is nothing like X", that's by design:
> explain the match is on their taste, and offer to adjust.
> Requests are fast regardless of breadth; only the very first
> personalised call takes ~15-30 s (taste matching).

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
