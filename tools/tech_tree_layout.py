"""Check constraints of the stock BNW TechTree.lua connector renderer.

These are data/layout checks, not an assertion that a game screenshot was tested.
The stock renderer uses a shared outgoing adapter and vertical textures for
differences of 1..4 rows. Long horizontal runs stay at the prerequisite's row.
"""
from collections import defaultdict


def layout_issues(db, include_industrial=False):
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
        if (px < 11 or cx < 12) and not (include_industrial and parent in {
            'TECH_STEAM_POWER', 'TECH_FERTILIZER', 'TECH_DYNAMITE', 'TECH_RAILROAD'}):
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
        if len(columns) > 1:
            px, py = positions[parent]
            up = [c for c in children if positions[c][1] < py]
            down = [c for c in children if positions[c][1] > py]
            center = any(positions[c][1] == py for c in children)
            longest = max(columns)
            # Native right adapter types 5/6/7 put the downward corner at the
            # parent column; types 6/7 put the upward corner at the longest run.
            # Distinct lengths CAN work when branches use these exact sides.
            down_column = px + 1 if down and (up or center) else longest
            if any(positions[c][0] != longest for c in up) or any(positions[c][0] != down_column for c in down):
                issues.append(f'mixed outgoing adapter lengths: {parent}')
    return issues
