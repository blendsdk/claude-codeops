#!/usr/bin/env bash
#
# telemetry-check.sh — specification-test suite for the telemetry utility.
#
# Drives scripts/codeops-events.sh entirely inside SANDBOX home directories (temp dirs
# standing in for the user's home, so the real ~/.claude is never touched) against the
# fixtures in scripts/fixtures/telemetry-events/. Each SPEC-N check pins one specified
# behavior: envelope auto-fill, strict whole-line refusal of invalid emits, hook-payload
# parsing, kill switches, aggregation (stats/gaps), content hashing, concurrent-append
# integrity, and sandbox containment. It is a specification test: written from the
# specification BEFORE the utility exists, so it is RED until scripts/codeops-events.sh
# lands and GREEN thereafter. A failing check means the utility is wrong, never the check.
#
# It NEVER mutates a committed fixture — fixtures are copied into temp dirs first, and
# every utility invocation runs with an overridden HOME inside the sandbox.
#
# CodeOps Skills Version: 3.18.0
#
# Usage:  ./scripts/telemetry-check.sh
# Exit:   0 = all checks pass (green); non-zero = at least one check failed (red).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

UTILITY="$REPO_ROOT/scripts/codeops-events.sh"
FIXTURES="$REPO_ROOT/scripts/fixtures/telemetry-events"
EVENTS_REL=".claude/codeops-telemetry/events.jsonl"

FAILURES=0

pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
fail() {
  printf '  \033[31mFAIL\033[0m %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}
section() { printf '\n\033[1m%s\033[0m\n' "$1"; }

TMP_DIRS=()
cleanup() {
  for d in "${TMP_DIRS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# Snapshot the REAL home's telemetry file up front — the containment check at the end
# asserts the suite never touched it.
REAL_EVENTS="$HOME/$EVENTS_REL"
real_events_state() { stat -c '%Y %s' "$REAL_EVENTS" 2>/dev/null || echo "absent"; }
REAL_BEFORE="$(real_events_state)"

SANDBOX="$(mktemp -d)"
TMP_DIRS+=("$SANDBOX")

# mk_home — fresh, empty sandbox home; echo its path.
mk_home() {
  local h
  h="$(mktemp -d)"
  TMP_DIRS+=("$h")
  printf '%s\n' "$h"
}

# A work repo named "acme" — emits run from here so the project field is derivable.
WORK_ROOT="$(mktemp -d)"
TMP_DIRS+=("$WORK_ROOT")
WORK="$WORK_ROOT/acme"
mkdir -p "$WORK"
git -C "$WORK" init -q

# run_util <home> <cwd> <args...> — run the utility with a sandbox home and controlled
# environment; sets OUT/ERR/RC. Extra env pairs go via the UTIL_ENV array. The telemetry
# env kill switch is cleared by default so only SPEC-7 exercises it.
UTIL_ENV=()
OUT=""
ERR=""
RC=0
run_util() {
  local home="$1" cwd="$2"
  shift 2
  if [[ ! -x "$UTILITY" ]]; then
    OUT=""
    ERR="utility missing or not executable"
    RC=127
    return
  fi
  OUT="$(cd "$cwd" && env -u CODEOPS_TELEMETRY ${UTIL_ENV[@]+"${UTIL_ENV[@]}"} HOME="$home" "$UTILITY" "$@" 2>"$SANDBOX/stderr.txt")"
  RC=$?
  ERR="$(cat "$SANDBOX/stderr.txt")"
}

count_lines() { if [[ -f "$1" ]]; then wc -l <"$1"; else echo 0; fi; }
jget() { jq -r "$1" <<<"$2" 2>/dev/null; }

# -----------------------------------------------------------------------------
# Utility presence — without it every check below is red (the pre-implementation state).
# -----------------------------------------------------------------------------
section "Utility: scripts/codeops-events.sh present and executable"
if [[ -x "$UTILITY" ]]; then
  pass "utility present and executable"
else
  fail "utility missing or not executable: $UTILITY"
fi

# -----------------------------------------------------------------------------
# SPEC-1 — a valid emit from inside a git repo appends exactly one JSON line with the
# envelope auto-filled: v=1, ts ISO-8601 UTC, codeops = the utility's own version stamp,
# project = repo basename, src defaults to skill; list/object fields land typed.
# -----------------------------------------------------------------------------
section "SPEC-1: valid emit — envelope auto-fill"
h1="$(mk_home)"
run_util "$h1" "$WORK" emit review_run agent=phase-reviewer feature=checkout phase=P1 \
  lenses=security findings_critical=1 findings_major=0 findings_minor=2
ev1="$h1/$EVENTS_REL"
if [[ "$RC" -eq 0 ]]; then pass "emit exited 0"; else fail "emit exited $RC"; fi
if [[ "$(count_lines "$ev1")" == "1" ]]; then
  pass "exactly one line appended"
else
  fail "expected exactly 1 line, found $(count_lines "$ev1")"
fi
line="$(tail -n1 "$ev1" 2>/dev/null || true)"
if jq -e . >/dev/null 2>&1 <<<"$line"; then pass "appended line is valid JSON"; else fail "appended line is not valid JSON"; fi
[[ "$(jget '.v' "$line")" == "1" ]] && pass "v == 1" || fail "v != 1"
ts="$(jget '.ts' "$line")"
if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  pass "ts is ISO-8601 UTC ($ts)"
else
  fail "ts is not ISO-8601 UTC: '$ts'"
fi
if [[ -x "$UTILITY" ]]; then
  util_stamp="$(grep -oE 'CodeOps Skills Version: [0-9.]+' "$UTILITY" | awk '{print $NF}')"
  if [[ -n "$util_stamp" && "$(jget '.codeops' "$line")" == "$util_stamp" ]]; then
    pass "codeops == utility version stamp ($util_stamp)"
  else
    fail "codeops '"$(jget '.codeops' "$line")"' != utility stamp '$util_stamp'"
  fi
else
  fail "codeops stamp not checkable (utility missing)"
fi
[[ "$(jget '.project' "$line")" == "acme" ]] && pass "project == repo basename (acme)" || fail "project != acme"
[[ "$(jget '.src' "$line")" == "skill" ]] && pass "src defaults to skill" || fail "src != skill"
[[ "$(jget '.event' "$line")" == "review_run" ]] && pass "event == review_run" || fail "event != review_run"
[[ "$(jget '.lenses == ["security"]' "$line")" == "true" ]] && pass "lenses stored as a list" || fail "lenses not stored as [\"security\"]"
[[ "$(jget '.findings == {"critical":1,"major":0,"minor":2}' "$line")" == "true" ]] \
  && pass "findings stored as a typed object" || fail "findings object wrong"
[[ "$(jget 'has("session")' "$line")" == "false" ]] && pass "no session field on a skill-side emit" || fail "unexpected session field"

# -----------------------------------------------------------------------------
# SPEC-2 / SPEC-3 / SPEC-4 — strict whole-line refusal: unknown event type, illegal enum
# value, unknown key. Each: nothing appended, one stderr warning, exit 0.
# -----------------------------------------------------------------------------
section "SPEC-2/3/4: invalid emits are refused whole-line"
bad_lines=()
while IFS= read -r bline; do
  [[ -z "$bline" || "$bline" == \#* ]] && continue
  bad_lines+=("$bline")
done <"$FIXTURES/bad-emits.txt"
bad_labels=("SPEC-2 unknown event type" "SPEC-3 illegal enum value" "SPEC-4 unknown key")
for i in 0 1 2; do
  hbad="$(mk_home)"
  read -r -a bargs <<<"${bad_lines[$i]}"
  run_util "$hbad" "$WORK" emit "${bargs[@]}"
  evbad="$hbad/$EVENTS_REL"
  if [[ "$RC" -eq 0 && "$(count_lines "$evbad")" == "0" && -n "$ERR" ]]; then
    pass "${bad_labels[$i]}: refused (nothing appended, warned, exit 0)"
  else
    fail "${bad_labels[$i]}: rc=$RC lines=$(count_lines "$evbad") warn='${ERR:0:60}'"
  fi
done

# -----------------------------------------------------------------------------
# SPEC-5 — hook mode with a Skill-tool payload appends a skill_invoked line carrying
# src=hook, the skill name, and the session id from the payload.
# -----------------------------------------------------------------------------
section "SPEC-5: hook payload (Skill tool) → skill_invoked"
h5="$(mk_home)"
run_util "$h5" "$WORK" emit --src hook --stdin <"$FIXTURES/hook-payloads/skill-invoked.json"
ev5="$h5/$EVENTS_REL"
if [[ "$RC" -eq 0 && "$(count_lines "$ev5")" == "1" ]]; then
  pass "one line appended, exit 0"
else
  fail "rc=$RC lines=$(count_lines "$ev5")"
fi
line="$(tail -n1 "$ev5" 2>/dev/null || true)"
[[ "$(jget '.event' "$line")" == "skill_invoked" ]] && pass "event == skill_invoked" || fail "event != skill_invoked"
[[ "$(jget '.src' "$line")" == "hook" ]] && pass "src == hook" || fail "src != hook"
[[ "$(jget '.skill' "$line")" == "exec_plan" ]] && pass "skill == exec_plan" || fail "skill != exec_plan"
[[ "$(jget '.session' "$line")" == "sess-fixture-01" ]] && pass "session from payload" || fail "session missing/wrong"
[[ "$(jget 'has("duration_s")' "$line")" == "false" ]] && pass "no duration on skill_invoked" || fail "unexpected duration_s"

# -----------------------------------------------------------------------------
# SPEC-6 — subagent-tool payloads → agent_completed. With a first-line dispatch header the
# agent/feature/phase fields are populated and duration_s comes from the payload's elapsed
# milliseconds; without a header the event is still appended with those fields omitted;
# the legacy Task tool name is accepted as an alias.
# -----------------------------------------------------------------------------
section "SPEC-6: hook payloads (subagent tool) → agent_completed"
h6="$(mk_home)"
ev6="$h6/$EVENTS_REL"
run_util "$h6" "$WORK" emit --src hook --stdin <"$FIXTURES/hook-payloads/agent-with-header.json"
rc_a=$RC
run_util "$h6" "$WORK" emit --src hook --stdin <"$FIXTURES/hook-payloads/agent-no-header.json"
rc_b=$RC
run_util "$h6" "$WORK" emit --src hook --stdin <"$FIXTURES/hook-payloads/agent-legacy-task.json"
rc_c=$RC
if [[ "$rc_a" -eq 0 && "$rc_b" -eq 0 && "$rc_c" -eq 0 && "$(count_lines "$ev6")" == "3" ]]; then
  pass "three lines appended, all exit 0"
else
  fail "rc=$rc_a/$rc_b/$rc_c lines=$(count_lines "$ev6")"
fi
l1="$(sed -n 1p "$ev6" 2>/dev/null || true)"
l2="$(sed -n 2p "$ev6" 2>/dev/null || true)"
l3="$(sed -n 3p "$ev6" 2>/dev/null || true)"
if [[ "$(jget '.event' "$l1")" == "agent_completed" && "$(jget '.agent' "$l1")" == "phase-reviewer" \
   && "$(jget '.feature' "$l1")" == "checkout" && "$(jget '.phase' "$l1")" == "P3" ]]; then
  pass "header parsed: agent/feature/phase populated"
else
  fail "header fields wrong: $(jget '{agent,feature,phase}' "$l1")"
fi
[[ "$(jget '.duration_s' "$l1")" == "154" ]] && pass "duration_s == 154 (from milliseconds)" || fail "duration_s != 154: $(jget '.duration_s' "$l1")"
[[ "$(jget '.session' "$l1")" == "sess-fixture-02" ]] && pass "session from payload" || fail "session missing/wrong"
if [[ "$(jget '.event' "$l2")" == "agent_completed" && "$(jget 'has("agent")' "$l2")" == "false" \
   && "$(jget 'has("feature")' "$l2")" == "false" && "$(jget 'has("phase")' "$l2")" == "false" ]]; then
  pass "no header → event kept, agent/feature/phase omitted"
else
  fail "headerless payload mishandled"
fi
[[ "$(jget '.duration_s' "$l2")" == "8" ]] && pass "headerless duration_s == 8" || fail "headerless duration_s wrong"
if [[ "$(jget '.event' "$l3")" == "agent_completed" && "$(jget '.agent' "$l3")" == "security-auditor" \
   && "$(jget '.phase' "$l3")" == "P2" && "$(jget '.duration_s' "$l3")" == "61" ]]; then
  pass "legacy Task tool name accepted as alias"
else
  fail "legacy Task payload mishandled"
fi

# -----------------------------------------------------------------------------
# SPEC-6B — agent attribution comes from the payload's subagent_type, not the prose header.
# A CodeOps dispatch is one whose subagent_type is "codeops:<name>" OR a bare "<name>" that
# matches a file in the plugin's own agents/ directory. Anything else is not a CodeOps dispatch
# and carries no agent field. The header remains the fallback source of agent when subagent_type
# is absent, and the sole source of feature/phase in every case.
# -----------------------------------------------------------------------------
section "SPEC-6B: agent attribution from subagent_type"
h6b="$(mk_home)"
ev6b="$h6b/$EVENTS_REL"
run_util "$h6b" "$WORK" emit --src hook --stdin <"$FIXTURES/hook-payloads/agent-bare-name.json"
rc_d=$RC
run_util "$h6b" "$WORK" emit --src hook --stdin <"$FIXTURES/hook-payloads/agent-unknown-type.json"
rc_e=$RC
run_util "$h6b" "$WORK" emit --src hook --stdin <"$FIXTURES/hook-payloads/agent-no-subagent-type.json"
rc_f=$RC
run_util "$h6b" "$WORK" emit --src hook --stdin <"$FIXTURES/hook-payloads/agent-conflict.json"
rc_g=$RC
if [[ "$rc_d" -eq 0 && "$rc_e" -eq 0 && "$rc_f" -eq 0 && "$rc_g" -eq 0 && "$(count_lines "$ev6b")" == "4" ]]; then
  pass "four lines appended, all exit 0"
else
  fail "rc=$rc_d/$rc_e/$rc_f/$rc_g lines=$(count_lines "$ev6b")"
fi
m1="$(sed -n 1p "$ev6b" 2>/dev/null || true)"
m2="$(sed -n 2p "$ev6b" 2>/dev/null || true)"
m3="$(sed -n 3p "$ev6b" 2>/dev/null || true)"
m4="$(sed -n 4p "$ev6b" 2>/dev/null || true)"

# A bare name matching agents/codebase-scout.md is a CodeOps dispatch even with no header at all.
if [[ "$(jget '.event' "$m1")" == "agent_completed" && "$(jget '.agent' "$m1")" == "codebase-scout" ]]; then
  pass "bare subagent_type matching agents/ → attributed"
else
  fail "bare name not attributed: $(jget '.agent' "$m1")"
fi
# No header on that payload, so feature/phase stay absent — attribution must not invent them.
if [[ "$(jget 'has("feature")' "$m1")" == "false" && "$(jget 'has("phase")' "$m1")" == "false" ]]; then
  pass "bare name without header → feature/phase omitted"
else
  fail "feature/phase invented: $(jget '{feature,phase}' "$m1")"
fi
# general-purpose is not a CodeOps agent; the event is kept but must carry no agent field,
# otherwise ordinary agent use pollutes per-agent stats.
if [[ "$(jget '.event' "$m2")" == "agent_completed" && "$(jget 'has("agent")' "$m2")" == "false" ]]; then
  pass "unknown subagent_type → event kept, agent omitted"
else
  fail "non-CodeOps agent attributed: $(jget '.agent' "$m2")"
fi
# Absent subagent_type falls back to the header, so no dispatch that works today regresses.
if [[ "$(jget '.agent' "$m3")" == "perf-auditor" && "$(jget '.feature' "$m3")" == "billing" \
   && "$(jget '.phase' "$m3")" == "P7" ]]; then
  pass "no subagent_type → header fallback populates agent/feature/phase"
else
  fail "header fallback failed: $(jget '{agent,feature,phase}' "$m3")"
fi
# When the two disagree the payload wins: subagent_type is what the tool actually ran,
# the header is prose that can go stale.
if [[ "$(jget '.agent' "$m4")" == "security-auditor" ]]; then
  pass "subagent_type wins over a conflicting header agent"
else
  fail "conflict resolved wrongly: $(jget '.agent' "$m4")"
fi
# feature/phase still come from the header even when its agent field was overridden.
if [[ "$(jget '.feature' "$m4")" == "checkout" && "$(jget '.phase' "$m4")" == "P4" ]]; then
  pass "header still owns feature/phase on conflict"
else
  fail "feature/phase lost on conflict: $(jget '{feature,phase}' "$m4")"
fi

# -----------------------------------------------------------------------------
# SPEC-7 — the environment kill switch: a valid emit with the telemetry env var set to 0
# is a silent no-op (nothing written, exit 0).
# -----------------------------------------------------------------------------
section "SPEC-7: env kill switch"
h7="$(mk_home)"
UTIL_ENV=(CODEOPS_TELEMETRY=0)
run_util "$h7" "$WORK" emit skill_invoked skill=exec_plan
UTIL_ENV=()
if [[ "$RC" -eq 0 && ! -e "$h7/$EVENTS_REL" ]]; then
  pass "env kill switch → no-op, exit 0"
else
  fail "rc=$RC file_exists=$([[ -e "$h7/$EVENTS_REL" ]] && echo yes || echo no)"
fi

# -----------------------------------------------------------------------------
# SPEC-8 — the per-repo kill switch: an emit from a repo whose CLAUDE.md quality block
# turns telemetry off is a no-op (exit 0).
# -----------------------------------------------------------------------------
section "SPEC-8: per-repo kill switch (quality block)"
h8="$(mk_home)"
fake_root="$(mktemp -d)"
TMP_DIRS+=("$fake_root")
cp -R "$FIXTURES/fake-repo/." "$fake_root/"
git -C "$fake_root" init -q
run_util "$h8" "$fake_root" emit skill_invoked skill=exec_plan
if [[ "$RC" -eq 0 && ! -e "$h8/$EVENTS_REL" ]]; then
  pass "repo kill switch → no-op, exit 0"
else
  fail "rc=$RC file_exists=$([[ -e "$h8/$EVENTS_REL" ]] && echo yes || echo no)"
fi

# -----------------------------------------------------------------------------
# SPEC-9 — jq absent from PATH: a valid emit becomes a no-op with exactly one stderr note.
# A restricted PATH is built from symlinks to everything except jq.
# -----------------------------------------------------------------------------
section "SPEC-9: jq absent → no-op with one stderr note"
NOJQ="$SANDBOX/nojq-bin"
if [[ ! -d "$NOJQ" ]]; then
  mkdir -p "$NOJQ"
  IFS=: read -r -a path_dirs <<<"$PATH"
  for d in "${path_dirs[@]}"; do
    [[ -d "$d" ]] || continue
    for b in "$d"/*; do
      n="$(basename "$b")"
      [[ "$n" == "jq" ]] && continue
      [[ -e "$NOJQ/$n" ]] || ln -s "$b" "$NOJQ/$n" 2>/dev/null
    done
  done
fi
h9="$(mk_home)"
UTIL_ENV=(PATH="$NOJQ")
run_util "$h9" "$WORK" emit skill_invoked skill=exec_plan
UTIL_ENV=()
if [[ "$RC" -eq 0 && ! -e "$h9/$EVENTS_REL" ]]; then
  pass "no jq → no-op, exit 0"
else
  fail "rc=$RC file_exists=$([[ -e "$h9/$EVENTS_REL" ]] && echo yes || echo no)"
fi
if [[ "$RC" -eq 0 && "$(printf '%s' "$ERR" | grep -c .)" == "1" ]]; then
  pass "exactly one stderr note"
else
  fail "stderr note count wrong: '${ERR:0:80}'"
fi

# -----------------------------------------------------------------------------
# SPEC-10 — stats --by agent over the fixture events: correct per-agent counts, average
# duration, and acceptance rate (accepted / ruled, deferred excluded), within 40 lines.
# The fixture holds 4 phase-reviewer completions (durations 42/38/51/45 → avg 44) and
# 4 rulings (2 accepted, 1 rejected, 1 deferred → 2/3 = 67%), plus 1 scout completion.
# -----------------------------------------------------------------------------
section "SPEC-10: stats --by agent over fixture events"
h10="$(mk_home)"
mkdir -p "$h10/.claude/codeops-telemetry"
cp "$FIXTURES/valid-events.jsonl" "$h10/$EVENTS_REL"
run_util "$h10" "$WORK" stats --by agent
if [[ "$RC" -eq 0 ]]; then pass "stats exited 0"; else fail "stats exited $RC"; fi
if [[ -n "$OUT" && "$(printf '%s\n' "$OUT" | wc -l)" -le 40 ]]; then
  pass "output within 40 lines"
else
  fail "output empty or over 40 lines"
fi
rev_row="$(printf '%s\n' "$OUT" | grep 'phase-reviewer' || true)"
scout_row="$(printf '%s\n' "$OUT" | grep 'codebase-scout' || true)"
if [[ -n "$rev_row" ]] && grep -qw 4 <<<"$rev_row" && grep -qw 44 <<<"$rev_row" && grep -q '67%' <<<"$rev_row"; then
  pass "phase-reviewer row: 4 runs, avg 44s, 67% acceptance"
else
  fail "phase-reviewer row wrong: '${rev_row:-<missing>}'"
fi
if [[ -n "$scout_row" ]] && grep -qw 1 <<<"$scout_row"; then
  pass "codebase-scout row: 1 run"
else
  fail "codebase-scout row wrong: '${scout_row:-<missing>}'"
fi

# -----------------------------------------------------------------------------
# SPEC-11 — gaps over the fixture events: 4 reviewer/auditor completions, 3 with a
# downstream ruling in the same project+feature+phase → a 25% gap rate. The scout
# completion must not count toward the denominator.
# -----------------------------------------------------------------------------
section "SPEC-11: gaps over fixture events → 25%"
run_util "$h10" "$WORK" gaps
if [[ "$RC" -eq 0 ]]; then pass "gaps exited 0"; else fail "gaps exited $RC"; fi
if grep -q '25%' <<<"$OUT"; then
  pass "reports a 25% gap rate"
else
  fail "expected 25% in: '${OUT:0:120}'"
fi

# -----------------------------------------------------------------------------
# SPEC-12 — content hashing: the utility computes the hash itself from --hash-text,
# stores the first 8 hex of the digest, and the raw text lands nowhere in the file.
# -----------------------------------------------------------------------------
section "SPEC-12: --hash-text stores an 8-hex hash, never the text"
h12="$(mk_home)"
secret="SQL injection in login"
run_util "$h12" "$WORK" emit finding_decided agent=phase-reviewer feature=checkout phase=P1 \
  severity=major lens=security decision=accepted fix_applied=true --hash-text "$secret"
ev12="$h12/$EVENTS_REL"
if [[ "$RC" -eq 0 && "$(count_lines "$ev12")" == "1" ]]; then
  pass "emit accepted, one line"
else
  fail "rc=$RC lines=$(count_lines "$ev12")"
fi
line="$(tail -n1 "$ev12" 2>/dev/null || true)"
want_hash="$(printf '%s' "$secret" | sha256sum | awk '{print $1}' | cut -c1-8)"
got_hash="$(jget '.hash' "$line")"
if [[ "$got_hash" == "$want_hash" ]]; then
  pass "hash == first 8 hex of the digest ($want_hash)"
else
  fail "hash '$got_hash' != expected '$want_hash'"
fi
if [[ -f "$ev12" ]] && ! grep -qF "$secret" "$ev12"; then
  pass "raw text appears nowhere in the events file"
else
  fail "raw text leaked into the events file (or file missing)"
fi

# -----------------------------------------------------------------------------
# SPEC-13 — 50 concurrent emits land as 50 intact, parseable JSON lines (no interleaving).
# -----------------------------------------------------------------------------
section "SPEC-13: 50 concurrent emits — no interleaving"
h13="$(mk_home)"
ev13="$h13/$EVENTS_REL"
if [[ -x "$UTILITY" ]]; then
  for i in $(seq 1 50); do
    (cd "$WORK" && env -u CODEOPS_TELEMETRY HOME="$h13" "$UTILITY" emit task_completed \
      feature=checkout phase=P1 task="1.1.$i" verify=pass attempts=1 files_changed=1) >/dev/null 2>&1 &
  done
  wait
fi
if [[ "$(count_lines "$ev13")" == "50" ]]; then
  pass "50 lines present"
else
  fail "expected 50 lines, found $(count_lines "$ev13")"
fi
if [[ -f "$ev13" ]] && jq -e . "$ev13" >/dev/null 2>&1; then
  pass "every line parses as JSON (no interleaving)"
else
  fail "at least one corrupt/interleaved line"
fi

# -----------------------------------------------------------------------------
# SPEC-14 — the timestamp always comes from the system clock: a ts= argument is an
# unknown key (whole-line refusal), and an accepted emit carries a current ISO timestamp.
# -----------------------------------------------------------------------------
section "SPEC-14: ts is clock-derived, never caller-supplied"
h14="$(mk_home)"
run_util "$h14" "$WORK" emit phase_started feature=checkout phase=P1 tag=standard mode=inline \
  ts=2020-01-01T00:00:00Z
if [[ "$RC" -eq 0 && "$(count_lines "$h14/$EVENTS_REL")" == "0" && -n "$ERR" ]]; then
  pass "ts= argument refused as an unknown key"
else
  fail "ts= argument was not refused (rc=$RC lines=$(count_lines "$h14/$EVENTS_REL"))"
fi
run_util "$h14" "$WORK" emit phase_started feature=checkout phase=P1 tag=standard mode=inline
line="$(tail -n1 "$h14/$EVENTS_REL" 2>/dev/null || true)"
ts="$(jget '.ts' "$line")"
today="$(date -u +%Y-%m-%d)"
yesterday="$(date -u -d yesterday +%Y-%m-%d 2>/dev/null || echo "$today")"
if [[ "$ts" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] \
   && { [[ "$ts" == "$today"* ]] || [[ "$ts" == "$yesterday"* ]]; }; then
  pass "accepted emit carries a current clock timestamp ($ts)"
else
  fail "timestamp not current/ISO: '$ts'"
fi

# -----------------------------------------------------------------------------
# SPEC-15 — malformed hook stdin: warn, refuse, exit 0.
# -----------------------------------------------------------------------------
section "SPEC-15: malformed hook stdin refused"
h15="$(mk_home)"
run_util "$h15" "$WORK" emit --src hook --stdin <"$FIXTURES/hook-payloads/malformed.json"
if [[ "$RC" -eq 0 && "$(count_lines "$h15/$EVENTS_REL")" == "0" && -n "$ERR" ]]; then
  pass "malformed stdin → warn, refuse, exit 0"
else
  fail "rc=$RC lines=$(count_lines "$h15/$EVENTS_REL") warn='${ERR:0:60}'"
fi

# =============================================================================
# Edge cases (implementation tests — internals + boundaries, written after green).
# =============================================================================

# -----------------------------------------------------------------------------
# Edge: stats over an empty or absent events file → friendly notice, exit 0.
# -----------------------------------------------------------------------------
section "Edge: stats with empty/absent events file"
he="$(mk_home)"
run_util "$he" "$WORK" stats
if [[ "$RC" -eq 0 ]] && grep -qi 'no events' <<<"$OUT"; then
  pass "absent file → 'no events' notice, exit 0"
else
  fail "absent file mishandled (rc=$RC out='${OUT:0:60}')"
fi
mkdir -p "$he/.claude/codeops-telemetry"
: >"$he/$EVENTS_REL"
run_util "$he" "$WORK" stats --by agent
if [[ "$RC" -eq 0 ]] && grep -qi 'no events' <<<"$OUT"; then
  pass "empty file → 'no events' notice, exit 0"
else
  fail "empty file mishandled (rc=$RC out='${OUT:0:60}')"
fi

# -----------------------------------------------------------------------------
# Edge: --since window filtering and refusal of an unusable --since value.
# -----------------------------------------------------------------------------
section "Edge: --since parsing"
hs="$(mk_home)"
mkdir -p "$hs/.claude/codeops-telemetry"
printf '{"v":1,"ts":"2000-01-01T00:00:00Z","codeops":"0.0.0","project":"acme","src":"hook","event":"skill_invoked","skill":"exec_plan"}\n' >"$hs/$EVENTS_REL"
run_util "$hs" "$WORK" emit task_completed feature=checkout phase=P1 task=1.1.1 verify=pass attempts=1 files_changed=1
run_util "$hs" "$WORK" stats --since 7d --by event
if [[ "$RC" -eq 0 ]] && grep -q 'task_completed' <<<"$OUT" && ! grep -q 'skill_invoked' <<<"$OUT"; then
  pass "--since 7d keeps the fresh event, drops the ancient one"
else
  fail "--since window filtering wrong (rc=$RC out='${OUT:0:80}')"
fi
run_util "$hs" "$WORK" stats --since banana
if [[ "$RC" -eq 0 && -z "$OUT" && -n "$ERR" ]]; then
  pass "unusable --since value → warn, no table, exit 0"
else
  fail "unusable --since value mishandled (rc=$RC)"
fi

# -----------------------------------------------------------------------------
# Edge: an oversized corrupt line in the events file is skipped, never fatal.
# -----------------------------------------------------------------------------
section "Edge: oversized corrupt line skipped by readers"
hb="$(mk_home)"
mkdir -p "$hb/.claude/codeops-telemetry"
{
  printf '{"v":1,"ts":"2026-07-18T09:00:00Z","codeops":"0.0.0","project":"acme","src":"skill","event":"phase_started","feature":"checkout","phase":"P1","tag":"standard","mode":"inline"}\n'
  head -c 100000 /dev/zero | tr '\0' 'x'
  printf '\n'
  printf '{"v":1,"ts":"2026-07-18T09:10:00Z","codeops":"0.0.0","project":"acme","src":"skill","event":"phase_completed","feature":"checkout","phase":"P1","tag":"standard","mode":"inline"}\n'
} >"$hb/$EVENTS_REL"
run_util "$hb" "$WORK" stats --by event
if [[ "$RC" -eq 0 ]] && grep -q 'phase_started' <<<"$OUT" && grep -q 'phase_completed' <<<"$OUT"; then
  pass "both valid events aggregated around a 100KB garbage line"
else
  fail "oversized corrupt line broke stats (rc=$RC out='${OUT:0:80}')"
fi

# -----------------------------------------------------------------------------
# Edge: emit from outside any git repository → project recorded as unknown.
# -----------------------------------------------------------------------------
section "Edge: emit outside a git repo → project=unknown"
hn="$(mk_home)"
nogit="$(mktemp -d)"
TMP_DIRS+=("$nogit")
run_util "$hn" "$nogit" emit skill_invoked skill=exec_plan
line="$(tail -n1 "$hn/$EVENTS_REL" 2>/dev/null || true)"
if [[ "$RC" -eq 0 && "$(jget '.project' "$line")" == "unknown" ]]; then
  pass "non-repo emit accepted with project=unknown"
else
  fail "non-repo emit mishandled (rc=$RC project='$(jget '.project' "$line")')"
fi

# -----------------------------------------------------------------------------
# SPEC-17 — the specialist auditors are visible to telemetry by name, and their
# completions are subject to the gap report.
#
# Attribution alone is not enough: an agent that produces findings but sits outside
# the reviewer roster is never asked whether its findings were ruled on, which reads
# in the report as an agent with nothing outstanding rather than one nobody checked.
# -----------------------------------------------------------------------------
section "SPEC-17: specialist auditors are attributed and gap-checked"
h17="$(mk_home)"
ev17="$h17/$EVENTS_REL"
spec17_ok=1
for agent in concurrency-auditor financial-integrity-auditor semantics-reviewer; do
  payload="$SANDBOX/hook-$agent.json"
  jq -n --arg a "$agent" '{
    hook_event_name: "PostToolUse",
    tool_name: "Agent",
    tool_input: {description: "Audit the phase", prompt: "Audit exactly this packet.", subagent_type: ("codeops:" + $a)},
    duration: {elapsed_milliseconds: 9000}
  }' > "$payload"
  run_util "$h17" "$WORK" emit --src hook --stdin <"$payload"
  [[ "$RC" -eq 0 ]] || { fail "$agent emit exited $RC"; spec17_ok=0; }
done
if [[ "$(count_lines "$ev17")" == "3" ]]; then
  pass "three specialist completions recorded"
else
  fail "expected 3 lines, got $(count_lines "$ev17")"
  spec17_ok=0
fi
for n in 1 2 3; do
  line="$(sed -n "${n}p" "$ev17" 2>/dev/null || true)"
  name="$(jget '.agent' "$line")"
  case "$name" in
    concurrency-auditor|financial-integrity-auditor|semantics-reviewer)
      pass "attributed by name: $name" ;;
    *)
      fail "line $n attributed as '${name:-<none>}'"
      spec17_ok=0 ;;
  esac
done
# No review_run or finding_decided follows any of them, so every completion is a gap.
run_util "$h17" "$WORK" gaps
if [[ "$RC" -eq 0 ]] && grep -q 'completions: *3' <<<"$OUT" && grep -q '100%' <<<"$OUT"; then
  pass "all three count as reviewer completions in the gap report"
else
  fail "specialists missing from the reviewer roster: '${OUT:0:160}'"
  spec17_ok=0
fi
[[ "$spec17_ok" -eq 1 ]] && pass "specialist telemetry surface complete"

# -----------------------------------------------------------------------------
# SPEC-18 — the measure-taxonomy event types are in the catalog and land typed.
#
# Four types and two keys, each closing one audited measure. Every field is an int, a
# bool, or a closed enum: the taxonomy exists to count outcomes, and an outcome that
# needs prose to describe it is not collected at all.
# -----------------------------------------------------------------------------
section "SPEC-18: measure-taxonomy types accepted and typed"
h18="$(mk_home)"
ev18="$h18/$EVENTS_REL"

run_util "$h18" "$WORK" emit spec_test_cycle feature=checkout phase=P1 \
  authored=6 red_confirmed=6 post_impl_failures=1
line="$(tail -n1 "$ev18" 2>/dev/null || true)"
if [[ "$RC" -eq 0 && "$(jget '.event' "$line")" == "spec_test_cycle" \
      && "$(jget '.authored' "$line")" == "6" && "$(jget '.authored|type' "$line")" == "number" \
      && "$(jget '.post_impl_failures' "$line")" == "1" ]]; then
  pass "spec_test_cycle accepted with integer counters"
else
  fail "spec_test_cycle not accepted as specified (rc=$RC line='${line:0:120}')"
fi

run_util "$h18" "$WORK" emit runtime_ambiguity feature=checkout phase=P1 \
  owner=plan kind=assumption_invalidated
line="$(tail -n1 "$ev18" 2>/dev/null || true)"
if [[ "$RC" -eq 0 && "$(jget '.event' "$line")" == "runtime_ambiguity" \
      && "$(jget '.owner' "$line")" == "plan" \
      && "$(jget '.kind' "$line")" == "assumption_invalidated" ]]; then
  pass "runtime_ambiguity accepted with owning stage and kind"
else
  fail "runtime_ambiguity not accepted as specified (rc=$RC line='${line:0:120}')"
fi

run_util "$h18" "$WORK" emit session_resumed feature=checkout phase=P1 \
  resume_point=in_progress_task marks_corrected=true
line="$(tail -n1 "$ev18" 2>/dev/null || true)"
if [[ "$RC" -eq 0 && "$(jget '.event' "$line")" == "session_resumed" \
      && "$(jget '.resume_point' "$line")" == "in_progress_task" \
      && "$(jget '.marks_corrected' "$line")" == "true" \
      && "$(jget '.marks_corrected|type' "$line")" == "boolean" ]]; then
  pass "session_resumed accepted with a boolean correction flag"
else
  fail "session_resumed not accepted as specified (rc=$RC line='${line:0:120}')"
fi

run_util "$h18" "$WORK" emit design_delegated feature=checkout phase=P1 \
  class=failure_recovery outcome=resolved confidence=high challenged=true
line="$(tail -n1 "$ev18" 2>/dev/null || true)"
if [[ "$RC" -eq 0 && "$(jget '.event' "$line")" == "design_delegated" \
      && "$(jget '.class' "$line")" == "failure_recovery" \
      && "$(jget '.outcome' "$line")" == "resolved" \
      && "$(jget '.confidence' "$line")" == "high" ]]; then
  pass "design_delegated accepted with class, outcome and confidence"
else
  fail "design_delegated not accepted as specified (rc=$RC line='${line:0:120}')"
fi

# A reserved-authority escalation carries no class — the choice was never in an eligible
# one, and inventing a class to fill the field would misreport why it escalated.
run_util "$h18" "$WORK" emit design_delegated feature=checkout phase=P1 \
  outcome=escalated_reserved confidence=med challenged=false
line="$(tail -n1 "$ev18" 2>/dev/null || true)"
if [[ "$RC" -eq 0 && "$(jget '.outcome' "$line")" == "escalated_reserved" \
      && "$(jget '.class' "$line")" == "null" ]]; then
  pass "reserved escalation accepted without a class"
else
  fail "reserved escalation mishandled (rc=$RC line='${line:0:120}')"
fi

run_util "$h18" "$WORK" emit phase_started feature=checkout phase=P1 tag=standard \
  mode=inline tasks_planned=12
line="$(tail -n1 "$ev18" 2>/dev/null || true)"
if [[ "$RC" -eq 0 && "$(jget '.tasks_planned' "$line")" == "12" \
      && "$(jget '.tasks_planned|type' "$line")" == "number" ]]; then
  pass "phase_started carries a planned-task count"
else
  fail "tasks_planned not accepted on phase_started (rc=$RC line='${line:0:120}')"
fi

run_util "$h18" "$WORK" emit review_run agent=phase-reviewer feature=checkout phase=P1 \
  lenses=correctness round=rereview findings_critical=0 findings_major=0 findings_minor=1
line="$(tail -n1 "$ev18" 2>/dev/null || true)"
if [[ "$RC" -eq 0 && "$(jget '.round' "$line")" == "rereview" ]]; then
  pass "review_run distinguishes a re-review from the initial pass"
else
  fail "round not accepted on review_run (rc=$RC line='${line:0:120}')"
fi

# -----------------------------------------------------------------------------
# SPEC-19 (ST-6.2) — content-bearing payloads are refused whole-line.
#
# Each case is a PAIR: the same event with a legal enumerated value must land, and with
# free text, a path, or an identifier in that same field must be refused. The pair is
# what makes the check meaningful — a refusal on its own is also what an unimplemented
# event type produces, so a lone rejection assertion would pass before the feature
# exists and prove nothing.
# -----------------------------------------------------------------------------
section "SPEC-19: content-bearing payloads refused (ST-6.2)"
h19="$(mk_home)"
ev19="$h19/$EVENTS_REL"

# refuses_but_accepts <label> <legal-args...> -- <hostile-args...>
refuses_but_accepts() {
  local label="$1"; shift
  local -a legal=() hostile=()
  local seen=0 a
  for a in "$@"; do
    if [[ "$a" == "--" ]]; then seen=1; continue; fi
    if [[ "$seen" -eq 0 ]]; then legal+=("$a"); else hostile+=("$a"); fi
  done
  local before after
  before="$(count_lines "$ev19")"
  run_util "$h19" "$WORK" emit "${legal[@]}"
  after="$(count_lines "$ev19")"
  if [[ "$RC" -ne 0 || "$after" != "$((before + 1))" ]]; then
    fail "$label: the legal form was not accepted (rc=$RC ${before}→${after})"
    return
  fi
  before="$after"
  run_util "$h19" "$WORK" emit "${hostile[@]}"
  after="$(count_lines "$ev19")"
  if [[ "$RC" -eq 0 && "$after" == "$before" && -n "$ERR" ]]; then
    pass "$label"
  else
    fail "$label: hostile form not refused (rc=$RC ${before}→${after} warn='${ERR:0:60}')"
  fi
}

refuses_but_accepts "free text in runtime_ambiguity.owner" \
  runtime_ambiguity feature=checkout phase=P1 owner=plan kind=unspecified_detail \
  -- runtime_ambiguity feature=checkout phase=P1 owner="the plan never said" kind=unspecified_detail
refuses_but_accepts "a file path in runtime_ambiguity.kind" \
  runtime_ambiguity feature=checkout phase=P1 owner=spec_tests kind=conflicting_spec \
  -- runtime_ambiguity feature=checkout phase=P1 owner=spec_tests kind=src/auth/login.ts
refuses_but_accepts "a path in design_delegated.class" \
  design_delegated feature=checkout phase=P1 class=concurrency outcome=resolved confidence=low challenged=false \
  -- design_delegated feature=checkout phase=P1 class=/etc/passwd outcome=resolved confidence=low challenged=false
refuses_but_accepts "an unknown key carrying decision prose" \
  design_delegated feature=checkout phase=P1 class=persistence outcome=resolved confidence=high challenged=true \
  -- design_delegated feature=checkout phase=P1 class=persistence outcome=resolved confidence=high challenged=true rationale=chose-b
refuses_but_accepts "traversal in session_resumed.resume_point" \
  session_resumed feature=checkout phase=P1 resume_point=next_task marks_corrected=false \
  -- session_resumed feature=checkout phase=P1 resume_point=../../etc marks_corrected=false
refuses_but_accepts "a non-integer spec_test_cycle counter" \
  spec_test_cycle feature=checkout phase=P1 authored=4 red_confirmed=4 post_impl_failures=0 \
  -- spec_test_cycle feature=checkout phase=P1 authored=three red_confirmed=4 post_impl_failures=0
refuses_but_accepts "an out-of-enum review round" \
  review_run agent=phase-reviewer feature=checkout phase=P1 lenses=correctness round=initial \
    findings_critical=0 findings_major=0 findings_minor=0 \
  -- review_run agent=phase-reviewer feature=checkout phase=P1 lenses=correctness round=third-pass \
    findings_critical=0 findings_major=0 findings_minor=0

# The hash channel is the one place free text is legitimately handed to the utility, so
# the new types must not open it: none of them takes a hash, and asking for one refuses
# the line rather than quietly hashing prose into a measure event.
for t in spec_test_cycle runtime_ambiguity session_resumed design_delegated; do
  before="$(count_lines "$ev19")"
  run_util "$h19" "$WORK" emit "$t" feature=checkout phase=P1 --hash-text "the user said the retry budget should be three"
  if [[ "$RC" -eq 0 && "$(count_lines "$ev19")" == "$before" && -n "$ERR" ]]; then
    pass "$t refuses --hash-text"
  else
    fail "$t accepted a hash channel (rc=$RC warn='${ERR:0:60}')"
  fi
done

# -----------------------------------------------------------------------------
# SPEC-20 (ST-6.3) — `telemetry: off` silences every new type.
#
# Paired for the same reason as SPEC-19: each type is first shown to land in a normal
# home, so the silence in the opted-out repo is the kill switch working rather than the
# type not existing.
# -----------------------------------------------------------------------------
section "SPEC-20: telemetry: off silences every new type (ST-6.3)"
h20a="$(mk_home)"
h20b="$(mk_home)"
off_root="$(mktemp -d)"
TMP_DIRS+=("$off_root")
cp -R "$FIXTURES/fake-repo/." "$off_root/"
git -C "$off_root" init -q
for spec in \
  "spec_test_cycle feature=checkout phase=P1 authored=1 red_confirmed=1 post_impl_failures=0" \
  "runtime_ambiguity feature=checkout phase=P1 owner=execution kind=unspecified_detail" \
  "session_resumed feature=checkout phase=P1 resume_point=plan_complete marks_corrected=false" \
  "design_delegated feature=checkout phase=P1 class=algorithms outcome=resolved confidence=high challenged=false"
do
  read -r -a argv <<<"$spec"
  run_util "$h20a" "$WORK" emit "${argv[@]}"
  landed_on="$RC:$(count_lines "$h20a/$EVENTS_REL")"
  run_util "$h20b" "$off_root" emit "${argv[@]}"
  if [[ "${landed_on%%:*}" -eq 0 && "${landed_on##*:}" -gt 0 \
        && "$RC" -eq 0 && ! -e "$h20b/$EVENTS_REL" ]]; then
    pass "${argv[0]}: recorded normally, silent under telemetry: off"
  else
    fail "${argv[0]}: on='$landed_on' off_rc=$RC off_file=$([[ -e "$h20b/$EVENTS_REL" ]] && echo present || echo absent)"
  fi
done

# -----------------------------------------------------------------------------
# SPEC-21 (ST-6.4) — event files written before the taxonomy still parse.
#
# A regression guard, and green on both sides of this change by design: it exists to
# catch a reader that starts assuming a key older data cannot have. The committed
# fixture predates every type above, so it is exactly the shape a user's file has.
# -----------------------------------------------------------------------------
section "SPEC-21: pre-taxonomy events.jsonl still parses (ST-6.4)"
h21="$(mk_home)"
mkdir -p "$h21/.claude/codeops-telemetry"
cp "$FIXTURES/valid-events.jsonl" "$h21/$EVENTS_REL"
spec21_ok=1
for view in "stats" "stats --by agent" "stats --by lens" "stats --by event" "stats --by project" "gaps"; do
  read -r -a argv <<<"$view"
  run_util "$h21" "$WORK" "${argv[@]}"
  if [[ "$RC" -ne 0 || -z "$OUT" ]] || grep -qi 'error\|null' <<<"$OUT"; then
    fail "'$view' broke on pre-taxonomy data (rc=$RC out='${OUT:0:80}')"
    spec21_ok=0
  fi
done
[[ "$spec21_ok" -eq 1 ]] && pass "every reader handles a pre-taxonomy file unchanged"

# Old and new lines side by side: the readers must aggregate across the boundary rather
# than choke on rows that lack the newer keys.
run_util "$h21" "$WORK" emit runtime_ambiguity feature=checkout phase=P1 owner=requirements kind=conflicting_spec
run_util "$h21" "$WORK" emit design_delegated feature=checkout phase=P1 class=testing_strategy outcome=resolved confidence=med challenged=false
run_util "$h21" "$WORK" stats --by event
if [[ "$RC" -eq 0 ]] && grep -q 'runtime_ambiguity' <<<"$OUT" && grep -q 'review_run' <<<"$OUT"; then
  pass "mixed old/new file aggregates across the version boundary"
else
  fail "mixed file aggregation wrong (rc=$RC out='${OUT:0:120}')"
fi

# -----------------------------------------------------------------------------
# SPEC-22 (ST-6.5) — an emit that genuinely fails never blocks the workflow step.
#
# HOME is a regular file, so the events directory cannot be created for any user, root
# included. The utility must warn about THAT and still exit 0, letting both a sequenced
# and an `&&`-chained caller continue. The warning text is asserted because a refusal
# for some earlier reason — an unknown event type, say — would also exit 0 and would
# make this check pass without ever reaching the write.
# -----------------------------------------------------------------------------
section "SPEC-22: a failing emit never blocks the workflow step (ST-6.5)"
blocked_home="$SANDBOX/home-is-a-file"
: >"$blocked_home"
step_out="$(cd "$WORK" && env -u CODEOPS_TELEMETRY HOME="$blocked_home" \
  "$UTILITY" emit design_delegated feature=checkout phase=P1 class=performance \
  outcome=resolved confidence=high challenged=false 2>"$SANDBOX/blocked-err.txt" \
  && printf 'CHAINED\n'; printf 'STEP-DONE\n')"
blocked_err="$(cat "$SANDBOX/blocked-err.txt")"
if grep -q 'CHAINED' <<<"$step_out" && grep -q 'STEP-DONE' <<<"$step_out"; then
  pass "the workflow step continues, sequenced and && -chained"
else
  fail "a failed emit blocked the step (out='${step_out:0:80}')"
fi
if [[ -n "$blocked_err" ]] && ! grep -qi 'unknown event' <<<"$blocked_err"; then
  pass "the warning names the write failure, not an unrecognized event"
else
  fail "wrong failure reached: '${blocked_err:0:100}'"
fi

# -----------------------------------------------------------------------------
# SPEC-23 (R7.7) — the new measures reach a reader.
#
# A measure that lands in the file and reaches no aggregation answers no question, which
# under the taxonomy's own rule is indistinguishable from one that was never collected.
# The arithmetic is asserted, not just the presence of a table: the rates are what a
# retro threshold fires on.
# -----------------------------------------------------------------------------
section "SPEC-23: new measures reach a reader with correct arithmetic"
h23="$(mk_home)"
run_util "$h23" "$WORK" emit phase_started feature=checkout phase=P1 tag=standard mode=inline tasks_planned=10
run_util "$h23" "$WORK" emit task_completed feature=checkout phase=P1 task=1.1 verify=pass attempts=1 files_changed=2
run_util "$h23" "$WORK" emit task_completed feature=checkout phase=P1 task=1.2 verify=pass attempts=3 files_changed=1
run_util "$h23" "$WORK" emit spec_test_cycle feature=checkout phase=P1 authored=6 red_confirmed=6 post_impl_failures=1
run_util "$h23" "$WORK" emit review_run agent=phase-reviewer feature=checkout phase=P1 \
  lenses=correctness round=initial findings_critical=0 findings_major=1 findings_minor=0
run_util "$h23" "$WORK" emit review_run agent=phase-reviewer feature=checkout phase=P1 \
  lenses=correctness round=rereview findings_critical=0 findings_major=0 findings_minor=0
run_util "$h23" "$WORK" emit runtime_ambiguity feature=checkout phase=P1 owner=plan kind=assumption_invalidated
run_util "$h23" "$WORK" emit runtime_ambiguity feature=checkout phase=P1 owner=requirements kind=unspecified_detail
run_util "$h23" "$WORK" emit session_resumed feature=checkout phase=P1 resume_point=in_progress_task marks_corrected=true
run_util "$h23" "$WORK" emit design_delegated feature=checkout phase=P1 class=failure_recovery outcome=resolved confidence=high challenged=true
run_util "$h23" "$WORK" emit design_delegated feature=checkout phase=P1 class=concurrency outcome=resolved confidence=low challenged=false
run_util "$h23" "$WORK" emit design_delegated feature=checkout phase=P1 outcome=escalated_reserved confidence=med challenged=false

# 2 tasks, one at attempts=1 → 50% first-pass; 1 of 6 spec tests failed after implementation.
run_util "$h23" "$WORK" stats --by delivery
row="$(grep 'first-pass verify' <<<"$OUT" || true)"
if [[ "$RC" -eq 0 ]] && grep -q '50%' <<<"$row" && grep -q '10' <<<"$(grep 'tasks planned' <<<"$OUT")"; then
  pass "delivery view: planned count and 50% first-pass rate"
else
  fail "delivery view wrong (rc=$RC row='${row:-<missing>}')"
fi
if grep -qE 'spec failed post-impl .* 17%' <<<"$OUT"; then
  pass "delivery view: 1 of 6 spec tests failed after implementation"
else
  fail "spec-cycle arithmetic wrong: '$(grep 'spec failed' <<<"$OUT")'"
fi

# 2 ambiguities, one owned by plan and one by requirements; the single resume needed a correction.
run_util "$h23" "$WORK" stats --by drift
if [[ "$RC" -eq 0 ]] && grep -qE '^  plan +1 +2 +50%' <<<"$OUT" \
   && grep -qE 'marks corrected +1 +1 +100%' <<<"$OUT"; then
  pass "drift view: ambiguity split by owning stage, resume accuracy"
else
  fail "drift view wrong (rc=$RC out='${OUT:0:200}')"
fi

# 2 of 3 delegated decisions resolved — the ratio RD-07 exists to make answerable.
run_util "$h23" "$WORK" stats --by design
if [[ "$RC" -eq 0 ]] && grep -qE '^resolved +2 +3 +67%' <<<"$OUT" \
   && grep -qE '^escalated_reserved +1 +3 +33%' <<<"$OUT"; then
  pass "design view: delegation resolved/escalated split"
else
  fail "design view wrong (rc=$RC out='${OUT:0:200}')"
fi
# The reserved escalation carried no class, so it must not appear in the class breakdown.
if [[ "$(grep -cE '^(failure_recovery|concurrency) ' <<<"$OUT")" == "2" ]] \
   && ! grep -qE '^null ' <<<"$OUT"; then
  pass "design view: classless escalation absent from the class breakdown"
else
  fail "class breakdown wrong: '$(grep -A4 '^class' <<<"$OUT")'"
fi

# An unknown view is refused rather than silently falling back to the overview.
run_util "$h23" "$WORK" stats --by rationale
if [[ "$RC" -eq 0 && -z "$OUT" && -n "$ERR" ]]; then
  pass "an unknown --by view is refused"
else
  fail "unknown --by view not refused (rc=$RC out='${OUT:0:60}')"
fi

# -----------------------------------------------------------------------------
# SPEC-16 — containment meta-assertion: the whole run wrote nothing to the real home's
# telemetry file (every invocation above used a sandbox home).
# -----------------------------------------------------------------------------
section "SPEC-16: no writes outside the sandbox"
if [[ -x "$UTILITY" ]]; then
  REAL_AFTER="$(real_events_state)"
  if [[ "$REAL_BEFORE" == "$REAL_AFTER" ]]; then
    pass "real ~/$EVENTS_REL untouched ($REAL_AFTER)"
  else
    fail "real telemetry file changed during the suite: '$REAL_BEFORE' → '$REAL_AFTER'"
  fi
else
  fail "containment not demonstrable — utility missing, nothing ran"
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
section "Summary"
if [[ "$FAILURES" -eq 0 ]]; then
  printf '  \033[32mAll telemetry checks passed.\033[0m\n'
  exit 0
else
  printf '  \033[31m%d telemetry check(s) failed.\033[0m\n' "$FAILURES"
  exit 1
fi
