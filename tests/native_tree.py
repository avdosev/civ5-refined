#!/usr/bin/env python3
"""Native UI recorder regressions: execute external Lua, don't repair its bugs."""
from pathlib import Path
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'dev-utils'))
from native_tech_tree import references
from native_tree.engine import capture,database
from native_tree.render import rect,render,Textures


def pipes(scene,texture=None):
    result=[i['roots'][0] for i in scene['instances'] if i['template']=='TechPipeInstance']
    return [c for c in result if not texture or c['texture']==texture]


def test_current():
    db,hashes=database()
    scene=capture(db)
    assert scene['lua']=='Lua 5.1'
    assert len(scene['technologies'])==97 and len(scene['edges'])==158
    cards=[i['roots'][0] for i in scene['instances'] if i['template']=='TechButtonInstance']
    techs={r['ID']:r for r in scene['technologies']}
    assert len(cards)==97 and len(pipes(scene))==618
    for c in cards:
        t=techs[c['firstVoid1']]
        # Assert the *captured call*, not a second placement inside the painter.
        assert c['offset']=={'x':t['GridX']*366+64,'y':(t['GridY']-5)*68+32}
    before=db.execute('SELECT GridX,GridY FROM Technologies ORDER BY ID').fetchall()
    with tempfile.TemporaryDirectory() as temp:
        target=Path(temp)/'loaded.db'
        import sqlite3
        copy=sqlite3.connect(target);db.backup(copy);copy.close()
        loaded,_=database(target,loaded=True)
        assert [tuple(r) for r in loaded.execute('SELECT GridX,GridY FROM Technologies ORDER BY ID')]==[tuple(r) for r in before]
        loaded.execute('DELETE FROM Language_RU_RU')
        without_localization=capture(loaded)
        assert without_localization['localization']['TXT_KEY_TECH_REFINED_AI_SHORT_NAME']=='Прикладной ИИ'
    print('PASS: 97 native card placements, 618 actual pipe controls, 158 edges; loaded DB not migrated twice')


def isolated(span=1):
    db,_=database(stage='stock')
    db.execute('DELETE FROM Technology_PrereqTechs')
    db.execute("UPDATE Technologies SET GridX=10,GridY=2 WHERE Type='TECH_COMPUTERS'")
    db.execute("UPDATE Technologies SET GridX=11,GridY=? WHERE Type='TECH_INTERNET'",(2+span,))
    db.execute("INSERT INTO Technology_PrereqTechs VALUES ('TECH_INTERNET','TECH_COMPUTERS')")
    return db


def test_native_defects():
    # These values are observed API calls of the original renderer. Its vertical
    # path disappears at five rows; the recorder must NOT connect the endpoints.
    for span,height in [(1,42),(2,110),(3,156),(4,212),(5,None)]:
        s=capture(isolated(span))
        v=pipes(s,'TechBranchV.dds')
        assert len(v)==(0 if height is None else 1)
        if v:assert v[0]['size']['y']==height
    s=capture(isolated(4))
    vertical=pipes(s,'TechBranchV.dds')[0]
    bottom=[c for c in pipes(s,'TechBranches.dds')
            if c['textureOffset']=={'x':0,'y':72}][0]
    vr=rect(vertical,(0,0,6000,740));br=rect(bottom,(0,0,6000,740))
    assert br[1]-(vr[1]+vr[3])==6, 'native four-row image rectangles leave a six-pixel gap'
    # Shared downward adapter stays in the source column even when all three
    # destinations are two columns away. No idealized destination-side elbow.
    db=isolated()
    db.execute('DELETE FROM Technology_PrereqTechs')
    for t,y in [('TECH_COMPUTERS',4),('TECH_INTERNET',3),('TECH_TELECOM',4),('TECH_LASERS',5)]:
        db.execute('UPDATE Technologies SET GridX=?,GridY=? WHERE Type=?',(10 if t=='TECH_COMPUTERS' else 12,y,t))
    db.executemany('INSERT INTO Technology_PrereqTechs VALUES (?,?)',[(t,'TECH_COMPUTERS') for t in ['TECH_INTERNET','TECH_TELECOM','TECH_LASERS']])
    s=capture(db)
    right_down=[c for c in pipes(s,'TechBranches.dds') if c['textureOffset']=={'x':72,'y':0}][0]
    assert right_down['offset']['x']==10*366+354
    assert all(c['offset']['x']==12*366 for c in pipes(s,'TechBranchV.dds'))
    print('PASS: actual five-row missing segment, four-row six-pixel gap, distant mixed adapter mismatch preserved')


def test_sql_and_pixels():
    db,_=database()
    with tempfile.TemporaryDirectory() as temp:
        sql=Path(temp)/'move.sql';sql.write_text("UPDATE Technologies SET GridX=24,GridY=1 WHERE Type='TECH_FUTURE_TECH';")
        changed,_=database(extra_sql=[sql])
        s=capture(changed)
        future=changed.execute("SELECT ID FROM Technologies WHERE Type='TECH_FUTURE_TECH'").fetchone()[0]
        c=next(i['roots'][0] for i in s['instances'] if i['template']=='TechButtonInstance' and i['roots'][0]['firstVoid1']==future)
        assert c['offset']=={'x':24*366+64,'y':-240}
        m=render(s,Path(temp)/'render.png',columns=(14,25))
        assert Path(m['image']).is_file()
        from PIL import Image
        # Supplied original textures are sampled at their actual atlas offsets,
        # rather than replaced with the reconstructed drawing or stretched.
        atlas=Image.new('RGBA',(128,128))
        atlas.putpixel((76,9),(200,100,50,255))
        atlas.save(Path(temp)/'TechBranches.dds')
        sampled=Textures(temp).sprite({'texture':'TechBranches.dds','textureOffset':{'x':72,'y':0}},(32,42))
        assert sampled.size==(32,42) and sampled.getpixel((4,9))==(200,100,50,255)
        im=Image.open(m['image'])
        assert im.height==740 and len(im.getcolors(im.width*im.height))>100
        assert {'TechBranchH.dds','TechBranchV.dds','TechBranches.dds'}==set(m['reconstructed_textures'])
        assert any('Refined_Technologies' in i.get('texture','') for card in m['cards'] for i in card['icons'])
    print('PASS: extra SQL changes captured placement; image uses native controls and real mod DDS, not graph routes')


if __name__=='__main__':
    references()
    test_current();test_native_defects();test_sql_and_pixels()
