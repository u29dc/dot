---
name: commit
description: Analyze staged/unstaged changes and create commitlint-compliant commits with intelligent batching
argument-hint: ""
allowed-tools: Bash, Read
---

# Commit Command

## Purpose

Self-contained git commit workflow that analyzes changes, intelligently batches commits when necessary, and ensures strict commitlint compliance.

## Workflow

1. **Inspect Status**: Run `git status --porcelain` and `git diff HEAD` to identify all modified files
2. **Parse Config**: Read `commitlint.config.js` if present to extract allowed types/scopes, fall back to conventional commit defaults
3. **Analyze Changes**: Review diffs to determine change type (feat/fix/refactor/docs/chore/style) and scope
4. **Group Commits**: Cluster files by type and scope, separate unrelated changes into distinct commits
5. **Execute**: For each group: unstage all → stage group → generate message → commit → validate
6. **Report**: Display commit SHAs, messages, and file counts

## Commit Format

**Required format:** `type(scope): subject line`

All fields mandatory, all lowercase, no trailing punctuation, max 100 characters.

**Optional body:** Dash-prefixed lists in sentence-case for detailed changes.

**Type heuristics:** `feat` (new functionality), `fix` (bug fixes), `refactor` (restructuring), `docs` (.md files, comments), `chore` (config, tooling, deps), `style` (formatting only)

**Scope heuristics:** Derive from file paths (e.g., `scripts/*` → scripts), directory structure, or functional area. Validate against commitlint config if available.

**Subject rules:** Imperative mood action verbs (add, fix, update, refactor, remove), specific and concise, describe what changed not why.

## Batching Strategy

**Single commit when:** All changes share same type/scope, tightly coupled changes, small cohesive changeset.

**Multiple commits when:** Changes span distinct scopes/types, unrelated changes mixed together, large separable changeset.

**Principles:**

- Prefer fewer coherent commits over many tiny commits
- Never split logically dependent changes
- Group related files even across scopes (use broader scope)
- Separate breaking changes and refactoring from features

## Execution Process

**Status collection:** `git status --porcelain`, `git diff HEAD --stat`, `git diff HEAD --name-only`

**Config parsing:** Check `commitlint.config.js` or `.commitlintrc.js`, extract type-enum and scope-enum arrays

**Diff analysis:** Run `git diff HEAD <file>` for each file, analyze lines added/removed, identify new functions (feat), bug fixes (fix), structural changes (refactor)

**Commit loop:** For each group:

- `git reset HEAD` (clean staging)
- `git add <files>` (stage group only)
- `git diff --cached --name-only` (verify)
- `git commit -m "type(scope): subject" -m "- detail 1" -m "- detail 2"` (execute)
- `git log -1 --oneline` (validate)

**Final validation:** `git status` and `git log --oneline -n <count>` to confirm all changes committed

## Quality Standards

- Strict commitlint compliance: `type(scope): subject` format always
- Atomic commits: each represents single logical change
- No build artifacts: never commit dist/, build/, generated files
- Clean staging: unstage before each group to prevent partial commits
- Descriptive subjects: specific action verbs, concise explanations
- Body for complexity: add dash-prefixed details for non-trivial changes
- Config awareness: respect project commitlint rules when available
- Verification: validate success and check git log after execution
