# Auto-Design Authority Policy (shared convention)

> **CodeOps Skills Version**: 3.17.0
> **Policy version**: 1

`--auto-design` delegates eligible **technical** design decisions to CodeOps for one workflow
chain. It preserves ambiguity closure: it changes **who may resolve** an eligible ambiguity, never
whether the ambiguity must be found, recorded, traced, challenged, and verified.

This file is the single owner of the policy. The four supported skills link here and never restate
it — a rule that exists in two places is a rule that will eventually disagree with itself.

## Invocation contract

Only **exactly one standalone token** `--auto-design`, appearing before the first `--`
end-of-options sentinel, activates this policy.

| Arguments contain | Mode |
|-------------------|------|
| Zero occurrences before the sentinel | **Default mode** |
| Exactly one standalone token before the sentinel | **Auto-design mode** |
| More than one standalone token before the sentinel | **Invalid** — stop with a usage correction |

A token **at or after the sentinel is target content**, not an option, so a feature or path
literally named `--auto-design` still resolves as a target. Lookalikes never activate the policy:
`--auto-designer`, `--auto-design=true`, and bare `auto-design` (no leading dashes) are ordinary
arguments.

A supporting skill **removes the one recognized token before resolving** feature names, paths,
targets, or other options, announces activation in-session before any delegated decision is made,
and assigns a root invocation ID for the chain.

The strictness is the point. This token is the only thing standing between a typo and delegated
design authority, so it is matched exactly or not at all — there is no fuzzy match, no
abbreviation, and no attempt to infer intent from something close to it. An invalid invocation
stops rather than guessing which reading the user meant.

### Downward-only propagation

An explicitly invoked **supported** child inherits:

```text
mode: auto-design
root invocation ID: <stable ID for this workflow chain>
parent workflow: <invoking supported workflow>
policy version: 1
delegated categories: <parent's eligible classes, or a strict subset>
reserved categories: <the complete reserved set>
permission state: <unchanged action and commit permissions>
```

A child may **narrow** authority, never widen it. An **unsupported child fails closed** and uses
normal authority rules.

### The mode is never persisted

There is no repository setting, no global default, and no quality-profile key that grants or
refuses this mode. A later independent invocation is in Default mode unless its own arguments
contain the token. Historical delegated records **confer no standing authority** — a record that a
decision was once delegated is evidence about that decision, never permission for the next one.

Invocation scope is the whole containment story for this feature. A configuration key would make a
shared repository permanently delegated for everyone who works in it, including people who never
chose it, and the record-as-precedent habit would arrive at the same place more slowly.

## Default mode

Without the token, behavior is unchanged: every material semantic choice requires an explicit user
decision or an explicit named deferral.

## Eligibility boundary

CodeOps may decide only when the choice:

- stays within confirmed goals, product behavior, scope, constraints, and acceptance criteria;
- concerns an implementation **mechanism**;
- contradicts no user decision or governing artifact; and
- creates no reserved-authority consequence.

**Eligible classes:** algorithms; data structures; internal architecture and interfaces; compiler
and optimizer mechanisms; failure and recovery design; concurrency and consistency; persistence and
reversible migration mechanisms; security mechanisms *within an already-approved policy*; testing
strategy; performance engineering; implementation sequencing.

## Reserved authority

**Always escalate to the user**, in every commit mode, whatever the delegation:

- product behavior or scope
- priorities and acceptance criteria
- access and security policy
- data ownership or retention
- legal, ethical, compliance, or risk acceptance
- financial exposure
- budget and deadline commitments
- paid-vendor choices
- public compatibility breaks
- destructive migration
- credentials
- spending
- deployment or publication
- destructive or irreversible external actions
- external communication
- **equally defensible designs that create materially different products**

That last one is the easiest to talk yourself past. When two options are both sound and the choice
is really about what the product becomes, the tie is not yours to break, and the fact that it is a
tie is exactly why the user has to see it.

### It grants no action permission

`--auto-design` **does not grant action permission**. It does not authorize implementation outside
the invoked workflow, file-scope expansion, commits, pushes, `--auto-commit`, installation,
purchases, deployment, publication, destructive operations, credential use, or external-system
changes. Delegated design and permission to act are independent axes and stay that way.

## Strongest-option procedure

1. Gather repository evidence, domain knowledge, constraints, and failure conditions.
2. Generate every genuinely viable option, actively searching for a non-obvious alternative. When
   only one survives the evidence, name the rejected candidates and why — never invent a strawman
   to manufacture a comparison.
3. Apply forced reframing: 10× budget, contrarian expert, obsolescence, pre-emptive challenge.
4. Compare on correctness, soundness and safety, objective fit, maintainability, verifiability,
   performance, compatibility, operational recovery, delivery risk, proportional complexity, and
   future evolution.
5. State the strongest counterargument and set confidence.
6. Require a **blind independent challenger** — the `design-challenger` agent, per
   `recommendation-hardening.md` — for complex, sensitive, high-impact, or hard-to-reverse choices.
   Material divergence, an unavailable required review, or insufficient confidence triggers bounded
   escalation. It never silently accepts or waives risk.
7. Select the best-supported option. **Strongest means most likely to make the whole project
   succeed** — not the most sophisticated design.

## Durable resolution

Every delegated resolution is recorded in the **owning** ambiguity or decision artifact:

```text
Authority: AI — delegated by --auto-design
Eligibility: <class and boundary rationale>
Objective: <governing success objective>
Decision: <selected option>
Evidence: <repository/domain facts and constraints>
Rejected alternatives: <viable alternatives and why not>
Strongest counterargument: <best case against the choice>
Confidence: High | Med | Low — <what would change it>
Hardening: <result and challenger verdict when required>
Policy version: 1
Root invocation ID: <ID>
Reopen triggers: <observable invalidation conditions>
```

The canonical delegated marker may occupy an existing `User Decision` column, so existing registers
keep their shape. Do **not** create a parallel decision database and do not duplicate rationale
into traceability — one owning artifact per decision, as everywhere else in CodeOps.

## Bounded escalation

Research and challenge first. Then, if the choice is reserved, constraints conflict, material
evidence is unavailable, concerns cannot be separated, or no option is defensible, **stop once per
root cause** with:

- the exact decision that is blocked,
- the boundary or evidence failure behind it,
- the strongest available recommendation, and
- the minimum user input needed to proceed.

Never guess, and never loop over the same evidence hoping for a different reading. One stop per
root cause is what keeps escalation useful rather than a stream of interruptions.

## Invalidation

When new evidence breaks an assumption, or a recorded reopen trigger fires: reopen the owning
decision, mark the affected downstream specifications, tests, tasks, implementation, and
verification **stale**, repeat this policy, and re-run the applicable gates.

## Supported workflows

The allowlist is closed: `make_requirements`, `make_plan`, `preflight`, and `exec_plan`. Adding a
workflow requires specification coverage and deterministic integration checks, not merely a link
to this file.
