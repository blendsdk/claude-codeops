# CodeOps for Claude Code

The CodeOps AI-development workflow — **11 skills + 16 slash commands + always-on coding
standards** — packaged as an installable [Claude Code plugin](https://code.claude.com/docs/en/plugins).

Ported from the original [`codeops-mcp`](https://github.com/blendsdk/codeops-mcp) server (built for
Cline) to native Claude Code. The MCP server existed to load rule documents on demand so the context
window wouldn't blow up; Claude Code does that natively via **skill progressive disclosure** (only
each skill's name + description load up front, the body loads when used). So the machinery is gone
and only the knowledge remains. See [CHANGES.md](CHANGES.md) for the full migration record.

> 📖 **Documentation site:** <https://blendsdk.github.io/claude-codeops/> — full guides, a usage page
> for every skill, and end-to-end tutorials.
>
> **New here?** Follow the step-by-step [TUTORIAL.md](TUTORIAL.md) — it walks install → verify →
> use → update on a fresh machine.

**What's new in 3.3.0 — token efficiency.** Measured against two production repos and an A/B
pilot: execution plans carry each task **once** (single checkbox list — the Master Progress
Checklist is gone from new plans; old plans run unchanged, no migration), verify runs are
**output-captured** (a PASS one-liner or a 50-line failure tail instead of the full build/test
dump), plan documents **cite instead of restating** (one owning doc per fact), and execution is
**inline-first** (phases run inline on the tagged model; whole-phase dispatch only when a cheaper
model is warranted). Validated at ~16% fewer tokens per plan on a small project at full quality
parity — more on repos with verbose verify chains. Details in [CHANGES.md](CHANGES.md).

## Install (recommended): the plugin

Inside Claude Code, add this repo as a marketplace and install the plugin:

```text
/plugin marketplace add blendsdk/claude-codeops
/plugin install codeops@codeops-marketplace
```

That's it — skills, commands, **and the always-on coding standards are active immediately**. No
`CLAUDE.md` editing and no manual merge: a bundled `SessionStart` hook injects the standards into
every session automatically (see [Always-on standards](#always-on-standards) below).

> The marketplace must be added **via git** (`add <org>/<repo>`), as shown — that is what lets the
> plugin's `source: "."` resolve to the repo root. A raw-URL add will not resolve it.

## Verify it loaded

Inside Claude Code:
- Ask **"What skills are available?"** — the CodeOps skills should be listed.
- Type `/` and look for the namespaced commands `/codeops:make_plan`, `/codeops:exec_plan`,
  `/codeops:gitcm`, `/codeops:gitcmp`, … (plugin skills/commands are namespaced under `codeops:`).
- Run `/doctor` to confirm no skill descriptions are being truncated.

## Updating

This plugin uses **rolling updates** — installs follow the marketplace's latest commit; the
`version` field in `plugin.json` names the release you're running (visible in `/plugin list`)
without gating updates. To pick up the latest:

```text
/plugin update codeops@codeops-marketplace
```

Every push to the repo is immediately installable; there is no version bump to wait for. A fresh
session may be needed for newly added directories to be watched.

## Uninstalling

```text
/plugin uninstall codeops@codeops-marketplace
```

Disabling or uninstalling the plugin also turns off the standards hook — there is nothing left
behind in your `~/.claude/CLAUDE.md` to clean up (because the plugin never edited it).

## Always-on standards

The plugin bundles a single source of truth for the universal coding/testing/working-style
standards: [`standards/coding-standards.md`](standards/coding-standards.md). A `SessionStart`
hook ([`hooks/hooks.json`](hooks/hooks.json)) `cat`s that file into the context of every new
session, so the standards are always present with **zero setup**.

- This fires on every session start (including after `/clear` and context compaction).
- It is read-only — the hook only reads a file shipped inside the plugin; it never writes anything.
- To turn it off, disable the plugin. There is no separate toggle.
- If you prefer the classic approach, you *can* still merge `standards/coding-standards.md` into your
  global `~/.claude/CLAUDE.md` by hand — but with the plugin that is unnecessary and would duplicate
  the content.

## Developing the skills (optional)

If you want to live-edit the skills themselves, there is an in-repo dev installer that symlinks the
`skills/` and `commands/` folders into `~/.claude/` so a `git pull` propagates edits with no
reinstall:

```bash
./install.sh            # symlink skills + commands into ~/.claude/ (recommended)
./install.sh --copy     # install detached copies instead of symlinks
./install.sh --dry-run  # preview, change nothing
./uninstall.sh          # reverse it (restores any backups)
./scripts/validate.sh   # pre-push guard: validates manifests, hook, standards, descriptions
```

The dev installer gives you **short** names (`/make_plan`); the plugin gives you **namespaced**
names (`/codeops:make_plan`). **Pick one — the plugin OR the dev installer, not both** — or you will
see duplicate skills. Note the dev installer does *not* install the standards hook (that is a plugin
mechanism); see [Always-on standards](#always-on-standards) for the manual-merge alternative.

## What's here

```text
codeops-skills/                # repo root == plugin root
├── .claude-plugin/
│   ├── marketplace.json       # marketplace manifest (source: ".")
│   └── plugin.json            # plugin manifest (version tracks the release)
├── skills/                    # 11 skills → /codeops:<name>
│   ├── make_plan/             #   create a multi-document implementation plan
│   ├── exec_plan/             #   execute a plan task-by-task (commit modes)
│   ├── make_requirements/     #   gather/add/review requirements (RDs)
│   ├── retro_requirements/    #   reverse-engineer a codebase into requirements
│   ├── grill_me/              #   relentless disambiguation interview
│   ├── preflight/             #   13-dimension quality audit of a plan/requirements
│   ├── techdocs/              #   VitePress architecture docs + ADRs
│   ├── roadmap/               #   feature-set lifecycle tracker
│   ├── upgrade_plan/          #   upgrade outdated plans/requirements
│   ├── setup_routing/         #   per-project model & effort routing (Opus/Sonnet by tag)
│   └── setup_codeops/         #   scaffold / migrate a repo into the nested codeops/ layout
├── commands/                  # 16 slash commands → /codeops:<name>
│   ├── gitcm.md / gitcmp.md   #   commit (and push) with a Conventional Commit message
│   ├── analyze_project.md     #   generate/refresh this project's CLAUDE.md
│   ├── migrate_clinerules.md  #   convert a legacy .clinerules/project.md → CLAUDE.md
│   └── …                      #   + thin alias commands that delegate to a parent skill
├── hooks/hooks.json           # SessionStart hook → injects the standards every session
├── standards/coding-standards.md  # always-on coding/testing/working-style standards (single source)
├── scripts/validate.sh        # pre-push validation guard
├── install.sh / uninstall.sh  # optional in-repo dev installer (symlink loop)
├── LICENSE                    # MIT
├── TUTORIAL.md                # end-to-end walkthrough
└── CHANGES.md                 # migration record
```

## Usage at a glance

| You type / say | What happens |
|---|---|
| `make a plan` / `make_plan` | Clarifying interview → Zero-Ambiguity Gate → `plans/<feature>/` doc set (deduplicated: each task stated once, documents cite their owning doc) |
| `exec_plan <feature> [--auto-commit]` | Implements the plan task-by-task — inline-first, verify output captured to a log — verifying and committing per mode |
| `make_requirements` / `add_requirement` / `review_requirements` | Requirements discovery / add one RD / health-check |
| `retro_requirements [--scope <path>]` | Reverse-engineer a codebase into a reconstruction brief |
| `grill_me [topic]` | Relentless design-disambiguation interview |
| `preflight <artifact>` | Adversarial, codebase-grounded quality audit |
| `make_techdocs` / `review_techdocs` | Create/maintain VitePress architecture docs + ADRs |
| `make_roadmap` / `update_roadmap` / … | Track a whole feature-set across its lifecycle |
| `upgrade_plan <feature>` / `upgrade_requirements` | Bring an outdated artifact to current standards |
| `setup_routing` / `/setup_routing` | Analyze the repo, then wire per-project model & effort routing (Opus/Sonnet by task tag) into `CLAUDE.md` + `.claude/agents/` |
| `setup_codeops` / `/setup_codeops` | Scaffold a fresh `codeops/` skeleton, or auto-migrate an existing flat `requirements/` + `plans/` layout into the nested layout (preview → one confirmation → `git mv`) |
| `/gitcm` / `/gitcmp` | Commit (and push) with a detailed Conventional Commit message |
| `/analyze_project` | Generate/refresh this project's `CLAUDE.md` |
| `/migrate_clinerules` | Convert a legacy `.clinerules/project.md` into `CLAUDE.md` |

The consolidated skills cover several verbs each, and thin **alias commands** make each verb directly
typeable (they delegate to the parent skill in the right mode): `/add_requirement`,
`/review_requirements` → `make_requirements`; `/make_techdocs`, `/review_techdocs` → `techdocs`;
`/make_roadmap`, `/update_roadmap`, `/review_roadmap`, `/archive_roadmap` → `roadmap`;
`/upgrade_requirements` → `upgrade_plan`; `/setup_routing` → `setup_routing`; `/setup_codeops` →
`setup_codeops`. These aliases are manual-only — only the parent skills auto-trigger from natural
language.

The skills compose into the original CodeOps pipelines, e.g.
`grill_me → make_requirements → preflight → make_plan → preflight → exec_plan`, with `roadmap`
tracking it all and `techdocs` keeping architecture docs current.

## License

MIT — see [LICENSE](LICENSE).
