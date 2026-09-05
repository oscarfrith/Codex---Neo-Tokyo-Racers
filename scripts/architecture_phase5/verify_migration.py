"""Read-only source parity and packaging verification for the final phase."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]; HERE=Path(__file__).resolve().parent
def read(p): return p.read_text(encoding='utf-8')
baseline=json.loads(read(HERE/'baseline.json'))
current={r['roblox_path']:r for r in json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))}
owner='ReplicatedStorage.Modules.Game.World.LODClient'
unchanged=0
for row in baseline:
    if row['roblox_path']==owner: continue
    now=current[row['roblox_path']]
    for key in ['source_sha256','class_name','disabled']: assert row[key]==now[key],(row['roblox_path'],key)
    unchanged+=1
for name in ['LODClient','LODPolicy','LODRuntime']:
    row=current['ReplicatedStorage.Modules.Game.World.'+name]
    assert row['class_name']=='ModuleScript'
    assert read(ROOT/row['file'])==read(HERE/(name+'.lua')),name
print(json.dumps({'status':'PASS','untouched_sources':unchanged,'mirrored_sources':len(current),'canonical_source_matches':3},indent=2))
