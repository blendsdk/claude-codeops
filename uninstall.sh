#!/usr/bin/env bash
#
# uninstall.sh — cleanly reverse install.sh.
#
# Reads the manifest written by install.sh and removes every skill/command it installed
# (symlink or copy), then restores anything that was backed up during install.
# If the manifest is missing, falls back to removing only the known CodeOps skill/command
# names that are symlinks pointing back into this repo (safe — never touches your own files).
#
# Usage:
#   ./uninstall.sh            # reverse the install
#   ./uninstall.sh --dry-run  # show what would happen, change nothing
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR"
CLAUDE_DIR="${CLAUDE_HOME:-$HOME/.claude}"
DEST_SKILLS="$CLAUDE_DIR/skills"
DEST_COMMANDS="$CLAUDE_DIR/commands"
DEST_SHARED="$CLAUDE_DIR/_shared"
MANIFEST="$CLAUDE_DIR/.codeops-skills-manifest"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { sed -n '2,13p' "$0"; exit 0; }

say() { printf '%s\n' "$*"; }
run() { if [ "$DRY_RUN" -eq 1 ]; then say "  [dry-run] $*"; else eval "$*"; fi; }

say "CodeOps skills uninstaller"
DRYLABEL=""; [ "$DRY_RUN" -eq 1 ] && DRYLABEL="  (dry-run)"
say "  target : $CLAUDE_DIR$DRYLABEL"
say ""

removed=0 restored=0

if [ -f "$MANIFEST" ]; then
  say "Using manifest: $MANIFEST"
  # First pass: remove installed paths (non-BACKUP lines).
  while IFS= read -r line; do
    case "$line" in
      \#*|"") continue ;;
      BACKUP*) continue ;;
    esac
    if [ -e "$line" ] || [ -L "$line" ]; then
      say "  - remove $(basename "$line")"
      run "rm -rf \"$line\""
      removed=$((removed+1))
    fi
  done < "$MANIFEST"

  # Second pass: restore backups (BACKUP \t original \t backup).
  while IFS=$'\t' read -r tag original backup; do
    [ "$tag" = "BACKUP" ] || continue
    if [ -e "$backup" ] || [ -L "$backup" ]; then
      say "  ^ restore $(basename "$original")"
      run "mv \"$backup\" \"$original\""
      restored=$((restored+1))
    fi
  done < "$MANIFEST"

  run "rm -f \"$MANIFEST\""
else
  say "No manifest found — falling back to removing CodeOps symlinks that point into this repo."
  for d in "$SRC/skills"/*/; do
    [ -d "$d" ] || continue
    t="$DEST_SKILLS/$(basename "${d%/}")"
    if [ -L "$t" ] && [ "$(readlink "$t")" = "${d%/}" ]; then
      say "  - remove $(basename "$t")"; run "rm -f \"$t\""; removed=$((removed+1))
    fi
  done
  for f in "$SRC/commands"/*.md; do
    [ -f "$f" ] || continue
    t="$DEST_COMMANDS/$(basename "$f")"
    if [ -L "$t" ] && [ "$(readlink "$t")" = "$f" ]; then
      say "  - remove $(basename "$t")"; run "rm -f \"$t\""; removed=$((removed+1))
    fi
  done
  # Shared reference docs mirror ($DEST_SHARED), only if it points back into this repo.
  if [ -L "$DEST_SHARED" ] && [ "$(readlink "$DEST_SHARED")" = "$SRC/_shared" ]; then
    say "  - remove _shared"; run "rm -f \"$DEST_SHARED\""; removed=$((removed+1))
  fi
fi

say ""
say "Done. Removed $removed item(s), restored $restored backup(s)."
say "Note: if you optionally merged standards/coding-standards.md into ~/.claude/CLAUDE.md by hand,"
say "this script does NOT touch it — remove that section yourself if you want it gone. (The plugin's"
say "SessionStart standards hook is removed automatically when you uninstall/disable the plugin.)"
