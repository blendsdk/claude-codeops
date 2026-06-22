---
name: roadmap
description: >-
  Tracks an entire feature-set across its lifecycle in a live roadmap at plans/00-roadmap.md —
  every RD and plan and the lifecycle stage each is in. Use when the user says "roadmap",
  "make_roadmap", "update_roadmap", "review_roadmap", or "archive_roadmap". Covers four actions:
  make_roadmap (create the roadmap and seed rows from disk), update_roadmap (re-infer stages and
  sync to current disk state), review_roadmap (read-only health check for drift and broken links),
  and archive_roadmap (move a completed feature-set into plans/_archive/<feature-set>/). Detects the
  action from the user's phrasing or arguments and branches. The roadmap is the cross-session source
  of truth at the RD/plan altitude, above any single execution plan.
argument-hint: "[make | update | review | archive]"
---

# roadmap — Live Feature-Set Roadmap Keeper

> **CodeOps Skills Version**: 2.0.0

The roadmap is a single living document — `plans/00-roadmap.md` — that tracks an
entire **feature-set** at a higher altitude than any individual execution plan.
Where `99-execution-plan.md` tracks the tasks *within one feature*, the roadmap
tracks *every requirement (RD) and plan* across the whole feature-set and the
lifecycle stage each one is in. It is the user's cross-session lifeline: open it
to see, at a glance, what is done, in flight, blocked, or still in the backlog.

It never replaces the execution plan; it indexes and summarizes across many of them.

## Action dispatch

Detect the action from the user's phrasing or argument and branch:

| Trigger | Action |
|---------|--------|
| `make_roadmap`, "create the roadmap", "start a roadmap" | **make** — create + seed |
| `update_roadmap`, "sync the roadmap", "update the roadmap" | **update** — re-infer + sync |
| `review_roadmap`, "check the roadmap", "is the roadmap healthy" | **review** — read-only health check |
| `archive_roadmap`, "archive the feature-set", "archive the roadmap" | **archive** — move to `_archive` |

## The lifecycle state machine

```
⬜  Backlog          — RD identified but not yet drafted
✏️  RD Drafted       — RD document written
🔎  RD Preflighted   — RD passed preflight
📋  Plan Created     — a plan was produced
🔬  Plan Preflighted — plan passed preflight
🔄  Executing        — execution in progress
✅  Done             — plan fully executed
⛔  Blocked          — cannot proceed (waiting on a Deferred dependency)
⏸️  Deferred         — a discovered dependency pulled out as its own tracked item
```

**Linear happy path:**
`Backlog → RD Drafted → RD Preflighted → Plan Created → Plan Preflighted → Executing → Done`.

`Blocked` and `Deferred` are **orthogonal overlays** on the linear path — a row in
any stage can become `Blocked`, and any discovered dependency can be pulled out as
a `Deferred` sub-row.

The full stage-transition map (which lifecycle events advance which rows, and which
skill fires each hook) is in [stage-hooks.md](stage-hooks.md) — read it when wiring
or reasoning about transitions.

## Two governing rules (apply to every action)

**Ask-if-missing / sync-if-exists** — the roadmap is never auto-created silently:

- **When MISSING:** ask the user whether to create it. Never fabricate one without consent.
- **When it EXISTS:** always sync from disk state automatically — never ask, never prompt.
  Stage hooks fire silently.

This keeps the roadmap opt-in to create, but always-fresh once it exists.

**Real-time update mandate** — the roadmap is updated **immediately** on each stage
transition, **BEFORE** verification, commit, or the next action. Update order:
`complete the stage transition → update plans/00-roadmap.md → proceed`. On each
transition update the row's `Stage`, `Status`, and `Last Updated`, plus the header
`Progress` counter and `Last Updated`. Rationale — crash resilience: a session can
crash or hit context limits at any moment; if the roadmap is stale the user loses
their cross-session view. Keep it always reflecting reality, and never end a
session/task with a stale roadmap.

## Deterministic linking (RD ↔ plan)

Plan folders are named by feature (e.g. `plans/billing/`) and carry **no encoded RD
id**, and the repo can hold multiple unrelated feature-sets at once, so "everything
under `plans/`" is **not** a valid membership rule. Link deterministically instead:

- Every plan declares the requirement it implements as a `> **Implements**: RD-NN`
  line in its `00-index.md`. The `Plan Created` hook reads this line and links the
  plan to the matching RD row.
- A plan with **no declared RD** is linked only when the user explicitly states which
  RD (or `DEF-n`) it belongs to. Unrelated plans are never silently swept in.

## Deferred & Blocked handling

When a blocking dependency is discovered mid-preflight or mid-execution:

1. Add a **nested `↳ DEF-n` sub-row** directly beneath the affected parent row, visually tied to it.
2. Set the **parent row to `Blocked`**, naming the `DEF-n` it waits on in `Notes / Blocker`.
3. Track the `DEF-n` sub-row through its own lifecycle stages like any other item.
4. When `DEF-n` reaches `Done`, the parent **leaves `Blocked`** and resumes its prior stage.

Deferred work is never hidden in a separate section — it stays nested under the item
it blocks so the dependency is obvious at a glance.

---

## make — create the roadmap

Create the roadmap at `plans/00-roadmap.md` using the template in
[template.md](template.md) (read it for the header, legend, and tracker columns).

1. **Ask the user once for the feature-set name** — used in the header and as the
   archive folder slug.
2. **Auto-populate from disk (suggest, don't sweep):**
   - Seed one row per `requirements/RD-*.md` found.
   - For each `plans/*/99-execution-plan.md`, *suggest* a link plus an inferred stage
     (from checklist completion), but only write the plan into the roadmap **after the
     user confirms** it belongs to this feature-set.
3. **If the roadmap already exists:** do NOT ask — sync it from disk state instead
   (the update action).

## update — re-infer stages and sync to disk

Advance stages and sync the roadmap to current disk state.

- Walk each row, re-infer its stage from disk (RD present, plan present, checklist
  completion), and update `Stage`, `Status`, and `Last Updated`.
- Recompute the header `Progress` counter and `Last Updated`.
- **If the roadmap is missing:** fall back to **make** — ask whether to create it, then create it.

## review — read-only health check

Run a health check and report findings; change nothing on disk.

- Every RD row references an existing `requirements/RD-*.md` file.
- Every plan link references an existing `plans/*/` folder.
- The recorded `Stage` matches on-disk reality (flag any drift between table and files).
- Every `Blocked` row has a live `DEF-n` sub-row; if the `DEF-n` is already `Done`,
  flag the parent as ready to unblock.
- The header `Progress` counter matches the number of `Done` rows.
- **If the roadmap is missing:** return the error below.

## archive — archive a completed feature-set

Membership is **explicit**: move only the rows actually listed in the roadmap.

1. Read the feature-set slug from the roadmap header.
2. Create `plans/_archive/<feature-set>/`.
3. Move into it: the roadmap itself, plus **only** the RD documents and plan folders
   that appear as rows in the roadmap.
4. Leave all other `requirements/` and `plans/` content untouched. Never sweep every
   folder under `plans/`.
5. A fresh roadmap can then be created for the next feature-set.
6. **If the roadmap is missing:** return the error below.

---

## Error handling

| Error case | Handling |
|------------|----------|
| **review** / **archive** when roadmap missing | Return `**Error:** No roadmap found at plans/00-roadmap.md. Run make_roadmap first.` |
| **update** when roadmap missing | Fall back to **make** (ask-if-missing, then create) |
| **make** when roadmap already exists | Do NOT ask; sync from disk state (the update action) |

## Project conventions

For project-specific settings (build/test/verify commands, package manager,
structure, conventions), read the project's CLAUDE.md (or detected project
conventions). If no CLAUDE.md exists, detect settings from manifest files and use
only facts you can read — do not invent settings.

## Pointers & related skills

- [template.md](template.md) — the `plans/00-roadmap.md` template, legend, tracker
  columns, and a worked example. Read before **make**.
- [stage-hooks.md](stage-hooks.md) — the full stage-transition map, which skill fires
  which hook, and the source-of-truth rule. Read when reasoning about transitions.
- Related skills: requirements (`RD Drafted` hook), preflight (`RD/Plan Preflighted`
  hooks), make_plan (`Plan Created` hook + linking), exec_plan (`Executing` / `Done` /
  `Blocked` hooks).
