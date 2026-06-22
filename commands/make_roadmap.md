---
description: Create the feature-set roadmap at plans/00-roadmap.md and seed rows from disk. Typeable alias for the roadmap skill's make action.
disable-model-invocation: true
---

Run the **roadmap** skill's **make_roadmap** action.

Use the Skill tool to invoke `roadmap`, treating this request as:
`make_roadmap $ARGUMENTS`

Follow that skill's `make_roadmap` procedure: ask for the feature-set name, create
`plans/00-roadmap.md` from the template, and seed one row per `requirements/RD-*.md`, suggesting
plan links and inferred stages for the user to confirm.
