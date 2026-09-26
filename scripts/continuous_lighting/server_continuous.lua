-- Server state stays authoritative; only the client renderer writes the environment.
local requestedMode=config:GetAttribute("CycleMode") or "Stepped"
assert(requestedMode=="Stepped" or requestedMode=="Continuous","Invalid CycleMode")
Lighting:SetAttribute("LightingCycleMode",requestedMode)
if requestedMode=="Continuous" then
    local RunService=game:GetService("RunService")
    local HttpService=game:GetService("HttpService")
    local World=ReplicatedStorage.Modules.Game.World
    local Cycle=require(World.LightingCycle)
    local Definition=require(World.LightingCycleDefinition)
    local looks=config:FindFirstChild("ContinuousLooks")
    assert(looks and looks:IsA("Folder"),"Missing ContinuousLooks config")
    local palette=config:FindFirstChild("ContinuousPresets")
    assert(palette and palette:IsA("Folder"),"Missing ContinuousPresets config")
    local sessionEpoch=workspace:GetServerTimeNow()
    local cycle,settings,configError
    local dirty=true
    local revision=0
    local function put(name,value) if Lighting:GetAttribute(name)~=value then Lighting:SetAttribute(name,value) end end
    local function rebuild()
        local candidate=Definition.read(config)
        local built=Cycle.build(presets,schedule,candidate)
        assert(Cycle.finite(candidate.ManualClockTime) and candidate.ManualClockTime>=0 and candidate.ManualClockTime<24,"ContinuousManualClockTime must be 0..<24")
        local sky=skyPresets:FindFirstChild(candidate.SkyName)
        assert(sky and sky:IsA("Sky"),"ContinuousSkyName must name an existing sky template")
        revision+=1
        candidate.Version=3; candidate.Revision=revision
        candidate.Epoch=candidate.Synchronized and 0 or sessionEpoch
        local encoded=HttpService:JSONEncode(candidate)
        cycle,settings=built,candidate
        put("LightingCycleState",encoded)
    end
    -- Reject a bad edit atomically; keep the last valid configuration until repaired.
    local function update()
        if dirty then
            dirty=false
            local success,problem=xpcall(rebuild,debug.traceback)
            configError=not success and tostring(problem) or nil
            put("LightingCycleError",configError)
            if configError then warn("[LightingServer] Rejected lighting config: "..configError) end
        end
        assert(settings,"No valid lighting configuration")
        local now=workspace:GetServerTimeNow()
        local seconds=settings.Auto and (now-settings.Epoch) or settings.ManualClockTime/24*cycle.total
        local _,info=Cycle.sample(cycle,seconds)
        local night=Cycle.isNight(info.clock,settings.Sunrise,settings.Sunset)
        put("LightingPreset",info.preset); put("LightingStageIndex",info.index)
        -- Compatibility metadata: next visual milestone, not a separate timer.
        put("LightingStageEndsAtUnix",settings.Auto and math.floor(now+info.endsIn+.5) or 0)
        put("StreetLightsOn",night); put("WindowMode",night and "Night" or "Day")
        put("StreetLightBrightness",math.max(0,tonumber(config:GetAttribute("DefaultStreetLightBrightness")) or 2))
    end
    local connections={}
    local watched={}
    local function changed() dirty=true end
    local function watch(folder)
        if watched[folder] then return end
        watched[folder]={folder.AttributeChanged:Connect(changed),folder:GetPropertyChangedSignal("Name"):Connect(changed)}
        dirty=true
    end
    local function unwatch(folder)
        if watched[folder] then for _,c in ipairs(watched[folder]) do c:Disconnect() end; watched[folder]=nil end
        dirty=true
    end
    for _,root in ipairs({looks,palette}) do
        for _,folder in ipairs(root:GetDescendants()) do watch(folder) end
        connections[#connections+1]=root.DescendantAdded:Connect(watch)
        connections[#connections+1]=root.DescendantRemoving:Connect(unwatch)
    end
    connections[#connections+1]=config.AttributeChanged:Connect(function(name) if name~="CycleMode" then changed() end end)
    update()
    local elapsed=0
    local lastError
    connections[#connections+1]=RunService.Heartbeat:Connect(function(dt)
        elapsed+=dt; if elapsed<.25 then return end; elapsed=0
        local success,problem=xpcall(update,debug.traceback)
        if not success then
            put("LightingCycleError",tostring(problem))
            if problem~=lastError then warn("[LightingServer] "..tostring(problem)); lastError=problem end
        elseif not configError then lastError=nil; put("LightingCycleError",nil) end
    end)
    script.Destroying:Once(function()
        for _,connection in ipairs(connections) do connection:Disconnect() end
        for folder in pairs(watched) do unwatch(folder) end
        table.clear(connections)
    end)
    return
end
Lighting.GeographicLatitude=config:GetAttribute("SteppedGeographicLatitude") or Lighting.GeographicLatitude

