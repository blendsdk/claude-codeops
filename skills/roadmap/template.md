# Roadmap Template & Tracker Reference

Resolve where the roadmap lives via **[../../_shared/layout-convention.md](../../_shared/layout-convention.md)**:

- **Flat layout** (no marker): a single roadmap at `plans/00-roadmap.md` — exactly as before.
- **Nested layout** (marker present): a **per-feature roadmap** at
  `codeops/features/<f>/00-roadmap.md` (the template below, scoped to one feature, **plus task
  rows**) and a **portfolio roadmap** at `codeops/00-roadmap.md` (one row per feature — see
  [The portfolio roadmap template](#the-portfolio-roadmap-template)).

The per-feature roadmap and the flat roadmap share the same template, columns, and legend; use it
verbatim when creating either. The portfolio is a separate, higher-altitude template.

## The single / per-feature roadmap template

````markdown
# Roadmap: [Feature-Set Name]

> **Feature-Set**: [Feature-Set Name]
> **Status**: In Progress
> **Created**: [YYYY-MM-DD]
> **Last Updated**: [YYYY-MM-DD HH:MM]
> **Progress**: [Done RDs] / [Total RDs] ([Z]%)
> **CodeOps Skills Version**: 3.2.0

## Legend

⬜ Backlog · ✏️ RD Drafted · 🔎 RD Preflighted · 📋 Plan Created · 🔬 Plan Preflighted · 🔄 Executing · ✅ Done · ⛔ Blocked · ⏸️ Deferred

## Tracker

| ID | Title | RD | Plan | Stage | Status | Last Updated | Notes / Blocker |
|----|-------|----|------|-------|--------|--------------|-----------------|
| RD-01 | [Title] | [link] | [link] | Done | ✅ | [date] | — |
| RD-02 | [Title] | [link] | [link] | Executing | 🔄 | [date] | — |
| RD-03 | [Title] | [link] | — | Blocked (was: RD Preflighted) | ⛔ | [date] | waiting on DEF-1 |
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
- **CodeOps Skills Version** — the release stamp (currently `3.2.0`).

## Tracker columns

| Column | Meaning |
|--------|---------|
| ID | `RD-NN` for a top-level requirement; `T-NN` for a lightweight task (nested layout — separate per-feature namespace, see the task-lane spec); `↳ DEF-n` for a nested discovered dependency. |
| Title | Short human label. |
| RD | Relative link to `requirements/RD-*.md`, or `—` if not yet drafted. |
| Plan | Relative link to the plan folder's `00-index.md`, or `—` if no plan yet. |
| Stage | One of the 9 lifecycle states (text form). A `Blocked` row records its prior stage in-cell — `Blocked (was: <stage>)` — so unblocking never depends on memory. |
| Status | The matching emoji for the stage (see legend). |
| Last Updated | Date (or date + time) of the last change to this row. |
| Notes / Blocker | Free text; for `Blocked` rows, name the `DEF-n` being waited on. |

Links are relative to the roadmap file itself. Flat layout (`plans/00-roadmap.md`): RDs are
`../requirements/RD-NN-*.md`, plans are `<plan>/00-index.md`. Nested layout
(`codeops/features/<f>/00-roadmap.md`): RDs are `requirements/RD-NN-*.md`, plans are
`plans/<plan>/00-index.md`.

## Worked example

```markdown
# Roadmap: Billing Platform

> **Feature-Set**: Billing Platform
> **Status**: In Progress
> **Created**: 2026-05-01
> **Last Updated**: 2026-05-14 16:20
> **Progress**: 1 / 4 (25%)
> **CodeOps Skills Version**: 3.2.0

## Legend

⬜ Backlog · ✏️ RD Drafted · 🔎 RD Preflighted · 📋 Plan Created · 🔬 Plan Preflighted · 🔄 Executing · ✅ Done · ⛔ Blocked · ⏸️ Deferred

## Tracker

| ID | Title | RD | Plan | Stage | Status | Last Updated | Notes / Blocker |
|----|-------|----|------|-------|--------|--------------|-----------------|
| RD-01 | Invoicing core | [RD-01](../requirements/RD-01-invoicing.md) | [invoicing](invoicing/00-index.md) | Done | ✅ | 2026-05-10 | — |
| RD-02 | Payment gateway | [RD-02](../requirements/RD-02-payments.md) | — | Blocked (was: RD Drafted) | ⛔ | 2026-05-14 | waiting on DEF-1 |
| ↳ DEF-1 | Secrets vault integration | — | [vault](vault/00-index.md) | Executing | 🔄 | 2026-05-14 | blocks RD-02 |
| RD-03 | Dunning emails | [RD-03](../requirements/RD-03-dunning.md) | — | RD Preflighted | 🔎 | 2026-05-12 | — |
| RD-04 | Usage metering | — | — | Backlog | ⬜ | 2026-05-01 | — |

## Notes

- 2026-05-14: RD-02 blocked when payment gateway work hit a hard dependency on a secrets vault;
  pulled the vault work out as DEF-1 and set RD-02 to Blocked until DEF-1 reaches Done.
```

Here RD-02 is `Blocked` by the nested `DEF-1` sub-row; once DEF-1 reaches `Done`,
RD-02 resumes from its prior stage.

In a **nested-layout** repo this same roadmap lives at `codeops/features/<f>/00-roadmap.md` and
may also carry `T-NN` **task rows** beside its RD rows (a trivial task is just a row; a non-trivial
one links a single mini-plan). RD and `T` ids are separate per-feature namespaces and never collide.

---

## The portfolio roadmap template

> **Nested layout only.** Lives at `codeops/00-roadmap.md`. One row per feature in the repo; it is
> a *derived summary* of the per-feature roadmaps, never the detailed record. Each feature's Stage
> Summary, Progress, and Status roll up from that feature's own roadmap (any executing → 🔄; all
> done → ✅; any blocked → ⛔). The portfolio **auto-cascades**: every per-feature stage transition
> immediately updates that feature's portfolio row (see [stage-hooks.md](stage-hooks.md)).

````markdown
# Portfolio Roadmap: [Repo / Product Name]

> **Status**: Active
> **Last Updated**: [YYYY-MM-DD HH:MM]
> **Features**: [Done] / [Total] done
> **CodeOps Skills Version**: 3.2.0

## Legend

⬜ Backlog · 🔄 In progress · ✅ Done · ⛔ Blocked · ⏸️ Deferred · 📦 Archived

## Features

| Feature | Roadmap | Stage Summary | Progress | Status | Last Updated |
|---------|---------|---------------|----------|--------|--------------|
| billing | [→](features/billing/00-roadmap.md) | 2 RDs · 1 plan executing | 1/2 RDs | 🔄 | 2026-06-29 |
| auth    | [→](features/auth/00-roadmap.md)    | backlog | 0/3 RDs | ⬜ | 2026-06-20 |

## Archived

| Feature | Roadmap | Completed | Last Updated |
|---------|---------|-----------|--------------|
| onboarding | [→](_archive/onboarding/00-roadmap.md) | 4/4 RDs | 2026-05-30 |

## Notes

[Cross-feature running log: dependencies (name them feature-qualified, e.g. `billing waiting on
auth/RD-02`), detours, decisions.]
````

### Portfolio header fields

- **Status** — `Active` while the repo has live features; informational.
- **Last Updated** — bumps on every cascade.
- **Features** — `[Done] / [Total] done`, counting feature rows whose rolled-up Status is ✅.

### Portfolio columns

| Column | Meaning |
|--------|---------|
| Feature | The feature folder name under `codeops/features/`. |
| Roadmap | Relative link to that feature's `00-roadmap.md`. |
| Stage Summary | Short derived phrase (e.g. "2 RDs · 1 plan executing"). |
| Progress | Derived count (e.g. "1/2 RDs"). |
| Status | Rolled-up emoji (🔄 / ✅ / ⛔ / ⬜ / ⏸️). |
| Last Updated | Date of the last cascade to this row. |

### Archived section

Archiving a feature **moves** its row here (📦) — never deletes it (AR #11). The feature folder is
`git mv`d to `codeops/_archive/<f>/`, so the Roadmap link points under `_archive/`.

A fresh-scaffolded or just-migrated repo seeds this portfolio automatically (the `setup_codeops`
migration writes a one-feature portfolio; refine it with `update`).
