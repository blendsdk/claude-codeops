---
layout: home
hero:
  name: CodeOps
  text: AI-development workflow for Claude Code
  tagline: 11 skills + 21 commands + always-on coding standards, packaged as an installable plugin.
  actions:
    - theme: brand
      text: Get started
      link: /guide/install
    - theme: alt
      text: Browse the skills
      link: /skills/
    - theme: alt
      text: View on GitHub
      link: https://github.com/blendsdk/claude-codeops
features:
  - title: Plan before you build
    details: make_plan drives a clarifying interview through a hard Zero-Ambiguity Gate into a task-by-task execution plan, then exec_plan implements it spec-tests-first.
  - title: Requirements, archaeology & audits
    details: make_requirements turns ideas into numbered RDs, retro_requirements reverse-engineers legacy code into a spec, and preflight runs an adversarial, codebase-grounded quality audit.
  - title: Always-on standards
    details: A SessionStart hook injects the CodeOps coding, testing, and working-style standards into every session — zero setup, nothing to merge into your CLAUDE.md.
  - title: Docs, roadmaps & upgrades
    details: techdocs maintains VitePress architecture docs + ADRs, roadmap tracks a whole feature-set across its lifecycle, and upgrade_plan brings older artifacts up to current standards.
---

## What is CodeOps?

CodeOps is a disciplined AI-development workflow delivered as a native
[Claude Code plugin](https://code.claude.com/docs/en/plugins). It gives Claude a set of
**skills** (multi-step protocols for planning, requirements, audits, docs, and more), a set of
**slash commands**, and a single source of **always-on coding standards** that load into every
session automatically.

It is ported from the original [`codeops-mcp`](https://github.com/blendsdk/codeops-mcp) server
(built for Cline). The MCP server existed to load rule documents on demand so the context window
wouldn't blow up — Claude Code does that natively via **skill progressive disclosure**, so the
machinery is gone and only the knowledge remains.

## The pipeline

The skills are designed to compose into a single, repeatable pipeline:

```
grill_me → make_requirements → preflight → make_plan → preflight → exec_plan
```

…with `roadmap` tracking the whole feature-set and `techdocs` keeping architecture docs current.
Start with the [tutorials](/tutorials/) to see it end to end.
