# Changelog

All notable changes to the Like Me Like integrations repo. The
SKILL.md files in `integrations/openclaw/` and
`integrations/claude-skill/` carry an `lml_skill_version:` field in
their YAML frontmatter that matches the most recent date a SKILL
content change shipped — compare yours against the
[`/api/v1/skills/versions`](https://www.likemelike.com/api/v1/skills/versions)
endpoint, or eyeball the dates below.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Date stamps are ISO YYYY-MM-DD; meaningful skill content changes
bump that date. Pure copy-edits, typo fixes, and dev-facing README
changes do not bump the SKILL version.

## [2026-05-11]

### Added — Wikipedia URLs in recommendations + admin recovery tool

- **`wikipedia_url` on every recommendation.** Server-populated
  during the existing image-enrichment pass (no extra HTTP calls).
  Locale-aware: Dutch users searching for Dutch titles get
  `nl.wikipedia.org` links; English fallback when the localised
  article doesn't exist. Field is absent when lookup fails entirely
  (rare — most LMLM-suitable items have a Wikipedia article).
  Host LLMs can optionally surface as a clickable reference; both
  SKILL.md files gain a "Wikipedia URLs in recommendations"
  section.
- **`POST /api/admin/user-undo-likes`** — surgical rollback of the
  N most-recently-added liked / disliked entries on a user's
  profile, with summary + cluster_axes + cohort re-derive. Built
  for profile-pollution recovery: when a host LLM forgot to set
  `gift_mode: true` on a "for someone else" turn, the recipient's
  anchors get into the user's main profile and pivot their
  cluster_axes (the 2026-05-10.2 gift heuristic prevents this
  prospectively; this endpoint cleans up sessions where it
  already happened). `?dropLikes=N&dropDislikes=M`.

## [2026-05-10.2]

### Added — host-side attribution + agent-side observability

- **Attribution discipline section** in both SKILL.md files. When
  the host LLM presents recommendations to the end-user, mark the
  line between LML output and the host's own additions ("LML
  suggests X, Y; I'd also add Z because…"). Anti-pattern is calling
  out specifically: 5 picks as a flat list with no marking.
- **`agent_calibration` on atomic recommend tools.** The structured
  output of `recommend_cross`, `recommend_scoped`, and the JSON
  body of `POST /api/v1/recommend/scoped` now carries the same
  signal-quality / missing-signals / hint block that `ask` returns.
  Hosts who skip the chat brain still get per-call feedback.
- **gift_mode heuristic.** Server-side detection of gift-context
  patterns ("voor [naam]", "verjaardag", "for my friend",
  "een cadeau voor X") in the user's message. When detected AND
  `gift_mode` was NOT passed, `gift_mode` lands at the TOP of
  `agent_calibration.missing_signals` with a hint warning about
  profile pollution. Multilingual (Dutch + English at minimum);
  conservative (self-reference patterns suppress).
- **`allow_source_variants` override.** Default behaviour stays
  unchanged: recommendations are NEVER variants of the source
  item — not in the same category and not across categories
  (validator rules B + D enforce this). When the user explicitly
  asks for derivatives ("the soundtrack of X", "the book version
  of Y", "another work by [creator]"), the host LLM can now pass
  `allow_source_variants: true` on `recommend_*` tools (or the
  REST body) to skip rules B + D for that one call.

## [2026-05-10.1]

### Changed — equal weight to dislikes in first-call kickoff

- **Kickoff guidance now pairs `liked_items[]` and `disliked_items[]`.**
  Previous version focused on positives only. Negative space is
  hard for the cohort pipeline to guess from likes alone — explicit
  rejections (genres / titles the user has bounced off) sharpen the
  match meaningfully, so the host should extract both directions
  with the same diligence.
- **Tool description / SKILL.md / agents.md** all explicitly state:
  LMLM does NOT parse `message` text for preferences; only the
  structured `liked_items[]` / `disliked_items[]` arrays feed the
  cohort pipeline. The host LLM is the extractor.
- **`agent_calibration.missing_signals`** gains `disliked_items` as
  a follow-up signal (only flagged once likes have arrived). New
  hint case explains the disliked_items shape and where to source
  negatives from.
- **Same-day sub-revision** (`.1` suffix) so integrators who pulled
  the earlier 2026-05-10 SKILL today see "remote is newer" on the
  lexical version compare.

## [2026-05-10]

### Added — agent quality of life

- **First-call kickoff guidance.** Both SKILL.md files and every
  recipe README now name the asymmetry explicitly (the host LLM
  knows the user from prior conversation; Like Me Like does not)
  and prescribe two patterns: confident extraction (pass items
  directly when the user has unambiguously praised them) or
  propose-and-confirm ("I'll factor in X, Y, Z that you've
  mentioned loving — that OK?"). Anti-pattern called out: don't
  fire a generic call and accept the generic reply as the
  product's ceiling.
- **`agent_calibration` response field.** Every chat-orchestrator
  response (`POST /api/v1/chat` JSON body and MCP `ask`
  `structuredContent`) now carries a programmatic feedback block
  for the host LLM: `signal_quality` (`weak` / `partial` / `rich`),
  `missing_signals[]` ordered by impact, and a one-sentence `hint`.
  Replaces having to memorise input-passing rules with per-turn
  feedback the host reacts to.
- **Cold-start cohort prep for agent flow.** The first `ask` /
  `chat` call without `liked_items` now triggers a Haiku-tier
  early-sketch summary + embedding + cohort assign synchronously
  (~10–15 s on first call), so the chat brain has a learned
  profile to ground in even on turn 1. Mirrors what the website's
  `/api/init` does for cold-start visitors. Subsequent calls
  reuse the warm signal.
- **`/api/v1/skills/versions` endpoint.** Returns the canonical
  ISO-date version stamp for each shipped SKILL.md plus their
  raw URLs, so integrators can compare against their local
  copies.

### SKILL.md frontmatter additions

- `lml_skill_version: "2026-05-10"`
- `lml_skill_canonical_url: <raw github url>`

## [2026-05-04]

### Added

- **Cost transparency across all surfaces.** Every recipe README
  and both SKILL.md files now explain the 10-call free tier per
  end-user and the x402 / L402 paid path. Tool descriptions
  surface the cost framing for host LLMs to relay accurately.
- **Supported categories list.** All recipes now list the canonical
  category ids (book, movie, song, ..., dier, overig) plus English
  aliases (animal, food, place, artist) that resolve automatically.
- **`animal` / `pet` aliases** added to the category resolver — was
  previously a silent drop; now resolves to canonical `dier`.
- **`unknown_category_ids[]` in `recommend_cross` results** — the
  brain (and host LLMs) can acknowledge dropped categories instead
  of pretending they were returned.
- **Minimum tool timeout note (≥ 60 s).** First call with
  `liked_items` triggers cohort matching that takes 15-30 s extra;
  default 20-30 s timeouts cut the call off.
- **`display_name` upgraded to "always pass when known".** Was
  previously framed as "optional"; replies addressing the user by
  name materially improve perceived quality.

## [2026-05-02]

### Changed

- **All URLs canonicalised to `www.likemelike.com`.** Some MCP
  clients don't follow the apex-domain 307 redirect, so all recipe
  examples now use the www subdomain directly.

### Added

- **Wallet compatibility table** for x402 USDC payments,
  documenting the [coinbase/x402#623](https://github.com/coinbase/x402/issues/623)
  CDP-side limitation with Smart-Wallet sigs (ERC-6492 wrapped
  signatures aren't yet unwrapped by the facilitator). EOA wallets
  (MetaMask, Rabby, etc.) work end-to-end.

## [2026-04-30]

### Added

- **Lightning Network (L402) as a peer payment rail to x402.**
  USDC on Base via x402 OR sats over Lightning via L402 — same
  challenge / poll / settle envelope, agents pick whichever rail
  matches their wallet.
- **C-lite hosted payment pattern.** A `/pay/<challengeId>` page
  the agent can deep-link the end-user to, server-rendering a QR
  for either rail. Closes the loop for hosts that can't sign
  EIP-712 in their own runtime.

## [2026-04-26]

### Added

- **Initial public release** of the Like Me Like integrations repo.
  MIT licensed. Recipes for: ChatGPT (Custom GPT actions), Claude
  Desktop (MCP), Claude Skills (skill markdown), Gemini (function
  calling), Grok (xAI function calling), Hermes Agent (MCP YAML),
  OpenClaw (MCP + skill).
- **`docs/agents.md`** central guide with curl examples for every
  endpoint plus the JSON-RPC handshake for the MCP transport.
- **`docs/openapi.json`** auto-extracted from the canonical OpenAPI
  source so spec consumers can generate clients.
