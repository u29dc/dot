---
name: align
description: Bootstrap or align projects to strict quality standards
argument-hint: [project-type or preferences]
allowed-tools: Bash, Read, Write, Glob
disable-model-invocation: true
---

# Align Command

## Purpose

Bootstrap new projects or align existing projects to the user's strict quality standards defined in AGENTS.md. Ensures consistent tooling, scripts, commit hooks, and configurations across all projects.

## Reference (for agents without filesystem access to dot repo)

Example config files to use as templates:

- https://github.com/u29dc/dot/blob/main/commitlint.config.js
- https://github.com/u29dc/dot/blob/main/.gitignore
- https://github.com/u29dc/dot/blob/main/biome.json
- https://github.com/u29dc/dot/blob/main/tsconfig.json

Note: AGENTS.md defines the standards to follow - it is NOT a file to copy into projects. The align command creates actual config files based on those standards.

## Arguments

Optional: `$ARGUMENTS`

- **Project type override**: "svelte", "next", "monorepo", "go", "cli"
- **Scope limit**: "only scripts" - align only package.json scripts
- **Dry run**: "dry-run" - report changes without applying

## Workflow

1. **Detect Project Type**: Check for go.mod (Go), workspaces in package.json (monorepo), svelte.config.js (SvelteKit), next.config.js (Next.js), or plain TypeScript/JavaScript.

2. **Audit Existing Configs**: Read and compare against standards:
    - package.json: field order, util:\* scripts, prepare hook
    - commitlint.config.js: rules, type/scope enums
    - lint-staged.config.js: util:check trigger
    - .husky/: pre-commit and commit-msg hooks
    - biome.json: extends global config
    - tsconfig.json: strict flags
    - .gitignore: standard patterns

3. **Report Misalignments**: List missing files, incorrect configurations, and deviations from standards.

4. **Apply Fixes**: Create missing files, update misaligned configs. For existing files, preserve project-specific values (like scope-enum) while enforcing structure.

5. **Install Dependencies**: If missing, add devDependencies: @biomejs/biome, @commitlint/cli, @commitlint/config-conventional, husky, lint-staged, @typescript/native-preview, bun-types.

6. **Initialize Husky**: Run `bunx husky init` if .husky/ missing; create hooks.

7. **Report**: Summary of changes made, files created/updated.

## Standards Applied

### package.json

- Field order: name, version, type, private, workspaces (if monorepo), repository, scripts, devDependencies, dependencies
- Scripts: util:format, util:lint, util:types, util:check (chained with exit status), prepare (husky)
- SvelteKit util:types: `bunx --bun svelte-kit sync && bunx --bun tsgo --noEmit && bunx svelte-check-rs --tsconfig ./tsconfig.svelte.json`
- Standard util:types: `bunx tsgo --noEmit`

### commitlint.config.js

- Extends: @commitlint/config-conventional
- Types: feat, fix, refactor, docs, style, chore, test
- Scopes: project-specific (infer from structure or ask)
- Rules: scope-empty never, subject-case lower-case, subject-full-stop never, header-max-length 100, body-max-line-length 100

### lint-staged.config.js

- Pattern: `'*': () => ['bun run util:check']`

### .husky/pre-commit

- Content: `bunx lint-staged`

### .husky/commit-msg

- Content: `bunx --no-install commitlint --edit "$1"`

### biome.json

- Extends: /Users/han/.config/biome/biome.json
- SvelteKit: add overrides disabling noUnusedVariables, noUnusedImports, useConst for \*.svelte

### tsconfig.json

- Strict flags: strict, alwaysStrict, noUncheckedIndexedAccess, noImplicitAny, noImplicitReturns, noUnusedLocals, noUnusedParameters, noImplicitThis, noFallthroughCasesInSwitch, exactOptionalPropertyTypes, noImplicitOverride, noPropertyAccessFromIndexSignature, verbatimModuleSyntax, isolatedModules, noEmit
- SvelteKit: extends .svelte-kit/tsconfig.json
- Paths: @/_ -> ./src/_

### .gitignore

- Standard: node*modules/, dist/, build/, \*.tsbuildinfo, .biome, .svelte-kit/, .DS_Store, .*_, .vscode/, .zed/, .idea/, _.log, .tmp/, .env, .env.\* (!.env.example), .husky/\_/, .claude/, .wrangler/

## Quality Standards

- Never overwrite project-specific values without confirmation
- Preserve existing valid configurations
- Infer scope-enum from project structure (packages/, src/ folders, existing commits)
- Report all changes before applying in interactive mode
- Support dry-run for audit-only
