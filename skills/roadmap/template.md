# Roadmap Template & Tracker Reference

The roadmap lives at `plans/00-roadmap.md`. Use the template below verbatim when
creating it (`make_roadmap`), and the column/legend reference when reading or
updating it.

## The `plans/00-roadmap.md` template

````markdown
# Roadmap: [Feature-Set Name]

> **Feature-Set**: [Feature-Set Name]
> **Status**: In Progress
> **Created**: [YYYY-MM-DD]
> **Last Updated**: [YYYY-MM-DD HH:MM]
> **Progress**: [Done RDs] / [Total RDs] ([Z]%)
> **CodeOps Skills Version**: 2.0.0

## Legend

⬜ Backlog · ✏️ RD Drafted · 🔎 RD Preflighted · 📋 Plan Created · 🔬 Plan Preflighted · 🔄 Executing · ✅ Done · ⛔ Blocked · ⏸️ Deferred

## Tracker

| ID | Title | RD | Plan | Stage | Status | Last Updated | Notes / Blocker |
|----|-------|----|------|-------|--------|--------------|-----------------|
| RD-01 | [Title] | [link] | [link] | Done | ✅ | [date] | — |
| RD-02 | [Title] | [link] | [link] | Executing | 🔄 | [date] | — |
| RD-03 | [Title] | [link] | — | Blocked | ⛔ | [date] | waiting on DEF-1 |
| ↳ DEF-1 | [Discovered dependency] | — | [link] | Plan Created | 📋 | [date] | blocks RD-03 |
| RD-04 | [Title] | — | — | Backlog | ⬜ | [date] | — |

## Notes

[Free-form running log of significant transitions, detours, and decisions.]
````

## Header fields

- **Feature-Set** — display name; the slug form is the `plans/_archive/<slug>/` folder name on archive.
- **Status** — `In Progress` while active; `Archived` once `archive_roadmap` runs.
- **Created** / **Last Updated** — `Last Updated` bumps on every transition.
- **Progress** — `[Done RDs] / [Total RDs] ([Z]%)`; counts only top-level RD rows that reached `Done`.
- **CodeOps Skills Version** — static `2.0.0`.

## Tracker columns

| Column | Meaning |
|--------|---------|
| ID | `RD-NN` for a top-level requirement; `↳ DEF-n` for a nested discovered dependency. |
| Title | Short human label. |
| RD | Relative link to `requirements/RD-*.md`, or `—` if not yet drafted. |
| Plan | Relative link to the plan folder's `00-index.md`, or `—` if no plan yet. |
| Stage | One of the 9 lifecycle states (text form). |
| Status | The matching emoji for the stage (see legend). |
| Last Updated | Date (or date + time) of the last change to this row. |
| Notes / Blocker | Free text; for `Blocked` rows, name the `DEF-n` being waited on. |

Links are relative to `plans/00-roadmap.md`: RDs are `../requirements/RD-NN-*.md`,
plans are `<feature>/00-index.md`.

## Worked example

```markdown
# Roadmap: Billing Platform

> **Feature-Set**: Billing Platform
> **Status**: In Progress
> **Created**: 2026-05-01
> **Last Updated**: 2026-05-14 16:20
> **Progress**: 1 / 4 (25%)
> **CodeOps Skills Version**: 2.0.0

## Legend

⬜ Backlog · ✏️ RD Drafted · 🔎 RD Preflighted · 📋 Plan Created · 🔬 Plan Preflighted · 🔄 Executing · ✅ Done · ⛔ Blocked · ⏸️ Deferred

## Tracker

| ID | Title | RD | Plan | Stage | Status | Last Updated | Notes / Blocker |
|----|-------|----|------|-------|--------|--------------|-----------------|
| RD-01 | Invoicing core | [RD-01](../requirements/RD-01-invoicing.md) | [invoicing](invoicing/00-index.md) | Done | ✅ | 2026-05-10 | — |
| RD-02 | Payment gateway | [RD-02](../requirements/RD-02-payments.md) | — | Blocked | ⛔ | 2026-05-14 | waiting on DEF-1 |
| ↳ DEF-1 | Secrets vault integration | — | [vault](vault/00-index.md) | Executing | 🔄 | 2026-05-14 | blocks RD-02 |
| RD-03 | Dunning emails | [RD-03](../requirements/RD-03-dunning.md) | — | RD Preflighted | 🔎 | 2026-05-12 | — |
| RD-04 | Usage metering | — | — | Backlog | ⬜ | 2026-05-01 | — |

## Notes

- 2026-05-14: RD-02 blocked when payment gateway work hit a hard dependency on a secrets vault;
  pulled the vault work out as DEF-1 and set RD-02 to Blocked until DEF-1 reaches Done.
```

Here RD-02 is `Blocked` by the nested `DEF-1` sub-row; once DEF-1 reaches `Done`,
RD-02 resumes from its prior stage.
