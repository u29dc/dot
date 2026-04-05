> Shared operating contract for Claude Code, Codex CLI, and AMP. Use this file for system-wide defaults on communication, tooling, implementation quality, and validation. Let more local `AGENTS.md` files add repo-specific commands, architecture, and constraints.

## 1. Documentation

- Local source of truth: [`agents/AGENTS.md`](AGENTS.md), [`agents/claude.json`](claude.json), [`agents/codex.toml`](codex.toml), [`agents/amp.settings.json`](amp.settings.json)
- Skill procedures live with the named skills: `align`, `compose`, `craft`, `create`, `ship`.
- Canonical templates and repo-alignment references live with the `align` skill.
- Preferred external docs: [Bun](https://bun.sh/docs/llms.txt), [Biome](https://biomejs.dev), [Zod](https://zod.dev/llms.txt), [Svelte](https://svelte.dev/llms.txt), [Next.js](https://nextjs.org/docs/llms.txt), [Vite](https://vite.dev/llms.txt), [Tailwind](https://tailwindcss.com/docs), [shadcn/ui](https://ui.shadcn.com/llms.txt), [Bits UI](https://bits-ui.com/llms.txt), [Convex](https://docs.convex.dev/llms.txt), [Clerk](https://clerk.com/docs/llms.txt), [Rust Book](https://doc.rust-lang.org/book/), [Rust Reference](https://doc.rust-lang.org/reference/), [Cargo Book](https://doc.rust-lang.org/cargo/), [Rust Standard Library](https://doc.rust-lang.org/std/), [Clippy](https://doc.rust-lang.org/clippy/), [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/), [Tokio](https://tokio.rs/tokio/tutorial)
- Prefer `llms.txt`, official docs, and primary sources for technical behavior. Cross-check conflicting claims, cite high-impact recommendations, acknowledge evidence gaps, and state confidence as `high`, `medium`, or `low` when uncertainty remains.

## 2. Scope and Precedence

- Runtime surface usually includes this shared policy file, per-agent runtime settings, and named task-scoped skills.

- This file applies unless an agent-specific or repo-local override says otherwise.
- When rules conflict, prefer `security > correctness > reproducibility > performance > convenience`.
- Repo-level or subtree-level `AGENTS.md` files should define local commands, architecture, runtime state, dangerous paths, and validation. Do not duplicate full template payloads here.
- Normative keywords follow RFC intent: `MUST` required, `SHOULD` default unless a justified exception exists, `MAY` optional, `NEVER` forbidden.
- Default operating principles: context awareness, performance first, clarity over cleverness, consistency with existing patterns, and measurement over preference.

## 3. Communication

- Applies to terminal replies, plans, docs, code comments, commit text, and generated files.
- MUST use the shortest response that fully solves the task. Prefer terse, direct, information-dense phrasing with no wasted words.
- MUST not start with pleasantries, acknowledgements, praise, or conversational filler such as `got it`, `sure`, `happy to help`, `great question`, `done`, or `absolutely` unless the user explicitly asks for that tone.
- MUST not restate the user's request, obvious context, or already-stated constraints unless repetition prevents an error or changes the decision.
- MUST remove filler, motivational prose, rhetorical preambles, weak modifiers, and duplicated guidance. Cut words such as `just`, `really`, `basically`, and `simply` unless they add necessary meaning.
- MUST use imperative language for instructions and explicit statements for facts.
- MUST keep one actionable idea per bullet or sentence. Collapse repetition aggressively.
- MUST prefer short prose over bullets when prose is shorter. Use lists only when content is inherently list-shaped or materially easier to scan that way.
- MUST surface assumptions, constraints, unknowns, and tradeoffs when they affect decisions.
- MUST provide progress updates during long tasks and report measurable outcomes such as files changed, checks run, failures, and residual risk.
- MUST use normal grammar and precise technical wording in persistent artifacts. Terseness means less filler, not clipped or vague writing.
- MUST avoid decorative formatting. Use tables only when they materially improve compression.
- MUST forbid emojis everywhere, including responses, code, docs, scripts, commits, and generated output.
- MUST not compress so aggressively that required caveats, evidence, reasoning, or validation results disappear.
- SHOULD default to `Goal -> Constraints -> Actions -> Validation -> Risks` when a structured response helps.
- SHOULD preserve all constraints when compacting existing text and target meaningful line-count reduction instead of cosmetic rewrites.

## 4. Tooling and Research Defaults

- MUST prefer built-in agent read, search, and edit tools over shell commands when they are sufficient.
- MUST use shell only when built-ins are unavailable, materially slower, or clearly less reliable for the task.
- JavaScript and TypeScript: prefer `bun` over `npm` or `yarn`, `bunx` over `npx`, and keep lockfiles committed.
- Python: prefer `uv` over `pip`, `uvx` for one-off CLIs, and `uv tool install` for persistent tools.
- Lint and format: prefer `biome` over `eslint` or `prettier`.
- Typecheck: prefer `bunx tsgo --noEmit` when `@typescript/native-preview` is configured; otherwise use `bunx tsc --noEmit`. Add framework-specific checks when needed.
- Shell utilities: prefer `eza`, `bat`, `fd`, `rg`, and `sd` over older defaults when available.
- Benchmarking: prefer `hyperfine`.
- Repository analysis: prefer `uvx gitingest -o -` for initial ingestion, then narrow scope with direct reads.
- Git UI preference: `gitui` for staging, `lazygit` for rebase or cherry-pick workflows, `delta` for diffs.
- MUST chain commands with `&&` only when later commands depend on earlier success.
- SHOULD avoid `||` in quality-gate scripts unless intentionally aggregating failure status.
- SHOULD parallelize independent reads and checks when tooling allows.

## 5. Engineering Standards

- Type safety: zero `any`, explicit boundaries, strict mode always.
- Error handling: contextual messages, stable error codes, no internal leakage.
- Validation: sanitize and validate all external input at boundaries.
- Security: least privilege, secrets via environment variables, never commit sensitive data.
- Architecture: clear domain boundaries, single-responsibility modules, predictable naming.
- Default project structure: `src/{app,components,lib,types,utils}` with mirrored `tests/` when the stack fits that model.
- Naming default: lowercase-hyphen files and PascalCase component exports.
- Documentation: JSDoc for exported APIs; comments only for non-obvious logic or invariants.
- Build quality: favor caching, parallel work, tree shaking, and minimal bundle impact where relevant.

## 6. Project and Framework Defaults

- Required baseline files for most JS or TS repositories: `.gitignore`, `package.json`, `tsconfig.json`, `biome.json`, `commitlint.config.js`, `lint-staged.config.js`, and `.husky/*`.
- Default bootstrap flow: framework CLI or `bun init` -> install tooling deps -> add configs -> `bunx husky init` -> add `util:*` scripts -> first commit.
- `package.json` policy: field order `name > version > type > private > workspaces > repository > scripts > devDependencies > dependencies`; keep scripts under `util:*` where appropriate and avoid bare `format` or `lint`.
- Monorepo policy: `workspaces: ["packages/*"]`, workspace dependencies via `workspace:*`, and child `tsconfig` files extending the root.
- TypeScript policy: `ESNext`, bundler resolution, strict flags, `noEmit`, `isolatedModules`, and `verbatimModuleSyntax`.
- Biome policy: extend `~/.config/biome/biome.json` and add Svelte-specific overrides when compiler-driven unused semantics require them.
- Commitlint policy: conventional base, scoped commits, allowed types `feat|fix|refactor|docs|style|chore|test`, lowercase subject, no trailing period, max header and body length `100`.
- Lint-staged policy: trigger the full quality gate through `bun run util:check`.
- SvelteKit: use `vitePreprocess`, alias `@ -> ./src`, and keep strict TypeScript on top of `.svelte-kit/tsconfig.json`.
- Svelte typecheck pipeline: `bunx svelte-kit sync && bunx tsgo --noEmit && bunx svelte-check --tsconfig ./tsconfig.json` when `@typescript/native-preview` is configured; otherwise substitute `bunx tsc --noEmit`.
- Preserve existing compatible variants such as `svelte-check-rs` or custom Svelte tsconfig layouts when the project already depends on them.
- Next.js: use `jsx: preserve`, incremental builds, the Next TypeScript plugin, and Turbopack for development where supported.
- CLI projects: prefer `citty`, keep the TypeScript entrypoint in `src/index.ts`, and keep orchestration in `scripts/` when that structure exists.

## 7. Frontend Standards

- Use the `craft` skill when frontend work needs deeper guidance on interaction, accessibility, motion, layout, or performance.
- Start with design intent: identify user, job-to-be-done, and interaction mood before implementation.
- Avoid generic AI-default UI. Choose deliberate typography, color direction, and motion language.
- Motion defaults: `150-200ms` standard duration, `300ms` max, button press `scale(0.97)`, entry scale at least `0.96`, and animate `transform` plus `opacity` only.
- Motion constraints: no animation for frequent keyboard-driven actions, no `transition: all`, and no layout-property animation.
- Easing defaults: `cubic-bezier(0.16, 1, 0.3, 1)` for ease-out and `cubic-bezier(0.34, 1.56, 0.64, 1)` for spring-like motion.
- Accessibility and touch: minimum touch target `44px`, minimum input text `16px`, hover styles gated by `@media (hover: hover)`, and robust ARIA labels and state handling.
- Respect `prefers-reduced-motion` with reduced or disabled alternatives.
- Interaction rules: labels focus inputs, `Enter` submits forms, submitting states disable repeat actions, optimistic updates require rollback paths, and clickable regions must not contain dead zones.
- Visual quality: use tabular numerals for numeric UI, preserve border radius on focus rings, and avoid theme-transition flashes.

## 8. Execution, Constraints, and Validation

- Execute one scoped task at a time. Keep boundaries explicit and validate each meaningful change before widening scope.
- Review mode defaults to findings first: prioritize bugs, regressions, missing tests, and operational risk before summaries.
- Root-cause analysis should follow `symptom -> immediate cause -> contributing factors -> 5-whys root cause -> fix validation -> recurrence prevention`.
- NEVER invent facts, citations, test results, command output, or evidence.
- NEVER rewrite large files, configs, or generated artifacts when a smaller, reviewable edit will preserve more valid intent.
- NEVER commit secrets, credentials, private tokens, or personal runtime state.
- Treat deploy config, infrastructure code, billing paths, auth flows, `~/.ssh`, `.github/workflows`, migrations, and irreversible write paths as high risk. Run extra validation when they change.
- Required completion bar: zero type errors, zero linter warnings, passing tests when present, and a successful production build when the repo has one.
- Manual QA minimum: config variants, invalid input paths, empty states, limits, and concurrency-sensitive behavior.
- If automated checks are absent, partial, or intentionally skipped, say so explicitly and describe the residual risk.
- Git hygiene: no generated artifacts in commits unless the repo intentionally tracks them, and commit headers should follow `type(scope): subject` with lowercase subjects and no trailing period.

## 9. Skills and Canonical References

- Skill selection rule: when a request explicitly names a skill or clearly matches a skill scope, use the minimal set of relevant skills and state the sequence when multiple skills apply.
- `align`: project bootstrap, config drift correction, template alignment, and quality-gate baseline enforcement.
- `compose`: CLI or tooling design that requires agent-native primitives, capability discovery, and JSON contracts.
- `craft`: frontend UI and UX implementation or review with accessibility, motion, layout, and performance requirements.
- `create`: local skill creation or updates with required frontmatter, structure, and compact operational guidance.
- `ship`: deterministic commit batching, commitlint-compliant messaging, and repository-specific pull-request or release flow.
- Canonical template reference: use the `align` skill references.
- Remote fallback: the `align` references in the `u29dc/dot` repository.
- This file is the shared policy layer. The `align` skill owns repo-level template instantiation and project-specific conformance.
