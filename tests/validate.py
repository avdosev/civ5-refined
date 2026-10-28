#!/usr/bin/env python3
"""SQLite migration/package contracts. Fixture is a BNW-shaped subset, not the game DB.

Pass --database Civ5DebugDatabase.db to validate a copy of a real clean BNW DB.
The supplied database is opened read-only and never modified.
"""
import argparse
from collections import Counter
import hashlib
from pathlib import Path
import sqlite3
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build import build
from tech_tree_layout import layout_issues


def fixture(db):
    db.executescript('''
    CREATE TABLE Technologies (Type TEXT PRIMARY KEY, Cost INTEGER, Description TEXT,
      Civilopedia TEXT, Help TEXT, Quote TEXT, Era TEXT, GridX INTEGER, GridY INTEGER DEFAULT 0,
      PortraitIndex INTEGER DEFAULT 0, IconAtlas TEXT, Trade INTEGER DEFAULT 1, ScenarioTechButton INTEGER DEFAULT -1);
    CREATE TABLE Technology_PrereqTechs (TechType TEXT REFERENCES Technologies(Type),
      PrereqTech TEXT REFERENCES Technologies(Type), UNIQUE(TechType, PrereqTech));
    CREATE TABLE Technology_Flavors (TechType TEXT REFERENCES Technologies(Type), FlavorType TEXT, Flavor INTEGER);
    CREATE TABLE BuildingClasses (Type TEXT PRIMARY KEY, DefaultBuilding TEXT, Description TEXT);
    CREATE TABLE Buildings (Type TEXT PRIMARY KEY, BuildingClass TEXT REFERENCES BuildingClasses(Type),
      Cost INTEGER, GoldMaintenance INTEGER DEFAULT 0, PrereqTech TEXT REFERENCES Technologies(Type),
      Description TEXT, Civilopedia TEXT, Help TEXT, Strategy TEXT, ArtDefineTag TEXT, MinAreaSize INTEGER,
      HurryCostModifier INTEGER, ConquestProb INTEGER, PortraitIndex INTEGER, IconAtlas TEXT,
      FaithCost INTEGER, GreatWorkCount INTEGER, NeverCapture INTEGER, NukeImmune INTEGER,
      MutuallyExclusiveGroup INTEGER DEFAULT 0, CultureRateModifier INTEGER DEFAULT 0);
    CREATE TABLE Building_YieldModifiers (BuildingType TEXT REFERENCES Buildings(Type), YieldType TEXT, Yield INTEGER);
    CREATE TABLE Building_YieldChanges (BuildingType TEXT REFERENCES Buildings(Type), YieldType TEXT, Yield INTEGER);
    CREATE TABLE Building_Flavors (BuildingType TEXT REFERENCES Buildings(Type), FlavorType TEXT, Flavor INTEGER);
    CREATE TABLE Units (Type TEXT PRIMARY KEY, Class TEXT, Help TEXT, PrereqTech TEXT REFERENCES Technologies(Type));
    CREATE TABLE Unit_TechTypes (UnitType TEXT REFERENCES Units(Type), TechType TEXT REFERENCES Technologies(Type), UNIQUE(UnitType, TechType));
    CREATE TABLE Building_TechAndPrereqs (BuildingType TEXT REFERENCES Buildings(Type), TechType TEXT REFERENCES Technologies(Type), UNIQUE(BuildingType, TechType));
    CREATE TABLE Unit_ResourceQuantityRequirements (UnitType TEXT REFERENCES Units(Type), ResourceType TEXT,
      Cost INTEGER DEFAULT 1, UNIQUE(UnitType, ResourceType));
    CREATE TABLE Improvement_TechYieldChanges (ImprovementType TEXT, TechType TEXT REFERENCES Technologies(Type), YieldType TEXT, Yield INTEGER);
    CREATE TABLE Building_ResourceQuantityRequirements (BuildingType TEXT REFERENCES Buildings(Type), ResourceType TEXT, Cost INTEGER);
    CREATE TABLE Building_LocalResourceOrs (BuildingType TEXT REFERENCES Buildings(Type), ResourceType TEXT);
    CREATE TABLE Building_ResourceYieldChanges (BuildingType TEXT REFERENCES Buildings(Type), ResourceType TEXT, YieldType TEXT, Yield INTEGER);
    CREATE TABLE Unit_ProductionModifierBuildings (UnitType TEXT REFERENCES Units(Type), BuildingType TEXT REFERENCES Buildings(Type), ProductionModifier INTEGER);
    CREATE TABLE Language_en_US (Tag TEXT PRIMARY KEY, Text TEXT);
    CREATE TABLE Language_RU_RU (Tag TEXT PRIMARY KEY, Text TEXT);
    ''')
    # Affected prerequisite subgraph only. Full BNW validation needs --database.
    # BNW coordinates, verified against the BNW Technologies data module.
    # In v4 Computers was incorrectly modelled at row 6 rather than row 7.
    techs = {'ELECTRONICS': (12, 4), 'RADAR': (13, 5), 'COMBINED_ARMS': (13, 7),
             'COMPUTERS': (14, 7), 'TELECOM': (15, 1), 'ROBOTICS': (15, 6),
             'INTERNET': (16, 0), 'FUTURE_TECH': (17, 4),
             'ELECTRICITY': (10, 1), 'RADIO': (11, 2), 'INDUSTRIALIZATION': (9, 3),
             'ECOLOGY': (14, 1), 'NUCLEAR_FISSION': (14, 3), 'ROCKETRY': (14, 5),
             'SATELLITES': (15, 5), 'MOBILE_TACTICS': (15, 2),
             'ADVANCED_BALLISTICS': (15, 4), 'PARTICLE_PHYSICS': (16, 2),
             'ATOMIC_THEORY': (13, 3), 'PLASTIC': (12, 2), 'PENICILIN': (13, 1),
             'LASERS': (15, 7), 'GLOBALIZATION': (16, 1), 'NUCLEAR_FUSION': (16, 5),
             'NANOTECHNOLOGY': (16, 6), 'STEALTH': (16, 7),
             'FERTILIZER': (9, 9), 'STEAM_POWER': (10, 5), 'DYNAMITE': (10, 8),
             'RAILROAD': (11, 7), 'FLIGHT': (11, 5), 'REPLACEABLE_PARTS': (11, 3),
             'BALLISTICS': (12, 5), 'COMBUSTION': (12, 7), 'CHEMISTRY': (8, 7),
             'MILITARY_SCIENCE': (9, 8), 'SCIENTIFIC_THEORY': (9, 1), 'RIFLING': (9, 7),
             'HORSEBACK_RIDING': (2, 4), 'CONSTRUCTION': (3, 5), 'IRON_WORKING': (3, 7),
             'EDUCATION': (6, 2), 'MACHINERY': (6, 4), 'BANKING': (7, 3),
             'PRINTING_PRESS': (7, 5), 'NAVIGATION': (8, 0), 'ECONOMICS': (8, 3),
             'GUILDS': (5, 3), 'REFRIGERATION': (11, 0)}
    techs['ELECTRICITY'] = (10, 2)
    for name, (x, y) in techs.items():
        db.execute('INSERT INTO Technologies (Type, Help, GridX, GridY, IconAtlas, PortraitIndex) VALUES (?, ?, ?, ?, ?, ?)',
                   ('TECH_' + name, 'HELP_' + name, x, y, 'STOCK_ATLAS', 5))
    db.execute("UPDATE Technologies SET Description='TXT_KEY_' || Type")
    # Preserve era bands when v6 adds an Industrial-era column.
    for name, (x, _) in techs.items():
        era = ('ERA_FUTURE' if x >= 15 else 'ERA_POSTMODERN' if x >= 13 else
               'ERA_MODERN' if x >= 11 else 'ERA_INDUSTRIAL' if x >= 9 else 'ERA_RENAISSANCE')
        db.execute('UPDATE Technologies SET Era=? WHERE Type=?', (era, 'TECH_' + name))
    db.executemany('INSERT INTO Technology_PrereqTechs VALUES (?, ?)', [
        ('TECH_COMPUTERS', 'TECH_RADAR'), ('TECH_COMPUTERS', 'TECH_COMBINED_ARMS'),
        ('TECH_ROBOTICS', 'TECH_COMPUTERS'), ('TECH_ROBOTICS', 'TECH_ROCKETRY'),
        ('TECH_TELECOM', 'TECH_ECOLOGY'), ('TECH_INTERNET', 'TECH_TELECOM'),
        ('TECH_PARTICLE_PHYSICS', 'TECH_TELECOM'), ('TECH_PARTICLE_PHYSICS', 'TECH_MOBILE_TACTICS'),
        ('TECH_PARTICLE_PHYSICS', 'TECH_ADVANCED_BALLISTICS'),
        ('TECH_ADVANCED_BALLISTICS', 'TECH_ROCKETRY'), ('TECH_ADVANCED_BALLISTICS', 'TECH_NUCLEAR_FISSION'),
        ('TECH_SATELLITES', 'TECH_ROCKETRY'),
        ('TECH_FUTURE_TECH', 'TECH_INTERNET'),
        ('TECH_RADIO', 'TECH_ELECTRICITY'), ('TECH_PLASTIC', 'TECH_RADIO'),
        ('TECH_ATOMIC_THEORY', 'TECH_ELECTRONICS'), ('TECH_ATOMIC_THEORY', 'TECH_PLASTIC'),
        ('TECH_NUCLEAR_FISSION', 'TECH_ATOMIC_THEORY'),
        ('TECH_ECOLOGY', 'TECH_ATOMIC_THEORY'), ('TECH_ECOLOGY', 'TECH_PENICILIN'),
        ('TECH_MOBILE_TACTICS', 'TECH_ECOLOGY'), ('TECH_MOBILE_TACTICS', 'TECH_NUCLEAR_FISSION'),
        ('TECH_LASERS', 'TECH_COMPUTERS'), ('TECH_GLOBALIZATION', 'TECH_TELECOM'),
        ('TECH_NANOTECHNOLOGY', 'TECH_ROBOTICS'),
        ('TECH_NUCLEAR_FUSION', 'TECH_ROBOTICS'), ('TECH_NUCLEAR_FUSION', 'TECH_SATELLITES'),
        ('TECH_NUCLEAR_FUSION', 'TECH_ADVANCED_BALLISTICS'),
        ('TECH_STEALTH', 'TECH_ROBOTICS'), ('TECH_STEALTH', 'TECH_LASERS'),
        ('TECH_FUTURE_TECH', 'TECH_GLOBALIZATION'), ('TECH_FUTURE_TECH', 'TECH_PARTICLE_PHYSICS'),
        ('TECH_FUTURE_TECH', 'TECH_NUCLEAR_FUSION'), ('TECH_FUTURE_TECH', 'TECH_NANOTECHNOLOGY'),
        ('TECH_FUTURE_TECH', 'TECH_STEALTH')])
    db.executemany('INSERT INTO Technology_PrereqTechs VALUES (?, ?)', [
        ('TECH_FERTILIZER', 'TECH_CHEMISTRY'), ('TECH_MILITARY_SCIENCE', 'TECH_CHEMISTRY'),
        ('TECH_DYNAMITE', 'TECH_FERTILIZER'), ('TECH_DYNAMITE', 'TECH_MILITARY_SCIENCE'),
        ('TECH_STEAM_POWER', 'TECH_SCIENTIFIC_THEORY'), ('TECH_STEAM_POWER', 'TECH_INDUSTRIALIZATION'),
        ('TECH_STEAM_POWER', 'TECH_RIFLING'), ('TECH_FLIGHT', 'TECH_STEAM_POWER'),
        ('TECH_REPLACEABLE_PARTS', 'TECH_STEAM_POWER'), ('TECH_RAILROAD', 'TECH_STEAM_POWER'),
        ('TECH_RAILROAD', 'TECH_DYNAMITE'), ('TECH_BALLISTICS', 'TECH_RAILROAD'),
        ('TECH_COMBUSTION', 'TECH_RAILROAD')])
    db.executemany('INSERT INTO Improvement_TechYieldChanges VALUES (?, ?, ?, ?)', [
        ('IMPROVEMENT_QUARRY', 'TECH_CHEMISTRY', 'YIELD_PRODUCTION', 1),
        ('IMPROVEMENT_LUMBERMILL', 'TECH_SCIENTIFIC_THEORY', 'YIELD_PRODUCTION', 1)])
    for name, tech in [('FACTORY', 'INDUSTRIALIZATION'), ('MINT', 'BANKING'),
                       ('UNIVERSITY', 'EDUCATION'), ('OPERA_HOUSE', 'SCIENTIFIC_THEORY'),
                       ('HARBOR', 'CONSTRUCTION'), ('PUBLIC_SCHOOL', 'SCIENTIFIC_THEORY')]:
        db.execute('INSERT INTO BuildingClasses (Type, DefaultBuilding) VALUES (?, ?)',
                   ('BUILDINGCLASS_' + name, 'BUILDING_' + name))
        db.execute('INSERT INTO Buildings (Type, BuildingClass, PrereqTech, IconAtlas, PortraitIndex, ArtDefineTag) VALUES (?, ?, ?, ?, ?, ?)',
                   ('BUILDING_' + name, 'BUILDINGCLASS_' + name, 'TECH_' + tech, 'STOCK_BUILDING', 1, name))
    db.execute("INSERT INTO Buildings (Type, IconAtlas, PortraitIndex, ArtDefineTag) VALUES ('BUILDING_LABORATORY', 'LAB_ATLAS', 27, 'LAB_ART')")
    db.execute("INSERT INTO BuildingClasses (Type, DefaultBuilding) VALUES ('BUILDINGCLASS_SPACESHIP_FACTORY', 'BUILDING_SPACESHIP_FACTORY')")
    db.execute("INSERT INTO Buildings (Type, BuildingClass, PrereqTech) VALUES ('BUILDING_SPACESHIP_FACTORY', 'BUILDINGCLASS_SPACESHIP_FACTORY', 'TECH_ROBOTICS')")
    for lang in ['Language_en_US', 'Language_RU_RU']:
        for name in techs:
            db.execute(f'INSERT INTO {lang} VALUES (?, ?)', ('HELP_' + name, 'Original help'))
    classes = [
        'KNIGHT', 'CANNON', 'ARTILLERY', 'ROCKET_ARTILLERY', 'WWI_TANK', 'TANK',
        'MODERN_ARMOR', 'MECHANIZED_INFANTRY', 'MOBILE_SAM', 'HELICOPTER_GUNSHIP',
        'MECH', 'IRONCLAD', 'DESTROYER', 'BATTLESHIP', 'CARRIER', 'SUBMARINE',
        'NUCLEAR_SUBMARINE', 'MISSILE_CRUISER', 'TRIPLANE', 'WWI_BOMBER',
        'FIGHTER', 'BOMBER', 'JET_FIGHTER', 'STEALTH_BOMBER', 'GUIDED_MISSILE',
        'MUSKETMAN', 'RIFLEMAN', 'GREAT_WAR_INFANTRY', 'INFANTRY', 'MARINE',
        'PARATROOPER', 'XCOM_SQUAD', 'GATLINGGUN', 'MACHINE_GUN', 'BAZOOKA',
        'ANTI_TANK_GUN', 'ANTI_AIRCRAFT_GUN', 'LANCER', 'CAVALRY', 'FRIGATE',
        'PRIVATEER', 'CARAVEL', 'ATOMIC_BOMB', 'NUCLEAR_MISSILE', 'SWORDSMAN',
        'CATAPULT', 'SS_BOOSTER', 'WORKER']
    units = [('UNIT_' + name, 'UNITCLASS_' + name) for name in classes]
    units += [('UNIT_GERMAN_PANZER', 'UNITCLASS_TANK'),
              ('UNIT_JAPANESE_ZERO', 'UNITCLASS_FIGHTER'),
              ('UNIT_AMERICAN_B17', 'UNITCLASS_BOMBER'),
              ('UNIT_IROQUOIAN_MOHAWKWARRIOR', 'UNITCLASS_SWORDSMAN'),
              ('UNIT_SPANISH_CONQUISTADOR', 'UNITCLASS_KNIGHT'),
              ('UNIT_SONGHAI_MUSLIMCAVALRY', 'UNITCLASS_KNIGHT'),
              ('UNIT_MONGOLIAN_KESHIK', 'UNITCLASS_KNIGHT'),
              ('UNIT_ARABIAN_CAMELARCHER', 'UNITCLASS_KNIGHT'),
              ('UNIT_SIAMESE_WARELEPHANT', 'UNITCLASS_KNIGHT')]
    for unit, unit_class in units:
        db.execute('INSERT INTO Units (Type, Class, Help) VALUES (?, ?, ?)', (unit, unit_class, 'HELP_' + unit))
        for lang in ['Language_en_US', 'Language_RU_RU']:
            db.execute(f'INSERT INTO {lang} VALUES (?, ?)', ('HELP_' + unit, 'Original unit help'))
    db.execute("UPDATE Units SET PrereqTech = 'TECH_ROBOTICS' WHERE Class = 'UNITCLASS_MISSILE_CRUISER'")
    db.execute("UPDATE Units SET PrereqTech = 'TECH_TELECOM' WHERE Class = 'UNITCLASS_NUCLEAR_SUBMARINE'")
    # Representative input requirements, not a complete dump of BNW unit data.
    baseline = {
        'KNIGHT': ('IRON', 1), 'SPANISH_CONQUISTADOR': ('HORSE', 1),
        'SONGHAI_MUSLIMCAVALRY': ('HORSE', 1), 'MONGOLIAN_KESHIK': ('HORSE', 1),
        'TANK': ('OIL', 1), 'GERMAN_PANZER': ('OIL', 1),
        'MODERN_ARMOR': ('ALUMINUM', 1), 'IRONCLAD': ('COAL', 1),
        'ROCKET_ARTILLERY': ('ALUMINUM', 1), 'MOBILE_SAM': ('ALUMINUM', 1),
        'HELICOPTER_GUNSHIP': ('ALUMINUM', 1), 'MECH': ('URANIUM', 1),
        'FIGHTER': ('OIL', 1), 'BOMBER': ('OIL', 1), 'AMERICAN_B17': ('OIL', 1),
        'JET_FIGHTER': ('ALUMINUM', 1), 'STEALTH_BOMBER': ('ALUMINUM', 1),
        'ATOMIC_BOMB': ('URANIUM', 1), 'NUCLEAR_MISSILE': ('URANIUM', 2),
        'SWORDSMAN': ('IRON', 1), 'FRIGATE': ('IRON', 1),
        'LANCER': ('HORSE', 1), 'CAVALRY': ('HORSE', 1), 'SS_BOOSTER': ('ALUMINUM', 1)}
    for name, (resource, cost) in baseline.items():
        db.execute('INSERT INTO Unit_ResourceQuantityRequirements VALUES (?, ?, ?)',
                   ('UNIT_' + name, 'RESOURCE_' + resource, cost))
    # Deliberately stale requirements test replacement rather than accumulation.
    db.execute("INSERT INTO Unit_ResourceQuantityRequirements VALUES ('UNIT_MODERN_ARMOR', 'RESOURCE_IRON', 1)")
    db.execute("INSERT INTO Unit_ResourceQuantityRequirements VALUES ('UNIT_NUCLEAR_SUBMARINE', 'RESOURCE_ALUMINUM', 1)")



def validate_database(db):
    baseline_reference_errors = set(db.execute('PRAGMA foreign_key_check'))
    # Load localization as the game UpdateDatabase XML action does.
    localization = ET.parse(ROOT / 'mod/Text/Localization.xml').getroot()
    for lang in localization:
        for row in lang:
            db.execute(f'INSERT INTO {lang.tag} (Tag, Text) VALUES (?, ?)',
                       (row.attrib['Tag'], row.findtext('Text')))
    old_resources = set(db.execute('SELECT UnitType, ResourceType, Cost FROM Unit_ResourceQuantityRequirements'))
    original_tech_types = {row[0] for row in db.execute('SELECT Type FROM Technologies')}
    db.executescript((ROOT / 'mod/SQL/Gameplay.sql').read_text())
    original_particle = db.execute("SELECT * FROM Technologies WHERE Type = 'TECH_PARTICLE_PHYSICS'").fetchone()
    db.executescript((ROOT / 'mod/SQL/TechnologyRefinements.sql').read_text())
    assert db.execute("SELECT * FROM Technologies WHERE Type = 'TECH_PARTICLE_PHYSICS'").fetchone() == original_particle, 'Particle Physics metadata changed'
    legacy_layout_issues = layout_issues(db)
    assert any('vertical span > 4: TECH_COMPUTERS -> TECH_REFINED_NETWORKS' in issue for issue in legacy_layout_issues), 'fixture failed to reproduce v4 connector bug'
    db.executescript((ROOT / 'mod/SQL/TechTreePresentation.sql').read_text())
    assert db.execute("SELECT * FROM Technologies WHERE Type = 'TECH_PARTICLE_PHYSICS'").fetchone() == original_particle, 'Particle Physics metadata changed in UI migration'
    db.executescript((ROOT / 'mod/SQL/UnitResources.sql').read_text())
    # v6 extends Industrial-era layout AFTER checking v5's regression contracts.
    v5_position = db.execute("SELECT GridX, GridY FROM Technologies WHERE Type='TECH_ROBOTICS'").fetchone()
    assert v5_position == (16, 6)
    db.executescript((ROOT / 'mod/SQL/Development.sql').read_text())
    new_reference_errors = set(db.execute('PRAGMA foreign_key_check')) - baseline_reference_errors
    assert not new_reference_errors, ('new foreign key violations', new_reference_errors)
    rows = list(db.execute('SELECT Type, GridX, GridY FROM Technologies'))
    assert {row[0] for row in rows} == original_tech_types | {
        'TECH_REFINED_NETWORKS', 'TECH_REFINED_AI',
        'TECH_REFINED_MICROELECTRONICS', 'TECH_REFINED_AUTOMATION',
        'TECH_REFINED_AGRICULTURAL_MECHANIZATION'}, 'missing or unexpected technologies'
    assert len({(x, y) for _, x, y in rows}) == len(rows), 'technology positions collide'
    bands = list(db.execute("SELECT Era, min(GridX), max(GridX) FROM Technologies WHERE Era IS NOT NULL GROUP BY Era ORDER BY min(GridX)"))
    for left, right in zip(bands, bands[1:]):
        assert left[2] < right[1], ('era headers would overlap', left, right)
    assert not layout_issues(db, include_industrial=True), layout_issues(db, include_industrial=True)
    assert db.execute("SELECT GridX, GridY FROM Technologies WHERE Type = 'TECH_ROBOTICS'").fetchone() == (17, 6)
    assert db.execute("SELECT GridX, GridY FROM Technologies WHERE Type = 'TECH_FUTURE_TECH'").fetchone() == (19, 4)
    print('PASS: v4 regression and v6 industrial/late connectors: spans, card crossing and adapter positions')
    prereqs = {}
    for tech, parent in db.execute('SELECT TechType, PrereqTech FROM Technology_PrereqTechs'):
        prereqs.setdefault(tech, set()).add(parent)
    visiting, visited = set(), set()
    def visit(tech):
        assert tech not in visiting, 'technology cycle: ' + tech
        if tech in visited:
            return
        visiting.add(tech)
        for parent in prereqs.get(tech, set()):
            visit(parent)
        visiting.remove(tech)
        visited.add(tech)
    for tech, _, _ in rows:
        visit(tech)
    assert 'TECH_COMBINED_ARMS' not in prereqs['TECH_COMPUTERS']
    assert prereqs['TECH_COMPUTERS'] == {'TECH_ATOMIC_THEORY'}
    assert 'TECH_RADIO' in prereqs['TECH_ELECTRONICS']
    assert prereqs['TECH_TELECOM'] == {'TECH_REFINED_NETWORKS'}
    assert prereqs['TECH_INTERNET'] == {'TECH_TELECOM'}
    assert prereqs['TECH_ROBOTICS'] == {'TECH_REFINED_MICROELECTRONICS', 'TECH_REFINED_AUTOMATION'}
    assert prereqs['TECH_PARTICLE_PHYSICS'] == {'TECH_ADVANCED_BALLISTICS', 'TECH_SATELLITES'}
    assert db.execute("SELECT 1 FROM Building_TechAndPrereqs WHERE BuildingType = 'BUILDING_SPACESHIP_FACTORY' AND TechType = 'TECH_ROCKETRY'").fetchone()
    assert db.execute("SELECT 1 FROM Unit_TechTypes WHERE UnitType = 'UNIT_MISSILE_CRUISER' AND TechType = 'TECH_ROCKETRY'").fetchone()
    assert db.execute("SELECT 1 FROM Unit_TechTypes WHERE UnitType = 'UNIT_NUCLEAR_SUBMARINE' AND TechType = 'TECH_NUCLEAR_FISSION'").fetchone()
    print('PASS: civilian research paths and rocket/nuclear prerequisites for their applications')
    assert prereqs['TECH_REFINED_AI'] == {'TECH_TELECOM', 'TECH_ROBOTICS'}
    current_resources = set(db.execute('SELECT UnitType, ResourceType, Cost FROM Unit_ResourceQuantityRequirements'))
    affected = {row[0] for row in db.execute('SELECT u.Type FROM Units u JOIN Refined_UnitResourcePolicy p ON p.UnitClass = u.Class')}
    assert {r for r in old_resources if r[0] not in affected} == {r for r in current_resources if r[0] not in affected}, 'unreviewed requirements changed'
    assert set(db.execute('SELECT * FROM Refined_OriginalUnitResources')) == old_resources
    for (unit_class,) in db.execute('SELECT DISTINCT UnitClass FROM Refined_UnitResourcePolicy'):
        assert db.execute('SELECT 1 FROM Units WHERE Class = ?', (unit_class,)).fetchone(), 'unknown class: ' + unit_class
    def resources(unit):
        return dict(db.execute('SELECT ResourceType, Cost FROM Unit_ResourceQuantityRequirements WHERE UnitType = ?', (unit,)))
    assert resources('UNIT_KNIGHT') == {'RESOURCE_IRON': 1, 'RESOURCE_HORSE': 1}
    assert resources('UNIT_SPANISH_CONQUISTADOR') == {'RESOURCE_IRON': 1, 'RESOURCE_HORSE': 1}
    assert resources('UNIT_MONGOLIAN_KESHIK') == {'RESOURCE_HORSE': 1}
    assert not resources('UNIT_ARABIAN_CAMELARCHER')
    assert not resources('UNIT_SIAMESE_WARELEPHANT')
    assert resources('UNIT_CANNON') == {'RESOURCE_IRON': 1}
    assert resources('UNIT_GERMAN_PANZER') == {'RESOURCE_IRON': 1, 'RESOURCE_OIL': 1}
    assert resources('UNIT_MODERN_ARMOR') == {'RESOURCE_ALUMINUM': 1, 'RESOURCE_OIL': 1}
    assert resources('UNIT_NUCLEAR_SUBMARINE') == {'RESOURCE_IRON': 1, 'RESOURCE_URANIUM': 1}
    assert resources('UNIT_IRONCLAD') == {'RESOURCE_IRON': 1, 'RESOURCE_COAL': 1}
    assert resources('UNIT_AMERICAN_B17') == {'RESOURCE_ALUMINUM': 1, 'RESOURCE_OIL': 1}
    assert resources('UNIT_JAPANESE_ZERO') == {'RESOURCE_ALUMINUM': 1}, 'Zero lost oil exemption'
    assert resources('UNIT_NUCLEAR_MISSILE') == {'RESOURCE_URANIUM': 2}, 'nuclear cost changed'
    for unit in ['UNIT_INFANTRY', 'UNIT_ANTI_TANK_GUN', 'UNIT_ANTI_AIRCRAFT_GUN', 'UNIT_WORKER']:
        assert not resources(unit), 'resource-free fallback disappeared: ' + unit
    # Exact policies, including unique replacements; no duplicate or stray entries.
    expected = set(db.execute("""SELECT u.Type, p.ResourceType, p.Cost
        FROM Units u JOIN Refined_UnitResourcePolicy p ON p.UnitClass = u.Class
        WHERE NOT EXISTS (SELECT 1 FROM Refined_UnitResourceExemptions e
          WHERE e.UnitType = u.Type AND e.ResourceType = p.ResourceType)"""))
    assert expected == {r for r in current_resources if r[0] in affected}
    assert not db.execute('SELECT UnitType, ResourceType FROM Unit_ResourceQuantityRequirements GROUP BY UnitType, ResourceType HAVING COUNT(*) > 1').fetchall()
    assert db.execute('SELECT COUNT(DISTINCT UnitClass) FROM Refined_UnitResourcePolicy').fetchone()[0] == 25
    assert not db.execute('SELECT UnitType FROM Unit_ResourceQuantityRequirements GROUP BY UnitType HAVING COUNT(*) > 2').fetchall()
    def army_cost(army):
        total = Counter()
        for unit, count in army.items():
            total.update({resource: cost * count for resource, cost in resources('UNIT_' + unit).items()})
        return dict(total)
    assert army_cost({'RIFLEMAN': 6, 'ARTILLERY': 3, 'CAVALRY': 2, 'IRONCLAD': 2}) == {
        'RESOURCE_IRON': 5, 'RESOURCE_COAL': 2, 'RESOURCE_HORSE': 2}
    assert army_cost({'INFANTRY': 6, 'TANK': 2, 'ARTILLERY': 2, 'FIGHTER': 2, 'DESTROYER': 2}) == {
        'RESOURCE_IRON': 6, 'RESOURCE_OIL': 6, 'RESOURCE_ALUMINUM': 2}
    assert army_cost({'MECHANIZED_INFANTRY': 4, 'MODERN_ARMOR': 2, 'ROCKET_ARTILLERY': 2,
                     'JET_FIGHTER': 2, 'NUCLEAR_SUBMARINE': 1, 'MISSILE_CRUISER': 1}) == {
        'RESOURCE_IRON': 1, 'RESOURCE_OIL': 11, 'RESOURCE_ALUMINUM': 7, 'RESOURCE_URANIUM': 1}
    for lang in ['Language_en_US', 'Language_RU_RU']:
        for unit in affected:
            text = db.execute(f'SELECT l.Text FROM {lang} l JOIN Units u ON u.Help = l.Tag WHERE u.Type = ?', (unit,)).fetchone()
            assert text and text[0] and ('Refined' in text[0]), (lang, unit)
    print('PASS: 25 resource policies, replacements, Zero exemption, nuclear costs, alternatives and army demand')
    for (building,) in db.execute('SELECT Type FROM Refined_EffectBuildings'):
        row = db.execute('SELECT Cost, FaithCost, GreatWorkCount, GoldMaintenance, NeverCapture, NukeImmune FROM Buildings WHERE Type = ?', (building,)).fetchone()
        assert row == (-1, -1, -1, 0, 1, 1), (building, row)
        assert db.execute('SELECT 1 FROM BuildingClasses WHERE DefaultBuilding = ?', (building,)).fetchone()
    # All custom text keys exist in both languages.
    for table in ['Technologies', 'Buildings']:
        fields = ['Description', 'Civilopedia', 'Help']
        for row in db.execute(f"SELECT {', '.join(fields)} FROM {table} WHERE Type LIKE '%REFINED%'"):
            for key in filter(None, row):
                for lang in ['Language_en_US', 'Language_RU_RU']:
                    assert db.execute(f'SELECT 1 FROM {lang} WHERE Tag = ?', (key,)).fetchone(), key
    for lang in ['Language_en_US', 'Language_RU_RU']:
        help_key = db.execute("SELECT Help FROM Technologies WHERE Type = 'TECH_COMPUTERS'").fetchone()[0]
        text = db.execute(f'SELECT Text FROM {lang} WHERE Tag = ?', (help_key,)).fetchone()[0]
        assert 'Refined:' in text
    marker_texts = ['TXT_KEY_REFINED_NETWORKS_HELP', 'TXT_KEY_REFINED_MICRO_HELP',
                    'TXT_KEY_REFINED_AUTOMATION_HELP', 'TXT_KEY_REFINED_AI_HELP']
    for marker, tech in enumerate(['TECH_REFINED_NETWORKS', 'TECH_REFINED_MICROELECTRONICS',
                                  'TECH_REFINED_AUTOMATION', 'TECH_REFINED_AI'], 1):
        assert db.execute('SELECT ScenarioTechButton FROM Technologies WHERE Type = ?', (tech,)).fetchone()[0] == marker
        for lang in ['Language_en_US', 'Language_RU_RU']:
            actual = db.execute(f'SELECT Text FROM {lang} WHERE Tag = ?', ('TXT_KEY_SCENARIO_TECH_BUTTON_' + str(marker),)).fetchone()[0]
            expected_text = db.execute(f'SELECT Text FROM {lang} WHERE Tag = ?', (marker_texts[marker - 1],)).fetchone()[0]
            if marker == 1:
                assert 'Stock Exchange' in actual or 'фондовой биржей' in actual
                assert 'Farm' in actual or 'ферма' in actual
            else:
                assert actual == expected_text
    print('PASS: native ability tooltips, including the shared named network/agriculture slot')
    assert prereqs['TECH_REFINED_AGRICULTURAL_MECHANIZATION'] == {'TECH_FERTILIZER', 'TECH_STEAM_POWER'}
    assert 'TECH_FERTILIZER' not in prereqs['TECH_DYNAMITE']
    assert db.execute("SELECT Cost, Era, GridX, GridY FROM Technologies WHERE Type='TECH_REFINED_AGRICULTURAL_MECHANIZATION'").fetchone() == (2350, 'ERA_INDUSTRIAL', 11, 9)
    assert not db.execute("SELECT 1 FROM Technology_PrereqTechs WHERE PrereqTech='TECH_REFINED_AGRICULTURAL_MECHANIZATION'").fetchone()
    assert db.execute("SELECT TechType, Yield FROM Improvement_TechYieldChanges WHERE ImprovementType='IMPROVEMENT_LUMBERMILL'").fetchall() == [('TECH_MACHINERY', 1)]
    assert set(db.execute("SELECT TechType, Yield FROM Improvement_TechYieldChanges WHERE ImprovementType='IMPROVEMENT_QUARRY'")) == {('TECH_CONSTRUCTION', 1), ('TECH_CHEMISTRY', 1)}
    assert db.execute("SELECT ResourceType, Cost FROM Building_ResourceQuantityRequirements WHERE BuildingType='BUILDING_REFINED_STEEL_MILL'").fetchall() == [('RESOURCE_IRON', 1)]
    bonuses = {r[0] for r in db.execute("SELECT UnitType FROM Unit_ProductionModifierBuildings WHERE BuildingType='BUILDING_REFINED_STEEL_MILL' AND ProductionModifier=15")}
    expected_units = {r[0] for r in db.execute('SELECT u.Type FROM Units u JOIN Refined_SteelClasses c ON u.Class=c.UnitClass')}
    assert bonuses == expected_units and 'UNIT_GERMAN_PANZER' in bonuses and 'UNIT_FRIGATE' not in bonuses and 'UNIT_ARTILLERY' not in bonuses
    groups = db.execute("SELECT MutuallyExclusiveGroup FROM Buildings WHERE Type IN ('BUILDING_REFINED_ACADEMY','BUILDING_REFINED_SALON')").fetchall()
    assert len(groups)==2 and groups[0]==groups[1] and groups[0][0]>0
    assert db.execute("SELECT CultureRateModifier FROM Buildings WHERE Type='BUILDING_REFINED_SALON'").fetchone() == (10,)
    assert db.execute("SELECT Yield FROM Building_YieldChanges WHERE BuildingType='BUILDING_REFINED_PRINTING_CULTURE' AND YieldType='YIELD_CULTURE'").fetchone() == (4,)
    assert db.execute('SELECT count(*) FROM Refined_Eurekas').fetchone()[0] == 19
    for lang in ['Language_en_US', 'Language_RU_RU']:
        for tech, key in db.execute('SELECT TechType, Help FROM Refined_Eurekas'):
            condition = db.execute(f'SELECT Text FROM {lang} WHERE Tag=?', (key,)).fetchone()
            assert condition and condition[0]
            help_text = db.execute(f'SELECT l.Text FROM {lang} l JOIN Technologies t ON l.Tag=t.Help WHERE t.Type=?', (tech,)).fetchone()
            assert help_text and condition[0] not in help_text[0], ('revealed eureka condition', lang, tech)
            assert db.execute(f'SELECT Text FROM {lang} WHERE Tag=?', ('TXT_KEY_REFINED_EUREKA_FLAVOR_' + tech,)).fetchone(), ('missing eureka flavor', lang, tech)
    assert not db.execute('SELECT e.TechType FROM Refined_Eurekas e LEFT JOIN Technologies t ON e.TechType=t.Type WHERE t.Type IS NULL').fetchall()
    print('PASS: v6 agriculture layout, improvements, exact steel unit list, exclusion and 19 eureka rules')
    print('PASS: SQL, dependencies, positions, text references, hidden effects and resource preservation')


def validate_package():
    target = build()
    manifest = ET.parse(next(target.glob('*.modinfo'))).getroot()
    declared = {}
    for entry in manifest.find('Files'):
        path = target / entry.text
        assert hashlib.md5(path.read_bytes()).hexdigest() == entry.attrib['md5']
        declared[entry.text] = path
    for action in manifest.findall('./Actions/OnModActivated/UpdateDatabase'):
        assert action.text in declared
    assert [action.text for action in manifest.findall('./Actions/OnModActivated/UpdateDatabase')] == [
        'Text/Localization.xml', 'SQL/Gameplay.sql', 'SQL/TechnologyRefinements.sql', 'SQL/TechTreePresentation.sql', 'SQL/UnitResources.sql', 'SQL/Development.sql']
    for entry in manifest.findall('./EntryPoints/EntryPoint'):
        assert entry.attrib['file'] in declared
        if entry.attrib['file'].endswith('.xml'):
            context = ET.parse(declared[entry.attrib['file']]).getroot()
            assert context.tag == 'Context'
            assert declared[entry.attrib['file']].with_suffix('.lua').is_file()
            ids = {node.attrib['ID'] for node in context.iter() if 'ID' in node.attrib}
            assert not ids, 'gameplay addin must not expose eureka controls'
    assert {'Text/Localization.xml', 'SQL/Gameplay.sql', 'SQL/TechnologyRefinements.sql', 'SQL/TechTreePresentation.sql', 'SQL/UnitResources.sql', 'Lua/Refined.lua', 'Lua/Development.lua', 'Lua/Development.xml'} <= set(declared)
    print('PASS: package manifest, checksums, database actions and Lua entry point')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--database', type=Path)
    args = parser.parse_args()
    db = sqlite3.connect(':memory:')
    if args.database:
        source = sqlite3.connect(args.database.resolve().as_uri() + '?mode=ro', uri=True)
        source.backup(db)
        source.close()
        print('Checking a read-only copy of real BNW database:', args.database)
    else:
        fixture(db)
        print('Checking representative fixture; this is not an in-game test.')
    validate_database(db)
    validate_package()
