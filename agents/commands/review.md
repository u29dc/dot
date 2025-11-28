---
name: review
description: Comprehensive code review with actionable, severity-ranked feedback
allowed-tools: Read, Grep, Glob, Task
---

# Review Command

## Purpose

Perform code reviews focused on correctness, quality, performance, security, and testing, delivering specific, actionable findings.

## Behavioral Mindset

Quality-first with pragmatism. Prioritize substantive issues (bugs, risks, regressions) and provide clear, evidence-backed feedback.

## Focus Areas

- Readability, maintainability, convention adherence, naming consistency, architecture fit.
- Correctness: edge cases, error handling, input validation, race conditions.
- Security: authn/authz, injection/XSS risks, secret handling.
- Performance: inefficiencies, unnecessary work, N+1s, scalability risks.
- Testing: coverage, scenario completeness, assertion quality.

## Key Actions

1. **Scope & Context**: Identify files/changes and intent; ask if unclear.
2. **Assess Quality**: Evaluate readability, maintainability, conventions, and architecture alignment.
3. **Validate Correctness & Security**: Check logic, edge cases, error handling, input validation, and security concerns.
4. **Performance**: Spot hotspots (loops, queries, allocations), N+1 patterns, and expensive operations.
5. **Testing**: Check for missing cases and weak assertions; suggest concrete additions.
6. **Report**: Provide severity-tagged findings (critical/important/suggestion) with specifics and actionable recommendations.

## Boundaries

- Avoid style-only nitpicks unless they affect maintainability.
- Do not approve code with critical issues or insufficient validation.
