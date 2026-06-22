---
name: exec_plan
description: >-
  Executes an implementation plan created by the make_plan skill. Use when the user says
  "exec_plan", "run the plan", "execute the plan", "implement the plan in plans/<feature>",
  or "continue the plan for <feature>". Accepts a feature name and an optional commit-mode
  flag: --ask-commit (default, ask after each verified task), --no-commit (never commit),
  or --auto-commit (commit + push after each verified task). Reads plans/<feature>/99-execution-plan.md,
  finds the next incomplete task, and runs the per-task loop (implement -> update the execution
  plan immediately -> verify -> commit per mode) following specification-first task ordering.
when_to_use: >-
  Use for plan EXECUTION only. Plan CREATION lives in the make_plan skill — point the user there
  instead of duplicating it. Trigger on /exec_plan or any request to run, execute, implement, or
  continue an existing plan under plans/<feature>/.
argument-hint: "[feature-name] [--ask-commit | --no-commit | --auto-commit]"
arguments: feature
---

# exec_plan — Execute an Implementation Plan

> **CodeOps Skills Version**: 2.0.0

Execute the implementation plan at `plans/$ARGUMENTS/99-execution-plan.md`. The first
argument is the feature name; an optional flag selects the commit mode.

This skill covers **execution only**. To create a plan, use the make_plan skill.

## Commit modes

| Flag | Behavior |
|------|----------|
| *(none)* / `--ask-commit` | **Default.** After each verified task, ask the user whether to commit. |
| `--no-commit` | Never commit, never ask. Pure implementation. |
| `--auto-commit` | Automatically commit + push (via `/gitcmp`) after each verified task. |

Full prompt wording, end-of-plan reminders, and commit-message format live in
[commit-modes.md](commit-modes.md) — read it before the first commit decision.

## Execution protocol (summary)

Read [execution-protocol.md](execution-protocol.md) for the full step-by-step protocol,
the specification-first ordering rules, the real-time update mandate, and the session
summary template. The essentials:

### Step 1 — Load the plan

1. Read `plans/$ARGUMENTS/99-execution-plan.md`.
2. Find incomplete tasks (unchecked `[ ]` items); read supporting specs in `plans/$ARGUMENTS/`.
3. Determine the starting point: first incomplete phase/session/task.
4. If the plan is missing/empty/already complete, **STOP** — see the load table in
   [execution-protocol.md](execution-protocol.md). Generally suggest the make_plan skill.

**Version check:** look for `> **CodeOps Version**: X.Y.Z` (or `CodeOps Skills Version`) in
`00-index.md` / `99-execution-plan.md`. If it is older than **2.0.0** or missing, suggest the
upgrade_plan skill, then ask whether to proceed anyway. Suggestion only — the user may proceed.

### Step 2 — Execute tasks (per-task loop)

For each task, in order:

1. **Implement** the task following the technical specs in `plans/$ARGUMENTS/`.
2. **🚨 Immediately update `99-execution-plan.md`** — mark the task `[x]` with a timestamp in the
   Master Progress Checklist, bump the Progress counter and Last Updated stamp. This happens
   **BEFORE** verification, commit, or anything else, so progress survives a crash.
3. **Verify** — run your project's verify command (from the project's CLAUDE.md, or detected
   project conventions).
4. **Commit** per the active commit mode (see [commit-modes.md](commit-modes.md)).
5. **Techdocs check (after each phase):** if the phase introduced architectural changes and
   techdocs exist, do an incremental update via the techdocs skill.
6. Continue until all tasks are complete. (Claude Code auto-compacts context — no manual
   threshold handling is needed.)

> **🚨 Specification-first task ordering — non-negotiable.** Within each feature:
> `spec tests → verify red → implement → verify green → impl tests → full verify`.
> Never write implementation code before its spec tests exist, and never edit a spec test to
> match the implementation (the implementation is wrong, not the test). Details and the
> compressed single-session form are in [execution-protocol.md](execution-protocol.md).

> **🚨 Zero-ambiguity during execution.** If you hit any detail not covered by the plan docs or
> `00-ambiguity-register.md`, STOP, present options to the user, wait for an explicit decision,
> record it in `00-ambiguity-register.md` (tag `(runtime)`), then resume. Never guess.

### Step 3 — Session wrap-up

1. Finish the current task before stopping.
2. **🚨 First, update `99-execution-plan.md`** with all completed tasks (before anything else).
3. Run the verify command.
4. Handle the commit per the active commit mode.
5. Report a session summary (must state `Execution Plan Updated: ✅`). Template in
   [execution-protocol.md](execution-protocol.md).

To resume in a later session, just run `/exec_plan $ARGUMENTS` again — the execution plan is the
source of truth and tells the skill where to pick up.

## Roadmap sync

If `plans/00-roadmap.md` exists, keep it in sync via the roadmap skill (update-first, before
verify/commit/next): set the RD row to `Executing` (🔄) on start, `Done` (✅) on completion, and
`Blocked` (⛔) with a nested `↳ DEF-n` sub-row when a blocking dependency is discovered. If no
roadmap exists, these hooks are inert.

## Error handling

Brief rules for verification failure, plan deviation, and mid-task interruption are in
[execution-protocol.md](execution-protocol.md) — consult it when something goes wrong.

## Post-completion hooks (all tasks done)

1. Handle the end-of-plan commit per the active commit mode (see [commit-modes.md](commit-modes.md)).
2. **Techdocs:** if techdocs exist, do a comprehensive update via the techdocs skill; otherwise
   ask whether to create them.
3. **Re-analyze:** ask whether to re-analyze the project and update the project's CLAUDE.md via
   the `/analyze_project` command.
4. **Roadmap:** set the RD row to `Done` via the roadmap skill if a roadmap exists.

## Conventions

- Follow your project's coding and testing standards (the project's CLAUDE.md, or detected
  project conventions). If no CLAUDE.md exists, detect build/test/verify commands from manifest
  files and use only facts you can read — do not invent settings.
- Commit using `/gitcm` (commit only) or `/gitcmp` (commit + push), or a normal git commit.
- Related skills: make_plan (creation), upgrade_plan (outdated plans), preflight, roadmap, techdocs.
