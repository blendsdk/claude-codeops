# make_plan

> Create a detailed, multi-document implementation plan for a feature or task **before any code is
> written**.

## What it does

`make_plan` drives a mandatory clarifying-questions interview, enforces a hard **Zero-Ambiguity
Gate**, and produces a `plans/<feature>/` document set ending in a task-by-task execution plan.

The document set typically includes an ambiguity register (the gate's audit trail), an index,
requirements, a current-state analysis, one or more component technical specs, a testing strategy
with concrete specification test cases, and a `99-execution-plan.md` that structures the work into
phases and sessions following **specification-first** test ordering.

Every decision in the plan traces back to an explicit, user-confirmed entry in the ambiguity
register — nothing is guessed on your behalf. For **high-stakes** gate decisions (tagged
complex/sensitive), an independent challenger hardens the recommendation before you decide (see
[Concepts → Recommendation hardening](/guide/concepts#recommendation-hardening)).

## When to use it

- You want to plan a feature, refactor, or task before building it.
- You want a spec/plan written down with clear scope and acceptance criteria.
- **Not** for executing an existing plan — use [`exec_plan`](/skills/exec_plan) for that.

## Trigger phrases

Auto-triggers on: "make a plan", "make_plan", "plan this feature", "create an implementation plan",
"plan out this work", "write a spec/plan for X". Explicit: `/codeops:make_plan`.

## Worked example

```text
/codeops:make_plan
```

Describe a small feature when prompted. The skill runs the clarifying interview, presents the
ambiguity register for your confirmation (the gate), and — only once you confirm — writes
`plans/<feature>/`. To implement it:

```text
/codeops:exec_plan <feature-name>
```

## Related skills

- [`grill_me`](/skills/grill_me) — deep disambiguation *before* planning.
- [`make_requirements`](/skills/make_requirements) — produces RDs that `make_plan` can consume.
- [`preflight`](/skills/preflight) — audit the plan before you build.
- [`exec_plan`](/skills/exec_plan) — execute the finished plan.
- [`upgrade_plan`](/skills/upgrade_plan) — bring an older plan up to current standards.
