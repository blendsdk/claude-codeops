# CodeOps Tutorial — install, use, and update on any machine

This is a copy-pasteable, end-to-end walkthrough for getting the CodeOps plugin onto a fresh
machine, confirming it works, using a skill, and keeping it up to date. For a feature overview, see
[README.md](README.md).

---

## 1. Prerequisites

- **Claude Code** installed and working (`claude` launches and you can open a session).
- A **GitHub account / git access** — the marketplace is added by git reference
  (`blendsdk/claude-codeops`), so Claude Code needs to be able to clone the repo.
- Nothing else. No Node, Python, or build step is required to *use* the plugin. (Python 3 is only
  needed if you run the optional `./scripts/validate.sh` dev guard.)

---

## 2. Install on a fresh machine

Open Claude Code and run, in the prompt:

```text
/plugin marketplace add blendsdk/claude-codeops
/plugin install codeops@codeops-marketplace
```

- The first line registers this repo as a plugin **marketplace** (named `codeops-marketplace`).
- The second installs the `codeops` plugin from it.

> **Why the git form?** The plugin's manifest uses `source: "."` (the repo root *is* the plugin).
> That only resolves when the marketplace is added via a git reference like `blendsdk/claude-codeops`
> — not via a raw file URL.

---

## 3. Confirm it loaded (and that standards auto-loaded)

In a **new** session:

1. Ask: **"What skills are available?"** — you should see the CodeOps skills listed.
2. Type `/` and look for the namespaced commands, e.g. `/codeops:make_plan`, `/codeops:gitcmp`.
3. Ask: **"What coding standards are you following?"** — the model should describe the CodeOps
   standards (DRY, single-responsibility, spec-vs-impl tests, security-from-line-one, etc.)
   **without you having edited any `CLAUDE.md`**. That confirms the `SessionStart` standards hook is
   working.
4. Run `/doctor` and confirm there are no warnings about truncated skill descriptions.

If the standards do not appear, start a brand-new session (the hook runs at session start), and
confirm the plugin is enabled with `/plugin`.

---

## 4. Use a skill end-to-end

Try the planning workflow:

```text
/codeops:make_plan
```

Describe a small feature when prompted. The skill runs a clarifying interview, enforces its
Zero-Ambiguity Gate, and writes a `plans/<feature>/` document set ending in an execution plan. To
implement it:

```text
/codeops:exec_plan <feature-name>
```

This walks the plan task-by-task (spec tests → red → implement → green), updating the execution plan
as it goes.

### Optional: switch on the quality loop

Run `/codeops:setup_routing` in your project and confirm its proposal — it writes a routing block
AND a quality-profile block into the project's `CLAUDE.md`. From then on `exec_plan` ends each
phase with a review by dedicated agents (critical/major findings pause for your ruling in every
commit mode), and local, metadata-only telemetry accrues under `~/.claude/codeops-telemetry/`.
Inspect it any time with `/codeops:codeops_stats`; judge the loop periodically with
`/codeops:codeops_retro`. Removing the block — or setting `review_hook: off` inside it — switches
the loop off again.

---

## 5. Update later

CodeOps uses **rolling updates** — there is no version number, so the latest commit is the latest
version. To upgrade:

```text
/plugin update codeops@codeops-marketplace
```

Whatever has been pushed to `blendsdk/claude-codeops` is now active. (Open a fresh session if a
newly added skill/command directory does not appear immediately.)

---

## 6. Author workflow (maintaining the plugin)

If you maintain the skills, the loop is:

```bash
git clone git@github.com:blendsdk/claude-codeops.git
cd claude-codeops
# ...edit a skill or command...
./scripts/validate.sh        # pre-push guard: manifests, hook, standards, descriptions
/codeops:gitcmp              # commit + push  → the rolling update is immediately live
```

On every target machine, `/plugin update codeops@codeops-marketplace` pulls your change. No version
bump, no re-publish step.

---

## 7. Optional: the dev installer (live-editing)

Instead of the plugin, you can symlink the skills straight into `~/.claude/` for live editing:

```bash
./install.sh              # symlink skills + commands into ~/.claude/
./install.sh --dry-run    # preview only
./uninstall.sh            # reverse it
```

This gives **short** command names (`/make_plan`) instead of namespaced ones (`/codeops:make_plan`).

> **Pick one path, not both.** Running the plugin *and* the dev installer at the same time installs
> the same skills twice and you will see duplicates. To switch from the dev installer back to the
> plugin, run `./uninstall.sh` first, then install the plugin.
>
> The dev installer does **not** install the standards hook (that is a plugin-only mechanism). If you
> use the installer and still want the always-on standards, merge `standards/coding-standards.md`
> into your `~/.claude/CLAUDE.md` by hand.

---

## 8. Troubleshooting

| Symptom | Fix |
|---|---|
| New skills/commands don't appear after install/update | Start a fresh session so newly added directories start being watched. |
| `/doctor` flags a truncated skill description | A description exceeds Claude Code's display budget; shorten it (the dev guard `./scripts/validate.sh` enforces ≤ 1024 chars). |
| Standards don't show up in a new session | Confirm the plugin is enabled (`/plugin`); the hook runs at **session start**, so open a new session. |
| `source: "."` won't resolve / install fails | Make sure you added the marketplace via the **git** form (`/plugin marketplace add blendsdk/claude-codeops`), not a raw URL. |
| Duplicate skills (short *and* namespaced) | You have both the dev installer and the plugin active — run `./uninstall.sh` to drop the symlinked copies. |
