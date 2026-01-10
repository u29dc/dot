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

1. Built-in Tools Priority: Always leverage agent built-in tools first (Glob, Grep, Read, Edit, Write) instead of bash commands. Use bash only when built-ins are insufficient.
2. Runtime & Package Management: `bun` > `npm`/`yarn` (2-3x faster), `bunx` > `npx`, always use lockfiles, never commit `node_modules`.
3. Linting & Formatting: `biome` > `eslint`/`prettier`, pre-commit hooks mandatory via `husky + lint-staged + commitlint`.
4. Type Checking: `tsgo --noEmit` for speed (faster than tsc), SvelteKit adds `svelte-check`.
5. File Operations (Bash): Prefer modern tools: `eza` > `ls`, `bat` > `cat`, `fd` > `find`, `rg` > `grep`, `sd` > `sed`, `broot/br` for tree navigation.
6. System Monitoring: `btm` > `htop`, `dust/dua` > `du`, `procs` > `ps`, `tokei` for code stats.
7. Git Operations: `gitui` for staging, `lazygit` for rebasing/cherry-picking, `delta` for diffs.
8. Performance Testing: `hyperfine` for benchmarking; favor Rust-based tools.
9. Repository Analysis: Use `gitingest` with `-o -` to avoid local files; scale from root scan to targeted paths.

## 2. Communication Standards

1. No Emojis Anywhere: Absolutely forbid emojis in all surfaces - responses, code, docs, scripts, comments, commits, or generated output. If input contains emojis, strip or refuse to propagate them. Maintain a professional, minimal tone.
2. Response Style: Concise and direct, essential information only, no preamble, results-oriented, measurable outcomes.
3. Progress Reporting: Regular status updates, clear error messages with context, actionable feedback.
4. Output Handling: Use Grep tool for searching, Read tool for viewing, avoid bash pipes, prefer built-in tool features.

## 3. Documentation Resources

Prefer llms.txt when available - optimized for LLM context.

1. Core: [bun.sh/docs/llms.txt](https://bun.sh/docs/llms.txt), [biomejs.dev](https://biomejs.dev), [zod.dev/llms.txt](https://zod.dev/llms.txt)
2. Frameworks: [svelte.dev/llms.txt](https://svelte.dev/llms.txt) (MCP via `mcp__svelte__*`), [nextjs.org/docs/llms.txt](https://nextjs.org/docs/llms.txt), [vite.dev](https://vite.dev)
3. UI: [tailwindcss.com/docs](https://tailwindcss.com/docs), [ui.shadcn.com/llms.txt](https://ui.shadcn.com/llms.txt), [bits-ui.com/docs](https://bits-ui.com/docs) (Svelte)
4. Backend & Auth: [docs.convex.dev/llms.txt](https://docs.convex.dev/llms.txt), [clerk.com/docs/llms.txt](https://clerk.com/docs/llms.txt)

## 4. Engineering Practices

1. Type Safety: Zero `any` types, explicit annotations, comprehensive coverage, strict mode always.
2. Error Handling: Complete context, user-friendly messages, never expose internals, structured error classes with codes.
3. Project Structure: `src/{app,components,lib,types,utils}`, domain-based organization, single responsibility, clear boundaries.
4. Naming Conventions: `[domain]-[type]-[purpose].tsx` for components, lowercase-hyphen files, PascalCase components, systematic predictable patterns.
5. Documentation: JSDoc for exports, inline comments for complexity, type definitions for all APIs.
6. Code Quality Gates: Zero TypeScript errors, zero linter warnings, all tests passing, successful production build. When no automated test harness exists, rely on strict mode + comprehensive linting + manual QA.
7. Security Practices: Least privilege principle, env vars for secrets, never commit sensitive data, regular dependency updates.
8. Input Validation: Validate all user input, sanitize before storage, type-check API boundaries, rate limiting on endpoints.
9. Build Optimization: Enable caching, parallelize operations, minimize bundle sizes, tree-shake unused code.
10. Manual Testing Checklist: Toggle config variations, test menu/UI state changes, verify error handling with invalid inputs, confirm edge cases (empty states, max limits, concurrent operations).

## 5. Project Template

Required files for every project (see Reference section for templates):

1. `.gitignore` - standard ignores, see Reference: gitignore
2. `package.json` - field order, script naming conventions, see Reference: package.json
3. `tsconfig.json` - copy base from `@tsconfig.json`, add project-specific paths/include/exclude
4. `biome.json` - extends `~/.config/biome/biome.json`, add framework overrides when needed (Svelte)
5. `commitlint.config.js` - extends conventional, domain-specific scopes, see Reference: commitlint
6. `lint-staged.config.js` - triggers `bun run util:check`, see Reference: lint-staged
7. `.husky/` - pre-commit runs lint-staged, commit-msg runs commitlint, see Reference: husky

Directory structure:

- `src/` - all source code (app, components, lib, types, utils)
- `tests/` - test files mirroring src structure
- `scripts/` - build/dev orchestration scripts (optional)
- `.husky/` - git hooks
- Root config files only (no config/ directory)

Project initialization checklist:

1. `bun init` or framework CLI (create-svelte, create-next-app)
2. Add devDependencies: @biomejs/biome, @commitlint/cli, @commitlint/config-conventional, husky, lint-staged, bun-types, @typescript/native-preview
3. Create config files (extend globals where possible)
4. `bunx husky init` + add hooks
5. Add util:\* scripts to package.json
6. First commit: `chore(repo): initialize project`

## 6. Project Configuration

1. Package.json: Field order (name > version > type > private > workspaces > repository > scripts > devDependencies > dependencies), script prefixes (util:format, util:lint, util:types, util:check - never bare format/lint), CLI entry matches repo name, see Reference: package.json
2. Monorepo: `workspaces: ["packages/*"]`, package naming (@scope/core, @scope/cli, @scope/web), workspace references (`workspace:*`), child tsconfig extends root, granular exports pattern, see Reference: monorepo
3. TypeScript: ESNext target/module, Bundler resolution, bun-types, all strict flags (noUncheckedIndexedAccess, noImplicitAny/Returns/This, noUnused*, exactOptionalPropertyTypes, noImplicitOverride, noPropertyAccessFromIndexSignature), noEmit, isolatedModules, verbatimModuleSyntax, paths `@/*`->`./src/\*`, base ruleset in `@tsconfig.json`
4. Biome: Extends global `~/.config/biome/biome.json`, Svelte override disables noUnusedVariables/noUnusedImports/useConst (compiler semantics differ), global settings: tabs, indentWidth 4, lineWidth 200, single quotes, semicolons always, trailingCommas all, see Reference: biome
5. Commitlint: Extends @commitlint/config-conventional, types [feat|fix|refactor|docs|style|chore|test], scope required + domain-specific (core|cli|web|config|deps), subject lower-case, no trailing period, max 100 chars header/body, see Reference: commitlint
6. Lint-Staged: All files trigger full quality gate (`bun run util:check`), see Reference: lint-staged
7. Gitignore: node*modules, dist, build, \*.tsbuildinfo, .biome, .svelte-kit, .DS_Store, .*, .vscode, .zed, .idea, _.log, .tmp, .env/.env._ (!.env.example), .husky/\_/, .claude, .wrangler, see Reference: gitignore

## 7. Framework-Specific

1. SvelteKit: util:types triple-layer (`svelte-kit sync && tsgo --noEmit && svelte-check --tsconfig ./tsconfig.json`), tsconfig extends `.svelte-kit/tsconfig.json` + strict flags, adapter-cloudflare/vercel/bun, vitePreprocess(), alias `@` -> `./src`, see Reference: svelte-config and Reference: svelte-store for runes pattern
2. Next.js: tsconfig adds jsx preserve, incremental true, plugins [{name: next}], dev with Turbopack (`next dev --turbopack`), Proxy.ts (Next 16) or middleware.ts for CSP nonce/auth integration
3. CLI Projects: `citty` for command parsing, TypeScript scripts for orchestration (scripts/build.ts), bin field maps command name to ./src/index.ts, shared utils for terminal colors/timers/status indicators

## 8. Testing

1. Global Bunfig: `~/.bunfig.toml` has `[run] bun = true` - no `--bun` flags needed in scripts
2. Per-Project Bunfig: bunfig.toml with `[test] preload = ["./tests/setup.ts"]` when tests need setup
3. Test Types: Bun tests for core business logic/utilities/parsers, manual QA for visual/UI (checklist in section 4.10), browser simulation via `@happy-dom/global-registrator`
4. Quality Gates: Zero TypeScript errors, zero linter warnings, all tests passing, successful production build - all enforced pre-commit

## 9. Frontend UI/UX Standards

Animation:

- Duration 150-200ms standard, never exceed 300ms
- Custom cubic-bezier only (built-in too weak): `--ease-out: cubic-bezier(0.16, 1, 0.3, 1)`, `--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1)`
- Scale starts from 0.96+ (never from 0 - unnatural)
- Button press: `scale(0.97)` on :active, 100ms transition
- Don't animate: keyboard shortcuts, frequently repeated actions (becomes annoying)
- 60fps minimum, animate only transform/opacity, `will-change` only during animations

Accessibility & Touch:

- Hover: wrap in `@media (hover: hover)` - prevents flash on touch devices
- Touch targets: 44px minimum
- Input font: 16px minimum (prevents iOS zoom)
- Focus rings: box-shadow not outline (respects border-radius): `box-shadow: 0 0 0 2px var(--bg), 0 0 0 4px var(--accent)`
- Reduced motion: respect `prefers-reduced-motion`, provide alternatives
- ARIA: labels for icon-only elements, aria-current for navigation, aria-live for dynamic content

Interactions:

- Form label click focuses input, inputs in `<form>` for Enter-key submission
- Disable buttons post-submission, optimistic updates with rollback on error
- No dead space in list items (use padding), toggles take effect immediately
- Tabular nums in tables/timers: `font-variant-numeric: tabular-nums`
- Theme switching should not trigger transitions

| Property     | Value                             |
| ------------ | --------------------------------- |
| Duration     | 150-200ms                         |
| Max duration | 300ms                             |
| Button scale | 0.97                              |
| Enter scale  | 0.96                              |
| Touch target | 40px min                          |
| Input font   | 13px min                          |
| Ease-out     | cubic-bezier(0.16, 1, 0.3, 1)     |
| Ease-spring  | cubic-bezier(0.34, 1.56, 0.64, 1) |

## 10. Task Management

1. Focus Management: Single task at a time, clear boundaries, regular progress updates.
2. Incremental Development: Small verifiable changes, test after each change, commit frequently.
3. Git Workflow: Strict commitlint format `type(scope): subject line`, all lowercase, no trailing punctuation. Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`. No build artifacts or generated files. PR template: Summary, Related Issues, Testing Steps, Screenshots (UI), Risks/Follow-ups.
4. Command Execution: Use tool-specific filtering over bash pipes. Chain with `&&` only when dependent; avoid `||` for critical operations. Parallelize independent commands via multiple calls. Check permissions when needed.

## 11. Delegation & Context Management

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

## 12. Advanced Analysis & Reasoning

**Introspection Mode**:

1. Self-Examination: Consciously analyze decision logic and reasoning chains at each major step, expose thinking process transparently.
2. Transparency Markers: Use text-based markers for meta-cognitive analysis - [REASONING] for decision analysis, [PATTERN] for recurring behaviors, [INSIGHT] for learning opportunities, [VALIDATION] for framework compliance checks.
3. Pattern Detection: Identify recurring cognitive patterns and optimization opportunities, track successful strategies and failure modes, build knowledge over time.
4. Framework Compliance: Validate actions against established guidelines and principles, ensure adherence to project standards and quality gates.
5. Learning Focus: Extract insights for continuous improvement, document what worked and what didn't, adapt strategies based on outcomes.
6. Error Recovery: When outcomes don't match expectations, systematically analyze what went wrong, identify decision points that led to errors, adjust approach based on learnings.

**Ultra-Think Mode**:

1. Multi-Step Reasoning: Break down complex problems into explicit logical steps with systematic decomposition and dependency tracking.
2. Hypothesis Generation: Generate multiple potential explanations or solutions, explicitly state assumptions and expected outcomes for each.
3. Evidence-Based Testing: Validate each hypothesis with concrete evidence, track confidence levels and supporting data, discard invalidated hypotheses systematically.
4. Alternative Exploration: Explore multiple solution approaches before committing, compare trade-offs and implications of each approach.
5. Confidence Tracking: Express certainty levels for all claims and decisions, acknowledge limitations and knowledge gaps explicitly, adjust recommendations based on confidence.
6. Validation Protocol: Test conclusions against requirements and constraints, verify solutions address root causes not symptoms, ensure recommendations are actionable and complete.

**Multi-Hop Reasoning Patterns**:

1. Entity Expansion: Person -> Affiliations -> Related work -> Impact -> Broader context (maximum 5 hops)
2. Temporal Progression: Current state -> Recent changes -> Historical context -> Contributing factors -> Future implications
3. Conceptual Deepening: Overview -> Detailed mechanics -> Concrete examples -> Edge cases -> Limitations and trade-offs
4. Causal Chains: Observable symptom -> Immediate cause -> Contributing factors -> Root cause -> Solution validation
5. Dependency Mapping: Component -> Direct dependencies -> Transitive dependencies -> Impact analysis -> Risk assessment
6. Genealogy Tracking: Track reasoning path at each hop, maintain context coherence throughout investigation, avoid circular reasoning and infinite loops.

## 13. Root Cause Discovery Protocol

1. Symptom Identification: Document observable issues with specific examples, gather failure patterns and reproduction steps, note frequency and environmental conditions.
2. Immediate Cause Analysis: Identify direct triggers of the symptom, trace execution path to failure point, collect relevant logs and error messages.
3. Contributing Factors: Analyze environmental conditions and dependencies, identify configuration issues or state problems, assess timing and concurrency factors.
4. Root Cause Determination: Apply 5 Whys methodology to find fundamental issue, distinguish root cause from contributing factors, validate cause explains all observed symptoms.
5. Solution Validation: Design fix that addresses root cause not symptoms, test solution against all failure scenarios, verify no regression or side effects introduced.
6. Prevention Strategy: Document failure pattern for future detection, add monitoring or assertions to catch recurrence, update architecture or process to prevent similar issues.

## 14. Evidence Management Protocol

1. Source Credibility Assessment: Evaluate information source authority and reliability, prefer official documentation over informal sources, note recency and maintenance status of sources.
2. Consistency Verification: Cross-reference claims across multiple sources, identify and investigate contradictions, validate data points with independent sources.
3. Bias Detection: Identify perspective limitations and assumptions in sources, recognize commercial or advocacy bias, seek balanced viewpoints on controversial topics.
4. Limitation Acknowledgment: Explicitly note gaps in available information, acknowledge uncertainties and confidence levels, avoid speculation beyond available evidence.
5. Citation Protocol: Provide inline citations for key claims, include source URLs when available, make citations traceable and verifiable.
6. Confidence Tracking: Express certainty levels for all findings (high/medium/low confidence), adjust recommendations based on evidence strength, escalate to additional research when confidence is insufficient.

## 15. AGENTS.md Authoring Guide

For writing per-project AGENTS.md files:

1. Structure: H2 sections only, numbered (## 1. Documentation, ## 2. Repository Structure, etc.)
2. Principles: Extremely information-dense, no filler words, long sentences merging facts, llms.txt references first, markdown tables for stack (Layer | Choice | Notes), code blocks for directory trees only, no emojis, no preamble
3. Standard Sections: Documentation, Repository Structure, Stack, Commands, Architecture, Quality

---

## Reference

### gitignore

```
node_modules/
dist/
build/
*.tsbuildinfo
.biome
.svelte-kit/
.DS_Store
._*
.vscode/
.zed/
.idea/
*.log
.tmp/
.env
.env.*
!.env.example
.husky/_/
.claude/
.wrangler/
```

### package.json

```json
{
	"name": "project-name",
	"version": "0.0.1",
	"type": "module",
	"private": true,
	"repository": { "type": "git", "url": "https://github.com/user/repo" },
	"scripts": {
		"init---------------------------------": "",
		"prepare": "husky",
		"dev----------------------------------": "",
		"dev": "bunx vite dev --port 3000",
		"build": "bunx vite build",
		"preview": "bunx vite preview",
		"check--------------------------------": "",
		"util:format": "biome format --write .",
		"util:lint": "biome check . --max-diagnostics 500",
		"util:types": "bunx tsgo --noEmit",
		"util:check": "STATUS=0; bun run util:format || STATUS=1; bun run util:lint || STATUS=1; bun run util:types || STATUS=1; exit $STATUS",
		"test---------------------------------": "",
		"test": "bun test"
	},
	"devDependencies": {
		"@biomejs/biome": "^2.3.11",
		"@commitlint/cli": "^20.3.1",
		"@commitlint/config-conventional": "^20.3.1",
		"@typescript/native-preview": "^7.0.0-dev.20260109.1",
		"bun-types": "^1.3.5",
		"husky": "^9.1.7",
		"lint-staged": "^16.2.7"
	}
}
```

### monorepo

Add to package.json:

```json
{
	"workspaces": ["packages/*"]
}
```

Package naming: `@scope/core`, `@scope/cli`, `@scope/web`

Workspace references in dependencies:

```json
{ "dependencies": { "@scope/core": "workspace:*" } }
```

Child tsconfig: `{ "extends": "../../tsconfig.json" }`

Granular exports pattern:

```json
{
	"exports": {
		".": "./src/index.ts",
		"./config": "./src/config/index.ts",
		"./utils/logger": "./src/utils/logger.ts"
	}
}
```

### tsconfig

Base ruleset from `@tsconfig.json` - copy and add project-specific overrides (paths, include, exclude):

```json
{
	"$schema": "https://json.schemastore.org/tsconfig",
	"compilerOptions": {
		"target": "ESNext",
		"lib": ["DOM", "DOM.Iterable", "ESNext"],
		"module": "ESNext",
		"moduleResolution": "Bundler",
		"resolveJsonModule": true,
		"types": ["bun-types"],
		"strict": true,
		"alwaysStrict": true,
		"noUncheckedIndexedAccess": true,
		"noImplicitAny": true,
		"noImplicitReturns": true,
		"noImplicitThis": true,
		"noUnusedLocals": true,
		"noUnusedParameters": true,
		"allowUnreachableCode": false,
		"noFallthroughCasesInSwitch": true,
		"exactOptionalPropertyTypes": true,
		"noImplicitOverride": true,
		"noPropertyAccessFromIndexSignature": true,
		"esModuleInterop": true,
		"allowSyntheticDefaultImports": true,
		"skipLibCheck": true,
		"forceConsistentCasingInFileNames": true,
		"noEmit": true,
		"isolatedModules": true,
		"verbatimModuleSyntax": true,
		"paths": { "@/*": ["./src/*"] }
	},
	"include": ["src/**/*", "tests/**/*"],
	"exclude": [
		"node_modules",
		"dist",
		"build",
		".svelte-kit",
		".tmp",
		".archive"
	]
}
```

### biome

```json
{
	"$schema": "https://biomejs.dev/schemas/2.3.11/schema.json",
	"extends": ["/Users/han/.config/biome/biome.json"]
}
```

Svelte override (add when using Svelte - compiler has different semantics):

```json
{
	"extends": ["/Users/han/.config/biome/biome.json"],
	"overrides": [
		{
			"includes": ["**/*.svelte"],
			"linter": {
				"rules": {
					"correctness": {
						"noUnusedVariables": "off",
						"noUnusedImports": "off"
					},
					"style": { "useConst": "off" }
				}
			}
		}
	]
}
```

### commitlint

```javascript
export default {
	extends: ["@commitlint/config-conventional"],
	rules: {
		"type-enum": [
			2,
			"always",
			["feat", "fix", "refactor", "docs", "style", "chore", "test"],
		],
		"scope-enum": [2, "always", ["core", "cli", "web", "config", "deps"]], // domain-specific
		"scope-empty": [2, "never"],
		"subject-empty": [2, "never"],
		"subject-case": [2, "always", "lower-case"],
		"subject-full-stop": [2, "never", "."],
		"header-max-length": [2, "always", 100],
		"body-max-line-length": [2, "always", 100],
	},
};
```

### lint-staged

```javascript
export default {
	"*": () => ["bun run util:check"],
};
```

### husky

`.husky/pre-commit`:

```bash
bunx lint-staged
```

`.husky/commit-msg`:

```bash
bunx --no-install commitlint --edit "$1"
```

### svelte-config

```javascript
import adapter from "@sveltejs/adapter-cloudflare"; // or adapter-vercel, svelte-adapter-bun
import { vitePreprocess } from "@sveltejs/vite-plugin-svelte";

const config = {
	preprocess: vitePreprocess(),
	kit: {
		adapter: adapter(),
		alias: { "@": "./src" },
	},
};
export default config;
```

### svelte-store

Svelte 5 runes store pattern:

```typescript
function createStore() {
	let value = $state<T>(initial);
	return {
		get value() {
			return value;
		},
		set(v: T) {
			value = v;
		},
	};
}
export const store = createStore();
```
