# Like Me Like Agent API — quick start

The agent surface is stable from the `v1/` prefix. All endpoints
take an `X-LML-Agent-Id` header carrying a stable third-party-supplied
end-user identifier (8-256 ASCII chars). First call from a new
identifier auto-creates a shadow profile and grants 10 free calls.
After that, an x402 USDC top-up gates further calls (see Payments
below).

```sh
BASE="https://likemelike.com"
AGENT="agent-test-$(openssl rand -hex 4)"   # any 8-256 ASCII chars
```

## Spec discovery

```sh
curl -s "$BASE/api/v1/openapi" | jq .
```

## Recommend (cross-domain, streaming)

The streaming response uses the LMLM wire format:
`SOURCE: <category> | <enriched item> | <orig lang> | <anchor lang>\n`
followed by narration text, then a sentinel + JSON tail.

**Per-call cell budget.** Configure categories and variants freely
as long as their **product** stays within budget:

```
categories.length × variants.length ≤ 5
```

Each cell yields ~2 picks from the LLM, so this caps each call at
~10 results — safely under the truncation threshold of the
recommendation model (~25% parse-error rate observed above ~10–12
items in one streamed JSON response).

Examples:

| categories | variants | cells | items | OK? |
| --- | --- | --- | --- | --- |
| 5 | best | 5 | ~10 | ✓ |
| 4 | best | 4 | ~8 | ✓ |
| 2 | best, recent | 4 | ~8 | ✓ |
| 1 | best, recent, wild | 3 | ~6 | ✓ |
| 3 | best, recent | 6 | ~12 | ✗ — too many cells |
| 5 | best, recent | 10 | ~20 | ✗ — too many cells |

The website avoids this constraint via client-side variant
splitting + parse-side salvage + per-cell top-ups via
`/api/recommend/more`. Agents have no UI to drive that, so the
cap is enforced server-side on input — explicit failure with a
hint beats silent truncation.

**Default values** (when fields omitted): `categories` = first 2
free-tier categories (book + movie typically), `variants` =
`["best","recent"]`. That's 4 cells / ~8 items — a safe default.

**For larger asks**, fire multiple parallel calls and merge
client-side:

```sh
# Call A: 5 cats × 1 var (best)
curl -s -N "$BASE/api/v1/recommend" \
  -H "X-LML-Agent-Id: $AGENT" -H "Content-Type: application/json" \
  -d '{"item":"Interstellar","categories":["book","movie","song","eten","plaats"],"variants":["best"]}' &

# Call B: same 5 cats × 1 var (recent)
curl -s -N "$BASE/api/v1/recommend" \
  -H "X-LML-Agent-Id: $AGENT" -H "Content-Type: application/json" \
  -d '{"item":"Interstellar","categories":["book","movie","song","eten","plaats"],"variants":["recent"]}' &

wait
```

Each call counts as one against the free-tier counter (and
against the credit balance once x402 enforcement is on).

Basic single-call example:

```sh
curl -s -N "$BASE/api/v1/recommend" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"item": "Interstellar", "locale": "en"}'
```

URL-as-item works too — server resolves to the page title:

```sh
curl -s -N "$BASE/api/v1/recommend" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"item": "https://en.wikipedia.org/wiki/Interstellar_(film)"}'
```

Or pass the URL explicitly via `source_url`:

```sh
curl -s -N "$BASE/api/v1/recommend" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"source_url": "https://en.wikipedia.org/wiki/Interstellar_(film)"}'
```

Image input via URL (server fetches, base64s internally):

```sh
curl -s -N "$BASE/api/v1/recommend" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"item": "this picture", "image_url": "https://upload.wikimedia.org/.../foo.jpg"}'
```

## Recommend scoped (single-category, JSON)

`{"item": "Interstellar", "target_category": "book", "num_picks": 1}`
→ 1 book recommendation, returned as JSON (not a stream).

```sh
curl -s "$BASE/api/v1/recommend/scoped" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{
    "item": "Interstellar",
    "target_category": "book",
    "num_picks": 1,
    "locale": "en"
  }' | jq .
```

`num_picks` only accepts 1 in stap-2; 3-pick scoped lands in a
follow-up commit. For more picks now, call repeatedly with the
returned title appended to a client-side exclude list.

## Disambiguate

Resolve an ambiguous title to ranked candidates from the items
catalog. Confidence 1.0 = exact title-key match in the category
hint; 0.85 = exact match without category match; 0.4-0.6 = prefix
match.

```sh
curl -s "$BASE/api/v1/disambiguate" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"query": "Dune", "category_hint": "film"}' | jq .
```

## Item lookup (GET)

```sh
# By id
curl -s "$BASE/api/v1/item/abc123" -H "X-LML-Agent-Id: $AGENT" | jq .

# Search
curl -s "$BASE/api/v1/item/search?q=Interstellar&category=film&limit=5" \
  -H "X-LML-Agent-Id: $AGENT" | jq .
```

## Profile lookup (GET)

Returns the same data the website's `/profile/{slug}` page renders.
404s for users with `profile_share_enabled=false`.

```sh
curl -s "$BASE/api/v1/profiles/abc123def4" \
  -H "X-LML-Agent-Id: $AGENT" | jq .
```

## Chat (conversational entry point)

`POST /api/v1/chat` is the natural-language doorway. The chat brain
parses intent and calls the atomic tools above on your behalf, then
returns a text reply plus the flat list of recommendations any tool
calls produced.

Cell-budget rule applies inside the brain too — if you ask for more
than ~10 results, it narrows + explains rather than truncating.

### Single-turn, stateless

Easiest pattern. Don't track a conversation id; just send the user's
message and (optionally) a `previous_messages[]` array for context.

```sh
curl -s "$BASE/api/v1/chat" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Interstellar is my favorite film. What is the best book for me to read next? Give me one result.",
    "source": "api",
    "locale": "en"
  }' | jq .
```

Response shape:

```json
{
  "conversation_id": "uuid-or-null",
  "reply": "Building on Interstellar, 'Contact' by Carl Sagan is a strong pick...",
  "recommendations": [ { "type": "book", "title": "Contact", ... } ],
  "tool_calls": [ { "name": "recommend_scoped", "args": {...}, "ok": true } ],
  "latency_ms": 12450
}
```

### Multi-turn, stateful

First turn: omit `conversation_id`. The response returns one in the
`conversation_id` field. Pass it back on every subsequent turn.

```sh
# Turn 1
RESP=$(curl -s "$BASE/api/v1/chat" \
  -H "X-LML-Agent-Id: $AGENT" -H "Content-Type: application/json" \
  -d '{"message":"Interstellar is my favorite film, what is the best book?","source":"api","locale":"en"}')
CONV=$(echo "$RESP" | jq -r .conversation_id)
echo "$RESP" | jq .reply

# Turn 2 — refers to turn 1's pick implicitly
curl -s "$BASE/api/v1/chat" \
  -H "X-LML-Agent-Id: $AGENT" -H "Content-Type: application/json" \
  -d "{\"message\":\"And a film in the same mood?\",\"conversation_id\":\"$CONV\",\"locale\":\"en\"}" | jq .reply
```

Conversations expire after 48 hours of inactivity.

### Personalisation: liked_items, disliked_items, first_touch, user_demographics, gift_mode, display_name

The same six optional fields are accepted on **all** these
surfaces — pass any subset:

| Surface | How |
| --- | --- |
| `POST /api/v1/chat` | Top-level body fields |
| `POST /api/v1/recommend` (streaming) | Top-level body fields |
| `POST /api/v1/recommend/scoped` (JSON) | Top-level body fields |
| MCP `ask` tool | Tool-call arguments |
| MCP `recommend_cross` / `recommend_scoped` tools | Tool-call arguments |

- `liked_items[]` — items the end-user has explicitly loved.
  Each entry: `{ title: string, category?: string }`. 1-5 is
  plenty; max 20. **Highest-impact signal**.
- `disliked_items[]` — same shape, for explicit negatives.
- `first_touch` — cold-start cohort hint when no liked_items yet.
  Mirrors what the website captures from `device_profile` +
  `first_visit_context` so the same fields generalise across
  every interface. Pass any subset the channel can derive:
  - `timezone` — IANA, e.g. `'Europe/Amsterdam'`.
  - `country` — ISO 3166-1 alpha-2, e.g. `'NL'`.
  - `device` — `'mobile' | 'desktop' | 'tablet'`.
  - `referrer` — `'whatsapp' | 'discord' | 'web' | …`.
  - `languages` — ordered list of BCP-47 locales, primary first.
    `['nl-NL','en-US']` = Dutch primary, comfortable with English.
    Stronger signal than a single locale code (max 6).
  - `entry_path` — host-app path the user landed on (e.g.
    `'/profile/abc'` for deep-links).
  - `entry_params` — `{utm_source?, utm_medium?, utm_campaign?, utm_content?, utm_term?, ref?, source?, via?}`.
    Other keys are dropped server-side; values capped at 80 chars.
  - `prefers_dark` — boolean, light/dark UI preference.
- `user_demographics` — `{ age_group?, gender?, birth_year? }`.
  Self-declared, persisted with `demographics_source='self'`.
  Soft signal used (when wired) to match against item-level
  age/gender targeting.
- `gift_mode: boolean` — true when the recommendation is FOR
  SOMEONE ELSE (a birthday gift, a friend, a child). Lands in
  `gift_sessions` instead of touching the agent's own taste graph
  → won't pollute future personal picks. The brain is told to
  build picks around the message-described recipient, not the
  agent's prior likes.
- `display_name: string` — the end-user's first name or handle
  (max 40 chars). Persisted on the shadow profile's `screen_name`;
  the brain will address the user by this name when natural. Pass
  on every call where it's known — late corrections (host LLM
  hears "actually I'm Sam") overwrite cleanly. Same field the
  website's profile-share dialog writes, so when a user later
  claims their shadow profile on the LML website (Connect-Agent
  flow, planned), the name carries over.

When `liked_items` or `disliked_items` is non-empty, the server
runs the **full cohort-match pipeline before** the chat brain
sees the message:

1. Persists the items to the user's shadow taste profile.
2. Calls the LLM-summary deriver — same path the website uses on
   first-visit init.
3. Embeds the summary.
4. Assigns the user to the nearest cohort centroid.
5. Refreshes the cohort cache so subsequent recommend calls
   surface "users like you also like…" hits.

Total extra latency on the FIRST call: ~10-30 s (LLM summary is
the slow part). Subsequent turns in the same conversation are
free — the cohort signal is now persisted.

The chat brain handles whatever signals it gets:

- Anchors present → ground the reply in them; mention briefly that
  the matching took a moment when cohort prep ran.
- Anchors absent → give the best generic pick possible. The brain
  doesn't proselytise about how more input would help; collecting
  context is the host's job (your job, not ours), and the input
  may be reaching us via an automated workflow with no human in
  the loop.

Scaling input from caller's side is what matters: every additional
field above tightens the cohort match. The server makes the best of
whatever you pass — no input is required beyond `message`. If you
pass `liked_items` for the first time on a given agent_id, surface a
warning to the end-user that the first reply takes longer (10-30 s
on top of normal).

**WhatsApp example** (via MCP `ask`):

```sh
curl -s "$BASE/api/v1/mcp" \
  -H "X-LML-Agent-Id: $WHATSAPP_HASH" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "id":1,
    "method":"tools/call",
    "params":{
      "name":"ask",
      "arguments":{
        "message":"What should I read next?",
        "locale":"en",
        "display_name":"Sam",
        "liked_items":[
          {"title":"Interstellar","category":"movie"},
          {"title":"Stoner","category":"book"},
          {"title":"Past Lives","category":"movie"}
        ],
        "first_touch":{
          "country":"US",
          "timezone":"America/New_York",
          "device":"mobile",
          "referrer":"whatsapp"
        }
      }
    }
  }'
```

Stable `X-LML-Agent-Id` per WhatsApp end-user (`sha256(phone_number)`)
keeps the shadow profile growing across conversations — cohort
prep only runs the FIRST time taste anchors arrive; later calls
just reuse the now-warm cohort signal.

### Sources

The `source` field shapes the brain's tone:

- `api` (default) — concise JSON-flavoured replies, the agent
  composes its own UI on top.
- `web` — warmer prose, complements visual cards.
- `x` — tweet-shaped, ≤280-char text framing image cards.
- `mcp` — tight machine-readable replies for the MCP `ask` tool.

## MCP (Model Context Protocol)

`POST /api/v1/mcp` is a standards-compliant MCP server. Any MCP-aware
client (Claude Desktop, custom MCP agents, the official MCP SDKs)
can connect, list tools, and invoke them.

The server exposes the same six atomic tools as the chat endpoint
plus a high-level `ask` tool that wraps `/api/v1/chat`:

| **Tool** | **Shape** | **Use when** |
| --- | --- | --- |
| `recommend_cross` | structured | you want fine-grained control over categories + variants |
| `recommend_scoped` | structured | you want one focused pick in a single category |
| `disambiguate` | structured | the seed is ambiguous (e.g. "Dune") |
| `get_item` | structured | look up canonical item details by id |
| `search_items` | structured | title-prefix browse the items catalog |
| `get_profile` | structured | fetch a public profile by slug |
| `ask` | natural-language | one-shot conversational entry — same brain as `/chat` |

Atomic tools = the agent's host LLM orchestrates. `ask` = our brain
orchestrates. Pricing is the same per call against the free-tier /
balance counters.

### JSON-RPC handshake

MCP uses JSON-RPC 2.0 over HTTP POST. Each call is a single message
(or batch). Auth via `X-LML-Agent-Id` header — same rules as the
rest of /api/v1/*.

```sh
# Initialize the session
curl -s "$BASE/api/v1/mcp" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-06-18",
      "capabilities": {},
      "clientInfo": { "name": "curl", "version": "0.1" }
    }
  }' | jq .
```

```sh
# List available tools
curl -s "$BASE/api/v1/mcp" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | jq '.result.tools | map(.name)'
```

```sh
# Call the high-level `ask` tool
curl -s "$BASE/api/v1/mcp" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 3,
    "method": "tools/call",
    "params": {
      "name": "ask",
      "arguments": {
        "message": "Interstellar is my favorite film, what is the best book?",
        "locale": "en"
      }
    }
  }' | jq '.result.structuredContent'
```

```sh
# Call an atomic tool — search the catalog
curl -s "$BASE/api/v1/mcp" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc":"2.0",
    "id":4,
    "method":"tools/call",
    "params":{"name":"search_items","arguments":{"q":"Inter","limit":3}}
  }' | jq '.result.structuredContent.items'
```

### Claude Desktop configuration

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`
(macOS) or the equivalent path on Windows. The Streamable-HTTP
transport reads the `url` + `headers` block:

```json
{
  "mcpServers": {
    "like-me-like": {
      "url": "https://likemelike.com/api/v1/mcp",
      "headers": {
        "X-LML-Agent-Id": "your-stable-agent-id-here"
      }
    }
  }
}
```

Reuse the same agent id across sessions — the shadow profile builds
up over calls, and free-tier credits are tracked against this id.

### Notifications

JSON-RPC requests without an `id` are notifications and produce no
response body (HTTP 204). Used for client→server signals like
`notifications/initialized` after the handshake.

## Payments (x402 via Coinbase CDP)

Agents start with **10 free calls** per X-LML-Agent-Id. After that,
the agent must hold a positive USD-micro balance — topped up via the
x402 protocol settling USDC on Base.

The flow:

1. Free tier (first 10 calls): no payment, just call.
2. After free tier exhausted: every call is gated by balance.
3. To top up: POST /api/v1/billing/topup. Without an X-Payment
   header you get **HTTP 402 Payment Required** with the
   PaymentRequirements payload (price, asset, network, payTo
   address).
4. Sign a USDC transfer per those requirements, base64-encode the
   payload, retry with `X-Payment: <payload>`. Server verifies +
   settles via the Coinbase CDP facilitator → balance credited.

During the public preview, x402 enforcement may be off — calls
past the free tier are still served while the ledger logs the
would-be-charged amount. Production traffic is gated by balance.

### Who pays — three patterns

The wire-level x402 flow is silent on **who actually holds the
wallet that pays**. Three patterns, in increasing build-cost on
your side:

**A. Integrator absorbs (default).** You (the developer) hold the
wallet. Every end-user call decrements your balance. End-user
monetisation is your decision (free, ad-supported, subscription,
in-app credits) — invisible to us. Use the direct top-up endpoint
below.

**B. Pass-through pricing.** Same wire flow as A — you charge your
end-users in fiat (Stripe, in-app purchase, subscription) and pay
us in USDC. The user-facing billing stack is yours; we don't
facilitate it.

**C-lite. Hosted payment page for end-users with a wallet.** For
end-users who already hold a wallet, you can hand the payment off
entirely. Two payment rails are supported, selectable per challenge
via a `method` field:

- `method: "x402"` (default) — Permit2 signed authorisation on Base
  USDC. The user signs typed-data in their EVM wallet. Stable USD
  pricing.
- `method: "lightning"` — Lightning Network (BOLT11 invoice via
  Alby Hub + NWC). The user scans a QR or taps a `lightning:` URI
  with their Lightning wallet. Sub-second settle, simpler UX for
  Lightning-native users.

**Wallet compatibility table.** Pick the rail that matches your
end-user audience:

| Wallet | x402 method | lightning method |
| --- | --- | --- |
| MetaMask (Mobile / extension) | ✓ | — |
| Rainbow (EOA mode) | ✓ | — |
| Trust Wallet | ✓ | — |
| Coinbase Wallet (legacy / EOA mode) | ✓ | — |
| Hardware wallets via WalletConnect (Ledger, Trezor) | ✓ | — |
| Programmatic agents (viem `privateKeyToAccount`, ethers HD) | ✓ | — |
| Coinbase Smart Wallet / Base Wallet (passkey) | ✗ pending [coinbase/x402#623](https://github.com/coinbase/x402/issues/623) | ✓ |
| Argent / Safe / ZeroDev (ERC-4337) | ✗ pending [coinbase/x402#639](https://github.com/coinbase/x402/issues/639) | ✓ |
| Phoenix / Wallet of Satoshi / Zeus / Strike / Cash App / Alby | — | ✓ |

**Why some wallets are blocked on x402.** Coinbase's hosted x402
facilitator currently rejects EIP-1271 / ERC-6492 wrapped
signatures (used by all Smart Wallets including Coinbase's own).
This is tracked in
[coinbase/x402#623](https://github.com/coinbase/x402/issues/623) —
the facilitator's verify step doesn't unwrap ERC-6492 before
calling `verifyTypedData`. When the upstream fix ships, no client
or server changes are needed on your side; Smart Wallet payments
will start succeeding through the existing Permit2 path. For
consumer Smart Wallet end-users today, use `method: "lightning"`.

The high-level shape is the same in both modes:

1. Bot calls `POST /api/v1/billing/topup/challenge` with the
   amount and (optionally) the `method`.
2. We return `{ challenge_id, link_url, expires_at, … }` plus
   method-specific fields (network/payTo/asset for x402,
   invoice_bolt11/amount_sats for lightning).
3. Bot shows `link_url` (or a QR of it) to the end-user. For
   lightning the page also renders a QR of the BOLT11 directly so
   the user can scan from their wallet without going through our
   page first.
4. End-user pays — either by signing in their EVM wallet (x402)
   or by paying the invoice in their Lightning wallet (lightning).
5. Page detects settlement (synchronous /sign for x402; polling
   our /poll endpoint for lightning) and credits the agent's
   balance.
6. Bot polls `GET /api/v1/billing/topup/status?challenge_id=…`
   until status is `settled`, then retries the original API call.

Walletless end-users (the majority of consumer apps in 2026) need
patterns A or B; on-ramp + hosted billing portal for fully
walletless users is on the roadmap but not shipped.

### Top up — challenge / response

Step 1 — request the challenge (no X-Payment yet):

```sh
curl -s -i "$BASE/api/v1/billing/topup" \
  -X POST \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"amount_usd_micros": 5000000}'   # $5
```

Returns `HTTP/2 402` with body containing `accepts[].asset` (USDC
contract), `accepts[].payTo` (operator wallet), `accepts[].network`
(`eip155:8453` or `eip155:84532`), and `accepts[].maxAmountRequired`
in USDC base units.

Step 2 — construct + sign the USDC transfer payload (your agent's
job; the x402 client SDKs handle this). Then retry:

```sh
curl -s "$BASE/api/v1/billing/topup" \
  -X POST \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "X-Payment: <base64-encoded-signed-payload>" \
  -H "Content-Type: application/json" \
  -d '{"amount_usd_micros": 5000000}'
```

Successful settle returns `{ ok: true, credited_usd_micros, balance_usd_micros, on_chain_tx, network }`.

### Hosted payment page (pattern C-lite)

For end-users who already hold a wallet, you can hand the payment
off to them via a link. Two payment methods supported.

**Step 1 — agent creates a challenge.** Same auth as the rest. Add
`"method": "lightning"` for the Lightning rail; omit (or
`"method": "x402"`) for the default EIP-3009 USDC rail.

x402 (default):

```sh
curl -s "$BASE/api/v1/billing/topup/challenge" \
  -X POST \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"amount_usd_micros": 5000000}'   # $5 in USDC
```

Response:

```json
{
  "challenge_id": "abc123…",
  "method": "x402",
  "link_url": "https://likemelike.com/pay/abc123…",
  "amount_usd_micros": "5000000",
  "pay_to_address": "0x…",
  "network": "eip155:8453",
  "asset_address": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
  "valid_after_unix": "…",
  "valid_before_unix": "…",
  "expires_at": "2026-05-09T17:30:00.000Z",
  "status": "pending"
}
```

Lightning:

```sh
curl -s "$BASE/api/v1/billing/topup/challenge" \
  -X POST \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"amount_usd_micros": 5000000, "method": "lightning"}'
```

Response:

```json
{
  "challenge_id": "abc123…",
  "method": "lightning",
  "link_url": "https://likemelike.com/pay/abc123…",
  "amount_usd_micros": "5000000",
  "amount_sats": 7250,
  "btc_usd_rate": 68965.5,
  "invoice_bolt11": "lnbc7250n1p5…",
  "payment_hash_hex": "abc…",
  "valid_after_unix": "…",
  "valid_before_unix": "…",
  "expires_at": "2026-05-09T17:30:00.000Z",
  "status": "pending"
}
```

`amount_sats` is computed from `amount_usd_micros` at the current
BTC/USD spot rate (Coinbase, cached 30 s). The user pays the
locked sats amount in their Lightning wallet; we credit the locked
USD amount on the agent's balance. Volatility window = invoice
TTL (15 min default).

**Step 2 — show `link_url` to the end-user.** A QR code of the URL
works well for messaging-channel bots; for web bots the URL itself
is enough. Example QR (any QR library):

```js
import QRCode from "qrcode";
const qrSvg = await QRCode.toString(challenge.link_url, { type: "svg" });
```

**Step 3 — end-user pays.**

For x402: the page connects to their EVM wallet (Coinbase Wallet
via in-app browser, MetaMask Mobile via deeplink, Rainbow, browser
extensions), builds the EIP-3009 `TransferWithAuthorization`
typed-data, and the wallet signs. The page POSTs the signed
payload to `/api/v1/billing/topup/sign`.

For Lightning: the page renders a QR of the BOLT11 invoice + a
"Open in wallet" button (`lightning:` URI scheme). The user scans
or taps to pay in their Lightning wallet. The page polls
`/api/v1/billing/topup/poll?challenge_id=…` (no auth) every 2 s
to detect settlement; once Alby reports the invoice paid, the
agent's balance is credited automatically.

No agent action required during this step in either mode.

**Step 4 — bot polls for completion.** Same auth as the rest:

```sh
curl -s "$BASE/api/v1/billing/topup/status?challenge_id=abc123…" \
  -H "X-LML-Agent-Id: $AGENT" | jq .
```

Response:

```json
{
  "challenge_id": "abc123…",
  "status": "pending",
  "amount_usd_micros": "5000000",
  "settled_tx_hash": null,
  "failed_reason": null,
  "expires_at": "2026-05-09T17:30:00.000Z",
  "balance_usd_micros": "0",
  "free_calls_remaining": 0
}
```

`status` transitions: `pending` → `signed` → `settled`. Or
`expired` (challenge timed out without a signature) / `failed`
(verify or settle rejected). Once `settled`, the agent's balance
includes the credited amount and the bot can retry its original
API call.

Poll every 2-3 seconds; challenges expire 15 minutes after
creation. Don't poll for hours — re-create a fresh challenge if
the user takes that long.

### Per-call cost model

Each paid-tier call deducts a **flat $0.05 estimate** from balance
in this version. Actual cost is logged for future reconciliation
against the upstream LLM provider's reported cost. Refunds for
over-charges live in the ledger as manual adjustments by the
operator.

## Browser console testing

POST endpoints can be hit from the browser console too:

```js
const r = await fetch("/api/v1/recommend/scoped", {
  method: "POST",
  headers: {
    "X-LML-Agent-Id": "agent-test-" + Math.random().toString(16).slice(2, 10),
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    item: "Interstellar",
    target_category: "book",
    num_picks: 1,
  }),
});
console.log(await r.json());
```

## Errors

All endpoints surface JSON `{ "error": "<code>", "detail": "..." }`
on validation/auth failures. Streaming `/recommend` produces an
in-stream error event after the sentinel when the provider fails;
shape: `{"type": "error", "message", "errorClass", "userMessage"}`.

Known error codes:

- `missing_agent_id` (401) — header absent
- `invalid_agent_id` (400) — header malformed (length / charset)
- `400` — body validation failure with `detail`
- `404` — item or profile not found
- `502` — provider failure (recommend stream couldn't produce a result)
