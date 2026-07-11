# Parallel agents

Run several Claude Code agents at once on one repo — one per feature — without them colliding on
shared files. This page covers the workflow and how to adopt it in an existing project.

## The idea

Give each concurrent agent its own **git worktree** on its own `feat/*` branch. A worktree is a
second working folder that shares the repo's one `.git`, so you never re-clone. The number of
folders you need is the number of agents running **at once**, not the number of features.

Per-feature CodeOps files (under `codeops/features/<f>/`) are already isolated, so they never clash.
The only shared surfaces are **derived** files — the portfolio roadmap (`codeops/00-roadmap.md`),
the generated sections of `CLAUDE.md`, and the `setup_routing` block. CodeOps treats these as
derived: it **does not rewrite them on a feature branch**; they are regenerated once on the
**integration branch** (where features merge — `master`, `main`, or `devel`).

## Spin up a worktree

The `codeops-worktree` helper does the git plumbing:

```bash
codeops-worktree new billing            # → branch feat/billing in ../<repo>-billing
codeops-worktree new billing --launch   # ...and start `claude` in it
codeops-worktree ls                      # list worktrees
codeops-worktree rm billing              # tear it down when merged
```

It picks a sensible base branch, places the worktree as a sibling folder, and prints
parallel-safety reminders. Add `--dry-run` to preview. It ships with the in-repo dev installer
(onto `~/.local/bin`); marketplace-plugin users symlink `bin/codeops-worktree` there by hand. On
Windows, run it from **Git Bash** or **WSL**. See [Install](/guide/install).

## Why there are no conflicts

Each skill that writes a derived file is **branch-aware**:

- **Roadmap** — on a feature branch, a stage transition updates only that feature's roadmap and
  **defers** the portfolio write. `update the roadmap` reconciles the portfolio on the integration
  branch.
- **`analyze_project`** — on a feature branch it **previews** (and can stage hand-written notes to
  `codeops/features/<f>/CLAUDE.notes.md`); it regenerates and folds those notes on the integration
  branch.
- **`setup_routing`** — its `CLAUDE.md` routing block is an integration-branch write; on a feature
  branch it warns and skips.

The branch is resolved from the optional `integrationBranch` key in `codeops/.codeops.yml`, falling
back to the repo's default branch (`origin/HEAD`, else `main`/`master`). If the key is absent
everything still works — it's just auto-detected.

## After the PRs merge

On the integration branch, reconcile the derived files once:

```
update the roadmap        # regenerates the portfolio from the per-feature roadmaps
analyze_project           # regenerates CLAUDE.md, folds any staged notes
```

Any portfolio-roadmap merge conflict is safe to resolve by taking either side — it's regenerable —
then `update the roadmap` makes it correct.

## Adopting this in an existing project

It's additive and opt-in — nothing breaks if you don't adopt it.

1. Update the plugin (or `git pull` + `./install.sh` for the dev installer).
2. Run **`setup_codeops`** once — on a nested repo it backfills the `integrationBranch` key; a flat
   repo is migrated to the nested layout first (which also writes the key). See
   [Install](/guide/install) and the [setup_codeops skill](/skills/setup_codeops).
3. Put `codeops-worktree` on your `PATH`.
4. Do one integration-branch reconcile (above) to clean any pre-existing divergence.

No document migration is needed — existing roadmap and `CLAUDE.md` files are already compatible.
