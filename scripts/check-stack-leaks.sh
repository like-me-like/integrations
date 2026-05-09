#!/usr/bin/env bash
# Public-repo leak check — for files authored directly in this
# repo (integrations/, examples/, README, .github/, scripts/, top
# docs/ that AREN'T sync-mirrored).
#
# Sister script to the upstream `scripts/check-public-leaks.sh` in
# the private likemelike repo. That one scans the FOUR mirrored
# files; this one scans everything else in the public repo.
#
# What this guards against: an author-written file in this repo
# accidentally revealing the internal Like Me Like stack — model
# choices, infra vendors, operator details, or internal pricing.
#
# Platform-supplied model names that legitimately appear inside a
# specific integration folder (e.g. `gemini-2.5-flash` inside
# integrations/gemini/, `grok-2-latest` inside integrations/grok/)
# are NOT flagged — those are what the developer calls on their
# own platform and must stay correct.
#
# Run before opening a PR or pushing a public-side change:
#
#   bash scripts/check-stack-leaks.sh
#
# Exits non-zero on any hit.

set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE"

EXIT=0
HITS=()

# ----------------------------------------------------------------
# scan_pattern <regex> <category-label> [exclude-path-regex]
# ----------------------------------------------------------------
# Scans every text file in the repo (md / sh / mjs / js / py / json
# / yaml / yml / ts) for the regex. If exclude-path-regex is given,
# files whose path matches it are skipped — used for legitimate
# platform-supplied model names that only appear inside their own
# integration folder.
#
# // line comments are exempt (they don't ship via any client
# response). Only string-literal content + prose is scanned.
# ----------------------------------------------------------------
scan_pattern() {
  local pattern="$1"
  local label="$2"
  local exclude_path="${3:-}"

  local files
  files=$(find . -type f \
    \( -name "*.md" -o -name "*.sh" -o -name "*.mjs" -o -name "*.js" \
       -o -name "*.py" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" \
       -o -name "*.ts" \) \
    -not -path "./.git/*" \
    -not -path "./node_modules/*" \
    -not -path "./scripts/check-stack-leaks.sh" \
    | sort)

  if [[ -n "$exclude_path" ]]; then
    files=$(echo "$files" | grep -vE "$exclude_path" || true)
  fi

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    # Strip pure // line comments before scanning so source comments
    # don't trigger hits. (We don't process /* ... */ blocks since
    # this repo's TS files don't use them in description content.)
    matches=$(grep -niE "$pattern" "$file" 2>/dev/null \
              | grep -vE '^[0-9]+:[[:space:]]*//' || true)
    if [[ -n "$matches" ]]; then
      while IFS= read -r line; do
        HITS+=("${file#./} [${label}] ${line}")
      done <<< "$matches"
      EXIT=1
    fi
  done <<< "$files"
}

# ============================================================
# Patterns — internal stack revelations
# ============================================================

# Internal Anthropic model usage. Model IDs and branded names.
# We never reference Anthropic models by version anywhere in
# public content — even the Claude Desktop / Claude Skill recipes
# only name "Claude" as the platform.
scan_pattern 'claude-(sonnet|haiku|opus)-' "internal Anthropic model id"
scan_pattern '\b(Sonnet|Haiku|Opus)[[:space:]]*[0-9]' "internal Anthropic model name"

# Internal Google model usage. The recommendation engine uses
# Gemini Flash Lite — public examples that legitimately call
# `gemini-2.5-flash` (without "Lite") sit inside
# integrations/gemini/ and are exempt via path filter.
scan_pattern 'Gemini Flash Lite|gemini-flash-lite|gemini-[0-9.]+-flash-lite' "internal recommendation model"

# Internal benchmark candidates / alternatives.
scan_pattern '\bDeepSeek\b|deepseek-v[0-9]' "internal benchmarked model"
scan_pattern '\bMistral Large\b|mistral-large' "internal benchmarked model"
scan_pattern '\bQwen[0-9]?-Max\b|qwen[0-9]?-max' "internal benchmarked model"

# Internal LLM routing / aggregation layer.
scan_pattern '\bOpenRouter\b|openrouter\.ai' "internal LLM routing layer"

# Internal infrastructure vendors that reveal stack topology.
scan_pattern '\bSupabase\b|supabase\.com' "internal DB vendor"
scan_pattern '\bUpstash\b|upstash\.com' "internal Redis vendor"
scan_pattern '\bCloudflare\b|cloudflare\.com' "internal DNS / edge vendor"
scan_pattern 'pgvector|pgbouncer' "internal Postgres extensions"
scan_pattern '\bHDBSCAN\b|hdbscan' "internal clustering algorithm"

# Internal pricing / benchmark cost values that leak per-call
# economics.
scan_pattern '\$0\.13[^[:digit:]]|\$0\.119|\$0\.024' "internal per-call cost"

# Personal / operator identifiers.
scan_pattern '\byme\b|ymebosma|yme\.bosma' "personal name"
scan_pattern 'likemelike-git-[a-z]+|[a-z0-9-]+-yme-bosmas-projects\.vercel\.app' "dev preview / legacy host"

# Operator env vars / secrets / wallet addresses.
scan_pattern 'LML_X402_ENFORCE|CDP_API_KEY_(ID|SECRET)|X402_PAY_TO_ADDRESS|LML_ADMIN_TOKEN|X402_FACILITATOR_URL|LML_X402_TOPUP_AMOUNTS' "operator env-var"

# Internal spec / planning references.
scan_pattern 'PLAN §|\bstap [0-9]' "internal spec / planning ref"

# Stale stack mentions (we use Coinbase CDP, not Stripe).
scan_pattern 'Stripe Machine Payments|Stripe MP' "stale payment-stack reference"

# Common Dutch test-message tells.
scan_pattern 'lievelingsfilm|Wat moet ik|wat is het beste|geef me een|wat ik nu kan' "Dutch test content"

# ============================================================
# Path-filtered patterns — platform-eigen model names that ARE
# legitimate, but only inside their own integration folder.
# ============================================================
#
# We only flag these when they appear OUTSIDE the matching
# integration folder. Inside, they're correct (the developer
# needs to know which model to call on their platform).

# `gemini-2.5-flash` (or any gemini-N-flash) is fine inside
# integrations/gemini/, anywhere else it's noise/leak.
scan_pattern 'gemini-[0-9.]+-flash\b' "Gemini model id outside its integration folder" 'integrations/gemini/'

# Grok models are fine inside integrations/grok/.
scan_pattern '\bgrok-[0-9](-[a-z]+)*\b' "Grok model id outside its integration folder" 'integrations/grok/'

# ============================================================
# Result
# ============================================================

if (( EXIT == 0 )); then
  echo "✓ Public repo clean — no internal-stack or operator references"
  echo "  in author-controlled files."
  exit 0
fi

echo
echo "✗ Public-repo leak check FAILED. The following content reveals" >&2
echo "  internal Like Me Like stack, operator details, or stale refs:" >&2
echo >&2
printf '  %s\n' "${HITS[@]}" >&2
echo >&2
echo "Either rephrase model-agnostically, move the explanation into" >&2
echo "a // source comment (TS files only), or move the file to the" >&2
echo "private repo if it shouldn't be public at all." >&2
exit 1
