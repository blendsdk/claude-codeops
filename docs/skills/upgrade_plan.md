# upgrade_plan

> Upgrade an outdated plan or requirements set to current CodeOps standards.

## What it does

One skill covers both targets:

- **upgrade_plan [feature-name]** — re-evaluates a plan in `plans/<feature>/` against current
  standards.
- **upgrade_requirements** — re-evaluates the set in `requirements/`.

It detects the target from your phrasing/arguments and branches. The flow is: detect version →
assess gaps → present an **upgrade report BEFORE changing anything** → pass a non-negotiable Content
Quality Gate → apply upgrades **preserving all user-authored content verbatim** → verify. It does not
auto-advance the roadmap.

## When to use it

- An existing plan or requirements set predates the current standards and you want it brought up to
  date.
- "upgrade my plan", "bring my requirements up to date", "version upgrade of a plan".
- **Not** for creating new artifacts — use [`make_plan`](/skills/make_plan) /
  [`make_requirements`](/skills/make_requirements).

## Trigger phrases

"upgrade_plan", "upgrade_requirements", "upgrade my plan", "upgrade my requirements", "bring my
plan/requirements up to date", "version upgrade".

## Worked example

```text
upgrade_plan my-feature
```

Detects the plan's version, shows you an upgrade report of what would change, and — only after you
approve — applies the upgrades while preserving everything you wrote. Then re-verify with
[`preflight`](/skills/preflight).

## Related skills

- [`make_plan`](/skills/make_plan) / [`make_requirements`](/skills/make_requirements) — create the
  artifacts this skill upgrades.
- [`preflight`](/skills/preflight) — audit the upgraded artifact.
