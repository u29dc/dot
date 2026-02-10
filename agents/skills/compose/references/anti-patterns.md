# Compose Anti-Patterns

Use during `/compose audit` to detect why agents stall, hallucinate, or require brittle glue code.

## Critical (blocks reliable automation)

### AP-01 Missing discovery surface

- Pattern: no `<tool> tools --json`, no stable catalog, or catalog hand-written and stale.
- Detection: catalog output missing `name/command/parameters/outputFields/idempotent/example`.
- Fix: add single-source registry and generate `tools --json` from it.

### AP-02 Missing readiness gate

- Pattern: no `<tool> health --json`, or health output has no actionable fix steps.
- Detection: cannot classify `ready|degraded|blocked` without reading docs/source.
- Fix: add machine-readable checks with `checks[].fix`, stable statuses, exit `2` on blocked.

### AP-03 Non-deterministic JSON contract

- Pattern: JSON mode emits logs/tables on `stdout`, multiple lines, or shape changes by branch.
- Detection: piping `--json` output cannot be parsed as one envelope.
- Fix: enforce envelope-only `stdout`; send all logs/errors to `stderr`.

### AP-04 Unstable error semantics

- Pattern: free-form text errors, no stable `error.code`, no `hint`, wrong exit codes.
- Detection: same failure class returns different codes/messages across commands.
- Fix: normalize to `{ ok:false, error:{ code, message, hint }, meta }` + stable `0/1/2`.

### AP-05 Workflow mega-commands

- Pattern: one command does fetch + score + decide + recommend.
- Detection: behavior changes require code edits instead of prompt changes.
- Fix: split into primitives; keep recommendation/judgment in agent loop.

### AP-06 Interactive-only paths

- Pattern: required prompts/TTY flows for core operations.
- Detection: cannot run end-to-end from pure flags/args.
- Fix: make all required inputs flag/arg driven; keep interactive mode optional only.

## High (causes drift, brittleness, or hidden risk)

### AP-07 CRUD holes

- Pattern: entities can be created/read but not updated/deleted (or vice versa).
- Detection: parity matrix shows missing operations with no documented external owner.
- Fix: add missing primitive or explicitly document external ownership.

### AP-08 Hidden side effects

- Pattern: commands write outside declared data scope or mutate state during read operations.
- Detection: read commands change files/db; outputs depend on hidden writes.
- Fix: isolate writable boundaries; make side effects explicit in command docs and metadata.

### AP-09 Inconsistent interface grammar

- Pattern: same concept uses different flag names or pagination semantics across commands.
- Detection: `--limit` means page size in one command and total rows in another.
- Fix: standardize grammar (`from/to/limit/cursor/sort`) and keep semantics invariant.

### AP-10 Hard-coded narrow enums

- Pattern: wrappers reject valid upstream values because local enums are over-restricted.
- Detection: upstream API accepts value but CLI blocks it.
- Fix: permit pass-through where safe; validate shape, not unnecessary vocabulary.

### AP-11 Mutating commands without guardrails

- Pattern: destructive commands execute immediately; no `--dry-run`/preview path.
- Detection: first execution can irreversibly mutate state with no inspection point.
- Fix: add dry-run and explicit confirmation strategy for destructive operations.

## Medium (hurts velocity and maintainability)

### AP-12 Weak help surface

- Pattern: root help exists, subcommand help missing or misleading.
- Detection: agent must read source to infer args.
- Fix: complete `--help` coverage at all levels with example invocations.

### AP-13 Thin output schemas

- Pattern: output fields implied by docs only; no schema metadata in tool catalog.
- Detection: agent cannot infer payload structure from `tools --json`.
- Fix: add `outputSchema` and `inputSchema` metadata for structured flows.

### AP-14 Pagination/date drift

- Pattern: mixed cursor/page/offset styles with inconsistent date formats.
- Detection: cross-command chaining requires per-command adapters.
- Fix: normalize date/time/ID/pagination contracts across tool groups.

## Fast Triage Protocol

1. Run `<tool> tools --json`; verify stable catalog and required metadata.
2. Run `<tool> health --json`; verify readiness status and actionable fixes.
3. Run representative read command with `--json`; assert one-line envelope on `stdout`.
4. Trigger a validation error; assert stable `error.code`, `hint`, and exit code.
5. Execute one realistic end-to-end workflow without scraping text output.

## Remediation Mapping

- Parity gap: add smallest missing primitive.
- Granularity gap: split bundled command into atomic commands.
- Discovery gap: implement registry-backed `tools --json`.
- Contract gap: enforce envelope + exit-code invariants centrally.
- Safety gap: add dry-run, explicit mutation semantics, and migration/deprecation notes.
