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

1. **Verify first.** Run the project's verify command (build + test) as defined in the
   project's `CLAUDE.md` (or detected conventions). **Only continue if it passes.** If it
   fails, stop and report — do not commit broken code. If the project has no verify command,
   say so and continue.
2. **Stage everything:** `git add .`
3. **Write the commit message to a file, never inline.** Compose a Conventional Commit
   message and write it to `.git/COMMIT_EDITMSG_codeops` (or a temp file) with the Write tool,
   then commit with `git commit -F <file>`. **Never use `git commit -m`** — inline messages
   break on quotes, parentheses, `$`, backticks, and multi-line bodies.
4. **Clean up** the temp message file after a successful commit.
5. **Report** the resulting commit (`git log -1 --stat`).

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
