# exec_plan

> Execute an implementation plan created by [`make_plan`](/skills/make_plan), task-by-task.

## What it does

`exec_plan` reads `plans/<feature>/99-execution-plan.md`, finds the next incomplete task, and runs
the per-task loop: **implement → immediately update the execution plan → verify → commit per mode**.
It follows the plan's specification-first task ordering (spec tests → red → implement → green → impl
tests → verify) and keeps the plan's task checkboxes current — two-stage `[~]`/`[x]` marks in the
phase sections (or the legacy consolidated checklist in pre-3.3.0 plans; both formats run
unchanged) — so progress survives crashes and session handoffs.

Verify runs are **output-captured**: the full build/test output goes to a temp log, and only a
PASS one-liner (or the last 50 lines on failure) enters the conversation — the biggest per-task
token saving in the loop.

## Execution mode — inline first

`exec_plan` runs each **phase** on the model its task tags call for (via a project routing block,
if one exists). It implements a phase **inline** when the session model already fits, and
dispatches the whole phase as **one** pinned-model executor only when a cheaper model is
warranted. Per-task or parallel dispatch is opt-in — for wall-clock parallelism or isolating a
very large plan — because splitting into many subagents costs *more* tokens, not fewer. Untagged
and older plans run unchanged.

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
