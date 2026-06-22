---
description: Health-check an existing requirements set for gaps, inconsistencies, and scope creep. Typeable alias for the make_requirements skill's review_requirements mode.
disable-model-invocation: true
argument-hint: "[optional focus]"
---

Run the **make_requirements** skill in **review_requirements** mode.

Use the Skill tool to invoke `make_requirements`, treating this request as:
`review_requirements $ARGUMENTS`

Follow that skill's `review_requirements` protocol: audit the existing `requirements/` set for
completeness, internal consistency, coverage, dependency correctness, scope creep, and orphaned
RDs, then report findings (do not silently rewrite the RDs).
