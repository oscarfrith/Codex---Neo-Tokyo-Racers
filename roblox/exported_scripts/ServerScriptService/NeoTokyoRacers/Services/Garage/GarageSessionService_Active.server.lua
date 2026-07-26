-- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
-- NTR_GARAGE_CANONICAL_EXPERIENCE_V1
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local remotes = kit:WaitForChild("Shared"):WaitForChild("Remotes")
local uiRemotes = remotes:FindFirstChild("UI") or Instance.new("Folder")
uiRemotes.Name = "UI"; uiRemotes.Parent = remotes
local request = uiRemotes:FindFirstChild("GarageSessionRequest") or Instance.new("RemoteFunction")
request.Name = "GarageSessionRequest"; request.Parent = uiRemotes
local legacy = uiRemotes:FindFirstChild("DriveInCustomisationSession") or Instance.new("RemoteEvent")
legacy.Name = "DriveInCustomisationSession"; legacy.Parent = uiRemotes

local sessions = {}
local function customisationAccess(player)
	local binding = script.Parent:FindFirstChild("GarageCustomisationAccessBinding") or script.Parent:WaitForChild("GarageCustomisationAccessBinding", 10)
	if not binding or not binding:IsA("BindableFunction") then return { Success=false, Message="Customisation access is unavailable." } end
	local ok, result = pcall(function() return binding:Invoke(player) end)
	if not ok or typeof(result)~="table" then return { Success=false, Message="Customisation access is unavailable." } end
	return result
end
local function worldParts()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local dealership = world and world:FindFirstChild("Dealership")
	local intro = dealership and dealership:FindFirstChild("Intro")
	local desk = intro and intro:FindFirstChild("Desk")
	local custom = dealership and dealership:FindFirstChild("Customisation")
	return {
		Dealership = desk and desk:FindFirstChild("GarageDeskTrigger"),
		Customisation = custom and custom:FindFirstChild("CustomisationDeskTrigger"),
		DriveIn = custom and custom:FindFirstChild("DriveInCustomisationTrigger"),
		Hold = custom and custom:FindFirstChild("DriveInCustomisationPlayerHoldPoint"),
	}
end
local function character(player)
	local model = player.Character
	return model, model and model:FindFirstChildOfClass("Humanoid"), model and model:FindFirstChild("HumanoidRootPart")
end
local function saveVisuals(model)
	local values = {}
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			values[object] = { object.Transparency, object.CanCollide, object.CanTouch, object.CanQuery }
			object.Transparency = 1; object.CanCollide = false; object.CanTouch = false; object.CanQuery = false
		elseif object:IsA("Decal") or object:IsA("Texture") then
			values[object] = { object.Transparency }; object.Transparency = 1
		elseif object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then
			values[object] = { object.Enabled }; object.Enabled = false
		end
	end
	return values
end
local function restoreVisuals(values)
	for object, value in pairs(values or {}) do
		if object.Parent then
			if object:IsA("BasePart") then object.Transparency=value[1]; object.CanCollide=value[2]; object.CanTouch=value[3]; object.CanQuery=value[4]
			elseif object:IsA("Decal") or object:IsA("Texture") then object.Transparency=value[1]
			elseif object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then object.Enabled=value[1] end
		end
	end
end
local function finish(player, returnToEntry)
	local state = sessions[player]
	local _, humanoid, root = character(player)
	if state then
		restoreVisuals(state.Visuals)
		if humanoid then humanoid.WalkSpeed=state.WalkSpeed; humanoid.JumpPower=state.JumpPower; humanoid.JumpHeight=state.JumpHeight; humanoid.AutoRotate=state.AutoRotate end
		if root then root.Anchored=state.RootAnchored; if returnToEntry and state.ReturnCFrame then root.CFrame=state.ReturnCFrame end end
	end
	sessions[player] = nil
	player:SetAttribute("NTR_GarageSessionActive", false)
	player:SetAttribute("NTR_GarageSessionMode", nil)
	player:SetAttribute("NTR_DriveInCustomisationActive", false)
	return { Success=true }
end
local function begin(player, mode)
	if mode~="Dealership" and mode~="Customisation" and mode~="DriveIn" then return { Success=false, Message="Unknown garage session mode." } end
	if sessions[player] then return { Success=false, Message="A garage session is already active." } end
	if player:GetAttribute("NTR_RaceQueueActive") == true or player:GetAttribute("NTR_RaceSessionActive") == true then return { Success=false, Message="Leave the race session first." } end
	if mode=="Customisation" or mode=="DriveIn" then
		local access=customisationAccess(player)
		if access.Success~=true then return { Success=false, Message=tostring(access.Message or "Customisation access is unavailable.") } end
	end
	local model, humanoid, root = character(player)
	if not model or not humanoid or not root then return { Success=false, Message="Character is not ready." } end
	local parts = worldParts(); local trigger = parts[mode]
	if not trigger or not trigger:IsA("BasePart") then return { Success=false, Message="Garage entrance is unavailable." } end
	local distancePoint = root.Position
	if mode == "DriveIn" and humanoid.SeatPart then distancePoint = humanoid.SeatPart.Position end
	if (distancePoint-trigger.Position).Magnitude > math.max(20, trigger.Size.Magnitude*0.7) then return { Success=false, Message="Move closer to the entrance." } end
	if mode == "DriveIn" and not humanoid.SeatPart then return { Success=false, Message="Drive your vehicle into the bay first." } end
	sessions[player] = { ReturnCFrame=root.CFrame, WalkSpeed=humanoid.WalkSpeed, JumpPower=humanoid.JumpPower, JumpHeight=humanoid.JumpHeight, AutoRotate=humanoid.AutoRotate, RootAnchored=root.Anchored }
	humanoid.Sit=false; humanoid.WalkSpeed=0; humanoid.JumpPower=0; humanoid.JumpHeight=0; humanoid.AutoRotate=false
	if parts.Hold and parts.Hold:IsA("BasePart") then root.CFrame=parts.Hold.CFrame+Vector3.new(0,3,0) end
	root.Anchored=true; sessions[player].Visuals=saveVisuals(model)
	player:SetAttribute("NTR_GarageSessionActive", true); player:SetAttribute("NTR_GarageSessionMode", mode)
	player:SetAttribute("NTR_DriveInCustomisationActive", mode == "DriveIn")
	return { Success=true, Mode=mode }
end
request.OnServerInvoke = function(player, action, payload)
	payload = typeof(payload)=="table" and payload or {}
	if action=="Begin" then return begin(player, tostring(payload.Mode or "Dealership")) end
	if action=="End" then return finish(player, payload.ReturnToEntry==true) end
	if action=="State" then return { Success=true, Active=sessions[player]~=nil, Mode=player:GetAttribute("NTR_GarageSessionMode") } end
	return { Success=false, Message="Unknown garage session action." }
end
legacy.OnServerEvent:Connect(function(player, locked) if locked~=true then finish(player, false) end end)
Players.PlayerRemoving:Connect(function(player) sessions[player]=nil end)
Players.PlayerAdded:Connect(function(player) player.CharacterAdded:Connect(function() if sessions[player] then task.defer(function() finish(player, false) end) end end) end)
