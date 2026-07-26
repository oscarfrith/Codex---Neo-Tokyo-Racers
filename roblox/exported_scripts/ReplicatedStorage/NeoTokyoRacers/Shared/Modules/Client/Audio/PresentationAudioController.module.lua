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
