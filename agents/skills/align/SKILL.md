---
name: align
description: Bootstrap or align projects to strict quality standards
argument-hint: [project-type or preferences]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Align

Audit and enforce project baseline standards from `agents/AGENTS.md` using canonical templates under `agents/skills/align/references/`.

## How to Use

- `/align` - full audit + fix pass for current project
- `/align <project-type>` - enforce variant-specific rules (`svelte`, `next`, `monorepo`, `go`, `cli`)
- `/align dry-run` - report only, no file mutations

## Arguments

Optional: `$ARGUMENTS`

- project type override: `svelte | next | monorepo | go | cli`
- scope limiter: `only scripts`
- dry run: `dry-run`

## Workflow

1. Detect project type and package/runtime context.
2. Load canonical references from `references/index.md`.
3. Audit existing config files against policy and templates.
4. Report drift (missing files, invalid patterns, rule violations).
5. Apply minimal corrective edits while preserving valid project-specific intent.
6. Install missing tooling dependencies required by configured scripts.
7. Initialize `.husky` hooks when absent.
8. Run available quality checks.
9. Report changed files, unresolved gaps, and next actions.

## Canonical Sources

- Primary: `agents/skills/align/references/index.md`
- Templates: `agents/skills/align/references/templates/`
- Variants: `agents/skills/align/references/variants/`
- Remote fallback: `https://github.com/u29dc/dot/tree/main/agents/skills/align/references`

## Standards Contract

### package.json

- MUST enforce field order:
  `name > version > type > private > workspaces > repository > scripts > devDependencies > dependencies`
- MUST enforce script namespace `util:*`.
- MUST include `prepare` hook for husky when hooks are used.
- MUST set typecheck script:
  - default: `bunx tsgo --noEmit`
  - svelte default: `bunx svelte-kit sync && bunx tsgo --noEmit && bunx svelte-check --tsconfig ./tsconfig.json`
- SHOULD preserve existing compatible variants (`svelte-check-rs`, custom tsconfig).

### Core config files

- MUST align `commitlint.config.js` with conventional base + scoped rules.
- MUST align `lint-staged.config.js` to run full quality gate.
- MUST align `biome.json` to extend global config.
- MUST align `tsconfig.json` strict-mode baseline and alias contract.
- MUST align `.gitignore` baseline patterns.
- MUST align `.husky/pre-commit` and `.husky/commit-msg` hooks.

## Safety Rules

- MUST preserve valid project-specific configuration unless explicitly overridden.
- MUST avoid destructive resets and unrelated file rewrites.
- MUST report before/after intent in dry-run mode.
- SHOULD infer scope enums from repository structure and commit history.
- SHOULD prefer small, reviewable edits over full-file replacement when practical.

## Quality Standards

- No unresolved template placeholders.
- No broken config syntax after updates.
- All aligned files trace back to canonical references.
- Drift report includes exact file-level diffs or rule-level findings.
- Skill text remains policy-focused; template payloads stay in `references/`.
