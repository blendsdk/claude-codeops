# Introduction

**CodeOps** is the CodeOps AI-development workflow — **11 skills + 17 slash commands + always-on
coding standards** — packaged as an installable [Claude Code plugin](https://code.claude.com/docs/en/plugins).

## Why it exists

CodeOps is ported from the original [`codeops-mcp`](https://github.com/blendsdk/codeops-mcp) server,
which was built for Cline. That MCP server existed to load rule documents on demand so the context
window wouldn't blow up. Claude Code does that natively via **skill progressive disclosure** — only
each skill's name and description load up front, and the body loads when the skill is actually used.
So the MCP machinery is gone and only the knowledge remains.

## What you get

- **11 skills** — multi-step protocols that Claude runs on request:
  [`make_plan`](/skills/make_plan), [`exec_plan`](/skills/exec_plan),
  [`make_requirements`](/skills/make_requirements), [`retro_requirements`](/skills/retro_requirements),
  [`grill_me`](/skills/grill_me), [`preflight`](/skills/preflight), [`techdocs`](/skills/techdocs),
  [`roadmap`](/skills/roadmap), [`upgrade_plan`](/skills/upgrade_plan),
  [`setup_codeops`](/skills/setup_codeops), and [`setup_routing`](/skills/setup_routing).
- **17 slash commands** — including [`/gitcm` / `/gitcmp`](/skills/commands) for Conventional-Commit
  flows, `/analyze_project`, `/migrate_clinerules`, and thin alias commands that delegate to the
  parent skills.
- **Always-on coding standards** — a single source of universal coding, testing, and working-style
  standards, injected into every session by a `SessionStart` hook with **zero setup**.

## How it fits together

The skills compose into the original CodeOps pipelines, for example:

```
grill_me → make_requirements → preflight → make_plan → preflight → exec_plan
```

with [`roadmap`](/skills/roadmap) tracking the whole feature-set across its lifecycle and
[`techdocs`](/skills/techdocs) keeping architecture docs current.

## Next steps

- [Install](/guide/install) the plugin.
- [Verify](/guide/verify) it loaded.
- Learn the [core concepts](/guide/concepts).
- Work through a [tutorial](/tutorials/).
