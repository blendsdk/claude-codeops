# Zero-Ambiguity Gate (Phase 1C) — Full Protocol

This is the most important quality gate in the planning process. Read it before writing any plan document. It MUST be passed before ANY document in `plans/<feature-name>/` is created — no exceptions, no overrides, no "good enough" thresholds.

## Why this gate exists

Plans built on ambiguity produce implementations built on guesswork. When you guess, the user gets code they didn't ask for, behaviors they didn't expect, and architectures they didn't choose. Every item in every plan document must trace back to an **explicit, user-confirmed decision**. If you cannot point to a specific user answer for a design choice, technical detail, behavioral spec, edge case, or scope boundary, you have failed this gate.

## The Ambiguity Register

Before Phase 2, compile and present an **Ambiguity Register** — a formal, numbered inventory of every identified gap, ambiguity, unstated assumption, undefined behavior, and open question. Hunt systematically across ALL of these categories:

| Category | What to look for |
|----------|-----------------|
| **Feature gaps** | Features mentioned but not fully specified, unclear interactions, undefined workflows |
| **Behavioral gaps** | Undefined "what happens when…" scenarios, missing error handling, unspecified state transitions |
| **Scope ambiguities** | Features that could go either way, unclear in/out-of-scope boundaries |
| **Technical unknowns** | Undecided architecture/technology, unresolved implementation approaches |
| **Edge cases** | Boundary conditions, failure modes, concurrent access, empty/null states, overflow |
| **Integration points** | Unclear interfaces, undefined API contracts, missing data-flow specs |
| **Data & state** | Unclear data models, undefined ownership, missing validation rules, unspecified formats |
| **Security & compliance** | Unaddressed threat vectors, undefined auth flows, missing data-protection decisions |
| **Non-functional gaps** | Missing performance targets, undefined scalability, unspecified availability |
| **UX & presentation** | Undefined user-facing text, missing error messages, unspecified display formats, unclear navigation |
| **Stakeholder conflicts** | Competing needs between user types, unresolved priority disputes, unclear permission boundaries |
| **Naming & terminology** | Unconfirmed file names, directory structures, class/function names, API paths, inconsistent domain terms |

### Register template

```markdown
## Ambiguity Register: [Feature Name]

> **Status**: ❌ GATE BLOCKED — [X] items unresolved
> *(When all resolved, change to: ✅ GATE PASSED — all [X] items resolved)*
> **Last Updated**: [Date]

| # | Category | Ambiguity / Gap | Options Presented | User Decision | Status |
|---|----------|-----------------|-------------------|---------------|--------|
| 1 | Behavioral | [Specific ambiguity] | [Option A / B / C] | [User's answer] | ✅ Resolved |
| 2 | Scope | [Specific ambiguity] | [Option A / B] | — | ❌ Open |

### Resolution Notes

**AR-1:** [Expanded context if needed]
**AR-2:** [Pending — presented to user, awaiting answer]
```

## Gate enforcement rules

**🚫 PROHIBITED while the gate is blocked:**

- ❌ Create any plan document (`00-index.md`, `01-requirements.md`, etc.)
- ❌ Write any technical specification
- ❌ Define any task in an execution plan
- ❌ Make any design decision on the user's behalf
- ❌ Use phrases like "we'll assume…", "by default…", "a reasonable approach would be…"
- ❌ Proceed with a partially resolved register

**✅ The gate opens ONLY when ALL are true:**

1. ✅ Every row has Status = `✅ Resolved`
2. ✅ Every resolution contains the **user's explicit decision** (not your recommendation accepted by silence)
3. ✅ The user has reviewed and confirmed the complete register (for >15 items, present in batches by category — the user confirms each batch, then gives a final confirmation: "I have reviewed and confirmed all [X] items")
4. ✅ Zero items deferred — every item has a concrete answer ("figure it out later" is NOT accepted; explain the consequences and guide the user to a decision NOW)
5. ✅ The header reads `✅ GATE PASSED — all [X] items resolved`

**User dismissals:** If the user says "that's not ambiguous, the answer is obviously X," that IS a valid resolution — record it as `✅ Resolved — User: "[their stated answer]"`. You cannot dismiss items yourself; only the user can.

**Zero-ambiguity register:** If the review finds ZERO ambiguities, still create and save the register with header `✅ GATE PASSED — 0 ambiguities identified (systematic review completed)`. This proves the gate was executed.

## No-deferral policy

Deferrals and delegations are NOT permitted. Every ambiguity must be resolved with a concrete decision before the gate opens.

**If the user says "I don't know" / "decide later":** (1) explain why the decision matters and the cost of getting it wrong, (2) present options with trade-offs, (3) recommend an option with rationale (you CAN recommend), (4) guide them to an explicit choice, (5) record THEIR choice — not your recommendation.

**If the user says "you decide" / "just pick one":** (1) politely refuse — "I can recommend, but the decision must be yours," (2) present options with your recommendation marked, (3) wait for "I choose [option]", (4) record their explicit choice — never "AI decided."

## Register persistence

Saved as a permanent file: `plans/[feature-name]/00-ambiguity-register.md`. It is the audit trail — every decision in every plan document traces to it — and it survives crashes mid-planning.

## Traceability requirement

Every decision in the final plan documents must include a back-reference to the register entry that resolved it:

```markdown
> **Decision per AR #7:** User chose Option B — time-based cache invalidation with 5-minute TTL.
```

This creates an unbroken chain: **user question → user answer → register entry → plan document.**

The ONLY items exempt from `AR #` back-references are: **(a)** universally obvious facts with exactly one possible interpretation (e.g., "TypeScript files use `.ts`"), and **(b)** formatting choices with zero semantic impact (markdown syntax, whitespace). **When in doubt, it is NOT an exception — add it to the register.** Never classify a decision as "obvious" to avoid the register; if you hesitate even briefly, it goes in.

## Surface-during-authoring rule

Even after the gate passes, if you discover a NEW ambiguity while writing plan documents in Phase 2:

1. **STOP writing immediately** — do not finish the current sentence or bullet.
2. **Add** it to the register with the next sequential number.
3. **Present** it to the user with options and trade-offs.
4. **Wait** for the user's explicit decision.
5. **Record** the resolution.
6. **Only then** resume writing.

This is not optional. Never "make a reasonable choice and move on."

## Interaction with the grill_me skill

Phase 1C fires regardless of how Phase 1 was conducted — including when the grill_me skill ran first. The grill_me shared understanding feeds INTO the register as pre-resolved context but does NOT replace the formal gate. Still scan all 12 categories and compile the register; items already settled by grill_me are recorded as `✅ Resolved` with a note referencing that session.

## Interaction with the upgrade_plan skill

When plans are upgraded via the upgrade_plan skill, the gate applies to any **new** decisions introduced during the upgrade. Existing resolved decisions from the original register are preserved; only new or changed items go through the register.
