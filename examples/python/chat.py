"""Minimal Python example.

Requires:  pip install requests
Env:       LML_AGENT_ID (defaults to a random demo id)

Run:       python chat.py
"""

import os
import secrets
import sys

import requests

AGENT = os.environ.get("LML_AGENT_ID", f"example-{secrets.token_hex(4)}")
BASE = "https://www.likemelike.com"


def main() -> int:
    body = {
        "message": "Recommend me a book based on Interstellar.",
        "locale": "en",
        "display_name": "Sam",
        "liked_items": [
            {"title": "Interstellar", "category": "movie"},
            {"title": "Stoner", "category": "book"},
        ],
    }
    r = requests.post(
        f"{BASE}/api/v1/chat",
        headers={"X-LML-Agent-Id": AGENT, "Content-Type": "application/json"},
        json=body,
        timeout=120,
    )
    if not r.ok:
        print(f"HTTP {r.status_code}: {r.text}", file=sys.stderr)
        return 1

    data = r.json()
    print("Reply:", data["reply"])
    print("Recommendations:")
    for rec in data.get("recommendations", []):
        print(f"  - {rec['title']} ({rec['type']}) — {rec.get('reason', '')}")
    print(f"Latency: {data.get('latency_ms')} ms")
    return 0


if __name__ == "__main__":
    sys.exit(main())
