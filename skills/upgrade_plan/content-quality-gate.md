# Phase 2B — Content Quality Gate (Reference)

The upgrade_plan skill links here. **Read this before running Phase 2B.** This is a 🚨
NON-NEGOTIABLE HARD GATE 🚨 — Phase 3 (structural upgrades) is BLOCKED until it passes.

## Why this gate exists

Older plans and requirements were often created without the Zero-Ambiguity Gate. They may contain
vague decisions, unstated assumptions, undefined edge cases, missing error handling, ambiguous
acceptance criteria, and AI-guessed specifications. Upgrading the *format* without fixing the
*content* produces a **polished but hollow** artifact. This gate catches and resolves every content
gap before the structural upgrade touches anything.

The principle is identical for both branches: a plan/requirements set that looks modern but
contains vague content is still bad.

## Content scanning protocol — the 12 ambiguity categories

Systematically scan ALL existing documents for content gaps across all 12 categories. The wording
below merges the plan-specific and requirements-specific scan guidance; apply whichever fits the
document you are scanning.

| Category | What to scan for in existing documents |
|----------|----------------------------------------|
| **Feature gaps** | Features mentioned but not fully specified; incomplete component specs; unclear feature interactions; undefined workflows |
| **Behavioral gaps / unknowns** | Missing "what happens when…" scenarios; undefined error handling/states; unspecified state transitions |
| **Scope ambiguities** | Vague scope boundaries; vague MVP-vs-future split; items interpretable multiple ways; undefined "out of scope" |
| **Technical unknowns** | Architecture decisions stated without rationale; unresolved implementation/integration approaches |
| **Edge cases** | Missing boundary conditions; undefined failure modes; unaddressed concurrent-access scenarios |
| **Integration points** | Unclear interfaces between components / external systems; undefined API contracts; missing data-flow specs |
| **Data & state / data-model questions** | Undefined data models or entity relationships; unclear ownership; missing validation rules; unspecified formats/cardinality |
| **Security & compliance** | Missing security section; unaddressed threat vectors; undefined auth flows/models; regulatory gaps |
| **Non-functional gaps** | Missing performance targets; undefined scalability approach; unspecified availability |
| **UX & presentation** | Undefined user-facing text; missing error messages; unspecified display formats |
| **Stakeholder conflicts** | Competing needs between user types; unresolved priority disputes; unclear permission boundaries |
| **Naming & terminology** | Inconsistent naming; undefined terms/jargon; ambiguous labels |

Security requirements expectations follow your project's coding standards (CLAUDE.md).

## Vague-language patterns to flag

Every instance of vague language is a red flag for hidden ambiguity. Flag each one in the register
and resolve it with the user.

```
Vague language to flag: "TBD", "to be determined", "something like", "we could",
"probably", "might", "maybe", "a reasonable approach", "as needed", "if applicable",
"similar to", "standard approach", "best practices", "etc.", "and so on"
```

## Ambiguity Register handling

The register lives at `00-ambiguity-register.md` (for plans, inside `plans/[feature-name]/`; for
requirements, inside `requirements/`).

| Condition | Action |
|-----------|--------|
| Register file **exists** | **Append** new findings, continuing numbering from the last AR #. Tag each with `(upgrade)` in the Category column. |
| Register file does **NOT** exist | **Create** it — this artifact predates the Zero-Ambiguity Gate, so all findings go into a fresh register. |

Upgrade entries are tagged `(upgrade)` to distinguish them from original planning decisions:

```markdown
| 15 | Behavioral (upgrade) | Error handling for [X] was undefined in the original plan | [Option A / B / C] | [User's answer] | ✅ Resolved |
```

## Gate enforcement rules

**🚫 ABSOLUTELY PROHIBITED while the gate is blocked:**

- ❌ Proceed to Phase 3 (structural upgrades)
- ❌ Update version stamps
- ❌ Modify any document content
- ❌ Accept vague language as "good enough"
- ❌ Rationalize with phrases like "the existing approach seems reasonable"

**✅ REQUIRED — the gate opens ONLY when ALL 5 conditions are met:**

1. ✅ Every content gap found has been added to the Ambiguity Register.
2. ✅ Every register entry has Status = "✅ Resolved" with the user's explicit decision.
3. ✅ The user has reviewed and confirmed the complete register (for >15 items, present in batches
   by category).
4. ✅ Zero vague-language patterns remain unresolved.
5. ✅ Zero deferred items — the user must decide NOW (no-deferral, no-delegation policy).

## Content Quality Register template

```markdown
## Content Quality Upgrade: [Feature Name | Requirements]

> **Status**: ❌ GATE BLOCKED — [X] content gaps found
> *(When all resolved, change to: ✅ GATE PASSED — all [X] content gaps resolved)*
> **Last Updated**: [Date]
> **Upgrade From**: [old version or "pre-versioning"]
> **Upgrade To**: 3.0.0

| # | Category | Gap / Ambiguity Found | Source Document | Options Presented | User Decision | Status |
|---|----------|-----------------------|-----------------|-------------------|---------------|--------|
| 1 | Behavioral (upgrade) | [Gap found in existing doc] | `03-component.md` | [Option A / B] | [User's answer] | ✅ Resolved |
| 2 | Security (upgrade) | [Missing security consideration] | `01-requirements.md` | [Option A / B / C] | — | ❌ Open |
```

## After the gate passes

Phase 3 applies structural upgrades AND incorporates the content fixes into the documents. **Every
resolved content gap must be written into the appropriate document with an `AR #` back-reference**,
so the document content and the register stay linked.
