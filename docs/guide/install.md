# Install

## Prerequisites

- **Claude Code** installed and working (`claude` launches and you can open a session).
- A **GitHub account / git access** — the marketplace is added by git reference, so Claude Code
  needs to be able to clone the repo.
- Nothing else. No Node, Python, or build step is required to *use* the plugin.

## Install the plugin (recommended)

Inside Claude Code, add this repo as a marketplace and install the plugin:

```text
/plugin marketplace add blendsdk/claude-codeops
/plugin install codeops@codeops-marketplace
```

That's it — skills, commands, **and the always-on coding standards are active immediately**. No
`CLAUDE.md` editing and no manual merge: a bundled `SessionStart` hook injects the standards into
every session automatically (see [Concepts → Always-on standards](/guide/concepts#always-on-standards)).

::: tip Why the git form?
The plugin's manifest uses `source: "."` (the repo root *is* the plugin). That only resolves when
the marketplace is added via a **git reference** like `blendsdk/claude-codeops` — not via a raw file
URL.
:::

## Next

- [Verify it loaded](/guide/verify)
- [Keep it up to date](/guide/update)

## Alternative: the dev installer

If you want to live-edit the skills themselves, there is an in-repo dev installer that symlinks the
`skills/` and `commands/` folders into `~/.claude/` so a `git pull` propagates edits with no
reinstall:

```bash
./install.sh            # symlink skills + commands into ~/.claude/ (recommended)
./install.sh --copy     # install detached copies instead of symlinks
./install.sh --dry-run  # preview, change nothing
./uninstall.sh          # reverse it (restores any backups)
```

The dev installer gives you **short** names (`/make_plan`); the plugin gives you **namespaced**
names (`/codeops:make_plan`).

::: warning Pick one, not both
Running the plugin *and* the dev installer at the same time installs the same skills twice and you
will see duplicates. The dev installer also does **not** install the standards hook (that is a
plugin-only mechanism) — if you use the installer and still want the always-on standards, merge
`standards/coding-standards.md` into your `~/.claude/CLAUDE.md` by hand.
:::
