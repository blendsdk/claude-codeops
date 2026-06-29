# setup_codeops

> Set up the CodeOps **nested `codeops/` layout** in a repo — scaffold a fresh skeleton or
> auto-migrate an existing flat layout into it.

## What it does

`setup_codeops` prepares the git repo you are in for the nested CodeOps layout, where each feature
owns its requirements, plans, and roadmap under `codeops/features/<feature>/`, with a portfolio
roadmap at `codeops/00-roadmap.md`. It detects the repo's state and dispatches:

1. **Marker already present** (`codeops/.codeops.yml`) → no-op status report (idempotent).
2. **Flat layout** (`requirements/` / `plans/`) → **migration**: it runs the deterministic engine
   `scripts/codeops-migrate.sh --dry-run` to compute the move map + warnings, renders the preview,
   takes **one** confirmation, then applies via `git mv` (history preserved).
3. **Neither** → a minimal **fresh scaffold** (`.codeops.yml`, an empty portfolio roadmap, and
   `features/`).

It is the **sole writer** of the layout marker. Migration is `git mv`-only, refuses a dirty tree,
rejects path-traversal feature slugs, and is fully idempotent. The marker keeps the change
non-breaking: repos without it keep using the flat layout forever.

## When to use it

- You want to organize a repo's CodeOps artifacts per feature instead of in flat `requirements/` +
  `plans/` directories.
- You have an existing flat-layout repo and want to migrate it to the nested layout in one
  reviewable commit.
- You are starting fresh and want the minimal `codeops/` skeleton scaffolded.
- **Not** for authoring requirements or plans — use `make_requirements` / `make_plan` for that
  (they then resolve paths under the new layout automatically).

## Trigger phrases

"setup_codeops", "set up codeops", "initialize codeops", "migrate to the nested layout", "convert
my flat plans/requirements", "scaffold the codeops structure". Explicit: `/codeops:setup_codeops`
or the alias `/setup_codeops`. Flags: `--dry-run` (preview only) and `--yes` (apply without the
prompt).

## Worked example

```text
/setup_codeops
```

In a flat-layout repo with `requirements/` and `plans/billing/`, the skill runs the migration
engine in dry-run and shows a preview:

```text
setup_codeops — migration preview (flat → nested)
  Feature slug:  billing-platform   (source: roadmap header "Billing Platform")
  Move:          requirements/, plans/billing/, plans/00-roadmap.md
  Create:        codeops/.codeops.yml, codeops/00-roadmap.md (portfolio, 1 feature)
  ⚠ Warnings: plans/legacy/ not in roadmap; plans/legacy/03-old.md links ../../src/pay.ts
  Apply with git mv? [y/N]
```

After you confirm, it `git mv`s everything under `codeops/features/billing-platform/`, writes the
marker + seeded portfolio last, and lists the warnings as manual follow-ups.

## Related skills

- [`roadmap`](/skills/roadmap) — the two-tier (per-feature + portfolio) roadmaps the layout enables.
- [`make_requirements`](/skills/make_requirements) — authors RDs under `codeops/features/<f>/`.
- [`make_plan`](/skills/make_plan) — authors plans (and lightweight task mini-plans) under the feature.
- See the [Commands page](/skills/commands) for the `/setup_codeops` alias.
