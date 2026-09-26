"""Verify cumulative delivery and the current configuration-only refinement."""
from pathlib import Path
import copy, hashlib, json, math, sys
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent))
import studio_capture as c
scope=json.loads((HERE/'scope.json').read_text())
before=c.load(c.ROOT/scope['before_capture'])
revision=c.load(c.ROOT/scope['revision_before_capture'])
after=c.load(c.ROOT/'roblox/captures/lighting-horizon-moon-after/capture.json')
assert before['content_sha256']==scope['before_sha256']
delta=c.compare(before,after,details=True)
assert not delta['sourceRemoved'] and not delta['missingBefore'] and not delta['missingAfter']
expected_new={'ReplicatedStorage.Modules.Game.World.'+name for name in scope['new_modules']}
assert {'.'.join(p) for p in delta['sourceAdded']}==expected_new
assert {'.'.join(p) for p in delta['sourceChanged']}==set(scope['sources'].values())
rows={r['roblox_path']:r for r in after['manifest']}
for name,path in list(scope['sources'].items())+[(n,'ReplicatedStorage.Modules.Game.World.'+n) for n in scope['new_modules']]:
    assert rows[path]['source_sha256']==hashlib.sha256((HERE/(name+'.lua')).read_bytes()).hexdigest(),path

def shallow(node):
    n=copy.deepcopy(node); n.pop('children',None); return n
old={n['path']:shallow(n) for n in c.nodes(before['hierarchy'])}
new={n['path']:shallow(n) for n in c.nodes(after['hierarchy'])}
revision_nodes={n['path']:shallow(n) for n in c.nodes(revision['hierarchy'])}
assert set(old)<=set(new),'Removed captured object'
config='ReplicatedStorage.Config.World.Lighting'
expected_attrs=dict(CycleMode='Continuous',ContinuousGeographicLatitude=35,SteppedGeographicLatitude=189,SunriseClockTime=6,SunsetClockTime=18,ContinuousCycleDurationSeconds=720,ContinuousManualClockTime=12,ContinuousSkyName='ContinuousSky',ContinuousRayFadeHours=.4)
assert set(expected_attrs)==set(scope['attributes'])
for path,n in old.items():
    got=copy.deepcopy(new[path])
    if path==config:
        for key,val in expected_attrs.items():assert got['attributes'].pop(key)['value']==val
    if path=='Lighting.SunRays':
        assert got==revision_nodes[path],'Pre-existing Edit ray values were overwritten'
        for key in ['Enabled','Intensity','Spread']:got['properties'][key]=n['properties'][key]
    assert got==n,'Unexpected original object/property/tag change: '+path

def unpack(v):
    kind=v['type']
    if kind=='Color3':return dict(Type=kind,**{k.upper():v[k] for k in ['r','g','b']})
    if kind=='Vector3':return dict(Type=kind,**{k.upper():v[k] for k in ['x','y','z']})
    return v['value']
def close(a,b):
    if isinstance(a,dict):return isinstance(b,dict) and set(a)==set(b) and all(close(v,b[k]) for k,v in a.items())
    if type(a) in (int,float):return type(b) in (int,float) and math.isclose(a,b,rel_tol=0,abs_tol=1e-7)
    return a==b
expected_nodes=set()
def tree_check(tree,parent):
    path=parent+'.'+tree['name']; expected_nodes.add(path); got=new[path]
    assert got['class_name']==tree['class_name'] and got['name']==tree['name'] and not got['tags'],path
    assert close(tree['attributes'],{k:unpack(v) for k,v in (got['attributes'] or {}).items()}),path+' attributes'
    assert close(tree['properties'],{k:unpack(v) for k,v in (got['properties'] or {}).items()}),path+' properties'
    for child in tree['children']:tree_check(child,path)
for tree in scope['trees']:
    tree_check(tree,'ReplicatedStorage.Assets.World.Skies' if tree['class_name']=='Sky' else config)
assert set(new)-set(old)==expected_nodes,'Unexpected new captured nodes'
revision_delta=c.compare(revision,after,details=True)
assert not revision_delta['sourceAdded'] and not revision_delta['sourceRemoved']
expected_revision=set()
assert {'.'.join(p) for p in revision_delta['sourceChanged']}==expected_revision
expected_revision_nodes=copy.deepcopy(revision_nodes)
for op in scope['revision_operations']:
    if op['kind']=='source':continue
    path='.'.join(op['path'])
    field='properties' if op['kind']=='property' else 'attributes'
    assert close(unpack(revision_nodes[path][field][op['key']]),op['before'])
    expected_revision_nodes[path][field][op['key']]=new[path][field][op['key']]
    assert close(unpack(new[path][field][op['key']]),op['after'])
assert expected_revision_nodes==new,'Unexpected change outside refinement attributes'
result=dict(pass_scope=True,after_time_utc=after['generated_in_studio'],sources=len(after['manifest']),unchanged_original_sources=len(before['manifest'])-len(scope['sources']),changed_original_sources=7,new_modules=3,changed_revision_sources=0,refinement_attributes=sum(o['kind']=='attribute' for o in scope['revision_operations']),refinement_properties=1,preserved_edit_ray_properties=True,added_root_attributes=9,added_config_and_sky_nodes=len(expected_nodes),captured_nodes=len(new),capture_sha256=after['content_sha256'],coverage=delta['coverage'])
(HERE/'evidence/v7').mkdir(exist_ok=True)
(HERE/'evidence/v7/delivery-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(result,indent=2))
