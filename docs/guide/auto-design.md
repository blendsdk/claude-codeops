# Delegated technical design

CodeOps normally stops for every material semantic choice. That is right for product scope and
risk, and expensive for implementation mechanism — being asked to pick a data structure or a retry
strategy, when the answer needs nothing you know and the system doesn't.

`--auto-design` delegates the second kind for one workflow chain, and only the second kind.

```bash
/codeops:exec_plan billing --auto-design
```

It changes **who may resolve** an eligible ambiguity. It never changes whether the ambiguity must
be found, recorded, challenged, and verified. Nothing is skipped; the register still fills up.

::: danger Read this before using it unattended
This feature carries two risks that were weighed and accepted, not overlooked. They are stated
plainly in [Accepted risks](#accepted-risks) below. If you run `--auto-design --auto-commit`
unattended on a repository you share with other people, read that section first.
:::

## What it may decide

Only when the choice stays inside confirmed goals, scope, constraints, and acceptance criteria;
concerns an implementation **mechanism**; contradicts no decision you already made; and creates no
reserved consequence.

Algorithms · data structures · internal architecture and interfaces · failure and recovery design ·
concurrency and consistency · reversible migration mechanisms · security mechanisms *inside a
policy you already approved* · testing strategy · performance engineering · implementation
sequencing.

## What it never decides

These always stop for you, in every commit mode:

Product behavior or scope · priorities and acceptance criteria · access and security **policy** ·
data ownership or retention · legal, ethical, compliance, or risk acceptance · financial exposure ·
budget and deadline commitments · paid-vendor choices · public compatibility breaks · destructive
migration · credentials · spending · deployment or publication · destructive or irreversible
external actions · external communication.

And one more that is easy to argue past: **equally defensible designs that create materially
different products**. When two options are both sound and the real question is what the product
becomes, the tie is not CodeOps' to break — the fact that it *is* a tie is exactly why you need to
see it.

## It grants no permission to act

`--auto-design` and commit mode are independent axes. The flag does not authorize implementation
outside the invoked workflow, file-scope expansion, commits, pushes, `--auto-commit`, installation,
purchases, deployment, publication, destructive operations, credential use, or any external-system
change.

## The token is matched exactly

Exactly one standalone `--auto-design` before the first `--` sentinel activates it.

| You typed | Result |
|-----------|--------|
| `billing` | Normal mode |
| `--auto-design billing` | Delegated; the token is removed, target is `billing` |
| `--auto-design --auto-design billing` | **Stops** with a usage correction — never guesses which you meant |
| `-- --auto-design` | Normal mode; `--auto-design` is a target name |
| `--auto-designer`, `--auto-design=true`, `auto-design` | Normal mode — none of these activate it |

There is no fuzzy match and no abbreviation. This token is the only thing between a typo and
delegated authority, so a near-miss is treated as an ordinary argument rather than as an intention
to be inferred.

## Scope: one invocation, and no further

**There is no setting for this.** No repository key, no global default, nothing in the quality
profile. A later run is in normal mode unless its own arguments carry the token, and a record that
a decision was once delegated is evidence about *that* decision — never standing permission for the
next one.

A supported child workflow inherits the mode and may **narrow** it, never widen it. An unsupported
child fails closed to normal authority; only that branch drops, and the parent chain is unaffected.

## Every delegated decision is on the record

The resolution is written into the artifact that owns the decision — the ambiguity register, in its
`User Decision` column — with the authority marker, why it was eligible, the evidence, the
alternatives rejected and why, the strongest argument *against* the choice, a confidence level,
the challenger's verdict where one was required, and the observable conditions that should reopen
it.

There is no second database. A delegated resolution sits beside your own decisions, visibly
distinguishable from them.

High-impact, complex, or hard-to-reverse choices additionally require a blind independent
challenger. If that review is unavailable, or diverges materially, or confidence is insufficient,
the run escalates to you — it never quietly proceeds.

## Findings are resolved, never waived

Under active auto-design, a 🔴 CRITICAL or 🟠 MAJOR review finding may be **resolved** by choosing
and implementing an eligible technical fix, then re-reviewing the fix once.

It may never be waived, dismissed, downgraded, or re-scoped. There is no "accepted risk" path here:
the only two outcomes are a fix that survives re-review, or an escalation to you.

## Accepted risks

Two, stated as they were accepted:

**An unattended `--auto-design --auto-commit` run can fix a CRITICAL security finding without your
prior review.** The fix is implemented, verified, re-reviewed, and recorded — but you see it
afterwards, not before. An alternative where CRITICAL findings always pause was considered and
declined, because it would have made the flag useless for the long unattended runs it exists for.
If that trade is wrong for your repository, do not combine the two flags.

**A shared repository cannot refuse the flag.** Because there is no configuration key, there is
also no way for a repo to opt out — the only control is operator discipline. This is the direct
cost of the no-persistence guarantee that keeps the mode from ever becoming ambient, and it
compounds the first risk on repositories where more than one person runs CodeOps.

What holds regardless: the reserved-authority list, the no-waiver rule, mandatory re-review of fix
diffs, the durable provenance record, and the independent challenger on high-impact choices. None
of those are weakened by either flag.
