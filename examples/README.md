# Worked examples

Language-agnostic recipes for hitting the Like Me Like REST API
directly. For platform-specific (MCP, custom GPT actions,
function calling) see [`../integrations/`](../integrations/).

| Folder | Language |
| --- | --- |
| [`curl/`](curl/) | Shell + curl |
| [`node/`](node/) | Node.js (≥ 18, native `fetch`) |
| [`python/`](python/) | Python 3.10+ with `requests` |

Every example uses a stable `X-LML-Agent-Id` of the form
`example-<rand>` — replace with your own per-end-user identifier in
production.

## Cost — free to use

Like Me Like is free to use, so running these examples costs
nothing. The examples generate a fresh random id by default, so each
run starts an empty taste profile. If you `export LML_AGENT_ID=foo`
and reuse it, the same id accumulates calls — useful for testing
cohort matching across calls (the second call onwards reuses the
warm cohort signal).

For a real integration, derive the id from your end-user's stable
identifier (`sha256(user_id)`) so each user gets their own taste
profile. See the top-level [README § Pricing](../README.md#pricing--free-to-use).
