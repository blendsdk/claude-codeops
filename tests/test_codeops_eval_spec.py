"""Specification tests for the evaluation harness.

These expectations come from the harness specification alone. They are an immutable oracle: if
the implementation disagrees with a test here, the implementation is wrong.
"""

import json

import pytest

import codeops_eval as ev


# --------------------------------------------------------------------------------------
# Fixtures — minimal shapes the specification defines, built explicitly so each test reads
# on its own without tracing helper indirection.
# --------------------------------------------------------------------------------------

EXPECTED = {
    "requiredConcepts": {
        "rounding": ["round", "precision"],
        "idempotency": ["idempoten", "duplicate"],
        "atomicity": ["atomic", "rollback"],
        "currency": ["currency", "unit"],
        "overflow": ["overflow", "negative"],
        "audit": ["audit", "trail"],
        "authz": ["authoriz", "permission"],
        "isolation": ["tenant", "isolation"],
    },
    "expectedGate": "closed",
}

ALL_CONCEPT_BLOCKERS = [
    {"question": "How are amounts rounded?", "impact": "precision loss"},
    {"question": "Is the transfer idempotent?", "impact": "duplicate posting"},
    {"question": "Is the write atomic with rollback?", "impact": "partial commit"},
    {"question": "What currency unit is stored?", "impact": "unit mismatch"},
    {"question": "Can an amount be negative or overflow?", "impact": "overflow"},
    {"question": "What audit trail is kept?", "impact": "no audit"},
    {"question": "Who is authorized to post?", "impact": "permission gap"},
    {"question": "How is tenant isolation enforced?", "impact": "cross-tenant read"},
]


def result(blockers, gate="closed"):
    """Build a structured run result carrying the given blockers and gate verdict."""
    return {"domains": [], "blockers": list(blockers), "gate": gate}


def runs_with_counts(counts, gate="closed"):
    """Build one run per requested blocker count, each covering every required concept.

    Concept coverage is held constant so a test that varies counts is isolated to counts.
    """
    out = []
    for count in counts:
        blockers = list(ALL_CONCEPT_BLOCKERS)
        while len(blockers) < count:
            blockers.append({"question": f"Extra question {len(blockers)}", "impact": "minor"})
        out.append(result(blockers[:count] if count < len(blockers) else blockers, gate))
    return out


# --------------------------------------------------------------------------------------
# The oracle
# --------------------------------------------------------------------------------------

def test_should_pass_when_every_required_concept_is_covered_and_the_gate_matches():
    score = ev.score(EXPECTED, result(ALL_CONCEPT_BLOCKERS, gate="closed"))
    assert score.passed is True
    assert score.coverage == 1.0
    assert score.missing_concepts == []


def test_should_fail_and_name_the_gap_when_one_required_concept_is_uncovered():
    score = ev.score(EXPECTED, result(ALL_CONCEPT_BLOCKERS[:-1], gate="closed"))
    assert score.passed is False
    assert score.coverage < 1.0
    assert score.missing_concepts == ["isolation"]


def test_should_fail_on_the_gate_verdict_when_coverage_is_complete_but_the_gate_is_wrong():
    score = ev.score(EXPECTED, result(ALL_CONCEPT_BLOCKERS, gate="open"))
    assert score.passed is False
    assert score.gate_ok is False
    assert score.coverage == 1.0


# --------------------------------------------------------------------------------------
# The comparator
# --------------------------------------------------------------------------------------

def test_should_report_no_regression_when_the_candidate_median_is_at_or_above_the_baseline_floor():
    comparison = ev.compare(
        EXPECTED, runs_with_counts([10, 13, 16]), runs_with_counts([11, 12, 14])
    )
    assert comparison.regressed is False


def test_should_report_regression_when_the_candidate_median_falls_below_the_baseline_floor():
    comparison = ev.compare(
        EXPECTED, runs_with_counts([10, 13, 16]), runs_with_counts([7, 8, 9])
    )
    assert comparison.regressed is True


def test_should_report_regression_when_a_required_concept_is_dropped_despite_a_higher_count():
    # The candidate asks more questions overall but stops covering one required concept.
    # Losing a concept outranks any gain in raw question count.
    weakened = []
    for run in runs_with_counts([20, 20, 20]):
        run["blockers"] = [
            b for b in run["blockers"] if "tenant" not in b["question"].lower()
        ]
        weakened.append(run)
    comparison = ev.compare(EXPECTED, runs_with_counts([10, 13, 16]), weakened)
    assert comparison.regressed is True


def test_should_report_regression_when_the_gate_closes_less_often_than_the_baseline():
    baseline = runs_with_counts([10, 13, 16], gate="closed")
    candidate = runs_with_counts([10, 13, 16], gate="open")
    comparison = ev.compare(EXPECTED, baseline, candidate)
    assert comparison.regressed is True


# --------------------------------------------------------------------------------------
# Running a scenario — retry, aggregation, and refusal to measure too little
# --------------------------------------------------------------------------------------

def test_should_record_one_successful_run_when_the_first_attempt_fails_and_the_retry_succeeds():
    attempts = []

    def invoke(_plugin, _scenario):
        attempts.append(1)
        if len(attempts) == 1:
            raise ev.InvocationError("transient failure")
        return result(ALL_CONCEPT_BLOCKERS)

    outcome = ev.run_scenario("plugin", "scenario", runs=1, invoke=invoke)
    assert len(outcome.successful) == 1
    assert outcome.failed == []
    assert len(attempts) == 2


def test_should_exclude_and_report_a_run_when_both_attempts_fail():
    def invoke(_plugin, _scenario):
        raise ev.InvocationError("hard failure")

    outcome = ev.run_scenario("plugin", "scenario", runs=3, invoke=invoke, min_runs=0)
    assert outcome.successful == []
    assert len(outcome.failed) == 3


def test_should_abort_when_fewer_than_two_runs_succeed_because_a_median_needs_two():
    calls = []

    def invoke(_plugin, _scenario):
        calls.append(1)
        if len(calls) <= 2:
            raise ev.InvocationError("failure")
        return result(ALL_CONCEPT_BLOCKERS)

    with pytest.raises(ev.InsufficientRunsError) as excinfo:
        ev.run_scenario("plugin", "scenario", runs=1, invoke=invoke)
    assert "2" in str(excinfo.value)


# --------------------------------------------------------------------------------------
# Refusing to proceed on bad inputs
# --------------------------------------------------------------------------------------

def test_should_raise_a_hard_error_naming_the_capture_command_when_the_baseline_is_absent(tmp_path):
    missing = tmp_path / "baseline-3.12.0.json"
    with pytest.raises(ev.BaselineMissingError) as excinfo:
        ev.load_baseline(missing)
    # A reader who hits this must be told how to produce the file, not merely that it is absent.
    assert "run" in str(excinfo.value)


def test_should_raise_before_spending_anything_when_the_plugin_directory_does_not_exist(tmp_path):
    spent = []

    def invoke(_plugin, _scenario):
        spent.append(1)
        return result(ALL_CONCEPT_BLOCKERS)

    with pytest.raises(ev.PluginNotFoundError):
        ev.run_scenario(tmp_path / "absent", tmp_path, runs=1, invoke=invoke)
    assert spent == []


def test_should_reject_a_path_that_resolves_outside_its_allowed_root(tmp_path):
    root = tmp_path / "root"
    root.mkdir()
    with pytest.raises(ev.PathEscapeError):
        ev.resolve_within(root, "../outside")


def test_should_accept_a_path_that_stays_inside_its_allowed_root(tmp_path):
    root = tmp_path / "root"
    (root / "inner").mkdir(parents=True)
    assert ev.resolve_within(root, "inner") == (root / "inner").resolve()


def test_should_raise_a_parse_error_naming_the_file_when_json_is_malformed(tmp_path):
    broken = tmp_path / "expected.json"
    broken.write_text('{"requiredConcepts": ', encoding="utf-8")
    with pytest.raises(ev.MalformedJSONError) as excinfo:
        ev.load_json(broken)
    assert "expected.json" in str(excinfo.value)


def test_should_load_well_formed_json_unchanged(tmp_path):
    good = tmp_path / "expected.json"
    good.write_text(json.dumps(EXPECTED), encoding="utf-8")
    assert ev.load_json(good) == EXPECTED
