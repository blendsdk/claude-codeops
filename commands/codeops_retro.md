---
description: >
  Run a CodeOps quality retrospective — aggregate the telemetry via codeops-events.sh
  stats/gaps, apply the retro thresholds, and sort what triggers into plugin-bucket (tune the
  plugin's agents/prompts) vs profile-bucket (tune this repo's quality profile) verdicts.
  Terminal-only report; recommends actions, never applies them. Use for "codeops_retro",
  "quality retro", "review the review loop", "are the quality agents earning their keep".
argument-hint: "[--since <Nd>]"
---

# codeops_retro — the quality loop's own review

Judge whether the quality agents are earning their keep, from the telemetry alone. Cadence:
monthly OR roughly every 10 executed phases, whichever comes first — plus one focused retro
shortly after each release. This command is **terminal-only** (no file output) and
**recommend-only**: it proposes changes, and the user applies them.

## Step 1 — Gather

Run the utility at `"${CLAUDE_PLUGIN_ROOT}/scripts/codeops-events.sh"` (the sole reader of the
events file — never open `events.jsonl` yourself):

1. `stats --since <Nd>` (default `30d`, or the user's window)
2. `stats --since <Nd> --by agent`
3. `stats --since <Nd> --by lens`
4. `gaps --since <Nd>`

Relay each table verbatim, then analyze.

## Step 2 — Apply the thresholds (this table is the owning copy)

| Signal | Trigger | Reading |
|--------|---------|---------|
| Per-agent acceptance rate | **< 40%** with **n ≥ 10** rulings | The agent's findings are mostly rejected — its prompt, checklists, or severity calibration need tuning |
| Emission gap rate | **> 20%** | Reviews complete without recorded rulings — the dispatch wiring or ruling discipline is leaking |
| Blocker category | same category **≥ 3×** in the window | A systemic weakness in packets or plans, not bad luck |
| Lens acceptance | a lens with **0 accepted** findings over **n ≥ 10** phases | The lens adds noise, not value — candidate to drop from the profile |
| gate_summary trends | *display-only* | Context only — no gate-friction threshold yet (deliberately deferred until about a quarter of gate data exists) |

Below-n signals are reported as "insufficient data", never judged.

## Step 3 — Two-bucket verdicts

Sort every triggered signal into exactly one bucket:

- **Plugin bucket** — the fix belongs in the plugin (agent prompts, checklists, packet
  contracts): signals that trigger **across repos**, systemic blocker categories,
  spec-author red-phase failures.
- **Profile bucket** — the fix belongs in **this repo's** quality block (drop a lens, adjust
  security profiles, unset `perf_critical`, override a model): signals that trigger in this
  repo only.

The discriminator is scope: one repo → profile bucket; everywhere → plugin bucket. When the
data cannot distinguish, say so and name what additional window or repos would settle it.

## Step 4 — Recommend

Present the verdicts with concrete recommended edits (which file, which key, which agent) —
and stop. Never edit a profile, an agent, or the plugin yourself from a retro.
