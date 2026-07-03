# Phase 3 — Quality Checklist

Run this before finalizing the plan documents. The **Specification-First Testing**, **Security-First**, **Zero-Ambiguity**, and **Execution Plan Completeness** blocks are NON-NEGOTIABLE.

## ✅ Completeness
- [ ] All requirements captured
- [ ] All affected components identified
- [ ] All scope decisions documented
- [ ] All dependencies mapped

## ✅ Granularity
- [ ] Each task is one reviewable change: 1-3 files, ~50-150 lines, immediately testable
- [ ] Anything touching >=6 files, 200+ lines, or 3+ concerns is SPLIT into multiple tasks
- [ ] Each task has clear deliverables
- [ ] Each task is independently testable

## ✅ Dependencies
- [ ] Phase dependencies documented
- [ ] Task dependencies documented
- [ ] No circular dependencies
- [ ] Dependency order is logical

## ✅ Testing
- [ ] Every component has test requirements
- [ ] E2E tests planned
- [ ] Test coverage goals defined

## ✅ Specification-First Testing — 🚨 NON-NEGOTIABLE
- [ ] `07-testing-strategy.md` contains the `🚨 Specification Test Cases` section with concrete ST-cases
- [ ] Every ST-case has concrete input → expected output pairs (not just test names/descriptions)
- [ ] Every ST-case traces to a requirement, spec document, RFC, or AR entry
- [ ] ST-case expectations are derived from specification documents, NOT from imagined implementation behavior
- [ ] `99-execution-plan.md` follows the three-phase task ordering: spec tests → implementation → impl tests
- [ ] Spec test tasks reference ST-cases from `07-testing-strategy.md`
- [ ] Spec test and impl test files use separate naming conventions (`*.spec.test.*` and `*.impl.test.*`)
- [ ] A red-phase verification task exists in the execution plan (verify spec tests fail before implementation)

## ✅ No Dead Code
- [ ] No unused parameters (except interface contracts, overrides, and framework-required signatures)
- [ ] No unused functions, classes, or modules
- [ ] No unreachable code or commented-out blocks
- [ ] Language-specific dead code tooling enabled (if available)

## ✅ Security-First — 🚨 NON-NEGOTIABLE
- [ ] All user input validated and sanitized server-side
- [ ] Injection prevention addressed (SQL, XSS, command injection, path traversal)
- [ ] Authentication & authorization properly designed
- [ ] Rate limiting planned for public and authentication endpoints
- [ ] No hardcoded secrets or credentials — secrets management strategy defined
- [ ] Sensitive data encrypted at rest and in transit
- [ ] Error responses expose no internal details (no stack traces, no DB schemas)
- [ ] Infrastructure hardened (non-root containers, minimal base images, no secrets in images/CI)
- [ ] Security test cases included in the testing strategy

## ✅ Zero-Ambiguity (per Phase 1C) — 🚨 NON-NEGOTIABLE
- [ ] Ambiguity Register (`00-ambiguity-register.md`) exists and is saved to disk
- [ ] Every register entry has Status = `✅ Resolved` with an explicit user decision
- [ ] Zero deferred items — every ambiguity has a concrete answer
- [ ] All decisions in plan documents have AR # back-references (only exceptions: universally obvious facts + zero-semantic-impact formatting)
- [ ] No plan document contains AI-assumed defaults, inferred behaviors, or guessed specifications
- [ ] Surface-during-authoring rule was followed — new ambiguities discovered during writing were added to the register and resolved with the user

## ✅ Execution Plan Completeness — 🚨 NON-NEGOTIABLE
- [ ] `99-execution-plan.md` contains the `🚨 Master Progress Checklist (All Phases) — MANDATORY` section
- [ ] The Master Progress Checklist lists ALL tasks from ALL phases (no tasks omitted)
- [ ] The Master Progress Checklist includes the embedded execution rule block instructing agents to update it
- [ ] Every task in the checklist matches the task tables in the phase sections (consistent numbering and descriptions)

## ✅ Format
- [ ] All documents follow the templates
- [ ] Tables are properly formatted
- [ ] Task numbers follow the convention (Phase.Session.Task)
- [ ] Checkboxes included for tracking
- [ ] `00-index.md` and `99-execution-plan.md` are stamped with `> **CodeOps Skills Version**: 3.2.0`
