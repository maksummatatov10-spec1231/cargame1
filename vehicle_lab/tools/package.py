#!/usr/bin/env python3
"""Build the distributable archive. Development artifacts are excluded."""
from pathlib import Path
import hashlib, zipfile, json

root = Path(__file__).resolve().parents[1]
out = root.parent / 'Raptor_Animation_Lab.zip'
exclude = {'tools', 'tests', 'dist', '__pycache__',
           'reports/animation_reference.json', 'reports/conversion.json',
           'reports/model_inventory.json', 'reports/browser-test.json',
           'reports/viewer-desktop.png', 'reports/viewer-mobile.png',
           'reports/viewer-steering.png', 'reports/car_preview.png'}
required = ['start.py', 'index.html', 'app.js', 'style.css', 'README.md',
            'model/ford_raptor.glb', 'model/catalog.json', 'model/rig.json',
            'vendor/three.module.min.js', 'vendor/GLTFLoader.js', 'vendor/OrbitControls.js',
            'vendor/THREE-LICENSE.txt', 'reports/ANALYSIS.md',
            'source/Sketchfab_2023_04_02_02_24_34.blend']
files = []
for path in sorted(root.rglob('*')):
    if not path.is_file():
        continue
    rel = path.relative_to(root).as_posix()
    if any(rel == x or rel.startswith(x + '/') for x in exclude):
        continue
    files.append((path, rel))
with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path, rel in files:
        archive.write(path, Path('Raptor_Animation_Lab') / rel)
    names = set(archive.namelist())
    bad = archive.testzip()
    if bad:
        raise SystemExit('corrupt entry: ' + bad)
    for item in required:
        if 'Raptor_Animation_Lab/' + item not in names:
            raise SystemExit('missing required file: ' + item)
print(json.dumps({'zip': str(out), 'bytes': out.stat().st_size,
                  'sha256': hashlib.sha256(out.read_bytes()).hexdigest(),
                  'files': len(files),
                  'expanded_bytes': sum(i.file_size for i in zipfile.ZipFile(out).infolist())}, indent=2))
