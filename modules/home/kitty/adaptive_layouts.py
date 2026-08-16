"""Adapt Kitty layouts to the aspect ratio of each OS window.

Loaded as a global Kitty watcher. The ratio comes from the enclosing OS window's
pixel dimensions rather than from an individual terminal pane, so moving a
maximized Kitty window between portrait and landscape displays updates every tab
in that OS window.
"""

from __future__ import annotations

import json
from typing import Any

from kitty.boss import Boss
from kitty.fast_data_types import get_os_window_size
from kitty.window import Window


PORTRAIT_LAYOUTS = tuple(json.loads(r'''@portrait_layouts_json@'''))
LANDSCAPE_LAYOUTS = tuple(json.loads(r'''@landscape_layouts_json@'''))
_APPLYING: set[int] = set()


def layouts_for(window: Window) -> tuple[str, ...] | None:
    """Return the profile selected by the enclosing OS window's pixel ratio."""
    metrics = get_os_window_size(window.os_window_id)
    if metrics is None:
        return None

    try:
        width = int(metrics["width"])
        height = int(metrics["height"])
    except (KeyError, TypeError, ValueError):
        return None

    if width <= 0 or height <= 0:
        return None

    return PORTRAIT_LAYOUTS if height > width else LANDSCAPE_LAYOUTS


def on_resize(boss: Boss, window: Window, data: dict[str, Any]) -> None:
    """Apply the profile to every tab in the resized OS window."""
    del data

    os_window_id = window.os_window_id
    if os_window_id in _APPLYING:
        return

    layouts = layouts_for(window)
    if layouts is None:
        return

    tab_manager = boss.os_window_map.get(os_window_id)
    if tab_manager is None:
        return

    tabs_to_update = [
        tab
        for tab in tab_manager.tabs
        if tuple(tab.enabled_layouts) != layouts
    ]
    if not tabs_to_update:
        return

    # Changing a layout can resize panes and synchronously invoke this watcher
    # again. Guard that re-entrant path, then let later resize events verify the
    # profile normally.
    _APPLYING.add(os_window_id)
    try:
        for tab in tabs_to_update:
            tab.set_enabled_layouts(layouts)
    finally:
        _APPLYING.discard(os_window_id)
