# Compose Ecosystem Design

Rules for multi-tool ecosystems where one agent composes several CLIs in a single workflow.

## Ecosystem Invariants

- Every tool MUST expose orientation surface:
    - `<tool> tools --json`
    - `<tool> health --json`
    - `<tool> config show --json` (or equivalent capability/config introspection)
- Every tool MUST use the same JSON envelope keys: `ok`, `data` or `error`, `meta`.
- Every tool MUST map blocked prerequisites to exit code `2`.
- Every tool MUST keep JSON mode stdout envelope-only (no logs/tables mixed in).

## Boundary Contract

- Each tool owns its writable scope; cross-tool writes are forbidden.
- Agent owns orchestration artifacts (`context.md`, analysis notes, workflow state).
- Tool outputs/configs SHOULD remain inspectable and versionable.
- Read-only commands MUST NOT mutate state.

## Interface Compatibility Contract

- Standardize IDs, timestamps, currency/units, and pagination semantics across tools.
- Keep flag semantics consistent (`--from`, `--to`, `--limit`, `--cursor`, `--sort`).
- Align error code families so cross-tool handling logic is reusable.
- Align mutating safety semantics (`--dry-run`, confirmation policy, idempotency markers).

## Discovery and Metadata Strategy

- Use registry-backed tool catalogs as source of truth.
- Include per-command metadata required for orchestration:
    - `name`, `command`, `category`, `parameters`, `outputFields`
    - `outputSchema`, `inputSchema` when structured
    - `idempotent`, `rateLimit`, `example`
- Prefer dynamic discovery against external APIs (`list-types`, `describe-type`, `query --type`).
- Avoid command-per-endpoint explosion that drifts with upstream APIs.

## Interop Data Contract

- Define canonical date/time format (e.g. ISO-8601) and apply universally.
- Define canonical identity format per entity and keep stable across commands.
- Document numeric units explicitly (minor/major currency units, percentages, durations).
- Ensure cross-tool joins require zero ad-hoc parsing adapters.

## Shared Context Contract

`context.md` SHOULD track:

- available tools and capability summaries
- constraints/assumptions
- current workflow state
- recent outcomes, failures, and next actions

Keep context concise and factual; this file is orchestration memory, not narrative docs.

## New Tool Onboarding Checklist

1. Implement envelope + exit code invariants.
2. Implement registry-backed `tools --json`.
3. Implement `health --json` with fix actions and readiness states.
4. Normalize IDs/dates/pagination to ecosystem contracts.
5. Prove one end-to-end agent workflow chaining existing tools + new tool.
6. Add migration notes if any shared contract changed.

## Capability Evolution Loop

1. Agent executes workflows from primitives.
2. Capture exact failure points (command, args, envelope, exit code).
3. Add smallest missing primitive with stable contract.
4. Re-run workflow and verify autonomy gain.
5. Promote repeated chains to shortcuts without removing primitives.

## Release and Compatibility Safety

- Preserve primitive contracts when adding shortcuts/wrappers.
- Version schemas when breaking changes are unavoidable.
- Provide explicit deprecation windows and replacement commands.
- Keep backward-compatible wrappers during migration windows.
- Validate downstream automations before removing legacy surfaces.
