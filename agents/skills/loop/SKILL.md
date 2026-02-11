---
name: loop
description: Generate autonomous agent loop setups with PRD, prompt, harness, and progress tracking
argument-hint: [goal or requirements]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Loop

Generate deterministic autonomous-loop scaffolding (`prd.json`, `PROMPT.md`, `loop.sh`, `progress.txt`) with strict story decomposition and quality-gate wiring.

## How to Use

- `/loop` - detect project context and scaffold a new loop setup
- `/loop <goal>` - scaffold setup for explicit objective
- `/loop <goal> --prefix MIG --dir ./automation` - scaffold with explicit ID prefix and output path

## Arguments

Optional: `$ARGUMENTS`

- `goal` (free text): target outcome for loop execution
- `--prefix <ID>`: override story ID prefix (`ENG`, `MIG`, `RSH`, etc.)
- `--dir <path>`: output directory (default project root)
- `--no-quality-gate`: non-dev loops where compile/test/lint gate is not applicable
- `--continue`: append new stories to existing loop setup

## Generated Outputs

- `prd.json`: source of truth for story queue and completion state
- `PROMPT.md`: agent instruction protocol for one-story-per-iteration execution
- `loop.sh`: harness for repeated `claude -p` runs and completion detection
- `progress.txt`: append-only execution log + codebase patterns

Templates live in `agents/skills/loop/templates/`.

## New Setup Workflow

1. Detect project and toolchain context.
2. Derive quality-gate command and commit format rules.
3. Clarify scope, deliverables, constraints, and done criteria.
4. Choose ID prefix from rules or explicit override.
5. Decompose into right-sized stories in dependency order.
6. Generate `prd.json` from template with populated stories.
7. Generate `PROMPT.md` with concrete `{QUALITY_CMD}` and `{COMMITLINT_RULES}` substitution.
8. Copy `loop.sh`, mark executable.
9. Copy `progress.txt`; add setup note to `CLAUDE.md` if present.
10. Create branch `loop/<descriptive-name>`, commit scaffold, report run commands.

## Continue Workflow (`--continue`)

1. Validate existing loop files exist in target directory.
2. Parse existing `prd.json` and identify highest story ID.
3. Decompose new goal into additional stories following same rules.
4. Continue ID sequence; set new stories `passes: false`.
5. Append stories to `prd.json`; update description if scope widened.
6. Update `PROMPT.md` context scope only; keep phases and gates stable.
7. Append continuation block to `progress.txt`.
8. Commit extension with explicit ID range summary.

## Story Rules

### ID Prefixes

| Project Type         | Prefix |
| -------------------- | ------ |
| Engineering/features | `ENG-` |
| Migration            | `MIG-` |
| Research             | `RSH-` |
| Sales                | `SLS-` |
| Creative             | `CRE-` |
| Infrastructure       | `INF-` |
| Documentation        | `DOC-` |
| Refactor             | `REF-` |
| Testing              | `TST-` |

Format: `{PREFIX}{NNN}` with 3-digit zero padding.

### Sizing and Scope

- MUST size each story to one context window (~20-30 minutes).
- MUST split oversized stories until independently completable.
- MUST merge trivial micro-edits into meaningful stories.
- MUST order categories: `setup -> core -> integration -> polish`.

### Acceptance Criteria Contract

- MUST use signal-as-state wording (`X is Y`, not vague verbs).
- MUST avoid ambiguous verbs: `configured`, `done`, `implemented`, `working`.
- MUST include final criterion:
    - software loop: `Quality gate passes`
    - non-software loop: `Output file saved to <path>`

### Dependencies

- Use `priority` for linear flows.
- Use `dependsOn` for non-linear graphs.
- `PROMPT.md` MUST instruct skipping blocked stories.

## Prompt Adaptation Rules

### Software loops

- Keep full implement -> verify -> commit cycle.
- Verify phase MUST run concrete quality gate command.

### Non-software loops (`--no-quality-gate`)

- Replace verify phase with explicit acceptance-criteria self-check.
- Keep one-story-per-iteration and completion signaling semantics unchanged.
- Keep append-only progress and commit/update flow.

## Critical Rules

- MUST replace all template placeholders with concrete values.
- MUST include explicit "search before assuming missing" instruction in generated prompt.
- MUST keep generated `PROMPT.md` self-contained and avoid directives that require launching nested/secondary agent sessions.
- MUST keep `loop.sh` Claude CLI flags compatibility-safe: if `--output-format stream-json` is used, include `--verbose`; optional flags must be capability-detected.
- MUST keep `PROMPT.md` concise (target <=120 lines).
- MUST use `<promise>COMPLETE</promise>` stop signal exactly.
- MUST keep `progress.txt` append-only.
- MUST keep iteration flow strict: implement -> verify -> commit -> update state.
- SHOULD warn about runtime/model cost for long loops.
- SHOULD use safer permission modes on bare metal; permissive mode is acceptable in isolated containers/VMs.

## Quality Standards

- Generated JSON is valid and parseable.
- Generated shell harness is executable and signal-safe.
- `PROMPT.md` contains concrete quality/commit rules, no unresolved placeholders.
- Stories are right-sized and use signal-as-state acceptance criteria.
- Continuations preserve historical state and ID sequencing.
- Branch and initial commit are created before reporting completion.

## Run Commands to Report

After scaffold creation, report at minimum:

- loop run: `./loop.sh`
- log tail: `tail -f agent_logs/agent_*.log`
- branch name
- story count and first/last story IDs
