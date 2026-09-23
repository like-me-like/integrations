# Meta Muse

[Muse](https://muse.ai) is Meta's personal AI agent (app, web and
WhatsApp). It speaks MCP, and it lets you build a **custom
connector** to any remote MCP server by asking for one in the chat.
Like Me Like isn't in Muse's built-in connector list yet, so you add
it that way: one message, one credential prompt, no code.

Muse runs its connectors from a cloud VM, so the service has to be
reachable on the public internet. Like Me Like's MCP endpoint is:

- **URL:** `https://www.likemelike.com/api/v1/mcp`
- **Transport:** Streamable HTTP (remote MCP server)
- **Auth:** one header, `X-LML-Agent-Id: <your-stable-id>`

When Muse asks whether the server is reachable at a URL or runs
over stdio, and whether it "needs any auth, such as an API key or a
header" — the answers are: a URL, and a header. No OAuth round
trip, no browser session.

## Files

Nothing to download. The whole integration is the prompt below plus
the id you choose. For [Muse Code](#muse-code-the-cli-coding-agent)
there is a `settings.json` snippet further down.

## Quick start

1. **Pick a stable id.** Any 8–256 printable ASCII characters
   without spaces, for example `muse-jane-4f9c2a7e1b`. This id *is*
   your Like Me Like identity: your taste profile is keyed to it. Keep it somewhere safe and reuse it —
   a new id starts an empty profile.
2. **Send Muse the prompt** from the next section.
3. **Answer the credential prompt.** Muse asks for the header value
   through a separate, secure prompt (its Secure Credentials Store),
   not in the chat. Paste your id there. Muse keeps it outside the
   agent runtime and swaps it into requests at the network edge, so
   later sessions reuse it without you re-entering it.
4. **Let Muse test and save.** It connects, lists the tools, runs
   the two test calls named in the prompt, and saves the
   connector as a reusable skill.
5. **(Optional) Set an approval policy** for the connector in
   Settings. See [Permissions](#permissions) below.

## The prompt

Copy this into Muse as-is (or adapt the "I want you to be able to"
line to your taste):

> Build a custom integration to Like Me Like, a cross-domain taste
> recommendation service. Its MCP server is at
> https://www.likemelike.com/api/v1/mcp — a remote MCP server over
> streamable HTTP. It needs one auth header, `X-LML-Agent-Id`; I'll
> give you the value through the secure credential prompt. I want
> you to be able to recommend films, series, books, music, podcasts,
> games, places, restaurants and food based on what I love, from any
> future conversation. Connect to it, list its tools, test the
> connection with `get_popular` and `query_items`, show me the
> results and save the integration as a reusable skill.

Why name `get_popular` and `query_items` as the smoke test: they are
fast (a few seconds) and need no personal input, so Muse can confirm
the connection before you tell it anything about your taste.

## What you can ask once it's connected

- "What's popular on Like Me Like right now?" (fast)
- "Italian films from the 70s" / "Podcasts about deep-sea life"
  (fast — a `query_items` criteria query)
- "Based on Interstellar, what's a great book to read next?"
- "I love Stoner, Past Lives and Joni Mitchell. Recommend a
  restaurant in Amsterdam."
- "My friend's birthday is next week — she's into 90s indie films.
  Suggest a gift book." (gift mode)
- "Can I watch something like Past Lives on Netflix in the UK?"
  (a `query_items` call with an availability filter and an anchor)

Start with the fast questions to confirm the connection,
then ask for something personal. On that first personal request,
tell Muse two to five things you genuinely love (and a couple you
don't). Muse's model passes them as `liked_items` / `disliked_items`
— Like Me Like does not mine preferences from free text, and those
anchors are what turns a generic answer into a taste-matched one.

## Tools exposed

Same tool set as every other MCP integration: `ask` (one-shot
natural language, our brain orchestrates) plus the atomic tools —
`recommend_cross`, `recommend_scoped`, `recommend_more`,
`query_items`, `get_popular`, `disambiguate`, `get_item`,
`search_items`, `get_profile`, the save/recall tools (`save_item`,
`list_saved_items`, `remove_saved_item`, `list_my_likes`), the
account tools and `submit_feedback`. The manifest is served live by
the server, so new tools appear automatically. Argument shapes are
in the [OpenAPI spec](../../docs/openapi.json) and
[`docs/agents.md`](../../docs/agents.md).

Muse's model reads the tool descriptions when it connects, and the
`ask` description already carries the operating instructions: the
[first-call kickoff](../../docs/agents.md#first-call-kickoff--bridge-the-asymmetry)
(bring `liked_items` from what it knows about you), how to read the
[`agent_calibration`](../../docs/agents.md#reading-agent_calibration-on-every-response)
block on every reply, and the
[attribution rule](../../docs/agents.md#attribution--mark-the-line-between-lml-picks-and-your-own)
(label its own additions separately from Like Me Like's picks). No
extra instructions to paste.

Two behaviours worth knowing so they don't read as bugs:

- **Cross-domain picks are discovery, not look-alikes.** Ask for a
  book based on a film and you get books matched to the taste the
  film signals, not "books like that film".
- **`recommend_cross` serves at most three categories per call**,
  most relevant first. Ask again for more.

## Cost — free to use

Like Me Like is free to use: no payment, no card, no account. Each
Muse user brings their own id and gets their own taste profile;
nothing is shared between users. Fair-use rate limits apply.

If you ask Muse to call `get_my_profile`, its `tier` block shows
`metered: false`; the `freeCallsRemaining` counter next to it is a
legacy of an earlier credit system and never refuses a call.
Separately, Muse's own usage meter counts the work its connectors
do, the same as anything else Muse does.

## Latency and timeouts

Muse doesn't document a per-tool timeout for custom connectors, so
plan for the slow call rather than around it:

- The smoke-test tools are quick: `get_popular` and `query_items`
  usually answer in 5–10 s.
- **The first personalised call is slow.** The first `ask` (or
  `recommend_*`) with `liked_items` triggers cohort matching. In our
  runs against production on 2026-09-19 that first `ask` took about
  40–55 s wall-clock; the next `ask` on the same id took 25–30 s.
  Later calls stay in that range or faster, broad or narrow.
- If Muse reports that the first personalised call timed out, ask
  it to retry once. The taste-profile work from the first attempt is
  normally kept on the server, so the retry does not start from
  zero.
- Keep the first personal request simple (one question, a handful
  of anchors). Muse's model handles the rest.

## Permissions

Muse asks for approval before connectors take significant actions
and lets you configure a connector as read-only. Two things to know
before you tighten it:

- Building your taste profile *is* a write: liking something, saving
  a pick for later, and the anchors Muse passes on a personalised
  call all land on your Like Me Like profile. A fully read-only
  connector still works for `get_popular` and `query_items` but
  won't learn your taste.
- The manifest includes account tools, among them
  `delete_my_account` (wipes the profile behind your id, end to
  end). Leave Muse's default approval policy on for the connector so
  nothing like that runs without you confirming it.

Meta's own note on custom connectors applies: *"Meta does not review
custom connectors or how they use your data, so be careful when
granting access and review the provider's privacy policy."* Like Me
Like sees only your id (stored hashed) and what Muse sends on each
call — the request, the anchors, the taste signals — never your Meta
account. Privacy policy:
[likemelike.com/privacy](https://www.likemelike.com/privacy).

## Fallback: build the connector from the OpenAPI document

If Muse's MCP path misbehaves in your build, point it at the REST
API instead. Muse can write a connector from an API spec:

> Build a custom integration to Like Me Like from its OpenAPI
> document at https://www.likemelike.com/api/v1/openapi. Every
> request needs the header `X-LML-Agent-Id`; I'll give you the value
> through the secure credential prompt. Use the `chat` endpoint for
> natural-language recommendation questions, the item `query`
> endpoint for criteria queries and the `popular` endpoint for
> what's trending. Connect, test with the `query` and `popular`
> endpoints, show me the results and save the integration as a
> reusable skill.

Same id, same profile — the REST and MCP surfaces
share everything. What you lose versus MCP is only convenience:
Muse's model has to orchestrate the endpoints itself instead of
reading the live tool manifest.

## Muse Code (the CLI coding agent)

[Muse Code](https://dev.meta.ai/docs/muse-code/) is Meta's separate
terminal coding agent. It reads MCP servers from
`~/.config/muse/settings.json` and supports remote servers over
streamable HTTP with custom headers directly — no connector
conversation needed. Merge this into the file (the
`schema_version` key is required by Muse Code):

```json
{
  "schema_version": 1,
  "mcp_servers": {
    "like-me-like": {
      "transport": "streamable_http",
      "url": "https://www.likemelike.com/api/v1/mcp",
      "headers": {
        "X-LML-Agent-Id": "replace-with-your-stable-id"
      }
    }
  }
}
```

Restart Muse Code and run `/mcp` in a session to see the connected
servers and their tools. Header auth means no `muse mcp login` step
is needed. Muse Code's docs note that MCP servers run outside its
sandbox — for a remote server that only means a network connection
to `likemelike.com`.

## Availability and status of this recipe

Muse launched in the US first, with an account-level gate, so this
recipe may not be usable everywhere yet. It was written from Meta's
connector documentation and independent walkthroughs of the custom
connector flow, and every server-side claim (tool manifest, free
tier metering, latency) was verified against Like Me Like's
production MCP server on 2026-09-19. We have not yet run the flow
inside Muse ourselves. If Muse asks something this page doesn't
cover, or a step differs, please
[open an issue](https://github.com/like-me-like/integrations/issues)
— it helps the next person.

## Troubleshooting

- **401** — the `X-LML-Agent-Id` header is missing or malformed
  (needs 8–256 printable ASCII characters, no spaces). Re-enter the
  id in the credential prompt.
- **Muse can't see the tools** — ask it to re-list them
  (the manifest is live). A `GET` on the
  URL answers `405` by design; the server only speaks JSON-RPC over
  `POST`.
- **First personalised answer never arrives** — see Latency above;
  retry once.
