#!/usr/bin/env python3
"""Execute BNW TechTree.lua and export its actual UI controls as PNG/HTML."""
import argparse
import base64
import hashlib
import json
from functools import partial
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import threading
import time
from urllib.request import urlopen

from native_tree.engine import CACHE, ROOT, action_paths, capture, database


def references(fetch=False):
    manifest=json.loads((Path(__file__).parent/'native_tree/references.json').read_text())
    CACHE.mkdir(parents=True,exist_ok=True)
    for name,record in manifest.items():
        path=CACHE/name
        if not path.exists():
            if not fetch:
                raise FileNotFoundError(f'{name} not cached. Run with --fetch-references once, or supply --database and --ui-dir.')
            data=urlopen(record['url'],timeout=60).read()
            if hashlib.sha256(data).hexdigest()!=record['sha256']:
                raise ValueError('Reference download checksum mismatch: '+name)
            path.write_bytes(data)
        if hashlib.sha256(path.read_bytes()).hexdigest()!=record['sha256']:
            raise ValueError('Cached reference changed: '+str(path))
    return manifest


def build(args):
    from native_tree.render import render,rect
    from native_tree.geometry import inspect
    provenance=references(args.fetch_references) if not (args.database and args.ui_dir) else {}
    db,sql_hashes=database(args.database,args.stage,args.loaded_database,args.sql)
    scene=capture(db,args.ui_dir,args.width,args.height,args.researched,args.language,args.civilization,renderer=args.renderer)
    # Preserve the source hashes and exact controls for independent inspection.
    scene['sql_hashes']=sql_hashes
    scene['input']=dict(database=str(args.database or CACHE/'Civ5DebugDatabase.db'),
                       loaded_database=args.loaded_database,stage=args.stage)
    scene['reference_origins']=provenance
    out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
    (out/'trace.json').write_text(json.dumps(scene,ensure_ascii=False,indent=2))
    meta=render(scene,out/'scene.png',args.assets,args.font)
    inspect(scene,meta,args.assets)
    meta['sources']=scene['sources'];meta['sql_hashes']=sql_hashes;meta['stage']=args.stage+' / '+args.renderer
    meta['tool_hashes']=scene['tool_hashes']
    meta['civilization']=scene['civilization']
    meta['generation']=str(time.time_ns())
    meta['edge_count']=len(scene['edges'])
    meta['source_note']='Packaged mod/UI Lua controller; external native XML/TechButtonInclude.' if args.renderer=='mod' else 'Unchanged external BNW UI mirror; pinned source hashes.'
    meta['limits']=[
        'Geometry and visibility are emitted under Lua 5.1 by '+meta['source_note'],
        'The game renderer itself is not running. Grid9 skins and unavailable original portraits use visible substitutes.',
        'Without --assets, the appearance of three stock line sprites is reconstructed; actual control rectangles and atlas offsets are unchanged.',
        'Locale font/truncation use a local fallback. Research state is explicitly simulated, not read from a save.',
        'Optional Technology_FreePromotions is empty in this BNW snapshot; mirror Duel options are disabled.'
    ]
    (out/'controls.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
    payload=json.dumps(meta,ensure_ascii=False).replace('<','\\u003c')
    picture=base64.b64encode((out/'scene.png').read_bytes()).decode()
    template=(Path(__file__).parent/'native_tree/viewer.html').read_text()
    (out/'index.html').write_text(template.replace('__DATA__',payload).replace('__PNG__',picture))
    (out/'build.json').write_text(json.dumps({'generation':meta['generation'],'error':None}))
    if args.columns:
        render(scene,out/'late.png',args.assets,args.font,args.columns)
    print(out.resolve()/'index.html')
    print(f'{len(meta["cards"])} cards / {meta["edge_count"]} prerequisites / {len(meta["pipes"])} native pipe controls / Lua 5.1')
    print('Trace:',out.resolve()/'trace.json')
    print('Reconstructed stock sprites:',', '.join(meta['reconstructed_textures']) or 'none')
    return scene,meta


def serve(args):
    class LocalHandler(SimpleHTTPRequestHandler):
        def log_message(self,format,*values):
            if self.path.split('?',1)[0]!='/build.json':
                super().log_message(format,*values)
    handler=partial(LocalHandler,directory=str(args.output))
    server=ThreadingHTTPServer(('127.0.0.1',args.port),handler)
    thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
    print(f'Local viewer: http://127.0.0.1:{args.port}/index.html',flush=True)
    watch=[ROOT/'mod'/p for p in action_paths()]+list(args.sql)
    watch += [Path(args.ui_dir or CACHE)/n for n in ('TechTree.lua','TechTree.xml','TechButtonInclude.lua')]
    watch += list((ROOT/'mod/UI').glob('*.lua'))
    watch += [ROOT/'dev-utils/native_tree/viewer.html']
    def signature():
        result=[]
        for p in watch:
            try:
                stat=p.stat();result.append((stat.st_mtime_ns,stat.st_size))
            except FileNotFoundError:result.append((None,None))
        return result
    previous=signature()
    try:
        while True:
            time.sleep(1)
            if args.watch:
                current=signature()
                if current!=previous:
                    previous=current
                    try: build(args)
                    except Exception as e:
                        print('BUILD FAILED:',e,flush=True)
                        (args.output/'build.json').write_text(json.dumps({'generation':None,'error':str(e)}))
    except KeyboardInterrupt:
        server.shutdown();server.server_close()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fetch-references',action='store_true',help='Fetch pinned external UI files and clean BNW data into ignored local cache')
    parser.add_argument('--database',type=Path,help='Clean BNW DB, opened read-only; copied to memory')
    parser.add_argument('--loaded-database',action='store_true',help='Use already modded DB as-is; do NOT apply migrations again')
    parser.add_argument('--ui-dir',type=Path,help='Directory containing TechTree.lua/XML and TechButtonInclude.lua from the target game')
    parser.add_argument('--renderer',choices=['mod','stock'],default='mod',help='Execute packaged game controller (default) or unchanged external stock controller')
    parser.add_argument('--stage',default='current',choices=['stock','current']+[Path(p).stem for p in action_paths() if p.endswith('.sql')])
    parser.add_argument('--sql',action='append',default=[],type=Path,help='Additional experimental SQL on disposable DB, after selected stage')
    parser.add_argument('--assets',type=Path,help='Directory of extracted original DDS textures/atlases; never redistributed')
    parser.add_argument('--font',type=Path,help='Optional original UI font')
    parser.add_argument('--width',type=int,default=1920)
    parser.add_argument('--height',type=int,default=1080)
    parser.add_argument('--language',choices=['ru','en'],default='ru')
    parser.add_argument('--civilization',default='CIVILIZATION_AMERICA',help='Civilization Type for the original unique-unit/building selection')
    parser.add_argument('--researched',nargs='*',default=[],help='Explicit list of researched technology Types for card states')
    parser.add_argument('--columns',nargs=2,type=int,default=[14,24],metavar=('FIRST','END'))
    parser.add_argument('--output',type=Path,default=ROOT/'dist/native-tree')
    parser.add_argument('--serve',action='store_true',help='Serve the generated viewer on loopback only')
    parser.add_argument('--watch',action='store_true',help='Rebuild and reload on SQL/XML/UI source changes; requires --serve')
    parser.add_argument('--port',type=int,default=8765)
    args=parser.parse_args()
    if args.loaded_database and not args.database:parser.error('--loaded-database requires --database')
    if args.watch and not args.serve:parser.error('--watch requires --serve')
    build(args)
    if args.serve:serve(args)
