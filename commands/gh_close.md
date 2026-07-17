---
description: >
  Close one or more GitHub issues by number with GitHub's native close reasons — completed
  (default), not planned (--not-planned / --wontfix), or duplicate (--duplicate <#N>) — or
  reopen with --reopen. Echoes each issue's title before acting and pauses when other open
  issues depend on the one being closed. Use for "gh_close".
disable-model-invocation: true
argument-hint: "<number…> [--not-planned|--wontfix] [--duplicate <#N>] [--reopen] [--comment \"…\"] [--repo owner/repo]"
allowed-tools: Bash(gh issue view:*), Bash(gh issue close:*), Bash(gh issue reopen:*), Bash(gh issue comment:*), Bash(gh issue list:*), Bash(gh api graphql:*), Bash(gh auth status:*)
---

# gh_close — close or reopen GitHub issues by number

Close (or reopen) the listed issues using GitHub's native close-reason model, guarded by a
title echo and a dependent-issue pause. This command **mutates** issues — it fires only when
the user types it, never on the model's own initiative.

`gh issue list` and `gh api graphql` are in the allowlist **solely** for the read-only
dependent lookup below — never use them for anything else, and never send GraphQL mutations.

## Argument grammar

- One or more issue numbers; `9` and `#9` are equivalent (strip the `#`). Anything that is
  not numeric after stripping → reject the whole invocation with a usage line, **before any
  mutation**.
- Reason flags are mutually exclusive: default **completed**, `--not-planned` (alias
  `--wontfix`), `--duplicate <#N>`. `--reopen` excludes all reason flags and `--duplicate`.
  Any conflicting combination → reject before any mutation.
- `--duplicate <#N>` applies to EVERY listed issue (all become duplicates of #N). If #N
  itself is among the listed issues → error, nothing is closed.
- `--comment "…"` combines with any close reason and with `--reopen`; its text is always
  passed as a quoted argument — never interpolated unquoted, never through `eval`.
- `--repo owner/repo` targets another repo (default: the current directory's repo).

Preflight before touching anything: `gh auth status` — if `gh` is missing or
unauthenticated, stop with an actionable hint (install: https://cli.github.com ·
authenticate: `gh auth login`).

## Per-issue flow

For each issue number, in the order given:

1. **View & echo.** `gh issue view <n>` → print `Closing: <title> (#<n>) as <reason>` (or
   `Reopening: <title> (#<n>)`). Nonexistent issue → clear error naming the number, then
   **continue with the remaining issues**.
2. **State check.** Close mode on an already-closed issue → "already closed — skipping",
   no-op. Reopen mode on an already-open issue → "already open — skipping", no-op.
3. **Dependent guard** *(close modes only)*. Look up OPEN issues that depend on this one: a
   relation query (sub-issue / parent links) plus a search for body markers referencing it —
   `Depends on #<n>`, `Blocked by #<n>`, `Depends: #<n>`, case-insensitive. Open dependents
   found → list them and **pause for the user's explicit confirmation** before closing this
   issue; none found → proceed immediately. Lookup failure → degrade to the marker search
   only, say so, and proceed with the echo guard alone.
4. **Execute.**
   - completed → `gh issue close <n> --reason completed`
   - not planned → `gh issue close <n> --reason "not planned"`
   - duplicate of #M → `gh issue comment <n> --body "Duplicate of #M"`, then
     `gh issue close <n> --reason "not planned"` (emulation — see below)
   - reopen → `gh issue reopen <n>`
   - `--comment` rides on the action's own comment flag when the subcommand has one
     (`gh issue close -c` / `gh issue reopen -c`); otherwise post it as a separate
     `gh issue comment` immediately before the action.
5. **Record the outcome** — closed / reopened / skipped / failed plus the reason.

After the batch: print a per-issue outcome summary. One bad issue never aborts the rest.

## Duplicate emulation

`gh` (baseline 2.45.0) exposes only `completed` and `not planned` as close reasons. Marking
a duplicate therefore comments `Duplicate of #M` — GitHub auto-links and cross-references
it — and closes as *not planned*. If the running `gh` accepts `--reason duplicate` natively,
probe once and prefer it; the observable contract (linked duplicate reference + closed
state) stays identical either way.

## Error handling

| Error case | Handling |
|------------|----------|
| `gh` missing / unauthenticated | stop before any mutation, actionable hint |
| non-numeric issue argument | reject the whole invocation with a usage line |
| nonexistent issue in a batch | per-issue error, batch continues, summary records it |
| conflicting flags (`--reopen` + a reason, duplicate target in the list) | reject before any mutation |
| dependent-lookup failure | degrade to marker search + note; echo guard still applies |
