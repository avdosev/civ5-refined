#!/usr/bin/env python3
"""Check real DDS pixels, portrait references and gameplay preservation without Pillow."""
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]


def validate(db):
    icons = json.loads((ROOT / 'assets/icons/catalog.json').read_text())['icons']
    tables = ('Buildings', 'Projects', 'Processes', 'Technologies')
    before = {table: {r['Type']: dict(r) for r in db.execute('SELECT * FROM ' + table)}
              for table in tables}
    # The mechanical BNW fixture omits art tables. This is the standard atlas schema.
    db.execute('''CREATE TABLE IF NOT EXISTS IconTextureAtlases
        (Atlas TEXT, IconSize INTEGER, Filename TEXT, IconsPerRow INTEGER, IconsPerColumn INTEGER,
         PRIMARY KEY (Atlas, IconSize))''')
    db.executescript((ROOT / 'mod/SQL/Icons.sql').read_text())
    by_type = {icon['type']: icon for icon in icons}
    assert len(by_type) == len(icons) == 37
    assert sum(t.startswith('BUILDING_') for t in by_type) == 10
    assert sum(t.startswith('PROJECT_') for t in by_type) == 10
    assert sum(t.startswith('PROCESS_') for t in by_type) == 1
    tech_types = {t for t in by_type if t.startswith('TECH_')}
    assert len(tech_types) == 16
    assert tech_types == {t for t in before['Technologies'] if t.startswith('TECH_REFINED_')}
    assert set(by_type) <= {t for table in before.values() for t in table}
    for table in tables:
        after = {r['Type']: dict(r) for r in db.execute('SELECT * FROM ' + table)}
        assert set(after) == set(before[table])
        for type_, row in after.items():
            old = before[table][type_]
            if type_ in by_type:
                icon = by_type[type_]
                assert row['IconAtlas'] == 'REFINED_' + icon['atlas'] + '_ATLAS'
                assert row['PortraitIndex'] == icon['index']
                old.update(IconAtlas=row['IconAtlas'], PortraitIndex=row['PortraitIndex'])
            assert old == row, (table, type_, 'unrelated field changed')
    seen = set()
    # Independently fixed SDK porthole dimensions. Full-cell artwork previously
    # passed alpha checks while hiding the tech frame and overlapping unlocks.
    diameters = {256: 176, 214: 144, 128: 88, 80: 52, 64: 44, 45: 31, 32: 22}
    for atlas, size, filename, cols, rows in db.execute(
            "SELECT * FROM IconTextureAtlases WHERE Atlas LIKE 'REFINED_%'"):
        data = (ROOT / 'mod/Art/Icons' / filename).read_bytes()
        header = struct.unpack('<31I', data[4:128])
        assert data[:4] == b'DDS ' and header[0] == 124
        height, width, pitch, depth, mips = header[2:7]
        assert (width, height, pitch, depth, mips) == (size * cols, size * rows, size * cols * 4, 0, 0)
        assert header[18:26] == (32, 65, 0, 32, 0xFF0000, 0xFF00, 0xFF, 0xFF000000)
        assert len(data) == 128 + width * height * 4
        assert (cols, rows) == (4, 4)
        selected = [i for i in icons if atlas == 'REFINED_' + i['atlas'] + '_ATLAS']
        indices = {i['index'] for i in selected}
        assert len(indices) == len(selected)
        for index in range(cols * rows):
            x, y = index % cols * size, index // cols * size
            alpha = bytearray()
            for dy in range(size):
                start = 128 + ((y + dy) * width + x) * 4 + 3
                alpha.extend(data[start:start + size * 4:4])
            if index in indices:
                assert min(alpha) == 0 and max(alpha) == 255
                assert alpha[(size // 2) * size + size // 2] > 240
                assert all(alpha[k] == 0 for k in (0, size - 1, size * (size - 1), size * size - 1))
                visible = [(k % size, k // size) for k, a in enumerate(alpha) if a > 128]
                left = min(p[0] for p in visible)
                top = min(p[1] for p in visible)
                right = max(p[0] for p in visible) + 1
                bottom = max(p[1] for p in visible) + 1
                expected = diameters[size]
                if atlas == 'REFINED_TECHNOLOGIES_ATLAS':
                    expected += 2 * {256: 16, 214: 13, 128: 8, 80: 5, 64: 4, 45: 3}[size]
                assert abs((right - left) - expected) <= 1, (filename, index, 'wrong porthole width')
                assert abs((bottom - top) - expected) <= 1, (filename, index, 'wrong porthole height')
                assert abs(left + right - size) <= 1 and abs(top + bottom - size) <= 1
                expected_area = 3.14159265 / 4 * (expected / size) ** 2
                assert abs(len(visible) / (size * size) - expected_area) < .02
                # The whole border strip must stay transparent, not only corners.
                # LANCZOS support extends up to three target pixels beyond
                # the hard disk edge with a tiny antialiasing fringe.
                margin = max(0, (size - expected) // 2 - 3)
                assert not any(a for k, a in enumerate(alpha)
                               if min(k % size, size - 1 - k % size,
                                      k // size, size - 1 - k // size) < margin), (filename, index, 'padding is not clear')
            else:
                assert not any(alpha), (filename, index, 'unused cell is not transparent')
        seen.add((atlas, size))
    assert seen == ({(f'REFINED_{group}_ATLAS', size) for group in ('BUILDINGS', 'PROGRAMS')
                     for size in (256, 128, 80, 64, 45, 32)} |
                    {('REFINED_TECHNOLOGIES_ATLAS', size) for size in (256, 214, 128, 80, 64, 45)})
    print('PASS: 37 unique portraits (all 16 new technologies), 18 legacy DDS atlases, alpha, SQL and gameplay preservation')


if __name__ == '__main__':
    from victories import database, apply_modernization, apply_presentation
    db = database()
    apply_modernization(db)
    apply_presentation(db)
    validate(db)
