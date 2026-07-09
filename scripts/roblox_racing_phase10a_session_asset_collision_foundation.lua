-- NTR Racing Phase 10A - Session Asset Collision Foundation
--
-- Adds the first server-owned race/time-trial session asset layer:
--   * Route authoring folder: RaceRoutes.<RouteId>.SessionAssetMarkers
--   * Server-owned templates: ServerStorage.NeoTokyoRacers.Racing.SessionAssetTemplates
--   * RaceSessionAssetService_Active with fixed collision groups
--   * Session colliders/assets clone only into RaceInstances.<RunId>.SessionAssets
--   * Free-roam authoring markers are hidden and non-collidable
--
-- This script intentionally does not edit reward config, route-guide config,
-- checkpoint visuals, Phase 8H reset behavior, or Phase 9A lap/session scoring.
--
-- Source patch note:
-- This phase uses small guarded source insertions in the isolated
-- TimeTrialService_Active and RaceMatchmakingService_Active so session assets
-- are created and cleaned up with the existing run folders.

local MODE = "INSTALL" -- INSTALL or SMOKE

local function info(message)
	print("[NTR Racing Phase 10A] " .. tostring(message))
end

local function fail(message)
	error("[NTR Racing Phase 10A] " .. tostring(message), 2)
end

local function replaceOnce(source, oldText, newText, label)
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. tostring(label) .. ". Refresh the Studio mirror before another repair.")
	end
	local second = string.find(source, oldText, endIndex + 1, true)
	if second then
		fail("Source anchor matched more than once: " .. tostring(label) .. ". Refusing ambiguous replacement.")
	end
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
end

local function serverRacingFolder()
	local root = game:GetService("ServerScriptService"):FindFirstChild("NeoTokyoRacers")
	local services = root and root:FindFirstChild("Services")
	return services and services:FindFirstChild("Racing")
end

local function clientRacingFolder()
	local starterScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
	local clientRoot = starterScripts and starterScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = clientRoot and clientRoot:FindFirstChild("Controllers")
	return controllers and controllers:FindFirstChild("Racing")
end

local function worldRaceRoutes()
	local world = game:GetService("Workspace"):FindFirstChild("NeoTokyoRacersWorld")
	return world and world:FindFirstChild("RaceRoutes")
end

local SERVICE_SOURCE = [==[
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
]==]

local SESSION_ASSET_CLIENT_SOURCE = [==[
-- NTR_RACING_PHASE10A_SESSION_ASSET_VISIBILITY_CLIENT

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local racingRemotes = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("Racing")
local raceEvent = racingRemotes:WaitForChild("RaceEvent")

local activeParticipants = {}
local active = false

local function setHidden(model, hidden)
	for _, item in ipairs(model and model:GetDescendants() or {}) do
		if item:IsA("BasePart") and item:GetAttribute("NTR_SessionAsset") == true then
			item.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

local function isLocalParticipant()
	return activeParticipants[player.UserId] == true
end

local function apply()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local instances = world and world:FindFirstChild("RaceInstances")
	local hide = not (active and isLocalParticipant())
	for _, runFolder in ipairs(instances and instances:GetChildren() or {}) do
		local assets = runFolder:FindFirstChild("SessionAssets")
		if assets then
			setHidden(assets, hide)
		end
	end
end

raceEvent.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.Type == "RaceVisibilityUpdate" then
		active = payload.Active == true
		table.clear(activeParticipants)
		for _, userId in ipairs(payload.Participants or {}) do
			activeParticipants[tonumber(userId)] = true
		end
		apply()
	elseif payload.Type == "TimeTrialEnded" or payload.Type == "TimeTrialFinished" or payload.Type == "RaceEnded" or payload.Type == "RaceDNF" then
		task.delay(0.1, apply)
	end
end)

task.spawn(function()
	while true do
		apply()
		task.wait(1)
	end
end)

print("[NTR Racing Phase 10A Client] Session asset visibility active.")
]==]

local SERVICE_CALL_HELPER = [==[local function callSessionAssetService(action, payload)
	-- NTR_RACING_PHASE10A_SESSION_ASSET_BRIDGE
	local bindings = script.Parent:FindFirstChild("RaceSessionAssetBindings")
	local binding = bindings and bindings:FindFirstChild("SessionAssets")
	if not (binding and binding:IsA("BindableFunction")) then
		return nil
	end
	local ok, result = pcall(function()
		return binding:Invoke(action, payload or {})
	end)
	if ok then
		return result
	end
	warn("[NTR Racing Phase 10A] Session asset service failed: " .. tostring(result))
	return nil
end

]==]

local TT_CREATE_OLD = [==[	assets.Name = "SessionAssets"
	assets.Parent = folder
	return folder
end
]==]

local TT_CREATE_NEW = [==[	assets.Name = "SessionAssets"
	assets.Parent = folder
	callSessionAssetService("CreateForRun", {
		RunId = run.RunId,
		EventId = run.EventId,
		RouteId = run.RouteId,
		Route = run.Route,
		RouteFolder = run.Route and run.Route.Folder,
		SessionFolder = folder,
		Mode = "TimeTrial",
		Participants = {
			{ Player = run.Player, Vehicle = run.Vehicle },
		},
	})
	return folder
end
]==]

local TT_CLEAR_OLD = [==[	if folder and folder.Parent then
		folder:Destroy()
	end
end
]==]

local TT_CLEAR_NEW = [==[	if folder and folder.Parent then
		callSessionAssetService("ClearForRun", { RunId = run.RunId })
		folder:Destroy()
	end
end
]==]

local TT_RESET_APPLY_OLD = [==[	if ok then
		fire(player, {
			Type = "TimeTrialReset",]==]

local TT_RESET_APPLY_NEW = [==[	if ok then
		-- NTR_RACING_PHASE10A_RESET_COLLISION_REAPPLY
		callSessionAssetService("ApplyParticipants", {
			RunId = run.RunId,
			Participants = {
				{ Player = player, Vehicle = run.Vehicle },
			},
		})
		fire(player, {
			Type = "TimeTrialReset",]==]

local RACE_CREATE_OLD = [==[	assets.Name = "SessionAssets"
	assets.Parent = folder
	return folder
end
]==]

local RACE_CREATE_NEW = [==[	assets.Name = "SessionAssets"
	assets.Parent = folder
	callSessionAssetService("CreateForRun", {
		RunId = race.RunId,
		EventId = race.EventId,
		RouteId = race.RouteId,
		Route = race.Route,
		RouteFolder = race.Route and race.Route.Folder,
		SessionFolder = folder,
		Mode = "Race",
		Participants = race.Participants,
	})
	return folder
end
]==]

local RACE_CLEAR_OLD = [==[	if race.SessionFolder and race.SessionFolder.Parent then
		race.SessionFolder:Destroy()
	end
end
]==]

local RACE_CLEAR_NEW = [==[	if race.SessionFolder and race.SessionFolder.Parent then
		callSessionAssetService("ClearForRun", { RunId = race.RunId })
		race.SessionFolder:Destroy()
	end
end
]==]

local RACE_RESET_APPLY_OLD = [==[	if ok then
		fire(player, {
			Type = "RaceReset",]==]

local RACE_RESET_APPLY_NEW = [==[	if ok then
		-- NTR_RACING_PHASE10A_RESET_COLLISION_REAPPLY
		callSessionAssetService("ApplyParticipants", {
			RunId = race.RunId,
			Participants = {
				{ Player = player, Vehicle = entry.Vehicle },
			},
		})
		fire(player, {
			Type = "RaceReset",]==]

local function ensureTemplateFolders()
	local serverStorage = game:GetService("ServerStorage")
	local root = serverStorage:FindFirstChild("NeoTokyoRacers") or Instance.new("Folder")
	root.Name = "NeoTokyoRacers"
	root.Parent = serverStorage
	local racing = root:FindFirstChild("Racing") or Instance.new("Folder")
	racing.Name = "Racing"
	racing.Parent = root
	local templates = racing:FindFirstChild("SessionAssetTemplates") or Instance.new("Folder")
	templates.Name = "SessionAssetTemplates"
	templates.Parent = racing

	local barrier = templates:FindFirstChild("SimpleBarrier")
	if not barrier then
		barrier = Instance.new("Part")
		barrier.Name = "SimpleBarrier"
		barrier.Size = Vector3.new(20, 12, 2)
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.CanTouch = false
		barrier.CanQuery = true
		barrier.Transparency = 0.35
		barrier.Color = Color3.fromRGB(255, 68, 196)
		barrier.Material = Enum.Material.Neon
		barrier.Parent = templates
	end
	info("Ensured server session asset template folder and SimpleBarrier template.")
end

local function ensureRouteMarkers()
	for _, route in ipairs(worldRaceRoutes() and worldRaceRoutes():GetChildren() or {}) do
		local markers = route:FindFirstChild("SessionAssetMarkers") or Instance.new("Folder")
		markers.Name = "SessionAssetMarkers"
		markers.Parent = route
		local sample = markers:FindFirstChild("Example_Blocker_Disabled")
		if not sample then
			local sampleCFrame = CFrame.new()
			for _, item in ipairs(route:GetDescendants()) do
				if item:IsA("BasePart") then
					sampleCFrame = item.CFrame
					break
				end
			end
			sample = Instance.new("Part")
			sample.Name = "Example_Blocker_Disabled"
			sample.Size = Vector3.new(20, 10, 2)
			sample.CFrame = sampleCFrame
			sample.Anchored = true
			sample.Transparency = 1
			sample.CanCollide = false
			sample.CanTouch = false
			sample.CanQuery = false
			sample:SetAttribute("Enabled", false)
			sample:SetAttribute("TemplateId", "SimpleBarrier")
			sample:SetAttribute("Modes", "TimeTrial,Race")
			sample:SetAttribute("RuntimeTransparency", 0.35)
			sample.Parent = markers
		end
		for _, marker in ipairs(markers:GetChildren()) do
			if marker:IsA("BasePart") then
				marker.Anchored = true
				marker.Transparency = 1
				marker.CanCollide = false
				marker.CanTouch = false
				marker.CanQuery = false
				if marker:GetAttribute("Modes") == nil then marker:SetAttribute("Modes", "TimeTrial,Race") end
				if marker:GetAttribute("TemplateId") == nil then marker:SetAttribute("TemplateId", "SimpleBarrier") end
			end
		end
	end
	info("Ensured hidden/non-collidable SessionAssetMarkers folders on routes.")
end

local function installService()
	local folder = serverRacingFolder()
	if not folder then fail("Could not find server Racing folder.") end
	local service = folder:FindFirstChild("RaceSessionAssetService_Active") or Instance.new("Script")
	service.Name = "RaceSessionAssetService_Active"
	service.Source = SERVICE_SOURCE
	service.Parent = folder
	info("Installed RaceSessionAssetService_Active.")
end

local function installClient()
	local folder = clientRacingFolder()
	if not folder then fail("Could not find client Racing folder.") end
	local client = folder:FindFirstChild("RaceSessionAssetsClient_Active") or Instance.new("LocalScript")
	client.Name = "RaceSessionAssetsClient_Active"
	client.Source = SESSION_ASSET_CLIENT_SOURCE
	client.Parent = folder
	info("Installed RaceSessionAssetsClient_Active.")
end

local function patchTimeTrialService()
	local folder = serverRacingFolder()
	local service = folder and folder:FindFirstChild("TimeTrialService_Active")
	if not (service and service:IsA("Script")) then fail("TimeTrialService_Active missing.") end
	local source = service.Source
	if not string.find(source, "NTR_RACING_PHASE10A_SESSION_ASSET_BRIDGE", 1, true) then
		source = replaceOnce(source, "local function createSessionFolder(run)\n", SERVICE_CALL_HELPER .. "local function createSessionFolder(run)\n", "time-trial session asset helper insert")
		source = replaceOnce(source, TT_CREATE_OLD, TT_CREATE_NEW, "time-trial createSessionFolder SessionAssets insert")
		source = replaceOnce(source, TT_CLEAR_OLD, TT_CLEAR_NEW, "time-trial clearSessionFolder asset cleanup")
	else
		info("TimeTrialService_Active already has Phase 10A create/cleanup bridge.")
	end
	if not string.find(source, "NTR_RACING_PHASE10A_RESET_COLLISION_REAPPLY", 1, true) then
		source = replaceOnce(source, TT_RESET_APPLY_OLD, TT_RESET_APPLY_NEW, "time-trial reset participant collision reapply")
	else
		info("TimeTrialService_Active already reapplies participant collision groups after reset.")
	end
	service.Source = source
	info("Patched TimeTrialService_Active session asset create/cleanup hooks.")
end

local function patchRaceService()
	local folder = serverRacingFolder()
	local service = folder and folder:FindFirstChild("RaceMatchmakingService_Active")
	if not (service and service:IsA("Script")) then fail("RaceMatchmakingService_Active missing.") end
	local source = service.Source
	if not string.find(source, "NTR_RACING_PHASE10A_SESSION_ASSET_BRIDGE", 1, true) then
		source = replaceOnce(source, "local function createSessionFolder(race)\n", SERVICE_CALL_HELPER .. "local function createSessionFolder(race)\n", "race session asset helper insert")
		source = replaceOnce(source, RACE_CREATE_OLD, RACE_CREATE_NEW, "race createSessionFolder SessionAssets insert")
		source = replaceOnce(source, RACE_CLEAR_OLD, RACE_CLEAR_NEW, "race cleanupRace asset cleanup")
	else
		info("RaceMatchmakingService_Active already has Phase 10A create/cleanup bridge.")
	end
	if not string.find(source, "NTR_RACING_PHASE10A_RESET_COLLISION_REAPPLY", 1, true) then
		source = replaceOnce(source, RACE_RESET_APPLY_OLD, RACE_RESET_APPLY_NEW, "race reset participant collision reapply")
	else
		info("RaceMatchmakingService_Active already reapplies participant collision groups after reset.")
	end
	service.Source = source
	info("Patched RaceMatchmakingService_Active session asset create/cleanup hooks.")
end

local function smoke()
	local serverFolder = serverRacingFolder()
	local service = serverFolder and serverFolder:FindFirstChild("RaceSessionAssetService_Active")
	local client = clientRacingFolder() and clientRacingFolder():FindFirstChild("RaceSessionAssetsClient_Active")
	local timeTrial = serverFolder and serverFolder:FindFirstChild("TimeTrialService_Active")
	local race = serverFolder and serverFolder:FindFirstChild("RaceMatchmakingService_Active")
	assert(service and service:IsA("Script") and string.find(service.Source, "NTR_RACING_PHASE10A_SESSION_ASSET_SERVICE", 1, true), "Session asset service missing")
	assert(client and client:IsA("LocalScript") and string.find(client.Source, "NTR_RACING_PHASE10A_SESSION_ASSET_VISIBILITY_CLIENT", 1, true), "Session asset client missing")
	assert(timeTrial and string.find(timeTrial.Source, "NTR_RACING_PHASE10A_SESSION_ASSET_BRIDGE", 1, true), "TimeTrialService bridge missing")
	assert(race and string.find(race.Source, "NTR_RACING_PHASE10A_SESSION_ASSET_BRIDGE", 1, true), "RaceMatchmakingService bridge missing")
	assert(timeTrial and string.find(timeTrial.Source, "NTR_RACING_PHASE10A_RESET_COLLISION_REAPPLY", 1, true), "TimeTrialService reset collision reapply missing")
	assert(race and string.find(race.Source, "NTR_RACING_PHASE10A_RESET_COLLISION_REAPPLY", 1, true), "RaceMatchmakingService reset collision reapply missing")
	local templates = game:GetService("ServerStorage"):FindFirstChild("NeoTokyoRacers")
		and game:GetService("ServerStorage").NeoTokyoRacers:FindFirstChild("Racing")
		and game:GetService("ServerStorage").NeoTokyoRacers.Racing:FindFirstChild("SessionAssetTemplates")
	assert(templates and templates:FindFirstChild("SimpleBarrier"), "SimpleBarrier template missing")
	info("Smoke passed: Phase 10A session asset collision foundation is installed.")
end

if MODE == "INSTALL" then
	ensureTemplateFolders()
	ensureRouteMarkers()
	installService()
	installClient()
	patchTimeTrialService()
	patchRaceService()
	smoke()
	info("Installed. Restart Play before testing session asset markers.")
elseif MODE == "SMOKE" then
	smoke()
else
	fail("Unknown MODE: " .. tostring(MODE))
end
