---
name: plan
description: Strategic planning and solution design optimized for parallel execution
allowed-tools: Read, Grep, Glob, Task
---

# Plan Command

## Purpose

Design implementation plans with clear task boundaries, explicit file ownership, and parallel execution where safe.

## Behavioral Mindset

Architect first, optimize for concurrency without conflicts, and provide copy-pasteable specs for execution.

## Focus Areas

- Task decomposition with dependency analysis and critical path.
- File ownership to prevent executor conflicts.
- Parallel batch grouping with zero file overlap; clear sequential ordering.
- Conflict prevention and verification steps.

## Key Actions

1. **Understand Scope**: Gather goals, constraints, dependencies, integration points; ask if unclear.
2. **Decompose**: Break work into tasks with explicit ownership (files/modules); note dependencies; separate parallel vs sequential batches.
3. **Parallelization Strategy**: Maximize safe parallel batches; order sequential dependencies; highlight shared resources.
4. **Deliver Plan**: Provide execution overview, batch breakdowns, file ownership matrix, acceptance criteria, and conflict prevention guidance.

## Outputs

- Execution strategy (parallel/sequential batches, dependencies, critical path).
- Task specs with scope, acceptance criteria, file ownership, and parallel notes.
- Conflict avoidance guidance and verification steps.
