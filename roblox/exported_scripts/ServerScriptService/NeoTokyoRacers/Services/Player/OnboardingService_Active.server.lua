-- NTR_PLAYER_ONBOARDING_V1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local ServerScriptService=game:GetService("ServerScriptService")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("Onboarding_EditAttributes")
local shared=kit:WaitForChild("Shared")
local remotes=shared:WaitForChild("Remotes"):WaitForChild("Onboarding")
local invoke=remotes:WaitForChild("OnboardingInvoke")
local changedEvent=remotes:WaitForChild("OnboardingStateChanged")
local services=ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
local playerServices=services:WaitForChild("Player")
local bindings=playerServices:WaitForChild("ProfileServiceBindings")
local execute=bindings:WaitForChild("ExecuteOnboardingCommand")
local progress=playerServices:WaitForChild("OnboardingProgress")
local replayStates={}
local allowedPages={Dealership=true,CustomisationHome=true,AddModules=true,UpgradeModules=true,PaintShop=true,PCDriving=true,MobileDriving=true,VehicleShortcut=true,RaceShortcut=true,RaceBrowser=true,EventMode=true,TimeTrialSetup=true,RaceSetup=true,GarageShortcut=true,GarageBrowser=true,GarageHome=true,DisplayCars=true,GarageAssetFamilies=true,BuildStructure=true,BuildDecorations=true}
local allowedProgress={FirstVehiclePurchased=true,FirstVehicleDriven=true,FirstEventEntered=true,GarageManagementEntered=true}

local function stageFor(state)
	return (state.Completed.FirstVehiclePurchased~=true or state.Completed.FirstVehicleDriven~=true) and 1 or state.Completed.GarageManagementEntered~=true and 2 or state.Completed.FirstEventEntered~=true and 3 or 4
end

local function replayRun(player,action,data)
	local state=replayStates[player]
	if not state then state={SeenPages={},Completed={}}; replayStates[player]=state end
	local changed=false
	if action=="MarkSeen" then local pageId=tostring(data and data.PageId or ""); if allowedPages[pageId] and state.SeenPages[pageId]~=true then state.SeenPages[pageId]=true; changed=true end
	elseif action=="RecordProgress" then local progressId=tostring(data and data.ProgressId or ""); if allowedProgress[progressId] and state.Completed[progressId]~=true then state.Completed[progressId]=true; changed=true end
	elseif action~="Get" then return {Success=false,Message="Unknown replay action."} end
	return {Success=true,Stage=stageFor(state),SeenPages=state.SeenPages,Completed=state.Completed,Changed=changed,ReplayMode=true}
end

local function run(player,action,data)
	local replay=RunService:IsStudio() and config:GetAttribute("StudioReplayEveryPlay")==true
	local ok,result
	if replay then ok,result=true,replayRun(player,action,data)
	else
		local command={Action=action}
		for key,value in pairs(type(data)=="table" and data or {}) do command[key]=value end
		ok,result=pcall(function() return execute:Invoke(player,command) end)
	end
	if not ok or type(result)~="table" then return {Success=false,Message=tostring(result),ReplayMode=replay} end
	if result.Success then
		player:SetAttribute("NTR_OnboardingStage",result.Stage)
		if RunService:IsStudio() and result.Changed then
			print("[NTR Onboarding Replay] "..player.Name.." action="..tostring(action).." stage="..tostring(result.Stage))
		end
		if result.Changed then changedEvent:FireClient(player,result) end
	end
	return result
end

invoke.OnServerInvoke=function(player,action,data)
	action=tostring(action or "")
	if action=="GetState" then return run(player,"Get") end
	if action=="MarkSeen" then
		local pageId=tostring(type(data)=="table" and data.PageId or "")
		if not allowedPages[pageId] then return {Success=false,Message="Invalid page id."} end
		return run(player,"MarkSeen",{PageId=pageId})
	end
	return {Success=false,Message="Unsupported onboarding request."}
end

progress.Event:Connect(function(player,progressId)
	if player and player.Parent==Players then run(player,"RecordProgress",{ProgressId=progressId}) end
end)

local function checkVehicle(player)
	if player:GetAttribute("NTR_OnboardingStage")==1 then
		local world=workspace:FindFirstChild("NeoTokyoRacersWorld")
		local runtime=world and world:FindFirstChild("Runtime")
		local vehicles=runtime and runtime:FindFirstChild("PlayerVehicles")
		for _,vehicle in ipairs(vehicles and vehicles:GetChildren() or {}) do
			if vehicle:IsA("Model") and tonumber(vehicle:GetAttribute("OwnerUserId"))==player.UserId and tonumber(vehicle:GetAttribute("DriverUserId"))==player.UserId then
				local seat=vehicle:FindFirstChild("DriverSeat",true); local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if seat and seat:IsA("VehicleSeat") and humanoid and seat.Occupant==humanoid then progress:Fire(player,"FirstVehicleDriven"); return end
			end
		end
	end
end

local function initialise(player)
	while player.Parent==Players and player:GetAttribute("NTR_ProfileServiceLoaded")~=true do task.wait(.1) end
	if player.Parent~=Players then return end
	run(player,"Get")
end
Players.PlayerAdded:Connect(function(player) task.spawn(initialise,player) end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(initialise,player) end
Players.PlayerRemoving:Connect(function(player) replayStates[player]=nil end)
task.spawn(function()
	while true do task.wait(.5); for _,player in ipairs(Players:GetPlayers()) do checkVehicle(player) end end
end)
print("[NTR Onboarding] authoritative service active | StudioReplayEveryPlay="..tostring(RunService:IsStudio() and config:GetAttribute("StudioReplayEveryPlay")==true))
