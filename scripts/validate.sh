#!/usr/bin/env bash
#
# validate.sh — pre-push validation guard for the CodeOps plugin marketplace.
#
# This is the executable specification-test suite for the plugin-distribution work
# (see plans/plugin-distribution/07-testing-strategy.md). Each check maps to a spec
# test case (ST-n). The script asserts repo structure/config and exits non-zero with a
# clear message on the first failure class, after running every check so the full set of
# problems is reported in one pass.
#
# Dependency policy: pure bash + python3 for JSON/frontmatter parsing (python3 is the
# only non-coreutils dependency; a structural grep fallback is used if it is absent).
# The script never executes repo data as code — it only reads and parses it.
#
# Usage:  ./scripts/validate.sh
# Exit:   0 = all checks pass (green); non-zero = at least one check failed (red).

set -uo pipefail

# Resolve the repo root as the parent of this script's directory, so the validator can be
# run from any CWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

MARKETPLACE=".claude-plugin/marketplace.json"
PLUGIN=".claude-plugin/plugin.json"
STANDARDS="standards/coding-standards.md"
HOOKS="hooks/hooks.json"
DESC_LIMIT=1024

FAILURES=0

# Detect python3 once; some checks degrade gracefully without it.
HAVE_PY3=0
if command -v python3 >/dev/null 2>&1; then
  HAVE_PY3=1
fi

# pass/fail helpers — keep output uniform and machine-greppable.
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# is_valid_json <file> — true if the file parses as JSON.
is_valid_json() {
  local f="$1"
  if [[ ! -f "$f" ]]; then
    return 2
  fi
  if [[ "$HAVE_PY3" -eq 1 ]]; then
    python3 -m json.tool "$f" >/dev/null 2>&1
  else
    # Structural fallback: must start with '{' and have balanced-looking braces.
    grep -q '{' "$f" && grep -q '}' "$f"
  fi
}

# json_get <file> <python-expr-on-data> — print a value extracted from parsed JSON.
# `data` is the parsed object. Prints nothing (and returns non-zero) on error.
json_get() {
  local f="$1" expr="$2"
  [[ "$HAVE_PY3" -eq 1 ]] || return 3
  python3 - "$f" "$expr" <<'PY' 2>/dev/null
import json, sys
f, expr = sys.argv[1], sys.argv[2]
with open(f) as fh:
    data = json.load(fh)
val = eval(expr, {"__builtins__": {}}, {"data": data})
if val is None:
    sys.exit(1)
print(val)
PY
}

# -----------------------------------------------------------------------------
# ST-1 — manifests are valid JSON
# -----------------------------------------------------------------------------
section "ST-1: manifests are valid JSON"
for f in "$MARKETPLACE" "$PLUGIN"; do
  if is_valid_json "$f"; then
    pass "$f is valid JSON"
  else
    fail "$f is missing or not valid JSON"
  fi
done

# -----------------------------------------------------------------------------
# ST-2 — marketplace.json .plugins[0].source == "."
# -----------------------------------------------------------------------------
section "ST-2: marketplace plugin source is \".\""
if is_valid_json "$MARKETPLACE"; then
  src="$(json_get "$MARKETPLACE" 'data["plugins"][0].get("source")')"
  if [[ "$src" == "." ]]; then
    pass "source == \".\""
  else
    fail "source is \"${src:-<missing>}\", expected \".\""
  fi
else
  fail "cannot check source — $MARKETPLACE not valid JSON"
fi

# -----------------------------------------------------------------------------
# ST-3 — marketplace.json has no top-level "//"-style comment keys
# -----------------------------------------------------------------------------
section "ST-3: no \"//\" comment keys in marketplace.json"
if is_valid_json "$MARKETPLACE"; then
  comment_keys="$(json_get "$MARKETPLACE" '",".join(k for k in data.keys() if k.startswith("//")) or None')"
  if [[ -z "$comment_keys" ]]; then
    pass "no comment keys present"
  else
    fail "comment keys present: $comment_keys"
  fi
else
  fail "cannot check comment keys — $MARKETPLACE not valid JSON"
fi

# -----------------------------------------------------------------------------
# ST-4 — plugin.json has NO version key (rolling updates)
# -----------------------------------------------------------------------------
section "ST-4: plugin.json has no \"version\" key"
if is_valid_json "$PLUGIN"; then
  has_version="$(json_get "$PLUGIN" '"yes" if "version" in data else None')"
  if [[ -z "$has_version" ]]; then
    pass "no version key (rolling updates)"
  else
    fail "version key present — must be removed for rolling updates"
  fi
else
  fail "cannot check version — $PLUGIN not valid JSON"
fi

# -----------------------------------------------------------------------------
# ST-6 — required files exist and are non-empty
# -----------------------------------------------------------------------------
section "ST-6: required files exist and are non-empty"
for f in "$HOOKS" "$STANDARDS" "LICENSE" "README.md" "TUTORIAL.md"; do
  if [[ -s "$f" ]]; then
    pass "$f exists and is non-empty"
  else
    fail "$f is missing or empty"
  fi
done

# -----------------------------------------------------------------------------
# ST-8 — single-source standards: snippet absent, no content lost
# -----------------------------------------------------------------------------
section "ST-8: single-source standards (snippet removed, headers intact)"
if [[ -e "CLAUDE.md.snippet" ]]; then
  fail "CLAUDE.md.snippet still exists — standards must have a single source"
else
  pass "CLAUDE.md.snippet absent"
fi
if [[ -s "$STANDARDS" ]]; then
  missing_headers=""
  for header in "Coding standards" "Testing standards" "Working style"; do
    if ! grep -qi "$header" "$STANDARDS"; then
      missing_headers+=" \"$header\""
    fi
  done
  if [[ -z "$missing_headers" ]]; then
    pass "standards file retains all key section headers"
  else
    fail "standards file is missing section headers:$missing_headers"
  fi
else
  fail "cannot check headers — $STANDARDS missing or empty"
fi

# -----------------------------------------------------------------------------
# ST-9 — every skill description <= DESC_LIMIT chars
# -----------------------------------------------------------------------------
section "ST-9: every skill description <= $DESC_LIMIT chars"
if [[ "$HAVE_PY3" -eq 1 ]]; then
  while IFS=$'\t' read -r length skillfile; do
    [[ -z "$length" ]] && continue
    if [[ "$length" -le "$DESC_LIMIT" ]]; then
      pass "$skillfile description = $length chars"
    else
      fail "$skillfile description = $length chars (> $DESC_LIMIT)"
    fi
  done < <(
    python3 - "$DESC_LIMIT" <<'PY'
import glob, sys

def frontmatter(text):
    """Return the YAML frontmatter block (between the first two '---' lines)."""
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return []
    out = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        out.append(line)
    return out

def scalar(fm, key):
    """Extract a frontmatter scalar, supporting folded/literal block scalars (>- , | )."""
    for i, line in enumerate(fm):
        stripped = line.strip()
        if stripped.startswith(key + ":"):
            rest = stripped[len(key) + 1:].strip()
            if rest and rest[0] in "|>":
                # block scalar: gather subsequent more-indented lines
                base_indent = len(line) - len(line.lstrip())
                parts = []
                for cont in fm[i + 1:]:
                    if not cont.strip():
                        parts.append("")
                        continue
                    indent = len(cont) - len(cont.lstrip())
                    if indent <= base_indent:
                        break
                    parts.append(cont.strip())
                return " ".join(p for p in parts if p)
            # inline scalar; strip surrounding quotes
            return rest.strip().strip('"').strip("'")
    return ""

for path in sorted(glob.glob("skills/*/SKILL.md")):
    with open(path) as fh:
        fm = frontmatter(fh.read())
    desc = scalar(fm, "description")
    print(f"{len(desc)}\t{path}")
PY
  )
else
  fail "python3 unavailable — cannot measure description lengths reliably"
fi

# -----------------------------------------------------------------------------
# ST-10 — hooks.json valid and registers a SessionStart hook referencing the standards
# -----------------------------------------------------------------------------
section "ST-10: hooks.json registers a SessionStart standards hook"
if is_valid_json "$HOOKS"; then
  has_sessionstart="$(json_get "$HOOKS" '"yes" if "SessionStart" in data.get("hooks", {}) else None')"
  if [[ -n "$has_sessionstart" ]]; then
    pass "SessionStart hook registered"
  else
    fail "no SessionStart hook in $HOOKS"
  fi
  if grep -q "coding-standards.md" "$HOOKS"; then
    pass "hook references coding-standards.md"
  else
    fail "hook does not reference coding-standards.md"
  fi
else
  fail "$HOOKS is missing or not valid JSON"
fi

# -----------------------------------------------------------------------------
# ST-11 — frontmatter present: skills need name+description, commands need description
# -----------------------------------------------------------------------------
section "ST-11: skill/command frontmatter is well-formed"
if [[ "$HAVE_PY3" -eq 1 ]]; then
  while IFS=$'\t' read -r status item; do
    [[ -z "$status" ]] && continue
    if [[ "$status" == "OK" ]]; then
      pass "$item"
    else
      fail "$item"
    fi
  done < <(
    python3 - <<'PY'
import glob

def frontmatter(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    out = []
    for line in lines[1:]:
        if line.strip() == "---":
            return out
        out.append(line)
    return None  # unterminated frontmatter

def has_nonempty(fm, key):
    for i, line in enumerate(fm):
        stripped = line.strip()
        if stripped.startswith(key + ":"):
            rest = stripped[len(key) + 1:].strip()
            if rest and rest[0] in "|>":
                # block scalar has content if any following indented line is non-empty
                base = len(line) - len(line.lstrip())
                for cont in fm[i + 1:]:
                    if not cont.strip():
                        continue
                    if (len(cont) - len(cont.lstrip())) <= base:
                        break
                    return True
                return False
            return bool(rest.strip().strip('"').strip("'"))
    return False

for path in sorted(glob.glob("skills/*/SKILL.md")):
    with open(path) as fh:
        fm = frontmatter(fh.read())
    if fm is None:
        print(f"BAD\t{path}: missing or unterminated frontmatter")
        continue
    missing = [k for k in ("name", "description") if not has_nonempty(fm, k)]
    if missing:
        print(f"BAD\t{path}: missing/empty {', '.join(missing)}")
    else:
        print(f"OK\t{path}: name + description present")

for path in sorted(glob.glob("commands/*.md")):
    with open(path) as fh:
        fm = frontmatter(fh.read())
    if fm is None:
        print(f"BAD\t{path}: missing or unterminated frontmatter")
        continue
    if has_nonempty(fm, "description"):
        print(f"OK\t{path}: description present")
    else:
        print(f"BAD\t{path}: missing/empty description")
PY
  )
else
  fail "python3 unavailable — cannot parse frontmatter"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
section "Summary"
if [[ "$FAILURES" -eq 0 ]]; then
  printf '  \033[32mAll checks passed.\033[0m\n'
  exit 0
else
  printf '  \033[31m%d check(s) failed.\033[0m\n' "$FAILURES"
  exit 1
fi
