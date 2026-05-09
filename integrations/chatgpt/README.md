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
6. In the GPT's **Instructions** field, add a hint like:
   > Use the Like Me Like Action whenever the user asks for taste
   > recommendations. Prefer `chat` for natural-language
   > requests; use `recommend` or `recommendScoped` when you want
   > structured control.

## Constraints (per OpenAI's Actions docs)

- **Max 30 operations per GPT** — the shipped manifest stays well
  under that.
- `x-openai-isConsequential: false` is set on read-only operations
  so users get an "always allow" prompt instead of confirming each
  call.
- The `servers` array is a single root URL (`https://likemelike.com`).
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
