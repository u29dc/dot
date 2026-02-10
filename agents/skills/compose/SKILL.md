---
name: compose
description: Build/refactor CLIs into agent-native, composable primitives with strict discovery + JSON contracts
argument-hint: [file|audit|migrate]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Compose

Design tool ecosystems that agents can discover, trust, and compose without scraping output or guessing behavior.

## Use Cases

- `/compose` - apply this contract during new CLI/tool design.
- `/compose <file>` - audit one module and propose exact refactors.
- `/compose audit` - run full parity/granularity/interface/CRUD audit.
- `/compose migrate` - plan and execute legacy CLI migration to agent-native contracts.

Apply when:

- Designing a new CLI, SDK, or internal automation surface.
- Refactoring monolithic workflow commands into primitives.
- Debugging agent failures caused by weak contracts.
- Standardizing mixed-language toolchains (TS/Bun, Go, Rust) for shared agent usage.

## Core Model

- Tools expose domain primitives.
- Prompts orchestrate primitives.
- Agent judgment stays in the agent layer.
- If humans can perform an action, tools MUST expose that action.

## Non-Negotiable Principles

### 1. Parity

- MUST expose every domain action required for end-to-end workflows.
- MUST document intentionally unsupported actions and alternative handling paths.
- NEVER keep critical operations UI-only or manual-only.

### 2. Granularity

- MUST keep one command focused on one atomic operation.
- MUST keep judgment in prompts/agent loops, not bundled in command internals.
- NEVER ship "analyze + decide + execute" mega-commands by default.

### 3. Composability

- MUST produce chainable outputs for downstream tools/scripts.
- MUST provide filters/selectors to avoid fragile post-processing.
- SHOULD favor consistent nouns/verbs across commands.

### 4. Emergent Capability

- MUST treat repeated failures as missing primitive signals.
- MUST add the smallest missing primitive, not a bespoke workflow wrapper.
- SHOULD promote repeated chains to optional shortcuts only after evidence.

### 5. Improvement Loop

- MUST capture command traces, failures, and outputs for iterative fixes.
- SHOULD promote high-frequency chains to shortcuts after validation.
- MUST keep primitives available after shortcuts are added.

## Agent-Native CLI Contract

### 1. Orientation Surface

- MUST provide:
    - `<tool> tools --json`
    - `<tool> health --json`
    - `<tool> config show --json` (or equivalent capability/config introspection)
- `health` MUST return actionable remediation (`checks[].fix`) and lifecycle status (`ready|degraded|blocked`).

### 2. Capability Discovery (`tools`)

- MUST expose full catalog and single-tool detail:
    - `<tool> tools --json`
    - `<tool> tools <name> --json` (or equivalent detail mode)
- MUST generate catalog from a single source registry; do not duplicate metadata.
- MUST return deterministic order (category, then name).
- MUST include `globalFlags` in catalog output.

Required per-tool metadata fields:

- `name` (dotted: `group.action`)
- `command` (full invocation string)
- `category`
- `description`
- `parameters[]` with `name,type,required,description`
- `outputFields[]`
- `outputSchema` (when structured schema is known)
- `inputSchema` (for structured mutating input)
- `idempotent`
- `rateLimit` (string or `null`)
- `example`

### 3. JSON Envelope

- Every `--json` command MUST emit exactly one JSON line on `stdout`.
- `stdout` in JSON mode MUST contain envelope only; logs/errors go to `stderr`.
- Success envelope:
    - `{ ok: true, data: <payload>, meta: { tool, elapsed, count?, total?, hasMore? } }`
- Error envelope:
    - `{ ok: false, error: { code, message, hint }, meta: { tool, elapsed } }`
- Envelope keys (`ok,data,error,meta`) MUST stay stable across projects.

### 4. Exit Codes + Error Semantics

- Exit codes MUST be stable:
    - `0`: success (including partial success where explicitly documented)
    - `1`: runtime/validation/business failure
    - `2`: blocked prerequisites (environment/config/schema/dependency gate)
- Errors MUST use stable `error.code` plus actionable `error.hint`.
- Blocking error codes MUST map deterministically to exit `2`.

### 5. Command Behavior

- Every data-bearing command MUST support `--json` (or `--format json` with same envelope).
- Commands MUST run fully non-interactively via args/flags.
- Mutating commands SHOULD support `--dry-run`; if impossible, document why.
- Command signatures and flag semantics MUST stay consistent across groups.

### 6. Architecture

- Keep CLI commands thin; place domain logic in core/application modules.
- Use one registry wrapper (`defineToolCommand`-style abstraction) per language stack.
- Infrastructure commands (`tools`, `health`) MAY be outside tool registry, but MUST follow envelope rules.
- Do not enforce one folder tree; enforce interface and contract invariants.

## Build Playbook (New Tooling)

1. Inventory human workflows and derive domain action list.
2. Build entity CRUD matrix; fill all required operations.
3. Define command grammar (`group action`, shared flags, naming conventions).
4. Implement envelope + exit code contract first.
5. Implement tool registry wrapper and `tools --json`.
6. Implement `health --json` and config/capability introspection.
7. Implement primitives (read-only first, mutating second).
8. Validate with real agent loops; add shortcuts only after repeated-chain evidence.

## Migration Playbook (Legacy CLI)

1. Capture current surface (`--help`, common workflows, failure modes).
2. Add JSON envelope without breaking text mode.
3. Introduce registry wrapper; backfill tool metadata incrementally.
4. Add `tools --json` generated from registry.
5. Add `health --json` with fix commands and blocked/degraded semantics.
6. Split workflow commands into primitives; keep legacy command as thin compatibility wrapper.
7. Mark wrappers as deprecated with explicit replacement commands.
8. Preserve old flags where possible; normalize on new contract for new commands.
9. Remove deprecated wrappers only after downstream automation migration window.

## Cross-Language Mapping

- TypeScript/Bun: command framework + registry wrapper + envelope helpers (`ok/fail/emitRaw`).
- Go: command framework (e.g. Cobra) + central `[]ToolMeta` registry + shared envelope writer.
- Rust: command framework (e.g. Clap) + `ToolMeta` registry + serde envelope structs.
- Language is implementation detail; contract is invariant.

## Audit Output Contract

When auditing, produce:

1. `findings`: parity gaps, bundled commands, contract breaks, CRUD holes.
2. `severity`: critical/high/medium/low with explicit impact.
3. `surface plan`: exact command additions/splits/deprecations.
4. `compatibility plan`: rollout order, wrappers, deprecation window.
5. `validation`: concrete agent tasks proving autonomy improved.

## Acceptance Checks

- Agent can discover full capability surface via `tools --json` only.
- Agent can classify health readiness via `health --json` only.
- Agent can run one realistic end-to-end workflow without scraping text output.
- Error paths return stable `error.code` + `hint` and correct exit code.
- JSON mode never leaks non-envelope output on `stdout`.

## Graduation Heuristic

- Start with primitives.
- Add shortcuts only for repeated, measured chains.
- Optimize internals only after proven bottleneck.
- Never remove primitives after shortcut introduction.

## Anti-Patterns

Load `references/index.md` first, then `references/anti-patterns.md` for deep diagnostics.

## Ecosystem Design

Load `references/index.md` first, then `references/ecosystem-design.md` for cross-tool architecture work.

## Reference Index

- `references/index.md` - routing guide for compose reference files.
- `references/anti-patterns.md` - audit anti-pattern catalog.
- `references/ecosystem-design.md` - ecosystem boundary and evolution rules.
