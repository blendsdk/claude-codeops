# Data and migration

> **CodeOps Skills Version**: 3.13.0

Select this domain for persistent schemas, imports and exports, migrations, indexing, backfills,
retention, and data-model changes — and whenever an existing artifact must keep working across a
change.

## Data lifecycle checklist

- Entity identity, ownership, cardinality, constraints, nullability, uniqueness, and invariants
- Canonical representation, normalization and denormalization, units, encoding, and precision
- Create, update, delete, archive, and restore lifecycle; referential behavior
- Transaction and isolation requirements; concurrent writers and readers
- Query access patterns, indexes, scale assumptions, and performance bounds
- Sensitive-data classification, encryption, access, masking, retention, deletion, and audit
- Schema versioning and compatibility across application versions
- Migration preconditions, online or offline mode, locks, batching, throttling, and checkpoints
- Backfill correctness, resumability, idempotency, validation, and repair
- Rollforward, rollback, irreversible steps, backups, restore proof, and disaster recovery
- Import validation, duplicate and collision rules, partial files, and provenance
- Derived data, cache, and index rebuild, with consistency checks

## Gate

The gate fails until every migration has measurable pre- and postconditions, bounded operational
impact, resumable and idempotent behavior, verification, and a recovery path proportionate to its
irreversibility and the criticality of the data.
