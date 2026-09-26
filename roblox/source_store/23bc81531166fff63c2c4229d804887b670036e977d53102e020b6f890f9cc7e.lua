-- Sole environment property writer in Continuous mode. Context decisions stay with their owners.
local Client={}
local started=false
local continuous=false
local contexts={}
local refresh=function() end
local validPreset=function() return false end
local PRIORITIES={OwnedInterior=10,Dealership=20}
function Client.isContinuous() return continuous end
function Client.setContext(owner,preset)
    assert(PRIORITIES[owner],"Unknown lighting context")
    if not continuous then return false end
    if not validPreset(preset) then warn("[LightingClient] Rejected context preset: "..tostring(preset)); return false end
    if contexts[owner]~=preset then contexts[owner]=preset; refresh() end
    return true
end
function Client.releaseContext(owner)
    if contexts[owner] then contexts[owner]=nil; refresh() end
end
function Client.start()
    if started then return end
    started=true
    local RS=game:GetService("ReplicatedStorage")
    local Lighting=game:GetService("Lighting")
    local RunService=game:GetService("RunService")
    local HttpService=game:GetService("HttpService")
    local player=game:GetService("Players").LocalPlayer
    local world=RS:WaitForChild("Modules").Game.World
    local config=RS:WaitForChild("Config").World.Lighting
    local tools=RS.Config.Development.ClientTools
    local deadline=os.clock()+15
    while Lighting:GetAttribute("LightingCycleMode")==nil and os.clock()<deadline do task.wait(.05) end
    local mode=Lighting:GetAttribute("LightingCycleMode")
    assert(mode=="Stepped" or mode=="Continuous","LightingServer did not publish a valid mode before startup timeout")
    continuous=mode=="Continuous"
    if not continuous then return end
    local Cycle=require(world.LightingCycle)
    local presets=require(world.LightingPresets)
    local schedule=require(world.LightingSchedule)
    local skies=RS.Assets.World.Skies
    local runtime=player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("World")
    local effects={}
    local specs={Atmosphere="Atmosphere",Bloom="BloomEffect",ColorCorrection="ColorCorrectionEffect",DepthOfField="DepthOfFieldEffect",SunRays="SunRaysEffect"}
    for name,class in pairs(specs) do
        local effect=Lighting:FindFirstChild(name)
        assert(not effect or effect.ClassName==class,"Unexpected lighting effect class: "..name)
        if not effect then effect=Instance.new(class); effect.Name=name; effect.Parent=Lighting end
        effects[name]=effect
    end
    local activeSky=Lighting:FindFirstChild("ActiveSky")
    if activeSky then assert(activeSky:IsA("Sky"),"Invalid ActiveSky") end
    if not activeSky then activeSky=Instance.new("Sky"); activeSky.Name="ActiveSky"; activeSky.Parent=Lighting end
    local skyKeys={"SkyboxBk","SkyboxDn","SkyboxFt","SkyboxLf","SkyboxRt","SkyboxUp","SkyboxOrientation","SunTextureId","MoonTextureId","SunAngularSize","MoonAngularSize","StarCount","CelestialBodiesShown"}
    local skyName
    local function properties(instance,values)
        for k,v in pairs(values) do if instance[k]~=v then instance[k]=v end end
    end
    local function apply(target)
        properties(Lighting,target.Lighting)
        for name,effect in pairs(effects) do properties(effect,target[name]) end
        if skyName~=target.SkyName then
            local template=skies:FindFirstChild(target.SkyName)
            assert(template and template:IsA("Sky"),"Missing sky: "..tostring(target.SkyName))
            for _,key in ipairs(skyKeys) do if activeSky[key]~=template[key] then activeSky[key]=template[key] end end
            skyName=target.SkyName
        end
    end
    local state,cycle
    local legacyLatitude=config:GetAttribute("SteppedGeographicLatitude") or 189
    local classic={}
    for name in pairs(presets) do classic[name]=Cycle.preset(presets,name,legacyLatitude) end
    validPreset=function(name) return classic[name]~=nil end
    local connections={}
    local alive=true
    local function mark(name,value) if runtime:GetAttribute(name)~=value then runtime:SetAttribute(name,value) end end
    local function readState()
        local raw=Lighting:GetAttribute("LightingCycleState")
        if type(raw)~="string" then return end
        local incoming=HttpService:JSONDecode(raw)
        assert(incoming.Version==2 and Cycle.finite(incoming.Epoch),"Invalid lighting state")
        local built=Cycle.build(presets,schedule,incoming)
        assert(Cycle.finite(incoming.Sunrise) and Cycle.finite(incoming.Sunset) and incoming.Sunrise>=0 and incoming.Sunrise<incoming.Sunset and incoming.Sunset<24,"Invalid sunrise/sunset")
        assert(type(incoming.Auto)=="boolean" and Cycle.finite(incoming.ManualClockTime) and incoming.ManualClockTime>=0 and incoming.ManualClockTime<24,"Invalid manual state")
        state,cycle=incoming,built
        skyName=nil
    end
    local lastFailure
    local function guarded(fn)
        local ok,err=xpcall(fn,debug.traceback)
        if not ok then
            mark("LightingRenderError",tostring(err))
            if lastFailure~=tostring(err) then warn("[LightingClient] "..tostring(err)); lastFailure=tostring(err) end
        else lastFailure=nil; mark("LightingRenderError",nil) end
    end
    local wasPreview=false
    local function render()
        if not alive or not state then return end
        local seconds=state.Auto and (workspace:GetServerTimeNow()-state.Epoch) or state.ManualClockTime/24*cycle.total
        local preview=RunService:IsStudio() and tools:GetAttribute("LightingPreviewEnabled")==true and runtime:GetAttribute("LightingPreviewClockTime")
        local target,info=Cycle.sample(cycle,Cycle.finite(preview) and preview/24*cycle.total or seconds)
        local owner="City"
        if Cycle.finite(preview) then owner="StudioPreview"
        else
            local priority=0
            for name,preset in pairs(contexts) do
                if PRIORITIES[name]>priority then
                    assert(classic[preset],"Unknown context preset: "..tostring(preset))
                    target=classic[preset]; owner=name; priority=PRIORITIES[name]
                end
            end
        end
        apply(target)
        -- Debug scrubbing only; normal city switch signals remain server-owned.
        if owner=="StudioPreview" or wasPreview then
            local night=Cycle.isNight(info.clock,state.Sunrise,state.Sunset)
            Lighting:SetAttribute("StreetLightsOn",night); Lighting:SetAttribute("WindowMode",night and "Night" or "Day")
        end
        wasPreview=owner=="StudioPreview"
        mark("LightingContext",owner)
        mark("LightingCycleReady",true)
    end
    refresh=function() guarded(render) end
    guarded(readState)
    connections[#connections+1]=Lighting:GetAttributeChangedSignal("LightingCycleState"):Connect(function() guarded(readState); refresh() end)
    -- Resolve existing interior/preview intent before the first city application.
    local interior=RS.Config.Garage.Interior
    if player:GetAttribute("OwnedGarageInside")==true and interior:GetAttribute("InteriorEnvironmentLightingEnabled")~=false then
        contexts.OwnedInterior=interior:GetAttribute("InteriorEnvironmentPreset") or "ClearNight"
    end
    if player:GetAttribute("GarageSessionActive")==true and RS.Config.UI.GarageReplacement:GetAttribute("PreviewLightingEnabled")~=false then
        contexts.Dealership=RS.Config.UI.GarageReplacement:GetAttribute("PreviewLightingPreset") or "EightPM"
    end
    refresh()
    local elapsed=0
    connections[#connections+1]=RunService.Heartbeat:Connect(function(dt)
        elapsed+=dt
        if elapsed>=1/30 then elapsed=0; refresh() end
    end)
    connections[#connections+1]=script.Destroying:Connect(function()
        alive=false
        for _,connection in ipairs(connections) do connection:Disconnect() end
        table.clear(connections); table.clear(contexts); refresh=function() end
    end)
end
return Client
