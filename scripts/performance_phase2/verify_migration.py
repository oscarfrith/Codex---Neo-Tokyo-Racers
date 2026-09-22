"""Exact exported-source and complete captured hierarchy/property projection."""
from build import ROOT,HERE,flatten,target,dump,checksum
import collections,copy,gzip,hashlib,json
D=json.loads((HERE/'payload.json').read_text())
before=json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes()))
current=json.loads((ROOT/'roblox/studio_snapshot/hierarchy.json').read_text(encoding='utf-8'))
changes={tuple(r['path']):r['after'] for r in D['sources']}
def clean(n):return {k:copy.deepcopy(v) for k,v in n.items() if k not in ('children','script_id')}
def refs(v):
    if isinstance(v,dict):
        if v.get('type')=='Instance':v['path_parts']=target(v['path_parts'],D['moves']);v['path']='.'.join(v['path_parts'])
        else:
            for x in v.values():refs(x)
    elif isinstance(v,list):
        for x in v:refs(x)
expected=[]
for n in flatten(before):
    r=clean(n);p=r['path_parts'];r['path_parts']=target(p,D['moves']);r['path']='.'.join(r['path_parts'])
    refs(r.get('properties',{}))
    if tuple(p) in changes:
        s=changes[tuple(p)];r['source_lines']=s.count('\n')+1;r['source_checksum']=checksum(s)
    expected.append(r)
for p in D['created']:expected.append({'name':p[-1],'path':'.'.join(p),'path_parts':p,'class_name':'Folder','attributes':[],'properties':[]})
serial=lambda n:json.dumps(n,sort_keys=True,separators=(',',':'))
left=collections.Counter(map(serial,expected));right=collections.Counter(serial(clean(n)) for n in flatten(current))
manifest=json.loads((ROOT/'roblox/exported_scripts/manifest.json').read_text(encoding='utf-8'))
actual={tuple(r['path_parts']):r['source_sha256'] for r in manifest}
source_ok=actual=={tuple(r['path']):r['sha256'] for r in D['fingerprints']}
for r in manifest:assert hashlib.sha256((ROOT/r['file']).read_text(encoding='utf-8').encode()).hexdigest()==r['source_sha256']
result={'mirror':current['generated_in_studio'],'sources':len(actual),'source_sha256_parity':source_ok,'all_hierarchy_property_parity':left==right,
        'missing_or_changed':sum((left-right).values()),'added_or_changed':sum((right-left).values()),'nodes':sum(right.values()),
        'replicatedDescendants':sum(n['path_parts'][0]=='ReplicatedStorage' and len(n['path_parts'])>1 for n in flatten(current))}
dump(HERE/'verification.json',result)
if left!=right:dump(HERE/'mirror-differences.json',{'missing':[json.loads(x) for x in (left-right).elements()],'added':[json.loads(x) for x in (right-left).elements()]})
print(json.dumps(result,indent=2));assert source_ok and left==right
