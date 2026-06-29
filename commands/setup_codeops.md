---
description: Set up the CodeOps nested codeops/ layout in the current git repo — scaffold a fresh skeleton or auto-migrate an existing flat (requirements/ + plans/) layout into it, via a deterministic preview + single confirmation. Typeable alias for the setup_codeops skill.
disable-model-invocation: true
argument-hint: "[--dry-run | --yes]"
---

Run the **setup_codeops** skill.

Use the Skill tool to invoke `setup_codeops`, treating this request as:
`setup_codeops $ARGUMENTS`

Follow that skill's protocol: detect the current repo's state and dispatch — a layout marker
already present → no-op status report; a flat layout (`requirements/` / `plans/`) → migration
(run `scripts/codeops-migrate.sh --dry-run`, render the preview, take **one** confirmation, then
apply with `git mv`); neither → a minimal fresh scaffold. Respect `--dry-run` (preview only) and
`--yes` (apply without the prompt). Per-repo only; migration refuses a dirty tree and is
idempotent. `setup_codeops` is the sole writer of `codeops/.codeops.yml`.
