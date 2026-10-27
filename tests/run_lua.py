#!/usr/bin/env python3
"""Run shipped Lua 5.1 scripts against BNW-shaped behavioral mocks.
Runtime rule data comes from the actual SQL migrations, not a second rule list.
"""
import argparse
import json
from pathlib import Path
import sqlite3
import subprocess
import tempfile
from validate import fixture, ROOT


def lua(value):
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if value is None:
        return 'nil'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    if isinstance(value, (list, tuple)):
        return '{' + ','.join(lua(v) for v in value) + '}'
    return str(value)


if __name__ == '__main__':
    args = argparse.ArgumentParser()
    args.add_argument('--lua', default='lua5.1')
    options = args.parse_args()
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    fixture(db)
    for name in ['Gameplay', 'TechnologyRefinements', 'TechTreePresentation', 'UnitResources', 'Development']:
        db.executescript((ROOT / 'mod/SQL' / (name + '.sql')).read_text())
    data = {name: [dict(row) for row in db.execute('SELECT * FROM ' + name)]
            for name in ['Refined_Eurekas', 'Buildings', 'Technologies']}
    with tempfile.TemporaryDirectory(prefix='refined-lua-') as temp:
        path = Path(temp) / 'rules.lua'
        path.write_text('return ' + lua(data), encoding='utf-8')
        for script in ['tests/effects.lua', 'tests/development.lua']:
            subprocess.run([options.lua, script, str(path)], cwd=ROOT, check=True)
