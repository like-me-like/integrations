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
