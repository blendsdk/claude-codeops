---
description: Create or comprehensively regenerate VitePress technical architecture documentation and ADRs. Typeable alias for the techdocs skill's make_techdocs mode.
disable-model-invocation: true
argument-hint: "[--continue]"
---

Run the **techdocs** skill in **make_techdocs** mode.

Use the Skill tool to invoke `techdocs`, treating this request as:
`make_techdocs $ARGUMENTS`

Follow that skill's `make_techdocs` protocol: gather architecture from requirements/plans/code,
build the `docs/` VitePress set (system overview, data model, API design, infrastructure,
security, ADRs, guides, reference), and set the `techdocs: true` opt-in marker.
