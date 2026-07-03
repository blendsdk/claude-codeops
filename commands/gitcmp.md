---
description: Stage, commit with a detailed Conventional Commit message (file-based, never inline -m), then rebase and push. Runs verify first; stops and asks on conflicts. Use for "gitcmp".
disable-model-invocation: true
argument-hint: "[optional scope or note]"
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*), Bash(git pull:*), Bash(git push:*), Write
---

# gitcmp — commit, rebase, and push

Run the full `/gitcm` flow, then sync with the remote and push.

## Current state

- Status: !`git status --short`
- Branch & upstream: !`git status -sb | head -1`

## Steps

1. **Do everything `/gitcm` does:** clean-tree guard ("nothing to commit" → stop) → verify
   (build + test) → deliberate staging → file-based Conventional Commit → pre-commit-hook
   handling → clean up. **Never use `git commit -m`.** If verify fails, stop and report.
2. **Upstream check.** If the branch has no upstream (`git rev-parse --abbrev-ref @{u}` fails —
   a first push of a new branch), skip the rebase and, after confirming with the user, push
   with `git push -u origin HEAD`. Then report and stop here.
3. **Rebase on the remote:** `git pull --rebase`.
4. **If the rebase is clean,** push: `git push`. Then report the pushed commit.
5. **If the rebase reports conflicts,** follow the Conflict Protocol below — do **not** push.

If the user passed `$ARGUMENTS`, use it as a hint for the scope or emphasis. See `/gitcm` for
the full commit-message format and scope guidance.

## Conflict Protocol (on `git pull --rebase` conflicts)

1. **STOP.** Do not attempt automatic conflict resolution.
2. **Report** the conflicting files and the nature of each conflict.
3. **Ask the user** how to proceed:
   - Abort the rebase and keep the local commit (`git rebase --abort`)
   - "I'll resolve manually — show me the conflicts"
   - Abort and discard the commit (rare)
4. **Wait** for the user's decision before doing anything.
5. **After resolution,** re-run the project verify command before pushing.

Never accept "theirs"/"ours" wholesale, never force-push, and never reset/delete commits
without explicit user instruction.

## Push Failure Recovery

| Failure | Likely cause | Recovery |
|---|---|---|
| Authentication error | SSH key / token | Report — cannot fix programmatically |
| Remote rejection | Branch protection | Report — may need a PR workflow |
| Non-fast-forward | Remote has new commits | `git pull --rebase`, resolve, retry push once |
| No upstream configured | First push of a new branch | Confirm, then `git push -u origin HEAD` |
| Network error | Connectivity | Wait briefly, retry **once**, then report |

In all cases the local commit is safe. Report the error clearly and suggest the most likely
fix. Do not retry more than once without approval, and never `git push --force` unless
explicitly told to.
