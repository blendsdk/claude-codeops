---
description: Configure per-project model & effort routing — analyze the repo, classify its sensitivity profile, and (on confirmation) write a routing policy into CLAUDE.md plus pinned-model executor subagents. Typeable alias for the setup_routing skill.
disable-model-invocation: true
argument-hint: "[short description of the project]"
---

Run the **setup_routing** skill.

Use the Skill tool to invoke `setup_routing`, treating this request as:
`setup_routing $ARGUMENTS`

Follow that skill's protocol: independently analyze the current repository, classify it into a
sensitivity profile (Opus-dominant, Mixed core/scaffold, Sonnet-default, or the Balanced
fallback), present the proposed tag-driven routing policy and the executor subagents to create,
**wait for explicit confirmation**, then write the sentinel-delimited routing block into the
project's `CLAUDE.md` and the pinned-model executors into `.claude/agents/`. Non-destructive and
idempotent; never touches global user files.
