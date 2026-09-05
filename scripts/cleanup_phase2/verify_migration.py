"""Verify the exported source set and every captured hierarchy/property record against the migration."""
from prepare import *
from collections import Counter
import copy
def flatten(h):
    result=[];todo=list(h['hierarchy'])
    while todo:
        n=todo.pop();todo.extend(n.get('children',[]));result.append({k:v for k,v in n.items() if k not in ('children','script_id')})
    return result
def serial(n):return json.dumps(n,sort_keys=True,separators=(',',':'))
def digest(nodes):return hashlib.sha256('\n'.join(sorted(map(serial,nodes))).encode()).hexdigest()
def relocate(n,path):
    n=copy.deepcopy(n);n['path_parts']=path;n['path']='.'.join(path);n['name']=path[-1];return n
d=json.loads(read(HERE/'payload.json'));before=flatten(json.loads(read(HERE/'hierarchy-before.json')))
current_h=json.loads(read(ROOT/'roblox/studio_snapshot/hierarchy.json'));actual=flatten(current_h)
expected=[copy.deepcopy(n) for n in before];retired={tuple(r['node']['path_parts']):r for r in d['retired']}
expected=[relocate(n,retired[tuple(n['path_parts'])]['move']) if tuple(n['path_parts']) in retired else n for n in expected if tuple(n['path_parts']) not in retired or retired[tuple(n['path_parts'])]['move']]
for r in d['sources']:
    if r['from']!=r['path']:
        matches=[i for i,n in enumerate(expected) if n['path_parts']==r['from']];assert len(matches)==1,r['from']
        i=matches[0];expected[i]=relocate(expected[i],r['path'])
for r in d['created']:
    if not any(n['path_parts']==r['path'] for n in expected):
        expected.append({'attributes':[],'class_name':r['class'],'name':r['path'][-1],'path':'.'.join(r['path']),'path_parts':r['path'],'properties':[]})
for n in expected:
    source=next((r for r in d['sources'] if r['path']==n['path_parts']),None)
    if source:
        text=source['source'];n['source_lines']=text.count('\n')+1
        n['source_checksum']=str(sum((i+1)*b for i,b in enumerate(text.encode()))%1000000007)
        n['disabled']=False
    if n['path_parts']==['ReplicatedStorage','NeoTokyoRacers']:
        for key in d['configAttributes']:del n['attributes'][key]
    if n['path_parts']==['ReplicatedStorage','Config','Garage']:n['attributes']=d['configAttributes']
left=Counter(map(serial,expected));right=Counter(map(serial,actual))
differences={'missing_or_changed':[json.loads(n) for n in (left-right).elements()], 'added_or_changed':[json.loads(n) for n in (right-left).elements()]}
dump(HERE/'mirror-differences.json',differences)
manifest=json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))
source_hashes={tuple(r['path']):hashlib.sha256(r['source'].encode()).hexdigest() for r in d['sources']}
actual_hashes={tuple(r['path_parts']):r['source_sha256'] for r in manifest}
workspace_before=[n for n in before if n['path_parts'][0]=='Workspace'];workspace_after=[n for n in actual if n['path_parts'][0]=='Workspace']
summary={'mirror':current_h['generated_in_studio'],'sources':len(manifest),'source_set_sha256_parity':source_hashes==actual_hashes,
 'expected_hierarchy_parity':left==right,'missing_or_changed':len(differences['missing_or_changed']),'added_or_changed':len(differences['added_or_changed']),
 'entire_workspace_parity':digest(workspace_before)==digest(workspace_after),'workspace_digest':digest(workspace_after),
 'before_nodes':len(before),'after_nodes':len(actual),'expected_nodes':len(expected)}
dump(HERE/'verification.json',summary);print(json.dumps(summary,indent=2))
assert summary['source_set_sha256_parity'] and summary['entire_workspace_parity'] and summary['expected_hierarchy_parity'],'Mirror parity failed; inspect mirror-differences.json'
