# Update & uninstall

## Updating

CodeOps uses **rolling updates** — it carries no version number, so the git commit is the version.
To pick up the latest:

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
behind in your `~/.claude/CLAUDE.md` to clean up, because the plugin never edited it.

## Maintainer update loop

If you maintain the skills, the loop is:

```bash
git clone git@github.com:blendsdk/claude-codeops.git
cd claude-codeops
# ...edit a skill or command...
./scripts/validate.sh        # pre-push guard: manifests, hook, standards, descriptions
/codeops:gitcmp              # commit + push → the rolling update is immediately live
```

On every target machine, `/plugin update codeops@codeops-marketplace` pulls the change. No version
bump, no re-publish step.
