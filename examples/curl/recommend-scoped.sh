#!/usr/bin/env bash
# One book recommendation based on a film.
#
# Usage:  ./recommend-scoped.sh
# Env:    LML_AGENT_ID (defaults to a random demo id)

set -euo pipefail

AGENT="${LML_AGENT_ID:-example-$(openssl rand -hex 4)}"

curl -s "https://www.likemelike.com/api/v1/recommend/scoped" \
  -H "X-LML-Agent-Id: $AGENT" \
  -H "Content-Type: application/json" \
  -d '{
    "item": "Interstellar",
    "target_category": "book",
    "num_picks": 1,
    "locale": "en"
  }' | jq .
