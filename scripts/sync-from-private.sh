#!/usr/bin/env bash
# Sync canonical artefacts from the private likemelike repo into this
# public integrations repo.
#
# What gets synced:
#   - docs/agents.md          (curated agent-facing API guide)
#   - docs/openapi.json       (OpenAPI 3.0 spec, extracted from the
#                              live route handler)
#
# What stays local to this repo (never overwritten):
#   - integrations/<platform>/  (per-platform recipes)
#   - examples/                  (worked usage examples)
#   - README.md / LICENSE / .github/
#
# Usage:
#   ./scripts/sync-from-private.sh [path-to-private-repo]
#
# Default private repo path is ../likemelike (sibling clone). Override
# with the first arg or the LML_PRIVATE_REPO env var.

set -euo pipefail

PRIVATE_REPO="${1:-${LML_PRIVATE_REPO:-../likemelike}}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -d "$PRIVATE_REPO" ]]; then
  echo "Private repo not found at: $PRIVATE_REPO" >&2
  echo "Pass the path as the first arg or set LML_PRIVATE_REPO." >&2
  exit 1
fi

PRIVATE_REPO="$(cd "$PRIVATE_REPO" && pwd)"

echo "Syncing from: $PRIVATE_REPO"
echo "Into:         $HERE"
echo

# 1. agents.md — direct copy.
SRC_AGENTS="$PRIVATE_REPO/docs/agents.md"
DST_AGENTS="$HERE/docs/agents.md"
if [[ ! -f "$SRC_AGENTS" ]]; then
  echo "Missing: $SRC_AGENTS" >&2
  exit 1
fi
cp "$SRC_AGENTS" "$DST_AGENTS"
echo "  + docs/agents.md"

# 2. openapi.json — extracted from the route handler.
SRC_ROUTE="$PRIVATE_REPO/src/app/api/v1/openapi/route.ts"
DST_OPENAPI="$HERE/docs/openapi.json"
if [[ ! -f "$SRC_ROUTE" ]]; then
  echo "Missing: $SRC_ROUTE" >&2
  exit 1
fi
node "$HERE/scripts/extract-openapi.mjs" "$SRC_ROUTE" "$DST_OPENAPI"

# 3. Show what changed so the operator can decide whether to commit.
echo
echo "Diff after sync:"
git -C "$HERE" --no-pager diff --stat docs/ || true
echo
echo "Done. Review the diff, then commit + push if everything looks right."
