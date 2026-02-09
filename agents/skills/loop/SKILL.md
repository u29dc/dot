---
name: loop
description: Generate autonomous agent loop setups with PRD, prompt, harness, and progress tracking
argument-hint: [goal or requirements]
allowed-tools: Bash, Read, Write, Glob, Grep, Edit
---

# Loop

Generate production-ready autonomous agent loop setups for any project type.

## How to Use

- `/loop` - scan project and interactively build loop setup
- `/loop <goal>` - generate loop setup for stated goal
- `/loop <goal> --prefix MIG` - generate with explicit ID prefix

## Arguments

Optional: `$ARGUMENTS`

- **Goal**: free text describing what the loop should accomplish
- **--prefix**: override auto-detected ID prefix (ENG, MIG, RSH, etc.)
- **--dir**: output directory for loop files (default: project root)
- **--no-quality-gate**: omit the quality gate phase (for non-dev loops like research, sales, creative)

## Workflow

1. **Scan Project**: Read package.json / Cargo.toml / pyproject.toml, CLAUDE.md, AGENTS.md, commitlint config, biome/eslint config, tsconfig. Run `git log --oneline -10`. Identify the quality gate command (e.g., `bun run util:check`, `cargo check && cargo test && cargo clippy`, `uv run pytest && uv run ruff check`). Extract commitlint rules (allowed types, scopes, formatting).

2. **Determine Scope**: Infer goal from `$ARGUMENTS` or ask the user for: goal, deliverables, constraints, done criteria. Determine whether this is a software or non-software loop.

3. **Select ID Prefix**: Choose from the prefix table based on project type, or use `--prefix` override.

4. **Decompose Stories**: Break requirements into right-sized stories per the story rules below. Order by dependency: setup > core > integration > polish. Add `dependsOn` for complex dependency graphs.

5. **Generate prd.json**: Read `templates/prd.json`, replace placeholders, populate with decomposed stories, write to target directory.

6. **Generate PROMPT.md**: Read `templates/prompt.md` and replace `{QUALITY_CMD}` with the actual quality gate command and `{COMMITLINT_RULES}` with the project's commit format rules. For non-dev loops (research, sales, creative): adapt the prompt -- replace Phase 2 (Implement) with task-appropriate instructions (e.g., "research and save output", "draft content to specified path"), replace Phase 3 (Verify) with self-check against acceptance criteria instead of a quality gate command, and adjust Phase 1 and critical rules to fit the domain. Keep the Phase 0/4/Stop Condition/progress structure intact. Write to target directory.

7. **Generate loop.sh**: Copy `templates/loop.sh` to the target directory and make it executable (`chmod +x`).

8. **Initialize State**: Copy `templates/progress.txt` to the target directory. If CLAUDE.md exists, append a Loop Setup section referencing the generated files.

9. **Create Branch and Report**: Create `loop/<descriptive-name>` branch, stage and commit all generated files with `chore(config): initialize autonomous loop setup`, then display: story count, branch name, run command (`./loop.sh`), monitor command (`tail -f agent_logs/agent_*.log`), and reminder to review commits before merging.

## Story Rules

### ID Prefixes

| Project Type           | Prefix |
| ---------------------- | ------ |
| Engineering / features | `ENG-` |
| Migration              | `MIG-` |
| Research               | `RSH-` |
| Sales                  | `SLS-` |
| Creative               | `CRE-` |
| Infrastructure         | `INF-` |
| Documentation          | `DOC-` |
| Refactoring            | `REF-` |
| Testing                | `TST-` |

Format: `{PREFIX}{NNN}` zero-padded to 3 digits.

### Sizing

Each story MUST fit within one context window (~20-30 minutes of agent work).

**Right-sized**: add a DB column with migration, add a UI component to an existing page, update a server action, create one API endpoint with validation, write tests for one module, create one CLI subcommand, research one company profile, draft one outreach email.

**Too large** (split further): "build the entire dashboard", "add authentication", "migrate the database layer", "implement the API".

**Too small** (merge upward): "add a single CSS class", "fix a typo", "add one import statement".

### Category Ordering

1. **setup**: scaffolding, schemas, config, dependencies, project structure
2. **core**: primary features, main business logic
3. **integration**: connecting systems, API wiring, data flow
4. **polish**: edge cases, UI refinements, error states, documentation

Priority numbers within categories handle fine-grained ordering. Lower number = higher priority.

### Acceptance Criteria

Use the **Signal = State** pattern -- "X is Y", not vague verbs:

- "Migration creates users table with id, email, password_hash columns"
- "CLI exits with code 0 when given valid input"
- "File exists at `src/lib/auth.ts` and exports `authenticate` function"
- "Report saved to `research/acme-corp.md`"
- "Contains sections: Overview, Key People, Recent News"
- "Word count between 800-1500"

Never use: "configured", "completed", "set up", "implemented", "working".

Every software story MUST include "Quality gate passes" as the final criterion. Every non-software story MUST include "Output file saved to {specific path}" as the final criterion.

### Dependencies

For simple linear flows, priority ordering is sufficient. For complex graphs, add `dependsOn`:

```json
{
	"id": "ENG-005",
	"dependsOn": ["ENG-001", "ENG-003"]
}
```

The PROMPT.md instructs the agent to skip stories whose dependencies have not passed yet.

## Templates

All templates live in `agents/skills/loop/templates/`. Read and customize before writing to the target project.

| Template      | File                     | Placeholders to Replace                                                      |
| ------------- | ------------------------ | ---------------------------------------------------------------------------- |
| PRD           | `templates/prd.json`     | `{PROJECT_NAME}`, `{ONE_LINE_GOAL}`, `{BRANCH_NAME}`, `{ID_PREFIX}`, stories |
| Prompt        | `templates/prompt.md`    | `{QUALITY_CMD}`, `{COMMITLINT_RULES}` -- adapt phases for non-dev loops      |
| Loop harness  | `templates/loop.sh`      | (none -- copy verbatim, make executable)                                     |
| Progress init | `templates/progress.txt` | (none -- copy verbatim)                                                      |

## Critical Rules

- **Right-size stories**: oversized stories are the most expensive failure mode -- the agent exhausts context without completing, wasting an entire iteration.
- **Embed real commands**: never leave `{QUALITY_CMD}` or `{COMMITLINT_RULES}` as placeholders in generated PROMPT.md -- substitute the actual values discovered in step 1.
- **"Don't assume not implemented"**: always include "confirm with code search first" in software PROMPT.md to prevent duplicate implementations.
- **Quality gate hierarchy**: type systems > tests > linting > LLM-as-judge. Gate sequence per iteration: implement > typecheck > lint > test > commit.
- **Keep PROMPT.md under 120 lines**: model adherence drops with instruction count. Move reference material to CLAUDE.md.
- **Cost awareness**: sonnet for ~80% of tasks, opus for complex decisions. A 50-iteration loop on a large codebase costs $50-100+ in API credits.
- **Security**: `--dangerously-skip-permissions` is acceptable inside containers/VMs; on bare metal, prefer `--permission-mode acceptEdits` or `--allowedTools`.
- **Stop condition**: always use `<promise>COMPLETE</promise>` -- the loop harness greps for this exact string.
- **Append-only progress**: never replace progress.txt content; always append. Consolidate reusable patterns to the top section.
- **No overcooking**: tightly scoped acceptance criteria and max iteration limits prevent the agent from adding unrequested features or refactoring working code.

## Quality Standards

- All generated files are syntactically valid (JSON parses, bash runs, markdown renders).
- prd.json stories follow Signal = State acceptance criteria with no vague verbs.
- PROMPT.md contains the actual quality gate command and commitlint rules, not placeholders.
- loop.sh is executable and handles SIGINT/SIGTERM gracefully.
- progress.txt is initialized with the Codebase Patterns header.
- Branch created and initial commit made before reporting to user.
- No references to external files that do not exist in the generated output.
