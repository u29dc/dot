---
name: pr
description: Automate dev→main PR workflow with checks and branch sync
allowed-tools: Bash, Read
---

# PR Command

## Purpose

Automate the dev→main PR flow: validate environment, create PR with conventional title, monitor checks, merge safely, and sync branches.

## Workflow

1. **Validate Environment**: Confirm on dev with clean tree; verify main/dev branches and origin remote; ensure `gh` auth works.
2. **Detect Tooling**: Check for semantic-release, Vercel, and workflows to decide which checks to monitor.
3. **Push Dev**: Sync dev to origin; ensure no pending commits.
4. **Create PR**: Analyze commits main..dev to choose type/scope; run `gh pr create --base main --head dev --title "type(scope): subject"` with summary body.
5. **Wait for Checks**: If CI/Vercel detected, watch checks; abort with context on failures/timeouts.
6. **Merge PR**: Merge (preserve history), do not delete dev; verify merged state.
7. **Release Sync**: If semantic-release present, watch release workflow and tag; acceptable if none for non-feat/fix.
8. **Sync Branches**: Pull main, merge main→dev, push dev; verify no drift.
9. **Report**: Provide PR URL and latest tag if created.

## Title Format

`type(scope): subject` (all lowercase, imperative, max 100 chars). Type priority: feat > fix > refactor > perf > docs > style > test > chore. Scope from commits or paths; fall back to repo/api/ui.

## Quality Standards

- Wait for required checks before merge.
- Merge commits only (never squash) to keep semantic-release history.
- Never delete dev.
- Clear progress reporting; abort with actionable guidance on errors.
