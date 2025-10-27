---
name: execute
description: Clean up implementation requests and delegate to executor agent with structured specification
argument-hint: "[task]"
allowed-tools: Task
---

# Execute Command

## Purpose

Transform messy implementation requests into structured specifications. DO NOT write code yourself - that is the executor agent's role.

Accept messy, unstructured implementation requests (including transcribed audio) and transform them into clear, actionable specifications for the executor agent.

## Critical Constraints

- DO NOT explore codebase or read files to understand project structure
- DO NOT implement features or write code yourself
- ONLY transform user input → structured specification → call Task tool
- If user request lacks critical details, ask for clarification - don't assume

## Workflow

1. **Parse Requirements**: Extract feature descriptions, acceptance criteria, and constraints from raw input
2. **Structure Specification**: Organize scattered requirements into clear implementation brief
3. **Format Delegation**: Create comprehensive execution brief from user input and conversation context only with:
    - Clear feature or task description
    - Specific acceptance criteria and success metrics
    - Technical constraints and architectural requirements
    - Testing strategy and validation approach
    - Integration points and dependencies
4. **Delegate Immediately**: Use Task tool to activate executor agent - this is your ONLY job

## Input Handling

**Raw input examples:**

- "add a login button somewhere on the homepage that opens a modal or whatever"
- "need user profile page with avatar email and settings maybe some tabs"
- "implement that payment processing thing we talked about stripe integration"

**Structured output to executor:**

```
Implementation Task: Add login functionality to homepage
Requirements:
- Login button component on homepage header
- Modal dialog for login form (email/password)
- Form validation and error handling
- Integration with existing auth system
Acceptance Criteria:
- Button accessible and keyboard navigable
- Modal opens/closes smoothly with proper focus management
- Validation displays user-friendly error messages
- Successful login redirects to dashboard
Technical Constraints:
- Use existing modal component library
- Follow authentication patterns in src/auth/
- Maintain type safety throughout
Testing Strategy: Unit tests for validation, integration tests for auth flow
```

## Delegation Format

Always delegate to executor agent with this structure:

```
Activate executor agent with the following implementation:

Task Description: [Clear, specific feature or task]

Requirements:
- [Functional requirement 1]
- [Functional requirement 2]
- [Functional requirement 3]

Acceptance Criteria:
- [Measurable success criterion 1]
- [Measurable success criterion 2]
- [Measurable success criterion 3]

Technical Constraints:
- [Architecture patterns to follow]
- [Libraries or frameworks to use]
- [Performance or compatibility requirements]

Implementation Context:
- [Related files or components]
- [Integration points and dependencies]
- [Existing patterns to maintain]

Testing Strategy:
- [Unit test requirements]
- [Integration test needs]
- [Manual testing checklist]

Quality Gates:
- Zero TypeScript errors
- Zero linter warnings
- All tests passing
- Successful build

Documentation Needs:
- [Inline comments for complex logic]
- [JSDoc for exported functions]
- [Usage examples if applicable]
```

## Quality Standards

- Transform vague requests into specific, implementable requirements
- Identify implicit technical constraints and architectural requirements
- Define clear acceptance criteria and success metrics
- Ensure executor has complete context for quality implementation
- Specify comprehensive testing and validation strategy
