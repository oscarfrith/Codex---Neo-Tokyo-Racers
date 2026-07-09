-- NTR_RACING_PHASE10A_SESSION_ASSET_SERVICE

local PhysicsService = game:GetService("PhysicsService")
local ServerStorage = game:GetService("ServerStorage")

local PHASE = "NTR Racing Phase 10A Assets"
local ASSET_GROUP = "NTR_RaceSessionAsset"
local PARTICIPANT_GROUP = "NTR_RaceParticipant"

local racingRoot = script.Parent
local bindings = racingRoot:FindFirstChild("RaceSessionAssetBindings") or Instance.new("Folder")
bindings.Name = "RaceSessionAssetBindings"
bindings.Parent = racingRoot

local sessionBinding = bindings:FindFirstChild("SessionAssets") or Instance.new("BindableFunction")
sessionBinding.Name = "SessionAssets"
sessionBinding.Parent = bindings

local sessions = {}
local originalGroups = {}
local clearForRun

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function ensureGroup(name)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
	pcall(function()
		PhysicsService:CreateCollisionGroup(name)
	end)
end

local function configureCollisionGroups()
	ensureGroup(ASSET_GROUP)
	ensureGroup(PARTICIPANT_GROUP)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(ASSET_GROUP, "Default", false)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(ASSET_GROUP, PARTICIPANT_GROUP, true)
	end)
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable(PARTICIPANT_GROUP, "Default", true)
	end)
end

local function setPartCollisionGroup(part, groupName)
	if not (part and part:IsA("BasePart")) then return end
	if originalGroups[part] == nil then
		originalGroups[part] = part.CollisionGroup
	end
	pcall(function()
		part.CollisionGroup = groupName
	end)
end

local function restorePartCollisionGroup(part)
	if not (part and part:IsA("BasePart")) then return end
	local original = originalGroups[part]
	if original ~= nil then
		pcall(function()
			part.CollisionGroup = original
		end)
		originalGroups[part] = nil
	end
end

local function setModelGroup(model, groupName)
	for _, item in ipairs(model and model:GetDescendants() or {}) do
		if item:IsA("BasePart") then
			setPartCollisionGroup(item, groupName)
		end
	end
end

local function restoreModelGroup(model)
	for _, item in ipairs(model and model:GetDescendants() or {}) do
		if item:IsA("BasePart") then
			restorePartCollisionGroup(item)
		end
	end
end

local function templatesRoot()
	local root = ServerStorage:FindFirstChild("NeoTokyoRacers")
	local racing = root and root:FindFirstChild("Racing")
	return racing and racing:FindFirstChild("SessionAssetTemplates")
end

local function markerModeAllows(marker, mode)
	local modes = tostring(marker:GetAttribute("Modes") or marker:GetAttribute("Mode") or "TimeTrial,Race")
	if modes == "All" or modes == "" then
		return true
	end
	mode = tostring(mode or "")
	for token in string.gmatch(modes, "[^,%s]+") do
		if token == mode then
			return true
		end
	end
	return false
end

local function prepRuntimePart(part, marker)
	part.Anchored = true
	part.CanCollide = marker:GetAttribute("CanCollide") ~= false
	part.CanTouch = marker:GetAttribute("CanTouch") == true
	part.CanQuery = marker:GetAttribute("CanQuery") ~= false
	part.Transparency = tonumber(marker:GetAttribute("RuntimeTransparency")) or 0.35
	part.Material = Enum.Material.Neon
	part.Color = marker:GetAttribute("RuntimeColor") or Color3.fromRGB(255, 68, 196)
	part:SetAttribute("NTR_SessionAsset", true)
	setPartCollisionGroup(part, ASSET_GROUP)
end

local function prepRuntimeInstance(instance, marker)
	for _, item in ipairs(instance:GetDescendants()) do
		if item:IsA("BasePart") then
			prepRuntimePart(item, marker)
		end
	end
	if instance:IsA("BasePart") then
		prepRuntimePart(instance, marker)
	end
end

local function cloneFromMarker(marker)
	local templateId = tostring(marker:GetAttribute("TemplateId") or marker:GetAttribute("TemplateName") or "")
	local template = templateId ~= "" and templatesRoot() and templatesRoot():FindFirstChild(templateId) or nil
	local clone
	if template then
		clone = template:Clone()
	else
		clone = Instance.new("Part")
		clone.Name = marker.Name .. "_Collider"
		clone.Size = marker.Size
	end
	clone.Name = tostring(marker:GetAttribute("RuntimeName") or clone.Name)
	if clone:IsA("Model") then
		clone:PivotTo(marker.CFrame)
	elseif clone:IsA("BasePart") then
		clone.CFrame = marker.CFrame
		clone.Size = marker.Size
	end
	prepRuntimeInstance(clone, marker)
	clone:SetAttribute("NTR_SessionAsset", true)
	clone:SetAttribute("SourceMarker", marker:GetFullName())
	clone:SetAttribute("TemplateId", templateId)
	return clone
end

local function applyParticipants(runId, participants)
	local state = sessions[runId]
	if not state then return end
	for _, participant in ipairs(participants or {}) do
		local player = participant.Player
		local vehicle = participant.Vehicle
		if player and player.Character then
			setModelGroup(player.Character, PARTICIPANT_GROUP)
			table.insert(state.ParticipantModels, player.Character)
		end
		if vehicle then
			setModelGroup(vehicle, PARTICIPANT_GROUP)
			table.insert(state.ParticipantModels, vehicle)
		end
	end
end

local function createForRun(payload)
	payload = typeof(payload) == "table" and payload or {}
	local runId = tostring(payload.RunId or "")
	local route = payload.Route
	local routeFolder = payload.RouteFolder or (route and route.Folder)
	local sessionFolder = payload.SessionFolder
	local mode = tostring(payload.Mode or "")
	if runId == "" or not (routeFolder and routeFolder.Parent) or not (sessionFolder and sessionFolder.Parent) then
		return { Ok = false, Created = 0, Message = "Missing route/session data." }
	end
	clearForRun({ RunId = runId })
	local assetsFolder = sessionFolder:FindFirstChild("SessionAssets")
	if not assetsFolder then
		assetsFolder = Instance.new("Folder")
		assetsFolder.Name = "SessionAssets"
		assetsFolder.Parent = sessionFolder
	end
	local state = {
		SessionFolder = sessionFolder,
		Assets = {},
		ParticipantModels = {},
	}
	sessions[runId] = state
	local markers = routeFolder:FindFirstChild("SessionAssetMarkers")
	local created = 0
	for _, marker in ipairs(markers and markers:GetChildren() or {}) do
		if marker:IsA("BasePart") and marker:GetAttribute("Enabled") ~= false and markerModeAllows(marker, mode) then
			local clone = cloneFromMarker(marker)
			clone:SetAttribute("RunId", runId)
			clone:SetAttribute("RouteId", tostring(payload.RouteId or routeFolder.Name))
			clone:SetAttribute("Mode", mode)
			clone.Parent = assetsFolder
			table.insert(state.Assets, clone)
			created += 1
		end
	end
	applyParticipants(runId, payload.Participants or {})
	info("Created " .. tostring(created) .. " session assets for " .. runId .. ".")
	return { Ok = true, Created = created }
end

clearForRun = function(payload)
	payload = typeof(payload) == "table" and payload or {}
	local runId = tostring(payload.RunId or "")
	local state = sessions[runId]
	if not state then
		return { Ok = true, Cleared = 0 }
	end
	local cleared = 0
	for _, asset in ipairs(state.Assets or {}) do
		if asset and asset.Parent then
			asset:Destroy()
			cleared += 1
		end
	end
	for _, model in ipairs(state.ParticipantModels or {}) do
		if model and model.Parent then
			restoreModelGroup(model)
		end
	end
	sessions[runId] = nil
	info("Cleared " .. tostring(cleared) .. " session assets for " .. runId .. ".")
	return { Ok = true, Cleared = cleared }
end

sessionBinding.OnInvoke = function(action, payload)
	if action == "CreateForRun" then
		return createForRun(payload)
	elseif action == "ClearForRun" then
		return clearForRun(payload)
	elseif action == "ApplyParticipants" then
		payload = typeof(payload) == "table" and payload or {}
		applyParticipants(tostring(payload.RunId or ""), payload.Participants or {})
		return { Ok = true }
	end
	return { Ok = false, Message = "Unknown session asset action." }
end

configureCollisionGroups()
info("Session asset service active. Assets collide with race participants, not default free-roam parts.")
