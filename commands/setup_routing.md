---
description: Configure per-project model & effort routing — analyze the repo, classify its sensitivity profile, and (on confirmation) write a routing policy into CLAUDE.md plus pinned-model executor subagents. Typeable alias for the setup_routing skill.
disable-model-invocation: true
argument-hint: "[short description of the project]"
---

Pure dispatch — no behavior lives here.

Use the Skill tool to invoke `setup_routing` (`codeops:setup_routing` under the plugin),
passing the arguments through: `$ARGUMENTS`.

The skill owns the entire protocol and all layout/path resolution.
