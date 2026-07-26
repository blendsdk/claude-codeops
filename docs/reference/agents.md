# Agents

The plugin ships twelve subagents in its `agents/` directory: two plan-task executors (used by
model routing) and, since 3.10.0, ten quality agents that power the profile-gated quality
loop. All are dispatched by the skills — you never invoke them directly.

## Roster

| Agent | Model / effort | Tools | Role |
|-------|---------------|-------|------|
| `plan-task-executor` | sonnet / medium | read + write + bash | Executes one dispatched trivial/standard unit from an execution plan |
| `plan-task-executor-opus` | opus / high | read + write + bash | Executes one dispatched complex/sensitive unit |
| `phase-reviewer` | opus / high | read-only + bash | Reviews one phase diff through the base + add-on lenses; RV findings |
| `spec-test-author` | fable / high | read + write + bash | Writes spec tests implementation-blind from the packet; confirms the red phase |
| `security-auditor` | fable / high | read-only + bash | One dispatch per phase with the union of active security checklists; SA findings |
| `preflight-auditor` | opus / high | read-only + bash | Audits one artifact against one preflight dimension cluster; PA findings |
| `design-challenger` | fable / high | read-only, no bash | Independent second opinion on a decision, blind to the dispatcher's pick |
| `perf-auditor` | opus / high | read-only + bash | Hot paths, allocations, complexity, N+1s, blocking I/O; PE findings |
| `concurrency-auditor` | inherit / high | read-only + bash | Races, deadlocks, lost updates, unsafe retry; each finding carries an interleaving; CA findings |
| `financial-integrity-auditor` | inherit / high | read-only + bash | Idempotency, precision, atomicity, audit trails on money movement; FA findings |
| `semantics-reviewer` | inherit / high | read-only + bash | Formal semantics across parsing, typing, lowering, diagnostics, compatibility; SR findings |
| `codebase-scout` | sonnet / low | read-only | Facts with `file:line` only; honest "not found"; capped at 3 per skill run |

The three specialists inherit the session model rather than pinning a tier, so they run at
whatever you are already running at. Raise or lower them per repo through `agent_models` like any
other agent.

## Supersession

A dedicated auditor **supersedes** the matching dimension in a shared reviewer for that phase, so
the same ground is never covered twice at two different depths:

| When this dispatches | It supersedes | In |
|----------------------|---------------|----|
| `security-auditor` | the `security` lens | `phase-reviewer` |
| `perf-auditor` | the `perf` lens | `phase-reviewer` |
| `concurrency-auditor` | the `concurrency` lens | `phase-reviewer` |
| `financial-integrity-auditor` | the `financial-integrity` checklist | `security-auditor`, which still runs for its other checklists |
| `semantics-reviewer` | *(nothing — no shared reviewer covers formal semantics)* | — |

Supersession is written into both prompts, not just the profile: the specialist claims the ground
and the shared reviewer is told to stand down. Each dispatch packet names the dimensions withdrawn
for that phase, and a reviewer that skipped one says so in its report — a dropped dimension has to
be visible, never assumed.

## Activation

| Agent | Activates on |
|-------|--------------|
| `security-auditor` | `security_profile` is non-empty |
| `perf-auditor` | `perf_critical: true` and the diff touches code |
| `concurrency-auditor` | `lenses` contains `concurrency` and the diff touches code |
| `financial-integrity-auditor` | `security_profile` contains `financial-integrity` |
| `semantics-reviewer` | `compiler-and-language` is among the selected domains and the diff touches code |

The semantics reviewer is the one agent keyed on a **domain** rather than a profile field, because
`compiler-and-language` already means "this system has formal transformation semantics". Domains
are classified for every repo, but this dispatch still requires a quality profile — as every agent
does. See [Domains](/guide/domains).

## Packet contracts

Every quality dispatch carries a machine-readable header on line 1 —
`[codeops-dispatch agent=<name> feature=<slug> phase=<id>]` — plus a self-contained packet: the
reviewers/auditors get the phase [worktree snapshot](/reference/worktree-snapshot), task lines,
active lenses, and verify context; the
spec-test-author gets spec excerpts, planned interfaces, and a FORBIDDEN implementation-file
list it must never open; the challenger gets the problem and options without the dispatcher's
preference. The canonical packet definitions live in the plugin's `_shared/quality-profile.md`.

For telemetry, the agent is identified from the dispatch tool's own `subagent_type`, not from that
header — so a run is attributed even on the dispatch paths that do not carry one. A dispatch counts
as CodeOps when its `subagent_type` is `codeops:<name>` or a bare `<name>` matching an agent the
plugin ships, which also attributes project-local overrides in `.claude/agents/`. Ordinary agent
use (`Explore`, `general-purpose`, your own agents) is recorded without an agent name, so it never
appears in per-agent statistics. The header remains the only source of `feature` and `phase`, and
is still read as a fallback when `subagent_type` is absent.

All finding-producing agents are read-only — they never edit, fix, or commit — and report
"no findings" explicitly rather than returning empty output.

## Model fallback

A pinned model that is unavailable on your account (for example, absent from an organization's
model allowlist) **silently falls back to the session model**. There is no error and no warning
— if review quality seems off on a restricted account, check this first. The same is true of an
effort level the model does not offer.

## Customizing an agent for one repo

Per-repo model **and** effort overrides go through the quality profile's `agent_models` map (see
[Quality profile](/guide/quality-profile#per-repo-model-and-effort-overrides)) — for example
`{phase-reviewer: {effort: xhigh}}`.

**Do not copy an agent file into `.claude/agents/` to change its model or effort.** A copy
shadows the plugin's agent permanently and freezes its prompt at the release you copied from, so
every later improvement silently passes the repo by. Overrides carrying an effort are generated
and version-stamped for you by `"${CLAUDE_PLUGIN_ROOT}/scripts/codeops-agents-sync.sh"`, which `/setup_routing` runs;
`--check` afterwards tells you whether anything has gone stale.

Copying an agent file is still the right move when you want a genuinely different **prompt**. Such
a file carries no `CODEOPS-GENERATED` marker, and the sync engine leaves it alone permanently.
