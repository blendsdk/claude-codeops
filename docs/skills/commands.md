# Commands

CodeOps ships **19 slash commands**. Under the plugin they are namespaced as `/codeops:<name>`; with
the dev installer they get short names (`/<name>`).

## Core commands

These do focused jobs of their own:

| Command | What it does |
|---|---|
| `/gitcm` | Commit the working tree with a detailed **Conventional Commit** message. |
| `/gitcmp` | Commit **and push** with a Conventional Commit message. |
| `/analyze_project` | Scan the project's manifests and structure and generate/refresh its `CLAUDE.md` (toolchain, commands, structure, conventions). Merges non-destructively. Add `--compact` (with `--dry-run`) to slim an already-bloated `CLAUDE.md`, preview-first. |
| `/migrate_clinerules` | Convert a legacy `codeops-mcp` `.clinerules/project.md` into this project's `CLAUDE.md`, preserving hand-authored content. |
| `/clean_jsdoc` | Retrofit an existing project's JSDoc and code comments to the CodeOps documentation standard — strip references to ephemeral planning artifacts (`plans/`, `requirements/`, RD/AR IDs), document non-trivial entities, and add `@example` to public API. Detection-first, comments-only; `--dry-run` / `--refs-only`. |
| `/gh_issues` | Tabular overview of a GitHub repo's issues — number, title, type, priority, effort, dependencies, assignee — with the semantic columns resolved through the repo's **own** label scheme, native issue types, and project fields (discovered per run, never imposed). Read-only; never mutates issues. |
| `/gh_close` | Close one or more GitHub issues by number with GitHub's native close reasons — completed (default), not planned (`--wontfix`), or duplicate (`--duplicate <#N>`) — or reopen with `--reopen`. Echoes each issue's title before acting and pauses when other open issues depend on the one being closed. **Manual-only** — never fires on the model's own initiative. |

## Alias commands

The consolidated skills cover several verbs each. Thin **alias commands** make each verb directly
typeable by delegating to the parent skill in the right mode. These are **manual-only** — only the
parent skills auto-trigger from natural language.

| Alias command | Delegates to |
|---|---|
| `/add_requirement`, `/review_requirements` | [`make_requirements`](/skills/make_requirements) |
| `/make_techdocs`, `/review_techdocs` | [`techdocs`](/skills/techdocs) |
| `/make_roadmap`, `/update_roadmap`, `/review_roadmap`, `/show_roadmap`, `/archive_roadmap` | [`roadmap`](/skills/roadmap) |
| `/upgrade_requirements` | [`upgrade_plan`](/skills/upgrade_plan) |
| `/setup_routing` | [`setup_routing`](/skills/setup_routing) |
| `/setup_codeops` | [`setup_codeops`](/skills/setup_codeops) |

## Example

```text
/codeops:gitcmp
```

Stages the working tree, writes a Conventional Commit message describing the change, commits, and
pushes. Used by [`exec_plan`](/skills/exec_plan) in `--auto-commit` mode after each verified task.

## Keeping `CLAUDE.md` lean

`CLAUDE.md` is injected into **every** session, so its size is a permanent per-session cost. CodeOps
keeps it lean on both ends:

- **Generation stays terse by default** — the *Project structure* section is one line per top-level
  item, the [routing block](/skills/setup_routing) is a ≤10-line sentinel span, and the
  `analyze_project` refresh comment is replaced in place instead of stacking up every run.
- **Cleanup for a file that has already grown** — `/analyze_project --compact` measures it against the
  budgets (whole file ≤150 lines; derived *Project structure* ≤20; routing span ≤10; one refresh
  comment; no pasted-in coding standards), then previews a slimmed version and asks before writing.
  `--compact --dry-run` reports without writing. It works on the current project only and
  *advisory-flags* — never silently rewrites — your hand-authored sections.
