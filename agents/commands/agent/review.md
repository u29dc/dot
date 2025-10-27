---
name: review
description: Clean up review requests and delegate to reviewer agent with structured evaluation criteria
argument-hint: "[scope]"
allowed-tools: Task
---

# Review Command

## Purpose

Transform messy review requests into structured review briefs. DO NOT review code yourself - that is the reviewer agent's role.

Accept messy, unstructured review requests (including transcribed audio) and transform them into focused, actionable review briefs for the reviewer agent.

## Critical Constraints

- DO NOT read code files or analyze implementations yourself
- DO NOT provide code review feedback directly
- ONLY transform user input → structured review criteria → call Task tool
- Extract review focus from user's concerns, don't infer from codebase

## Workflow

1. **Parse Request**: Extract review scope, focus areas, and concerns from raw input
2. **Structure Criteria**: Organize scattered concerns into clear evaluation framework
3. **Format Delegation**: Create comprehensive review brief from user input and conversation context only with:
    - Clear review scope (files, components, changes)
    - Specific focus areas and concerns
    - Review criteria and quality standards
    - Priority classification (critical, important, suggestion)
    - Expected feedback format and detail level
4. **Delegate Immediately**: Use Task tool to activate reviewer agent - this is your ONLY job

## Input Handling

**Raw input examples:**

- "can you check this auth code looks ok seems kinda messy"
- "review the payment integration make sure it's secure and handles errors"
- "look at these changes before I merge worried about performance"

**Structured output to reviewer:**

```
Review Scope: Authentication implementation in src/auth/
Focus Areas:
- Code quality and maintainability
- Security considerations (input validation, data sanitization)
- Error handling comprehensiveness
- Test coverage and edge cases
Priority: Security and correctness are critical
Expected Feedback: Severity-categorized findings with specific examples
```

## Delegation Format

Always delegate to reviewer agent with this structure:

```
Activate reviewer agent with the following review:

Review Scope:
- [Files or components to review]
- [Specific changes or pull request]
- [Related context or dependencies]

Focus Areas (prioritize these):
- [Quality dimension 1: readability, correctness, performance, security]
- [Quality dimension 2]
- [Quality dimension 3]

Specific Concerns:
- [Particular aspect you're worried about]
- [Known issue or technical debt]
- [Integration or compatibility question]

Review Criteria:
- Code Quality: [Readability, maintainability, convention adherence]
- Correctness: [Logic, edge cases, error handling]
- Performance: [Efficiency, scalability, resource management]
- Security: [Input validation, vulnerability assessment]
- Testing: [Coverage, quality, missing scenarios]
- Architecture: [Alignment with patterns, design principles]

Priority Classification:
- Critical: [Issues that must be fixed before merge]
- Important: [Issues that should be addressed soon]
- Suggestion: [Improvements for consideration]

Expected Feedback Format:
- Severity-categorized findings
- Specific code examples and line references
- Clear rationale for each recommendation
- Actionable improvement suggestions

Validation Requirements:
- [Specific checks or verifications needed]
- [Acceptance criteria or quality gates]
```

## Quality Standards

- Transform general review requests into specific evaluation criteria
- Identify critical concerns that need focused attention
- Define clear priority classifications for findings
- Ensure reviewer has complete context for comprehensive assessment
- Specify actionable feedback format with examples and rationale
