# Coding standards (CodeOps) — core

These apply to all code I write unless this project's `CLAUDE.md` overrides a specific point.
This is the compact, always-injected core; the complete text lives in
`standards/coding-standards-full.md` — **read it before writing substantial code or tests.**
Do not duplicate these standards in `~/.claude/CLAUDE.md` — the plugin injects them.

## Quality & structure
- **DRY**; **clarity over cleverness** (junior-readable); **single responsibility**; **no dead
  code**; **consistency with the existing codebase is non-negotiable**; be explicit when in doubt.
- Split files before ~500 lines; respect module boundaries (import public APIs only); imports at
  the top; keep the dependency surface minimal.
- Comment **why**, not what; every public/protected API gets a doc comment.
- Statically-typed code: no unsafe casts (`as any`/`as unknown`); use type guards; enums/constants
  for discriminators.

## Security — non-negotiable, from the first line
- Validate and sanitize ALL input server-side (allowlists). Prevent injection: parameterized
  queries, escaped output, no unsanitized shell/`eval`, canonicalized paths (reject `..`),
  anti-CSRF + `SameSite`, rate-limited auth.
- Protect data: TLS in transit, encryption at rest, `bcrypt`/`argon2`/`scrypt` for passwords, no
  hardcoded secrets, never log secrets/PII, minimal prod errors, restrictive CORS, non-root
  containers.

# Testing standards
- **Run the project's verify command before completing any task or committing**; full verify
  before declaring done. No code is "done" while any test fails.
- Granular coverage (happy path, edges, errors, integration); E2E where feasible; real objects
  over mocks (mock only true externals); test files split by concern.
- **Specification vs. implementation tests (non-negotiable):** `[feature].spec.test.[ext]`
  derives from requirements only — an immutable oracle (a failing spec test means the
  implementation is wrong, never the test); `[feature].impl.test.[ext]` covers internals.
  Order: spec tests → red → implement → green → impl tests → verify.
- Security tests are mandatory (input validation, authz, injection, rate limiting). Non-code
  artifacts get validation too — see the full standards' validation-command table.

# Working style
- **Ask before assuming**; don't overcomplicate; **verify previous work** before building on it.
- **Grounded options & recommendations (NON-NEGOTIABLE):** Filter (only genuinely viable options,
  no strawmen; ≥2 only when ≥2 are viable) → Second-guess each → Ground in the code (cite
  `file:line`; say so if unverified) → Recommend (lead with it and a concrete reason; you
  recommend, the user decides). Proportionality: ceremony matches stakes. Harden consequential
  recommendations per `_shared/recommendation-hardening.md` (high-stakes decisions get one
  independent challenger; disclose `Confidence:`/`Hardening:` where that protocol requires).

> Project-specific commands, structure, and conventions live in this project's `CLAUDE.md`
> (generate/refresh it with `/analyze_project`). Multi-step CodeOps workflows are available as
> skills: `make_plan`, `exec_plan`, `make_requirements`, `retro_requirements`, `grill_me`,
> `preflight`, `techdocs`, `roadmap`, `upgrade_plan`, `setup_codeops`, `setup_routing`; and as
> commands: `/gitcm`, `/gitcmp`, `/analyze_project`, `/migrate_clinerules` (plus thin aliases).
