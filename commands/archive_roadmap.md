---
description: Archive a completed feature to the archive. Typeable alias for the roadmap skill's archive action (layout-aware — flat or nested codeops/).
disable-model-invocation: true
---

Run the **roadmap** skill's **archive_roadmap** action.

Use the Skill tool to invoke `roadmap`, treating this request as:
`archive_roadmap $ARGUMENTS`

Follow that skill's `archive_roadmap` procedure, which is **layout-aware**: in flat layout, read
the feature-set slug from the roadmap header, create `plans/_archive/<feature-set>/`, and move into
it the roadmap plus only the RD/plan rows it lists (leaving all other content untouched); in nested
layout, `git mv` the whole feature folder to `codeops/_archive/<f>/` and move its portfolio row to
the Archived section. The skill resolves paths and behaviour — this wrapper just invokes it.
