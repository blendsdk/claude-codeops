# techdocs

> Create and maintain VitePress-compatible **technical architecture** documentation and architecture
> decision records (ADRs).

## What it does

`techdocs` covers two modes:

- **make_techdocs** — create or comprehensively regenerate the `docs/` set: system overview, data
  model, API design, infrastructure, security, ADRs, developer guides, and reference.
- **review_techdocs** — run a 7-dimension health check (staleness, completeness, accuracy, ADR
  coverage, link health, diagram accuracy, getting-started) and produce a diagnostic report.

It can also fire automatically as an incremental or comprehensive update when an
[`exec_plan`](/skills/exec_plan) phase completes or [`make_requirements`](/skills/make_requirements)
finishes — but only if the project has opted in.

::: tip Scope
`techdocs` is for **technical/architectural** docs for developers — not product/end-user
documentation, tutorials, FAQs, or release notes. (This very documentation website is user-facing and
was authored by hand, not by `techdocs`.)
:::

## When to use it

- You want architecture docs + ADRs for a codebase, kept in VitePress.
- "document the architecture", "create architecture docs", "write ADRs".
- **Not** for product/user docs or tutorials.

## Trigger phrases

"make_techdocs", "review_techdocs", "techdocs", "document the architecture", "create architecture
docs", "write ADRs", "architecture decision records".

## Worked example

```text
make_techdocs
```

Scaffolds VitePress and generates the architecture doc set + ADRs from the real codebase. Later:

```text
review_techdocs      # health-check the docs for staleness and gaps
```

## Related skills

- [`exec_plan`](/skills/exec_plan) — triggers incremental techdocs updates (opt-in).
- [`retro_requirements`](/skills/retro_requirements) — pair with it to document a legacy system.
