---
name: like-me-like
description: Cross-domain taste recommendations from Like Me Like. Use when the user asks for a book, film, song, place, food, or other item based on something else they love. Supports natural-language input via the `ask` tool, or atomic tools (`recommend_cross`, `recommend_scoped`, `disambiguate`) for fine-grained control. Pass any liked items, disliked items, demographics, or display name the user has shared — they materially improve recommendation quality.
allowed-tools:
  - "mcp__like-me-like__*"
---

# Like Me Like

You have access to Like Me Like's recommendation tools via the MCP
server `like-me-like`. Use them whenever the user asks for taste
recommendations.

## When to use

Recognise these patterns:

- **Cross-domain:** "What's a good book based on Interstellar?",
  "Recommend a restaurant for someone who loves Wes Anderson films",
  "What music goes with Stoner?"
- **Single-pick:** "Give me one film like Past Lives." (use
  `recommend_scoped`)
- **Disambiguation:** "Recommend something like Dune." → first
  call `disambiguate("Dune")` to pick the right one (1965 novel /
  2021 film / video game).
- **Multi-domain at once:** "I love Joni Mitchell — what should I
  watch, read, and eat tonight?" → `recommend_cross` with
  `categories=["movie","book","food"]`.

For natural-language one-shots, the `ask` tool is fine — it wraps
the chat brain and orchestrates the atomic tools internally. Prefer
atomic tools when you want explicit control or to chain results.

## Personalisation — pass what you have

The single highest-leverage signal is `liked_items` (1–5 things the
user has explicitly loved). Pass it whenever the user volunteers
even one. Other useful fields:

- `disliked_items` — explicit negatives
- `display_name` — the user's first name (≤ 40 chars)
- `user_demographics` — `age_group`, `gender`, `birth_year` only
  when the user has shared them
- `gift_mode: true` — when the recommendation is for someone else
- `locale` — BCP-47, drives reply language

You don't need to re-ask the user for these on every turn; pass
whatever you already know from the conversation context.

## Cell budget — at most ~10 results per call

`recommend_cross` enforces `categories.length × variants.length ≤ 5`.
Each cell yields ~2 picks, so a single call returns at most ~10
results. If the user asks for more, split into parallel calls and
merge the results.

## Supported categories

LMLM accepts these category ids (English aliases also resolve):
`book`, `movie`, `song`, `tv_series`, `documentary`, `podcast`,
`video`, `game`, `image`, `article`, `magazine`, `comic_or_manga`,
`persoon`, `artiest`, `acteur`, `influencer`, `plaats`,
`restaurant`, `event`, `experience`, `sportteam`, `sport`,
`hobby`, `eten`, `drinken`, `merk`, `stijl`, `grap`, `dier`,
`shop`, `overig`. Aliases like `food`, `place`, `animal`, `artist`
resolve automatically.

When you pass an unknown id, it's silently dropped and reported
in the response's `unknown_category_ids` field. Acknowledge to the
user instead of pretending it was returned.

## First-call latency

The first call with `liked_items` triggers cohort matching
(~15–30 s extra). Configure your client / tool timeout to at
least 60 s. Subsequent calls under the same agent id are fast.

## Cost & free tier

Like Me Like is a paid recommendation API. Each unique end-user
gets 10 free calls one-time, then payment is required (USDC on
Base via x402, or Lightning via L402). If a user asks about
cost: answer accurately ("first 10 recommendations are free per
user, paid after that — depending on how this channel has it
configured"). Don't bring up cost proactively unless asked. Don't
claim it's free if you don't know the channel's billing setup.

## Reply style

Ground your reply in the items returned. Reference them by title,
explain why each fits in one short clause, and don't pad. The
recommendations include `description`, `reason`, and `imageUrl` —
mention those naturally rather than dumping the JSON.

If a tool returns an error (truncation, provider failure, cell-budget
violation), tell the user honestly and suggest narrowing the request.
Do not invent picks.
