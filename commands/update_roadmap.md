---
description: Re-infer lifecycle stages and sync the roadmap to the current on-disk state. Typeable alias for the roadmap skill's update action.
disable-model-invocation: true
---

Run the **roadmap** skill's **update_roadmap** action.

Use the Skill tool to invoke `roadmap`, treating this request as:
`update_roadmap $ARGUMENTS`

Follow that skill's `update_roadmap` procedure: rescan `requirements/` and `plans/`, advance each
row's stage/status to match reality, refresh the progress counter and Last Updated fields. If no
roadmap exists, fall back to make_roadmap behavior.
