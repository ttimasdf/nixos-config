"""Back up and restore Kitty sessions across all discoverable Kitty servers."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import datetime
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
from typing import Sequence


KITTY = "@kitty@"
SOCKET_PREFIX = "kitty-rc-"
SESSION_SUFFIX = ".kitty-session"


@dataclass(frozen=True)
class SnapshotInfo:
    """A saved session and the Kitty window topology it contains."""

    path: Path
    windows: int
    tabs: int

    @property
    def name(self) -> str:
        return self.path.name.removesuffix(SESSION_SUFFIX)

    @property
    def label(self) -> str:
        return f"{self.name}, {self.windows} windows, {self.tabs} tabs"


def session_directory() -> Path:
    """Return the fixed XDG state directory used for session snapshots."""
    state_home = os.environ.get("XDG_STATE_HOME")
    if state_home:
        return Path(state_home) / "kitty" / "sessions"
    return Path.home() / ".local" / "state" / "kitty" / "sessions"


def snapshot_path(name: str) -> Path:
    """Resolve one user-supplied snapshot name inside the fixed snapshot directory."""
    if not name or name in {".", "..", SESSION_SUFFIX}:
        raise RuntimeError("Snapshot name must be a non-empty filename")
    if name.startswith("-") or Path(name).is_absolute() or Path(name).name != name:
        raise RuntimeError("Snapshot name must be a filename in the Kitty session directory")

    filename = name if name.endswith(SESSION_SUFFIX) else f"{name}{SESSION_SUFFIX}"
    return session_directory() / filename


def default_snapshot_path() -> Path:
    timestamp = datetime.now().astimezone().strftime("%Y%m%d-%H%M%S-%f")
    return session_directory() / f"{timestamp}{SESSION_SUFFIX}"


def snapshot_paths() -> list[Path]:
    """List snapshots newest-first, ignoring files that disappear mid-scan."""
    directory = session_directory()
    try:
        entries = tuple(directory.glob(f"*{SESSION_SUFFIX}"))
    except OSError as error:
        raise RuntimeError(f"Cannot inspect {directory}: {error}") from error

    snapshots: list[tuple[float, Path]] = []
    for path in entries:
        try:
            if path.is_file():
                snapshots.append((path.stat().st_mtime, path))
        except OSError:
            continue
    return [path for _, path in sorted(snapshots, key=lambda item: item[0], reverse=True)]


def snapshot_info(path: Path) -> SnapshotInfo:
    """Read the tab and terminal-window counts from a Kitty session file."""
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise RuntimeError(f"Cannot read {path}: {error}") from error

    windows = 0
    tabs = 0
    os_windows = 1
    for raw_line in lines:
        line = raw_line.strip()
        command = line.split(maxsplit=1)[0] if line else ""
        if command == "launch":
            windows += 1
        elif command == "new_tab":
            tabs += 1
        elif command == "new_os_window":
            os_windows += 1

    # Kitty's serialized sessions always include new_tab, but retain sensible
    # counts for a hand-written session with only the implicit first tab.
    if tabs == 0 and windows:
        tabs = os_windows
    return SnapshotInfo(path, windows, tabs)


def available_snapshots() -> list[SnapshotInfo]:
    """Load usable snapshots while leaving a corrupt file visible as a warning."""
    snapshots: list[SnapshotInfo] = []
    for path in snapshot_paths():
        try:
            snapshots.append(snapshot_info(path))
        except RuntimeError as error:
            print(f"warning: skipped {path.name}: {error}", file=sys.stderr)
    return snapshots


def discover_sockets() -> list[Path]:
    """Find Kitty remote-control sockets in the current user session."""
    runtime_home = os.environ.get("XDG_RUNTIME_DIR")
    if not runtime_home:
        raise RuntimeError("XDG_RUNTIME_DIR is not set, so Kitty sockets cannot be discovered")

    runtime_dir = Path(runtime_home)
    try:
        entries = tuple(runtime_dir.iterdir())
    except OSError as error:
        raise RuntimeError(f"Cannot inspect {runtime_dir}: {error}") from error

    sockets: list[Path] = []
    for path in entries:
        if not path.name.startswith(SOCKET_PREFIX):
            continue
        try:
            if stat.S_ISSOCK(path.stat().st_mode):
                sockets.append(path)
        except OSError:
            # A Kitty process can exit between listing the directory and stat().
            continue
    return sorted(sockets)


def session_from_socket(socket: Path) -> str:
    """Ask one Kitty server to serialize every OS window it owns."""
    result = subprocess.run(
        [
            KITTY,
            "@",
            "--to",
            f"unix:{socket}",
            "ls",
            "--output-format=session",
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        detail = result.stderr.strip() or result.stdout.strip()
        if not detail:
            detail = f"kitty exited with status {result.returncode}"
        raise RuntimeError(detail)
    return result.stdout.rstrip()


def write_snapshot(target: Path, sessions: Sequence[tuple[Path, str]]) -> None:
    """Atomically write combined per-server sessions as one Kitty session file."""
    try:
        target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        file_descriptor, temporary_name = tempfile.mkstemp(
            dir=target.parent,
            prefix=f".{target.name}.",
        )
    except OSError as error:
        raise RuntimeError(f"Cannot create snapshot in {target.parent}: {error}") from error

    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(file_descriptor, "w", encoding="utf-8") as output:
            os.fchmod(output.fileno(), 0o600)
            output.write("# Generated by kitty-session backup.\n")
            output.write("# Restore with: kitty-session restore [snapshot-name]\n")

            for index, (socket, session) in enumerate(sessions):
                if index:
                    # Each server serializes its first OS window without this
                    # marker. Add one when joining independently running servers.
                    output.write("\nnew_os_window\n")
                output.write(f"\n# Source socket: {socket}\n")
                output.write(session)
                output.write("\n")

        os.replace(temporary_path, target)
        os.chmod(target, 0o600)
    except BaseException:
        temporary_path.unlink(missing_ok=True)
        raise


def backup(name: str | None, force: bool, best_effort: bool) -> int:
    target = snapshot_path(name) if name else default_snapshot_path()
    if target.exists() and not force:
        raise RuntimeError(f"Refusing to overwrite existing snapshot: {target.name} (use --force to replace it)")

    sockets = discover_sockets()
    if not sockets:
        raise RuntimeError(
            "No Kitty remote-control sockets were found. Start Kitty after activating this configuration."
        )

    sessions: list[tuple[Path, str]] = []
    failures: list[tuple[Path, str]] = []
    for socket in sockets:
        try:
            session = session_from_socket(socket)
        except RuntimeError as error:
            failures.append((socket, str(error)))
            continue
        if session:
            sessions.append((socket, session))

    if failures and not best_effort:
        details = "\n".join(f"  {socket}: {error}" for socket, error in failures)
        raise RuntimeError(
            "Could not back up every discovered Kitty server:\n"
            f"{details}\n"
            "Restart Kitty after activating this configuration, then try again. "
            "Use --best-effort only when omitting inaccessible servers is acceptable."
        )
    if not sessions:
        raise RuntimeError("No Kitty server returned a session to save")

    write_snapshot(target, sessions)
    for socket, error in failures:
        print(f"warning: omitted {socket}: {error}", file=sys.stderr)
    print(f"Saved {len(sessions)} Kitty server session(s) as {target.name}")
    return 0


def select_snapshot(snapshots: Sequence[SnapshotInfo]) -> Path | None:
    """Use fzf to select a snapshot from the same display format as list."""
    choices = {snapshot.label: snapshot.path for snapshot in snapshots}
    if not choices:
        raise RuntimeError(f"No snapshots found in {session_directory()}")

    try:
        result = subprocess.run(
            [
                "fzf",
                "--height=40%",
                "--layout=reverse",
                "--border",
                "--prompt=Kitty session > ",
            ],
            input="\n".join(choices) + "\n",
            check=False,
            stdout=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError as error:
        raise RuntimeError("Interactive restore requires fzf") from error

    if result.returncode in {1, 130}:
        return None
    if result.returncode:
        raise RuntimeError(f"fzf exited with status {result.returncode}")

    selected = result.stdout.rstrip("\n")
    return choices.get(selected)


def restore(name: str | None) -> int:
    source = snapshot_path(name) if name else select_snapshot(available_snapshots())
    if source is None:
        return 0
    if not source.is_file():
        raise RuntimeError(f"Snapshot does not exist: {source.name}")

    # Restore intentionally leaves existing Kitty OS windows alone. The session
    # starts a fresh Kitty process and recreates the saved OS-window/tab/pane tree.
    subprocess.Popen([KITTY, "--session", str(source)], start_new_session=True)
    print(f"Started Kitty restore from {source.name}")
    return 0


def list_snapshots() -> int:
    for snapshot in available_snapshots():
        print(snapshot.label)
    return 0


def complete_snapshot_names(prefix: str) -> int:
    for path in snapshot_paths():
        if path.name.startswith(prefix):
            print(path.name)
    return 0


def parse_arguments(arguments: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Back up and restore Kitty sessions from one fixed XDG state directory.",
    )
    subcommands = parser.add_subparsers(dest="command", required=True)

    backup_parser = subcommands.add_parser("backup", help="write a session snapshot")
    backup_parser.add_argument("name", nargs="?", help="snapshot filename in the session directory")
    backup_parser.add_argument("--force", action="store_true", help="replace an existing snapshot")
    backup_parser.add_argument(
        "--best-effort",
        action="store_true",
        help="save accessible servers even if another Kitty socket cannot be queried",
    )

    restore_parser = subcommands.add_parser("restore", help="select and open a saved session")
    restore_parser.add_argument("name", nargs="?", help="snapshot filename in the session directory")

    subcommands.add_parser("list", help="list saved sessions and their window/tab counts")
    return parser.parse_args(arguments)


def main(arguments: Sequence[str] | None = None) -> int:
    raw_arguments = list(arguments) if arguments is not None else sys.argv[1:]
    try:
        if raw_arguments[:2] == ["__complete", "restore"] and len(raw_arguments) <= 3:
            return complete_snapshot_names(raw_arguments[2] if len(raw_arguments) == 3 else "")

        args = parse_arguments(raw_arguments)
        if args.command == "backup":
            return backup(args.name, args.force, args.best_effort)
        if args.command == "restore":
            return restore(args.name)
        return list_snapshots()
    except RuntimeError as error:
        print(f"kitty-session: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
