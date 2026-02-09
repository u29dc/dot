---
name: newskill
description: Create new Claude Code skills following established conventions
argument-hint: [skill name or description]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Newskill

Scaffold a new Claude Code skill with correct directory structure, frontmatter, and section conventions.

## How to Use

- `/newskill` - interactive mode: prompt for skill name, purpose, and category
- `/newskill <name>` - create skill with given name, prompt for remaining details
- `/newskill <name> <description>` - create skill with name and description, infer remaining details

## Arguments

Optional: `$ARGUMENTS`

- **First word**: skill name (lowercase, hyphenated). If omitted, ask the user.
- **Remaining words**: one-line description for the `description` frontmatter field. If omitted, ask the user.
- When both are provided, infer category (procedural or reasoning) from the description and proceed without prompting.

## Workflow

1. **Gather Requirements**: Determine skill name, one-line description, and primary purpose. If `$ARGUMENTS` provides them, skip prompting.

2. **Classify Style**: Decide whether the skill is **procedural** (step-by-step workflow like ship/align) or **reasoning** (principle-based reference like compose/craft). This drives section structure and tone.

3. **Inspect Existing Skills**: Read 1-2 existing skills under `agents/skills/` to confirm current conventions have not drifted. Use the skill closest in style to the one being created.

4. **Populate Frontmatter**: Fill in all required fields using the conventions table below.

5. **Write Sections**: Build the SKILL.md content following the standard section structure for the chosen style.

6. **Create Skill**: Write the file to `agents/skills/<name>/SKILL.md`.

7. **Verify**: Read back the created file. Confirm valid YAML frontmatter, correct directory placement, and section completeness.

## Conventions

### Frontmatter Fields

| Field                      | Required | Notes                                                     |
| -------------------------- | -------- | --------------------------------------------------------- |
| `name`                     | Yes      | Lowercase, hyphenated, matches directory name             |
| `description`              | Yes      | One line, starts with verb or noun phrase                 |
| `argument-hint`            | Yes      | Bracket-wrapped hint shown in skill list                  |
| `allowed-tools`            | Yes      | Comma-separated list of tools the skill needs             |
| `disable-model-invocation` | No       | Omit unless skill should not be auto-invoked by the model |

### Section Structure

**Procedural skills** (ship, align):

1. H1 title + one-line intro
2. `## How to Use` - three example invocations
3. `## Arguments` - parse `$ARGUMENTS`
4. `## Workflow` - numbered steps with bold step names
5. Domain-specific sections as needed
6. `## Quality Standards` - validation bullet list

**Reasoning skills** (compose, craft):

1. H1 title + one-line intro
2. `## How to Use` - three example invocations
3. `## When to Apply` - bullet list of applicable contexts
4. `## Role` or `## Philosophy` - framing section
5. Core principle sections with H3 subsections
6. Reference tables, code examples, anti-patterns
7. `## Review Checklist` or equivalent

### Content Rules

- Imperative tone for procedural skills, declarative for reasoning skills.
- No emojis anywhere in the file.
- No trailing whitespace or blank lines at end of file.
- Use markdown tables for structured reference data.
- Use code blocks only for concrete CLI examples or config snippets.
- Three `## How to Use` examples minimum: bare invocation, with name/file argument, with full arguments.
- Keep line count between 50-300 lines depending on domain complexity.
- Frontmatter `allowed-tools` should list only the tools the skill actually needs (Read, Write, Bash, Glob, Grep, Edit, WebFetch, WebSearch).

## Quality Standards

- Valid YAML frontmatter with all required fields.
- Three distinct `/skillname` examples in How to Use.
- At least one allowed tool listed.
- No emojis, no preamble text before the H1.
- Correct directory: `agents/skills/<name>/SKILL.md`.
- Skill name in frontmatter matches directory name.
- File is self-contained; no references to files that do not exist.
- Procedural skills have a numbered Workflow section.
- Reasoning skills have at least one principle or rule section.
