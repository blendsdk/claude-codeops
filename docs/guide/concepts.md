# Concepts

A few ideas explain how CodeOps behaves. Understanding them makes the skills predictable.

## Skills vs. commands

- **Skills** are multi-step protocols Claude runs on request. They **auto-trigger** from natural
  language (e.g. "make a plan") *and* can be invoked explicitly as `/codeops:<name>`.
- **Commands** are slash commands. The core ones (`/gitcm`, `/gitcmp`, `/analyze_project`,
  `/migrate_clinerules`) do focused jobs; the rest are **thin alias commands** that delegate to a
  parent skill in a specific mode. Aliases are manual-only — only the parent skills auto-trigger.

See the [Skills overview](/skills/) and the [Commands page](/skills/commands).

## Progressive disclosure

Only each skill's **name + description** load into context up front. The full body loads **when the
skill is used**. This is why CodeOps no longer needs the old MCP server: Claude Code keeps the
context window small natively. It also means skill descriptions must stay within Claude Code's
display budget (the repo's `validate.sh` enforces ≤ 1024 chars).

## Always-on standards

The plugin bundles a single source of truth for universal coding/testing/working-style standards:
`standards/coding-standards.md`. A `SessionStart` hook `cat`s that file into the context of every
new session, so the standards are always present with **zero setup**.

- Fires on every session start (including after `/clear` and context compaction).
- Read-only — the hook only reads a file shipped inside the plugin; it never writes anything.
- To turn it off, disable the plugin. There is no separate toggle.

See the summarized standards in the [Reference](/reference/standards).

## Rolling updates

The plugin carries **no version number** — the latest git commit *is* the version. Every push is
immediately installable via `/plugin update`. There is no release/publish ceremony.

## The Zero-Ambiguity Gate

Several skills ([`make_plan`](/skills/make_plan), [`make_requirements`](/skills/make_requirements))
enforce a hard **Zero-Ambiguity Gate**: before any plan or requirement document is written, every
gap, assumption, and open question is hunted across a fixed set of categories, compiled into an
**Ambiguity Register**, and resolved by **you** — never guessed by the model. The gate opens only
when every item is explicitly resolved and you have confirmed the complete register.

## Specification-first testing

CodeOps separates **specification tests** (derived from requirements/acceptance criteria — immutable
oracles) from **implementation tests** (edge cases and internals). The enforced order is:
**write spec tests → confirm they fail (red) → implement → make them pass (green) → add impl tests →
verify**. [`exec_plan`](/skills/exec_plan) drives this ordering task-by-task.

## The pipeline

The skills compose:

```
grill_me → make_requirements → preflight → make_plan → preflight → exec_plan
```

with [`roadmap`](/skills/roadmap) tracking the feature-set and [`techdocs`](/skills/techdocs) keeping
architecture docs current. The [tutorials](/tutorials/) walk this end to end.
