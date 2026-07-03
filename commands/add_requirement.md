---
description: Add one new requirement document (RD) to an existing requirements set. Typeable alias for the make_requirements skill's add_requirement mode.
disable-model-invocation: true
argument-hint: "[what to add]"
---

Pure dispatch — no behavior lives here.

Use the Skill tool to invoke `make_requirements` (`codeops:make_requirements` under the plugin) in its
**add_requirement** mode, treating this request as: `add_requirement $ARGUMENTS`.

The skill owns the entire protocol and all layout/path resolution.
