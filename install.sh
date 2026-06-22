#!/usr/bin/env bash
#
# install.sh — install the CodeOps skills and commands into your user-level Claude Code config.
#
# This is a DEV convenience for live-editing the skills in this repo. For normal use, install the
# plugin instead (see README.md): the plugin also activates the always-on standards hook, which
# this dev installer does not. Pick one path — the plugin OR this installer — not both.
#
# By default it SYMLINKS each skill folder and command file from this repo into
# ~/.claude/skills/ and ~/.claude/commands/, so `git pull` in this repo propagates updates
# with no reinstall. Use --copy to install detached copies instead.
#
# Idempotent: re-running is safe. Anything it would overwrite is backed up first, and every
# change is recorded in a manifest so uninstall.sh can reverse it cleanly.
#
# Usage:
#   ./install.sh            # symlink (recommended)
#   ./install.sh --copy     # copy instead of symlink
#   ./install.sh --dry-run  # show what would happen, change nothing
#
# Verified install paths (Claude Code docs, code.claude.com/docs/en/skills):
#   personal skills   -> ~/.claude/skills/<name>/SKILL.md
#   personal commands -> ~/.claude/commands/<name>.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SKILLS="$SCRIPT_DIR/skills"
SRC_COMMANDS="$SCRIPT_DIR/commands"

CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
DEST_SKILLS="$CLAUDE_DIR/skills"
DEST_COMMANDS="$CLAUDE_DIR/commands"
MANIFEST="$CLAUDE_DIR/.codeops-skills-manifest"

MODE="symlink"
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --copy)    MODE="copy" ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

TS="$(date +%Y%m%d-%H%M%S)"
DRYLABEL=""; [ "$DRY_RUN" -eq 1 ] && DRYLABEL=" , dry-run"
say()  { printf '%s\n' "$*"; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then say "  [dry-run] $*"; else eval "$*"; fi; }

# Record an installed path so uninstall can find it (skip during dry-run).
record() { [ "$DRY_RUN" -eq 1 ] || printf '%s\n' "$1" >> "$MANIFEST"; }

[ -d "$SRC_SKILLS" ]   || { echo "Missing $SRC_SKILLS — run from the repo root." >&2; exit 1; }
[ -d "$SRC_COMMANDS" ] || { echo "Missing $SRC_COMMANDS — run from the repo root." >&2; exit 1; }

say "CodeOps skills installer"
say "  source : $SCRIPT_DIR"
say "  target : $CLAUDE_DIR  (mode: $MODE$DRYLABEL)"
say ""

run "mkdir -p \"$DEST_SKILLS\" \"$DEST_COMMANDS\""
# Fresh manifest header for this install run.
[ "$DRY_RUN" -eq 1 ] || { : > "$MANIFEST"; printf '# CodeOps skills manifest (mode=%s, %s)\n' "$MODE" "$TS" >> "$MANIFEST"; }

# install_one <source-path> <dest-path>
install_one() {
  local src="$1" dest="$2" name; name="$(basename "$dest")"

  # Already our up-to-date symlink? Skip.
  if [ "$MODE" = "symlink" ] && [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    say "  = $name (already linked)"
    record "$dest"
    return
  fi

  # Back up anything that's already there and isn't our link.
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    local backup="$dest.codeops-bak.$TS"
    say "  ~ $name (backing up existing -> $(basename "$backup"))"
    run "mv \"$dest\" \"$backup\""
    record "$(printf 'BACKUP\t%s\t%s' "$dest" "$backup")"
  fi

  if [ "$MODE" = "symlink" ]; then
    say "  + $name (symlink)"
    run "ln -s \"$src\" \"$dest\""
  else
    say "  + $name (copy)"
    run "cp -R \"$src\" \"$dest\""
  fi
  record "$dest"
}

say "Skills -> $DEST_SKILLS"
for d in "$SRC_SKILLS"/*/; do
  [ -f "$d/SKILL.md" ] || continue
  install_one "${d%/}" "$DEST_SKILLS/$(basename "$d")"
done

say ""
say "Commands -> $DEST_COMMANDS"
for f in "$SRC_COMMANDS"/*.md; do
  [ -f "$f" ] || continue
  install_one "$f" "$DEST_COMMANDS/$(basename "$f")"
done

say ""
say "Done."
[ "$DRY_RUN" -eq 1 ] && { say "(dry-run — nothing changed)"; exit 0; }
say "Manifest: $MANIFEST"
say ""
say "Verify inside Claude Code:"
say "  • Start (or restart) Claude Code, then ask:  What skills are available?"
say "  • Open the menu with  /  and look for: make_plan, exec_plan, make_requirements,"
say "    retro_requirements, grill_me, preflight, techdocs, roadmap, upgrade_plan,"
say "    gitcm, gitcmp, analyze_project, migrate_clinerules — plus alias commands add_requirement,"
say "    review_requirements, make_techdocs, review_techdocs, make_roadmap,"
say "    update_roadmap, review_roadmap, archive_roadmap, upgrade_requirements"
say "  • Run  /doctor  to see if any skill descriptions are being truncated."
say ""
say "Note: creating brand-new top-level skills/commands dirs may require a Claude Code restart"
say "so the new directories start being watched. Edits to existing skills are picked up live."
say ""
say "Global standards: the plugin auto-loads standards/coding-standards.md every session via a"
say "  SessionStart hook (no merge needed). This dev installer does NOT install that hook — if you"
say "  use the installer instead of the plugin, you can optionally merge standards/coding-standards.md"
say "  into ~/.claude/CLAUDE.md by hand."
say "Per-project setup: run  /analyze_project  inside a project to generate its CLAUDE.md"
