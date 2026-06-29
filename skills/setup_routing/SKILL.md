---
name: setup_routing
description: >-
  Configures per-project model and effort routing so Opus + high/xhigh thinking is spent only where it changes output quality and high-volume mechanical work runs on Sonnet. Use when the user says "setup_routing", "/setup_routing", "set up model routing", "configure model routing", "route tasks by model", or "make this project use Opus/Sonnet per task". Independently analyzes the repo, classifies it into a sensitivity profile (Opus-dominant, Mixed core/scaffold, Sonnet-default, or a Balanced fallback), proposes a tag-driven routing policy, waits for explicit confirmation, then writes a sentinel-delimited routing block into the project CLAUDE.md and the pinned-model executor subagents in .claude/agents/ that the policy references.
when_to_use: >-
  Trigger on "setup_routing", "/setup_routing", "set up / configure model routing", "route tasks by model / cost", or any request to make a project spend Opus only where it matters and Sonnet elsewhere. Operates on the CURRENT project's CLAUDE.md and .claude/agents/ — never on global user files. Re-runnable and non-destructive.
argument-hint: "[short description of the project]"
---

# Model & Effort Routing Setup (`setup_routing`)

> **CodeOps Skills Version**: 3.0.0

Configure **per-project model and effort routing** for the project the user is currently in, so
that expensive reasoning (Opus, high/xhigh thinking) is spent only where it changes output
quality, and high-volume mechanical work runs on Sonnet. Invoked as `/codeops:setup_routing` or
the typeable alias `/setup_routing`.

## The two-layer principle (preserve this throughout)

Routing has **two layers**, and they must stay coordinated:

1. **Policy layer (soft, behavioral).** A block in the project's `CLAUDE.md` decides *which
   executor* a task is delegated to, expressed as a rule over task tags.
2. **Enforcement layer (hard, guaranteed).** Each executor subagent's frontmatter pins both
   `model:` (which model runs) and `effort:` (which reasoning effort runs) when that executor is
   invoked. Claude Code enforces both, overriding the user's session/`settings.json`/env config —
   so routing works *regardless of what the user has already configured*. The sole exception is the
   `CLAUDE_CODE_SUBAGENT_MODEL` env var, which sits above subagent frontmatter and forces every
   subagent onto one model (a deliberate global cost-cap escape hatch — surface it in Phase 5).

> The policy is only trustworthy because the pinned executors exist to back it. **Never generate
> routing prose that references an executor subagent that does not exist.** Phase 4 writes the
> executors and the policy together, executors first.

> The policy layer is a *behavioral instruction to the orchestrator*, not a hard guarantee. The
> `exec_plan` skill executes tasks inline today; the routing block asks it to delegate by tag.
> This is the one thing the user must validate in the real world (see Phase 5).

## Project configuration

For build/test/verify commands, package manager, structure, and conventions, read **the project's
CLAUDE.md** (or detect from manifests if none). This skill *adds to* that CLAUDE.md; it never
rewrites the user's own sections. It reuses the non-destructive merge discipline of
`analyze_project`, tightened with explicit sentinels for idempotency.

## Hard rules

- **Independent analysis, not blind trust.** Classify the project from the *repository*, using the
  user's description only as a hint. State the evidence behind the classification.
- **Hard confirmation gate.** Never write anything until the user explicitly approves (Phase 3).
- **Non-destructive & idempotent.** Re-running must be safe: update the sentinel block in place,
  never duplicate it; create executors only if absent; never overwrite a user's existing file.
- **Operate on the current project only.** Touch the project's `CLAUDE.md` and `.claude/agents/`.
  **Never edit `~/.claude/CLAUDE.md` or any global user file.**
- **Concise generated output.** The routing block is injected into every session; keep it tight.
- **Grounded options & recommendations.** When you present the profile, the proposal, or any
  adjustment choice, follow the always-on Grounded Options directive in the coding standards:
  present only viable options, second-guess each, ground claims in the real repo, and lead with a
  recommendation and its reason. You recommend; the user decides.

---

## Sensitivity profiles

Detect the project type and map it to a profile. The set is extensible — add profiles by giving
each a trigger set, detection hints, and a default-tag + escalation rule.

### Profile A — "Opus-dominant" (high reasoning sensitivity)
- **Triggers:** compiler, interpreter, programming-language implementation, type system, semantic
  analysis, code generation, optimizer, formal verification, or similar.
- **Detection hints:** `lexer`/`parser`/`ast`/`ir`/`codegen` directories or files; grammar files
  (`.g4`, `.pest`, custom); heavy use of a systems language; a description mentioning "compiler",
  "language", "type checker", "IR", "codegen".
- **Default tag:** untagged → `complex` (Opus). **De-escalate** only explicitly mechanical tasks
  (lexer tables, AST-node boilerplate, test fixtures, mechanical refactors) → `trivial` (Sonnet).
- `preflight` always Opus.

### Profile B — "Mixed core/scaffold" (split sensitivity)
- **Triggers:** a DSL or query language that lowers/compiles to another target (e.g. SQL); ORMs
  with non-trivial query generation; any *semantic translation core* surrounded by *mechanical
  scaffolding*.
- **Detection hints:** description mentioning "DSL", "lowering", "transpile", "query builder",
  "compiles to SQL"; a translation/lowering layer plus a parser/CLI surface.
- **Default tag:** untagged → `standard`, but **all lowering/translation tasks and anything
  touching target-language semantics → `sensitive` (Opus).** Frontend plumbing, error formatting,
  CLI wiring, scaffolding, fixtures → `trivial`/`standard` (Sonnet).
- `preflight` always Opus, with explicit emphasis on **semantic-correctness review** — silent
  wrong-output is the failure mode.

### Profile C — "Sonnet-default" (low reasoning sensitivity)
- **Triggers:** conventional web/app development — React, Vue, Node, REST/GraphQL APIs, CRUD,
  standard backend services.
- **Detection hints:** `package.json` with react/next/express/fastify/nest; component directories;
  typical web-app layout.
- **Default tag:** untagged → `standard` (Sonnet). **Escalate** only tasks tagged
  security-sensitive, concurrency-sensitive, or performance-critical → `sensitive` (Opus).

### Fallback — "Balanced"
If detection is ambiguous, use a balanced profile: untagged → `standard` (Sonnet), escalate
`complex`/`sensitive` → Opus. **Tell the user this was a fallback** and invite them to correct the
classification before confirming.

## Task-tag vocabulary

Routing is **tag-driven**, not a blanket per-project switch (Profiles A and B are internally
mixed). The vocabulary is fixed: `trivial`, `standard`, `complex`, `sensitive`. Each profile sets
only the **default tag** for untagged tasks and the **escalation/de-escalation** it applies. The
routing rule is constant: `trivial`/`standard` → Sonnet executor; `complex`/`sensitive` → Opus
executor.

The generated routing block also instructs `make_plan`/`exec_plan` (within this project) to **tag
each task** with one of these levels, so routing becomes a mechanical rule rather than a per-task
judgment call. This is written into the project CLAUDE.md routing block — the skill does **not**
modify the global `make_plan` skill.

---

## The interaction flow

### Phase 1 — Analyze (read-only)
Read the repo: manifests (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `Makefile`,
build files), directory structure, key files, grammar/IR/codegen markers, framework signals, and
any existing `CLAUDE.md`. Combine the evidence with the user's one-line description.

### Phase 2 — Classify & propose
Pick a profile and **state the evidence** ("I see `parser/`, `ir/`, and `codegen.rs` — classifying
as Opus-dominant"). Then present, in full and exactly as they will be written:
- the chosen profile and its default tag + escalation rule;
- the complete routing block (from [templates.md](templates.md), filled in);
- the list of executor subagents to create, with their target paths under `.claude/agents/`.

### Phase 3 — Confirmation gate (HARD STOP)
Ask the user to **confirm**, **adjust** (override the profile or individual tag mappings), or
**cancel**. Do not write anything until explicit approval. Honor adjustments before writing.

### Phase 4 — Write
Apply the writes from [templates.md](templates.md):
1. **Executors first.** For each executor, create it under `.claude/agents/` only if absent. On a
   name collision, **report and skip**, or offer a suffixed name — never overwrite a user's file.
2. **Routing block.** Apply the sentinel merge to the project `CLAUDE.md` (replace between markers /
   append / refuse-on-corruption — see templates.md).
Never touch content outside the managed block or pre-existing executor files.

### Phase 5 — Verify & report
Summarize exactly what was written and where. Tell the user how to confirm:
- run `/agents` to see the executors;
- inspect the `<!-- CODEOPS-ROUTING -->` block in `CLAUDE.md`;
- (recommended) run one `exec_plan` task and confirm the Sonnet executor is actually selected.

**Flag the real-world validation explicitly:** whether their Claude Code version honors
delegation-by-name reliably, and that they should watch their **rework rate** for a week before
trusting Sonnet on borderline tasks. Also confirm the generated `model:`/`effort:` shorthand is
valid for their installed Claude Code version (see templates.md). Note that the pinned `model:` and
`effort:` win over any model/effort they already set in `settings.json` or env — **except** if they
have set `CLAUDE_CODE_SUBAGENT_MODEL`, which overrides every subagent's pinned model.

---

## Related skills

- **exec_plan skill** — consumes the routing block: delegates each tagged task to the executor the
  policy names. Today it executes inline, so delegation is behavioral — the soft-spot to validate.
- **make_plan skill** — the routing block asks it to tag each generated task `trivial`/`standard`/
  `complex`/`sensitive` within this project.
- **preflight skill** — always Opus under every profile (and semantic-correctness-focused under B).
- **analyze_project command** — the non-destructive CLAUDE.md merge discipline this skill reuses.
- For coding, testing, and git standards, follow **your project's CLAUDE.md** and use **/gitcm** /
  **/gitcmp** for commits.
