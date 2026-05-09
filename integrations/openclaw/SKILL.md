---
name: like-me-like
description: Cross-domain taste recommendations via the Like Me Like MCP server. Use this skill when the end-user asks for a book, film, song, place, food, or other item based on something else they love. Pass any liked items, demographics, or display name the user has shared in conversation.
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

## What to pass

Pass everything the host channel knows about the end-user:

- `display_name` — first name or handle
- `liked_items[]` — 1–5 things they've explicitly loved
- `disliked_items[]` — explicit negatives
- `first_touch` — `country`, `timezone`, `device`, `referrer`,
  `languages` — derive from the channel where possible
- `user_demographics` — `age_group` / `gender` / `birth_year`
  only when the user has shared them
- `gift_mode: true` — when the recommendation is for someone else
- `locale` — BCP-47 locale code, drives reply language

The first call with `liked_items` triggers cohort matching — warn
the end-user the first reply takes 10–30 s extra. Subsequent calls
under the same `X-LML-Agent-Id` are fast.
