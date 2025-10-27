---
name: pr
description: Automate dev→main PR workflow with Vercel checks and semantic-release sync
argument-hint: ""
allowed-tools: Bash, Read
---

# PR Command

## Purpose

Self-contained PR workflow that automates dev→main deployment cycle: validates environment, creates PR with conventional commit title, waits for checks, merges preserving history, syncs semantic-release commits back to dev.

## Workflow

1. **Validate Environment**: Run `git branch --show-current` and `git status --porcelain` to confirm on dev with clean tree, `git branch -a | grep -E '(main|dev)'` to verify branches exist, `git remote -v | grep origin` for remote, `gh auth status` for CLI access
2. **Detect Tooling**: Check for semantic-release with `[ -f .releaserc ] || grep -q '"release"' package.json`, Vercel with `[ -f vercel.json ] || [ -d .vercel ]`, workflows with `ls .github/workflows/*.yml`
3. **Push Dev**: Run `git push origin dev` to sync remote, validate with `git log origin/dev..dev` (should be empty)
4. **Create PR**: Run `git log main..dev --oneline` to analyze commits, determine dominant type (feat > fix > refactor > docs > chore) and common scope, execute `gh pr create --base main --head dev --title "type(scope): description"` with body listing commits and SHAs, capture PR number from output (if exists, use `gh pr view dev`)
5. **Wait for Checks**: If Vercel/CI detected, run `gh pr checks <number> --watch --interval 10`, skip if none configured, abort on failure >10min with PR URL for manual review
6. **Merge PR**: Run `gh pr merge <number> --merge --delete-branch=false` using merge commit to preserve history, validate with `gh pr view <number> --json state` showing "MERGED"
7. **Wait for Release**: If semantic-release detected, run `gh run watch` or `gh run list --workflow=release.yml --limit 1`, expect version commit/tag/release (acceptable if none for non-feat/fix commits), validate with `git tag --sort=-creatordate | head -1`
8. **Sync Branches**: Run `git checkout main && git pull origin main` then `git checkout dev && git merge main && git push origin dev` to bring release commit back to dev, validate with `git log main..dev` (empty)
9. **Report**: Display PR URL with `gh pr view <number> --json url --jq '.url'` and latest tag, confirm branches synchronized

## PR Title Format

**Required format:** `type(scope): subject line`

All fields mandatory, all lowercase, no trailing punctuation, imperative mood, max 100 characters.

**Type priority:** feat (new functionality), fix (bug fixes), refactor (restructuring), perf (performance), docs (documentation), style (formatting), test (tests), chore (maintenance)

**Scope heuristics:** Extract common scope from commit messages, or derive from file paths/directory structure, use "repo", "api", "ui" as fallbacks.

## Execution Details

**Branch validation:** `git branch -a`, `git branch --show-current`, `git remote -v`, `git status --porcelain`

**Tooling detection:** Check `.releaserc*`, `release.config.js`, `package.json` for semantic-release, `vercel.json` or `.vercel/` for Vercel

**PR creation:** Analyze commits with `git log main..dev --oneline`, generate title following type priority, create with body:

```bash
gh pr create --base main --head dev --title "type(scope): description" --body "$(cat <<'EOF'
## Summary
[Auto-generated from commits]

## Commits Included
[List with SHAs from main..dev]
EOF
)"
```

**Check monitoring:** `gh pr checks <number> --watch --interval 10`, alternative: `gh pr view <number> --json statusCheckRollup`

**Branch sync:** `git checkout main && git pull origin main && git checkout dev && git merge main && git push origin dev`

**Final verification:** `git log main..dev` (empty), `git tag --sort=-creatordate | head -1`, `gh pr view <number> --json url`

## Quality Standards

- Strict conventional commit PR title: `type(scope): subject` format
- Merge commits only (never squash) to preserve history for semantic-release
- Never delete dev branch (still needed for future work)
- Wait for all required checks before merge
- Always sync main→dev after release workflow completes
- Provide PR and release URLs for user reference
- Clear progress reporting at each step with validation
- Abort on errors with actionable recovery messages

## Error Handling

- Not on dev branch: abort with clear message
- Uncommitted changes: suggest `/commit` first
- No commits between main..dev: warn "branches already synchronized"
- gh CLI not installed/authenticated: abort with install/auth instructions
- PR already exists: retrieve existing with `gh pr view dev`, skip creation
- Checks fail: display logs, provide PR URL for manual review
- Merge conflicts: abort, guide to manual resolution
- Semantic-release fails or creates no release: sync branches anyway
- Branch sync fails: provide manual sync commands
