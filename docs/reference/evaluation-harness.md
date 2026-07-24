# Evaluation harness

`scripts/codeops_eval.py` answers one question about a release: **does it surface the safety
concepts a scenario demands, and does it reach the right gate verdict?**

It exists so that changes to the skills can be judged against evidence instead of impression. It is
a contributor tool for this repository — it is not part of the installed plugin, and you never need
it to use CodeOps.

## What it does and does not measure

::: warning The limits are the point
The harness measures **requirements-stage** ambiguity discovery and gate behavior, and nothing
else. It is **not** evidence of **execution quality**, of **recovery** behavior, or of final
**system quality**, and a result from it must never be presented as such.
:::

A scenario is a short problem brief with known traps. The harness asks a release to work through it
under the requirements workflow, then scores what came back. A release that scores well has proven
it asks the right questions before planning — which is a real property, and a narrow one.

## The pieces

| Concept | Where it lives | What it holds |
|---------|----------------|---------------|
| Scenario | `tests/scenarios/<name>/scenario.md` | The problem brief handed to the release |
| Expectation | `tests/scenarios/<name>/expected.json` | Required domains, required concepts, minimum blocking count, expected verdict |
| Result schema | `tests/scenarios/result.schema.json` | The structured shape a run must return |
| Baseline | `tests/scenarios/<name>/baseline-<version>.json` | A captured set of runs for one release |

## Subcommands

```bash
codeops_eval.py run     --plugin <dir> --scenario <dir> --runs N --out <file>
codeops_eval.py score   --scenario <dir> --result <file> [--no-domains]
codeops_eval.py compare --scenario <dir> <baseline.json> <candidate.json>
```

Only `run` invokes a model, so only `run` costs tokens. `score` and `compare` are pure functions
over stored JSON — they need no network and are covered by the test suite.

### Selecting a release by path

`run` passes `--plugin-dir` straight through to the CLI, so a release is chosen by **path**, not by
what happens to be installed:

```bash
python scripts/codeops_eval.py run \
  --plugin ~/.claude/plugins/marketplaces/codeops-marketplace \
  --scenario tests/scenarios/compiler \
  --runs 3 --out tests/scenarios/compiler/baseline-3.12.0.json
```

A candidate can therefore be measured before it is merged, and the installed plugin is never
mutated to take a reading.

The release directory is also passed as `--add-dir`, because a run works from the scenario
directory and would otherwise be unable to read the release's own reference material. That failure
is silent: the run answers from general knowledge and returns a well-formed, plausible result. Any
change to how a run is invoked invalidates existing captures — re-take the baseline rather than
comparing across rigs.

## Scoring

`score` applies four independent checks and reports every failure by name, rather than collapsing
them into one number:

| Check | Passes when |
|-------|-------------|
| Required domains | Every required domain appears in the run's selection. Skip with `--no-domains` for a release predating domain selection, which cannot satisfy it by construction |
| Blocking volume | The run's blocking-ambiguity count reaches the scenario's minimum |
| Concept coverage | For each required concept, at least half its words appear somewhere in the run's questions and impacts |
| Gate verdict | The run's verdict matches the expected one |

Matching is set overlap over `[a-z0-9]+` tokens against a fixed threshold — no fuzzy similarity, no
embeddings, no model in the loop. The same input always yields the same verdict, which is what lets
the oracle be used as a gate.

## Comparing two releases

`compare` reports a regression when any of three signals moves the wrong way:

1. **A required concept covered by the baseline is no longer covered** — however many questions the
   candidate asked in total.
2. **The expected verdict is reached less often** than it was.
3. **The median blocking count falls below the baseline's lowest observed run.**

The first two admit no tolerance: they are what the harness is for. The third is noise-tolerant,
because volume is the only metric that varies materially between runs of the same release.

## The oracle saturates

Each check is pass/fail, so a scenario a release already handles well scores 3/3 and cannot score
higher. On a strong release most scenarios sit at that ceiling, and the harness stops being able
to see improvement — it can only see damage.

Two consequences worth planning around:

- **Frame a comparison as "no regression, and improvement where there is headroom."** A criterion
  demanding improvement everywhere is unsatisfiable against a saturated baseline, and failing it
  says nothing about the change.
- **A regression claim needs more runs than a no-change claim.** At three runs per side, one run
  flipping moves a scenario between 3/3 and 2/3. If the run-to-run spread in blocking count is
  wider than the difference being claimed, the claim is noise. Six runs per side is the working
  minimum before calling something a regression.

The durable fix is scenarios with real headroom, not a looser threshold.

## Running it honestly

- **Two successful runs minimum.** A median over one run is not a measurement, and the harness
  refuses to report one.
- **One retry per run.** A run that fails twice is excluded and reported — never replaced by a
  partial result and never silently substituted.
- **Never in CI.** It invokes a model and costs tokens, so it is run deliberately, by a person who
  intends to spend them.

## Test suites

```bash
./scripts/pytest-check.sh
```

The specification suite (`tests/test_codeops_eval_spec.py`) fixes what the harness must conclude;
the implementation suite (`tests/test_codeops_eval_impl.py`) covers how it gets there. Both run
without a model. `pytest-check.sh` prints a skip notice and exits 0 when pytest is not installed,
so the Bash verify chain stays usable without a development environment.
