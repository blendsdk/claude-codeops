# roadmap

> Track an entire feature-set across its lifecycle in a live roadmap at `plans/00-roadmap.md`.

## What it does

`roadmap` maintains the cross-session source of truth at the RD/plan altitude — above any single
execution plan. It tracks every RD and plan and the lifecycle stage each is in. It covers six
actions:

- **make_roadmap** — create the roadmap and seed rows from what is on disk.
- **update_roadmap** — re-infer stages and sync to the current disk state.
- **review_roadmap** — a read-only health check for drift and broken links.
- **show_roadmap** — a read-only status overview: overall progress, the per-item stage table, and
  concrete next steps, for one feature or the whole repo. Presentation only — it changes nothing.
- **archive_roadmap** — move a completed feature-set into `plans/_archive/<feature-set>/`.
- **compact_roadmap** — slim a bloated roadmap back to a lean table: strip a legacy `## Notes`
  running log and trim any overstuffed cells. Git is the archive, so it runs only on a clean tree.

It detects the action from your phrasing or arguments and branches accordingly.

A roadmap is **only a table** — a dependency-ordered list of RDs, plans, and tasks and the lifecycle
stage each is in, worked top-to-bottom. Per-item history and rationale live in the plan folder and
git, never in the roadmap, so it stays small; `compact_roadmap` slims any older roadmap that
predates this and still carries a Notes log or paragraph-sized cells.

## When to use it

- You are running a multi-feature effort and want one view of where everything stands.
- "roadmap", "make_roadmap", "update_roadmap", "review_roadmap", "show_roadmap", "archive_roadmap", "compact_roadmap".

## Trigger phrases

"roadmap", "make_roadmap", "update_roadmap", "review_roadmap", "show_roadmap", "archive_roadmap", "compact_roadmap".

## Worked example

```text
make_roadmap
```

Seeds `plans/00-roadmap.md` from your existing `requirements/` and `plans/` directories. As work
proceeds, [`make_plan`](/skills/make_plan) sets a row to `Plan Created` and
[`exec_plan`](/skills/exec_plan) advances it to `Executing` → `Done`; run `update_roadmap` any time to
re-sync.

## Related skills

- [`make_plan`](/skills/make_plan) — sets the `Plan Created` stage.
- [`exec_plan`](/skills/exec_plan) — advances stages as execution proceeds.
- [`make_requirements`](/skills/make_requirements) — the RDs the roadmap tracks.
