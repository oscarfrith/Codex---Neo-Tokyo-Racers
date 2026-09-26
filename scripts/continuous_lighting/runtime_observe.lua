-- Read-only bounded observer, run in the normally started Client sandbox.
local p=game.Players.LocalPlayer
assert(p:GetAttribute("StudioVehicleSandboxActive")==true and p:GetAttribute("StartScreenActive")==false)
local L=game.Lighting
local runtime=p.PlayerScripts.Runtime.World
assert(runtime:GetAttribute("LightingContext")=="City")
assert(not _G.LightingV3Observation or _G.LightingV3Observation.done,"Observation already running")
local result={samples=0,wraps=0,switches={},errors={},presets={},maxPhaseError=0,maxRays=0,nightRays=0,childCounts={},done=false}
_G.LightingV3Observation=result
task.spawn(function()
    local start=os.clock(); local previousClock,previousNight
    local sky=L.ActiveSky
    repeat
        local state=game.HttpService:JSONDecode(L:GetAttribute("LightingCycleState"))
        local clock=L.ClockTime
        local expected=((workspace:GetServerTimeNow()-state.Epoch)%state.DurationSeconds)/state.DurationSeconds*24
        result.maxPhaseError=math.max(result.maxPhaseError,math.abs((clock-expected+12)%24-12))
        if previousClock and clock<previousClock-12 then result.wraps+=1 end
        local night=L:GetAttribute("StreetLightsOn")
        if previousNight~=nil and night~=previousNight then table.insert(result.switches,{clock=clock,night=night,window=L:GetAttribute("WindowMode")}) end
        previousClock,previousNight=clock,night
        result.samples+=1
        result.presets[L:GetAttribute("LightingPreset")]=true
        result.maxRays=math.max(result.maxRays,L.SunRays.Intensity)
        if (clock<6 or clock>=18) and L.SunRays.Intensity>1e-7 then result.nightRays+=1 end
        result.childCounts[tostring(#L:GetChildren())]=true
        for _,err in ipairs({L:GetAttribute("LightingCycleError") or "",runtime:GetAttribute("LightingRenderError") or ""}) do if err~="" then result.errors[err]=true end end
        if L.ActiveSky~=sky then result.errors["ActiveSky replaced"]=true end
        if runtime:GetAttribute("LightingContext")~="City" then result.errors["Unexpected context"]=true end
        task.wait(.1)
    until os.clock()-start>=122
    result.elapsed=os.clock()-start; result.done=true
end)
return "122-second observation started; poll _G.LightingV3Observation after completion."
