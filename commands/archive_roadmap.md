---
description: Archive a completed feature-set into plans/_archive/<feature-set>/. Typeable alias for the roadmap skill's archive action.
disable-model-invocation: true
---

Run the **roadmap** skill's **archive_roadmap** action.

Use the Skill tool to invoke `roadmap`, treating this request as:
`archive_roadmap $ARGUMENTS`

Follow that skill's `archive_roadmap` procedure: read the feature-set slug from the roadmap
header, create `plans/_archive/<feature-set>/`, and move into it the roadmap plus only the RD/plan
rows it lists — leaving all other `requirements/` and `plans/` content untouched.
