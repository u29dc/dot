---
name: newskill
description: Create new Claude Code skills following established conventions
argument-hint: [skill name or description]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Newskill

Create or update skills with strict frontmatter, compact instructions, and progressive-disclosure structure.

## How to Use

- `/newskill` - interactive creation (name + purpose + style)
- `/newskill <name>` - create named skill and infer remaining metadata
- `/newskill <name> <description>` - create with explicit purpose line

## Arguments

Optional: `$ARGUMENTS`

- first token: skill name (`lowercase-hyphen`)
- remaining tokens: one-line description
- omit arguments to enter interactive requirement gathering

## Workflow

1. Gather concrete trigger/use examples from user request.
2. Determine style:
    - procedural (workflow-first)
    - reasoning (principle/reference-first)
3. Inspect nearest existing skills for convention drift.
4. Draft frontmatter with required fields.
5. Author compact SKILL body with strict sections.
6. Create or update `agents/skills/<name>/SKILL.md`.
7. Validate structure, references, and trigger clarity.

## Frontmatter Contract

Required fields:

- `name`: lowercase-hyphen, matches directory
- `description`: concise trigger summary
- `argument-hint`: bracketed hint for invocation
- `allowed-tools`: only tools genuinely needed

Optional fields are allowed only when required by runtime behavior.

## SKILL Body Contract

### Procedural skill baseline

1. H1 + one-line purpose
2. `## How to Use` (minimum 3 concrete invocations)
3. `## Arguments` (explicit parsing rules)
4. `## Workflow` (numbered deterministic steps)
5. domain-specific constraints
6. `## Quality Standards`

### Reasoning skill baseline

1. H1 + one-line purpose
2. `## How to Use`
3. `## When to Apply`
4. framing section (`Role`, `Philosophy`, or equivalent)
5. principle/rule sections
6. review/audit contract
7. reference index

## Writing Rules

- MUST be directive, dense, and operational.
- MUST avoid filler, narrative preamble, and redundant explanation.
- MUST keep one core action per bullet where possible.
- MUST use `MUST/SHOULD/NEVER` for enforceable constraints.
- MUST include defaults and exception conditions when relevant.
- SHOULD keep SKILL files compact by moving heavy material to `references/`.
- SHOULD keep references one level deep and linked directly from SKILL.
- NEVER create auxiliary docs (`README`, `CHANGELOG`, process notes) inside skill folders.

## Progressive Disclosure Rules

- Keep SKILL body focused on workflow and constraints.
- Place large examples, matrices, and long domain docs in `references/`.
- Add `scripts/` only for deterministic repeated automation.
- Add `assets/` only for output resources, not instruction content.
- Avoid duplicating the same knowledge between SKILL and references.

## Quality Standards

- Valid YAML frontmatter and matching directory/name.
- Three invocation examples in `How to Use`.
- Correct section structure for selected style.
- No broken reference links.
- No emojis, no extraneous files, no dead guidance.
- Skill is self-sufficient and executable by another agent without external explanation.
