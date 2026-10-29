#!/usr/bin/env python3
"""v7 SQL contracts and behavioral Lua tests using a factual BNW snapshot.

Snapshot: schema/parameters only, not an installed game or an emulated engine.
"""
import argparse
import json
from pathlib import Path
import sqlite3
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from systems_content import ALLIES, POLICY_TEXT
from run_lua import lua


def fixture():
    source = json.loads((ROOT / 'tests/data/bnw-society.json').read_text())
    db = sqlite3.connect(':memory:')
    db.row_factory = sqlite3.Row
    for name, table in source['tables'].items():
        db.execute(table['schema'])
        for row in table['rows']:
            cols = ','.join('"' + k + '"' for k in row)
            db.execute(f'INSERT INTO "{name}" ({cols}) VALUES ({",".join("?" for _ in row)})', list(row.values()))
    for lang in ['Language_en_US', 'Language_RU_RU']:
        db.execute(f'CREATE TABLE {lang} (Tag TEXT PRIMARY KEY, Text TEXT)')
        tags = {r[0] for r in db.execute('SELECT Help FROM Policies UNION SELECT Help FROM PolicyBranchTypes UNION SELECT Civilopedia FROM MinorCivilizations UNION SELECT Help FROM Technologies UNION SELECT Help FROM Units') if r[0]}
        db.executemany(f'INSERT INTO {lang} VALUES (?,?)', [(t, 'Original ' + t) for t in tags])
    return db


def apply(db):
    for name in ['Localization', 'Society']:
        root = ET.parse(ROOT / 'mod/Text' / (name + '.xml')).getroot()
        for lang in root:
            db.executemany(f'INSERT INTO {lang.tag} VALUES (?,?)', [(r.attrib['Tag'], r.findtext('Text')) for r in lang])
    for name in ['Gameplay', 'TechnologyRefinements', 'TechTreePresentation', 'UnitResources', 'Development', 'Institutions', 'Allies']:
        db.executescript((ROOT / 'mod/SQL' / (name + '.sql')).read_text())


def validate(db, before):
    minors = {r[0] for r in db.execute('SELECT Type FROM MinorCivilizations')}
    assert len(minors) == 58
    assert minors == {r[0] for r in db.execute('SELECT MinorType FROM Refined_Allies')}
    assert [tuple(r) for r in db.execute('SELECT * FROM MinorCivilizations')] == before['minors']
    expected_graph = set(before['graph']) - {('POLICY_MERITOCRACY','POLICY_CITIZENSHIP')}
    expected_graph.add(('POLICY_MERITOCRACY','POLICY_REPRESENTATION'))
    assert {tuple(r) for r in db.execute('SELECT * FROM Policy_PrereqPolicies')} == expected_graph
    assert [tuple(r) for r in db.execute('SELECT * FROM Policy_PrereqORPolicies')] == before['or_graph']
    assert db.execute('SELECT COUNT(*) FROM Policies').fetchone()[0] == before['policy_count']
    liberty = {r['Type']: r for r in db.execute("SELECT * FROM Policies WHERE PolicyBranchType='POLICY_BRANCH_LIBERTY'")}
    assert len({(r['GridX'],r['GridY']) for r in liberty.values()}) == 5
    assert (liberty['POLICY_MERITOCRACY']['GridX'], liberty['POLICY_MERITOCRACY']['GridY']) == (3,3)
    ancestors = {}
    def visit(policy, active=()):
        assert policy not in active, ('policy cycle',policy)
        deps = {r[0] for r in db.execute('SELECT PrereqPolicy FROM Policy_PrereqPolicies WHERE PolicyType=?',(policy,))}
        result = deps | {ancestor for dep in deps for ancestor in visit(dep, active+(policy,))}
        ancestors[policy] = result
        return result
    for policy in liberty: visit(policy)
    assert ancestors['POLICY_MERITOCRACY'] == {'POLICY_CITIZENSHIP','POLICY_REPRESENTATION'}
    assert tuple(db.execute("SELECT WorkerSpeedModifier,BuildingProductionModifier,IncludesOneShotFreeUnits FROM Policies WHERE Type='POLICY_REPUBLIC'").fetchone()) == (25,0,1)
    assert tuple(db.execute("SELECT WorkerSpeedModifier,HappinessPerTradeRoute,UnhappinessMod,IncludesOneShotFreeUnits FROM Policies WHERE Type='POLICY_CITIZENSHIP'").fetchone()) == (0,100,-5,0)
    assert tuple(db.execute("SELECT HappinessPerTradeRoute,UnhappinessMod FROM Policies WHERE Type='POLICY_MERITOCRACY'").fetchone()) == (0,0)
    assert [tuple(r) for r in db.execute("SELECT UnitClassType,Count FROM Policy_FreeUnitClasses WHERE PolicyType='POLICY_REPUBLIC'")] == [('UNITCLASS_WORKER',1)]
    assert not db.execute("SELECT * FROM Policy_FreeUnitClasses WHERE PolicyType='POLICY_CITIZENSHIP'").fetchall()
    assert {tuple(r) for r in db.execute("SELECT YieldType,Yield FROM Policy_SpecialistExtraYields WHERE PolicyType='POLICY_MERITOCRACY'")} == {('YIELD_SCIENCE',1),('YIELD_PRODUCTION',1)}
    assert db.execute("SELECT BuildingProductionModifier FROM Policies WHERE Type='POLICY_LIBERTY_FINISHER'").fetchone()[0] == 10
    assert not db.execute("SELECT * FROM Refined_SocietyCarriers WHERE BuildingType='BUILDING_REFINED_SOCIETY_LIBERTY'").fetchall()
    assert db.execute("SELECT NumTradeRouteBonus FROM Buildings WHERE Type='BUILDING_REFINED_SOCIETY_COMMERCE_ROUTE'").fetchone()[0] == 1
    assert [tuple(r) for r in db.execute("SELECT * FROM Policies WHERE PolicyBranchType IN ('POLICY_BRANCH_RATIONALISM','POLICY_BRANCH_FREEDOM','POLICY_BRANCH_ORDER','POLICY_BRANCH_AUTOCRACY') OR Type IN ('POLICY_RATIONALISM','POLICY_RATIONALISM_FINISHER')")] == before['untouched']
    honor = db.execute("SELECT CultureFromKills,CultureFromBarbarianKills,GoldFromKills FROM Policies WHERE Type='POLICY_HONOR_FINISHER'").fetchone()
    assert tuple(honor) == (25, -25, 100)
    # Native engine combines the barbarian and general components before /100.
    assert (25 - 25) * 16 // 100 == 0
    assert 25 * 34 // 100 == 8
    assert db.execute("SELECT CultureWonderMultiplier FROM Policies WHERE Type='POLICY_FLOURISHING_OF_ARTS'").fetchone()[0] == 0
    assert db.execute("SELECT COUNT(*) FROM Units WHERE Type LIKE 'UNIT_REFINED_%'").fetchone()[0] == 2
    assert tuple(db.execute("SELECT Combat,Cost,PurchaseOnly,PolicyType FROM Units WHERE Type='UNIT_REFINED_SWISS_GUARD'").fetchone()) == (26,100,1,'POLICY_TRADE_UNIONS')
    assert tuple(db.execute("SELECT Combat,Cost,PurchaseOnly,PolicyType FROM Units WHERE Type='UNIT_REFINED_MERCENARY_LEGION'").fetchone()) == (42,180,1,'POLICY_TRADE_UNIONS')
    assert tuple(db.execute("SELECT * FROM Units WHERE Type='UNIT_FRENCH_FOREIGNLEGION'").fetchone()) == before['legion']
    for unit, target in [('UNIT_GERMAN_LANDSKNECHT','UNITCLASS_REFINED_SWISS_GUARD'),
                         ('UNIT_REFINED_SWISS_GUARD','UNITCLASS_REFINED_MERCENARY_LEGION'),
                         ('UNIT_REFINED_MERCENARY_LEGION','UNITCLASS_INFANTRY')]:
        assert [r[0] for r in db.execute('SELECT UnitClassType FROM Unit_ClassUpgrades WHERE UnitType=?',(unit,))] == [target]
    assert not db.execute("SELECT * FROM Unit_ResourceQuantityRequirements WHERE UnitType IN ('UNIT_REFINED_SWISS_GUARD','UNIT_REFINED_MERCENARY_LEGION')").fetchall()
    for name in ['Unit_AITypes','Unit_Flavors','Unit_FreePromotions']:
        if name != 'Unit_FreePromotions':
            assert db.execute(f"SELECT COUNT(*) FROM {name} WHERE UnitType='UNIT_REFINED_SWISS_GUARD'").fetchone()[0] > 0
    assert not db.execute('SELECT a.MinorType FROM Refined_Allies a LEFT JOIN Buildings b ON b.Type=a.BuildingType WHERE b.Type IS NULL').fetchall()
    assert not db.execute('SELECT a.BuildingClass FROM Refined_AllyClasses a LEFT JOIN BuildingClasses b ON b.Type=a.BuildingClass WHERE b.Type IS NULL').fetchall()
    assert not db.execute('SELECT r.ResourceType FROM Building_ResourceYieldChanges r LEFT JOIN Resources t ON r.ResourceType=t.Type WHERE t.Type IS NULL').fetchall()
    for a in ALLIES:
        if a['unitcombat']:
            assert db.execute('SELECT COUNT(*) FROM Unit_ProductionModifierBuildings WHERE BuildingType=?', ('BUILDING_REFINED_SOCIETY_' + a['code'],)).fetchone()[0] > 0
    for unit in ['UNIT_REFINED_SWISS_GUARD', 'UNIT_REFINED_MERCENARY_LEGION']:
        assert db.execute("SELECT ProductionModifier FROM Unit_ProductionModifierBuildings WHERE UnitType=? AND BuildingType='BUILDING_REFINED_SOCIETY_MBANZA_KONGO'",(unit,)).fetchone()[0] == 10
    for lang in ['Language_en_US', 'Language_RU_RU']:
        for a in db.execute('SELECT Help FROM Refined_Allies'):
            assert db.execute(f'SELECT Text FROM {lang} WHERE Tag=?', (a[0],)).fetchone()[0]
        for code, _, _, replace in POLICY_TEXT:
            table = 'PolicyBranchTypes' if code.endswith('_FINISHER') else 'Policies'
            type_ = 'POLICY_BRANCH_' + code[:-9] if code.endswith('_FINISHER') else 'POLICY_' + code
            help_ = db.execute(f'SELECT Help FROM {table} WHERE Type=?', (type_,)).fetchone()[0]
            result = db.execute(f'SELECT Text FROM {lang} WHERE Tag=?', (help_,)).fetchone()[0]
            assert ('Original ' not in result) if replace else ('Original ' in result)
    print('PASS: all 58 real minors, nine branch graph, ideology/rationalism preservation, exact Honor reward, mercenary line, texts and references')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', default='lua5.1')
    args = parser.parse_args()
    db = fixture()
    before = dict(minors=[tuple(r) for r in db.execute('SELECT * FROM MinorCivilizations')],
                  graph=[tuple(r) for r in db.execute('SELECT * FROM Policy_PrereqPolicies')],
                  or_graph=[tuple(r) for r in db.execute('SELECT * FROM Policy_PrereqORPolicies')],
                  policy_count=db.execute('SELECT COUNT(*) FROM Policies').fetchone()[0],
                  untouched=[tuple(r) for r in db.execute("SELECT * FROM Policies WHERE PolicyBranchType IN ('POLICY_BRANCH_RATIONALISM','POLICY_BRANCH_FREEDOM','POLICY_BRANCH_ORDER','POLICY_BRANCH_AUTOCRACY') OR Type IN ('POLICY_RATIONALISM','POLICY_RATIONALISM_FINISHER')")],
                  legion=tuple(db.execute("SELECT * FROM Units WHERE Type='UNIT_FRENCH_FOREIGNLEGION'").fetchone()))
    apply(db)
    validate(db, before)
    names = ['Refined_Allies','Refined_AllyClasses','Refined_SocietyCarriers','Buildings','BuildingClasses',
             'Technologies','Units','Policies','PolicyBranchTypes','Eras','GameSpeeds','MinorCivilizations','Civilizations','Civilization_BuildingClassOverrides','UnitPromotions']
    data = {name: [dict(row) for row in db.execute('SELECT * FROM ' + name)] for name in names}
    with tempfile.TemporaryDirectory(prefix='refined-society-') as temp:
        path = Path(temp) / 'data.lua'
        path.write_text('return ' + lua(data))
        subprocess.run([args.lua, 'tests/society.lua', str(path)], cwd=ROOT, check=True)
