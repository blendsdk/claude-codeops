# Repository map

The repo root **is** the plugin root (the marketplace manifest uses `source: "."`).

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
│   ├── setup_codeops/         #   scaffold or migrate to the nested codeops/ layout
│   └── setup_routing/         #   per-project model & effort routing (Opus/Sonnet by tag)
├── commands/                  # 15 slash commands → /codeops:<name>
│   ├── gitcm.md / gitcmp.md   #   commit (and push) with a Conventional Commit message
│   ├── analyze_project.md     #   generate/refresh this project's CLAUDE.md
│   ├── migrate_clinerules.md  #   convert a legacy .clinerules/project.md → CLAUDE.md
│   └── …                      #   + thin alias commands that delegate to a parent skill
├── _shared/                   # shared reference docs (layout convention, gates, hardening)
├── agents/                    # plugin-shipped executor subagents (plan-task-executor*)
├── hooks/hooks.json           # SessionStart standards hook + PreToolUse marker guard
├── standards/coding-standards.md  # always-on standards (single source)
├── scripts/                   # validate.sh, docs-check.sh, migration-check.sh,
│                              #   codeops-migrate.sh, codeops-roadmap-sync.sh, fixtures/
├── docs/                      # this VitePress documentation website
├── install.sh / uninstall.sh  # optional in-repo dev installer (symlink loop)
├── LICENSE                    # MIT
├── TUTORIAL.md                # end-to-end walkthrough
└── CHANGES.md                 # changelog + migration record
```

## What the plugin loader reads

Only `skills/`, `commands/`, `agents/`, `hooks/`, and `.claude-plugin/` are meaningful to Claude
Code's plugin loader (`_shared/` is read via relative links from the skills). The `docs/` site, `package.json`, and `.github/` workflows are inert to it — they exist for
this documentation website and its deployment, and do not affect the installed plugin.
