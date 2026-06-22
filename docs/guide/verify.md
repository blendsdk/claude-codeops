# Verify it loaded

In a **new** Claude Code session:

1. Ask **"What skills are available?"** — you should see the CodeOps skills listed.
2. Type `/` and look for the namespaced commands, e.g. `/codeops:make_plan`, `/codeops:exec_plan`,
   `/codeops:gitcm`, `/codeops:gitcmp` (plugin skills/commands are namespaced under `codeops:`).
3. Ask **"What coding standards are you following?"** — the model should describe the CodeOps
   standards (DRY, single-responsibility, spec-vs-impl tests, security-from-line-one, …)
   **without you having edited any `CLAUDE.md`**. That confirms the `SessionStart` standards hook is
   working.
4. Run `/doctor` and confirm there are no warnings about truncated skill descriptions.

## If something is missing

- **Standards don't appear:** start a brand-new session — the hook runs at session start — and
  confirm the plugin is enabled with `/plugin`.
- **New skills/commands don't appear after install/update:** start a fresh session so newly added
  directories start being watched.

See [Troubleshooting](/reference/troubleshooting) for the full table.
