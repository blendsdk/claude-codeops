---
description: >
  Show CodeOps quality telemetry — event counts, per-agent runs and acceptance rates,
  durations, emission gaps — by running the plugin's codeops-events.sh utility and relaying
  its pre-aggregated table verbatim. Use for "codeops_stats", "codeops stats", "show quality
  telemetry", "review acceptance rates", "telemetry gaps". Read-only; the raw events file is
  never read into context.
argument-hint: "[--since <Nd>] [--project <p>] [--by agent|lens|project|event] [gaps]"
---

# codeops_stats — relay the telemetry tables

The utility at `"${CLAUDE_PLUGIN_ROOT}/scripts/codeops-events.sh"` is the ONLY reader of the
telemetry file (`~/.claude/codeops-telemetry/events.jsonl`). This command runs it and relays
its output **verbatim** — never open, grep, or summarize `events.jsonl` yourself; the utility
pre-aggregates to a table of at most ~40 lines precisely so raw events stay out of context.

## Mapping the ask to an invocation

| User asks for | Run |
|---------------|-----|
| overall picture (default) | `codeops-events.sh stats` |
| per-agent rates | `codeops-events.sh stats --by agent` |
| per-lens rates | `codeops-events.sh stats --by lens` |
| per-project / per-event counts | `codeops-events.sh stats --by project` / `--by event` |
| a time window ("last 2 weeks") | add `--since 14d` |
| one project only | add `--project <name>` |
| emission gaps ("reviews without rulings") | `codeops-events.sh gaps [--since <Nd>]` |

Pass `$ARGUMENTS` through when the user already typed flags.

## Relay rules

- Print the utility's table as-is (a fenced code block keeps the alignment). Add at most a
  one-line reading of what stands out — no re-derivation, no editorializing beyond the numbers.
- `no events recorded` → explain the likely causes: telemetry off (`CODEOPS_TELEMETRY=0`, or
  `telemetry: off` in the repo's quality block), `jq` missing, or simply nothing has run yet.
- For threshold judgments ("is this acceptance rate bad?") point to `/codeops_retro` — that
  command owns the thresholds; this one only reports.
