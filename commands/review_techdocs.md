---
description: Run a health check on existing technical architecture docs (staleness, completeness, accuracy, ADR coverage, links, diagrams). Typeable alias for the techdocs skill's review_techdocs mode.
disable-model-invocation: true
---

Run the **techdocs** skill in **review_techdocs** mode.

Use the Skill tool to invoke `techdocs`, treating this request as:
`review_techdocs $ARGUMENTS`

Follow that skill's `review_techdocs` protocol: run the 7-dimension health check (staleness,
completeness, accuracy, ADR coverage, link health, diagram accuracy, getting-started) and produce
a diagnostic report.
