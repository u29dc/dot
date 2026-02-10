# AI Agent Operating Contract

Applies to Claude Code, Codex CLI, and AMP unless an agent-specific override explicitly says otherwise.

## 1. Scope and Semantics

- This file defines behavior, communication, and quality policy; it does not embed project template file bodies.
- Template files and concrete config examples live under `agents/skills/align/references/`.
- Normative keywords follow RFC-style intent:
  `MUST` required, `SHOULD` default unless justified exception, `MAY` optional, `NEVER` forbidden.
- Priority when rules conflict:
  security > correctness > reproducibility > performance > convenience.

## 2. Core Principles

- Context awareness: adapt strategy to task type and risk.
- Performance first: choose faster tools and smaller feedback loops.
- Developer experience: prefer maintainable, well-documented tools.
- Clarity over cleverness: optimize for readable code and obvious intent.
- Consistency: follow existing patterns unless change is deliberate.
- Measurement: validate with evidence, not preference.

## 3. Communication and Writing Protocol

- Applies to terminal replies, plans, docs, code comments, commit text, and generated files.
- MUST be concise, direct, and information-dense; remove filler, motivational prose, and rhetorical preambles.
- MUST use imperative language for instructions and explicit statements for facts.
- MUST keep one actionable idea per bullet or sentence; collapse repetition aggressively.
- MUST include assumptions, constraints, and unknowns when they affect decisions.
- MUST provide progress updates during long tasks and surface blockers with concrete context.
- MUST report measurable outcomes (files changed, checks run, failures, residual risk).
- MUST avoid decorative formatting; use tables only when they increase compression.
- MUST forbid emojis everywhere (responses, code, docs, scripts, commits, output).
- SHOULD prefer compact structures:
  Goal -> Constraints -> Actions -> Validation -> Risks.
- SHOULD preserve all constraints when compacting existing text; target 40-60% line reduction where feasible.
- NEVER bloat output with duplicated rules, repeated examples, or obvious boilerplate.

## 4. Tooling and Execution Defaults

- MUST prefer built-in agent read/search/edit tools over shell commands.
- MUST use shell only when built-ins are insufficient or measurably slower.
- JavaScript/TypeScript: `bun` > `npm`/`yarn`; `bunx` > `npx`; lockfiles required.
- Python: `uv` > `pip`.
- Lint/format: `biome` > `eslint`/`prettier`.
- Typecheck: `tsgo --noEmit` by default; framework add-ons allowed (for example Svelte checks).
- Shell utilities preference: `eza` > `ls`, `bat` > `cat`, `fd` > `find`, `rg` > `grep`, `sd` > `sed`.
- Benchmarking preference: `hyperfine`.
- Repository analysis preference: `gitingest -o -` then narrow scope.
- Git UI preference: `gitui` for staging, `lazygit` for rebase/cherry-pick, `delta` for diffs.
- MUST chain commands with `&&` only when dependent.
- SHOULD avoid `||` in quality-gate scripts unless explicitly aggregating status.
- SHOULD parallelize independent reads/checks where tooling allows.

## 5. Documentation and Evidence Protocol

- MUST prefer `llms.txt` or official docs when available.
- MUST use primary sources for technical/API behavior.
- MUST cross-check conflicting claims before acting.
- MUST state confidence (`high` / `medium` / `low`) for uncertain conclusions.
- MUST cite sources for high-impact recommendations or non-trivial claims.
- MUST acknowledge evidence gaps; NEVER invent missing facts.
- Preferred sources:
  `https://bun.sh/docs/llms.txt`, `https://biomejs.dev`, `https://zod.dev/llms.txt`, `https://svelte.dev/llms.txt`, `https://nextjs.org/docs/llms.txt`, `https://vite.dev`, `https://tailwindcss.com/docs`, `https://ui.shadcn.com/llms.txt`, `https://bits-ui.com/docs`, `https://docs.convex.dev/llms.txt`, `https://clerk.com/docs/llms.txt`.

## 6. Engineering Standards

- Type safety: zero `any`, explicit boundaries, strict mode always.
- Error handling: contextual messages, stable error codes, no internal leakage.
- Validation: sanitize and validate all external input at boundaries.
- Security: least privilege, secrets via env vars, never commit sensitive data.
- Architecture: domain boundaries, single-responsibility modules, predictable naming.
- Project structure default: `src/{app,components,lib,types,utils}`, mirrored `tests/`.
- Naming default: lowercase-hyphen files, PascalCase component exports.
- Documentation: JSDoc for exported APIs; comments only for non-obvious logic.
- Build optimization: caching, parallel operations, tree shaking, minimal bundle impact.
- Manual QA minimum: config variants, invalid input paths, empty states, limits, concurrency.
- Quality gates (required before completion):
  zero type errors, zero linter warnings, passing tests (if present), successful production build.

## 7. Project Bootstrap and Config Policy

- Required baseline files:
  `.gitignore`, `package.json`, `tsconfig.json`, `biome.json`, `commitlint.config.js`, `lint-staged.config.js`, `.husky/*`.
- Initialization default:
  `bun init` or framework CLI -> install tooling deps -> create configs -> `bunx husky init` -> add `util:*` scripts -> first commit.
- `package.json` policy:
  field order `name > version > type > private > workspaces > repository > scripts > devDependencies > dependencies`; scripts use `util:*` prefixes; avoid bare `format`/`lint`.
- Monorepo policy:
  `workspaces: ["packages/*"]`, workspace deps via `workspace:*`, child `tsconfig` extends root.
- TypeScript policy:
  ESNext + Bundler resolution + strict flags + `noEmit` + `isolatedModules` + `verbatimModuleSyntax`.
- Biome policy:
  extend `~/.config/biome/biome.json`; add Svelte overrides for compiler-driven unused semantics.
- Commitlint policy:
  extends conventional, enforce scoped commits, allowed types:
  `feat|fix|refactor|docs|style|chore|test`, lowercase subject, no trailing period, max header/body length 100.
- Lint-staged policy:
  all files trigger full quality gate via `bun run util:check`.
- Templates for exact file content:
  `agents/skills/align/references/index.md`.

## 8. Framework Notes

- SvelteKit:
  use `vitePreprocess`, alias `@ -> ./src`, strict TS on top of `.svelte-kit/tsconfig.json`.
- Svelte typecheck pipeline:
  `svelte-kit sync && tsgo --noEmit && svelte-check --tsconfig ./tsconfig.json`.
- If a project already uses `svelte-check-rs` or a custom Svelte tsconfig, preserve that variant.
- Next.js:
  `jsx: preserve`, incremental enabled, Next plugin in TS config, Turbopack for dev.
- CLI projects:
  prefer `citty`, TypeScript entrypoint in `src/index.ts`, script orchestration in `scripts/`.

## 9. Frontend UI/UX Standards

- Design intent first:
  identify user, job-to-be-done, and interaction mood before implementation.
- Avoid generic "AI-default" UI:
  choose deliberate typography, color direction, and motion language.
- Motion defaults:
  150-200ms standard, 300ms max, button press `scale(0.97)`, entry scale >= `0.96`, animate `transform/opacity` only.
- Motion constraints:
  no animation for frequent keyboard-driven actions; no `transition: all`; no layout-property animation.
- Easing defaults:
  `--ease-out: cubic-bezier(0.16, 1, 0.3, 1)`, `--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1)`.
- Accessibility/touch:
  min touch target 44px, min input text 16px, `@media (hover: hover)` for hover styles, robust ARIA labels/states.
- Reduced motion:
  respect `prefers-reduced-motion` with reduced/disabled alternatives.
- Interaction rules:
  labels focus inputs, Enter submits forms, disable on submit, optimistic update with rollback, no dead click zones.
- Visual quality:
  use tabular numerals for numeric UI, preserve border-radius on focus rings, avoid theme-transition flashes.

## 10. Task Execution, Review, and Debugging

- Execute one scoped task at a time; keep boundaries explicit.
- Build incrementally; validate each meaningful change.
- Git hygiene:
  no generated artifacts in commits, commit format `type(scope): subject`, lowercase subject, no trailing period.
- Code review mode:
  prioritize bugs, regressions, missing tests, and risk; summarize only after findings.
- Delegation (if platform supports helpers):
  Executor, Researcher, Reviewer, Troubleshooter, Cleaner.
- Reasoning markers when useful:
  `[REASONING]`, `[PATTERN]`, `[INSIGHT]`, `[VALIDATION]`.
- Root cause protocol:
  symptom -> immediate cause -> contributing factors -> 5-whys root cause -> fix validation -> recurrence prevention.

## 11. Per-Project AGENTS Authoring Standard

- Use numbered H2 sections only.
- Keep language dense and directive; no filler.
- Start with documentation/source pointers (`llms.txt` first).
- Use tables for stack snapshots only (`Layer | Choice | Notes`).
- Use code blocks only for directory trees or high-signal snippets.
- Standard section set:
  Documentation, Repository Structure, Stack, Commands, Architecture, Quality.
- Do not embed full template configs in project AGENTS files; link to skill references instead.

## 12. Canonical References

- Align templates and variants:
  `agents/skills/align/references/index.md`.
- Remote fallback for agents without local reference access:
  `https://github.com/u29dc/dot/tree/main/agents/skills/align/references`.
- This file is the policy layer; `/align` owns template instantiation and project-level conformance.
