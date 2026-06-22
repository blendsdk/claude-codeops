# Tutorial: Your first plan

This is the quickest way to feel how CodeOps works: **plan a small feature, then implement it
task-by-task.** It uses two skills — [`make_plan`](/skills/make_plan) and
[`exec_plan`](/skills/exec_plan).

## Prerequisites

- The plugin is [installed](/guide/install) and [verified](/guide/verify).
- You're in a project where you want to build something small.

## 1. Create the plan

In Claude Code:

```text
/codeops:make_plan
```

Describe a small feature when prompted (e.g. "add a `/health` endpoint that returns build version and
uptime"). The skill will:

1. Run a **clarifying interview** — answer the questions concretely.
2. Compile an **Ambiguity Register** and present it. This is the **Zero-Ambiguity Gate**: review
   every item and confirm. Nothing gets written until you do.
3. Write a `plans/<feature>/` document set ending in `99-execution-plan.md`.

::: tip The gate is the point
If the model offers options, you decide — it won't guess. That's what keeps the resulting plan (and
code) aligned with what you actually want. See [Concepts](/guide/concepts#the-zero-ambiguity-gate).
:::

## 2. (Optional) audit the plan

Before building, you can run an adversarial, codebase-grounded audit:

```text
preflight <feature-name>
```

Walk through any findings and decide on each. See [`preflight`](/skills/preflight).

## 3. Execute the plan

```text
/codeops:exec_plan <feature-name>
```

`exec_plan` walks the plan task-by-task following **specification-first** ordering:

```
write spec tests → confirm they fail (red) → implement → confirm they pass (green) → impl tests → verify
```

It updates the execution plan's progress checklist after each task. Pick a commit mode:

```text
/codeops:exec_plan <feature-name> --auto-commit   # commit + push after each verified task
/codeops:exec_plan <feature-name> --no-commit      # never commit
/codeops:exec_plan <feature-name>                   # default: ask after each task
```

## 4. Done

When all tasks are checked off and verification passes, the feature is complete. From here you can:

- Document the architecture with [`techdocs`](/skills/techdocs).
- Track a larger effort with [`roadmap`](/skills/roadmap).
- Try [the full pipeline](/tutorials/full-pipeline) for a bigger feature.
