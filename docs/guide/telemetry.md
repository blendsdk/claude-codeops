# Telemetry

CodeOps 3.10.0 adds local, metadata-only workflow telemetry so the quality loop can be judged
on evidence instead of vibes: which agents' findings get accepted, where reviews run without
rulings, how long dispatches take.

## The metadata-only pledge

**No content is ever collected.** Events carry enums, counts, ids, and durations — never code,
never prose, never finding text. Free text that needs correlating (a finding's description) is
reduced to the first 8 hex characters of its SHA-256 before storage; the text itself is
discarded. The write path enforces this strictly: an event with an unknown type, key, or value
is refused whole-line.

Everything stays **on your machine**: events append to
`~/.claude/codeops-telemetry/events.jsonl`, one JSON object per line. Nothing is uploaded,
ever. The `scripts/codeops-events.sh` utility is the file's only reader and writer.

## How events flow

- A **PostToolUse hook** records skill invocations and quality-agent completions
  automatically (deterministic, no model involvement). Which agent ran is read from the dispatch
  tool's own `subagent_type`, so every agent is attributed regardless of the path that dispatched
  it — including project-local overrides in `.claude/agents/`. Agent use that is not part of
  CodeOps is still recorded, but without an agent name, so it never skews per-agent statistics.
- The **skills emit** workflow events — phases, task completions, review findings and rulings,
  gate summaries — but only in repos whose quality profile is active. A repo without a profile
  block emits nothing from the skills.

## Kill switches

Any one of these silences telemetry completely (always exiting 0 — telemetry can never block
work):

1. `CODEOPS_TELEMETRY=0` in the environment (global),
2. `telemetry: off` in the repo's quality block (per-repo — see
   [Quality profile](/guide/quality-profile)),
3. `jq` not installed (the utility no-ops with a single note).

## The measure taxonomy (3.18.0)

The first two years of events answered "are the review agents earning their keep". They could not
answer "did the workflow do what it planned, and what did it discover too late". 3.18.0 adds four
event types and two fields for that, each one tied to a question `/codeops_retro` can act on — a
measure that cannot change a decision is not collected.

**Every measure field below is content-free** — an integer, a boolean, or a closed enumeration.
None of these events accepts free text, and none of them opens the hashing channel: asking one to
hash a string refuses the whole line. The pledge above did not get an exception for being useful.

The one thing these events carry beyond their measures is the `feature` / `phase` pair that every
CodeOps event has carried since telemetry existed — the correlation keys that let a review be tied
to the phase it reviewed. They are your own slugs, they are not new here, and they are the reason
`gaps` can tell a completed review from an unruled one at all.

| Event | Records | Emitted when |
|-------|---------|--------------|
| `spec_test_cycle` | how many spec tests were authored, how many were confirmed red, and how many still failed after implementation | once per phase, at the post-phase quality step |
| `runtime_ambiguity` | the stage that should have caught it (`requirements` / `plan` / `spec_tests` / `execution`) and what kind of gap it was | when execution records a runtime entry in the ambiguity register |
| `session_resumed` | where the resume scan landed, and whether the plan's marks had to be corrected to match reality | when a load picks up a plan already in progress |
| `design_delegated` | the eligible class, whether it resolved or escalated and why, the confidence, and whether a blind challenger ran | once per delegated design resolution or escalation |

Plus `tasks_planned` on `phase_started` (the planned side of planned-vs-verified, which previously
existed nowhere) and `round` on `review_run` (so a re-review after a fix is distinguishable from
the initial pass).

`/codeops_stats --by delivery|drift|design` aggregates them.

### What is deliberately **dropped**

Two of the nine measures this taxonomy was designed against are not collected, and that is the
finished outcome rather than work left over:

- **Findings that escaped review entirely.** Attributing a defect nobody reported back to the
  phase that introduced it requires a description of the defect, and a description is content.
  There is no enumerated proxy — severity and lens are only knowable once somebody has written
  down what the thing *is*. Approximating it with a nearby count would quietly relabel a different
  population as this one, which is worse than a blank.
- **Unplanned files or scope changes.** This one is not a privacy limit: `files_changed` already
  counts files, but "unplanned" needs identity, and CodeOps plans do not carry a per-task declared
  file list to compare against. The measure becomes available the day they do, without touching
  the pledge above.

Where a measure would need content to compute, it is dropped rather than approximated. That rule
wins every conflict, and it is the reason the pledge at the top of this page is worth anything.

## Reading the data

- **`/codeops_stats`** — relays the utility's pre-aggregated tables: event counts, per-agent
  runs and acceptance rates, durations, emission gaps. Flags: `--since <Nd>`, `--project <p>`,
  `--by agent|lens|project|event|delivery|drift|design`, and `gaps`.
- **`/codeops_retro`** — the periodic retrospective (monthly, or roughly every 10 phases). It
  applies the thresholds — per-agent acceptance below 40% (with at least 10 rulings), a gap
  rate above 20%, a blocker category repeating three times, a lens with zero accepted findings
  over ten phases, plus the taxonomy thresholds above — and sorts what triggers into
  **plugin-bucket** verdicts (tune the plugin's agents) versus **profile-bucket** verdicts (tune
  this repo's quality block). It recommends; you apply.

Neither command reads the raw events file into context — the utility aggregates, the commands
relay.

## Older event files keep working

Every addition is additive: no existing event, key, or value has been renamed, removed, or
repurposed, and the readers treat an absent key as absent rather than as an error. An
`events.jsonl` written by an earlier CodeOps parses and aggregates unchanged — the new measures
simply read as zero for the period before they existed.
