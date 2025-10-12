---
name: cleanup
description: Clean up refactoring requests and delegate to cleaner agent with structured safety plan
argument-hint: "[target]"
allowed-tools: Task
---

# Cleanup Command

## Purpose

Transform messy cleanup requests into structured refactoring plans. DO NOT refactor code yourself - that is the cleaner agent's role.

Accept messy, unstructured cleanup requests (including transcribed audio) and transform them into safe, systematic refactoring plans for the cleaner agent.

## Critical Constraints

- DO NOT explore codebase to find cleanup opportunities yourself
- DO NOT remove dead code or refactor directly
- ONLY transform user input → structured cleanup plan → call Task tool
- Organize user's cleanup intent, don't discover new cleanup targets

## Workflow

1. **Parse Intent**: Extract cleanup goals, target scope, and safety requirements from raw input
2. **Structure Plan**: Organize scattered cleanup ideas into systematic refactoring approach
3. **Format Delegation**: Create comprehensive cleanup brief from user input and conversation context only with:
    - Clear cleanup scope and objectives
    - Specific cleanup types (dead code, imports, structure, code smells)
    - Safety mode and validation requirements
    - Success criteria and metrics
    - Rollback and validation strategy
4. **Delegate Immediately**: Use Task tool to activate cleaner agent - this is your ONLY job

## Input Handling

**Raw input examples:**

- "clean up this components folder lots of unused stuff"
- "remove dead code and optimize imports maybe refactor some duplicated logic"
- "technical debt cleanup before new feature do it safe though"

**Structured output to cleaner:**

```
Cleanup Scope: src/components directory
Cleanup Types:
- Dead code detection and removal
- Unused import elimination
- Code duplication refactoring
Safety Mode: Safe (preserve all functionality with validation)
Success Criteria:
- No functionality loss or regressions
- All tests passing before and after
- Zero new errors or warnings
Validation Strategy: Run full test suite after each change
```

## Delegation Format

Always delegate to cleaner agent with this structure:

```
Activate cleaner agent with the following refactoring:

Cleanup Scope:
- [Files, directories, or components to clean]
- [Specific areas or modules]
- [Boundaries and exclusions]

Cleanup Types (what to address):
- Dead Code: [Unused functions, variables, files]
- Imports: [Unused imports, dependency optimization]
- Structure: [File organization, architectural improvements]
- Code Smells: [Duplication, complexity, maintainability issues]

Safety Mode: [Safe / Aggressive]
- Safe: Conservative cleanup with thorough validation at each step
- Aggressive: More comprehensive cleanup accepting calculated risks

Safety Requirements:
- [Validation steps required: tests, builds, manual checks]
- [Rollback strategy and backup plan]
- [Risk tolerance and acceptable changes]

Success Criteria:
- Zero functionality loss or behavioral changes
- All tests passing before and after cleanup
- Zero new errors or warnings introduced
- Successful builds throughout process

Validation Strategy:
- [Pre-cleanup baseline: tests, builds, metrics]
- [Continuous validation: after each change]
- [Post-cleanup verification: full regression check]

Expected Metrics:
- Lines of code removed
- Files affected or deleted
- Complexity reduction
- Import dependencies reduced

Priorities:
- [High priority cleanup areas]
- [Low risk vs high impact balance]
- [Quick wins vs thorough refactoring]

Reporting:
- Cleanup summary with before/after metrics
- Safety validation results
- Remaining technical debt identified
- Recommendations for ongoing maintenance
```

## Quality Standards

- Transform vague cleanup requests into specific, systematic refactoring plans
- Identify appropriate safety mode based on risk tolerance and context
- Define comprehensive validation strategy with rollback capability
- Ensure cleaner has complete context for safe, effective cleanup
- Specify measurable success criteria and expected metrics
