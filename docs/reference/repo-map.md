# Repository map

The repo root **is** the plugin root (the marketplace manifest uses `source: "."`).

```text
codeops-skills/                # repo root == plugin root
├── .claude-plugin/
│   ├── marketplace.json       # marketplace manifest (source: ".")
│   └── plugin.json            # plugin manifest (no version → rolling updates)
├── skills/                    # 9 skills → /codeops:<name>
│   ├── make_plan/             #   create a multi-document implementation plan
│   ├── exec_plan/             #   execute a plan task-by-task (commit modes)
│   ├── make_requirements/     #   gather/add/review requirements (RDs)
│   ├── retro_requirements/    #   reverse-engineer a codebase into requirements
│   ├── grill_me/              #   relentless disambiguation interview
│   ├── preflight/             #   13-dimension quality audit of a plan/requirements
│   ├── techdocs/              #   VitePress architecture docs + ADRs
│   ├── roadmap/               #   feature-set lifecycle tracker
│   └── upgrade_plan/          #   upgrade outdated plans/requirements
├── commands/                  # 13 slash commands → /codeops:<name>
│   ├── gitcm.md / gitcmp.md   #   commit (and push) with a Conventional Commit message
│   ├── analyze_project.md     #   generate/refresh this project's CLAUDE.md
│   ├── migrate_clinerules.md  #   convert a legacy .clinerules/project.md → CLAUDE.md
│   └── …                      #   + thin alias commands that delegate to a parent skill
├── hooks/hooks.json           # SessionStart hook → injects the standards every session
├── standards/coding-standards.md  # always-on standards (single source)
├── scripts/validate.sh        # pre-push validation guard
├── docs/                      # this VitePress documentation website
├── install.sh / uninstall.sh  # optional in-repo dev installer (symlink loop)
├── LICENSE                    # MIT
├── TUTORIAL.md                # end-to-end walkthrough
└── CHANGES.md                 # migration record
```

## What the plugin loader reads

Only `skills/`, `commands/`, `hooks/`, and `.claude-plugin/` are meaningful to Claude Code's plugin
loader. The `docs/` site, `package.json`, and `.github/` workflows are inert to it — they exist for
this documentation website and its deployment, and do not affect the installed plugin.
