# Contributing

Thanks for considering a contribution. This repo collects
integration recipes for [Like Me Like](https://likemelike.com)
across AI agent platforms, chat apps, and developer toolchains.

## What we accept

- **New platform recipes.** If your favourite agent platform isn't
  in [`integrations/`](../integrations/), open a PR with a folder
  containing at minimum a `README.md` and a working manifest /
  config snippet. Match the structure of an existing folder
  (e.g. [`integrations/openclaw/`](../integrations/openclaw/)).
- **Improvements to existing recipes.** Found a stale config field?
  An undocumented gotcha? A cleaner example? PRs welcome.
- **More worked examples.** Add a script under
  [`examples/<lang>/`](../examples/) that demonstrates a real
  pattern, not just the absolute minimum.
- **Issue reports** for bugs, broken examples, or platforms that
  ship breaking config changes.

## What we don't merge

- **Changes to the API surface itself** (`docs/agents.md`,
  `docs/openapi.json`). These files are generated from the upstream
  private repo. Open an issue describing the API change you want;
  we'll route it to the upstream backlog.
- **Marketing copy or rewrites of the main README** that don't
  add information.
- **Dependencies for the sake of dependencies.** The example
  scripts deliberately stay minimal — don't add a framework when a
  10-line `fetch` works.

## Pull request process

1. Fork + branch off `main`.
2. Match the conventions of the closest existing file. Two-space
   indentation in YAML/JSON, consistent header levels in
   markdown, no emojis in committed files.
3. Test what you ship. If you're adding a curl example, run it.
   If you're adding a Node example, `node example.mjs` should
   exit 0 with a real reply.
4. Run the leak audit before opening the PR:
   ```bash
   bash scripts/check-stack-leaks.sh
   ```
   The maintainers' Like Me Like stack (the chat brain, the
   recommendation engine, infra vendors) stays out of this repo
   by policy. The script flags accidental references. Platform-
   eigen model names (e.g. `gemini-2.5-flash`,
   `grok-2-latest`) are exempt inside their own
   `integrations/<platform>/` folder where they belong.
5. Open the PR with a clear "what" and "why". Screenshots help
   for UI-heavy platforms (Claude Desktop, ChatGPT GPT editor).
6. We review and merge based on quality and fit. Not every PR
   will land — sometimes a recipe overlaps with an existing one,
   or a platform is too niche to maintain. We'll explain the
   reasoning either way.

## License

By contributing, you agree your contribution is licensed under the
[MIT License](../LICENSE).

## Code of conduct

Be civil. Be concrete. Disagree with ideas, not people. We'll
remove anyone who can't manage that.
