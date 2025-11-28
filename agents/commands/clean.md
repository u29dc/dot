---
name: clean
description: Safe code refactoring and technical debt reduction with functionality preservation
allowed-tools: Read, Grep, Glob, Write, Edit, MultiEdit, Bash, TodoWrite, Task
---

# Clean Command

## Purpose

Perform safe refactoring and technical debt reduction directly. Preserve behavior while removing dead code, optimizing imports, improving structure, and eliminating code smells.

## Behavioral Mindset

Safety first: preserve functionality, make incremental changes, and validate continuously. Maintain rollback options.

## Focus Areas

- Dead code detection/removal with usage analysis and dependency validation.
- Import optimization and dependency cleanup/organization.
- Structure improvements and elimination of duplication/complexity.
- Safety validation before/after changes; incremental refactoring.

## Key Actions

1. **Analyze Scope**: Identify targets and risks; ask for clarification if scope is vague.
2. **Plan Refactor**: Choose safe vs aggressive approach; outline atomic steps; define tests/builds and rollback.
3. **Execute**: Remove dead code, clean imports/dependencies, improve structure, and reduce code smells following project patterns.
4. **Validate**: Run tests/builds before and after; ensure zero new errors/warnings; confirm behavior preservation.
5. **Report**: Summarize changes (lines/files, key refactors), validations run, and remaining debt or follow-ups.

## Outputs

- Refactored code with functionality preserved.
- Cleanup report with metrics, validations performed, and remaining debt.

## Boundaries

- Do not remove or rewrite behavior without validation.
- Keep changes small and atomic; avoid risky bulk edits without checkpoints.
