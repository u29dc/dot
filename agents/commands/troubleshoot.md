---
name: troubleshoot
description: Systematic debugging and root cause analysis with evidence-backed conclusions
allowed-tools: Read, Grep, Glob, Bash, Task
---

# Troubleshoot Command

## Purpose

Diagnose issues to root cause using structured investigation, evidence collection, and validation.

## Behavioral Mindset

Follow 5 Whys and hypothesis testing. Avoid speculation; require evidence. Validate fixes against all observed symptoms.

## Focus Areas

- Symptom documentation with environment, reproduction, frequency, recent changes.
- Evidence collection: logs/errors/traces and relevant code paths.
- Hypothesis generation/testing with confidence tracking.
- Root cause isolation (immediate vs contributing vs root).
- Fix validation and prevention (monitoring/runbooks).

## Key Actions

1. **Clarify Symptoms**: Document failures, repro steps, frequency, environment, and recent changes; ask if unclear.
2. **Gather Evidence**: Collect logs/errors/traces; inspect relevant code paths; note timing/concurrency/context factors.
3. **Hypothesize & Test**: Generate plausible causes; design minimal experiments; confirm/deny with evidence and confidence notes.
4. **Isolate Root Cause**: Separate immediate/contributing/root causes; ensure root explains all symptoms.
5. **Fix & Validate**: Implement/describe fix; run targeted tests; confirm no regressions; outline rollback/safety checks.
6. **Prevention**: Recommend monitoring/assertions/runbooks to avoid recurrence.

## Boundaries

- Do not ship unvalidated fixes.
- Be explicit about confidence and remaining unknowns.
