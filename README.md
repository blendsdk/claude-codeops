# CodeOps Skills for Claude Code

The CodeOps AI-development workflow, ported from the original [`codeops-mcp`](https://github.com/blendsdk/codeops-mcp)
server (built for Cline) to **native Claude Code skills and slash commands**.

The MCP server existed to load rule documents on demand so Cline's context window wouldn't blow
up. Claude Code does that natively via **skill progressive disclosure** — only each skill's
name + description load up front; the full body loads when the skill is actually used. So the
machinery is gone and only the knowledge remains.

See [CHANGES.md](CHANGES.md) for the full migration record (what was removed, what was enhanced).

## What's here

```
codeops-skills/
├── skills/                 # 9 skills → ~/.claude/skills/<name>/SKILL.md
│   ├── make_plan/          #   create a multi-document implementation plan
│   ├── exec_plan/          #   execute a plan task-by-task (commit modes)
│   ├── make_requirements/  #   gather/add/review requirements (RDs)
│   ├── retro_requirements/ #   reverse-engineer a codebase into requirements
│   ├── grill_me/           #   relentless disambiguation interview
│   ├── preflight/          #   13-dimension quality audit of a plan/requirements
│   ├── techdocs/           #   VitePress architecture docs + ADRs
│   ├── roadmap/            #   feature-set lifecycle tracker
│   └── upgrade_plan/       #   upgrade outdated plans/requirements
├── commands/               # 13 slash commands → ~/.claude/commands/<name>.md
│   ├── gitcm.md            #   commit (file-based Conventional Commit message)
│   ├── gitcmp.md           #   commit + rebase + push, with conflict protocol
│   ├── analyze_project.md  #   generate/refresh this project's CLAUDE.md
│   ├── migrate_clinerules.md # convert a legacy .clinerules/project.md → CLAUDE.md
│   └── …                   #   + thin alias commands that delegate to a parent skill:
│                           #     add_requirement, review_requirements → make_requirements
│                           #     make_techdocs, review_techdocs        → techdocs
│                           #     make_roadmap, update_roadmap,
│                           #       review_roadmap, archive_roadmap      → roadmap
│                           #     upgrade_requirements                   → upgrade_plan
├── CLAUDE.md.snippet       # always-on coding/testing standards (merge into global CLAUDE.md)
├── CHANGES.md              # migration record
└── .claude-plugin/         # optional: lets the whole folder install as a plugin
    └── plugin.json
```

## Install (Ubuntu / any Linux/macOS)

From the repo root (one level up):

```bash
./install.sh            # symlink skills + commands into ~/.claude/ (recommended)
./install.sh --copy     # install detached copies instead of symlinks
./install.sh --dry-run  # preview, change nothing
```

Symlinks mean a `git pull` in this repo updates your installed skills with no reinstall.
The installer backs up anything it would overwrite and records a manifest so `./uninstall.sh`
can reverse everything (and restore backups).

Then, for the always-on standards, merge the snippet into your **global** config:

```bash
cat codeops-skills/CLAUDE.md.snippet >> ~/.claude/CLAUDE.md
```

And, inside any project, generate that project's config:

```
/analyze_project
```

## Verify it loaded

Inside Claude Code:
- Ask **"What skills are available?"** — the CodeOps skills should be listed.
- Type `/` and look for `make_plan`, `exec_plan`, `make_requirements`, `retro_requirements`,
  `grill_me`, `preflight`, `techdocs`, `roadmap`, `upgrade_plan`, `gitcm`, `gitcmp`,
  `analyze_project`, `migrate_clinerules`.
- Run `/doctor` to confirm no skill descriptions are being truncated.

> Creating brand-new top-level `~/.claude/skills` or `~/.claude/commands` directories may need a
> Claude Code restart (so the new directory starts being watched). Edits to already-installed
> skills are picked up live.

## Usage at a glance

| You type / say | What happens |
|---|---|
| `make a plan` / `make_plan` | Clarifying interview → Zero-Ambiguity Gate → `plans/<feature>/` doc set |
| `exec_plan <feature> [--auto-commit]` | Implements the plan task-by-task, verifying and committing per mode |
| `make_requirements` / `add_requirement` / `review_requirements` | Requirements discovery / add one RD / health-check |
| `retro_requirements [--scope <path>]` | Reverse-engineer a codebase into a reconstruction brief |
| `grill_me [topic]` | Relentless design-disambiguation interview |
| `preflight <artifact>` | Adversarial, codebase-grounded quality audit |
| `make_techdocs` / `review_techdocs` | Create/maintain VitePress architecture docs + ADRs |
| `make_roadmap` / `update_roadmap` / … | Track a whole feature-set across its lifecycle |
| `upgrade_plan <feature>` / `upgrade_requirements` | Bring an outdated artifact to current standards |
| `/gitcm` / `/gitcmp` | Commit (and push) with a detailed Conventional Commit message |
| `/analyze_project` | Generate/refresh this project's `CLAUDE.md` |
| `/migrate_clinerules` | Convert a legacy `.clinerules/project.md` into `CLAUDE.md` |

Every original trigger word is also a typeable command. The consolidated skills cover several
verbs each, and thin **alias commands** make each verb directly typeable (they delegate to the
parent skill in the right mode): `/add_requirement`, `/review_requirements` → `make_requirements`;
`/make_techdocs`, `/review_techdocs` → `techdocs`; `/make_roadmap`, `/update_roadmap`,
`/review_roadmap`, `/archive_roadmap` → `roadmap`; `/upgrade_requirements` → `upgrade_plan`.
These aliases are manual-only — only the parent skills auto-trigger from natural language.

The skills compose into the original CodeOps pipelines, e.g.
`grill_me → make_requirements → preflight → make_plan → preflight → exec_plan`, with `roadmap`
tracking it all and `techdocs` keeping architecture docs current.

## Optional: install as a plugin

This folder is also a valid plugin root (see `.claude-plugin/plugin.json`). Plugin skills are
namespaced (`/codeops:make_plan`). To try it without installing:

```bash
claude --plugin-dir ./codeops-skills
```

Standalone install (above) gives you short names (`/make_plan`); the plugin gives you shareable,
versioned, namespaced distribution. Pick one — don't run both at once or you'll see duplicates.
# claude-codeops
