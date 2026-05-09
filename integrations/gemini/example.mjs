// Minimal Gemini <-> Like Me Like function-calling loop.
//
// Requires:  npm install @google/genai
// Env:       GEMINI_API_KEY, LML_AGENT_ID (8-256 ASCII chars,
//            reused across calls per end-user)
//
// Run:  node example.mjs "Recommend a book based on Interstellar"

import { GoogleGenAI, Type } from "@google/genai";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const TOOLS_DOC = JSON.parse(readFileSync(join(HERE, "tools.json"), "utf8"));

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const LML_AGENT_ID = process.env.LML_AGENT_ID ?? "demo-agent-001";
const LML_BASE = "https://likemelike.com";

if (!GEMINI_API_KEY) {
  console.error("Set GEMINI_API_KEY in env.");
  process.exit(1);
}

async function callLml(name, args) {
  const headers = {
    "X-LML-Agent-Id": LML_AGENT_ID,
    "Content-Type": "application/json",
  };
  let url;
  if (name === "lml_chat") url = `${LML_BASE}/api/v1/chat`;
  else if (name === "lml_recommend_scoped") url = `${LML_BASE}/api/v1/recommend/scoped`;
  else if (name === "lml_disambiguate") url = `${LML_BASE}/api/v1/disambiguate`;
  else return { error: `unknown tool ${name}` };
  const r = await fetch(url, { method: "POST", headers, body: JSON.stringify(args) });
  if (!r.ok) throw new Error(`${url} ${r.status}: ${await r.text()}`);
  return await r.json();
}

async function main(userMessage) {
  const client = new GoogleGenAI({ apiKey: GEMINI_API_KEY });
  const tools = [{
    functionDeclarations: TOOLS_DOC.tools[0].functionDeclarations,
  }];

  const contents = [{ role: "user", parts: [{ text: userMessage }] }];

  // eslint-disable-next-line no-constant-condition
  while (true) {
    const resp = await client.models.generateContent({
      model: "gemini-2.5-flash",
      contents,
      config: { tools },
    });
    const part = resp.candidates[0].content.parts[0];
    if (part.functionCall) {
      const { name, args } = part.functionCall;
      console.log(`[gemini] calling ${name} with`, args);
      const result = await callLml(name, args);
      contents.push({ role: "model", parts: [{ functionCall: part.functionCall }] });
      contents.push({
        role: "user",
        parts: [{ functionResponse: { name, response: { result } } }],
      });
      continue;
    }
    console.log(part.text ?? resp.text);
    return;
  }
}

main(process.argv.slice(2).join(" ") || "Recommend a book based on Interstellar.");
