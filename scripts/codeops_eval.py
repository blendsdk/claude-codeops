#!/usr/bin/env python3
"""Evaluation harness — score a CodeOps release against pinned requirements-stage scenarios.

CodeOps Skills Version: 3.19.0

The harness answers one question: does a release surface the safety concepts a scenario demands,
and does it reach the right gate verdict? Scoring and comparison are pure functions over stored
JSON, so they run without a model and are cheap to test. Only `run_scenario` invokes a model, and
it takes its invoker as an argument so the retry and aggregation rules can be exercised for free.

Scope note: this measures requirements-stage ambiguity discovery and gate behavior. It is not
evidence of execution quality, recovery behavior, or final-system quality, and must not be
presented as such.

A release is selected by path rather than by installation state, so a candidate can be measured
before it is merged and the installed plugin is never mutated to take a reading.

@example
    expected = load_json(scenario / "expected.json")
    baseline = load_baseline(scenario / "baseline-3.12.0.json")
    candidate = run_scenario(plugin_dir, scenario, runs=3).successful
    if compare(expected, baseline, candidate).regressed:
        raise SystemExit(1)
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Iterable, Sequence

# A concept counts as covered when at least half its words appear somewhere in the run's
# questions and impacts. Taken from the source edition rather than re-derived: that threshold is
# already validated against real model output across all three scenarios, whereas a number
# invented here would have nothing behind it.
COVERAGE_THRESHOLD = 0.5

# Two successful runs are the minimum from which a median means anything.
DEFAULT_MIN_RUNS = 2

# Each run gets one retry; a second failure is reported rather than papered over.
ATTEMPTS_PER_RUN = 2


class HarnessError(Exception):
    """Base class for every condition that must stop a measurement rather than degrade it."""


class InvocationError(HarnessError):
    """A single scenario run failed: bad exit status, unparseable output, or schema violation."""


class InsufficientRunsError(HarnessError):
    """Too few runs succeeded to compute a median, so no measurement can honestly be reported."""


class BaselineMissingError(HarnessError):
    """The baseline file is absent. Absent is never the same as 'no regression'."""


class PluginNotFoundError(HarnessError):
    """The requested plugin directory does not exist, raised before anything is spent."""


class PathEscapeError(HarnessError):
    """A supplied path resolved outside its allowed root."""


class MalformedJSONError(HarnessError):
    """A scenario, schema, or result file could not be parsed as JSON."""


@dataclass(frozen=True)
class Comparison:
    """Whether a candidate regressed against a baseline, and why if it did."""

    regressed: bool
    reason: str | None = None


@dataclass
class RunOutcome:
    """The successful and failed runs from one measurement set."""

    successful: list[dict[str, Any]] = field(default_factory=list)
    failed: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------------------------

def resolve_within(root: Path | str, candidate: Path | str) -> Path:
    """Resolve `candidate` under `root`, refusing any path that escapes it.

    A traversal attempt is an error rather than something silently clamped, so a mistyped path
    fails loudly instead of quietly measuring the wrong tree.
    """
    root_path = Path(root).resolve()
    resolved = (root_path / Path(candidate)).resolve()
    if resolved != root_path and root_path not in resolved.parents:
        raise PathEscapeError(f"{candidate!r} resolves outside {root_path}")
    return resolved


def load_json(path: Path | str) -> Any:
    """Read and parse a JSON file, naming the file when it cannot be parsed."""
    path = Path(path)
    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise MalformedJSONError(f"{path}: cannot be read ({exc})") from exc
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise MalformedJSONError(f"{path}: invalid JSON at line {exc.lineno} column {exc.colno}") from exc


def load_result(path: Path | str) -> dict[str, Any]:
    """Load one run result, normalizing the field name older evidence used.

    Retained results from the source edition name the selected classification `selected_lenses`.
    This repository calls the concept `domains`, so the older name is translated here, at the
    boundary, and never leaks further in.
    """
    result = load_json(path)
    if "selected_lenses" in result:
        result = dict(result)
        result["selected_domains"] = result.pop("selected_lenses")
    return result


def load_baseline(path: Path | str) -> list[dict[str, Any]]:
    """Load a pinned baseline, explaining how to capture one when it is absent.

    An absent baseline is never treated as "no regression" — that would turn a missing
    measurement into a silent pass.
    """
    path = Path(path)
    if not path.is_file():
        raise BaselineMissingError(
            f"{path} does not exist. Capture it first with: "
            f"codeops_eval.py run --plugin <dir> --scenario <dir> --runs 3 --out {path}"
        )
    runs = load_json(path)
    if not isinstance(runs, list):
        raise MalformedJSONError(f"{path}: expected a list of runs")
    return runs


def schema_payload(path: Path | str) -> dict[str, Any]:
    """Load the structured-output schema in the form the CLI accepts.

    The CLI validates the schema it is handed against the dialects it has loaded, and rejects a
    `$schema` URI it cannot resolve — which fails the invocation before any measurement happens.
    The declaration is dropped here rather than removed from the file so the file stays a
    well-formed schema for every other reader.
    """
    schema = dict(load_json(path))
    schema.pop("$schema", None)
    return schema


# ---------------------------------------------------------------------------------------------
# The oracle
# ---------------------------------------------------------------------------------------------

def _tokens(value: str) -> set[str]:
    """Reduce a phrase to its comparable words."""
    return set(re.findall(r"[a-z0-9]+", value.lower()))


def _corpus(result: dict[str, Any]) -> set[str]:
    """Every word the run used across its questions and their impacts."""
    parts: list[str] = []
    for item in result.get("material_ambiguities", []):
        parts.append(str(item.get("question", "")))
        impact = item.get("impact", [])
        parts.extend(impact if isinstance(impact, list) else [str(impact)])
    return _tokens(" ".join(parts))


def covered_concepts(expected: dict[str, Any], result: dict[str, Any]) -> list[str]:
    """The required concepts this run surfaced, by word overlap against its whole corpus."""
    corpus = _corpus(result)
    found = []
    for concept in expected.get("required_concepts", []):
        concept_tokens = _tokens(concept)
        overlap = len(concept_tokens & corpus) / max(1, len(concept_tokens))
        if overlap >= COVERAGE_THRESHOLD:
            found.append(concept)
    return found


def blocking_count(result: dict[str, Any]) -> int:
    """How many ambiguities this run judged severe enough to block a plan."""
    return sum(
        1 for item in result.get("material_ambiguities", []) if item.get("must_block") is True
    )


def score(
    expected: dict[str, Any],
    result: dict[str, Any],
    *,
    require_domains: bool = True,
) -> list[str]:
    """Judge one run against one scenario's expectations, returning every failure found.

    Errors are returned rather than a single verdict so a failure names exactly what is missing.
    An empty list means the run passed.

    `require_domains` is disabled when scoring a release that predates domain classification:
    such a release cannot satisfy the check by construction, and failing it there would say
    nothing about the coverage and gate behavior actually under measurement.
    """
    errors: list[str] = []

    if require_domains:
        selected = set(result.get("selected_domains", []))
        for domain in expected.get("required_domains", []):
            if domain not in selected:
                errors.append(f"missing required domain: {domain}")

    blocking = blocking_count(result)
    minimum = expected.get("minimum_material_ambiguities", 0)
    if blocking < minimum:
        errors.append(f"only {blocking} blocking ambiguities; expected at least {minimum}")

    found = set(covered_concepts(expected, result))
    for concept in expected.get("required_concepts", []):
        if concept not in found:
            errors.append(f"missing concept coverage: {concept}")

    verdict = result.get("gate_verdict")
    if verdict != expected.get("verdict"):
        errors.append(f"gate verdict {verdict!r}; expected {expected.get('verdict')!r}")

    return errors


# ---------------------------------------------------------------------------------------------
# The comparator
# ---------------------------------------------------------------------------------------------

def _coverage_union(expected: dict[str, Any], runs: Sequence[dict[str, Any]]) -> set[str]:
    """Every required concept any run in the set surfaced."""
    union: set[str] = set()
    for result in runs:
        union.update(covered_concepts(expected, result))
    return union


def _verdict_rate(expected: dict[str, Any], runs: Sequence[dict[str, Any]]) -> float:
    """How often the set reached the expected gate verdict."""
    if not runs:
        return 0.0
    hits = sum(1 for r in runs if r.get("gate_verdict") == expected.get("verdict"))
    return hits / len(runs)


def compare(
    expected: dict[str, Any],
    baseline: Sequence[dict[str, Any]],
    candidate: Sequence[dict[str, Any]],
) -> Comparison:
    """Compare a candidate run set against a baseline set.

    Concept coverage and gate verdict are the primary signals and admit no tolerance: losing
    either is a regression however many questions the candidate asked. Blocking volume is
    secondary and varies materially between runs of the same release, so it regresses only when
    the candidate's median falls below the baseline's lowest observed run — a threshold ordinary
    variance cannot trip.
    """
    if not baseline or not candidate:
        raise InsufficientRunsError("both a baseline and a candidate run set are required")

    lost = _coverage_union(expected, baseline) - _coverage_union(expected, candidate)
    if lost:
        return Comparison(True, f"concepts no longer covered: {', '.join(sorted(lost))}")

    base_rate = _verdict_rate(expected, baseline)
    cand_rate = _verdict_rate(expected, candidate)
    if cand_rate < base_rate:
        return Comparison(
            True, f"expected verdict reached {cand_rate:.0%} of runs, was {base_rate:.0%}"
        )

    base_floor = min(blocking_count(r) for r in baseline)
    cand_median = statistics.median(blocking_count(r) for r in candidate)
    if cand_median < base_floor:
        return Comparison(
            True,
            f"median blocking ambiguities {cand_median} below the baseline's lowest run {base_floor}",
        )

    return Comparison(False)


# ---------------------------------------------------------------------------------------------
# Running a scenario
# ---------------------------------------------------------------------------------------------

def invocation_command(plugin: Path | str, schema: Path | str, prompt: str) -> list[str]:
    """Build the read-only CLI invocation that measures one run.

    A run works from the scenario directory, so the release under measurement needs an explicit
    read grant: without it the release's own reference material is unreadable and the run answers
    from general knowledge instead. That still produces a well-formed, plausible result, which
    makes it the most dangerous way for a measurement to be wrong.
    """
    plugin = Path(plugin).resolve()
    return [
        "claude", "-p",
        "--no-session-persistence",
        "--permission-mode", "dontAsk",
        "--tools", "Read",
        "--plugin-dir", str(plugin),
        "--add-dir", str(plugin),
        "--effort", "high",
        "--output-format", "json",
        "--json-schema", json.dumps(schema_payload(schema), separators=(",", ":")),
        prompt,
    ]


def _invoke_cli(plugin: Path, scenario: Path) -> dict[str, Any]:
    """Measure one run by invoking the CLI read-only against a scenario directory."""
    schema = Path(__file__).resolve().parent.parent / "tests" / "scenarios" / "result.schema.json"
    prompt = (
        "Read scenario.md. Use the make_requirements workflow. Apply its domain-selection and "
        "zero-ambiguity gate rules, but do not create files and do not interview. Return only "
        "the required structured evaluation: select applicable canonical CodeOps domain ids, "
        "enumerate every material unresolved question that blocks an executable plan, explain "
        "its concrete impacts, and set the gate verdict."
    )
    command = invocation_command(plugin, schema, prompt)
    completed = subprocess.run(command, cwd=scenario, capture_output=True, text=True)
    if completed.returncode:
        raise InvocationError(completed.stderr.strip() or completed.stdout.strip())
    try:
        envelope = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise InvocationError(f"unparseable CLI output: {exc}") from exc
    result = envelope.get("structured_output")
    if result is None:
        try:
            result = json.loads(envelope["result"])
        except (KeyError, json.JSONDecodeError) as exc:
            raise InvocationError("CLI returned no structured output") from exc
    if "selected_lenses" in result:
        result["selected_domains"] = result.pop("selected_lenses")
    return result


def run_scenario(
    plugin: Path | str,
    scenario: Path | str,
    runs: int,
    invoke: Callable[[Path, Path], dict[str, Any]] | None = None,
    min_runs: int = DEFAULT_MIN_RUNS,
) -> RunOutcome:
    """Run one scenario `runs` times, retrying each run once before giving up on it.

    `invoke` performs a single measurement and is injectable so the retry and aggregation rules
    can be tested without a model. A run that fails twice is excluded and reported, never
    replaced by a partial result.
    """
    plugin_path = Path(plugin)
    scenario_path = Path(scenario)
    # Checked before the loop so a mistyped plugin path costs nothing.
    if not plugin_path.is_dir():
        raise PluginNotFoundError(f"plugin directory does not exist: {plugin_path}")
    if not scenario_path.is_dir():
        raise HarnessError(f"scenario directory does not exist: {scenario_path}")

    invoker = invoke or _invoke_cli
    outcome = RunOutcome()
    for index in range(runs):
        last_error: str | None = None
        for _ in range(ATTEMPTS_PER_RUN):
            try:
                outcome.successful.append(invoker(plugin_path, scenario_path))
                last_error = None
                break
            except InvocationError as exc:
                last_error = str(exc)
        if last_error is not None:
            outcome.failed.append(f"run {index + 1}: {last_error}")

    if len(outcome.successful) < min_runs:
        # The failures travel with the abort: without them an operator has to reproduce the
        # invocation by hand before they can act on it.
        detail = "".join(f"\n  {failure}" for failure in outcome.failed)
        raise InsufficientRunsError(
            f"only {len(outcome.successful)} runs succeeded; at least {min_runs} are needed "
            f"for a median to mean anything{detail}"
        )
    return outcome


# ---------------------------------------------------------------------------------------------
# Command line
# ---------------------------------------------------------------------------------------------

def _cmd_run(args: argparse.Namespace) -> int:
    outcome = run_scenario(args.plugin, args.scenario, runs=args.runs)
    Path(args.out).write_text(json.dumps(outcome.successful, indent=2) + "\n", encoding="utf-8")
    print(f"captured {len(outcome.successful)} run(s) to {args.out}")
    for failure in outcome.failed:
        print(f"  excluded — {failure}", file=sys.stderr)
    return 0


def _cmd_score(args: argparse.Namespace) -> int:
    expected = load_json(Path(args.scenario) / "expected.json")
    results = load_result(args.result)
    runs = results if isinstance(results, list) else [results]
    failed = False
    for index, result in enumerate(runs, start=1):
        errors = score(expected, result, require_domains=not args.no_domains)
        if errors:
            failed = True
            print(f"run {index} failed:")
            for error in errors:
                print(f"  - {error}")
        else:
            print(f"run {index} passed")
    return 1 if failed else 0


def _cmd_compare(args: argparse.Namespace) -> int:
    expected = load_json(Path(args.scenario) / "expected.json")
    comparison = compare(expected, load_baseline(args.baseline), load_baseline(args.candidate))
    if comparison.regressed:
        print(f"REGRESSION: {comparison.reason}")
        return 1
    print("no regression against the pinned baseline")
    return 0


def main(argv: Iterable[str] | None = None) -> int:
    """Dispatch the `run`, `score`, and `compare` subcommands."""
    parser = argparse.ArgumentParser(description="Evaluate a CodeOps release against pinned scenarios.")
    sub = parser.add_subparsers(dest="command", required=True)

    p_run = sub.add_parser("run", help="invoke a release against one scenario N times")
    p_run.add_argument("--plugin", required=True, help="plugin directory to measure")
    p_run.add_argument("--scenario", required=True, help="scenario directory")
    p_run.add_argument("--runs", type=int, default=3)
    p_run.add_argument("--out", required=True)
    p_run.set_defaults(func=_cmd_run)

    p_score = sub.add_parser("score", help="score stored results against a scenario")
    p_score.add_argument("--scenario", required=True)
    p_score.add_argument("--result", required=True)
    p_score.add_argument(
        "--no-domains",
        action="store_true",
        help="skip the domain check when scoring a release that predates domain selection",
    )
    p_score.set_defaults(func=_cmd_score)

    p_cmp = sub.add_parser("compare", help="compare a candidate run set against a baseline")
    p_cmp.add_argument("--scenario", required=True)
    p_cmp.add_argument("baseline")
    p_cmp.add_argument("candidate")
    p_cmp.set_defaults(func=_cmd_compare)

    args = parser.parse_args(list(argv) if argv is not None else None)
    try:
        return args.func(args)
    except HarnessError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
