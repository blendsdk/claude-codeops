---
description: Scan the current project's manifests and structure and generate or update a project-level CLAUDE.md (toolchain, commands, structure, conventions). Merges non-destructively. Use for "analyze_project" or "set up CLAUDE.md for this project".
argument-hint: "[path-to-project-root] [--compact] [--dry-run]"
allowed-tools: Bash(ls:*), Bash(cat:*), Bash(find:*), Bash(test:*), Bash(git:*), Read, Glob, Grep, Write, Edit
---

# analyze_project — generate/refresh this project's CLAUDE.md

Detect this project's toolchain and conventions and write them to a project-level `CLAUDE.md`
so every Claude Code session (and every CodeOps skill) adapts to *this* project. A non-flag
`$ARGUMENTS` value is the target root (otherwise the current working directory); the flags
`--compact` and `--dry-run` select the leaning mode described under *Compact mode* below.

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
**additively — never replace a section** — but first **skip any block already present** under that
heading, so a fold interrupted after appending but before it could `git rm` the note re-runs without
double-appending (idempotent). Then `git rm` the consumed file. Flat layout has no notes; the
integration-branch refresh alone is canonical.

## Step 3 — Generate or merge (on the integration branch, or a solo checkout)

Run this write path on the integration branch, or when the user chose **Write anyway** in Step 2.

**If no `CLAUDE.md` exists at the root:** write a new one from the template below.

**If `CLAUDE.md` already exists:** merge non-destructively.
- **Refresh** auto-detectable sections from the fresh scan: *Toolchain*, *Commands*, *Project structure*.
- **Preserve verbatim** any user-authored sections: *Conventions*, *Git conventions*, *Special rules*,
  and anything outside the template. Never delete content you didn't generate.
- Maintain a **single refresh comment** — one `<!-- analyze_project: refreshed <fields> -->` HTML
  comment recording what last changed. **Replace-in-place**: if one already exists, rewrite it;
  never append a second (one comment total, not a stack that grows every run).
- If the file contains unrelated user content, integrate the CodeOps sections under a clear
  `## Project configuration` heading rather than overwriting the file.

## Step 4 — Report

Print the branch route you took (integration write, staged to a feature's `CLAUDE.notes.md`, or
preview-only), what you detected, what you wrote or refreshed, and any `TODO:` placeholders the
user should fill in.

## Compact mode (`--compact`) — slim an already-bloated CLAUDE.md

`--compact` is an explicit, preview-gated leaning pass over the **current project only** — never a
global or `~/.claude/CLAUDE.md`, which are off-limits. The default refresh (Steps 1–4) is
non-destructive; compaction deliberately rewrites generated sections and *may* propose changes to
hand-authored ones, so it is a separate mode with a **preview-before-write** gate. A composable
`--dry-run` prints the same report and preview but writes nothing (use it to inspect any project
safely).

Operating on the current project's `CLAUDE.md` only:

1. **Measure** against the budgets — whole file ≤150 lines; each derived section (the `## Project
   structure` block and the `<!-- CODEOPS-ROUTING:START -->…:END -->` span) ≤20 and ≤10 lines
   respectively; ≤1 refresh comment. Report every violation and every advisory flag.
2. **Tighten derived sections** — rewrite an over-budget `## Project structure` to one terse line
   per top-level item (drop narration; keep the load-bearing what/why clause).
3. **Slim the routing block in place** — compress the `CODEOPS-ROUTING` span to ≤10 lines,
   preserving **every** routing directive (task tags + default, make_plan tagging, exec_plan
   inline-first dispatch, the Sonnet/Opus mapping *with* executor names, the profile-specific
   override line, reserve-Opus-for-planning, and `/compact`/`/clear`). Keep the sentinels
   **byte-exact** and **never relocate** the block — it is load-bearing precisely because it rides
   in always-on context.
4. **Prune refresh comments** — collapse stacked `<!-- analyze_project: … -->` comments to the
   single most recent.
5. **Advisory-flag** any hand-authored section over budget, but **do not** rewrite it without the
   user's explicit go-ahead — hand-authored prose is the user's.
6. **Never** paste injected coding-standards content into `CLAUDE.md`; if any is found, flag it for
   removal (the plugin injects those every session).

**Preview-before-write:** `--compact` shows the violation report plus a section-by-section
before/after (or diff), then **asks for explicit confirmation** before writing — and writes
hand-authored-section changes only when the user approves them specifically. Branch routing is the
same as Step 2: on a feature branch with parallel worktrees, prefer preview and warn that the write
belongs on the integration branch. Edge cases: no `CLAUDE.md` → report "nothing to compact" and
exit; already within budget → report "already lean — nothing to do" (idempotent, no write); exactly
one routing sentinel (corrupted) → report it, do not guess the span, do not write.

Invocation:

```
/analyze_project --compact --dry-run   # report + preview, no write (any project)
/analyze_project --compact             # report + preview + confirm, then slim in place
```

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
<one line per meaningful top-level directory — a `path` plus a one-clause purpose, each on a
single physical line; note where source and tests live and the test-file naming convention.
Keep the whole section ≤20 lines; do not narrate rationale per directory.>

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

Keep the generated file lean — it is always-on context (injected into every session), so its size
is a permanent per-session cost. State facts, not narration. Budgets: whole file ≤150 lines, each
derived section (Project structure) ≤20 lines. Never paste the injected coding standards into
`CLAUDE.md` — the plugin injects them every session already. The CodeOps skills (make_plan,
make_requirements, exec_plan, etc.) read this file to adapt their verify command, commit scope,
structure, and conventions to this project.
