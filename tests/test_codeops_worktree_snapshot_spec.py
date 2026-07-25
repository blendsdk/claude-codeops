"""Specification tests for the worktree phase snapshot.

These expectations come from the snapshot specification alone. They are an immutable oracle: if
the implementation disagrees with a test here, the implementation is wrong.

The suite builds real git repositories rather than mocking git. The whole point of the engine is
that it reads git correctly in states a commit-range diff cannot see, and a mocked git would only
prove that the mock agrees with the implementation's idea of git.
"""

import os
import subprocess

import pytest

import codeops_worktree_snapshot as wts


# A commit that cannot exist in a fresh fixture repository. Well-formed, so a caller cannot claim
# the rejection was only shape validation.
ABSENT_COMMIT = "0" * 39 + "1"


def git(repo, *args, check=True):
    """Run one git command in `repo`, isolated from the developer's own git configuration."""
    env = dict(os.environ)
    env["GIT_CONFIG_GLOBAL"] = os.devnull
    env["GIT_CONFIG_SYSTEM"] = os.devnull
    return subprocess.run(
        [
            "git",
            "-C",
            str(repo),
            "-c",
            "user.name=CodeOps Test",
            "-c",
            "user.email=test@example.invalid",
            "-c",
            "commit.gpgsign=false",
            "-c",
            "core.hooksPath=" + os.devnull,
            *args,
        ],
        capture_output=True,
        text=True,
        check=check,
    )


def write(repo, relpath, text):
    """Write a text file into the repository, creating parent directories as needed."""
    target = repo / relpath
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text)
    return target


def commit(repo, message):
    """Stage everything and commit it."""
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "-m", message)


def new_repo(tmp_path, name="repo"):
    """Create a repository with one baseline commit and return it with its phase-start ref."""
    repo = tmp_path / name
    repo.mkdir()
    git(repo, "init", "-q", "-b", "main")
    write(repo, "a.txt", "alpha 1\n")
    write(repo, "b.txt", "bravo 1\n")
    write(repo, "c.txt", "charlie 1\n")
    commit(repo, "baseline")
    return repo, git(repo, "rev-parse", "HEAD").stdout.strip()


def by_path(snap):
    """Index a snapshot's changes by path, so a test can assert on one without ordering games."""
    return {change.path: change for change in snap.changes}


# ---------------------------------------------------------------------------------------------
# ST-5.1 — a phase creating only untracked new files, in --no-commit mode.
# This is the blind spot the engine exists to close: nothing is committed, nothing is staged, and
# a commit-range diff sees an empty phase.
# ---------------------------------------------------------------------------------------------
def test_untracked_new_files_are_captured_with_their_content(tmp_path):
    repo, ref = new_repo(tmp_path)
    write(repo, "src/engine.py", "def run():\n    return 1\n")
    write(repo, "src/helper.py", "HELPER = 2\n")

    snap = wts.snapshot(repo, ref)

    changes = by_path(snap)
    assert set(changes) == {"src/engine.py", "src/helper.py"}
    assert changes["src/engine.py"].kind == "added"
    assert "def run():" in changes["src/engine.py"].content
    assert "HELPER = 2" in changes["src/helper.py"].content


# ---------------------------------------------------------------------------------------------
# ST-5.2 — the identical phase under all three commit modes yields the identical change set.
# Commit mode decides when work is recorded, never what gets reviewed.
# ---------------------------------------------------------------------------------------------
def apply_phase(repo):
    """Apply one logical phase: a modification, a new file, and a deletion."""
    write(repo, "a.txt", "alpha 1\nalpha 2\n")
    write(repo, "new/module.py", "VALUE = 42\n")
    (repo / "c.txt").unlink()


def comparable(snap):
    """Reduce a snapshot to the facts a reviewer acts on, discarding nothing that matters."""
    return [(c.path, c.kind, c.content, c.binary) for c in snap.changes]


def test_change_set_is_identical_in_all_three_commit_modes(tmp_path):
    snapshots = {}
    for mode in ("no-commit", "ask-commit", "auto-commit"):
        repo, ref = new_repo(tmp_path, name=mode)
        apply_phase(repo)
        if mode in ("ask-commit", "auto-commit"):
            git(repo, "add", "-A")
        if mode == "auto-commit":
            git(repo, "commit", "-q", "-m", "phase work")
        snapshots[mode] = wts.snapshot(repo, ref)

    assert comparable(snapshots["no-commit"]) == comparable(snapshots["ask-commit"])
    assert comparable(snapshots["no-commit"]) == comparable(snapshots["auto-commit"])
    assert {c.path for c in snapshots["no-commit"].changes} == {"a.txt", "c.txt", "new/module.py"}


# ---------------------------------------------------------------------------------------------
# ST-5.3 — git-ignored paths never enter a review packet.
# Build output and the git-ignored planning trees are not phase deliverables, and a packet padded
# with them buries the code the reviewer was dispatched to read.
# ---------------------------------------------------------------------------------------------
def test_git_ignored_output_is_absent_from_the_snapshot(tmp_path):
    repo = tmp_path / "ignored"
    repo.mkdir()
    git(repo, "init", "-q", "-b", "main")
    write(repo, ".gitignore", "build/\n*.log\n")
    write(repo, "a.txt", "alpha 1\n")
    commit(repo, "baseline")
    ref = git(repo, "rev-parse", "HEAD").stdout.strip()

    write(repo, "src/real.py", "REAL = True\n")
    write(repo, "build/bundle.js", "console.log('generated')\n")
    write(repo, "debug.log", "noise\n")

    snap = wts.snapshot(repo, ref)

    assert set(by_path(snap)) == {"src/real.py"}


# ---------------------------------------------------------------------------------------------
# ST-5.4 — the engine is read-only with respect to git state.
# A reviewer's view is never purchased with a risk to the user's uncommitted work.
# ---------------------------------------------------------------------------------------------
def git_state(repo):
    """Everything a mutation would disturb: worktree status, refs, and the reflog."""
    return (
        git(repo, "status", "--porcelain=v2", "--branch", "--untracked-files=all").stdout,
        git(repo, "for-each-ref").stdout,
        (repo / ".git" / "logs" / "HEAD").read_bytes(),
        (repo / ".git" / "index").read_bytes(),
    )


def test_snapshot_leaves_git_state_byte_identical(tmp_path):
    repo, ref = new_repo(tmp_path)
    write(repo, "a.txt", "alpha 1\nalpha 2\n")
    write(repo, "untracked.py", "X = 1\n")
    git(repo, "add", "b.txt")

    before = git_state(repo)
    wts.snapshot(repo, ref)
    after = git_state(repo)

    assert before == after


# ---------------------------------------------------------------------------------------------
# ST-5.5 — output is bounded, and truncation is stated rather than silent.
# A packet that quietly drops half a phase reads as "the reviewer saw everything" when it did not.
# ---------------------------------------------------------------------------------------------
def test_oversized_change_set_is_truncated_and_says_what_was_omitted(tmp_path):
    repo, ref = new_repo(tmp_path)
    for index in range(20):
        write(repo, f"generated/file_{index:02d}.txt", "x" * 400 + "\n")

    snap = wts.snapshot(repo, ref, max_bytes=1200)

    assert snap.truncated is True
    assert snap.omissions, "a truncated snapshot must enumerate what it dropped"
    omitted_paths = {omission.path for omission in snap.omissions}
    included_paths = set(by_path(snap))
    assert omitted_paths & included_paths == set(), "a path is either included or omitted"
    assert len(omitted_paths | included_paths) == 20

    rendered = snap.render()
    for omission in snap.omissions:
        assert omission.path in rendered
        assert omission.reason
        assert omission.reason in rendered


def test_a_complete_snapshot_is_not_marked_truncated(tmp_path):
    repo, ref = new_repo(tmp_path)
    write(repo, "small.py", "SMALL = 1\n")

    snap = wts.snapshot(repo, ref, max_bytes=1_000_000)

    assert snap.truncated is False
    assert snap.omissions == ()


# ---------------------------------------------------------------------------------------------
# ST-5.6 — failure is loud, and never degrades into a partial diff.
# Reviewing less than claimed is worse than not reviewing: it produces a clean report on unseen
# code, which is indistinguishable from a real pass.
# ---------------------------------------------------------------------------------------------
def test_an_unresolvable_phase_ref_raises_rather_than_returning_a_partial_snapshot(tmp_path):
    repo, _ = new_repo(tmp_path)

    with pytest.raises(wts.InvalidRefError):
        wts.snapshot(repo, ABSENT_COMMIT)


def test_a_path_outside_a_repository_raises(tmp_path):
    plain = tmp_path / "not-a-repo"
    plain.mkdir()
    (plain / "a.txt").write_text("alpha\n")

    with pytest.raises(wts.NotARepositoryError):
        wts.snapshot(plain, "HEAD")


def test_every_snapshot_failure_is_one_error_family(tmp_path):
    assert issubclass(wts.InvalidRefError, wts.SnapshotError)
    assert issubclass(wts.NotARepositoryError, wts.SnapshotError)


def test_the_command_line_reports_a_blocker_and_emits_no_packet(tmp_path, capsys):
    repo, _ = new_repo(tmp_path)

    status = wts.main(["--repo", str(repo), "--phase-ref", ABSENT_COMMIT])

    captured = capsys.readouterr()
    assert status != 0
    assert captured.out == "", "a failed snapshot must not emit a partial packet"
    assert "BLOCKER" in captured.err


# ---------------------------------------------------------------------------------------------
# ST-5.7 — a binary file is listed as changed without content, and does not abort the snapshot.
# ---------------------------------------------------------------------------------------------
def test_binary_files_are_listed_without_content_and_the_snapshot_completes(tmp_path):
    repo, ref = new_repo(tmp_path)
    (repo / "asset.bin").write_bytes(b"\x00\x01\x02binary\x00payload")
    write(repo, "src/real.py", "REAL = True\n")

    snap = wts.snapshot(repo, ref)

    changes = by_path(snap)
    assert set(changes) == {"asset.bin", "src/real.py"}
    assert changes["asset.bin"].binary is True
    assert changes["asset.bin"].content is None
    assert changes["src/real.py"].binary is False
    assert "REAL = True" in changes["src/real.py"].content


# ---------------------------------------------------------------------------------------------
# ST-5.8 — one snapshot carries all four sources at once.
# ---------------------------------------------------------------------------------------------
def test_committed_staged_unstaged_and_untracked_appear_in_one_snapshot(tmp_path):
    repo, ref = new_repo(tmp_path)

    write(repo, "a.txt", "alpha 1\nalpha committed\n")
    commit(repo, "committed part of the phase")

    write(repo, "b.txt", "bravo 1\nbravo staged\n")
    git(repo, "add", "b.txt")

    write(repo, "c.txt", "charlie 1\ncharlie unstaged\n")

    write(repo, "d.txt", "delta untracked\n")

    snap = wts.snapshot(repo, ref)

    changes = by_path(snap)
    assert set(changes) == {"a.txt", "b.txt", "c.txt", "d.txt"}
    assert "alpha committed" in changes["a.txt"].content
    assert "bravo staged" in changes["b.txt"].content
    assert "charlie unstaged" in changes["c.txt"].content
    assert "delta untracked" in changes["d.txt"].content
    assert changes["d.txt"].kind == "added"
