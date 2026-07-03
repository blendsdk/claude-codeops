# Execution Protocol (Reference)

Detailed execution protocol for the exec_plan skill. SKILL.md links here. Read this for the
load-the-plan edge cases, specification-first ordering, the real-time update mandate, the
session summary template, and error handling.

---

## Step 1: Load the Plan

1. Read `plans/[feature-name]/99-execution-plan.md`.
2. Find incomplete tasks: **both** unchecked `[ ]` items **and** implemented-but-unverified `[~]`
   items (see the two-stage marks below).
3. Read supporting technical specs in `plans/[feature-name]/`.
4. Determine the starting point: a `[~]` task is resumed FIRST — re-read its partial-completion
   note, re-run verification, then promote it to `[x]` or continue fixing. Otherwise start at the
   first `[ ]` task.
5. **Resume spot-check:** before building on prior work, confirm the most recent `[x]` task's
   named files actually exist (branch switches and reverts happen). If they don't, flag the drift
   to the user before continuing.

If the execution plan can't be loaded cleanly, **STOP** and handle as follows:

| Condition | Action |
|-----------|--------|
| `plans/` directory doesn't exist | STOP — suggest using the make_plan skill first |
| `plans/[feature-name]/` doesn't exist | STOP — suggest the make_plan skill, or check for typos in the feature name |
| `plans/[feature-name]/` exists but `99-execution-plan.md` is missing | STOP — plan is incomplete; suggest recreating it with the make_plan skill |
| `99-execution-plan.md` exists but has no tasks | STOP — plan is empty; suggest recreating it with the make_plan skill |
| All tasks already marked `[x]` | Report "All tasks are already complete." Suggest re-analyzing the project via the `/analyze_project` command |
| No verify command resolvable — the plan's Verify lines are empty/generic AND neither the project's CLAUDE.md nor its manifests name one | STOP — ask the user to name the verify command, write it into the plan's Verify lines, then proceed. **Never invent a command** (a plausible-looking `npm test` that was never configured verifies nothing) |

### Version Check (auto-suggest)

After loading, check the version stamp against the current **CodeOps Skills Version: 3.1.0**:

1. Read `00-index.md` or `99-execution-plan.md`.
2. Look for `> **CodeOps Version**: X.Y.Z` (or `CodeOps Skills Version`).
3. Compare against `3.1.0` (current; `3.0.0` is still compatible — the `3.0.0`→`3.1.0` bump needs no migration).

| Condition | Action |
|-----------|--------|
| Matches `3.0.0` or `3.1.0` | Proceed normally — plan is current |
| Older than `3.0.0` | Suggest: "This plan was created with an older CodeOps version (current: 3.1.0). Consider running the upgrade_plan skill. Proceed anyway?" |
| No version stamp | Suggest: "This plan has no version stamp. Consider running the upgrade_plan skill to bring it to current standards. Proceed anyway?" |

Suggestion only — the user may proceed without upgrading.

---

## Step 2: Execute Tasks

Task completion is **two-stage**: `[~]` = implemented (crash-safe progress mark), `[x]` = verified
complete. For each task, in order:

1. Implement the task following the technical specifications.
2. **🚨 Immediately update `99-execution-plan.md`** — mark the task `[~]` with a timestamp
   (`- [~] 1.1.1 … ⏳ (implemented: YYYY-MM-DD HH:MM)`, timestamp via `date '+%Y-%m-%d %H:%M'`)
   and update the Progress header. Do this before running verification or anything else — if the
   session crashes now, the implementation progress is preserved and the resume session knows the
   task still needs verification.
3. Run verification (your project's verify command — from the project's CLAUDE.md, or detected
   project conventions).
   - **PASS** → promote the mark to `[x]` with a completion timestamp
     (`- [x] 1.1.1 … ✅ (completed: YYYY-MM-DD HH:MM)`).
   - **FAIL** → the mark STAYS `[~]`. Fix the implementation and re-verify; promote only on pass.
     A task is never `[x]` with a failing verify.
4. Commit per the active commit mode (see [commit-modes.md](commit-modes.md)) — the commit gate
   keys off `[x]`, never `[~]`.
5. **Techdocs check (after each phase):** if techdocs exist and the just-completed phase
   introduced architectural changes (new components, data entities, API endpoints, integrations,
   or infrastructure), perform an incremental techdocs update via the techdocs skill.
6. Continue until all tasks are complete. Claude Code auto-compacts context, so there is no
   manual context-threshold handling — just keep going.

### Zero-Ambiguity During Execution

If you encounter any implementation detail, behavioral question, edge case, or design choice not
covered by the plan documents or `00-ambiguity-register.md`:

1. **STOP** — do not guess, infer, or apply "reasonable defaults".
2. **Present** the ambiguity to the user with options and trade-offs.
3. **Wait** for the user's explicit decision.
4. **Record** it in `00-ambiguity-register.md` with the next sequential AR number, tagged
   `(runtime)` in the Category column. Update the register header to note items added during
   execution.
5. **Only then** resume implementation using the user's decision.

This applies to ALL ambiguities — architectural, behavioral, naming, formatting, UX, error
handling. Never fill gaps by guessing.

---

## Delegated Execution (routing-tagged tasks → executor subagents)

When the project's CLAUDE.md carries a routing policy (see the setup_routing skill) that maps
task tags to executor subagents (`plan-task-executor` / `plan-task-executor-opus`, shipped in the
plugin's `agents/` directory), delegate tagged tasks as follows.

**The handoff packet.** The parent composes it; the subagent receives nothing else and must not
need anything else:

- the verbatim task line from `99-execution-plan.md`, plus its phase's Deliverables and Verify lines;
- the relevant excerpt of the governing `03-XX` spec document (the excerpt, not a filename);
- the applicable ST-cases from `07-testing-strategy.md`;
- the AR decisions that bear on this task (quoted rows, not the whole register);
- the target file paths and the project's verify command.

**Division of labor.** The PARENT — never the subagent — updates `99-execution-plan.md`
(two-stage marks), the Progress header, and the roadmap. The subagent implements and reports.
Mark `[~]` when the subagent reports implementation done; verify (or trust the subagent's verify
run and spot-check it); promote to `[x]` on pass.

**Blocker path.** On ambiguity, missing packet context, or a failing SPEC test, the subagent
stops and returns a blocker report. The parent then runs the zero-ambiguity loop above with the
user (STOP → options → decision → AR `(runtime)` entry) and re-delegates with the enriched
packet. A subagent never asks the user directly and never guesses.

**Missing-executor guard.** If the routing policy names executors that are not present in the
agent registry (e.g. the plugin's `agents/` isn't loaded, or the project overrode them and the
override is gone), execute the task inline and tell the user delegation was skipped and why.
Delegation is an optimization — the protocol's guarantees hold either way.

---

## Specification-First Task Ordering (NON-NEGOTIABLE)

The ordering `spec tests → red phase → implement → green phase → impl tests → verify` is defined
ONCE in **[../../_shared/spec-first-ordering.md](../../_shared/spec-first-ordering.md)** — read it
before executing the first implementation task. Enforce it exactly as written there: never start
implementation before that feature's spec tests exist and have a recorded red phase, and apply the
immutable-oracle rule — a failing spec test means the implementation is wrong, never the test.

---

## Real-Time Execution Plan Update Mandate (ULTRA-CRITICAL)

`99-execution-plan.md` is the SINGLE SOURCE OF TRUTH for progress and the user's lifeline if a
session ends unexpectedly. Update it after completing EACH task. No exceptions.

### Update-first order (two-stage)

```
Implement task → 🚨 MARK [~] IN THE PLAN → verify → PASS: promote to [x] / FAIL: fix, stays [~] → commit → next task
```

NOT: batch-updating later, updating only at the end, or "maybe update and maybe forget". If the
agent crashes during verify or commit, the plan already reflects exactly how far the work got —
`[~]` says "implemented, verification not yet passed"; `[x]` says "verified complete".

### Update procedure

1. On implementation: change `[ ]` → `[~]` with an implemented-timestamp in the **Master Progress
   Checklist**; on verify pass: promote `[~]` → `[x]` with a completion timestamp.
2. Update the Progress counter in the header (e.g., `3/12 tasks (25%)`) — only `[x]` tasks count
   as complete.
3. Update the Last Updated timestamp (obtain timestamps via `date '+%Y-%m-%d %H:%M'` — never
   invent them).

Task mark formats:

```markdown
- [~] 1.1.1 Task description ⏳ (implemented: YYYY-MM-DD HH:MM)
- [x] 1.1.1 Task description ✅ (completed: YYYY-MM-DD HH:MM)
```

### Master Progress Checklist — existence gate

Before executing the first task, verify the `## 🚨 Master Progress Checklist (All Phases)` section
exists. If missing, reconstruct it from the phase/session/task details (`- [ ] X.X.X [desc]`,
grouped by phase) before any task execution begins. If incomplete, add the missing tasks. Do NOT
execute any task while the checklist is missing or incomplete.

### Hard gate

Before running verification you MUST have already marked the task `[~]` with a timestamp. Before
committing, proceeding to the next task, ending a session, or presenting a session summary, the
task's final state MUST be recorded truthfully — `[x]` (with timestamp) only if its verify passed,
otherwise still `[~]` — with the progress counter and Last Updated stamp current.

---

## Step 3: Session Wrap-Up

1. Complete the current task before stopping.
2. **🚨 First: update `99-execution-plan.md`** with ALL completed tasks (before anything else).
3. Run the verify command.
4. Handle the commit per the active commit mode (see [commit-modes.md](commit-modes.md)).
5. Report the session summary (must include `Execution Plan Updated: ✅`).

### Session Summary Template

```markdown
## Session Complete

**Feature:** [feature-name]
**Execution Plan:** `plans/[feature-name]/99-execution-plan.md`

**Completed This Session:**
- [x] Phase X, Task X.X.X: [description]
- [x] Phase X, Task X.X.X: [description]

**Remaining Work:**
- [ ] Phase X, Task X.X.X: [description]
- [ ] Phase Y: [phase description]

**Execution Plan Updated:** ✅ `99-execution-plan.md` reflects all completed work
**Verification:** [Status — e.g., "All tests passing", "Build successful"]
**Commit Mode:** [ask-commit | no-commit | auto-commit]
**Commit:** [hash] / "Committed successfully" / "Uncommitted — user deferred" / "No-commit mode"

**To Continue:**
Run `/exec_plan [feature-name]` again in a new session.
```

---

## Error Handling During Execution

### If verification fails

1. The task's mark stays `[~]` (it was set at implementation time — never promote on a failing
   verify).
2. Fix the failing tests/build (for a failing SPEC test, fix the implementation — never the test).
3. Re-run verification until all checks pass.
4. Only then promote the mark to `[x]`.

### If implementation deviates from the plan

A deviation is by definition territory the plan doesn't cover — route it by materiality:

- **Material deviation** (different approach, different files, different behavior than the plan
  specifies): run the Zero-Ambiguity loop above — STOP, present the deviation with options,
  wait for the user's decision, record it in `00-ambiguity-register.md` tagged `(runtime)`,
  update the task description, then continue.
- **Mechanical correction** (typo'd path, renamed symbol, an import the plan forgot): note it in
  the execution plan and continue — no user round-trip needed.

When unsure which it is, treat it as material.

### If a session is interrupted mid-task

1. Save progress so far.
2. Ensure the task is marked `[~]` with a clear partial-completion note (what is done, what
   remains, what to verify).
3. Do NOT commit the half-done task (the commit gate keys off `[x]`).
4. Resume later by running `/exec_plan [feature-name]` again — Step 1 finds the `[~]` task,
   resumes it first, and re-verifies before promoting.
