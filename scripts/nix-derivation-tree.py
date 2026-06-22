#!/usr/bin/env python3
"""
nix-derivation-tree: Analyze a Nix derivation closure BEFORE building.

Outputs a self-contained HTML page with:
  - Interactive dependency tree (collapsible, with state/size per node)
  - Duplicate package analysis (same package name, multiple versions)

Usage:
  python3 nix-derivation-tree.py <installable> [--output tree.html] [--open]
  python3 nix-derivation-tree.py nixpkgs#hello
  python3 nix-derivation-tree.py .#nixosConfigurations.viscacha.config.system.build.toplevel
"""

import argparse
import json
import os
import re
import subprocess
import sys
import textwrap
from collections import defaultdict
from pathlib import Path
from typing import Optional

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Nix Derivation Tree — {installable}</title>
<style>
  :root {{
    --bg: #1e1e2e;
    --surface: #313244;
    --overlay: #45475a;
    --text: #cdd6f4;
    --subtext: #a6adc8;
    --blue: #89b4fa;
    --green: #a6e3a1;
    --yellow: #f9e2af;
    --red: #f38ba8;
    --mauve: #cba6f7;
    --peach: #fab387;
    --teal: #94e2d5;
    --border: #585b70;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: var(--bg);
    color: var(--text);
    height: 100vh;
    overflow: hidden;
  }}

  /* Header */
  .header {{
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 12px 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex-shrink: 0;
  }}
  .header h1 {{ font-size: 1.1em; font-weight: 600; }}
  .header .stats {{ color: var(--subtext); font-size: 0.85em; }}
  .header .stats span {{ margin-left: 16px; }}

  /* Tab bar */
  .tabs {{
    display: flex;
    gap: 0;
    background: var(--surface);
    border-bottom: 1px solid var(--border);
    padding: 0 20px;
  }}
  .tab {{
    padding: 10px 20px;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    color: var(--subtext);
    font-size: 0.9em;
    transition: all 0.15s;
  }}
  .tab:hover {{ color: var(--text); }}
  .tab.active {{ color: var(--blue); border-bottom-color: var(--blue); }}

  /* Main layout */
  .main {{ display: flex; height: calc(100vh - 90px); }}
  .panel {{ flex: 1; overflow-y: auto; }}

  /* Tree panel (left) */
  .tree-panel {{
    flex: 1;
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
  }}
  .search-bar {{
    padding: 10px 16px;
    border-bottom: 1px solid var(--border);
    background: var(--surface);
  }}
  .search-bar input {{
    width: 100%;
    padding: 6px 12px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: var(--bg);
    color: var(--text);
    font-size: 0.9em;
    outline: none;
  }}
  .search-bar input:focus {{ border-color: var(--blue); }}
  .tree-content {{ flex: 1; overflow-y: auto; padding: 8px 0; }}

  /* Detail panel (right) */
  .detail-panel {{
    flex: 1;
    padding: 20px;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
  }}
  .detail-empty {{
    color: var(--subtext);
    text-align: center;
    margin-top: 40px;
    font-style: italic;
  }}
  .detail-card {{
    background: var(--surface);
    border-radius: 8px;
    padding: 16px;
    border: 1px solid var(--border);
  }}
  .detail-card h3 {{ font-size: 1em; margin-bottom: 12px; color: var(--blue); }}
  .detail-card .field {{
    display: flex;
    padding: 4px 0;
    font-size: 0.85em;
  }}
  .detail-card .field-label {{
    color: var(--subtext);
    width: 120px;
    flex-shrink: 0;
  }}
  .detail-card .field-value {{ word-break: break-all; }}

  /* Tree nodes */
  .tree-node {{ user-select: none; }}
  .tree-row {{
    display: flex;
    align-items: center;
    padding: 3px 8px;
    cursor: pointer;
    border-radius: 4px;
    margin: 1px 4px;
    font-size: 0.85em;
  }}
  .tree-row:hover {{ background: var(--overlay); }}
  .tree-row.selected {{ background: var(--overlay); border-left: 2px solid var(--blue); }}
  .tree-row .toggle {{
    width: 18px;
    height: 18px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: var(--subtext);
    font-size: 0.7em;
    flex-shrink: 0;
  }}
  .tree-row .toggle.leaf {{ visibility: hidden; }}
  .tree-row .name {{ margin-left: 4px; flex: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }}
  .tree-row .size {{ color: var(--subtext); margin-left: 8px; font-size: 0.8em; white-space: nowrap; }}
  .tree-children {{ margin-left: 18px; }}
  .tree-children.collapsed {{ display: none; }}

  /* State badges */
  .badge {{
    font-size: 0.7em;
    padding: 1px 6px;
    border-radius: 4px;
    font-weight: 600;
    white-space: nowrap;
    margin-left: 6px;
  }}
  .badge.completed {{ background: rgba(166,227,161,0.15); color: var(--green); }}
  .badge.cache-hit {{ background: rgba(249,226,175,0.15); color: var(--yellow); }}
  .badge.pending {{ background: rgba(243,139,168,0.15); color: var(--red); }}
  .badge.source {{ background: rgba(137,180,250,0.15); color: var(--blue); }}

  /* Duplicates table */
  .dup-panel {{ padding: 16px; overflow-y: auto; }}
  .dup-table {{ width: 100%; border-collapse: collapse; font-size: 0.85em; }}
  .dup-table th {{
    text-align: left;
    padding: 8px 12px;
    border-bottom: 2px solid var(--border);
    color: var(--subtext);
    font-weight: 600;
    position: sticky;
    top: 0;
    background: var(--bg);
  }}
  .dup-table td {{ padding: 6px 12px; border-bottom: 1px solid var(--overlay); }}
  .dup-table tr:hover td {{ background: var(--surface); }}
  .dup-table .pkg-name {{ color: var(--blue); cursor: pointer; }}
  .dup-table .pkg-name:hover {{ text-decoration: underline; }}
  .dup-expand {{
    display: none;
    background: var(--surface);
    margin: 4px 12px 8px;
    border-radius: 6px;
    padding: 12px;
    font-size: 0.83em;
  }}
  .dup-expand.visible {{ display: block; }}
  .dup-expand table {{ width: 100%; border-collapse: collapse; }}
  .dup-expand th {{ text-align: left; padding: 4px 8px; color: var(--subtext); }}
  .dup-expand td {{ padding: 4px 8px; }}
  .dup-expand .referenced-by {{ color: var(--subtext); font-size: 0.85em; }}
</style>
</head>
<body>
<div class="header">
  <h1>Derivation Tree: <span style="color:var(--blue)">{installable}</span></h1>
  <div class="stats">
    <span>📦 {total_nodes} nodes</span>
    <span>✅ {completed_count} completed</span>
    <span>⬇️ {cache_count} cache hit</span>
    <span>🔨 {pending_count} pending</span>
    <span>📥 {source_count} source</span>
    <span>💾 {total_size_str}</span>
  </div>
</div>
<div class="tabs">
  <div class="tab active" onclick="switchTab('tree')">🌳 Dependency Tree</div>
  <div class="tab" onclick="switchTab('duplicates')">🔄 Duplicates ({dup_count})</div>
</div>
<div class="main">
  <div class="tree-panel" id="tree-panel">
    <div class="search-bar">
      <input type="text" id="search" placeholder="🔍 Filter tree nodes..." oninput="filterTree()">
    </div>
    <div class="tree-content" id="tree-content"></div>
  </div>
  <div class="detail-panel" id="detail-panel">
    <div class="detail-empty">Click a node to see details</div>
  </div>
</div>
<div class="dup-panel" id="dup-panel" style="display:none;"></div>

<script>
const DATA = {data_json};

let activeTab = 'tree';

function switchTab(tab) {{
  activeTab = tab;
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelector(`.tab:nth-child(${{tab === 'tree' ? 1 : 2}})`).classList.add('active');
  document.getElementById('tree-panel').style.display = tab === 'tree' ? '' : 'none';
  document.getElementById('detail-panel').style.display = tab === 'tree' ? '' : 'none';
  document.getElementById('dup-panel').style.display = tab === 'duplicates' ? '' : 'none';
}}

function fmtSize(bytes) {{
  if (bytes == null) return '?';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024*1024) return (bytes/1024).toFixed(1) + ' KB';
  if (bytes < 1024*1024*1024) return (bytes/(1024*1024)).toFixed(1) + ' MB';
  return (bytes/(1024*1024*1024)).toFixed(2) + ' GB';
}}

function badge(state) {{
  const cls = state === 'completed' ? 'completed' :
              state === 'nar-cache-hit' ? 'cache-hit' :
              state === 'download-source' ? 'source' : 'pending';
  const label = state === 'completed' ? 'done' :
                state === 'nar-cache-hit' ? 'cache' :
                state === 'download-source' ? 'source' : 'build';
  return `<span class="badge ${{cls}}">${{label}}</span>`;
}}

function buildTree(node, depth = 0) {{
  if (node == null) return '';
  const hasChildren = node.children && node.children.length > 0;
  const id = node.id.replace(/[^a-zA-Z0-9]/g, '_');
  let html = `<div class="tree-node" data-name="${{node.name.toLowerCase()}}" data-id="${{node.id}}">`;
  html += `<div class="tree-row" onclick="selectNode('${{node.id.replace(/'/g, "\\'")}}', this)" data-node-id="${{node.id.replace(/'/g, "\\'")}}">`;
  html += `<span class="toggle ${{hasChildren ? '' : 'leaf'}}" onclick="event.stopPropagation();toggleChildren(this)">${{hasChildren ? '▶' : '·'}}</span>`;
  html += `<span class="name">${{node.name}}</span>`;
  html += badge(node.state);
  html += `<span class="size">${{fmtSize(node.size)}}</span>`;
  html += `</div>`;
  if (hasChildren) {{
    html += `<div class="tree-children collapsed">`;
    for (const child of node.children) {{
      html += buildTree(child, depth + 1);
    }}
    html += `</div>`;
  }}
  html += `</div>`;
  return html;
}}

function toggleChildren(toggle) {{
  const row = toggle.parentElement;
  const container = row.parentElement;
  const children = container.querySelector('.tree-children');
  if (children) {{
    children.classList.toggle('collapsed');
    toggle.textContent = children.classList.contains('collapsed') ? '▶' : '▼';
  }}
}}

function selectNode(id, rowEl) {{
  document.querySelectorAll('.tree-row.selected').forEach(r => r.classList.remove('selected'));
  if (rowEl) rowEl.classList.add('selected');

  const node = findNode(DATA.tree, id);
  if (!node) return;

  const panel = document.getElementById('detail-panel');
  const refs = node.referencedBy || [];
  panel.innerHTML = `
    <div class="detail-card">
      <h3>${{node.name}}</h3>
      <div class="field"><span class="field-label">Derivation</span><span class="field-value">${{node.id}}</span></div>
      <div class="field"><span class="field-label">State</span><span class="field-value">${{badge(node.state)}} ${{node.state}}</span></div>
      <div class="field"><span class="field-label">Size</span><span class="field-value">${{fmtSize(node.size)}}</span></div>
      <div class="field"><span class="field-label">System</span><span class="field-value">${{node.system || '—'}}</span></div>
      <div class="field"><span class="field-label">Outputs</span><span class="field-value">${{(node.outputs || []).join('<br>') || '—'}}</span></div>
      <div class="field"><span class="field-label">Input Drvs</span><span class="field-value">${{node.inputDrvCount || 0}}</span></div>
      <div class="field"><span class="field-label">Input Srcs</span><span class="field-value">${{node.inputSrcCount || 0}}</span></div>
      <div class="field"><span class="field-label">Referenced By</span><span class="field-value">${{refs.length > 0 ? refs.slice(0,10).join('<br>') + (refs.length > 10 ? '<br>... and ' + (refs.length-10) + ' more' : '') : '—'}}</span></div>
    </div>
  `;
}}

function findNode(tree, id) {{
  if (!tree) return null;
  if (tree.id === id) return tree;
  if (tree.children) {{
    for (const child of tree.children) {{
      const found = findNode(child, id);
      if (found) return found;
    }}
  }}
  return null;
}}

function filterTree() {{
  const q = document.getElementById('search').value.toLowerCase();
  document.querySelectorAll('.tree-node').forEach(node => {{
    const name = node.getAttribute('data-name');
    if (!q || name.includes(q)) {{
      node.style.display = '';
    }} else {{
      node.style.display = 'none';
    }}
  }});
}}

// Duplicates view
const DUPS = DATA.duplicates || [];
let expandedDup = null;

function buildDupTable() {{
  let html = `<table class="dup-table">
    <thead><tr>
      <th>Package</th>
      <th>Versions</th>
      <th>Total Size</th>
      <th>Referenced By</th>
    </tr></thead><tbody>`;
  for (const dup of DUPS) {{
    const pkgId = dup.name.replace(/[^a-zA-Z0-9]/g, '_');
    html += `<tr>
      <td><span class="pkg-name" onclick="toggleDupDetail('${{pkgId}}')">${{dup.name}}</span></td>
      <td>${{dup.versions.length}}</td>
      <td>${{fmtSize(dup.totalSize)}}</td>
      <td>${{dup.totalRefs}}</td>
    </tr>`;
    html += `<tr class="dup-expand-row"><td colspan="4">
      <div class="dup-expand" id="dup-${{pkgId}}">
        <table>
          <thead><tr><th>Derivation</th><th>Size</th><th>State</th><th>Refs</th></tr></thead>
          <tbody>`;
    for (const v of dup.versions) {{
      html += `<tr>
        <td>${{v.name}}</td>
        <td>${{fmtSize(v.size)}}</td>
        <td>${{badge(v.state)}}</td>
        <td><span class="referenced-by">${{(v.referencedBy || []).slice(0,5).join(', ')}}${{(v.referencedBy||[]).length > 5 ? '...' : ''}}</span></td>
      </tr>`;
    }}
    html += `</tbody></table></div></td></tr>`;
  }}
  html += `</tbody></table>`;
  return html;
}}

function toggleDupDetail(pkgId) {{
  const el = document.getElementById('dup-' + pkgId);
  if (!el) return;
  if (expandedDup && expandedDup !== el) {{
    expandedDup.classList.remove('visible');
  }}
  el.classList.toggle('visible');
  expandedDup = el.classList.contains('visible') ? el : null;
}}

// Initialize
document.getElementById('tree-content').innerHTML = buildTree(DATA.tree);
document.getElementById('dup-panel').innerHTML = buildDupTable();
</script>
</body>
</html>"""


def run(*args: str, check: bool = True, timeout: int = 60) -> subprocess.CompletedProcess:
    """Run a command, return CompletedProcess."""
    return subprocess.run(list(args), capture_output=True, text=True, timeout=timeout, check=check)


def run_no_check(*args: str, timeout: int = 60) -> subprocess.CompletedProcess:
    """Run a command, don't raise on non-zero exit."""
    return subprocess.run(list(args), capture_output=True, text=True, timeout=timeout)


def get_derivation_closure(installable: str) -> dict:
    """Get the full recursive derivation graph."""
    print(f"📋 Fetching derivation closure for {installable}...", file=sys.stderr)
    result = run("nix", "derivation", "show", "--recursive", installable, timeout=120)
    data = json.loads(result.stdout)
    # nix derivation show wraps in {"derivations": {...}, "version": N}
    if "derivations" in data:
        return data["derivations"]
    return data


def get_path_infos(paths: list[str]) -> dict[str, Optional[dict]]:
    """
    Batch query nix path-info for multiple store paths.
    Returns {path: info_dict_or_None}.
    - info_dict: path exists locally, has narSize, narHash, etc.
    - None: path is substitutable but not local (nix path-info returns null)
    - Path missing from result: path unknown / not substitutable
    """
    if not paths:
        return {}

    # Filter to only valid store paths (must start with /nix/store/...)
    store_paths = [p for p in paths if p.startswith("/nix/store/")]
    if not store_paths:
        return {}

    result = run_no_check(
        "nix", "path-info", "--json", "--json-format", "1",
        *store_paths, timeout=120
    )

    info = {}
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        # If batch fails, try individually
        for p in store_paths:
            single = run_no_check("nix", "path-info", "--json", "--json-format", "1", p, timeout=10)
            try:
                single_data = json.loads(single.stdout)
                if isinstance(single_data, list) and len(single_data) > 0:
                    entry = single_data[0]
                    info[p] = entry.get(p)
                elif isinstance(single_data, dict):
                    info[p] = single_data.get(p)
            except json.JSONDecodeError:
                info[p] = None
        return info

    # data is a list of {path: info_or_null} dicts
    for entry in (data if isinstance(data, list) else [data]):
        if isinstance(entry, dict):
            for p, v in entry.items():
                info[p] = v

    return info


def get_substituter_sizes(paths: list[str], max_workers: int = 50) -> dict[str, Optional[int]]:
    """
    For paths that are nar-cache-hit (substitutable but not local),
    fetch .narinfo files from configured substituters to get narSize.
    Uses parallel HTTP requests for speed.
    Returns {path: narSize} for paths found on the substituter.
    """
    import urllib.request
    from concurrent.futures import ThreadPoolExecutor, as_completed

    if not paths:
        return {}

    # Get configured substituters
    try:
        result = run("nix", "config", "show", "substituters", timeout=10)
        substituters = [s.strip() for s in result.stdout.strip().split() if s.strip().startswith("http")]
    except subprocess.CalledProcessError:
        substituters = ["https://cache.nixos.org"]

    if not substituters:
        substituters = ["https://cache.nixos.org"]

    sub_url = substituters[0]  # Use first configured substituter

    sizes: dict[str, Optional[int]] = {}

    def fetch_narinfo(store_path: str) -> tuple[str, Optional[int]]:
        """Fetch narSize for a single store path from the substituter."""
        hash_part = store_path.split("/")[-1][:32]
        url = f"{sub_url}/{hash_part}.narinfo"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "nix-derivation-tree/1.0"})
            with urllib.request.urlopen(req, timeout=3) as resp:
                content = resp.read().decode()
                for line in content.splitlines():
                    if line.startswith("NarSize:"):
                        return store_path, int(line.split(":", 1)[1].strip())
        except Exception:
            pass
        return store_path, None

    # Parallel fetch with progress
    done_count = 0
    total = len(paths)
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(fetch_narinfo, p): p for p in paths}
        for future in as_completed(futures):
            path, sz = future.result()
            done_count += 1
            if sz is not None:
                sizes[path] = sz
            if done_count % 50 == 0 or done_count == total:
                print(f"\r   Fetched {done_count}/{total} ({len(sizes)} with sizes)", end="", file=sys.stderr)
    print(file=sys.stderr)

    return sizes


def parse_nar_size_from_stderr(stderr: str) -> Optional[int]:
    """Try to parse nar size from nix path-info stderr messages like:
    'this path will be fetched (57.2 KiB download, 273.1 KiB unpacked):'
    """
    match = re.search(r"(\d+\.?\d*)\s*(KiB|MiB|GiB|B)\s+unpacked", stderr)
    if match:
        size = float(match.group(1))
        unit = match.group(2)
        multipliers = {"B": 1, "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3}
        return int(size * multipliers.get(unit, 1))
    return None


def format_size(size_bytes: Optional[int]) -> str:
    """Format bytes to human-readable string."""
    if size_bytes is None:
        return "?"
    if size_bytes < 1024:
        return f"{size_bytes} B"
    elif size_bytes < 1024**2:
        return f"{size_bytes / 1024:.1f} KB"
    elif size_bytes < 1024**3:
        return f"{size_bytes / (1024**2):.1f} MB"
    else:
        return f"{size_bytes / (1024**3):.2f} GB"


def parse_pkg_name(drv_name: str) -> tuple[str, Optional[str]]:
    """
    Parse a derivation name into (base_name, version).
    E.g., 'hello-2.12.3' -> ('hello', '2.12.3')
    'bash-5.3p9' -> ('bash', '5.3p9')
    'stdenv-linux' -> ('stdenv-linux', None)
    'python3.11-setuptools-69.0.0' -> ('python3.11-setuptools', '69.0.0')
    """
    # Try to split on the last -version pattern
    # Version starts with a digit after the last -
    parts = drv_name.rsplit("-", 1)
    if len(parts) == 2:
        rest, candidate = parts
        # Version must start with a digit and look version-like
        if candidate and candidate[0].isdigit():
            return rest, candidate
    return drv_name, None


def build_tree(
    drv_data: dict,
    path_info_cache: dict,
    root_drv_key: str,
    reverse_deps: dict[str, list[str]],
    visited: Optional[set] = None,
) -> Optional[dict]:
    """Build a recursive tree structure from the derivation graph."""
    if visited is None:
        visited = set()

    if root_drv_key in visited:
        return None
    visited.add(root_drv_key)

    drv = drv_data.get(root_drv_key)
    if drv is None:
        return None

    name = drv.get("name", root_drv_key)
    system = drv.get("system", "")
    outputs = drv.get("outputs", {})

    # Determine state and size
    state = "pending-build"
    size = None

    # Check output paths
    output_paths = []
    for out_name, out_info in outputs.items():
        path_hash = out_info.get("path", "")
        if path_hash:
            full_path = f"/nix/store/{path_hash}"
            output_paths.append(full_path)

    # Determine state from output paths
    if output_paths:
        for op in output_paths:
            if op in path_info_cache:
                pinfo = path_info_cache[op]
                if isinstance(pinfo, dict):
                    # Path exists locally
                    state = "completed"
                    sz = pinfo.get("narSize", 0)
                    if size is None:
                        size = sz
                    else:
                        size += sz
                else:
                    # pinfo is None → substitutable but not local (nix path-info returned null)
                    if state == "pending-build":
                        state = "nar-cache-hit"
            # else: op not in cache at all → not substitutable → stays pending-build

    # If it's a source derivation (builtin:fetchurl, etc.), mark as download-source
    # Check by derivation name (e.g., hello-2.12.3.tar.gz) and by outputs being content-addressed
    is_source = any(
        hint in name
        for hint in [".tar", ".zip", ".patch", "-source"]
    ) and state == "pending-build"
    if is_source:
        state = "download-source"

    # Get input derivations and sources
    input_drvs = drv.get("inputDrvs", drv.get("inputs", {}).get("drvs", {}))
    if isinstance(input_drvs, dict):
        input_drv_keys = list(input_drvs.keys())
    else:
        input_drv_keys = []

    input_srcs = drv.get("inputSrcs", drv.get("inputs", {}).get("srcs", []))
    if not isinstance(input_srcs, list):
        input_srcs = []

    # Build children
    children = []
    for child_key in input_drv_keys:
        child_node = build_tree(drv_data, path_info_cache, child_key, reverse_deps, visited)
        if child_node:
            children.append(child_node)

    # Sort children by name
    children.sort(key=lambda c: c["name"])

    # Determine total size (recursive)
    total_size = (size or 0) + sum(c.get("totalSize", c.get("size") or 0) for c in children)

    node = {
        "id": root_drv_key,
        "name": name,
        "state": state,
        "size": size,
        "totalSize": total_size,
        "system": system,
        "outputs": output_paths,
        "inputDrvCount": len(input_drv_keys),
        "inputSrcCount": len(input_srcs),
        "referencedBy": reverse_deps.get(root_drv_key, []),
        "children": children,
    }

    return node


def find_duplicates(drv_data: dict, reverse_deps: dict[str, list[str]], path_info_cache: dict) -> list[dict]:
    """
    Find packages that appear with multiple versions.
    Groups derivations by base name, returns only groups with >1 version.
    Deduplicates identical full names (multiple .drv files for same package).
    """
    # First pass: collect all unique (name, drv_key) pairs with state/size info
    raw_entries: dict[str, dict] = {}  # full_name -> entry
    for drv_key, drv in drv_data.items():
        name = drv.get("name", drv_key)
        base, version = parse_pkg_name(name)

        # Skip derivations without a detectable version (bootstrap, stdenv, etc.)
        if not version:
            continue

        # Skip source fetch derivations (tarballs, patches, etc.)
        is_source = any(
            hint in name
            for hint in [".tar", ".zip", ".patch", "-source"]
        )
        if is_source:
            continue

        refs = reverse_deps.get(drv_key, [])

        # Determine state/size from outputs
        outputs = drv.get("outputs", {})
        state = "pending-build"
        size = None
        for out_name, out_info in outputs.items():
            path_hash = out_info.get("path", "")
            if path_hash:
                full_path = f"/nix/store/{path_hash}"
                if full_path in path_info_cache:
                    pinfo = path_info_cache[full_path]
                    if isinstance(pinfo, dict):
                        state = "completed"
                        sz = pinfo.get("narSize", 0)
                        size = (size or 0) + sz
                    else:
                        if state == "pending-build":
                            state = "nar-cache-hit"

        # Deduplicate by full name: merge refs from multiple .drv files
        if name in raw_entries:
            existing = raw_entries[name]
            # Merge referencedBy, deduplicating
            merged_refs = list(set(existing["referencedBy"] + refs))
            existing["referencedBy"] = merged_refs
        else:
            raw_entries[name] = {
                "drvKey": drv_key,
                "name": name,
                "version": version,
                "state": state,
                "size": size,
                "referencedBy": list(set(refs)),
            }

    # Group by base name (stripping version)
    groups: dict[str, list[dict]] = defaultdict(list)
    for entry in raw_entries.values():
        base, _ = parse_pkg_name(entry["name"])
        groups[base].append(entry)

    # Filter to duplicates only
    duplicates = []
    for base_name, versions in sorted(groups.items()):
        if len(versions) <= 1:
            continue

        # Sort versions by name
        versions.sort(key=lambda v: v["name"])

        dup = {
            "name": base_name,
            "versions": versions,
            "totalSize": 0,
            "totalRefs": sum(len(v["referencedBy"]) for v in versions),
        }
        duplicates.append(dup)

    # Sort by totalRefs descending (most impactful first)
    duplicates.sort(key=lambda d: d["totalRefs"], reverse=True)
    return duplicates


def main():
    parser = argparse.ArgumentParser(
        description="Analyze a Nix derivation closure and output an interactive HTML tree."
    )
    parser.add_argument(
        "installable",
        help="Nix installable (e.g., nixpkgs#hello, .#nixosConfigurations.host.config.system.build.toplevel)",
    )
    parser.add_argument(
        "-o", "--output",
        default=None,
        help="Output HTML file path (default: <installable-slug>.html)",
    )
    parser.add_argument(
        "--open",
        action="store_true",
        help="Open the HTML file in the default browser after generation",
    )
    parser.add_argument(
        "--fetch-sizes",
        action="store_true",
        help="Fetch narSize from substituters for cache-hit paths (slow, uses network)",
    )
    args = parser.parse_args()

    installable = args.installable

    # Step 1: Get the full derivation closure
    try:
        drv_data = get_derivation_closure(installable)
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to get derivation closure: {e.stderr}", file=sys.stderr)
        sys.exit(1)

    if not drv_data:
        print("❌ No derivations found for this installable.", file=sys.stderr)
        sys.exit(1)

    print(f"   Found {len(drv_data)} derivations in closure.", file=sys.stderr)

    # Step 2: Find the root derivation (the one with the shortest dependency chain,
    # or the one that matches the installable name)
    # The root is typically the one that nothing depends on, but we find it by
    # looking for the derivation that is not an input of any other.
    all_deps: set[str] = set()
    for drv_key, drv in drv_data.items():
        inputs = drv.get("inputDrvs", drv.get("inputs", {}).get("drvs", {}))
        if isinstance(inputs, dict):
            all_deps.update(inputs.keys())

    root_keys = [k for k in drv_data if k not in all_deps]
    if not root_keys:
        # Fallback: use the derivation with the most dependents
        dep_count = defaultdict(int)
        for drv_key, drv in drv_data.items():
            inputs = drv.get("inputDrvs", drv.get("inputs", {}).get("drvs", {}))
            if isinstance(inputs, dict):
                for inp in inputs:
                    dep_count[inp] += 1
        if dep_count:
            root_keys = [max(drv_data.keys(), key=lambda k: dep_count.get(k, 0))]
        else:
            root_keys = [list(drv_data.keys())[0]]

    root_key = root_keys[0]
    root_name = drv_data[root_key].get("name", root_key)
    print(f"   Root derivation: {root_name}", file=sys.stderr)

    # Step 3: Build reverse dependency map
    reverse_deps: dict[str, list[str]] = defaultdict(list)
    for drv_key, drv in drv_data.items():
        inputs = drv.get("inputDrvs", drv.get("inputs", {}).get("drvs", {}))
        if isinstance(inputs, dict):
            for inp_key in inputs:
                reverse_deps[inp_key].append(drv.get("name", drv_key))

    # Step 4: Collect all output paths and query path-info
    all_output_paths = []
    for drv_key, drv in drv_data.items():
        outputs = drv.get("outputs", {})
        for out_name, out_info in outputs.items():
            path_hash = out_info.get("path", "")
            if path_hash:
                all_output_paths.append(f"/nix/store/{path_hash}")

    print(f"   Querying path-info for {len(all_output_paths)} output paths...", file=sys.stderr)

    # Query in batches of 500 to avoid command-line length limits
    path_info_cache: dict[str, Optional[dict]] = {}
    batch_size = 500
    for i in range(0, len(all_output_paths), batch_size):
        batch = all_output_paths[i : i + batch_size]
        batch_info = get_path_infos(batch)
        path_info_cache.update(batch_info)
        done = min(i + batch_size, len(all_output_paths))
        print(f"\r   Path-info: {done}/{len(all_output_paths)}", end="", file=sys.stderr)
    print(file=sys.stderr)

    # Also query path-info for the .drv files themselves (they exist locally)
    drv_store_paths = [f"/nix/store/{k}" for k in drv_data]
    drv_info = get_path_infos(drv_store_paths)
    path_info_cache.update(drv_info)

    # Step 4b: For nar-cache-hit paths, optionally query substituters to get narSize
    cache_hit_paths = [
        p for p in all_output_paths
        if p in path_info_cache and path_info_cache[p] is None
    ]
    if cache_hit_paths and args.fetch_sizes:
        print(f"   Querying substituters for {len(cache_hit_paths)} cache-hit sizes...", file=sys.stderr)
        sub_sizes = get_substituter_sizes(cache_hit_paths)
        for p, sz in sub_sizes.items():
            # Update path_info_cache: replace None with dict containing narSize
            path_info_cache[p] = {"narSize": sz}
        print(f"   Got sizes for {len(sub_sizes)}/{len(cache_hit_paths)} paths from substituters", file=sys.stderr)
    elif cache_hit_paths:
        print(f"   {len(cache_hit_paths)} paths are cache-hit (sizes unknown, use --fetch-sizes to query)", file=sys.stderr)

    # Step 5: Build the tree
    print(f"   Building tree...", file=sys.stderr)
    tree = build_tree(drv_data, path_info_cache, root_key, reverse_deps)

    # Step 6: Find duplicates
    duplicates = find_duplicates(drv_data, reverse_deps, path_info_cache)

    # Step 7: Compute stats
    def count_states(node, counts):
        if node is None:
            return
        counts[node["state"]] = counts.get(node["state"], 0) + 1
        counts["totalSize"] = counts.get("totalSize", 0) + (node.get("size") or 0)
        for child in node.get("children", []):
            count_states(child, counts)

    stats: dict = {}
    count_states(tree, stats)

    # Step 8: Generate HTML
    print(f"   Generating HTML...", file=sys.stderr)
    html = HTML_TEMPLATE.format(
        installable=installable,
        data_json=json.dumps({
            "tree": tree,
            "duplicates": duplicates,
        }, indent=None),
        total_nodes=len(drv_data),
        completed_count=stats.get("completed", 0),
        cache_count=stats.get("nar-cache-hit", 0),
        pending_count=stats.get("pending-build", 0) + stats.get("download-source", 0),
        source_count=stats.get("download-source", 0),
        total_size_str=format_size(stats.get("totalSize")),
        dup_count=len(duplicates),
    )

    # Step 9: Write output
    output_path = args.output
    if output_path is None:
        slug = re.sub(r"[^a-zA-Z0-9._-]", "_", installable)
        output_path = f"{slug}.html"

    with open(output_path, "w") as f:
        f.write(html)

    file_size = os.path.getsize(output_path)
    print(f"✅ Written {file_size:,} bytes → {output_path}", file=sys.stderr)

    if args.open:
        import webbrowser
        webbrowser.open("file://" + os.path.abspath(output_path))


if __name__ == "__main__":
    main()