---
name: like-me-like
description: Cross-domain taste recommendations via the Like Me Like MCP server. Use this skill when the end-user asks for a book, film, song, place, food, animal, or other item based on something else they love. Pass any liked items, demographics, and display name the user has shared in conversation. Like Me Like has a free tier (10 calls per end-user) then paid; mention this honestly if the user asks about cost.
lml_skill_version: "2026-05-14.2"
lml_skill_canonical_url: "https://raw.githubusercontent.com/like-me-like/integrations/main/integrations/openclaw/SKILL.md"
metadata:
  openclaw:
    requires:
      mcp_servers:
        - like-me-like
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

- **Cross-domain:** "What's a good [item_in_category_A] based on [item_in_category_B]?",
  "Recommend [a-restaurant/a-place/a-book/etc.] for someone who loves [creator-or-work]",
  "What [category] goes with [seed_item]?"
- **Single-pick:** "Give me one [item_in_category] like [seed_item]." (use
  `recommend_scoped`)
- **Disambiguation:** "Recommend something like [ambiguous_term]." → first
  call `disambiguate("[ambiguous_term]")` to pick the right interpretation
  (when one term resolves to multiple distinct works — novel / film /
  video game / song that share the name).
- **Multi-domain at once:** "I love [seed_creator_or_work] — what should I
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

## Save vs Like — critical distinction

Liked items and saved items are NOT the same. Mixing them
corrupts the user's profile.

- **`liked_items`** = the user has personally EXPERIENCED something
  AND likes it. Pattern in any language: declarative first-person
  praise ("I love [item]", "[item] is my favourite [category]",
  "[item] is one of my comfort [category]s") or recurring-
  experience claim ("I [watch/read/listen to] [item] every
  [time-marker]"). Requires PRIOR contact, implied or explicit.
  liked_items shape the user's cohort + drive future
  recommendations as anchors.

  **Each liked_item carries an optional `confidence` (0-1).**
  This lets you hedge when the user's claim is strong vs soft:

  | Confidence | When | Pattern (recognise across languages) |
  |---|---|---|
  | **1.0** | Declarative explicit claim with clear prior experience, no hedge | "[item] is my [favourite/best/comfort] [category]"; "[item] was [strong-positive-past-tense]"; "I love [item]"; "I've been [verb-of-experience] [item] for years"; "[item] vond ik top, ken ik al" |
  | **0.85-0.95** | Explicit claim with a softening hedge ("I think", "denk dat", "best wel", "kind of", "vrij", "sort of") | "I think I really liked [item]", "[item] is best wel leuk, kijk het regelmatig" |
  | **0.5-0.7** | Casual mention, prior experience implied but not asserted | "I was in [place] recently and it was magical", "that [adjective] [item] [time-ago] was strong" |
  | **0.2-0.4** | Ambiguous ack on a fresh suggestion (no prior-experience claim) | "[item] is leuk" / "sounds good" / "klinkt aardig" / "interesting" — when the item was JUST suggested THIS turn and the user makes no claim of prior contact |

  Pass `confidence_source: "explicit_like" | "casual_mention" |
  "ambiguous_ack"` alongside so the operator can see why you
  chose the value. Default when omitted: 1.0 (full strength) —
  backwards compat for seed inserts.

  **Don't under-grade declarative claims.** Unhedged superlatives
  or first-person past-tense state verbs ("[item] was [strong-
  positive]", "[item] vond ik top, ken ik al", "I love [item]" —
  the pattern works across any language) ARE the 1.0 case.
  Reserve 0.85-0.95 for cases where the user softens with hedge
  words ("I think" / "denk dat" / "best wel" / "kind of" /
  equivalents in their language). A pattern of consistently
  scoring strong claims at 0.9 produces a fuzzy taste profile
  over time.

  **Cohort matching weighs by confidence.** Low-confidence
  anchors land on the profile so the brain has continuity, but
  they don't dominate cohort retrieval. The user can reinforce
  them later (e.g. the user later reports actually experiencing
  the previously-ambiguous item: "I finally [verb-of-experience]
  [item], it's beautiful" → pass the same item again with
  confidence 0.9-1.0; dedupeAndCap keeps the higher value).

  Low-confidence anchors do NOT auto-decay. They stay on the
  profile until the user explicitly unlikes them.

- **`save_item`** (tool) = the user wants a BOOKMARK to come
  back to this item later. Use this ONLY when the user signals
  bookmark intent — not for every positive ack. Triggers:
  - The user uses an explicit save verb (any language): save,
    bewaar, opslaan, bookmark, remember, onthoud, "voor later",
    "voor me noteren", "op m'n lijst", "ga ik kijken/lezen/
    luisteren met X".
  - The user explicitly asks for a bookmark / list-add.

  **CRITICAL: call `save_item` IMMEDIATELY when those verbs
  fire.** Don't just say "ik zal het onthouden" in your reply
  without actually calling the tool — that's lip service. Call
  the tool; the server-side write IS the bookmark.

  Save does NOT touch the cohort signal — it's a softer
  "interested" tier, separate from the taste graph.

- **Positive ack on a fresh suggestion ≠ save.** When the user
  reacts positively to something you JUST suggested — "sounds
  good", "interesting", "klinkt aardig", "lijkt me wel wat",
  "[item] is leuk" (where [item] is something you just named) —
  pass it as a **liked_item with confidence 0.2-0.4 and
  confidence_source: "ambiguous_ack"** — not as save_item.
  That's a soft taste signal, not a bookmark. Only ALSO call
  save_item if the user uses an explicit save verb in the same
  message ("sounds good, save it" / "klinkt aardig, bewaar
  maar"). The two actions are independent and can fire together
  when both signals are present.

- **Promotion path**: when the user later reports having
  experienced something they saved (pattern: "I [verb-of-
  experience] [the saved item] [time-ago], loved it" — works
  across languages), THAT is the moment to remove it from saves
  (call `remove_saved_item`) AND add it to `liked_items` on
  your next recommend_* call.

- **Demotion path**: if the user reports tried-and-disliked
  ("[the saved item] viel tegen", "it didn't land for me", "not
  for me"), do NOT add to liked_items — add to `disliked_items`
  and call `remove_saved_item` to clear the pending intent.

The brain reads a `SAVED ITEMS` block above this section
(when populated) — surface those naturally when the user asks
"what did I save?" / "wat had ik bewaard?" / "I want to watch
something from my list".

Also useful: the `RECENT QUERIES` block lists the user's last
~8 chat messages. Lean on it when the user references a prior
turn ("die film waar je het laatst over had") or when you want
continuity across conversations.

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

## Earn trust by drawing out preferences

Your job isn't just to fire `recommend_*` and serve whatever
comes back. It's to make the user feel understood. The
`liked_items[]` / `disliked_items[]` arrays you pass shape
EVERY future call for this user — they accumulate into a cohort
signal, a learned summary, a cluster of axes. So every concrete
preference you can elicit pays compound interest.

When context is thin (no `liked_items` this turn, no learned
profile from prior turns), don't fall back to a generic call.
Spend a turn or two getting to know them:

- **Ask focused questions that invite concrete answers.**
  Avoid: "What do you like?" (too broad — produces non-answers).
  Prefer: "What's the last film that genuinely surprised you?"
  or "Wat is een boek waar je iemand altijd over vertelt?".
- **Pick a domain the user has already signalled.** "Welke film?"
  → ask about films, not about hobbies. Stay close to their
  framing.
- **Reflect back what you understand.** Before firing the
  recommend, paraphrase: "ah, dus iets wat aandacht vraagt, niet
  popcorn-mode" — then call the tool. Demonstrates listening.
- **Match tone to the user.** Playful "wat is jouw guilty pleasure
  film?" works for casual messages. "Een film die je nog steeds
  bezig houdt?" works for thoughtful ones. Serious for serious,
  warm for warm, dry humour for dry humour. Read the room each
  turn; don't commit to one register.

When you do call a recommend tool, sweep up EVERY mention the
user dropped — not just the seed. E.g. "I was in [place]
recently and I'm looking for a [category]" → `item: "[category]"`
OR `item: "[place]"` AND `liked_items: [{"title":"[place]",
"category":"plaats"}]`. Casual mentions of places, films, foods,
hobbies, artists count as anchors; silently add them.

The bar: after three or four exchanges, the user should think
"this thing knows me" — not because you guessed lucky, but
because you actually listened.

Use the persisted context that lands above this section
(`USER NAME`, `USER DEMOGRAPHICS`, `USER DEVICE`,
`USER FIRST VISIT`, `USER LOCAL TIME`, `USER TASTE PROFILE`,
`REFINED COHORT`). They're free signal — the user already gave
them by visiting the site and asking this question. Address them
by name when natural; let their device + locale + first-visit
context + local time steer your tone (someone visiting from a
podcast review site cares about podcasts; mobile + dark mode +
nl-NL skews casual Dutch; late-evening or deep-night vs daytime
changes how energetic vs contemplative a pick should feel).

The `REFINED COHORT` block (when present) is the most useful
cohort signal for THIS turn: the server embedded the user's
current question and found similar-tasted users, then surfaced
their top likes. Lean on it for query-relevant picks (e.g. the
user asked about "iets voor onder het koken" → REFINED COHORT
likely lists items that other "ambient/easy-listening" users
loved). The `USER TASTE PROFILE` block stays useful for
long-term taste; `REFINED COHORT` captures this-turn intent.

Don't ask permission before adding anchors ("zal ik dit
onthouden?"). The user already volunteered the signal by
mentioning it. They can always retract via "actually I don't
love X" (which you map to `unlike_items`, rule 14).

## Reply style

Ground your reply in the items returned. Reference them by title,
explain why each fits in one short clause, and don't pad. The
recommendations include `description`, `reason`, and `imageUrl` —
mention those naturally rather than dumping the JSON.

If a tool returns an error (truncation, provider failure, cell-budget
violation), tell the user honestly and suggest narrowing the request.
Do not invent picks.


## Multi-tenant note

This skill's MCP config uses a single `X-LML-Agent-Id` (set in
`openclaw.config.json`). For a single-user / personal install
that's fine. For multi-tenant deployments (WhatsApp bot, Discord
server, etc.) you need a per-end-user agent id (`sha256(<channel>:<user_id>)`)
or all your users share the same free tier and shadow profile.
That requires a thin MCP proxy layer that injects a per-call
header — see [the multi-tenant MCP routing design](https://github.com/like-me-like/likemelike#) (template coming when the first
multi-tenant integration ships).
