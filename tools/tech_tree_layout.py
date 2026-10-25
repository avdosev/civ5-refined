"""Check constraints of the stock BNW TechTree.lua connector renderer.

These are data/layout checks, not an assertion that a game screenshot was tested.
The stock renderer uses a shared outgoing adapter and vertical textures for
differences of 1..4 rows. Long horizontal runs stay at the prerequisite's row.
"""
from collections import defaultdict


def layout_issues(db):
    positions = {name: (x, y) for name, x, y in db.execute('SELECT Type, GridX, GridY FROM Technologies')}
    issues = []
    outgoing = defaultdict(list)
    for child, parent in db.execute('SELECT TechType, PrereqTech FROM Technology_PrereqTechs'):
        if child not in positions or parent not in positions:
            issues.append(f'missing technology: {parent} -> {child}')
            continue
        px, py = positions[parent]
        cx, cy = positions[child]
        # This overhaul changes the late tree. Do not reject stock early layouts.
        if px < 11 or cx < 12:
            continue
        outgoing[parent].append(child)
        if cx <= px:
            issues.append(f'non-forward connector: {parent} -> {child}')
        if abs(cy - py) > 4:
            issues.append(f'vertical span > 4: {parent} -> {child}')
        for other, (x, y) in positions.items():
            if px < x < cx and y == py:
                issues.append(f'line crosses card {other}: {parent} -> {child}')
    for parent, children in outgoing.items():
        columns = {positions[child][0] for child in children}
        if len(columns) > 1 and any(positions[c][1] != positions[parent][1] for c in children):
            issues.append(f'mixed outgoing adapter lengths: {parent}')
    return issues
