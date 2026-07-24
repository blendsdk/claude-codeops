"""Implementation tests for the evaluation harness.

Where the spec suite fixes what the harness must conclude, these cover how it gets there: the
payload handed to the CLI, the retry accounting, and how a partially failed run set is reported.
"""

import json

import pytest

import codeops_eval as ev


def result(scenario="sample"):
    """Build a schema-valid run result."""
    return {
        "scenario": scenario,
        "selected_domains": [],
        "material_ambiguities": [],
        "gate_verdict": "PASS",
    }


# --------------------------------------------------------------------------------------
# The schema payload handed to the CLI
# --------------------------------------------------------------------------------------

def test_should_drop_the_dialect_declaration_the_cli_cannot_resolve(tmp_path):
    # The CLI rejects a schema carrying a `$schema` URI it has no loaded definition for, which
    # fails the invocation before any measurement happens.
    path = tmp_path / "result.schema.json"
    path.write_text(
        json.dumps(
            {
                "$schema": "https://json-schema.org/draft/2020-12/schema",
                "type": "object",
                "properties": {"scenario": {"type": "string"}},
            }
        ),
        encoding="utf-8",
    )
    payload = ev.schema_payload(path)
    assert "$schema" not in payload
    assert payload["properties"] == {"scenario": {"type": "string"}}


def test_should_leave_a_schema_without_a_dialect_declaration_untouched(tmp_path):
    path = tmp_path / "result.schema.json"
    body = {"type": "object", "properties": {}}
    path.write_text(json.dumps(body), encoding="utf-8")
    assert ev.schema_payload(path) == body


def test_should_produce_a_payload_the_cli_accepts_from_the_shipped_schema(request):
    shipped = request.config.rootpath / "tests" / "scenarios" / "result.schema.json"
    payload = ev.schema_payload(shipped)
    assert "$schema" not in payload
    assert payload["required"], "the shipped schema must still constrain the result shape"


# --------------------------------------------------------------------------------------
# The command handed to the CLI
# --------------------------------------------------------------------------------------

def _schema(tmp_path):
    """A minimal schema file on disk, since the command embeds its contents."""
    path = tmp_path / "schema.json"
    path.write_text(json.dumps({"type": "object"}), encoding="utf-8")
    return path


def test_should_grant_read_access_to_the_release_under_measurement(tmp_path):
    # A run works from the scenario directory, so without an explicit grant the release's own
    # reference files are unreadable. The run still returns a plausible-looking answer, produced
    # without the material being measured — the worst kind of failure for a measurement.
    plugin = tmp_path / "release"
    plugin.mkdir()
    command = ev.invocation_command(plugin, _schema(tmp_path), "prompt")
    assert "--add-dir" in command
    assert str(plugin.resolve()) in command


def test_should_select_the_release_by_path(tmp_path):
    plugin = tmp_path / "release"
    plugin.mkdir()
    command = ev.invocation_command(plugin, _schema(tmp_path), "prompt")
    assert command[command.index("--plugin-dir") + 1] == str(plugin.resolve())


def test_should_keep_the_run_read_only(tmp_path):
    plugin = tmp_path / "release"
    plugin.mkdir()
    command = ev.invocation_command(plugin, _schema(tmp_path), "prompt")
    assert command[command.index("--tools") + 1] == "Read"
    assert "--no-session-persistence" in command


# --------------------------------------------------------------------------------------
# Retry accounting
# --------------------------------------------------------------------------------------

def test_should_attempt_each_run_at_most_twice(tmp_path):
    attempts = []

    def invoke(_plugin, _scenario):
        attempts.append(1)
        raise ev.InvocationError("always fails")

    with pytest.raises(ev.InsufficientRunsError):
        ev.run_scenario(tmp_path, tmp_path, runs=3, invoke=invoke)
    assert len(attempts) == 3 * ev.ATTEMPTS_PER_RUN


def test_should_not_retry_a_run_that_succeeds_on_its_first_attempt(tmp_path):
    attempts = []

    def invoke(_plugin, _scenario):
        attempts.append(1)
        return result()

    ev.run_scenario(tmp_path, tmp_path, runs=2, invoke=invoke)
    assert len(attempts) == 2


def test_should_keep_the_successes_and_report_the_failures_when_a_set_is_mixed(tmp_path):
    calls = []

    def invoke(_plugin, _scenario):
        calls.append(1)
        # The second run fails both of its attempts; the first and third succeed outright.
        if len(calls) in (2, 3):
            raise ev.InvocationError("transient")
        return result()

    outcome = ev.run_scenario(tmp_path, tmp_path, runs=3, invoke=invoke)
    assert len(outcome.successful) == 2
    assert len(outcome.failed) == 1
    assert "run 2" in outcome.failed[0]


def test_should_stop_before_invoking_anything_when_the_scenario_directory_is_absent(tmp_path):
    spent = []

    def invoke(_plugin, _scenario):
        spent.append(1)
        return result()

    with pytest.raises(ev.HarnessError):
        ev.run_scenario(tmp_path, tmp_path / "absent", runs=1, invoke=invoke)
    assert spent == []


# --------------------------------------------------------------------------------------
# Reading captured results
# --------------------------------------------------------------------------------------

def test_should_read_a_capture_file_as_a_list_of_runs(tmp_path):
    capture = tmp_path / "baseline.json"
    capture.write_text(json.dumps([result("a"), result("b")]), encoding="utf-8")
    runs = ev.load_baseline(capture)
    assert [r["scenario"] for r in runs] == ["a", "b"]


def test_should_reject_a_capture_file_that_is_not_a_list_of_runs(tmp_path):
    capture = tmp_path / "baseline.json"
    capture.write_text(json.dumps(result()), encoding="utf-8")
    with pytest.raises(ev.HarnessError):
        ev.load_baseline(capture)
