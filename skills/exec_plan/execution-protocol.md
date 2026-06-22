# Execution Protocol (Reference)

Detailed execution protocol for the exec_plan skill. SKILL.md links here. Read this for the
load-the-plan edge cases, specification-first ordering, the real-time update mandate, the
session summary template, and error handling.

---

## Step 1: Load the Plan

1. Read `plans/[feature-name]/99-execution-plan.md`.
2. Find incomplete tasks (unchecked `[ ]` items).
3. Read supporting technical specs in `plans/[feature-name]/`.
4. Determine the starting point: first incomplete phase/session/task.

If the execution plan can't be loaded cleanly, **STOP** and handle as follows:

| Condition | Action |
|-----------|--------|
| `plans/` directory doesn't exist | STOP — suggest using the make_plan skill first |
| `plans/[feature-name]/` doesn't exist | STOP — suggest the make_plan skill, or check for typos in the feature name |
| `plans/[feature-name]/` exists but `99-execution-plan.md` is missing | STOP — plan is incomplete; suggest recreating it with the make_plan skill |
| `99-execution-plan.md` exists but has no tasks | STOP — plan is empty; suggest recreating it with the make_plan skill |
| All tasks already marked `[x]` | Report "All tasks are already complete." Suggest re-analyzing the project via the `/analyze_project` command |

### Version Check (auto-suggest)

After loading, check the version stamp against the current **CodeOps Skills Version: 2.0.0**:

1. Read `00-index.md` or `99-execution-plan.md`.
2. Look for `> **CodeOps Version**: X.Y.Z` (or `CodeOps Skills Version`).
3. Compare against `2.0.0`.

| Condition | Action |
|-----------|--------|
| Matches `2.0.0` | Proceed normally — plan is current |
| Older than `2.0.0` | Suggest: "This plan was created with an older CodeOps version (current: 2.0.0). Consider running the upgrade_plan skill. Proceed anyway?" |
| No version stamp | Suggest: "This plan has no version stamp. Consider running the upgrade_plan skill to bring it to current standards. Proceed anyway?" |

Suggestion only — the user may proceed without upgrading.

---

## Step 2: Execute Tasks

For each task, in order:

1. Implement the task following the technical specifications.
2. **🚨 Immediately update `99-execution-plan.md`** — mark the task `[x]` with a timestamp (see
   the Real-Time Update Mandate below). This happens BEFORE verification, BEFORE commit, BEFORE
   anything else. If the agent crashes after this point, progress is preserved.
3. Run verification (your project's verify command — from the project's CLAUDE.md, or detected
   project conventions).
4. Commit per the active commit mode (see [commit-modes.md](commit-modes.md)).
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

## Specification-First Task Ordering (NON-NEGOTIABLE)

Every feature implementation phase follows this three-phase task structure. It prevents
tautological testing — tests that mirror the implementation instead of independently verifying it
against the specification.

```
Phase N: [Feature Name]

  Session N.1: Specification Tests (BEFORE implementation)
    N.1.1  Write specification tests from 07-testing-strategy.md ST-cases
           → File: [feature].spec.test.[ext]
           → Source: 07-testing-strategy.md ST-1 through ST-X
           → Do NOT read implementation logic when writing these tests
    N.1.2  Run spec tests — verify they FAIL (red phase)
           → Document any that pass pre-implementation with justification

  Session N.2: Implementation
    N.2.1  Implement [feature/component] per technical specification
           → File: [implementation files]
           → Reference: 03-XX-[component].md
    N.2.2  Run spec tests — verify they PASS (green phase)
           → If any spec test fails: STOP, fix the implementation (NOT the test)

  Session N.3: Implementation Tests & Hardening
    N.3.1  Write implementation tests (edge cases, internals, error paths)
           → File: [feature].impl.test.[ext]
    N.3.2  Full verification (your project's verify command)
```

### Why this ordering

| Step | What it prevents |
|------|-----------------|
| Spec tests BEFORE implementation | Prevents deriving test expectations from the code you just wrote |
| Red-phase verification | Proves the spec tests are meaningful (they test something that doesn't exist yet) |
| Spec tests PASS after implementation | Proves the implementation satisfies the specification |
| Impl tests AFTER implementation | These CAN be derived from the code (edge cases, internals); spec tests cannot |

### Enforcement

**Prohibited:**

- ❌ Writing implementation code before specification tests exist for that feature
- ❌ Skipping the spec-test phase ("we'll write tests after")
- ❌ Combining spec tests and implementation in the same task
- ❌ Writing spec tests and implementation simultaneously

**Required:** the immutable-oracle rule — if the implementation doesn't match a spec test, the
implementation is wrong, not the test. Never modify a spec test's expectations to match code.

### Small features

For small features, you MAY compress into a single session — but the ordering is still mandatory:

```
Session N.1: [Feature Name]
  N.1.1  Write specification tests (from ST-cases)
  N.1.2  Verify spec tests fail (red phase)
  N.1.3  Implement feature
  N.1.4  Verify spec tests pass (green phase)
  N.1.5  Write implementation tests
  N.1.6  Full verification
```

`spec tests → red → implement → green → impl tests → verify` is never negotiable, at any size.

---

## Real-Time Execution Plan Update Mandate (ULTRA-CRITICAL)

`99-execution-plan.md` is the SINGLE SOURCE OF TRUTH for progress and the user's lifeline if a
session ends unexpectedly. Update it after completing EACH task. No exceptions.

### Update-first order

```
Implement task → 🚨 UPDATE EXECUTION PLAN → verify → commit → next task
```

NOT: batch-updating later, updating only at the end, or "maybe update and maybe forget". If the
agent crashes during verify or commit, the plan already reflects the completed work.

### Update procedure (per completed task)

1. Edit `99-execution-plan.md` to change `[ ]` → `[x]` with a timestamp in the **Master Progress
   Checklist** section.
2. Update the Progress counter in the header (e.g., `3/12 tasks (25%)`).
3. Update the Last Updated timestamp.

Task completion format:

```markdown
- [x] 1.1.1 Task description ✅ (completed: YYYY-MM-DD HH:MM)
```

### Master Progress Checklist — existence gate

Before executing the first task, verify the `## 🚨 Master Progress Checklist (All Phases)` section
exists. If missing, reconstruct it from the phase/session/task details (`- [ ] X.X.X [desc]`,
grouped by phase) before any task execution begins. If incomplete, add the missing tasks. Do NOT
execute any task while the checklist is missing or incomplete.

### Hard gate

Before proceeding to the next task, running verification, committing, ending a session, or
presenting a session summary, you MUST have already: marked the task `[x]` with a timestamp,
updated the progress counter, and updated the Last Updated stamp.

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

1. Fix the failing tests/build.
2. Verify all checks pass.
3. Only then mark the task complete.

### If implementation deviates from the plan

1. Note the deviation in the execution plan.
2. Update task descriptions if needed.
3. Continue with the corrected approach.

### If a session is interrupted mid-task

1. Save progress so far.
2. Add clear notes about partial completion.
3. Mark the task as `[~]` (partial) with an explanation.
4. Handle the commit per the active commit mode (ask / no-commit / auto-commit).
5. Resume later by running `/exec_plan [feature-name]` again — files are always saved to disk, so
   no work is lost, and the execution plan tells the skill where to pick up.
