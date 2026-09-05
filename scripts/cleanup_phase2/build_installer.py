"""Package a single transactional installer from frozen sources and reviewed projections."""
from prepare import *
from path_analysis import analyze
rows=json.loads(read(HERE/'baseline.json'));by_path={r['roblox_path']:r for r in rows}
index=json.loads(read(HERE/'projection-index.json'))
module_map=json.loads(read(HERE/'module-map.json'));runtime_map=json.loads(read(HERE/'runtime-map.json'))
h=json.loads(read(HERE/'hierarchy-before.json'))
nodes=[];todo=list(h['hierarchy'])
while todo:
    n=todo.pop();todo.extend(n.get('children',[]));nodes.append({k:v for k,v in n.items() if k not in ('children','script_id')})
node_index={tuple(n['path_parts']):n for n in nodes}
def map_runtime(parts):
    for old,new in sorted(runtime_map.items(),key=lambda kv:-len(kv[0])):
        old=old.split('.')
        if parts[:len(old)]==old:return new.split('.')+parts[len(old):]
    raise AssertionError(parts)

runtime={}
for file in ('server-runtime-before.json','client-runtime-before.json'):
    for n in json.loads(read(HERE/file))['nodes']:
        if n['class'] not in ('Folder','BindableEvent','BindableFunction'):continue
        parts=n['path'] if file.startswith('server') else ['StarterPlayer','StarterPlayerScripts']+n['path']
        if parts[-1].isdigit():continue
        target=map_runtime(parts)
        runtime[tuple(target)]=n['class']

sources=[]
for path in index:
    row=by_path.get(path)
    previous=next((r for r in rows if module_map.get(r['roblox_path'])==path and r['roblox_path'] not in index),None) if row is None else None
    # A newly moved shared implementation keeps its source instance; a retired adapter never does.
    if previous and read(HERE/previous['before_file']).startswith('-- Phase '):previous=None
    source=read(HERE/'projected'/('/'.join(path.split('.'))+'.lua'))
    parts=row['path_parts'] if row else path.split('.')
    sources.append({'path':parts,'source':source,'class':(row or previous or {}).get('class_name','ModuleScript'),
                    'from':previous['path_parts'] if previous else parts,'hash':hash32(source)})

# Only endpoint-containing/explicitly used runtime folders survive. No empty code namespace replica.
required=set()
unknown=[]
for r in sources:
    chains,_=analyze(r['source'],r['path'])
    for _,_,path,_ in chains:
        if path[:2]==('ServerStorage','Runtime') or path[:3]==('StarterPlayer','StarterPlayerScripts','Runtime'):
            if path not in runtime:unknown.append(['.'.join(r['path']),'.'.join(path)])
            required.add(path)
for path,cls in runtime.items():
    if cls!='Folder':required.add(path)
required.add(('ServerStorage','Runtime','Player','RuntimeProfiles'))
# Attribute and lifetime owners referenced directly through private script APIs in old sources.
for feature in ('UI','Racing','World','Garage','Dealership','Vehicles'):required.add(('StarterPlayer','StarterPlayerScripts','Runtime',feature))
for path in list(required):
    root_length=2 if path[0]=='ServerStorage' else 3
    for i in range(root_length,len(path)+1):required.add(path[:i])
containers=[{'path':list(p),'class':runtime.get(p,'Folder')} for p in sorted(required,key=lambda p:(len(p),p))]
dump(HERE/'unresolved-runtime.json',unknown)

retired_roots=[['ServerScriptService','NeoTokyoRacers'],['StarterPlayer','StarterPlayerScripts','NeoTokyoRacersClient'],['ReplicatedStorage','NeoTokyoRacers','Shared','Modules']]
source_paths={tuple(r['path']) for r in sources}
moved_from={tuple(r['from']) for r in sources if r['from']!=r['path']}
deleted=[]
for n in nodes:
    p=n['path_parts']
    if any(p[:len(root)]==root for root in retired_roots) or (n['class_name'] in ('ModuleScript','Script','LocalScript') and tuple(p) not in source_paths):
        if tuple(p) in moved_from:continue
        assert p[0]!='Workspace','Workspace deletion is prohibited'
        assert n['class_name'] in ('Folder','ModuleScript','StringValue','ObjectValue','BindableEvent','BindableFunction'),(p,n['class_name'])
        # Existing endpoint instances are moved, not destroyed.
        dest=None
        if n['class_name'] in ('BindableEvent','BindableFunction') or (n['class_name']=='Folder' and n.get('attributes')):
            if any(p[:len(root)]==root for root in retired_roots[:2]):
                dest=map_runtime(p)
                if tuple(dest) not in required:dest=None
        deleted.append({'node':n,'move':dest})

# Do not move branded roots carrying only historical metadata into Runtime; their descendants move individually.
for r in deleted:
    if r['move'] and len(r['move'])<4 and r['node']['class_name']=='Folder':r['move']=None
    if r['node']['path_parts'][-1] in ('NeoTokyoRacersClient','Controllers','NeoTokyoRacers','Services'):r['move']=None

root_node=node_index[('ReplicatedStorage','NeoTokyoRacers')]
config_keys=('StartingCash','SpawnX','SpawnY','SpawnZ','PreviewX','PreviewY','PreviewZ')
config_attrs={k:root_node.get('attributes',{}).get(k) for k in config_keys}
assert all(v is not None for v in config_attrs.values()),config_attrs
payload={'placeId':121304917315753,'sources':sources,
 'beforeSources':[dict(path=r['path_parts'],className=r['class_name'],source=read(HERE/r['before_file']),hash=r['hash32'],disabled=r.get('disabled')) for r in rows],
 'retired':deleted,'containers':containers,'configAttributes':config_attrs,
 'sourceCount':len(sources),'beforeCount':len(rows)}
created={}
for r in containers+sources+[{'path':['ReplicatedStorage','Config','Garage'],'class':'Folder'}]:
    path=r['path']
    for i in range(2,len(path)+1):
        p=tuple(path[:i])
        if p not in node_index:created[p]=r['class'] if i==len(path) else 'Folder'
payload['created']=[{'path':list(p),'class':cls} for p,cls in sorted(created.items(),key=lambda kv:(len(kv[0]),kv[0]))]
dump(HERE/'payload.json',payload)
template=read(HERE/'installer_template.lua')
blob=json.dumps(payload,separators=(',',':'))
assert ']========]' not in blob
write(ROOT/'scripts/roblox_cleanup_phase2_canonical_ownership.lua',template.replace('--[[PAYLOAD]]','[========['+blob+']========]'))
print('Packaged',len(sources),'sources;',len(deleted),'retired/moved records;',len(containers),'runtime instances;',len(unknown),'runtime paths to review')
