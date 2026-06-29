# Concepts

A few ideas explain how CodeOps behaves. Understanding them makes the skills predictable.

## Skills vs. commands

- **Skills** are multi-step protocols Claude runs on request. They **auto-trigger** from natural
  language (e.g. "make a plan") *and* can be invoked explicitly as `/codeops:<name>`.
- **Commands** are slash commands. The core ones (`/gitcm`, `/gitcmp`, `/analyze_project`,
  `/migrate_clinerules`) do focused jobs; the rest are **thin alias commands** that delegate to a
  parent skill in a specific mode. Aliases are manual-only — only the parent skills auto-trigger.

See the [Skills overview](/skills/) and the [Commands page](/skills/commands).

## Repo layout: flat vs. nested

CodeOps supports two on-disk layouts, and every layout-aware skill detects which one a repo uses:

- **Flat layout** (the default): requirements live in `requirements/`, plans in `plans/<feature>/`,
  and a single roadmap at `plans/00-roadmap.md`. This is unchanged from earlier versions and keeps
  working forever — no marker, no migration required.
- **Nested layout**: each feature owns its work under `codeops/features/<feature>/`
  (`requirements/`, `plans/`, and a per-feature `00-roadmap.md`), with a **portfolio roadmap** at
  `codeops/00-roadmap.md` rolling up one row per feature. It also adds a lightweight **task lane**
  (`T-NN`) for ad-hoc work that isn't a full feature.

A repo opts into the nested layout via a single marker file, `codeops/.codeops.yml`. The
[`setup_codeops`](/skills/setup_codeops) skill is the sole writer of that marker: it scaffolds a
fresh skeleton or auto-migrates an existing flat repo (preview → one confirmation → `git mv`,
history preserved). Repos without the marker stay flat, so the feature is fully non-breaking.

## Progressive disclosure

Only each skill's **name + description** load into context up front. The full body loads **when the
skill is used**. This is why CodeOps no longer needs the old MCP server: Claude Code keeps the
context window small natively. It also means skill descriptions must stay within Claude Code's
display budget (the repo's `validate.sh` enforces ≤ 1024 chars).

## Always-on standards

The plugin bundles a single source of truth for universal coding/testing/working-style standards:
`standards/coding-standards.md`. A `SessionStart` hook `cat`s that file into the context of every
new session, so the standards are always present with **zero setup**.

- Fires on every session start (including after `/clear` and context compaction).
- Read-only — the hook only reads a file shipped inside the plugin; it never writes anything.
- To turn it off, disable the plugin. There is no separate toggle.

See the summarized standards in the [Reference](/reference/standards).

## Rolling updates

The plugin carries **no version number** — the latest git commit *is* the version. Every push is
immediately installable via `/plugin update`. There is no release/publish ceremony.

## The Zero-Ambiguity Gate

Several skills ([`make_plan`](/skills/make_plan), [`make_requirements`](/skills/make_requirements))
enforce a hard **Zero-Ambiguity Gate**: before any plan or requirement document is written, every
gap, assumption, and open question is hunted across a fixed set of categories, compiled into an
**Ambiguity Register**, and resolved by **you** — never guessed by the model. The gate opens only
when every item is explicitly resolved and you have confirmed the complete register.

## Recommendation hardening

CodeOps institutionalizes the question *"are these your best recommendations?"* so it runs **before**
you ever see the answer — and so the result *converges* on a verified-best option instead of drifting
under pressure. Before presenting a consequential recommendation the model (1) **reframes** — what
would it recommend with 10× the budget, what would a contrarian expert push, what would make its pick
obsolete; (2) passes a **definition-of-done** rubric — a genuinely non-obvious option considered,
confidence stated, the strongest counter-argument named; and (3) discloses a `Confidence:` /
`Hardening:` line so residual uncertainty is visible and you know where to push.

For **high-stakes** decisions — [`preflight`](/skills/preflight) findings at CRITICAL/MAJOR severity,
or [`make_plan`](/skills/make_plan) / [`make_requirements`](/skills/make_requirements) gate decisions
tagged complex/sensitive — an **independent challenger** is spawned in a fresh context (blind to the
model's pick) and reconciled, because a self-critique in the same context inherits the same blind
spots. The protocol is the always-on directive plus `_shared/recommendation-hardening.md`; it reaches
every installation automatically via [rolling updates](#rolling-updates) and the always-on standards.

## Specification-first testing

CodeOps separates **specification tests** (derived from requirements/acceptance criteria — immutable
oracles) from **implementation tests** (edge cases and internals). The enforced order is:
**write spec tests → confirm they fail (red) → implement → make them pass (green) → add impl tests →
verify**. [`exec_plan`](/skills/exec_plan) drives this ordering task-by-task.

## The pipeline

The skills compose:

```
grill_me → make_requirements → preflight → make_plan → preflight → exec_plan
```

with [`roadmap`](/skills/roadmap) tracking the feature-set and [`techdocs`](/skills/techdocs) keeping
architecture docs current. The [tutorials](/tutorials/) walk this end to end.
