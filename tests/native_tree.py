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
from native_tree.geometry import inspect,key


def pipes(scene,texture=None):
    result=[i['roots'][0] for i in scene['instances'] if i['template']=='TechPipeInstance']
    return [c for c in result if not texture or c['texture']==texture]


def test_current():
    partial,_=database(stage='Modernization')
    assert partial.execute('SELECT COUNT(*) FROM Technologies').fetchone()[0]==97
    assert partial.execute("SELECT GridY FROM Technologies WHERE Type='TECH_COMPUTERS'").fetchone()[0]==5
    db,hashes=database()
    scene=capture(db,renderer='stock')
    assert scene['lua']=='Lua 5.1'
    assert len(scene['technologies'])==97 and len(scene['edges'])==158
    cards=[i['roots'][0] for i in scene['instances'] if i['template']=='TechButtonInstance']
    techs={r['ID']:r for r in scene['technologies']}
    assert len(cards)==97 and len(pipes(scene))>500
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
        without_localization=capture(loaded,renderer='stock')
        assert without_localization['localization']['TXT_KEY_TECH_REFINED_AI_SHORT_NAME']=='Прикладной ИИ'
    print('PASS: 97 native card placements, actual pipe controls, 158 edges; loaded DB not migrated twice')


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
        s=capture(isolated(span),renderer='stock')
        v=pipes(s,'TechBranchV.dds')
        assert len(v)==(0 if height is None else 1)
        if v:assert v[0]['size']['y']==height
    s=capture(isolated(4),renderer='stock')
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
    s=capture(db,renderer='stock')
    right_down=[c for c in pipes(s,'TechBranches.dds') if c['textureOffset']=={'x':72,'y':0}][0]
    assert right_down['offset']['x']==10*366+354
    assert all(c['offset']['x']==12*366 for c in pipes(s,'TechBranchV.dds'))
    print('PASS: actual five-row missing segment, four-row six-pixel gap, distant mixed adapter mismatch preserved')


def test_sql_and_pixels():
    db,_=database()
    with tempfile.TemporaryDirectory() as temp:
        sql=Path(temp)/'move.sql';sql.write_text("UPDATE Technologies SET GridX=24,GridY=1 WHERE Type='TECH_FUTURE_TECH';")
        changed,_=database(extra_sql=[sql])
        s=capture(changed,renderer='stock')
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


def test_sprite_paths():
    db,_=database();scene=capture(db,renderer='stock')
    with tempfile.TemporaryDirectory() as temp:
        meta=inspect(scene,render(scene,Path(temp)/'current.png'))
        assert all(p['uses'] and p['origin']['kind'] in ('edge','adapter') for p in meta['pipes'])
        assert all(p['sprite'] in meta['pipe_sprites'] for p in meta['pipes'])
        # Native defects are asserted in the isolated regressions above.
        # Final gameplay paths are checked against the packaged controller below.
        # A long native H sprite really runs behind this unrelated card.
        db=isolated(0)
        db.execute("UPDATE Technologies SET GridX=0 WHERE Type NOT IN ('TECH_COMPUTERS','TECH_INTERNET','TECH_TELECOM')")
        db.execute("UPDATE Technologies SET GridX=13 WHERE Type='TECH_INTERNET'")
        db.execute("UPDATE Technologies SET GridX=11,GridY=2 WHERE Type='TECH_TELECOM'")
        scene=capture(db,renderer='stock');meta=inspect(scene,render(scene,Path(temp)/'crossing.png'))
        assert any(i['kind']=='wire_through_card' and i['card']=='TECH_TELECOM' for i in meta['issues'])
        assert any(i['kind']=='disconnected_path' and i.get('edge')==key('TECH_COMPUTERS','TECH_INTERNET') for i in meta['issues'])
    print('PASS: source attribution for every sprite, original masks for highlighting, pixel-level card occlusion')


def test_packaged_paths():
    # Execute the same two Lua files that are imported into the game VFS.
    db,_=database();scene=capture(db)
    with tempfile.TemporaryDirectory() as temp:
        meta=inspect(scene,render(scene,Path(temp)/'packaged.png'))
        assert not meta['issues'], meta['issues']
        assert all(p['origin']['kind']=='edge' and len(p['uses'])==1 for p in meta['pipes'])
        tracks={}
        for pipe in meta['pipes']:
            if pipe['texture']!='TechBranchV.dds':continue
            child=pipe['origin']['child'];x=pipe['rect'][0]
            tracks[child]=x
            assert pipe['rect'][3]<=96
        by_column={}
        for child,x in tracks.items():
            col=db.execute('SELECT GridX FROM Technologies WHERE Type=?',(child,)).fetchone()[0]
            assert col*366-32 < x+4 < col*366+64
            assert x not in by_column.setdefault(col,set()), 'unrelated vertical paths merged'
            by_column[col].add(x)
        # Both directions, including previously missing 4/5-row paths. No other
        # cards in this fixture: this is a rendering test, not a layout test.
        for span in [-9,-5,-4,-3,-1,0,1,3,4,5,9]:
            case=isolated(span)
            case.execute("UPDATE Technologies SET GridX=0 WHERE Type NOT IN ('TECH_COMPUTERS','TECH_INTERNET')")
            scene=capture(case)
            meta=inspect(scene,render(scene,Path(temp)/'span.png'))
            assert not meta['issues'], (span,meta['issues'])
    print('PASS: all packaged dependency paths connected and unobscured; native sprites span 0..9 rows in either direction')


def test_controller():
    db,_=database()
    # Assert the network protocol and all card states, not just a pretty PNG.
    capture(db,exercise=r'''
        local id=GameInfo.Technologies.TECH_COMPUTERS.ID
        local sent={}
        Network={SendResearch=function(...) sent={...} end}
        local p=Players[0]
        p.GetNumFreeTechs=function() return 2 end
        TechSelected(id)
        assert(sent[1]==id and sent[2]==2 and sent[3]==-1 and sent[4]==false)
        UIManager.GetShift=function() return true end
        TechSelected(id);assert(sent[4]==true)
        UIManager.GetShift=function() return false end
        sent={};TechSelected(-1);assert(#sent==0)
        local function root()
            for _,i in ipairs(recorded.instances) do
                if i.template=='TechButtonInstance' and i.roots[1].firstVoid1==id then return i.controls end
            end
        end
        local card=root()
        local function state(name)
            RefreshDisplay()
            for _,n in ipairs({'AlreadyResearched','CurrentlyResearching','Available','Unavailable','Locked','FreeTech'}) do
                assert(card[n].hidden==(n~=name),n..' when '..name)
            end
        end
        p.GetNumFreeTechs=function() return 0 end
        state('Unavailable')
        p.CanResearch=function() return true end;state('Available')
        p.GetCurrentResearch=function() return id end;state('CurrentlyResearching')
        p.GetNumFreeTechs=function() return 1 end
        p.CanResearchForFree=function() return true end;state('FreeTech')
        TechSelected(id);sent={};TechSelected(id);assert(#sent==0)
        recorded.events.SerialEventResearchDirty()
        p.CanResearchForFree=function() return false end
        p.GetCurrentResearch=function() return -1 end;state('Available')
        p.CanResearch=function() return false end;state('Locked')
        p.GetNumFreeTechs=function() return 0 end
        p.GetQueuePosition=function() return 3 end;state('Unavailable')
        assert(not card.TechQueue.hidden and card.TechQueueLabel.text=='2')
        RESEARCHED[id]=true;state('AlreadyResearched')
        assert(card.TechButton.void1==-1)
        RESEARCHED[id]=false
        p.GetNumFreeTechs=function() return 0 end
        p.CanResearch=function() return true end
        local hidden=true
        ContextPtr.IsHidden=function() return hidden end
        UIManager.QueuePopup=function() hidden=false end
        UIManager.DequeuePopup=function() hidden=true end
        Events.SerialEventGameMessagePopupProcessed.CallImmediate=function() end
        Players[1]={GetTeam=function() return 1 end}
        Teams[1]={IsHasTech=function() return true end}
        p.GetNumTechsToSteal=function() return 1 end
        OnDisplay({Type=ButtonPopupTypes.BUTTONPOPUP_TECH_TREE,Data1=0,Data2=1})
        state('FreeTech');TechSelected(id)
        assert(sent[1]==id and sent[2]==0 and sent[3]==1)
        p.GetNumTechsToSteal=function() return 0 end;state('Locked')
        OnCloseButtonClicked();assert(hidden)
        OnDisplay({Type=ButtonPopupTypes.BUTTONPOPUP_TECH_TREE,Data1=0,Data2=-1})
        OnDisplay({Type=ButtonPopupTypes.BUTTONPOPUP_TECH_TREE,Data1=1,Data2=-1})
        assert(hidden)
        Game.IsOption=function() return true end;state('Unavailable')
        assert(card.TechButton.void1==-1)
        sent={};TechSelected(id);assert(#sent==0)
    ''')
    print('PASS: research/free-tech/shift network arguments, six native card states, espionage eligibility, close/toggle and no-science guards')


if __name__=='__main__':
    references()
    test_current();test_native_defects();test_sql_and_pixels();test_sprite_paths();test_packaged_paths();test_controller()
