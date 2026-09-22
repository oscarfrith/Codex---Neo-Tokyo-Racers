-- Canonical feature implementation; startup is owned by the composition root.
local Client={}
local state
function Client.start()
if state then assert(state=="ready","Client startup already attempted: "..tostring(state)); return end
state="starting"
local ok,message=xpcall(function()
-- Headless race-entry state/action bridge. This script intentionally constructs no UI.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local player=Players.LocalPlayer
local kit=game:GetService("ReplicatedStorage")
local shared=game:GetService("ReplicatedStorage")
local remotes=game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local racingRemotes=game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceRequest=game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Racing"):WaitForChild("RaceRequest")
local raceEvent=game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Racing"):WaitForChild("RaceEvent")
local garageInvoke=game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Garage"):WaitForChild("GarageInvoke")
local presentationRequest=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("Racing"):WaitForChild("RaceEntryPresentationRequest")
local presentationAction=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("Racing"):WaitForChild("RaceEntryLegacyAction")
local startRaceQueueEvent=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("Racing"):WaitForChild("StartRaceQueueRequest")
local transitionRequest=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("Racing"):WaitForChild("RaceTransitionRequest") 
local entry=nil
local function transition(step,payload) payload=payload or {}; payload.Step=step; transitionRequest:Fire(payload) end

local function call(remote, action, payload)
	local ok,result=pcall(function() return remote:InvokeServer(action,payload or {}) end)
	if not ok then return {Success=false,Ok=false,Message=tostring(result)} end
	return type(result)=="table" and result or {Success=result==true,Ok=result==true}
end
local function uiEvent(name)
	local folder=game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):FindFirstChild("UI")
	local event=folder and folder:FindFirstChild(name)
	if event and event:IsA("BindableEvent") then event:Fire() end
end
local function cockpitFor(vehicleId, supplied)
	if tostring(supplied or "")~="" then return tostring(supplied) end
	local result=call(garageInvoke,"GetInitial",{})
	local profile=result.Profile or result.Data or result
	local vehicle=profile and profile.Vehicles and (profile.Vehicles[vehicleId] or profile.Vehicles[tostring(vehicleId)])
	if not vehicle then return "" end
	if tostring(vehicle.CockpitId or "")~="" then return tostring(vehicle.CockpitId) end
	local owned=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
	return tostring(owned and owned.TemplateId or "")
end
local function spawnVehicle(data)
	local vehicleId=tostring(data.VehicleId or "")
	if vehicleId=="" then return false,"No vehicle selected." end
	local cockpitId=cockpitFor(vehicleId,data.CockpitId)
	local result=call(garageInvoke,"SpawnOwnedVehicleFromFreeRoam",{VehicleId=vehicleId,CockpitId=cockpitId})
	if result.Success~=true and result.Ok~=true then
		local selected=call(garageInvoke,"SelectVehicleInstance",{VehicleId=vehicleId,CockpitId=cockpitId})
		if selected.Success~=true and selected.Ok~=true then return false,tostring(selected.Message or result.Message or "Vehicle selection failed.") end
		result=call(garageInvoke,"SpawnVehicle",{})
		if result.Success~=true and result.Ok~=true then return false,tostring(result.Message or "Vehicle spawn failed.") end
	end
	uiEvent("FreeRoamVehicleSpawned")
	return true,cockpitId
end

presentationAction.Event:Connect(function(action,data)
	data=type(data)=="table" and data or {}
	if action~="StartSelectedVehicle" then return end
	local mode=tostring(data.Mode)=="Race" and "Race" or "TimeTrial"
	if mode=="TimeTrial" then transition("BeginLoading",{Destination="TimeTrialSession",Status="STAGING TIME TRIAL"}) end
	local ok,cockpitOrMessage=spawnVehicle(data)
	if not ok then
		if mode=="TimeTrial" then transition("FailLoading",{Status="RETURNING",Reason=cockpitOrMessage}) end
		warn("[RaceEntryMenuClient] "..cockpitOrMessage)
		return
	end
	task.wait(0.35)
	local eventId=tostring(data.EventId or (entry and entry.EventId) or "")
	if mode=="Race" then
		startRaceQueueEvent:Fire({EventId=eventId,VehicleId=tostring(data.VehicleId),CockpitId=cockpitOrMessage,DisplayName=entry and entry.Summary and entry.Summary.DisplayName})
	else
		local result=call(raceRequest,"StartStagedTimeTrial",{EventId=eventId,VehicleId=tostring(data.VehicleId),LapCount=tonumber(data.LapCount) or 1})
		if result.Success~=true and result.Ok~=true then
			transition("FailLoading",{Status="RETURNING",Reason=result.Message})
			warn("[RaceEntryMenuClient] "..tostring(result.Message or "Time trial start failed."))
		end
	end
end)

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload)~="table" then return end
	local kind=tostring(payload.Type or "")
	if kind=="OpenRaceEntry" then
		entry={EventId=payload.EventId,RaceEventId=payload.RaceEventId,TimeTrialEventId=payload.TimeTrialEventId,Summary=payload.Summary}
		presentationRequest:Fire(payload)
	elseif kind=="TimeTrialStarted" then
		local route=game:GetService("Workspace"):FindFirstChild("World")
		route=route and route:FindFirstChild("RaceRoutes")
		route=route and route:FindFirstChild(tostring(payload.RouteId or ""))
		local gate=route and route:FindFirstChild("Checkpoint1",true)
		if gate and gate:IsA("BasePart") then pcall(function() player:RequestStreamAroundAsync(gate.Position,3) end) end
		task.defer(function() uiEvent("FreeRoamVehicleSpawned") end)
	elseif kind=="TimeTrialFinished" or kind=="TimeTrialEnded" or kind=="TimeTrialError" or kind=="RaceExitedToStart" then
		uiEvent("FreeRoamVehicleExited")
	end
end)
print("[RaceEntryMenuClient] Headless race-entry bridge active.")

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Client
