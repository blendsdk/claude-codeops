---
description: Add one new requirement document (RD) to an existing requirements set. Typeable alias for the make_requirements skill's add_requirement mode.
disable-model-invocation: true
argument-hint: "[what to add]"
---

Run the **make_requirements** skill in **add_requirement** mode.

Use the Skill tool to invoke `make_requirements`, treating this request as:
`add_requirement $ARGUMENTS`

Follow that skill's `add_requirement` protocol: read the current `requirements/` set, run a
focused discovery for the new capability, pass the Zero-Ambiguity Gate for the new RD, write the
new `RD-XX-*.md`, then update the README index and dependency graph.
