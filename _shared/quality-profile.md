# Quality Profile (shared convention)

> **CodeOps Skills Version**: 3.16.0

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
agent_models: {phase-reviewer: {effort: xhigh}, codebase-scout: opus}
<!-- CODEOPS-QUALITY:END -->
```

The markers are exactly `<!-- CODEOPS-QUALITY:START -->` and `<!-- CODEOPS-QUALITY:END -->` —
the same convention as the CODEOPS-ROUTING sentinels, so tooling can rewrite the block in place.

### Fields

Every key is optional; a missing key takes its default. `[]` is a valid, meaningful value.

| Key | Values | Default | Effect |
|-----|--------|---------|--------|
| `domains` | list of domain names (see the enum below) | *(absent — detect)* | **Pins** the domain selection for a repo whose domains are stable, skipping detection. It can only pin, never disable: classification always runs |
| `lenses` | list of **add-on** lens names (see the enum below) | `[]` | Extra review lenses for the phase reviewer, beyond the always-on base |
| `security_profile` | list of security-profile names (see the enum below) | `[]` | Non-empty list activates the security auditor with the **union** of the named checklists in ONE dispatch per phase |
| `perf_critical` | `true` \| `false` | `false` | `true` activates the perf auditor on code-touching phases |
| `review_hook` | `on` \| `off` | `on` (when the block exists) | `off` switches the whole quality loop off while keeping the profile on record |
| `telemetry` | `on` \| `off` | `on` | Per-repo telemetry kill switch (`off` silences `codeops-events.sh` for this repo) |
| `agent_models` | map of agent name → model, or → `{model, effort}` | `{}` | Per-repo model and/or effort override (see Model & effort resolution) |

### Parsing, absence, ownership

- **Absence rule.** No block in the repo's `CLAUDE.md` → the quality loop is **fully dormant**:
  no agents dispatch, no skill-side events emit, behavior is exactly as before the loop existed.
  Repos opt in via `/setup_routing`, which proposes and writes the block.
- **Domain classification is outside the absence rule**, because it dispatches no agent and emits
  no event — the two things that rule governs. It is prompt guidance inside skills that already run
  regardless of the profile, so gating it would deny it to every repo that never opts in. The
  `domains` key tunes classification; it does not switch it on.
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
  So is a value the enums do not recognize — the entry drops, the rest of the map still applies.

## Taxonomies

### Domain enum (5 — grow-only; renaming or repurposing an existing value is forbidden)

| Domain | Selected when the system… |
|--------|---------------------------|
| `compiler-and-language` | Has formal transformation semantics: grammar, parser, IR, type checker, query planner, protocol codec |
| `financial-system` | Records, calculates, authorizes, transfers, reconciles, reports, or audits monetary value |
| `web-application` | Serves a browser UI, HTTP API, or mobile backend, with sessions, roles, or tenant resources |
| `distributed-and-concurrent` | Runs across threads, workers, queues, replicas, or nodes, or integrates asynchronously |
| `data-and-migration` | Owns a persistent schema or serialized format, migrates it, or must keep an existing artifact working |

Domains classify **what is being built**, so the right questions get asked before requirements
discovery. The per-domain question sets live in `references/domains/`; this table is the naming
authority and the structural guards read the enum from here.

> **Domains are not lenses.** A domain selects *which questions to ask about the system* and is
> chosen from repository evidence, unconditionally, by four skills. A lens (below) selects *which
> concerns a phase reviewer applies to a diff* and is opt-in through this profile. The words are
> not interchangeable, and no file under `references/domains/` may use "lens" for this concept.

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

RV (phase-reviewer) · SA (security-auditor) · PA (preflight-auditor) · PE (perf-auditor) ·
CA (concurrency-auditor) · FA (financial-integrity-auditor) · SR (semantics-reviewer), each
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
| `lenses` contains `concurrency` + diff touches code | Concurrency auditor dispatches and **supersedes** the reviewer's `concurrency` lens |
| `security_profile` contains `financial-integrity` | Financial-integrity auditor dispatches and **supersedes** that one checklist inside the security auditor, which still runs for the rest |
| `compiler-and-language` among the selected domains + diff touches code | `semantics-reviewer` dispatches; it supersedes nothing, being a discipline no shared reviewer covers |

Supersession exists so the same ground is never reviewed twice at different depths: a dedicated
agent replaces the reviewer's matching add-on lens for that phase. It is implemented on **both**
sides — the specialist's prompt claims the ground and the shared reviewer's prompt stands down —
because a supersession recorded only here would leave both agents reviewing, and the shallower
pass is the one that sets expectations.

> **The semantics reviewer is domain-activated, not profile-keyed.** It reads its trigger from the
> `compiler-and-language` domain rather than a fourth profile field, because that domain already
> means "this system has formal transformation semantics" — inventing a key to restate it would
> give a repo two places to disagree with itself. Classification runs unconditionally, but this
> dispatch does not: like every other agent, it requires a profile block. Domain selection decides
> *whether the discipline applies*; the profile decides *whether agents run at all*.

## Dispatch packets & header

**Line 1 of every quality-agent dispatch prompt** is the machine-readable header:

```
[codeops-dispatch agent=<name> feature=<slug> phase=<id>]
```

The telemetry hook parses it from the completion payload; a dispatch without the header still
produces a completion event with those fields omitted, so missing headers are measurable.

| Agent | Packet contents (the agent receives nothing else and must need nothing else) |
|-------|------------------------------------------------------------------------------|
| phase-reviewer, security-auditor, perf-auditor, concurrency-auditor, financial-integrity-auditor, semantics-reviewer | Phase diff (`git diff <phase-start-ref>..HEAD`), the phase's task + Deliverable lines, active lenses, profile excerpt, verify command + last result. The packet names every dimension superseded for this phase, so a reviewer standing down never has to infer it |
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

## Model & effort resolution

### The `agent_models` value forms

The key name is historical — it carries effort too. Three forms, all valid in the same map:

```yaml
agent_models: {codebase-scout: opus, phase-reviewer: {effort: xhigh}, security-auditor: {model: fable, effort: max}}
```

| Form | Meaning |
|------|---------|
| `name: <model>` | Model only. Applied at dispatch time; nothing is written to disk. |
| `name: {effort: <E>}` | Effort only; the model stays the agent's own pin. |
| `name: {model: <M>, effort: <E>}` | Both. |

Models: `sonnet` · `opus` · `haiku` · `fable` · `inherit`. Efforts: `low` · `medium` · `high` ·
`xhigh` · `max` — **availability depends on the model** (Sonnet does not expose `xhigh`), and an
effort the model cannot honor degrades silently, exactly like an unavailable model pin.

### Why effort needs a file and model does not

Model can be redirected when the agent is dispatched. **Effort cannot** — Claude Code reads it
from the agent's own frontmatter, and offers no dispatch parameter, environment variable, or
settings key for it. So an effort override has to exist as a file in the repo's `.claude/agents/`.

Writing that file by hand is what this convention exists to prevent. A hand copy of a plugin
agent is a silent, permanent fork: the plugin ships an improved prompt in its next release and
the repo keeps the old one forever, with nothing to notice it by. Instead,
**`"${CLAUDE_PLUGIN_ROOT}/scripts/codeops-agents-sync.sh"` generates those files** — body copied byte-for-byte from the
plugin's `agents/<name>.md`, only `model:`/`effort:` rewritten, and a marker line recording the
plugin version that produced it:

```
<!-- CODEOPS-GENERATED agent=phase-reviewer version=3.12.0 source=agents/phase-reviewer.md — generated by CodeOps; regenerate with /setup_routing, do not hand-edit -->
```

The marker is what makes the fork honest. Regeneration is a no-op when nothing changed, a stale
stamp is detectable (`--check` exits 1), and withdrawing an override prunes its file rather than
leaving a dead pin in force.

**Ownership is one-directional: the engine owns files carrying its marker and nothing else.** An
agent file without the marker is hand-authored — reported and left completely alone, never
overwritten and never pruned. Deliberately forking a prompt stays legal; it just stops being the
only way to change one frontmatter line.

### Resolution order

1. `CLAUDE_CODE_SUBAGENT_MODEL` — a deliberate global cost cap that beats every model pin below;
2. the dispatch-time `model` from an `agent_models` entry;
3. the `model:` / `effort:` frontmatter of the agent that actually loads — the generated
   `.claude/agents/<name>.md` when one exists (a project agent shadows the plugin's), else the
   plugin's `agents/<name>.md`;
4. native fallback — **a pinned model or effort that is unavailable (for example, a model absent
   from an org's allowlist) silently runs at the session's.** No handling code exists for this;
   surprising review quality on a restricted account is worth checking against this note.

Upstream note: the file-generation step exists only because effort has no configuration surface.
If Claude Code gains one (tracked in `anthropics/claude-code#79866`), the generated files become
unnecessary and the engine's job reduces to pruning them.
