---
description: Create the roadmap and seed rows from disk. Typeable alias for the roadmap skill's make action (layout-aware — single plans/00-roadmap.md flat, or two-tier per-feature + portfolio under codeops/).
disable-model-invocation: true
---

Run the **roadmap** skill's **make_roadmap** action.

Use the Skill tool to invoke `roadmap`, treating this request as:
`make_roadmap $ARGUMENTS`

Follow that skill's `make_roadmap` procedure, which is **layout-aware**: in flat layout, create
`plans/00-roadmap.md` from the template and seed one row per `requirements/RD-*.md`; in nested
layout, create the portfolio `codeops/00-roadmap.md` and/or the target feature's roadmap and seed
its rows. Suggest plan links and inferred stages for the user to confirm. The skill resolves the
paths — this wrapper just invokes it.
