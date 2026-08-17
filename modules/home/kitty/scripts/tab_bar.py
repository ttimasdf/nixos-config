"""Render concise Kitty tab titles for agent and ordinary terminal programs."""

from __future__ import annotations

import os
import unicodedata

from kitty.fast_data_types import get_boss


INTERACTIVE_SHELLS = frozenset(
    {
        "bash",
        "dash",
        "elvish",
        "fish",
        "ksh",
        "nu",
        "sh",
        "tcsh",
        "xonsh",
        "zsh",
    }
)


def basename(value: str) -> str:
    """Return the final path segment, retaining the filesystem root as `/`."""
    if not value:
        return ""
    trimmed = value.rstrip("/")
    return os.path.basename(trimmed) if trimmed else "/"


def agent_status(title: str) -> str:
    """Extract a symbolic status prefix from titles such as `⏳ - project`."""
    status, separator, _ = title.partition(" - ")
    if separator and any(unicodedata.category(character) in ("So", "Ll") for character in status):
        return status
    return ""


def ordinary_title(command_line: list[str]) -> str:
    """Render the command and its final positional argument."""
    if not command_line:
        return ""

    command = basename(command_line[0]).lstrip("-")
    if command in INTERACTIVE_SHELLS:
        return ""

    argument = next(
        (
            basename(value)
            for value in reversed(command_line[1:])
            if value and not value.startswith("-")
        ),
        "",
    )
    return " ".join(part for part in (command, argument) if part)


def active_command_line(tab_id: int) -> list[str]:
    """Return the foreground command line for a tab's active terminal window."""
    try:
        tab = get_boss().tab_for_id(tab_id)
        window = tab.active_window if tab else None
        return list(window.child.foreground_cmdline) if window else []
    except Exception:
        # A tab or window can disappear while Kitty redraws its tab bar.
        return []


def draw_title(data: dict[str, object]) -> str:
    """Render an agent status plus folder, or a concise ordinary command line."""
    tab = data["tab"]
    folder = basename(tab.active_wd)
    status = agent_status(str(data["title"]).strip())
    if status:
        return f"{status} {folder}"

    title = ordinary_title(active_command_line(tab.tab_id))
    return title or folder or str(data["title"])
