#!/usr/bin/env bash
#
# pytest-check.sh — run the Python specification and implementation suites, tolerating absence.
#
# CodeOps Skills Version: 3.14.0
#
# The repository's engines are Bash entry points with embedded Python; modules with an
# independent unit-test surface are standalone .py files instead, and those are covered by
# pytest rather than a Bash spec suite.
#
# pytest is a development-only dependency: it is never needed to install, load, or run the
# plugin. A contributor without the dev environment must still be able to run the full verify
# chain, so an absent pytest reports which coverage was skipped and exits 0. Only a genuine
# test failure is red.
#
# Usage:  ./scripts/pytest-check.sh
# Exit:   0 = suites passed, or pytest is unavailable (skipped with notice);
#         1 = at least one test failed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TESTS_DIR="tests"

if [[ ! -d "$TESTS_DIR" ]]; then
  printf '  \033[33mSKIP\033[0m no %s/ directory — nothing to run\n' "$TESTS_DIR"
  exit 0
fi

# Prefer a project-local virtualenv when one exists, so a contributor who created .venv/ does
# not have to activate it by hand; fall back to whatever python3 is on PATH.
PY="python3"
if [[ -x ".venv/bin/python" ]]; then
  PY=".venv/bin/python"
fi

if ! command -v "${PY%% *}" >/dev/null 2>&1 && [[ ! -x "$PY" ]]; then
  printf '  \033[33mSKIP\033[0m python3 unavailable — Python suites not run\n'
  exit 0
fi

if ! "$PY" -c 'import pytest' >/dev/null 2>&1; then
  printf '  \033[33mSKIP\033[0m pytest not installed — Python suites under %s/ were NOT run\n' "$TESTS_DIR"
  printf '         install with: python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt\n'
  exit 0
fi

"$PY" -m pytest "$TESTS_DIR" -q
