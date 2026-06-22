# Phase 2B: Zero-Ambiguity Gate — 🚨 NON-NEGOTIABLE HARD GATE 🚨

> **This gate MUST be passed before ANY requirement document (RD) is written.
> There are NO exceptions, NO overrides, and NO "good enough" thresholds.** It
> is the most important quality gate in the entire requirements process. It also
> applies (scoped to new decisions) during add_requirement and upgrade.

## Why This Gate Exists

Requirements built on ambiguity produce plans built on guesswork, which produce
implementations built on assumptions. When the AI guesses, the user gets
requirements they didn't specify, behaviors they didn't define, and scope they
didn't approve. Every item in every RD must trace back to an **explicit,
user-confirmed decision**. If you cannot point to a specific user answer for any
feature spec, behavioral definition, scope boundary, edge-case handling, or
technical choice — you have failed this gate.

## The Ambiguity Register

Before Phase 3, compile and present an **Ambiguity Register** — a formal,
numbered inventory of every gap, ambiguity, unstated assumption, undefined
behavior, and open question found during Phases 1–2.

**Systematically hunt for ambiguities across ALL of these categories:**

| Category | What to Look For |
|----------|-----------------|
| **Feature gaps** | Features mentioned but not fully specified, unclear interactions, undefined workflows |
| **Scope ambiguities** | Features that could go either way, unclear MVP vs. future, conflicting stakeholder needs |
| **Behavioral unknowns** | Undefined "what happens when…", missing error states, unspecified state transitions |
| **Data model questions** | Undefined relationships, unclear ownership, missing validation rules, unspecified cardinality |
| **Technical unknowns** | Architecture/technology choices not decided, unresolved integration approaches |
| **Edge cases** | Boundary conditions, failure modes, concurrent access, empty/null states, data volume limits |
| **Integration points** | Unclear external interfaces, undefined API contracts, missing data flow specs |
| **Security & compliance** | Unaddressed threat vectors, undefined auth models, missing data protection decisions, regulatory gaps |
| **Non-functional gaps** | Missing performance targets, undefined scalability approach, unspecified availability requirements |
| **UX & presentation** | Undefined user-facing text, missing error messages, unspecified display formats, unclear navigation |
| **Stakeholder conflicts** | Competing needs between user types, unresolved priority disputes, unclear permission boundaries |
| **Naming & terminology** | Domain terms used inconsistently, undefined jargon, ambiguous labels |

**Register template:**

```markdown
## Ambiguity Register: [Project Name] Requirements

> **Status**: ❌ GATE BLOCKED — [X] items unresolved
> *(When all resolved, change to: ✅ GATE PASSED — all [X] items resolved)*
> **Last Updated**: [Date]

| # | Category | Ambiguity / Gap | Options Presented | User Decision | Status |
|---|----------|----------------|-------------------|---------------|--------|
| 1 | Feature | [Specific ambiguity] | [Option A / B / C] | [User's answer] | ✅ Resolved |
| 2 | Scope | [Specific ambiguity] | [Option A / B] | — | ❌ Open |

### Resolution Notes

**AR-1:** [Expanded context for the decision if needed]
**AR-2:** [Pending — presented to user, awaiting answer]
```

## Gate Enforcement Rules

**🚫 ABSOLUTELY PROHIBITED while the gate is blocked:**

- ❌ Create any requirement document (`RD-XX-*.md`)
- ❌ Write `requirements/README.md`
- ❌ Define any requirement specification
- ❌ Make any design decision on the user's behalf
- ❌ Use phrases like "we'll assume…", "by default…", "a reasonable approach would be…"
- ❌ Proceed with a partially resolved register

**✅ The gate opens ONLY when ALL of these are met:**

1. Every row has Status = "✅ Resolved".
2. Every resolution contains the **user's explicit decision** (not your recommendation accepted by silence).
3. The user has reviewed and confirmed the complete register (for >15 items, present in batches by category — user confirms each batch, then gives a final confirmation: *"I have reviewed and confirmed all [X] items"*).
4. Zero items are deferred — every item has a concrete answer ("figure it out later" is NOT accepted; explain the consequences and guide the user to a decision NOW).
5. The header reads `✅ GATE PASSED — all [X] items resolved`.

**User dismissals:** if the user says *"that's not ambiguous, the answer is obviously X"* — that IS a valid resolution. Record it as `✅ Resolved — User: "[their stated answer]"`. You cannot dismiss items on your own; only the user can.

**Zero-ambiguity register:** if the systematic review finds ZERO ambiguities, the register file is STILL created and saved to disk with header `✅ GATE PASSED — 0 ambiguities identified (systematic review completed)`. This proves the gate was executed.

## No-Deferral Policy

Deferrals and delegations are NOT permitted. Every ambiguity must be resolved
with a concrete decision before the gate opens.

**If the user says "I don't know" / "decide later":**
1. **Explain** why the decision matters and what happens if it's wrong.
2. **Present** the options with clear trade-offs and consequences.
3. **Recommend** an option with rationale (you CAN recommend — you CANNOT decide).
4. **Guide** the user to an explicit choice.
5. **Record** the user's choice — not your recommendation.

**If the user says "you decide" / "I trust you, just pick one":**
1. **Refuse politely** — "I can recommend, but the decision must be yours."
2. **Present** the options with your recommendation clearly marked.
3. **Wait** for the user to explicitly say "I choose [option]".
4. **Record** the user's explicit choice — never "AI decided" or "delegated to AI".

The user MUST make the call. Delegation to the AI is not permitted.

## Register Persistence

Saved as a permanent file alongside the RDs:

- **Location:** `requirements/00-ambiguity-register.md`
- **Purpose:** audit trail — every decision in every RD is traceable to this register.
- **Survives interruptions:** the register persists on disk even if the session ends mid-authoring.

## Traceability Requirement

Every decision in the final RDs MUST include a back-reference to the register
entry that resolved it:

```markdown
> **Decision per AR #7:** User chose Option B — JWT-based authentication with 24-hour token expiry.
```

This creates an unbroken chain: **user question → user answer → register entry → RD document**.

**The ONLY items exempt from AR # back-references:**
- **(a)** Universally obvious facts with exactly one possible interpretation (e.g., "TypeScript files use `.ts`").
- **(b)** Formatting choices with zero semantic impact (markdown syntax, whitespace, line breaks).

**When in doubt, it is NOT an exception — add it to the register.** Never
classify a decision as "obvious" to avoid the register. If you hesitate even
briefly about whether something is obvious, it goes in the register.

## Surface-During-Authoring Rule

Even after the gate passes, if you discover **NEW ambiguities** while writing RDs
in Phase 3:

1. **STOP writing immediately** — do not finish the current paragraph, sentence, or bullet.
2. **Add** the new ambiguity to the register with the next sequential number.
3. **Present** it to the user with options and trade-offs.
4. **Wait** for the user's explicit decision.
5. **Record** the resolution.
6. **Only then** resume writing.

This is NOT optional. Never "make a reasonable choice and move on." Every new
ambiguity, no matter how small, goes through the register.

## Interaction with the grill_me skill

Phase 2B fires **regardless** of how Phase 1 was conducted — including when the
grill_me skill ran before make_requirements. The grill-me shared understanding
feeds INTO the register as pre-resolved context but does NOT replace the formal
gate. Still systematically scan all 12 categories and compile the register. Items
already settled via grill-me get recorded as `✅ Resolved` with a note
referencing the grill-me session.

## Interaction with upgrade (the upgrade_plan skill)

When requirements are upgraded (upgrade_requirements), the gate applies to any
**new decisions** introduced during the upgrade. Existing resolved decisions from
the original register are preserved; only new or changed items go through the gate.
