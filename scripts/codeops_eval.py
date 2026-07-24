#!/usr/bin/env python3
"""Evaluation harness — score a CodeOps release against pinned requirements-stage scenarios.

CodeOps Skills Version: 3.12.0

The harness answers one question: does a candidate release surface the safety concepts a
scenario demands, and does it close its gate correctly? Scoring and comparison are pure
functions over stored JSON, so they run without a model and are cheap to test. Only
`run_scenario` invokes a model, and it takes its invoker as an argument so the retry and
aggregation rules can be exercised at no cost.

Scope note: this measures requirements-stage ambiguity discovery and gate behavior. It is not
evidence of execution quality, recovery behavior, or final-system quality.

@example
    expected = load_json(scenario / "expected.json")
    baseline = load_baseline(scenario / "baseline-3.12.0.json")
    candidate = run_scenario(plugin_dir, scenario, runs=3).successful
    if compare(expected, baseline, candidate).regressed:
        raise SystemExit(1)
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Iterable, Sequence


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
class Score:
    """The oracle's verdict for one run against one scenario's expectations."""

    passed: bool
    coverage: float
    gate_ok: bool
    missing_concepts: list[str]


@dataclass(frozen=True)
class Comparison:
    """Whether a candidate regressed against a baseline, and the reason if it did."""

    regressed: bool
    reason: str | None = None


@dataclass
class RunOutcome:
    """The successful and failed runs from one measurement set."""

    successful: list[dict[str, Any]] = field(default_factory=list)
    failed: list[str] = field(default_factory=list)


def resolve_within(root: Path | str, candidate: Path | str) -> Path:
    """Resolve `candidate` under `root`, refusing any path that escapes it."""
    raise NotImplementedError


def load_json(path: Path | str) -> Any:
    """Read and parse a JSON file, naming the file when it cannot be parsed."""
    raise NotImplementedError


def load_baseline(path: Path | str) -> list[dict[str, Any]]:
    """Load a pinned baseline, explaining how to capture one when it is absent."""
    raise NotImplementedError


def score(expected: dict[str, Any], result: dict[str, Any]) -> Score:
    """Judge one run: are all required concepts covered, and is the gate verdict right?"""
    raise NotImplementedError


def compare(
    expected: dict[str, Any],
    baseline: Sequence[dict[str, Any]],
    candidate: Sequence[dict[str, Any]],
) -> Comparison:
    """Compare a candidate run set against a baseline set.

    Concept coverage and gate verdict are the primary signals and admit no tolerance. Blocker
    count varies materially between runs, so it regresses only when the candidate's median
    falls below the baseline's lowest observed run.
    """
    raise NotImplementedError


def run_scenario(
    plugin: Path | str,
    scenario: Path | str,
    runs: int,
    invoke: Callable[[Path, Path], dict[str, Any]] | None = None,
    min_runs: int = 2,
) -> RunOutcome:
    """Run one scenario `runs` times, retrying each run once before giving up on it.

    `invoke` performs a single measurement and is injectable so the retry and aggregation
    rules can be tested without a model. A run that fails twice is excluded and reported,
    never replaced by a partial result.
    """
    raise NotImplementedError


def main(argv: Iterable[str] | None = None) -> int:
    """Dispatch the `run`, `score`, and `compare` subcommands."""
    raise NotImplementedError


if __name__ == "__main__":
    raise SystemExit(main())
