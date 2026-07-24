# Web application

> **CodeOps Skills Version**: 3.13.0

Select this domain for browser applications, HTTP APIs, mobile backends, and user-facing network
services.

## Behavior and boundary checklist

- Actors, roles, tenant boundaries, resource ownership, the authorization matrix, and
  administrative exceptions
- Authentication, session and token lifecycle, revocation, recovery, MFA, and device behavior
- API request and response schemas, validation, errors, pagination, filtering, ordering,
  idempotency, and versioning
- UI states: initial, loading, empty, partial, success, stale, offline, unauthorized, forbidden,
  validation error, and server failure
- State transitions, optimistic updates, retries, duplicate submission, and conflict resolution
- Accessibility: semantics, keyboard, focus, announcements, contrast, motion, and error association
- Responsive, browser, and device support; localization and timezone behavior
- Caching layers, invalidation, privacy, consistency, and stale-data experience
- File upload and download handling, and untrusted content
- CSRF, XSS, injection, SSRF, redirect, cookie, CORS, CSP, and rate-limit boundaries
- Background jobs, notifications, webhooks, scheduling, and eventual-consistency visibility
- Observability, privacy-safe logging, support diagnostics, feature flags, rollout, and rollback
- Deployment compatibility, migrations, zero-downtime constraints, and client skew

## Gate

The web gate fails when any actor / action / resource combination lacks an authorization result,
any user-visible transition lacks a defined state, or any network operation lacks the validation,
error, retry or idempotency, and stale or concurrent behavior appropriate to its risk.
