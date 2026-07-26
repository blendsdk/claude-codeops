# Domain classification fixtures

Four miniature repositories, each built so that the domain selection rubric has exactly one
defensible answer. They exist to check classification behavior, which no structural guard can
reach: `validate.sh` can prove the rubric and its files are well-formed, but only a run can show
that the rubric actually decides these cases the way it claims to.

| Fixture | Planted evidence | Expected selection |
|---------|------------------|--------------------|
| `mixed-service` | Double-entry postings and reconciliation, an Express HTTP API with sessions, a BullMQ queue consumer | `financial-system`, `web-application`, `distributed-and-concurrent` |
| `serialized-format` | An on-disk snapshot format with an in-band version and a stated cross-release readability contract | `data-and-migration` |
| `language-tool` | An EBNF grammar with precedence tiers, and a type checker inferring over an AST | `compiler-and-language` |
| `plain-utility` | Three pure string transforms, no I/O, no state, no manifest | *(none)* |

`mixed-service` is deliberately multi-domain: the additive rule is the one most likely to be lost
in a rewrite, and a fixture that only ever needs a single domain would not notice.
`plain-utility` is the negative case — the rubric must be willing to select nothing rather than
reach for the nearest-looking domain.

## Running them

Classification reads the rubric from the plugin, so the rubric's directory has to be readable from
the fixture's working directory:

```bash
ROOT=$(pwd)
cd scripts/fixtures/domain-repos/mixed-service
claude -p --no-session-persistence --permission-mode dontAsk \
  --tools Read,Glob,Grep --add-dir "$ROOT/references" --plugin-dir "$ROOT" \
  "Read $ROOT/references/domains/selection.md, then classify this repository with it."
```

Without `--add-dir`, the rubric is unreadable and the run will invent its own domain vocabulary
instead — plausible-looking names that match no enum value. A run that cannot cite the rubric is
not evidence about the rubric, so check that its output uses canonical ids before believing it.

## Observed behavior

Each fixture was run at high effort against the working tree. All four selected exactly the
expected domains using canonical ids, and each cited the planted evidence file-by-file.
`plain-utility` selected nothing and listed what it had searched, rather than picking a
near-miss.

Re-evaluation — surfacing a domain that discovery reveals after the initial selection — is
conversational and has no fixture. It is carried by the rubric's protocol and by each wiring
point, all of which state that a later domain is surfaced with the questions it newly requires
and never folded in silently.
