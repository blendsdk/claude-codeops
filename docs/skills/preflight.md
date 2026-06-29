# preflight

> Run a rigorous, multi-dimensional quality audit of a plan, requirements set, or any artifact —
> grounded in the actual codebase.

## What it does

`preflight` is an **adversarial review gate**. It hunts for every ambiguity, contradiction, gap, and
risk in an artifact, **verifies every claim against the real code**, scores findings on a
13-dimension scan, and presents each finding with options and a recommendation for **you** to decide.

It never fixes anything silently — it is a review protocol that finds and reports issues, applying
changes only when you explicitly ask.

For **high-stakes** findings (CRITICAL/MAJOR), preflight hardens its recommendation with an
independent challenger before presenting it, and closes consequential findings with a `Confidence:` /
`Hardening:` line (see [Concepts → Recommendation hardening](/guide/concepts#recommendation-hardening)).

## When to use it

- After [`make_requirements`](/skills/make_requirements) or [`make_plan`](/skills/make_plan), before
  [`exec_plan`](/skills/exec_plan).
- Any time you want a codebase-grounded audit of a plan, requirements, or an ad-hoc document.
- "Audit this plan", "review gate", "quality audit", "review my requirements before I build".

## Trigger phrases

"preflight", "preflight &lt;artifact&gt;", "audit this plan", "audit these requirements",
"quality audit", "review gate". Resume with `--continue`.

## Worked example

```text
preflight my-feature
```

Audits `plans/my-feature/` against the real codebase, scores findings across 13 dimensions, and
walks you through each one with a recommendation. You can also target a single document
(`preflight my-feature 03-api-design`) or a requirements RD (`preflight requirements RD-03`).

## Related skills

- [`make_plan`](/skills/make_plan) / [`make_requirements`](/skills/make_requirements) — the artifacts
  preflight audits.
- [`exec_plan`](/skills/exec_plan) — run it after a clean preflight.
- [`upgrade_plan`](/skills/upgrade_plan) — if preflight shows the artifact is below current standards.
