# Quality Profile (shared convention)

> **CodeOps Skills Version**: 3.10.0

This is the **single canonical definition** of the per-repo quality profile and the quality-agent
conventions built on it. It lives at the plugin root in `_shared/` (deliberately outside
`skills/`, like `layout-convention.md` and `zero-ambiguity-gate.md`). The dispatching skills —
exec_plan, preflight, setup_routing, and the commands that consume telemetry — link here instead
of carrying their own copies. Change the convention in one place: here.

## The profile block

A repo opts into the quality loop through one sentinel-fenced block in its project `CLAUDE.md`:

```markdown
## Quality profile (CodeOps)
<!-- CODEOPS-QUALITY:START -->
lenses: [security, concurrency]
security_profile: [auth-protocol]
perf_critical: false
review_hook: on
telemetry: on
agent_models: {}
<!-- CODEOPS-QUALITY:END -->
```

The markers are exactly `<!-- CODEOPS-QUALITY:START -->` and `<!-- CODEOPS-QUALITY:END -->` —
the same convention as the CODEOPS-ROUTING sentinels, so tooling can rewrite the block in place.

### Fields

Every key is optional; a missing key takes its default. `[]` is a valid, meaningful value.

| Key | Values | Default | Effect |
|-----|--------|---------|--------|
| `lenses` | list of **add-on** lens names (see the enum below) | `[]` | Extra review lenses for the phase reviewer, beyond the always-on base |
| `security_profile` | list of security-profile names (see the enum below) | `[]` | Non-empty list activates the security auditor with the **union** of the named checklists in ONE dispatch per phase |
| `perf_critical` | `true` \| `false` | `false` | `true` activates the perf auditor on code-touching phases |
| `review_hook` | `on` \| `off` | `on` (when the block exists) | `off` switches the whole quality loop off while keeping the profile on record |
| `telemetry` | `on` \| `off` | `on` | Per-repo telemetry kill switch (`off` silences `codeops-events.sh` for this repo) |
| `agent_models` | map of agent name → model | `{}` | Per-repo model override, applied at dispatch time (see Model resolution) |

### Parsing, absence, ownership

- **Absence rule.** No block in the repo's `CLAUDE.md` → the quality loop is **fully dormant**:
  no agents dispatch, no skill-side events emit, behavior is exactly as before the loop existed.
  Repos opt in via `/setup_routing`, which proposes and writes the block.
- **Parsing rule — lenient per key.** An unknown key, or a key with an unusable value, is warned
  about once in-session and treated as absent; the remaining keys still apply. Reading the
  profile must never block work. (Emit-side telemetry validation is the opposite — strict — but
  that gate lives in `scripts/codeops-events.sh` and protects the dataset, not the workflow.)
- **Corrupt sentinels.** A START marker without its END (or vice versa) makes the block
  unparseable: skills treat the profile as absent and say so; setup_routing refuses to merge
  into a corrupt pair rather than guessing at boundaries.
- **Ownership — shared.** setup_routing writes and updates the block; direct hand-edits are
  legitimate and expected (flipping `review_hook`, adding a lens). There is deliberately no
  guard hook on it.
- `agent_models` naming an agent that never activates in this repo is tolerated: warn, ignore.

## Taxonomies

### Lens enum (7 — grow-only; renaming or repurposing an existing value is forbidden)

| Lens | Scope (one line) |
|------|------------------|
| `correctness` | Logic errors, broken behavior against the spec and tests. **Base.** |
| `maintainability` | Design-quality judgment calls: clarity, structure, duplication, naming. **Base.** |
| `standards` | Violations of the always-on written coding standards. **Base-only — never a valid profile add-on.** |
| `security` | Injection, authorization, secrets handling, unsafe input. Add-on. |
| `perf` | Hot paths, allocations, algorithmic complexity, blocking I/O. Add-on. |
| `api-surface` | Public interface design, compatibility, versioning. Add-on. |
| `concurrency` | Races, locking, ordering — explicitly **owns data-integrity**. Add-on. |

The base lenses `correctness` + `maintainability` + `standards` are always on for every review;
the profile's `lenses` list names **add-ons only**. Disambiguation: a violation of a written
standard is `standards`; a design-quality judgment with no written rule behind it is
`maintainability` — keeping the two distinguishable in telemetry.

### security_profile enum (5)

| Profile | Focus |
|---------|-------|
| `owasp-web` | Classic web-app risks: injection, XSS, CSRF, broken access control, SSRF |
| `auth-protocol` | Authentication/session flows: token handling, expiry, replay, fixation |
| `financial-integrity` | Money movement: idempotency, double-spend, rounding, audit trails |
| `tenant-isolation` | Multi-tenant boundaries: cross-tenant reads/writes, scoping, leakage |
| `mcp-agent` | Agent/MCP integrations: prompt injection, tool abuse, secret exfiltration |

The per-profile checklists live in `agents/security-auditor.md`; this table is the naming
authority. Both enums are grow-only: adding a value here legalizes it everywhere (the structural
guards read the enums from this file).

### Severity

Findings reuse the preflight severity scale **by reference** — 🔴 CRITICAL / 🟠 MAJOR /
🟡 MINOR as defined in the preflight skill — verbatim, with no extra levels.

### Finding prefixes

RV (phase-reviewer) · SA (security-auditor) · PA (preflight-auditor) · PE (perf-auditor), each
numbered `XX-NNN`. Every finding-producing agent reports "no findings" explicitly rather than
returning empty output.

## Activation & supersession

| Condition | Effect |
|-----------|--------|
| No profile block | Everything dormant — no dispatches, no skill-side emissions |
| Block present, `review_hook: off` | Loop announced as off; no dispatches |
| Block present (hook on) | Post-phase quality review runs for **all executed phases and task mini-plans** (whole-task diff); trivial tasks are never reviewed |
| Docs-only diff | Phase reviewer still runs; security/perf auditors skip — the skip is logged, never silent |
| `security_profile` non-empty | Security auditor dispatches once per phase with the union of the named checklists, and **supersedes** the reviewer's `security` lens |
| `perf_critical: true` + diff touches code | Perf auditor dispatches and **supersedes** the reviewer's `perf` lens |

Supersession exists so the same ground is never reviewed twice at different depths: a dedicated
agent replaces the reviewer's matching add-on lens for that phase.

## Dispatch packets & header

**Line 1 of every quality-agent dispatch prompt** is the machine-readable header:

```
[codeops-dispatch agent=<name> feature=<slug> phase=<id>]
```

The telemetry hook parses it from the completion payload; a dispatch without the header still
produces a completion event with those fields omitted, so missing headers are measurable.

| Agent | Packet contents (the agent receives nothing else and must need nothing else) |
|-------|------------------------------------------------------------------------------|
| phase-reviewer, security-auditor, perf-auditor | Phase diff (`git diff <phase-start-ref>..HEAD`), the phase's task + Deliverable lines, active lenses, profile excerpt, verify command + last result |
| spec-test-author | Spec excerpts + test cases, planned interface signatures from the plan documents, test framework/conventions, the FORBIDDEN implementation-file list, verify command (expected RED) |
| preflight-auditor | The artifact under audit + ONE assigned dimension cluster |
| design-challenger | Problem + candidate options, **without** the parent's preferred choice (per `_shared/recommendation-hardening.md`) |
| codebase-scout | The factual questions, search hints, and the facts-only contract |

## Budget caps

- **Preflight fan-out:** ~5 clustered auditor dispatches — an exact partition of the preflight
  skill's 13 dimensions, grouped by affinity: ① Ambiguities + Logical Contradictions +
  Consistency (document soundness) · ② Implicit Assumptions + Codebase Alignment (grounding) ·
  ③ Completeness Gaps + Dependency Issues + Ordering & Sequencing (delivery) · ④ Security Blind
  Spots + Edge Cases + Feasibility Concerns (risk) · ⑤ Testability + Scope Creep Indicators
  (fit). `--thorough` expands to one dispatch per dimension.
- **Re-review:** at most ONE re-review per phase, only after 🔴/🟠 fixes, scoped to the fix
  diff — never a third pass.
- **Scout:** ≤3 codebase-scout dispatches per skill run, enforced by the dispatching parent.
- **Challenger:** caps live in `_shared/recommendation-hardening.md` and apply unchanged.

## Model resolution

Each agent's model resolves in this order:

1. the `model:` pin in its `agents/*.md` frontmatter;
2. an `agent_models` override from the repo's profile block, applied at dispatch time;
3. native fallback — **a pinned model that is unavailable (for example, absent from an org's
   model allowlist) silently runs on the session model.** No handling code exists for this;
   surprising review quality on a restricted account is worth checking against this note.
