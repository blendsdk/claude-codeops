# setup_routing

> Configure per-project model & effort routing — spend Opus where it changes output quality, run
> mechanical work on Sonnet.

## What it does

`setup_routing` independently analyzes the current repository, classifies it into a **sensitivity
profile**, and proposes a **tag-driven routing policy** — then, only after you confirm, writes two
coordinated artifacts:

1. a concise (**≤10-line**), sentinel-delimited routing block in the project's `CLAUDE.md` (the **policy** layer —
   which executor a tagged task is delegated to), and
2. the pinned-model **executor subagents** in `.claude/agents/` that the policy references (the
   **enforcement** layer — `plan-task-executor` on Sonnet, `plan-task-executor-opus` on Opus).

The policy is only trustworthy because the pinned executors exist to back it, so the skill writes
the executors first and never references one that does not exist. It is non-destructive and
idempotent: re-running updates the managed block in place and creates executors only if absent.

## When to use it

- You want a project to reserve Opus + high/xhigh thinking for the work that needs it and let
  Sonnet handle high-volume mechanical tasks.
- You are setting up a compiler/DSL/web project and want routing wired into `make_plan` /
  `exec_plan` for that repo.
- **Not** for global configuration — it only ever touches the **current project's** `CLAUDE.md` and
  `.claude/agents/`, never `~/.claude/`.

## Trigger phrases

"setup_routing", "set up model routing", "configure model routing", "route tasks by model/cost",
"make this project use Opus/Sonnet per task". Explicit: `/codeops:setup_routing <description>` or
the alias `/setup_routing`.

## Sensitivity profiles

| Profile | Fits | Default tag → model |
|---|---|---|
| **A — Opus-dominant** | compilers, interpreters, type systems, codegen | untagged → `complex` (Opus); only mechanical work de-escalates to Sonnet |
| **B — Mixed core/scaffold** | DSL/query languages that lower to a target (e.g. SQL) | lowering/semantics → `sensitive` (Opus); scaffolding → Sonnet |
| **C — Sonnet-default** | React/Vue/Node, REST/GraphQL, CRUD | untagged → `standard` (Sonnet); escalate only security/concurrency/perf |
| **Balanced (fallback)** | ambiguous detection | Sonnet default, Opus on `complex`/`sensitive` — flagged as a fallback to correct |

Routing is expressed over a fixed tag vocabulary — `trivial` · `standard` · `complex` ·
`sensitive` — with the constant rule `trivial`/`standard` → Sonnet, `complex`/`sensitive` → Opus.
Each profile only sets the default tag and what it escalates or de-escalates.

## Worked example

```text
/codeops:setup_routing a Rust compiler with a parser, IR, and codegen backend
```

The skill reads the repo, sees `parser/`, `ir/`, and `codegen.rs`, classifies it **Opus-dominant**,
and presents the routing block plus the two executors to be created. After you confirm, it writes
the `<!-- CODEOPS-ROUTING -->` block into `CLAUDE.md` and `plan-task-executor{,-opus}.md` into
`.claude/agents/`, then tells you to run `/agents` to verify and to watch your rework rate before
trusting Sonnet on borderline tasks.

## Related skills

- [`make_plan`](/skills/make_plan) — the routing block asks it to tag each generated task.
- [`exec_plan`](/skills/exec_plan) — consumes the routing block, delegating tasks to executors by tag.
- [`preflight`](/skills/preflight) — always Opus under every profile.
- See the [Commands page](/skills/commands) for the `/setup_routing` alias.
