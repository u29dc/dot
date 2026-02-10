# Align Reference Assets

Canonical source for project bootstrap templates used by `/align`.

## Usage Rules

- Treat this folder as the template source of truth.
- Keep `agents/AGENTS.md` policy-only; do not paste full file templates there.
- Preserve project-specific values when aligning existing repos.
- Use variants only when project type requires them.

## Templates

- `templates/.gitignore`: baseline ignore patterns.
- `templates/package.json`: script naming, field order, and baseline tooling deps.
- `templates/tsconfig.json`: strict TypeScript defaults and path alias baseline.
- `templates/biome.json`: extends global biome configuration.
- `templates/commitlint.config.js`: commit type/scope and message rules.
- `templates/lint-staged.config.js.template`: pre-commit quality gate trigger (rename to `.js` when copying).
- `templates/bunfig.toml`: global Bun run behavior baseline.
- `templates/husky/pre-commit`: lint-staged hook.
- `templates/husky/commit-msg`: commitlint hook.

## Variants

- `variants/monorepo.package.fragment.json`: workspace and package export pattern.
- `variants/biome.svelte.json`: Svelte-specific Biome overrides.
- `variants/svelte-config.js`: SvelteKit baseline config.
- `variants/svelte-store.ts`: Svelte 5 runes store pattern.

## Sync Policy

- Update references when standards change.
- Prefer local references; fallback remote path:
`https://github.com/u29dc/dot/tree/main/agents/skills/align/references`.
- Keep examples minimal, executable, and opinionated.
