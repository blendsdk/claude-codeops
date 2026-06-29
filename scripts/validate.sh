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
# ST-12 — Grounded Options & Recommendations directive present + reconciled
# -----------------------------------------------------------------------------
section "ST-12: Grounded Options directive present and enforced"

# 12a — sentinel present in the standards, every scoped skill, and analyze_project
GROUNDED_SENTINEL="grounded options"
grounded_targets=(
  "$STANDARDS"
  "skills/preflight/SKILL.md"
  "skills/make_plan/SKILL.md"
  "skills/make_requirements/SKILL.md"
  "skills/exec_plan/SKILL.md"
  "skills/grill_me/SKILL.md"
  "skills/upgrade_plan/SKILL.md"
  "skills/retro_requirements/SKILL.md"
  "commands/analyze_project.md"
)
for f in "${grounded_targets[@]}"; do
  if [[ -f "$f" ]] && grep -qi "$GROUNDED_SENTINEL" "$f"; then
    pass "$f references the Grounded Options directive"
  else
    fail "$f is missing the Grounded Options directive reference"
  fi
done

# 12b — viable-only reconciliation replaced the old "always >=2 options" rule
for f in "skills/preflight/report-format.md" "skills/grill_me/SKILL.md"; do
  if [[ -f "$f" ]] && grep -qi "genuinely viable" "$f"; then
    pass "$f carries the viable-only reconciliation"
  else
    fail "$f is missing the viable-only reconciliation (\"genuinely viable\")"
  fi
done

# =============================================================================
# CodeOps v2 nested-layout checks (ST-13…ST-17)
#
# These continue validate.sh's real ST sequence (ST-12 = Grounded Options is the
# last pre-v2 check). They are SPECIFICATION tests for the v2 layout work — written
# from the spec (plans/codeops-v2-layout/03-01, 03-06, 07-testing-strategy.md), BEFORE
# the implementation, so they fail (red) on the unmodified repo and pass (green) once
# each phase lands. Mapping to SPEC cases: ST-13→SPEC-4, ST-14→SPEC-25, ST-15→SPEC-26,
# ST-16→SPEC-1 (schema parse), ST-17→SPEC-32.
# =============================================================================

# Shared layout-convention doc and the skills that must link it (03-01, 03-05 / AR #7, #22).
# Lives at the PLUGIN ROOT (not under skills/) so the plugin loader never sees a SKILL.md-less
# dir under skills/ — the documented-safe location (supersedes AR #7's skills/_shared/, see AR #30).
SHARED_DOC="_shared/layout-convention.md"
AFFECTED_SKILLS=(roadmap make_requirements make_plan exec_plan preflight upgrade_plan retro_requirements)
# A sample marker exercises the schema/detection rule without a full nested fixture (03-01).
SAMPLE_MARKER="scripts/fixtures/sample.codeops.yml"

# -----------------------------------------------------------------------------
# ST-13 — shared convention doc present; _shared/ holds no SKILL.md (SPEC-4)
# -----------------------------------------------------------------------------
section "ST-13: shared layout-convention doc present; skills/ holds only real skills"
if [[ -s "$SHARED_DOC" ]]; then
  pass "$SHARED_DOC exists and is non-empty (at the plugin root, not under skills/)"
else
  fail "$SHARED_DOC is missing or empty"
fi
# The plugin loader treats each skills/<dir> as a skill (must have a SKILL.md). The shared docs
# deliberately live OUTSIDE skills/ (AR #30) so the loader never meets a SKILL.md-less subdir.
# Assert that invariant directly: every subdirectory of skills/ contains a SKILL.md.
non_skill_dirs=""
for d in skills/*/; do
  [[ -d "$d" ]] || continue
  [[ -f "${d}SKILL.md" ]] || non_skill_dirs+=" $d"
done
if [[ -z "$non_skill_dirs" ]]; then
  pass "every skills/<dir> contains a SKILL.md (no non-skill dirs under skills/)"
else
  fail "skills/ contains subdir(s) without a SKILL.md:$non_skill_dirs"
fi

# -----------------------------------------------------------------------------
# ST-14 — every affected skill links the convention doc (SPEC-25)
# -----------------------------------------------------------------------------
section "ST-14: affected skills reference the layout-convention doc"
for s in "${AFFECTED_SKILLS[@]}"; do
  skillfile="skills/$s/SKILL.md"
  if [[ -f "$skillfile" ]] && grep -qF "layout-convention.md" "$skillfile"; then
    pass "$skillfile links the convention doc"
  else
    fail "$skillfile does not link _shared/layout-convention.md"
  fi
done

# -----------------------------------------------------------------------------
# ST-15 — no stale 2.0.0 left in the shipped surface; current stamp present (SPEC-26)
# -----------------------------------------------------------------------------
# NOTE: ST-24 is the authoritative version check (all CodeOps Skills Version stamps == the
# current version and agree). ST-15 only guards against (a) stale 2.0.0 and (b) accidental stamp
# deletion. `3.0.0` may legitimately remain in skills/ as the compatibility floor (upgrade/exec
# thresholds) and as `layoutVersion` (the nested-layout schema version), so ST-15 does NOT ban it.
section "ST-15: no stale 2.0.0 version stamps; current stamp present"
# 15a — no 2.0.0 anywhere in the distributed skills/ + commands/ surface (fixtures under
# scripts/ are test data and intentionally excluded).
stale_stamps="$(grep -rln '2\.0\.0' skills/ commands/ 2>/dev/null || true)"
if [[ -z "$stale_stamps" ]]; then
  pass "no 2.0.0 stamps in skills/ or commands/"
else
  fail "stale 2.0.0 stamp(s) found in:"$'\n'"$stale_stamps"
fi
# 15b — guard against deleting (rather than bumping) the stamps: the current 3.1.0 must be present.
if grep -rqF '3.1.0' skills/; then
  pass "current 3.1.0 stamp present in skills/"
else
  fail "no 3.1.0 stamp found in skills/ (stamps must be bumped, not removed)"
fi

# -----------------------------------------------------------------------------
# ST-16 — sample marker parses and carries codeopsLayout: nested (SPEC-1 schema)
# -----------------------------------------------------------------------------
section "ST-16: sample .codeops.yml marker is well-formed"
# The flat schema (03-01) is detected by a simple key match; this mirrors the grep fallback
# the skills use, so the test asserts the real detection mechanism, not a heavier YAML parse.
if [[ -f "$SAMPLE_MARKER" ]]; then
  if grep -Eq '^codeopsLayout:[[:space:]]*nested[[:space:]]*$' "$SAMPLE_MARKER"; then
    pass "$SAMPLE_MARKER declares codeopsLayout: nested"
  else
    fail "$SAMPLE_MARKER does not declare 'codeopsLayout: nested'"
  fi
else
  fail "$SAMPLE_MARKER is missing"
fi

# -----------------------------------------------------------------------------
# ST-17 — setup_codeops skill + command present (SPEC-32)
# -----------------------------------------------------------------------------
# Existing ST-9 (description length) and ST-11 (frontmatter) cover these files automatically
# once they exist, since both glob skills/*/SKILL.md and commands/*.md.
section "ST-17: setup_codeops skill + command present"
for f in "skills/setup_codeops/SKILL.md" "commands/setup_codeops.md"; do
  if [[ -s "$f" ]]; then
    pass "$f exists and is non-empty"
  else
    fail "$f is missing or empty"
  fi
done

# =============================================================================
# Recommendation-hardening checks (ST-18…ST-24)
#
# SPECIFICATION tests for the recommendation-hardening work, written from the spec
# (plans/recommendation-hardening/07-testing-strategy.md), BEFORE the implementation, so
# they fail (red) on the unmodified repo and pass (green) once each phase lands. Mapping:
# ST-18→FR-6, ST-19→FR-1..4, ST-20→FR-6/AR-15, ST-21→FR-5, ST-22→FR-7, ST-23→FR-6, ST-24→FR-9.
# =============================================================================

HARDENING_DOC="_shared/recommendation-hardening.md"
# Tier-A skills get explicit challenger-escalation machinery (AR-6).
HARDENING_TIER_A=(preflight make_plan make_requirements)
# Tier-B files reference the protocol only (no bespoke escalation).
HARDENING_TIER_B=(
  "skills/exec_plan/SKILL.md"
  "skills/grill_me/SKILL.md"
  "skills/upgrade_plan/SKILL.md"
  "skills/retro_requirements/SKILL.md"
  "skills/setup_routing/SKILL.md"
  "skills/setup_codeops/SKILL.md"
  "commands/analyze_project.md"
)
EXPECTED_VERSION="3.1.0"

# -----------------------------------------------------------------------------
# ST-18 — shared hardening protocol doc present and non-empty (FR-6 / AR-2)
# -----------------------------------------------------------------------------
section "ST-18: recommendation-hardening protocol doc present"
if [[ -s "$HARDENING_DOC" ]]; then
  pass "$HARDENING_DOC exists and is non-empty (plugin root, not under skills/)"
else
  fail "$HARDENING_DOC is missing or empty"
fi

# -----------------------------------------------------------------------------
# ST-19 — shared doc defines all four layers (FR-1..FR-4 / AR-9,10,11,5)
# -----------------------------------------------------------------------------
section "ST-19: shared doc carries a sentinel for each of the four layers"
hardening_layer_sentinels=("forced reframing" "definition-of-done" "independent challenger" "Hardening:")
if [[ -s "$HARDENING_DOC" ]]; then
  for sentinel in "${hardening_layer_sentinels[@]}"; do
    if grep -qiF "$sentinel" "$HARDENING_DOC"; then
      pass "layer sentinel present: \"$sentinel\""
    else
      fail "layer sentinel missing from $HARDENING_DOC: \"$sentinel\""
    fi
  done
else
  fail "cannot check layer sentinels — $HARDENING_DOC missing"
fi

# -----------------------------------------------------------------------------
# ST-20 — directive references the protocol AND keeps the ST-12 grounded sentinel (FR-6 / AR-15)
# -----------------------------------------------------------------------------
section "ST-20: standards directive points at the protocol and retains the grounded sentinel"
if grep -qF "recommendation-hardening.md" "$STANDARDS"; then
  pass "$STANDARDS references recommendation-hardening.md"
else
  fail "$STANDARDS does not reference recommendation-hardening.md"
fi
if grep -qi "$GROUNDED_SENTINEL" "$STANDARDS"; then
  pass "$STANDARDS still carries the \"$GROUNDED_SENTINEL\" sentinel (ST-12a preserved)"
else
  fail "$STANDARDS lost the \"$GROUNDED_SENTINEL\" sentinel"
fi

# -----------------------------------------------------------------------------
# ST-21 — shared doc states the high-stakes trigger (FR-5 / AR-8)
# -----------------------------------------------------------------------------
section "ST-21: shared doc defines the high-stakes escalation trigger"
if [[ -s "$HARDENING_DOC" ]]; then
  if grep -qiF "CRITICAL/MAJOR" "$HARDENING_DOC" && grep -qiF "complex/sensitive" "$HARDENING_DOC"; then
    pass "high-stakes trigger names CRITICAL/MAJOR and complex/sensitive"
  else
    fail "high-stakes trigger must name both CRITICAL/MAJOR and complex/sensitive"
  fi
else
  fail "cannot check high-stakes trigger — $HARDENING_DOC missing"
fi

# -----------------------------------------------------------------------------
# ST-22 — Tier-A skills link the protocol and reference the high-stakes hook (FR-7 / AR-6)
# -----------------------------------------------------------------------------
section "ST-22: Tier-A skills carry the escalation hook"
for s in "${HARDENING_TIER_A[@]}"; do
  skillfile="skills/$s/SKILL.md"
  if [[ -f "$skillfile" ]] && grep -qF "recommendation-hardening.md" "$skillfile" && grep -qiF "high-stakes" "$skillfile"; then
    pass "$skillfile links the protocol and references the high-stakes hook"
  else
    fail "$skillfile must link recommendation-hardening.md and reference \"high-stakes\""
  fi
done

# -----------------------------------------------------------------------------
# ST-23 — Tier-B files reference the protocol (FR-6 / AR-6)
# -----------------------------------------------------------------------------
section "ST-23: Tier-B files reference the protocol"
for f in "${HARDENING_TIER_B[@]}"; do
  if [[ -f "$f" ]] && grep -qF "recommendation-hardening.md" "$f"; then
    pass "$f references recommendation-hardening.md"
  else
    fail "$f does not reference recommendation-hardening.md"
  fi
done

# -----------------------------------------------------------------------------
# ST-24 — all CodeOps Skills Version stamps are 3.1.0 and agree (FR-9 / AR-14)
# -----------------------------------------------------------------------------
section "ST-24: version stamps are $EXPECTED_VERSION and consistent"
stamp_lines="$(grep -rhoE 'CodeOps (Skills )?Version[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' skills/ commands/ standards/ _shared/ 2>/dev/null || true)"
uniq_versions="$(printf '%s\n' "$stamp_lines" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
if [[ -z "$uniq_versions" ]]; then
  fail "no CodeOps Skills Version stamps found in the shipped surface"
elif [[ "$uniq_versions" == "$EXPECTED_VERSION" ]]; then
  pass "all version stamps == $EXPECTED_VERSION"
else
  fail "version stamps disagree or are not $EXPECTED_VERSION (found: $uniq_versions)"
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
