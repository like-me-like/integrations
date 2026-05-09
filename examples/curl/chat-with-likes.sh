#!/usr/bin/env bash
# Conversational call with cohort matching from liked items.
#
# First call with `liked_items` triggers cohort prep (~10-30 s extra
# latency). Subsequent calls under the same X-LML-Agent-Id reuse
# the now-warm cohort signal and are fast.
#
# Usage:  ./chat-with-likes.sh
# Env:    LML_AGENT_ID — reuse across calls per end-user.

set -euo pipefail

AGENT="${LML_AGENT_ID:-example-$(openssl rand -hex 4)}"
echo "Using X-LML-Agent-Id: $AGENT"

curl -s "https://likemelike.com/api/v1/chat" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Wat moet ik nu lezen? Iets met diepgang maar niet te zwaar.",
    "locale": "nl",
    "display_name": "Sam",
    "liked_items": [
      {"title": "Interstellar", "category": "movie"},
      {"title": "Stoner", "category": "book"},
      {"title": "Past Lives", "category": "movie"}
    ],
    "first_touch": {
      "country": "NL",
      "timezone": "Europe/Amsterdam",
      "device": "mobile",
      "languages": ["nl-NL", "en-US"]
    }
  }' | jq '{reply, recommendations: .recommendations | map({title, type})}'
