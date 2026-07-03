---
description: Set up the CodeOps nested codeops/ layout in the current git repo — scaffold a fresh skeleton or auto-migrate an existing flat (requirements/ + plans/) layout into it, via a deterministic preview + single confirmation. Typeable alias for the setup_codeops skill.
disable-model-invocation: true
argument-hint: "[--dry-run | --yes]"
---

Pure dispatch — no behavior lives here.

Use the Skill tool to invoke `setup_codeops` (`codeops:setup_codeops` under the plugin),
passing the arguments through: `$ARGUMENTS`.

The skill owns the entire protocol and all layout/path resolution.
