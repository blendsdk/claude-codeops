# Coding & testing standards

These are the always-on standards the plugin injects into every session via the `SessionStart` hook.
The canonical, full text lives in
[`standards/coding-standards.md`](https://github.com/blendsdk/claude-codeops/blob/master/standards/coding-standards.md)
in the repo — this page is a summary. A project's own `CLAUDE.md` may override specific points.

## Quality & structure

- **DRY** — extract repeated logic, constants, and patterns.
- **Clarity over cleverness** — readable by a junior developer; explicit over "smart" one-liners.
- **Single responsibility** per function/class/module.
- **No dead code** — remove unused imports, variables, params, functions, and commented-out blocks.
- **Consistency is non-negotiable** — follow the existing patterns and architecture.

## Documentation

- Comment **why**, not just what.
- Every public/protected class, method, function, and component gets a doc comment in the language's
  format (JSDoc, docstrings, `///`, etc.).

## Architecture & boundaries

- **Split files before ~500 lines**; aim for 200–500 lines per file with a single public entry point.
- **Respect module boundaries** — import from public APIs, never reach into internals.
- Keep imports at the top; separate type-only from value imports; minimal dependency surface.

## Type safety

- Top-of-file type imports; **no unsafe casts** (`as any`, `as unknown`) in production code.
- Use type guards / narrowing; provide all required fields; use enums/constants for discriminators.

## Security — from the first line

- **Validate and sanitize all input server-side** with allowlists.
- **Prevent injection**: parameterized queries, output escaping/auto-escaping, no unsanitized input to
  shells/`eval`, canonicalize and reject `..`/absolute paths, anti-CSRF + `SameSite` cookies,
  rate-limit auth endpoints.
- **Protect data**: TLS in transit, encrypt sensitive data at rest, hash passwords with
  `bcrypt`/`argon2`/`scrypt`, never hardcode secrets, never log secrets/PII, restrictive CORS,
  request-size limits, audit dependencies, run containers as non-root from minimal images.

## Testing

- **Run the project's verify command (build + test) before completing any task or committing.**
- **Maximum, granular coverage**: happy path, edge/boundary, error/invalid inputs, and integration.
- **Prefer real objects over mocks** — only mock true externals (DB, HTTP, filesystem).
- **Specification vs. implementation tests (non-negotiable)**, kept in separate files:
  - *Spec tests* (`[feature].spec.test.[ext]`) derive expectations from requirements/contracts — never
    from the implementation. They are immutable oracles.
  - *Impl tests* (`[feature].impl.test.[ext]`) cover internals, edge cases, and error paths.
  - Enforced order: **spec tests → red → implement → green → impl tests → verify**.
- **Security tests are mandatory** for input validation, authz, injection, and rate limiting.

## Working style

- **Ask before assuming** — clarify ambiguity rather than guessing (see [`grill_me`](/skills/grill_me)).
- **Don't overcomplicate** — use existing infrastructure and patterns first.
- **Verify previous work** before building on it.
- **Grounded options & recommendations** — present only genuinely viable options (no strawmen),
  second-guess each, ground any code-change option in the real code (`file:line`), and lead with a
  recommendation and its reason; match ceremony to the stakes. The user decides.
- **Recommendation hardening** — before presenting a consequential recommendation, run the reframing
  prompts + a definition-of-done rubric and close with a `Confidence:` / `Hardening:` disclosure; for
  high-stakes decisions an independent challenger is spawned and reconciled. See
  [Concepts → Recommendation hardening](/guide/concepts#recommendation-hardening).
