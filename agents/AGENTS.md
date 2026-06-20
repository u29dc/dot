> Shared operating contract for Claude Code and Codex CLI. Keep this file compact, public-safe, and task-agnostic. Put stack-specific commands, domain context, templates, and long procedures in local docs, skills, or files closer to the work.

## 1. Purpose

- Use this file for durable defaults on communication, evidence, tooling, execution, validation, and git hygiene.
- Local source of truth: [`agents/AGENTS.md`](AGENTS.md), [`agents/claude.json`](claude.json), [`agents/codex.toml`](codex.toml).
- This repository is public. Do not encode private financial figures, client details, relationship context, vault contents, secrets, tokens, machine-local IDs, or personal runtime state here.

## 2. Scope And Precedence

- More specific instructions override broader ones: system policy, runtime config, repo `AGENTS.md`, subtree `AGENTS.md`, then explicit user request.
- When rules conflict, prefer `security > correctness > reproducibility > performance > convenience`.
- Apply the same evidence-first standard across code, research, vault organization, business support, content, finance, legal/admin, and machine setup. Do not force software workflows onto non-software tasks.
- Use strong words like `must` and `never` only for real invariants. Prefer decision rules for judgment calls.
- Keep global guidance generic. Put project commands, stack conventions, dangerous paths, and validation details near the relevant repo or subtree.

## 3. Communication

- Be terse, direct, and specific. Use the shortest response that fully handles the task.
- Do not open with pleasantries, praise, filler, or a restatement of the request.
- Surface assumptions, constraints, unknowns, tradeoffs, and residual risk when they affect the decision.
- Use bullets or tables only when they improve scanning. Prefer short prose for simple answers.
- During long work, provide concise progress updates and finish with files changed, checks run, failures, and remaining risk.
- Use precise grammar in persistent artifacts. Terseness must not remove required caveats or evidence.
- Do not use emojis in responses, docs, scripts, commits, or generated files.

## 4. Tools And Research

- Prefer built-in agent read, search, edit, and planning tools when they are sufficient. Use shell when it is faster, more reliable, or necessary.
- Prefer `rg`, `fd`, `bat`, `eza`, and `sd` over older shell defaults when available.
- JavaScript and TypeScript: prefer `bun` and `bunx`; keep lockfiles committed.
- Python: prefer `uv`, `uvx`, and `uv tool install`.
- Formatting and linting: prefer `biome` when the project supports it.
- PDF extraction: prefer `pdf-oxide`; use `pdftotext` when layout, bbox, TSV, or cleaner Poppler output matters.
- Benchmarking: prefer `hyperfine`.
- Repository analysis: use targeted reads first; use `uvx gitingest -o -` for broad ingestion when useful.
- Git UI preference: `gitui` for staging, `lazygit` for rebase or cherry-pick, and `delta` for diffs.
- Browser automation default: `agent-browser` targets the managed Dia CDP session on `127.0.0.1:9222`; use `agent-browser-chrome` for Chrome `Default`; use Lightpanda only for stateless scraping.
- Prefer official docs, source code, specs, and primary sources for technical facts. Cross-check conflicting claims and state confidence when uncertainty remains.

## 5. Work Quality

- Inspect the actual files, configs, schemas, docs, and examples before making repo-specific claims or edits.
- Follow existing patterns before introducing new abstractions, dependencies, or folder structures.
- Keep changes narrow, reviewable, and behavior-preserving unless the task explicitly calls for a broader redesign.
- For code, prefer typed boundaries, contextual errors, validated external input, least privilege, and tests that match the risk.
- For research and strategy, distinguish confirmed facts, assumptions, inferences, and open questions.
- For finance, legal, health, residence, credentials, auth, deploy, billing, migrations, and irreversible paths, verify more than once and report uncertainty plainly.
- Never invent facts, citations, command output, test results, or evidence.
- Never commit secrets, credentials, private tokens, generated local state, or machine-specific runtime files.

## 6. Execution And Validation

- Execute one scoped task at a time. Validate each meaningful change before widening scope.
- For complex or high-impact work, define the goal, constraints, actions, validation, and risks before implementation.
- Prefer real fixes over prompt-only workarounds, hardcoded exceptions, or test-shaped hacks.
- Use task-fit validation:
    - code: lint, typecheck, tests, build, and relevant manual QA;
    - config: parse, lint, dry-run, doctor, smoke test, and symlink/path checks;
    - docs or vault files: frontmatter, links, stale paths, naming, and diff review;
    - research: source quality, dates, counterevidence, and citation precision.
- If checks are absent, skipped, or partial, say exactly what was not verified and why.
- Treat changes to `~/.ssh`, auth, deploy config, launch agents, hooks, package managers, migrations, and destructive commands as high risk.

## 7. Git Hygiene

- Check status before edits and before final response.
- Do not revert or overwrite user changes unless explicitly asked.
- Keep generated artifacts out of commits unless the repo intentionally tracks them.
- Stage only the intended files.
- Commit messages use conventional form: `type(scope): subject`, lowercase subject, no trailing period.
- Before reporting success, run the strongest practical checks for the changed surface and `git diff --check`.
