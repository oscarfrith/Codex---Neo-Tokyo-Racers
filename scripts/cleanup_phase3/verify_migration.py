"""Compare every exported source/property record with the exact Phase 3 map."""
from prepare import *
import copy
p=json.loads(read(HERE/'payload.json'));before=flatten(json.loads(gzip.decompress((HERE/'hierarchy-before.json.gz').read_bytes())))
h=json.loads(read(ROOT/'roblox/studio_snapshot/hierarchy.json'));current=flatten(h)
def clean(n):return {k:copy.deepcopy(v) for k,v in n.items() if k not in ('children','script_id')}
def target(path):
 for m in sorted(p['moves'],key=lambda r:-len(r['before'])):
  if path[:len(m['before'])]==m['before']:return m['after']+path[len(m['before']):]
 return path
def references(v):
 if isinstance(v,dict):
  if v.get('type')=='Instance':v['path_parts']=target(v['path_parts']);v['path']='.'.join(v['path_parts'])
  else:
   for x in v.values():references(x)
 elif isinstance(v,list):
  for x in v:references(x)
retired={tuple(n['path_parts']) for n in p['retired']};source_by={tuple(r['beforePath']):r for r in p['sources']}
meta=collections.defaultdict(list)
for r in p['metadata']:meta[tuple(r['path'])].append(r)
expected=[]
for n in before:
 old=tuple(n['path_parts'])
 if old in retired:continue
 r=clean(n)
 for m in meta.get(old,[]):
  if m['class']==r['class_name'] and m['attributes']==r['attributes']:
   for c in m['changes']:
    del r['attributes'][c['old']]
    if c['new']:r['attributes'][c['new']]=c.get('afterValue',c['value'])
   if not r['attributes']:r['attributes']=[]
   break
 r['path_parts']=target(r['path_parts']);r['path']='.'.join(r['path_parts']);r['name']=r['path_parts'][-1]
 references(r.get('properties'))
 if old in source_by:
  s=source_by[old]['source'];r['source_lines']=s.count('\n')+1;r['source_checksum']=str(sum((i+1)*b for i,b in enumerate(s.encode()))%1000000007)
 expected.append(r)
for c in p['created']:expected.append({'path_parts':c['path'],'path':'.'.join(c['path']),'name':c['path'][-1],'class_name':c['class'],'attributes':[],'properties':[]})
serial=lambda n:json.dumps(n,sort_keys=True,separators=(',',':'))
left=collections.Counter(map(serial,expected));right=collections.Counter(serial(clean(n)) for n in current)
diff={'missing_or_changed':[json.loads(x) for x in (left-right).elements()],'added_or_changed':[json.loads(x) for x in (right-left).elements()]}
dump(HERE/'mirror-differences.json',diff)
manifest=json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))
source_ok={tuple(r['path']):hashlib.sha256(r['source'].encode()).hexdigest() for r in p['sources']}=={tuple(r['path_parts']):r['source_sha256'] for r in manifest}
def wip(ns):return collections.Counter(serial(clean(n)) for n in ns if n['path_parts'][0]=='Workspace' and len(n['path_parts'])>1 and n['path_parts'][1] not in ('World','NeoTokyoRacersWorld'))
result={'mirror':h['generated_in_studio'],'sources':len(manifest),'source_sha256_parity':source_ok,'expected_hierarchy_property_parity':left==right,'excluded_workspace_export_parity':wip(before)==wip(current),'missing_or_changed':sum((left-right).values()),'added_or_changed':sum((right-left).values()),'before_nodes':len(before),'after_nodes':len(current),'expected_nodes':len(expected),'tag_evidence':'Installer verifies exact approved WIP tag inventory separately; tags are not captured by the current exporter.'}
dump(HERE/'verification.json',result);print(json.dumps(result,indent=2));assert source_ok and left==right and wip(before)==wip(current)
