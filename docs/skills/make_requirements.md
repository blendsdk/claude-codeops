# make_requirements

> Turn an idea into formal, numbered requirement documents (RDs) — or add to / audit an existing set.

## What it does

`make_requirements` acts as a proactive domain consultant. It absorbs a seed idea (a brain dump or a
bare one-liner), expands it with features comparable systems have, challenges it with edge cases,
then decomposes everything into numbered RDs behind a hard **Zero-Ambiguity Gate**. The result is a
structured `requirements/` set that [`make_plan`](/skills/make_plan) can consume directly.

It covers three modes:

- **make_requirements** — full discovery from an idea into a structured RD set.
- **add_requirement** — add one new RD to an existing set.
- **review_requirements** — a health check / gap analysis on an existing set.

## When to use it

- You want to capture, expand, structure, or audit what a system must do **before building it**.
- "Help me spec out my app", "document requirements", "what features am I missing".
- **Not** for reconstructing requirements from existing code — use
  [`retro_requirements`](/skills/retro_requirements).

## Trigger phrases

"make_requirements", "add_requirement", "review_requirements", "help me spec out my app",
"document requirements", "what features am I missing", "review my requirements for gaps".

## Worked example

```text
make_requirements
```

Brain-dump your idea when prompted. The skill expands and challenges it, resolves every ambiguity
with you, and writes `requirements/RD-01-*.md`, `RD-02-*.md`, … Then plan one:

```text
/codeops:make_plan      # choose to base the plan on a specific RD
```

## Related skills

- [`grill_me`](/skills/grill_me) — disambiguate the idea first.
- [`make_plan`](/skills/make_plan) — consumes the RDs into an implementation plan.
- [`preflight`](/skills/preflight) — audit the requirements set for gaps and risks.
- [`roadmap`](/skills/roadmap) — track each RD across its lifecycle.
- [`upgrade_plan`](/skills/upgrade_plan) — `upgrade_requirements` brings an old set up to standard.
