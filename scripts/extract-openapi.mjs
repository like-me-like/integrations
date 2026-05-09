// Extract the OpenAPI SPEC constant from the private repo's
// route file as canonical JSON. Used by sync-from-private.sh.
//
// Usage: node scripts/extract-openapi.mjs <path-to-route.ts> <output.json>
//
// We don't import the TS file (it's an ESM/Next module that pulls
// in too much). Instead we extract the SPEC = { ... } literal via a
// regex + a tiny `eval`-in-vm-context trick. Safe because the file
// is committed in the private repo and we control it.

import { readFileSync, writeFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { argv, exit } from "node:process";

const [, , routeTsPath, outJsonPath] = argv;
if (!routeTsPath || !outJsonPath) {
  console.error("usage: node extract-openapi.mjs <route.ts> <out.json>");
  exit(1);
}

const src = readFileSync(routeTsPath, "utf8");

// The route file declares two top-level constants we need:
//   const AGENT_AUTH = { ... } as const;
//   const SPEC = { ... } as const;
// SPEC references AGENT_AUTH, so we extract both and eval them in
// the same VM context so the reference resolves.
const authMatch = src.match(/const AGENT_AUTH =\s*({[\s\S]*?})\s*as const;/);
const specMatch = src.match(/const SPEC =\s*({[\s\S]*?})\s*as const;/);
if (!authMatch || !specMatch) {
  console.error(
    "Could not locate AGENT_AUTH and/or SPEC literals in",
    routeTsPath,
  );
  exit(1);
}

let spec;
try {
  // Strip TypeScript-only syntax that the JS VM can't parse:
  //   - `as const` — already gone via the regex
  //   - `satisfies T` — strip
  //   - inline type annotations on object keys — none in this file
  const stripTs = (s) => s.replace(/\s+satisfies\s+[\w<>,.\s|&[\]]+/g, "");
  const program = `
    const AGENT_AUTH = ${stripTs(authMatch[1])};
    const SPEC = ${stripTs(specMatch[1])};
    SPEC;
  `;
  spec = runInNewContext(program, {}, { timeout: 2000 });
} catch (err) {
  console.error("Failed to evaluate SPEC literal:", err.message);
  exit(1);
}

writeFileSync(outJsonPath, JSON.stringify(spec, null, 2) + "\n", "utf8");
console.log(`Wrote ${outJsonPath}`);
