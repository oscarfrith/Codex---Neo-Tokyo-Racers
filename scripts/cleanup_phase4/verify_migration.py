"""Verify source projection and every captured property against arrival baseline."""
from pathlib import Path
import json,gzip,hashlib,collections
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
def flatten(h):
    out=[];todo=list(h['hierarchy'])
    while todo:
        n=todo.pop();todo.extend(n.get('children',[]));out.append(n)
    return out
before=json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes()))
after=json.loads((ROOT/'roblox/studio_snapshot/hierarchy.json').read_text())
payload=json.loads((HERE/'payload.json').read_text())['sources']
sources={tuple(r['path']):r['after'] for r in payload}
def records(h,project=False):
    out=[]
    for n in flatten(h):
        r={k:v for k,v in n.items() if k not in ('children','script_id')}
        if project and tuple(r['path_parts']) in sources:
            s=sources[tuple(r['path_parts'])];r['source_lines']=s.count('\n')+1
            r['source_checksum']=str(sum(i*b for i,b in enumerate(s.encode(),1))%1000000007)
        out.append(json.dumps(r,sort_keys=True))
    return collections.Counter(out)
a,b=records(before,True),records(after)
manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text())
expected={p:hashlib.sha256(s.encode()).hexdigest() for p,s in sources.items()}
actual={tuple(r['path_parts']):r['source_sha256'] for r in manifest}
result={'mirror':after['generated_in_studio'],'sources':len(actual),'source_parity':expected==actual,'all_hierarchy_property_parity':a==b,'missing_or_changed':sum((a-b).values()),'added_or_changed':sum((b-a).values()),'nodes':sum(b.values()),'arrival_physical_changes':'User approved preserving 628 changed arrow CFrames and 66 added thumbnail-model records before Phase 4.'}
(HERE/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2));assert a==b and actual==expected
