// Minimal Grok <-> Like Me Like function-calling loop.
//
// Grok's API is OpenAI-compatible — we use the openai SDK pointed
// at https://api.x.ai/v1.
//
// Requires:  npm install openai
// Env:       XAI_API_KEY, LML_AGENT_ID
//
// Run:  node example.mjs "Recommend a book based on Interstellar"

import OpenAI from "openai";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const TOOLS_DOC = JSON.parse(readFileSync(join(HERE, "tools.json"), "utf8"));

const XAI_API_KEY = process.env.XAI_API_KEY;
const LML_AGENT_ID = process.env.LML_AGENT_ID ?? "demo-agent-001";
const LML_BASE = "https://www.likemelike.com";

if (!XAI_API_KEY) {
  console.error("Set XAI_API_KEY in env.");
  process.exit(1);
}

const grok = new OpenAI({
  apiKey: XAI_API_KEY,
  baseURL: "https://api.x.ai/v1",
});

async function callLml(name, args) {
  const headers = {
    "X-LML-Agent-Id": LML_AGENT_ID,
    "Content-Type": "application/json",
  };
  let url;
  if (name === "lml_chat") url = `${LML_BASE}/api/v1/chat`;
  else if (name === "lml_recommend_scoped") url = `${LML_BASE}/api/v1/recommend/scoped`;
  else if (name === "lml_disambiguate") url = `${LML_BASE}/api/v1/disambiguate`;
  else if (name === "lml_query_items") url = `${LML_BASE}/api/v1/item/query`;
  else if (name === "lml_get_popular") url = `${LML_BASE}/api/v1/popular`;
  else return { error: `unknown tool ${name}` };
  const r = await fetch(url, { method: "POST", headers, body: JSON.stringify(args) });
  if (!r.ok) throw new Error(`${url} ${r.status}: ${await r.text()}`);
  return await r.json();
}

async function main(userMessage) {
  const messages = [{ role: "user", content: userMessage }];

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const resp = await grok.chat.completions.create({
      model: "grok-2-latest",
      messages,
      tools: TOOLS_DOC.tools,
    });
    const msg = resp.choices[0].message;
    if (msg.tool_calls?.length) {
      messages.push(msg);
      for (const tc of msg.tool_calls) {
        const args = JSON.parse(tc.function.arguments);
        console.log(`[grok] calling ${tc.function.name} with`, args);
        const result = await callLml(tc.function.name, args);
        messages.push({
          role: "tool",
          tool_call_id: tc.id,
          content: JSON.stringify(result),
        });
      }
      continue;
    }
    console.log(msg.content);
    return;
  }
}

main(process.argv.slice(2).join(" ") || "Recommend a book based on Interstellar.");
