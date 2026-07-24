-- Neo Tokyo Racers - Audio System Phase 2 Context Music + Ambience
-- Run this complete file in the Roblox Studio Command Bar in Edit mode.
--
-- This is an additive, isolated installer. It does not patch Phase 1 vehicle
-- audio, driving, bootstrap, garage UI, loading, VFX, persistence or economy.
-- Asset IDs remain blank and the context runtime remains disabled by default.
--
-- Modes: INSTALL, AUDIT, DISABLE

local MODE = "INSTALL"

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run Audio Phase 2 in Studio Edit mode.")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "NTR Audio System Phase 2 V1"
local REVISION = "NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_MUSIC_AMBIENCE_V1"
local CATALOG_REVISION = "NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CATALOG_V1"
local CONTROLLER_REVISION = "NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CONTROLLER_V1"
local RUNTIME_REVISION = "NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_RUNTIME_V1"

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

local function hasMarker(source, marker)
	return type(source) == "string" and string.find(source, "-- " .. marker, 1, true) ~= nil
end

local function compile(label, source)
	local fn, problem = loadstring(source, "=" .. label)
	assert(fn, label .. " compile failed: " .. tostring(problem))
end

local function ensureClass(parent, name, className, created)
	local object = parent:FindFirstChild(name)
	if object then
		assert(object.ClassName == className, object:GetFullName() .. " must be a " .. className)
		return object
	end
	object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	table.insert(created, object)
	return object
end

local function snapshotAttribute(snapshots, object, name)
	table.insert(snapshots, {
		Object = object,
		Name = name,
		HadValue = object:GetAttribute(name) ~= nil,
		Value = object:GetAttribute(name),
	})
end

local function setDefaultAttribute(snapshots, object, name, value)
	if object:GetAttribute(name) == nil then
		snapshotAttribute(snapshots, object, name)
		object:SetAttribute(name, value)
	end
end

local CONTEXT_CATALOG_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CATALOG_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = {}
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local contextConfig = kit:WaitForChild("Config"):WaitForChild("Audio"):WaitForChild("Context")
local contexts = contextConfig:WaitForChild("Contexts")
local global = contextConfig:WaitForChild("Global")

local function assetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

local function trackRows(folder)
	local rows = {}
	for _, object in ipairs(folder and folder:GetChildren() or {}) do
		if object:IsA("StringValue") then
			local id = assetId(object.Value)
			if id ~= "" then
				table.insert(rows, {
					Id = id,
					Name = object.Name,
					Order = tonumber(object:GetAttribute("Order")) or 0,
					Gain = math.clamp(tonumber(object:GetAttribute("Gain")) or 1, 0, 3),
					Loop = object:GetAttribute("Loop") == true,
				})
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.Order ~= b.Order then return a.Order < b.Order end
		return a.Name < b.Name
	end)
	local limit = math.max(1, math.floor(tonumber(global:GetAttribute("MaxTracksPerChannel")) or 64))
	while #rows > limit do table.remove(rows) end
	return rows
end

function Catalog.GlobalBool(name, fallback)
	local value = global:GetAttribute(name)
	return typeof(value) == "boolean" and value or fallback
end

function Catalog.GlobalNumber(name, fallback)
	local value = tonumber(global:GetAttribute(name))
	return value ~= nil and value or fallback
end

function Catalog.GlobalString(name, fallback)
	local value = global:GetAttribute(name)
	return typeof(value) == "string" and value or fallback
end

function Catalog.HasContext(contextId)
	local folder = contexts:FindFirstChild(tostring(contextId or ""))
	return folder ~= nil and folder:IsA("Folder")
end

function Catalog.Get(contextId)
	local folder = contexts:FindFirstChild(tostring(contextId or ""))
	if not (folder and folder:IsA("Folder")) then return nil end
	return {
		Id = folder.Name,
		DisplayName = tostring(folder:GetAttribute("DisplayName") or folder.Name),
		Priority = tonumber(folder:GetAttribute("Priority")) or 0,
		FadeSeconds = math.clamp(tonumber(folder:GetAttribute("FadeSeconds")) or 1.5, 0, 10),
		MusicGain = math.clamp(tonumber(folder:GetAttribute("MusicGain")) or 0.55, 0, 3),
		AmbienceGain = math.clamp(tonumber(folder:GetAttribute("AmbienceGain")) or 0.45, 0, 3),
		PlaylistMode = tostring(folder:GetAttribute("PlaylistMode") or "Sequential"),
		Music = trackRows(folder:FindFirstChild("MusicTracks")),
		Ambience = trackRows(folder:FindFirstChild("AmbienceTracks")),
	}
end

function Catalog.CountPopulatedTracks()
	local count = 0
	for _, context in ipairs(contexts:GetChildren()) do
		if context:IsA("Folder") then
			for _, childName in ipairs({ "MusicTracks", "AmbienceTracks" }) do
				local tracks = context:FindFirstChild(childName)
				for _, track in ipairs(tracks and tracks:GetChildren() or {}) do
					if track:IsA("StringValue") and tostring(track.Value or "") ~= "" then count += 1 end
				end
			end
		end
	end
	return count
end

return Catalog
]=]

local CONTEXT_CONTROLLER_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CONTROLLER_V1
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Controller = {}
local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audioModules = kit.Shared.Modules.Client:WaitForChild("Audio")
local Catalog = require(audioModules:WaitForChild("ContextAudioCatalog"))
local contextConfig = kit.Config.Audio:WaitForChild("Context")
local global = contextConfig:WaitForChild("Global")

local TAG = "NTR_AudioContextZone"
local channels = { Music = {}, Ambience = {} }
local zones = setmetatable({}, { __mode = "k" })
local connections = {}
local heartbeatConnection = nil
local runtimeRoot = nil
local currentContextId = nil
local currentContext = nil
local elapsed = 0
local transitionGeneration = 0
local started = false

local function debugLog(message)
	if global:GetAttribute("DebugContextAudio") == true then
		print("[NTR Audio Phase 2] " .. tostring(message))
	end
end

local function enabled()
	local phase1Global = kit.Config.Audio:FindFirstChild("Global")
	return phase1Global and phase1Global:GetAttribute("AudioSystemEnabled") == true
		and global:GetAttribute("ContextAudioEnabled") == true
end

local function humanoidAndRoot()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

local function driving()
	local humanoid = humanoidAndRoot()
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then return false end
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
	return vehicles ~= nil and seat:IsDescendantOf(vehicles)
end

local function pointInside(object, position)
	if object:IsA("BasePart") then
		local localPoint = object.CFrame:PointToObjectSpace(position)
		local half = object.Size * 0.5
		return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
	end
	if object:IsA("Model") then
		local ok, cf, size = pcall(object.GetBoundingBox, object)
		if not ok then return false end
		local localPoint = cf:PointToObjectSpace(position)
		local half = size * 0.5
		return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
	end
	return false
end

local function registerZone(object)
	if zones[object] then return end
	if not (object:IsA("BasePart") or object:IsA("Model")) then
		if global:GetAttribute("DebugContextAudio") == true then warn("[NTR Audio Phase 2] Ignored non-spatial tagged zone " .. object:GetFullName()) end
		return
	end
	local cap = math.max(1, math.floor(Catalog.GlobalNumber("MaxRegisteredZones", 32)))
	local count = 0
	for _ in pairs(zones) do count += 1 end
	if count >= cap then
		if global:GetAttribute("DebugContextAudio") == true then warn("[NTR Audio Phase 2] Zone cap reached; ignored " .. object:GetFullName()) end
		return
	end
	zones[object] = true
end

local function unregisterZone(object)
	zones[object] = nil
end

local function zoneContext(position)
	local winnerId = nil
	local winnerPriority = -math.huge
	local winnerName = ""
	for object in pairs(zones) do
		if not object.Parent then
			zones[object] = nil
		else
			local contextId = tostring(object:GetAttribute("AudioContextId") or "")
			if contextId ~= "" and Catalog.HasContext(contextId) and pointInside(object, position) then
				local definition = Catalog.Get(contextId)
				local priority = tonumber(object:GetAttribute("AudioContextPriority")) or (definition and definition.Priority) or 0
				local stableName = object:GetFullName()
				if priority > winnerPriority or (priority == winnerPriority and stableName < winnerName) then
					winnerId = contextId
					winnerPriority = priority
					winnerName = stableName
				end
			end
		end
	end
	return winnerId
end

local function resolveContextId()
	if player:GetAttribute("NTR_OwnedGarageInside") == true and Catalog.HasContext("OWNED_GARAGE_INTERIOR") then
		return "OWNED_GARAGE_INTERIOR", "OwnedGarage"
	end
	if player:GetAttribute("NTR_GarageSessionActive") == true and Catalog.HasContext("DEALERSHIP_INTERIOR") then
		return "DEALERSHIP_INTERIOR", tostring(player:GetAttribute("NTR_GarageSessionMode") or "GarageSession")
	end
	local _, root = humanoidAndRoot()
	local zoned = root and zoneContext(root.Position)
	if zoned then return zoned, "TaggedZone" end
	if driving() and Catalog.HasContext("FREE_ROAM_DRIVING") then return "FREE_ROAM_DRIVING", "Driving" end
	return Catalog.GlobalString("DefaultContextId", "FREE_ROAM_ON_FOOT"), "Default"
end

local function newSound(channelName, context, row)
	local sound = Instance.new("Sound")
	sound.Name = channelName .. "_" .. context.Id .. "_" .. row.Name
	sound.SoundId = row.Id
	sound.Volume = 0
	sound.Looped = row.Loop == true
	sound.SoundGroup = SoundService:FindFirstChild(channelName == "Music" and "NTR_GameplayMusic" or "NTR_Ambience")
	sound.Parent = runtimeRoot
	return sound
end

local function chooseTrack(context, channelName, previousIndex)
	local rows = channelName == "Music" and context.Music or context.Ambience
	if #rows == 0 then return nil, 0 end
	local mode = string.lower(context.PlaylistMode)
	local index
	if mode == "random" and #rows > 1 then
		repeat index = math.random(1, #rows) until index ~= previousIndex
	else
		index = (previousIndex % #rows) + 1
	end
	return rows[index], index
end

local function fadeSound(sound, from, to, seconds, generation, destroyAtEnd)
	task.spawn(function()
		local duration = math.max(0, seconds)
		local startedAt = os.clock()
		repeat
			if generation ~= transitionGeneration or not sound.Parent then
				if destroyAtEnd and sound.Parent then sound:Destroy() end
				return
			end
			local alpha = duration == 0 and 1 or math.clamp((os.clock() - startedAt) / duration, 0, 1)
			sound.Volume = from + (to - from) * alpha
			if alpha >= 1 then break end
			RunService.Heartbeat:Wait()
		until false
		if destroyAtEnd and sound.Parent then sound:Destroy() end
	end)
end

local function startChannel(channelName, context, fadeSeconds)
	local channel = channels[channelName]
	local previous = channel.Sound
	local previousVolume = previous and previous.Volume or 0
	local row, index = chooseTrack(context, channelName, channel.Index or 0)
	channel.Index = index
	channel.ContextId = context.Id
	channel.Sound = nil
	if previous then fadeSound(previous, previousVolume, 0, fadeSeconds, transitionGeneration, true) end
	if not row then return end
	local sound = newSound(channelName, context, row)
	channel.Sound = sound
	local baseGain = channelName == "Music" and context.MusicGain or context.AmbienceGain
	local target = math.clamp(baseGain * row.Gain, 0, 3)
	sound.Ended:Connect(function()
		if channel.Sound ~= sound or transitionGeneration <= 0 or sound.Looped then return end
		local nextRow, nextIndex = chooseTrack(context, channelName, channel.Index or 0)
		if not nextRow then return end
		channel.Index = nextIndex
		local nextSound = newSound(channelName, context, nextRow)
		channel.Sound = nextSound
		nextSound.Volume = math.clamp(baseGain * nextRow.Gain, 0, 3)
		pcall(function() nextSound:Play() end)
		sound:Destroy()
	end)
	pcall(function() sound:Play() end)
	fadeSound(sound, 0, target, fadeSeconds, transitionGeneration, false)
end

local function transition(contextId, reason)
	local context = Catalog.Get(contextId)
	if not context then
		if global:GetAttribute("DebugContextAudio") == true then warn("[NTR Audio Phase 2] Missing context " .. tostring(contextId)) end
		return
	end
	if currentContextId == contextId then return end
	transitionGeneration += 1
	currentContextId = contextId
	currentContext = context
	local fade = enabled() and context.FadeSeconds or 0
	startChannel("Music", context, fade)
	startChannel("Ambience", context, fade)
	debugLog(("context=%s reason=%s music=%d ambience=%d"):format(context.Id, reason, #context.Music, #context.Ambience))
end

local function stopAll(seconds)
	transitionGeneration += 1
	for _, channel in pairs(channels) do
		local sound = channel.Sound
		channel.Sound = nil
		channel.ContextId = nil
		if sound then fadeSound(sound, sound.Volume, 0, seconds or 0, transitionGeneration, true) end
	end
	currentContextId = nil
	currentContext = nil
end

local function refresh()
	if not enabled() then
		if currentContextId ~= nil then stopAll(Catalog.GlobalNumber("DisableFadeSeconds", 0.4)) end
		return
	end
	local contextId, reason = resolveContextId()
	transition(contextId, reason)
end

function Controller.Start()
	if started then return Controller end
	started = true
	runtimeRoot = SoundService:FindFirstChild("NTR_ContextAudioRuntime_Local")
	if runtimeRoot then runtimeRoot:Destroy() end
	runtimeRoot = Instance.new("Folder")
	runtimeRoot.Name = "NTR_ContextAudioRuntime_Local"
	runtimeRoot.Parent = SoundService
	for _, object in ipairs(CollectionService:GetTagged(TAG)) do registerZone(object) end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(TAG):Connect(registerZone))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregisterZone))
	for _, attributeName in ipairs({ "NTR_OwnedGarageInside", "NTR_GarageSessionActive", "NTR_GarageSessionMode" }) do
		table.insert(connections, player:GetAttributeChangedSignal(attributeName):Connect(refresh))
	end
	local phase1Global = kit.Config.Audio:WaitForChild("Global")
	table.insert(connections, phase1Global:GetAttributeChangedSignal("AudioSystemEnabled"):Connect(refresh))
	table.insert(connections, global:GetAttributeChangedSignal("ContextAudioEnabled"):Connect(refresh))
	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local interval = 1 / math.max(1, Catalog.GlobalNumber("ContextUpdateHz", 5))
		if elapsed >= interval then elapsed = 0; refresh() end
	end)
	refresh()
	debugLog("ContextAudioController started")
	return Controller
end

function Controller.Stop()
	if not started then return end
	started = false
	if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	stopAll(0)
	if runtimeRoot and runtimeRoot.Parent then runtimeRoot:Destroy() end
	runtimeRoot = nil
	table.clear(channels.Music)
	table.clear(channels.Ambience)
end

function Controller.State()
	local zoneCount = 0
	for _ in pairs(zones) do zoneCount += 1 end
	return {
		ContextId = currentContextId,
		DisplayName = currentContext and currentContext.DisplayName or nil,
		RegisteredZones = zoneCount,
		MusicActive = channels.Music.Sound ~= nil,
		AmbienceActive = channels.Ambience.Sound ~= nil,
	}
end

return Controller
]=]

local CONTEXT_RUNTIME_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_RUNTIME_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(kit.Shared.Modules.Client.Audio:WaitForChild("ContextAudioController"))
	controller.Start()
	return controller
end)

if not ok then
	warn("[NTR Audio Phase 2] Context runtime failed safely: " .. tostring(result))
end
]=]

for label, source in pairs({
	ContextAudioCatalog = CONTEXT_CATALOG_SOURCE,
	ContextAudioController = CONTEXT_CONTROLLER_SOURCE,
	ContextAudioRuntime = CONTEXT_RUNTIME_SOURCE,
}) do compile(label, source) end

local kit = assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"), "ReplicatedStorage.NeoTokyoRacers missing")
local audioConfig = assert(find(kit, "Config.Audio"), "Phase 1 Audio config missing")
local phase1Global = assert(audioConfig:FindFirstChild("Global"), "Phase 1 Audio.Global missing")
assert(audioConfig:GetAttribute("InstallerRevision") == "NTR_AUDIO_SYSTEM_PHASE1_STANDARD_VEHICLE_AUDIO_V1", "Confirmed Phase 1 installer revision missing")
assert(phase1Global:GetAttribute("SchemaVersion") == 1, "Phase 1 audio schema mismatch")

local clientAudio = assert(find(kit, "Shared.Modules.Client.Audio"), "Phase 1 client Audio modules missing")
local vehicleController = assert(clientAudio:FindFirstChild("VehicleAudioController"), "Phase 1 VehicleAudioController missing")
assert(hasMarker(vehicleController.Source, "NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CLIENT_V1"), "Phase 1 vehicle controller marker missing")
compile("ConfirmedVehicleAudioController", vehicleController.Source)

local controllers = assert(find(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio"), "Phase 1 client Audio controllers missing")
for _, groupName in ipairs({ "NTR_GameplayMusic", "NTR_Ambience" }) do
	local group = SoundService:FindFirstChild(groupName)
	assert(group and group:IsA("SoundGroup"), "Confirmed SoundGroup missing: " .. groupName)
end

local function installedObject(path, className, marker)
	local object = find(game, path)
	assert(object and object.ClassName == className, path .. " missing or wrong class")
	if marker then
		assert(hasMarker(object.Source, marker), path .. " marker missing")
		compile(path, object.Source)
	end
	return object
end

local requiredContexts = {
	FREE_ROAM_ON_FOOT = { Priority = 0, DisplayName = "Free Roam - On Foot" },
	FREE_ROAM_DRIVING = { Priority = 10, DisplayName = "Free Roam - Driving" },
	DEALERSHIP_INTERIOR = { Priority = 100, DisplayName = "Dealership Interior" },
	OWNED_GARAGE_INTERIOR = { Priority = 110, DisplayName = "Owned Garage Interior" },
}

local function auditInstalled()
	local context = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.Context", "Folder")
	local global = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.Context.Global", "Folder")
	local definitions = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.Context.Contexts", "Folder")
	assert(context:GetAttribute("InstallerRevision") == REVISION, "Phase 2 installer revision mismatch")
	assert(global:GetAttribute("SchemaVersion") == 1, "Phase 2 context schema must be 1")
	assert(global:GetAttribute("DefaultContextId") == "FREE_ROAM_ON_FOOT", "Phase 2 default context mismatch")
	assert(global:GetAttribute("ZoneTag") == "NTR_AudioContextZone", "Phase 2 zone tag mismatch")
	for contextId in pairs(requiredContexts) do
		local folder = definitions:FindFirstChild(contextId)
		assert(folder and folder:IsA("Folder"), "Missing context definition " .. contextId)
		for _, childName in ipairs({ "MusicTracks", "AmbienceTracks" }) do
			local tracks = folder:FindFirstChild(childName)
			assert(tracks and tracks:IsA("Folder"), contextId .. "." .. childName .. " missing")
			local placeholder = tracks:FindFirstChild("Track01")
			assert(placeholder and placeholder:IsA("StringValue"), contextId .. "." .. childName .. ".Track01 missing")
		end
	end
	installedObject("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.ContextAudioCatalog", "ModuleScript", CATALOG_REVISION)
	installedObject("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.ContextAudioController", "ModuleScript", CONTROLLER_REVISION)
	installedObject("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.ContextAudioRuntimeController_Active", "LocalScript", RUNTIME_REVISION)
	return global, definitions
end

if MODE == "AUDIT" then
	local global, definitions = auditInstalled()
	local populated = 0
	for _, context in ipairs(definitions:GetChildren()) do
		for _, descendant in ipairs(context:GetDescendants()) do
			if descendant:IsA("StringValue") and descendant.Value ~= "" then populated += 1 end
		end
	end
	info(("AUDIT PASS: 4 context profiles; %d populated tracks; enabled=%s; tagged zones are runtime-discovered. No Studio objects changed."):format(populated, tostring(global:GetAttribute("ContextAudioEnabled"))))
	return
end

if MODE == "DISABLE" then
	local global = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.Context.Global", "Folder")
	global:SetAttribute("ContextAudioEnabled", false)
	info("DISABLE PASS: ContextAudioEnabled=false. Definitions and Phase 1 vehicle audio were preserved.")
	return
end

assert(MODE == "INSTALL", "MODE must be INSTALL, AUDIT, or DISABLE")

local created = {}
local attributes = {}
local sources = {}

local function writeSource(object, source, marker)
	if object.Source ~= "" then assert(hasMarker(object.Source, marker), object:GetFullName() .. " has unknown existing source") end
	local canDisable = object:IsA("Script") or object:IsA("LocalScript")
	table.insert(sources, { Object = object, Source = object.Source, Disabled = canDisable and object.Disabled or nil })
	object.Source = source
	if canDisable then object.Disabled = false end
end

local function rollback(problem)
	for index = #sources, 1, -1 do
		local snapshot = sources[index]
		pcall(function()
			snapshot.Object.Source = snapshot.Source
			if snapshot.Disabled ~= nil then snapshot.Object.Disabled = snapshot.Disabled end
		end)
	end
	for index = #attributes, 1, -1 do
		local snapshot = attributes[index]
		pcall(function()
			if snapshot.HadValue then snapshot.Object:SetAttribute(snapshot.Name, snapshot.Value)
			else snapshot.Object:SetAttribute(snapshot.Name, nil) end
		end)
	end
	for index = #created, 1, -1 do pcall(function() if created[index].Parent then created[index]:Destroy() end end) end
	error("[" .. PHASE .. "] rolled back: " .. tostring(problem), 0)
end

local ok, problem = xpcall(function()
	local context = ensureClass(audioConfig, "Context", "Folder", created)
	local global = ensureClass(context, "Global", "Folder", created)
	local definitions = ensureClass(context, "Contexts", "Folder", created)
	setDefaultAttribute(attributes, context, "InstallerRevision", REVISION)
	if context:GetAttribute("InstallerRevision") ~= REVISION then
		snapshotAttribute(attributes, context, "InstallerRevision")
		context:SetAttribute("InstallerRevision", REVISION)
	end
	for name, value in pairs({
		SchemaVersion = 1,
		ContextAudioEnabled = false,
		DefaultContextId = "FREE_ROAM_ON_FOOT",
		ContextUpdateHz = 5,
		MaxRegisteredZones = 32,
		MaxTracksPerChannel = 64,
		DisableFadeSeconds = 0.4,
		DebugContextAudio = false,
		ZoneTag = "NTR_AudioContextZone",
	}) do setDefaultAttribute(attributes, global, name, value) end

	for contextId, defaults in pairs(requiredContexts) do
		local definition = ensureClass(definitions, contextId, "Folder", created)
		setDefaultAttribute(attributes, definition, "DisplayName", defaults.DisplayName)
		setDefaultAttribute(attributes, definition, "Priority", defaults.Priority)
		setDefaultAttribute(attributes, definition, "FadeSeconds", 1.5)
		setDefaultAttribute(attributes, definition, "MusicGain", 0.55)
		setDefaultAttribute(attributes, definition, "AmbienceGain", 0.45)
		setDefaultAttribute(attributes, definition, "PlaylistMode", "Sequential")
		for _, tracksName in ipairs({ "MusicTracks", "AmbienceTracks" }) do
			local tracks = ensureClass(definition, tracksName, "Folder", created)
			local track = ensureClass(tracks, "Track01", "StringValue", created)
			setDefaultAttribute(attributes, track, "Order", 1)
			setDefaultAttribute(attributes, track, "Gain", 1)
			setDefaultAttribute(attributes, track, "Loop", tracksName == "AmbienceTracks")
		end
	end

	local catalog = ensureClass(clientAudio, "ContextAudioCatalog", "ModuleScript", created)
	local controller = ensureClass(clientAudio, "ContextAudioController", "ModuleScript", created)
	local runtime = ensureClass(controllers, "ContextAudioRuntimeController_Active", "LocalScript", created)
	writeSource(catalog, CONTEXT_CATALOG_SOURCE, CATALOG_REVISION)
	writeSource(controller, CONTEXT_CONTROLLER_SOURCE, CONTROLLER_REVISION)
	writeSource(runtime, CONTEXT_RUNTIME_SOURCE, RUNTIME_REVISION)
	auditInstalled()
end, debug.traceback)

if not ok then rollback(problem) end

local global = auditInstalled()
info("INSTALL PASS: contextual music/ambience profiles and runtime installed.")
info("ContextAudioEnabled remains " .. tostring(global:GetAttribute("ContextAudioEnabled")) .. "; all Track01 values remain blank by design.")
info("Add StringValue tracks under a context's MusicTracks/AmbienceTracks; tag sparse zone Parts/Models NTR_AudioContextZone and set AudioContextId when needed.")
info("No Phase 1 vehicle audio, driving, UI, loading, VFX, persistence, economy or world geometry source was changed.")
