---
name: ship
description: Git workflow - commit changes and ship PRs
argument-hint: [pr] or [preferences]
allowed-tools: Bash, Read
disable-model-invocation: true
---

# Ship

Git workflow: commit changes and ship PRs.

## How to Use

- `/ship` - commit staged/unstaged changes with intelligent batching
- `/ship pr` - create and merge PR from dev to main
- `/ship [preferences]` - commit with scope/grouping hints (e.g., "single commit", "only src/lib")

## Commit Workflow

1. **Inspect Status**: Run `git status --porcelain` and `git diff HEAD` to identify all modified files. If preferences are provided via `$ARGUMENTS`, filter or adjust scope accordingly.
2. **Parse Config**: Read `commitlint.config.js` if present to extract allowed types/scopes; otherwise use conventional defaults.
3. **Analyze Changes**: Review diffs to determine change type (feat/fix/refactor/docs/chore/style) and scope.
4. **Group Commits**: Cluster files by type and scope; separate unrelated changes into distinct commits.
5. **Execute**: For each group: unstage all, stage group, generate message, commit, validate.
6. **Report**: Display commit SHAs, messages, and file counts.

### Commit Arguments

- **Path scope**: "only src/lib" - limit to specific folder
- **File filter**: "\*.ts only" - limit to file patterns
- **Grouping hint**: "single commit" or "separate commits"
- **Message hint**: any text to incorporate into commit message context

### Commit Format

Required: `type(scope): description` (all lowercase, imperative, max 100 chars, no trailing punctuation). Required body: dash-prefixed lists in sentence case explaining the "why" behind changes.

### Batching Strategy

- Single commit when changes share type/scope and are tightly coupled.
- Multiple commits when scopes/types differ or changes are separable.
- Arguments can override: "single commit" forces one commit, "separate commits" forces splitting.

## PR Workflow

Triggered when first argument is "pr".

1. **Validate Environment**: Confirm on dev with clean tree; verify main/dev branches and origin remote; ensure `gh` auth works.
2. **Detect Tooling**: Check for semantic-release, Vercel, and workflows to decide which checks to monitor.
3. **Push Dev**: Sync dev to origin; ensure no pending commits.
4. **Create PR**: Analyze commits main..dev to choose type/scope; run `gh pr create --base main --head dev --title "type(scope): subject"` with summary body.
5. **Wait for Checks**: If CI/Vercel detected, watch checks; abort with context on failures/timeouts.
6. **Merge PR**: Merge (preserve history), do not delete dev; verify merged state.
7. **Release Sync**: If semantic-release present, watch release workflow and tag; acceptable if none for non-feat/fix.
8. **Sync Branches**: Pull main, merge main into dev, push dev; verify no drift.
9. **Report**: Provide PR URL and latest tag if created.

### PR Title Format

`type(scope): subject` (all lowercase, imperative, max 100 chars). Type priority: feat > fix > refactor > perf > docs > style > test > chore. Scope from commits or paths; fall back to repo/api/ui.

## Quality Standards

- Strict commitlint compliance.
- Body required for all commits.
- Atomic commits; no build artifacts.
- Clean staging before each commit.
- Descriptive, specific subjects.
- Wait for required checks before merge.
- Merge commits only (never squash) to keep semantic-release history.
- Never delete dev branch.
- Clear progress reporting; abort with actionable guidance on errors.
