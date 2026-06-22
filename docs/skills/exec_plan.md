# exec_plan

> Execute an implementation plan created by [`make_plan`](/skills/make_plan), task-by-task.

## What it does

`exec_plan` reads `plans/<feature>/99-execution-plan.md`, finds the next incomplete task, and runs
the per-task loop: **implement → immediately update the execution plan → verify → commit per mode**.
It follows the plan's specification-first task ordering (spec tests → red → implement → green → impl
tests → verify) and keeps the Master Progress Checklist current so progress survives crashes and
session handoffs.

## When to use it

- You have a finished plan under `plans/<feature>/` and want to build it.
- You want to resume an interrupted execution — just run it again; the execution plan is the source
  of truth for where to pick up.
- **Not** for creating a plan — use [`make_plan`](/skills/make_plan) for that.

## Trigger phrases

"exec_plan", "run the plan", "execute the plan", "implement the plan in plans/&lt;feature&gt;",
"continue the plan for &lt;feature&gt;". Explicit: `/codeops:exec_plan <feature>`.

## Commit modes

| Flag | Behavior |
|---|---|
| *(none)* / `--ask-commit` | **Default.** Ask whether to commit after each verified task. |
| `--no-commit` | Never commit, never ask. Pure implementation. |
| `--auto-commit` | Automatically commit **and push** (via `/gitcmp`) after each verified task. |

## Worked example

```text
/codeops:exec_plan my-feature --auto-commit
```

Walks `plans/my-feature/` task-by-task: writes spec tests, confirms they fail, implements, confirms
they pass, adds implementation tests, verifies, then commits + pushes — repeating until the plan is
complete.

## Related skills

- [`make_plan`](/skills/make_plan) — creates the plan this skill executes.
- [`roadmap`](/skills/roadmap) — tracks the feature-set; `exec_plan` syncs stages.
- [`techdocs`](/skills/techdocs) — architecture docs updated as phases complete.
- See the [Commands page](/skills/commands) for `/gitcm` / `/gitcmp`.
