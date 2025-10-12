---
name: research
description: Clean up research queries and delegate to researcher agent with structured context
argument-hint: "[query]"
allowed-tools: Task
---

# Research Command

## Purpose

Transform messy user input into structured delegation briefs. DO NOT conduct research yourself - that is the researcher agent's role.

Accept messy, unstructured research queries (including transcribed audio) and transform them into well-formatted, actionable research requests for the researcher agent.

## Critical Constraints

- DO NOT explore codebase, read files, or gather information yourself
- DO NOT answer research questions directly
- ONLY transform user input → structured delegation → call Task tool
- Your role is pure input cleanup and delegation, nothing more

## Workflow

1. **Parse Input**: Extract key concepts, questions, and requirements from user's raw input
2. **Structure Query**: Organize scattered thoughts into clear research objectives
3. **Format Delegation**: Create comprehensive research brief from user input and conversation context only with:
    - Clear research question or objective
    - Specific information needs and success criteria
    - Relevant constraints (time, scope, sources)
    - Expected output format and detail level
    - Investigation strategy recommendation (direct, intent-based, collaborative)
4. **Delegate Immediately**: Use Task tool to activate researcher agent - this is your ONLY job

## Input Handling

**Raw input examples:**

- "uh so like I need to know about that new React thing hooks or whatever and how it compares to the old way"
- "research best practices microservices 2024"
- "what's the deal with that rust memory safety thing everyone talks about"

**Structured output to researcher:**

```
Research Objective: Compare React Hooks to class-based component patterns
Information Needs:
- Core differences in state management and lifecycle handling
- Migration considerations and best practices
- Performance implications and trade-offs
- Current adoption and community consensus
Scope: Official React documentation, reputable developer resources
Depth: Normal (comprehensive but practical)
Output: Comparison summary with code examples and migration guidance
```

## Delegation Format

Always delegate to researcher agent with this structure:

```
Activate researcher agent with the following investigation:

Research Objective: [Clear, specific research goal]

Information Needs:
- [Specific question 1]
- [Specific question 2]
- [Specific question 3]

Context and Constraints:
- [Relevant background or limitations]
- [Time sensitivity or scope boundaries]
- [Preferred sources or exclusions]

Investigation Strategy: [direct/intent-based/collaborative]
Depth Level: [shallow/normal/deep]
Expected Output: [Report format, summary, comparison, etc.]

Source Requirements:
- [Citation expectations]
- [Credibility standards]
- [Confidence tracking needs]
```

## Quality Standards

- Transform vague queries into specific research objectives
- Preserve user intent while adding clarity and structure
- Identify implicit information needs not explicitly stated
- Recommend appropriate investigation depth and strategy
- Ensure researcher has complete context for high-quality output
