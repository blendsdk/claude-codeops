# Commands

CodeOps ships **15 slash commands**. Under the plugin they are namespaced as `/codeops:<name>`; with
the dev installer they get short names (`/<name>`).

## Core commands

These do focused jobs of their own:

| Command | What it does |
|---|---|
| `/gitcm` | Commit the working tree with a detailed **Conventional Commit** message. |
| `/gitcmp` | Commit **and push** with a Conventional Commit message. |
| `/analyze_project` | Scan the project's manifests and structure and generate/refresh its `CLAUDE.md` (toolchain, commands, structure, conventions). Merges non-destructively. |
| `/migrate_clinerules` | Convert a legacy `codeops-mcp` `.clinerules/project.md` into this project's `CLAUDE.md`, preserving hand-authored content. |
| `/clean_jsdoc` | Retrofit an existing project's JSDoc and code comments to the CodeOps documentation standard — strip references to ephemeral planning artifacts (`plans/`, `requirements/`, RD/AR IDs), document non-trivial entities, and add `@example` to public API. Detection-first, comments-only; `--dry-run` / `--refs-only`. |

## Alias commands

The consolidated skills cover several verbs each. Thin **alias commands** make each verb directly
typeable by delegating to the parent skill in the right mode. These are **manual-only** — only the
parent skills auto-trigger from natural language.

| Alias command | Delegates to |
|---|---|
| `/add_requirement`, `/review_requirements` | [`make_requirements`](/skills/make_requirements) |
| `/make_techdocs`, `/review_techdocs` | [`techdocs`](/skills/techdocs) |
| `/make_roadmap`, `/update_roadmap`, `/review_roadmap`, `/archive_roadmap` | [`roadmap`](/skills/roadmap) |
| `/upgrade_requirements` | [`upgrade_plan`](/skills/upgrade_plan) |
| `/setup_routing` | [`setup_routing`](/skills/setup_routing) |
| `/setup_codeops` | [`setup_codeops`](/skills/setup_codeops) |

## Example

```text
/codeops:gitcmp
```

Stages the working tree, writes a Conventional Commit message describing the change, commits, and
pushes. Used by [`exec_plan`](/skills/exec_plan) in `--auto-commit` mode after each verified task.
