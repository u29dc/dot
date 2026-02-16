---
name: ship
description: Commit changes and ship pull requests
argument-hint: [commit or pr preferences]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Ship

Commit changes with deterministic batching and execute safe `dev -> main` pull request flow.

## How to Use

- `/ship` - analyze changes and create optimal commit batches
- `/ship pr` - create, validate, and merge PR from `dev` to `main`
- `/ship only src/lib single commit` - scope and batching override

## Arguments

Optional: `$ARGUMENTS`

- path scope: `only <path>`
- file filter: `<glob> only`
- batching override: `single commit` or `separate commits`
- message context: free text hints for subject/body wording

## Commit Workflow

1. Read status and full diff (`git status --porcelain`, `git diff HEAD`).
2. Load commit rules from `commitlint.config.js` if present; otherwise use conventional defaults.
3. Classify changes by type/scope and detect unrelated clusters.
4. Determine batching strategy (auto or argument override).
5. For each batch: reset staging, stage exact files, generate compliant message, commit.
6. Report commit SHAs, titles, scopes, and file counts.

## Commit Message Contract

- Header MUST be `type(scope): subject`.
- Header MUST be lowercase, imperative, <=100 chars, no trailing period.
- Body MUST be present and explain rationale, not only restate diff.
- Body SHOULD use concise dash bullets when multiple reasons exist.

## Git Commit Execution

- MUST write commit message to `/tmp/claude/commit-msg.txt` then commit with `git commit -F /tmp/claude/commit-msg.txt`.
- MUST NOT use heredoc syntax (`<<EOF`) for commit messages; shell heredocs create temp files that fail under macOS sandbox.
- MUST remove the temp file after successful commit.

## Batching Rules

- Single commit when changes share one type/scope and are tightly coupled.
- Multiple commits when independent concerns can be reviewed/reverted separately.
- Never mix docs/chore/refactor with feature/fix work unless tightly coupled.

## PR Workflow (`/ship pr`)

1. Validate environment: clean tree, on `dev`, remotes configured, `gh` authenticated.
2. Sync local `dev` with remote before PR creation.
3. Analyze `main..dev` commit range and derive PR title type/scope.
4. Create PR `dev -> main` with summary body and risk/testing notes.
5. Detect and watch required checks (CI, deployment, release workflows).
6. Abort with actionable failure context if checks fail or timeout.
7. Merge with merge commit (no squash) to preserve commit/release semantics.
8. Keep `dev` branch; sync `main` back into `dev`; push both states.
9. Report PR URL, merge commit SHA, and release tag if produced.

## PR Title Contract

- Format: `type(scope): subject`.
- Type priority when mixed: `feat > fix > refactor > perf > docs > style > test > chore`.
- Scope priority: derive from commits/paths; fallback `repo`.

## Safety Rules

- MUST preserve unrelated staged work if outside requested scope.
- MUST avoid force-push during normal ship flow.
- MUST avoid deleting `dev`.
- MUST avoid squash merges unless explicitly requested.
- SHOULD block merge when required checks are missing or failing.

## Quality Standards

- Commitlint-compliant headers and scopes.
- Commit bodies included for every commit.
- Atomic commit grouping with clear review boundaries.
- Clean staging boundaries between batches.
- PR checks verified before merge.
- Final branch sync complete (`main` merged back into `dev`).
- Clear report with exact next-state verification commands.
