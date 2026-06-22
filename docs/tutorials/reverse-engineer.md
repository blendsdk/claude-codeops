# Tutorial: Reverse-engineer a codebase

When you inherit an existing, undocumented, or legacy codebase, CodeOps can reconstruct **what it
does** into a structured spec — then you can plan a rebuild or migration. This uses
[`retro_requirements`](/skills/retro_requirements) followed by
[`make_requirements`](/skills/make_requirements).

## 1. Run requirements archaeology — `retro_requirements`

Point it at the whole codebase, or scope it to one module:

```text
retro_requirements --scope src/billing
```

[`retro_requirements`](/skills/retro_requirements) analyzes the code through a multi-phase pipeline
and produces a **reconstruction brief**. Two things make its output trustworthy:

- **Confidence classification** — every reconstructed behavior is tagged ✅ certain / ⚠️ inferred /
  🔴 uncertain, so you know what's solid and what needs confirmation.
- **Bug-or-Feature Triage Gate** — anything that looks like a bug is triaged with you rather than
  silently written down as intended behavior.

Resume an interrupted run with `retro_requirements --continue`.

## 2. Confirm the uncertain bits

Review the brief, focusing on the ⚠️ and 🔴 items and any triaged bugs. Decide what is genuinely
required behavior versus an accident of the current implementation.

## 3. Formalize into requirements — `make_requirements`

```text
make_requirements
```

Feed the reconstruction brief in. [`make_requirements`](/skills/make_requirements) turns it into a
clean, numbered RD set behind its Zero-Ambiguity Gate — now you have a spec that describes the system
deliberately, not accidentally.

## 4. Plan the rebuild or migration

```text
/codeops:make_plan      # base the plan on the reconstructed RDs
/codeops:exec_plan <feature-name>
```

From here it's the same flow as [the full pipeline](/tutorials/full-pipeline): optionally
[`preflight`](/skills/preflight) the requirements and plan, then build with
[`exec_plan`](/skills/exec_plan).

## When to use this

- Documenting a legacy service before changing it.
- Migrating a system to a new stack and needing a precise spec of current behavior.
- Onboarding onto an undocumented codebase.

For greenfield work from a fresh idea instead, start with [the full pipeline](/tutorials/full-pipeline).
