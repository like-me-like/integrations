// Minimal Node example. Native fetch (Node 18+); no deps.
//
// Run:
//   LML_AGENT_ID=my-stable-id node chat.mjs

const AGENT = process.env.LML_AGENT_ID ?? `example-${Math.random().toString(16).slice(2, 10)}`;
const BASE = "https://likemelike.com";

const body = {
  message: "Recommend me a book based on Interstellar.",
  locale: "en",
  display_name: "Sam",
  liked_items: [
    { title: "Interstellar", category: "movie" },
    { title: "Stoner", category: "book" },
  ],
};

const r = await fetch(`${BASE}/api/v1/chat`, {
  method: "POST",
  headers: {
    "X-LML-Agent-Id": AGENT,
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
});

if (!r.ok) {
  console.error(`HTTP ${r.status}:`, await r.text());
  process.exit(1);
}

const data = await r.json();
console.log("Reply:", data.reply);
console.log("Recommendations:");
for (const rec of data.recommendations ?? []) {
  console.log(`  - ${rec.title} (${rec.type}) — ${rec.reason ?? ""}`);
}
console.log(`Latency: ${data.latency_ms} ms`);
