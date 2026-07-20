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
├── commands/                  # 21 slash commands → /codeops:<name>
│   ├── gitcm.md / gitcmp.md   #   commit (and push) with a Conventional Commit message
│   ├── analyze_project.md     #   generate/refresh this project's CLAUDE.md (+ --compact leaning mode)
│   ├── migrate_clinerules.md  #   convert a legacy .clinerules/project.md → CLAUDE.md
│   ├── clean_jsdoc.md         #   retrofit JSDoc/comments to the doc standard (strip plan refs)
│   ├── gh_issues.md           #   adaptive GitHub issues table (repo's own labels/types/fields)
│   ├── gh_close.md            #   guarded close/reopen of issues by number (native close reasons)
│   ├── codeops_stats.md       #   relay the telemetry tables (stats/gaps)
│   ├── codeops_retro.md       #   quality retrospective (thresholds + two-bucket verdicts)
│   └── …                      #   + thin alias commands that delegate to a parent skill
├── _shared/                   # shared reference docs (layout convention, gates, hardening,
│                              #   quality-profile.md — the quality-loop convention)
├── agents/                    # plugin-shipped subagents: 2 executors + 7 quality agents
│                              #   (phase-reviewer, spec-test-author, security-auditor,
│                              #   preflight-auditor, design-challenger, perf-auditor,
│                              #   codebase-scout)
├── hooks/hooks.json           # SessionStart standards + PreToolUse marker guard
│                              #   + PostToolUse telemetry hook
├── standards/coding-standards.md  # always-on standards (single source)
├── standards/output-style.md      # always-on reporting rules (injected beside the standards)
├── scripts/                   # validate.sh, docs-check.sh, migration-check.sh,
│                              #   codeops-migrate.sh, codeops-roadmap-sync.sh,
│                              #   codeops-events.sh (telemetry), telemetry-check.sh, fixtures/
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
