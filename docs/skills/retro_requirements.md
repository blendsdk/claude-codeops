# retro_requirements

> Reverse-engineer an existing codebase into structured requirements.

## What it does

`retro_requirements` performs **requirements archaeology**: it analyzes an existing, undocumented, or
legacy codebase through a multi-phase pipeline and produces a **reconstruction brief** that feeds
[`make_requirements`](/skills/make_requirements).

It extracts **what** the system does (not how), classifies every behavior by confidence
(✅ certain / ⚠️ inferred / 🔴 uncertain), and enforces a hard **Bug-or-Feature Triage Gate** so bugs
are never silently documented as features. It works across languages and frameworks, and supports
`--scope <path>` to analyze a single module or package.

## When to use it

- You have an existing or legacy codebase and need a spec — for documentation, migration, or a
  from-scratch rebuild.
- "Document what this app does", "extract requirements from this code", "reverse-engineer this
  service into a spec".
- **Not** for greenfield requirements from an idea — use [`make_requirements`](/skills/make_requirements).

## Trigger phrases

"retro_requirements", "reverse requirements", "reconstruct requirements from code", "requirements
archaeology", "reverse-engineer this codebase".

## Worked example

```text
retro_requirements --scope src/billing
```

Analyzes the billing module, classifies each behavior by confidence, triages anything that looks like
a bug, and writes a reconstruction brief. Feed it forward:

```text
make_requirements      # turn the brief into a formal RD set
```

Resume an interrupted run with `retro_requirements --continue`.

## Related skills

- [`make_requirements`](/skills/make_requirements) — consumes the reconstruction brief.
- [`make_plan`](/skills/make_plan) — plan a rebuild from the reconstructed requirements.
- [`techdocs`](/skills/techdocs) — document the architecture you uncover.
