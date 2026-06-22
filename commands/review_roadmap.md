---
description: Read-only health check of the roadmap for drift, broken links, and unblockable rows. Typeable alias for the roadmap skill's review action.
disable-model-invocation: true
---

Run the **roadmap** skill's **review_roadmap** action.

Use the Skill tool to invoke `roadmap`, treating this request as:
`review_roadmap $ARGUMENTS`

Follow that skill's `review_roadmap` checks: verify every RD/plan link resolves, every stage
matches on-disk reality, every Blocked row has a live DEF-n (flag any whose blocker is already
Done), and the progress counter matches the Done count. Report only — make no changes.
