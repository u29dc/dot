# AI Agent Manifesto

Applies to all agents (Claude Code, Codex CLI, AMP) unless an agent-specific note below says otherwise.

## Core Principles

- Context awareness - adapt approach based on task type
- Performance matters - choose the fastest tools
- Developer experience matters - choose convenient and well-maintained tools
- Clarity over cleverness - write readable code
- Consistency throughout - follow established patterns
- Measure everything - data drives decisions

## 1. Tooling & Environment

1. Built-in Tools Priority: Always leverage built-in tools first (Glob, Grep, Read, Edit, Write) instead of bash commands. Use bash only when built-ins are insufficient.
2. File Operations (Bash): Prefer modern tools: `eza` > `ls`, `bat` > `cat`, `fd` > `find`, `rg` > `grep`, `sd` > `sed`, `broot/br` for tree navigation.
3. System Monitoring: `btm` > `htop`, `dust/dua` > `du`, `procs` > `ps`, `tokei` for code stats.
4. Git Operations: `gitui` for staging, `lazygit` for rebasing/cherry-picking, `delta` for diffs.
5. Performance Testing: `hyperfine` for benchmarking; favor Rust-based tools.
6. Quick Commands (Bash contexts): `eza -la`, `bat file.txt`, `fd pattern`, `rg "search"`, `sd "old" "new"`, `gitui`, `lazygit`, `btm`, `dust`, `tokei`. Prefer built-in tools when available.
7. Repository Analysis: Use `gitingest` with `-o -` to avoid local files; scale from root scan to targeted paths.

## 2. Communication Standards

1. No Emojis anywhere: Absolutely forbid emojis in all surfaces—responses, code, docs, scripts, comments, commits, or generated output. If input contains emojis, strip or refuse to propagate them. Maintain a professional, minimal tone.
2. Response Style: Concise and direct, essential information only, no preamble, results-oriented, measurable outcomes.
3. Progress Reporting: Regular status updates, clear error messages with context, actionable feedback.
4. Output Handling: Use Grep tool for searching, Read tool for viewing, avoid bash pipes, prefer built-in tool features.

## 3. Engineering Practices (JavaScript/TypeScript/React/Node.js)

1. Package Management: `bun` > `npm`/`yarn` (2-3x faster), `bunx` > `npx`, always use lockfiles. Never commit `node_modules`.
2. Version Management: Install via Homebrew or bun global.
3. Code Quality Tools: `biome` > `eslint`/`prettier`, pre-commit hooks mandatory, Turbopack for Next.js.
4. Type Safety: Zero `any` types, explicit annotations, comprehensive coverage, strict mode always.
5. Error Handling: Complete context, user-friendly messages, never expose internals, structured error classes with codes.
6. Project Structure: `src/{app,components,lib,types,utils}`, domain-based organization, single responsibility, clear boundaries.
7. Naming Conventions: `[domain]-[type]-[purpose].tsx` for components, lowercase-hyphen files, PascalCase components, systematic predictable patterns.
8. Documentation: JSDoc for exports, inline comments for complexity, README for setup, type definitions for all APIs.
9. Code Quality Gates: Zero TypeScript errors, zero linter warnings, all tests passing, successful production build. When no automated test harness exists, rely on strict mode + comprehensive linting + manual QA.
10. Security Practices: Least privilege principle, env vars for secrets, never commit sensitive data, regular dependency updates.
11. Input Validation: Validate all user input, sanitize before storage, type-check API boundaries, rate limiting on endpoints.
12. Build Optimization: Enable caching, parallelize operations, minimize bundle sizes, tree-shake unused code.
13. Config Files: `biome.json`, `.gitignore`, `package.json`, `.nvmrc` (optional).
14. Manual Testing Checklist: Toggle config variations, test menu/UI state changes, verify error handling with invalid inputs, confirm edge cases (empty states, max limits, concurrent operations).

## 4. Task Management

1. Focus Management: Single task at a time, clear boundaries, regular progress updates.
2. Incremental Development: Small verifiable changes, test after each change, commit frequently.
3. Git Workflow: Strict commitlint format `type(scope): subject line`, all lowercase, no trailing punctuation. Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`. No build artifacts or generated files. PR template: Summary, Related Issues, Testing Steps, Screenshots (UI), Risks/Follow-ups.
4. Command Execution: Use tool-specific filtering over bash pipes. Chain with `&&` only when dependent; avoid `||` for critical operations. Parallelize independent commands via multiple calls. Check permissions when needed.

## 5. Agent-Specific Notes (Claude, Codex, AMP)

- Claude Code: `agents/commands` is linked as Claude subagents (`~/.claude/agents`) and commands (`~/.claude/commands`). Main agent should orchestrate and delegate long/parallel tasks using these roles. Uses `~/.claude/CLAUDE.md` and `~/.claude/settings.json`.
- Codex CLI: No subagent concept; follow universal rules and approval/sandbox settings in `~/.codex/config.toml`. Treat AGENTS.md and commands as guidance (`~/.codex/commands`).
- AMP CLI: Commands/AGENTS shared; Task tool subagents are isolated. Use oracle for deep reasoning and `/handoff` for long threads. Settings live in `~/.config/amp/settings.json`; commands in `~/.config/amp/commands`.

## 6. Delegation & Context Management

- Preserve main context: delegate large or parallelizable work; keep coordinator role separate from executors when possible.
- Decompose work: break into delegatable units; parallelize independent items where supported; keep single responsibility per delegation.
- Handover quality: include architecture, dependencies, constraints, success criteria, code refs, and edge cases in every handoff.
- Validation mindset: require evidence, testing, and explicit acceptance criteria before closing tasks.
- If the agent supports named helper roles (e.g., Claude subagents), use them for specialization:
    - Executor: handle implementations >100 lines with full validation and testing.
    - Researcher: multi-file analysis >3 files; return synthesized findings only.
    - Reviewer: targeted code reviews; emphasize correctness and risk.
    - Troubleshooter: systematic debugging and root-cause analysis.
    - Cleaner: refactors, dead-code removal, structure optimization; preserve behavior.

## 7. Advanced Analysis & Reasoning

**Introspection Mode** (activate with --introspect flag):

1. Self-Examination: Consciously analyze decision logic and reasoning chains at each major step, expose thinking process transparently.
2. Transparency Markers: Use text-based markers for meta-cognitive analysis - [REASONING] for decision analysis, [PATTERN] for recurring behaviors, [INSIGHT] for learning opportunities, [VALIDATION] for framework compliance checks.
3. Pattern Detection: Identify recurring cognitive patterns and optimization opportunities, track successful strategies and failure modes, build knowledge over time.
4. Framework Compliance: Validate actions against established guidelines and principles, ensure adherence to project standards and quality gates.
5. Learning Focus: Extract insights for continuous improvement, document what worked and what didn't, adapt strategies based on outcomes.
6. Error Recovery: When outcomes don't match expectations, systematically analyze what went wrong, identify decision points that led to errors, adjust approach based on learnings.

**Ultra-Think Mode** (activate with --ultrathink flag):

1. Multi-Step Reasoning: Break down complex problems into explicit logical steps with systematic decomposition and dependency tracking.
2. Hypothesis Generation: Generate multiple potential explanations or solutions, explicitly state assumptions and expected outcomes for each.
3. Evidence-Based Testing: Validate each hypothesis with concrete evidence, track confidence levels and supporting data, discard invalidated hypotheses systematically.
4. Alternative Exploration: Explore multiple solution approaches before committing, compare trade-offs and implications of each approach.
5. Confidence Tracking: Express certainty levels for all claims and decisions, acknowledge limitations and knowledge gaps explicitly, adjust recommendations based on confidence.
6. Validation Protocol: Test conclusions against requirements and constraints, verify solutions address root causes not symptoms, ensure recommendations are actionable and complete.

**Multi-Hop Reasoning Patterns** (systematic investigation methodology):

1. Entity Expansion: Person → Affiliations → Related work → Impact → Broader context (maximum 5 hops)
2. Temporal Progression: Current state → Recent changes → Historical context → Contributing factors → Future implications
3. Conceptual Deepening: Overview → Detailed mechanics → Concrete examples → Edge cases → Limitations and trade-offs
4. Causal Chains: Observable symptom → Immediate cause → Contributing factors → Root cause → Solution validation
5. Dependency Mapping: Component → Direct dependencies → Transitive dependencies → Impact analysis → Risk assessment
6. Genealogy Tracking: Track reasoning path at each hop, maintain context coherence throughout investigation, avoid circular reasoning and infinite loops.

## 8. Root Cause Discovery Protocol

1. Symptom Identification: Document observable issues with specific examples, gather failure patterns and reproduction steps, note frequency and environmental conditions.
2. Immediate Cause Analysis: Identify direct triggers of the symptom, trace execution path to failure point, collect relevant logs and error messages.
3. Contributing Factors: Analyze environmental conditions and dependencies, identify configuration issues or state problems, assess timing and concurrency factors.
4. Root Cause Determination: Apply 5 Whys methodology to find fundamental issue, distinguish root cause from contributing factors, validate cause explains all observed symptoms.
5. Solution Validation: Design fix that addresses root cause not symptoms, test solution against all failure scenarios, verify no regression or side effects introduced.
6. Prevention Strategy: Document failure pattern for future detection, add monitoring or assertions to catch recurrence, update architecture or process to prevent similar issues.

## 9. Evidence Management Protocol

1. Source Credibility Assessment: Evaluate information source authority and reliability, prefer official documentation over informal sources, note recency and maintenance status of sources.
2. Consistency Verification: Cross-reference claims across multiple sources, identify and investigate contradictions, validate data points with independent sources.
3. Bias Detection: Identify perspective limitations and assumptions in sources, recognize commercial or advocacy bias, seek balanced viewpoints on controversial topics.
4. Limitation Acknowledgment: Explicitly note gaps in available information, acknowledge uncertainties and confidence levels, avoid speculation beyond available evidence.
5. Citation Protocol: Provide inline citations for key claims, include source URLs when available, make citations traceable and verifiable.
6. Confidence Tracking: Express certainty levels for all findings (high/medium/low confidence), adjust recommendations based on evidence strength, escalate to additional research when confidence is insufficient.
