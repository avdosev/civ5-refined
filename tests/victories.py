#!/usr/bin/env python3
"""v8 migration/layout checks and execution of the shipped Lua in Lua 5.1.

Public BNW data projection; not an installed game or UI renderer.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from society import fixture, apply
from run_lua import lua

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from tech_tree_layout import layout_issues


def database():
    db = fixture()
    extra = json.loads((ROOT / 'tests/data/bnw-victories.json').read_text())
    for name, table in extra['tables'].items():
        db.execute(table['schema'])
        for row in table['rows']:
            columns = ','.join('"' + k + '"' for k in row)
            db.execute(f'INSERT INTO "{name}" ({columns}) VALUES ({",".join("?" for _ in row)})', list(row.values()))
    apply(db)
    original = {r['Type']: dict(r) for r in db.execute('SELECT * FROM Technologies')}
    parts = {r['Type']: dict(r) for r in db.execute("SELECT * FROM Units WHERE Type LIKE 'UNIT_SS_%'")}
    thresholds = [tuple(r) for r in db.execute('SELECT * FROM Project_VictoryThresholds')]
    root = ET.parse(ROOT / 'mod/Text/Victories.xml').getroot()
    for lang in root:
        db.executemany(f'INSERT INTO {lang.tag} VALUES (?,?)', [(r.attrib['Tag'], r.findtext('Text')) for r in lang])
    db.executescript((ROOT / 'mod/SQL/Victories.sql').read_text())
    assert not layout_issues(db, include_industrial=True), layout_issues(db, True)
    assert len(list(db.execute('SELECT * FROM Refined_VictoryTechs'))) == 8
    assert db.execute('SELECT COUNT(*) FROM Technologies').fetchone()[0] == 94
    for type_, before in original.items():
        after = dict(db.execute('SELECT * FROM Technologies WHERE Type=?', (type_,)).fetchone())
        assert {k: v for k, v in before.items() if k not in ('GridX','GridY')} == {
            k: v for k, v in after.items() if k not in ('GridX','GridY')}, type_
    for type_, before in parts.items():
        after = dict(db.execute('SELECT * FROM Units WHERE Type=?', (type_,)).fetchone())
        if type_ == 'UNIT_SS_ENGINE':
            assert after['PrereqTech'] == 'TECH_REFINED_ENGINES'
            before['PrereqTech'] = after['PrereqTech']
        assert before == after, type_
    assert thresholds == [tuple(r) for r in db.execute('SELECT * FROM Project_VictoryThresholds')]
    positions = [tuple(r) for r in db.execute('SELECT GridX,GridY FROM Technologies')]
    assert len(positions) == len(set(positions))
    # Full acyclic graph, not only renderer constraints.
    graph = {}
    for r in db.execute('SELECT Type FROM Technologies'): graph[r[0]] = set()
    for tech, parent in db.execute('SELECT TechType,PrereqTech FROM Technology_PrereqTechs'):
        assert parent in graph and tech in graph
        graph[tech].add(parent)
    done = set()
    def visit(tech, active):
        assert tech not in active, ('cycle', tech)
        if tech in done: return
        for parent in graph[tech]: visit(parent, active | {tech})
        done.add(tech)
    for tech in graph: visit(tech, set())
    assert graph['TECH_REFINED_ENGINES'] == {'TECH_PARTICLE_PHYSICS','TECH_NUCLEAR_FUSION'}
    assert graph['TECH_REFINED_NETWORK_WAR'] == {'TECH_REFINED_AI','TECH_MOBILE_TACTICS'}
    expected = {'PROJECT_REFINED_MARS_RECON':500, 'PROJECT_REFINED_MARS_TRANSPORT':600,
                'PROJECT_REFINED_MARS_HABITAT':800, 'PROJECT_REFINED_MARS_COLONY':1000,
                'PROJECT_REFINED_UNIVERSAL_AI':1000}
    for type_, cost in expected.items():
        r = db.execute('SELECT * FROM Projects WHERE Type=?',(type_,)).fetchone()
        assert (r['Cost'],r['MaxTeamInstances'],r['MaxGlobalInstances'],r['Spaceship'],r['VictoryPrereq']) == (
            cost,1,-1,0,'VICTORY_SPACE_RACE')
    order = ['PROJECT_REFINED_MARS_'+name for name in ('RECON','TRANSPORT','HABITAT','COLONY')]
    assert {tuple(r) for r in db.execute("SELECT * FROM Project_Prereqs WHERE ProjectType LIKE 'PROJECT_REFINED_%'")} == {
        (child,parent,1) for parent,child in zip(order,order[1:])}
    assert tuple(db.execute("SELECT Cost,GoldMaintenance,SpaceProductionModifier FROM Buildings WHERE Type='BUILDING_REFINED_ORBITAL_YARD'").fetchone()) == (500,4,20)
    assert tuple(db.execute("SELECT Cost,GoldMaintenance,NeverCapture,ConquestProb FROM Buildings WHERE Type='BUILDING_REFINED_SUPERCOMPUTER'").fetchone()) == (1200,20,1,0)
    assert db.execute("SELECT MaxPlayerInstances FROM BuildingClasses WHERE Type='BUILDINGCLASS_REFINED_SUPERCOMPUTER'").fetchone()[0] == 1
    assert db.execute("SELECT MaxGlobalInstances FROM BuildingClasses WHERE Type='BUILDINGCLASS_REFINED_BATTLE_COMMAND'").fetchone()[0] == 1
    assert tuple(db.execute("SELECT VisibilityChange,CombatPercent,LostWithUpgrade,CannotBeChosen FROM UnitPromotions WHERE Type='PROMOTION_REFINED_NETWORK_COMMAND'").fetchone()) == (1,10,0,1)
    assert not db.execute("SELECT * FROM Process_ProductionYields WHERE ProcessType='PROCESS_REFINED_LEARNING'").fetchall()
    assert db.execute("SELECT Value FROM Refined_VictorySettings WHERE Name='LearningGoal'").fetchone()[0] == 13666
    for table, fields in [('Technologies',('Description','Help','Civilopedia','Quote')),
                          ('Buildings',('Description','Help','Civilopedia')),
                          ('Projects',('Description','Help','Civilopedia')),
                          ('Processes',('Description','Help','Strategy')),
                          ('UnitPromotions',('Description','Help'))]:
        # Validate this migration's text; earlier content has its own checks.
        for r in db.execute(f'SELECT * FROM {table}'):
            for field in fields:
                key = r[field]
                if key and 'REFINED' in r['Type']:
                    for lang in ('Language_en_US','Language_RU_RU'):
                        result = db.execute(f'SELECT Text FROM {lang} WHERE Tag=?',(key,)).fetchone()
                        assert result and result[0], (table, r['Type'], lang, key)
    assert not db.execute('SELECT v.Type FROM Refined_VictoryTechs v LEFT JOIN Technologies t ON v.Type=t.Type WHERE t.Type IS NULL').fetchall()
    known_flavors = {r[0] for r in db.execute('SELECT Type FROM Flavors')}
    for table in ('Technology_Flavors','Building_Flavors','Project_Flavors'):
        assert all(r[0] in known_flavors for r in db.execute('SELECT FlavorType FROM '+table))
    assert {tuple(r) for r in db.execute("SELECT BuildingType,BuildingClassType FROM Building_ClassesNeededInCity WHERE BuildingType LIKE 'BUILDING_REFINED_%'")} == {
        ('BUILDING_REFINED_SUPERCOMPUTER','BUILDINGCLASS_REFINED_DATA_CENTER'),
        ('BUILDING_REFINED_BATTLE_COMMAND','BUILDINGCLASS_REFINED_DATA_CENTER')}
    assert tuple(db.execute("SELECT Cost,GoldMaintenance,ConquestProb FROM Buildings WHERE Type='BUILDING_REFINED_BATTLE_COMMAND'").fetchone()) == (1250,0,100)
    assert db.execute("SELECT Yield FROM Building_YieldChanges WHERE BuildingType='BUILDING_REFINED_SUPERCOMPUTER' AND YieldType='YIELD_SCIENCE'").fetchone()[0] == 10
    assert db.execute("SELECT Yield FROM Building_YieldModifiers WHERE BuildingType='BUILDING_REFINED_SUPERCOMPUTER' AND YieldType='YIELD_SCIENCE'").fetchone()[0] == 25
    # The planning model must not silently drift away from shipped prices/rules.
    sys.path.insert(0, str(ROOT / 'dev-utils'))
    import victory_timing as timing
    timing.compare(tuned=True, profiles={})
    aliases = ('ORBITAL','AUTONOMOUS','BIOSYSTEMS','ENGINES','ADVANCED_COMPUTING','GENERAL_AI','RECURSIVE')
    for alias in aliases:
        type_ = 'TECH_REFINED_' + alias
        assert timing.COST[alias] == db.execute('SELECT Cost FROM Technologies WHERE Type=?',(type_,)).fetchone()[0]
        expected_parents = {'TECH_REFINED_'+p if p in aliases else 'TECH_'+p for p in timing.PARENTS[alias]}
        assert graph[type_] == expected_parents
    assert timing.MARS_COSTS == tuple(db.execute('SELECT Cost FROM Projects WHERE Type=?',(p,)).fetchone()[0] for p in order)
    assert timing.TRAINING_GOAL == 13666
    print('PASS: full v8 SQL stack, 94-node acyclic/native layout, unchanged stock parts/thresholds, prices, national/world limits and RU/EN text')
    return db


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', default='lua5.1')
    args = parser.parse_args()
    db = database()
    tables = ['Technologies','Buildings','Units','Projects','Processes','GameSpeeds',
              'Refined_VictoryProjects','Refined_VictorySettings']
    data = {name:[dict(r) for r in db.execute('SELECT * FROM '+name)] for name in tables}
    with tempfile.TemporaryDirectory(prefix='refined-victories-') as temp:
        path = Path(temp) / 'data.lua'
        path.write_text('return '+lua(data))
        subprocess.run([args.lua, 'tests/victories.lua', str(path)], cwd=ROOT, check=True)
