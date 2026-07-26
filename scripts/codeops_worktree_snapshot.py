#!/usr/bin/env python3
"""Worktree phase snapshot — the complete change set a phase produced, in any commit mode.

CodeOps Skills Version: 3.19.0

A review packet built from a commit range sees only what has been committed. When a phase runs
without committing, that range is empty or partial, and a reviewer handed it reports clean on code
it never received — a false pass that is indistinguishable from a real one. Newly created files
are the worst case, because they are frequently the entire deliverable of a phase.

This engine composes the change set between a phase-start ref and the current worktree, covering
all four states a phase can leave work in: committed, staged, unstaged, and untracked-but-new.

Two properties make it safe to run against someone's live working tree:

* **Read-only.** Every git invocation runs against a throwaway copy of the index, so no command
  can stage, refresh, or lock the real one. A reviewer's view is never bought with a risk to
  uncommitted work.
* **Loud.** Anything that prevents a complete snapshot raises. There is no partial result, because
  a partial packet presented as a whole one is the failure this engine exists to prevent.

Output is normalized per path rather than concatenated per source, which is what makes it
identical in every commit mode: whether a change is committed, staged, or merely written to disk
changes when it was recorded, never what it is.

@example
    snap = snapshot(repo_root, phase_start_ref)
    if snap.truncated:
        print(f"{len(snap.omissions)} change(s) omitted from the packet")
    print(snap.render())
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

# Budgets for one review packet. A reviewer reads a packet; it is not an archive. These bound what
# is included so a phase touching a thousand files degrades into an honest, explicit truncation
# rather than an unreadable wall of text.
DEFAULT_MAX_BYTES = 512_000
DEFAULT_MAX_FILE_BYTES = 64_000
DEFAULT_MAX_FILES = 200

# A ref is passed straight to git as an argument. Refusing anything outside this set — and any
# leading dash — keeps a ref from being read as a git option, which is the one way a caller-
# supplied string could change what the command does rather than what it operates on.
REF_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/^~@{}-]*$")

# git's --name-status letters, mapped to the vocabulary a reviewer reads. Renames and copies are
# switched off at the call site so this table stays total.
STATUS_KINDS = {"A": "added", "M": "modified", "D": "deleted", "T": "modified"}


class SnapshotError(Exception):
    """A condition that must stop a snapshot rather than yield a partial one."""


class NotARepositoryError(SnapshotError):
    """The given path is not inside a git repository."""


class InvalidRefError(SnapshotError):
    """The phase-start ref does not resolve to a commit in this repository."""


@dataclass(frozen=True)
class Change:
    """One path's net change between the phase-start ref and the current worktree."""

    path: str
    kind: str
    content: str | None
    binary: bool
    size: int
    note: str | None = None


@dataclass(frozen=True)
class Omission:
    """One change left out of the packet, with the bound that excluded it."""

    path: str
    reason: str
    size: int


@dataclass(frozen=True)
class Snapshot:
    """The change set for one phase, bounded and self-describing."""

    phase_ref: str
    changes: tuple[Change, ...]
    omissions: tuple[Omission, ...]
    truncated: bool

    def paths(self) -> tuple[str, ...]:
        """Every path included in the packet, in the order it is rendered."""
        return tuple(change.path for change in self.changes)

    def render(self) -> str:
        """Format the packet for a reviewer, stating any omission rather than hiding it.

        Two choices here are about trust rather than layout. The summary and the omission list
        come first, before any file content, so a reviewer has the authoritative counts before
        reading anything the repository wrote. And every file's content is fenced with a fence
        longer than any run of backticks inside it, so a file cannot close its own block and
        continue as if it were packet structure. Repository content is data in this packet, and
        it is presented as data.
        """
        lines = [
            "# Phase snapshot",
            "",
            f"Phase ref: {self.phase_ref}",
            f"Changes included: {len(self.changes)}",
            f"Changes omitted: {len(self.omissions)}",
            "",
        ]
        if self.omissions:
            lines.append("## Omitted from this packet")
            lines.append("")
            lines.append(
                "These changes are part of the phase but exceeded the packet bounds. "
                "They were NOT reviewed."
            )
            lines.append("")
            for omission in self.omissions:
                lines.append(f"- {omission.path} — {omission.reason}")
            lines.append("")
        for change in self.changes:
            lines.append(f"## {change.kind}: {change.path}")
            lines.append("")
            if change.content is None:
                lines.append(f"({change.note or 'content not included'})")
            else:
                fence = "`" * max(3, len(max(re.findall(r"`+", change.content), key=len, default="")) + 1)
                lines.extend([fence, change.content.rstrip("\n"), fence])
            lines.append("")
        return "\n".join(lines)


def _git_env(index_file: Path) -> dict[str, str]:
    """Build the environment every git call runs under.

    The index copy is the whole read-only guarantee: git may refresh and rewrite the index it is
    pointed at, and pointing it at a throwaway means it can never rewrite the user's.
    """
    env = dict(os.environ)
    env["GIT_INDEX_FILE"] = str(index_file)
    env["GIT_OPTIONAL_LOCKS"] = "0"
    return env


def _git(repo: Path, env: dict[str, str], *args: str) -> bytes:
    """Run one git command and return its stdout, raising if it fails."""
    command = ["git", "-C", str(repo), "-c", "core.quotePath=false", *args]
    try:
        completed = subprocess.run(command, capture_output=True, env=env, check=False)
    except OSError as exc:  # git missing, or not executable
        raise SnapshotError(f"could not run git: {exc}") from exc
    if completed.returncode != 0:
        detail = completed.stderr.decode("utf-8", "replace").strip()
        raise SnapshotError(f"git {' '.join(args)} failed: {detail or 'no detail'}")
    return completed.stdout


def _split_z(payload: bytes) -> list[str]:
    """Split a NUL-delimited git listing, dropping the trailing empty field."""
    return [field.decode("utf-8", "replace") for field in payload.split(b"\0") if field]


def _resolve_repo(repo: Path | str) -> tuple[Path, Path]:
    """Return the repository root and its git directory, or explain why it is not a repository."""
    candidate = Path(repo).expanduser()
    try:
        candidate = candidate.resolve(strict=True)
    except OSError as exc:
        raise NotARepositoryError(f"{repo}: {exc.strerror or exc}") from exc
    probe = subprocess.run(
        ["git", "-C", str(candidate), "rev-parse", "--absolute-git-dir", "--show-toplevel"],
        capture_output=True,
        check=False,
    )
    if probe.returncode != 0:
        raise NotARepositoryError(f"{candidate} is not inside a git repository")
    # git reports every path relative to the worktree root, so the root is what the rest of the
    # engine must read against — being handed a subdirectory would otherwise silently resolve
    # each reported path against the wrong directory.
    lines = [line for line in probe.stdout.decode("utf-8", "replace").splitlines() if line.strip()]
    if len(lines) < 2:
        # A bare repository answers with a git directory and no worktree. There is nothing to
        # snapshot there, and reporting that is better than guessing at a root.
        raise NotARepositoryError(f"{candidate} has no working tree to snapshot")
    return Path(lines[1].strip()), Path(lines[0].strip())


def _verify_ref(repo: Path, env: dict[str, str], phase_ref: str) -> str:
    """Resolve the phase-start ref to a commit, refusing anything that is not one."""
    if not REF_PATTERN.match(phase_ref):
        raise InvalidRefError(f"{phase_ref!r} is not a well-formed git ref")
    resolved = subprocess.run(
        ["git", "-C", str(repo), "rev-parse", "--verify", "--quiet", f"{phase_ref}^{{commit}}"],
        capture_output=True,
        env=env,
        check=False,
    )
    if resolved.returncode != 0 or not resolved.stdout.strip():
        raise InvalidRefError(f"{phase_ref} does not resolve to a commit in {repo}")
    return resolved.stdout.decode("utf-8", "replace").strip()


def _tracked_changes(repo: Path, env: dict[str, str], phase_ref: str) -> dict[str, str]:
    """Map each tracked path to its net change kind against the ref.

    One diff of the ref against the worktree covers committed, staged, and unstaged work at once,
    and yields the same answer however that work was recorded. Renames are switched off so the
    output is a total function of content rather than of a similarity heuristic.
    """
    payload = _git(repo, env, "diff", "--name-status", "--no-renames", "-z", phase_ref, "--")
    fields = _split_z(payload)
    changes: dict[str, str] = {}
    for status, path in zip(fields[::2], fields[1::2]):
        kind = STATUS_KINDS.get(status[0])
        if kind is not None:
            changes[path] = kind
    return changes


def _untracked_paths(repo: Path, env: dict[str, str]) -> list[str]:
    """List files git does not track and does not ignore.

    `--exclude-standard` is what keeps build output, dependency trees, and any other ignored path
    out of a review packet: they are not phase deliverables, and a packet padded with them buries
    the code the reviewer was dispatched to read.
    """
    return _split_z(_git(repo, env, "ls-files", "--others", "--exclude-standard", "-z"))


def _read_worktree_file(repo: Path, path: str) -> Change:
    """Read a file as packet payload, listing anything content-free with the reason why.

    An unreadable file is reported rather than fatal. One broken symlink or one directory-shaped
    entry is not a reason to deny the reviewer the rest of the phase.
    """
    try:
        data = (repo / path).read_bytes()
    except OSError as exc:
        reason = exc.strerror or str(exc)
        return Change(path, "added", None, False, 0, note=f"unreadable — {reason}")
    if b"\0" in data:
        return Change(path, "added", None, True, 0, note="binary")
    return Change(path, "added", data.decode("utf-8", "replace"), False, len(data))


def _build_change(repo: Path, env: dict[str, str], phase_ref: str, path: str, kind: str) -> Change:
    """Produce one path's packet entry."""
    if kind == "deleted":
        return Change(path, kind, None, False, 0, note="deleted")
    if kind == "added":
        return _read_worktree_file(repo, path)
    payload = _git(repo, env, "diff", "--no-renames", phase_ref, "--", path)
    text = payload.decode("utf-8", "replace")
    if "\0" in text or re.search(r"^Binary files .* differ$", text, re.MULTILINE):
        return Change(path, kind, None, True, 0, note="binary")
    return Change(path, kind, text, False, len(payload))


def _apply_bounds(
    changes: Sequence[Change], max_bytes: int, max_file_bytes: int, max_files: int
) -> tuple[tuple[Change, ...], tuple[Omission, ...]]:
    """Fit the change set inside the packet bounds, naming everything left out.

    Once the total budget is spent, every remaining change is omitted rather than cherry-picking
    whichever ones happen to be small: a packet whose contents depend on file size ordering is
    harder to reason about than one that simply stops, and both must state what was dropped.
    """
    included: list[Change] = []
    omissions: list[Omission] = []
    used = 0
    budget_spent = False
    for change in changes:
        if budget_spent:
            omissions.append(Omission(change.path, "total size bound reached", change.size))
        elif len(included) >= max_files:
            omissions.append(
                Omission(change.path, f"file count bound reached ({max_files} files)", change.size)
            )
        elif change.size > max_file_bytes:
            omissions.append(
                Omission(
                    change.path,
                    f"change exceeds the per-file bound ({max_file_bytes} bytes)",
                    change.size,
                )
            )
        elif used + change.size > max_bytes:
            budget_spent = True
            omissions.append(
                Omission(change.path, f"total size bound reached ({max_bytes} bytes)", change.size)
            )
        else:
            used += change.size
            included.append(change)
    return tuple(included), tuple(omissions)


def snapshot(
    repo: Path | str,
    phase_ref: str,
    *,
    max_bytes: int = DEFAULT_MAX_BYTES,
    max_file_bytes: int = DEFAULT_MAX_FILE_BYTES,
    max_files: int = DEFAULT_MAX_FILES,
) -> Snapshot:
    """Compose the complete change set between `phase_ref` and the current worktree.

    Raises `SnapshotError` — never returns something incomplete — if any part of the change set
    cannot be read.
    """
    root, git_dir = _resolve_repo(repo)
    with tempfile.TemporaryDirectory(prefix="codeops-snapshot-") as scratch:
        index_copy = Path(scratch) / "index"
        real_index = git_dir / "index"
        if real_index.exists():
            shutil.copy2(real_index, index_copy)
        env = _git_env(index_copy)

        resolved_ref = _verify_ref(root, env, phase_ref)
        kinds = _tracked_changes(root, env, phase_ref)
        for path in _untracked_paths(root, env):
            kinds.setdefault(path, "added")

        changes = [
            _build_change(root, env, phase_ref, path, kinds[path]) for path in sorted(kinds)
        ]

    included, omissions = _apply_bounds(changes, max_bytes, max_file_bytes, max_files)
    return Snapshot(
        phase_ref=resolved_ref,
        changes=included,
        omissions=omissions,
        truncated=bool(omissions),
    )


def _parser() -> argparse.ArgumentParser:
    """Build the command-line interface."""
    parser = argparse.ArgumentParser(
        prog="codeops_worktree_snapshot.py",
        description="Print the complete change set for a phase, in any commit mode.",
    )
    parser.add_argument("--repo", default=".", help="repository to snapshot (default: .)")
    parser.add_argument("--phase-ref", required=True, help="commit the phase started from")
    parser.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    parser.add_argument("--max-file-bytes", type=int, default=DEFAULT_MAX_FILE_BYTES)
    parser.add_argument("--max-files", type=int, default=DEFAULT_MAX_FILES)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    """Print a packet on success; on failure print a blocker and print no packet at all."""
    options = _parser().parse_args(argv)
    try:
        snap = snapshot(
            options.repo,
            options.phase_ref,
            max_bytes=options.max_bytes,
            max_file_bytes=options.max_file_bytes,
            max_files=options.max_files,
        )
    except SnapshotError as exc:
        print(f"SNAPSHOT BLOCKER: {exc}", file=sys.stderr)
        return 1
    print(snap.render())
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
