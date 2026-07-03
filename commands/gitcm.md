---
description: Stage all changes and commit with a detailed Conventional Commit message written to a file (never inline -m). Runs the project verify command first. Use for "gitcm".
disable-model-invocation: true
argument-hint: "[optional scope or note]"
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*), Write
---

# gitcm — commit with a detailed message

Stage all changes and create one well-formed commit. Do **not** push.

## Current state

- Status: !`git status --short`
- Staged/unstaged diff stat: !`git diff HEAD --stat`

## Steps

0. **Clean-tree guard.** If `git status --short` prints nothing, report "nothing to commit"
   and stop — do not run verify or stage.
1. **Verify first.** Run the project's verify command (build + test) as defined in the
   project's `CLAUDE.md` (or detected conventions). **Only continue if it passes.** If it
   fails, stop and report — do not commit broken code. If the project has no verify command,
   say so and continue.
2. **Stage deliberately.** Glance at the untracked files in the status first — anything that
   looks like secrets, scratch files, or build output gets flagged to the user before staging.
   Then `git add .` — noting it is CWD-relative: in a monorepo subdirectory it stages only the
   subtree; run it from the intended root.
3. **Write the commit message to a file, never inline.** Compose a Conventional Commit
   message and write it to `.git/COMMIT_EDITMSG_codeops` (or a temp file) with the Write tool,
   then commit with `git commit -F <file>`. **Never use `git commit -m`** — inline messages
   break on quotes, parentheses, `$`, backticks, and multi-line bodies.
4. **Pre-commit hooks.** If a hook modifies files during the commit, re-stage the modified
   files and retry ONCE; if the hook fails, show its output and ask — never pass
   `--no-verify` without the user's explicit approval.
5. **Clean up** the temp message file after a successful commit.
6. **Report** the resulting commit (`git log -1 --stat`).

If the user passed `$ARGUMENTS`, use it as a hint for the scope or emphasis.

## Commit message format (Conventional Commits)

```
<type>(<scope>): brief description in the imperative

- Specific change 1
- Specific change 2
- Tests added/updated
- Verification: passing
```

**Types:** `feat`, `fix`, `refactor`, `test`, `docs`, `chore`.

**Scope** = the module / package / service / directory touched. Follow the project's scope
convention if `CLAUDE.md` defines one. Examples: `feat(auth)`, `fix(utils)`, `docs(readme)`,
`chore(ci)`. For changes spanning many areas, use a broad scope: `refactor(project): …`,
`feat(infra): …`.

## Rules

- Never use the `-m` flag. Always write the message to a file and use `git commit -F`.
- Never force-push, amend published history, or reset commits unless explicitly asked.
- The commit is local only — `gitcm` never pushes. Use `/gitcmp` to commit **and** push.
