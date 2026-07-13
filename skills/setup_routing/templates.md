# setup_routing — templates & write contracts

Read this before writing anything in Phase 4. It holds the exact artifacts the skill emits:
the two executor subagents, the sentinel routing block, and the merge rules. Fill the
`<PLACEHOLDERS>` from the chosen profile before presenting (Phase 2) and writing (Phase 4).

---

## 1. Executor subagents (plugin-shipped; per-project override is opt-in)

Since v3.2.0 both executors ship with the plugin in its `agents/` directory
(`agents/plan-task-executor.md`, `agents/plan-task-executor-opus.md`) — the routing block works
on every install with NO per-project agent writes. Write copies into the TARGET project's
`.claude/agents/` ONLY when the user opted in at Phase 3 (customized prompts; a project agent of
the same name shadows the plugin one). For an override: start from the plugin file's current
content, create each only if it does not already exist, and never overwrite a user's file of the
same name — report the collision and skip, or offer a suffixed name.

> **`model:` field syntax.** These templates use the `sonnet` / `opus` shorthand (also valid:
> `haiku`, `fable`, `inherit`, or a full model id). Confirm the shorthand is valid for the user's
> installed Claude Code version; if their version requires explicit model strings, substitute those
> and note it in the Phase 5 summary. When uncertain, emit the shorthand and ask the user to
> confirm — do not silently guess.
>
> **Both `model:` and `effort:` are pinned — by design.** A subagent's frontmatter `model:`
> overrides the session model, `settings.json` `"model"`, and `ANTHROPIC_MODEL`; its `effort:`
> overrides the session effort level *while that subagent is active*. So routing works **regardless
> of what model or effort the user has already configured** in their CC config. Pinning effort is
> what makes the Sonnet executor actually run cheap even if the user's session effort is high/xhigh.
> Effort levels: `low | medium | high | xhigh | max` (available levels depend on the model — Sonnet
> does not expose `xhigh`). The policy reserves `xhigh`/`max` for planning skills, so the executors
> cap at `high`.
>
> **The one override that beats these pins:** the `CLAUDE_CODE_SUBAGENT_MODEL` env var sits *above*
> subagent frontmatter in the precedence order, so a user who sets it forces every subagent onto
> that model. That is a deliberate global cost-cap escape hatch, not a bug — mention it in the
> Phase 5 summary so the user knows their pins are honored unless they have set it.

### Override sources

The override starting-point content is NOT duplicated here (it would drift): read the plugin's
`agents/plan-task-executor.md` (Sonnet, effort medium) and `agents/plan-task-executor-opus.md`
(Opus, effort high) and copy their current content verbatim, then customize. Both carry the
phase-packet contract, the spec-test blocker rule, and the never-guess/never-edit-the-plan
rules — keep those in any customization.

---

## 2. The CLAUDE.md routing block

Write it between the sentinels so re-running updates it in place. Keep it tight — it rides into
every session's context, so the sentinel span stays **≤10 lines** (each directive on one dense
line). Fill `<PROFILE NAME>`, `<DEFAULT TAG>`, and the profile-specific override line; drop the
override line if the profile has none.

```markdown
<!-- CODEOPS-ROUTING:START -->
## Model & effort routing (<PROFILE NAME>)
- Tag each task trivial|standard|complex|sensitive (default <DEFAULT TAG>) in make_plan.
- exec_plan runs phases inline on the tagged model; dispatch one pinned executor only when a cheaper model than the session's is warranted — trivial/standard→Sonnet (plan-task-executor), complex/sensitive→Opus (plan-task-executor-opus).
- <PROFILE-SPECIFIC OVERRIDE LINE>
- Reserve Opus + high/xhigh for make_plan, grill_me, preflight. /compact after each phase; /clear on project switch.
<!-- CODEOPS-ROUTING:END -->
```

### Profile-specific override line (pick the matching one)

- **A — Opus-dominant:** `Default complex; de-escalate only mechanical tasks (lexer tables, AST boilerplate, fixtures, mechanical refactors) to trivial. preflight always Opus.`
- **B — Mixed core/scaffold:** `All lowering/translation and target-language-semantics tasks are sensitive (Opus); CLI/error-formatting/scaffolding/fixtures are trivial/standard (Sonnet). preflight always Opus, focused on semantic correctness.`
- **C — Sonnet-default:** `Escalate to sensitive (Opus) only for security-, concurrency-, or performance-critical tasks.`
- **Balanced (fallback):** `Fallback classification — escalate complex/sensitive to Opus; confirm or correct the profile if this is wrong.`

---

## 3. Sentinel-merge rules (CLAUDE.md)

The markers are exactly `<!-- CODEOPS-ROUTING:START -->` and `<!-- CODEOPS-ROUTING:END -->`.

- **Both markers present:** replace only the content between them; leave everything else byte-for-byte.
- **Neither marker present:** append the block at the end of `CLAUDE.md` (create the file if the
  project has none), separated by a blank line.
- **Exactly one marker present (corrupted state):** do **not** guess. Report it and ask the user
  how to proceed.

Never disturb user-authored or `analyze_project`-authored sections. The block is the only region
this skill owns.
