"""Run the external TechTree Lua against the actual, migrated SQLite tables."""
import ast
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT / 'dev-utils/.cache/native-tree'


def action_paths():
    """Read the real package action list, rather than maintain a second order."""
    tree = ast.parse((ROOT / 'tools/build.py').read_text())
    for node in ast.walk(tree):
        if isinstance(node, ast.For) and isinstance(node.iter, ast.List):
            values = [ast.literal_eval(v) for v in node.iter.elts]
            if values and all(isinstance(v, str) and v.startswith(('Text/', 'SQL/')) for v in values):
                return values
    raise ValueError('Cannot find database actions in tools/build.py')


def database(source=None, stage='current', loaded=False, extra_sql=()):
    source = Path(source or CACHE / 'Civ5DebugDatabase.db').resolve()
    db = sqlite3.connect(':memory:')
    original = sqlite3.connect(source.as_uri() + '?mode=ro', uri=True)
    original.backup(db)
    original.close()
    db.row_factory = sqlite3.Row
    for lang in ('Language_RU_RU', 'Language_en_US'):
        db.execute(f'CREATE TABLE IF NOT EXISTS {lang} (Tag TEXT PRIMARY KEY, Text TEXT)')
    hashes = {}
    if not loaded:
        count = db.execute('SELECT COUNT(*) FROM Technologies').fetchone()[0]
        if count != 81 or db.execute("SELECT 1 FROM Technologies WHERE Type LIKE 'TECH_REFINED_%'").fetchone():
            raise ValueError('Expected a clean BNW database; use --loaded-database for an already modded snapshot')
        if stage != 'stock':
            for name in action_paths():
                path = ROOT / 'mod' / name
                content=path.read_bytes()
                hashes[name] = hashlib.sha256(content).hexdigest()
                if name.endswith('.xml'):
                    for table in ET.fromstring(content):
                        for row in table:
                            if row.tag != 'Row':
                                raise ValueError(f'Unsupported XML database operation: {row.tag}')
                            values = dict(row.attrib)
                            values.update({c.tag: c.text or '' for c in row})
                            fields = list(values)
                            db.execute(f'INSERT INTO "{table.tag}" (' + ','.join('"'+f+'"' for f in fields)
                                       + ') VALUES (' + ','.join('?' for _ in fields) + ')', list(values.values()))
                else:
                    db.executescript(content.decode('utf-8-sig'))
                if stage != 'current' and Path(name).stem.lower() == stage.lower():
                    break
    for path in extra_sql:
        path = Path(path)
        content=path.read_bytes()
        hashes[str(path)] = hashlib.sha256(content).hexdigest()
        db.executescript(content.decode('utf-8-sig'))
    return db, hashes


def pair(text, fallback=(0, 0)):
    if not text:
        return list(fallback)
    parts = text.replace('.', ',').split(',')
    if len(parts) != 2:
        raise ValueError(f'Unsupported UI size/offset: {text}')
    return [v if v.lower() == 'full' else float(v) for v in parts]


def xml_spec(node):
    xy = pair(node.get('Offset'))
    size = pair(node.get('Size'))
    uv = pair(node.get('TextureOffset'))
    return dict(id=node.get('ID'), tag=node.tag, attrs=dict(node.attrib),
                offset=dict(zip(('x', 'y'), xy)), size=dict(zip(('x', 'y'), size)),
                textureOffset=dict(zip(('x', 'y'), uv)), hidden=node.get('Hidden') == '1',
                children=[xml_spec(c) for c in node])


def capture(db, ui_dir=None, width=1920, height=1080, researched=(), language='ru', civilization='CIVILIZATION_AMERICA'):
    from lupa.lua51 import LuaRuntime
    ui_dir = Path(ui_dir or CACHE)
    required = ('TechTree.lua', 'TechTree.xml', 'TechButtonInclude.lua')
    source_bytes={n:(ui_dir/n).read_bytes() for n in required}
    sources = {n: hashlib.sha256(b).hexdigest() for n,b in source_bytes.items()}
    lua = LuaRuntime(unpack_returned_tuples=True)
    g = lua.globals()
    def to_lua(value):
        if isinstance(value, dict):
            return lua.table_from({k: to_lua(v) for k, v in value.items()})
        if isinstance(value, (list, tuple)):
            return lua.table_from([to_lua(v) for v in value])
        return value
    def from_lua(t):
        if not hasattr(t, 'items'):
            return t
        items = list(t.items())
        if items and all(isinstance(k, int) for k, _ in items):
            return [from_lua(t[k]) for k in range(1, len(items)+1)]
        return {k: from_lua(v) for k, v in items}
    schema = {}
    types = {}
    for (name,) in db.execute("SELECT name FROM sqlite_master WHERE type='table'"):
        fields = {r['name']: r['type'].upper() for r in db.execute(f'PRAGMA table_info("{name}")')}
        schema[name] = fields
        if {'Type', 'ID'} <= fields.keys():
            types.update({r['Type']: r['ID'] for r in db.execute(f'SELECT Type,ID FROM "{name}"')})
    def query(name, condition):
        # This optional table occurs in the public UI mirror, but is absent in
        # the clean BNW snapshot. No such promotions exist in this mod either.
        if name == 'Technology_FreePromotions' and name not in schema:
            return to_lua([])
        if name not in schema:
            raise ValueError('Missing GameInfo table: ' + name)
        sql = f'SELECT * FROM "{name}"'
        args = []
        if isinstance(condition, str) and condition:
            # External game UI SQL conditions run only on the disposable DB.
            sql += ' WHERE ' + condition
        elif condition is not None:
            tests = []
            for k,v in condition.items():
                if k not in schema[name]:
                    raise ValueError(f'Unknown GameInfo field: {name}.{k}')
                tests.append('"'+k+'" = ?');args.append(v)
            if tests:
                sql += ' WHERE ' + ' AND '.join(tests)
        rows = []
        for row in db.execute(sql, args):
            rows.append({k: bool(v) if schema[name][k] == 'BOOLEAN' and v is not None else v
                         for k,v in dict(row).items()})
        return to_lua(rows)
    # Some game DebugDatabase snapshots omit localization entirely. Read-only
    # display fallbacks must not reapply any gameplay migration to those files.
    language_table='Language_' + ('RU_RU' if language == 'ru' else 'en_US')
    loc={}
    for path in sorted((ROOT/'mod/Text').glob('*.xml')):
        for row in ET.parse(path).getroot().findall(language_table+'/Row'):
            loc[row.get('Tag')]=row.findtext('Text','')
    loc.update({r['Tag']:r['Text'] for r in db.execute('SELECT * FROM '+language_table)})
    snapshot = json.loads((ROOT / 'dev-utils/data/bnw-tech-tree.json').read_text())
    for t in snapshot['technologies']:
        loc.setdefault(t['Description'], t['name'] if language == 'ru' else t['Type'].removeprefix('TECH_').replace('_', ' ').title())
    era_names = ['Древний мир','Античность','Средневековье','Возрождение','Промышленная эпоха','Новейшее время','Эпоха атома','Информационная эпоха']
    for era in db.execute('SELECT * FROM Eras ORDER BY ID'):
        loc.setdefault(era['Description'], era_names[era['ID']] if language == 'ru' else era['Type'].removeprefix('ERA_').title())
    loc.update({'TXT_KEY_TURNS': 'ход.' if language == 'ru' else 'turns', 'TXT_KEY_FREE': 'Бесплатно' if language == 'ru' else 'Free'})
    def localize(key, *args):
        text = loc.get(str(key), str(key))
        for i, value in enumerate(args, 1):
            text = re.sub(r'\{'+str(i)+r'[^}]*\}', str(value), text)
        return text
    def tech_help(id_):
        row = db.execute('SELECT Description,Help FROM Technologies WHERE ID=?', (id_,)).fetchone()
        return localize(row['Description']) + '\n' + localize(row['Help'])
    def object_help(table, id_):
        row = db.execute(f'SELECT Description FROM "{table}" WHERE ID=?', (id_,)).fetchone()
        return localize(row[0]) if row else str(id_)
    g.DB_QUERY = query;g.DB_TYPE = types.get;g.LOCALIZE = localize
    g.UTF8_LENGTH = lambda s: len(s)
    g.TRUNCATE = lambda s,n,*_: s if len(s) <= n else s[:max(0, int(n)-3)].rstrip() + '...'
    g.TECH_HELP = tech_help;g.OBJECT_HELP = object_help
    def atlas_lookup(index, size, atlas):
        row = db.execute('SELECT * FROM IconTextureAtlases WHERE Atlas=? AND IconSize=?', (atlas,size)).fetchone()
        if row:
            columns = int(row['IconsPerRow'])
            return to_lua(dict(x=(index % columns)*size, y=(index // columns)*size, file=row['Filename']))
        return to_lua(dict(x=0,y=0,file=f'__missing__/{atlas}/{index}/{size}'))
    g.ATLAS_LOOKUP = atlas_lookup
    g.SCREEN_WIDTH = width;g.SCREEN_HEIGHT = height
    civ = db.execute('SELECT ID FROM Civilizations WHERE Type=?',(civilization,)).fetchone()
    if not civ:raise ValueError('Unknown civilization: '+civilization)
    g.CIVILIZATION_ID = civ[0]
    researched = set(researched)
    ids = {r['ID']: r['Type'] for r in db.execute('SELECT ID,Type FROM Technologies')}
    g.RESEARCHED = to_lua({i: t in researched for i,t in ids.items()})
    parents = {}
    for t,p in db.execute('SELECT TechType,PrereqTech FROM Technology_PrereqTechs'):
        parents.setdefault(t, set()).add(p)
    g.RESEARCHABLE = to_lua({i: t not in researched and parents.get(t,set()) <= researched for i,t in ids.items()})
    xml = ET.fromstring(source_bytes['TechTree.xml'])
    instances = {n.get('Name'): [xml_spec(c) for c in n] for n in xml if n.tag == 'Instance'}
    screen = xml_spec(xml)
    screen['children'] = [xml_spec(n) for n in xml if n.tag != 'Instance']
    screen['size'] = {'x': width, 'y': height}
    g.XML_SCREEN = to_lua(screen);g.XML_INSTANCES = to_lua(instances)
    g.TECH_BUTTON_SOURCE = source_bytes['TechButtonInclude.lua'].decode('utf-8-sig')
    lua.execute((Path(__file__).parent / 'capture.lua').read_text())
    # Run the whole external source, including its actual InitialSetup() call.
    # This is deliberately not a port of its connector algorithm.
    lua.execute(source_bytes['TechTree.lua'].decode('utf-8-sig'), name='@TechTree.lua')
    g.RefreshDisplay()
    trace = from_lua(g.exportScene())
    trace['tool_hashes']={name:hashlib.sha256((Path(__file__).parent/name).read_bytes()).hexdigest()
                          for name in ('capture.lua','engine.py','render.py')}
    trace.update(width=width, height=height, lua=lua.eval('_VERSION'), sources=sources,
                 language=language, civilization=civilization,
                 technologies=[dict(r) for r in db.execute('SELECT * FROM Technologies')],
                 edges=[dict(r) for r in db.execute('SELECT * FROM Technology_PrereqTechs')],
                 localization=loc)
    return trace
