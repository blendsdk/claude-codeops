---
description: Run a health check on existing technical architecture docs (staleness, completeness, accuracy, ADR coverage, links, diagrams). Typeable alias for the techdocs skill's review_techdocs mode.
disable-model-invocation: true
---

Pure dispatch — no behavior lives here.

Use the Skill tool to invoke `techdocs` (`codeops:techdocs` under the plugin) in its
**review_techdocs** mode, treating this request as: `review_techdocs $ARGUMENTS`.

The skill owns the entire protocol and all layout/path resolution.
