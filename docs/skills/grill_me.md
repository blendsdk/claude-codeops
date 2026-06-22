# grill_me

> Relentlessly interrogate a design to eliminate ambiguity **before** any planning, requirements, or
> implementation work begins.

## What it does

`grill_me` runs a structured, branch-by-branch interview, acting as a senior architect conducting a
design review. It maps the design tree of major decision branches, walks each branch surfacing
options, assumptions, and sub-decisions one at a time, resolves cross-branch dependencies, and
confirms explicit shared understanding.

It never accepts vague answers: it names every decision, assumption, and constraint, resolves
dependencies first, and tracks the decision tree until **zero ambiguity** remains.

## When to use it

- A design is fuzzy and you want it pinned down before committing to requirements or a plan.
- "Grill me about this", "disambiguate", "deep-dive this", "interview me about X".
- As a front-end to [`make_requirements`](/skills/make_requirements) or
  [`make_plan`](/skills/make_plan) to pre-resolve ambiguity.

## Trigger phrases

"grill_me", "grill me", "grill_me on &lt;topic&gt;", "disambiguate", "deep-dive this",
"interview me about &lt;topic&gt;". Resume with `grill_me --continue`.

## Worked example

```text
grill_me on the notification system
```

The skill maps the decision branches (channels, delivery guarantees, batching, opt-out, …) and walks
each one with you until the design is fully specified. The shared understanding then feeds into
`make_requirements` or `make_plan`.

## Related skills

- [`make_requirements`](/skills/make_requirements) — capture the disambiguated design as RDs.
- [`make_plan`](/skills/make_plan) — its Zero-Ambiguity Gate uses the grill_me output as pre-resolved
  context (but still runs the formal gate).
