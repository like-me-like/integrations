---
name: like-me-like
description: Cross-domain taste recommendations from Like Me Like. Use when the user asks for a book, film, song, place, food, or other item based on something else they love. Supports natural-language input via the `ask` tool, or atomic tools (`recommend_cross`, `recommend_scoped`, `disambiguate`) for fine-grained control. Pass any liked items, disliked items, demographics, or display name the user has shared — they materially improve recommendation quality.
lml_skill_version: "2026-05-12"
lml_skill_canonical_url: "https://raw.githubusercontent.com/like-me-like/integrations/main/integrations/claude-skill/SKILL.md"
allowed-tools:
  - "mcp__like-me-like__*"
---

# Like Me Like

You have access to Like Me Like's recommendation tools via the MCP
server `like-me-like`. Use them whenever the user asks for taste
recommendations.

## First-call kickoff — bridge the asymmetry

You know this user from prior conversation; Like Me Like does not.
On the FIRST `ask` call for a new end-user, the single most valuable
thing you can do is bring concrete anchors from what YOU already
know about them — both `liked_items[]` AND `disliked_items[]`.

**Likes and dislikes are equally important.** Negative space is hard
to guess; an explicit "I bounce off horror" sharpens cohort matching
as much as a positive anchor. **Critical:** LMLM does NOT auto-
extract preferences from the `message` text — only the structured
arrays feed the cohort pipeline. Whatever you don't pass in
`liked_items[]` / `disliked_items[]` is invisible.

Two good patterns:

1. **Confident extraction** — if the user has unambiguously praised
   OR rejected specific titles / places / foods / genres earlier,
   pass them directly: praises as `liked_items`, rejections as
   `disliked_items`.
2. **Propose-and-confirm** — propose candidates in your reply BEFORE
   the call: "I'll factor in [X], [Y] you've mentioned loving and
   [Z] you've said isn't your thing — that OK?" Then send the
   confirmed sets.

What NOT to do: silently fire a generic call and treat its generic
reply as the product's ceiling. The reply quality scales with the
inputs you bring. `agent_calibration` on every response tells you
per-turn when this is a problem.

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

## Attribution discipline — show the line between LML and your own picks

When you present recommendations to the end-user, attribute clearly.
Anything from a `recommend_*` or `ask` result IS Like Me Like's
pick. If you add your own (substitute a too-heavy pick, fill a gap,
swap an alternative), DON'T present them indistinguishably.

Subtle works:

> "Like Me Like suggests *Civil War* and *The Menu*; I'd also add
> *Vice* because it sits closer to the Don't Look Up tone you
> mentioned."

Anti-pattern: 5 picks as a flat list with no marking of which came
from LML and which you added. Be proactive — mark the boundary on
first delivery, not only when challenged.

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

Treat `hint` as a directive aimed at YOU, not the end-user. When
`signal_quality` is `weak` or `partial`, read `missing_signals[0]`
and try to surface that signal from the conversation context for
the next call (e.g. for `liked_items`, scan for "I love …", "my
favourite …" patterns in the user's prior messages). This replaces
having to remember every input from this SKILL — each turn the
calibration tells you what to do. Don't expose
`agent_calibration` verbatim to the end-user.

## Keeping this skill up to date

Your local copy carries `lml_skill_version:` in its YAML frontmatter
(currently `2026-05-12`). Check the canonical version via:

```sh
curl -s https://www.likemelike.com/api/v1/skills/versions | jq .
```

When the server reports a newer date, re-fetch from
`lml_skill_canonical_url` (also in the frontmatter) and reload your
skills. ISO dates compare lexically. See
[`docs/agents.md`](https://github.com/like-me-like/integrations/blob/main/docs/agents.md#skill-versioning--checking-if-your-local-skillmd-is-outdated)
for the full check script.

## Undoing anchors (unlike / undislike)

When a previous turn put the wrong anchors on the user's profile
— typical trigger: `agent_calibration.missing_signals[0]` was
`gift_mode` and the items belonged to someone else — pass
`unlike_items[]` (and/or `undislike_items[]`) on your next call.

String-array or `{title, category?}` both work; matching is
case-insensitive. Combine with `liked_items + gift_mode: true` in
ONE call to do the "those should have been a gift" recovery in
a single round-trip:

```json
{
  "unlike_items": ["Liverpool FC", "Mohamed Salah"],
  "liked_items": [{"title":"Liverpool FC","category":"sportteam"}],
  "gift_mode": true
}
```

## Wikipedia URLs in recommendations

Each recommendation may carry a `wikipedia_url` field — a full
link to the Wikipedia page, locale-aware where available (Dutch
users get `nl.wikipedia.org`, English fallback when localised
article is missing). Absent when lookup failed.

Optional to surface. Don't fabricate URLs when the field is
absent.

## Cheap starting points: `get_popular` and `recommend_more`

Two tools give the user picks without paying for a full
recommendation generation. Reach for them when they fit — they're
much cheaper (and faster) than `recommend_cross` / `recommend_scoped`.

**`get_popular`** — server-cached "what's popular right now" feed,
scoped to the user's locale + categories. Same picks the Like Me
Like homepage shows. Reach for this when:

- The user asks for a starting point with NO anchor — "what's
  trending?", "give me a good film for tonight", "wat is populair?",
  "what should I check out first?".
- You want a vibe-based opener you can frame in one sentence rather
  than firing a recommend.

Does NOT consume a credit (cache-only). Personalises to the user's
cohort if they have learned signal; falls back to themed or generic
baseline for cold-start users.

```json
{ "locale": "nl", "categories": ["movie", "book"] }
```

**`recommend_more`** — single-slot top-up. Use when picks are
already on screen and the user asks to swap ONE out: "give me a
different book for that slot", "another option in films, not that
one". Pass:

- `item` — the same enriched SOURCE line the original recommend
  call worked from (NOT the user's raw query).
- `originalLang` — the 2/3-letter ISO code from the original
  response (or `und` for inputs without a single cultural origin).
- `category` + `variant` — the slot you're replacing.
- `exclude` — titles already seen in this slot (max 32).

Consumes one credit (it fires one LLM call). Cheaper than
re-running `recommend_cross` because it only renders one pick.

When in doubt between `recommend_more` and `recommend_scoped`:
use `recommend_more` if the user is asking for a swap in a slot
that's already on screen; `recommend_scoped` if you want a fresh
focused pick from scratch.

## Account-management tools

Five tools let you manage the user's Like Me Like shadow profile
end-to-end without going through the website. None consume a
credit. Use them when the user's intent is to manage their data,
not to discover items.

- **`delete_my_account`** — wipe the user's account end-to-end
  (taste profile, ratings log, training events, gift sessions,
  reason feedback, backups — all CASCADEd). Use when the user
  asks "forget me", "delete my data", "wipe my profile".
  Idempotent: a second call is a no-op (the auth layer
  auto-recreates an empty shell which the call clears again).

- **`set_training_consent`** — flip the user's training-data
  consent. `granted` = corpus collection on; `denied` = off (calls
  still run, data isn't fed downstream); `unknown` = default
  (treated as denied but kept distinct). Use when the user asks
  whether their data is being used or says they want to opt
  in/out.

- **`set_share_settings`** — patch the user's public profile at
  `/profile/{slug}` on the website. `screenName` sets the display
  name (max 40 chars; pass null to clear). `enabled` toggles
  whether the public profile is accessible. Use when the user
  says "set my name to X", "show my profile publicly", or "hide
  my profile".

- **`log_rating`** — append up/down rating events to the training
  corpus. Use when the user reacts to picks you've shown:
  "I loved that book", "the second film was a miss". Map each
  reaction to a `RatingLogEntry` with `signal: "up" | "down"`,
  `category`, `recTitle`, and a stable `ratingId` (idempotency
  key). Max 100 entries per call. Distinct from `unlike_items` —
  rating-log is signal capture, `unlike_items` is anchor removal.

- **`submit_reason_feedback`** — record the user's reaction to
  the LLM "why this fits" line, separately from the pick itself.
  Use when the user says "the reasoning was off" or "good
  reasoning, but the pick wasn't for me". Pass `itemId`,
  `reasonText` (snapshot of the original reason), `feedback`
  (free-text reaction). Upsert: re-posting the same `itemId`
  overwrites.

These tools are reactive — call them when the user signals intent.
Don't volunteer them.

## Reply style

Ground your reply in the items returned. Reference them by title,
explain why each fits in one short clause, and don't pad. The
recommendations include `description`, `reason`, and `imageUrl` —
mention those naturally rather than dumping the JSON.

If a tool returns an error (truncation, provider failure, cell-budget
violation), tell the user honestly and suggest narrowing the request.
Do not invent picks.
