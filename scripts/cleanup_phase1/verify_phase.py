"""Read current mirror and prove only the reviewed Phase 1 metadata changed."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def digest(nodes): return hashlib.sha256('\n'.join(sorted(json.dumps(n,sort_keys=True,separators=(',',':')) for n in nodes)).encode()).hexdigest()
b=read(HERE/'baseline.json');h=read(ROOT/'roblox/studio_snapshot/hierarchy.json')
nodes=[];pending=list(h['hierarchy'])
while pending:
    n=pending.pop();pending.extend(n.get('children',[]))
    nodes.append({k:v for k,v in n.items() if k not in ('children','script_id')})
assert digest(nodes)==b['expectedDigest'],'Unexpected hierarchy/property/attribute change'
assert len(nodes)==b['expectedNodeCount']
assert digest([n for n in nodes if n['path_parts'][0]=='Workspace'])==b['workspaceDigest'],'Workspace changed'
m=read(ROOT/'roblox/exported_scripts/manifest.json')
expected={tuple(s['path']):s['sha256'] for s in b['sources']}
actual={tuple(s['path_parts']):s['source_sha256'] for s in m}
assert actual==expected,'Gameplay source set/SHA-256 changed'
result={'status':'installed_awaiting_user_playtest','objects_removed':len(b['nodes']),
    'exported_objects_removed':b['exportedRemovedCount'],'root_metadata_removed':len(b['attributes']),
    'scripts':len(m),'source_sha256_parity':'PASS','remaining_exported_nodes':len(nodes),
    'expected_hierarchy_property_parity':'PASS','entire_workspace_parity':'PASS',
    'mirror':h['generated_in_studio'],'schema':h['schema_revision']}
print(json.dumps(result,indent=2))
