"""Read-only migration evidence, including every source outside Phase 4's scope."""
from pathlib import Path
import hashlib
import json
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf-8'))
baseline=json.loads((HERE/'baseline.json').read_text(encoding='utf-8'))
migrations=json.loads((HERE/'migration.json').read_text(encoding='utf-8'))
current={r['roblox_path']:r for r in manifest}
changed={r['old'] for r in migrations}
unchanged=0
for original in baseline:
    if original['roblox_path'] in changed: continue
    row=current[original['roblox_path']]
    for key in ['class_name','disabled','source_sha256']: assert row[key]==original[key],(original['roblox_path'],key)
    unchanged+=1
for migration in migrations:
    row=current[migration['old']]
    assert row['class_name']=='ModuleScript'
    source=(ROOT/row['file']).read_text(encoding='utf-8')
    assert source==migration['adapter'],row['roblox_path']
    projected=HERE/'projected'/(migration['new'].removeprefix('ReplicatedStorage.Modules.')+'.lua')
    expected=hashlib.sha256(projected.read_bytes()).hexdigest()
    assert current[migration['new']]['source_sha256']==expected,migration['new']
print(json.dumps({'status':'PASS','untouched_sources':unchanged,'migrated_implementations':len(migrations),'mirrored_sources':len(manifest)},indent=2))
