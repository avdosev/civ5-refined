#!/usr/bin/env python3
"""Build a separate load-audit ZIP; preserve the normal package and gameplay."""
from pathlib import Path
import hashlib
import shutil
import xml.etree.ElementTree as ET
import zipfile
from build import ROOT, OUTPUT, NAME, build


def diagnostic_build():
    source = build()
    target = OUTPUT / 'diagnostic' / NAME
    if target.exists():
        shutil.rmtree(target)
    shutil.copytree(source, target)
    script = target / 'Lua/LoadAudit.lua'
    shutil.copyfile(ROOT / 'tools/diagnostics/LoadAudit.lua', script)
    manifest = next(target.glob('*.modinfo'))
    tree = ET.parse(manifest)
    root = tree.getroot()
    root.find('./Properties/Name').text += ' — LOAD AUDIT'
    ET.SubElement(root.find('Files'), 'File', {'import': '0', 'md5': hashlib.md5(script.read_bytes()).hexdigest()}).text = 'Lua/LoadAudit.lua'
    entry = ET.Element('EntryPoint', {'type': 'InGameUIAddin', 'file': 'Lua/LoadAudit.lua'})
    ET.SubElement(entry, 'Name').text = 'Refined independent load audit'
    ET.SubElement(entry, 'Description').text = 'Report loaded content once; no gameplay effects.'
    root.find('EntryPoints').insert(0, entry)
    ET.indent(root)
    tree.write(manifest, encoding='utf-8', xml_declaration=True)
    archive = OUTPUT / f'{NAME} load-audit.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
        for path in sorted(target.rglob('*')):
            if path.is_file():
                out.write(path, Path(NAME) / path.relative_to(target))
    # Only the manifest and independent addin differ from the normal package.
    for path in source.rglob('*'):
        if path.is_file() and path.suffix != '.modinfo':
            assert path.read_bytes() == (target / path.relative_to(source)).read_bytes()
    original = ET.parse(next(source.glob('*.modinfo'))).getroot()
    assert ET.tostring(root.find('Actions')) == ET.tostring(original.find('Actions'))
    print(archive)
    return archive


if __name__ == '__main__':
    diagnostic_build()
