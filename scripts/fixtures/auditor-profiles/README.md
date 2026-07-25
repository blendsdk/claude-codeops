# Auditor activation fixtures

Three repositories whose only meaningful content is a quality-profile block. They exist to answer
one question behaviorally: given a profile shape and a code-touching phase, does the written
convention actually lead to the right set of dispatches and the right stand-downs?

Activation is prose, spread across `_shared/quality-profile.md` and
`skills/exec_plan/execution-protocol.md`. A structural guard can confirm the words are present; it
cannot confirm they lead a reader to the right answer. That is what these fixtures measure.

| Fixture | Profile | Expected dispatch set |
|---------|---------|-----------------------|
| `lenses-concurrency/` | `lenses: [concurrency]` | phase-reviewer (minus its `concurrency` lens) + concurrency-auditor |
| `security-financial/` | `security_profile: [financial-integrity, owasp-web]` | phase-reviewer (minus `security`) + security-auditor (`owasp-web` only) + financial-integrity-auditor |
| `no-profile/` | *(no block)* | nothing dispatches |

## How to run one

```bash
cd scripts/fixtures/auditor-profiles/<fixture>
claude -p --no-session-persistence --permission-mode dontAsk --tools Read \
  --plugin-dir <plugin-root> --add-dir <plugin-root> --effort high \
  "A CodeOps exec_plan phase has just finished in this repository. The phase diff touches source
   code. List EXACTLY which quality agents dispatch, and for each shared reviewer that dispatches,
   which lenses or checklists it must omit because a specialist supersedes them."
```

`--add-dir` is not optional. A run works from the fixture directory, so without an explicit read
grant the plugin's own conventions are unreadable and the run answers from general knowledge —
producing a well-formed, plausible, and unmeasured result.

## Observed

All three answered exactly to expectation. Two details worth keeping:

- The **no-profile** run ruled the semantics reviewer out for the right reason, naming that it is
  domain-activated but still profile-gated. That is the one rule in this phase a reader could
  plausibly get wrong, since domain classification itself runs unconditionally.
- The **security-financial** run had the security auditor apply `owasp-web` **only**, and said so
  — which is the behavior that makes a withdrawn checklist visible rather than assumed.

## Agent-contract checks

Two agent behaviors were exercised directly, by running an agent's own prompt body against a
constructed packet rather than through a dispatch:

| Case | Packet | Observed |
|------|--------|----------|
| Insufficient packet | concurrency-auditor, phase title and verify result but **no diff** | Refused. Named the diff as the hard blocker, the other two items as precision losses, and said explicitly that findings inferred from a four-word phase title would be fabricated — indistinguishable in form from a real audit |
| Clean phase | financial-integrity-auditor, a 4-line `--help` sorting change | "**Verdict: no findings.**" with a table of every profile invariant and why each is vacuous here |

The clean-phase case took two attempts, and the first one is the more useful record. It used a
diff that added a currency-uniformity guard — intended as clean by construction, since it only
strengthens a check. The auditor returned five findings, and they were real: a batch where every
entry has `currency=None` passes a uniqueness test, an empty batch passes it too, and the total is
returned stripped of the currency the function had just established. None of that was planted.

A "clean" fixture is therefore harder to build than it looks in a domain where the invariants are
this dense. The replacement diff has no reachable path to a posting at all, which is the only
construction that made cleanliness verifiable rather than merely intended.
