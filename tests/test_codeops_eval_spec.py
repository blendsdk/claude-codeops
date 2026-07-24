"""Specification tests for the evaluation harness.

These expectations come from the harness specification alone. They are an immutable oracle: if
the implementation disagrees with a test here, the implementation is wrong.
"""

import json

import pytest

import codeops_eval as ev


EXPECTED = {
    "scenario": "sample",
    "required_domains": ["financial-system", "distributed-and-concurrent"],
    "required_concepts": [
        "currency precision and rounding order",
        "idempotency and timeout unknown outcome",
    ],
    "minimum_material_ambiguities": 2,
    "verdict": "BLOCK",
}


def ambiguity(question, impact, blocking=True):
    """Build one material ambiguity in the shape a scored run reports."""
    return {"question": question, "impact": list(impact), "must_block": blocking}


COVERING = [
    ambiguity(
        "What currency precision applies and in what rounding order?",
        ["wrong rounding order changes settled amounts"],
    ),
    ambiguity(
        "Is the transfer idempotent when a timeout leaves the outcome unknown?",
        ["a retry can double-post"],
    ),
]


def run(ambiguities, verdict="BLOCK", domains=("financial-system", "distributed-and-concurrent")):
    """Build a structured run result."""
    return {
        "selected_domains": list(domains),
        "material_ambiguities": list(ambiguities),
        "gate_verdict": verdict,
    }


def padded(count, ambiguities=COVERING):
    """Extend a covering run to `count` blocking ambiguities, holding coverage constant."""
    items = list(ambiguities)
    while len(items) < count:
        items.append(ambiguity(f"Filler question {len(items)}", ["minor"]))
    return run(items)


# --------------------------------------------------------------------------------------
# The oracle
# --------------------------------------------------------------------------------------

def test_should_return_no_errors_when_concepts_volume_domains_and_verdict_all_hold():
    assert ev.score(EXPECTED, run(COVERING)) == []


def test_should_name_the_concept_left_below_the_overlap_threshold():
    thin = [COVERING[0], ambiguity("Is anything cached?", ["unclear"])]
    errors = ev.score(EXPECTED, run(thin))
    assert any("idempotency and timeout unknown outcome" in e for e in errors)


def test_should_report_the_gate_verdict_when_it_does_not_match_the_expectation():
    errors = ev.score(EXPECTED, run(COVERING, verdict="PASS"))
    assert any("PASS" in e and "BLOCK" in e for e in errors)


def test_should_report_both_counts_when_too_few_ambiguities_block():
    one_blocking = [COVERING[0], dict(COVERING[1], must_block=False)]
    errors = ev.score(EXPECTED, run(one_blocking))
    assert any("1" in e and "2" in e for e in errors)


def test_should_not_report_a_domain_gap_when_the_domain_check_is_disabled():
    # A release predating domain selection cannot satisfy the check by construction, so a
    # baseline from such a release is scored on coverage and verdict alone.
    errors = ev.score(EXPECTED, run(COVERING, domains=()), require_domains=False)
    assert not any("domain" in e.lower() for e in errors)


def test_should_report_a_domain_gap_when_the_domain_check_is_enabled():
    errors = ev.score(EXPECTED, run(COVERING, domains=("financial-system",)))
    assert any("distributed-and-concurrent" in e for e in errors)


# --------------------------------------------------------------------------------------
# The comparator
# --------------------------------------------------------------------------------------

def test_should_report_no_regression_when_the_candidate_median_is_at_or_above_the_baseline_floor():
    baseline = [padded(10), padded(13), padded(16)]
    candidate = [padded(11), padded(12), padded(14)]
    assert ev.compare(EXPECTED, baseline, candidate).regressed is False


def test_should_report_regression_when_the_candidate_median_falls_below_the_baseline_floor():
    baseline = [padded(10), padded(13), padded(16)]
    candidate = [padded(7), padded(8), padded(9)]
    assert ev.compare(EXPECTED, baseline, candidate).regressed is True


def test_should_report_regression_when_a_covered_concept_is_lost_despite_a_higher_volume():
    baseline = [padded(10), padded(13), padded(16)]
    thin = [COVERING[0], ambiguity("Is anything cached?", ["unclear"])]
    candidate = [padded(20, thin), padded(20, thin), padded(20, thin)]
    assert ev.compare(EXPECTED, baseline, candidate).regressed is True


def test_should_report_regression_when_the_expected_verdict_is_reached_less_often():
    baseline = [padded(10), padded(13), padded(16)]
    candidate = [
        run(list(padded(10)["material_ambiguities"]), verdict="PASS"),
        run(list(padded(13)["material_ambiguities"]), verdict="PASS"),
        run(list(padded(16)["material_ambiguities"]), verdict="BLOCK"),
    ]
    assert ev.compare(EXPECTED, baseline, candidate).regressed is True


def test_should_map_the_source_editions_field_name_when_loading_a_retained_result(tmp_path):
    retained = tmp_path / "retained.json"
    legacy = {
        "selected_lenses": ["financial-system"],
        "material_ambiguities": COVERING,
        "gate_verdict": "BLOCK",
    }
    retained.write_text(json.dumps(legacy), encoding="utf-8")
    loaded = ev.load_result(retained)
    assert loaded["selected_domains"] == ["financial-system"]
    assert "selected_lenses" not in loaded


# --------------------------------------------------------------------------------------
# Running a scenario — retry, aggregation, and refusal to measure too little
# --------------------------------------------------------------------------------------

def test_should_record_one_successful_run_when_the_first_attempt_fails_and_the_retry_succeeds(tmp_path):
    attempts = []

    def invoke(_plugin, _scenario):
        attempts.append(1)
        if len(attempts) == 1:
            raise ev.InvocationError("transient failure")
        return run(COVERING)

    outcome = ev.run_scenario(tmp_path, tmp_path, runs=1, invoke=invoke, min_runs=1)
    assert len(outcome.successful) == 1
    assert outcome.failed == []
    assert len(attempts) == 2


def test_should_exclude_and_report_a_run_when_both_attempts_fail(tmp_path):
    def invoke(_plugin, _scenario):
        raise ev.InvocationError("hard failure")

    outcome = ev.run_scenario(tmp_path, tmp_path, runs=3, invoke=invoke, min_runs=0)
    assert outcome.successful == []
    assert len(outcome.failed) == 3


def test_should_abort_when_fewer_than_two_runs_succeed_because_a_median_needs_two(tmp_path):
    def invoke(_plugin, _scenario):
        raise ev.InvocationError("failure")

    with pytest.raises(ev.InsufficientRunsError) as excinfo:
        ev.run_scenario(tmp_path, tmp_path, runs=3, invoke=invoke)
    assert "2" in str(excinfo.value)


# --------------------------------------------------------------------------------------
# Refusing to proceed on bad inputs
# --------------------------------------------------------------------------------------

def test_should_raise_a_hard_error_naming_the_capture_command_when_the_baseline_is_absent(tmp_path):
    with pytest.raises(ev.BaselineMissingError) as excinfo:
        ev.load_baseline(tmp_path / "baseline-3.12.0.json")
    # A reader hitting this must be told how to produce the file, not merely that it is absent.
    assert "run" in str(excinfo.value)


def test_should_raise_before_spending_anything_when_the_plugin_directory_does_not_exist(tmp_path):
    spent = []

    def invoke(_plugin, _scenario):
        spent.append(1)
        return run(COVERING)

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
    broken.write_text('{"required_concepts": ', encoding="utf-8")
    with pytest.raises(ev.MalformedJSONError) as excinfo:
        ev.load_json(broken)
    assert "expected.json" in str(excinfo.value)


def test_should_load_well_formed_json_unchanged(tmp_path):
    good = tmp_path / "expected.json"
    good.write_text(json.dumps(EXPECTED), encoding="utf-8")
    assert ev.load_json(good) == EXPECTED


# --------------------------------------------------------------------------------------
# The ported fixtures must satisfy the contract the oracle reads
# --------------------------------------------------------------------------------------

@pytest.mark.parametrize("name", ["compiler", "financial", "web"])
def test_should_ship_each_scenario_with_a_well_formed_expectation(name, request):
    scenario = request.config.rootpath / "tests" / "scenarios" / name
    expected = ev.load_json(scenario / "expected.json")
    assert (scenario / "scenario.md").is_file()
    for key in ("required_domains", "required_concepts", "minimum_material_ambiguities", "verdict"):
        assert key in expected, f"{name}/expected.json is missing {key}"
    assert expected["required_concepts"], f"{name} declares no required concepts"
