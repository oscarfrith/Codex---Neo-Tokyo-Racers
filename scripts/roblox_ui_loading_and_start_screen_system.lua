-- Neo Tokyo Racers - Loading and Start Screen System
-- Canonical phased installer. Current target: Phase 5 initial loading and the
-- responsive Play/Shop start screen on top of the confirmed Phase 1-4 foundation
-- and confirmed race-staging readiness gate.
--
-- Run once in Roblox Studio Command Bar while in Edit mode.
-- Phase 5 V1.3 preserves the confirmed Grid3x2 repair and replaces only the
-- known isolated initial/start client with config-driven safe-area button
-- placement. It creates no in-game backups.

local MODE = "INSTALL" -- INSTALL or AUDIT

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Studio Edit mode.")

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "NTR Loading System Phase 5 V1.3"
local REVISION = "NTR_LOADING_SYSTEM_PHASE5_START_BUTTON_POSITION_V1_3"
local INITIAL_REVISION = "NTR_LOADING_SYSTEM_PHASE5_INITIAL_START_SCREEN_V1_2_CONFIGURED_BUTTON_POSITION"
local PREVIOUS_INITIAL_REVISION = "NTR_LOADING_SYSTEM_PHASE5_INITIAL_START_SCREEN_V1_1_COMPACT_ICON_BUTTONS"
local LEGACY_INITIAL_REVISION = "NTR_LOADING_SYSTEM_PHASE5_INITIAL_START_SCREEN_V1"
local VIEW_REVISION = "NTR_LOADING_SYSTEM_PHASE1_SCREEN_VIEW_V1_4_GRID_FETCH_STATUS"
local PREVIOUS_VIEW_REVISION = "NTR_LOADING_SYSTEM_PHASE1_SCREEN_VIEW_V1_3"

local function info(message)
	print(("[%s] %s"):format(PHASE, tostring(message)))
end

local function find(root, path)
	local current = root
	for segment in string.gmatch(path, "[^.]+") do
		current = current and current:FindFirstChild(segment)
	end
	return current
end

local function replaceOnce(source, old, new, label)
	local first, last = string.find(source, old, 1, true)
	assert(first, label .. " anchor missing. Refresh the Studio mirror before changing this installer.")
	assert(not string.find(source, old, last + 1, true), label .. " anchor is not unique.")
	return string.sub(source, 1, first - 1) .. new .. string.sub(source, last + 1)
end

local function compile(label, source)
	local fn, problem = loadstring(source, "=" .. label)
	assert(fn, label .. " compile failed: " .. tostring(problem))
end

local function hasCommentMarker(source, marker)
	local _, last = string.find(source, "-- " .. marker, 1, true)
	if not last then return false end
	local boundary = string.sub(source, last + 1, last + 1)
	return boundary == "" or boundary == "\r" or boundary == "\n"
end

local kit = assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"), "ReplicatedStorage.NeoTokyoRacers missing")
local clientModules = assert(find(kit, "Shared.Modules.Client"), "Shared.Modules.Client missing")
local controllerModules = assert(clientModules:FindFirstChild("Controllers"), "Client.Controllers missing")
local driving = assert(controllerModules:FindFirstChild("DrivingControllerV47"), "DrivingControllerV47 missing")
local clientRoot = assert(find(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient"), "NeoTokyoRacersClient missing")
local uiControllers = assert(find(clientRoot, "Controllers.UI"), "NeoTokyoRacersClient.Controllers.UI missing")
local introControllers = assert(find(clientRoot, "Controllers.Intro"), "NeoTokyoRacersClient.Controllers.Intro missing")
local racingControllers = assert(find(clientRoot, "Controllers.Racing"), "NeoTokyoRacersClient.Controllers.Racing missing")
local desktop = assert(uiControllers:FindFirstChild("DesktopFreeRoamHudController_Active"), "Desktop free-roam HUD missing")
local mobile = assert(uiControllers:FindFirstChild("MobileFreeRoamHudController_Active"), "Mobile free-roam HUD missing")
local presentation = assert(uiControllers:FindFirstChild("FreeRoamHudPresentationMode"), "FreeRoamHudPresentationMode missing")
local garageEntrance = assert(introControllers:FindFirstChild("GarageEntranceController_Active"), "GarageEntranceController_Active missing")
local moduleShop = assert(uiControllers:FindFirstChild("ModuleShopUIController"), "ModuleShopUIController missing")
local ownedGarageBrowser = assert(uiControllers:FindFirstChild("OwnedGarageBrowserController"), "OwnedGarageBrowserController missing")
local garageServices = assert(find(ServerScriptService, "NeoTokyoRacers.Services.Garage"), "Server garage services missing")
local ownedGarageManagement = assert(garageServices:FindFirstChild("OwnedGarageManagementRuntime"), "OwnedGarageManagementRuntime missing")
local raceBrowser = assert(racingControllers:FindFirstChild("RaceBrowserClient_Active"), "RaceBrowserClient_Active missing")
local raceTransition = assert(racingControllers:FindFirstChild("RaceTransitionClient_Active"), "RaceTransitionClient_Active missing")
local raceEntry = assert(racingControllers:FindFirstChild("RaceEntryMenuClient_Active"), "RaceEntryMenuClient_Active missing")
local raceSession = assert(racingControllers:FindFirstChild("RaceSessionPresentationController_Active"), "RaceSessionPresentationController_Active missing")
local raceResults = assert(racingControllers:FindFirstChild("RaceTimeTrialResultCoachClient_Active"), "RaceTimeTrialResultCoachClient_Active missing")
local raceTransitionRequest = assert(racingControllers:FindFirstChild("RaceTransitionRequest"), "RaceTransitionRequest missing")

assert(driving:IsA("ModuleScript"), "DrivingControllerV47 must be a ModuleScript")
assert(desktop:IsA("LocalScript"), "DesktopFreeRoamHudController_Active must be a LocalScript")
assert(mobile:IsA("LocalScript"), "MobileFreeRoamHudController_Active must be a LocalScript")
assert(presentation:IsA("BindableEvent"), "FreeRoamHudPresentationMode must be a BindableEvent")
assert(garageEntrance:IsA("LocalScript"), "GarageEntranceController_Active must be a LocalScript")
assert(moduleShop:IsA("ModuleScript"), "ModuleShopUIController must be a ModuleScript")
assert(ownedGarageBrowser:IsA("ModuleScript"), "OwnedGarageBrowserController must be a ModuleScript")
assert(ownedGarageManagement:IsA("ModuleScript"), "OwnedGarageManagementRuntime must be a ModuleScript")
assert(raceBrowser:IsA("LocalScript"), "RaceBrowserClient_Active must be a LocalScript")
assert(raceTransition:IsA("LocalScript"), "RaceTransitionClient_Active must be a LocalScript")
assert(raceEntry:IsA("LocalScript"), "RaceEntryMenuClient_Active must be a LocalScript")
assert(raceSession:IsA("LocalScript"), "RaceSessionPresentationController_Active must be a LocalScript")
assert(raceResults:IsA("LocalScript"), "RaceTimeTrialResultCoachClient_Active must be a LocalScript")
assert(raceTransitionRequest:IsA("BindableEvent"), "RaceTransitionRequest must be a BindableEvent")

for object, marker in pairs({
	[driving] = "NTR_DRIFT_MINI_BOOST_STAT_SCALING_V1",
	[desktop] = "NTR_PC_FREEROAM_UI_PHASE4A_DEALERSHIP_TELEPORT",
	[mobile] = "NTR_MOBILE_FREEROAM_UI_PHASE1O_MAJOR_MENU_SUPPRESSION",
	[garageEntrance] = "NTR_GARAGE_NATIVE_ENTRANCE_PROMPTS_V1",
	[moduleShop] = "NTR_GARAGE_FLOW_REFINEMENT_V2",
	[ownedGarageBrowser] = "NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V3_ASYNC_OPEN",
	[ownedGarageManagement] = "NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V7_VERIFIED_TRANSITIONS",
	[raceBrowser] = "NTR_RACING_PHASE8D_BROWSER_TELEPORT_FADE",
	[raceTransition] = "NTR_RACING_PHASE8H_TRANSITION_CLIENT",
	[raceEntry] = "NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP",
	[raceSession] = "NTR_RACING_UI_PHASE16A_SHARED_IN_RACE_HUD",
	[raceResults] = "NTR_RACING_UI_PHASE11_UNIFIED_RESULTS_PRESENTATION",
}) do
	assert(string.find(object.Source, marker, 1, true), object.Name .. " is missing confirmed marker " .. marker)
end

local INPUT_GATE_SOURCE = [=[
-- NTR_LOADING_SYSTEM_PHASE1_GAMEPLAY_INPUT_GATE_V1
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Gate = {}
local player = Players.LocalPlayer
local tokens = {}
local nextToken = 0
local pendingNeutral = false
local neutralGeneration = 0
local controls = nil

local watchedKeys = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
	Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift,
}
local watchedGamepad = {
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonB] = true,
	[Enum.KeyCode.ButtonL2] = true,
	[Enum.KeyCode.ButtonR2] = true,
	[Enum.KeyCode.ButtonY] = true,
}

local function mobileState()
	local parent = script.Parent and script.Parent.Parent
	local controllers = parent and parent:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("MobileDriveInputState")
	if not (module and module:IsA("ModuleScript")) then return nil end
	local ok, value = pcall(require, module)
	return ok and type(value) == "table" and value or nil
end

local function resetMobile()
	local state = mobileState()
	if state and type(state.Reset) == "function" then pcall(state.Reset) end
end

local function resolveControls()
	if controls then return controls end
	local playerScripts = player and player:FindFirstChild("PlayerScripts")
	local playerModule = playerScripts and playerScripts:FindFirstChild("PlayerModule")
	if not playerModule then return nil end
	local ok, module = pcall(require, playerModule)
	if not ok or type(module) ~= "table" or type(module.GetControls) ~= "function" then return nil end
	local got, result = pcall(function() return module:GetControls() end)
	if got then controls = result end
	return controls
end

local function disableControls()
	resetMobile()
	local current = resolveControls()
	if current and type(current.Disable) == "function" then pcall(function() current:Disable() end) end
end

local function enableControls()
	resetMobile()
	local current = resolveControls()
	if current and type(current.Enable) == "function" then pcall(function() current:Enable() end) end
end

local function tokenCount()
	local count = 0
	for _ in pairs(tokens) do count += 1 end
	return count
end

local function inputsNeutral()
	for _, key in ipairs(watchedKeys) do
		if UserInputService:IsKeyDown(key) then return false end
	end
	for _, input in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
		if watchedGamepad[input.KeyCode] and input.Position.Z > 0.12 then return false end
		if input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.12 then return false end
	end
	return true
end

local function finishNeutralWait(generation)
	if generation ~= neutralGeneration or tokenCount() > 0 then return end
	pendingNeutral = false
	enableControls()
end

local function beginNeutralWait()
	neutralGeneration += 1
	local generation = neutralGeneration
	pendingNeutral = true
	task.spawn(function()
		local deadline = os.clock() + 5
		repeat
			if generation ~= neutralGeneration or tokenCount() > 0 then return end
			if inputsNeutral() then finishNeutralWait(generation) return end
			task.wait(0.05)
		until os.clock() >= deadline
		finishNeutralWait(generation)
	end)
end

function Gate.Acquire(owner, generation)
	nextToken += 1
	local token = ("%s:%s:%d"):format(tostring(owner or "Unknown"), tostring(generation or "0"), nextToken)
	tokens[token] = true
	neutralGeneration += 1
	pendingNeutral = false
	disableControls()
	return token
end

function Gate.Release(token, requireNeutral)
	if token then tokens[token] = nil end
	resetMobile()
	if tokenCount() > 0 then return false end
	if requireNeutral ~= false and not inputsNeutral() then
		beginNeutralWait()
	else
		pendingNeutral = false
		enableControls()
	end
	return true
end

function Gate.IsLocked()
	return tokenCount() > 0 or pendingNeutral
end

function Gate.ResetMobileState()
	resetMobile()
end

function Gate.ActiveCount()
	return tokenCount()
end

return Gate
]=]

local AUDIO_MIXER_SOURCE = [=[
-- NTR_LOADING_SYSTEM_PHASE1_AUDIO_MIXER_V1_1
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Mixer = {}
local started = false
local config = nil
local activeGeneration = 0
local active = false
local operationPending = false
local tweens = {}
local loadingSound = nil

local gameplayGroups = {
	"NTR_GameplayMusic",
	"NTR_Vehicle",
	"NTR_Ambience",
	"NTR_GameplaySFX",
}

local function number(name, fallback)
	local value = config and config:GetAttribute(name)
	return tonumber(value) or fallback
end

local function text(name, fallback)
	local value = config and config:GetAttribute(name)
	return type(value) == "string" and value or fallback
end

local function group(name)
	local item = SoundService:FindFirstChild(name)
	return item and item:IsA("SoundGroup") and item or nil
end

local function tweenVolume(item, target, duration)
	if not item then return end
	if tweens[item] then tweens[item]:Cancel() end
	local tween = TweenService:Create(item, TweenInfo.new(math.max(0, duration), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = target })
	tweens[item] = tween
	tween:Play()
	tween.Completed:Once(function() if tweens[item] == tween then tweens[item] = nil end end)
end

local function assetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

function Mixer.Start(configuration)
	config = configuration or config
	if started then return Mixer end
	started = true
	local loadingGroup = group("NTR_LoadingMusic")
	if loadingGroup then loadingGroup.Volume = 0 end
	loadingSound = Instance.new("Sound")
	loadingSound.Name = "NTR_LoadingMusic_Runtime"
	loadingSound.Looped = true
	loadingSound.Volume = 1
	loadingSound.SoundGroup = loadingGroup
	loadingSound.Parent = SoundService
	return Mixer
end

function Mixer.Begin(generation)
	activeGeneration = tonumber(generation) or (activeGeneration + 1)
	local thisGeneration = activeGeneration
	active = true
	operationPending = true
	for _, name in ipairs(gameplayGroups) do
		tweenVolume(group(name), number("GameplayDuckVolume", 0), number("GameplayAudioDuckSeconds", 0.25))
	end
	task.delay(math.max(0, number("LoadingMusicStartDelaySeconds", 0.9)), function()
		if not active or not operationPending or thisGeneration ~= activeGeneration or not loadingSound then return end
		local id = assetId(text("LoadingMusicAssetId", ""))
		if id == "" then return end
		loadingSound.SoundId = id
		if not loadingSound.IsPlaying then pcall(function() loadingSound:Play() end) end
		tweenVolume(group("NTR_LoadingMusic"), number("LoadingMusicVolume", 0.55), number("LoadingMusicFadeInSeconds", 0.5))
	end)
	return thisGeneration
end

function Mixer.MarkReady(generation)
	if tonumber(generation) ~= activeGeneration then return false end
	operationPending = false
	return true
end

function Mixer.Finish(generation, duration)
	if tonumber(generation) ~= activeGeneration then return false end
	active = false
	operationPending = false
	local fade = math.max(0, tonumber(duration) or number("FadeOutSeconds", 0.3))
	tweenVolume(group("NTR_LoadingMusic"), 0, fade)
	for _, name in ipairs(gameplayGroups) do
		tweenVolume(group(name), number(name .. "BaseVolume", 1), fade)
	end
	local thisGeneration = activeGeneration
	task.delay(fade + 0.05, function()
		if thisGeneration == activeGeneration and not active and loadingSound then pcall(function() loadingSound:Stop() end) end
	end)
	return true
end

function Mixer.IsActive()
	return active
end

return Mixer
]=]

local ARTWORK_CATALOG_SOURCE = [=[
-- NTR_LOADING_SYSTEM_PHASE1_ARTWORK_CATALOG_V1_2
local Catalog = {}
local rng = Random.new()
local bags = {}

local function normalizedAssetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

local function supportsDestination(csv, destination)
	local requested = string.lower(tostring(destination or ""))
	for item in string.gmatch(tostring(csv or "*"), "[^,]+") do
		local value = string.lower((string.gsub(item, "^%s*(.-)%s*$", "%1")))
		if value == "*" or value == requested then return true end
	end
	return false
end

local function tileSet(item, layout)
	local columns = math.clamp(math.floor(tonumber(item:GetAttribute("Columns")) or 3), 1, 4)
	local rows = math.clamp(math.floor(tonumber(item:GetAttribute("Rows")) or 2), 1, 3)
	if layout == "Grid3x2" then columns, rows = 3, 2 end
	if layout ~= "Grid3x2" then return {}, columns, rows, false end
	local result = {}
	local complete = layout == "Grid3x2"
	local root = item:FindFirstChild("Tiles")
	for row = 1, rows do
		for column = 1, columns do
			local name = ("R%dC%d"):format(row, column)
			local tile = root and root:FindFirstChild(name)
			local imageAssetId = normalizedAssetId(tile and tile:GetAttribute("ImageAssetId"))
			if imageAssetId == "" then complete = false end
			table.insert(result, { Name = name, Row = row, Column = column, ImageAssetId = imageAssetId })
		end
	end
	return result, columns, rows, complete
end

local function entries(config, destination)
	local artworkRoot = config and config:FindFirstChild("Artworks")
	local result = {}
	for _, item in ipairs(artworkRoot and artworkRoot:GetChildren() or {}) do
		if item:IsA("Folder") and item:GetAttribute("Enabled") ~= false and supportsDestination(item:GetAttribute("Destinations"), destination) then
			local layout = tostring(item:GetAttribute("Layout") or "Single")
			local tiles, columns, rows, gridReady = tileSet(item, layout)
			table.insert(result, {
				ArtworkId = tostring(item:GetAttribute("ArtworkId") or item.Name),
				ImageAssetId = normalizedAssetId(item:GetAttribute("ImageAssetId")),
				Weight = math.max(0.01, tonumber(item:GetAttribute("Weight")) or 1),
				FocalPointX = math.clamp(tonumber(item:GetAttribute("FocalPointX")) or 0.5, 0, 1),
				FocalPointY = math.clamp(tonumber(item:GetAttribute("FocalPointY")) or 0.5, 0, 1),
				MotionPreset = tostring(item:GetAttribute("MotionPreset") or "SlowPanRight"),
				Layout = layout,
				Columns = columns,
				Rows = rows,
				AspectRatio = math.clamp(tonumber(item:GetAttribute("AspectRatio")) or (16 / 9), 0.5, 3),
				Tiles = tiles,
				GridReady = gridReady,
				StartScreenEligible = item:GetAttribute("StartScreenEligible") == true,
			})
		end
	end
	table.sort(result, function(a, b) return a.ArtworkId < b.ArtworkId end)
	return result
end

local function signature(items)
	local ids = {}
	for _, item in ipairs(items) do
		local tileIds = {}
		for _, tile in ipairs(item.Tiles or {}) do table.insert(tileIds, tile.ImageAssetId) end
		table.insert(ids, table.concat({ item.ArtworkId, tostring(item.Weight), item.Layout, table.concat(tileIds, ",") }, ":"))
	end
	return table.concat(ids, "|")
end

local function refill(destination, items, previousId)
	local weighted = {}
	for _, item in ipairs(items) do
		local key = rng:NextNumber() ^ (1 / item.Weight)
		table.insert(weighted, { Key = key, Entry = item })
	end
	table.sort(weighted, function(a, b) return a.Key > b.Key end)
	local bag = {}
	for _, item in ipairs(weighted) do table.insert(bag, item.Entry) end
	if #bag > 1 and bag[1].ArtworkId == previousId then bag[1], bag[2] = bag[2], bag[1] end
	bags[destination] = { Signature = signature(items), Entries = bag }
	return bags[destination]
end

function Catalog.Choose(config, destination, previousId)
	destination = tostring(destination or "Default")
	local available = entries(config, destination)
	if #available == 0 then
		return { ArtworkId = "FallbackBlack", ImageAssetId = "", Weight = 1, FocalPointX = 0.5, FocalPointY = 0.5, MotionPreset = "None", Layout = "Single", Columns = 1, Rows = 1, AspectRatio = 16 / 9, Tiles = {}, GridReady = false }
	end
	local bag = bags[destination]
	if not bag or bag.Signature ~= signature(available) or #bag.Entries == 0 then bag = refill(destination, available, previousId) end
	return table.remove(bag.Entries, 1)
end

function Catalog.List(config, destination)
	return entries(config, destination)
end

return Catalog
]=]

local VIEW_SOURCE = [=[
-- NTR_LOADING_SYSTEM_PHASE1_SCREEN_VIEW_V1_4_GRID_FETCH_STATUS
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local View = {}
View.__index = View

local function new(className, properties, parent)
	local item = Instance.new(className)
	for key, value in pairs(properties or {}) do item[key] = value end
	item.Parent = parent
	return item
end

local function color(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item:IsA("Color3Value") and item.Value or fallback
end

function View.Create(playerGui, config, colours)
	local self = setmetatable({}, View)
	self.Config = config
	self.Tweens = {}
	self.MotionTween = nil
	self.ProgressTween = nil
	self.GridImages = {}
	self.ArtworkGeneration = 0
	self.Fading = false

	local displayOrder = tonumber(config:GetAttribute("DisplayOrder")) or 1000
	local backgroundGui = new("ScreenGui", { Name = "NTR_LoadingBackground", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = displayOrder, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false }, playerGui)
	pcall(function() backgroundGui.ScreenInsets = Enum.ScreenInsets.None end)
	local background = new("Frame", { Name = "BlackBacking", Active = true, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, backgroundGui)
	local artworkClip = new("Frame", { Name = "ArtworkClip", Active = false, BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, background)
	local artworkMotion = new("Frame", { Name = "ArtworkMotion", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.08, 1.08), ZIndex = 2 }, artworkClip)
	local artwork = new("ImageLabel", { Name = "SingleArtwork", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Image = "", ImageTransparency = 0, Position = UDim2.fromScale(0.5, 0.5), ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, artworkMotion)
	local gridComposite = new("Frame", { Name = "GridArtwork", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3 }, artworkMotion)
	local blocker = new("TextButton", { Name = "InputBlocker", Active = true, AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0, Modal = true, Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 10 }, background)

	local safeGui = new("ScreenGui", { Name = "NTR_LoadingSafeContent", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = displayOrder + 1, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false }, playerGui)
	pcall(function() safeGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets end)
	local safeRoot = new("Frame", { Name = "SafeRoot", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 20 }, safeGui)
	local status = new("TextLabel", { Name = "Status", AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.Michroma, Position = UDim2.fromScale(0.5, 0.79), Size = UDim2.new(0.72, 0, 0, 34), Text = "LOADING", TextColor3 = color(colours, "Text", Color3.fromRGB(246, 248, 252)), TextSize = 15, TextTransparency = 0, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 22 }, safeRoot)
	local statusConstraint = new("UISizeConstraint", { MinSize = Vector2.new(220, 34), MaxSize = Vector2.new(820, 34) }, status)
	statusConstraint.Name = "StatusWidthConstraint"
	local track = new("Frame", { Name = "ProgressTrack", AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = color(colours, "PanelSoft", Color3.fromRGB(24, 29, 36)), BackgroundTransparency = 0, BorderSizePixel = 0, ClipsDescendants = true, Position = UDim2.fromScale(0.5, 0.81), Size = UDim2.new(0.58, 0, 0, 22), ZIndex = 22 }, safeRoot)
	new("UISizeConstraint", { MinSize = Vector2.new(220, 22), MaxSize = Vector2.new(720, 22) }, track)
	new("UICorner", { CornerRadius = UDim.new(0, 9) }, track)
	local fill = new("Frame", { Name = "ProgressFill", BackgroundColor3 = color(colours, "Telemetry", Color3.fromRGB(43, 225, 218)), BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 23 }, track)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, fill)
	new("UIGradient", { Color = ColorSequence.new(color(colours, "ElectricBlue", Color3.fromRGB(25, 116, 255)), color(colours, "Telemetry", Color3.fromRGB(43, 225, 218))), Rotation = 0 }, fill)

	self.BackgroundGui = backgroundGui
	self.SafeGui = safeGui
	self.Background = background
	self.ArtworkClip = artworkClip
	self.ArtworkMotion = artworkMotion
	self.Artwork = artwork
	self.GridComposite = gridComposite
	self.Blocker = blocker
	self.Status = status
	self.Track = track
	self.Fill = fill
	self.SizeConnection = artworkClip:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_UpdateCompositeCover()
	end)
	return self
end

function View:_UpdateCompositeCover()
	if not self.GridComposite then return end
	local size = self.ArtworkClip.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then return end
	local viewportAspect = size.X / size.Y
	local sourceAspect = tonumber(self.Entry and self.Entry.AspectRatio) or (16 / 9)
	if viewportAspect >= sourceAspect then
		self.GridComposite.Size = UDim2.fromScale(1, viewportAspect / sourceAspect)
	else
		self.GridComposite.Size = UDim2.fromScale(sourceAspect / viewportAspect, 1)
	end
end

function View:_EnsureGridImages(count)
	while #self.GridImages < count do
		local image = new("ImageLabel", {
			Name = "Tile",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = "",
			ImageTransparency = 0,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 3,
		}, self.GridComposite)
		pcall(function() image.ResampleMode = Enum.ResamplerMode.Default end)
		table.insert(self.GridImages, image)
	end
	for index, image in ipairs(self.GridImages) do
		image.Visible = index <= count
		if index > count then image.Image = "" end
	end
end

local function allLoaded(images, count)
	for index = 1, count do
		if not images[index].IsLoaded then return false end
	end
	return true
end

local function fetchStatusName(contentId)
	local ok, status = pcall(function() return ContentProvider:GetAssetFetchStatus(contentId) end)
	return ok and status and status.Name or "Unknown"
end

local function failedTiles(tiles, resolved)
	local failures = {}
	for _, tile in ipairs(tiles or {}) do
		local status = resolved[tile.ImageAssetId]
		if status ~= "Success" then
			table.insert(failures, ("%s=%s(%s)"):format(tile.Name, tostring(status or fetchStatusName(tile.ImageAssetId)), tile.ImageAssetId))
		end
	end
	return failures
end

function View:SetArtwork(entry)
	self.ArtworkGeneration += 1
	local generation = self.ArtworkGeneration
	self.Fading = false
	self.Entry = entry
	self.Artwork.Image = tostring(entry and entry.ImageAssetId or "")
	local focalPoint = Vector2.new(tonumber(entry and entry.FocalPointX) or 0.5, tonumber(entry and entry.FocalPointY) or 0.5)
	self.Artwork.AnchorPoint = focalPoint
	self.Artwork.Position = UDim2.fromScale(0.5, 0.5)
	self.Artwork.Visible = self.Artwork.Image ~= ""
	self.GridComposite.AnchorPoint = focalPoint
	self.GridComposite.Position = UDim2.fromScale(0.5, 0.5)
	self.GridComposite.Visible = false
	self:_UpdateCompositeCover()

	local tiles = entry and entry.Tiles or {}
	local columns = math.max(1, tonumber(entry and entry.Columns) or 3)
	local rows = math.max(1, tonumber(entry and entry.Rows) or 2)
	self:_EnsureGridImages(#tiles)
	local overlap = math.clamp(tonumber(self.Config:GetAttribute("GridOverlapPixels")) or 1, 0, 4)
	for index, tile in ipairs(tiles) do
		local image = self.GridImages[index]
		image.Name = tostring(tile.Name or ("Tile%02d"):format(index))
		image.Image = tostring(tile.ImageAssetId or "")
		image.Position = UDim2.new((tile.Column - 1) / columns, -overlap, (tile.Row - 1) / rows, -overlap)
		image.Size = UDim2.new(1 / columns, overlap * 2, 1 / rows, overlap * 2)
		image.ImageTransparency = 0
	end

	if entry and entry.Layout == "Grid3x2" and entry.GridReady == true and #tiles == 6 then
		local targets = {}
		for index = 1, #tiles do table.insert(targets, self.GridImages[index]) end
		task.spawn(function()
			local attempts = math.clamp(math.floor(tonumber(self.Config:GetAttribute("GridPreloadAttempts")) or 2), 1, 4)
			local retryDelay = math.clamp(tonumber(self.Config:GetAttribute("GridPreloadRetrySeconds")) or 0.25, 0, 2)
			local fetched = false
			local lastFailures = {}
			for attempt = 1, attempts do
				local resolved = {}
				local ok, problem = pcall(function()
					ContentProvider:PreloadAsync(targets, function(contentId, fetchStatus)
						resolved[tostring(contentId)] = fetchStatus and fetchStatus.Name or "Unknown"
					end)
				end)
				lastFailures = failedTiles(tiles, resolved)
				if ok and #lastFailures == 0 then fetched = true; break end
				warn(("[NTR Loading Grid] artwork=%s attempt=%d/%d preload=%s failures=%s"):format(
					tostring(entry.ArtworkId), attempt, attempts, ok and "completed" or tostring(problem), table.concat(lastFailures, ", ")))
				if attempt < attempts and retryDelay > 0 then task.wait(retryDelay) end
			end
			if generation ~= self.ArtworkGeneration or self.Fading then return end
			if not fetched then
				warn(("[NTR Loading Grid] artwork=%s retained single fallback; unresolved tiles=%s"):format(tostring(entry.ArtworkId), table.concat(lastFailures, ", ")))
				return
			end

			-- Render the fetched grid behind the opaque single fallback first. This
			-- avoids the documented hidden-ImageLabel unload race before promotion.
			self.GridComposite.Visible = true
			local deadline = os.clock() + math.clamp(tonumber(self.Config:GetAttribute("GridPromotionWaitSeconds")) or 3, 0.25, 8)
			while generation == self.ArtworkGeneration and not self.Fading and os.clock() < deadline and not allLoaded(self.GridImages, #tiles) do
				RunService.RenderStepped:Wait()
			end
			if generation ~= self.ArtworkGeneration or self.Fading then return end
			if allLoaded(self.GridImages, #tiles) then
				self.Artwork.Visible = false
				print(("[NTR Loading Grid] artwork=%s promoted Grid3x2 composite."):format(tostring(entry.ArtworkId)))
			else
				self.GridComposite.Visible = false
				local unresolved = {}
				for index, tile in ipairs(tiles) do
					if not self.GridImages[index].IsLoaded then table.insert(unresolved, tile.Name .. "=" .. fetchStatusName(tile.ImageAssetId)) end
				end
				warn(("[NTR Loading Grid] artwork=%s retained single fallback after render deadline; unresolved=%s"):format(tostring(entry.ArtworkId), table.concat(unresolved, ", ")))
			end
		end)
	elseif entry and entry.Layout == "Grid3x2" then
		warn(("[NTR Loading Grid] artwork=%s grid config incomplete; retaining single fallback."):format(tostring(entry.ArtworkId)))
	end
end

function View:Warm(entries, limit)
	limit = math.max(0, math.floor(tonumber(limit) or 0))
	if limit == 0 then return end
	task.spawn(function()
		for index = 1, math.min(limit, #(entries or {})) do
			local entry = entries[index]
			local temporary = {}
			local function add(imageAssetId)
				if tostring(imageAssetId or "") == "" then return end
				local image = Instance.new("ImageLabel")
				image.Image = tostring(imageAssetId)
				table.insert(temporary, image)
			end
			add(entry.ImageAssetId)
			if entry.GridReady then for _, tile in ipairs(entry.Tiles or {}) do add(tile.ImageAssetId) end end
			if #temporary > 0 then pcall(function() ContentProvider:PreloadAsync(temporary) end) end
			for _, image in ipairs(temporary) do image:Destroy() end
		end
	end)
end

function View:Show(statusText)
	if self.ProgressTween then self.ProgressTween:Cancel(); self.ProgressTween = nil end
	if self.MotionTween then self.MotionTween:Cancel(); self.MotionTween = nil end
	self.Fading = false
	self.Background.BackgroundTransparency = 0
	self.Artwork.ImageTransparency = 0
	for _, image in ipairs(self.GridImages) do image.ImageTransparency = 0 end
	self.Status.TextTransparency = 0
	self.Track.BackgroundTransparency = 0
	self.Fill.BackgroundTransparency = 0
	self.Fill.Size = UDim2.fromScale(0, 1)
	self.Status.Text = tostring(statusText or "LOADING")
	local startScale = tonumber(self.Config:GetAttribute("MotionStartScale")) or 1.06
	self.ArtworkMotion.Position = UDim2.fromScale(0.5, 0.5)
	self.ArtworkMotion.Size = UDim2.fromScale(startScale, startScale)
	self.BackgroundGui.Enabled = true
	self.SafeGui.Enabled = true
	self.Blocker.Active = true
end

function View:SetStatus(text)
	self.Status.Text = tostring(text or "LOADING")
end

function View:SetProgress(value, duration)
	value = math.clamp(tonumber(value) or 0, 0, 1)
	if self.ProgressTween then self.ProgressTween:Cancel() end
	self.ProgressTween = TweenService:Create(self.Fill, TweenInfo.new(math.max(0.03, tonumber(duration) or 0.18), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(value, 1) })
	self.ProgressTween:Play()
end

function View:SetProgressImmediate(value)
	value = math.clamp(tonumber(value) or 0, 0, 1)
	if self.ProgressTween then self.ProgressTween:Cancel(); self.ProgressTween = nil end
	self.Fill.Size = UDim2.fromScale(value, 1)
end

function View:StartMotion(enabled)
	if self.MotionTween then self.MotionTween:Cancel(); self.MotionTween = nil end
	if not enabled or not self.Entry or self.Entry.MotionPreset == "None" then return end
	local startScale = tonumber(self.Config:GetAttribute("MotionStartScale")) or 1.06
	local endScale = tonumber(self.Config:GetAttribute("MotionEndScale")) or 1.10
	local travel = tonumber(self.Config:GetAttribute("MotionTravelPercent")) or 0.012
	local duration = tonumber(self.Config:GetAttribute("MotionDurationSeconds")) or 5
	local targetX, targetY = 0.5 + travel, 0.5
	if self.Entry.MotionPreset == "SlowPanLeft" then targetX = 0.5 - travel
	elseif self.Entry.MotionPreset == "SlowPanUp" then targetX, targetY = 0.5, 0.5 - travel
	elseif self.Entry.MotionPreset == "SlowPanDown" then targetX, targetY = 0.5, 0.5 + travel
	elseif self.Entry.MotionPreset == "SlowZoom" then targetX, targetY = 0.5, 0.5 end
	self.ArtworkMotion.Size = UDim2.fromScale(startScale, startScale)
	self.MotionTween = TweenService:Create(self.ArtworkMotion, TweenInfo.new(math.max(1, duration), Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, true), { Position = UDim2.fromScale(targetX, targetY), Size = UDim2.fromScale(endScale, endScale) })
	self.MotionTween:Play()
end

function View:FadeOut(duration)
	duration = math.max(0.03, tonumber(duration) or 0.3)
	self.Fading = true
	if self.ProgressTween then self.ProgressTween:Cancel(); self.ProgressTween = nil end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweens = {
		TweenService:Create(self.Background, info, { BackgroundTransparency = 1 }),
		TweenService:Create(self.Artwork, info, { ImageTransparency = 1 }),
		TweenService:Create(self.Status, info, { TextTransparency = 1 }),
		TweenService:Create(self.Track, info, { BackgroundTransparency = 1 }),
		TweenService:Create(self.Fill, info, { BackgroundTransparency = 1 }),
	}
	for _, image in ipairs(self.GridImages) do table.insert(tweens, TweenService:Create(image, info, { ImageTransparency = 1 })) end
	for _, tween in ipairs(tweens) do tween:Play() end
	tweens[1].Completed:Wait()
end

function View:Hide()
	if self.MotionTween then self.MotionTween:Cancel(); self.MotionTween = nil end
	self.ArtworkGeneration += 1
	self.Blocker.Active = false
	self.BackgroundGui.Enabled = false
	self.SafeGui.Enabled = false
end

function View:Destroy()
	if self.SizeConnection then self.SizeConnection:Disconnect(); self.SizeConnection = nil end
	if self.BackgroundGui then self.BackgroundGui:Destroy() end
	if self.SafeGui then self.SafeGui:Destroy() end
end

return View
]=]

local RUNTIME_SOURCE = [=[
-- NTR_LOADING_SYSTEM_PHASE1_TRANSITION_RUNTIME_V1_2
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local packageFolder = ReplicatedFirst:WaitForChild("NTRLoading")
local Catalog = require(packageFolder:WaitForChild("LoadingArtworkCatalog"))
local View = require(packageFolder:WaitForChild("LoadingScreenView"))

local Runtime = {}
local singleton = nil

local function waitRenderedFrames(count)
	for _ = 1, count do RunService.RenderStepped:Wait() end
end

local function smoothstep(value)
	local alpha = math.clamp(tonumber(value) or 0, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

local function automaticProgress(elapsed, minimum)
	local firstStage = math.max(0.05, minimum * 0.8)
	if elapsed <= firstStage then
		return 0.02 + (0.85 - 0.02) * smoothstep(elapsed / firstStage)
	end
	if elapsed <= minimum then
		return 0.85 + (0.94 - 0.85) * smoothstep((elapsed - firstStage) / math.max(0.05, minimum - firstStage))
	end
	return 0.94 + 0.04 * (1 - math.exp(-(elapsed - minimum) * 0.22))
end

function Runtime.Start(options)
	if singleton then return singleton end
	options = options or {}
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("LoadingSystem")
	local colours = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("DesktopFreeRoamHud"):WaitForChild("Colours")
	local inputGate = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Input"):WaitForChild("GameplayInputGate"))
	local audioMixer = require(kit.Shared.Modules.Client:WaitForChild("Audio"):WaitForChild("AudioMixController"))
	local uiFolder = options.UIFolder or error("UIFolder required")
	local presentationEvent = uiFolder:WaitForChild("FreeRoamHudPresentationMode")
	local presentationState = uiFolder:WaitForChild("LoadingPresentationState")
	local presentationChanged = uiFolder:WaitForChild("LoadingPresentationChanged")
	local view = View.Create(playerGui, config, colours)
	local api = {}
	local generation = 0
	local current = nil
	local previousArtworkId = nil

	audioMixer.Start(config)
	view:Warm(Catalog.List(config, "Default"), tonumber(config:GetAttribute("WarmPoolSize")) or 2)

	local function publish(active, fadeStarted, destination, reason)
		presentationState:SetAttribute("Active", active == true)
		presentationState:SetAttribute("Generation", current and current.Generation or generation)
		presentationState:SetAttribute("Destination", tostring(destination or (current and current.Destination) or ""))
		presentationState:SetAttribute("FadeStarted", fadeStarted == true)
		presentationState:SetAttribute("Reason", tostring(reason or ""))
		presentationChanged:Fire({ Active = active == true, FadeStarted = fadeStarted == true, Generation = current and current.Generation or generation, Destination = destination or (current and current.Destination), Reason = reason })
	end

	local function suppress(active)
		presentationEvent:Fire({ Owner = "LoadingTransition", Active = active == true, KeepTelemetry = false })
	end

	local function releaseCurrent(requireNeutral)
		if not current then return end
		local token = current.InputToken
		current = nil
		if token then inputGate.Release(token, requireNeutral ~= false) end
	end

	local function begin(payload)
		payload = type(payload) == "table" and payload or {}
		if current then return current.Generation end
		generation += 1
		local destination = tostring(payload.Destination or "Default")
		local artwork = Catalog.Choose(config, destination, previousArtworkId)
		previousArtworkId = artwork.ArtworkId
		current = {
			Generation = generation,
			Destination = destination,
			StartedAt = os.clock(),
			InputToken = inputGate.Acquire("LoadingTransition", generation),
			DisplayProgress = 0.02,
			ReportedProgress = 0.02,
			Completing = false,
		}
		view:SetArtwork(artwork)
		view:Show(payload.Status or "LOADING")
		view:SetProgressImmediate(0.02)
		view:StartMotion(config:GetAttribute("MotionEnabled") ~= false and payload.StartScreen ~= true)
		suppress(true)
		publish(true, false, destination, "Begin")
		audioMixer.Begin(generation)

		local thisGeneration = generation
		task.spawn(function()
			local lastStep = os.clock()
			while current and current.Generation == thisGeneration do
				RunService.RenderStepped:Wait()
				if not current or current.Generation ~= thisGeneration then return end
				if not current.Completing then
					local now = os.clock()
					local elapsed = now - current.StartedAt
					local minimum = math.max(0.1, tonumber(config:GetAttribute("MinimumVisibleSeconds")) or 1.5)
					local target = math.max(automaticProgress(elapsed, minimum), math.min(0.98, current.ReportedProgress or 0))
					local delta = math.max(0, now - lastStep)
					local reportedBlend = math.min(1, delta * 5)
					local smoothedTarget = current.DisplayProgress + (target - current.DisplayProgress) * reportedBlend
					current.DisplayProgress = math.max(current.DisplayProgress, automaticProgress(elapsed, minimum), smoothedTarget)
					view:SetProgressImmediate(current.DisplayProgress)
					lastStep = now
				end
			end
		end)
		task.delay(math.max(1, tonumber(config:GetAttribute("TimeoutSeconds")) or 12), function()
			if current and current.Generation == thisGeneration then
				api:Handle("Fail", { Generation = thisGeneration, Status = "TRANSITION TIMED OUT", Reason = "Timeout" })
			end
		end)
		return generation
	end

	local function finish(payload, success)
		payload = type(payload) == "table" and payload or {}
		if not current or tonumber(payload.Generation) ~= current.Generation then return false, "StaleGeneration" end
		local finishing = current
		audioMixer.MarkReady(finishing.Generation)
		local readyHold = math.max(0, tonumber(config:GetAttribute("ReadyHoldSeconds")) or 0.06)
		local minimum = math.max(0.1, tonumber(config:GetAttribute("MinimumVisibleSeconds")) or 1.5)
		local completionFill = math.max(0.05, tonumber(config:GetAttribute("CompletionFillSeconds")) or 0.2)
		local remaining = math.max(0, minimum - completionFill - (os.clock() - finishing.StartedAt))
		if remaining > 0 then task.wait(remaining) end
		if not current or current.Generation ~= finishing.Generation then return false, "Superseded" end
		finishing.Completing = true
		view:SetStatus(payload.Status or (success and "READY" or "RETURNING"))
		view:SetProgress(1, completionFill)
		task.wait(completionFill + readyHold)
		if not current or current.Generation ~= finishing.Generation then return false, "Superseded" end
		publish(true, true, finishing.Destination, success and "Ready" or tostring(payload.Reason or "Failed"))
		suppress(false)
		local fade = math.max(0.03, tonumber(config:GetAttribute("FadeOutSeconds")) or 0.3)
		audioMixer.Finish(finishing.Generation, fade)
		waitRenderedFrames(2)
		view:FadeOut(fade)
		view:Hide()
		publish(false, false, finishing.Destination, success and "Complete" or tostring(payload.Reason or "Failed"))
		releaseCurrent(true)
		return true
	end

	function api:Handle(action, payload)
		action = tostring(action or "")
		if action == "Begin" then return begin(payload)
		elseif action == "Progress" then
			if not current or tonumber(payload and payload.Generation) ~= current.Generation then return false end
			current.ReportedProgress = math.max(current.ReportedProgress, math.clamp(tonumber(payload.Progress) or 0, 0, 0.98))
			if payload.Status then view:SetStatus(payload.Status) end
			return true
		elseif action == "Complete" then return finish(payload, true)
		elseif action == "Fail" or action == "Cancel" then return finish(payload, false)
		elseif action == "GetState" then
			return { Active = current ~= nil, Generation = current and current.Generation or generation, Destination = current and current.Destination or "", InputLocked = inputGate.IsLocked(), AudioActive = audioMixer.IsActive() }
		end
		return false, "UnknownAction"
	end

	singleton = api
	return api
end

return Runtime
]=]

local CONTROLLER_SOURCE = [=[
-- NTR_LOADING_SYSTEM_PHASE1_CONTROLLER_V1
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local runtime = require(ReplicatedFirst:WaitForChild("NTRLoading"):WaitForChild("LoadingTransitionRuntime"))
local api = runtime.Start({ UIFolder = script.Parent })
local invoke = script.Parent:WaitForChild("LoadingTransitionInvoke")

invoke.OnInvoke = function(action, payload)
	local ok, a, b = pcall(function() return api:Handle(action, payload) end)
	if ok then return a, b end
	warn("[NTR Loading System Phase 1] " .. tostring(action) .. " failed: " .. tostring(a))
	return false, tostring(a)
end

script.Parent.LoadingPresentationState:SetAttribute("ControllerReady", true)
print("[NTR Loading System Phase 1] Runtime controller ready.")
]=]

local INITIAL_START_SCREEN_SOURCE = [=[
-- NTR_LOADING_SYSTEM_PHASE5_INITIAL_START_SCREEN_V1_2_CONFIGURED_BUTTON_POSITION
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = player:WaitForChild("PlayerGui")
local playerScripts = player:WaitForChild("PlayerScripts")
local packageFolder = script.Parent
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config = kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("LoadingSystem")

if config:GetAttribute("StartScreenEnabled") == false then
	ReplicatedFirst:RemoveDefaultLoadingScreen()
	return
end

local clientRoot = playerScripts:WaitForChild("NeoTokyoRacersClient")
local uiFolder = clientRoot:WaitForChild("Controllers"):WaitForChild("UI")
local Runtime = require(packageFolder:WaitForChild("LoadingTransitionRuntime"))
local UI = require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))
local api = Runtime.Start({ UIFolder = uiFolder })

local startedAt = os.clock()
local originalTimeout = config:GetAttribute("TimeoutSeconds")
local eligibility = {}
local artworkRoot = config:FindFirstChild("Artworks")
for _, artwork in ipairs(artworkRoot and artworkRoot:GetChildren() or {}) do
	if artwork:IsA("Folder") and artwork:GetAttribute("StartScreenEligible") ~= true then
		local enabled = artwork:GetAttribute("Enabled")
		eligibility[artwork] = { Had = enabled ~= nil, Value = enabled }
		artwork:SetAttribute("Enabled", false)
	end
end
config:SetAttribute("TimeoutSeconds", 86400)
local beginOk, generation = pcall(function()
	return api:Handle("Begin", { Destination = "StartScreen", Status = "LOADING NEO TOKYO", StartScreen = true })
end)
config:SetAttribute("TimeoutSeconds", originalTimeout)
for artwork, snapshot in pairs(eligibility) do
	if artwork and artwork.Parent then
		if snapshot.Had then artwork:SetAttribute("Enabled", snapshot.Value)
		else artwork:SetAttribute("Enabled", nil) end
	end
end
if not beginOk or not generation then
	warn("[NTR Loading System Phase 5] Initial loading could not begin; restoring Roblox loading ownership.")
	return
end

player:SetAttribute("NTR_StartScreenActive", true)
ReplicatedFirst:RemoveDefaultLoadingScreen()

local function progress(value, status)
	api:Handle("Progress", { Generation = generation, Progress = value, Status = status })
end

progress(0.18, "LOADING WORLD")
local deadline = os.clock() + math.max(5, tonumber(config:GetAttribute("StartScreenLoadTimeoutSeconds")) or 20)
local loaded = game:IsLoaded()
local worldReady = Workspace:FindFirstChild("NeoTokyoRacersWorld") ~= nil
local characterReady = player.Character and player.Character:FindFirstChild("HumanoidRootPart") ~= nil
while os.clock() < deadline and not (loaded and worldReady and characterReady) do
	loaded = loaded or game:IsLoaded()
	worldReady = worldReady or Workspace:FindFirstChild("NeoTokyoRacersWorld") ~= nil
	characterReady = characterReady or (player.Character and player.Character:FindFirstChild("HumanoidRootPart") ~= nil)
	local elapsed = 1 - math.clamp((deadline - os.clock()) / math.max(5, tonumber(config:GetAttribute("StartScreenLoadTimeoutSeconds")) or 20), 0, 1)
	progress(0.18 + elapsed * 0.72, loaded and "PREPARING CITY" or "LOADING WORLD")
	task.wait(0.05)
end

if not (loaded and worldReady and characterReady) then
	warn(("[NTR Loading System Phase 5] Bounded initial readiness reached deadline loaded=%s world=%s character=%s"):format(tostring(loaded), tostring(worldReady), tostring(characterReady)))
end
progress(0.96, "FINALISING")

local safeGui = playerGui:WaitForChild("NTR_LoadingSafeContent", 5)
local safeRoot = safeGui and safeGui:FindFirstChild("SafeRoot")
if not safeRoot then
	warn("[NTR Loading System Phase 5] Loading safe content was unavailable; releasing to gameplay.")
	player:SetAttribute("NTR_StartScreenActive", false)
	api:Handle("Complete", { Generation = generation, Status = "READY" })
	return
end

local status = safeRoot:FindFirstChild("Status")
local track = safeRoot:FindFirstChild("ProgressTrack")
local minimum = math.max(0.1, tonumber(config:GetAttribute("MinimumVisibleSeconds")) or 1.5)
local completion = math.max(0.05, tonumber(config:GetAttribute("CompletionFillSeconds")) or 0.2)
local remaining = math.max(0, minimum - completion - (os.clock() - startedAt))
if remaining > 0 then task.wait(remaining) end
if status then status.Text = "READY" end
local completionOverlay = nil
if track then
	local fill = track:FindFirstChild("ProgressFill")
	if fill and fill:IsA("Frame") then
		local overlay = fill:Clone()
		overlay.Name = "StartScreenCompletionFill"
		overlay.Size = fill.Size
		overlay.ZIndex = fill.ZIndex + 1
		overlay.Parent = track
		completionOverlay = overlay
		local tween = TweenService:Create(overlay, TweenInfo.new(completion, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1, 1) })
		tween:Play()
		tween.Completed:Wait()
	end
end
task.wait(math.max(0, tonumber(config:GetAttribute("ReadyHoldSeconds")) or 0.06))
if status then status.Visible = false end
if track then track.Visible = false end

local menu = Instance.new("Frame")
menu.Name = "StartScreenActions"
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.BackgroundTransparency = 1
menu.BorderSizePixel = 0
menu.Position = UDim2.fromScale(0.5, 0.82)
menu.Size = UDim2.fromOffset(560, 52)
menu.ZIndex = 40
menu.Parent = safeRoot

local actions = Instance.new("Frame")
actions.Name = "Buttons"
actions.AnchorPoint = Vector2.new(0.5, 0.5)
actions.BackgroundTransparency = 1
actions.BorderSizePixel = 0
actions.Position = UDim2.fromScale(0.5, 0.5)
actions.Size = UDim2.fromOffset(560, 52)
actions.ZIndex = 41
actions.Parent = menu
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 16)
list.Parent = actions

local play = UI.Button(actions, {
	Name = "Play",
	Text = "",
	Size = UDim2.fromOffset(270, 52),
	Color = UI.Colour("PanelBlue"),
	StrokeColor = UI.Colour("Telemetry"),
	FocusColor = UI.Colour("Telemetry"),
	ZIndex = 43,
})
local shop = UI.Button(actions, {
	Name = "Shop",
	Text = "",
	Size = UDim2.fromOffset(270, 52),
	Color = UI.Colour("PanelSoft"),
	StrokeColor = UI.Colour("ElectricBlue"),
	FocusColor = UI.Colour("Telemetry"),
	ZIndex = 43,
})
play.LayoutOrder = 1
shop.LayoutOrder = 2
list.SortOrder = Enum.SortOrder.LayoutOrder

local playDefaultText = tostring(config:GetAttribute("StartScreenPlayText") or "PLAY")
local shopDefaultText = tostring(config:GetAttribute("StartScreenShopText") or "SHOP")

local function decorateButton(button, labelText, iconAssetId)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(0.5, 0.5)
	content.AutomaticSize = Enum.AutomaticSize.X
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Position = UDim2.fromScale(0.5, 0.5)
	content.Size = UDim2.fromOffset(0, 26)
	content.ZIndex = button.ZIndex + 2
	content.Parent = button

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Horizontal
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.Parent = content

	local asset = UI.Asset(iconAssetId)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = asset
	icon.LayoutOrder = 1
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(22, 22)
	icon.Visible = asset ~= ""
	icon.ZIndex = content.ZIndex
	icon.Parent = content

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.LayoutOrder = 2
	label.Size = UDim2.fromOffset(0, 26)
	label.Text = labelText
	label.TextColor3 = UI.Colour("Text")
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = content.ZIndex
	UI.Font(label, "Button")
	label.Parent = content
	return icon, label, contentLayout
end

-- Optional LoadingSystem String attributes; blank/absent IDs intentionally collapse icon space.
local playIcon, playLabel, playContentLayout = decorateButton(play, playDefaultText, config:GetAttribute("StartScreenPlayIconAssetId"))
local shopIcon, shopLabel, shopContentLayout = decorateButton(shop, shopDefaultText, config:GetAttribute("StartScreenShopIconAssetId"))

local function setButtonMetrics(width, height, iconSize, textSize)
	play.Size = UDim2.fromOffset(width, height)
	shop.Size = UDim2.fromOffset(width, height)
	playIcon.Size = UDim2.fromOffset(iconSize, iconSize)
	shopIcon.Size = UDim2.fromOffset(iconSize, iconSize)
	playLabel.TextSize = textSize
	shopLabel.TextSize = textSize
	local padding = iconSize <= 18 and 6 or 8
	playContentLayout.Padding = UDim.new(0, padding)
	shopContentLayout.Padding = UDim.new(0, padding)
end

local function positionMenu(attributeName, fallback, menuHeight)
	local requested = math.clamp(tonumber(config:GetAttribute(attributeName)) or fallback, 0.5, 0.95)
	local safeHeight = math.max(1, safeRoot.AbsoluteSize.Y)
	local maximum = math.max(0.5, 1 - ((menuHeight * 0.5 + 8) / safeHeight))
	menu.Position = UDim2.fromScale(0.5, math.min(requested, maximum))
end

local function updateLayout()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	local portrait = viewport.Y > viewport.X
	local phone = UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) <= 700
	if phone and portrait then
		menu.Size = UDim2.fromOffset(190, 90)
		actions.Size = UDim2.fromOffset(190, 90)
		list.FillDirection = Enum.FillDirection.Vertical
		list.Padding = UDim.new(0, 10)
		setButtonMetrics(190, 40, 17, 12)
		positionMenu("StartScreenButtonYScalePortrait", 0.80, 90)
	elseif phone then
		menu.Size = UDim2.fromOffset(388, 40)
		actions.Size = UDim2.fromOffset(388, 40)
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 12)
		setButtonMetrics(188, 40, 17, 12)
		positionMenu("StartScreenButtonYScaleLandscapePhone", 0.84, 40)
	elseif viewport.X < 800 or portrait then
		menu.Size = UDim2.fromOffset(240, 108)
		actions.Size = UDim2.fromOffset(240, 108)
		list.FillDirection = Enum.FillDirection.Vertical
		list.Padding = UDim.new(0, 12)
		setButtonMetrics(240, 48, 20, 13)
		positionMenu("StartScreenButtonYScalePortrait", 0.80, 108)
	else
		menu.Size = UDim2.fromOffset(560, 52)
		actions.Size = UDim2.fromOffset(560, 52)
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 16)
		setButtonMetrics(270, 52, 22, 14)
		positionMenu("StartScreenButtonYScaleDesktop", 0.82, 52)
	end
end
updateLayout()
local camera = Workspace.CurrentCamera
local layoutConnections = {}
if camera then table.insert(layoutConnections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)) end
table.insert(layoutConnections, safeRoot:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout))
for _, attributeName in ipairs({ "StartScreenButtonYScaleDesktop", "StartScreenButtonYScaleLandscapePhone", "StartScreenButtonYScalePortrait" }) do
	table.insert(layoutConnections, config:GetAttributeChangedSignal(attributeName):Connect(updateLayout))
end

local busy = false
local function setBusy(active, target, text)
	busy = active == true
	play.Active = not busy
	shop.Active = not busy
	playLabel.Text = playDefaultText
	shopLabel.Text = shopDefaultText
	if target == "Play" and text then playLabel.Text = tostring(text)
	elseif target == "Shop" and text then shopLabel.Text = tostring(text) end
end

local function release(success, reason)
	for _, connection in ipairs(layoutConnections) do connection:Disconnect() end
	table.clear(layoutConnections)
	if menu then menu.Visible = false end
	player:SetAttribute("NTR_StartScreenActive", false)
	local action = success and "Complete" or "Fail"
	api:Handle(action, { Generation = generation, Status = success and "READY" or "RETURNING", Reason = reason })
	if status then status.Visible = true end
	if track then track.Visible = true end
	if completionOverlay then completionOverlay:Destroy(); completionOverlay = nil end
	if menu then menu:Destroy(); menu = nil end
end

play.Activated:Connect(function()
	if busy then return end
	setBusy(true, "Play", "ENTERING")
	release(true, "Play")
end)

shop.Activated:Connect(function()
	if busy then return end
	setBusy(true, "Shop", "TRAVELLING")
	local remote = kit:WaitForChild("Shared"):WaitForChild("Remotes"):WaitForChild("UI"):WaitForChild("FreeRoamHudTeleportInvoke")
	local ok, result = pcall(function() return remote:InvokeServer("TeleportToDealership") end)
	if ok and typeof(result) == "table" and result.Success == true then
		local exited = uiFolder:FindFirstChild("FreeRoamVehicleExited")
		if exited and exited:IsA("BindableEvent") then exited:Fire() end
		release(true, "Shop")
	else
		local reason = typeof(result) == "table" and (result.Message or result.Error) or tostring(result or "DEALERSHIP TELEPORT FAILED")
		warn("[NTR Loading System Phase 5] SHOP failed: " .. tostring(reason))
		setBusy(false, "Shop", "SHOP - TRY AGAIN")
	end
end)

print("[NTR Loading System Phase 5] Compact icon Play/Shop start screen ready.")
]=]

local projected = {}

local drivingSource = driving.Source
if not string.find(drivingSource, "NTR_LOADING_SYSTEM_PHASE1_INPUT_GATE_V1", 1, true) then
	drivingSource = replaceOnce(drivingSource,
		"local player = Players.LocalPlayer\n",
		"local player = Players.LocalPlayer\n\n-- NTR_LOADING_SYSTEM_PHASE1_INPUT_GATE_V1\nlocal GameplayInputGate = require(script.Parent.Parent:WaitForChild(\"Input\"):WaitForChild(\"GameplayInputGate\"))\n",
		"driving input gate require")
	drivingSource = replaceOnce(drivingSource,
		"local function refreshInput()\n\treadGamepad()",
		[=[local function refreshInput()
	if GameplayInputGate.IsLocked() then
		state.GamepadSteer = 0
		state.GamepadAccel = 0
		state.GamepadBrake = 0
		state.GamepadBoostHeld = false
		state.DriftHeld = false
		state.DriftCharge = 0
		state.MiniBoostTimer = 0
		state.MiniBoostPower = 0
		state.AccelCameraActive = false
		state.BoostCameraActive = false
		if state.Vehicle then
			state.Vehicle:SetAttribute("Accelerating", false)
			state.Vehicle:SetAttribute("Boosting", false)
			state.Vehicle:SetAttribute("DriftingLeft", false)
			state.Vehicle:SetAttribute("DriftingRight", false)
		end
		return 0, 0
	end
	readGamepad()]=],
		"driving neutral input")
	drivingSource = replaceOnce(drivingSource,
		"local boostHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space) or state.GamepadBoostHeld",
		"local boostHeld = not GameplayInputGate.IsLocked() and (UserInputService:IsKeyDown(Enum.KeyCode.Space) or state.GamepadBoostHeld)",
		"normal boost gate")
	drivingSource = replaceOnce(drivingSource,
		"if inputState == Enum.UserInputState.Begin and state.IsDriving then",
		"if inputState == Enum.UserInputState.Begin and state.IsDriving and not GameplayInputGate.IsLocked() then",
		"reset input gate")
end
compile(driving.Name, drivingSource)
projected[driving] = drivingSource

local desktopSource = desktop.Source
if not string.find(desktopSource, "NTR_LOADING_SYSTEM_PHASE1_DEALERSHIP_TELEPORT_DESKTOP_V1", 1, true) then
	desktopSource = replaceOnce(desktopSource,
		"local teleportInvoke = kit:WaitForChild(\"Shared\"):WaitForChild(\"Remotes\"):WaitForChild(\"UI\"):WaitForChild(\"FreeRoamHudTeleportInvoke\")",
		"local teleportInvoke = kit:WaitForChild(\"Shared\"):WaitForChild(\"Remotes\"):WaitForChild(\"UI\"):WaitForChild(\"FreeRoamHudTeleportInvoke\")\nlocal loadingInvoke = script.Parent:WaitForChild(\"LoadingTransitionInvoke\") -- NTR_LOADING_SYSTEM_PHASE1_DEALERSHIP_TELEPORT_DESKTOP_V1",
		"desktop loading invoke")
	desktopSource = replaceOnce(desktopSource,
		[=[local function fireUiEvent(name)
	local event = script.Parent:FindFirstChild(name)
	if event and event:IsA("BindableEvent") then event:Fire(); return true end
	return false
end]=],
		[=[local function fireUiEvent(name)
	local event = script.Parent:FindFirstChild(name)
	if event and event:IsA("BindableEvent") then event:Fire(); return true end
	return false
end

local function loadingAction(action, payload)
	local ok, result = pcall(function() return loadingInvoke:Invoke(action, payload or {}) end)
	if ok then return result end
	warn("[NTR Desktop HUD] Loading transition " .. tostring(action) .. " failed: " .. tostring(result))
	return nil
end]=],
		"desktop loading helper")
	desktopSource = replaceOnce(desktopSource,
		[=[	yes.Activated:Connect(function()
		if busy then return end
		busy = true
		closeModal()
		showToast("TELEPORTING...", true)
		local ok, result = pcall(function()
			return teleportInvoke:InvokeServer("TeleportToDealership")
		end)
		if ok and typeof(result) == "table" and result.Success == true then
			fireUiEvent("FreeRoamVehicleExited")
			lastProfileRead = 0
			showToast(result.Message or "TELEPORTED TO DEALERSHIP", true)
		else
			showToast((typeof(result) == "table" and (result.Message or result.Error)) or "DEALERSHIP TELEPORT FAILED", false)
		end
		busy = false
	end)]=],
		[=[	yes.Activated:Connect(function()
		if busy then return end
		busy = true
		closeModal()
		local generation = loadingAction("Begin", { Destination = "DealershipExterior", Status = "TRAVELLING TO DEALERSHIP" })
		local ok, result = pcall(function()
			return teleportInvoke:InvokeServer("TeleportToDealership")
		end)
		if ok and typeof(result) == "table" and result.Success == true then
			fireUiEvent("FreeRoamVehicleExited")
			lastProfileRead = 0
			loadingAction("Complete", { Generation = generation, Status = "READY" })
			showToast(result.Message or "TELEPORTED TO DEALERSHIP", true)
		else
			local message = (typeof(result) == "table" and (result.Message or result.Error)) or "DEALERSHIP TELEPORT FAILED"
			loadingAction("Fail", { Generation = generation, Status = "RETURNING", Reason = message })
			showToast(message, false)
		end
		busy = false
	end)]=],
		"desktop dealership teleport flow")
end
compile(desktop.Name, desktopSource)
projected[desktop] = desktopSource

local mobileSource = mobile.Source
if not string.find(mobileSource, "NTR_LOADING_SYSTEM_PHASE1_DEALERSHIP_TELEPORT_MOBILE_V1", 1, true) then
	mobileSource = replaceOnce(mobileSource,
		"local teleportInvoke=remotes:WaitForChild(\"UI\"):WaitForChild(\"FreeRoamHudTeleportInvoke\")",
		"local teleportInvoke=remotes:WaitForChild(\"UI\"):WaitForChild(\"FreeRoamHudTeleportInvoke\")\nlocal loadingInvoke=script.Parent:WaitForChild(\"LoadingTransitionInvoke\") -- NTR_LOADING_SYSTEM_PHASE1_DEALERSHIP_TELEPORT_MOBILE_V1",
		"mobile loading invoke")
	mobileSource = replaceOnce(mobileSource,
		"local function fire(name,payload) local event=uiFolder:FindFirstChild(name); if event and event:IsA(\"BindableEvent\") then event:Fire(payload); return true end return false end",
		"local function fire(name,payload) local event=uiFolder:FindFirstChild(name); if event and event:IsA(\"BindableEvent\") then event:Fire(payload); return true end return false end\nlocal function loadingAction(action,payload) local ok,result=pcall(function() return loadingInvoke:Invoke(action,payload or {}) end); if ok then return result end; warn(\"[NTR Mobile HUD] Loading transition \"..tostring(action)..\" failed: \"..tostring(result)); return nil end",
		"mobile loading helper")
	mobileSource = replaceOnce(mobileSource,
		[=[local function showTeleport()
	openModal("TELEPORT TO DEALERSHIP?",tonumber(read(config,"ConfirmModalWidth",650)) or 650,tonumber(read(config,"ConfirmModalHeight",270)) or 270)
	label(modalBody,"Message","Your current vehicle will be despawned.",UDim2.new(1,-20,0,60),UDim2.fromOffset(10,46),12,WHITE,Enum.TextXAlignment.Center)
	local no=button(modalBody,"No","NO",UDim2.fromOffset(270,54),UDim2.fromOffset(16,126),PINK); local yes=button(modalBody,"Yes","YES",UDim2.fromOffset(270,54),UDim2.fromOffset(336,126),CYAN); buttonGradient(no); buttonGradient(yes)
	no.Activated:Connect(closeModal); yes.Activated:Connect(function() closeModal(); local ok,result=pcall(function() return teleportInvoke:InvokeServer("TeleportToDealership") end); if ok and typeof(result)=="table" and result.Success then fire("FreeRoamVehicleExited"); showToast(result.Message or "TELEPORTED",true) else showToast(typeof(result)=="table" and (result.Message or result.Error) or "TELEPORT FAILED",false) end end)
end]=],
		[=[local teleportBusy=false
local function showTeleport()
	openModal("TELEPORT TO DEALERSHIP?",tonumber(read(config,"ConfirmModalWidth",650)) or 650,tonumber(read(config,"ConfirmModalHeight",270)) or 270)
	label(modalBody,"Message","Your current vehicle will be despawned.",UDim2.new(1,-20,0,60),UDim2.fromOffset(10,46),12,WHITE,Enum.TextXAlignment.Center)
	local no=button(modalBody,"No","NO",UDim2.fromOffset(270,54),UDim2.fromOffset(16,126),PINK); local yes=button(modalBody,"Yes","YES",UDim2.fromOffset(270,54),UDim2.fromOffset(336,126),CYAN); buttonGradient(no); buttonGradient(yes)
	no.Activated:Connect(closeModal)
	yes.Activated:Connect(function()
		if teleportBusy then return end
		teleportBusy=true
		closeModal()
		local generation=loadingAction("Begin",{Destination="DealershipExterior",Status="TRAVELLING TO DEALERSHIP"})
		local ok,result=pcall(function() return teleportInvoke:InvokeServer("TeleportToDealership") end)
		if ok and typeof(result)=="table" and result.Success then
			fire("FreeRoamVehicleExited")
			loadingAction("Complete",{Generation=generation,Status="READY"})
			showToast(result.Message or "TELEPORTED",true)
		else
			local message=typeof(result)=="table" and (result.Message or result.Error) or "TELEPORT FAILED"
			loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=message})
			showToast(message,false)
		end
		teleportBusy=false
	end)
end]=],
		"mobile dealership teleport flow")
end
compile(mobile.Name, mobileSource)
projected[mobile] = mobileSource

local garageEntranceSource = garageEntrance.Source
if not string.find(garageEntranceSource, "NTR_LOADING_SYSTEM_PHASE2_GARAGE_ENTRY_V1", 1, true) then
	garageEntranceSource = replaceOnce(garageEntranceSource,
		"local config = kit:WaitForChild(\"Config\"):WaitForChild(\"UI\"):WaitForChild(\"GarageExperience\")",
		"local config = kit:WaitForChild(\"Config\"):WaitForChild(\"UI\"):WaitForChild(\"GarageExperience\")\nlocal loadingInvoke = script.Parent.Parent:WaitForChild(\"UI\"):WaitForChild(\"LoadingTransitionInvoke\") -- NTR_LOADING_SYSTEM_PHASE2_GARAGE_ENTRY_V1",
		"garage entry loading invoke")
	garageEntranceSource = replaceOnce(garageEntranceSource,
		"local entries = {}\nlocal busy = false",
		[=[local entries = {}
local busy = false

local function loadingAction(action, payload)
	local ok, result = pcall(function()
		return loadingInvoke:Invoke(action, payload or {})
	end)
	if ok then return result end
	warn("[NTR Garage Entrance] Loading transition " .. tostring(action) .. " failed: " .. tostring(result))
	return nil
end

local function loadingDetails(mode)
	if mode == "Dealership" then
		return "Dealership", "ENTERING DEALERSHIP"
	elseif mode == "DriveIn" then
		return "DriveInCustomisation", "ENTERING CUSTOMISATION"
	end
	return "Customisation", "ENTERING CUSTOMISATION"
end]=],
		"garage entry loading helper")
	garageEntranceSource = replaceOnce(garageEntranceSource,
		[=[	prompt.Triggered:Connect(function()
		if busy or garageIsActive() then return end
		if definition.Mode == "DriveIn" and not drivingOwnVehicle() then
			flash("Drive your owned vehicle into the bay first.")
			refreshPromptAvailability()
			return
		end

		busy = true
		local ok, result = pcall(function()
			return request:InvokeServer("Begin", { Mode = definition.Mode })
		end)
		if not ok or not result or result.Success ~= true then
			busy = false
			flash((result and result.Message) or "Could not enter garage.")
			refreshPromptAvailability()
			return
		end

		player:SetAttribute("NTR_GarageEntryMode", definition.Mode)
		refreshPromptAvailability()
		local event = script.Parent:FindFirstChild(definition.Event) or script.Parent:WaitForChild(definition.Event, 5)
		if event and event:IsA("BindableEvent") then
			event:Fire()
		else
			request:InvokeServer("End", { ReturnToEntry = true })
			player:SetAttribute("NTR_GarageEntryMode", nil)
			flash("Garage UI handoff is unavailable.")
		end
		busy = false
		refreshPromptAvailability()
	end)]=],
		[=[	prompt.Triggered:Connect(function()
		if busy or garageIsActive() then return end
		if definition.Mode == "DriveIn" and not drivingOwnVehicle() then
			flash("Drive your owned vehicle into the bay first.")
			refreshPromptAvailability()
			return
		end

		busy = true
		local destination, status = loadingDetails(definition.Mode)
		local generation = loadingAction("Begin", { Destination = destination, Status = status })
		local ok, result = pcall(function()
			return request:InvokeServer("Begin", { Mode = definition.Mode })
		end)
		if not ok or not result or result.Success ~= true then
			local message = (result and result.Message) or "Could not enter garage."
			loadingAction("Fail", { Generation = generation, Status = "RETURNING", Reason = message })
			busy = false
			flash(message)
			refreshPromptAvailability()
			return
		end

		player:SetAttribute("NTR_GarageEntryMode", definition.Mode)
		refreshPromptAvailability()
		local event = script.Parent:FindFirstChild(definition.Event) or script.Parent:WaitForChild(definition.Event, 5)
		if event and event:IsA("BindableEvent") then
			event:Fire({ LoadingGeneration = generation, LoadingDestination = destination })
		else
			request:InvokeServer("End", { ReturnToEntry = true })
			player:SetAttribute("NTR_GarageEntryMode", nil)
			loadingAction("Fail", { Generation = generation, Status = "RETURNING", Reason = "Garage UI handoff unavailable" })
			flash("Garage UI handoff is unavailable.")
		end
		busy = false
		refreshPromptAvailability()
	end)]=],
		"garage entry transition flow")
end
compile(garageEntrance.Name, garageEntranceSource)
projected[garageEntrance] = garageEntranceSource

local moduleShopSource = moduleShop.Source
if not string.find(moduleShopSource, "NTR_LOADING_SYSTEM_PHASE2_GARAGE_UI_TRANSITIONS_V1", 1, true) then
	moduleShopSource = replaceOnce(moduleShopSource,
		"local sessionRequest=kit:WaitForChild(\"Shared\"):WaitForChild(\"Remotes\"):WaitForChild(\"UI\"):WaitForChild(\"GarageSessionRequest\")",
		"local sessionRequest=kit:WaitForChild(\"Shared\"):WaitForChild(\"Remotes\"):WaitForChild(\"UI\"):WaitForChild(\"GarageSessionRequest\")\nlocal loadingInvoke=script.Parent:WaitForChild(\"LoadingTransitionInvoke\") -- NTR_LOADING_SYSTEM_PHASE2_GARAGE_UI_TRANSITIONS_V1",
		"garage UI loading invoke")
	moduleShopSource = replaceOnce(moduleShopSource,
		"local action=Adapter.new(State); local browser=Browser.new(); local workspaceUI=WorkspaceUI.new(); local preview={}; local active=false; local modal",
		[=[local action=Adapter.new(State); local browser=Browser.new(); local workspaceUI=WorkspaceUI.new(); local preview={}; local active=false; local modal
local function loadingAction(actionName,payload) local ok,result=pcall(function() return loadingInvoke:Invoke(actionName,payload or {}) end); if ok then return result end; warn("[NTR Canonical Garage] Loading transition "..tostring(actionName).." failed: "..tostring(result)); return nil end
local function entryLoading(mode,payload)
	payload=typeof(payload)=="table" and payload or {}
	if payload.LoadingGeneration then return payload.LoadingGeneration end
	local destination=mode=="Dealership" and "Dealership" or (mode=="DriveIn" and "DriveInCustomisation" or "Customisation")
	return loadingAction("Begin",{Destination=destination,Status=mode=="Dealership" and "ENTERING DEALERSHIP" or "ENTERING CUSTOMISATION"})
end]=],
		"garage UI loading helper")
	moduleShopSource = replaceOnce(moduleShopSource,
		[=[local function driveFromGarage()
	local engine,stabilisers,boost=coreReady(); if not(engine and stabilisers and boost) then message("Equip one engine, stabilisers, and boost before driving."); return end
	clearTransientModulePreview(); action:Session("End",{ReturnToEntry=false}); local result=action:Call("SpawnVehicle",{}); if not result.Success then message(result.Message); return end; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); fire("FreeRoamVehicleSpawned"); local event=intro:FindFirstChild("GarageClosedFromDealershipExit"); if event and event:IsA("BindableEvent") then event:Fire() end
end]=],
		[=[local function driveFromGarage()
	local engine,stabilisers,boost=coreReady(); if not(engine and stabilisers and boost) then message("Equip one engine, stabilisers, and boost before driving."); return end
	local generation=loadingAction("Begin",{Destination="FreeRoamDrive",Status="PREPARING VEHICLE"})
	clearTransientModulePreview()
	local ended=action:Session("End",{ReturnToEntry=true})
	if not ended or ended.Success~=true then local reason=(ended and ended.Message) or "Could not leave customisation."; loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); message(reason); return end
	local result=action:Call("SpawnVehicle",{})
	if not result.Success then local reason=result.Message or "Vehicle spawn failed"; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); local failedEvent=intro:FindFirstChild("GarageClosedFromDealershipExit"); if failedEvent and failedEvent:IsA("BindableEvent") then failedEvent:Fire() end; loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); warn("[NTR Canonical Garage] Drive exit failed safely: "..tostring(reason)); return end
	active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); fire("FreeRoamVehicleSpawned"); local event=intro:FindFirstChild("GarageClosedFromDealershipExit"); if event and event:IsA("BindableEvent") then event:Fire() end
	loadingAction("Complete",{Generation=generation,Status="READY TO DRIVE"})
end]=],
		"garage drive transition flow")
	moduleShopSource = replaceOnce(moduleShopSource,
		[=[	OnExit=function() action:Session("End",{ReturnToEntry=true}); active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); local e=intro:FindFirstChild("GarageClosedFromDealershipExit"); if e and e:IsA("BindableEvent") then e:Fire() end end,OnCash=showCash,OnCapacity=showProperties})]=],
		[=[	OnExit=function() local generation=loadingAction("Begin",{Destination="DealershipExterior",Status="LEAVING GARAGE"}); local ended=action:Session("End",{ReturnToEntry=true}); if not ended or ended.Success~=true then local reason=(ended and ended.Message) or "Could not leave garage."; loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); message(reason); return end; active=false; hideAll(); closeCamera(); player:SetAttribute("NTR_GarageEntryMode",nil); local e=intro:FindFirstChild("GarageClosedFromDealershipExit"); if e and e:IsA("BindableEvent") then e:Fire() end; loadingAction("Complete",{Generation=generation,Status="READY"}) end,OnCash=showCash,OnCapacity=showProperties})]=],
		"garage foot exit transition flow")
	moduleShopSource = replaceOnce(moduleShopSource,
		[=[local function open(mode)
	if active then return end; local result=action:Refresh(); if not result.Success then warn("[NTR Canonical Garage] "..tostring(result.Message)); action:Session("End",{ReturnToEntry=true}); return end
	active=true; State.ShopMode=mode=="Dealership" and "Dealership" or "Customisation"; State.CategoryId=State.Profile.CurrentCategory or (allCategories()[1] and allCategories()[1].CategoryId) or "bruiser"; State.SelectedCockpit=State.Profile.CurrentCockpit; State.SelectedVehicleId=nil; State.BrowseAll=true; State.NoPreviewYet=true; State.GarageCameraActive=true; startCamera()
	if mode=="DriveIn" then local vehicleId=State.Profile.CurrentVehicleId; action:Call("DespawnVehicle",{}); fire("FreeRoamVehicleExited"); if vehicleId then action:Call("SelectVehicleInstance",{VehicleId=vehicleId}) end; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.SelectedCockpit=State.Profile.CurrentCockpit; State.NoPreviewYet=false; buildPreview(); renderHub() else renderBrowser() end
	auditOwnership(mode)
end
local function bindGarageOpen(name,mode) introEvent(name).Event:Connect(function() print("[NTR Garage Route] event="..name.." mode="..mode); open(mode) end) end]=],
		[=[local function open(mode,payload)
	if active then if typeof(payload)=="table" and payload.LoadingGeneration then loadingAction("Complete",{Generation=payload.LoadingGeneration,Status="READY"}) end; return end
	local generation=entryLoading(mode,payload)
	local result=action:Refresh(); if not result.Success then local reason=tostring(result.Message or "Garage data unavailable"); warn("[NTR Canonical Garage] "..reason); action:Session("End",{ReturnToEntry=true}); player:SetAttribute("NTR_GarageEntryMode",nil); loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); return end
	active=true; State.ShopMode=mode=="Dealership" and "Dealership" or "Customisation"; State.CategoryId=State.Profile.CurrentCategory or (allCategories()[1] and allCategories()[1].CategoryId) or "bruiser"; State.SelectedCockpit=State.Profile.CurrentCockpit; State.SelectedVehicleId=nil; State.BrowseAll=true; State.NoPreviewYet=true; State.GarageCameraActive=true; startCamera()
	if mode=="DriveIn" then local vehicleId=State.Profile.CurrentVehicleId; action:Call("DespawnVehicle",{}); fire("FreeRoamVehicleExited"); if vehicleId then action:Call("SelectVehicleInstance",{VehicleId=vehicleId}) end; State.SelectedVehicleId=State.Profile.CurrentVehicleId; State.SelectedCockpit=State.Profile.CurrentCockpit; State.NoPreviewYet=false; buildPreview(); renderHub() else renderBrowser() end
	auditOwnership(mode)
	loadingAction("Complete",{Generation=generation,Status="READY"})
end
local function bindGarageOpen(name,mode) introEvent(name).Event:Connect(function(payload) print("[NTR Garage Route] event="..name.." mode="..mode); open(mode,payload) end) end]=],
		"garage open readiness flow")
end
compile(moduleShop.Name, moduleShopSource)
projected[moduleShop] = moduleShopSource

local ownedGarageBrowserSource = ownedGarageBrowser.Source
if not string.find(ownedGarageBrowserSource, "NTR_LOADING_SYSTEM_PHASE3_OWNED_GARAGE_BROWSER_V1", 1, true) then
	ownedGarageBrowserSource = replaceOnce(ownedGarageBrowserSource,
		"local Players=game:GetService(\"Players\"); local ReplicatedStorage=game:GetService(\"ReplicatedStorage\"); local UserInputService=game:GetService(\"UserInputService\"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild(\"PlayerGui\"); local kit=ReplicatedStorage:WaitForChild(\"NeoTokyoRacers\")",
		"local Players=game:GetService(\"Players\"); local ProximityPromptService=game:GetService(\"ProximityPromptService\"); local ReplicatedStorage=game:GetService(\"ReplicatedStorage\"); local UserInputService=game:GetService(\"UserInputService\"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild(\"PlayerGui\"); local kit=ReplicatedStorage:WaitForChild(\"NeoTokyoRacers\")",
		"owned garage prompt service")
	ownedGarageBrowserSource = replaceOnce(ownedGarageBrowserSource,
		"local UI=require(kit.Shared.Modules.UI:WaitForChild(\"RacingUIComponents\")); local Mobile=require(kit.Shared.Modules.UI:WaitForChild(\"RacingMobileScaledDesktopLayout\")); local Shared=require(script.Parent:WaitForChild(\"GarageReplacementComponents\")); local remote=kit.Shared.Remotes.Garage:WaitForChild(\"OwnedGarageInvoke\"); local push=kit.Shared.Remotes.Garage:WaitForChild(\"OwnedGarageEvent\"); local openEvent=script.Parent:WaitForChild(\"OpenOwnedGarageBrowser\")",
		"local UI=require(kit.Shared.Modules.UI:WaitForChild(\"RacingUIComponents\")); local Mobile=require(kit.Shared.Modules.UI:WaitForChild(\"RacingMobileScaledDesktopLayout\")); local Shared=require(script.Parent:WaitForChild(\"GarageReplacementComponents\")); local remote=kit.Shared.Remotes.Garage:WaitForChild(\"OwnedGarageInvoke\"); local push=kit.Shared.Remotes.Garage:WaitForChild(\"OwnedGarageEvent\"); local openEvent=script.Parent:WaitForChild(\"OpenOwnedGarageBrowser\")\n\tlocal loadingInvoke=script.Parent:WaitForChild(\"LoadingTransitionInvoke\") -- NTR_LOADING_SYSTEM_PHASE3_OWNED_GARAGE_BROWSER_V1",
		"owned garage loading invoke")
	ownedGarageBrowserSource = replaceOnce(ownedGarageBrowserSource,
		"local C=function(name) return UI.Colour(name) end; local L=function(name,fallback) return UI.Layout(name,fallback) end; local T=function(name,fallback) return UI.Type(name,fallback) end; local state; local selected; local busy=false; local cards={}; local generation=0",
		"local C=function(name) return UI.Colour(name) end; local L=function(name,fallback) return UI.Layout(name,fallback) end; local T=function(name,fallback) return UI.Type(name,fallback) end; local state; local selected; local busy=false; local cards={}; local generation=0; local physicalLoadingGeneration",
		"owned garage physical generation")
	ownedGarageBrowserSource = replaceOnce(ownedGarageBrowserSource,
		"local function request(action,args) local ok,result=pcall(function() return remote:InvokeServer(action,args or {}) end); if ok and type(result)==\"table\" then return result end; return {Success=false,Message=\"Garage service unavailable.\"} end",
		[=[local function request(action,args) local ok,result=pcall(function() return remote:InvokeServer(action,args or {}) end); if ok and type(result)=="table" then return result end; return {Success=false,Message="Garage service unavailable."} end
	local function loadingAction(action,payload) local ok,result=pcall(function() return loadingInvoke:Invoke(action,payload or {}) end); if ok then return result end; warn("[NTR Owned Garage] Loading transition "..tostring(action).." failed: "..tostring(result)); return nil end
	local function beginPhysicalLoading(destination,status) if physicalLoadingGeneration then return end; physicalLoadingGeneration=loadingAction("Begin",{Destination=destination,Status=status}) end
	local function finishPhysicalLoading(success,message) local current=physicalLoadingGeneration; if not current then return end; physicalLoadingGeneration=nil; loadingAction(success and "Complete" or "Fail",{Generation=current,Status=success and "READY" or "RETURNING",Reason=message}) end]=],
		"owned garage loading helpers")
	ownedGarageBrowserSource = replaceOnce(ownedGarageBrowserSource,
		[=[		for index,slot in ipairs(result.Slots or {}) do local button=Shared.ActionButton(panel,{Name=slot.SlotId,Text=tostring(slot.DisplayName or slot.VehicleId),IconText=tostring(index),Size=UDim2.new(1,-48,0,touchPrompt and 112 or 58),Color=C("PanelSoft"),StrokeColor=C("Outline")}); button.Position=UDim2.fromOffset(24,112+(index-1)*(touchPrompt and 124 or 68)); button.ZIndex=203; button.Activated:Connect(function() if busy then return end; busy=true; local replaced=request("EnterSelectedGarage",{PropertyId=selected.PropertyId,ReplacementSlotId=slot.SlotId}); busy=false; if replaced.Success then shade:Destroy(); close() else setStatus(replaced.Message,false) end end) end]=],
		[=[		for index,slot in ipairs(result.Slots or {}) do
			local button=Shared.ActionButton(panel,{Name=slot.SlotId,Text=tostring(slot.DisplayName or slot.VehicleId),IconText=tostring(index),Size=UDim2.new(1,-48,0,touchPrompt and 112 or 58),Color=C("PanelSoft"),StrokeColor=C("Outline")}); button.Position=UDim2.fromOffset(24,112+(index-1)*(touchPrompt and 124 or 68)); button.ZIndex=203
			button.Activated:Connect(function()
				if busy then return end; busy=true
				local loadingGeneration=loadingAction("Begin",{Destination="OwnedGarageInterior",Status="ENTERING OWNED GARAGE"})
				local replaced=request("EnterSelectedGarage",{PropertyId=selected.PropertyId,ReplacementSlotId=slot.SlotId}); busy=false
				if replaced.Success then shade:Destroy(); close(); loadingAction("Complete",{Generation=loadingGeneration,Status="READY"}) else loadingAction("Fail",{Generation=loadingGeneration,Status="RETURNING",Reason=replaced.Message}); setStatus(replaced.Message,false) end
			end)
		end]=],
		"owned garage replacement entry flow")
	ownedGarageBrowserSource = replaceOnce(ownedGarageBrowserSource,
		[=[	exit.Activated:Connect(close); enter.Activated:Connect(function() if busy or not selected then return end; busy=true; local result;if state.InGarage then result=request("ExitOnFoot",{}) else result=request("EnterSelectedGarage",{PropertyId=selected.PropertyId}) end; busy=false; if result.Success then close() elseif result.NeedsReplacement then replacementPrompt(result) else setStatus(result.Message,false) end end); openEvent.Event:Connect(function() if overlay.Visible then close() else open() end end); push.OnClientEvent:Connect(function(message) if type(message)=="table" and message.Type=="DriveOut" then close() end end)]=],
		[=[	exit.Activated:Connect(close)
	enter.Activated:Connect(function()
		if busy or not selected then return end; busy=true
		local returning=state and state.InGarage==true
		local loadingGeneration=loadingAction("Begin",{Destination=returning and "OwnedGarageExterior" or "OwnedGarageInterior",Status=returning and "RETURNING TO CITY" or "ENTERING OWNED GARAGE"})
		local result;if returning then result=request("ExitOnFoot",{}) else result=request("EnterSelectedGarage",{PropertyId=selected.PropertyId}) end; busy=false
		if result.Success then close(); loadingAction("Complete",{Generation=loadingGeneration,Status="READY"}) elseif result.NeedsReplacement then loadingAction("Fail",{Generation=loadingGeneration,Status="SELECT A DISPLAY SPACE",Reason=result.Message}); replacementPrompt(result) else loadingAction("Fail",{Generation=loadingGeneration,Status="RETURNING",Reason=result.Message}); setStatus(result.Message,false) end
	end)
	openEvent.Event:Connect(function() if overlay.Visible then close() else open() end end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt,triggeringPlayer)
		if triggeringPlayer and triggeringPlayer~=player then return end
		if player:GetAttribute("NTR_OwnedGarageInside")~=true or not prompt then return end
		if prompt.Name=="FootExitPrompt" then beginPhysicalLoading("OwnedGarageExterior","RETURNING TO CITY") elseif prompt.Name=="DriveOutPrompt" then beginPhysicalLoading("OwnedGarageDriveOut","PREPARING VEHICLE") end
	end)
	player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(function() if player:GetAttribute("NTR_OwnedGarageInside")~=true then finishPhysicalLoading(true,"Ready") end end)
	push.OnClientEvent:Connect(function(message)
		if type(message)~="table" then return end
		if message.Type=="DriveOut" then close()
		elseif message.Type=="DriveOutResult" then finishPhysicalLoading(message.Success==true,message.Message)
		elseif message.Type=="FootExitResult" then finishPhysicalLoading(message.Success==true,message.Message) end
	end)]=],
		"owned garage transition flows")
end
compile(ownedGarageBrowser.Name, ownedGarageBrowserSource)
projected[ownedGarageBrowser] = ownedGarageBrowserSource

local ownedGarageManagementSource = ownedGarageManagement.Source
if not string.find(ownedGarageManagementSource, "NTR_LOADING_SYSTEM_PHASE3_OWNED_GARAGE_FOOT_EXIT_RESULT_V1", 1, true) then
	ownedGarageManagementSource = replaceOnce(ownedGarageManagementSource,
		[=[		local foot=session.Interior:FindFirstChild("FootExitPrompt",true); if foot then foot.HoldDuration=0; foot:SetAttribute("OwnedGarageAvailable",true); table.insert(list,foot.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then exitOnFoot(player) end end)) end]=],
		[=[		-- NTR_LOADING_SYSTEM_PHASE3_OWNED_GARAGE_FOOT_EXIT_RESULT_V1
		local foot=session.Interior:FindFirstChild("FootExitPrompt",true)
		if foot then
			foot.HoldDuration=0; foot:SetAttribute("OwnedGarageAvailable",true)
			table.insert(list,foot.Triggered:Connect(function(triggeringPlayer)
				if triggeringPlayer==player then local result=exitOnFoot(player); push:FireClient(player,{Type="FootExitResult",Success=result.Success==true,Message=result.Message}) end
			end))
		end]=],
		"owned garage physical foot exit result")
end
compile(ownedGarageManagement.Name, ownedGarageManagementSource)
projected[ownedGarageManagement] = ownedGarageManagementSource

local raceTransitionSource = raceTransition.Source
if not string.find(raceTransitionSource, "NTR_LOADING_SYSTEM_PHASE4_RACE_TRANSITION_BRIDGE_V1", 1, true) then
	raceTransitionSource = replaceOnce(raceTransitionSource,
		[=[local transitionRequest = racingFolder:WaitForChild("RaceTransitionRequest")
local transitionStateChanged = racingFolder:FindFirstChild("RaceTransitionStateChanged")]=],
		[=[local transitionRequest = racingFolder:WaitForChild("RaceTransitionRequest")
local transitionStateChanged = racingFolder:FindFirstChild("RaceTransitionStateChanged")
local uiControllers = assert(racingFolder.Parent:FindFirstChild("UI"), "Racing loading UI folder missing")
local loadingInvoke = uiControllers:WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE4_RACE_TRANSITION_BRIDGE_V1
local loadingGeneration = nil
local loadingFinishing = false]=],
		"race transition loading invoke")
	raceTransitionSource = replaceOnce(raceTransitionSource,
		[=[local function fireState()
	if transitionStateChanged and transitionStateChanged:IsA("BindableEvent") then]=],
		[=[local function loadingAction(action, payload)
	local ok, result = pcall(function() return loadingInvoke:Invoke(action, payload or {}) end)
	if ok then return result end
	warn("[NTR Racing Loading] " .. tostring(action) .. " failed: " .. tostring(result))
	return nil
end

local function beginLoading(destination, status)
	if loadingGeneration then return loadingGeneration end
	loadingGeneration = loadingAction("Begin", { Destination = destination or "RaceSession", Status = status or "LOADING RACE" })
	return loadingGeneration
end

local function finishLoading(success, status, reason)
	local current = loadingGeneration
	if not current then return loadingFinishing end
	loadingGeneration = nil
	loadingFinishing = true
	loadingAction(success and "Complete" or "Fail", {
		Generation = current,
		Status = status or (success and "READY TO RACE" or "RETURNING"),
		Reason = reason,
	})
	loadingFinishing = false
	return true
end

local function fireState()
	if transitionStateChanged and transitionStateChanged:IsA("BindableEvent") then]=],
		"race transition loading helpers")
	raceTransitionSource = replaceOnce(raceTransitionSource,
		[=[local function startTransition(reason)
	setSessionActive(true, reason)
	suppressFreeRoamHud()
	fadeOut("STAGING")
	task.delay(0.22, function() restoreCamera(reason) end)
	task.delay(0.78, function() fadeIn(0) end)
end

local function finishTransition(reason)
	restoreCamera(reason)
	fadeIn(0.18)
end]=],
		[=[local function startTransition(reason)
	setSessionActive(true, reason)
	suppressFreeRoamHud()
	if not beginLoading(string.find(tostring(reason), "TimeTrial", 1, true) and "TimeTrialSession" or "RaceSession", "STAGING") then fadeOut("STAGING") end
	task.delay(0.22, function() restoreCamera(reason) end)
end

local function finishTransition(reason)
	restoreCamera(reason)
	if not finishLoading(true, "READY TO RACE", reason) then fadeIn(0.18) end
end]=],
		"race staged transition loading")
	raceTransitionSource = replaceOnce(raceTransitionSource,
		[=[	elseif kind == "RaceExitedToStart" then
		finishHold = false
		setSessionActive(false, kind)
		restoreCamera(kind)
		fadeIn(0.28)
	elseif kind == "RaceEnded" and finishHold then
		suppressFreeRoamHud()
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError"
		or kind == "RaceDNF" or kind == "RaceEnded" or kind == "RaceQueueError" then
		finishHold = false
		setSessionActive(false, kind)
		restoreCamera(kind)
		fadeIn(0.18)
	end]=],
		[=[	elseif kind == "RaceExitedToStart" then
		finishHold = false
		setSessionActive(false, kind)
		restoreCamera(kind)
		if not finishLoading(true, "READY", kind) then fadeIn(0.28) end
	elseif kind == "RaceEnded" and finishHold then
		suppressFreeRoamHud()
	elseif kind == "TimeTrialFinished" or kind == "TimeTrialEnded" or kind == "TimeTrialError"
		or kind == "RaceDNF" or kind == "RaceEnded" or kind == "RaceQueueError" then
		finishHold = false
		setSessionActive(false, kind)
		restoreCamera(kind)
		local success = kind ~= "TimeTrialError" and kind ~= "RaceQueueError"
		if not finishLoading(success, success and "READY" or "RETURNING", kind) then fadeIn(0.18) end
	end]=],
		"race exit event loading completion")
	raceTransitionSource = replaceOnce(raceTransitionSource,
		[=[	elseif step == "FadeOut" then
		fadeOut(payload.Label or "")
	elseif step == "FadeIn" then
		fadeIn(payload.Delay)
	elseif step == "RestoreCamera" then]=],
		[=[	elseif step == "FadeOut" then
		if tostring(payload.Reason or "") == "Reset" then fadeOut(payload.Label or "")
		else beginLoading(payload.Destination or "RaceStart", payload.Label or "LOADING") end
	elseif step == "FadeIn" then
		if tostring(payload.Reason or "") == "Reset" then fadeIn(payload.Delay)
		else
			local failed = payload.Success == false or string.find(tostring(payload.Reason or ""), "Failed", 1, true) ~= nil
			finishLoading(not failed, failed and "RETURNING" or "READY", payload.Reason)
		end
	elseif step == "BeginLoading" then
		if not beginLoading(payload.Destination, payload.Status) then fadeOut(payload.Status or "LOADING") end
	elseif step == "CompleteLoading" then
		if not finishLoading(true, payload.Status, payload.Reason) then fadeIn(payload.Delay) end
	elseif step == "FailLoading" then
		if not finishLoading(false, payload.Status, payload.Reason) then fadeIn(payload.Delay) end
	elseif step == "RestoreCamera" then]=],
		"race transition request loading bridge")
end
compile(raceTransition.Name, raceTransitionSource)
projected[raceTransition] = raceTransitionSource

local raceEntrySource = raceEntry.Source
if not string.find(raceEntrySource, "NTR_LOADING_SYSTEM_PHASE4_TIME_TRIAL_START_V1", 1, true) then
	raceEntrySource = replaceOnce(raceEntrySource,
		[=[local startRaceQueueEvent=script.Parent:WaitForChild("StartRaceQueueRequest")
local entry=nil]=],
		[=[local startRaceQueueEvent=script.Parent:WaitForChild("StartRaceQueueRequest")
local transitionRequest=script.Parent:WaitForChild("RaceTransitionRequest") -- NTR_LOADING_SYSTEM_PHASE4_TIME_TRIAL_START_V1
local entry=nil
local function transition(step,payload) payload=payload or {}; payload.Step=step; transitionRequest:Fire(payload) end]=],
		"time trial start transition bridge")
	raceEntrySource = replaceOnce(raceEntrySource,
		[=[presentationAction.Event:Connect(function(action,data)
	data=type(data)=="table" and data or {}
	if action~="StartSelectedVehicle" then return end
	local ok,cockpitOrMessage=spawnVehicle(data)
	if not ok then warn("[NTR Phase 16E Entry Bridge] "..cockpitOrMessage) return end
	task.wait(0.35)
	local mode=tostring(data.Mode)=="Race" and "Race" or "TimeTrial"
	local eventId=tostring(data.EventId or (entry and entry.EventId) or "")
	if mode=="Race" then
		startRaceQueueEvent:Fire({EventId=eventId,VehicleId=tostring(data.VehicleId),CockpitId=cockpitOrMessage,DisplayName=entry and entry.Summary and entry.Summary.DisplayName})
	else
		local result=call(raceRequest,"StartStagedTimeTrial",{EventId=eventId,VehicleId=tostring(data.VehicleId),LapCount=tonumber(data.LapCount) or 1})
		if result.Success~=true and result.Ok~=true then warn("[NTR Phase 16E Entry Bridge] "..tostring(result.Message or "Time trial start failed.")) end
	end
end)]=],
		[=[presentationAction.Event:Connect(function(action,data)
	data=type(data)=="table" and data or {}
	if action~="StartSelectedVehicle" then return end
	local mode=tostring(data.Mode)=="Race" and "Race" or "TimeTrial"
	if mode=="TimeTrial" then transition("BeginLoading",{Destination="TimeTrialSession",Status="STAGING TIME TRIAL"}) end
	local ok,cockpitOrMessage=spawnVehicle(data)
	if not ok then
		if mode=="TimeTrial" then transition("FailLoading",{Status="RETURNING",Reason=cockpitOrMessage}) end
		warn("[NTR Phase 16E Entry Bridge] "..cockpitOrMessage)
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
			warn("[NTR Phase 16E Entry Bridge] "..tostring(result.Message or "Time trial start failed."))
		end
	end
end)]=],
		"time trial immediate loading flow")
end
compile(raceEntry.Name, raceEntrySource)
projected[raceEntry] = raceEntrySource

local raceSessionSource = raceSession.Source
if not string.find(raceSessionSource, "NTR_LOADING_SYSTEM_PHASE4_ACTIVE_RACE_EXIT_V1", 1, true) then
	raceSessionSource = replaceOnce(raceSessionSource,
		[=[	transition("RestoreCamera",{Reason=kind}) transition("FadeIn",{Reason=kind,Delay=success and .3 or .08})]=],
		[=[	transition("RestoreCamera",{Reason=kind}) transition("FadeIn",{Reason=kind,Delay=success and .3 or .08,Success=success}) -- NTR_LOADING_SYSTEM_PHASE4_ACTIVE_RACE_EXIT_V1]=],
		"active race exit result")
end
compile(raceSession.Name, raceSessionSource)
projected[raceSession] = raceSessionSource

local raceResultsSource = raceResults.Source
if not string.find(raceResultsSource, "NTR_LOADING_SYSTEM_PHASE4_RESULTS_EXIT_V1", 1, true) then
	raceResultsSource = replaceOnce(raceResultsSource,
		[=[local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")]=],
		[=[local queueRequest = racingRemotes:WaitForChild("RaceQueueRequest")
local transitionRequest = script.Parent:WaitForChild("RaceTransitionRequest") -- NTR_LOADING_SYSTEM_PHASE4_RESULTS_EXIT_V1
local function transition(step,payload) payload=payload or {}; payload.Step=step; transitionRequest:Fire(payload) end]=],
		"results loading transition bridge")
	raceResultsSource = replaceOnce(raceResultsSource,
		[=[	footerButtons("EXIT TO START","TRY AGAIN",function() complete.Text="EXITING..." local result=invoke(raceRequest,"ExitFinishedTimeTrial",{}) if result.Ok==true or result.Success==true then fireDrivingExit() hide() else complete.Text=string.upper(tostring(result.Message or "EXIT FAILED")) end end,function() local result=invoke(raceRequest,"StartStagedTimeTrial",{EventId=payload.EventId,VehicleId=payload.SelectedVehicleId,LapCount=payload.LapTarget}) if result.Ok==true or result.Success==true then hide() end end)]=],
		[=[	footerButtons("EXIT TO START","TRY AGAIN",function()
		complete.Text="EXITING..."; transition("BeginLoading",{Destination="RaceStart",Status="RETURNING TO START"})
		local result=invoke(raceRequest,"ExitFinishedTimeTrial",{}); local success=result.Ok==true or result.Success==true
		if success then fireDrivingExit(); hide(); transition("CompleteLoading",{Status="READY"}) else transition("FailLoading",{Status="RETURNING",Reason=result.Message}); complete.Text=string.upper(tostring(result.Message or "EXIT FAILED")) end
	end,function() local result=invoke(raceRequest,"StartStagedTimeTrial",{EventId=payload.EventId,VehicleId=payload.SelectedVehicleId,LapCount=payload.LapTarget}) if result.Ok==true or result.Success==true then hide() end end)]=],
		"time trial results exit loading")
	raceResultsSource = replaceOnce(raceResultsSource,
		[=[	footerButtons("EXIT TO START","RACE AGAIN",function() complete.Text="EXITING..." local result=invoke(queueRequest,"ExitRaceToStart",{}) if result.Ok==true or result.Success==true then hide() else complete.Text=string.upper(tostring(result.Message or "EXIT FAILED")) end end,function() local eventId=tostring(player:GetAttribute("NTR_LastRacingEventId") or payload.EventId or "") local vehicleId=tostring(player:GetAttribute("NTR_LastRacingVehicleId") or "") local root=script.Parent local start=root:FindFirstChild("StartRaceQueueRequest") if start and start:IsA("BindableEvent") and eventId~="" and vehicleId~="" then hide() start:Fire({EventId=eventId,VehicleId=vehicleId,DisplayName=payload.DisplayName}) end end)]=],
		[=[	footerButtons("EXIT TO START","RACE AGAIN",function()
		complete.Text="EXITING..."; transition("BeginLoading",{Destination="RaceStart",Status="RETURNING TO START"})
		local result=invoke(queueRequest,"ExitRaceToStart",{}); local success=result.Ok==true or result.Success==true
		if success then hide(); transition("CompleteLoading",{Status="READY"}) else transition("FailLoading",{Status="RETURNING",Reason=result.Message}); complete.Text=string.upper(tostring(result.Message or "EXIT FAILED")) end
	end,function() local eventId=tostring(player:GetAttribute("NTR_LastRacingEventId") or payload.EventId or "") local vehicleId=tostring(player:GetAttribute("NTR_LastRacingVehicleId") or "") local root=script.Parent local start=root:FindFirstChild("StartRaceQueueRequest") if start and start:IsA("BindableEvent") and eventId~="" and vehicleId~="" then hide() start:Fire({EventId=eventId,VehicleId=vehicleId,DisplayName=payload.DisplayName}) end end)]=],
		"race results exit loading")
end
compile(raceResults.Name, raceResultsSource)
projected[raceResults] = raceResultsSource

for label, source in pairs({
	GameplayInputGate = INPUT_GATE_SOURCE,
	AudioMixController = AUDIO_MIXER_SOURCE,
	LoadingArtworkCatalog = ARTWORK_CATALOG_SOURCE,
	LoadingScreenView = VIEW_SOURCE,
	LoadingTransitionRuntime = RUNTIME_SOURCE,
	LoadingTransitionController = CONTROLLER_SOURCE,
	Phase5InitialStartScreen = INITIAL_START_SCREEN_SOURCE,
}) do compile(label, source) end

-- Phase 5 V1.3 preserves every confirmed owner and the installed Grid3x2 view,
-- then upgrades only the isolated ReplicatedFirst initial/start client. The
-- companion config installer remains a separate config-only transaction.
local existingLoadingInvoke = assert(uiControllers:FindFirstChild("LoadingTransitionInvoke"), "Confirmed LoadingTransitionInvoke missing")
local existingLoadingState = assert(uiControllers:FindFirstChild("LoadingPresentationState"), "Confirmed LoadingPresentationState missing")
local existingLoadingChanged = assert(uiControllers:FindFirstChild("LoadingPresentationChanged"), "Confirmed LoadingPresentationChanged missing")
local existingLoadingController = assert(uiControllers:FindFirstChild("LoadingTransitionController_Active"), "Confirmed LoadingTransitionController_Active missing")
assert(existingLoadingInvoke:IsA("BindableFunction"), "LoadingTransitionInvoke must be a BindableFunction")
assert(existingLoadingState:IsA("Folder"), "LoadingPresentationState must be a Folder")
assert(existingLoadingChanged:IsA("BindableEvent"), "LoadingPresentationChanged must be a BindableEvent")
assert(existingLoadingController:IsA("LocalScript"), "LoadingTransitionController_Active must be a LocalScript")

local existingInputGate = assert(find(clientModules, "Input.GameplayInputGate"), "Confirmed GameplayInputGate missing")
local existingAudioMixer = assert(find(clientModules, "Audio.AudioMixController"), "Confirmed AudioMixController missing")
local existingLoadingPackage = assert(ReplicatedFirst:FindFirstChild("NTRLoading"), "Confirmed ReplicatedFirst.NTRLoading missing")
local existingCatalog = assert(existingLoadingPackage:FindFirstChild("LoadingArtworkCatalog"), "Confirmed LoadingArtworkCatalog missing")
local existingView = assert(existingLoadingPackage:FindFirstChild("LoadingScreenView"), "Confirmed LoadingScreenView missing")
local existingRuntime = assert(existingLoadingPackage:FindFirstChild("LoadingTransitionRuntime"), "Confirmed LoadingTransitionRuntime missing")
for object, marker in pairs({
	[existingInputGate] = "NTR_LOADING_SYSTEM_PHASE1_GAMEPLAY_INPUT_GATE_V1",
	[existingAudioMixer] = "NTR_LOADING_SYSTEM_PHASE1_AUDIO_MIXER_V1_1",
	[existingCatalog] = "NTR_LOADING_SYSTEM_PHASE1_ARTWORK_CATALOG_V1_2",
	[existingRuntime] = "NTR_LOADING_SYSTEM_PHASE1_TRANSITION_RUNTIME_V1_2",
	[existingLoadingController] = "NTR_LOADING_SYSTEM_PHASE1_CONTROLLER_V1",
}) do
	assert(object:IsA("ModuleScript") or object:IsA("LocalScript") or object:IsA("Script"), object:GetFullName() .. " must contain source")
	assert(string.find(object.Source, marker, 1, true), object.Name .. " confirmed foundation marker missing: " .. marker)
	compile(object.Name .. "_confirmed", object.Source)
end
assert(existingView:IsA("ModuleScript"), "LoadingScreenView must be a ModuleScript")
assert(hasCommentMarker(existingView.Source, VIEW_REVISION) or hasCommentMarker(existingView.Source, PREVIOUS_VIEW_REVISION), "LoadingScreenView has unknown source")
compile(existingView.Name .. "_confirmed", existingView.Source)

local existingLoadingConfig = assert(find(kit, "Config.UI.LoadingSystem"), "Confirmed LoadingSystem config missing")
assert(existingLoadingConfig:IsA("Folder"), "LoadingSystem config must be a Folder")
assert(tonumber(existingLoadingConfig:GetAttribute("MinimumVisibleSeconds")), "LoadingSystem minimum visibility config missing")
assert(tonumber(existingLoadingConfig:GetAttribute("FadeOutSeconds")), "LoadingSystem fade config missing")
for _, attributeName in ipairs({
	"StartScreenPlayIconAssetId",
	"StartScreenShopIconAssetId",
	"GridPreloadAttempts",
	"GridPreloadRetrySeconds",
	"GridPromotionWaitSeconds",
	"StartScreenButtonYScaleDesktop",
	"StartScreenButtonYScaleLandscapePhone",
	"StartScreenButtonYScalePortrait",
}) do
	assert(existingLoadingConfig:GetAttribute(attributeName) ~= nil, attributeName .. " missing; run scripts/roblox_ui_loading_start_screen_config.lua first")
end
local existingArtwork = assert(find(existingLoadingConfig, "Artworks.NeoTokyoStreet01"), "Confirmed loading artwork entry missing")
assert(existingArtwork:GetAttribute("Layout") == "Grid3x2", "Confirmed Grid3x2 artwork layout missing")
assert(existingArtwork:GetAttribute("StartScreenEligible") == true, "Confirmed artwork is not StartScreenEligible")
assert(string.find(raceTransition.Source, "NTR_RACING_STAGING_READINESS_GATE_V1", 1, true), "Confirmed race-staging readiness baseline missing")

local existingInitialStart = existingLoadingPackage:FindFirstChild("InitialLoadingAndStartScreenClient")
if existingInitialStart then
	assert(existingInitialStart:IsA("LocalScript"), "InitialLoadingAndStartScreenClient must be a LocalScript")
	local knownPhase5 = hasCommentMarker(existingInitialStart.Source, INITIAL_REVISION)
		or hasCommentMarker(existingInitialStart.Source, PREVIOUS_INITIAL_REVISION)
		or hasCommentMarker(existingInitialStart.Source, LEGACY_INITIAL_REVISION)
	assert(knownPhase5, "Existing InitialLoadingAndStartScreenClient has unknown source")
end

if MODE == "AUDIT" then
	assert(existingInitialStart, "Phase 5 initial start controller missing")
	assert(hasCommentMarker(existingInitialStart.Source, INITIAL_REVISION), "Phase 5 configured button-position revision missing")
	assert(hasCommentMarker(existingView.Source, VIEW_REVISION), "Phase 5 Grid3x2 fetch-status view revision missing")
	compile(existingInitialStart.Name .. "_audit", existingInitialStart.Source)
	compile(existingView.Name .. "_audit", existingView.Source)
	info("AUDIT PASS: confirmed Phase 1-4 foundation, race readiness, responsive configured start client and retryable Grid3x2 view. No Studio objects changed.")
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

local initialWasCreated = false
local initialOriginalSource = existingInitialStart and existingInitialStart.Source or nil
local initialOriginalDisabled = existingInitialStart and existingInitialStart.Disabled or nil
local viewOriginalSource = existingView.Source
local viewChanged = false

local function rollback(problem)
	if viewChanged then pcall(function() existingView.Source = viewOriginalSource end) end
	if initialWasCreated then
		pcall(function() if existingInitialStart and existingInitialStart.Parent then existingInitialStart:Destroy() end end)
	elseif existingInitialStart then
		pcall(function() existingInitialStart.Source = initialOriginalSource; existingInitialStart.Disabled = initialOriginalDisabled end)
	end
	error("[" .. PHASE .. "] rolled back: " .. tostring(problem), 0)
end

local ok, problem = xpcall(function()
	if not hasCommentMarker(existingView.Source, VIEW_REVISION) then
		existingView.Source = VIEW_SOURCE
		viewChanged = true
	end
	if not existingInitialStart then
		existingInitialStart = Instance.new("LocalScript")
		existingInitialStart.Name = "InitialLoadingAndStartScreenClient"
		existingInitialStart.Source = INITIAL_START_SCREEN_SOURCE
		existingInitialStart.Disabled = false
		existingInitialStart.Parent = existingLoadingPackage
		initialWasCreated = true
	elseif not hasCommentMarker(existingInitialStart.Source, INITIAL_REVISION) then
		existingInitialStart.Source = INITIAL_START_SCREEN_SOURCE
		existingInitialStart.Disabled = false
	end
	assert(existingInitialStart.Parent == existingLoadingPackage, "Phase 5 initial client parent missing")
	assert(hasCommentMarker(existingInitialStart.Source, INITIAL_REVISION), "Phase 5 initial client marker missing")
	assert(hasCommentMarker(existingView.Source, VIEW_REVISION), "Phase 5 Grid3x2 view marker missing")
	compile(existingInitialStart.Name .. "_final", existingInitialStart.Source)
	compile(existingView.Name .. "_final", existingView.Source)
	for object, marker in pairs({ [raceTransition] = "NTR_LOADING_SYSTEM_PHASE4_RACE_TRANSITION_BRIDGE_V1", [raceEntry] = "NTR_LOADING_SYSTEM_PHASE4_TIME_TRIAL_START_V1", [raceSession] = "NTR_LOADING_SYSTEM_PHASE4_ACTIVE_RACE_EXIT_V1", [raceResults] = "NTR_LOADING_SYSTEM_PHASE4_RESULTS_EXIT_V1" }) do
		assert(string.find(object.Source, marker, 1, true), object.Name .. " confirmed Phase 4 marker changed")
	end
	assert(raceTransitionRequest.Parent == racingControllers, "RaceTransitionRequest hierarchy changed")
end, debug.traceback)

if not ok then rollback(problem) end

info("PASS: confirmed Phase 4 integrations preserved during the Phase 5 transaction.")
info("PASS: " .. REVISION .. " installed with responsive safe-area button positioning; retryable per-tile fetch diagnostics preserved.")
info("Confirmed Phase 1-4 loading integrations and race-staging readiness marker were preserved; no bootstrap, camera, spawn, persistence, economy or dealership server owner changed.")
info("Restart Play. Expect '[NTR Loading Grid] ... promoted Grid3x2 composite.'; any retained fallback warning now names the exact failed tile/status.")
