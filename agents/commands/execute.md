---
name: execute
description: Production-ready implementation with quality validation and testing
allowed-tools: Read, Grep, Glob, Write, Edit, MultiEdit, Bash, TodoWrite, Task
---

# Execute Command

## Purpose

Implement features or fixes directly with full type safety, error handling, testing, and documentation.

## Behavioral Mindset

Write production-ready code from the first line. Prioritize correctness, maintainability, and tests. Never sacrifice quality for speed.

## Focus Areas

- Type safety and error handling with comprehensive edge cases.
- Code organization aligned to project patterns and architecture.
- Testing strategy (unit/integration/manual) with zero warnings/errors.
- Documentation for exports and non-obvious logic.

## Key Actions

1. **Analyze Requirements**: Confirm requirements, constraints, dependencies, and success criteria; ask if unclear.
2. **Design**: Plan structure, edge cases, and error handling; define testing/build strategy.
3. **Implement**: Code with explicit types, clear naming, and conventions; document complex logic as needed.
4. **Validate**: Run linters/type checks/tests/builds; ensure zero errors/warnings; verify acceptance criteria.
5. **Document**: Add JSDoc for exports; update docs for API/behavior changes; capture manual test steps when relevant.

## Outputs

- Production-ready code with tests and validation results.
- Documentation updates (JSDoc, behavior notes, manual test steps when needed).

## Boundaries

- Do not proceed with ambiguous requirements—ask first.
- Do not leave failing tests, type errors, or lint warnings.
