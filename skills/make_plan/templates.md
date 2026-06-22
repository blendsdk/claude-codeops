# Plan Document Templates

Read this when writing the Phase 2 documents. Create files in `plans/<feature-name>/`. Stamp `00-index.md` and `99-execution-plan.md` with `> **CodeOps Skills Version**: 2.0.0`.

Folder layout:

```
plans/<feature-name>/
├── 00-ambiguity-register.md   # see zero-ambiguity-gate.md for this file's template
├── 00-index.md
├── 01-requirements.md
├── 02-current-state.md
├── 03-XX-<component>.md        # one or more, per component
├── 07-testing-strategy.md
└── 99-execution-plan.md
```

---

## 00-index.md — Index and Overview

```markdown
# [Feature Name] Implementation Plan

> **Feature**: [Brief description]
> **Status**: Planning Complete
> **Created**: [Date]
> **Implements**: RD-NN   (only if based on a requirements document; omit otherwise)
> **CodeOps Skills Version**: 2.0.0

## Overview

[2-3 paragraph description of what this feature does and why it's needed]

## Document Index

| #   | Document                                       | Description                                 |
| --- | ---------------------------------------------- | ------------------------------------------- |
| AR  | [Ambiguity Register](00-ambiguity-register.md) | Zero-Ambiguity Gate decisions (audit trail) |
| 00  | [Index](00-index.md)                           | This document — overview and navigation     |
| 01  | [Requirements](01-requirements.md)             | Feature requirements and scope              |
| 02  | [Current State](02-current-state.md)           | Analysis of current implementation          |
| 03  | [Component Name](03-component.md)              | Technical specification                     |
| ... | ...                                            | ...                                         |
| 07  | [Testing Strategy](07-testing-strategy.md)     | Test cases and verification                 |
| 99  | [Execution Plan](99-execution-plan.md)         | Phases, sessions, and task checklist        |

## Quick Reference

### Usage Examples

[Code examples showing the feature in use]

### Key Decisions

| Decision     | Outcome   |
| ------------ | --------- |
| [Decision 1] | [Outcome] |

## Related Files

[List of key files that will be created or modified]
```

---

## 01-requirements.md — Requirements and Scope

If the plan is based on a requirements document, add at the top: `> **Source**: [RD-XX](../../requirements/RD-XX-feature-name.md)`.

```markdown
# Requirements: [Feature Name]

> **Document**: 01-requirements.md
> **Parent**: [Index](00-index.md)

## Feature Overview

[Detailed description of the feature]

## Functional Requirements

### Must Have
- [ ] Requirement 1

### Should Have
- [ ] Requirement 1

### Won't Have (Out of Scope)
- Exclusion 1

## Technical Requirements

### Performance
- [Performance requirements]

### Compatibility
- [Compatibility requirements]

### Security
- [Security requirements]

## Scope Decisions

| Decision   | Options Considered | Chosen | Rationale | AR Ref |
| ---------- | ------------------ | ------ | --------- | ------ |
| [Decision] | A, B, C            | B      | [Why]     | AR #X  |

> **Traceability:** Every scope decision must reference the Ambiguity Register entry (AR #) that resolved it. See `00-ambiguity-register.md`.

## Acceptance Criteria

1. [ ] Criterion 1
2. [ ] All tests pass
3. [ ] Documentation updated
```

---

## 02-current-state.md — Current State Analysis

```markdown
# Current State: [Feature Name]

> **Document**: 02-current-state.md
> **Parent**: [Index](00-index.md)

## Existing Implementation

### What Exists
[Description of current relevant code]

### Relevant Files

| File           | Purpose   | Changes Needed |
| -------------- | --------- | -------------- |
| `path/to/file` | [Purpose] | [Changes]      |

### Code Analysis
[Key code snippets and analysis]

## Gaps Identified

### Gap 1: [Name]
**Current Behavior:** [What happens now]
**Required Behavior:** [What should happen]
**Fix Required:** [What needs to change]

## Dependencies

### Internal Dependencies
- [List internal dependencies]

### External Dependencies
- [List external dependencies]

## Risks and Concerns

| Risk   | Likelihood   | Impact       | Mitigation |
| ------ | ------------ | ------------ | ---------- |
| [Risk] | High/Med/Low | High/Med/Low | [Strategy] |
```

---

## 03-XX-[component].md — Component Technical Specification

```markdown
# [Component Name]: [Feature Name]

> **Document**: 03-[component].md
> **Parent**: [Index](00-index.md)

## Overview
[What this component does and why]

## Architecture

### Current Architecture
[Describe current state]

### Proposed Changes
[Describe what changes]

## Implementation Details

### New Types/Interfaces
[Type definitions — use the project's language]

### New Functions/Methods
[Function signatures with documentation]

### Integration Points
[How this connects to other components]

## Code Examples

### Example 1: [Name]
[Code example]

## Error Handling

| Error Case | Handling Strategy | AR Ref |
| ---------- | ----------------- | ------ |
| [Error]    | [Strategy]        | AR #X  |

> **Traceability:** Every error-handling strategy and design choice must reference the Ambiguity Register entry (AR #) that resolved it. See `00-ambiguity-register.md`. Only exceptions: universally obvious facts and zero-semantic-impact formatting.

## Testing Requirements
- Unit tests for [specific functionality]
- Integration tests for [interactions]
```

**Component document sizing:** one `03-XX-[component].md` per major component, or split into `03-XX-[component]-[sub].md` per sub-component. Keep each document manageable to author (aim well under ~30K tokens to write).

---

## 07-testing-strategy.md — Testing Strategy

```markdown
# Testing Strategy: [Feature Name]

> **Document**: 07-testing-strategy.md
> **Parent**: [Index](00-index.md)

## Testing Overview

### Coverage Goals
- Unit tests: [X]% coverage
- Integration tests: Key workflows covered
- E2E tests: Complete feature verification

## 🚨 Specification Test Cases (MANDATORY — NON-NEGOTIABLE)

> These test cases are derived EXCLUSIVELY from requirements (`01-requirements.md`),
> component specs (`03-XX-*.md`), API contracts, RFCs, and the Ambiguity Register
> (`00-ambiguity-register.md`). They define expected behavior BEFORE any implementation exists.
>
> **IMMUTABLE ORACLE RULE:** Do NOT modify these expectations to match the implementation.
> If the implementation does not match a spec test case, the implementation is wrong — not the test.
>
> **Every spec test case MUST include a source reference** tracing it to the requirement,
> spec document, or AR entry that defines the expected behavior.

### [Component/Feature 1]

| #    | Input / Scenario           | Expected Output / Behavior             | Source            |
|------|----------------------------|----------------------------------------|-------------------|
| ST-1 | [Concrete input or action] | [Concrete expected output or behavior] | [Req X.X / AR #X] |
| ST-2 | [Concrete input or action] | [Concrete expected output or behavior] | [Req X.X / AR #X] |
| ST-3 | [Error/edge scenario]      | [Expected error type and message]      | [Req X.X / AR #X] |

> **⚠️ AUTHORING RULE:** Derive expectations from the specification documents above. Do NOT
> imagine or infer what the implementation will produce. If the expected output cannot be
> determined from the spec, that is an ambiguity — add it to the Ambiguity Register and
> resolve it with the user before defining the test case.

## Test Categories

### Specification Tests (from ST-cases above)
> Written BEFORE implementation. Filed as `[feature].spec.test.[ext]`.

| Test File                   | ST Cases Covered | Component     |
| --------------------------- | ---------------- | ------------- |
| `[feature].spec.test.[ext]` | ST-1, ST-2, ST-3 | [Component 1] |

### Implementation Tests (edge cases, internals)
> Written AFTER implementation. Filed as `[feature].impl.test.[ext]`.

| Test File                   | Description                                       | Priority     |
| --------------------------- | ------------------------------------------------- | ------------ |
| `[feature].impl.test.[ext]` | [Edge cases, boundary conditions, internal logic] | High/Med/Low |

### Integration Tests

| Test        | Components   | Description   |
| ----------- | ------------ | ------------- |
| [Test name] | [Components] | [Description] |

### End-to-End Tests

| Scenario   | Steps   | Expected Result |
| ---------- | ------- | --------------- |
| [Scenario] | [Steps] | [Result]        |

## Test Data

### Fixtures Needed
[List test fixtures]

### Mock Requirements
[List any mocks needed — prefer real objects when possible]

## Verification Checklist
- [ ] All specification test cases (ST-*) defined with concrete input/output pairs
- [ ] Every ST case traces to a requirement, spec doc, or AR entry
- [ ] Specification tests written BEFORE implementation
- [ ] Specification tests verified to FAIL before implementation (red phase)
- [ ] All specification tests pass after implementation (green phase)
- [ ] Implementation tests written for edge cases and internals
- [ ] All unit / integration / E2E tests pass
- [ ] No regressions in existing tests
- [ ] Test coverage meets goals
```

---

## 99-execution-plan.md — Execution Plan

Every execution plan MUST follow this template, MUST include the **Master Progress Checklist**, and MUST structure feature phases with the specification-first ordering (see the next section).

````markdown
# Execution Plan: [Feature Name]

> **Document**: 99-execution-plan.md
> **Parent**: [Index](00-index.md)
> **Last Updated**: [YYYY-MM-DD HH:MM]
> **Progress**: 0/X tasks (0%)
> **CodeOps Skills Version**: 2.0.0

## Overview

[Brief description of the feature implementation]

**🚨 Update this document after EACH completed task!**

---

## Implementation Phases

| Phase | Title          | Sessions | Est. Time |
| ----- | -------------- | -------- | --------- |
| 1     | [Phase 1 Name] | 1        | XX min    |
| 2     | [Phase 2 Name] | 1-2      | XX min    |

**Total: X sessions, ~X-X hours**

---

## Phase 1: [Phase Name]

### Session 1.1: [Session Objective]

**Reference**: [Link to technical doc]
**Objective**: [What this session achieves]

**Tasks**:

| #     | Task               | File           |
| ----- | ------------------ | -------------- |
| 1.1.1 | [Task description] | `path/to/file` |
| 1.1.2 | [Task description] | `path/to/file` |

**Deliverables**:
- [ ] Deliverable 1
- [ ] All verification passing

**Verify**: [Project's verify command from CLAUDE.md / detected conventions]

---

## 🚨 Master Progress Checklist (All Phases) — MANDATORY

> **⚠️ EXECUTION RULE — APPLIES TO EVERY AGENT EXECUTING THIS PLAN:**
>
> This checklist is the **single source of truth** for tracking progress across all phases.
> The executing agent MUST:
>
> 1. **After completing each task:** mark it `[x]` with a timestamp — e.g., `- [x] 1.1.1 Task description ✅ (completed: YYYY-MM-DD HH:MM)`
> 2. **After completing each phase:** confirm every completed task in that phase is marked `[x]` with a timestamp
> 3. **Update the Progress header** (`> **Progress**: X/Y tasks (Z%)`) after every update
> 4. **This checklist MUST exist** — if missing or incomplete, reconstruct it from the phase details above before executing any task
> 5. **Never batch updates** — update immediately after each task, not at the end of a session
>
> Failure to maintain this checklist means progress is invisible after crashes, context resets, or session handoffs.

### Phase 1: [Phase Name]
- [ ] 1.1.1 [Task]
- [ ] 1.1.2 [Task]

### Phase 2: [Phase Name]
- [ ] 2.1.1 [Task]

---

## Dependencies

```
Phase 1
    ↓
Phase 2
    ↓
...
```

---

## Success Criteria

**Feature is complete when:**

1. ✅ All phases completed
2. ✅ All verification passing (project's verify command)
3. ✅ No warnings/errors
4. ✅ No dead code — no unused parameters, functions, classes, or modules
5. ✅ Security hardened — input validation, injection prevention, auth, rate limiting, data protection
6. ✅ Documentation updated
7. ✅ Code reviewed (if applicable)
8. ✅ Post-completion project re-analysis (handled by the exec_plan skill)
````

> Detailed session-by-session execution mechanics (commit modes, real-time progress updates, post-completion re-analysis) belong to the **exec_plan skill**, not here.

---

## Specification-First Task Ordering (NON-NEGOTIABLE)

Every feature implementation phase in `99-execution-plan.md` MUST follow this three-session ordering. This prevents tautological testing — tests mirroring the implementation instead of independently verifying it against the specification.

```
Phase N: [Feature Name]

  Session N.1: Specification Tests (BEFORE implementation)
    N.1.1  Write specification tests from 07-testing-strategy.md ST-cases
           → File: [feature].spec.test.[ext]
           → Source: 07-testing-strategy.md ST-1 through ST-X
           → MUST NOT read implementation logic when writing these tests
    N.1.2  Run spec tests — verify they FAIL (red phase)
           → Document any that pass pre-implementation with justification

  Session N.2: Implementation
    N.2.1  Implement [feature/component] per technical specification
           → Reference: 03-XX-[component].md
    N.2.2  Run spec tests — verify they PASS (green phase)
           → If any spec test fails: STOP, fix implementation (NOT the test)

  Session N.3: Implementation Tests & Hardening
    N.3.1  Write implementation tests (edge cases, internals, error paths)
           → File: [feature].impl.test.[ext]
    N.3.2  Full verification (project's verify command)
```

**Why each step matters:** spec tests BEFORE implementation prevent deriving expectations from code just written; red-phase proves the spec tests are meaningful; green-phase proves the implementation satisfies the spec; impl tests AFTER implementation may legitimately be derived from the code (edge cases, internals) — but spec tests must not be.

**🚫 PROHIBITED:** writing implementation code before spec tests exist; skipping the spec test phase; combining spec tests and implementation in one task; writing them simultaneously; generating a plan where implementation tasks precede spec test tasks for the same feature.

**✅ REQUIRED in every generated `99-execution-plan.md`:** the three-session ordering per feature phase; explicit `[feature].spec.test.[ext]` and `[feature].impl.test.[ext]` file references; references to the ST-cases from `07-testing-strategy.md` in spec test tasks; a distinct red-phase verification task.

**Small features:** you may compress into a single session, but the ordering is still mandatory:

```
Session N.1: [Feature Name]
  N.1.1  Write specification tests (from ST-cases)
  N.1.2  Verify spec tests fail (red phase)
  N.1.3  Implement feature
  N.1.4  Verify spec tests pass (green phase)
  N.1.5  Write implementation tests
  N.1.6  Full verification
```

The order `spec tests → red phase → implement → green phase → impl tests → verify` is NEVER negotiable, regardless of feature size.

---

## Adapting to Project Type

Adapt the component documents to the project type:

| Project Type       | Typical Components                             |
| ------------------ | ---------------------------------------------- |
| **Web App**        | Frontend, Backend, API, Database, Auth         |
| **API / Backend**  | Endpoints, Services, Data Models, Validation   |
| **Library / SDK**  | Core, Utils, Types, Public API                 |
| **CLI Tool**       | Commands, Arguments, Output, Config            |
| **UI Components**  | Component, Styles, Hooks, Stories, Tests       |
| **Mobile App**     | UI, State, Services, Navigation                |
| **Compiler**       | Lexer, Parser, Analyzer, Generator             |
| **Microservices**  | Services, Events, Data, Integration            |
| **Infrastructure** | Docker, Nginx, CI/CD, Deployment Scripts       |
| **Database**       | Schema/Migration, Repository, Service, Tests   |
| **Bug Fix**        | Root cause analysis, Fix, Regression test      |
| **Refactoring**    | Current state, New structure, Migration, Tests |
