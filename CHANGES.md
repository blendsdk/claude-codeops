# CHANGES — CodeOps for Claude Code

## Changelog

### 3.10.1 — Telemetry attributes agents from `subagent_type` (2026-07-20)

Fix. No configuration change, no document migration; existing events are untouched.

- **Agent attribution no longer depends on the dispatch header.** The
  `[codeops-dispatch agent=… feature=… phase=…]` header is only required on the post-phase
  quality-loop path, so `codebase-scout`, `design-challenger`, `spec-test-author` and both
  executors never appeared in `/codeops_stats --by agent` — the telemetry was blind to five of
  the nine agents. `scripts/codeops-events.sh` now identifies the agent from the dispatch tool's
  own `subagent_type`.
- **What counts as a CodeOps dispatch.** A `subagent_type` carrying the `codeops:` prefix, or a
  bare name matching an agent the plugin ships — so project-local overrides in `.claude/agents/`
  attribute correctly too. Resolving against the shipped `agents/` directory keeps one source of
  truth: adding or renaming an agent needs no change to the utility.
- **Ordinary agent use stays out of the per-agent view.** Spawns such as `Explore` or
  `general-purpose` are still recorded, but without an agent name, so they cannot skew per-agent
  statistics.
- **Nothing regresses.** The header remains the sole source of `feature` and `phase`, which are
  not derivable from the payload, and is still read as a fallback for the agent when
  `subagent_type` is absent. Where the two disagree, the payload wins — a copy-pasted header can
  name an agent that never ran.

### 3.10.0 — Quality agents, per-repo quality profiles, and telemetry (2026-07-19)

Additive and dormant-by-default — repos without a quality-profile block behave exactly as
before; no document migration.

- **Seven quality agents** join the two executors in `agents/`: `phase-reviewer` (one phase
  diff, base + add-on lenses, RV findings), `spec-test-author` (implementation-blind spec tests
  with a FORBIDDEN-file contract, red-phase confirmation), `security-auditor` (one dispatch per
  phase with the union of the active checklists — owasp-web, auth-protocol, financial-integrity,
  tenant-isolation, mcp-agent; SA findings), `preflight-auditor` (one artifact × one dimension
  cluster, evidence + self-refutation; PA findings), `design-challenger` (blind second opinion
  for the recommendation-hardening protocol), `perf-auditor` (cost-model-driven; PE findings),
  and `codebase-scout` (facts with `file:line`, ≤3 dispatches per skill run). All reviewers are
  read-only and report "no findings" explicitly.
- **Per-repo quality profile.** A `<!-- CODEOPS-QUALITY -->` sentinel block in the project's
  `CLAUDE.md` — written by `/setup_routing` alongside the routing block, hand-edits welcome —
  activates the loop: add-on lenses (7-value grow-only enum; `standards` is base-only),
  security profiles, `perf_critical`, `review_hook`, `telemetry`, `agent_models` overrides.
  Canonical definition in `_shared/quality-profile.md`; parsing is lenient per key.
- **exec_plan quality loop.** Phase-start refs, `[spec-author]` task dispatch, and a post-phase
  quality step: reviewer + active auditors in parallel on the phase diff, severity-grouped
  rulings — 🔴/🟠 findings pause execution in **every** commit mode (auto-commit automates git,
  never the ruling), one fix-diff re-review, follow-up commits. `preflight` fans out as five
  clustered preflight-auditor dispatches (`--thorough` → per-dimension).
- **Metadata-only telemetry.** `scripts/codeops-events.sh` appends enum/count/id/hash events —
  never content — to a local `~/.claude/codeops-telemetry/events.jsonl`; a PostToolUse hook
  (matcher `Skill|Task|Agent`) records skill and subagent completions deterministically; skills
  emit workflow events only where a profile is active. Strict whole-line refusal protects the
  dataset; kill switches: `CODEOPS_TELEMETRY=0`, `telemetry: off`, missing `jq`. New commands:
  **`/codeops_stats`** (relay the aggregated tables) and **`/codeops_retro`** (thresholds +
  plugin-bucket vs profile-bucket verdicts) — the suite reaches **21 slash commands**.
- **Guards + spec suite.** `telemetry-check.sh` (16 spec cases, written red-first, plus edge
  cases) joins the verify chain; validate.sh gains ST-68…ST-73 (agent frontmatter, roster,
  quality-profile enums, taxonomy drift, hook registration, catalog drift), mutation-verified.
- Docs: new Guide pages (Quality profile, Telemetry) + Reference page (Agents); README/TUTORIAL
  sections. Dev-installer users: re-run `./install.sh` for the new command symlinks.

### 3.9.0 — GitHub issue commands: `/gh_issues` + `/gh_close` (2026-07-17)

Additive — no document migration; existing workflows untouched.

- **New `/gh_issues` command.** Read-only tabular overview of a GitHub repo's issues
  (`# · Title · Type · Priority · Effort · Deps · Assignee`) whose semantic columns are resolved
  through the repo's **own** scheme — labels, native issue types, project fields — discovered per
  run, never imposed. Native filters (`--state --label --mine --author --milestone --search
  --limit --repo`), semantic filters through the discovered scheme (`--type`, `--priority`,
  with mapping notices like `--priority high → P1`), client-side `--sort`, and dependency
  detection from sub-issue relations plus body markers (`Depends on #N`, `Blocked by #N` —
  open dependencies only), skippable via `--no-deps`. Honest empty states: notices for absent
  label families, a truncation footer instead of silent caps. Model-invocable — "list the
  github issues", "issues table", "what's open in this repo".
- **New `/gh_close` command.** Close one or more issues by number with GitHub's native close
  reasons — completed (default), not planned (`--not-planned` / `--wontfix`), or duplicate
  (`--duplicate <#N>`, emulated as a `Duplicate of #N` comment + not-planned close) — or reopen
  with `--reopen`; `--comment` rides along. Echoes each issue's title before acting, skips
  already-closed/already-open no-ops, continues past nonexistent numbers with a per-issue
  outcome summary, and **pauses for confirmation when other open issues depend on the target**.
  Manual-only — fires only when typed.
- Command count 17 → 19 across the guarded prose surface; release stamped 3.9.0.
- Dev-installer users: re-run `./install.sh` — new command files need fresh symlinks
  (`install.sh` links per file).

### 3.8.0 — `show_roadmap`, a read-only roadmap status view (2026-07-15)

Additive — no document migration; existing roadmaps and workflows are untouched.

- **New `show` roadmap action + `/show_roadmap` alias.** The `roadmap` skill gains a sixth action
  that *presents* a roadmap instead of maintaining it: the resolved header and `Last Updated`, the
  overall progress line, the per-item stage table with its legend, a "where you stand right now"
  read, and 1–3 grounded next steps — for one feature (`show_roadmap <feature>`) or the whole repo
  (portfolio overview, layout-aware). It is **read-only**: unlike `update`/`compact` it never writes
  to disk, and unlike `review` (a drift/broken-link health check) it is a human-facing status
  dashboard. Stale counters or stages are noted with a suggestion to run `update_roadmap`, never
  silently rewritten. The command ships as a manual-only thin alias (`disable-model-invocation`),
  while "show the roadmap" / "roadmap status" / "where do things stand" also trigger the parent
  skill. This brought the suite to nineteen slash commands.

Behavioral + format guidance, no document migration — existing `CLAUDE.md` files keep working and
can be slimmed on demand.

- **`CLAUDE.md` stays lean, because it is always-on context.** `analyze_project` now generates a
  terse *Project structure* (one line per top-level item), and `setup_routing` emits a **≤10-line**
  routing block (every routing directive preserved on dense single lines) instead of the old
  18-line block. The `analyze_project` refresh comment is **replaced in place** — one comment, not a
  stack that grows every run.
- **New `analyze_project --compact` leaning mode.** `/analyze_project --compact` slims an
  already-bloated `CLAUDE.md`: it measures the file against the budgets, tightens the derived
  sections, slims the routing block in place (sentinels byte-exact, never relocated), prunes stacked
  refresh comments to one, and *advisory-flags* over-budget hand-authored sections without rewriting
  them. It previews before writing and asks for confirmation; `--dry-run` reports without writing; it
  operates on the current project only.
- **Mechanical budget guards.** `validate.sh` now gates the verify chain on `CLAUDE.md` leanness —
  total ≤150 lines, derived *Project structure* ≤20, routing span ≤10, ≤1 refresh comment, and no
  duplicated injected coding standards — skipping cleanly when a repo has no root `CLAUDE.md`. This
  repo's own `CLAUDE.md` was slimmed from 102 to 75 lines to match.

### 3.5.0 — lean, table-only roadmaps + a `compact` action (2026-07-13)

Behavioral + format guidance, no document migration — existing roadmaps keep working and can be
slimmed on demand with the new action.

- **Roadmaps are a table, not a log.** The `## Notes` running log is dropped from every roadmap
  template, and the per-row `Notes / Blocker` column is renamed **`Depends-on / Blocker`** (terse:
  a planned prerequisite or the `DEF-n` a `Blocked` row waits on). Rows are ordered by dependency
  and worked top-to-bottom. Per-item history now lives only in the plan folder and git, so a
  roadmap can no longer bloat the context it is loaded into. `codeops-migrate.sh` stops seeding a
  Notes log in the portfolio it writes.
- **New `compact` roadmap action + engine.** `compact_roadmap` slims a bloated roadmap back to a
  lean table: the new deterministic `scripts/codeops-roadmap-compact.sh` strips every `## Notes`
  section and flags oversized cells (`FLAG <file>:<row>:<column>`), then the action trims the
  flagged cells to terse phrases while preserving the load-bearing `waiting on DEF-n` /
  `Blocked (was: <stage>)` tokens. Git is the archive, so `apply` refuses a non-git or dirty tree
  (mirrors `codeops-migrate.sh`). `update`/`review` run its `--check` mode to detect legacy bloat
  and recommend `compact`, but never mutate. Guarded by `validate.sh` ST-56…ST-59 and the
  `scripts/compact-check.sh` spec suite.

### 3.4.1 — worktree base branch follows `integrationBranch` (2026-07-12)

Behavioral, no document migration — 3.0.0–3.4.0 plans/requirements remain compatible.

- **`codeops-worktree` now reads `integrationBranch` from the marker.** New feature branches
  fork from the marker's `integrationBranch` (`codeops/.codeops.yml`) when that key is set,
  falling back to `origin/HEAD` → `main`/`master` → the current branch when it is absent (exactly
  as before). This makes the CLI's default base agree with the branch-aware skills, so a
  **`devel`/`acceptance`-based workflow works with no per-command `--from` flag** — set
  `integrationBranch: devel` once and `codeops-worktree new <topic>` forks from `devel`. `--from`
  still overrides per run. The marker value is only parsed, never executed. Guarded by
  `validate.sh` ST-55.

### 3.4.0 — parallel agents: branch-aware derived files (2026-07-12)

Behavioral, no document migration — 3.0.0–3.3.2 plans/requirements remain compatible, and every
new marker key is **optional** (a repo that never onboards keeps working unchanged). Lets multiple
Claude Code agents work concurrently on one repo — **one git worktree per feature** — without
colliding on the *derived*, repo-wide files. Highlights:

- **`codeops-worktree` CLI (shipped 3.3.x, now first-class):** `new` / `ls` / `rm` spin up and tear
  down a sibling worktree per feature branch (`--dry-run`, `--launch`). Installed onto `~/.local/bin`
  by the dev `install.sh` (with a reversible PATH-add); the marketplace plugin cannot place PATH
  executables, so rolling installs get it via the installer. Windows: Git Bash.
- **Derived files are reconciled, not cascaded (the core principle):** per-feature files under
  `codeops/features/<f>/` were already isolated; the conflict surface is the *derived* files — the
  portfolio roadmap, `CLAUDE.md`, and the routing block. Three skills now defer those writes off the
  integration branch:
  - **roadmap:** the portfolio cascade (`codeops/00-roadmap.md`) is **deferred on a non-integration
    branch** — only the isolated per-feature roadmap is written; `roadmap update` reconciles the
    portfolio from disk once the work lands on the integration branch (flat layout stays inert).
  - **setup_routing:** a light integration-branch guard — warn/skip the repo-wide `CLAUDE.md`
    routing-block write on a feature branch.
  - **analyze_project:** branch-aware — previews/stages generated `CLAUDE.md` sections to a
    per-feature `CLAUDE.notes.md` off the integration branch and folds them (idempotently) on it,
    instead of rewriting the shared `CLAUDE.md` on a feature branch.
- **New optional marker key `integrationBranch`:** names the branch derived files reconcile onto.
  `setup_codeops` (the sole marker writer) emits it on fresh scaffold and **idempotently backfills**
  it on the "marker already present" path — the one-command entry point for existing projects;
  `codeops-migrate.sh` writes it on flat→nested. When absent, every skill auto-detects the default
  branch (`origin/HEAD` → `main`/`master`; if git is unavailable, behaves exactly as today).
- **User guide:** a **[Parallel agents](https://blendsdk.github.io/claude-codeops/guide/parallel-agents)**
  page on the docs site (the idea, `codeops-worktree` usage, why there are no conflicts, the
  post-merge reconcile, and adopting it in existing projects) + a README pointer.
- **Guards:** `validate.sh` ST-48…ST-54 lock the branch-aware behavior, the marker emit/backfill,
  and the guide in place; ST-24's stamp glob now covers `bin/`.

### 3.3.2 — file-size ceiling raised to ~700 lines (2026-07-08)

Behavioral, no document migration — 3.0.0–3.3.1 plans/requirements remain compatible.

- **Standards:** the file-split guidance moves from "split before ~500 lines" to **"split before
  ~700 lines"**, while **200–500 lines stays the aspirational target** (700 is the ceiling, not the
  goal) and "split when a file holds multiple concerns" remains the primary trigger. Modern models
  (Opus 4.8, Sonnet 5, Haiku 4.5, Fable 5) read and edit 700-line files with room to spare — the
  cap is a human-readability / single-responsibility heuristic, not a context limit. Applied in both
  standards cores and the make_plan Phase-1 architecture check.

### 3.3.1 — self-contained code documentation (2026-07-08)

Behavioral, no document migration — 3.0.0–3.3.0 plans/requirements remain compatible. Highlights:

- **Documentation standard — ephemeral-reference ban (NON-NEGOTIABLE):** no code comment or doc
  comment may reference a CodeOps planning artifact (`codeops/`, `plans/`, `requirements/`, an
  execution plan, or an `RD-`/`AR-`/task identifier). Those files are regenerated, migrated between
  layouts, or deleted once a feature ships, so a reference into them is a dangling pointer and noise
  to a reviewer. Shipped code must stand on its own; restate any plan rationale in plain language.
  Commit / PR messages stay exempt (durable git history). Enforced at every path that writes code:
  both `standards/` cores, the exec_plan per-task implement step, a **doc-standard self-check** that
  gates `[~]`→`[x]` promotion (a leaked reference is invisible to build+test, so a green verify is
  not sufficient), and both dispatched executor agents (which run in a separate context that never
  sees the SessionStart standards hook). `validate.sh` ST-47 locks all of this in place.
- **Documentation standard — expanded:** document every non-trivial entity; `@example` on public /
  external-facing API (AI tools learn the contract from it); calm explaining tone; no change-history
  / bug-fix notes in doc comments (that belongs in the commit body). Spec-test traceability comments
  now quote the requirement's *substance* in plain language, never a path/ID into `requirements/`.
- **New `/clean_jsdoc` command:** a detection-first, language-agnostic retrofit that brings an
  existing project's JSDoc and code comments up to the standard above — cheap grep pass to find
  violations, then scoped semantic rewrites (comments only, never behavior). Runs well on a cheaper
  model. Modes: `--dry-run` (report only) and `--refs-only` (strip references only).

### 3.3.0 — token efficiency (2026-07-05)

Implements the measured token-diet findings (plan: `plan-token-efficiency`; evidence: the
2026-07-05 corpus analysis of two production repos + the 2026-07-04 dispatch pilots). Highlights:

- **Deduplicated execution plans:** the 99-execution-plan template carries each phase's tasks
  ONCE as a checkbox list (single source of truth; two-stage `[~]`/`[x]` marks live there); the
  Master Progress Checklist section is gone from new plans. exec_plan runs BOTH formats via
  dual-format detection — pre-3.3.0 plans keep their checklist, no migration, no upgrade nag.
- **Verify-output capture (exec_plan, NON-NEGOTIABLE):** verify runs redirect to a temp log;
  PASS surfaces one line, FAIL the last 50 lines + log path, red-phase runs a failing-test
  summary — the full build/test dump never enters context.
- **Reference, don't restate (make_plan, NON-NEGOTIABLE):** every fact has one owning doc
  (RD/01 → scope, 03 → design, 07 → ST-cases, register → decisions); other docs cite with a
  one-line gloss; AR/ST-restating audit tables banned; RD-based plans get a thin delta-only
  `01-requirements.md`.
- **Inline-first execution:** per-task delegation replaced — phases run inline on the tagged
  model (pilot-measured: per-task dispatch costs 1.5–2× inline; ~13k bootstrap per executor);
  a phase is dispatched as ONE pinned executor only when a cheaper model is warranted; per-task/
  parallel dispatch is opt-in. Executors are phase-packet units; setup_routing's generated block
  and docs match.
- **Guards:** validate.sh ST-41…ST-46 lock all of the above in place.

### 3.2.0 — v3 hardening (2026-07-03)

Implements all findings of the 2026-07-03 deep analysis (plan: `codeops-v3-hardening`). Highlights:

- **Correctness:** `codeops-migrate.sh` apply path is failure-checked (no marker after a failed
  step, non-zero exit, archive loose files relocated); exec_plan completion marks are two-stage
  (`[~]` implemented → `[x]` verified) with crash-safe resume; retro_requirements is truly
  layout-aware; roadmap stages are re-inferable (preflight-report artifacts, never-regress,
  `Blocked (was: <stage>)`).
- **Gate consolidation:** the Zero-Ambiguity Gate and spec-first ordering are single-sourced in
  `_shared/`; one named-deferral status (`⏸ Deferred — decision · owner · revisit-trigger`) is
  accepted across grill_me → gates → preflight; "accept all recommendations" is formally an
  explicit decision; recommendation-hardening is bounded (one batch challenger per preflight
  scan, ≤2 spawns/run, conditional disclosure).
- **Delegation:** executor subagents ship in the plugin's `agents/`; exec_plan has a real
  Delegated Execution protocol (handoff packet, blocker path, inline fallback); setup_routing
  writes the policy block only (per-project agents opt-in).
- **Mechanization:** new `scripts/codeops-roadmap-sync.sh` recomputes roadmap counters/cascade
  (`--check` powers review_roadmap); the flat layout gained the mini-plan task lane; grill_me and
  preflight continuity notes are save-as-you-go with staleness checks.
- **Distribution:** `plugin.json` carries `"version"` (kept in sync by validate.sh); docs counts
  are filesystem-derived-guarded; combined description+when_to_use budget enforced; standards
  injection slimmed with a full reference file; PreToolUse marker guard; Mermaid actually renders
  in generated techdocs (vitepress-plugin-mermaid); gitcm/gitcmp edge-case guards; legacy MCP
  revivals (coverage targets, task-size numerics, non-code validation, security-test layout).

### 3.1.0 — recommendation hardening (2026-07-01, PR #4)

- New `_shared/recommendation-hardening.md`: forced reframing, definition-of-done rubric,
  confidence disclosure, tiered independent challenger; wired into the standards' Grounded
  Options directive and the gate-running skills (validate.sh ST-18…ST-24).

### 3.0.0 — per-repo nested layout (2026-06-29, PR #3)

- Nested `codeops/` layout (portfolio + per-feature roadmaps, per-feature RD ids, task lane) with
  a permanent flat fallback, selected by the `codeops/.codeops.yml` marker.
- New `setup_codeops` skill + command; deterministic migration engine `scripts/codeops-migrate.sh`
  with the `migration-check.sh` spec suite; `_shared/layout-convention.md` as the single layout
  source; 11 skills plus the slash-command set.

---

## Port record — CodeOps MCP → Claude Code Skills (v2.0.0 era, frozen)

This records the migration of the `codeops-mcp` server (built for Cline, served via MCP) into
native Claude Code **skills**, **slash commands**, and **CLAUDE.md** content. The original repo
is preserved untouched in `../codeops-mcp-src/` for reference.

Version stamp adopted for the ported artifacts at the time: **CodeOps Skills v2.0.0** (replaces
the old `codeops-mcp` package version that plans/requirements used to stamp). Current stamps
track the release version above.

---

## 1. What moved where

| Original protocol / rule doc | New home | Type |
|---|---|---|
| `make_plan` (creation half of make_plan.md) | `skills/make_plan/` | Skill |
| `exec_plan` (execution half of make_plan.md) | `skills/exec_plan/` | Skill |
| `make_requirements` / `add_requirement` / `review_requirements` (requirements.md) | `skills/make_requirements/` | Skill (3 modes) |
| `retro_requirements` (retro_requirements.md) | `skills/retro_requirements/` | Skill |
| `grill_me` (grill_me.md) | `skills/grill_me/` | Skill |
| `preflight` (preflight.md) | `skills/preflight/` | Skill |
| `make_techdocs` / `review_techdocs` (techdocs.md) | `skills/techdocs/` | Skill (2 modes) |
| `make_roadmap` / `update_roadmap` / `review_roadmap` / `archive_roadmap` (roadmap.md) | `skills/roadmap/` | Skill (4 actions) |
| `upgrade_plan` / `upgrade_requirements` (upgrade_plan.md) | `skills/upgrade_plan/` | Skill (2 targets) |
| `gitcm` (git-commands.md) | `commands/gitcm.md` | Slash command |
| `gitcmp` (git-commands.md) | `commands/gitcmp.md` | Slash command |
| `analyze_project` (MCP tool) | `commands/analyze_project.md` | Slash command (now writes `CLAUDE.md`) |
| `add_requirement`, `review_requirements`, `make_techdocs`, `review_techdocs`, `make_roadmap`, `update_roadmap`, `review_roadmap`, `archive_roadmap`, `upgrade_requirements` | `commands/<verb>.md` | Thin alias commands → delegate to the parent skill |
| `code.md` + `testing.md` + universal parts of `agents.md` | `CLAUDE.md.snippet` | Always-on standards (global) |
| `project-template.md` (`.clinerules/project.md` template) | template inside `commands/analyze_project.md` | Per-project `CLAUDE.md` |
| — (new) | `commands/migrate_clinerules.md` | Slash command — converts an existing `.clinerules/project.md` into `CLAUDE.md`, preserving user content and stripping Cline/MCP cruft |
| MCP tools `get_rule` / `list_rules` / `search_rules` / `get_setup_guide` | **dropped** | Obsoleted by progressive disclosure |
| Entire `src/` TypeScript server + tests | **not ported** | Kept only as reference |

**Consolidations vs. the original keyword set.** Several keywords that were distinct triggers now
share one skill (the body branches on the user's phrasing/arguments):
- `make_requirements` skill also handles `add_requirement` and `review_requirements`.
- `techdocs` skill handles both `make_techdocs` and `review_techdocs`.
- `roadmap` skill handles `make_roadmap`/`update_roadmap`/`review_roadmap`/`archive_roadmap`.
- `upgrade_plan` skill handles both `upgrade_plan` and `upgrade_requirements`.

**Wrapper commands restore every original trigger word as typeable.** So muscle memory still works
for the non-primary verbs, each consolidated verb also ships as a thin alias command in
`commands/` that delegates to its parent skill in the right mode (via the Skill tool). These
aliases are `disable-model-invocation: true` (manual-only) so they don't compete with the parent
skills for auto-trigger and don't consume the skill-listing description budget — only the parent
skill auto-triggers from natural language. The wrappers:
`add_requirement`, `review_requirements` → `make_requirements`; `make_techdocs`,
`review_techdocs` → `techdocs`; `make_roadmap`, `update_roadmap`, `review_roadmap`,
`archive_roadmap` → `roadmap`; `upgrade_requirements` → `upgrade_plan`.

---

## 2. Cline / MCP-specific things removed (applied across ALL ported docs)

These were stripped everywhere they appeared:

- **MCP tool calls** — every `get_rule("…")`, `list_rules`, `search_rules`, `analyze_project`,
  `get_setup_guide`. Cross-references like `get_rule("roadmap")` became "the roadmap skill".
  Progressive disclosure replaces the entire load-on-demand mechanism the MCP existed to fake.
- **The "MANDATORY: load rules before any work" preamble** (from `project-template.md`) — deleted
  outright. CLAUDE.md is always loaded and skills self-trigger, so the ritual is unnecessary.
- **`.clinerules/project.md`** references (50+) — rewritten to "the project's CLAUDE.md
  (or detected project conventions)".
- **`clear && sleep 3 &&` shell prefix** (VS Code terminal warm-up) — removed from all commands.
- **Cline tool names** — `write_to_file`/`replace_in_file` → normal file writes/edits;
  `ask_followup_question` → "ask the user"; `list_files` → normal file listing;
  `attempt_completion` → "before ending the session/task".
- **`/compact` + context-window-threshold (90%) / multi-session-survival mechanics** — removed;
  Claude Code auto-compacts. Genuine "save progress to a file and resume" guidance was kept and
  rephrased natively (e.g. `requirements/_draft/`, `requirements/_retro/_progress.md`,
  `_grill_me_notes.md`, `_preflight_notes.md`, `docs/_draft/techdocs-progress.md`, `--continue`).
- **"NEVER run raw git, ALWAYS use gitcm/gitcmp" mandate** — softened to "commit using `/gitcm`
  or `/gitcmp` (or a normal git commit)". Claude Code runs git natively; the commands are now
  conveniences, not a hard gate.
- **Dynamic version stamp from `codeops-mcp` package.json** — replaced with the static
  `> **CodeOps Skills Version**: 2.0.0`. Upgrade-detection logic now compares against this constant.
- **Doc-to-doc cross-references** (`see make_plan.md`, `testing.md`, etc.) — rewritten to
  "the <X> skill", or to "your project's coding/testing standards (CLAUDE.md)" for the
  always-on `code.md`/`testing.md` material.
- **npm/MCP install & configuration language** — removed; replaced by this repo's `install.sh`.

The intent of every protocol — every phase, every hard gate, every output document set and
folder layout — was preserved. See per-skill notes below for anything specific.

---

## 3. Enhancements made (across the port)

- **Progressive disclosure built in.** Every `SKILL.md` is lean (most just a couple hundred lines;
  `grill_me` is the one larger single-file skill at ~320, and every `description` stays within Claude
  Code's ~1024-char display budget) with bulky templates/protocols moved into sibling reference files
  that are linked relatively and loaded only when Claude follows the link. This is the behavior the
  MCP was hand-rolling; it's now native.
- **Trigger-word-first descriptions.** Each `description` leads with the use case and the literal
  original trigger words plus natural-language variants, so the skills auto-invoke reliably.
- **Mode-dispatch tables** added to the consolidated skills (make_requirements, techdocs, roadmap,
  upgrade_plan) so one skill cleanly handles several former keywords.
- **Consistent house style** across all nine skills: frontmatter conventions, a "Related skills"
  pointer block, 🚨 markers preserved only on load-bearing gates, native session-resume guidance.
- **Argument hints** (`argument-hint`, `arguments`) added where the original took parameters
  (exec_plan flags, preflight target, retro `--scope`/`--continue`, upgrade feature name).

---

## 4. Per-skill / per-file notes

### skills/make_plan (creation only)
- Removed: 90%-context tables, the agent.sh session ritual, the raw-git "BANNED `-m`" banners,
  rule-number citations into Cline rule files.
- Files: `SKILL.md`, `zero-ambiguity-gate.md` (Phase 1C), `templates.md` (all plan docs +
  spec-first ordering + project-type table), `quality-checklist.md` (Phase 3).
- Preserved: Phases 1A/1B/1C, the `plans/<feature>/` doc set (00-ambiguity-register …
  99-execution-plan), the hard Zero-Ambiguity Gate, the Master Progress Checklist mandate, and the
  `> **Implements**: RD-NN` linkage used by the roadmap skill.

### skills/exec_plan (execution only)
- Files: `SKILL.md`, `execution-protocol.md`, `commit-modes.md`.
- Commit modes mapped to commands: `--ask-commit` (ask after each verified task), `--auto-commit`
  (uses `/gitcmp`), `--no-commit`. "Context limit mid-task" reframed as generic "session interrupted
  mid-task" recovery. Post-completion hooks point to the techdocs skill, `/analyze_project`, and the
  roadmap skill. Version check compares against `2.0.0` and points to the upgrade_plan skill.

### skills/make_requirements (make / add / review)
- Files: `SKILL.md`, `discovery-phases.md`, `zero-ambiguity-gate.md`, `templates.md`,
  `review-and-add.md`. Added a Step-0 mode-detection table.
- Preserved: proactive-domain-consultant principle, Phases 1/2/2B/3/4, the hard Zero-Ambiguity Gate
  + ambiguity register + AR back-references, mandatory non-functional RD, acceptance-criteria
  specificity, the "Did You Consider…" checklist, and the `requirements/` layout.

### skills/retro_requirements
- Files: `SKILL.md`, `phases.md`, `triage-gate.md`, `confidence-classification.md`.
- Normalization: standardized the brief filename to `09-reconstruction-brief.md` everywhere
  (source used both `reconstruction-brief.md` and `09-…`).
- Preserved: all 9 phases, ✅/⚠️/🔴 confidence classification, the hard Phase 8B Bug-or-Feature
  Triage Gate (A/B/C decisions), `requirements/_retro/` layout, `--scope`/`--continue`,
  WHAT-not-HOW extraction.

### skills/grill_me
- Single `SKILL.md` (fit cleanly). Preserved: the 4-step protocol, the 7 behavior rules, standalone
  mode, and the note that the downstream make_plan Phase 1C / make_requirements Phase 2B gates
  **still fire** with grill_me output as pre-resolved context.

### skills/preflight
- Files: `SKILL.md`, `dimensions.md` (13 dimensions incl. Dimension 13's 10 sub-checks),
  `report-format.md` (PF-NNN findings, persistence, batch rules, same-agent-bias). Severity icons
  (🔴🟠🟡🔵) kept in SKILL.md.
- Preserved: adversarial core directive, the non-negotiable Codebase Reconnaissance step,
  iterative re-scan numbering, the report at `…/00-preflight-report.md`.

### skills/techdocs (make / review + auto-update hook)
- Files: `SKILL.md`, `templates.md` (all VitePress files + ADR template), `vitepress-setup.md`,
  `authoring-and-update.md` (incl. the Design Intent Preservation rule + 7-dimension health check).
- Preserved: the `docs/index.md` `techdocs: true` opt-in marker, ask-once-then-auto-update, the
  technical-vs-product scope split, the full VitePress layout. ASCII opt-in flowchart replaced with
  a compact numbered decision.

### skills/roadmap (make / update / review / archive)
- Files: `SKILL.md`, `template.md`, `stage-hooks.md`. The agents.md "roadmap is source of truth"
  rule is now stated directly in the skill; "blocks attempt_completion" → "before ending a
  session/task".
- Preserved: the 9-state lifecycle, stage-transition map, `plans/00-roadmap.md` template,
  Blocked/Deferred (DEF-n) handling, ask-if-missing / sync-if-exists, deterministic
  `> **Implements**: RD-NN` linking, and the `archive_roadmap` procedure.

### skills/upgrade_plan (plan / requirements)
- Files: `SKILL.md`, `content-quality-gate.md` (Phase 2B), `upgrade-checklists.md` (Phase 3).
- Key change: staleness is detected by comparing the artifact's stamp against `2.0.0` (no stamp =
  pre-versioning/outdated); post-upgrade stamp is `> **CodeOps Skills Version**: 2.0.0`.
- Preserved: 4 phases, the upgrade-report-before-changes choice, the hard Content Quality Gate
  (12 categories, vague-language flags, register `(upgrade)` tag, 5 gate-open conditions), the
  Content Preservation Rules, Phase 4 verification, and "does NOT auto-advance the roadmap".

### commands/gitcm.md & commands/gitcmp.md
- Deterministic git flows as flat command files, `disable-model-invocation: true` (manual only —
  they have side effects) with `allowed-tools` pre-approving the git operations.
- Kept the file-based commit message (`git commit -F`, never `-m`), the Conventional Commit format,
  scope guidance, the STOP-and-ask Conflict Protocol, and Push Failure Recovery. Dropped the
  `clear && sleep 3 &&` prefix and the "new Cline task" advice. The hard "all commits must go
  through gitcm" mandate is now an offered convenience, not a global rule.

### commands/analyze_project.md
- Reimplements the old MCP `analyze_project` tool as a command that scans manifests/structure and
  writes a **project-level `CLAUDE.md`** (instead of `.clinerules/project.md`). Keeps the
  non-destructive merge behavior: auto-detectable sections refreshed, user-authored sections
  (Conventions, Git conventions, Special rules) preserved verbatim. The old "MANDATORY load rules"
  preamble is gone.

### CLAUDE.md.snippet
- A distilled, always-on merge of `code.md` (35 standards), `testing.md` essentials (incl. the
  spec-vs-impl test separation), and the universal working-style bits of `agents.md`. Kept lean for
  global `~/.claude/CLAUDE.md`. The detailed spec-first red/green protocol is enforced operationally
  by the make_plan/exec_plan skills; the snippet states the principle.

---

## 5. Post-migration additions

These are new to `claude-codeops` — they had no `codeops-mcp` predecessor.

### skills/setup_routing (+ commands/setup_routing.md alias)
- **New skill** — configures per-project model & effort routing so Opus + high/xhigh thinking is
  spent only where it changes output quality and high-volume mechanical work runs on Sonnet.
  Files: `SKILL.md`, `templates.md`. Exposed as `/codeops:setup_routing` plus the typeable alias
  `/setup_routing` (`commands/setup_routing.md`, manual-only).
- **Two-layer design.** A sentinel-delimited (`<!-- CODEOPS-ROUTING -->`) block in the project
  `CLAUDE.md` is the soft *policy* (which executor a tagged task is delegated to); pinned-model
  executor subagents in `.claude/agents/` (`plan-task-executor` → Sonnet, `plan-task-executor-opus`
  → Opus) are the hard *enforcement*. The skill writes executors first and never references one that
  does not exist.
- **Tag-driven routing** over a fixed vocabulary (`trivial`/`standard`/`complex`/`sensitive`) across
  four sensitivity profiles (Opus-dominant, Mixed core/scaffold, Sonnet-default, Balanced fallback).
  Reuses the `analyze_project` non-destructive merge discipline, tightened with explicit sentinels
  for idempotency. Operates only on the current project — never on global user files. Hard
  confirmation gate before any write.
- Count bumped at the time to ten skills + fourteen slash commands (eleven + fifteen as of 3.0.0) across README, project `CLAUDE.md`, and the docs
  site; new skill page `docs/skills/setup_routing.md` added to the sidebar and the `docs-check.sh`
  spec suite.
