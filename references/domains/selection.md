# Domain selection

> **CodeOps Skills Version**: 3.13.0

Before requirements discovery, specification preflight, design interrogation, or archaeology,
classify the system from repository evidence and stated intent. Select **every** domain whose
evidence appears — complex systems commonly need several.

## Evidence → domain

| Evidence | Domain |
|---|---|
| Grammar, parser, IR, optimizer, type checker, evaluator, query planner, protocol codec | `compiler-and-language` |
| Money, balances, invoices, payments, pricing, tax, ledger, reconciliation | `financial-system` |
| Browser UI, HTTP API, sessions, roles, tenant resources | `web-application` |
| Threads, workers, queues, events, replicas, workflows, caches, multiple nodes | `distributed-and-concurrent` |
| Persistent schema, migration, backfill, import/export, retention, serialized artifacts, durable caches, format evolution, mixed-version compatibility | `data-and-migration` |

## Two rules that decide most hard cases

**Domains are additive.** Selecting several is the normal outcome, not a hedge — a financial web
service with background workers and a schema commonly needs four. The universal CodeOps ambiguity
categories always apply on top. Domains **add** questions; they never replace scope, actors,
failure behavior, security, quality attributes, traceability, or verification.

**Compatibility language is evidence, not decoration.** If any existing artifact, database row,
cache entry, message, module, or client must keep working after a change, select
`data-and-migration` and make the version boundary, upgrade or invalidation path, rollback
behavior, and mixed-version window required questions. An artifact does not have to be a database
row for evolution semantics to matter — a serialized cache, an on-disk format, and a wire message
all evolve.

## Runtime protocol — detect, present, confirm

1. **Gather evidence** — manifests, directory names, dependency lists, existing code, stated intent.
2. **Classify** — select every domain whose evidence row matches.
3. **Present** — the selection, the evidence behind each domain, and what was considered and
   rejected. Name the evidence, not just the conclusion.
4. **Confirm** — the user adds or removes; then proceed.
5. **Record** — the selected domains and their evidence, durably, so a later reader can see why a
   given question set was asked.
6. **Re-evaluate** — when discovery reveals a further domain, surface the change and the questions
   it newly requires. Never apply it silently.

Step 3 exists because the selection governs which questions get asked for an entire session. A
missed `distributed-and-concurrent` silently costs every concurrency question, and no one notices
what was never asked. One confirmation at the top of a long interview is cheap against that.

## When nothing matches

Say so plainly, name what was searched, and proceed with the universal categories alone. Do not
reach for the nearest-looking domain to avoid an empty selection — a wrong domain adds the wrong
questions and lends them false authority.

## When the evidence is mixed or weak

Present the competing evidence and let the user decide. Picking the most likely reading silently is
the one move this protocol exists to prevent.

## Pinning

A repository whose domains are stable may pin them with the `domains:` quality-profile key, which
skips detection. It pins only — it can never disable classification.
