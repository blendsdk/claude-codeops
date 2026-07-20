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

## Reading the data

- **`/codeops_stats`** — relays the utility's pre-aggregated tables: event counts, per-agent
  runs and acceptance rates, durations, emission gaps. Flags: `--since <Nd>`, `--project <p>`,
  `--by agent|lens|project|event`, and `gaps`.
- **`/codeops_retro`** — the periodic retrospective (monthly, or roughly every 10 phases). It
  applies the thresholds — per-agent acceptance below 40% (with at least 10 rulings), a gap
  rate above 20%, a blocker category repeating three times, a lens with zero accepted findings
  over ten phases — and sorts what triggers into **plugin-bucket** verdicts (tune the plugin's
  agents) versus **profile-bucket** verdicts (tune this repo's quality block). It recommends;
  you apply.

Neither command reads the raw events file into context — the utility aggregates, the commands
relay.
