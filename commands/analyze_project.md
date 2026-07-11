---
description: Scan the current project's manifests and structure and generate or update a project-level CLAUDE.md (toolchain, commands, structure, conventions). Merges non-destructively. Use for "analyze_project" or "set up CLAUDE.md for this project".
argument-hint: "[path-to-project-root]"
allowed-tools: Bash(ls:*), Bash(cat:*), Bash(find:*), Bash(test:*), Bash(git:*), Read, Glob, Grep, Write, Edit
---

# analyze_project — generate/refresh this project's CLAUDE.md

Detect this project's toolchain and conventions and write them to a project-level `CLAUDE.md`
so every Claude Code session (and every CodeOps skill) adapts to *this* project. Target root is
`$ARGUMENTS` if provided, otherwise the current working directory.

This replaces the old CodeOps MCP `analyze_project` tool, which wrote `.clinerules/project.md`.
The Claude Code equivalent is the project's `CLAUDE.md`.

## Step 1 — Detect (read-only)

Inspect manifests and structure. Look for and read whichever exist:
`package.json`, `pnpm-workspace.yaml`/`turbo.json`/`nx.json` (monorepo), `tsconfig.json`,
`Cargo.toml`, `go.mod`, `pyproject.toml`/`setup.cfg`/`requirements.txt`, `composer.json`,
`Gemfile`, `pom.xml`/`build.gradle`, `docker-compose.yml`/`Dockerfile`, `Makefile`,
CI configs under `.github/workflows/`, and the lockfile (to infer the package manager).

From these, determine: project **name**, **type** (web-app / api / library / cli / mobile /
infrastructure / compiler / monorepo), **language(s)**, **framework(s)**, **package manager**,
**test framework**, and the **build / test / verify / clean** commands. Map the top-level
**directory structure** and where source vs. test files live. Detect whether it is a monorepo.

Use only facts you can verify from the files — never invent commands. If something can't be
determined, leave a clearly-marked `TODO:` placeholder.

## Step 2 — Route by branch (parallel-worktree safety)

`CLAUDE.md` is one repo-wide file, so two agents refreshing it on different branches collide at
merge time. Its *Toolchain / Commands / Project structure* are **derived from the tree** and can
always be regenerated, so treat `CLAUDE.md` like a derived artifact: concentrate writes on one
branch. Skip this whole step and just write normally if `git` is unavailable.

Determine:

- **current branch** — `git rev-parse --abbrev-ref HEAD`
- **integration branch** — `integrationBranch` from `codeops/.codeops.yml` if present, else the
  repo default (`git symbolic-ref refs/remotes/origin/HEAD`, else `main`/`master`)
- **parallel?** — whether `git worktree list` shows more than one worktree

**On the integration branch** → do the full refresh (Step 3), then fold any pending per-feature
notes into `CLAUDE.md` and delete them (see *Folding* below). This is the one branch where
`CLAUDE.md` is rewritten and committed.

**On any other (feature) branch** → do **not** silently rewrite the tracked `CLAUDE.md`. Show the
Step 1 facts as a preview, then offer these options and recommend one — recommend **Stage** or
**Preview** when `parallel?` is true (a write here will conflict); a direct write is only safe in a
solo checkout:

- **Stage** *(nested layout)* — append only the hand-written project prose you'd add to
  `codeops/features/<feature>/CLAUDE.notes.md` (ask which feature per
  [`../_shared/layout-convention.md`](../_shared/layout-convention.md); create it lazily). Don't
  copy derived facts here — they re-scan on the integration branch.
- **Preview only** — report the refreshed facts, write nothing. Right when the change is just
  derived facts.
- **Write anyway** — proceed to Step 3 against this branch's `CLAUDE.md`. Solo checkouts only.

**Folding (integration branch, nested layout):** for each `codeops/features/*/CLAUDE.notes.md`,
append its content under the matching `CLAUDE.md` heading (`## Special rules`, `## Conventions`, …)
**additively — never replace a section** — so the fold can't itself conflict, then `git rm` the
consumed file. Flat layout has no notes; the integration-branch refresh alone is canonical.

## Step 3 — Generate or merge (on the integration branch, or a solo checkout)

Run this write path on the integration branch, or when the user chose **Write anyway** in Step 2.

**If no `CLAUDE.md` exists at the root:** write a new one from the template below.

**If `CLAUDE.md` already exists:** merge non-destructively.
- **Refresh** auto-detectable sections from the fresh scan: *Toolchain*, *Commands*, *Project structure*.
- **Preserve verbatim** any user-authored sections: *Conventions*, *Git conventions*, *Special rules*,
  and anything outside the template. Never delete content you didn't generate.
- Append a short `<!-- analyze_project: refreshed <fields> -->` HTML comment noting what changed.
- If the file contains unrelated user content, integrate the CodeOps sections under a clear
  `## Project configuration` heading rather than overwriting the file.

## Step 4 — Report

Print the branch route you took (integration write, staged to a feature's `CLAUDE.notes.md`, or
preview-only), what you detected, what you wrote or refreshed, and any `TODO:` placeholders the
user should fill in.

---

## Template for a new project CLAUDE.md

```markdown
# <Project Name>

> Project configuration for Claude Code. Auto-generated by /analyze_project; edit freely —
> re-running preserves your hand-written sections.

## Overview
- **Type:** <web-app | api | library | cli | …>
- **Description:** <one or two sentences: what it does, who uses it>

## Toolchain
- **Language(s):** <…>
- **Framework(s):** <…>
- **Package manager:** <npm | yarn | pnpm | cargo | uv | go | …>
- **Test framework:** <…>

## Commands
- **Build:** `<command>`
- **Test:** `<command>`
- **Verify (run before every commit):** `<build && test>`
  <!-- For infra/DevOps-heavy projects, extend Verify with the matching non-code validations
       (docker compose config, shellcheck, terraform validate, kubectl --dry-run, …) — the
       table lives in the plugin's standards/coding-standards-full.md. -->
- **Clean:** `<command>`

## Project structure
<short tree of the meaningful top-level directories, with one-line purposes;
note where source and tests live and the test-file naming convention>

## Conventions
<naming (files/components/functions/constants/types), architecture patterns,
import style, documentation format. Hand-edit this — it is preserved on re-run.>

## Git conventions
- **Commit scope:** <how to pick the scope, e.g. module/package name>
- **Main branch:** <main | master>  •  **Feature branches:** <pattern>

## Special rules
<anything project-specific that doesn't fit above. Preserved on re-run.>
```

Always include, under `## Conventions`, this one-line pointer (verbatim) so the project echoes the
always-on directive:

> **Grounded Options & Recommendations** — follow the always-on directive in the coding standards:
> filter out non-viable options (no strawmen), second-guess each, ground any code-modifying option
> in the real code, and lead with a recommendation and its reason; match ceremony to stakes.

The always-on standards carry the fuller **recommendation-hardening** protocol
(`_shared/recommendation-hardening.md`); keep the *generated* pointer above to the one-liner shown.

Keep the generated file lean — it is always-on context. State facts, not narration. The
CodeOps skills (make_plan, make_requirements, exec_plan, etc.) read this file to adapt their
verify command, commit scope, structure, and conventions to this project.
