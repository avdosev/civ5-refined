#!/usr/bin/env python3
"""Render the complete BNW + current mod tree, offline, using Python stdlib."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import xml.etree.ElementTree as ET

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent


def generate(database=None):
    snapshot = json.loads((HERE / 'data/bnw-tech-tree.json').read_text())
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    if database:
        source = sqlite3.connect(Path(database).resolve().as_uri() + '?mode=ro', uri=True)
        source.backup(db)
        source.close()
    else:
        fields = {k: 'INTEGER' if isinstance(v, int) else 'TEXT'
                  for k, v in snapshot['technologies'][0].items() if k != 'name'}
        db.execute('CREATE TABLE Technologies (' + ','.join(k+' '+v for k,v in fields.items()) + ')')
        for row in snapshot['technologies']:
            db.execute('INSERT INTO Technologies VALUES ('+','.join('?' for _ in fields)+')',
                       [row[k] for k in fields])
        db.execute('CREATE TABLE Technology_PrereqTechs (TechType TEXT, PrereqTech TEXT)')
        db.executemany('INSERT INTO Technology_PrereqTechs VALUES (?,?)', [(c,p) for p,c in snapshot['edges']])
    baseline = {r['Type']: dict(r) for r in db.execute('SELECT * FROM Technologies')}
    old_edges = {tuple(r) for r in db.execute('SELECT PrereqTech,TechType FROM Technology_PrereqTechs')}
    if len(baseline) != 81 or any(k.startswith('TECH_REFINED_') for k in baseline):
        raise ValueError('Нужна чистая база BNW (81 технология), без уже применённого мода.')
    names = {r['Type']: r['name'] for r in snapshot['technologies']}
    # Expand old localized card abbreviations and use the project's terminology.
    names.update({
        'TECH_PARTICLE_PHYSICS': 'Физика элементарных частиц',
        'TECH_ROBOTICS': 'Робототехника',
        'TECH_TELECOM': 'Телекоммуникации',
        'TECH_REFRIGERATION': 'Охлаждение',
        'TECH_MACHINERY': 'Механизмы',
        'TECH_PRINTING_PRESS': 'Книгопечатание',
        'TECH_ATOMIC_THEORY': 'Атомная теория',
        'TECH_CONSTRUCTION': 'Строительство',
        'TECH_ADVANCED_BALLISTICS': 'Усовершенствованная баллистика',
        'TECH_BALLISTICS': 'Баллистика',
        'TECH_COMBUSTION': 'Двигатель внутреннего сгорания',
        'TECH_STEALTH': 'Стелс',
    })
    text = {r.attrib['Tag']: r.findtext('Text', '') for r in
            ET.parse(ROOT / 'mod/Text/Localization.xml').getroot().findall('Language_RU_RU/Row')}
    # Only project writes to technology tables. Other gameplay statements cannot
    # affect this graph. Derive their order from the package builder itself.
    paths = re.findall(r"'SQL/[^']+\.sql'", (ROOT / 'tools/build.py').read_text())
    hashes = {}
    for quoted in dict.fromkeys(paths):
        path = ROOT / 'mod' / quoted.strip("'")
        sql = path.read_text()
        hashes[str(path.relative_to(ROOT))] = hashlib.sha256(sql.encode()).hexdigest()
        pending = ''
        for line in sql.splitlines(True):
            pending += line
            if not sqlite3.complete_statement(pending):
                continue
            clean = re.sub(r'--[^\n]*', '', pending).strip()
            if re.match(r'(?:INSERT\s+(?:OR\s+\w+\s+)?INTO|UPDATE|DELETE\s+FROM)\s+(?:Technologies|Technology_PrereqTechs)\b', clean, re.I):
                db.executescript(pending)
            pending = ''
    rows = [dict(r) for r in db.execute('SELECT * FROM Technologies ORDER BY GridX,GridY')]
    edges = {tuple(r) for r in db.execute('SELECT PrereqTech,TechType FROM Technology_PrereqTechs')}
    ids = {r['Type'] for r in rows}
    assert all(p in ids and c in ids for p,c in edges)
    assert len({(r['GridX'],r['GridY']) for r in rows}) == len(rows), 'Наложение карточек'
    def visit(t, active, done):
        if t in active:
            raise ValueError('Цикл: '+t)
        if t in done:
            return
        active.add(t)
        for p,c in edges:
            if p == t:
                visit(c,active,done)
        active.remove(t)
        done.add(t)
    done = set()
    visit('TECH_AGRICULTURE',set(),done)
    assert done == ids, 'Недостижимые технологии: '+str(ids-done)
    nodes = []
    for r in rows:
        t = r['Type']
        before = baseline.get(t)
        incoming = {p for p,c in edges if c == t}
        old_incoming = {p for p,c in old_edges if c == t}
        nodes.append(dict(id=t, name=text.get(r['Description'],names.get(t,t)).split('|')[0],
                          x=r['GridX'],y=r['GridY'],era=r['Era'],cost=r['Cost'],
                          new=before is None, changed=before is not None and incoming != old_incoming,
                          moved=before is not None and (r['GridX'],r['GridY']) != (before['GridX'],before['GridY']),
                          help=text.get(r['Help'],''),parents=sorted(incoming),
                          removed=sorted(old_incoming-incoming)))
    return dict(nodes=nodes,edges=[dict(source=p,target=c,new=(p,c) not in old_edges) for p,c in sorted(edges)],
                hashes=hashes,source=snapshot['source'],sourceMode='Чистая игровая база' if database else 'Публичный снимок BNW')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database', help='Чистая Civ5DebugDatabase.db; открывается только для чтения')
    args = parser.parse_args()
    data = generate(args.database)
    payload = json.dumps(data,ensure_ascii=False).replace('<','\\u003c')
    target = HERE / 'tech-tree.html'
    target.write_text((HERE/'tech-tree.template.html').read_text().replace('__TREE_DATA__',payload))
    print(f'{target}: {len(data["nodes"])} technologies, {len(data["edges"])} prerequisites')
