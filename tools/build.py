#!/usr/bin/env python3
"""Create a ready-to-copy Civ V mod folder and a ZIP using only Python stdlib."""
from pathlib import Path
import hashlib
import shutil
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'mod'
OUTPUT = ROOT / 'dist'
VERSION = (ROOT / 'VERSION').read_text(encoding='utf-8').strip()
if not VERSION.isascii() or not VERSION.isdecimal() or int(VERSION) < 1 or str(int(VERSION)) != VERSION:
    raise ValueError('VERSION must contain a positive integer without leading zeros')
NAME = f'civ5-refined (v {VERSION})'
MOD_ID = '72f741c2-cbb3-4b31-aebc-f88915b615ad'


def build():
    target = OUTPUT / NAME
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(SOURCE, target)
    shutil.copyfile(ROOT / 'docs/unit-resources.md', target / 'ResourceRules.md')
    shutil.copyfile(ROOT / 'docs/technology-tree.md', target / 'TechnologyTree.md')
    root = ET.Element('Mod', id=MOD_ID, version=VERSION)
    props = ET.SubElement(root, 'Properties')
    for key, value in {
        'Name': 'civ5-refined — Prototype',
        'Teaser': 'Technology, agriculture, specialized industry and 19 research eurekas.',
        'Description': 'Prototype for unmodified Brave New World. New game recommended. Russian and English text. No DLL required.',
        'Authors': 'civ5-refined contributors',
        'AffectsSavedGames': '1', 'MinCompatibleSaveVersion': '1',
        'SupportsSinglePlayer': '1', 'SupportsMultiplayer': '0',
        'SupportsHotSeat': '0', 'SupportsMac': '1',
        'HideSetupGame': '0', 'ReloadAudioSystem': '0',
        'ReloadLandmarkSystem': '0', 'ReloadStrategicViewSystem': '0',
        'ReloadUnitSystem': '0',
    }.items():
        ET.SubElement(props, key).text = value
    deps = ET.SubElement(root, 'Dependencies')
    ET.SubElement(deps, 'Dlc', id='6DA07636-4123-4018-B643-6575B4EC336B',
                  minversion='0', maxversion='999')
    ET.SubElement(root, 'References')
    ET.SubElement(root, 'Blocks')
    files = ET.SubElement(root, 'Files')
    paths = sorted(p for p in target.rglob('*') if p.is_file())
    for path in paths:
        ET.SubElement(files, 'File', md5=hashlib.md5(path.read_bytes()).hexdigest(),
                      attrib={'import': '0'}).text = path.relative_to(target).as_posix()
    actions = ET.SubElement(ET.SubElement(root, 'Actions'), 'OnModActivated')
    for path in ['Text/Localization.xml', 'SQL/Gameplay.sql', 'SQL/TechnologyRefinements.sql', 'SQL/TechTreePresentation.sql', 'SQL/UnitResources.sql', 'SQL/Development.sql']:
        ET.SubElement(actions, 'UpdateDatabase').text = path
    entry = ET.SubElement(ET.SubElement(root, 'EntryPoints'), 'EntryPoint',
                          type='InGameUIAddin', file='Lua/Refined.lua')
    ET.SubElement(entry, 'Name').text = 'Refined city effects'
    ET.SubElement(entry, 'Description').text = 'Synchronizes technology bonuses in all cities.'
    entry = ET.SubElement(root.find('EntryPoints'), 'EntryPoint', type='InGameUIAddin', file='Lua/Development.xml')
    ET.SubElement(entry, 'Name').text = 'Refined development and eurekas'
    ET.SubElement(entry, 'Description').text = 'Agricultural adjacency, fishing and eureka progress.'
    ET.indent(root)
    ET.ElementTree(root).write(target / (NAME + '.modinfo'), encoding='utf-8', xml_declaration=True)
    archive = OUTPUT / (NAME + '.zip')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
        for path in sorted(target.rglob('*')):
            if path.is_file():
                out.write(path, path.relative_to(OUTPUT))
    print(target)
    print(archive)
    return target


if __name__ == '__main__':
    build()
