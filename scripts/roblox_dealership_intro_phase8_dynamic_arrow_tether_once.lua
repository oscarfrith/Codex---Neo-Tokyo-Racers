-- Neo Tokyo Racers - Dealership Intro Phase 8: Dynamic Arrow Tether Once
-- Run in Roblox Studio Command Bar, Edit mode, after Phase 7.
--
-- Purpose:
--   Replaces the static client-only path arrows with a dynamic arrow tether
--   from the local player to Intro.Desk.GarageDeskTrigger, and persists the
--   first "Go to the dealership desk" completion per player.
--
-- Safe design:
--   - Replaces only:
--       StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active
--   - Creates/updates only:
--       ServerScriptService.NeoTokyoRacers.Services.Dealership.IntroProgressService_Active
--       ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.DealershipIntro
--       Missing editable attributes on Workspace.NeoTokyoRacersWorld.Dealership.Intro
--   - Keeps the Phase 3/7 local OpenGarageFromIntro hook, so players can still
--     reopen the dealership menu by entering the desk zone later.
--   - Does not touch server purchase/profile/cash logic, final vehicle spawn,
--     driving, existing runtime VFX, LOD, lighting, traffic, or mobile controls.
--   - Does not create backup folders.
--   - Safe to rerun.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_dealership_intro_phase8_dynamic_arrow_tether_once"
local INTRO_CLIENT_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Intro.DealershipIntroClient_Active"
local SERVER_SERVICE_PATH = "ServerScriptService.NeoTokyoRacers.Services.Dealership.IntroProgressService_Active"
local REMOTE_FOLDER_PATH = "ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.DealershipIntro"
local INTRO_PATH = "Workspace.NeoTokyoRacersWorld.Dealership.Intro"

local INTRO_ATTRIBUTE_DEFAULTS = {
	DynamicArrowTetherEnabled = true,
	DynamicArrowTetherSpacing = 9,
	DynamicArrowTetherMaxArrows = 18,
	DynamicArrowTetherMinDistance = 4,
	DynamicArrowTetherStartOffset = 4,
	DynamicArrowTetherEndOffset = 3,
	DynamicArrowTetherHeightOffset = 1.8,
	DynamicArrowTetherArrowScale = 1,
	DynamicArrowTetherShaftEnabled = true,
	DynamicArrowTetherShaftLength = 2.6,
	DynamicArrowTetherShaftWidth = 0.42,
	DynamicArrowTetherHeadLength = 1.05,
	DynamicArrowTetherHeadWidth = 0.36,
	DynamicArrowTetherArrowTransparency = 0.12,
	DynamicArrowTetherPulseSpeed = 2,
	DynamicArrowTetherColor = Color3.fromRGB(172, 255, 197),
	DynamicArrowTetherHeadColor = Color3.fromRGB(255, 120, 210),
	DynamicArrowTetherBeamEnabled = true,
	DynamicArrowTetherBeamColor = Color3.fromRGB(102, 255, 214),
	DynamicArrowTetherBeamWidth = 3.5,
	DynamicArrowTetherBeamTransparency = 0.58,
	DynamicArrowTetherBeamCoreWidth = 0.8,
	DynamicArrowTetherBeamCoreTransparency = 0.25,
	PersistIntroObjectiveCompletion = true,
	CompletionServerMaxDistance = 20,
	DataStoreName = "NTR_DealershipIntro_v1",
}

local INTRO_PROGRESS_SERVICE_SOURCE = [===[
-- Neo Tokyo Racers - Dealership Intro Progress Service Active
-- Installed by scripts/roblox_dealership_intro_phase8_dynamic_arrow_tether_once.lua
--
-- Persists the first dealership desk objective completion per player.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LOG_PREFIX = "[NTR Dealership Intro Progress]"
local COMPLETE_ATTRIBUTE = "NTRDealershipIntroObjectiveComplete"
local LOADED_ATTRIBUTE = "NTRDealershipIntroObjectiveLoaded"
local REMOTE_FOLDER_NAME = "DealershipIntro"
local GET_REMOTE_NAME = "GetDealershipIntroObjectiveComplete"
local COMPLETE_REMOTE_NAME = "CompleteDealershipIntroObjective"
local DEFAULT_DATASTORE_NAME = "NTR_DealershipIntro_v1"

local function log(message)
	print(LOG_PREFIX .. " " .. message)
end

local function warnLine(message)
	warn(LOG_PREFIX .. " " .. message)
end

local function getAttribute(instance, name, fallback)
	if not instance then
		return fallback
	end

	local value = instance:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Folder") then
			error(existing:GetFullName() .. " is " .. existing.ClassName .. ", expected Folder.")
		end
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureRemote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing.ClassName ~= className then
			error(existing:GetFullName() .. " is " .. existing.ClassName .. ", expected " .. className .. ".")
		end
		return existing
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function getIntro()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local dealership = world and world:FindFirstChild("Dealership")
	return dealership and dealership:FindFirstChild("Intro")
end

local function getDeskTrigger(intro)
	local deskFolder = intro and intro:FindFirstChild("Desk")
	local deskTrigger = deskFolder and deskFolder:FindFirstChild("GarageDeskTrigger")
	if deskTrigger and deskTrigger:IsA("BasePart") then
		return deskTrigger
	end
	return nil
end

local function getDataStore()
	local intro = getIntro()
	local dataStoreName = tostring(getAttribute(intro, "DataStoreName", DEFAULT_DATASTORE_NAME))
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(dataStoreName)
	end)
	if ok then
		return store
	end

	warnLine("Could not open DataStore `" .. dataStoreName .. "`; progress will be session-only. " .. tostring(store))
	return nil
end

local dataStore = getDataStore()

local neoTokyo = ensureFolder(ReplicatedStorage, "NeoTokyoRacers")
local shared = ensureFolder(neoTokyo, "Shared")
local remotes = ensureFolder(shared, "Remotes")
local remoteFolder = ensureFolder(remotes, REMOTE_FOLDER_NAME)
local getCompleteRemote = ensureRemote(remoteFolder, GET_REMOTE_NAME, "RemoteFunction")
local completeRemote = ensureRemote(remoteFolder, COMPLETE_REMOTE_NAME, "RemoteEvent")

local function dataKey(player)
	return "desk_objective_" .. tostring(player.UserId)
end

local function loadPlayer(player)
	player:SetAttribute(LOADED_ATTRIBUTE, false)

	local complete = false
	if dataStore then
		local ok, result = pcall(function()
			return dataStore:GetAsync(dataKey(player))
		end)
		if ok then
			complete = result == true
		else
			warnLine("GetAsync failed for " .. player.Name .. "; using session fallback. " .. tostring(result))
		end
	end

	if player.Parent then
		player:SetAttribute(COMPLETE_ATTRIBUTE, complete)
		player:SetAttribute(LOADED_ATTRIBUTE, true)
	end
end

local function savePlayerComplete(player)
	player:SetAttribute(COMPLETE_ATTRIBUTE, true)
	player:SetAttribute(LOADED_ATTRIBUTE, true)

	if not dataStore then
		return false
	end

	local ok, err = pcall(function()
		dataStore:SetAsync(dataKey(player), true)
	end)
	if not ok then
		warnLine("SetAsync failed for " .. player.Name .. "; completion is set for this session only. " .. tostring(err))
		return false
	end

	return true
end

local function waitForLoaded(player)
	local started = os.clock()
	while player.Parent and player:GetAttribute(LOADED_ATTRIBUTE) ~= true and os.clock() - started < 8 do
		task.wait(0.1)
	end
	return player:GetAttribute(COMPLETE_ATTRIBUTE) == true
end

local function isNearDesk(player)
	local intro = getIntro()
	local deskTrigger = getDeskTrigger(intro)
	if not deskTrigger then
		warnLine("Cannot validate completion distance; GarageDeskTrigger was not found.")
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	local activationDistance = tonumber(getAttribute(deskTrigger, "ActivationDistance", nil))
		or tonumber(getAttribute(intro, "DeskActivationDistance", 5))
		or 5
	local maxDistance = tonumber(getAttribute(intro, "CompletionServerMaxDistance", 20)) or 20
	maxDistance = math.max(maxDistance, activationDistance + 8)
	return (root.Position - deskTrigger.Position).Magnitude <= maxDistance
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadPlayer, player)
end

getCompleteRemote.OnServerInvoke = function(player)
	return waitForLoaded(player)
end

completeRemote.OnServerEvent:Connect(function(player)
	if waitForLoaded(player) then
		return
	end

	if not isNearDesk(player) then
		warnLine("Rejected completion from " .. player.Name .. " because they are not near GarageDeskTrigger.")
		return
	end

	local persisted = savePlayerComplete(player)
	log("Marked dealership desk objective complete for " .. player.Name .. (persisted and " and saved it." or " for this session."))
end)

log("Ready. Remotes: " .. remoteFolder:GetFullName())
]===]

local DEALERSHIP_INTRO_CLIENT_SOURCE = [===[
-- Neo Tokyo Racers - Dealership Intro Client Active
-- Installed by scripts/roblox_dealership_intro_phase8_dynamic_arrow_tether_once.lua
--
-- Local-only intro helper:
--   - Reads Workspace.NeoTokyoRacersWorld.Dealership.Intro attributes.
--   - Shows the objective only until the player first reaches the desk.
--   - Creates a client-only dynamic arrow tether from the player to the desk.
--   - Persists objective completion through the Phase 8 server progress service.
--   - Keeps the Phase 7 leave-and-reenter desk gate for later garage opens.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LOG_PREFIX = "[NTR Dealership Intro Client]"
local CLIENT_ROOT_NAME = "_NTR_ClientOnly"
local INTRO_PATH_NAME = "IntroPath"
local OBJECTIVE_GUI_NAME = "NTR_DealershipIntroObjective"
local COMPLETE_ATTRIBUTE = "NTRDealershipIntroObjectiveComplete"
local REMOTE_FOLDER_NAME = "DealershipIntro"
local GET_REMOTE_NAME = "GetDealershipIntroObjectiveComplete"
local COMPLETE_REMOTE_NAME = "CompleteDealershipIntroObjective"

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

local function log(message)
	print(LOG_PREFIX .. " " .. message)
end

local function warnOnceFactory()
	local warned = {}
	return function(key, message)
		if warned[key] then
			return
		end
		warned[key] = true
		warn(LOG_PREFIX .. " " .. message)
	end
end

local warnOnce = warnOnceFactory()

local function getAttribute(instance, name, fallback)
	local value = instance:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

local function waitForCharacterRoot()
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:FindFirstChild("HumanoidRootPart")
	while not root do
		character = player.Character or player.CharacterAdded:Wait()
		root = character:WaitForChild("HumanoidRootPart", 10)
		if not root then
			warnOnce("missing-root", "Waiting for HumanoidRootPart before starting intro distance checks.")
		end
	end
	return character, root
end

local function waitForIntro()
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local dealership = world:WaitForChild("Dealership")
	return dealership:WaitForChild("Intro")
end

local function getIntroConfig(intro, deskTrigger)
	local activationDistance = getAttribute(intro, "DeskActivationDistance", 5)
	if deskTrigger and deskTrigger:GetAttribute("ActivationDistance") ~= nil then
		activationDistance = deskTrigger:GetAttribute("ActivationDistance")
	end

	return {
		Enabled = getAttribute(intro, "Enabled", true),
		DeskActivationDistance = tonumber(activationDistance) or 5,
		AutoOpenGarageAtDesk = getAttribute(intro, "AutoOpenGarageAtDesk", true),
		ShowObjectiveText = getAttribute(intro, "ShowObjectiveText", true),
		IntroObjectiveText = tostring(getAttribute(intro, "IntroObjectiveText", "Go to the dealership desk")),
		CameraIntroEnabled = getAttribute(intro, "CameraIntroEnabled", true),
		CameraIntroDuration = tonumber(getAttribute(intro, "CameraIntroDuration", 1.25)) or 1.25,
		PersistIntroObjectiveCompletion = getAttribute(intro, "PersistIntroObjectiveCompletion", true),
		DynamicArrowTetherEnabled = getAttribute(intro, "DynamicArrowTetherEnabled", true),
		DynamicArrowTetherSpacing = math.max(2, tonumber(getAttribute(intro, "DynamicArrowTetherSpacing", 9)) or 9),
		DynamicArrowTetherMaxArrows = math.clamp(math.floor(tonumber(getAttribute(intro, "DynamicArrowTetherMaxArrows", 18)) or 18), 1, 40),
		DynamicArrowTetherMinDistance = math.max(0, tonumber(getAttribute(intro, "DynamicArrowTetherMinDistance", 4)) or 4),
		DynamicArrowTetherStartOffset = math.max(0, tonumber(getAttribute(intro, "DynamicArrowTetherStartOffset", 4)) or 4),
		DynamicArrowTetherEndOffset = math.max(0, tonumber(getAttribute(intro, "DynamicArrowTetherEndOffset", 3)) or 3),
		DynamicArrowTetherHeightOffset = tonumber(getAttribute(intro, "DynamicArrowTetherHeightOffset", getAttribute(intro, "PathArrowHeightOffset", 1.8))) or 1.8,
		DynamicArrowTetherArrowScale = math.clamp(tonumber(getAttribute(intro, "DynamicArrowTetherArrowScale", 1)) or 1, 0.45, 2.25),
		DynamicArrowTetherShaftEnabled = getAttribute(intro, "DynamicArrowTetherShaftEnabled", true),
		DynamicArrowTetherShaftLength = math.max(0.4, tonumber(getAttribute(intro, "DynamicArrowTetherShaftLength", 2.6)) or 2.6),
		DynamicArrowTetherShaftWidth = math.max(0.05, tonumber(getAttribute(intro, "DynamicArrowTetherShaftWidth", 0.42)) or 0.42),
		DynamicArrowTetherHeadLength = math.max(0.25, tonumber(getAttribute(intro, "DynamicArrowTetherHeadLength", 1.05)) or 1.05),
		DynamicArrowTetherHeadWidth = math.max(0.05, tonumber(getAttribute(intro, "DynamicArrowTetherHeadWidth", 0.36)) or 0.36),
		DynamicArrowTetherArrowTransparency = math.clamp(tonumber(getAttribute(intro, "DynamicArrowTetherArrowTransparency", 0.12)) or 0.12, 0, 1),
		DynamicArrowTetherPulseSpeed = math.max(0, tonumber(getAttribute(intro, "DynamicArrowTetherPulseSpeed", 2)) or 2),
		DynamicArrowTetherColor = getAttribute(intro, "DynamicArrowTetherColor", Color3.fromRGB(172, 255, 197)),
		DynamicArrowTetherHeadColor = getAttribute(intro, "DynamicArrowTetherHeadColor", Color3.fromRGB(255, 120, 210)),
		DynamicArrowTetherBeamEnabled = getAttribute(intro, "DynamicArrowTetherBeamEnabled", true),
		DynamicArrowTetherBeamColor = getAttribute(intro, "DynamicArrowTetherBeamColor", Color3.fromRGB(102, 255, 214)),
		DynamicArrowTetherBeamWidth = math.max(0.1, tonumber(getAttribute(intro, "DynamicArrowTetherBeamWidth", 3.5)) or 3.5),
		DynamicArrowTetherBeamTransparency = math.clamp(tonumber(getAttribute(intro, "DynamicArrowTetherBeamTransparency", 0.58)) or 0.58, 0, 1),
		DynamicArrowTetherBeamCoreWidth = math.max(0.05, tonumber(getAttribute(intro, "DynamicArrowTetherBeamCoreWidth", 0.8)) or 0.8),
		DynamicArrowTetherBeamCoreTransparency = math.clamp(tonumber(getAttribute(intro, "DynamicArrowTetherBeamCoreTransparency", 0.25)) or 0.25, 0, 1),
		Debug = getAttribute(intro, "Debug", false),
	}
end

local function debugPrint(config, message)
	if config.Debug then
		log(message)
	end
end

local function clearObjectiveGui()
	local playerGui = player:FindFirstChild("PlayerGui")
	local existing = playerGui and playerGui:FindFirstChild(OBJECTIVE_GUI_NAME)
	if existing then
		existing:Destroy()
	end
end

local function createObjectiveGui(config)
	clearObjectiveGui()
	if not config.ShowObjectiveText then
		return nil
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = OBJECTIVE_GUI_NAME
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 18
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "ObjectiveRoot"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 18)
	root.Size = UDim2.new(0, 360, 0, 46)
	root.BackgroundColor3 = Color3.fromRGB(5, 9, 7)
	root.BackgroundTransparency = 0.18
	root.BorderSizePixel = 0
	root.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = root

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(172, 255, 197)
	stroke.Thickness = 1
	stroke.Transparency = 0.28
	stroke.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "ObjectiveText"
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, 5)
	label.Size = UDim2.new(1, -24, 1, -10)
	label.FontFace = Font.new("rbxasset://fonts/families/Michroma.json")
	label.Text = config.IntroObjectiveText
	label.TextColor3 = Color3.fromRGB(218, 255, 231)
	label.TextSize = 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = root

	local camera = Workspace.CurrentCamera
	local function updateScale()
		local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.78, 1)
	end

	updateScale()
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	return gui
end

local function clearPathArrows()
	local clientRoot = Workspace:FindFirstChild(CLIENT_ROOT_NAME)
	local introPath = clientRoot and clientRoot:FindFirstChild(INTRO_PATH_NAME)
	if introPath then
		introPath:Destroy()
	end
end

local function ensureClientPathFolder()
	local clientRoot = Workspace:FindFirstChild(CLIENT_ROOT_NAME)
	if not clientRoot then
		clientRoot = Instance.new("Folder")
		clientRoot.Name = CLIENT_ROOT_NAME
		clientRoot.Parent = Workspace
	end

	local introPath = clientRoot:FindFirstChild(INTRO_PATH_NAME)
	if introPath then
		introPath:Destroy()
	end

	introPath = Instance.new("Folder")
	introPath.Name = INTRO_PATH_NAME
	introPath.Parent = clientRoot
	return introPath
end

local function makeArrowPart(parent, name, size, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.12
	part.Size = size
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeBeamAnchor(parent, name)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = parent

	local attachment = Instance.new("Attachment")
	attachment.Name = "Attachment"
	attachment.Parent = part

	return part, attachment
end

local function createTetherBeam(parent, config)
	if not config.DynamicArrowTetherBeamEnabled then
		return nil
	end

	local beamFolder = Instance.new("Folder")
	beamFolder.Name = "DynamicBeam"
	beamFolder.Parent = parent

	local startPart, startAttachment = makeBeamAnchor(beamFolder, "BeamStart")
	local endPart, endAttachment = makeBeamAnchor(beamFolder, "BeamEnd")

	local aura = Instance.new("Beam")
	aura.Name = "AuraBeam"
	aura.Attachment0 = startAttachment
	aura.Attachment1 = endAttachment
	aura.Color = ColorSequence.new(config.DynamicArrowTetherBeamColor)
	aura.Transparency = NumberSequence.new(config.DynamicArrowTetherBeamTransparency)
	aura.Width0 = config.DynamicArrowTetherBeamWidth
	aura.Width1 = config.DynamicArrowTetherBeamWidth
	aura.LightEmission = 1
	aura.Brightness = 1.8
	aura.FaceCamera = true
	aura.Segments = 16
	aura.Enabled = false
	aura.Parent = beamFolder

	local core = Instance.new("Beam")
	core.Name = "CoreBeam"
	core.Attachment0 = startAttachment
	core.Attachment1 = endAttachment
	core.Color = ColorSequence.new(config.DynamicArrowTetherColor)
	core.Transparency = NumberSequence.new(config.DynamicArrowTetherBeamCoreTransparency)
	core.Width0 = config.DynamicArrowTetherBeamCoreWidth
	core.Width1 = config.DynamicArrowTetherBeamCoreWidth
	core.LightEmission = 1
	core.Brightness = 2.2
	core.FaceCamera = true
	core.Segments = 16
	core.Enabled = false
	core.Parent = beamFolder

	return {
		StartPart = startPart,
		EndPart = endPart,
		Aura = aura,
		Core = core,
	}
end

local function setBeamVisible(beam, visible)
	if not beam then
		return
	end

	beam.Aura.Enabled = visible
	beam.Core.Enabled = visible
end

local function updateBeam(beam, startPosition, endPosition)
	if not beam then
		return
	end

	beam.StartPart.CFrame = CFrame.new(startPosition)
	beam.EndPart.CFrame = CFrame.new(endPosition)
end

local function createArrowModel(parent, index, config)
	local scale = config.DynamicArrowTetherArrowScale
	local arrow = Instance.new("Model")
	arrow.Name = string.format("DynamicArrow_%02d", index)
	arrow.Parent = parent

	local shaft = makeArrowPart(arrow, "Shaft", Vector3.new(config.DynamicArrowTetherShaftWidth, 0.16, config.DynamicArrowTetherShaftLength) * scale, config.DynamicArrowTetherColor)
	local left = makeArrowPart(arrow, "HeadLeft", Vector3.new(config.DynamicArrowTetherHeadWidth, 0.16, config.DynamicArrowTetherHeadLength) * scale, config.DynamicArrowTetherHeadColor)
	local right = makeArrowPart(arrow, "HeadRight", Vector3.new(config.DynamicArrowTetherHeadWidth, 0.16, config.DynamicArrowTetherHeadLength) * scale, config.DynamicArrowTetherHeadColor)
	return {
		Model = arrow,
		Shaft = shaft,
		Left = left,
		Right = right,
		Transparency = config.DynamicArrowTetherArrowTransparency,
		ShaftEnabled = config.DynamicArrowTetherShaftEnabled,
	}
end

local function setArrowVisible(arrow, visible)
	local transparency = visible and arrow.Transparency or 1
	arrow.Shaft.Transparency = arrow.ShaftEnabled and transparency or 1
	arrow.Left.Transparency = transparency
	arrow.Right.Transparency = transparency
end

local function updateArrow(arrow, center, flatDirection, config, pulseOffset)
	local scale = config.DynamicArrowTetherArrowScale
	local shaftForward = config.DynamicArrowTetherShaftLength * 0.48 * scale
	local headForward = (config.DynamicArrowTetherShaftLength * 0.78 + config.DynamicArrowTetherHeadLength * 0.45) * scale
	local headSide = config.DynamicArrowTetherHeadWidth * 0.95 * scale
	local cframe = CFrame.lookAt(center, center + flatDirection)
	local rightVector = cframe.RightVector
	local pulse = config.DynamicArrowTetherPulseSpeed > 0 and (0.08 * math.sin(os.clock() * config.DynamicArrowTetherPulseSpeed + pulseOffset)) or 0
	local lift = Vector3.new(0, pulse, 0)

	arrow.Shaft.CFrame = cframe + lift
	arrow.Left.CFrame = CFrame.lookAt(center + lift + flatDirection * shaftForward - rightVector * headSide, center + lift + flatDirection * headForward)
	arrow.Right.CFrame = CFrame.lookAt(center + lift + flatDirection * shaftForward + rightVector * headSide, center + lift + flatDirection * headForward)
end

local function createDynamicTether(root, deskTrigger, config)
	clearPathArrows()
	if not config.DynamicArrowTetherEnabled then
		return nil
	end

	local folder = ensureClientPathFolder()
	local beam = createTetherBeam(folder, config)
	local arrows = {}
	for index = 1, config.DynamicArrowTetherMaxArrows do
		arrows[index] = createArrowModel(folder, index, config)
		setArrowVisible(arrows[index], false)
	end

	local active = true
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not active or not root.Parent or not deskTrigger.Parent then
			return
		end

		local rawStart = root.Position
		local rawEnd = deskTrigger.Position
		local delta = rawEnd - rawStart
		local flatDelta = Vector3.new(delta.X, 0, delta.Z)
		local distance = flatDelta.Magnitude

		if distance <= config.DynamicArrowTetherMinDistance then
			setBeamVisible(beam, false)
			for _, arrow in ipairs(arrows) do
				setArrowVisible(arrow, false)
			end
			return
		end

		local direction = flatDelta.Unit
		local usableDistance = math.max(0, distance - config.DynamicArrowTetherStartOffset - config.DynamicArrowTetherEndOffset)
		local arrowCount = math.clamp(math.floor(usableDistance / config.DynamicArrowTetherSpacing), 1, config.DynamicArrowTetherMaxArrows)
		local beamStart = rawStart + direction * config.DynamicArrowTetherStartOffset + Vector3.new(0, config.DynamicArrowTetherHeightOffset, 0)
		local beamEnd = rawEnd - direction * config.DynamicArrowTetherEndOffset + Vector3.new(0, config.DynamicArrowTetherHeightOffset, 0)
		updateBeam(beam, beamStart, beamEnd)
		setBeamVisible(beam, true)

		for index, arrow in ipairs(arrows) do
			if index <= arrowCount then
				local t = index / (arrowCount + 1)
				local travel = config.DynamicArrowTetherStartOffset + usableDistance * t
				local center = rawStart + direction * travel + Vector3.new(0, config.DynamicArrowTetherHeightOffset, 0)
				updateArrow(arrow, center, direction, config, index * 0.55)
				setArrowVisible(arrow, true)
			else
				setArrowVisible(arrow, false)
			end
		end
	end)

	return {
		Folder = folder,
		Stop = function()
			active = false
			if connection then
				connection:Disconnect()
				connection = nil
			end
			if folder then
				folder:Destroy()
			end
		end,
	}
end

local function playCameraIntro(intro, config)
	if not config.CameraIntroEnabled then
		return
	end

	local cameraFolder = intro:FindFirstChild("Camera")
	local cameraPoint = cameraFolder and cameraFolder:FindFirstChild("DealershipLookCameraPoint")
	if not cameraPoint or not cameraPoint:IsA("BasePart") then
		warnOnce("missing-camera-point", "CameraIntroEnabled is true, but DealershipLookCameraPoint was not found as a BasePart.")
		return
	end

	local deskTrigger = intro:FindFirstChild("Desk") and intro.Desk:FindFirstChild("GarageDeskTrigger")
	local lookPosition = deskTrigger and deskTrigger:IsA("BasePart") and deskTrigger.Position or (cameraPoint.Position + cameraPoint.CFrame.LookVector * 20)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local originalType = camera.CameraType
	local originalSubject = camera.CameraSubject
	local originalCFrame = camera.CFrame
	local duration = math.clamp(config.CameraIntroDuration, 0.1, 5)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(cameraPoint.Position, lookPosition)
	camera:SetAttribute("NTRDealershipIntroCameraActive", true)

	local targetCFrame = CFrame.lookAt(cameraPoint.Position, lookPosition)
	local tween = TweenService:Create(camera, TweenInfo.new(math.min(duration, 1.25), Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		CFrame = targetCFrame,
	})
	tween:Play()

	task.delay(duration, function()
		if camera:GetAttribute("NTRDealershipIntroCameraActive") == true then
			camera:SetAttribute("NTRDealershipIntroCameraActive", false)
			camera.CameraType = originalType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or originalType
			camera.CameraSubject = originalSubject
			if camera.CameraType == Enum.CameraType.Custom and originalSubject == nil then
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					camera.CameraSubject = humanoid
				end
			elseif camera.CameraType ~= Enum.CameraType.Custom then
				camera.CFrame = originalCFrame
			end
		end
	end)
end

local function getProgressRemotes()
	local neoTokyo = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local shared = neoTokyo and neoTokyo:FindFirstChild("Shared")
	local remotes = shared and shared:FindFirstChild("Remotes")
	local folder = remotes and remotes:FindFirstChild(REMOTE_FOLDER_NAME)
	local getComplete = folder and folder:FindFirstChild(GET_REMOTE_NAME)
	local complete = folder and folder:FindFirstChild(COMPLETE_REMOTE_NAME)

	if getComplete and not getComplete:IsA("RemoteFunction") then
		getComplete = nil
	end
	if complete and not complete:IsA("RemoteEvent") then
		complete = nil
	end

	return getComplete, complete
end

local function isObjectiveComplete(config)
	if not config.PersistIntroObjectiveCompletion then
		return false
	end

	if player:GetAttribute(COMPLETE_ATTRIBUTE) == true then
		return true
	end

	local getComplete = nil
	local started = os.clock()
	while os.clock() - started < 6 and not getComplete do
		getComplete = select(1, getProgressRemotes())
		if not getComplete then
			task.wait(0.1)
		end
	end

	if not getComplete then
		warnOnce("missing-progress-get", "Phase 8 progress RemoteFunction was not found; objective completion cannot persist in this Play session.")
		return false
	end

	local ok, complete = pcall(function()
		return getComplete:InvokeServer()
	end)
	if ok and complete == true then
		player:SetAttribute(COMPLETE_ATTRIBUTE, true)
		return true
	end

	if not ok then
		warnOnce("progress-get-failed", "Could not read persisted intro completion: " .. tostring(complete))
	end

	return false
end

local function markObjectiveComplete(config)
	if player:GetAttribute(COMPLETE_ATTRIBUTE) == true then
		return
	end

	player:SetAttribute(COMPLETE_ATTRIBUTE, true)
	if not config.PersistIntroObjectiveCompletion then
		return
	end

	local _, completeRemote = getProgressRemotes()
	if completeRemote then
		completeRemote:FireServer()
	else
		warnOnce("missing-progress-complete", "Phase 8 completion RemoteEvent was not found; objective is hidden for this session only.")
	end
end

local function tryOpenGarage(config)
	if not config.AutoOpenGarageAtDesk then
		log("Reached desk. AutoOpenGarageAtDesk is false, so no garage open call was attempted.")
		return
	end

	local openEvent = script.Parent:FindFirstChild("OpenGarageFromIntro")
	if not openEvent then
		openEvent = script.Parent:WaitForChild("OpenGarageFromIntro", 5)
	end

	if openEvent and openEvent:IsA("BindableEvent") then
		log("Reached dealership desk. Opening garage through OpenGarageFromIntro.")
		openEvent:Fire()
	else
		warnOnce("missing-open-hook", "Reached dealership desk, but OpenGarageFromIntro BindableEvent was not found under " .. script.Parent:GetFullName() .. ". Run scripts/roblox_dealership_intro_phase3_gate_garage_startup.lua and scripts/roblox_dealership_intro_phase7_exit_button_reopen_gate.lua, then test in a fresh Play Solo session.")
	end

	local playerGui = player:FindFirstChild("PlayerGui")
	local garageGui = playerGui and playerGui:FindFirstChild("HOVER_RACING_V2_GarageUI")
	if garageGui and garageGui.Enabled then
		warnOnce("garage-already-visible", "Garage UI is already visible. This likely means current startup still auto-opens/builds garage before the intro desk gate.")
	end
end

local function cleanup(objectiveGui, tether)
	if objectiveGui then
		objectiveGui.Enabled = false
	end
	if tether then
		tether.Stop()
	else
		clearPathArrows()
	end
end

local function run()
	local _, root = waitForCharacterRoot()
	local intro = waitForIntro()
	local deskFolder = intro:WaitForChild("Desk")
	local deskTrigger = deskFolder:WaitForChild("GarageDeskTrigger")

	if not deskTrigger:IsA("BasePart") then
		warnOnce("bad-desk-trigger", "Intro.Desk.GarageDeskTrigger is not a BasePart; intro client cannot run distance checks.")
		return
	end

	local config = getIntroConfig(intro, deskTrigger)
	if not config.Enabled then
		log("Intro.Enabled is false; dealership intro client is idle.")
		return
	end

	debugPrint(config, "Intro enabled. Activation distance: " .. tostring(config.DeskActivationDistance))

	local objectiveComplete = isObjectiveComplete(config)
	local objectiveGui = nil
	local tether = nil

	if not objectiveComplete then
		objectiveGui = createObjectiveGui(config)
		tether = createDynamicTether(root, deskTrigger, config)
		playCameraIntro(intro, config)
	else
		clearObjectiveGui()
		clearPathArrows()
		debugPrint(config, "Desk objective already complete; objective UI and tether are hidden.")
	end

	local closeEvent = script.Parent:FindFirstChild("GarageClosedFromDealershipExit")
	if closeEvent and not closeEvent:IsA("BindableEvent") then
		warnOnce("bad-close-hook", "GarageClosedFromDealershipExit exists but is " .. closeEvent.ClassName .. ", expected BindableEvent. Reopen gating will not arm.")
		closeEvent = nil
	end
	if not closeEvent then
		closeEvent = Instance.new("BindableEvent")
		closeEvent.Name = "GarageClosedFromDealershipExit"
		closeEvent.Parent = script.Parent
	end

	local dismissedUntilLeave = false
	local wasInsideZone = false
	local reopenDistance = math.max(config.DeskActivationDistance + 3, config.DeskActivationDistance * 1.75)

	local function onExited()
		dismissedUntilLeave = true
		wasInsideZone = true
		log("Dealership menu exited. Walk away from the desk, then re-enter the zone to reopen it.")
	end

	closeEvent.Event:Connect(onExited)

	while true do
		if not root.Parent then
			_, root = waitForCharacterRoot()
			if tether then
				tether.Stop()
				tether = createDynamicTether(root, deskTrigger, config)
			end
		end

		local distance = (root.Position - deskTrigger.Position).Magnitude
		local insideZone = distance <= config.DeskActivationDistance

		if dismissedUntilLeave and distance >= reopenDistance then
			dismissedUntilLeave = false
			wasInsideZone = false
			log("Dealership desk reopen gate reset. Re-enter the desk zone to reopen the menu.")
		end

		if insideZone and not wasInsideZone and not dismissedUntilLeave then
			if not objectiveComplete then
				objectiveComplete = true
				cleanup(objectiveGui, tether)
				objectiveGui = nil
				tether = nil
				markObjectiveComplete(config)
			end

			tryOpenGarage(config)
		end

		wasInsideZone = insideZone
		task.wait(0.15)
	end
end

task.spawn(function()
	local ok, err = pcall(run)
	if not ok then
		warn(LOG_PREFIX .. " Failed: " .. tostring(err))
		clearObjectiveGui()
		clearPathArrows()
	end
end)
]===]

local SERVICES = {
	ReplicatedStorage = ReplicatedStorage,
	ServerScriptService = ServerScriptService,
	StarterPlayer = StarterPlayer,
	Workspace = Workspace,
}

local created = {}
local reused = {}
local changed = {}
local attributesAdded = {}
local attributesPreserved = {}

local function log(message)
	print("[NTR Dealership Intro Phase 8] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Folder") then
			error(("Existing %s is %s, expected Folder. No changes applied."):format(
				safeFullName(existing),
				existing.ClassName
			))
		end
		table.insert(reused, safeFullName(existing) .. " -> Folder")
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	table.insert(created, safeFullName(folder) .. " -> Folder")
	return folder
end

local function ensureRemote(parent, name, className)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing.ClassName ~= className then
			error(("Existing %s is %s, expected %s. No changes applied."):format(
				safeFullName(existing),
				existing.ClassName,
				className
			))
		end
		table.insert(reused, safeFullName(existing) .. " -> " .. className)
		return existing
	end

	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = parent
	table.insert(created, safeFullName(remote) .. " -> " .. className)
	return remote
end

local function setDefaultAttribute(instance, name, value)
	if instance:GetAttribute(name) == nil then
		instance:SetAttribute(name, value)
		table.insert(attributesAdded, safeFullName(instance) .. "." .. name .. " = " .. tostring(value))
	else
		table.insert(attributesPreserved, safeFullName(instance) .. "." .. name .. " = " .. tostring(instance:GetAttribute(name)))
	end
end

local function resolvePath(path)
	local firstToken = string.match(path, "^[^%.]+")
	local current = SERVICES[firstToken]
	if not current then
		return nil
	end

	local skipFirst = true
	for token in string.gmatch(path, "[^%.]+") do
		if skipFirst then
			skipFirst = false
		else
			current = current:FindFirstChild(token)
			if not current then
				return nil
			end
		end
	end

	return current
end

local function ensurePath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = ensureFolder(current, name)
	end
	return current
end

local intro = resolvePath(INTRO_PATH)
if not intro or not intro:IsA("Folder") then
	error("Intro folder was not found at " .. INTRO_PATH .. ". Run scripts/roblox_dealership_intro_phase1_setup_markers.lua first.")
end

for name, value in pairs(INTRO_ATTRIBUTE_DEFAULTS) do
	setDefaultAttribute(intro, name, value)
end

local neoTokyo = ensureFolder(ReplicatedStorage, "NeoTokyoRacers")
local shared = ensureFolder(neoTokyo, "Shared")
local remotes = ensureFolder(shared, "Remotes")
local dealershipIntroRemotes = ensureFolder(remotes, "DealershipIntro")
ensureRemote(dealershipIntroRemotes, "GetDealershipIntroObjectiveComplete", "RemoteFunction")
ensureRemote(dealershipIntroRemotes, "CompleteDealershipIntroObjective", "RemoteEvent")

local serverDealershipFolder = ensurePath(ServerScriptService, { "NeoTokyoRacers", "Services", "Dealership" })
local progressService = serverDealershipFolder:FindFirstChild("IntroProgressService_Active")
if progressService then
	if not progressService:IsA("Script") then
		error(("Existing %s is %s, expected Script. No changes applied."):format(
			safeFullName(progressService),
			progressService.ClassName
		))
	end
	table.insert(reused, safeFullName(progressService) .. " -> Script")
else
	progressService = Instance.new("Script")
	progressService.Name = "IntroProgressService_Active"
	progressService.Parent = serverDealershipFolder
	table.insert(created, safeFullName(progressService) .. " -> Script")
end

if progressService.Source ~= INTRO_PROGRESS_SERVICE_SOURCE then
	progressService.Source = INTRO_PROGRESS_SERVICE_SOURCE
	table.insert(changed, safeFullName(progressService) .. ".Source")
end
if progressService.Disabled then
	progressService.Disabled = false
	table.insert(changed, safeFullName(progressService) .. ".Disabled = false")
end
progressService:SetAttribute("InstalledBy", SCRIPT_ID)
progressService:SetAttribute("InstalledAt", os.date("%Y-%m-%d %H:%M:%S"))

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = ensureFolder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = ensureFolder(clientRoot, "Controllers")
local introFolder = ensureFolder(controllers, "Intro")

local introClient = introFolder:FindFirstChild("DealershipIntroClient_Active")
if introClient then
	if not introClient:IsA("LocalScript") then
		error(("Existing %s is %s, expected LocalScript. No changes applied."):format(
			safeFullName(introClient),
			introClient.ClassName
		))
	end
	table.insert(reused, safeFullName(introClient) .. " -> LocalScript")
else
	introClient = Instance.new("LocalScript")
	introClient.Name = "DealershipIntroClient_Active"
	introClient.Parent = introFolder
	table.insert(created, safeFullName(introClient) .. " -> LocalScript")
end

if introClient.Source ~= DEALERSHIP_INTRO_CLIENT_SOURCE then
	introClient.Source = DEALERSHIP_INTRO_CLIENT_SOURCE
	table.insert(changed, safeFullName(introClient) .. ".Source")
end
if introClient.Disabled then
	introClient.Disabled = false
	table.insert(changed, safeFullName(introClient) .. ".Disabled = false")
end
introClient:SetAttribute("InstalledBy", SCRIPT_ID)
introClient:SetAttribute("InstalledAt", os.date("%Y-%m-%d %H:%M:%S"))
introClient:SetAttribute("DynamicArrowTetherPhase", 8)
introClient:SetAttribute("GarageOpenIntegration", "Uses local OpenGarageFromIntro BindableEvent installed by Phase 3/7")

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Dealership Intro Phase 8 Dynamic Arrow Tether Once")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Intro client target: " .. INTRO_CLIENT_PATH)
line("- Progress service target: " .. SERVER_SERVICE_PATH)
line("- Remote folder: " .. REMOTE_FOLDER_PATH)
line("- Intro attributes path: " .. INTRO_PATH)
line("- Objects created: " .. tostring(#created))
line("- Objects reused: " .. tostring(#reused))
line("- Changed fields: " .. tostring(#changed))
line("- Missing attributes added: " .. tostring(#attributesAdded))
line("- Existing attributes preserved: " .. tostring(#attributesPreserved))
line("- Purchase/profile/cash/final spawn/driving/VFX systems touched: false")
line("")

line("## Changed")
line("")
if #changed == 0 then
	line("- None.")
else
	for _, item in ipairs(changed) do
		line("- " .. item)
	end
end
line("")

line("## New Editable Intro Attributes")
line("")
line("- DynamicArrowTetherEnabled")
line("- DynamicArrowTetherSpacing")
line("- DynamicArrowTetherMaxArrows")
line("- DynamicArrowTetherMinDistance")
line("- DynamicArrowTetherStartOffset")
line("- DynamicArrowTetherEndOffset")
line("- DynamicArrowTetherHeightOffset")
line("- DynamicArrowTetherArrowScale")
line("- DynamicArrowTetherShaftEnabled")
line("- DynamicArrowTetherShaftLength")
line("- DynamicArrowTetherShaftWidth")
line("- DynamicArrowTetherHeadLength")
line("- DynamicArrowTetherHeadWidth")
line("- DynamicArrowTetherArrowTransparency")
line("- DynamicArrowTetherPulseSpeed")
line("- DynamicArrowTetherColor")
line("- DynamicArrowTetherHeadColor")
line("- DynamicArrowTetherBeamEnabled")
line("- DynamicArrowTetherBeamColor")
line("- DynamicArrowTetherBeamWidth")
line("- DynamicArrowTetherBeamTransparency")
line("- DynamicArrowTetherBeamCoreWidth")
line("- DynamicArrowTetherBeamCoreTransparency")
line("- PersistIntroObjectiveCompletion")
line("- CompletionServerMaxDistance")
line("- DataStoreName")
line("")

line("## Play Test")
line("")
line("1. Enable Studio API access if you want DataStore persistence to work in Studio testing.")
line("2. Start a fresh Play Solo session with a player that has not completed the desk objective.")
line("3. Confirm the objective appears and a client-only moving arrow tether follows the player to GarageDeskTrigger under Workspace._NTR_ClientOnly.IntroPath.")
line("4. Walk to GarageDeskTrigger. Confirm the objective/tether disappear and the dealership menu opens.")
line("5. Exit the menu, walk away, and re-enter the desk zone. Confirm the menu can still reopen, but the objective/tether do not come back.")
line("6. Leave and rejoin. Confirm the objective/tether stay hidden while the desk zone still opens the menu.")
line("7. Paste any `[NTR Dealership Intro Client]` or `[NTR Dealership Intro Progress]` warnings back into Codex.")

log("Phase 8 complete. Changed fields: " .. tostring(#changed) .. "; attributes added: " .. tostring(#attributesAdded))
print(table.concat(report, "\n"))
