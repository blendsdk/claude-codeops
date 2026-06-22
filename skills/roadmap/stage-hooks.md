# Stage Transition Map & Hooks

The roadmap sits **above** the per-feature execution plan. It does not replace
the execution plan — it indexes and summarizes across many of them.

| Altitude | Document | Tracks | Produced/updated by |
|----------|----------|--------|---------------------|
| Feature-set (high) | `plans/00-roadmap.md` | Every RD/plan + its lifecycle stage | this skill (`make_roadmap` / `update_roadmap`) + the stage hooks below |
| Single feature (low) | `plans/[feature]/99-execution-plan.md` | Tasks within one feature | the make_plan / exec_plan skills |

## Stage transition map

Other skills fire these transitions on the roadmap. Each hook follows the
**ask-if-missing / sync-if-exists** rule: if no roadmap exists the hook is inert
(never auto-create); if one exists the hook fires silently (never prompt).

| Lifecycle event | Roadmap effect |
|-----------------|----------------|
| RD created (the requirements skill, `make_requirements` / `add_requirement`) | Row → `RD Drafted` (✏️) |
| Preflight passes on an RD (the preflight skill) | Row → `RD Preflighted` (🔎) |
| A plan is produced (the make_plan skill) | Row → `Plan Created` (📋); link the plan |
| Preflight passes on a plan (the preflight skill) | Row → `Plan Preflighted` (🔬) |
| Execution starts (the exec_plan skill) | Row → `Executing` (🔄) |
| Execution completes (the exec_plan skill) | Row → `Done` (✅) |
| Dependency discovered mid-preflight / mid-exec | Add a nested `↳ DEF-n` sub-row; parent → `Blocked` (⛔) |
| `DEF-n` reaches `Done` | Parent leaves `Blocked`, resumes its prior stage |

## Which skill owns which hook

- **requirements skill** — fires the `RD Drafted` hook on RD creation.
- **preflight skill** — fires the `RD Preflighted` and `Plan Preflighted` hooks.
- **make_plan skill** — fires the `Plan Created` hook and links the plan (via the
  `> **Implements**: RD-NN` line — see deterministic linking in SKILL.md).
- **exec_plan skill** — fires the `Executing`, `Done`, and `Blocked` + `DEF` hooks.

## Source-of-truth rule (stated directly here)

The roadmap is the **cross-session source of truth** at the RD/plan altitude:

- **Read-if-exists** — when a roadmap exists, read it at the start of relevant work
  to see what is done, in flight, blocked, or in the backlog.
- **Update-first** — apply the matching stage transition to the roadmap *before*
  verification, commit, or the next action (see the real-time update mandate in SKILL.md).
- **Before ending a session/task** — make sure the roadmap reflects the latest
  reality. Do not finish with a stale roadmap.
