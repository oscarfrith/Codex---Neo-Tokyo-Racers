"""Build exact projected sources from the verified before capture. No live text patches."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import studio_capture as capture

ROOT=capture.ROOT
DEST=Path(__file__).resolve().parent
baseline=capture.load(ROOT/'roblox/captures/continuous-lighting-before/capture.json')
rows={r['roblox_path']:r for r in baseline['manifest']}
def read(path): return (ROOT/rows[path]['file']).read_text(encoding='utf8')
def replace(text,old,new):
    assert text.count(old)==1, 'Expected unique captured source anchor: '+old[:100]
    return text.replace(old,new)
def write(name,text): (DEST/name).write_text(text,encoding='utf8',newline='\n')

server=read('ServerStorage.Modules.Game.World.LightingServer')
branch=(DEST/'server_continuous.lua').read_text(encoding='utf8')+'\n'
server=replace(server,'local function getOrCreateEffect(className, name)',branch+'local function getOrCreateEffect(className, name)')
write('LightingServer.lua',server)

owned=read('ReplicatedStorage.Modules.Game.World.OwnedGarageEnvironmentLightingClient')
ownedBranch='''local renderer=require(ReplicatedStorage.Modules.Game.World.LightingClient)
if renderer.isContinuous() then
    local function updateContext()
        local active=player:GetAttribute("OwnedGarageInside")==true and settings:GetAttribute("InteriorEnvironmentLightingEnabled")~=false
        if active then renderer.setContext("OwnedInterior",settings:GetAttribute("InteriorEnvironmentPreset") or "ClearNight")
        else renderer.releaseContext("OwnedInterior") end
    end
    local connections={
        player:GetAttributeChangedSignal("OwnedGarageInside"):Connect(updateContext),
        settings:GetAttributeChangedSignal("InteriorEnvironmentLightingEnabled"):Connect(updateContext),
        settings:GetAttributeChangedSignal("InteriorEnvironmentPreset"):Connect(updateContext),
    }
    script.Destroying:Once(function()
        for _,connection in ipairs(connections) do connection:Disconnect() end
        renderer.releaseContext("OwnedInterior")
    end)
    updateContext()
    player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("World"):SetAttribute("OwnedGarageEnvironmentStarted",true)
    return
end

'''
owned=replace(owned,'local EFFECT_SPECS={',ownedBranch+'local EFFECT_SPECS={')
write('OwnedGarageEnvironmentLightingClient.lua',owned)

preview=read('ReplicatedStorage.Modules.Game.Garage.GaragePreviewPresentationClient')
preview=replace(preview,'local EFFECTS={','local renderer=require(ReplicatedStorage.Modules.Game.World.LightingClient)\n\nlocal EFFECTS={')
preview=replace(preview,'local function applyPreset(name)\n','local function applyPreset(name)\n\tif renderer.isContinuous() then return renderer.setContext("Dealership",name) end\n')
preview=replace(preview,'\tlightingSnapshot=captureLighting(presetName)','\tif renderer.isContinuous() then\n\t\tlightingOwned=renderer.setContext("Dealership",presetName); lastGaragePreset=presetName; return\n\tend\n\tlightingSnapshot=captureLighting(presetName)')
preview=replace(preview,'\tlightingOwned=false\n\tlocal authoritative=', '\tlightingOwned=false\n\tif renderer.isContinuous() then renderer.releaseContext("Dealership"); lastGaragePreset=nil; return end\n\tlocal authoritative=')
preview=replace(preview,'Lighting:GetAttributeChangedSignal("LightingPreset"):Connect(function()', '''player:GetAttributeChangedSignal("GarageSessionActive"):Connect(function() setActive(garageOpen()) end)
script.Destroying:Once(function() if renderer.isContinuous() then renderer.releaseContext("Dealership") end end)
setActive(garageOpen())

Lighting:GetAttributeChangedSignal("LightingPreset"):Connect(function()''')
write('GaragePreviewPresentationClient.lua',preview)

lamps=read('ReplicatedStorage.Modules.Game.World.NightLamppostLightClient')
lamps=replace(lamps,'local function settings()\n','''local function settings()
    if Lighting:GetAttribute("LightingCycleMode")=="Continuous" then
        return Lighting:GetAttribute("StreetLightsOn")==true, math.max(0,tonumber(Lighting:GetAttribute("StreetLightBrightness")) or 2)
    end
''')
lamps=replace(lamps,'Lighting:GetAttributeChangedSignal("LightingPreset"):Connect(refresh)','''Lighting:GetAttributeChangedSignal("LightingPreset"):Connect(refresh)
Lighting:GetAttributeChangedSignal("StreetLightsOn"):Connect(refresh)
Lighting:GetAttributeChangedSignal("StreetLightBrightness"):Connect(refresh)
Lighting:GetAttributeChangedSignal("LightingCycleMode"):Connect(refresh)''')
write('NightLamppostLightClient.lua',lamps)

windows=read('ReplicatedStorage.Modules.Game.World.WindowMaterialClient')
windows=replace(windows,'local function mode()\n','''local function mode()
    if Lighting:GetAttribute("LightingCycleMode")=="Continuous" then
        return Lighting:GetAttribute("WindowMode")=="Night" and "Night" or "Day"
    end
''')
windows=replace(windows,'Lighting:GetAttributeChangedSignal("LightingPreset"):Connect(refresh)','''Lighting:GetAttributeChangedSignal("LightingPreset"):Connect(refresh)
Lighting:GetAttributeChangedSignal("WindowMode"):Connect(refresh)
Lighting:GetAttributeChangedSignal("LightingCycleMode"):Connect(refresh)''')
write('WindowMaterialClient.lua',windows)

debug=read('ReplicatedStorage.Modules.Game.Development.LightingPreviewClient')
debugBranch=(DEST/'preview_continuous.lua').read_text(encoding='utf8')+'\n'
debug=replace(debug,'local effects = {}',debugBranch+'\nlocal effects = {}')
write('LightingPreviewClient.lua',debug)

client=read('StarterPlayer.StarterPlayerScripts.ClientBase')
client=replace(client,'local entries={{name="DriveSessionClient"','local entries={{name="LightingClient",path="ReplicatedStorage.Modules.Game.World.LightingClient",dependencies={}},{name="DriveSessionClient"')
for name in ['GaragePreviewPresentationClient','OwnedGarageEnvironmentLightingClient','LightingPreviewClient']:
    import re
    pattern=r'(name=\[====\[\s*'+name+r'\]====\],path=\[====\[.*?\]====\],dependencies=)\{\}'
    client,count=re.subn(pattern,r'\1{"LightingClient"}',client,count=1,flags=re.S)
    assert count==1,name
write('ClientBase.lua',client)
print('Prepared seven changed sources; three added modules are authored separately.')
