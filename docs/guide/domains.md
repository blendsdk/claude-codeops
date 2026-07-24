# Domains

CodeOps used to ask the same requirements questions no matter what you were building. A compiler, a
ledger, and a multi-tenant web app all got the same universal sweep — thorough, but blind to the
traps specific to each.

**Domains** fix that. Before discovery starts, CodeOps classifies your system from repository
evidence and loads the question sets that match it.

## Domains are not lenses

These are two different things with unfortunately similar shapes. The distinction matters enough
that a build guard enforces it.

| | **Domains** | **Lenses** |
|---|---|---|
| Answer the question | *What kind of system is this?* | *What should a reviewer look for in this diff?* |
| Chosen by | Repository evidence, automatically | You, in the quality profile |
| Run when | Always | Only with an active quality profile |
| Affect | Which questions get asked, before any code exists | Which concerns a phase reviewer applies, after code is written |
| Live in | `references/domains/` | `agents/phase-reviewer.md` |

A rough rule: domains shape the **questions**, lenses shape the **review**. If you are reading
about something that happens before requirements exist, it is a domain.

## The five domains

| Domain | Selected when your system… |
|--------|---------------------------|
| `compiler-and-language` | Has formal transformation semantics — grammar, parser, IR, type checker, query planner, protocol codec |
| `financial-system` | Records, calculates, authorizes, transfers, reconciles, reports, or audits monetary value |
| `web-application` | Serves a browser UI, HTTP API, or mobile backend, with sessions, roles, or tenant resources |
| `distributed-and-concurrent` | Runs across threads, workers, queues, replicas, or nodes, or integrates asynchronously |
| `data-and-migration` | Owns a persistent schema or serialized format, migrates it, or must keep an existing artifact working |

## Selecting several is normal

Domains are **additive**. A billing service with an HTTP API and background workers selects three,
and that is the right answer — not a hedge. The universal ambiguity categories still apply on top:
domains **add** questions and never replace scope, actors, failure behavior, security, quality
attributes, traceability, or verification.

The one that gets missed most often is `data-and-migration`. It is not only for databases. If any
existing artifact — a cache entry, a message, a serialized file, a client — has to keep working
after your change, that is the domain, and the version boundary, upgrade path, rollback behavior,
and mixed-version window become required questions.

## What you will see

Classification is **detect, present, confirm**:

```
Domains detected: financial-system, web-application, distributed-and-concurrent

  financial-system            src/ledger/postings.js — double-entry postings,
                              balances sum to zero; decimal.js for money arithmetic
  web-application             express; src/routes/invoices.js — session-gated routes
  distributed-and-concurrent  bullmq; src/workers/settlement.js — queue consumer

  Considered and rejected: data-and-migration — no schema, migration, or
  serialized format found

Add or remove any before I start?
```

You get the evidence, not just the conclusion, and you can amend it. This is deliberate: the
selection governs which questions get asked for the whole session, and nobody notices the questions
that were never asked. If discovery later turns up another domain, CodeOps surfaces the change
rather than folding it in quietly.

When nothing matches, it says so and names what it searched, rather than reaching for the
nearest-looking domain.

## Where it runs

| Skill | When |
|-------|------|
| `make_requirements` | Before discovery — domain questions join the sweep |
| `preflight` | Before the 13-dimension scan — the audit inherits domain questions |
| `grill_me` | Before the design tree — interrogation gains domain branches |
| `retro_requirements` | Before archaeology — reverse-engineering asks domain-appropriate questions |

## No opt-in required

Classification runs for every repository, with or without a `CODEOPS-QUALITY` block. It sits
outside the profile's absence rule because it dispatches no agent and emits no telemetry — the two
things that rule governs. Gating it behind opt-in would deny it to everyone who never opts in.

## Pinning a stable selection

If your repository's domains never change, pin them and skip detection:

```yaml
domains: [financial-system, web-application]
```

The key can only **pin**. There is no value that turns classification off.

An unrecognized name is warned about once and dropped; the rest of the list still applies, in
keeping with how every other profile key is parsed.
