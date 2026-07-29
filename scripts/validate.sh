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
# Combined description + when_to_use listing budget (ST-34 / v3-hardening AR #22).
DESC_COMBINED_LIMIT=1536
# The single expected release version. Every "CodeOps Skills Version" stamp AND plugin.json's
# "version" must equal this (ST-4, ST-24). Bump it here — and only here — per release.
CODEOPS_VERSION="3.20.0"

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
# ST-4 — plugin.json carries the release version (v3-hardening AR #5; supersedes the
# pre-3.2.0 "no version key" rule; kept in sync by ST-24's stamp-equality check).
# -----------------------------------------------------------------------------
section "ST-4: plugin.json version == $CODEOPS_VERSION"
if is_valid_json "$PLUGIN"; then
  plugin_version="$(json_get "$PLUGIN" 'data.get("version")')"
  if [[ "$plugin_version" == "$CODEOPS_VERSION" ]]; then
    pass "plugin.json version == $CODEOPS_VERSION"
  else
    fail "plugin.json version is \"${plugin_version:-<missing>}\", expected \"$CODEOPS_VERSION\" (AR #5)"
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
# ST-34 — combined description + when_to_use <= DESC_COMBINED_LIMIT per skill
# (v3-hardening AR #22 — Claude Code truncates the combined skill listing).
# -----------------------------------------------------------------------------
section "ST-34: description + when_to_use <= $DESC_COMBINED_LIMIT chars per skill"
if [[ "$HAVE_PY3" -eq 1 ]]; then
  while IFS=$'\t' read -r combined skillfile; do
    [[ -z "$combined" ]] && continue
    if [[ "$combined" -le "$DESC_COMBINED_LIMIT" ]]; then
      pass "$skillfile description+when_to_use = $combined chars"
    else
      fail "$skillfile description+when_to_use = $combined chars (> $DESC_COMBINED_LIMIT)"
    fi
  done < <(
    python3 - <<'PY'
import glob

def frontmatter(text):
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
    for i, line in enumerate(fm):
        stripped = line.strip()
        if stripped.startswith(key + ":"):
            rest = stripped[len(key) + 1:].strip()
            if rest and rest[0] in "|>":
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
            return rest.strip().strip('"').strip("'")
    return ""

for path in sorted(glob.glob("skills/*/SKILL.md")):
    with open(path) as fh:
        fm = frontmatter(fh.read())
    combined = len(scalar(fm, "description")) + len(scalar(fm, "when_to_use"))
    print(f"{combined}\t{path}")
PY
  )
else
  fail "python3 unavailable — cannot measure combined listing lengths"
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
# techdocs added per v3-hardening AR #41 — it is layout-aware and must link the convention doc.
AFFECTED_SKILLS=(roadmap make_requirements make_plan exec_plan preflight upgrade_plan retro_requirements techdocs)
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
# 15b — guard against deleting (rather than bumping) the stamps: some X.Y.Z stamp must remain.
# Version-agnostic on purpose — ST-24 owns the VALUE; this only guards against removal.
if grep -rqE 'CodeOps (Skills )?Version[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' skills/; then
  pass "version stamps present in skills/ (value checked by ST-24)"
else
  fail "no version stamps found in skills/ (stamps must be bumped, not removed)"
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
# (Release version is the top-level CODEOPS_VERSION constant — single edit point per release.)
EXPECTED_VERSION="$CODEOPS_VERSION"

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
# ST-24 — every CodeOps Skills Version stamp equals $CODEOPS_VERSION and they all agree.
# Scope extended per v3-hardening AR #20: scripts/ and agents/ are part of the shipped
# surface (the 3.0.0 stamp drift shipped inside scripts/codeops-migrate.sh because the old
# scope could not see it), and plugin.json's "version" must match too (AR #5).
# Fixtures under scripts/fixtures/ are test data and stay excluded.
# -----------------------------------------------------------------------------
section "ST-24: version stamps are $EXPECTED_VERSION and consistent (incl. scripts/, bin/, agents/, plugin.json)"
stamp_lines="$(grep -rhoE 'CodeOps (Skills )?Version[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' \
  skills/ commands/ standards/ _shared/ agents/ 2>/dev/null || true)"
script_stamps="$(grep -rhoE 'CodeOps (Skills )?Version[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' scripts/ bin/ \
  --exclude-dir=fixtures 2>/dev/null || true)"
uniq_versions="$(printf '%s\n%s\n' "$stamp_lines" "$script_stamps" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
if [[ -z "$uniq_versions" ]]; then
  fail "no CodeOps Skills Version stamps found in the shipped surface"
elif [[ "$uniq_versions" == "$EXPECTED_VERSION" ]]; then
  pass "all version stamps == $EXPECTED_VERSION"
else
  fail "version stamps disagree or are not $EXPECTED_VERSION (found: $uniq_versions)"
fi
if is_valid_json "$PLUGIN"; then
  pv="$(json_get "$PLUGIN" 'data.get("version")')"
  if [[ "$pv" == "$EXPECTED_VERSION" ]]; then
    pass "plugin.json version agrees with the stamps ($EXPECTED_VERSION)"
  else
    fail "plugin.json version (\"${pv:-<missing>}\") does not match the stamps ($EXPECTED_VERSION)"
  fi
fi

# =============================================================================
# CodeOps v3-hardening checks (ST-25…ST-33, ST-35…ST-40; ST-34 lives beside ST-9)
#
# SPECIFICATION tests for the v3-hardening work, written from the spec
# (plans/codeops-v3-hardening/07-testing-strategy.md ST-H3…H18), BEFORE the
# implementation — red on the unmodified repo, green as Phases 2–8 land.
# Sentinel strings are quoted in comments so prose rewording can't silently
# break a check without the author seeing which contract it guards.
# =============================================================================

ZAG_SHARED="_shared/zero-ambiguity-gate.md"
SPEC_FIRST_SHARED="_shared/spec-first-ordering.md"
STANDARDS_FULL="standards/coding-standards-full.md"
ROADMAP_SYNC="scripts/codeops-roadmap-sync.sh"

# -----------------------------------------------------------------------------
# ST-25 — exec_plan uses two-stage completion marks (ST-H3 / AR #2).
# Sentinels: positive "[~]" + "two-stage"; negative: the old mark-before-verify claim.
# -----------------------------------------------------------------------------
section "ST-25: exec_plan two-stage completion marks"
EXEC_PROTO="skills/exec_plan/execution-protocol.md"
if [[ -f "$EXEC_PROTO" ]] && grep -qF '[~]' "$EXEC_PROTO" && grep -qiF 'two-stage' "$EXEC_PROTO"; then
  pass "$EXEC_PROTO carries the two-stage [~] semantics"
else
  fail "$EXEC_PROTO missing two-stage [~] completion semantics"
fi
for f in "$EXEC_PROTO" "skills/exec_plan/SKILL.md"; do
  # Old contradictory instruction — the emphasized "**BEFORE** verification" / "happens BEFORE
  # verification" claim about the [x] mark. Under two-stage marks only [~] may precede verify,
  # and the rewritten prose must not use this exact emphasized phrase.
  if [[ -f "$f" ]] && grep -qiE '\*\*BEFORE\*\* verification|happens BEFORE verification' "$f"; then
    fail "$f still says the [x] update happens BEFORE verification (contradiction, AR #2)"
  else
    pass "$f no longer marks [x] before verification"
  fi
done

# -----------------------------------------------------------------------------
# ST-26 — executor agents ship in the plugin with the immutable-oracle rule (ST-H4 / AR #4, #14).
# Sentinel: "*.spec.test." + "blocker" in each agent prompt.
# -----------------------------------------------------------------------------
section "ST-26: plugin agents/ executors with spec-test blocker rule"
for f in "agents/plan-task-executor.md" "agents/plan-task-executor-opus.md"; do
  if [[ -s "$f" ]] && grep -qF '.spec.test.' "$f" && grep -qiF 'blocker' "$f"; then
    pass "$f present with the spec-test blocker rule"
  else
    fail "$f missing, empty, or lacks the spec-test blocker rule"
  fi
done

# -----------------------------------------------------------------------------
# ST-27 — shared Zero-Ambiguity Gate doc (ST-H5 / AR #9, #11, #12).
# Sentinels: category-table row, deferred status, bulk-acceptance ruling.
# -----------------------------------------------------------------------------
section "ST-27: shared zero-ambiguity-gate doc present with merged content"
if [[ -s "$ZAG_SHARED" ]]; then
  pass "$ZAG_SHARED exists and is non-empty"
  for sentinel in '| **Feature gaps** |' '⏸ Deferred' 'accepted recommendation'; do
    if grep -qiF "$sentinel" "$ZAG_SHARED"; then
      pass "gate doc carries sentinel: \"$sentinel\""
    else
      fail "gate doc missing sentinel: \"$sentinel\""
    fi
  done
else
  fail "$ZAG_SHARED is missing or empty"
fi
if [[ -s "$SPEC_FIRST_SHARED" ]] && grep -qF 'Specification Tests' "$SPEC_FIRST_SHARED"; then
  pass "$SPEC_FIRST_SHARED exists with the ordering content"
else
  fail "$SPEC_FIRST_SHARED is missing or lacks the ordering content"
fi

# -----------------------------------------------------------------------------
# ST-28 — callers are slim preambles; canonical content appears ONLY in _shared/ (ST-H6 / AR #9, #10).
# The category-table row sentinel and the full-ordering session header must not exist under skills/.
# -----------------------------------------------------------------------------
section "ST-28: gate + spec-first single-sourced (no duplicated canon under skills/)"
ZAG_CALLERS=(
  "skills/make_plan/zero-ambiguity-gate.md"
  "skills/make_requirements/zero-ambiguity-gate.md"
  "skills/upgrade_plan/content-quality-gate.md"
)
for f in "${ZAG_CALLERS[@]}"; do
  if [[ -f "$f" ]] && grep -qF '_shared/zero-ambiguity-gate.md' "$f"; then
    pass "$f links the shared gate doc"
  else
    fail "$f does not link _shared/zero-ambiguity-gate.md"
  fi
done
# Category table may exist ONLY in the shared doc.
dup_tables="$(grep -rlF '| **Feature gaps** |' skills/ 2>/dev/null || true)"
if [[ -z "$dup_tables" ]]; then
  pass "12-category table appears only under _shared/"
else
  fail "duplicated 12-category table found in:"$'\n'"$dup_tables"
fi
# Full spec-first ordering (the "Session N.1: Specification Tests" block) only in _shared/.
dup_orderings="$(grep -rlF 'Session N.1: Specification Tests' skills/ 2>/dev/null || true)"
if [[ -z "$dup_orderings" ]]; then
  pass "full spec-first ordering block appears only under _shared/"
else
  fail "duplicated spec-first ordering block found in:"$'\n'"$dup_orderings"
fi
for f in "skills/make_plan/templates.md" "$EXEC_PROTO"; do
  if [[ -f "$f" ]] && grep -qF "spec-first-ordering.md" "$f"; then
    pass "$f links the shared spec-first doc"
  else
    fail "$f does not link _shared/spec-first-ordering.md"
  fi
done

# -----------------------------------------------------------------------------
# ST-29 — hardening ceremony bounded (ST-H7 / AR #3, #40).
# Sentinels: "per preflight scan", "at most 2 challenger", conditional disclosure;
# grill_me must no longer carry its own undefined "genuinely high-stakes" trigger.
# -----------------------------------------------------------------------------
section "ST-29: recommendation-hardening bounds"
HARDENING_DOC="_shared/recommendation-hardening.md"
for sentinel in 'per preflight scan' 'at most 2 challenger'; do
  if [[ -f "$HARDENING_DOC" ]] && grep -qiF "$sentinel" "$HARDENING_DOC"; then
    pass "hardening doc carries: \"$sentinel\""
  else
    fail "hardening doc missing bound sentinel: \"$sentinel\""
  fi
done
if grep -qiE 'omit.*(Hardening|disclosure)|disclosure.*only when' "$HARDENING_DOC" 2>/dev/null; then
  pass "hardening doc makes the disclosure conditional"
else
  fail "hardening doc does not make the Confidence/Hardening disclosure conditional"
fi
if grep -qiF 'genuinely high-stakes' "skills/grill_me/SKILL.md" 2>/dev/null; then
  fail "grill_me still carries its own undefined high-stakes trigger (AR #40)"
else
  pass "grill_me's standalone high-stakes trigger removed"
fi
if grep -qiF 'per preflight scan' "skills/preflight/report-format.md" 2>/dev/null || \
   grep -qiF 'per scan' "skills/preflight/report-format.md" 2>/dev/null; then
  pass "preflight report-format uses the per-scan batch challenger"
else
  fail "preflight report-format still mandates per-finding challengers (AR #3)"
fi

# -----------------------------------------------------------------------------
# ST-30 — roadmap sync script (ST-H8 / AR #7): exists, --check clean on the fixture,
# and detects seeded Progress drift in a temp copy.
# -----------------------------------------------------------------------------
section "ST-30: codeops-roadmap-sync.sh --check (clean + seeded drift)"
if [[ -x "$ROADMAP_SYNC" ]]; then
  pass "$ROADMAP_SYNC present and executable"
  sync_tmp="$(mktemp -d)"
  cp -R "scripts/fixtures/flat-repo/." "$sync_tmp/"
  if (cd "$sync_tmp" && "$REPO_ROOT/$ROADMAP_SYNC" --check >/dev/null 2>&1); then
    pass "--check exits 0 on the clean fixture"
  else
    fail "--check reports drift on the clean fixture (fixture and script must agree)"
  fi
  # Seed drift: corrupt a Progress cell in the fixture roadmap copy.
  if sed -i -E 's/[0-9]+ ?\/ ?[0-9]+ \([0-9]+%\)/999 \/ 999 (0%)/' "$sync_tmp/plans/00-roadmap.md" 2>/dev/null; then
    if (cd "$sync_tmp" && "$REPO_ROOT/$ROADMAP_SYNC" --check >/dev/null 2>&1); then
      fail "--check did not detect seeded Progress drift"
    else
      pass "--check detects seeded Progress drift (non-zero exit)"
    fi
  else
    fail "could not seed drift into the temp fixture copy"
  fi
  rm -rf "$sync_tmp"
else
  fail "$ROADMAP_SYNC missing or not executable"
  fail "--check clean/seeded assertions skipped (script missing)"
fi

# -----------------------------------------------------------------------------
# ST-31 — layout retrofit complete (ST-H9 / AR #6, #44): retro sub-docs carry no
# unqualified flat _retro literal; convention doc has the flat mini-plan lane.
# -----------------------------------------------------------------------------
section "ST-31: retro nested paths + flat mini-plan lane"
for f in "skills/retro_requirements/phases.md" "skills/retro_requirements/triage-gate.md"; do
  if [[ -f "$f" ]] && grep -qF 'requirements/_retro/' "$f"; then
    fail "$f still hardcodes the flat requirements/_retro/ path (AR #44)"
  else
    pass "$f no longer hardcodes the flat _retro path"
  fi
done
if grep -qF 'plans/<task-slug>/' "_shared/layout-convention.md" 2>/dev/null && \
   ! grep -qiF 'flat-layout repo has no task lane' "_shared/layout-convention.md" 2>/dev/null; then
  pass "layout convention extends the mini-plan task lane to flat layout"
else
  fail "layout convention still excludes flat layout from the task lane (AR #6)"
fi
# AR #41 — the convention doc's layout-aware skill list must include techdocs.
if grep -qF 'techdocs' "_shared/layout-convention.md" 2>/dev/null; then
  pass "layout convention lists techdocs among the layout-aware skills"
else
  fail "layout convention omits techdocs from the layout-aware skill list (AR #41)"
fi

# -----------------------------------------------------------------------------
# ST-32 — count-drift guard (ST-H10 / AR #22): filesystem-derived skill/command counts
# must match every "N skills" / "N (slash )commands" claim in the prose surface.
# Includes a self-test on a seeded temp copy so the guard itself is proven live.
# -----------------------------------------------------------------------------
section "ST-32: prose skill/command counts match the filesystem"
SKILL_COUNT="$(ls -d skills/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
CMD_COUNT="$(ls commands/*.md 2>/dev/null | wc -l | tr -d ' ')"
# check_count_claims <file> — print each mismatched claim; silent when all claims match.
check_count_claims() {
  local f="$1" n
  while read -r n; do
    [[ -z "$n" ]] && continue
    [[ "$n" == "$SKILL_COUNT" ]] || printf '%s: claims %s skills (actual %s)\n' "$f" "$n" "$SKILL_COUNT"
  done < <(grep -ohE '[0-9]+ skills' "$f" 2>/dev/null | grep -oE '^[0-9]+' || true)
  while read -r n; do
    [[ -z "$n" ]] && continue
    [[ "$n" == "$CMD_COUNT" ]] || printf '%s: claims %s commands (actual %s)\n' "$f" "$n" "$CMD_COUNT"
  done < <(grep -ohE '[0-9]+ (slash )?commands' "$f" 2>/dev/null | grep -oE '^[0-9]+' || true)
}
COUNT_PROSE_FILES=(README.md docs/index.md docs/guide/introduction.md docs/reference/repo-map.md CHANGES.md)
for f in "${COUNT_PROSE_FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    fail "$f missing (count guard target)"
    continue
  fi
  mismatches="$(check_count_claims "$f")"
  if [[ -z "$mismatches" ]]; then
    pass "$f count claims match the filesystem ($SKILL_COUNT skills / $CMD_COUNT commands)"
  else
    fail "count drift:"$'\n'"$mismatches"
  fi
done
# Self-test: the guard must actually detect a seeded wrong claim.
selftest_tmp="$(mktemp)"
printf 'This plugin ships 999 skills and 999 slash commands.\n' >"$selftest_tmp"
if [[ -n "$(check_count_claims "$selftest_tmp")" ]]; then
  pass "guard self-test: seeded wrong counts are detected"
else
  fail "guard self-test FAILED: seeded wrong counts were not detected"
fi
rm -f "$selftest_tmp"

# -----------------------------------------------------------------------------
# ST-35 — standards diet + hooks (ST-H13 / AR #26, #27): slim injected core with a
# pointer to the full standards; PreToolUse marker guard registered.
# -----------------------------------------------------------------------------
section "ST-35: standards core + full split; PreToolUse marker guard"
if [[ -s "$STANDARDS_FULL" ]]; then
  pass "$STANDARDS_FULL exists and is non-empty"
else
  fail "$STANDARDS_FULL is missing or empty (AR #27)"
fi
core_lines="$(wc -l <"$STANDARDS" 2>/dev/null | tr -d ' ')"
if [[ -n "$core_lines" && "$core_lines" -le 50 ]]; then
  pass "injected standards core is slim ($core_lines lines <= 50)"
else
  fail "injected standards core is ${core_lines:-?} lines (> 50 — AR #27 diet)"
fi
if grep -qF 'coding-standards-full.md' "$STANDARDS" 2>/dev/null; then
  pass "core standards point at the full reference"
else
  fail "core standards do not reference coding-standards-full.md"
fi
if is_valid_json "$HOOKS" && grep -qF 'PreToolUse' "$HOOKS" && grep -qF '.codeops.yml' "$HOOKS"; then
  pass "hooks.json registers the PreToolUse marker guard"
else
  fail "hooks.json lacks the PreToolUse codeops/.codeops.yml marker guard (AR #26)"
fi

# -----------------------------------------------------------------------------
# ST-36 — plan-template ceremony retired + coverage targets landed (ST-H14 / AR #28, #42).
# -----------------------------------------------------------------------------
section "ST-36: templates without session/hour ceremony; numeric criteria + coverage targets"
TPL="skills/make_plan/templates.md"
if [[ -f "$TPL" ]] && grep -qE '\|\s*Sessions\s*\|' "$TPL"; then
  fail "$TPL still carries the Sessions column (AR #28)"
else
  pass "$TPL phase table no longer has a Sessions column"
fi
if grep -qF '90%' "$TPL" 2>/dev/null; then
  pass "$TPL coverage targets present (90/80/60 table fills the placeholder)"
else
  fail "$TPL coverage-target table missing (AR #42)"
fi
QC="skills/make_plan/quality-checklist.md"
if grep -qE '50.150 lines|1.3 files' "$QC" 2>/dev/null; then
  pass "$QC carries the numeric task-size criteria"
else
  fail "$QC lacks the numeric task-size criteria (AR #28/#42)"
fi

# -----------------------------------------------------------------------------
# ST-37 — roadmap stage machine is re-inferable (ST-H15 / AR #19).
# -----------------------------------------------------------------------------
section "ST-37: roadmap stage rules (artifacts, never-regress, Blocked (was:))"
RMAP="skills/roadmap/SKILL.md"
for sentinel in 'never regress' 'Blocked (was:' '00-preflight-report.md'; do
  if [[ -f "$RMAP" ]] && grep -qiF "$sentinel" "$RMAP"; then
    pass "roadmap skill carries: \"$sentinel\""
  else
    fail "roadmap skill missing stage-rule sentinel: \"$sentinel\""
  fi
done

# -----------------------------------------------------------------------------
# ST-38 — gitcm/gitcmp edge-case guards (ST-H16 / AR #24).
# -----------------------------------------------------------------------------
section "ST-38: gitcm/gitcmp guards"
if grep -qiF 'nothing to commit' "commands/gitcm.md" 2>/dev/null; then
  pass "gitcm has the clean-tree Step-0 guard"
else
  fail "gitcm lacks the clean-tree guard (AR #24)"
fi
if grep -qF 'push -u origin HEAD' "commands/gitcmp.md" 2>/dev/null; then
  pass "gitcmp handles the no-upstream first push"
else
  fail "gitcmp lacks the no-upstream path (AR #24)"
fi
for f in commands/gitcm.md commands/gitcmp.md; do
  if grep -qiE 'pre-commit' "$f" 2>/dev/null; then
    pass "$f addresses pre-commit hooks"
  else
    fail "$f does not address pre-commit hooks (AR #24)"
  fi
done

# -----------------------------------------------------------------------------
# ST-39 — alias wrappers are namespaced pure dispatch (ST-H17 / AR #25).
# The 13 thin aliases must reference the plugin-qualified skill name.
# -----------------------------------------------------------------------------
section "ST-39: alias wrappers reference plugin-qualified skill names"
ALIAS_WRAPPERS=(
  add_requirement review_requirements upgrade_requirements
  make_roadmap update_roadmap review_roadmap archive_roadmap
  make_techdocs review_techdocs setup_codeops setup_routing
)
for w in "${ALIAS_WRAPPERS[@]}"; do
  f="commands/$w.md"
  if [[ -f "$f" ]] && grep -qF 'codeops:' "$f"; then
    pass "$f references the codeops: namespaced skill"
  else
    fail "$f does not reference the plugin-qualified (codeops:) skill name"
  fi
done

# -----------------------------------------------------------------------------
# ST-40 — Mermaid rendering claim fixed (ST-H18 / AR #23).
# -----------------------------------------------------------------------------
section "ST-40: techdocs Mermaid setup"
if grep -qF 'vitepress-plugin-mermaid' "skills/techdocs/vitepress-setup.md" 2>/dev/null; then
  pass "vitepress-setup installs vitepress-plugin-mermaid"
else
  fail "vitepress-setup does not install vitepress-plugin-mermaid (AR #23)"
fi
if grep -qiF 'renders it natively' "skills/techdocs/authoring-and-update.md" 2>/dev/null; then
  fail "authoring-and-update still claims native Mermaid rendering (false)"
else
  pass "native-Mermaid claim removed"
fi

# -----------------------------------------------------------------------------
# Token-efficiency checks (ST-41…ST-46) — plans/plan-token-efficiency/07-testing-strategy.md
# -----------------------------------------------------------------------------

# ST-41 — 99-template deduplicated: tasks live once, as phase checkboxes (AR-2).
section "ST-41: make_plan template has no Master Progress Checklist"
TPL="skills/make_plan/templates.md"
if grep -qF 'Master Progress Checklist' "$TPL" 2>/dev/null; then
  fail "$TPL still contains a Master Progress Checklist (AR-2)"
else
  pass "Master Progress Checklist removed from the 99-template"
fi
if grep -qF 'single source of truth' "$TPL" 2>/dev/null; then
  pass "phase-checkbox single-source rule present"
else
  fail "$TPL lacks the phase-checkbox single-source rule (AR-2)"
fi
if grep -qF '(implemented:' "$TPL" 2>/dev/null && grep -qF '(completed:' "$TPL" 2>/dev/null; then
  pass "two-stage mark formats retained"
else
  fail "$TPL lost the two-stage [~]/[x] mark formats (AR-2)"
fi

# ST-42 — exec_plan verify-output capture rule (AR-3/AR-4).
section "ST-42: exec_plan verify-output capture rule"
PROTO="skills/exec_plan/execution-protocol.md"
if grep -qF 'Verify-output capture' "$PROTO" 2>/dev/null; then
  pass "capture section present"
else
  fail "$PROTO lacks the Verify-output capture section (AR-3)"
fi
if grep -qiF 'last 50 lines' "$PROTO" 2>/dev/null; then
  pass "50-line failure tail rule present"
else
  fail "$PROTO lacks the 50-line failure tail rule (AR-4)"
fi
if grep -qF 'VERIFY PASS' "$PROTO" 2>/dev/null; then
  pass "PASS one-liner format present"
else
  fail "$PROTO lacks the PASS one-liner format (AR-4)"
fi

# ST-43 — quality checklist enforces single-list + reference-don't-restate (AR-2/AR-6).
section "ST-43: quality checklist single-list + restate blocks"
QC="skills/make_plan/quality-checklist.md"
if grep -qF 'Master Progress Checklist' "$QC" 2>/dev/null; then
  fail "$QC still requires the Master Progress Checklist (AR-2)"
else
  pass "Master-Checklist requirement removed"
fi
if grep -qF 'appears exactly once' "$QC" 2>/dev/null; then
  pass "single-list completeness item present"
else
  fail "$QC lacks the appears-exactly-once item (AR-2)"
fi
if grep -qF 'No document restates' "$QC" 2>/dev/null; then
  pass "restate-enforcement block present"
else
  fail "$QC lacks the restate-enforcement block (AR-6)"
fi

# ST-44 — exec_plan dual-format detection + 3.3.0 version table (AR-5).
section "ST-44: exec_plan dual-format detection"
if grep -qiF 'legacy format' "$PROTO" 2>/dev/null && grep -qF '3.3.0 format' "$PROTO" 2>/dev/null; then
  pass "dual-format detection present"
else
  fail "$PROTO lacks dual-format detection (AR-5)"
fi
if grep -qF 'reconstruct' "$PROTO" 2>/dev/null; then
  pass "legacy reconstruct wording retained"
else
  fail "$PROTO lost the legacy reconstruct wording (AR-5)"
fi

# ST-45 — reference-don't-restate rule + thin 01-requirements variant (AR-6/AR-15).
section "ST-45: reference-don't-restate authoring rule"
if grep -qF "Reference, don't restate" "$TPL" 2>/dev/null; then
  pass "authoring rule present in templates"
else
  fail "$TPL lacks the Reference-don't-restate rule (AR-6)"
fi
if grep -qF 'delta view' "$TPL" 2>/dev/null; then
  pass "thin 01-requirements delta variant present"
else
  fail "$TPL lacks the thin 01-requirements variant (AR-15)"
fi

# ST-46 — inline-first execution mode across all consumers (AR-1/AR-7/AR-12/AR-13).
section "ST-46: inline-first execution mode"
if grep -qiF 'inline first' "$PROTO" 2>/dev/null; then
  pass "inline-first section present in the protocol"
else
  fail "$PROTO lacks the inline-first execution mode (AR-1)"
fi
if grep -qF 'Delegated Execution (routing-tagged' "$PROTO" 2>/dev/null; then
  fail "$PROTO still carries the per-task Delegated Execution heading (AR-1)"
else
  pass "per-task delegation heading removed"
fi
for f in agents/plan-task-executor.md agents/plan-task-executor-opus.md; do
  if grep -qiF 'phase packet' "$f" 2>/dev/null; then
    pass "$f uses the phase-packet wording"
  else
    fail "$f lacks the phase-packet wording (AR-12)"
  fi
done
if grep -qiF 'run each phase inline' "skills/setup_routing/SKILL.md" 2>/dev/null; then
  pass "setup_routing block template carries inline-first wording"
else
  fail "setup_routing lacks the inline-first wording (AR-12)"
fi
if grep -qF 'Master Progress Checklist' "docs/skills/exec_plan.md" 2>/dev/null; then
  fail "docs/skills/exec_plan.md still claims the Master Progress Checklist (AR-13)"
else
  pass "docs page no longer claims the Master Progress Checklist"
fi

# -----------------------------------------------------------------------------
# ST-47 — self-contained code documentation: the ephemeral-reference ban is
# present in both standards cores, enforced in the exec_plan per-task loop and in
# both executor agents, and the /clean_jsdoc retrofit command ships (3.3.1).
# Sentinels quoted so a rewording can't silently drop the enforcement.
# -----------------------------------------------------------------------------
section "ST-47: code-comment / JSDoc ephemeral-reference ban is enforced"
for f in "$STANDARDS" "$STANDARDS_FULL"; do
  if grep -qiF 'never reference' "$f" 2>/dev/null; then
    pass "$f carries the ephemeral-reference ban"
  else
    fail "$f lacks the ephemeral-reference ban (3.3.1)"
  fi
done
if grep -qiF 'doc-standard self-check' "$PROTO" 2>/dev/null; then
  pass "exec_plan gates promotion on the doc-standard self-check"
else
  fail "$PROTO lacks the doc-standard self-check before [x] (3.3.1)"
fi
for f in agents/plan-task-executor.md agents/plan-task-executor-opus.md; do
  if grep -qiF 'Documentation ban' "$f" 2>/dev/null; then
    pass "$f carries the Documentation ban"
  else
    fail "$f lacks the Documentation ban (3.3.1)"
  fi
done
if [[ -f commands/clean_jsdoc.md ]]; then
  pass "clean_jsdoc retrofit command present"
else
  fail "commands/clean_jsdoc.md is missing (3.3.1)"
fi

# -----------------------------------------------------------------------------
# ST-48 — analyze_project is branch-aware for parallel worktrees: it stages to a
# feature's CLAUDE.notes.md off the integration branch and folds them on it, instead
# of rewriting the shared CLAUDE.md everywhere. Sentinels: "integration branch" +
# "CLAUDE.notes.md" + "worktree" in the command; the marker key "integrationBranch"
# and the "CLAUDE.notes.md" path documented in the convention; the sample carrying it.
# -----------------------------------------------------------------------------
section "ST-48: analyze_project branch-aware CLAUDE.md routing"
AP_CMD="commands/analyze_project.md"
if [[ -f "$AP_CMD" ]] && grep -qiF 'integration branch' "$AP_CMD" \
   && grep -qF 'CLAUDE.notes.md' "$AP_CMD" && grep -qiF 'worktree' "$AP_CMD"; then
  pass "$AP_CMD routes by branch (feature-branch staging + integration-branch fold)"
else
  fail "$AP_CMD is missing the branch-aware parallel-worktree contract"
fi
if grep -qF 'integrationBranch' "$SHARED_DOC" && grep -qF 'CLAUDE.notes.md' "$SHARED_DOC"; then
  pass "$SHARED_DOC documents integrationBranch + the CLAUDE.notes.md path"
else
  fail "$SHARED_DOC does not document integrationBranch / CLAUDE.notes.md"
fi
if grep -qE '^integrationBranch:' "$SAMPLE_MARKER"; then
  pass "$SAMPLE_MARKER carries integrationBranch"
else
  fail "$SAMPLE_MARKER is missing integrationBranch"
fi

# -----------------------------------------------------------------------------
# ST-49 — roadmap Portfolio cascade mandate is branch-aware for parallel worktrees
# (FR-1 / AR-3): on a non-integration branch, update only the isolated per-feature roadmap and
# DEFER the portfolio write; reconcile on the integration branch. Sentinels: "integration branch"
# in both the mandate (SKILL.md) and the cascade-rule doc (stage-hooks.md), plus a "non-integration"
# + defer/skip cue so a mere mention can't pass.
# -----------------------------------------------------------------------------
section "ST-49: roadmap portfolio cascade is branch-aware (parallel worktrees)"
RM_SKILL="skills/roadmap/SKILL.md"
RM_HOOKS="skills/roadmap/stage-hooks.md"
if grep -qiF 'integration branch' "$RM_SKILL" && grep -qiF 'integration branch' "$RM_HOOKS"; then
  pass "cascade mandate + stage-hooks reference the integration branch"
else
  fail "roadmap cascade mandate is not branch-aware (missing 'integration branch' in SKILL.md/stage-hooks.md)"
fi
if grep -qiF 'non-integration' "$RM_HOOKS" && grep -qiE 'defer|skip' "$RM_HOOKS"; then
  pass "stage-hooks defers the portfolio write off the integration branch"
else
  fail "stage-hooks does not defer the portfolio cascade on a non-integration branch (FR-1)"
fi

# -----------------------------------------------------------------------------
# ST-50 — setup_codeops emits + idempotently backfills the integrationBranch marker key
# (FR-3 / AR-6): scaffold.md writes it on a fresh repo; the marker-present path backfills a
# missing key. Sentinels: "integrationBranch" in scaffold.md; "backfill" + "integrationBranch"
# in SKILL.md.
# -----------------------------------------------------------------------------
section "ST-50: setup_codeops emits + backfills integrationBranch"
SC_SCAFFOLD="skills/setup_codeops/scaffold.md"
SC_SKILL="skills/setup_codeops/SKILL.md"
if grep -qF 'integrationBranch' "$SC_SCAFFOLD"; then
  pass "scaffold.md marker emits integrationBranch"
else
  fail "scaffold.md does not emit integrationBranch (FR-3)"
fi
if grep -qiF 'backfill' "$SC_SKILL" && grep -qF 'integrationBranch' "$SC_SKILL"; then
  pass "setup_codeops backfills integrationBranch on the marker-present path"
else
  fail "setup_codeops does not backfill integrationBranch (FR-3)"
fi

# -----------------------------------------------------------------------------
# ST-51 — codeops-migrate.sh writes integrationBranch into the flat→nested marker (FR-4 / AR-7).
# migration-check.sh additionally asserts the *emitted* marker carries it.
# -----------------------------------------------------------------------------
section "ST-51: codeops-migrate.sh emits integrationBranch"
if grep -qF 'integrationBranch' scripts/codeops-migrate.sh; then
  pass "codeops-migrate.sh marker includes integrationBranch"
else
  fail "codeops-migrate.sh marker omits integrationBranch (FR-4)"
fi

# -----------------------------------------------------------------------------
# ST-52 — setup_routing has an integration-branch guard (FR-5 / AR-8): the routing block is a
# repo-wide CLAUDE.md write, so off the integration branch it warns and skips (light guard, no
# staging). Sentinels: "integration branch" + "non-integration" in the skill.
# -----------------------------------------------------------------------------
section "ST-52: setup_routing integration-branch guard"
SR_SKILL="skills/setup_routing/SKILL.md"
if grep -qiF 'integration branch' "$SR_SKILL" && grep -qiF 'non-integration' "$SR_SKILL"; then
  pass "setup_routing warns/skips the routing-block write off the integration branch"
else
  fail "setup_routing has no integration-branch guard (FR-5)"
fi

# -----------------------------------------------------------------------------
# ST-53 — analyze_project's notes-fold is idempotent (FR-6 / PA-1): before appending a note it
# checks whether the content is already present under the heading, so an interrupted-then-rerun
# fold cannot double-append. Sentinel: "already present" in the command.
# -----------------------------------------------------------------------------
section "ST-53: analyze_project fold idempotency (content-presence check)"
if grep -qiF 'already present' commands/analyze_project.md; then
  pass "fold skips content already present (no double-append)"
else
  fail "analyze_project fold lacks the content-presence idempotency guard (FR-6/PA-1)"
fi

# -----------------------------------------------------------------------------
# ST-54 — the user-facing "Parallel agents" docs guide exists and the README points to it
# (FR-7 / AR-14). Link integrity is covered by the VitePress dead-link build.
# -----------------------------------------------------------------------------
section "ST-54: parallel-agents docs guide + README pointer"
PA_GUIDE="docs/guide/parallel-agents.md"
if [[ -s "$PA_GUIDE" ]]; then
  pass "$PA_GUIDE exists"
else
  fail "parallel-agents docs guide missing (FR-7)"
fi
if grep -qF 'guide/parallel-agents' README.md; then
  pass "README links the parallel-agents guide"
else
  fail "README lacks a link to the parallel-agents guide (FR-7)"
fi

# -----------------------------------------------------------------------------
# ST-55 — codeops-worktree defaults its base branch to the marker's
# integrationBranch (falling back to origin/HEAD -> main/master -> HEAD when the
# key or the marker is absent), so a devel/acceptance-based workflow needs no
# per-command --from flag and the CLI agrees with the branch-aware skills.
# -----------------------------------------------------------------------------
section "ST-55: codeops-worktree honors integrationBranch as the default base"
WT="bin/codeops-worktree"
if grep -qF 'integrationBranch' "$WT" && grep -qF '.codeops.yml' "$WT"; then
  pass "codeops-worktree reads integrationBranch from the .codeops.yml marker"
else
  fail "codeops-worktree does not read integrationBranch from the .codeops.yml marker"
fi
# The marker must be consulted by the base-branch resolver, ahead of the origin/HEAD fallback.
if awk '/^default_base_branch\(\)/{f=1} f&&/integrationBranch|marker_integration_branch/{hit=1; exit} END{exit !hit}' "$WT"; then
  pass "default_base_branch prefers the marker's integrationBranch"
else
  fail "default_base_branch does not consult the marker's integrationBranch"
fi

# -----------------------------------------------------------------------------
# ST-56 — roadmap compact engine present (mirrors ST-30): exists, executable, --help exits 0.
# -----------------------------------------------------------------------------
section "ST-56: codeops-roadmap-compact.sh present + --help"
COMPACT="scripts/codeops-roadmap-compact.sh"
if [[ -x "$COMPACT" ]]; then
  pass "$COMPACT present and executable"
  if "$REPO_ROOT/$COMPACT" --help >/dev/null 2>&1; then
    pass "--help exits 0"
  else
    fail "$COMPACT --help did not exit 0"
  fi
else
  fail "$COMPACT missing or not executable"
fi

# -----------------------------------------------------------------------------
# ST-57 — the roadmap template ships lean: no running-log `## Notes` section (a roadmap is only
# its table; per-item history lives in the plan folder and git).
# -----------------------------------------------------------------------------
section "ST-57: roadmap template has no running-log ## Notes section"
if grep -qE '^## Notes' skills/roadmap/template.md; then
  fail "skills/roadmap/template.md still contains a ## Notes running-log section"
else
  pass "no ## Notes running-log section in the roadmap template"
fi

# -----------------------------------------------------------------------------
# ST-58 — the per-row free-text column is Depends-on / Blocker (renamed from Notes / Blocker).
# -----------------------------------------------------------------------------
section "ST-58: roadmap column reads Depends-on / Blocker"
if grep -qF 'Depends-on / Blocker' skills/roadmap/template.md \
   && ! grep -qF 'Notes / Blocker' skills/roadmap/template.md; then
  pass "column header is Depends-on / Blocker (Notes / Blocker removed)"
else
  fail "template must use 'Depends-on / Blocker' and drop 'Notes / Blocker'"
fi

# -----------------------------------------------------------------------------
# ST-59 — the roadmap skill documents the compact action in its dispatch.
# -----------------------------------------------------------------------------
section "ST-59: roadmap skill documents the compact action"
if grep -qF 'compact_roadmap' skills/roadmap/SKILL.md; then
  pass "compact action present in the roadmap skill dispatch"
else
  fail "skills/roadmap/SKILL.md does not document the compact action (compact_roadmap)"
fi

# =============================================================================
# CLAUDE.md leanness budgets. CLAUDE.md is injected into every session, so its
# size is a permanent per-session token cost. Derived (machine-generated) sections
# carry hard per-section caps; hand-authored sections are exempt. Each check skips
# cleanly when the repo has no root CLAUDE.md (not all repos do).
# =============================================================================
CLAUDEMD="CLAUDE.md"
MAX_TOTAL_LINES=150
MAX_DERIVED_SECTION=20
MAX_ROUTING_SPAN=10
MAX_REFRESH_COMMENTS=1

# -----------------------------------------------------------------------------
# ST-60 — the CLAUDE.md routing block stays lean (sentinel span <=10 lines). A
# lone sentinel is a corrupted block: fail rather than guess the span.
# -----------------------------------------------------------------------------
section "ST-60: CLAUDE.md routing block is lean (<=$MAX_ROUTING_SPAN lines)"
if [[ -f "$CLAUDEMD" ]]; then
  cm_start=$(grep -n 'CODEOPS-ROUTING:START' "$CLAUDEMD" | head -1 | cut -d: -f1)
  cm_end=$(grep -n 'CODEOPS-ROUTING:END' "$CLAUDEMD" | head -1 | cut -d: -f1)
  if [[ -n "$cm_start" && -n "$cm_end" ]]; then
    cm_span=$(( cm_end - cm_start + 1 ))
    if [[ "$cm_span" -le "$MAX_ROUTING_SPAN" ]]; then
      pass "routing block span is $cm_span lines (<=$MAX_ROUTING_SPAN)"
    else
      fail "CLAUDE.md routing block span is $cm_span lines; must be <=$MAX_ROUTING_SPAN (it rides into every session)"
    fi
  elif [[ -n "$cm_start" || -n "$cm_end" ]]; then
    fail "CLAUDE.md has exactly one routing sentinel (corrupted) — expected both markers or neither"
  else
    pass "no routing block present (nothing to bound)"
  fi
else
  pass "no root CLAUDE.md (check skipped)"
fi

# -----------------------------------------------------------------------------
# ST-61 — the derived `## Project structure` section stays terse (<=20 lines).
# Only this machine-generated section is hard-capped; hand-authored sections
# (Conventions, Special rules, …) are intentionally exempt.
# -----------------------------------------------------------------------------
section "ST-61: CLAUDE.md Project-structure section is lean (<=$MAX_DERIVED_SECTION lines)"
if [[ -f "$CLAUDEMD" ]]; then
  ps_start=$(grep -n '^## Project structure' "$CLAUDEMD" | head -1 | cut -d: -f1)
  if [[ -n "$ps_start" ]]; then
    ps_next=$(awk -v s="$ps_start" 'NR>s && /^## / {print NR; exit}' "$CLAUDEMD")
    [[ -z "$ps_next" ]] && ps_next=$(( $(wc -l < "$CLAUDEMD") + 1 ))
    ps_span=$(( ps_next - ps_start ))
    if [[ "$ps_span" -le "$MAX_DERIVED_SECTION" ]]; then
      pass "Project-structure section is $ps_span lines (<=$MAX_DERIVED_SECTION)"
    else
      fail "CLAUDE.md '## Project structure' is $ps_span lines; must be <=$MAX_DERIVED_SECTION (derived section — one line per top-level item)"
    fi
  else
    pass "no '## Project structure' section present"
  fi
else
  pass "no root CLAUDE.md (check skipped)"
fi

# -----------------------------------------------------------------------------
# ST-62 — at most one analyze_project refresh comment (replace-in-place, not a
# growing stack).
# -----------------------------------------------------------------------------
section "ST-62: CLAUDE.md has <=$MAX_REFRESH_COMMENTS analyze_project refresh comment"
if [[ -f "$CLAUDEMD" ]]; then
  rc=$(grep -c '<!-- analyze_project:' "$CLAUDEMD")
  if [[ "$rc" -le "$MAX_REFRESH_COMMENTS" ]]; then
    pass "$rc refresh comment(s) (<=$MAX_REFRESH_COMMENTS)"
  else
    fail "CLAUDE.md has $rc analyze_project refresh comments; keep <=$MAX_REFRESH_COMMENTS (replace in place, do not stack)"
  fi
else
  pass "no root CLAUDE.md (check skipped)"
fi

# -----------------------------------------------------------------------------
# ST-63 — total CLAUDE.md size within budget (<=150 lines). Guards against future
# bloat; the current file passes.
# -----------------------------------------------------------------------------
section "ST-63: CLAUDE.md total size within budget (<=$MAX_TOTAL_LINES lines)"
if [[ -f "$CLAUDEMD" ]]; then
  tl=$(wc -l < "$CLAUDEMD")
  if [[ "$tl" -le "$MAX_TOTAL_LINES" ]]; then
    pass "$tl lines (<=$MAX_TOTAL_LINES)"
  else
    fail "CLAUDE.md is $tl lines; keep it <=$MAX_TOTAL_LINES (it is always-on context)"
  fi
else
  pass "no root CLAUDE.md (check skipped)"
fi

# -----------------------------------------------------------------------------
# ST-64 — CLAUDE.md must not duplicate the injected coding standards. The plugin
# injects those every session; pasting them in doubles the always-on cost. Match
# their distinctive section headings.
# -----------------------------------------------------------------------------
section "ST-64: CLAUDE.md does not duplicate the injected coding standards"
if [[ -f "$CLAUDEMD" ]]; then
  if grep -qE '^## Quality & structure|^## Security .*non-negotiable|^# Testing standards|^# Working style' "$CLAUDEMD"; then
    fail "CLAUDE.md contains an injected-standards heading — the plugin injects those every session; do not paste them in"
  else
    pass "no injected-standards headings duplicated"
  fi
else
  pass "no root CLAUDE.md (check skipped)"
fi

# -----------------------------------------------------------------------------
# ST-65 — analyze_project documents the leaning mode: a --compact action (with a
# composable --dry-run), preview-before-write, scoped to the current project only.
# -----------------------------------------------------------------------------
section "ST-65: analyze_project documents the --compact leaning mode"
AP="commands/analyze_project.md"
if grep -qF -- '--compact' "$AP" \
   && grep -qF -- '--dry-run' "$AP" \
   && grep -qiE 'preview[- ]before[- ]write' "$AP" \
   && grep -qiE 'current[- ]project' "$AP"; then
  pass "documents --compact/--dry-run, preview-before-write, current-project-only"
else
  fail "analyze_project must document --compact, --dry-run, preview-before-write, and current-project-only scope"
fi

# -----------------------------------------------------------------------------
# ST-66 — the setup_routing routing-block template ships lean: the sentinel span in
# templates.md is <=10 lines, because that block rides into every session's context.
# -----------------------------------------------------------------------------
section "ST-66: setup_routing routing-block template is lean (<=10 lines)"
RT="skills/setup_routing/templates.md"
rt_start=$(grep -n 'CODEOPS-ROUTING:START' "$RT" | head -1 | cut -d: -f1)
rt_end=$(grep -n 'CODEOPS-ROUTING:END' "$RT" | head -1 | cut -d: -f1)
if [[ -n "$rt_start" && -n "$rt_end" ]]; then
  rt_span=$(( rt_end - rt_start + 1 ))
  if [[ "$rt_span" -le 10 ]]; then
    pass "routing-block template span is $rt_span lines (<=10)"
  else
    fail "routing-block template span is $rt_span lines; must be <=10 (it rides into every session)"
  fi
else
  fail "routing-block sentinels not found in $RT"
fi

# -----------------------------------------------------------------------------
# ST-67 — analyze_project replaces its refresh comment in place: a single comment,
# never an appended stack that grows every run.
# -----------------------------------------------------------------------------
section "ST-67: analyze_project refresh comment is replace-in-place (single)"
if grep -qiF 'replace-in-place' "$AP" \
   && grep -qiE 'single refresh comment' "$AP"; then
  pass "documents a single replace-in-place refresh comment"
else
  fail "analyze_project must document replacing the refresh comment in place (a single comment, not an appended stack)"
fi

# -----------------------------------------------------------------------------
# ST-68 — every agents/*.md has complete frontmatter: name, description, tools,
# model (sonnet|opus|haiku|fable|inherit), effort (low|medium|high); description
# within the listing budget.
# -----------------------------------------------------------------------------
section "ST-68: agent frontmatter complete and within budgets"
if [[ "$HAVE_PY3" -eq 1 ]]; then
  while IFS=$'\t' read -r afile aname amodel aeffort adesclen atools; do
    [[ -z "$afile" ]] && continue
    a_ok=1
    [[ -n "$aname" ]] || { fail "$afile: missing name"; a_ok=0; }
    [[ -n "$atools" ]] || { fail "$afile: missing tools"; a_ok=0; }
    case "$amodel" in
      sonnet|opus|haiku|fable|inherit) : ;;
      *) fail "$afile: model '${amodel:-<missing>}' not in sonnet|opus|haiku|fable|inherit"; a_ok=0 ;;
    esac
    case "$aeffort" in
      low|medium|high) : ;;
      *) fail "$afile: effort '${aeffort:-<missing>}' not in low|medium|high"; a_ok=0 ;;
    esac
    if [[ -z "$adesclen" || "$adesclen" -eq 0 ]]; then
      fail "$afile: missing description"; a_ok=0
    elif [[ "$adesclen" -gt "$DESC_LIMIT" ]]; then
      fail "$afile: description = $adesclen chars (> $DESC_LIMIT)"; a_ok=0
    fi
    [[ "$a_ok" -eq 1 ]] && pass "$afile frontmatter complete (model=$amodel effort=$aeffort desc=${adesclen}c)"
  done < <(
    python3 <<'PY'
import glob

def frontmatter(text):
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
    for i, line in enumerate(fm):
        stripped = line.strip()
        if stripped.startswith(key + ":"):
            rest = stripped[len(key) + 1:].strip()
            if rest and rest[0] in "|>":
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
            return rest.strip().strip('"').strip("'")
    return ""

for path in sorted(glob.glob("agents/*.md")):
    with open(path) as fh:
        fm = frontmatter(fh.read())
    print("\t".join([
        path,
        scalar(fm, "name"),
        scalar(fm, "model"),
        scalar(fm, "effort"),
        str(len(scalar(fm, "description"))),
        scalar(fm, "tools"),
    ]))
PY
  )
else
  fail "python3 unavailable — cannot parse agent frontmatter reliably"
fi

# -----------------------------------------------------------------------------
# ST-69 — roster drift guard: exactly the 12 expected agent files (2 executors +
# 10 quality agents), no strays.
# -----------------------------------------------------------------------------
section "ST-69: agent roster is exactly the 12 expected files"
EXPECTED_AGENTS=(codebase-scout concurrency-auditor design-challenger
  financial-integrity-auditor perf-auditor phase-reviewer plan-task-executor
  plan-task-executor-opus preflight-auditor security-auditor semantics-reviewer
  spec-test-author)
roster_ok=1
for a in "${EXPECTED_AGENTS[@]}"; do
  if [[ ! -f "agents/$a.md" ]]; then
    fail "agents/$a.md missing from the roster"
    roster_ok=0
  fi
done
actual_agents="$(ls agents/*.md 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$actual_agents" != "12" ]]; then
  fail "agents/ holds $actual_agents .md files; expected exactly 12"
  roster_ok=0
fi
[[ "$roster_ok" -eq 1 ]] && pass "all 12 expected agent files present, no strays"

# -----------------------------------------------------------------------------
# ST-70 — _shared/quality-profile.md: present, non-empty, stamped, carries the
# CODEOPS-QUALITY sentinel pair and the full lens (7) + security_profile (5) enums.
# -----------------------------------------------------------------------------
section "ST-70: quality-profile.md present with sentinels and full enums"
QP="_shared/quality-profile.md"
if [[ -s "$QP" ]]; then
  pass "$QP exists and is non-empty"
  grep -q "CodeOps Skills Version" "$QP" && pass "carries a version stamp" || fail "missing the version stamp"
  if grep -q "CODEOPS-QUALITY:START" "$QP" && grep -q "CODEOPS-QUALITY:END" "$QP"; then
    pass "CODEOPS-QUALITY sentinel pair present"
  else
    fail "CODEOPS-QUALITY sentinel pair missing/incomplete"
  fi
  QP_LENSES="$(sed -n '/^### Lens enum/,/^### security_profile/p' "$QP" | grep -oE '^\| `[a-z-]+`' | sed 's/[|` ]//g')"
  QP_SECS="$(sed -n '/^### security_profile/,/^### Severity/p' "$QP" | grep -oE '^\| `[a-z-]+`' | sed 's/[|` ]//g')"
  lens_n="$(printf '%s\n' $QP_LENSES | grep -c . || true)"
  sec_n="$(printf '%s\n' $QP_SECS | grep -c . || true)"
  if [[ "$lens_n" -eq 7 ]]; then
    pass "lens enum table lists 7 values"
  else
    fail "lens enum table lists $lens_n values; expected 7"
  fi
  if [[ "$sec_n" -eq 5 ]]; then
    pass "security_profile enum table lists 5 values"
  else
    fail "security_profile enum table lists $sec_n values; expected 5"
  fi
else
  fail "$QP missing or empty"
  QP_LENSES=""
  QP_SECS=""
fi

# -----------------------------------------------------------------------------
# ST-71 — taxonomy-drift guard: concrete lens / security_profile values referenced
# by the skills, agents, and the retro command must be members of the
# quality-profile.md enums (the enums are read FROM that file — adding a value
# there legalizes it everywhere).
# -----------------------------------------------------------------------------
section "ST-71: lens/security_profile references match the enums"
qp_lenses_flat=" $(printf '%s ' $QP_LENSES)"
qp_secs_flat=" $(printf '%s ' $QP_SECS)"
st71_bad=0
for f in skills/*/SKILL.md agents/*.md commands/codeops_retro.md; do
  [[ -f "$f" ]] || continue
  while read -r tok; do
    [[ -z "$tok" || "$tok" == *"<"* ]] && continue
    if [[ "$qp_lenses_flat" != *" $tok "* ]]; then
      fail "$f references lens '$tok' — not in the quality-profile.md enum"
      st71_bad=1
    fi
  done < <({ grep -ohE 'lenses: \[[^]]*\]' "$f" 2>/dev/null | sed 's/lenses: \[//; s/\]//' | tr ',' '\n' | tr -d ' `'; grep -ohE 'lens=[a-z-]+' "$f" 2>/dev/null | cut -d= -f2; } | grep . || true)
  while read -r tok; do
    [[ -z "$tok" || "$tok" == *"<"* ]] && continue
    if [[ "$qp_secs_flat" != *" $tok "* ]]; then
      fail "$f references security profile '$tok' — not in the quality-profile.md enum"
      st71_bad=1
    fi
  done < <(grep -ohE 'security_profile: \[[^]]*\]' "$f" 2>/dev/null | sed 's/security_profile: \[//; s/\]//' | tr ',' '\n' | tr -d ' `' | grep . || true)
done
[[ "$st71_bad" -eq 0 ]] && pass "no lens/security_profile reference falls outside the enums"

# -----------------------------------------------------------------------------
# ST-72 — hooks.json registers the PostToolUse telemetry hook referencing
# codeops-events.sh (structural, no execution; grep fallback without python3).
# -----------------------------------------------------------------------------
section "ST-72: hooks.json registers the PostToolUse telemetry hook"
if is_valid_json "$HOOKS"; then
  if [[ "$HAVE_PY3" -eq 1 ]]; then
    has_posttooluse="$(json_get "$HOOKS" '"yes" if "PostToolUse" in data.get("hooks", {}) else None')"
  else
    has_posttooluse="$(grep -o '"PostToolUse"' "$HOOKS" | head -1)"
  fi
  if [[ -n "$has_posttooluse" ]]; then
    pass "PostToolUse hook registered"
  else
    fail "no PostToolUse hook in $HOOKS"
  fi
  if grep -q "codeops-events.sh" "$HOOKS"; then
    pass "hook references codeops-events.sh"
  else
    fail "hook does not reference codeops-events.sh"
  fi
else
  fail "$HOOKS is missing or not valid JSON"
fi

# -----------------------------------------------------------------------------
# ST-73 — telemetry surface intact: utility + spec suite present, executable,
# stamped; every event/field/enum token named in emission prose exists in the
# utility's vocabulary; the utility accepts all 7 lens values (catalog drift).
# -----------------------------------------------------------------------------
section "ST-73: telemetry utility/suite present; no catalog drift"
EV_UTIL="scripts/codeops-events.sh"
EV_SUITE="scripts/telemetry-check.sh"
for f in "$EV_UTIL" "$EV_SUITE"; do
  if [[ -x "$f" ]]; then
    pass "$f present and executable"
  else
    fail "$f missing or not executable"
  fi
  grep -q "CodeOps Skills Version" "$f" 2>/dev/null && pass "$f carries a version stamp" || fail "$f missing the version stamp"
done
if [[ -f "$EV_UTIL" ]]; then
  st73_bad=0
  while read -r tok; do
    [[ -z "$tok" ]] && continue
    [[ -d "skills/$tok" ]] && continue
    if ! grep -q "$tok" "$EV_UTIL"; then
      fail "emission prose names '$tok' — unknown to $EV_UTIL"
      st73_bad=1
    fi
  done < <(grep -rhiE 'emit' skills commands _shared 2>/dev/null \
    | grep -oE '`[a-z]+(_[a-z]+)+`' | tr -d '`' | sort -u || true)
  [[ "$st73_bad" -eq 0 ]] && pass "every emission-prose token exists in the utility's vocabulary"
  lens_drift=0
  for l in $QP_LENSES; do
    if ! grep -q "$l" "$EV_UTIL"; then
      fail "lens '$l' from quality-profile.md is not accepted by $EV_UTIL"
      lens_drift=1
    fi
  done
  [[ "$lens_drift" -eq 0 && -n "$QP_LENSES" ]] && pass "utility accepts all lens enum values"
fi

# -----------------------------------------------------------------------------
# ST-74 — the output-style rules ship as their own injected file.
#
# Interaction style and code-quality standards are separate concerns, so they live in
# separate documents; both are injected at SessionStart, which makes the meaningful budget
# the SUM of the two, not either one alone. ST-35 keeps guarding the standards core; this
# check guards the combined injected volume so splitting the file cannot become a way to
# grow it unnoticed. Sentinels are quoted so a rewording can't silently drop a rule.
# -----------------------------------------------------------------------------
section "ST-74: output-style rules are injected and the combined budget holds"
OUTPUT_STYLE="standards/output-style.md"
if [[ -s "$OUTPUT_STYLE" ]]; then
  pass "$OUTPUT_STYLE exists and is non-empty"
else
  fail "$OUTPUT_STYLE is missing or empty"
fi
style_lines="$(wc -l <"$OUTPUT_STYLE" 2>/dev/null | tr -d ' ')"
if [[ -z "$style_lines" ]]; then
  fail "cannot measure the combined injected budget — $OUTPUT_STYLE is unreadable"
else
  combined_lines=$(( core_lines + style_lines ))
  if [[ "$combined_lines" -le 65 ]]; then
    pass "combined injected standards are slim ($combined_lines lines <= 65)"
  else
    fail "combined injected standards are $combined_lines lines (> 65)"
  fi
fi
# Each of the four user-facing behaviours the file exists to guarantee.
for sentinel in "tabular" "Next steps" "effort" "/compact"; do
  if grep -qiF "$sentinel" "$OUTPUT_STYLE" 2>/dev/null; then
    pass "$OUTPUT_STYLE carries the \"$sentinel\" rule"
  else
    fail "$OUTPUT_STYLE lost the \"$sentinel\" rule"
  fi
done
if is_valid_json "$HOOKS" && grep -qF 'standards/output-style.md' "$HOOKS" 2>/dev/null; then
  pass "hooks.json injects $OUTPUT_STYLE at SessionStart"
else
  fail "hooks.json does not inject $OUTPUT_STYLE at SessionStart"
fi

# -----------------------------------------------------------------------------
# ST-75 — the agent-sync surface is intact: engine + spec suite present, executable,
# stamped; the convention documents the value forms and the generated-file marker; and
# setup_routing points at the engine instead of telling anyone to hand-copy an agent.
#
# The whole point of the engine is that a per-repo effort override stops being a silent
# fork of the plugin's prompt. That guarantee lives in three places at once — the engine,
# the convention, and the skill that invokes it — so this check pins all three together:
# any one of them drifting re-opens the hole. Sentinels are quoted so a rewording cannot
# quietly break the contract without the author seeing which one they broke.
# -----------------------------------------------------------------------------
section "ST-75: agent-sync engine, suite, and convention agree"
AS_UTIL="scripts/codeops-agents-sync.sh"
AS_SUITE="scripts/agents-sync-check.sh"
SR="skills/setup_routing/SKILL.md"
for f in "$AS_UTIL" "$AS_SUITE"; do
  if [[ -x "$f" ]]; then
    pass "$f present and executable"
  else
    fail "$f missing or not executable"
  fi
  grep -q "CodeOps Skills Version" "$f" 2>/dev/null && pass "$f carries a version stamp" \
    || fail "$f missing the version stamp"
done
# The marker is the ownership boundary — without it the engine cannot tell its own output
# from a user's deliberate fork, and "never overwrite a hand-authored agent" stops holding.
for f in "$AS_UTIL" "$QP"; do
  grep -qF 'CODEOPS-GENERATED' "$f" 2>/dev/null && pass "$f names the CODEOPS-GENERATED marker" \
    || fail "$f does not name the CODEOPS-GENERATED marker"
done
# The engine's effort enum and the convention's must not drift apart: an effort the docs
# advertise but the engine rejects is a per-repo override that silently never materializes.
as_efforts="$(grep -m1 'VALID_EFFORT' "$AS_UTIL" 2>/dev/null || true)"
for e in low medium high xhigh max; do
  if grep -qF "\"$e\"" <<<"$as_efforts"; then
    pass "engine accepts effort '$e'"
  else
    fail "effort '$e' is missing from $AS_UTIL's VALID_EFFORT enum"
  fi
  if grep -qF "\`$e\`" "$QP" 2>/dev/null; then
    pass "quality-profile.md documents effort '$e'"
  else
    fail "effort '$e' is accepted by the engine but undocumented in $QP"
  fi
done
if grep -qF 'agent_models' "$AS_UTIL" 2>/dev/null; then
  pass "engine reads agent_models from the quality profile"
else
  fail "$AS_UTIL does not read agent_models"
fi
if grep -qiE 'effort' "$QP" && grep -qF 'codeops-agents-sync.sh' "$QP"; then
  pass "quality-profile.md documents effort overrides and names the engine"
else
  fail "quality-profile.md must document effort overrides and name $AS_UTIL"
fi
if grep -qF 'codeops-agents-sync.sh' "$SR" 2>/dev/null; then
  pass "setup_routing invokes the sync engine"
else
  fail "setup_routing must invoke $AS_UTIL rather than hand-copying agents"
fi

# =============================================================================
# Python toolchain and evaluation harness (ST-76…ST-80)
#
# SPECIFICATION tests written from the spec BEFORE the implementation — red on
# the unmodified repo, green as the harness lands. Same technique as ST-25…ST-40.
#
# The repository's engines are Bash entry points with embedded Python; a module
# with an independent unit-test surface is a standalone .py instead. These checks
# guard that second class: it must be declared, stamped, spec-tested, free of
# ephemeral planning references, and invisible to the plugin loader.
# =============================================================================

# Declared standalone Python modules. Extend this list when a module is added —
# an undeclared scripts/*.py is a failure, so a new module cannot dodge the
# checks below by simply never being listed.
PY_MODULES=(
  "scripts/codeops_eval.py"
  "scripts/codeops_worktree_snapshot.py"
)

# -----------------------------------------------------------------------------
# ST-76 — every declared Python module exists and carries a version stamp.
# ST-24 already checks that a stamp's VALUE matches; this checks it is PRESENT,
# which ST-24 cannot see (a file with no stamp contributes no line to its sweep).
# -----------------------------------------------------------------------------
section "ST-76: declared Python modules exist and are version-stamped"
for f in "${PY_MODULES[@]}"; do
  if [[ ! -s "$f" ]]; then
    fail "$f is missing or empty"
  elif grep -qE 'CodeOps (Skills )?Version[^0-9]*[0-9]+\.[0-9]+\.[0-9]+' "$f"; then
    pass "$f present and stamped"
  else
    fail "$f has no CodeOps Skills Version stamp"
  fi
done
# An undeclared module would silently escape ST-77 and ST-80.
while IFS= read -r found; do
  declared=0
  for f in "${PY_MODULES[@]}"; do [[ "$found" == "$f" ]] && declared=1; done
  if [[ "$declared" -eq 1 ]]; then
    pass "$found is declared in PY_MODULES"
  else
    fail "$found is not declared in PY_MODULES (add it, so ST-77/ST-80 cover it)"
  fi
done < <(find scripts -maxdepth 1 -name '*.py' 2>/dev/null | sort)

# -----------------------------------------------------------------------------
# ST-77 — every declared module has a specification test file.
# Naming is test_<module>_spec.py because pytest's default python_files does not
# collect a bare <module>_spec.py: such a suite would appear to pass by never
# running at all, which is the failure this check exists to make impossible.
# -----------------------------------------------------------------------------
section "ST-77: declared Python modules have specification tests"
for f in "${PY_MODULES[@]}"; do
  base="$(basename "$f" .py)"
  spec="tests/test_${base}_spec.py"
  if [[ -s "$spec" ]]; then
    pass "$spec covers $f"
  else
    fail "$f has no specification test at $spec"
  fi
done

# -----------------------------------------------------------------------------
# ST-78 — tests/ is inert to the plugin loader.
# The loader reads skills/, commands/, hooks/ and .claude-plugin/ only; a test
# tree that reaches an install manifest would ship to every user.
# -----------------------------------------------------------------------------
section "ST-78: tests/ is not part of the shipped surface"
for manifest in ".claude-plugin/plugin.json" ".claude-plugin/marketplace.json" "install.sh"; do
  if [[ ! -f "$manifest" ]]; then
    continue
  elif grep -qE '(^|[^a-zA-Z0-9_/-])tests/' "$manifest"; then
    fail "$manifest references tests/ — the test tree must not ship"
  else
    pass "$manifest does not reference tests/"
  fi
done

# -----------------------------------------------------------------------------
# ST-79 — the development dependency is declared and the virtualenv is ignored.
# pytest is development-only: it is never required to install, load, or run the
# plugin, so it belongs in a dev manifest rather than any shipped manifest.
# -----------------------------------------------------------------------------
section "ST-79: development dependencies declared, virtualenv ignored"
if [[ -s "requirements-dev.txt" ]] && grep -qiE '^pytest' "requirements-dev.txt"; then
  pass "requirements-dev.txt declares pytest"
else
  fail "requirements-dev.txt missing or does not declare pytest"
fi
if grep -qE '^\.venv/?$' ".gitignore" 2>/dev/null; then
  pass ".gitignore ignores .venv/"
else
  fail ".gitignore must ignore .venv/"
fi

# -----------------------------------------------------------------------------
# ST-80 — no shipped Python references an ephemeral CodeOps artifact.
# Planning folders are ephemeral and git-ignored; shipped code must stand alone.
# The same ban the executor agents already carry, enforced for .py as well.
# -----------------------------------------------------------------------------
section "ST-80: shipped Python carries no ephemeral CodeOps reference"
for f in "${PY_MODULES[@]}"; do
  [[ -s "$f" ]] || continue
  if grep -qE '\b(RD|AR|PA|PF|HR|GATE|AC|ST|ADR|DEF)-[0-9]|(codeops|plans|requirements)/' "$f"; then
    fail "$f references an ephemeral CodeOps artifact (plan/requirement path or id)"
  else
    pass "$f is free of ephemeral CodeOps references"
  fi
done

# -----------------------------------------------------------------------------
# ST-81 — the evaluation harness is documented with its limits attached.
# A measurement quoted without its scope invites over-reading: the harness sees
# the requirements stage only, and the page that explains it must say so.
# -----------------------------------------------------------------------------
section "ST-81: the evaluation harness is documented with its limits"
harness_doc="docs/reference/evaluation-harness.md"
if [[ ! -s "$harness_doc" ]]; then
  fail "$harness_doc is missing — the harness must be documented"
else
  pass "$harness_doc exists"
  for phrase in "requirements-stage" "execution quality" "recovery" "system quality"; do
    if grep -qiF "$phrase" "$harness_doc"; then
      pass "$harness_doc states its limit on \"$phrase\""
    else
      fail "$harness_doc does not state its limit on \"$phrase\""
    fi
  done
fi

# -----------------------------------------------------------------------------
# ST-82 — the domain enum and references/domains/ are a bijection.
# An enum value with no file sends a skill to a dead reference; a file outside
# the enum is content nothing can legally select. Both are packaging defects.
# -----------------------------------------------------------------------------
section "ST-82: domain enum and reference files agree"
QP_DOMAINS="$(sed -n '/^### Domain enum/,/^### Lens enum/p' "$QP" 2>/dev/null | grep -oE '^\| `[a-z-]+`' | sed 's/[|` ]//g')"
domain_n="$(printf '%s\n' $QP_DOMAINS | grep -c . || true)"
if [[ "$domain_n" -eq 5 ]]; then
  pass "domain enum table lists 5 values"
else
  fail "domain enum table lists $domain_n values; expected 5"
fi
st82_bad=0
for d in $QP_DOMAINS; do
  if [[ -s "references/domains/$d.md" ]]; then
    grep -q "CodeOps Skills Version" "references/domains/$d.md" \
      && pass "references/domains/$d.md present and stamped" \
      || { fail "references/domains/$d.md missing its version stamp"; st82_bad=1; }
  else
    fail "domain '$d' is in the enum but references/domains/$d.md does not exist"
    st82_bad=1
  fi
done
if [[ -s "references/domains/selection.md" ]]; then
  grep -q "CodeOps Skills Version" "references/domains/selection.md" \
    && pass "references/domains/selection.md present and stamped" \
    || fail "references/domains/selection.md missing its version stamp"
else
  fail "references/domains/selection.md does not exist"
  st82_bad=1
fi
for f in references/domains/*.md; do
  [[ -f "$f" ]] || continue
  base="$(basename "$f" .md)"
  [[ "$base" == "selection" ]] && continue
  if [[ " $(printf '%s ' $QP_DOMAINS) " != *" $base "* ]]; then
    fail "$f has no matching value in the domain enum"
    st82_bad=1
  fi
done
[[ "$st82_bad" -eq 0 ]] && pass "enum and reference files are a bijection"

# -----------------------------------------------------------------------------
# ST-83 — "lens" never names a domain.
# This repository already spends `lenses` on phase-reviewer add-ons. Two names
# for two concepts only stays workable if the boundary is mechanical.
# -----------------------------------------------------------------------------
section "ST-83: domain files never say \"lens\""
st83_bad=0
for f in references/domains/*.md; do
  [[ -f "$f" ]] || continue
  if grep -qiE '\blens(es)?\b' "$f"; then
    fail "$f uses \"lens\" — that word names phase-reviewer add-ons, not domains"
    st83_bad=1
  fi
done
[[ "$st83_bad" -eq 0 ]] && pass "no domain file uses \"lens\" for this concept"

# -----------------------------------------------------------------------------
# ST-84 — every wired skill reaches the selection rubric.
# A skill that stops referencing it silently reverts to the undifferentiated
# question sweep, which is precisely the regression this phase exists to undo.
# -----------------------------------------------------------------------------
section "ST-84: the four wired skills reference the selection rubric"
for s in make_requirements preflight grill_me retro_requirements; do
  if grep -rqF "references/domains/selection.md" "skills/$s/" 2>/dev/null; then
    pass "skills/$s references selection.md"
  else
    fail "skills/$s does not reference references/domains/selection.md"
  fi
done

# -----------------------------------------------------------------------------
# ST-85 — classification stays outside the quality loop.
# It runs unconditionally, which is only defensible while it dispatches nothing
# and emits nothing: those two are what the profile's absence rule governs.
# -----------------------------------------------------------------------------
section "ST-85: domain files dispatch no agent and emit no telemetry"
st85_bad=0
for f in references/domains/*.md; do
  [[ -f "$f" ]] || continue
  if grep -qE 'codeops-events\.sh|subagent_type|codeops-dispatch' "$f"; then
    fail "$f dispatches or emits — classification must do neither"
    st85_bad=1
  fi
done
[[ "$st85_bad" -eq 0 ]] && pass "no domain file dispatches an agent or emits telemetry"

# -----------------------------------------------------------------------------
# ST-86 — the domains pin key is documented, and documented as pin-only.
# A key that could disable classification would hand back the very default this
# phase removes, so the file that owns the taxonomy must rule it out in writing.
# -----------------------------------------------------------------------------
section "ST-86: the domains profile key is documented as pin-only"
if grep -qE '^\| `domains` \|' "$QP" 2>/dev/null; then
  pass "quality-profile.md documents the domains key"
  if sed -n '/^| `domains` |/p' "$QP" | grep -qiE 'pin|never disable'; then
    pass "the domains key is described as pinning only"
  else
    fail "the domains key must state that it pins the selection and never disables it"
  fi
else
  fail "quality-profile.md does not document the domains key"
fi

# =============================================================================
# Specialist auditors (ST-87…ST-91)
#
# SPECIFICATION tests written from the contract BEFORE the three agents exist —
# red on the unmodified repo, green once the prompts, the supersession edits, and
# the registrations land.
# =============================================================================

SPECIALIST_AGENTS=(concurrency-auditor financial-integrity-auditor semantics-reviewer)

# -----------------------------------------------------------------------------
# ST-87 — each specialist is present, read-only, and inherits the session model.
#
# Read-only is enforced by the tools list, not by the prompt: a prompt that says
# "never edit" while the frontmatter grants Edit is one careless dispatch away
# from a review agent rewriting the work it is judging. Model inheritance is the
# port's own constraint — these three carry no tier pin.
# -----------------------------------------------------------------------------
section "ST-87: specialist auditors are read-only and inherit the model"
for a in "${SPECIALIST_AGENTS[@]}"; do
  f="agents/$a.md"
  if [[ ! -s "$f" ]]; then
    fail "$f missing"
    continue
  fi
  a_tools="$(sed -n '/^---$/,/^---$/p' "$f" | sed -n 's/^tools:[[:space:]]*//p' | head -1)"
  a_model="$(sed -n '/^---$/,/^---$/p' "$f" | sed -n 's/^model:[[:space:]]*//p' | head -1)"
  if [[ -z "$a_tools" ]]; then
    fail "$f declares no tools"
  elif grep -qE '\b(Write|Edit|NotebookEdit)\b' <<<"$a_tools"; then
    fail "$f grants a mutating tool ($a_tools) — specialists are read-only"
  else
    pass "$f is read-only (tools: $a_tools)"
  fi
  if [[ "$a_model" == "inherit" ]]; then
    pass "$f inherits the session model"
  else
    fail "$f pins model '${a_model:-<missing>}' — the specialists must use inherit"
  fi
done

# -----------------------------------------------------------------------------
# ST-88 — supersession is implemented on BOTH sides.
#
# Adding a specialist without withdrawing the dimension from the shared reviewer
# leaves the supersession documentation-only: the ground is then covered twice,
# at two different depths, and the shallower pass is the one that sets
# expectations. The reviewer prompts must say they stand down.
# -----------------------------------------------------------------------------
# The frontmatter is excluded deliberately: both descriptions already claim the
# supersessions these agents *win*, and matching those would pass this check
# without a single instruction reaching the agent that has to stand down.
section "ST-88: superseded dimensions are withdrawn from the shared reviewers"
agent_body() { awk 'BEGIN{d=0} /^---$/{d++; next} d>=2' "$1"; }
if agent_body agents/phase-reviewer.md | grep -qi 'supersed'; then
  pass "phase-reviewer stands down on superseded lenses"
else
  fail "agents/phase-reviewer.md must instruct the reviewer to skip a superseded lens"
fi
if agent_body agents/security-auditor.md | grep -qi 'supersed'; then
  pass "security-auditor stands down on a superseded checklist"
else
  fail "agents/security-auditor.md must instruct the auditor to omit a superseded checklist"
fi

# -----------------------------------------------------------------------------
# ST-89 — the profile documents activation, supersession, and finding prefixes.
#
# quality-profile.md is the naming authority for the quality loop; an agent that
# dispatches without appearing there is invisible to every skill that reads it.
# -----------------------------------------------------------------------------
section "ST-89: quality-profile.md registers the three specialists"
for a in "${SPECIALIST_AGENTS[@]}"; do
  if grep -qF "$a" "$QP"; then
    pass "$QP names $a"
  else
    fail "$QP does not name $a"
  fi
done
if grep -qE 'CA \(concurrency-auditor\)|CA-NNN' "$QP" \
  && grep -qE 'FA \(financial-integrity-auditor\)|FA-NNN' "$QP" \
  && grep -qE 'SR \(semantics-reviewer\)|SR-NNN' "$QP"; then
  pass "the CA / FA / SR finding prefixes are registered"
else
  fail "$QP must register the CA, FA, and SR finding prefixes"
fi
if grep -qF 'compiler-and-language' "$QP" \
  && sed -n '/semantics-reviewer/p' "$QP" | grep -qF 'compiler-and-language'; then
  pass "semantics-reviewer activation derives from the compiler-and-language domain"
else
  fail "$QP must derive semantics-reviewer activation from the compiler-and-language domain"
fi

# -----------------------------------------------------------------------------
# ST-90 — the telemetry roster covers the three.
#
# The gap report asks which reviewer completions were never followed by a ruling.
# A finding-producing agent absent from that roster is silently exempt from the
# question, which reads as an agent with a perfect record rather than an unseen one.
# -----------------------------------------------------------------------------
section "ST-90: the telemetry reviewer roster covers the specialists"
EVENTS_UTIL="scripts/codeops-events.sh"
roster_line="$(grep -E '^REVIEWER_AGENTS=' "$EVENTS_UTIL" 2>/dev/null || true)"
if [[ -z "$roster_line" ]]; then
  fail "$EVENTS_UTIL declares no REVIEWER_AGENTS roster"
else
  for a in "${SPECIALIST_AGENTS[@]}"; do
    if grep -qF "$a" <<<"$roster_line"; then
      pass "REVIEWER_AGENTS covers $a"
    else
      fail "REVIEWER_AGENTS omits $a — its completions would never be gap-checked"
    fi
  done
fi

# -----------------------------------------------------------------------------
# ST-91 — the published roster documents every agent and every supersession.
# -----------------------------------------------------------------------------
section "ST-91: docs/reference/agents.md documents all twelve agents"
AGENT_DOC="docs/reference/agents.md"
if [[ ! -s "$AGENT_DOC" ]]; then
  fail "$AGENT_DOC missing"
else
  doc_ok=1
  for f in agents/*.md; do
    a="$(basename "$f" .md)"
    grep -qF "\`$a\`" "$AGENT_DOC" || { fail "$AGENT_DOC omits $a"; doc_ok=0; }
  done
  [[ "$doc_ok" -eq 1 ]] && pass "$AGENT_DOC lists every shipped agent"
  if grep -qi 'nine subagents' "$AGENT_DOC"; then
    fail "$AGENT_DOC still claims nine subagents"
  else
    pass "$AGENT_DOC's count claim is current"
  fi
  if grep -qi 'supersed' "$AGENT_DOC"; then
    pass "$AGENT_DOC documents supersession"
  else
    fail "$AGENT_DOC must document every supersession relationship"
  fi
fi

# =============================================================================
# Delegated technical design (ST-92…ST-98)
#
# SPECIFICATION tests written from the contract BEFORE the policy exists. The
# flag is parsed from prose, exactly as the commit-mode flags are, so these
# guards assert that every rule standing between a typo and delegated authority
# is actually written down. What they cannot do is prove the rule is followed —
# that is what the behavioral matrix in scripts/fixtures/auto-design/ is for,
# and neither substitutes for the other.
# =============================================================================

AUTO_DESIGN="_shared/auto-design.md"
AD_SKILLS=(make_requirements make_plan preflight exec_plan)

# -----------------------------------------------------------------------------
# ST-92 — the policy exists in one place and carries all eight sections.
# -----------------------------------------------------------------------------
section "ST-92: the auto-design policy is present and complete"
if [[ ! -s "$AUTO_DESIGN" ]]; then
  fail "$AUTO_DESIGN missing"
else
  pass "$AUTO_DESIGN present"
  for heading in "Invocation contract" "Default mode" "Eligibility boundary" \
    "Reserved authority" "Strongest-option procedure" "Durable resolution" \
    "Bounded escalation" "Invalidation" "Supported workflows"; do
    if grep -qiE "^#+ .*$heading" "$AUTO_DESIGN"; then
      pass "section present: $heading"
    else
      fail "$AUTO_DESIGN has no '$heading' section"
    fi
  done
  if grep -qiE 'Policy version.*: *1' "$AUTO_DESIGN"; then
    pass "policy version declared"
  else
    fail "$AUTO_DESIGN must declare its policy version"
  fi
fi

# -----------------------------------------------------------------------------
# ST-93 — the whole hostile-argument matrix is specified, not just the happy path.
#
# Every row here is a way a typo, a shell expansion, or a filename could hand
# over design authority nobody meant to delegate. A parser rule that is not
# written down is a rule the reader is free to improvise.
# -----------------------------------------------------------------------------
section "ST-93: the hostile-argument matrix is fully specified"
if [[ -s "$AUTO_DESIGN" ]]; then
  ad_matrix_ok=1
  check_ad() { # check_ad <label> <grep-pattern>
    if grep -qiE "$2" "$AUTO_DESIGN"; then
      pass "specified: $1"
    else
      fail "$AUTO_DESIGN does not specify: $1"
      ad_matrix_ok=0
    fi
  }
  check_ad "exactly one standalone token activates"        'exactly one standalone token'
  check_ad "the end-of-options sentinel bounds the scan"   'sentinel'
  check_ad "zero occurrences means default mode"           '[Zz]ero occurrences.*[Dd]efault mode'
  check_ad "more than one is invalid, with a correction"   'more than one is invalid|usage correction'
  check_ad "a token at or after the sentinel is content"   'at or after the sentinel is target content'
  check_ad "lookalike --auto-designer is inert"            'auto-designer'
  check_ad "lookalike --auto-design=true is inert"         'auto-design=true'
  check_ad "lookalike bare auto-design is inert"           'bare .?auto-design'
  check_ad "removal precedes target resolution"            'remove[sd]? the .*token before resolving'
  [[ "$ad_matrix_ok" -eq 1 ]] && pass "every hostile-argument case is written down"
fi

# -----------------------------------------------------------------------------
# ST-94 — reserved authority is ported whole, and the flag grants no action.
#
# The reserved list is the entire safety boundary of this feature: it is what
# stops a delegated technical decision from becoming a product, money, or
# security decision. A category dropped in transcription is a silent widening.
# -----------------------------------------------------------------------------
section "ST-94: reserved authority is complete and grants no action permission"
if [[ -s "$AUTO_DESIGN" ]]; then
  ad_reserved_ok=1
  for term in "product behavior" "scope" "acceptance criteria" "security policy" \
    "data ownership" "retention" "compliance" "risk acceptance" "financial exposure" \
    "budget" "deadline" "vendor" "compatibility break" "destructive migration" \
    "credential" "spending" "deployment" "publication" "external communication" \
    "equally defensible"; do
    if grep -qi -- "$term" "$AUTO_DESIGN"; then
      pass "reserved category present: $term"
    else
      fail "$AUTO_DESIGN omits reserved category: $term"
      ad_reserved_ok=0
    fi
  done
  if grep -qiE 'does not grant action permission' "$AUTO_DESIGN" \
    && grep -qiE '\-\-auto-commit' "$AUTO_DESIGN"; then
    pass "the no-action-permission clause names auto-commit explicitly"
  else
    fail "$AUTO_DESIGN must state it grants no action permission, naming --auto-commit"
    ad_reserved_ok=0
  fi
  [[ "$ad_reserved_ok" -eq 1 ]] && pass "reserved authority survived the port intact"
fi

# -----------------------------------------------------------------------------
# ST-95 — the supported surface is a closed allowlist.
#
# These four skills are themselves the slash commands (`/codeops:exec_plan <feature>
# --auto-commit`), so wiring the skill wires the only invocation path there is;
# there is no command wrapper that could silently drop the flag. What still needs
# guarding is the other direction — a fifth workflow quietly claiming the
# authority, which the closed-allowlist sweep below catches.
# -----------------------------------------------------------------------------
section "ST-95: exactly four skills honor the flag, and no others"
ad_surface_ok=1
for s in "${AD_SKILLS[@]}"; do
  if grep -qF 'auto-design' "skills/$s/SKILL.md" 2>/dev/null; then
    pass "skills/$s honors the flag"
  else
    fail "skills/$s/SKILL.md does not honor --auto-design"
    ad_surface_ok=0
  fi
done
while read -r stray; do
  [[ -z "$stray" ]] && continue
  if [[ "$stray" == commands/* ]]; then
    base="$(basename "$stray" .md)"
  else
    base="$(basename "$(dirname "$stray")")"
  fi
  case " ${AD_SKILLS[*]} " in
    *" $base "*) continue ;;
  esac
  fail "$stray references --auto-design but is outside the allowlist"
  ad_surface_ok=0
done < <(grep -lF 'auto-design' skills/*/*.md commands/*.md 2>/dev/null || true)
[[ "$ad_surface_ok" -eq 1 ]] && pass "the supported-workflow allowlist is closed and complete"

# -----------------------------------------------------------------------------
# ST-96 — nothing persists or confers the mode (ST-4.12).
#
# The feature's containment rests entirely on it being invocation-scoped. A
# config key that switched it on would make a shared repo permanently delegated,
# and a historical record read as standing authority would do the same by habit.
# -----------------------------------------------------------------------------
section "ST-96: the mode is never persisted and no key grants it"
if grep -qiE '^\| .auto.design' "$QP" || grep -qiE '^\| .auto_design' "$QP"; then
  fail "$QP defines a profile key for auto-design — the mode must not be configurable"
else
  pass "no quality-profile key grants or refuses the mode"
fi
# A leading `--` is required to be ABSENT: the policy and every skill that links
# to it must quote `--auto-design=true` in order to declare that lookalike inert,
# and a sweep that cannot tell quoting-to-forbid from assigning would fire on the
# documentation of the rule it is enforcing. A settings key has no dashes.
ad_persist="$(grep -rlniE '(^|[^-])auto[-_]design *[:=] *(true|on|yes|1)' \
  skills/ commands/ standards/ _shared/ agents/ hooks/ .claude-plugin/ 2>/dev/null || true)"
if [[ -n "$ad_persist" ]]; then
  fail "auto-design is assigned as a setting in: $(tr '\n' ' ' <<<"$ad_persist")"
else
  pass "no shipped file assigns auto-design as a setting"
fi
if [[ -s "$AUTO_DESIGN" ]] && grep -qiE 'never persisted' "$AUTO_DESIGN" \
  && grep -qiE 'confer|standing authority' "$AUTO_DESIGN"; then
  pass "the policy states non-persistence and that history confers no authority"
else
  fail "$AUTO_DESIGN must state the mode is never persisted and history confers no authority"
fi

# -----------------------------------------------------------------------------
# ST-97 — the finding gate resolves, and never waives.
#
# This is the phase's accepted-risk surface. A finding may be fixed under
# delegated authority; it may never be talked away. The distinction has to be
# explicit in the skill that runs the gate, not only in the policy.
# -----------------------------------------------------------------------------
section "ST-97: findings are resolved with a fix, never waived"
ad_gate_ok=1
for f in "$AUTO_DESIGN" "skills/exec_plan/execution-protocol.md"; do
  [[ -s "$f" ]] || { fail "$f missing"; ad_gate_ok=0; continue; }
  if grep -qiE 'never .*(waiv|dismiss|downgrad)' "$f"; then
    pass "$f forbids waiving, dismissing, or downgrading a finding"
  else
    fail "$f must state a finding is never waived, dismissed, or downgraded"
    ad_gate_ok=0
  fi
done
if grep -qiE 'reserved' skills/exec_plan/execution-protocol.md \
  && grep -qiE 'auto-design' skills/exec_plan/execution-protocol.md; then
  pass "the finding gate names the reserved-authority pause"
else
  fail "execution-protocol.md must state that reserved decisions still pause under auto-design"
  ad_gate_ok=0
fi
[[ "$ad_gate_ok" -eq 1 ]] && pass "the no-waiver rule is stated where the gate runs"

# -----------------------------------------------------------------------------
# ST-98 — the provenance record carries all twelve fields.
#
# The record is the only durable trace that a decision was made by delegation
# rather than by the user. A missing field is a decision nobody can audit later.
# -----------------------------------------------------------------------------
section "ST-98: the delegated resolution record has all twelve fields"
if [[ -s "$AUTO_DESIGN" ]]; then
  ad_fields_ok=1
  for field in "Authority" "Eligibility" "Objective" "Decision" "Evidence" \
    "Rejected alternatives" "Strongest counterargument" "Confidence" "Hardening" \
    "Policy version" "Root invocation ID" "Reopen triggers"; do
    if grep -qE "^${field}:" "$AUTO_DESIGN"; then
      pass "provenance field: $field"
    else
      fail "$AUTO_DESIGN omits provenance field: $field"
      ad_fields_ok=0
    fi
  done
  if grep -qiE 'parallel decision database' "$AUTO_DESIGN"; then
    pass "the record forbids a parallel decision database"
  else
    fail "$AUTO_DESIGN must forbid a parallel decision database"
    ad_fields_ok=0
  fi
  [[ "$ad_fields_ok" -eq 1 ]] && pass "the provenance record is complete"
fi

# -----------------------------------------------------------------------------
# ST-99 — the review packet comes from the worktree snapshot, not a commit range.
# A commit-range diff is empty in --no-commit mode, so a reviewer fed one reports
# clean on code it never received. Naming the engine is half the fix; the other
# half is that the old definition is gone, because a document carrying both
# leaves the reader to pick, and the wrong pick is the silent failure.
# -----------------------------------------------------------------------------
section "ST-99: the review packet is the worktree snapshot"
SNAPSHOT_ENGINE="scripts/codeops_worktree_snapshot.py"
for consumer in "$QP" "$EXEC_PROTO"; do
  if [[ ! -s "$consumer" ]]; then
    fail "$consumer is missing"
    continue
  fi
  if grep -qF "codeops_worktree_snapshot" "$consumer"; then
    pass "$consumer names the snapshot engine"
  else
    fail "$consumer must name $SNAPSHOT_ENGINE as the source of the review packet"
  fi
  # `<phase-ref>..HEAD` and its spelled variants are the commit-range definition
  # this phase replaces. Any surviving instance is a second, contradicting rule.
  if grep -qE 'git diff [^|]*\.\.HEAD' "$consumer"; then
    fail "$consumer still defines the packet as a commit-range diff (…..HEAD)"
  else
    pass "$consumer no longer defines the packet as a commit-range diff"
  fi
done

# -----------------------------------------------------------------------------
# ST-100 — the packet definition carries the snapshot's four invariants.
# quality-profile.md owns what a dispatched reviewer receives, so a reviewer or
# a future editor can read the guarantees at the point of use rather than
# inferring them from an engine they will never open.
# -----------------------------------------------------------------------------
section "ST-100: the packet definition states the snapshot invariants"
# Scoped to the packet section, not the whole file. A whole-file sweep for
# "omitted" already matches a telemetry sentence about missing headers, which
# would report the bounded-output invariant as present while no such rule
# existed anywhere — the guard has to look where the packet is actually defined.
qp_packets="$(awk '/^## Dispatch packets/{inside=1; print; next} inside && /^## /{exit} inside' "$QP" 2>/dev/null)"
if [[ -z "$qp_packets" ]]; then
  fail "$QP has no '## Dispatch packets' section to check"
else
  # Each pattern is an invariant, not a wording: read-only, mode-invariance,
  # bounded-with-omissions, and loud failure.
  declare -A SNAP_INVARIANTS=(
    ["read-only"]='read-only'
    ["commit-mode invariance"]='(commit mode|commit modes).*(identical|invariant)|(identical|invariant).*(commit mode|commit modes)'
    ["bounded output"]='truncat'
    ["loud failure"]='blocker'
  )
  for name in "${!SNAP_INVARIANTS[@]}"; do
    if printf '%s\n' "$qp_packets" | grep -qiE "${SNAP_INVARIANTS[$name]}"; then
      pass "$QP states the $name invariant where the packet is defined"
    else
      fail "$QP does not state the $name invariant in its packet section"
    fi
  done
fi

# -----------------------------------------------------------------------------
# ST-101 — a failed snapshot blocks the quality step; nothing is substituted.
# The dangerous fallback is a partial diff reviewed as if it were complete, so
# the protocol has to forbid the substitution explicitly, not merely omit it.
# -----------------------------------------------------------------------------
section "ST-101: snapshot failure is a blocker, never a partial fallback"
if [[ -s "$EXEC_PROTO" ]]; then
  if grep -qiE 'snapshot' "$EXEC_PROTO" && grep -qiE 'blocker' "$EXEC_PROTO"; then
    pass "$EXEC_PROTO reports a failed snapshot as a blocker"
  else
    fail "$EXEC_PROTO must report a failed snapshot as a blocker"
  fi
  if grep -qiE '(never|no) (falls? back|partial|substitut)' "$EXEC_PROTO"; then
    pass "$EXEC_PROTO forbids substituting a partial diff"
  else
    fail "$EXEC_PROTO must forbid substituting a partial diff for a failed snapshot"
  fi
fi

# -----------------------------------------------------------------------------
# ST-102 — the snapshot is documented with the blind spot it closes.
# A user who never sees why the packet changed cannot tell whether their own
# --no-commit phases were ever genuinely reviewed before this release.
# -----------------------------------------------------------------------------
section "ST-102: the worktree snapshot is documented"
snapshot_doc="docs/reference/worktree-snapshot.md"
if [[ ! -s "$snapshot_doc" ]]; then
  fail "$snapshot_doc is missing — the snapshot must be documented"
else
  pass "$snapshot_doc exists"
  for phrase in "no-commit" "untracked" "gitignore" "read-only" "truncat"; do
    if grep -qiF "$phrase" "$snapshot_doc"; then
      pass "$snapshot_doc covers \"$phrase\""
    else
      fail "$snapshot_doc does not cover \"$phrase\""
    fi
  done
fi

# -----------------------------------------------------------------------------
# ST-103 — every event the protocol tells a skill to emit exists in the catalog.
#
# The catalog refuses an unknown event type whole-line and only warns to stderr, so a
# pinned emission moment for a type nobody added is invisible: the skill dutifully calls
# the utility, the line is dropped, and the measure reads as "never happened" rather than
# "never collected". Nothing else in the suite compares the two lists, which is how one
# such moment survived several releases.
# -----------------------------------------------------------------------------
section "ST-103: pinned emission moments match the event catalog"
events_util="scripts/codeops-events.sh"
if [[ ! -s "$events_util" || ! -s "$EXEC_PROTO" ]]; then
  fail "cannot cross-check emissions — $events_util or $EXEC_PROTO missing"
else
  catalog_types="$(awk '/^allowed_keys_for\(\) \{/{inside=1; next} inside && /^\}/{exit} inside' \
      "$events_util" \
    | sed -n 's/^[[:space:]]*\([a-z_|]*\))[[:space:]].*/\1/p' | tr '|' '\n' | sort -u)"
  emitted_types="$(awk '/^### Telemetry emissions/{inside=1; next} inside && /^### /{exit} inside' \
      "$EXEC_PROTO" \
    | awk -F'|' '/^\| *`[a-z_]/ {print $2}' | grep -oE '[a-z_]+' | sort -u)"
  if [[ -z "$catalog_types" || -z "$emitted_types" ]]; then
    fail "ST-103 could not extract both lists (catalog=$(wc -w <<<"$catalog_types") protocol=$(wc -w <<<"$emitted_types"))"
  else
    orphans="$(comm -23 <(printf '%s\n' "$emitted_types") <(printf '%s\n' "$catalog_types"))"
    if [[ -z "$orphans" ]]; then
      pass "every pinned emission moment names a catalogued event type"
    else
      fail "pinned moments with no catalog entry — every emit is refused: $(tr '\n' ' ' <<<"$orphans")"
    fi
  fi
fi

# -----------------------------------------------------------------------------
# ST-104 — the measure taxonomy is documented and its content-free guarantee restated.
#
# The guarantee is the reason this telemetry is defensible at all, so it is restated
# wherever the new measures are introduced rather than left to a link.
# -----------------------------------------------------------------------------
section "ST-104: the measure taxonomy is documented"
telemetry_doc="docs/guide/telemetry.md"
if [[ ! -s "$telemetry_doc" ]]; then
  fail "$telemetry_doc is missing — the taxonomy must be documented"
else
  for type in spec_test_cycle runtime_ambiguity session_resumed design_delegated; do
    if grep -qF "$type" "$telemetry_doc"; then
      pass "$telemetry_doc documents \`$type\`"
    else
      fail "$telemetry_doc does not document \`$type\`"
    fi
  done
  if grep -qiE 'content-free|never (stores|records).*(text|content)' "$telemetry_doc"; then
    pass "$telemetry_doc restates the content-free guarantee"
  else
    fail "$telemetry_doc must restate the content-free guarantee"
  fi
  # A measure dropped for privacy is a design outcome, not an omission; saying so is what
  # stops the next reader from "fixing" it with something content-bearing.
  if grep -qiE 'dropped' "$telemetry_doc"; then
    pass "$telemetry_doc records that some measures are deliberately dropped"
  else
    fail "$telemetry_doc must record the deliberately dropped measures"
  fi
fi

# -----------------------------------------------------------------------------
# ST-105 — every shared-document reference from every skill resolves.
#
# The shared docs are linked by relative path from skills two directories down, so a
# rename or a move breaks silently: the skill still loads, the link simply points at
# nothing, and the convention it was supposed to carry quietly stops being read.
# -----------------------------------------------------------------------------
section "ST-105: every _shared reference resolves"
shared_refs_ok=1
shared_ref_count=0
while IFS= read -r src; do
  [[ -z "$src" ]] && continue
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    shared_ref_count=$((shared_ref_count + 1))
    if [[ ! -f "$ref" ]]; then
      fail "$src references $ref, which does not exist"
      shared_refs_ok=0
    fi
  done < <(grep -oE '_shared/[a-z0-9-]+\.md' "$src" | sort -u)
done < <(find skills commands agents standards -name '*.md' 2>/dev/null | sort)
if [[ "$shared_refs_ok" -eq 1 ]]; then
  pass "all $shared_ref_count shared-document references resolve"
fi

# -----------------------------------------------------------------------------
# ST-106 — the gate's closure conditions are present and complete.
#
# This list is what makes the gate a gate. Losing a condition to an edit would not
# break anything visibly — the document still reads well, the gate still "passes",
# and it passes on strictly less evidence than it used to.
# -----------------------------------------------------------------------------
section "ST-106: the zero-ambiguity gate's closure conditions are complete"
zag="_shared/zero-ambiguity-gate.md"
if [[ ! -s "$zag" ]]; then
  fail "$zag is missing"
else
  # The section between "GATE OPENS" and the next heading owns the numbered conditions.
  zag_closure="$(awk 'tolower($0) ~ /gate opens only when/{inside=1} inside && /^## /{exit} inside' "$zag")"
  # Each pattern is anchored to its own numbered condition. An unanchored phrase would
  # also match the explanatory prose that follows the list in the same section, so a
  # deleted condition would still be "found" — the guard would pass over its own gap.
  declare -A ZAG_CONDITIONS=(
    ["every row resolved or named-deferred"]='^[0-9]+\. ✅ Every row has Status'
    ["resolutions carry a decision"]='^[0-9]+\. ✅ Every resolution contains'
    ["the complete register is confirmed"]='^[0-9]+\. ✅ .*confirmed the complete register'
    ["no silent deferrals"]='^[0-9]+\. ✅ Zero items are \*\*silently\*\* deferred'
    ["the header state"]='^[0-9]+\. ✅ The header reads'
  )
  if [[ -z "$zag_closure" ]]; then
    fail "$zag has no gate-opening section — the closure conditions cannot be checked"
  else
    for name in "${!ZAG_CONDITIONS[@]}"; do
      if grep -qEi "${ZAG_CONDITIONS[$name]}" <<<"$zag_closure"; then
        pass "closure condition present: $name"
      else
        fail "$zag lost the closure condition: $name"
      fi
    done
  fi
  # Deferral is only ever valid in the fully-named form; a bare "deferred" state would
  # be the cheapest possible way to make the gate easier to pass.
  if grep -qEi 'Deferred row is valid ONLY in the fully-named form|three (mandatory )?parts' "$zag"; then
    pass "named-deferral requirement intact"
  else
    fail "$zag no longer restricts deferral to the fully-named form"
  fi
  # Delegated authority is bounded: whatever the gate says about it, reserved categories
  # must still escalate to the user.
  if grep -qEi 'reserved' "$zag" && grep -qF 'auto-design.md' "$zag"; then
    pass "delegated authority is bounded and points at its owning document"
  else
    fail "$zag must bound delegated authority and cite auto-design.md as its owner"
  fi
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
