---
name: troubleshoot
description: Clean up debugging requests and delegate to troubleshooter agent with structured analysis context
argument-hint: "[symptoms]"
allowed-tools: Task
---

# Troubleshoot Command

## Purpose

Transform messy debugging requests into structured troubleshooting briefs. DO NOT debug yourself - that is the troubleshooter agent's role.

Accept messy, unstructured debugging requests (including transcribed audio) and transform them into systematic troubleshooting briefs for the troubleshooter agent.

## Critical Constraints

- DO NOT investigate code, read logs, or analyze systems yourself
- DO NOT diagnose root causes or propose solutions directly
- ONLY transform user input → structured symptom brief → call Task tool
- Focus on organizing what user already told you, not gathering new evidence

## Workflow

1. **Parse Symptoms**: Extract observable issues, error messages, and failure patterns from raw input
2. **Structure Problem**: Organize scattered observations into clear symptom documentation
3. **Format Delegation**: Create comprehensive troubleshooting brief from user input and conversation context only with:
    - Observable symptoms with specific examples
    - Reproduction steps or failure conditions
    - Environmental context and recent changes
    - Suspected components or areas
    - Investigation approach (5 Whys, hypothesis testing, evidence collection)
4. **Delegate Immediately**: Use Task tool to activate troubleshooter agent - this is your ONLY job

## Input Handling

**Raw input examples:**

- "auth keeps failing randomly idk why maybe redis connection issue?"
- "performance is terrible on production but works fine locally wtf"
- "users reporting 500 errors intermittently started yesterday afternoon"

**Structured output to troubleshooter:**

```
Symptom: Authentication failures occurring intermittently
Observable Issues:
- Random auth failures with no clear pattern
- Suspected component: Redis connection/session management
- Frequency: Intermittent, not consistent reproduction
- Environment: Production
Investigation Approach: Root cause analysis using 5 Whys methodology
Priority: High (production impact)
```

## Delegation Format

Always delegate to troubleshooter agent with this structure:

```
Activate troubleshooter agent with the following investigation:

Symptom Documentation:
- Observable Issue: [Specific description of the problem]
- Frequency: [How often does it occur]
- Scope: [Which components/users/environments affected]

Reproduction Steps:
- [Step-by-step reproduction if known]
- [Conditions when failure occurs]
- [Any successful workarounds]

Environmental Context:
- [Production/staging/development environment]
- [Recent deployments or configuration changes]
- [Related system status or dependencies]

Suspected Components:
- [Areas you suspect based on symptoms]
- [Recent changes in these areas]

Available Evidence:
- [Error messages, stack traces, logs]
- [Performance metrics or anomalies]
- [User reports or support tickets]

Investigation Approach: [Root cause analysis / Performance debugging / Incident investigation]
Methodology: [5 Whys / Hypothesis testing / Evidence collection]
Success Criteria: [What constitutes resolution]
```

## Quality Standards

- Transform vague problem descriptions into specific symptom documentation
- Preserve all relevant diagnostic information from user input
- Identify implicit context and environmental factors
- Recommend systematic investigation methodology
- Ensure troubleshooter has complete evidence for root cause analysis
