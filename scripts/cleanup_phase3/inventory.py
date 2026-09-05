"""Read-only mirror inventory for the approved generic naming migration."""
from pathlib import Path
import json,re,collections
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
h=json.loads((ROOT/'roblox/studio_snapshot/hierarchy.json').read_text())
nodes=[]
def walk(n):
    nodes.append(n)
    for c in n.get('children',[]):walk(c)
for n in h['hierarchy']:walk(n)
manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text())
sources={r['roblox_path']:(ROOT/r['file']).read_text(encoding='utf-8') for r in manifest}
scope=lambda n:n['path_parts'][0]!='Workspace' or n['path_parts'][:2]==['Workspace','NeoTokyoRacersWorld']
for n in nodes:
    p=n['path_parts']
    if (p[0] in ('ReplicatedStorage','ServerStorage','SoundService','ReplicatedFirst') and len(p)<=4) or (p[:2]==['Workspace','NeoTokyoRacersWorld'] and len(p)<=3):
        print(n['path'],n['class_name'],len(n.get('children',[])), 'attrs='+','.join(n.get('attributes',{})))
attrs=collections.Counter(k for n in nodes if scope(n) for k in n.get('attributes',{}) if re.search('NTR|NeoTokyo|HOVER|Phase|Version|Patch',k,re.I))
names=collections.Counter(n['name'] for n in nodes if scope(n) and re.search('NTR|NeoTokyo|HOVER_RACING|_Active|_Disabled|_EditAttributes|_DoNotRename',n['name']))
result={'mirror':h['generated_in_studio'],'sources':len(sources),'nodes':len(nodes),'attributes':dict(attrs),'names':dict(names)}
(HERE/'inventory.json').write_text(json.dumps(result,indent=2)+'\n')
print('ATTRIBUTES',len(attrs),'NAMES',len(names))
