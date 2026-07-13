# Skills

CodeOps ships **11 skills**. Each is a multi-step protocol Claude runs on request — they auto-trigger
from natural language and can also be invoked explicitly as `/codeops:<name>`.

| Skill | What it does |
|---|---|
| [make_plan](/skills/make_plan) | Clarifying interview → Zero-Ambiguity Gate → `plans/<feature>/` document set |
| [exec_plan](/skills/exec_plan) | Implements a plan task-by-task, verifying and committing per mode |
| [make_requirements](/skills/make_requirements) | Requirements discovery / add one RD / health-check |
| [retro_requirements](/skills/retro_requirements) | Reverse-engineer a codebase into a reconstruction brief |
| [grill_me](/skills/grill_me) | Relentless design-disambiguation interview |
| [preflight](/skills/preflight) | Adversarial, codebase-grounded quality audit |
| [techdocs](/skills/techdocs) | Create/maintain VitePress architecture docs + ADRs |
| [roadmap](/skills/roadmap) | Track a whole feature-set across its lifecycle |
| [upgrade_plan](/skills/upgrade_plan) | Bring an outdated plan/requirements set to current standards |
| [setup_routing](/skills/setup_routing) | Wire per-project model & effort routing (Opus/Sonnet by task tag) into `CLAUDE.md` + `.claude/agents/` |
| [setup_codeops](/skills/setup_codeops) | Scaffold or auto-migrate a repo into the nested `codeops/` layout (one confirmation, `git mv`) |

See also the [Commands page](/skills/commands) for the 16 slash commands.

## How they compose

```
grill_me → make_requirements → preflight → make_plan → preflight → exec_plan
```

with [`roadmap`](/skills/roadmap) tracking the whole feature-set and [`techdocs`](/skills/techdocs)
keeping architecture docs current. The [tutorials](/tutorials/) walk these pipelines end to end.

## Skill vs. alias commands

The consolidated skills cover several verbs each, and thin **alias commands** make each verb directly
typeable (they delegate to the parent skill in the right mode) — e.g. `/add_requirement`,
`/review_requirements` → `make_requirements`. Aliases are manual-only; only the parent skills
auto-trigger from natural language. See [Commands](/skills/commands).
