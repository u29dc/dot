---
name: compose
description: Apply agent-native architecture patterns for composable, atomic tools
argument-hint: [file or audit]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Compose

Design every tool, CLI, and service so AI agents can discover, compose, and loop over it to achieve outcomes nobody explicitly coded.

## How to Use

- `/compose` - apply agent-native thinking to any software design in this conversation
- `/compose <file>` - evaluate a CLI/tool against agent-native principles
- `/compose audit` - full parity, granularity, and CRUD audit of a codebase

## When to Apply

Reference these guidelines when:

- Building new CLI tools or services
- Refactoring for composability
- Evaluating whether a tool follows agent-native principles
- Designing how multiple tools interact
- Reviewing architecture through an agent-native lens
- Planning any software where an AI agent is a first-class user

## Role

When asked to build, review, or refactor any tool:

1. **Evaluate** the current design against the five principles below
2. **Identify** where it falls short (parity gaps, bundled judgment, opaque output, CRUD holes)
3. **Propose** concrete changes - new commands, flag additions, output formats, structural refactors
4. **Build** with atomic tools, machine-readable output, and explicit completion signals from day one

When handed an existing tool or codebase: read it, understand what it does, then propose how to reshape it so an agent can use it effectively. Don't just critique - produce the improved architecture.

## The Core Idea

A **feature** is not code you write. A feature is an **outcome described in a prompt**, achieved by an agent with tools, operating in a loop until the outcome is reached.

CLI commands are tools. The agent is Claude Code (or any agent with bash access). The loop is the agent retrying, adjusting, and composing commands until the job is done.

**Design every tool as if an agent will use it - because one will.**

## Five Principles

### 1. Parity

Anything a human can do in a domain, the toolset must also support.

If a user can do it through a web UI, an API dashboard, or a manual workflow, the CLI must expose equivalent capability. No orphan actions.

**Audit:** List every action possible in the domain. Can the agent accomplish each one?

### 2. Granularity

Each command does one atomic thing. Judgment stays with the agent.

```bash
# WRONG — bundles judgment into the tool
tool analyze-and-recommend --input data.csv

# RIGHT — atomic primitives, agent decides
tool fetch --source data.csv --format json
tool list --category expenses --format json
tool report --type summary --format json
# Agent reads all outputs, reasons, forms its own recommendation
```

**Test:** To change behavior, do you edit a prompt or refactor code?

### 3. Composability

Atomic tools + parity = new capabilities from new prompts, zero code.

A "weekly review" feature is just a prompt:

```
"Fetch this week's transactions, compare against last week, flag anomalies,
and summarize trends."
```

No code written. Agent uses `fetch`, `list`, `report`, and judgment.

### 4. Emergent Capability

Because tools are composable, the agent handles requests nobody designed for. When it fails, that reveals a tool gap—add the missing primitive.

**Flywheel:** Build atomic tools → Use via agent → Agent hits a wall → Add missing primitive → Repeat.

### 5. Improvement Over Time

- **Context accumulation** — workspace files, context.md, saved outputs
- **Prompt refinement** — better prompts for common workflows
- **Tool evolution** — primitives graduate to domain shortcuts when patterns solidify

## Tool Design Rules

### Atomic by Default

One verb, one noun, predictable output.

```bash
# Good
tool search --query "term" --limit 10
tool get --id 12345
tool update --id 12345 --field status --value done
tool delete --id 12345

# Bad — workflow-shaped
tool find-and-update-all-matching --query "term" --set status=done
```

### Output for Machines AND Humans

Human-readable default. `--format json` (or `--json`) for agent consumption. Structured output lets the agent parse, filter, and reason.

```bash
tool list items                     # Pretty table for humans
tool list items --format json       # Structured for agents
```

### Consistent Interface Conventions

Apply across every tool in an ecosystem:

| Convention    | Pattern                                 | Example                       |
| ------------- | --------------------------------------- | ----------------------------- |
| Subcommands   | `tool verb noun`                        | `tool view accounts`          |
| Filters       | `--from`, `--to`, `--limit`, `--filter` | `tool list --from 2026-01-01` |
| Output format | `--format json\|table\|csv`             | `tool list --format json`     |
| Verbosity     | `--quiet` / `--verbose`                 | Suppress or expand output     |
| Dry run       | `--dry-run`                             | Show what would happen        |
| Help          | `tool --help`, `tool verb --help`       | Self-documenting              |

### CRUD Completeness

For every entity a tool manages, verify all four operations exist. Document any operations handled externally (e.g., only possible through a web UI). Gaps are fine if acknowledged—orphan operations are not.

### Exit Codes and Error Output

```
Exit 0  — success
Exit 1  — user error (bad args, not found)
Exit 2  — system error (network, auth, API failure)
```

Errors to stderr, data to stdout. Always. Agents pipe stdout; they need to trust it.

### No Mandatory Interactive Prompts

Every input must be passable as a flag or argument. Interactive mode is fine as a human convenience, never as the only interface.

### Dynamic Capability Discovery

When wrapping an external API, prefer discovery over static mapping:

```bash
# Instead of a command per endpoint:
tool api list-types                  # What's available?
tool api query --type <discovered>   # Query any type

# New API capabilities work automatically
```

## File and Data Conventions

### Shared Workspace

Tools and agent work in the same space. The agent reads tool output, writes analysis, and maintains state.

```
~/workspace/                         # Or project root
├── context.md                       # Agent reads at session start
├── {tool-a}/                        # Tool A's data directory
│   ├── exports/                     # Tool output snapshots
│   └── config.json                  # Tool config
├── {tool-b}/                        # Tool B's data directory
├── analysis/                        # Agent-generated cross-tool work
└── logs/                            # Session logs
```

Each tool owns its directory. Tools never write to another tool's directory. The agent orchestrates across all of them.

### The context.md Pattern

Portable working memory. Agent reads at session start, updates as state changes.

```markdown
# Context

## Tools Available

- tool-a: [brief capability description]
- tool-b: [brief capability description]

## Current State

- [key state facts the agent needs]

## Recent Activity

- [what happened recently]

## Preferences

- [user preferences that affect agent behavior]
```

### File Naming

| Type              | Pattern                   | Example                  |
| ----------------- | ------------------------- | ------------------------ |
| Exports/snapshots | `{type}-{date}.json`      | `report-2026-02-03.json` |
| Saved configs     | `{descriptive-name}.json` | `weekly-filter.json`     |
| Agent analysis    | `{topic}-analysis.md`     | `cost-analysis.md`       |

### Files vs Database

At single-user/personal tool scale: files. They're inspectable, portable, version-controllable, and agents reason about them natively. Reach for SQLite when you genuinely need indexed queries over thousands of records.

## What Good Looks Like

**Good tool:** `tool search --query "term" --limit 20 --format json`

- Atomic (one action)
- Filterable (query, limit)
- Machine-readable output
- Composable (agent pipes output to next step)
- Self-documenting (`--help`)

**Good ecosystem:** Agent chains tool A's output into tool B's input, filters, reasons, and produces a result neither tool was designed to create. The "feature" exists only as a prompt.

**Good prompt-as-feature:**

```
"Fetch all items from the last 7 days, cross-reference against the budget
data, flag anything over threshold, and write a summary."
```

No code written. Agent loops with atomic commands until the outcome is achieved.

## What Bad Looks Like

- **Workflow-shaped commands** — `tool find-and-rank-best` bundles search + ranking + judgment. Can't reuse search alone.
- **No structured output** — Tool only outputs pretty tables or HTML. Agent can't parse it.
- **Interactive-only input** — Tool prompts "Enter your query:" and blocks. Agent can't automate.
- **Silent failures** — Exit 0 on error. Agent thinks it succeeded.
- **CRUD gaps** — Can create and read but not update or delete.
- **No --help** — Agent guesses at flags and behavior.
- **Defensive over-constraining** — Strict enums prevent the agent from passing valid but unanticipated values through to the underlying API.

## Anti-Patterns

Read `references/anti-patterns.md` for the full diagnostic checklist.

## Building a New Tool

1. **List domain actions** — Everything a human can do (parity audit)
2. **Decompose into primitives** — Each action → smallest atomic command
3. **Design CLI interface** — Subcommands, flags, output formats per conventions
4. **Implement with --format json** — Structured output from day one
5. **Verify CRUD** — Every entity, all four operations
6. **Test via agent** — Ask Claude Code to accomplish a task. Where it stalls = next primitive
7. **Write context.md entry** — Document capabilities for agent consumption
8. **Iterate from usage** — Agent failures reveal gaps. Add primitives, not workflows.

## Evaluating an Existing Tool

When handed an existing CLI or codebase to assess:

1. **Map current commands** — What exists? What's each command's granularity?
2. **Parity audit** — What can the domain do that the tool can't?
3. **Granularity audit** — Which commands bundle multiple decisions?
4. **Output audit** — Is structured (JSON) output available everywhere?
5. **Interface audit** — Interactive prompts? Missing --help? Inconsistent flags?
6. **CRUD audit** — For each entity, which operations are missing?
7. **Propose refactored architecture** — Concrete new command structure, not just critique

## Graduating Patterns

| Stage                       | Example                                   | When to progress                       |
| --------------------------- | ----------------------------------------- | -------------------------------------- |
| Agent loops with primitives | Agent runs 5 commands to produce a report | Always start here                      |
| Add a domain shortcut       | `tool compare --ids 1,2,3`                | Same sequence repeats often            |
| Optimize hot path           | Logic moves to compiled code              | Performance matters, pattern is stable |

**Keep primitives available.** Domain shortcuts are conveniences, not gates.

## Reference Index

- `references/anti-patterns.md` — Named anti-patterns with examples + full diagnostic checklist. Read when auditing existing tools or reviewing new designs.
- `references/ecosystem-design.md` — Cross-tool composition patterns, shared workspace conventions, adding new tools. Read when planning how tools interact or onboarding a new tool into an ecosystem.
