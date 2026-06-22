# Tutorial: The full pipeline

For a substantial feature, CodeOps composes into one repeatable pipeline that takes you from a fuzzy
idea all the way to verified, committed code:

```
grill_me → make_requirements → preflight → make_plan → preflight → exec_plan
```

…with [`roadmap`](/skills/roadmap) tracking the whole feature-set and [`techdocs`](/skills/techdocs)
keeping architecture docs current.

## 1. Disambiguate the idea — `grill_me`

Start when the design is still fuzzy:

```text
grill_me on <your feature/system>
```

[`grill_me`](/skills/grill_me) maps the decision tree and walks each branch with you — options,
assumptions, sub-decisions — until zero ambiguity remains. The shared understanding feeds the next
step.

## 2. Capture requirements — `make_requirements`

```text
make_requirements
```

[`make_requirements`](/skills/make_requirements) expands your idea with comparable-system features,
challenges it with edge cases, and decomposes it into numbered RDs (`requirements/RD-01-*.md`, …)
behind its Zero-Ambiguity Gate.

## 3. Audit the requirements — `preflight`

```text
preflight requirements
```

[`preflight`](/skills/preflight) hunts for gaps, contradictions, and risks, verifying claims against
the real codebase. Resolve each finding before planning.

## 4. Plan it — `make_plan`

```text
/codeops:make_plan      # choose to base the plan on a specific RD when prompted
```

[`make_plan`](/skills/make_plan) turns an RD into a `plans/<feature>/` document set with a
specification-first execution plan. (Tip: run `make_roadmap` first so the plan is tracked — see
step 6.)

## 5. Audit the plan, then build — `preflight` + `exec_plan`

```text
preflight <feature-name>
/codeops:exec_plan <feature-name> --auto-commit
```

A second [`preflight`](/skills/preflight) pass audits the plan; then
[`exec_plan`](/skills/exec_plan) implements it task-by-task (spec tests → red → implement → green →
impl tests → verify), committing as it goes.

## 6. Track and document

- [`roadmap`](/skills/roadmap): `make_roadmap` early, then `update_roadmap` as stages advance
  (`Plan Created` → `Executing` → `Done`).
- [`techdocs`](/skills/techdocs): `make_techdocs` to produce architecture docs + ADRs; they can update
  automatically as `exec_plan` phases complete (opt-in).

## Result

You've gone from idea → disambiguated design → audited requirements → audited plan → verified,
committed implementation — with a roadmap and architecture docs to show for it. For a lighter-weight
version, see [Your first plan](/tutorials/first-plan).
