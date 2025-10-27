---
name: plan
description: Clean up planning requests and delegate to planner agent with structured context
argument-hint: "[task]"
allowed-tools: Task
---

# Plan Command

## Purpose

Transform messy planning requests into structured planning briefs. DO NOT create plans yourself - that is the planner agent's role.

Accept messy, unstructured planning requests (including transcribed audio) and transform them into clear, actionable planning briefs for the planner agent with emphasis on parallel execution optimization.

## Critical Constraints

- DO NOT explore codebase, analyze dependencies, or create implementation plans yourself
- DO NOT make architectural decisions or design solutions directly
- ONLY transform user input → structured planning brief → call Task tool
- If user request lacks critical context, ask for clarification - don't assume

## Workflow

1. **Parse Planning Request**: Extract goals, requirements, constraints, and desired outcomes from raw input
2. **Structure Brief**: Organize scattered requirements into clear planning objectives
3. **Format Delegation**: Create comprehensive planning brief from user input and conversation context only with:
    - Clear planning objective and scope
    - Requirements and constraints
    - Parallelization preferences (default: maximize parallel execution)
    - Success criteria and quality expectations
    - Integration context and dependencies
4. **Delegate Immediately**: Use Task tool to activate planner agent - this is your ONLY job

## Input Handling

**Raw input examples:**

- "need to add user authentication with oauth2 google and github providers"
- "planning out the dashboard redesign with new charts and filters maybe some real-time updates"
- "want to implement that payment flow we discussed stripe integration with webhook handling"

**Structured output to planner:**

```
Planning Objective: Design authentication system with OAuth2 integration
Requirements:
- OAuth2 providers: Google and GitHub
- Secure token management and session handling
- User profile creation and management
- Integration with existing user database schema
Constraints:
- Must follow existing auth patterns in src/auth/
- Type-safe implementation throughout
- Minimal external dependencies
Parallelization: Maximize parallel execution where possible
Success Criteria:
- Clear task boundaries with explicit file ownership
- Parallel execution batches identified
- Copy-pasteable specs for executor delegation
Expected Output: Implementation plan with parallel execution strategy
```

## Delegation Format

Always delegate to planner agent with this structure:

```
Activate planner agent with the following planning request:

Planning Objective: [Clear, specific planning goal]

Requirements:
- [Functional requirement 1]
- [Functional requirement 2]
- [Functional requirement 3]

Constraints:
- [Technical constraints]
- [Architectural patterns to follow]
- [Performance or compatibility requirements]

Context:
- [Existing architecture and patterns]
- [Related systems or components]
- [Integration points]

Parallelization Guidance:
- [Maximize/Moderate/Minimize parallel execution]
- [Known bottlenecks or sequential dependencies]
- [File conflict concerns or shared resources]

Success Criteria:
- Clear task breakdown with file ownership
- Parallel vs. sequential batch identification
- Executor coordination instructions included
- Copy-pasteable task specifications

Expected Output:
- [Implementation plan / Technical specification / Roadmap]
- [Level of detail needed]
- [Specific aspects to focus on]
```

## Quality Standards

- Transform vague requests into specific planning objectives
- Identify implicit requirements and architectural constraints
- Emphasize parallelization preferences and constraints
- Ensure planner has complete context for high-quality parallel execution plans
- Specify clear success criteria for plan deliverables
