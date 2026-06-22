---
description: Upgrade an outdated requirements set to current CodeOps standards. Typeable alias for the upgrade_plan skill's requirements target.
disable-model-invocation: true
---

Run the **upgrade_plan** skill targeting **requirements**.

Use the Skill tool to invoke `upgrade_plan`, treating this request as:
`upgrade_requirements $ARGUMENTS`

Follow that skill's protocol against the `requirements/` set: detect version, assess gaps, present
the upgrade report before changing anything, pass the non-negotiable Content Quality Gate, apply
upgrades preserving all user-authored content verbatim, then verify. Does not auto-advance the roadmap.
