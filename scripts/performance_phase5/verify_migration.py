"""Verify complete captured hierarchy, sources and generated catalogue freshness."""
from build import ROOT,HERE,dump,checksum
import sys
sys.path.insert(0,str(ROOT/'scripts/performance_phase3'))
from catalogue import flat
import collections,copy,gzip,hashlib,json
D=json.loads((HERE/'payload.json').read_text())
before=json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes()))
current=json.loads((ROOT/'roblox/studio_snapshot/hierarchy.json').read_text(encoding='utf8'))
changes={tuple(r['path']):r['after'] for r in D['sources']}
def clean(n):return {k:copy.deepcopy(v) for k,v in n.items() if k not in ('children','script_id')}
expected=[]
for n in flat(before):
    r=clean(n)
    if tuple(r['path_parts']) in changes:
        s=changes[tuple(r['path_parts'])];r['source_lines']=s.count('\n')+1;r['source_checksum']=checksum(s)
    expected.append(r)
for r in D['new']:
    p=r['path'];s=r['source']
    expected.append(dict(name=p[-1],path='.'.join(p),path_parts=p,class_name='ModuleScript',attributes=[],properties=[],source_lines=s.count('\n')+1,source_checksum=checksum(s),disabled=False))
serial=lambda n:json.dumps(n,sort_keys=True,separators=(',',':'))
left=collections.Counter(map(serial,expected));right=collections.Counter(serial(clean(n)) for n in flat(current))
manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf8'))
actual={tuple(r['path_parts']):r['source_sha256'] for r in manifest}
source_ok=actual=={tuple(r['path']):r['sha256'] for r in D['fingerprints']+D['new']}
for r in manifest:assert hashlib.sha256((ROOT/r['file']).read_text(encoding='utf8').encode()).hexdigest()==r['source_sha256']
result=dict(mirror=current['generated_in_studio'],sources=len(actual),source_sha256_parity=source_ok,all_hierarchy_property_parity=left==right,nodes=sum(right.values()),replicatedDescendants=sum(n['path_parts'][0]=='ReplicatedStorage' and len(n['path_parts'])>1 for n in flat(current)),missing_or_changed=sum((left-right).values()),added_or_changed=sum((right-left).values()))
dump(HERE/'verification.json',result)
if left!=right:dump(HERE/'mirror-differences.json',{'missing':[json.loads(x) for x in (left-right).elements()],'added':[json.loads(x) for x in (right-left).elements()]})
print(json.dumps(result,indent=2));assert source_ok and left==right
