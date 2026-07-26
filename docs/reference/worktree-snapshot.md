# Worktree phase snapshot

When the quality loop reviews a phase, it has to hand the reviewing agents *the phase*. That sounds
trivial and is not: a change set assembled from commits only contains work that has been committed.

`scripts/codeops_worktree_snapshot.py` builds the packet instead, from the phase-start ref to
whatever is on disk right now.

## The blind spot it closes

::: warning If you ran phases in `--no-commit` mode before 3.17.0
The review packet was a commit range. In `--no-commit` mode nothing is committed, so that range was
empty or partial — and a reviewer handed an empty change set reports **no findings**. That report is
indistinguishable from a genuine clean review. It was not a review at all.
:::

Newly created files were the worst case, and not only in that one mode. A file that has never been
added to git appears in no commit and in no `git diff`, so it was invisible to the old packet in
**every** commit mode — and a new file is frequently a phase's entire deliverable.

## What goes into a snapshot

Four states, composed into one packet:

| State | What it is |
|-------|-----------|
| Committed | Work already recorded in commits since the phase-start ref |
| Staged | Added to the index, not yet committed |
| Unstaged | Written to tracked files, not yet added |
| Untracked-but-new | Files git has never seen |

The packet is organized by path rather than by state, and that is deliberate: which of the four a
change happens to sit in is a fact about *when it was recorded*, not about what it is.

## Four guarantees

**Read-only.** The engine never stages, stashes, commits, or checks anything out. It runs git
against a throwaway copy of the index, so nothing it does can touch yours — a review is never
bought with a risk to your uncommitted work. The specification suite asserts that `git status`, the
refs, the reflog, and the index are byte-identical before and after.

**The same packet in every commit mode.** `--ask-commit`, `--no-commit`, and `--auto-commit`
produce the identical change set. Commit mode decides when work is recorded; it is not a review
input, and now it cannot become one by accident.

**Gitignore is respected.** Ignored paths never enter a packet. Build output, dependency trees, and
the git-ignored planning folders are not phase deliverables, and a packet padded with them buries
the code the reviewer was dispatched to read.

**Bounded, and never silently.** A phase touching a very large number of files is truncated to a
readable packet — but a truncated packet names every omitted path and the bound that dropped it.
Silent truncation is the same failure as the empty diff in a different costume: it reads as "the
reviewer saw everything" when it did not.

## When it fails

Failure is loud. If the snapshot cannot be produced — the ref does not resolve, the directory is
not a repository, a file cannot be read — the quality step reports a **blocker** and stops. Nothing
is substituted for it.

There is deliberately no fallback to a partial change set, because a reviewer cannot tell a packet
that is missing half a phase from a complete one, and neither can its report.

## Running it yourself

```bash
python3 scripts/codeops_worktree_snapshot.py --phase-ref <sha>
```

| Option | Default | Effect |
|--------|---------|--------|
| `--repo` | `.` | Repository to snapshot |
| `--phase-ref` | *(required)* | The commit the phase started from |
| `--max-bytes` | `512000` | Total packet budget |
| `--max-file-bytes` | `64000` | Largest single change included |
| `--max-files` | `200` | Most changes included |

It prints the packet on stdout and exits 0, or prints `SNAPSHOT BLOCKER: …` on stderr and exits 1
with no packet at all.

## What it does not do

It does not change when the quality loop runs, which agents it dispatches, or what any commit mode
means. It changes only what the reviewers are given — which, it turns out, was the part that was
wrong.
