# Troubleshooting

| Symptom | Fix |
|---|---|
| New skills/commands don't appear after install/update | Start a fresh session so newly added directories start being watched. |
| `/doctor` flags a truncated skill description | A description exceeds Claude Code's display budget; shorten it (the dev guard `./scripts/validate.sh` enforces ≤ 1024 chars). |
| Standards don't show up in a new session | Confirm the plugin is enabled (`/plugin`); the hook runs at **session start**, so open a new session. |
| `source: "."` won't resolve / install fails | Make sure you added the marketplace via the **git** form (`/plugin marketplace add blendsdk/claude-codeops`), not a raw URL. |
| Duplicate skills (short *and* namespaced) | You have both the dev installer and the plugin active — run `./uninstall.sh` to drop the symlinked copies. |

## Still stuck?

- Re-read [Install](/guide/install) and [Verify](/guide/verify).
- Open an issue at [github.com/blendsdk/claude-codeops/issues](https://github.com/blendsdk/claude-codeops/issues).
