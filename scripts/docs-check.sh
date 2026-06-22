#!/usr/bin/env bash
#
# docs-check.sh — specification-test suite for the docs website (plans/docs-website).
#
# Each check maps to a spec test case (ST-n) in plans/docs-website/07-testing-strategy.md.
# It asserts the STRUCTURE of the VitePress docs site, its config, the gitignore entries, and
# the deploy workflow — independently of the page prose. It never executes repo data as code;
# it only reads and pattern-matches files (mirrors scripts/validate.sh's policy).
#
# Usage:  ./scripts/docs-check.sh
# Exit:   0 = all checks pass (green); non-zero = at least one check failed (red).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

CONFIG="docs/.vitepress/config.ts"
GITIGNORE=".gitignore"
BASE_PATH="/claude-codeops/"

FAILURES=0

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# file_has <file> <fixed-string> — true if the file exists and contains the literal substring.
file_has() {
  local f="$1" needle="$2"
  [[ -f "$f" ]] && grep -qF -- "$needle" "$f"
}

# -----------------------------------------------------------------------------
# ST-3 — VitePress config sets the GitHub Pages base path
# -----------------------------------------------------------------------------
section "ST-3: VitePress base path is \"$BASE_PATH\""
if [[ -f "$CONFIG" ]]; then
  # Accept single or double quotes around the base value.
  if grep -Eq "base:[[:space:]]*['\"]${BASE_PATH}['\"]" "$CONFIG"; then
    pass "$CONFIG declares base: '$BASE_PATH'"
  else
    fail "$CONFIG does not declare base: '$BASE_PATH'"
  fi
else
  fail "$CONFIG is missing"
fi

# -----------------------------------------------------------------------------
# ST-9 — Node / VitePress build artifacts are git-ignored
# -----------------------------------------------------------------------------
section "ST-9: build artifacts are git-ignored"
for entry in "node_modules/" "docs/.vitepress/dist" "docs/.vitepress/cache"; do
  if file_has "$GITIGNORE" "$entry"; then
    pass "$GITIGNORE ignores $entry"
  else
    fail "$GITIGNORE does not ignore $entry"
  fi
done

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
section "Summary"
if [[ "$FAILURES" -eq 0 ]]; then
  printf '  \033[32mAll docs checks passed.\033[0m\n'
  exit 0
else
  printf '  \033[31m%d docs check(s) failed.\033[0m\n' "$FAILURES"
  exit 1
fi
