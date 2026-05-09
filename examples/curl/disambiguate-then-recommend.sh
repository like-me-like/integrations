#!/usr/bin/env bash
# Two-step pattern: disambiguate first, then recommend.
#
# "Dune" could mean the 1965 novel, the 2021 film, the 1984 film,
# or the video game. Disambiguate first to pick the right one,
# then drive recommend with that context.

set -euo pipefail

AGENT="${LML_AGENT_ID:-example-$(openssl rand -hex 4)}"

echo "=== Step 1: disambiguate ==="
curl -s "https://likemelike.com/api/v1/disambiguate" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"query": "Dune", "category_hint": "movie", "limit": 5}' | jq '.candidates[] | {title, category, anchor_culture, confidence}'

echo
echo "=== Step 2: recommend a book based on the 2021 film ==="
curl -s "https://likemelike.com/api/v1/recommend/scoped" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{"item": "Dune (2021 film)", "target_category": "book", "locale": "en"}' | jq .
