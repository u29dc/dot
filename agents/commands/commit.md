---
name: commit
description: Analyze changes and create commitlint-compliant commits with intelligent batching
argument-hint: [preferences]
allowed-tools: Bash, Read
---

# Commit Command

## Purpose

Self-contained git commit workflow that analyzes changes, intelligently batches commits when necessary, and ensures strict commitlint compliance.

## Arguments

Optional: `$ARGUMENTS`

Preferences that modify commit behavior:
- **Path scope**: "only src/lib" - limit to specific folder
- **File filter**: "*.ts only" - limit to file patterns
- **Grouping hint**: "single commit" or "separate commits"
- **Message hint**: any text to incorporate into commit message context

## Workflow

1. **Inspect Status**: Run `git status --porcelain` and `git diff HEAD` to identify all modified files. If preferences are provided via `$ARGUMENTS`, filter or adjust scope accordingly.
2. **Parse Config**: Read `commitlint.config.js` if present to extract allowed types/scopes; otherwise use conventional defaults.
3. **Analyze Changes**: Review diffs to determine change type (feat/fix/refactor/docs/chore/style) and scope.
4. **Group Commits**: Cluster files by type and scope; separate unrelated changes into distinct commits.
5. **Execute**: For each group: unstage all → stage group → generate message → commit → validate.
6. **Report**: Display commit SHAs, messages, and file counts.

## Commit Format

Required: `type(scope): subject` (all lowercase, imperative, max 100 chars, no trailing punctuation). Optional body: dash-prefixed lists in sentence case.

## Batching Strategy

- Single commit when changes share type/scope and are tightly coupled.
- Multiple commits when scopes/types differ or changes are separable.
- `$ARGUMENTS` can override: "single commit" forces one commit, "separate commits" forces splitting.

## Quality Standards

- Strict commitlint compliance.
- Atomic commits; no build artifacts.
- Clean staging before each commit.
- Descriptive, specific subjects; bodies for non-trivial changes.
