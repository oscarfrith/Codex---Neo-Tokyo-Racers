-- Bounded read-only observer in normally started Client; pure Cycle/data chunks are prepended.
local p=game.Players.LocalPlayer
assert(p:GetAttribute("StudioVehicleSandboxActive") and p:GetAttribute("StartScreenActive")==false)
local L=game.Lighting;local runtime=p.PlayerScripts.Runtime.World
local settings=game.HttpService:JSONDecode(L:GetAttribute("LightingCycleState"))
local cycle=Cycle.build(presets,schedule,settings)
local result={done=false,samples=0,maxError={},maxSteps={},contexts={},clockJumps=0,wraps=0,errors={},switches={}}
_G.LightingContinuityObservation=result
task.spawn(function()
 local start=os.clock();local previous;local previousTime;local previousNight
 repeat
  game.RunService.Heartbeat:Wait()
  local now=os.clock();local clock=L.ClockTime
  local target=Cycle.sample(cycle,clock/24*cycle.total)
  local current={clock=clock}
  for section,values in pairs(target) do if type(values)=="table" then
   local instance=section=="Lighting" and L or L:FindFirstChild(section)
   for key,wanted in pairs(values) do
    if key~="ClockTime" and (typeof(wanted)=="Color3" or type(wanted)=="number") then
     local actual=instance[key];local id=section.."."..key
     local err=typeof(wanted)=="Color3" and math.max(math.abs(wanted.R-actual.R),math.abs(wanted.G-actual.G),math.abs(wanted.B-actual.B)) or math.abs(wanted-actual)
     result.maxError[id]=math.max(result.maxError[id] or 0,err)
     current[id]=actual
     if previous then
      local old=previous[id]
      local step=typeof(actual)=="Color3" and math.max(math.abs(actual.R-old.R),math.abs(actual.G-old.G),math.abs(actual.B-old.B)) or math.abs(actual-old)
      if not result.maxSteps[id] or step>result.maxSteps[id].delta then result.maxSteps[id]={delta=step,clock=clock,dt=now-previousTime} end
     end
    end
   end
  end end
  if previous then
   local dc=(clock-previous.clock)%24
   if clock<previous.clock-12 then result.wraps+=1 end
   if dc>(now-previousTime)*24/cycle.total+.02 then result.clockJumps+=1 end
  end
  local night=L:GetAttribute("StreetLightsOn")
  if previousNight~=nil and night~=previousNight then table.insert(result.switches,{clock=clock,night=night}) end
  result.contexts[runtime:GetAttribute("LightingContext") or "nil"]=true
  for _,err in ipairs({L:GetAttribute("LightingCycleError") or "",runtime:GetAttribute("LightingRenderError") or ""}) do if err~="" then result.errors[err]=true end end
  previous=current;previousTime=now;previousNight=night;result.samples+=1
 until now-start>=122
 result.elapsed=os.clock()-start; result.done=true
end)
return "Continuity observation started: actual renderer values versus pure targets over 122 seconds."
