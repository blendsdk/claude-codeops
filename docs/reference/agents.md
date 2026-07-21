# Agents

The plugin ships nine subagents in its `agents/` directory: two plan-task executors (used by
model routing) and, since 3.10.0, seven quality agents that power the profile-gated quality
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
| `codebase-scout` | sonnet / low | read-only | Facts with `file:line` only; honest "not found"; capped at 3 per skill run |

## Packet contracts

Every quality dispatch carries a machine-readable header on line 1 —
`[codeops-dispatch agent=<name> feature=<slug> phase=<id>]` — plus a self-contained packet: the
reviewers/auditors get the phase diff, task lines, active lenses, and verify context; the
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
