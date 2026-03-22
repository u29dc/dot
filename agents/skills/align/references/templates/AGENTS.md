<!--
Canonical template for repo-level agent instructions.

Use this file to instantiate a repository's root `AGENTS.md`.

Authoring rules:
- `AGENTS.md` is the canonical agent instruction file. `CLAUDE.md` may mirror or symlink to it when a tool expects that filename. `README.md` should stay human-facing by default.
- Keep the instantiated root file focused on repo-wide guidance that applies to most tasks.
- Target 80-150 lines for most repositories. Split or link out if the file would exceed 200 lines.
- Use numbered H2 sections only. Do not add an H1.
- Prefer flat bullets. Avoid nested bullets unless compression is clearly better.
- Prefer links to authoritative docs or source files over copied snippets.
- Use one shallow ASCII tree only when it materially improves navigation.
- Use one stack table only when the stack is mixed or non-obvious.
- Omit sections that do not add signal. Do not leave placeholder text in generated repo docs.
- Move subtree-specific rules into nested `AGENTS.md` files or linked docs close to the code.
- Keep style or formatting rules out of this file when deterministic tooling already enforces them.
- Do not include long history, marketing copy, file-by-file descriptions, stale command catalogs, or exact counts that drift.
- Typography: use Markdown links for external docs and local files, with code-formatted labels for repo paths (for example [`src/cli.rs`](src/cli.rs)); wrap commands, paths, env vars, flags, identifiers, and contract names in backticks; avoid italics for routine labels.

Content priority:
- Highest signal: commands, validation, dangerous paths, generated files, config/runtime state, non-obvious architectural boundaries, source-of-truth docs.
- Lower signal: obvious language conventions, generic style advice, broad background, rare workflows.
-->

> `example` is a Rust CLI and local service that validates input files, syncs records to a remote API, and exposes a small JSON-first command surface for automation.

## 1. Documentation

- Primary references: [Framework docs](https://framework.example.dev/docs), [API reference](https://api.example.dev/reference), [Runtime guide](https://runtime.example.dev/guide)
- Local source-of-truth files: [`src/cli.rs`](src/cli.rs), [`src/tool_registry.rs`](src/tool_registry.rs), [`docs/architecture.md`](docs/architecture.md)
- Nested agent docs or subsystem guides: [`apps/web/AGENTS.md`](apps/web/AGENTS.md) for frontend work, [`docs/deploy.md`](docs/deploy.md) for release workflow
- Keep this section curated. Include only the docs an agent repeatedly needs to orient, preserve contracts, or avoid mistakes.

## 2. Repository Structure

```text
.
├── src/
│   ├── commands/            thin CLI entrypoints
│   ├── domain/              core business logic and validation
│   ├── infra/               API, DB, and filesystem adapters
│   └── main.rs              process entrypoint
├── tests/                   integration and contract tests
├── scripts/                 build, release, and codegen helpers
├── docs/                    deeper architecture and runbooks
└── AGENTS.md                canonical repo-level agent instructions
```

- Start in [`src/commands/`](src/commands/) for new command surfaces and [`src/domain/`](src/domain/) for behavior changes
- Update [`src/tool_registry.rs`](src/tool_registry.rs) when the command surface, schema, or tool metadata changes
- Treat [`src/generated/`](src/generated/) and [`openapi.json`](openapi.json) as generated; regenerate instead of editing by hand
- Keep the tree shallow. Prefer hotspot bullets over deep listings.

## 3. Stack

| Layer | Choice | Notes |
| --- | --- | --- |
| Runtime | Rust 2024 + `tokio` | workspace with strict lints and async services |
| CLI | `clap` | JSON-first non-interactive command surface |
| Storage | SQLite via `rusqlite` | local state under `~/.tools/example/` |
| Validation | `cargo test`, `cargo clippy`, `bun run util:check` | required before completion |
| Release | Bun wrapper around Cargo | installs release artifacts to a local tools directory |

<!--
Omit this section if the repository is small and the stack is obvious from the commands plus structure.
-->

## 4. Commands

- `bun install` - install hooks, JS tooling, and local helper scripts
- `cargo run -p example-cli -- --help` - iterate on the CLI locally
- `cargo build --workspace --release` - build the main artifacts
- `cargo test --workspace` - run unit and integration tests
- `bun run util:check` - run the full quality gate before completion
- `bun run release` - package and install the release build

- Group commands by operator intent, not by raw script inventory.
- Keep this section short. Include only commands agents need repeatedly.

## 5. Architecture

- [`src/main.rs`](src/main.rs): parses CLI input, initializes config, and dispatches subcommands
- [`src/commands/`](src/commands/): thin adapters over domain services; keep business logic out of this layer
- [`src/domain/`](src/domain/): core business rules, validation, and orchestration
- [`src/infra/`](src/infra/): persistence, remote API clients, and filesystem adapters
- Contract: non-interactive commands emit one JSON object to stdout; logs and diagnostics go to stderr
- Preserve the boundary `commands -> domain -> infra`; do not let domain code depend on CLI formatting

- Focus on boundaries, ownership, and invariants.
- Do not turn this section into a full architecture essay.

<!--
Include this section when environment quirks, config precedence, runtime state, or generated artifacts are frequent sources of failure.
Omit it when the repo is stateless or the details are already obvious from code and commands.
-->

## 6. Runtime and State

- Config precedence: CLI flags -> env vars -> `config.toml` -> built-in defaults
- Runtime directories or files: `~/.tools/example/config.toml`, `~/.tools/example/example.db`
- Generated artifacts: [`src/generated/schema.rs`](src/generated/schema.rs) regenerated by `bun run codegen`
- External state or services: `Example API` for remote sync, `S3` bucket for staged uploads
- Environment variables that materially affect behavior: `EXAMPLE_API_TOKEN`, `EXAMPLE_HOME`, `DATABASE_URL`

- Keep this section limited to state an agent would not reliably infer from the code alone.

<!--
Include this section only for non-obvious local conventions that differ from common defaults.
If lint, format, or codegen tooling already enforces a rule, prefer the tool over prose.
-->

## 7. Conventions

- Imports / aliases: use `@/` for application imports; keep same-directory relative imports only for generated types
- Naming / file layout: keep command modules thin and move business logic into [`src/domain/`](src/domain/)
- Output / envelope / API contract: public responses use `{ ok, data | error, meta }`
- Generated code, migrations, or schema updates must also update [`src/tool_registry.rs`](src/tool_registry.rs) and [`docs/cli.md`](docs/cli.md)
- Commit / review / release convention: use scoped Conventional Commits like `feat(cli): add sync dry-run` when repo policy requires it

## 8. Constraints

- Never edit [`src/generated/`](src/generated/) or [`openapi.json`](openapi.json) by hand; regenerate with `bun run codegen`
- Never commit `.env`, local databases, fixture outputs, or personal runtime data from `tmp/` or `data/`
- Treat [`migrations/`](migrations/), [`infra/terraform/`](infra/terraform/), and [`.github/workflows/`](.github/workflows/) as high risk; run extra validation when they change
- Writes to live services require `--dry-run` first and an explicit write flag like `--apply` or `--allow-writes`
- Respect secrets handling, rate limits, protected paths like `~/.ssh`, and any repo-local safety script or hook

- Be explicit about dangerous paths, protected files, live systems, rate limits, and non-reversible operations.
- If a risk is enforced mechanically elsewhere, say so briefly and point to the source of enforcement.

## 9. Validation

- Required gate: `bun run util:check`
- Required targeted checks when changing CLI or schema code: `cargo test --workspace -- cli:: schema::`
- Manual smoke check: run `example sync --dry-run` and verify one success path plus one failure path
- If you change the command surface, registry, schema, or generated outputs, also update [`src/tool_registry.rs`](src/tool_registry.rs), [`docs/cli.md`](docs/cli.md), or regenerated artifacts as needed
- State the repo-specific completion bar clearly if automated tests are absent or partial

- Define "done" in repo terms.
- Prefer deterministic validation over prose-only review guidance.

<!--
Use this section for deeper docs or subtree-specific guidance that should not live in the root file.
Prefer short descriptions plus links. Omit the section if the repo is small and self-contained.
-->

## 10. Further Reading

- [`docs/architecture.md`](docs/architecture.md) - deeper domain model and dependency rules
- [`docs/deploy.md`](docs/deploy.md) - release, packaging, and environment rollout steps
- [`apps/web/AGENTS.md`](apps/web/AGENTS.md) - frontend-specific conventions and validation
