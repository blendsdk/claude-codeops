# Distributed and concurrent

> **CodeOps Skills Version**: 3.14.0

Select this domain for multiple threads, processes, or nodes; queues, actors, workflows, replicated
state, caches, background jobs, and asynchronous integrations.

## Concurrency and failure checklist

- State ownership, mutation authority, synchronization, and atomicity boundaries
- Ordering guarantees per key, partition, stream, request, and observer
- Delivery semantics, deduplication, idempotency, replay, and poison-message behavior
- Consistency model, visibility, stale reads, conflict resolution, and convergence
- Transactions across resources: outbox and inbox, sagas, compensation, and orphan recovery
- Timeout, cancellation, deadline propagation, retries, backoff, jitter, and retry budgets
- Leader election, leases, fencing tokens, split brain, and clock assumptions
- Backpressure, admission control, queue bounds, overload, fairness, and starvation
- Deadlock, livelock, and race prevention; safe shutdown
- Partial availability, dependency degradation, circuit breaking, and health semantics
- Schema and protocol evolution with mixed-version participants
- Observability and correlation sufficient to reconstruct a distributed outcome

## Required interleavings

Specify and test at least: concurrent duplicate requests, a read during a write, failure before
and after durable commit, a timeout leaving the outcome unknown, a retry landing on a different
node, reordered delivery, a delayed stale worker, partition and heal, cancellation during a side
effect, and a rolling mixed-version deployment.

## Gate

The gate fails when correctness relies on unstated timing, a single delivery, synchronized clocks,
failure-free dependencies, or process-local state that is not process-local in deployment.
