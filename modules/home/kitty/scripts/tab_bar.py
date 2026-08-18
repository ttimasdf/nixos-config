"""Render concise Kitty tab titles for agent and ordinary terminal programs."""

from __future__ import annotations

import os
import unicodedata

from kitty.fast_data_types import get_boss


MAX_COMMAND_LENGTH = 6

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


def truncate(value: str, max_length: int) -> str:
    """Cap text to a display length, using an ellipsis when truncated."""
    if max_length < 1:
        return ""
    if len(value) <= max_length:
        return value
    return f"{value[: max_length - 1]}…"


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

    command = truncate(basename(command_line[0]).lstrip("-"), MAX_COMMAND_LENGTH)
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


MAXIMIZED_GLYPH = "⛶"  # U+26F6 SQUARE FOUR CORNERS, 1 cell wide
AGENT_GLYPH = "⌬"  # U+232C BENZENE RING, 1 cell wide


def is_maximized(tab_id: int) -> bool:
    """Report whether the real tab backing this tab-bar entry uses the stack layout."""
    try:
        # data["tab"] in tab-bar draws is a TabBarData record without layout
        # state, so resolve the live Tab via its id first.
        tab = get_boss().tab_for_id(tab_id)
        return tab.current_layout.name == "stack" if tab else False
    except Exception:
        # A tab can disappear while Kitty redraws its tab bar.
        return False


def draw_title(data: dict[str, object]) -> str:
    """Render an agent status plus folder, or a concise ordinary command line."""
    tab = data["tab"]
    prefix = MAXIMIZED_GLYPH if is_maximized(tab.tab_id) else ""
    folder = basename(tab.active_wd)
    status = agent_status(str(data["title"]).strip())
    if status:
        # Normalize the agent's own status glyph (e.g. π) to a fixed icon.
        title = f"{AGENT_GLYPH}{folder}" if folder else AGENT_GLYPH
    else:
        title = ordinary_title(active_command_line(tab.tab_id)) or folder or str(data["title"])
    return f"{prefix}{title}".strip() if prefix else title
