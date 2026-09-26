"""One dedicated, guarded installer including module creation and exact recovery."""
from pathlib import Path
import sys,json
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import studio_capture as capture
ROOT=capture.ROOT; HERE=Path(__file__).resolve().parent
baseline=capture.load(ROOT/'roblox/captures/continuous-lighting-before/capture.json')
rows={r['roblox_path']:r for r in baseline['manifest']}
def lua(v):
    if v is None:return 'nil'
    if type(v) is bool:return str(v).lower()
    if type(v) in (int,float):return repr(v)
    if isinstance(v,str):
        n=1
        while ']'+('='*n)+']' in v:n+=1
        return '['+('='*n)+'['+v+']'+('='*n)+']'
    if isinstance(v,list):return '{'+','.join(lua(x) for x in v)+'}'
    if isinstance(v,dict):
        if v.get('Type')=='Color3':return 'Color3.new('+','.join(lua(v[k]) for k in ['R','G','B'])+')'
        if v.get('Type')=='Vector3':return 'Vector3.new('+','.join(lua(v[k]) for k in ['X','Y','Z'])+')'
        return '{'+','.join('[ '+lua(k)+' ]='+lua(x) for k,x in v.items())+'}'
    raise TypeError(type(v))
paths={
    'LightingServer':'ServerStorage.Modules.Game.World.LightingServer',
    'ClientBase':'StarterPlayer.StarterPlayerScripts.ClientBase',
    'GaragePreviewPresentationClient':'ReplicatedStorage.Modules.Game.Garage.GaragePreviewPresentationClient',
    'OwnedGarageEnvironmentLightingClient':'ReplicatedStorage.Modules.Game.World.OwnedGarageEnvironmentLightingClient',
    'NightLamppostLightClient':'ReplicatedStorage.Modules.Game.World.NightLamppostLightClient',
    'WindowMaterialClient':'ReplicatedStorage.Modules.Game.World.WindowMaterialClient',
    'LightingPreviewClient':'ReplicatedStorage.Modules.Game.Development.LightingPreviewClient',
}
ops=[]
tuning=json.loads((HERE/'tuning.json').read_text())
palette=json.loads((HERE/'palette.json').read_text())
def folder(name,attributes=None,children=None):
    return dict(name=name,class_name='Folder',attributes=attributes or {},properties={},children=children or [])
look_tree=folder('ContinuousLooks',children=[folder(p['Name'],{k:v for k,v in p.items() if k!='Name'}) for p in tuning['Points']])
palette_tree=folder('ContinuousPresets',children=[folder(name,children=[folder(section,values) for section,values in sections.items()]) for name,sections in palette.items()])
for tree in [look_tree,palette_tree]:
    ops.append(dict(kind='tree',path=['ReplicatedStorage','Config','World','Lighting',tree['name']],class_name='Folder',after=tree))
day_sky=next(n for n in capture.nodes(baseline['hierarchy']) if n['path']=='ReplicatedStorage.Assets.World.Skies.DaySky')
sky_properties={k:v['value'] for k,v in day_sky['properties'].items() if v['type']!='Vector3'}
candidate=json.loads((HERE/'cloudless-sky.json').read_text())
for key in ['SkyboxBk','SkyboxDn','SkyboxFt','SkyboxLf','SkyboxRt','SkyboxUp']:sky_properties[key]=candidate['properties'][key]
sky_properties['SkyboxOrientation']=dict(Type='Vector3',X=0,Y=0,Z=0)
sky_properties['SunAngularSize']=9
sky_tree=dict(name='ContinuousSky',class_name='Sky',attributes={},properties=sky_properties,children=[])
ops.append(dict(kind='tree',path=['ReplicatedStorage','Assets','World','Skies','ContinuousSky'],class_name='Sky',after=sky_tree))
for name in ['LightingCycleDefinition','LightingCycle','LightingClient']:
    path='ReplicatedStorage.Modules.Game.World.'+name
    assert path not in rows
    ops.append(dict(kind='create',path=path.split('.'),class_name='ModuleScript',after=(HERE/(name+'.lua')).read_text(encoding='utf8')))
for name,path in paths.items():
    row=rows[path]
    after=(HERE/(name+'.lua')).read_text(encoding='utf8')
    assert len(after.encode())<150000,'Source size headroom'
    ops.append(dict(kind='source',path=path.split('.'),class_name=row['class_name'],before=(ROOT/row['file']).read_bytes().decode('utf8'),after=after))
cfg=['ReplicatedStorage','Config','World','Lighting']
node=next(n for n in capture.nodes(baseline['hierarchy']) if n['path_parts']==cfg)
attrs={k:v['value'] for k,v in node['attributes'].items()}
new_attributes=dict(CycleMode='Stepped',ContinuousGeographicLatitude=35,SteppedGeographicLatitude=189,SunriseClockTime=6,SunsetClockTime=18)
new_attributes.update({k:v for k,v in tuning.items() if k!='Points'})
for key,value in new_attributes.items():
    assert key not in attrs,'Unexpected existing configuration'
    ops.append(dict(kind='attribute',path=cfg,class_name='Folder',key=key,after=value))
guards=[]
for path in ['ReplicatedStorage.Modules.Game.World.LightingPresets','ReplicatedStorage.Modules.Game.World.LightingSchedule']:
    row=rows[path];guards.append(dict(path=path.split('.'),source=(ROOT/row['file']).read_bytes().decode('utf8')))
bundle=dict(placeId=baseline['place_id'],beforeCapture=baseline['content_sha256'],operations=ops,guards=guards)
revision_path='roblox/captures/lighting-horizon-moon-before/capture.json'
revision=capture.load(ROOT/revision_path)
revision_nodes={n['path']:n for n in capture.nodes(revision['hierarchy'])}
def unpack(v):
    if v['type']=='Color3':return dict(Type='Color3',R=v['r'],G=v['g'],B=v['b'])
    return v['value']
def close(a,b):
    if isinstance(a,dict):return isinstance(b,dict) and set(a)==set(b) and all(close(v,b[k]) for k,v in a.items())
    if type(a) in (int,float):return type(b) in (int,float) and abs(a-b)<1e-7
    return a==b
revision_ops=[]
def tune_tree(tree,parent):
    path=parent+[tree['name']]; old=revision_nodes['.'.join(path)]
    assert old['class_name']==tree['class_name'] and set(old['attributes'])==set(tree['attributes'])
    for key,value in tree['attributes'].items():
        previous=unpack(old['attributes'][key])
        if not close(previous,value):revision_ops.append(dict(kind='attribute',path=path,class_name=tree['class_name'],key=key,before=previous,after=value))
    for child in tree['children']:tune_tree(child,path)
for tree in [look_tree,palette_tree]:tune_tree(tree,cfg)
previous=unpack(revision_nodes['.'.join(cfg)]['attributes']['ContinuousCycleDurationSeconds'])
if not close(previous,tuning['ContinuousCycleDurationSeconds']):
    revision_ops.append(dict(kind='attribute',path=cfg,class_name='Folder',key='ContinuousCycleDurationSeconds',before=previous,after=tuning['ContinuousCycleDurationSeconds']))
sky_path=['ReplicatedStorage','Assets','World','Skies','ContinuousSky']
previous=unpack(revision_nodes['.'.join(sky_path)]['properties']['SunAngularSize'])
revision_ops.append(dict(kind='property',path=sky_path,class_name='Sky',key='SunAngularSize',before=previous,after=sky_properties['SunAngularSize']))
source_path='ReplicatedStorage.Modules.Game.World.LightingCycle'
row=next(r for r in revision['manifest'] if r['roblox_path']==source_path)
source_before=(ROOT/row['file']).read_text(encoding='utf8')
source_after=(HERE/'LightingCycle.lua').read_text(encoding='utf8')
if source_before!=source_after:
    revision_ops.append(dict(kind='source',path=source_path.split('.'),class_name='ModuleScript',before=source_before,after=source_after))
revision_bundle=dict(placeId=baseline['place_id'],beforeCapture=revision['content_sha256'],operations=revision_ops,guards=guards)
engine=(HERE/'installer_engine.lua').read_text(encoding='utf8')
text='-- Generated by build.py. REFINE changes only captured existing source/config/property targets.\nlocal fullBundle='+lua(bundle)+'\nlocal revisionBundle='+lua(revision_bundle)+'\nlocal function runner(bundle)\n'+engine+'\nend\n'
text+='return function(mode)\n if mode=="REFINE" then return runner(revisionBundle)("APPLY") end\n if mode=="REVERT_REFINEMENT" then return runner(revisionBundle)("ROLLBACK") end\n if mode=="AUDIT_REFINEMENT" then return runner(revisionBundle)("AUDIT") end\n return runner(fullBundle)(mode)\nend\n'
(HERE/'install.lua').write_text(text,encoding='utf8',newline='\n')
(HERE/'scope.json').write_text(json.dumps({'before_capture':'roblox/captures/continuous-lighting-before/capture.json','before_sha256':baseline['content_sha256'],'revision_before_capture':revision_path,'sources':paths,'new_modules':['LightingCycleDefinition','LightingCycle','LightingClient'],'attributes':list(new_attributes),'trees':[look_tree,palette_tree,sky_tree],'revision_operations':revision_ops,'lane':'Fast configuration refinement','contract':'docs/architecture/lighting-horizon-moon-handoff.md'},indent=2)+'\n',encoding='utf8')
print(json.dumps({'operations':len(ops),'installer_bytes':(HERE/'install.lua').stat().st_size}))
