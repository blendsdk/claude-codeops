---
description: Convert a legacy codeops-mcp .clinerules/project.md into this project's CLAUDE.md — preserving hand-authored content and stripping obsolete Cline/MCP cruft. Use for "migrate_clinerules", "convert my project.md", or "import .clinerules".
argument-hint: "[path-to-.clinerules/project.md]"
allowed-tools: Bash(ls:*), Bash(cat:*), Bash(find:*), Bash(test:*), Read, Glob, Grep, Write, Edit
---

# migrate_clinerules — convert a legacy `.clinerules/project.md` into `CLAUDE.md`

Translate a project's old codeops-mcp `.clinerules/project.md` (the Cline/MCP era format) into
the lean Claude Code `CLAUDE.md`. This is a **format translation that preserves the user's
hand-authored content** — it is *not* a fresh scan. For a from-scratch scan, use
`/analyze_project` instead.

Target source is `$ARGUMENTS` if provided, otherwise `./.clinerules/project.md`.

## Step 1 — Locate and read the source (read-only)

- Resolve the source file: `$ARGUMENTS`, else `./.clinerules/project.md`. If neither exists,
  stop and tell the user there is nothing to migrate (suggest `/analyze_project` to generate a
  fresh `CLAUDE.md` instead).
- Read the source in full. Also check whether a `CLAUDE.md` already exists at the project root.

## Step 2 — Map sections (preserve user content verbatim)

Translate the old structure into the new `CLAUDE.md` template (see `/analyze_project` for the
canonical template). Carry hand-authored prose across **verbatim** — never paraphrase the user's
conventions, special rules, or env notes.

| Old `.clinerules/project.md` section | New `CLAUDE.md` section |
|---|---|
| Project Overview (Name, Description, Type) | `## Overview` |
| Toolchain (Language, Framework, Package Manager, Test) | `## Toolchain` |
| Commands (Build / Test / Verify / Clean) | `## Commands` |
| Project Structure (layout, source & test locations) | `## Project structure` |
| Import & Module Conventions + Coding Conventions | `## Conventions` (merge the two) |
| Git & Commit Conventions | `## Git conventions` |
| Environment & Dependencies | `## Special rules` (or its own short section) |
| Special Rules (Project-Specific) | `## Special rules` (append, verbatim) |

## Step 3 — Strip the obsolete Cline/MCP cruft

These sections existed only for Cline + the old MCP and **must not** be carried over:

- **🚨 "MANDATORY: Load CodeOps Rules" / `get_rule(...)` block** — drop entirely. Skills now
  auto-load; there is nothing to pre-load.
- **"Terminal Delay" section, and the `clear && sleep [n] &&` prefix on every command** — strip
  the prefix so each command is the bare runnable command (e.g. `clear && sleep 3 && yarn build`
  → `yarn build`). That prefix was a VS Code/Cline terminal workaround.
- **"Agent Automation" (`scripts/agent.sh start/finished`)** — drop; Cline Act Mode only.
- **"Cross-References" to old rule files** (`make_plan.md`, `code.md`, `testing.md`,
  `agents.md`, `git-commands.md`, `requirements.md`, `roadmap.md`) — drop; those are skills now.
- **Roadmap directive prose** tied to `get_rule("roadmap")` — drop the MCP phrasing; the roadmap
  skill is invoked directly.
- **Empty template placeholders** (`[fill in]`, unchecked `[ ]` boxes, untouched examples) — omit
  rather than copy. Keep only fields the user actually filled in. Mark genuine unknowns as
  `TODO:` so they are visible.

## Step 4 — Write or merge `CLAUDE.md`

- **If no `CLAUDE.md` exists:** write the converted file at the project root.
- **If `CLAUDE.md` already exists:** merge non-destructively — fill empty/auto-detectable
  sections from the conversion, but never overwrite content the user already has in `CLAUDE.md`.
  On any genuine conflict, keep the existing `CLAUDE.md` value and note the alternative from
  `project.md` in a `<!-- migrate_clinerules: project.md had "<x>" -->` comment for the user.
- Append a `<!-- migrated from .clinerules/project.md on <date> -->` marker.
- **Do not delete** the original `.clinerules/project.md` — leave it for the user to remove once
  they have reviewed the result.

## Step 5 — Report

Print:
- The source path and the `CLAUDE.md` path written/merged.
- Which sections were carried over, which were **dropped as obsolete** (name them), and any
  command prefixes stripped.
- Any `TODO:` placeholders the user should fill in.
- A suggestion to run `/analyze_project` afterward to refresh the auto-detectable Toolchain /
  Commands / Project-structure sections against the current code, and to delete
  `.clinerules/project.md` once satisfied.
