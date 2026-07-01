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

URL_SIZE_TIMEOUT_SECONDS = 20
NARINFO_TIMEOUT_SECONDS = 20

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
  .main {{ display: flex; height: calc(100vh - 90px); min-width: 0; }}
  .panel {{ flex: 1 1 0; min-width: 0; overflow-y: auto; }}

  /* Tree panel (left) */
  .tree-panel {{
    flex: 0 0 50%;
    max-width: 50%;
    min-width: 0;
    border-right: 1px solid var(--border);
    display: flex;
    flex-direction: column;
  }}
  .search-bar {{
    padding: 10px 16px;
    border-bottom: 1px solid var(--border);
    background: var(--surface);
  }}
  .search-row {{ display: flex; gap: 8px; align-items: center; min-width: 0; }}
  .search-bar input {{
    width: 100%;
    min-width: 0;
    padding: 6px 12px;
    border: 1px solid var(--border);
    border-radius: 6px;
    background: var(--bg);
    color: var(--text);
    font-size: 0.9em;
    outline: none;
  }}
  .search-bar input:focus {{ border-color: var(--blue); }}
  .search-hint {{ color: var(--subtext); font-size: 0.75em; margin-top: 6px; }}
  .quick-filters {{ display: flex; gap: 4px; flex-shrink: 0; }}
  .filter-btn {{
    border: 1px solid transparent;
    border-radius: 6px;
    cursor: pointer;
    font-size: 0.75em;
    min-width: 48px;
    padding: 6px 8px;
  }}
  .filter-btn.build {{ background: rgba(243,139,168,0.15); color: var(--red); }}
  .filter-btn.cache {{ background: rgba(249,226,175,0.15); color: var(--yellow); }}
  .filter-btn.done {{ background: rgba(166,227,161,0.15); color: var(--green); }}
  .filter-btn:hover {{ filter: brightness(1.15); }}
  .filter-btn.build.active {{ border-color: var(--red); }}
  .filter-btn.cache.active {{ border-color: var(--yellow); }}
  .filter-btn.done.active {{ border-color: var(--green); }}
  .tree-content {{ flex: 1 1 0; min-width: 0; overflow-y: auto; padding: 8px 0; }}

  /* Detail panel (right) */
  .detail-panel {{
    flex: 0 0 50%;
    max-width: 50%;
    min-width: 0;
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
    min-width: 0;
    padding: 3px 8px;
    cursor: pointer;
    border-radius: 4px;
    margin: 1px 4px;
    font-size: 0.85em;
  }}
  .tree-row:hover {{ background: var(--overlay); }}
  .tree-row.selected {{ background: var(--overlay); border-left: 2px solid var(--blue); }}
  .tree-row.ignored {{ opacity: 0.45; }}
  .tree-row.ignored .name,
  .tree-row.ignored .badge,
  .tree-row.ignored .summary-plus,
  .tree-row.ignored .summary-size,
  .tree-row.ignored .size {{ text-decoration: line-through; }}
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
  .tree-row .name {{ margin-left: 4px; flex: 1 1 auto; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }}
  .tree-row .size {{ color: var(--subtext); flex-shrink: 0; margin-left: 8px; font-size: 0.8em; white-space: nowrap; }}
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
  .summary-badges {{ display: flex; gap: 4px; align-items: center; margin-left: 0; flex: 0 1 auto; min-width: 0; overflow: hidden; }}
  .summary-plus {{
    align-items: center;
    align-self: center;
    color: var(--subtext);
    display: inline-flex;
    flex-shrink: 0;
    font-size: 0.85em;
    height: 1.4em;
    justify-content: center;
    line-height: 1;
    margin-left: 6px;
  }}
  .summary-badges .badge {{ flex-shrink: 0; }}
  .summary-size {{ color: var(--subtext); flex-shrink: 0; font-size: 0.8em; margin-left: 4px; white-space: nowrap; }}
  .ref-link, .node-link {{
    border: 0;
    background: transparent;
    color: var(--blue);
    cursor: pointer;
    padding: 0;
    text-align: left;
    font: inherit;
  }}
  .ref-link:hover, .node-link:hover {{ text-decoration: underline; }}

  /* Duplicates table */
  .dup-panel {{ flex: 1 1 0; min-width: 0; padding: 16px; overflow-y: auto; }}
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
  .sort-header {{
    border: 0;
    background: transparent;
    color: var(--subtext);
    cursor: pointer;
    font: inherit;
    font-weight: 600;
    padding: 0;
    text-align: left;
    white-space: nowrap;
  }}
  .sort-header:hover {{ color: var(--blue); }}
  .sort-indicator {{ color: var(--blue); margin-left: 4px; }}
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
      <div class="search-row">
        <input type="text" id="search" placeholder="Filter tree nodes" oninput="filterTree()">
        <div class="quick-filters">
          <button class="filter-btn build" data-state-filter="pending-build" onclick="toggleStateFilter('pending-build')">build</button>
          <button class="filter-btn cache" data-state-filter="nar-cache-hit" onclick="toggleStateFilter('nar-cache-hit')">cache</button>
          <button class="filter-btn done" data-state-filter="completed" onclick="toggleStateFilter('completed')">done</button>
        </div>
      </div>
      <div class="search-hint">Syntax: text terms, <code>state:done</code>, <code>state:cache</code>, <code>state:build</code>, <code>ref:name</code>, <code>/regex/</code>.</div>
    </div>
    <div class="tree-content" id="tree-content"></div>
  </div>
  <div class="detail-panel" id="detail-panel">
    <div class="detail-empty">Click a node to see details</div>
  </div>
  <div class="dup-panel" id="dup-panel" style="display:none;"></div>
</div>

<script>
const DATA = {data_json};

let activeTab = 'tree';
let activeStateFilters = new Set();

function switchTab(tab) {{
  activeTab = tab;
  document.querySelectorAll('.tab').forEach((t, index) => {{
    t.classList.toggle('active', index === (tab === 'tree' ? 0 : 1));
  }});
  document.getElementById('tree-panel').style.display = tab === 'tree' ? '' : 'none';
  document.getElementById('detail-panel').style.display = tab === 'tree' ? '' : 'none';
  document.getElementById('dup-panel').style.display = tab === 'duplicates' ? 'block' : 'none';
}}

function esc(value) {{
  return String(value ?? '').replace(/[&<>"']/g, ch => ({{
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }})[ch]);
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

function summaryBadges(node) {{
  const summary = node.childSummary || {{done: 0, cache: 0, build: 0, size: 0}};
  const badges = [];
  if (summary.build) badges.push(`<span class="badge pending">${{summary.build}} build</span>`);
  if (summary.cache) badges.push(`<span class="badge cache-hit">${{summary.cache}} cache</span>`);
  if (summary.done) badges.push(`<span class="badge completed">${{summary.done}} done</span>`);
  badges.push(`<span class="summary-size">(${{fmtSize(summary.size)}})</span>`);
  return `<span class="summary-badges">${{badges.join('')}}</span>`;
}}

function renderRefs(refs, limit = 20) {{
  if (!refs || refs.length === 0) return '—';
  const shown = refs.slice(0, limit).map(ref =>
    `<button class="ref-link" data-jump-id="${{esc(ref.id)}}">${{esc(ref.name)}}</button>`
  );
  if (refs.length > limit) shown.push(`... and ${{refs.length - limit}} more`);
  return shown.join('<br>');
}}

function renderList(values) {{
  return values && values.length ? values.map(esc).join('<br>') : '—';
}}

function buildTree(node, forceExpand = false) {{
  if (node == null) return '';
  const hasChildren = node.children && node.children.length > 0;
  const expanded = forceExpand && hasChildren;
  let html = `<div class="tree-node" data-id="${{esc(node.id)}}">`;
  html += `<div class="tree-row ${{node.ignoredInParentSummary ? 'ignored' : ''}}" data-node-id="${{esc(node.id)}}">`;
  html += `<span class="toggle ${{hasChildren ? '' : 'leaf'}}">${{hasChildren ? (expanded ? '▼' : '▶') : '·'}}</span>`;
  html += `<span class="name">${{esc(node.name)}}</span>`;
  html += badge(node.state);
  if (hasChildren) html += `<span class="summary-plus">+</span>` + summaryBadges(node);
  html += `<span class="size">${{fmtSize(node.size)}}</span>`;
  html += `</div>`;
  if (hasChildren) {{
    html += `<div class="tree-children ${{expanded ? '' : 'collapsed'}}">`;
    for (const child of node.children) html += buildTree(child, forceExpand);
    html += `</div>`;
  }}
  html += `</div>`;
  return html;
}}

function toggleChildren(toggle) {{
  const row = toggle.parentElement;
  const container = row.parentElement;
  const children = container.querySelector(':scope > .tree-children');
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
      <h3>${{esc(node.name)}}</h3>
      <div class="field"><span class="field-label">Derivation</span><span class="field-value">${{esc(node.id)}}</span></div>
      <div class="field"><span class="field-label">State</span><span class="field-value">${{badge(node.state)}} ${{esc(node.state)}}</span></div>
      <div class="field"><span class="field-label">Ignored</span><span class="field-value">${{node.ignoredInParentSummary ? 'yes — excluded from parent summaries' : 'no'}}</span></div>
      <div class="field"><span class="field-label">Size</span><span class="field-value">${{fmtSize(node.size)}}</span></div>
      <div class="field"><span class="field-label">File Size</span><span class="field-value">${{fmtSize(node.fileSize)}}</span></div>
      <div class="field"><span class="field-label">NAR Size</span><span class="field-value">${{fmtSize(node.narSize)}}</span></div>
      <div class="field"><span class="field-label">Total Size</span><span class="field-value">${{fmtSize(node.totalSize)}}</span></div>
      <div class="field"><span class="field-label">System</span><span class="field-value">${{esc(node.system || '—')}}</span></div>
      <div class="field"><span class="field-label">Outputs</span><span class="field-value">${{renderList(node.outputs)}}</span></div>
      <div class="field"><span class="field-label">Source URLs</span><span class="field-value">${{renderList(node.sourceUrls)}}</span></div>
      <div class="field"><span class="field-label">Input Drvs</span><span class="field-value">${{node.inputDrvCount || 0}}</span></div>
      <div class="field"><span class="field-label">Input Srcs</span><span class="field-value">${{node.inputSrcCount || 0}}</span></div>
      <div class="field"><span class="field-label">Referenced By</span><span class="field-value">${{renderRefs(refs)}}</span></div>
    </div>
  `;
}}

function findNode(tree, id) {{
  if (!tree) return null;
  if (tree.id === id) return tree;
  for (const child of tree.children || []) {{
    const found = findNode(child, id);
    if (found) return found;
  }}
  return null;
}}

function findNodePath(tree, id, path = []) {{
  if (!tree) return null;
  const nextPath = [...path, tree.id];
  if (tree.id === id) return nextPath;
  for (const child of tree.children || []) {{
    const found = findNodePath(child, id, nextPath);
    if (found) return found;
  }}
  return null;
}}

function nodeText(node) {{
  return [
    node.name, node.id,
    ...(node.outputs || []),
    ...(node.sourceUrls || []),
    ...(node.referencedBy || []).map(ref => `${{ref.name}} ${{ref.id}}`),
  ].join(' ').toLowerCase();
}}

function stateMatches(node, state) {{
  if (state === 'pending-build') return node.state === 'pending-build' || node.state === 'download-source';
  return node.state === state;
}}

function parseQuery(query) {{
  const parsed = {{terms: [], regexes: [], states: [], refs: []}};
  const tokens = query.match(/\\/(?:\\\\\\/|[^/])+\\/|\\S+/g) || [];
  for (const raw of tokens) {{
    const token = raw.trim();
    if (!token) continue;
    if (token.startsWith('/') && token.endsWith('/') && token.length > 2) {{
      try {{ parsed.regexes.push(new RegExp(token.slice(1, -1), 'i')); }} catch (_err) {{}}
    }} else if (token.startsWith('state:')) {{
      const value = token.slice(6).toLowerCase();
      if (value === 'done') parsed.states.push('completed');
      else if (value === 'cache') parsed.states.push('nar-cache-hit');
      else if (value === 'build') parsed.states.push('pending-build');
    }} else if (token.startsWith('ref:')) {{
      parsed.refs.push(token.slice(4).toLowerCase());
    }} else {{
      parsed.terms.push(token.toLowerCase());
    }}
  }}
  return parsed;
}}

function nodeMatchesQuery(node, parsed) {{
  const text = nodeText(node);
  if (parsed.terms.some(term => !text.includes(term))) return false;
  if (parsed.regexes.some(regex => !regex.test(text))) return false;
  if (parsed.states.length && !parsed.states.some(state => stateMatches(node, state))) return false;
  if (parsed.refs.length) {{
    const refs = (node.referencedBy || []).map(ref => `${{ref.name}} ${{ref.id}}`.toLowerCase()).join(' ');
    if (parsed.refs.some(ref => !refs.includes(ref))) return false;
  }}
  if (activeStateFilters.size && !Array.from(activeStateFilters).some(state => stateMatches(node, state))) return false;
  return true;
}}

function filterNode(node, parsed) {{
  const childMatches = (node.children || []).map(child => filterNode(child, parsed)).filter(Boolean);
  if (nodeMatchesQuery(node, parsed) || childMatches.length) {{
    return {{...node, children: childMatches}};
  }}
  return null;
}}

function renderTree() {{
  const query = document.getElementById('search').value.trim();
  const isFiltering = Boolean(query || activeStateFilters.size);
  const tree = isFiltering ? filterNode(DATA.tree, parseQuery(query)) : DATA.tree;
  document.getElementById('tree-content').innerHTML = tree ? buildTree(tree, isFiltering) : '<div class="detail-empty">No matching derivations</div>';
}}

function filterTree() {{
  renderTree();
}}

function toggleStateFilter(state) {{
  if (activeStateFilters.has(state)) activeStateFilters.delete(state);
  else activeStateFilters.add(state);
  document.querySelectorAll('.filter-btn').forEach(btn => {{
    btn.classList.toggle('active', activeStateFilters.has(btn.dataset.stateFilter));
  }});
  renderTree();
}}

function rowForNode(id) {{
  return Array.from(document.querySelectorAll('.tree-row')).find(row => row.dataset.nodeId === id);
}}

function jumpToNode(id) {{
  switchTab('tree');
  document.getElementById('search').value = '';
  activeStateFilters.clear();
  document.querySelectorAll('.filter-btn').forEach(btn => btn.classList.remove('active'));
  renderTree();

  const path = findNodePath(DATA.tree, id) || [];
  for (const ancestorId of path.slice(0, -1)) {{
    const row = rowForNode(ancestorId);
    if (!row) continue;
    const toggle = row.querySelector('.toggle');
    const children = row.parentElement.querySelector(':scope > .tree-children');
    if (toggle && children) {{
      children.classList.remove('collapsed');
      toggle.textContent = '▼';
    }}
  }}

  const row = rowForNode(id);
  if (row) {{
    selectNode(id, row);
    row.scrollIntoView({{block: 'center'}});
  }}
}}

// Duplicates view
const DUPS = DATA.duplicates || [];
let expandedDup = null;
let dupSort = {{key: 'totalRefs', dir: 'desc'}};
let versionSorts = {{}};

function sortIndicator(sortState, key) {{
  if (sortState.key !== key) return '';
  return `<span class="sort-indicator">${{sortState.dir === 'asc' ? '▲' : '▼'}}</span>`;
}}

function compareValues(a, b) {{
  const aMissing = a == null;
  const bMissing = b == null;
  if (aMissing && bMissing) return 0;
  if (aMissing) return -1;
  if (bMissing) return 1;
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  return String(a).localeCompare(String(b), undefined, {{numeric: true, sensitivity: 'base'}});
}}

function applySort(rows, sortState, valueFn) {{
  return rows.slice().sort((a, b) => {{
    const result = compareValues(valueFn(a, sortState.key), valueFn(b, sortState.key));
    return sortState.dir === 'asc' ? result : -result;
  }});
}}

function dupSortValue(row, key) {{
  const dup = row.dup;
  if (key === 'name') return dup.name;
  if (key === 'versions') return dup.versions.length;
  if (key === 'totalSize') return dup.totalSize || 0;
  if (key === 'totalRefs') return dup.totalRefs || 0;
  return dup.name;
}}

function versionSortValue(version, key) {{
  if (key === 'name') return version.name;
  if (key === 'size') return version.size || 0;
  if (key === 'narSize') return version.narSize || 0;
  if (key === 'state') return version.state;
  if (key === 'refs') return (version.referencedBy || []).length;
  return version.name;
}}

function dupHeader(label, key) {{
  return `<button class="sort-header" onclick="sortDuplicates('${{key}}')">${{label}}${{sortIndicator(dupSort, key)}}</button>`;
}}

function versionHeader(label, key, dupIndex) {{
  const sortState = versionSorts[dupIndex] || {{key: 'name', dir: 'asc'}};
  return `<button class="sort-header" onclick="sortVersions(${{dupIndex}}, '${{key}}')">${{label}}${{sortIndicator(sortState, key)}}</button>`;
}}

function buildDupTable() {{
  const rows = applySort(DUPS.map((dup, index) => ({{dup, index}})), dupSort, dupSortValue);
  let html = `<table class="dup-table">
    <thead><tr>
      <th>${{dupHeader('Package', 'name')}}</th>
      <th>${{dupHeader('Versions', 'versions')}}</th>
      <th>${{dupHeader('Total Size', 'totalSize')}}</th>
      <th>${{dupHeader('Referenced By', 'totalRefs')}}</th>
    </tr></thead><tbody>`;
  rows.forEach(row => {{
    const dup = row.dup;
    const index = row.index;
    const pkgId = `dup-${{index}}`;
    const versionSort = versionSorts[index] || {{key: 'name', dir: 'asc'}};
    const versions = applySort(dup.versions || [], versionSort, versionSortValue);
    html += `<tr>
      <td><span class="pkg-name" onclick="toggleDupDetail('${{pkgId}}')">${{esc(dup.name)}}</span></td>
      <td>${{dup.versions.length}}</td>
      <td>${{fmtSize(dup.totalSize)}}</td>
      <td>${{dup.totalRefs}}</td>
    </tr>`;
    html += `<tr class="dup-expand-row"><td colspan="4">
      <div class="dup-expand ${{expandedDup === pkgId ? 'visible' : ''}}" id="${{pkgId}}">
        <table>
          <thead><tr>
            <th>${{versionHeader('Derivation', 'name', index)}}</th>
            <th>${{versionHeader('Size', 'size', index)}}</th>
            <th>${{versionHeader('NAR Size', 'narSize', index)}}</th>
            <th>${{versionHeader('State', 'state', index)}}</th>
            <th>${{versionHeader('Refs', 'refs', index)}}</th>
          </tr></thead>
          <tbody>`;
    for (const v of versions) {{
      html += `<tr>
        <td><button class="node-link" data-jump-id="${{esc(v.drvKey)}}">${{esc(v.name)}}</button></td>
        <td>${{fmtSize(v.size)}}</td>
        <td>${{fmtSize(v.narSize)}}</td>
        <td>${{badge(v.state)}}</td>
        <td><span class="referenced-by">${{renderRefs(v.referencedBy || [], 5)}}</span></td>
      </tr>`;
    }}
    html += `</tbody></table></div></td></tr>`;
  }});
  html += `</tbody></table>`;
  return html;
}}

function renderDupTable() {{
  document.getElementById('dup-panel').innerHTML = buildDupTable();
}}

function sortDuplicates(key) {{
  if (dupSort.key === key) dupSort.dir = dupSort.dir === 'asc' ? 'desc' : 'asc';
  else dupSort = {{key, dir: 'asc'}};
  renderDupTable();
}}

function sortVersions(dupIndex, key) {{
  const current = versionSorts[dupIndex] || {{key: 'name', dir: 'asc'}};
  if (current.key === key) versionSorts[dupIndex] = {{key, dir: current.dir === 'asc' ? 'desc' : 'asc'}};
  else versionSorts[dupIndex] = {{key, dir: 'asc'}};
  expandedDup = `dup-${{dupIndex}}`;
  renderDupTable();
}}

function toggleDupDetail(pkgId) {{
  const el = document.getElementById(pkgId);
  if (!el) return;
  if (expandedDup && expandedDup !== pkgId) {{
    const prev = document.getElementById(expandedDup);
    if (prev) prev.classList.remove('visible');
  }}
  el.classList.toggle('visible');
  expandedDup = el.classList.contains('visible') ? pkgId : null;
}}

document.getElementById('tree-content').addEventListener('click', event => {{
  const toggle = event.target.closest('.toggle');
  if (toggle && !toggle.classList.contains('leaf')) {{
    event.stopPropagation();
    toggleChildren(toggle);
    return;
  }}
  const row = event.target.closest('.tree-row');
  if (row) selectNode(row.dataset.nodeId, row);
}});

document.addEventListener('click', event => {{
  const jump = event.target.closest('[data-jump-id]');
  if (jump) jumpToNode(jump.dataset.jumpId);
}});

// Initialize
renderTree();
renderDupTable();
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


def get_substituter_infos(paths: list[str], max_workers: int = 50) -> dict[str, dict]:
    """
    For paths that are nar-cache-hit (substitutable but not local),
    fetch .narinfo files from configured substituters to get FileSize and NarSize.
    Uses parallel HTTP requests for speed.
    Returns {path: info} for paths found on the substituter.
    """
    import socket
    import urllib.error
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

    sub_url = substituters[0].rstrip("/")  # Use first configured substituter

    infos: dict[str, dict] = {}

    def describe_error(err: Exception) -> str:
        if isinstance(err, urllib.error.HTTPError):
            return f"HTTP {err.code} {err.reason}"
        if isinstance(err, urllib.error.URLError):
            reason = err.reason
            if isinstance(reason, (TimeoutError, socket.timeout)):
                return f"timeout after {NARINFO_TIMEOUT_SECONDS}s"
            return str(reason)
        if isinstance(err, (TimeoutError, socket.timeout)):
            return f"timeout after {NARINFO_TIMEOUT_SECONDS}s"
        return str(err) or err.__class__.__name__

    def fetch_narinfo(store_path: str) -> tuple[str, Optional[dict], Optional[str]]:
        """Fetch narinfo metadata for a single store path from the substituter."""
        hash_part = store_path.split("/")[-1][:32]
        url = f"{sub_url}/{hash_part}.narinfo"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "nix-derivation-tree/1.0"})
            with urllib.request.urlopen(req, timeout=NARINFO_TIMEOUT_SECONDS) as resp:
                content = resp.read().decode()
                info: dict[str, object] = {
                    "_cacheHit": True,
                    "narinfoUrl": url,
                    "fileSize": None,
                    "narSize": None,
                }
                for line in content.splitlines():
                    if line.startswith("FileSize:"):
                        info["fileSize"] = int(line.split(":", 1)[1].strip())
                    if line.startswith("NarSize:"):
                        info["narSize"] = int(line.split(":", 1)[1].strip())
                    if line.startswith("NarHash:"):
                        info["narHash"] = line.split(":", 1)[1].strip()
                    if line.startswith("URL:"):
                        info["url"] = line.split(":", 1)[1].strip()
                return store_path, info, None
        except Exception as err:
            return store_path, None, f"{url}: {describe_error(err)}"

    # Parallel fetch with progress
    warnings = []
    done_count = 0
    total = len(paths)
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(fetch_narinfo, p): p for p in paths}
        for future in as_completed(futures):
            path, info, warning = future.result()
            done_count += 1
            if info is not None:
                infos[path] = info
            if warning:
                warnings.append(f"   warning: failed to fetch narinfo for {path}: {warning}")
            if done_count % 50 == 0 or done_count == total:
                print(f"\r   Fetched {done_count}/{total} ({len(infos)} with narinfo)", end="", file=sys.stderr)
    print(file=sys.stderr)
    for warning in warnings:
        print(warning, file=sys.stderr)

    return infos


def extract_urls_from_drv(drv: dict) -> list[str]:
    """Extract source/download URLs from a derivation environment."""
    env = drv.get("env", {})
    if not isinstance(env, dict):
        return []

    urls = []
    url_re = re.compile(r"(?:https?|ftp)://[^\s'\"<>]+")
    for key, value in env.items():
        if not isinstance(value, str):
            continue
        if "url" not in key.lower() and not url_re.search(value):
            continue
        urls.extend(url_re.findall(value))

    seen = set()
    unique = []
    for url in urls:
        if url not in seen:
            seen.add(url)
            unique.append(url)
    return unique


def get_url_sizes(urls: list[str], max_workers: int = 20) -> dict[str, int]:
    """Return remote Content-Length values for URLs, falling back to 0."""
    import socket
    import urllib.error
    import urllib.request
    from concurrent.futures import ThreadPoolExecutor, as_completed

    unique_urls = list(dict.fromkeys(urls))
    if not unique_urls:
        return {}

    class RedirectHandler(urllib.request.HTTPRedirectHandler):
        http_error_308 = urllib.request.HTTPRedirectHandler.http_error_301

    opener = urllib.request.build_opener(RedirectHandler())

    def describe_error(err: Exception) -> str:
        if isinstance(err, urllib.error.HTTPError):
            return f"HTTP {err.code} {err.reason}"
        if isinstance(err, urllib.error.URLError):
            reason = err.reason
            if isinstance(reason, (TimeoutError, socket.timeout)):
                return f"timeout after {URL_SIZE_TIMEOUT_SECONDS}s"
            return str(reason)
        if isinstance(err, (TimeoutError, socket.timeout)):
            return f"timeout after {URL_SIZE_TIMEOUT_SECONDS}s"
        return str(err) or err.__class__.__name__

    def fetch_size(url: str) -> tuple[str, int, Optional[str]]:
        headers = {"User-Agent": "nix-derivation-tree/1.0"}
        errors = []
        try:
            req = urllib.request.Request(url, headers=headers, method="HEAD")
            with opener.open(req, timeout=URL_SIZE_TIMEOUT_SECONDS) as resp:
                length = resp.headers.get("Content-Length")
                if length and length.isdigit():
                    return url, int(length), None
                errors.append("HEAD response did not include Content-Length")
        except Exception as err:
            errors.append(f"HEAD failed: {describe_error(err)}")

        try:
            range_headers = {**headers, "Range": "bytes=0-0"}
            req = urllib.request.Request(url, headers=range_headers)
            with opener.open(req, timeout=URL_SIZE_TIMEOUT_SECONDS) as resp:
                content_range = resp.headers.get("Content-Range", "")
                match = re.search(r"/(\d+)$", content_range)
                if match:
                    return url, int(match.group(1)), None
                length = resp.headers.get("Content-Length")
                if length and length.isdigit():
                    return url, int(length), None
                errors.append("range GET response did not include Content-Length or Content-Range")
        except Exception as err:
            errors.append(f"range GET failed: {describe_error(err)}")

        return url, 0, "; ".join(errors)

    sizes: dict[str, int] = {}
    warnings = []
    done_count = 0
    total = len(unique_urls)
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        futures = {executor.submit(fetch_size, u): u for u in unique_urls}
        for future in as_completed(futures):
            url, size, warning = future.result()
            done_count += 1
            sizes[url] = size
            if warning:
                warnings.append(f"   warning: failed to get URL size for {url}: {warning}")
            if done_count % 20 == 0 or done_count == total:
                print(f"\r   URL HEAD: {done_count}/{total}", end="", file=sys.stderr)
    print(file=sys.stderr)
    for warning in warnings:
        print(warning, file=sys.stderr)
    return sizes


def summarize_outputs(outputs: dict, path_info_cache: dict) -> dict:
    """Classify derivation outputs and compute display/download sizes."""
    output_paths = []
    completed_size = 0
    cache_file_size = 0
    cache_nar_size = 0
    has_completed = False
    has_cache = False

    for _out_name, out_info in outputs.items():
        path_hash = out_info.get("path", "")
        if not path_hash:
            continue

        full_path = f"/nix/store/{path_hash}"
        output_paths.append(full_path)
        if full_path not in path_info_cache:
            continue

        pinfo = path_info_cache[full_path]
        if isinstance(pinfo, dict) and pinfo.get("_cacheHit"):
            has_cache = True
            cache_file_size += pinfo.get("fileSize") or 0
            cache_nar_size += pinfo.get("narSize") or 0
        elif isinstance(pinfo, dict):
            has_completed = True
            completed_size += pinfo.get("narSize", 0) or 0
        else:
            has_cache = True

    if has_completed and not has_cache:
        state = "completed"
        size = completed_size
    elif has_cache:
        state = "nar-cache-hit"
        size = cache_file_size
    else:
        state = "pending-build"
        size = 0

    return {
        "state": state,
        "size": size,
        "narSize": cache_nar_size if has_cache else completed_size,
        "fileSize": cache_file_size if has_cache else None,
        "outputs": output_paths,
    }


def summarize_children(children: list[dict], parent_state: str) -> dict:
    """Summarize descendant state counts and total size for tree rows."""
    summary = {"done": 0, "cache": 0, "build": 0, "size": 0}

    def should_ignore_child(current_parent_state: str, child: dict) -> bool:
        if current_parent_state == "completed":
            return child.get("state") in ["download-source", "pending-build"]
        if current_parent_state == "nar-cache-hit":
            return child.get("state") in ["download-source", "pending-build"]
        return False

    def visit(node: dict):
        if node["state"] == "completed":
            summary["done"] += 1
        elif node["state"] == "nar-cache-hit":
            summary["cache"] += 1
        else:
            summary["build"] += 1
        summary["size"] += node.get("size") or 0
        for child in node.get("children", []):
            if should_ignore_child(node["state"], child):
                continue
            visit(child)

    for child in children:
        if should_ignore_child(parent_state, child):
            continue
        visit(child)
    return summary


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
    url_size_cache: dict[str, int],
    root_drv_key: str,
    reverse_deps: dict[str, list[dict]],
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
    output_summary = summarize_outputs(outputs, path_info_cache)
    state = output_summary["state"]
    size = output_summary["size"]
    source_urls = extract_urls_from_drv(drv)
    source_size = 0

    # If a non-substitutable derivation has a URL source, use HEAD/Range size.
    if state == "pending-build" and source_urls:
        source_size = max((url_size_cache.get(url, 0) for url in source_urls), default=0)
        size = source_size

    # If it's a source derivation (builtin:fetchurl, etc.), mark it separately.
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
        child_node = build_tree(drv_data, path_info_cache, url_size_cache, child_key, reverse_deps, visited)
        if child_node:
            child_node["ignoredInParentSummary"] = (
                (state == "completed" and child_node.get("state") == "download-source")
                or (state == "nar-cache-hit" and child_node.get("state") in ["download-source", "pending-build"])
            )
            children.append(child_node)

    # Sort children by name
    children.sort(key=lambda c: c["name"])

    child_summary = summarize_children(children, state)
    total_size = (size or 0) + child_summary["size"]

    node = {
        "id": root_drv_key,
        "name": name,
        "state": state,
        "ignoredInParentSummary": False,
        "size": size,
        "narSize": output_summary["narSize"],
        "fileSize": output_summary["fileSize"],
        "sourceSize": source_size,
        "sourceUrls": source_urls,
        "totalSize": total_size,
        "childSummary": child_summary,
        "system": system,
        "outputs": output_summary["outputs"],
        "inputDrvCount": len(input_drv_keys),
        "inputSrcCount": len(input_srcs),
        "referencedBy": reverse_deps.get(root_drv_key, []),
        "children": children,
    }

    return node


def find_duplicates(drv_data: dict, reverse_deps: dict[str, list[dict]], path_info_cache: dict) -> list[dict]:
    """
    Find packages that appear with multiple versions.
    Groups derivations by base name, returns only groups with >1 version.
    Deduplicates identical full names (multiple .drv files for same package).
    """
    raw_entries: dict[str, dict] = {}
    for drv_key, drv in drv_data.items():
        name = drv.get("name", drv_key)
        _base, version = parse_pkg_name(name)

        if not version:
            continue

        is_source = any(
            hint in name
            for hint in [".tar", ".zip", ".patch", "-source"]
        )
        if is_source:
            continue

        output_summary = summarize_outputs(drv.get("outputs", {}), path_info_cache)
        refs = reverse_deps.get(drv_key, [])

        if name in raw_entries:
            existing = raw_entries[name]
            merged_refs = {ref["id"]: ref for ref in existing["referencedBy"]}
            merged_refs.update({ref["id"]: ref for ref in refs})
            existing["referencedBy"] = sorted(merged_refs.values(), key=lambda ref: ref["name"])
        else:
            raw_entries[name] = {
                "drvKey": drv_key,
                "name": name,
                "version": version,
                "state": output_summary["state"],
                "size": output_summary["size"],
                "narSize": output_summary["narSize"],
                "fileSize": output_summary["fileSize"],
                "referencedBy": sorted(refs, key=lambda ref: ref["name"]),
            }

    groups: dict[str, list[dict]] = defaultdict(list)
    for entry in raw_entries.values():
        base, _ = parse_pkg_name(entry["name"])
        groups[base].append(entry)

    duplicates = []
    for base_name, versions in sorted(groups.items()):
        if len(versions) <= 1:
            continue

        versions.sort(key=lambda v: v["name"])
        duplicates.append({
            "name": base_name,
            "versions": versions,
            "totalSize": sum(v.get("size") or 0 for v in versions),
            "totalRefs": sum(len(v["referencedBy"]) for v in versions),
        })

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
        help="Compatibility no-op: cache-hit narinfo sizes are fetched by default",
    )
    parser.add_argument(
        "--no-fetch-sizes",
        action="store_true",
        help="Skip remote narinfo and URL HEAD size requests",
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
    reverse_deps: dict[str, list[dict]] = defaultdict(list)
    for drv_key, drv in drv_data.items():
        inputs = drv.get("inputDrvs", drv.get("inputs", {}).get("drvs", {}))
        if isinstance(inputs, dict):
            for inp_key in inputs:
                reverse_deps[inp_key].append({"id": drv_key, "name": drv.get("name", drv_key)})

    for refs in reverse_deps.values():
        refs.sort(key=lambda ref: ref["name"])

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

    # Step 4b: For nar-cache-hit paths, query substituters for FileSize/NarSize.
    cache_hit_paths = [
        p for p in all_output_paths
        if p in path_info_cache and path_info_cache[p] is None
    ]
    if cache_hit_paths and not args.no_fetch_sizes:
        print(f"   Querying substituters for {len(cache_hit_paths)} cache-hit narinfos...", file=sys.stderr)
        sub_infos = get_substituter_infos(cache_hit_paths)
        for p in cache_hit_paths:
            path_info_cache[p] = sub_infos.get(p, {
                "_cacheHit": True,
                "fileSize": 0,
                "narSize": 0,
            })
        print(f"   Got narinfo for {len(sub_infos)}/{len(cache_hit_paths)} paths from substituters", file=sys.stderr)
    elif cache_hit_paths:
        print(f"   {len(cache_hit_paths)} paths are cache-hit (remote size fetch skipped)", file=sys.stderr)

    # Step 4c: For pending URL-backed derivations, use HEAD/Range size as source size.
    url_size_cache: dict[str, int] = {}
    if not args.no_fetch_sizes:
        pending_urls = []
        for drv in drv_data.values():
            output_summary = summarize_outputs(drv.get("outputs", {}), path_info_cache)
            if output_summary["state"] == "pending-build":
                pending_urls.extend(extract_urls_from_drv(drv))
        if pending_urls:
            unique_pending_urls = list(dict.fromkeys(pending_urls))
            print(f"   Querying source URL sizes for {len(unique_pending_urls)} pending URLs...", file=sys.stderr)
            url_size_cache = get_url_sizes(unique_pending_urls)

    # Step 5: Build the tree
    print(f"   Building tree...", file=sys.stderr)
    tree = build_tree(drv_data, path_info_cache, url_size_cache, root_key, reverse_deps)

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