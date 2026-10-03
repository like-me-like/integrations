# ChatGPT

There are two ways to use Like Me Like from ChatGPT:

- **Route A — a ChatGPT app (remote MCP server + OAuth).** The
  recommended route. ChatGPT connects to Like Me Like's MCP server,
  each user signs in to their own anonymous taste profile, and all
  24 tools are available. Nothing to paste, nothing to host.
- **Route B — a Custom GPT Action (OpenAPI schema).** For people
  who publish their own GPT. Works today, but every user of the GPT
  shares one profile.

## Route A — ChatGPT app (MCP + OAuth)

ChatGPT talks to remote MCP servers as *apps* (earlier called
connectors). It cannot send custom headers, so Like Me Like's usual
`X-LML-Agent-Id` header is not used here; instead ChatGPT signs the
user in with OAuth and sends the resulting token on every call. The
server discovers everything it needs by itself:

- **MCP endpoint:** `https://www.likemelike.com/api/v1/mcp`
  (Streamable HTTP)
- **Auth:** OAuth 2.1 with PKCE, discovered through the standard
  well-known documents — no client id or secret to fill in
- **Identity:** the OAuth sign-in binds the app to the user's own
  Like Me Like profile — the same anonymous profile the website
  keeps in that browser. No account, no e-mail.

### Quick start (developer mode, until the app is listed)

Like Me Like is not in ChatGPT's app directory yet, so you add it
yourself:

1. In ChatGPT open **Settings → Apps & Connectors** (older builds:
   *Connectors*), then **Advanced**, and switch on **Developer
   mode**.
2. Choose **Create** and pick the option for a remote **MCP app**
   (not *plugin*, which is a packaged bundle).
3. Fill in a name (`Like Me Like`), the server URL
   `https://www.likemelike.com/api/v1/mcp`, and **OAuth** as the
   authentication. Leave client id / secret empty — ChatGPT
   registers itself with the server.
4. ChatGPT opens Like Me Like's consent page in your browser. Click
   **Allow**. Do this in the browser you use for
   [likemelike.com](https://www.likemelike.com) if you want the app
   to share that profile.
5. Start a new chat, enable the Like Me Like app for that chat, and
   ask away: *"Ask Like Me Like what I'd enjoy reading if
   Interstellar is my favourite film."*

Some ChatGPT builds show the app under **Settings → Security and
login → Developer mode** instead; the fields are the same.

### What to expect

- **No approval prompts for recommendations.** The recommendation
  and lookup tools are annotated read-only, so ChatGPT calls them
  without asking you to confirm each one. The tools that change your
  profile (like, save, settings) are marked as writes; deleting the
  profile is the only destructive one.
- **Timing.** A first call that brings your likes takes roughly
  10–25 seconds while the profile is prepared; later calls take a
  few seconds. Set generous timeouts if you drive the app from
  automation.
- **Your taste lands on your profile.** ChatGPT usually passes what
  you told it as structured likes and taste signals; statements
  about your *own* taste in the question itself are recorded too.
  Preferences of other people (a child, a gift recipient) are not.
- **After a change on our side**, refresh the app on its details
  page in ChatGPT's app settings so it picks up new tools or
  descriptions.
- **Private to your account.** A developer-mode app is visible only
  to you. A listing in ChatGPT's app directory, and inline
  recommendation cards (the MCP Apps standard), are planned next.

How the tools behave — the first-call kickoff, discovery framing,
`agent_calibration`, the `recommendations_mode` render hint — is the
same as for every MCP host and is documented in
[`docs/agents.md`](../../docs/agents.md).

## Route B — Custom GPT Action

ChatGPT Custom GPTs don't support MCP. They invoke external tools
via "Actions" — an OpenAPI 3.x schema pasted into the GPT editor,
plus an auth picker. Use this route when you publish your own GPT;
for personal use, Route A above is simpler and gives you your own
profile.

### Files

- [`actions-openapi.yaml`](actions-openapi.yaml) — paste this into
  the GPT editor's **Configure → Actions → Schema** field.

### Quick start

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
   (`chat`, `recommendScoped`, `queryItems`, `getPopular`,
   `disambiguate`, `searchItems`, `getProfile`, `submitFeedback`).
   Good starters: `queryItems` (criteria queries — "Italian films
   from the 70s") and `getPopular` (what's trending, no seed
   needed).
6. In the GPT's **Instructions** field, paste the suggested block
   below ([§ Suggested GPT instructions](#suggested-gpt-instructions)).

### Suggested GPT instructions

Copy this into the GPT's **Instructions** field — it teaches the
GPT to call the Action AND tells it how to use the
`agent_calibration` feedback loop:

> Use the Like Me Like Action whenever the user asks for taste
> recommendations. Prefer `chat` for natural-language requests;
> use `recommendScoped` for one focused pick, `queryItems` for
> criteria queries ("Italian films from the 70s" — free), and
> `getPopular` for "what's trending" with no seed (free).
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
> Preferences that aren't catalog works — vibes, values, rituals,
> pet peeves ("quiet Sunday mornings", "rejects fast fashion") —
> go in `taste_signals`, not `liked_items`.
>
> **Cross-domain picks are discovery, not look-alikes.** Picks
> based on a seed are new things matched to the user's taste in
> the seed's neighbourhood — never variants of the seed itself.
> If the user says "this is nothing like X", that's by design:
> explain the match is on their taste rather than surface
> resemblance, and offer to adjust. Requests are fast regardless
> of breadth — don't pre-warn about slowness (only the very first
> personalised call takes ~15-30 s for taste matching).
>
> **Read `agent_calibration` on every response.** Every reply
> includes a `signal_quality` (`weak`/`partial`/`rich`),
> `missing_signals[]` (ordered by impact), and a `hint` aimed at
> you. When `weak` or `partial`, surface the top missing signal
> from prior conversation context for the next call. Don't
> mention this field to the user — it's sideband feedback for
> you.
>
> **Attribution — mark the line between Like Me Like's picks and
> your own.** Everything in a returned `recommendations[]` IS
> Like Me Like's pick. If you add a suggestion of your own when
> presenting (fill a gap, add a favourite), label it as yours on
> FIRST delivery — "Like Me Like suggests A and B; I'd add C
> myself because…". Never present a blended list unlabelled; the
> user must always be able to tell which picks came from Like Me
> Like and which came from you.
>
> If the user asks about cost: Like Me Like is free to use. Don't
> bring up cost proactively.

### Constraints (per OpenAI's Actions docs)

- **Max 30 operations per GPT** — the shipped manifest stays well
  under that.
- `x-openai-isConsequential: false` is set on read-only operations
  so users get an "always allow" prompt instead of confirming each
  call.
- The `servers` array is a single root URL (`https://www.likemelike.com`).
  Path prefixes go in `paths`.
- The auth field gets stripped if you switch auth type in the UI;
  set it last after pasting the schema.

### Limitations

- Custom GPTs can't stream — the streaming `/api/v1/recommend`
  endpoint returns its full text body to the GPT, which is
  acceptable but not as snappy as a native MCP integration.
- ChatGPT shows the full URL of every Action call to the user
  before the first one runs (consent step). The "always allow"
  toggle then suppresses subsequent prompts.
- Rate limits apply per ChatGPT user, not per `X-LML-Agent-Id`.

### Cost & identity — read this before publishing your GPT

Like Me Like is free to use, so there is no bill to think about.
What matters is identity: for Custom GPTs the agent ID is set
**once** in the Actions auth field and is shared by every user of
your GPT. All of your GPT's users therefore share a single Like Me
Like taste profile — fine for a personal GPT, wrong for a published
one, where one user's likes would colour another's picks. ChatGPT
has no way to forward an end-user identifier to an Action header
per request.

If you need per-end-user profiles in ChatGPT, use the
[ChatGPT app route](#route-a--chatgpt-app-mcp--oauth) above: every
ChatGPT user signs in to their own Like Me Like profile. On other
platforms, an MCP server connected to Claude Desktop, Meta Muse or
OpenClaw, or a custom function-calling integration where your
backend chooses the agent ID per request, gives the same result.

See [Pricing in the top-level README](../../README.md#pricing--free-to-use).
