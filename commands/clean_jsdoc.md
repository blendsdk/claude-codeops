---
description: Systematically clean JSDoc and code comments across an existing project so they comply with the CodeOps documentation standard — strip every reference to ephemeral CodeOps planning artifacts (`plans/`, `requirements/`, `codeops/`, RD/AR/PA/ST/task IDs) from shipped code, document every non-trivial entity, add `@example` to public / external-facing API, enforce a calm explaining tone, and remove change-history / bug-fix notes from doc comments. Use for "clean_jsdoc", "fix the jsdocs", "clean up the code comments", "remove plan references from comments", or "bring this codebase up to the CodeOps doc standard". Detection-first (a cheap grep pass) then scoped semantic rewrites — comments only, never behavior. Meant to run occasionally to fix an existing project; afterwards exec_plan keeps new code compliant. Runs well on a cheaper model. Modes: `--dry-run` (report only, changes nothing), `--refs-only` (fast — only strip the ephemeral-artifact references).
argument-hint: "[path] [--dry-run] [--refs-only]"
allowed-tools: Bash(grep:*), Bash(rg:*), Bash(ls:*), Bash(find:*), Bash(git:*), Read, Edit, Glob, Grep
---

# clean_jsdoc — bring an existing codebase up to the CodeOps documentation standard

Retrofit the doc comments and code comments of an **existing** project so they obey the CodeOps
documentation standard (`standards/coding-standards-full.md` → *Documentation*). This is a one-time
(or occasional) cleanup: once a project is clean, the exec_plan skill keeps newly-written code
compliant, so you should rarely need to run this twice on the same tree.

Target root is `$ARGUMENTS` (first non-flag token) if given, else the current working directory.

> **Model note.** This is high-volume, low-subtlety work: the detection is a deterministic grep and
> the rewrites are localized. Run it on a **cheaper model** (Sonnet, or Haiku for bulk) — the
> detection-first design keeps token cost proportional to the number of violations, not to the size
> of the codebase.

## The standard being enforced (the five rules)

These come straight from `standards/coding-standards-full.md`; do not restate or reinvent them:

1. **Document every non-trivial entity** — classes, methods, functions, exported globals — with a
   doc comment (purpose, params, return, side effects) in the language's native format (JSDoc,
   docstrings, `///`, …). Public / exported / external-facing API is **always** documented; a
   genuinely self-evident one-liner may be left alone rather than padded with ceremony.
2. **Comment code above a junior developer's level** — non-obvious algorithms, invariants, subtle
   ordering / lifecycle dependencies, and "why it is done this way" decisions get a short comment
   so a junior can follow along. Trivial lines get nothing.
3. **`@example` on public / external-facing API** wherever practical — a worked, copy-pasteable
   example, because AI tools and human callers both learn the contract from it.
4. **Calm, explaining tone** — comments and doc comments read like a patient explanation, not terse
   cryptic notes. Explain *why*, not *what*.
5. **No change history in doc comments** — no "fixed in vX", bug-fix notes, or maintainer
   traceability. A doc comment describes what the entity *is and does now*; the history belongs in
   the commit / PR body.

Plus the **non-negotiable ban** that motivates this whole command:

> **No code comment or doc comment may reference a CodeOps planning artifact** — `codeops/`,
> `plans/`, `requirements/`, an execution plan, or any `RD-`/`AR-`/`PA-`/`PF-`/`ST-`/`GATE-`/
> `DEF-`/task identifier. Those files are ephemeral (regenerated, migrated between layouts, or
> deleted once a feature ships); a reference into them is a dangling pointer and pure noise to a
> reviewer who never had that folder.

**Semantic rewrite, not a delete.** When a comment cites a plan artifact, keep the *behavior* it
annotated and drop only the *citation*: `// enabled by default (PA-3)` → `// enabled by default`.
When a comment needs the rationale a plan recorded, restate that rationale in plain language.

## Scope — what to touch and what to leave alone

- **In scope:** shipped source of the project (the language's source dirs — `src/`, `lib/`,
  `packages/*/src`, `app/`, etc.). Comments and doc comments only.
- **Test files:** in scope, but a spec test's traceability comment is *rewritten to quote the
  requirement's substance in plain language* (e.g. `// password must be at least 8 characters`),
  never a path or ID into `requirements/`. Never weaken an assertion.
- **Out of scope — never edit:** `codeops/`, `plans/`, `requirements/`, `.claude/`, `CLAUDE.md`,
  `node_modules/`, `vendor/`, `dist/`/`build/`/generated files, `*.d.ts`, `*.min.*`, lockfiles, and
  anything under `.git/`. These are not shipped source (or are themselves the planning layer).
- **Comments only, never behavior.** You edit comment text; you do **not** change code, rename
  symbols, or move logic. If a fix seems to require a code change, stop and report it instead.

## Workflow — detection first

### Step 0 — Parse flags and confirm the tree is clean

Read the flags from `$ARGUMENTS`: `--dry-run` (report only, change nothing) and `--refs-only`
(only strip the ephemeral-artifact references — the cheap, acute-pain pass; skip rules 1–3 tone /
coverage / `@example` work). Confirm the git working tree is clean (or warn the user that changes
will be interleaved with their own), so the cleanup is reviewable as an isolated diff.

### Step 1 — Detect (cheap, deterministic)

Run a grep pass for the banned references across in-scope source only. Language-agnostic — the
patterns are plain regexes. For example:

```bash
grep -rnEI \
  -e '\b(RD|AR|PA|PF|HR|GATE|AC|ST|ADR|DEF)-[0-9]+' \
  -e '\b(codeops|plans|requirements)/[[:alnum:]._/-]*' \
  --include='*.ts' --include='*.tsx' --include='*.js' --include='*.py' \
  --include='*.go' --include='*.rs' --include='*.java' --include='*.rb' \
  <source-dirs> 2>/dev/null
```

Adjust the `--include` globs to the project's languages (detect from its manifests / extensions).
Exclude the out-of-scope paths above. This produces the **violation inventory** — the exact files
and lines the model needs to open. **The model never opens a file with no hit** (except, in a full
run, the deliberate public-API coverage pass in Step 4).

### Step 2 — Present the inventory and get a go-ahead

Report: how many files and lines carry banned references, grouped by file, plus (for a full run) a
count of public exports missing `@example`. Recommend the batching plan. In `--dry-run` mode, stop
here — this report *is* the output (and doubles as a guard you can re-run later). Otherwise get the
user's go-ahead before editing.

### Step 3 — Fix the banned references (all modes)

Working in reviewable batches (by directory or file group), open each flagged file and rewrite each
flagged comment per the *semantic rewrite* rule above: keep the behavior, drop the citation, restate
any rationale in plain language. Also strip change-history / bug-fix notes from doc comments you are
already editing (rule 5). Edit comment text only.

### Step 4 — Full pass only (skip when `--refs-only`): coverage, `@example`, tone

For each public / exported symbol in the project's public entry points (barrels / `index` files /
the language's export surface), ensure it has: a plain-language lead sentence, `@param`/`@returns`,
an `@example`, and a calm explaining tone. Add doc comments to undocumented non-trivial entities and
short *why* comments to above-junior logic. Do **not** pad trivial one-liners.

### Step 5 — Verify

Run the project's verify command (from its `CLAUDE.md`, or its detected build + test). Comment-only
edits must not change behavior — a failing verify means something went wrong; investigate before
reporting done. Re-run the Step 1 grep to confirm zero banned references remain.

### Step 6 — Report

Summarize: files touched, references stripped, doc comments added / rewritten, `@example`s added,
and the verify result. Note anything you deliberately left alone (trivial entities, out-of-scope
paths) and anything that looked like it needed a *code* change (which you did not make).

## After the cleanup

Once a project is clean, it stays clean through normal work: the exec_plan skill enforces the same
ban at the per-task implement step, so newly-written code never reintroduces plan references. If you
want a permanent regression gate, wire a grep like Step 1's into the project's own `verify` / CI —
that is the project's choice, outside this command.
