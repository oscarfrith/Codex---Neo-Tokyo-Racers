from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]; HERE=Path(__file__).resolve().parent
def read(p): return p.read_text(encoding='utf-8')
def write(p,s): p.write_text(s,encoding='utf-8',newline='\n')
def q(s):
    eq='===='
    while ']'+eq+']' in s: eq+='='
    return '['+eq+'[\n'+s+']'+eq+']'
path='ReplicatedStorage.Modules.Game.World.LODClient'
manifest=json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))
if not (HERE/'baseline.json').exists(): write(HERE/'baseline.json',json.dumps(manifest,indent=2))
if not (HERE/'original.lua').exists(): write(HERE/'original.lua',read(ROOT/next(r['file'] for r in manifest if r['roblox_path']==path)))
settings={'UpdateSeconds':0.5,'Near1':200,'Near2':800,'Near3':1300,'FarStart':2450,'FarEnd':5000,'Hysteresis':50,'FoliageMin':1275,'FoliageMax':2000,'DiagnosticsEnabled':False}
def lua(v):
    if isinstance(v,str): return q(v)
    if isinstance(v,bool): return str(v).lower()
    if isinstance(v,(int,float)): return str(v)
    return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
extras=[{'path':'ReplicatedStorage.Modules.Game.World.'+name,'class':'ModuleScript','source':read(HERE/(name+'.lua'))} for name in ['LODPolicy','LODRuntime']]
extras.append({'path':'ReplicatedStorage.NeoTokyoRacers.Config.Runtime.WorldLOD','class':'Configuration','attributes':settings})
installer=read(HERE/'installer_template.lua').replace('--[[ORIGINAL]]',q(read(HERE/'original.lua'))).replace('--[[TARGET]]',q(read(HERE/'LODClient.lua'))).replace('--[[EXTRAS]]',','.join(lua(e) for e in extras))
write(ROOT/'scripts/roblox_architecture_phase5_world_optimisation.lua',installer)
prelude='local Policy=(function()\n'+read(HERE/'LODPolicy.lua')+'\nend)()\nlocal Scope=(function()\n'+read(ROOT/'scripts/architecture_phase4/ConnectionScope.lua')+'\nend)()\nlocal Runtime=(function()\n'+read(HERE/'LODRuntime.lua').replace('local Policy=require(script.Parent.LODPolicy)','').replace('local Scope=require(game:GetService("ReplicatedStorage").Modules.Core.ConnectionScope)','')+'\nend)()\n'
if (HERE/'tests.lua').exists(): write(ROOT/'scripts/roblox_architecture_phase5_safety_tests.lua',prelude+read(HERE/'tests.lua'))
# Isolate the confirmed legacy algorithm against disposable, unparented city clones.
old=read(HERE/'original.lua'); body=old[old.index('print("LOD Script Running")'):old.index('\nregisterBlocks()')]
body=body.replace('local ROOT = resolveCityRoot()','local ROOT = options.root').replace('local FAR_LOD5_SOURCE = resolveFarLod5Root()','local FAR_LOD5_SOURCE = options.far_root')
a=body.index('local ActiveFarLOD5 ='); b=body.index('local Blocks =',a)
body=body[:a]+'local ActiveFarLOD5=options.active\n'+body[b:]
loop=old[old.index('\tfor _, blockData in ipairs(Blocks) do'):old.index('\nend\nend)\n',old.index('\tfor _, blockData in ipairs(Blocks) do'))]
legacy='local function legacy(options)\n'+body+'\nregisterBlocks()\nreturn {step=function(_,playerPos)\n'+loop+'\nend,destroy=function() for _,block in ipairs(Blocks) do if block.FarLOD5Clone then block.FarLOD5Clone:Destroy() end end end}\nend\n'
if (HERE/'benchmark.lua').exists(): write(ROOT/'scripts/roblox_architecture_phase5_benchmark.lua',prelude+legacy+read(HERE/'benchmark.lua'))
print('Packaged Phase 5 installer',len(installer.encode()),'bytes')
