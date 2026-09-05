"""Freeze Phase 1 once, then generate its canonical metadata-only installer."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
def read(p): return p.read_text(encoding='utf-8')
def write(p,s): p.write_text(s,encoding='utf-8',newline='\n')
def flat(tree):
    result=[]; pending=list(tree)
    while pending:
        n=pending.pop();pending.extend(n.get('children',[]))
        result.append({k:v for k,v in n.items() if k not in ('children','script_id')})
    return result
def digest(nodes):
    return hashlib.sha256('\n'.join(sorted(json.dumps(n,sort_keys=True,separators=(',',':')) for n in nodes)).encode()).hexdigest()
baseline=HERE/'baseline.json'
if not baseline.exists():
    d=json.loads(read(HERE/'inventory.json'))
    h=json.loads(read(ROOT/'roblox/studio_snapshot/hierarchy.json'))
    m=json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))
    d['nodes'].sort(key=lambda n:(len(n['path']),n['path']))
    d['sources']=[dict(path=s['path_parts'],className=s['class_name'],bytes=s['source_bytes'],checksum=int(s['source_checksum']),disabled=s['disabled'],sha256=s['source_sha256']) for s in m]
    d['mirrorBefore']=h['generated_in_studio']
    nodes=flat(h['hierarchy']);d['beforeDigest']=digest(nodes)
    removed={tuple(n['path']) for n in d['nodes']}
    expected=[n for n in nodes if tuple(n['path_parts']) not in removed]
    bypath={tuple(n['path_parts']):n for n in expected}
    for a in d['attributes']:
        n=bypath[tuple(a['path'])]
        assert n['attributes'][a['key']]['value']==a['value']
        del n['attributes'][a['key']]
        if not n['attributes']: n['attributes']=[]
    d['expectedDigest']=digest(expected);d['expectedNodeCount']=len(expected)
    d['exportedRemovedCount']=len(nodes)-len(expected)
    d['workspaceDigest']=digest([n for n in nodes if n['path_parts'][0]=='Workspace'])
    write(baseline,json.dumps(d,indent=2)+'\n')
    # Freeze hashes/contracts and available owner maps before subsequent path changes.
    contracts=[]
    for n in nodes:
        if (n['class_name'] in ('RemoteEvent','RemoteFunction','BindableEvent','BindableFunction') or
            '.Config.' in n['path'] or n['path'].endswith('.Config')):
            contracts.append(n)
    write(HERE/'contracts-before.json',json.dumps(contracts,indent=2)+'\n')
    maps={}
    for name in ('phase3-path-map.md','phase4-path-map.md'):
        maps[name]=read(ROOT/'docs/architecture'/name)
    write(HERE/'owner-maps-before.json',json.dumps(maps,indent=2)+'\n')
else: d=json.loads(read(baseline))
payload=json.dumps(d,separators=(',',':'),ensure_ascii=False)
eq='===='
while ']'+eq+']' in payload: eq+='='
literal='['+eq+'[\n'+payload+']'+eq+']'
write(ROOT/'scripts/roblox_cleanup_phase1_scaffolding.lua',read(HERE/'installer_template.lua').replace('--[[PAYLOAD]]',literal))
print(json.dumps({'objects':len(d['nodes']),'attributes':len(d['attributes']),'sources':len(d['sources']),'mirrorBefore':d['mirrorBefore']}))
