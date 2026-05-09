"""Minimal Gemini ↔ Like Me Like function-calling loop.

Requires:
    pip install google-genai requests

Set GEMINI_API_KEY in the environment, plus an LML_AGENT_ID for the
end-user identifier (8-256 ASCII chars; reuse across calls).

Run:
    python example.py "Interstellar is my favorite film — give me a book"
"""

import json
import os
import sys

import requests
from google import genai
from google.genai import types

GEMINI_API_KEY = os.environ["GEMINI_API_KEY"]
LML_AGENT_ID = os.environ.get("LML_AGENT_ID", "demo-agent-001")
LML_BASE = "https://likemelike.com"

# Load function declarations from the shipped manifest.
with open(os.path.join(os.path.dirname(__file__), "tools.json")) as f:
    TOOLS_DOC = json.load(f)


def call_lml(name: str, args: dict) -> dict:
    """Dispatch a function call from Gemini to the Like Me Like API."""
    headers = {
        "X-LML-Agent-Id": LML_AGENT_ID,
        "Content-Type": "application/json",
    }
    if name == "lml_chat":
        r = requests.post(f"{LML_BASE}/api/v1/chat", headers=headers, json=args, timeout=120)
    elif name == "lml_recommend_scoped":
        r = requests.post(f"{LML_BASE}/api/v1/recommend/scoped", headers=headers, json=args, timeout=120)
    elif name == "lml_disambiguate":
        r = requests.post(f"{LML_BASE}/api/v1/disambiguate", headers=headers, json=args, timeout=30)
    else:
        return {"error": f"unknown tool {name}"}
    r.raise_for_status()
    return r.json()


def main(user_message: str) -> None:
    client = genai.Client(api_key=GEMINI_API_KEY)

    # Re-shape the JSON declarations into the SDK's tool object.
    tools = [
        types.Tool(function_declarations=TOOLS_DOC["tools"][0]["functionDeclarations"])
    ]

    contents = [{"role": "user", "parts": [{"text": user_message}]}]

    while True:
        resp = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=contents,
            config=types.GenerateContentConfig(tools=tools),
        )
        part = resp.candidates[0].content.parts[0]
        if hasattr(part, "function_call") and part.function_call:
            fc = part.function_call
            print(f"[gemini] calling {fc.name} with {dict(fc.args)}")
            result = call_lml(fc.name, dict(fc.args))
            contents.append({"role": "model", "parts": [{"function_call": fc}]})
            contents.append({
                "role": "user",
                "parts": [{
                    "function_response": {"name": fc.name, "response": {"result": result}}
                }],
            })
            continue
        # Final natural-language reply.
        print(part.text or resp.text)
        return


if __name__ == "__main__":
    main(" ".join(sys.argv[1:]) or "Recommend me a book based on Interstellar.")
