"""Reversible client migration. Mirror is output; reconstruction is fingerprint checked."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
def read(p): return p.read_text(encoding='utf-8')
def write(p,s): p.write_text(s,encoding='utf-8',newline='\n')
def hash(s):
    h=0
    for b in s.encode(): h=(h*31+b)%4294967296
    return h
def q(s):
    eq='===='
    while ']'+eq+']' in s: eq+='='
    return '['+eq+'[\n'+s+']'+eq+']'
def expression(parts):
    if parts[:2]==['StarterPlayer','StarterPlayerScripts']:
        return 'game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")'+''.join(':WaitForChild('+json.dumps(p)+')' for p in parts[2:])
    return 'game:GetService('+json.dumps(parts[0])+')'+''.join(':WaitForChild('+json.dumps(p)+')' for p in parts[1:])
manifest=json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))
previous=json.loads(read(HERE/'migration.json')) if (HERE/'migration.json').exists() else []
old_index={r['old']:r for r in previous}
root='StarterPlayer.StarterPlayerScripts.'
shared='ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.'
special={
 'NeoTokyoRacersClient_Bootstrap_Shadow_Disabled':'Garage.GarageClient',
 'LocalScript':'Development.TrailerVehicleCameraClient','TEMP_LightingPreview':'Development.LightingPreviewClient',
 'TrailerMode.client.lua':'Development.TrailerModeClient','TrailerShot01Camera':'Development.TrailerShotClient',
 'ModuleShopUIController':'Garage.GarageUI', 'ClientThemeAdapter':'Core.ClientThemeAdapter',
 'ClientState':'Garage.GarageState','GarageReplacementComponents':'UI.GarageComponents',
 'DrivingControllerV47':'Vehicles.DrivingClient','DrivingFallbackController':'Vehicles.DrivingFallbackClient',
 'VehicleDynamicsModel':'Vehicles.VehicleDynamics','CachedThrustVisualRuntime':'Vehicles.VehicleVFXClient',
 'VehicleVFXController':'Vehicles.LegacyVehicleVFXClient',
}
tools={'LocalScript':'TrailerVehicleCameraEnabled','TEMP_LightingPreview':'LightingPreviewEnabled',
       'TrailerMode.client.lua':'TrailerModeEnabled','TrailerShot01Camera':'TrailerShotEnabled'}
records=[]
for row in manifest:
    path=row['roblox_path']
    if not (path.startswith(root) or path.startswith(shared)) or row.get('disabled') is True: continue
    if path==root+'ClientBase': continue
    if not path.startswith(root+'NeoTokyoRacersClient.') and path.startswith(root) and row['path_parts'][-1] not in tools: continue
    src=read(ROOT/row['file']); name=row['path_parts'][-1]
    if path in old_index:
        old=old_index[path]; target=next(r for r in manifest if r['roblox_path']==old['new']) if src.startswith('-- Phase 4 stateless') else None
        if target:
            src=read(ROOT/target['file']); assert src.startswith(old['prefix']) and src.endswith(old['suffix'])
            src=src[len(old['prefix']):len(src)-len(old['suffix'])] if old['suffix'] else src[len(old['prefix']):]
            for a,b in reversed(old['edits']): assert src.count(b)==1; src=src.replace(b,a)
            assert hash(src)==old['before']; cls=old['class']
        else: cls=row['class_name']
    else: cls=row['class_name']
    if name in special: dest=special[name]
    else:
        group=row['path_parts'][-2]
        group={'Core':'Garage','Preview':'Garage','Intro':'Dealership','Runtime':'Vehicles','Debug':'Development','Controllers':'Vehicles','Input':'Vehicles','Visuals':'Vehicles','VFX':'Vehicles'}.get(group,group)
        clean=name.removesuffix('_Active').removesuffix('_StudioOnly')
        if clean.endswith('Controller'): clean=clean[:-10]+('UI' if group=='UI' else 'Client')
        elif cls=='LocalScript' and not clean.endswith('Client'): clean+='Client'
        dest=group+'.'+clean
    new='ReplicatedStorage.Modules.'+('' if dest.startswith('Core.') else 'Game.')+dest
    records.append({'old':path,'parts':row['path_parts'],'new':new,'class':cls,'original':src,'body':src,'edits':[]})
# Export traversal order changes when LocalScripts become ModuleScripts. Freeze packaging/startup
# order from the pre-phase manifest so a rebuild is byte-identical across the migration.
order_rows=json.loads(read(HERE/'baseline.json')) if (HERE/'baseline.json').exists() else manifest
order={row['roblox_path']:i for i,row in enumerate(order_rows)}
records.sort(key=lambda r:order[r['old']])
assert len({r['new'] for r in records})==len(records),'Name collision'
def rec(name): return next(r for r in records if r['parts'][-1]==name)
def replace(r,a,b):
    assert r['body'].count(a)==1,(r['old'],a[:100],r['body'].count(a))
    r['body']=r['body'].replace(a,b); r['edits'].append([a,b])
def block(r,a,b,new):
    start=r['body'].index(a); end=r['body'].index(b,start)
    replace(r,r['body'][start:end],new)
garage=rec('NeoTokyoRacersClient_Bootstrap_Shadow_Disabled')
start=garage['body'].index('local DefaultTheme = {')
end=garage['body'].index('\nrefreshThemeFromValues()\n',start)
replace(garage,garage['body'][start:end],'''local Theme = {}
local function refreshThemeFromValues()
	for key,value in pairs(require(game:GetService("ReplicatedStorage").Modules.Core.ClientThemeAdapter).Read(themeFolder)) do Theme[key]=value end
end
''')
replace(garage,'Theme.FontFamily or DefaultTheme.FontFamily','Theme.FontFamily or require(game:GetService("ReplicatedStorage").Modules.Core.ClientThemeAdapter).DefaultTheme.FontFamily')
start=garage['body'].index('RunService.Heartbeat:Connect(function()\n\tlocal now = os.clock()\n\tif not reentryProbe:ShouldRun(now)')
end=garage['body'].index('-- NTR_PERSISTENCE_PHASE17_CLOSE_GARAGE_DRIVE_HANDOFF_REPAIR',start)
replace(garage,garage['body'][start:end],'-- Prompt-only re-entry: retired disabled proximity polling.\n\n')
block(garage,'local function setupCameraInput()','local function init()', '''local function setupCameraInput()
	require(game:GetService("ReplicatedStorage").Modules.Game.Garage.PreviewInputClient).bind(State,function() return isDriving end,updateCamera,script)
end

''')
# Only the two top-level terminal loops need detaching from registration completion.
for name,anchor in [('LODClient_Active','\nwhile true do\n\ttask.wait(UPDATE_RATE)'),('DriveToEarnCashTelemetry_StudioOnly','\nwhile gui.Parent do\n')]:
    r=rec(name); start=r['body'].index(anchor)
    replace(r,r['body'][start:],'\ntask.spawn(function()'+r['body'][start:]+'\nend)\n')
# An enabled trailer tool must fail clearly before any camera mutation when its authored markers are absent.
r=rec('TrailerShot01Camera')
replace(r,'local shotFolder = workspace:WaitForChild("TrailerShots"):WaitForChild("Shot01_StraightRoadPan")',
'''local shots=workspace:FindFirstChild("TrailerShots")
local shotFolder=shots and shots:FindFirstChild("Shot01_StraightRoadPan")
assert(shotFolder,"TrailerShotEnabled requires Workspace.TrailerShots.Shot01_StraightRoadPan")''')
for child,var in [('Camera_A','cameraA'),('Camera_B','cameraB'),('LookAt_Target','lookAtTarget')]:
    replace(r,f'local {var} = shotFolder:WaitForChild("{child}")',f'local {var} = assert(shotFolder:FindFirstChild("{child}"),"Missing trailer marker {child}")\nassert({var}:IsA("BasePart"),"Trailer marker must be a BasePart")')
entries=[]
dependencies={
 'GarageClient':['LoadingTransitionUI','SharedTopNotificationUI'],
 'GarageEntranceClient':['LoadingTransitionUI','GarageClient'],
 'DealershipIntroClient':['GarageClient'],
 'OwnedGarageClient':['LoadingTransitionUI'],
 'RaceEntryPresentationClient':['LoadingTransitionUI'],
}
for r in records:
    name=r['parts'][-1]; context='local script = '+expression(r['parts'])+'\n'
    r['adapter']='-- Phase 4 stateless compatibility adapter. Canonical implementation is the single owner.\nreturn require('+expression(r['new'].split('.'))+')\n'
    if r['class']=='LocalScript':
        guard=''
        if name in tools:
            guard='local config=game:GetService("ReplicatedStorage").NeoTokyoRacers.Config.Development.ClientTools\nif not require(game:GetService("ReplicatedStorage").Modules.Core.ClientLifecycle).tool_enabled(game:GetService("RunService"):IsStudio(),config,'+q(tools[name])+') then return end\n'
        r['prefix']='-- Phase 4 client-session feature. ClientBase owns startup; legacy path hosts compatibility endpoints.\nlocal Client={}\nlocal state\nfunction Client.start()\nif state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end\n'+guard+'state="starting"\nlocal ok,message=xpcall(function()\n'+context
        r['suffix']='\nend,debug.traceback)\nstate=ok and "ready" or "failed"\nassert(ok,message)\nend\nreturn Client\n'
        key=r['new'].split('.')[-1]
        entry={'name':key,'path':r['new'],'dependencies':dependencies.get(key,[])}
        if name in tools: entry['tool']=tools[name]
        entries.append(entry)
    else: r['prefix']='-- Phase 4 canonical helper. Legacy paths forward to this instance.\n'+context; r['suffix']=''
    r['before']=hash(r['original']); r['beforeBytes']=len(r['original'].encode())
    r['source']=r['prefix']+r['body']+r['suffix']; r['after']=hash(r['source']); r['afterBytes']=len(r['source'].encode())
keys={e['name'] for e in entries}
assert len(keys)==len(entries)
for e in entries: assert set(e['dependencies'])<=keys,(e,keys)
def lua(v):
    if isinstance(v,str): return q(v)
    if isinstance(v,bool): return str(v).lower()
    if isinstance(v,int): return str(v)
    if isinstance(v,list): return '{'+','.join(lua(x) for x in v)+'}'
    return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
base='''-- Explicit client composition root. No descendant auto-discovery or gameplay state.
local RS=game:GetService("ReplicatedStorage")
local lifecycle=require(RS:WaitForChild("Modules").Core.ClientLifecycle)
local config=RS.NeoTokyoRacers.Config.Development.ClientTools
local entries='''+lua(entries)+'''
local state=Instance.new("Folder"); state.Name="StartupState"; state.Parent=script
lifecycle.start(entries,function(entry)
	local item=game
	for part in entry.path:gmatch("[^%.]+") do item=item:WaitForChild(part) end
	return require(item)
end,function(name,status,message)
	state:SetAttribute(name,status)
	if message then warn("[ClientBase] "..name.." "..status..": "..message) end
end,function(flag) return lifecycle.tool_enabled(game:GetService("RunService"):IsStudio(),config,flag) end)
'''
extras=[{'path':root+'ClientBase','class':'LocalScript','source':base}]
for file,path in [('ClientLifecycle','Core.ClientLifecycle'),('ConnectionScope','Core.ConnectionScope'),('PreviewInputClient','Game.Garage.PreviewInputClient')]:
    extras.append({'path':'ReplicatedStorage.Modules.'+path,'class':'ModuleScript','source':read(HERE/(file+'.lua'))})
extras.append({'path':'ReplicatedStorage.NeoTokyoRacers.Config.Development.ClientTools','class':'Configuration','attributes':{v:False for v in tools.values()}})
compact=[{k:v for k,v in r.items() if k not in ['original','body','source']} for r in records]
write(HERE/'migration.json',json.dumps(compact,indent=2))
template=read(ROOT/'scripts/architecture_phase3/installer_template.lua').replace('Phase 3','Phase 4').replace('Phase3','Phase4').replace('ServerScriptService.ServerBase',root+'ClientBase')
template=template.replace('local function find(path)','local pathParts={}\nfor _,r in ipairs(records) do pathParts[r.old]=r.parts end\nlocal function split(path) return pathParts[path] or string.split(path,".") end\nlocal function find(path)')
template=template.replace('for part in path:gmatch("[^%.]+") do','for _,part in ipairs(split(path)) do')
template=template.replace('local parentPath,name=path:match("^(.*)%.([^%.]+)$")','local parts=table.clone(split(path)); local name=table.remove(parts)')
template=template.replace('for part in parentPath:gmatch("[^%.]+") do','for _,part in ipairs(parts) do')
template=template.replace('r.item:IsA("Script")','r.item:IsA("BaseScript")').replace('r.class=="Script"','r.class=="LocalScript"').replace('make(r.old,"Script",r.original,attrs)','make(r.old,"LocalScript",r.original,attrs)')
template=template.replace('e.item.Source==e.source','(not e.source or e.item.Source==e.source)')
template=template.replace('compile(e.source,e.path)','if e.source then compile(e.source,e.path) end\n\tif installed and e.attributes then for k,v in pairs(e.attributes) do assert(e.item:GetAttribute(k)==v,"Tool config changed; restore defaults before migration "..k) end end')
template=template.replace('item.Name=name; item.Source=source','item.Name=name; if source then item.Source=source end')
template=template.replace('make(e.path,e.class,e.source)','make(e.path,e.class,e.source,e.attributes)')
template=template.replace('game.ServerStorage:GetDescendants()','game:GetDescendants()')
template=template.replace('--[[RECORDS]]',','.join(lua(r) for r in compact)).replace('--[[EXTRAS]]',','.join(lua(e) for e in extras))
write(ROOT/'scripts/roblox_architecture_phase4_client_organisation.lua',template)
tests='local Lifecycle=(function()\n'+read(HERE/'ClientLifecycle.lua')+'\nend)()\nlocal Scope=(function()\n'+read(HERE/'ConnectionScope.lua')+'\nend)()\n'+read(HERE/'test_helpers.lua')
write(ROOT/'scripts/roblox_architecture_phase4_safety_tests.lua',tests)
baseline=HERE/'baseline.json'
if not baseline.exists(): write(baseline,json.dumps(manifest,indent=2))
out=HERE/'projected'; out.mkdir(exist_ok=True)
for r in records: write(out/(r['new'].removeprefix('ReplicatedStorage.Modules.')+'.lua'),r['source'])
for e in extras:
    if e.get('source'): write(out/(e['path'].split('.')[-1]+'.lua'),e['source'])
mapping='# Phase 4 client path map\n\nOld paths forward to these canonical implementations. Disabled scripts stay disabled. ReplicatedFirst retains early loading.\n\n| Compatibility path | Canonical implementation | Startup |\n|---|---|---|\n'
for r in records: mapping+='| `'+r['old']+'` | `'+r['new']+'` | '+('ClientBase' if r['class']=='LocalScript' else 'Existing require contract')+' |\n'
write(ROOT/'docs/architecture/phase4-path-map.md',mapping)
print('Packaged',len(records),'implementations;',len(entries),'startup entries;',len(template.encode()),'installer bytes')
