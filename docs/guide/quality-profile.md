# Quality profile

The quality profile is a small sentinel-fenced block in your project's `CLAUDE.md` that opts the
repo into CodeOps' quality loop: post-phase reviews by dedicated agents, security/perf audits,
and workflow telemetry. **No block, no behavior change** — repos without a profile run exactly
as before.

## The block

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

Onboard a repo with **`/setup_routing`** — it analyzes the code, proposes the routing block and
the quality block together from the evidence it finds, and writes both only after you confirm.
Hand-editing the block afterwards is fully supported.

## Fields

| Key | Values | Default | Effect |
|-----|--------|---------|--------|
| `lenses` | add-on lens names | `[]` | Extra review lenses beyond the always-on base (correctness, maintainability, standards) |
| `security_profile` | `owasp-web`, `auth-protocol`, `financial-integrity`, `tenant-isolation`, `mcp-agent` | `[]` | Activates the security auditor with the union of the named checklists, once per phase |
| `perf_critical` | `true` / `false` | `false` | Activates the perf auditor on code-touching phases |
| `review_hook` | `on` / `off` | `on` | `off` switches the whole loop off while keeping the profile on record |
| `telemetry` | `on` / `off` | `on` | Per-repo telemetry kill switch |
| `agent_models` | map agent → model, or → `{model, effort}` | `{}` | Per-repo model and effort overrides for the quality agents — see [below](#per-repo-model-and-effort-overrides) |

Add-on lenses: `security`, `perf`, `api-surface`, `concurrency` (which owns data-integrity).
Parsing is lenient per key — an unknown key or value is warned about and ignored, never
blocking. Both enums are grow-only.

## What activates when

- **Every executed phase** (and non-trivial task mini-plan) ends with a parallel dispatch of the
  phase reviewer plus any active auditors on the phase diff. Trivial tasks are never reviewed;
  docs-only diffs get the reviewer only.
- **Findings gate commits:** critical and major findings pause execution for your ruling in
  every commit mode — auto-commit automates the git operation, never the ruling. Minor findings
  are report-only. Accepted fixes are re-reviewed once, on the fix diff.
- **Supersession:** an active security profile replaces the reviewer's `security` lens;
  `perf_critical` replaces its `perf` lens — the same ground is never reviewed twice.
- **Budget caps:** one re-review per phase, at most; three codebase-scout dispatches per skill
  run; preflight fans out as five clustered auditor dispatches (`--thorough` goes per-dimension).

## Per-repo model and effort overrides

Some repos want a harder reviewer than the plugin ships, or a cheaper scout. `agent_models` takes
three value forms:

```markdown
agent_models: {codebase-scout: opus, phase-reviewer: {effort: xhigh}, security-auditor: {model: fable, effort: max}}
```

| Form | Meaning |
|------|---------|
| `name: model` | Model only |
| `name: {effort: E}` | Effort only; the agent keeps its own model pin |
| `name: {model: M, effort: E}` | Both |

Efforts are `low`, `medium`, `high`, `xhigh`, `max` — availability depends on the model (Sonnet
has no `xhigh`), and an unavailable level degrades silently, exactly like an unavailable model.

**Why effort works differently.** Claude Code lets a model be redirected when an agent is
dispatched, but reads effort only from the agent's own frontmatter. An effort override therefore
has to exist as a file in `.claude/agents/`.

Do **not** write that file by hand. A hand copy of a plugin agent freezes its prompt at today's
release and never receives another improvement — a silent, permanent fork to change one line.
`/setup_routing` instead runs `"${CLAUDE_PLUGIN_ROOT}/scripts/codeops-agents-sync.sh"`, which copies the plugin's body
byte-for-byte, rewrites only the frontmatter, and stamps the result:

```
<!-- CODEOPS-GENERATED agent=phase-reviewer version=3.12.0 source=agents/phase-reviewer.md — … -->
```

That marker is the ownership boundary. Files carrying it are regenerated when the plugin moves on
and pruned when you withdraw the override; files without it are yours, and the engine never
touches them — so a genuinely customized prompt stays a deliberate choice. After upgrading the
plugin, `"${CLAUDE_PLUGIN_ROOT}/scripts/codeops-agents-sync.sh" --check` reports (exit 1) if any generated agent is stale.

The full convention — packet contents, dispatch headers, model and effort resolution — lives in the
plugin's `_shared/quality-profile.md`, which every dispatching skill links. See also
[Agents](/reference/agents) and [Telemetry](/guide/telemetry).
