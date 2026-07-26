-- Neo Tokyo Racers - Presentation Audio and Reliable Ignition V1.3.2
-- Run in the Roblox Studio Edit-mode Command Bar.
-- Change MODE to "AUDIT" after INSTALL passes. DISABLE retains all sources/config.

local MODE = "INSTALL"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local REVISION = "NTR_PRESENTATION_AUDIO_UI_PREVIEW_RACE_V1_3_2"
local BRIDGE_REVISION = "NTR_PRESENTATION_AUDIO_BRIDGE_V1_3"
local CATALOG_REVISION = "NTR_PRESENTATION_AUDIO_CATALOG_V1"
local CONTROLLER_REVISION = "NTR_PRESENTATION_AUDIO_CONTROLLER_V1_3_2_IMMEDIATE_ONESHOTS"
local STARTER_REVISION = "NTR_PRESENTATION_AUDIO_RUNTIME_CLIENT_V1"
local MODULE_SHOP_REVISION = "NTR_PRESENTATION_AUDIO_TRANSACTION_OUTCOMES_V1"
local MODULE_SHOP_REFINEMENT_REVISION = "NTR_PRESENTATION_AUDIO_MODULE_PURCHASE_EQUIP_CUE_V1_1"
local MODULE_SHOP_VEHICLE_PURCHASE_REVISION = "NTR_PRESENTATION_AUDIO_VEHICLE_PURCHASE_CUE_V1_2"
local OWNED_GARAGE_REVISION = "NTR_PRESENTATION_AUDIO_OWNED_GARAGE_OUTCOMES_V1"
local OWNED_GARAGE_SEMANTIC_REVISION = "NTR_PRESENTATION_AUDIO_OWNED_GARAGE_SEMANTIC_CUES_V1_3"
local VEHICLE_IGNITION_V1_3_REVISION = "NTR_AUDIO_VEHICLE_CLIENT_V4_RELIABLE_LOCAL_IGNITION"
local VEHICLE_IGNITION_REVISION = "NTR_AUDIO_VEHICLE_CLIENT_V5_CONFIRMED_LOCAL_IGNITION"
local PREVIEW_REVISION = "NTR_PRESENTATION_AUDIO_PREVIEW_PROFILE_V1"
local ONBOARDING_REVISION = "NTR_PRESENTATION_AUDIO_OBJECTIVES_V1"
local ONBOARDING_REFINEMENT_REVISION = "NTR_PRESENTATION_AUDIO_ONBOARDING_HOVER_SILENT_V1_1"

local function child(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), ("Missing %s.%s (%s)"):format(parent:GetFullName(), name, className))
	return object
end

local kit = child(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local config = child(kit, "Config", "Folder")
local audioConfig = child(config, "Audio", "Folder")
local audioGlobal = child(audioConfig, "Global", "Folder")
local profiles = child(audioConfig, "VehicleProfiles", "Folder")
local shared = child(kit, "Shared", "Folder")
local modules = child(shared, "Modules", "Folder")
local clientModules = child(modules, "Client", "Folder")
local audioModules = child(clientModules, "Audio", "Folder")
local remotes = child(shared, "Remotes", "Folder")
local racingRemotes = child(remotes, "Racing", "Folder")
child(racingRemotes, "RaceEvent", "RemoteEvent")

for _, name in ipairs({ "NTR_UI", "NTR_Vehicle", "NTR_GameplaySFX" }) do
	child(SoundService, name, "SoundGroup")
end

local starterScripts = child(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = child(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = child(clientRoot, "Controllers", "Folder")
local audioControllers = child(controllers, "Audio", "Folder")
local uiControllers = child(controllers, "UI", "Folder")
local previewControllers = child(controllers, "Preview", "Folder")

local moduleShop = child(uiControllers, "ModuleShopUIController", "ModuleScript")
local ownedGarage = child(uiControllers, "OwnedGarageWorkspaceController", "ModuleScript")
local onboarding = child(uiControllers, "OnboardingClient_Active", "LocalScript")
local previewVehicle = child(previewControllers, "PreviewVehicleController", "ModuleScript")
local vehicleAudioController = child(audioModules, "VehicleAudioController", "ModuleScript")

local function has(source, marker)
	return string.find(source, marker, 1, true) ~= nil
end

local function compile(label, source)
	local fn, problem = loadstring(source, "=" .. label)
	assert(fn, label .. " compile failed: " .. tostring(problem))
end

local function replaceOnce(source, old, new, label)
	local firstStart, firstEnd = string.find(source, old, 1, true)
	assert(firstStart, label .. " anchor missing; refresh/inspect the live mirror instead of guessing")
	assert(not string.find(source, old, firstEnd + 1, true), label .. " anchor is not unique")
	return string.sub(source, 1, firstStart - 1) .. new .. string.sub(source, firstEnd + 1)
end

local BRIDGE_SOURCE = [=[
-- NTR_PRESENTATION_AUDIO_BRIDGE_V1_3
local Bridge = {}
local subscribers = {}
local nextId = 0

local successCue = {
	Purchase = "UI.PurchaseSuccess",
	VehiclePurchase = "UI.VehiclePurchaseSuccess",
	ModuleEquip = "UI.ModuleEquipSuccess",
	DecorationPurchase = "UI.DecorationPurchaseSuccess",
	DecorationEquip = "UI.DecorationEquipSuccess",
	StructurePurchase = "UI.StructurePurchaseSuccess",
	StructureEquip = "UI.StructureEquipSuccess",
	Equip = "UI.EquipSuccess",
	Upgrade = "UI.UpgradeSuccess",
	Save = "UI.SaveSuccess",
}

local purchaseKinds = {
	Purchase = true,
	VehiclePurchase = true,
	DecorationPurchase = true,
	StructurePurchase = true,
}

function Bridge.Subscribe(callback)
	assert(type(callback) == "function", "PresentationAudioBridge.Subscribe requires a function")
	nextId += 1
	local id = nextId
	subscribers[id] = callback
	return function()
		subscribers[id] = nil
	end
end

function Bridge.Emit(cueId, payload)
	local id = tostring(cueId or "")
	if id == "" then return false end
	for _, callback in pairs(subscribers) do
		local ok, problem = pcall(callback, id, type(payload) == "table" and payload or {})
		if not ok then warn("[NTR Presentation Audio] subscriber failed safely: " .. tostring(problem)) end
	end
	return true
end

function Bridge.Result(kind, result, payload)
	local row = type(payload) == "table" and table.clone(payload) or {}
	row.Kind = tostring(kind or "")
	row.Message = type(result) == "table" and result.Message or nil
	local success = type(result) == "table" and result.Success == true
	if success then
		return Bridge.Emit(successCue[row.Kind] or "UI.SaveSuccess", row)
	end
	return Bridge.Emit(purchaseKinds[row.Kind] and "UI.PurchaseRejected" or "UI.ActionRejected", row)
end

return Bridge
]=]

local CATALOG_SOURCE = [=[
-- NTR_PRESENTATION_AUDIO_CATALOG_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = {}
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audio = kit.Config:WaitForChild("Audio")
local root = audio:WaitForChild("Presentation")
local global = root:WaitForChild("Global")

local function assetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

local function split(path)
	local result = {}
	for segment in string.gmatch(tostring(path or ""), "[^%.]+") do table.insert(result, segment) end
	return result
end

local function cueFolder(cueId)
	local at = root
	for _, segment in ipairs(split(cueId)) do
		at = at and at:FindFirstChild(segment)
	end
	return at and at:IsA("Folder") and at or nil
end

function Catalog.GlobalBool(name, fallback)
	local value = global:GetAttribute(name)
	if typeof(value) == "boolean" then return value end
	return fallback == true
end

function Catalog.GlobalNumber(name, fallback)
	local value = global:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

function Catalog.Enabled(scope)
	if audio:WaitForChild("Global"):GetAttribute("AudioSystemEnabled") ~= true then return false end
	if global:GetAttribute("PresentationAudioEnabled") ~= true then return false end
	local key = tostring(scope or "") .. "AudioEnabled"
	return global:GetAttribute(key) ~= false
end

function Catalog.MasterGain(scope)
	return math.max(0, Catalog.GlobalNumber(tostring(scope or "") .. "MasterGain", 1))
end

function Catalog.AssetId(raw)
	return assetId(raw)
end

function Catalog.Get(cueId)
	local folder = cueFolder(cueId)
	if not folder then return nil end
	return {
		Id = tostring(cueId),
		Enabled = folder:GetAttribute("Enabled") ~= false,
		AssetId = assetId(folder:GetAttribute("AssetId")),
		Gain = math.max(0, tonumber(folder:GetAttribute("Gain")) or 1),
		Pitch = math.clamp(tonumber(folder:GetAttribute("Pitch")) or 1, 0.1, 4),
		CooldownSeconds = math.max(0, tonumber(folder:GetAttribute("CooldownSeconds")) or 0),
		MaximumVoices = math.max(1, math.floor(tonumber(folder:GetAttribute("MaximumVoices")) or 1)),
		Bus = tostring(folder:GetAttribute("Bus") or "UI"),
		ProfileLayer = tostring(folder:GetAttribute("ProfileLayer") or ""),
		FadeInSeconds = math.max(0, tonumber(folder:GetAttribute("FadeInSeconds")) or 0.15),
		FadeOutSeconds = math.max(0, tonumber(folder:GetAttribute("FadeOutSeconds")) or 0.2),
		CrossfadeSeconds = math.max(0, tonumber(folder:GetAttribute("CrossfadeSeconds")) or 0.25),
		MissingPreviewGraceSeconds = math.max(0, tonumber(folder:GetAttribute("MissingPreviewGraceSeconds")) or 0.5),
	}
end

function Catalog.Root()
	return root
end

return Catalog
]=]

local CONTROLLER_SOURCE = [=[
-- NTR_PRESENTATION_AUDIO_CONTROLLER_V1_3_2_IMMEDIATE_ONESHOTS
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Controller = {}
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audioModules = kit.Shared.Modules.Client:WaitForChild("Audio")
local Catalog = require(audioModules:WaitForChild("PresentationAudioCatalog"))
local Bridge = require(audioModules:WaitForChild("PresentationAudioBridge"))
local raceEvent = kit.Shared.Remotes.Racing:WaitForChild("RaceEvent")
local profiles = kit.Config.Audio:WaitForChild("VehicleProfiles")

local BUS_GROUPS = {
	UI = "NTR_UI",
	Vehicle = "NTR_Vehicle",
	GameplaySFX = "NTR_GameplaySFX",
}

local connections = {}
local buttonConnections = setmetatable({}, { __mode = "k" })
local oneShots = {}
local oneShotRecords = setmetatable({}, { __mode = "k" })
local lastPlayed = {}
local semanticKeys = {}
local loops = {}
local runtimeRoot
local unsubscribeBridge
local started = false
local countdownGeneration = 0
local lastPreviewSeenAt = -math.huge

local function debugLog(message)
	if Catalog.GlobalBool("DebugPresentationAudio", false) then
		print("[NTR Presentation Audio] " .. tostring(message))
	end
end

local function scopeFor(cueId)
	local prefix = string.match(tostring(cueId or ""), "^([^.]+)")
	if prefix == "UI" then return "UI" end
	if prefix == "Preview" then return "Preview" end
	if prefix == "Objective" then return "Objective" end
	return "Race"
end

local function groupFor(bus)
	local group = SoundService:FindFirstChild(BUS_GROUPS[bus] or BUS_GROUPS.UI)
	return group and group:IsA("SoundGroup") and group or nil
end

local function newSound(name)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.RollOffMode = Enum.RollOffMode.Inverse
	sound.Parent = runtimeRoot
	return sound
end

local function activeVoiceCount(cueId)
	local count = 0
	for sound, record in pairs(oneShotRecords) do
		if sound.Parent and sound.Playing and record.CueId == cueId then count += 1 end
	end
	return count
end

local function availableOneShot(cueId, assetId)
	for _, sound in ipairs(oneShots) do
		local record = oneShotRecords[sound]
		if sound.Parent and not sound.Playing and record
			and record.CueId == cueId and sound.SoundId == assetId then
			return sound
		end
	end
	for _, sound in ipairs(oneShots) do
		if sound.Parent and not sound.Playing then return sound end
	end
	local cap = math.max(1, math.floor(Catalog.GlobalNumber("MaximumOneShotVoices", 8)))
	if #oneShots >= cap then return nil end
	local sound = newSound("OneShot_" .. tostring(#oneShots + 1))
	sound.Looped = false
	table.insert(oneShots, sound)
	return sound
end

local function play(cueId, payload)
	local scope = scopeFor(cueId)
	if not Catalog.Enabled(scope) then return false end
	local definition = Catalog.Get(cueId)
	if not (definition and definition.Enabled and definition.AssetId ~= "") then return false end
	local now = os.clock()
	if now - (lastPlayed[cueId] or -math.huge) < definition.CooldownSeconds then return false end
	local eventKey = type(payload) == "table" and tostring(payload.Key or "") or ""
	if eventKey ~= "" and semanticKeys[cueId] == eventKey then return false end
	if activeVoiceCount(cueId) >= definition.MaximumVoices then return false end
	local sound = availableOneShot(cueId, definition.AssetId)
	if not sound then return false end
	lastPlayed[cueId] = now
	if eventKey ~= "" then semanticKeys[cueId] = eventKey end
	sound:Stop()
	sound.SoundId = definition.AssetId
	sound.Volume = definition.Gain * Catalog.MasterGain(scope)
	sound.PlaybackSpeed = definition.Pitch
	sound.SoundGroup = groupFor(definition.Bus)
	oneShotRecords[sound] = { CueId = cueId, StartedAt = now }
	sound.TimePosition = 0
	sound:Play()
	debugLog("play " .. cueId)
	return true
end

local function warmConfiguredOneShots()
	if not Catalog.GlobalBool("PreloadOneShotsEnabled", true) then return end
	local root = Catalog.Root()
	local cap = math.max(1, math.floor(Catalog.GlobalNumber("PreloadOneShotAssetLimit", 24)))
	local sounds, seen = {}, {}
	for _, sectionName in ipairs({ "UI", "Objective", "Racing" }) do
		local section = root:FindFirstChild(sectionName)
		if section then
			for _, cue in ipairs(section:GetChildren()) do
				local assetId = Catalog.AssetId(cue:GetAttribute("AssetId"))
				if cue:IsA("Folder") and cue:GetAttribute("Enabled") ~= false
					and assetId ~= "" and not seen[assetId] and #sounds < cap then
					seen[assetId] = true
					local sound = Instance.new("Sound")
					sound.Name = "Warm_" .. sectionName .. "_" .. cue.Name
					sound.SoundId = assetId
					sound.Volume = 0
					sound.Parent = runtimeRoot
					table.insert(sounds, sound)
				end
			end
		end
	end
	if #sounds == 0 then return end
	task.spawn(function()
		local ok, problem = pcall(function() ContentProvider:PreloadAsync(sounds) end)
		for _, sound in ipairs(sounds) do if sound.Parent then sound:Destroy() end end
		if not ok then debugLog("one-shot warmup failed safely: " .. tostring(problem)) end
	end)
end

local function fade(sound, target, seconds, destroyAtEnd)
	task.spawn(function()
		if not (sound and sound.Parent) then return end
		local startVolume = sound.Volume
		local duration = math.max(0, tonumber(seconds) or 0)
		local startedAt = os.clock()
		repeat
			if not sound.Parent then return end
			local alpha = duration == 0 and 1 or math.clamp((os.clock() - startedAt) / duration, 0, 1)
			sound.Volume = startVolume + (target - startVolume) * alpha
			if alpha >= 1 then break end
			RunService.Heartbeat:Wait()
		until false
		if destroyAtEnd and sound.Parent then sound:Destroy() end
	end)
end

local function transitionLoop(name, desired)
	local state = loops[name] or {}
	loops[name] = state
	if desired and state.Key == desired.Key and state.Sound and state.Sound.Parent then
		state.Sound.PlaybackSpeed = desired.Pitch
		return
	end
	local previous = state.Sound
	state.Sound = nil
	state.Key = desired and desired.Key or nil
	if desired then
		local sound = newSound("Loop_" .. name)
		sound.SoundId = desired.AssetId
		sound.Volume = 0
		sound.PlaybackSpeed = desired.Pitch
		sound.Looped = true
		sound.SoundGroup = groupFor(desired.Bus)
		state.Sound = sound
		sound:Play()
		fade(sound, desired.Volume, previous and desired.CrossfadeSeconds or desired.FadeInSeconds, false)
	end
	if previous and previous.Parent then
		local seconds = desired and desired.CrossfadeSeconds or (state.LastFadeOutSeconds or 0.2)
		fade(previous, 0, seconds, true)
	end
	if desired then state.LastFadeOutSeconds = desired.FadeOutSeconds end
end

local function findPreview()
	local clientOnly = Workspace:FindFirstChild("_NTR_ClientOnly")
	local root = (clientOnly and clientOnly:FindFirstChild("VehiclePreview")) or Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW")
	if not root then return nil, nil end
	for _, object in ipairs(root:GetChildren()) do
		if object:IsA("Model") then return root, object end
	end
	return root, nil
end

local function loopDefinition(cueId, root, vehicle)
	local definition = Catalog.Get(cueId)
	if not (definition and definition.Enabled) then return nil end
	local profileId = tostring((root and root:GetAttribute("PreviewAudioProfileId"))
		or (vehicle and (vehicle:GetAttribute("ResolvedAudioProfileId") or vehicle:GetAttribute("StandardAudioProfileId")))
		or "GENERIC_STANDARD_AUDIO")
	local profile = profiles:FindFirstChild(profileId) or profiles:FindFirstChild("GENERIC_STANDARD_AUDIO")
	if not profile then return nil end
	local layer = definition.ProfileLayer
	local assetId = definition.AssetId
	if assetId == "" and layer ~= "" then assetId = Catalog.AssetId(profile:GetAttribute(layer .. "AssetId")) end
	if assetId == "" then return nil end
	local profileGain = layer ~= "" and (tonumber(profile:GetAttribute(layer .. "Gain")) or 1) or 1
	local profilePitch = layer ~= "" and (tonumber(profile:GetAttribute(layer .. "Pitch")) or 1) or 1
	local master = tonumber(profile:GetAttribute("ProfileMasterGain")) or 1
	local volume = definition.Gain * profileGain * master * Catalog.MasterGain("Preview")
	local pitch = definition.Pitch * profilePitch
	return {
		Key = table.concat({ profileId, assetId, layer, string.format("%.4f", volume), string.format("%.4f", pitch) }, "|"),
		AssetId = assetId,
		Volume = volume,
		Pitch = pitch,
		Bus = definition.Bus,
		FadeInSeconds = definition.FadeInSeconds,
		FadeOutSeconds = definition.FadeOutSeconds,
		CrossfadeSeconds = definition.CrossfadeSeconds,
		MissingPreviewGraceSeconds = definition.MissingPreviewGraceSeconds,
	}
end

local function updatePreview()
	if not Catalog.Enabled("Preview") then
		transitionLoop("PreviewIdle", nil)
		transitionLoop("PreviewBoost", nil)
		return
	end
	local root, vehicle = findPreview()
	if vehicle then
		lastPreviewSeenAt = os.clock()
		local idle = loopDefinition("Preview.IdleLoop", root, vehicle)
		transitionLoop("PreviewIdle", idle)
		local mode = root and tostring(root:GetAttribute("PreviewVFXMode") or "Idle") or "Idle"
		transitionLoop("PreviewBoost", mode == "ThrustColour" and loopDefinition("Preview.BoostLoop", root, vehicle) or nil)
		return
	end
	local definition = Catalog.Get("Preview.IdleLoop")
	local grace = definition and definition.MissingPreviewGraceSeconds or 0.5
	if os.clock() - lastPreviewSeenAt > grace then
		transitionLoop("PreviewIdle", nil)
		transitionLoop("PreviewBoost", nil)
	end
end

local function hasVisibleContent(button)
	if button:IsA("TextButton") and string.match(button.Text or "", "%S") then return true end
	if button:IsA("ImageButton") and tostring(button.Image or "") ~= "" then return true end
	if button.BackgroundTransparency < 0.98 then return true end
	for _, object in ipairs(button:GetDescendants()) do
		if object:IsA("TextLabel") and string.match(object.Text or "", "%S") then return true end
		if object:IsA("ImageLabel") and tostring(object.Image or "") ~= "" then return true end
	end
	return false
end

local function visibleAndActive(button)
	if not (button.Parent and button.Active and hasVisibleContent(button)) then return false end
	local at = button
	while at and at ~= playerGui do
		if at:IsA("GuiObject") and not at.Visible then return false end
		if at:IsA("LayerCollector") and not at.Enabled then return false end
		if at:GetAttribute("UIAudioSilent") == true then return false end
		at = at.Parent
	end
	return at == playerGui
end

local function bindButton(button)
	if not button:IsA("GuiButton") or buttonConnections[button] then return end
	local owned = {}
	buttonConnections[button] = owned
	table.insert(owned, button.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled and Catalog.GlobalBool("MouseHoverEnabled", true) and visibleAndActive(button) then
			play(tostring(button:GetAttribute("UIAudioHoverCue") or "UI.Hover"), { Button = button.Name })
		end
	end))
	table.insert(owned, button.SelectionGained:Connect(function()
		if UserInputService.GamepadEnabled and Catalog.GlobalBool("ControllerFocusHoverEnabled", true) and visibleAndActive(button) then
			play(tostring(button:GetAttribute("UIAudioHoverCue") or "UI.Hover"), { Button = button.Name })
		end
	end))
	table.insert(owned, button.Activated:Connect(function()
		if button:GetAttribute("UIAudioSuppressClick") ~= true and visibleAndActive(button) then
			play(tostring(button:GetAttribute("UIAudioClickCue") or "UI.Click"), { Button = button.Name })
		end
	end))
	table.insert(owned, button.Destroying:Connect(function()
		local list = buttonConnections[button]
		buttonConnections[button] = nil
		for _, connection in ipairs(list or {}) do connection:Disconnect() end
	end))
end

local function startCountdown(payload)
	countdownGeneration += 1
	local generation = countdownGeneration
	local goAt = tonumber(payload.GoAtServerTime)
	if not goAt then return end
	local maximum = math.max(1, math.floor(tonumber(payload.Countdown) or 5))
	local runId = tostring(payload.RunId or payload.EventId or "Countdown")
	task.spawn(function()
		local previous
		while started and generation == countdownGeneration do
			local remaining = goAt - Workspace:GetServerTimeNow()
			if remaining <= 0 then return end
			local seconds = math.clamp(math.ceil(remaining), 1, maximum)
			if seconds ~= previous then
				previous = seconds
				play("Racing.CountdownTick", { Key = runId .. ":" .. tostring(seconds), Countdown = seconds })
			end
			task.wait(0.03)
		end
	end)
end

local function onRaceEvent(payload)
	if type(payload) ~= "table" then return end
	local kind = tostring(payload.Type or "")
	local runId = tostring(payload.RunId or payload.EventId or "Race")
	if kind == "TimeTrialCountdownScheduled" or kind == "RaceCountdownScheduled" then
		startCountdown(payload)
	elseif kind == "TimeTrialCountdown" or kind == "RaceCountdown" then
		play("Racing.CountdownTick", { Key = runId .. ":" .. tostring(payload.Countdown or ""), Countdown = payload.Countdown })
	elseif kind == "TimeTrialStarted" or kind == "RaceStarted" then
		countdownGeneration += 1
		play("Racing.CountdownGo", { Key = runId .. ":GO" })
	elseif kind == "TimeTrialCheckpoint" or kind == "RaceCheckpoint" then
		local key = table.concat({ runId, tostring(payload.CurrentLap or payload.Lap or 1), tostring(payload.CheckpointIndex or payload.NextGateIndex or "") }, ":")
		play("Racing.Checkpoint", { Key = key })
	elseif kind == "TimeTrialLapCompleted" or kind == "RaceLapCompleted" then
		play("Racing.LapComplete", { Key = runId .. ":Lap:" .. tostring(payload.Lap or payload.CurrentLap or "") })
	elseif kind == "TimeTrialFinished" or kind == "RaceFinished" then
		countdownGeneration += 1
		play("Racing.RaceFinish", { Key = runId .. ":Finish" })
	elseif kind == "RaceDNF" then
		countdownGeneration += 1
		play("Racing.RaceDNF", { Key = runId .. ":DNF" })
	elseif kind == "RaceStaged" then
		play("Racing.MatchFound", { Key = runId .. ":Staged" })
	elseif kind == "TimeTrialEnded" or kind == "TimeTrialError" or kind == "RaceEnded"
		or kind == "RaceExitedToStart" or kind == "RaceQueueError" then
		countdownGeneration += 1
	end
end

function Controller.Start()
	if started then return Controller end
	started = true
	local old = SoundService:FindFirstChild("NTR_PresentationAudioRuntime_Local")
	if old then old:Destroy() end
	runtimeRoot = Instance.new("Folder")
	runtimeRoot.Name = "NTR_PresentationAudioRuntime_Local"
	runtimeRoot.Parent = SoundService
	warmConfiguredOneShots()
	for _, object in ipairs(playerGui:GetDescendants()) do bindButton(object) end
	table.insert(connections, playerGui.DescendantAdded:Connect(bindButton))
	table.insert(connections, raceEvent.OnClientEvent:Connect(onRaceEvent))
	unsubscribeBridge = Bridge.Subscribe(function(cueId, payload) play(cueId, payload) end)
	task.spawn(function()
		while started do
			updatePreview()
			task.wait(1 / math.max(1, Catalog.GlobalNumber("PreviewPollHz", 5)))
		end
	end)
	debugLog("started")
	return Controller
end

function Controller.Stop()
	if not started then return end
	started = false
	countdownGeneration += 1
	if unsubscribeBridge then unsubscribeBridge(); unsubscribeBridge = nil end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	for button, list in pairs(buttonConnections) do
		for _, connection in ipairs(list) do connection:Disconnect() end
		buttonConnections[button] = nil
	end
	if runtimeRoot then runtimeRoot:Destroy(); runtimeRoot = nil end
	table.clear(oneShots)
	table.clear(loops)
end

function Controller.Counts()
	local buttons, playing = 0, 0
	for _ in pairs(buttonConnections) do buttons += 1 end
	for _, sound in ipairs(oneShots) do if sound.Parent and sound.Playing then playing += 1 end end
	return { Buttons = buttons, OneShots = #oneShots, PlayingOneShots = playing }
end

return Controller
]=]

local STARTER_SOURCE = [=[
-- NTR_PRESENTATION_AUDIO_RUNTIME_CLIENT_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(kit.Shared.Modules.Client.Audio:WaitForChild("PresentationAudioController"))
	controller.Start()
	return controller
end)

if not ok then
	warn("[NTR Presentation Audio] Runtime failed safely: " .. tostring(result))
end
]=]

local function projectModuleShop(source)
	if has(source, MODULE_SHOP_VEHICLE_PURCHASE_REVISION) then return source end
	if has(source, MODULE_SHOP_REFINEMENT_REVISION) then
		source = replaceOnce(source,
			"-- " .. MODULE_SHOP_REFINEMENT_REVISION,
			"-- " .. MODULE_SHOP_REFINEMENT_REVISION .. "\n-- " .. MODULE_SHOP_VEHICLE_PURCHASE_REVISION,
			"vehicle-purchase revision")
		source = replaceOnce(source,
			'local outcomeAudioKind=actionName=="BuyModuleInstance" and result.Success==true and "ModuleEquip" or audioKind',
			'local outcomeAudioKind=audioKind\n\tif result.Success==true then\n\t\tif actionName=="BuyModuleInstance" then outcomeAudioKind="ModuleEquip"\n\t\telseif actionName=="BuyCockpitInstance" then outcomeAudioKind="VehiclePurchase" end\n\tend',
			"vehicle-purchase success cue")
		return source
	end
	if has(source, MODULE_SHOP_REVISION) then
		source = replaceOnce(source,
			"-- " .. MODULE_SHOP_REVISION,
			"-- " .. MODULE_SHOP_REVISION .. "\n-- " .. MODULE_SHOP_REFINEMENT_REVISION .. "\n-- " .. MODULE_SHOP_VEHICLE_PURCHASE_REVISION,
			"module-shop refinement revision")
		source = replaceOnce(source,
			'if result.Catalog then self.State.Catalog=result.Catalog end; if result.Profile then self.State.Profile=result.Profile end\n\tif audioKind then AudioBridge.Result(audioKind,result,{Action=actionName}) end\n\treturn result',
			'if result.Catalog then self.State.Catalog=result.Catalog end; if result.Profile then self.State.Profile=result.Profile end\n\tlocal outcomeAudioKind=audioKind\n\tif result.Success==true then\n\t\tif actionName=="BuyModuleInstance" then outcomeAudioKind="ModuleEquip"\n\t\telseif actionName=="BuyCockpitInstance" then outcomeAudioKind="VehiclePurchase" end\n\tend\n\tif outcomeAudioKind then AudioBridge.Result(outcomeAudioKind,result,{Action=actionName}) end\n\treturn result',
			"module-purchase equip cue")
		return source
	end
	assert(has(source, "NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3"), "Unknown ModuleShopUIController baseline")
	source = replaceOnce(source,
		"-- NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3",
		"-- NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3\n-- " .. MODULE_SHOP_REVISION .. "\n-- " .. MODULE_SHOP_REFINEMENT_REVISION .. "\n-- " .. MODULE_SHOP_VEHICLE_PURCHASE_REVISION,
		"module-shop revision")
	source = replaceOnce(source,
		'local loadingInvoke=script.Parent:WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE2_GARAGE_UI_TRANSITIONS_V1\nlocal Adapter={}; Adapter.__index=Adapter',
		'local loadingInvoke=script.Parent:WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE2_GARAGE_UI_TRANSITIONS_V1\nlocal AudioBridge=require(kit.Shared.Modules.Client.Audio:WaitForChild("PresentationAudioBridge"))\nlocal ACTION_AUDIO_KIND={BuyCockpitInstance="Purchase",BuyGarageProperty="Purchase",BuyModuleInstance="Purchase",BuyNeon="Purchase",BuyVehicleCosmetic="Purchase",EquipModuleInstance="ModuleEquip",UpgradeModule="Upgrade"}\nlocal Adapter={}; Adapter.__index=Adapter',
		"module-shop audio bridge")
	source = replaceOnce(source, [=[
function Adapter:Call(actionName,payload)
	if self.Busy then return {Success=false,Message="Please wait."} end
	self.Busy=true; local ok,result=pcall(function() return garageInvoke:InvokeServer(actionName,payload or {}) end); self.Busy=false
	if not ok or typeof(result)~="table" then return {Success=false,Message="Garage server did not respond."} end
	if result.Catalog then self.State.Catalog=result.Catalog end; if result.Profile then self.State.Profile=result.Profile end; return result
end
]=], [=[
function Adapter:Call(actionName,payload)
	local audioKind=ACTION_AUDIO_KIND[actionName]
	if self.Busy then local result={Success=false,Message="Please wait."}; if audioKind then AudioBridge.Result(audioKind,result,{Action=actionName}) end; return result end
	self.Busy=true; local ok,result=pcall(function() return garageInvoke:InvokeServer(actionName,payload or {}) end); self.Busy=false
	if not ok or typeof(result)~="table" then result={Success=false,Message="Garage server did not respond."}; if audioKind then AudioBridge.Result(audioKind,result,{Action=actionName}) end; return result end
	if result.Catalog then self.State.Catalog=result.Catalog end; if result.Profile then self.State.Profile=result.Profile end
	local outcomeAudioKind=audioKind
	if result.Success==true then
		if actionName=="BuyModuleInstance" then outcomeAudioKind="ModuleEquip"
		elseif actionName=="BuyCockpitInstance" then outcomeAudioKind="VehiclePurchase" end
	end
	if outcomeAudioKind then AudioBridge.Result(outcomeAudioKind,result,{Action=actionName}) end
	return result
end
]=], "module-shop authoritative outcome")
	return source
end

local function projectOwnedGarage(source)
	if not has(source, OWNED_GARAGE_REVISION) then
		assert(has(source, "NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V4_CANONICAL_VERTICAL_SLICE"), "Unknown OwnedGarageWorkspaceController baseline")
		source = replaceOnce(source,
			"-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V4_CANONICAL_VERTICAL_SLICE",
			"-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V4_CANONICAL_VERTICAL_SLICE\n-- " .. OWNED_GARAGE_REVISION,
			"owned-garage revision")
		source = replaceOnce(source,
			'local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers"); local uiFolder=script.Parent;',
			'local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers"); local AudioBridge=require(kit.Shared.Modules.Client.Audio:WaitForChild("PresentationAudioBridge")); local uiFolder=script.Parent;',
			"owned-garage audio bridge")
		source = replaceOnce(source, [=[
		if busy then return end; args=type(args)=="table" and args or {}; args.BaseRevision=state and state.Revision or nil; args.RequestId=HttpService:GenerateGUID(false); busy=true; workspace:Message("SAVING GARAGE..."); local result=request(action,args); busy=false
		if not result.Success then if result.Conflict then local token=generation; if refresh(token) then render(true) end end; workspace:Message(result.Message or "Garage update failed."); return end
]=], [=[
		if busy then return end; args=type(args)=="table" and args or {}; args.BaseRevision=state and state.Revision or nil; args.RequestId=HttpService:GenerateGUID(false); busy=true; workspace:Message("SAVING GARAGE..."); local result=request(action,args); busy=false
		local audioKind=args.Action=="Purchase" and "Purchase" or ((args.Action=="Equip" or args.Action=="Place") and "Equip" or nil)
		if audioKind then AudioBridge.Result(audioKind,result,{Action=action}) end
		if not result.Success then if result.Conflict then local token=generation; if refresh(token) then render(true) end end; workspace:Message(result.Message or "Garage update failed."); return end
]=], "owned-garage authoritative outcome")
	end
	if has(source, OWNED_GARAGE_SEMANTIC_REVISION) then return source end
	source = replaceOnce(source,
		"-- " .. OWNED_GARAGE_REVISION,
		"-- " .. OWNED_GARAGE_REVISION .. "\n-- " .. OWNED_GARAGE_SEMANTIC_REVISION,
		"owned-garage semantic revision")
	source = replaceOnce(source,
		'local audioKind=args.Action=="Purchase" and "Purchase" or ((args.Action=="Equip" or args.Action=="Place") and "Equip" or nil)\n\t\tif audioKind then AudioBridge.Result(audioKind,result,{Action=action}) end',
		'local audioKind\n\t\tif action=="AssignDisplay" then audioKind=result.Success==true and "VehiclePurchase" or "Equip"\n\t\telseif action=="ConfigureStructure" then audioKind=args.Action=="Purchase" and "StructurePurchase" or (args.Action=="Equip" and "StructureEquip" or nil)\n\t\telseif action=="ConfigureDecoration" then audioKind=args.Action=="Purchase" and "DecorationPurchase" or (args.Action=="Place" and "DecorationEquip" or nil) end\n\t\tif audioKind then AudioBridge.Result(audioKind,result,{Action=action}) end',
		"owned-garage semantic outcome routing")
	return source
end

local RELIABLE_IGNITION_SOURCE = [=[

-- NTR_AUDIO_VEHICLE_CLIENT_V4_RELIABLE_LOCAL_IGNITION
-- NTR_AUDIO_VEHICLE_CLIENT_V5_CONFIRMED_LOCAL_IGNITION
-- Local startup is deliberately separate from the replaceable per-vehicle graph:
-- loading ducking and External -> Internal route rebuilds cannot cut it off.
local function loadingPresentationActive()
	local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
	local client = playerScripts and playerScripts:FindFirstChild("NeoTokyoRacersClient")
	local controllers = client and client:FindFirstChild("Controllers")
	local ui = controllers and controllers:FindFirstChild("UI")
	local state = ui and ui:FindFirstChild("LoadingPresentationState")
	return state ~= nil and state:GetAttribute("Active") == true
end

local function cleanupLocalIgnition(state)
	local handle = state.LocalIgnitionCue
	state.LocalIgnitionCue = nil
	state.LocalIgnitionReadyAt = nil
	if not handle or handle.Cleaned then return end
	handle.Cleaned = true
	Bus.Unregister(handle.Fader)
	for _, item in ipairs(handle.Objects) do
		if item.Parent then item:Destroy() end
	end
end

local function prepareLocalIgnition(state)
	if state.LocalIgnitionCue or state.LocalIgnitionPlayed then return end
	local profileId = Catalog.ResolveProfileId(state.Vehicle)
	local profile = Catalog.GetProfile(profileId)
	local assetId = profile and profile.Assets.Ignition or ""
	if not profile or assetId == "" then
		state.LocalIgnitionPlayed = true
		return
	end
	local player = newPlayer(runtimeRoot, "ReliableLocalIgnitionPlayer", assetId, false, profile.Pitches.Ignition)
	if not player then state.LocalIgnitionPlayed = true; return end
	local fader = Instance.new("AudioFader")
	fader.Name = "ReliableLocalIgnitionFader"
	fader.Parent = runtimeRoot
	local firstWire = wire(player, fader, runtimeRoot, "ReliableLocalIgnition_PlayerToFader")
	local secondWire = wire(fader, deviceOutput, runtimeRoot, "ReliableLocalIgnition_FaderToOutput")
	local gain = (profile.Gains.Ignition or 0.5) * profile.MasterGain
		* Catalog.GlobalNumber("LocalDriverGain", 1) * Catalog.GlobalNumber("OneShotMasterGain", 1)
	Bus.Register("Vehicle", fader, gain)
	local handle = {
		Player = player,
		Fader = fader,
		Objects = { firstWire, secondWire, player, fader },
		PreparedAt = os.clock(),
		Cleaned = false,
		Played = false,
		PlayAttempts = 0,
		LastPlayAttemptAt = nil,
		LifetimeScheduled = false,
	}
	state.LocalIgnitionCue = handle
	state.LocalIgnitionRequestedAt = handle.PreparedAt
	player.Ended:Once(function() cleanupLocalIgnition(state) end)
	if global:GetAttribute("DebugReliableIgnition") == true then
		print("[NTR Audio] reliable ignition prepared for " .. state.Vehicle:GetFullName())
	end
end

local function localIgnitionAssetReady(handle)
	local ok, ready = pcall(function() return handle.Player.IsReady end)
	return not ok or ready == true
end

local function confirmLocalIgnition(state, handle)
	if state.LocalIgnitionCue ~= handle or handle.Cleaned or not handle.Player.IsPlaying then return false end
	state.LocalIgnitionPlayed = true
	state.LocalIgnitionConfirmedAt = os.clock()
	if global:GetAttribute("DebugReliableIgnition") == true then
		print("[NTR Audio] reliable ignition playback confirmed for " .. state.Vehicle:GetFullName())
	end
	return true
end

local function updateLocalIgnition(state)
	if global:GetAttribute("ReliableIgnitionEnabled") == false or state.LocalIgnitionPlayed or state.LocalIgnitionAbandoned then return end
	if not state.LocalDriver then
		if state.LocalIgnitionCue and not state.LocalIgnitionCue.Played then cleanupLocalIgnition(state) end
		return
	end
	prepareLocalIgnition(state)
	local handle = state.LocalIgnitionCue
	if not handle then return end
	if confirmLocalIgnition(state, handle) then return end
	local now = os.clock()
	if handle.PlayAttempts > 0 then
		local confirmSeconds = math.max(0.03, Catalog.GlobalNumber("IgnitionPlaybackConfirmSeconds", 0.12))
		if now - (handle.LastPlayAttemptAt or now) < confirmSeconds then return end
		local maximumAttempts = math.max(1, math.floor(Catalog.GlobalNumber("IgnitionMaxPlayAttempts", 3)))
		if handle.PlayAttempts >= maximumAttempts then
			state.LocalIgnitionAbandoned = true
			warn(("[NTR Audio] reliable ignition failed to start after %d attempts for %s"):format(handle.PlayAttempts, state.Vehicle:GetFullName()))
			cleanupLocalIgnition(state)
			return
		end
		local retryDelay = math.max(0, Catalog.GlobalNumber("IgnitionRetryDelaySeconds", 0.1))
		if now - (handle.LastPlayAttemptAt or now) < retryDelay then return end
	else
		if loadingPresentationActive() then
			state.LocalIgnitionReadyAt = nil
			return
		end
		local graphStable = state.Graph and state.Graph.Route == "Internal" and state.Route == "Internal"
		local timeout = math.max(0.25, Catalog.GlobalNumber("IgnitionReadinessTimeoutSeconds", 8))
		if not graphStable and now - (state.LocalIgnitionRequestedAt or now) < timeout then return end
		if not state.LocalIgnitionReadyAt then
			state.LocalIgnitionReadyAt = now
			return
		end
		local delaySeconds = math.max(0, Catalog.GlobalNumber("IgnitionAfterReadyDelaySeconds", 0.15))
		if now - state.LocalIgnitionReadyAt < delaySeconds then return end
		local warmTimeout = math.max(0, Catalog.GlobalNumber("IgnitionAssetWarmTimeoutSeconds", 2))
		if not localIgnitionAssetReady(handle) and now - handle.PreparedAt < warmTimeout then return end
	end
	handle.PlayAttempts += 1
	handle.LastPlayAttemptAt = now
	handle.Played = true
	local ok, problem = pcall(function() handle.Player:Play() end)
	if not ok and global:GetAttribute("DebugReliableIgnition") == true then warn("[NTR Audio] ignition Play failed: " .. tostring(problem)) end
	if not handle.LifetimeScheduled then
		handle.LifetimeScheduled = true
		task.delay(math.max(2, Catalog.GlobalNumber("OneShotMaxLifetimeSeconds", 12)), function()
			if state.LocalIgnitionCue == handle then cleanupLocalIgnition(state) end
		end)
	end
	task.defer(function() confirmLocalIgnition(state, handle) end)
	if global:GetAttribute("DebugReliableIgnition") == true then
		print(("[NTR Audio] reliable ignition play requested attempt %d for %s"):format(handle.PlayAttempts, state.Vehicle:GetFullName()))
	end
end

local function holdLocalEngineLoopsForIgnition(state)
	if not state.LocalDriver or global:GetAttribute("ReliableIgnitionEnabled") == false or state.LocalIgnitionAbandoned then return false end
	if not state.LocalIgnitionPlayed then return true end
	local lead = math.max(0, Catalog.GlobalNumber("IgnitionToIdleLeadSeconds", 0.15))
	return state.LocalIgnitionConfirmedAt ~= nil and os.clock() - state.LocalIgnitionConfirmedAt < lead
end
]=]

local function projectVehicleIgnition(source)
	if has(source, VEHICLE_IGNITION_REVISION) then return source end
	assert(has(source, "NTR_AUDIO_VEHICLE_CLIENT_V3_PARKED_EXTERNAL"), "Unknown VehicleAudioController baseline")
	if has(source, VEHICLE_IGNITION_V1_3_REVISION) then
		local blockStart = assert(string.find(source, "-- " .. VEHICLE_IGNITION_V1_3_REVISION, 1, true), "Installed V1.3 ignition block start missing")
		local semanticStart = assert(string.find(source, "local function semanticState(vehicle, localDriver)", blockStart, true), "Installed V1.3 ignition block end missing")
		assert(not string.find(source, "-- " .. VEHICLE_IGNITION_V1_3_REVISION, blockStart + 1, true), "Installed V1.3 ignition marker is not unique")
		source = string.sub(source, 1, blockStart - 1) .. RELIABLE_IGNITION_SOURCE .. "\n" .. string.sub(source, semanticStart)
	else
		source = replaceOnce(source,
			"local function semanticState(vehicle, localDriver)",
			RELIABLE_IGNITION_SOURCE .. "\nlocal function semanticState(vehicle, localDriver)",
			"reliable local ignition coordinator")
		source = replaceOnce(source, [=[
	if previous then
		if previous.Ignition ~= semantic.Ignition then
			if semantic.Ignition == "Running" then playOneShot(state, "Ignition") elseif semantic.Ignition == "Off" then playOneShot(state, "Shutdown") end
		end
]=], [=[
	if previous then
		if previous.Ignition ~= semantic.Ignition and not state.LocalDriver then
			if semantic.Ignition == "Running" then playOneShot(state, "Ignition") elseif semantic.Ignition == "Off" then playOneShot(state, "Shutdown") end
		end
]=], "local ignition legacy transition suppression")
	source = replaceOnce(source, [=[
	elseif semantic.Ignition == "Running" then
		playOneShot(state, "Ignition")
	end
	state.LastSemantic = semantic
]=], [=[
	elseif semantic.Ignition == "Running" and tonumber(state.Vehicle:GetAttribute("OwnerUserId")) ~= localPlayer.UserId then
		playOneShot(state, "Ignition")
	end
	updateLocalIgnition(state)
	state.LastSemantic = semantic
]=], "reliable ignition update")
		source = replaceOnce(source,
			"local function cleanupVehicle(vehicle)\n\tlocal state = tracked[vehicle]\n\tif not state then return end\n\tdestroyGraph(state)",
			"local function cleanupVehicle(vehicle)\n\tlocal state = tracked[vehicle]\n\tif not state then return end\n\tcleanupLocalIgnition(state)\n\tdestroyGraph(state)",
			"reliable ignition vehicle cleanup")
		source = replaceOnce(source,
			"\t\tlocal localDriver = isLocalDriver(vehicle)\n\t\tstate.LocalDriver = localDriver",
			"\t\tlocal localDriver = isLocalDriver(vehicle)\n\t\tlocal wasLocalDriver = state.LocalDriver\n\t\tstate.LocalDriver = localDriver\n\t\tif wasLocalDriver and not localDriver and Catalog.GlobalBool(\"ReplayIgnitionOnRunningVehicleReentry\", false) then\n\t\t\tcleanupLocalIgnition(state)\n\t\t\tstate.LocalIgnitionPlayed = false\n\t\tend",
			"reliable ignition re-entry policy")
	end
	source = replaceOnce(source,
		'\tsetTarget(graph, "Idle", idleTarget)',
		'\tif holdLocalEngineLoopsForIgnition(state) then\n\t\tidleTarget, engineLowTarget, engineHighTarget, coastTarget = 0, 0, 0, 0\n\tend\n\tsetTarget(graph, "Idle", idleTarget)',
		"ignition-to-idle sequencing")
	return source
end

local function projectPreview(source)
	if has(source, PREVIEW_REVISION) then return source end
	assert(has(source, "NTR_GARAGE_PREVIEW_VEHICLE_CANONICAL_V3"), "Unknown PreviewVehicleController baseline")
	source = replaceOnce(source,
		"-- NTR_GARAGE_PREVIEW_VEHICLE_CANONICAL_V3",
		"-- NTR_GARAGE_PREVIEW_VEHICLE_CANONICAL_V3\n-- " .. PREVIEW_REVISION,
		"preview revision")
	source = replaceOnce(source,
		'local currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]; VehicleCosmetics.ApplyPresentation(vehicle,currentVehicle)',
		'local currentVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]; VehicleCosmetics.ApplyPresentation(vehicle,currentVehicle)\n\tlocal previewAudioProfileId=currentVehicle and (currentVehicle.ResolvedAudioProfileId or currentVehicle.AudioProfileId) or template:GetAttribute("StandardAudioProfileId") or "GENERIC_STANDARD_AUDIO"; root:SetAttribute("PreviewAudioProfileId",tostring(previewAudioProfileId))',
		"preview audio-profile seam")
	return source
end

local function projectOnboarding(source)
	if has(source, ONBOARDING_REFINEMENT_REVISION) then return source end
	if has(source, ONBOARDING_REVISION) then
		source = replaceOnce(source,
			"-- " .. ONBOARDING_REVISION,
			"-- " .. ONBOARDING_REVISION .. "\n-- " .. ONBOARDING_REFINEMENT_REVISION,
			"onboarding refinement revision")
		source = replaceOnce(source,
			'local nextButton=Racing.Button(bubble,{Name="Next",Text="NEXT",Color=GOLD,TextColor=DEEP,StrokeColor=GOLD,FocusColor=GOLD,FocusFill=GOLD,Radius=6,ZIndex=24}); nextButton.AnchorPoint=Vector2.zero',
			'local nextButton=Racing.Button(bubble,{Name="Next",Text="NEXT",Color=GOLD,TextColor=DEEP,StrokeColor=GOLD,FocusColor=GOLD,FocusFill=GOLD,Radius=6,ZIndex=24}); nextButton.AnchorPoint=Vector2.zero; nextButton:SetAttribute("UIAudioHoverCue","")',
			"onboarding Next hover suppression")
		source = replaceOnce(source,
			'local shade={}; for i=1,4 do local f=Instance.new("TextButton"); f.Name="Shade"..i; f.Text=""; f.AutoButtonColor=false; f.BackgroundColor3=Color3.new(0,0,0); f.BackgroundTransparency=setting("DimTransparency",.35); f.BorderSizePixel=0; f.Visible=false; f.Active=true; f.ZIndex=20; f.Parent=overlay; shade[i]=f end',
			'local shade={}; for i=1,4 do local f=Instance.new("TextButton"); f.Name="Shade"..i; f.Text=""; f.AutoButtonColor=false; f.BackgroundColor3=Color3.new(0,0,0); f.BackgroundTransparency=setting("DimTransparency",.35); f.BorderSizePixel=0; f.Visible=false; f.Active=true; f.ZIndex=20; f:SetAttribute("UIAudioHoverCue",""); f.Parent=overlay; shade[i]=f end',
			"onboarding shade hover suppression")
		source = replaceOnce(source,
			'local catch=Instance.new("TextButton"); catch.Name="Advance"; catch.Text=""; catch.AutoButtonColor=false; catch.BackgroundTransparency=1; catch.Size=UDim2.fromScale(1,1); catch.Visible=false; catch.Active=true; catch.ZIndex=21; catch.Parent=overlay; pcall(function() catch.Modal=true end)',
			'local catch=Instance.new("TextButton"); catch.Name="Advance"; catch.Text=""; catch.AutoButtonColor=false; catch.BackgroundTransparency=1; catch.Size=UDim2.fromScale(1,1); catch.Visible=false; catch.Active=true; catch.ZIndex=21; catch:SetAttribute("UIAudioHoverCue",""); catch.Parent=overlay; pcall(function() catch.Modal=true end)',
			"onboarding advance hover suppression")
		return source
	end
	assert(has(source, "NTR_PLAYER_ONBOARDING_V1_13_STATE_IMPORT_RACE_CONTROLS_TWO_LINE_OBJECTIVES"), "Unknown OnboardingClient baseline")
	source = replaceOnce(source,
		"-- NTR_PLAYER_ONBOARDING_V1_13_STATE_IMPORT_RACE_CONTROLS_TWO_LINE_OBJECTIVES",
		"-- NTR_PLAYER_ONBOARDING_V1_13_STATE_IMPORT_RACE_CONTROLS_TWO_LINE_OBJECTIVES\n-- " .. ONBOARDING_REVISION .. "\n-- " .. ONBOARDING_REFINEMENT_REVISION,
		"onboarding revision")
	source = replaceOnce(source,
		'local Racing=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))\nlocal GuideTrail=require(script.Parent:WaitForChild("OnboardingGuideTrailRenderer"))',
		'local Racing=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))\nlocal AudioBridge=require(kit.Shared.Modules.Client.Audio:WaitForChild("PresentationAudioBridge"))\nlocal GuideTrail=require(script.Parent:WaitForChild("OnboardingGuideTrailRenderer"))',
		"onboarding audio bridge")
	source = replaceOnce(source,
		'\tobjectiveCompletionSnapshot={objectiveComplete(1),objectiveComplete(2),objectiveComplete(3)}\n\tif unlockDelay>0 then task.delay(unlockDelay*.45,function() layoutObjectives(true) end) else layoutObjectives(true) end',
		'\tlocal nextCompletion={objectiveComplete(1),objectiveComplete(2),objectiveComplete(3)}\n\tif objectiveCompletionSnapshot then for index=1,3 do if objectiveCompletionSnapshot[index]~=true and nextCompletion[index]==true then AudioBridge.Emit("Objective.Complete",{Key="Objective:"..tostring(index),ObjectiveIndex=index}) end end end\n\tobjectiveCompletionSnapshot=nextCompletion\n\tif unlockDelay>0 then task.delay(unlockDelay*.45,function() layoutObjectives(true) end) else layoutObjectives(true) end',
		"objective completion transition")
	source = replaceOnce(source,
		'local nextButton=Racing.Button(bubble,{Name="Next",Text="NEXT",Color=GOLD,TextColor=DEEP,StrokeColor=GOLD,FocusColor=GOLD,FocusFill=GOLD,Radius=6,ZIndex=24}); nextButton.AnchorPoint=Vector2.zero',
		'local nextButton=Racing.Button(bubble,{Name="Next",Text="NEXT",Color=GOLD,TextColor=DEEP,StrokeColor=GOLD,FocusColor=GOLD,FocusFill=GOLD,Radius=6,ZIndex=24}); nextButton.AnchorPoint=Vector2.zero; nextButton:SetAttribute("UIAudioHoverCue","")',
		"onboarding Next hover suppression")
	source = replaceOnce(source,
		'local shade={}; for i=1,4 do local f=Instance.new("TextButton"); f.Name="Shade"..i; f.Text=""; f.AutoButtonColor=false; f.BackgroundColor3=Color3.new(0,0,0); f.BackgroundTransparency=setting("DimTransparency",.35); f.BorderSizePixel=0; f.Visible=false; f.Active=true; f.ZIndex=20; f.Parent=overlay; shade[i]=f end',
		'local shade={}; for i=1,4 do local f=Instance.new("TextButton"); f.Name="Shade"..i; f.Text=""; f.AutoButtonColor=false; f.BackgroundColor3=Color3.new(0,0,0); f.BackgroundTransparency=setting("DimTransparency",.35); f.BorderSizePixel=0; f.Visible=false; f.Active=true; f.ZIndex=20; f:SetAttribute("UIAudioHoverCue",""); f.Parent=overlay; shade[i]=f end',
		"onboarding shade hover suppression")
	source = replaceOnce(source,
		'local catch=Instance.new("TextButton"); catch.Name="Advance"; catch.Text=""; catch.AutoButtonColor=false; catch.BackgroundTransparency=1; catch.Size=UDim2.fromScale(1,1); catch.Visible=false; catch.Active=true; catch.ZIndex=21; catch.Parent=overlay; pcall(function() catch.Modal=true end)',
		'local catch=Instance.new("TextButton"); catch.Name="Advance"; catch.Text=""; catch.AutoButtonColor=false; catch.BackgroundTransparency=1; catch.Size=UDim2.fromScale(1,1); catch.Visible=false; catch.Active=true; catch.ZIndex=21; catch:SetAttribute("UIAudioHoverCue",""); catch.Parent=overlay; pcall(function() catch.Modal=true end)',
		"onboarding advance hover suppression")
	return source
end

local projected = {
	{ Object = moduleShop, Source = projectModuleShop(moduleShop.Source), Marker = MODULE_SHOP_VEHICLE_PURCHASE_REVISION },
	{ Object = ownedGarage, Source = projectOwnedGarage(ownedGarage.Source), Marker = OWNED_GARAGE_SEMANTIC_REVISION },
	{ Object = vehicleAudioController, Source = projectVehicleIgnition(vehicleAudioController.Source), Marker = VEHICLE_IGNITION_REVISION },
	{ Object = previewVehicle, Source = projectPreview(previewVehicle.Source), Marker = PREVIEW_REVISION },
	{ Object = onboarding, Source = projectOnboarding(onboarding.Source), Marker = ONBOARDING_REFINEMENT_REVISION },
}

for _, item in ipairs(projected) do
	assert(has(item.Source, item.Marker), item.Marker .. " projection failed")
	compile(item.Object:GetFullName(), item.Source)
end
compile("PresentationAudioBridge", BRIDGE_SOURCE)
compile("PresentationAudioCatalog", CATALOG_SOURCE)
compile("PresentationAudioController", CONTROLLER_SOURCE)
compile("PresentationAudioRuntimeController_Active", STARTER_SOURCE)

local GLOBAL_DEFAULTS = {
	PresentationAudioEnabled = true,
	UIAudioEnabled = true,
	PreviewAudioEnabled = true,
	ObjectiveAudioEnabled = true,
	RaceAudioEnabled = true,
	DebugPresentationAudio = false,
	MaximumOneShotVoices = 8,
	PreloadOneShotsEnabled = true,
	PreloadOneShotAssetLimit = 24,
	PreviewPollHz = 5,
	MouseHoverEnabled = true,
	ControllerFocusHoverEnabled = true,
	UIMasterGain = 1,
	PreviewMasterGain = 0.7,
	ObjectiveMasterGain = 1,
	RaceMasterGain = 1,
}

local GLOBAL_HELP = {
	PresentationAudioEnabled = "Master switch for UI, preview, objective and racing presentation audio without changing vehicle/context configuration.",
	UIAudioEnabled = "Enables local hover, focus, click, purchase, rejection, equip, upgrade and save cues.",
	PreviewAudioEnabled = "Enables persistent dealership/customisation idle and thrust-colour boost preview loops.",
	ObjectiveAudioEnabled = "Enables local objective-completion cues emitted only on a new incomplete-to-complete transition.",
	RaceAudioEnabled = "Enables local countdown, checkpoint, lap and race-result cues driven by existing RaceEvent messages.",
	DebugPresentationAudio = "Prints concise cue/start diagnostics when true; leave false in production.",
	MaximumOneShotVoices = "Maximum pooled local one-shot Sounds shared by UI, objective and racing cues; extra cues are dropped rather than growing unbounded.",
	PreloadOneShotsEnabled = "Warms configured UI, objective and racing one-shot assets asynchronously at controller start so first playback is not delayed; does not delay input or race events.",
	PreloadOneShotAssetLimit = "Maximum number of unique configured presentation one-shot assets warmed per client. Preview loops and vehicle Ignition are excluded.",
	PreviewPollHz = "How often the controller checks the two known preview roots and their stable presentation attributes; no whole-Workspace scan is performed.",
	MouseHoverEnabled = "Allows MouseEnter hover cues on eligible visible buttons.",
	ControllerFocusHoverEnabled = "Uses the hover cue when controller selection moves onto an eligible button.",
	UIMasterGain = "Master multiplier applied after each UI cue's Gain and before the NTR_UI SoundGroup volume.",
	PreviewMasterGain = "Master multiplier for dealership/customisation idle and boost-preview loops before NTR_Vehicle volume.",
	ObjectiveMasterGain = "Master multiplier for objective cues before NTR_GameplaySFX volume.",
	RaceMasterGain = "Master multiplier for countdown/checkpoint/result cues before NTR_GameplaySFX volume.",
}

local VEHICLE_GLOBAL_DEFAULTS = {
	ReliableIgnitionEnabled = true,
	IgnitionAfterReadyDelaySeconds = 0.15,
	IgnitionReadinessTimeoutSeconds = 8,
	IgnitionAssetWarmTimeoutSeconds = 2,
	IgnitionPlaybackConfirmSeconds = 0.12,
	IgnitionMaxPlayAttempts = 3,
	IgnitionRetryDelaySeconds = 0.1,
	IgnitionToIdleLeadSeconds = 0.15,
	ReplayIgnitionOnRunningVehicleReentry = false,
	DebugReliableIgnition = false,
}

local VEHICLE_GLOBAL_HELP = {
	ReliableIgnitionEnabled = "Uses the graph-rebuild-safe local startup coordinator. Remote players keep the existing 3D ignition presentation.",
	IgnitionAfterReadyDelaySeconds = "Delay after loading is inactive and the local internal vehicle-audio route is stable before ignition plays.",
	IgnitionReadinessTimeoutSeconds = "Maximum time to wait for the final internal graph after seating; after this, the persistent local cue may safely play without that graph.",
	IgnitionAssetWarmTimeoutSeconds = "Maximum extra time to let the ignition AudioPlayer prepare before playback; avoids an indefinite wait on a slow or unavailable asset.",
	IgnitionPlaybackConfirmSeconds = "Time allowed after each Play request for AudioPlayer.IsPlaying to confirm audible playback before retrying.",
	IgnitionMaxPlayAttempts = "Maximum bounded Play requests for one new-vehicle ignition session before it fails safely and releases the engine loops.",
	IgnitionRetryDelaySeconds = "Minimum delay between bounded ignition Play attempts when playback has not confirmed.",
	IgnitionToIdleLeadSeconds = "How long confirmed Ignition leads before local Idle/engine loops fade in, preventing the loop from masking the startup transient.",
	ReplayIgnitionOnRunningVehicleReentry = "When false, leaving and re-entering the same still-running vehicle does not pretend the engine restarted. New vehicle instances still play once.",
	DebugReliableIgnition = "Prints concise local ignition prepared/played diagnostics. Leave false in production.",
}

local CUES = {
	{ "UI", "Hover", "Subtle mouse-hover or controller-focus cue.", { Enabled=true, AssetId="", Gain=0.35, Pitch=1, CooldownSeconds=0.07, MaximumVoices=1, Bus="UI" } },
	{ "UI", "Click", "Default Activated cue for eligible mouse, touch and controller buttons.", { Enabled=true, AssetId="", Gain=0.5, Pitch=1, CooldownSeconds=0.04, MaximumVoices=3, Bus="UI" } },
	{ "UI", "Back", "Optional lower-key navigation cue; set UIAudioClickCue=UI.Back on buttons that should use it.", { Enabled=true, AssetId="", Gain=0.45, Pitch=0.95, CooldownSeconds=0.05, MaximumVoices=2, Bus="UI" } },
	{ "UI", "PurchaseSuccess", "Plays only after an existing authoritative purchase result reports Success=true.", { Enabled=true, AssetId="", Gain=0.8, Pitch=1, CooldownSeconds=0.12, MaximumVoices=2, Bus="UI" } },
	{ "UI", "VehiclePurchaseSuccess", "Unique vehicle-acquisition cue after a dealership purchase or successful owned-garage display assignment.", { Enabled=true, AssetId="", Gain=0.9, Pitch=1, CooldownSeconds=0.2, MaximumVoices=1, Bus="UI" } },
	{ "UI", "DecorationPurchaseSuccess", "Unique cue after the owned-garage server confirms a decoration purchase; the same transaction also places it, so no equip cue is layered.", { Enabled=true, AssetId="", Gain=0.82, Pitch=1, CooldownSeconds=0.12, MaximumVoices=2, Bus="UI" } },
	{ "UI", "DecorationEquipSuccess", "Unique cue after the owned-garage server confirms placing an already-owned decoration.", { Enabled=true, AssetId="", Gain=0.72, Pitch=1, CooldownSeconds=0.1, MaximumVoices=2, Bus="UI" } },
	{ "UI", "StructurePurchaseSuccess", "Unique cue after the owned-garage server confirms a structure purchase; the same transaction also equips it, so no equip cue is layered.", { Enabled=true, AssetId="", Gain=0.85, Pitch=1, CooldownSeconds=0.12, MaximumVoices=2, Bus="UI" } },
	{ "UI", "StructureEquipSuccess", "Unique cue after the owned-garage server confirms equipping an already-owned structure style.", { Enabled=true, AssetId="", Gain=0.75, Pitch=1, CooldownSeconds=0.1, MaximumVoices=2, Bus="UI" } },
	{ "UI", "PurchaseRejected", "Plays when an attempted authoritative purchase is rejected or fails.", { Enabled=true, AssetId="", Gain=0.7, Pitch=0.95, CooldownSeconds=0.12, MaximumVoices=2, Bus="UI" } },
	{ "UI", "ActionRejected", "Generic rejection cue for failed equip/upgrade or future semantic actions.", { Enabled=true, AssetId="", Gain=0.65, Pitch=0.95, CooldownSeconds=0.12, MaximumVoices=2, Bus="UI" } },
	{ "UI", "ModuleEquipSuccess", "Plays only after the garage server confirms EquipModuleInstance.", { Enabled=true, AssetId="", Gain=0.75, Pitch=1, CooldownSeconds=0.1, MaximumVoices=2, Bus="UI" } },
	{ "UI", "EquipSuccess", "Generic confirmed equip/place cue used by owned-garage assets and future semantic integrations.", { Enabled=true, AssetId="", Gain=0.7, Pitch=1, CooldownSeconds=0.1, MaximumVoices=2, Bus="UI" } },
	{ "UI", "UpgradeSuccess", "Plays only after the authoritative module upgrade result succeeds.", { Enabled=true, AssetId="", Gain=0.75, Pitch=1, CooldownSeconds=0.1, MaximumVoices=2, Bus="UI" } },
	{ "UI", "SaveSuccess", "Optional confirmed save/apply cue for future semantic save boundaries.", { Enabled=true, AssetId="", Gain=0.6, Pitch=1, CooldownSeconds=0.1, MaximumVoices=2, Bus="UI" } },
	{ "Preview", "IdleLoop", "Persistent non-positional preview idle loop; reuses the selected profile Idle layer when AssetId is blank.", { Enabled=true, AssetId="", Gain=0.72, Pitch=1, CooldownSeconds=0, MaximumVoices=1, Bus="Vehicle", ProfileLayer="Idle", FadeInSeconds=0.25, FadeOutSeconds=0.3, CrossfadeSeconds=0.35, MissingPreviewGraceSeconds=0.6 } },
	{ "Preview", "BoostLoop", "Persistent thrust-colour preview loop; reuses BoostLoop and does not restart on slider/module rebuilds.", { Enabled=true, AssetId="", Gain=0.65, Pitch=1, CooldownSeconds=0, MaximumVoices=1, Bus="Vehicle", ProfileLayer="BoostLoop", FadeInSeconds=0.18, FadeOutSeconds=0.24, CrossfadeSeconds=0.25, MissingPreviewGraceSeconds=0.6 } },
	{ "Objective", "Complete", "Plays once when an onboarding objective newly changes from incomplete to complete, never during initial saved-state load.", { Enabled=true, AssetId="", Gain=0.85, Pitch=1, CooldownSeconds=0.2, MaximumVoices=2, Bus="GameplaySFX" } },
	{ "Racing", "CountdownTick", "One synchronized tick for each changed countdown number.", { Enabled=true, AssetId="", Gain=0.75, Pitch=1, CooldownSeconds=0.05, MaximumVoices=2, Bus="GameplaySFX" } },
	{ "Racing", "CountdownGo", "Distinct GO cue emitted once from the server-confirmed race/time-trial start event.", { Enabled=true, AssetId="", Gain=1, Pitch=1, CooldownSeconds=0.2, MaximumVoices=2, Bus="GameplaySFX" } },
	{ "Racing", "Checkpoint", "Plays once per server-confirmed run/lap/checkpoint identity.", { Enabled=true, AssetId="", Gain=0.75, Pitch=1, CooldownSeconds=0.08, MaximumVoices=3, Bus="GameplaySFX" } },
	{ "Racing", "LapComplete", "More substantial cue for a server-confirmed completed lap.", { Enabled=true, AssetId="", Gain=0.9, Pitch=1, CooldownSeconds=0.2, MaximumVoices=2, Bus="GameplaySFX" } },
	{ "Racing", "RaceFinish", "Local finish cue for RaceFinished or TimeTrialFinished.", { Enabled=true, AssetId="", Gain=1, Pitch=1, CooldownSeconds=0.4, MaximumVoices=2, Bus="GameplaySFX" } },
	{ "Racing", "RaceDNF", "Restrained failure cue for a multiplayer RaceDNF result.", { Enabled=true, AssetId="", Gain=0.8, Pitch=0.95, CooldownSeconds=0.4, MaximumVoices=1, Bus="GameplaySFX" } },
	{ "Racing", "WrongWayWarning", "Future-ready wrong-way warning cue; no producer is installed until a stable semantic warning event is approved.", { Enabled=true, AssetId="", Gain=0.65, Pitch=1, CooldownSeconds=1.5, MaximumVoices=1, Bus="GameplaySFX" } },
	{ "Racing", "MatchFound", "Optional cue when a multiplayer race reaches the existing server-confirmed staged state.", { Enabled=true, AssetId="", Gain=0.9, Pitch=1, CooldownSeconds=0.5, MaximumVoices=1, Bus="GameplaySFX" } },
}

local ATTRIBUTE_HELP = {
	Enabled = "Enables this cue without deleting its asset or tuning.",
	AssetId = "Optional numeric or rbxassetid:// sound ID. Blank loop AssetId falls back to its configured vehicle ProfileLayer; blank one-shots remain silent.",
	Gain = "Linear cue gain before its section master gain and existing SoundGroup volume.",
	Pitch = "Playback-speed/pitch multiplier; 1 is the uploaded sound's original speed.",
	CooldownSeconds = "Minimum time before this cue may play again; semantic event keys also prevent duplicate race/objective results.",
	MaximumVoices = "Maximum simultaneous voices for this cue inside the shared bounded one-shot pool.",
	Bus = "Existing mix category: UI routes to NTR_UI, Vehicle to NTR_Vehicle, and GameplaySFX to NTR_GameplaySFX.",
	ProfileLayer = "Vehicle profile layer used when AssetId is blank, such as Idle or BoostLoop.",
	FadeInSeconds = "Time for this persistent preview loop to reach its configured gain.",
	FadeOutSeconds = "Time for this persistent preview loop to fade when its preview state ends.",
	CrossfadeSeconds = "Crossfade time only when a future preview switches to a genuinely different audio profile/asset.",
	MissingPreviewGraceSeconds = "Keeps the persistent loop alive through a brief preview-model rebuild so module/car clone replacement does not cut it off.",
}

local sourceSnapshots, attributeSnapshots, valueSnapshots, created = {}, {}, {}, {}

local function snapshotAttribute(object, name)
	table.insert(attributeSnapshots, { Object=object, Name=name, Had=object:GetAttribute(name)~=nil, Value=object:GetAttribute(name) })
end

local function setDefault(object, name, value)
	if object:GetAttribute(name) == nil then
		snapshotAttribute(object, name)
		object:SetAttribute(name, value)
	end
end

local function ensure(parent, className, name)
	local object = parent:FindFirstChild(name)
	if object then
		assert(object:IsA(className), object:GetFullName() .. " must be " .. className)
		return object
	end
	object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	table.insert(created, object)
	return object
end

local function description(parent, name, text)
	local folder = ensure(parent, "Folder", "Descriptions")
	local value = folder:FindFirstChild(name)
	if value then
		assert(value:IsA("StringValue"), value:GetFullName() .. " must be StringValue")
		table.insert(valueSnapshots, { Object=value, Value=value.Value })
	else
		value = Instance.new("StringValue")
		value.Name = name
		value.Parent = folder
		table.insert(created, value)
	end
	value.Value = text
end

local function installConfig()
	local presentation = ensure(audioConfig, "Folder", "Presentation")
	local global = ensure(presentation, "Folder", "Global")
	snapshotAttribute(presentation, "InstallerRevision")
	presentation:SetAttribute("InstallerRevision", REVISION)
	for name, value in pairs(VEHICLE_GLOBAL_DEFAULTS) do setDefault(audioGlobal, name, value) end
	for name, text in pairs(VEHICLE_GLOBAL_HELP) do description(audioGlobal, name, text) end
	for name, value in pairs(GLOBAL_DEFAULTS) do setDefault(global, name, value) end
	for name, text in pairs(GLOBAL_HELP) do description(global, name, text) end
	for _, row in ipairs(CUES) do
		local section = ensure(presentation, "Folder", row[1])
		local cue = ensure(section, "Folder", row[2])
		description(cue, "Cue", row[3])
		for name, value in pairs(row[4]) do
			setDefault(cue, name, value)
			description(cue, name, ATTRIBUTE_HELP[name] or "Designer-tunable presentation-audio value.")
		end
	end
	return presentation
end

local function installSource(parent, className, name, source)
	local object = ensure(parent, className, name)
	if object.Source ~= source then
		table.insert(sourceSnapshots, { Object=object, Source=object.Source })
		object.Source = source
	end
	return object
end

local function audit()
	local presentation = child(audioConfig, "Presentation", "Folder")
	assert(presentation:GetAttribute("InstallerRevision") == REVISION, "Presentation-audio revision missing")
	for name in pairs(VEHICLE_GLOBAL_DEFAULTS) do
		assert(audioGlobal:GetAttribute(name) ~= nil, "Vehicle ignition config missing: " .. name)
		child(child(audioGlobal, "Descriptions", "Folder"), name, "StringValue")
	end
	local global = child(presentation, "Global", "Folder")
	for name in pairs(GLOBAL_DEFAULTS) do
		assert(global:GetAttribute(name) ~= nil, "Global presentation-audio config missing: " .. name)
		child(child(global, "Descriptions", "Folder"), name, "StringValue")
	end
	for _, row in ipairs(CUES) do
		local cue = child(child(presentation, row[1], "Folder"), row[2], "Folder")
		local docs = child(cue, "Descriptions", "Folder")
		child(docs, "Cue", "StringValue")
		for name in pairs(row[4]) do
			assert(cue:GetAttribute(name) ~= nil, row[1] .. "." .. row[2] .. " missing " .. name)
			child(docs, name, "StringValue")
		end
	end
	local bridge = child(audioModules, "PresentationAudioBridge", "ModuleScript")
	local catalog = child(audioModules, "PresentationAudioCatalog", "ModuleScript")
	local controller = child(audioModules, "PresentationAudioController", "ModuleScript")
	local starter = child(audioControllers, "PresentationAudioRuntimeController_Active", "LocalScript")
	assert(has(bridge.Source, BRIDGE_REVISION), "PresentationAudioBridge marker missing")
	assert(has(catalog.Source, CATALOG_REVISION), "PresentationAudioCatalog marker missing")
	assert(has(controller.Source, CONTROLLER_REVISION), "PresentationAudioController marker missing")
	assert(has(starter.Source, STARTER_REVISION), "PresentationAudio runtime marker missing")
	for _, item in ipairs(projected) do assert(has(item.Object.Source, item.Marker), item.Marker .. " missing") end
	assert(has(vehicleAudioController.Source, "Catalog.GetProfile(profileId)"), "Reliable ignition profile lookup missing")
	assert(not has(vehicleAudioController.Source, "Catalog.Get(profileId)"), "Broken V1.3 ignition profile lookup remains")
	assert(has(vehicleAudioController.Source, "holdLocalEngineLoopsForIgnition(state)"), "Ignition-to-idle sequencing missing")
	assert(has(controller.Source, "ContentProvider:PreloadAsync(sounds)"), "Presentation one-shot warmup missing")
	assert(has(controller.Source, "record.CueId == cueId and sound.SoundId == assetId"), "Cue-affine one-shot reuse missing")
	print(("[NTR Presentation Audio V1.3.2] AUDIT PASS | cues=%d | immediateOneShots=1 | confirmedIgnition=1 | previewLoops=2 | remotesAdded=0"):format(#CUES))
end

if MODE == "AUDIT" then audit(); return end
assert(not RunService:IsRunning(), "Run INSTALL/DISABLE in Edit mode, not during Play")
if MODE == "DISABLE" then
	local presentation = audioConfig:FindFirstChild("Presentation")
	local global = presentation and presentation:FindFirstChild("Global")
	assert(global and global:IsA("Folder"), "Presentation audio is not installed")
	global:SetAttribute("PresentationAudioEnabled", false)
	audioGlobal:SetAttribute("ReliableIgnitionEnabled", false)
	print("[NTR Presentation Audio V1.3.2] DISABLE PASS | presentation + reliable ignition disabled; sources/assets/config retained")
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL, AUDIT, or DISABLE")

local ok, problem = pcall(function()
	for _, item in ipairs(projected) do
		if item.Object.Source ~= item.Source then
			table.insert(sourceSnapshots, { Object=item.Object, Source=item.Object.Source })
			item.Object.Source = item.Source
		end
	end
	installSource(audioModules, "ModuleScript", "PresentationAudioBridge", BRIDGE_SOURCE)
	installSource(audioModules, "ModuleScript", "PresentationAudioCatalog", CATALOG_SOURCE)
	installSource(audioModules, "ModuleScript", "PresentationAudioController", CONTROLLER_SOURCE)
	installSource(audioControllers, "LocalScript", "PresentationAudioRuntimeController_Active", STARTER_SOURCE)
	installConfig()
	audit()
end)

if not ok then
	for index = #sourceSnapshots, 1, -1 do
		local snapshot = sourceSnapshots[index]
		pcall(function() snapshot.Object.Source = snapshot.Source end)
	end
	for index = #valueSnapshots, 1, -1 do
		local snapshot = valueSnapshots[index]
		pcall(function() snapshot.Object.Value = snapshot.Value end)
	end
	for index = #attributeSnapshots, 1, -1 do
		local snapshot = attributeSnapshots[index]
		pcall(function()
			if snapshot.Had then snapshot.Object:SetAttribute(snapshot.Name, snapshot.Value) else snapshot.Object:SetAttribute(snapshot.Name, nil) end
		end)
	end
	for index = #created, 1, -1 do
		local object = created[index]
		pcall(function() if object.Parent then object:Destroy() end end)
	end
	error("[NTR Presentation Audio V1.3.2] INSTALL ROLLBACK: " .. tostring(problem))
end

print("[NTR Presentation Audio V1.3.2] INSTALL PASS | immediate presentation one-shots + confirmed graph-safe local ignition installed")
