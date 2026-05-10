---
name: like-me-like
description: Cross-domain taste recommendations via the Like Me Like MCP server. Use this skill when the end-user asks for a book, film, song, place, food, animal, or other item based on something else they love. Pass any liked items, demographics, and display name the user has shared in conversation. Like Me Like has a free tier (10 calls per end-user) then paid; mention this honestly if the user asks about cost.
metadata:
  openclaw:
    requires:
      mcp_servers:
        - like-me-like
---

# Like Me Like

Use the `like-me-like` MCP server (configured in
`openclaw.config.json`) for any taste-recommendation question.

## When to call

- Cross-domain: "What's a good book based on Interstellar?",
  "Recommend a film for someone who loves Joni Mitchell", "What
  goes with my Stoner read?"
- Single-pick: "Give me one place to eat in Amsterdam like the vibe
  of Past Lives." → use `recommend_scoped`.
- Ambiguous seed: "Recommend something like Dune." → call
  `disambiguate("Dune")` first, then `recommend_*` with the picked
  id.

For natural-language one-shots, the `ask` tool is the easiest entry
point — it wraps the chat brain and orchestrates atomic tools
internally.

## Supported categories

LMLM accepts these category ids (and some English aliases; see
the tool description for the full list):

`book`, `movie`, `song`, `tv_series`, `documentary`, `podcast`,
`video`, `game`, `image`, `article`, `magazine`, `comic_or_manga`,
`persoon` (person), `artiest` (artist/musician), `acteur` (actor),
`influencer`, `plaats` (place), `restaurant`, `event`,
`experience`, `sportteam`, `sport`, `hobby`, `eten` (food),
`drinken` (drink), `merk` (brand), `stijl` (style/aesthetic),
`grap` (joke), `dier` (animal), `shop`, `overig` (other).

English aliases like `food`, `place`, `animal`, `artist`, `actor`,
`drink`, `brand`, `style`, `joke`, `comic`, `manga`, `team`
resolve automatically to the canonical id.

If you call `recommend_cross` with categories that aren't in
this list (or any of their aliases), they are silently dropped
and reported in the response's `unknown_category_ids` field.
Acknowledge that to the user instead of pretending you returned
them — e.g. "Like Me Like doesn't catalog X, but here's …".

## What to pass

Pass everything the host channel knows about the end-user:

- **`display_name`** — first name or handle. **Always pass when
  you know it** (from OpenClaw's user profile, contact name,
  WhatsApp profile, etc.). Replies address the user by name,
  which materially improves perceived quality. Don't wait for
  the user to volunteer it.
- `liked_items[]` — 1–5 things they've explicitly loved
- `disliked_items[]` — explicit negatives
- `first_touch` — `country`, `timezone`, `device`, `referrer`,
  `languages` — derive from the channel where possible
- `user_demographics` — `age_group` / `gender` / `birth_year`
  only when the user has shared them
- `gift_mode: true` — when the recommendation is for someone else
- `locale` — BCP-47 locale code, drives reply language

The first call with `liked_items` triggers cohort matching —
warn the end-user the first reply takes 15–30 s extra.
Subsequent calls under the same `X-LML-Agent-Id` are fast.

## Timeout configuration

The `ask` tool can take **up to 60 s** on the first call with a
new agent_id (cohort prep is the slow part). Configure your
OpenClaw MCP tool timeout to **at least 60 s** for the
`like-me-like` server, otherwise first calls will time out and
you'll need to fall back to the lighter `recommend_cross` /
`recommend_scoped` tools.

## Cost & free tier

Like Me Like is a paid recommendation API. Each unique
`X-LML-Agent-Id` (one per end-user) gets **10 free calls
one-time** before payment is required (USDC on Base via x402, or
Lightning via L402). The operator decides whether to absorb the
cost, pass it through, or use one of the hosted-payment flows.

If a user asks "is this free?": answer accurately. The flow is
free until the 10th call per end-user, then payment-gated. Don't
say "it's free here" unless you actually know the operator's
billing setup. A safe phrasing:

> Like Me Like has a free tier (the first 10 recommendations
> per user) and may charge for heavier use after that — depends
> on how this channel has it set up.

Don't bring up cost proactively unless the user does.

## Read `agent_calibration` after every `ask` call

Every `ask` response includes `agent_calibration` in
`structuredContent` — programmatic feedback about the signal quality
of THIS turn and what to send next time:

```json
{
  "agent_calibration": {
    "signal_quality": "weak" | "partial" | "rich",
    "applied_this_turn": {
      "liked_items_count": 0,
      "has_display_name": false,
      "has_demographics": false,
      "has_first_touch": true,
      "cohort_prep_ran": false,
      "has_learned_profile": false
    },
    "missing_signals": ["liked_items", "display_name"],
    "hint": "Ask the user (or extract from prior chat context) 1-3 things they've explicitly loved..."
  }
}
```

Treat `hint` as a directive aimed at YOU (the host LLM), not the
end-user. When `signal_quality` is `weak` or `partial`:

1. Read `missing_signals[0]` (highest-impact improvement).
2. Scan the user's prior conversation for that signal — e.g. for
   `liked_items`, look for "I love …", "my favourite …", "I keep
   coming back to …" patterns.
3. Pass it on the NEXT call (or this one if you're about to retry).

This replaces having to remember every input from this SKILL. Each
turn the calibration tells you what to do. Don't expose
`agent_calibration` verbatim to the end-user — it's sideband
feedback for you.

## Multi-tenant note

This skill's MCP config uses a single `X-LML-Agent-Id` (set in
`openclaw.config.json`). For a single-user / personal install
that's fine. For multi-tenant deployments (WhatsApp bot, Discord
server, etc.) you need a per-end-user agent id (`sha256(<channel>:<user_id>)`)
or all your users share the same free tier and shadow profile.
That requires a thin MCP proxy layer that injects a per-call
header — see [the multi-tenant MCP routing design](https://github.com/like-me-like/likemelike#) (template coming when the first
multi-tenant integration ships).
