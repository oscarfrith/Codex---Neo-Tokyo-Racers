-- Neo Tokyo Racers - Audio System V1
-- Canonical phased installer. Current target: Phase 1 Standard vehicle audio.
--
-- Run this complete file in the Roblox Studio Command Bar in Edit mode.
-- It creates no in-game backups and does not patch driving, VFX, bootstrap,
-- garage UI, persistence, economy, music, ambience, or acoustic world geometry.
--
-- Modes:
--   INSTALL - install/update the isolated Phase 1 foundation.
--   AUDIT   - verify the installed Phase 1 foundation without mutation.
--   DISABLE - turn off the installed audio runtime without deleting it.

local MODE = "INSTALL"

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run the audio installer in Studio Edit mode.")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "NTR Audio System Phase 1 V1"
local REVISION = "NTR_AUDIO_SYSTEM_PHASE1_STANDARD_VEHICLE_AUDIO_V1"
local STATE_REVISION = "NTR_AUDIO_SYSTEM_PHASE1_STATE_CONTRACT_V1"
local BUS_REVISION = "NTR_AUDIO_SYSTEM_PHASE1_BUS_V1"
local CATALOG_REVISION = "NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CATALOG_V1"
local SERVER_REVISION = "NTR_AUDIO_SYSTEM_PHASE1_STATE_SERVICE_V1"
local CLIENT_REVISION = "NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CLIENT_V1"
local RUNTIME_REVISION = "NTR_AUDIO_SYSTEM_PHASE1_RUNTIME_CLIENT_V1"

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

local function compile(label, source)
	local fn, problem = loadstring(source, "=" .. label)
	assert(fn, label .. " compile failed: " .. tostring(problem))
end

local function hasMarker(source, marker)
	return type(source) == "string" and string.find(source, "-- " .. marker, 1, true) ~= nil
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

local STATE_CONTRACT_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE1_STATE_CONTRACT_V1
local Contract = {}

Contract.Version = 1
Contract.States = {
	Ignition = { Off = true, Starting = true, Running = true },
	Drive = { Idle = true, Accelerating = true, Braking = true, Reversing = true },
	Drift = { None = true, Left = true, Right = true },
	Boost = { Off = true, Normal = true, MiniBoost = true },
}

Contract.Defaults = {
	Ignition = "Off",
	Drive = "Idle",
	Drift = "None",
	Boost = "Off",
}

function Contract.Validate(payload)
	if typeof(payload) ~= "table" then return false, "PayloadType" end
	local result = {}
	for field, allowed in pairs(Contract.States) do
		local value = tostring(payload[field] or "")
		if not allowed[value] then return false, "Invalid" .. field end
		result[field] = value
	end
	local revision = tonumber(payload.Revision)
	if not revision or revision < 1 or revision % 1 ~= 0 then return false, "InvalidRevision" end
	result.Revision = revision
	return true, result
end

return Contract
]=]

local AUDIO_BUS_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE1_BUS_V1
local SoundService = game:GetService("SoundService")

local Bus = {}
local started = false
local registrations = setmetatable({}, { __mode = "k" })
local groupConnections = {}

local groupNames = {
	LoadingMusic = "NTR_LoadingMusic",
	GameplayMusic = "NTR_GameplayMusic",
	Vehicle = "NTR_Vehicle",
	Ambience = "NTR_Ambience",
	GameplaySFX = "NTR_GameplaySFX",
	UI = "NTR_UI",
}

local function groupVolume(category)
	local name = groupNames[category]
	local group = name and SoundService:FindFirstChild(name)
	if group and group:IsA("SoundGroup") then
		return math.clamp(tonumber(group.Volume) or 1, 0, 3)
	end
	return 1
end

local function apply(fader, record)
	if not (fader and fader.Parent and fader:IsA("AudioFader")) then
		registrations[fader] = nil
		return
	end
	fader.Volume = math.clamp((tonumber(record.Gain) or 0) * groupVolume(record.Category), 0, 3)
end

local function refreshCategory(category)
	for fader, record in pairs(registrations) do
		if record.Category == category then apply(fader, record) end
	end
end

function Bus.Start()
	if started then return Bus end
	started = true
	for category, name in pairs(groupNames) do
		local group = SoundService:FindFirstChild(name)
		if group and group:IsA("SoundGroup") then
			groupConnections[category] = group:GetPropertyChangedSignal("Volume"):Connect(function()
				refreshCategory(category)
			end)
		end
	end
	return Bus
end

function Bus.Register(category, fader, initialGain)
	assert(groupNames[category], "Unknown audio category: " .. tostring(category))
	assert(fader and fader:IsA("AudioFader"), "AudioBusController.Register requires AudioFader")
	registrations[fader] = { Category = category, Gain = math.max(0, tonumber(initialGain) or 0) }
	apply(fader, registrations[fader])
	return fader
end

function Bus.SetGain(fader, gain)
	local record = registrations[fader]
	if not record then return false end
	record.Gain = math.max(0, tonumber(gain) or 0)
	apply(fader, record)
	return true
end

function Bus.Unregister(fader)
	registrations[fader] = nil
end

function Bus.Count(category)
	local count = 0
	for _, record in pairs(registrations) do
		if category == nil or record.Category == category then count += 1 end
	end
	return count
end

return Bus
]=]

local VEHICLE_CATALOG_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CATALOG_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = {}
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audioConfig = kit:WaitForChild("Config"):WaitForChild("Audio")
local profiles = audioConfig:WaitForChild("VehicleProfiles")
local global = audioConfig:WaitForChild("Global")

Catalog.LoopLayers = { "Idle", "EngineLow", "EngineHigh", "Acceleration", "Coast", "DriftLoop", "BoostLoop", "DriverWind" }
Catalog.OneShotLayers = { "Ignition", "Shutdown", "DriftEnter", "BoostEnter", "BoostRelease" }

local defaultGains = {
	Ignition = 0.85,
	Shutdown = 0.75,
	Idle = 0.34,
	EngineLow = 0.55,
	EngineHigh = 0.56,
	Acceleration = 0.48,
	Coast = 0.28,
	DriftEnter = 0.55,
	DriftLoop = 0.52,
	BoostEnter = 0.72,
	BoostLoop = 0.65,
	BoostRelease = 0.55,
	DriverWind = 0.38,
}

local function assetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

function Catalog.GlobalNumber(name, fallback)
	local value = tonumber(global:GetAttribute(name))
	return value ~= nil and value or fallback
end

function Catalog.GlobalBool(name, fallback)
	local value = global:GetAttribute(name)
	return typeof(value) == "boolean" and value or fallback
end

function Catalog.ResolveProfileId(vehicle)
	if not vehicle then return tostring(global:GetAttribute("FallbackProfileId") or "GENERIC_STANDARD_AUDIO") end
	local resolved = tostring(vehicle:GetAttribute("ResolvedAudioProfileId") or "")
	if resolved ~= "" and profiles:FindFirstChild(resolved) then return resolved end
	local standard = tostring(vehicle:GetAttribute("StandardAudioProfileId") or "")
	if standard ~= "" and profiles:FindFirstChild(standard) then return standard end
	return tostring(global:GetAttribute("FallbackProfileId") or "GENERIC_STANDARD_AUDIO")
end

function Catalog.GetProfile(profileId)
	local folder = profiles:FindFirstChild(tostring(profileId or ""))
	if not (folder and folder:IsA("Folder")) then
		folder = profiles:FindFirstChild(tostring(global:GetAttribute("FallbackProfileId") or "GENERIC_STANDARD_AUDIO"))
	end
	if not folder then return nil end
	local profile = { Id = folder.Name, Folder = folder, Assets = {}, Gains = {}, Pitches = {} }
	for _, layer in ipairs(Catalog.LoopLayers) do
		profile.Assets[layer] = assetId(folder:GetAttribute(layer .. "AssetId"))
		profile.Gains[layer] = math.clamp(tonumber(folder:GetAttribute(layer .. "Gain")) or defaultGains[layer] or 0.5, 0, 3)
		profile.Pitches[layer] = math.clamp(tonumber(folder:GetAttribute(layer .. "Pitch")) or 1, 0.5, 2)
	end
	for _, layer in ipairs(Catalog.OneShotLayers) do
		profile.Assets[layer] = assetId(folder:GetAttribute(layer .. "AssetId"))
		profile.Gains[layer] = math.clamp(tonumber(folder:GetAttribute(layer .. "Gain")) or defaultGains[layer] or 0.5, 0, 3)
		profile.Pitches[layer] = math.clamp(tonumber(folder:GetAttribute(layer .. "Pitch")) or 1, 0.5, 2)
	end
	return profile
end

function Catalog.HasAudibleAsset(profile)
	if not profile then return false end
	for _, value in pairs(profile.Assets or {}) do
		if value ~= "" then return true end
	end
	return false
end

return Catalog
]=]

local VEHICLE_AUDIO_CLIENT_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CLIENT_V1
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Controller = {}
local localPlayer = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audioModules = kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Client"):WaitForChild("Audio")
local commonAudio = kit.Shared.Modules:WaitForChild("Common"):WaitForChild("Audio")
local Bus = require(audioModules:WaitForChild("AudioBusController"))
local Catalog = require(audioModules:WaitForChild("VehicleAudioCatalog"))
local Contract = require(commonAudio:WaitForChild("VehicleAudioStateContract"))
local stateRemote = kit.Shared.Remotes:WaitForChild("Audio"):WaitForChild("VehicleAudioState")
local global = kit.Config.Audio:WaitForChild("Global")
local quality = kit.Config.Audio:WaitForChild("Quality")

local MPH_PER_STUD = 0.625
local tracked = setmetatable({}, { __mode = "k" })
local started = false
local heartbeatConnection = nil
local childAddedConnection = nil
local childRemovedConnection = nil
local cameraConnection = nil
local updateAccumulator = 0
local priorityAccumulator = 0
local localRevision = 0
local runtimeRoot = nil
local deviceOutput = nil
local listener = nil
local listenerWire = nil
local createdOutput = false
local createdListener = false
local createdListenerWire = false

local function enabled()
	return global:GetAttribute("AudioSystemEnabled") == true and global:GetAttribute("VehicleAudioEnabled") ~= false
end

local function debugLog(message)
	if global:GetAttribute("DebugAudio") == true then print("[NTR Audio Phase 1] " .. tostring(message)) end
end

local function vehiclesRoot()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function currentHumanoid()
	local character = localPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function seatFor(vehicle)
	local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
	return seat and seat:IsA("VehicleSeat") and seat or nil
end

local function rootFor(vehicle)
	local root = vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
	return root and root:IsA("BasePart") and root or nil
end

local function isLocalDriver(vehicle)
	if tonumber(vehicle:GetAttribute("DriverUserId")) ~= localPlayer.UserId then return false end
	local humanoid = currentHumanoid()
	local seat = humanoid and humanoid.SeatPart
	return seat ~= nil and seat:IsDescendantOf(vehicle)
end

local function ensureOutputGraph()
	local camera = Workspace.CurrentCamera
	if listener and listener.Parent ~= camera then
		if createdListenerWire and listenerWire and listenerWire.Parent then listenerWire:Destroy() end
		if createdListener and listener.Parent then listener:Destroy() end
		listener = nil
		listenerWire = nil
		createdListener = false
		createdListenerWire = false
	end
	deviceOutput = SoundService:FindFirstChildWhichIsA("AudioDeviceOutput", true)
	if not deviceOutput then
		deviceOutput = Instance.new("AudioDeviceOutput")
		deviceOutput.Name = "NTR_AudioDeviceOutput_Runtime"
		deviceOutput.Parent = runtimeRoot
		createdOutput = true
	end
	if camera then listener = camera:FindFirstChildWhichIsA("AudioListener", true) end
	if not listener and camera then
		listener = Instance.new("AudioListener")
		listener.Name = "NTR_AudioListener_Runtime"
		listener.Parent = camera
		createdListener = true
	end
	if listener and deviceOutput then
		for _, candidate in ipairs(SoundService:GetDescendants()) do
			if candidate:IsA("Wire") and candidate.SourceInstance == listener and candidate.TargetInstance == deviceOutput then
				listenerWire = candidate
				break
			end
		end
	end
	if listener and deviceOutput and not listenerWire then
		listenerWire = Instance.new("Wire")
		listenerWire.Name = "NTR_ListenerToOutput"
		listenerWire.SourceInstance = listener
		listenerWire.TargetInstance = deviceOutput
		listenerWire.Parent = runtimeRoot
		createdListenerWire = true
	end
end

local function wire(source, target, parent, name)
	local item = Instance.new("Wire")
	item.Name = name
	item.SourceInstance = source
	item.TargetInstance = target
	item.Parent = parent
	return item
end

local function setPlayerAsset(player, assetId)
	local ok = pcall(function() player.Asset = assetId end)
	if not ok then pcall(function() player.AssetId = assetId end) end
end

local function newPlayer(parent, name, assetId, looped, pitch)
	if assetId == "" then return nil end
	local player = Instance.new("AudioPlayer")
	player.Name = name
	player.AutoLoad = true
	player.Looping = looped == true
	player.Volume = 1
	player.PlaybackSpeed = math.clamp(tonumber(pitch) or 1, 0.5, 2)
	setPlayerAsset(player, assetId)
	player.Parent = parent
	return player
end

local function newRoutedSource(graph, layer, assetId, looped, pitch, route, emitter)
	local player = newPlayer(graph.Root, "Player_" .. layer, assetId, looped, pitch)
	if not player then return nil end
	local fader = Instance.new("AudioFader")
	fader.Name = "Fader_" .. layer
	fader.Volume = 0
	fader.Parent = graph.Root
	wire(player, fader, graph.Root, "Wire_" .. layer .. "_PlayerToFader")
	if route == "Internal" then
		wire(fader, deviceOutput, graph.Root, "Wire_" .. layer .. "_FaderToOutput")
	else
		wire(fader, emitter, graph.Root, "Wire_" .. layer .. "_FaderToEmitter")
	end
	Bus.Register("Vehicle", fader, 0)
	if looped then pcall(function() player:Play() end) end
	return { Player = player, Fader = fader, Gain = 0, Target = 0 }
end

local function destroyGraph(state)
	local graph = state.Graph
	if not graph then return end
	for _, layer in pairs(graph.Layers) do
		if layer.Fader then Bus.Unregister(layer.Fader) end
	end
	for fader in pairs(graph.OneShotFaders) do Bus.Unregister(fader) end
	if graph.Emitter and graph.Emitter.Parent then graph.Emitter:Destroy() end
	if graph.Root and graph.Root.Parent then graph.Root:Destroy() end
	state.Graph = nil
end

local function makeGraph(state, route, tier)
	destroyGraph(state)
	if tier == "Silent" or not enabled() then return end
	local vehicle = state.Vehicle
	local root = rootFor(vehicle)
	if not root then return end
	local profileId = Catalog.ResolveProfileId(vehicle)
	local profile = Catalog.GetProfile(profileId)
	if not profile then return end
	local graphRoot = Instance.new("Folder")
	graphRoot.Name = "Vehicle_" .. tostring(vehicle:GetAttribute("OwnerUserId") or vehicle.Name)
	graphRoot.Parent = runtimeRoot
	local graph = {
		Root = graphRoot,
		Layers = {},
		OneShotFaders = setmetatable({}, { __mode = "k" }),
		Route = route,
		Tier = tier,
		Profile = profile,
		ProfileId = profileId,
		Emitter = nil,
	}
	if route == "External" then
		local emitter = Instance.new("AudioEmitter")
		emitter.Name = "NTR_VehicleAudioEmitter_Runtime"
		pcall(function() emitter.AcousticSimulationEnabled = false end)
		emitter.Parent = root
		local minDistance = math.max(1, tonumber(global:GetAttribute("ExternalMinDistanceStuds")) or 12)
		local maxDistance = math.max(minDistance + 1, tonumber(global:GetAttribute("ExternalMaxDistanceStuds")) or 240)
		pcall(function() emitter:SetDistanceAttenuation({ [0] = 1, [minDistance] = 1, [maxDistance * 0.55] = 0.28, [maxDistance] = 0 }) end)
		graph.Emitter = emitter
	end
	state.Graph = graph
	local wanted = tier == "Simple" and { "EngineLow" } or Catalog.LoopLayers
	for _, layerName in ipairs(wanted) do
		if route == "External" and layerName == "DriverWind" then continue end
		local layer = newRoutedSource(graph, layerName, profile.Assets[layerName] or "", true, profile.Pitches[layerName], route, graph.Emitter)
		if layer then graph.Layers[layerName] = layer end
	end
	if Catalog.HasAudibleAsset(profile) then
		debugLog(("graph %s %s %s"):format(route, tier, profileId))
	end
end

local function playOneShot(state, layerName)
	local graph = state.Graph
	if not graph then return end
	local activeCount = 0
	for _ in pairs(graph.OneShotFaders) do activeCount += 1 end
	if activeCount >= math.max(1, math.floor(tonumber(quality:GetAttribute("MaxConcurrentOneShotsPerVehicle")) or 8)) then return end
	local assetId = graph.Profile.Assets[layerName] or ""
	if assetId == "" then return end
	local player = newPlayer(graph.Root, "OneShot_" .. layerName, assetId, false, graph.Profile.Pitches[layerName])
	if not player then return end
	local fader = Instance.new("AudioFader")
	fader.Name = "OneShotFader_" .. layerName
	fader.Parent = graph.Root
	local oneShotWires = { wire(player, fader, graph.Root, "OneShotWire_" .. layerName .. "_PlayerToFader") }
	if graph.Route == "Internal" then
		table.insert(oneShotWires, wire(fader, deviceOutput, graph.Root, "OneShotWire_" .. layerName .. "_FaderToOutput"))
	elseif graph.Emitter then
		table.insert(oneShotWires, wire(fader, graph.Emitter, graph.Root, "OneShotWire_" .. layerName .. "_FaderToEmitter"))
	else
		player:Destroy(); fader:Destroy(); return
	end
	graph.OneShotFaders[fader] = true
	Bus.Register("Vehicle", fader, graph.Profile.Gains[layerName] or 0.5)
	local cleaned = false
	local function cleanup()
		if cleaned then return end
		cleaned = true
		Bus.Unregister(fader)
		graph.OneShotFaders[fader] = nil
		for _, oneShotWire in ipairs(oneShotWires) do
			if oneShotWire.Parent then oneShotWire:Destroy() end
		end
		if player.Parent then player:Destroy() end
		if fader.Parent then fader:Destroy() end
	end
	player.Ended:Once(cleanup)
	task.delay(math.max(2, Catalog.GlobalNumber("OneShotMaxLifetimeSeconds", 12)), cleanup)
	pcall(function() player:Play() end)
end

local function semanticState(vehicle, localDriver)
	if localDriver then
		local accelerating = vehicle:GetAttribute("Accelerating") == true
		local braking = vehicle:GetAttribute("Braking") == true
		local driftingLeft = vehicle:GetAttribute("DriftingLeft") == true
		local driftingRight = vehicle:GetAttribute("DriftingRight") == true
		local root = rootFor(vehicle)
		local reversing = braking and root ~= nil and root.CFrame.LookVector:Dot(root.AssemblyLinearVelocity) < -2
		return {
			Ignition = "Running",
			Drive = accelerating and "Accelerating" or (reversing and "Reversing" or (braking and "Braking" or "Idle")),
			Drift = driftingLeft and "Left" or (driftingRight and "Right" or "None"),
			Boost = vehicle:GetAttribute("Boosting") == true and "Normal" or "Off",
		}
	end
	return {
		Ignition = tostring(vehicle:GetAttribute("NTRAudioIgnition") or Contract.Defaults.Ignition),
		Drive = tostring(vehicle:GetAttribute("NTRAudioDrive") or Contract.Defaults.Drive),
		Drift = tostring(vehicle:GetAttribute("NTRAudioDrift") or Contract.Defaults.Drift),
		Boost = tostring(vehicle:GetAttribute("NTRAudioBoost") or Contract.Defaults.Boost),
	}
end

local function sameState(a, b)
	return a and b and a.Ignition == b.Ignition and a.Drive == b.Drive and a.Drift == b.Drift and a.Boost == b.Boost
end

local function publishLocalState(state, semantic)
	if not state.LocalDriver or sameState(state.LastPublished, semantic) then return end
	localRevision += 1
	state.LastPublished = table.clone(semantic)
	stateRemote:FireServer(state.Vehicle, {
		Ignition = semantic.Ignition,
		Drive = semantic.Drive,
		Drift = semantic.Drift,
		Boost = semantic.Boost,
		Revision = localRevision,
	})
end

local function setTarget(graph, name, value)
	local layer = graph and graph.Layers[name]
	if layer then layer.Target = math.max(0, value) end
end

local function updateGraph(state, dt)
	local graph = state.Graph
	local root = rootFor(state.Vehicle)
	if not (graph and root) then return end
	local semantic = semanticState(state.Vehicle, state.LocalDriver)
	publishLocalState(state, semantic)
	local speedMph = root.AssemblyLinearVelocity.Magnitude * MPH_PER_STUD
	local speedAlpha = math.clamp(speedMph / math.max(1, Catalog.GlobalNumber("EngineHighFullSpeedMph", 120)), 0, 1)
	local running = semantic.Ignition == "Running" or semantic.Ignition == "Starting"
	local accelerating = semantic.Drive == "Accelerating"
	local coasting = running and not accelerating and speedMph > 8
	local drifting = semantic.Drift ~= "None"
	local boosting = semantic.Boost ~= "Off"
	local gains = graph.Profile.Gains
	setTarget(graph, "Idle", running and gains.Idle * (1 - speedAlpha * 0.75) or 0)
	setTarget(graph, "EngineLow", running and gains.EngineLow * (0.30 + (1 - math.abs(speedAlpha - 0.35)) * 0.70) or 0)
	setTarget(graph, "EngineHigh", running and gains.EngineHigh * speedAlpha or 0)
	setTarget(graph, "Acceleration", accelerating and gains.Acceleration or 0)
	setTarget(graph, "Coast", coasting and gains.Coast * math.clamp(speedMph / 50, 0.2, 1) or 0)
	setTarget(graph, "DriftLoop", drifting and gains.DriftLoop or 0)
	setTarget(graph, "BoostLoop", boosting and gains.BoostLoop or 0)
	setTarget(graph, "DriverWind", state.LocalDriver and gains.DriverWind * math.clamp((speedMph - 18) / 110, 0, 1) or 0)
	local smoothing = math.max(0.1, Catalog.GlobalNumber("LayerSmoothingPerSecond", 7))
	local alpha = math.clamp(dt * smoothing, 0, 1)
	for layerName, layer in pairs(graph.Layers) do
		layer.Gain += (layer.Target - layer.Gain) * alpha
		Bus.SetGain(layer.Fader, layer.Gain)
		if layerName == "EngineLow" then
			layer.Player.PlaybackSpeed = math.clamp((graph.Profile.Pitches.EngineLow or 1) * (0.82 + speedAlpha * 0.38), 0.5, 2)
		elseif layerName == "EngineHigh" then
			layer.Player.PlaybackSpeed = math.clamp((graph.Profile.Pitches.EngineHigh or 1) * (0.86 + speedAlpha * 0.34), 0.5, 2)
		end
	end
	local previous = state.LastSemantic
	if previous then
		if previous.Ignition ~= semantic.Ignition then
			if semantic.Ignition == "Running" then playOneShot(state, "Ignition") elseif semantic.Ignition == "Off" then playOneShot(state, "Shutdown") end
		end
		if previous.Drift == "None" and semantic.Drift ~= "None" then playOneShot(state, "DriftEnter") end
		if previous.Boost == "Off" and semantic.Boost ~= "Off" then playOneShot(state, "BoostEnter") end
		if previous.Boost ~= "Off" and semantic.Boost == "Off" then playOneShot(state, "BoostRelease") end
	elseif semantic.Ignition == "Running" then
		playOneShot(state, "Ignition")
	end
	state.LastSemantic = semantic
end

local function cleanupVehicle(vehicle)
	local state = tracked[vehicle]
	if not state then return end
	destroyGraph(state)
	for _, connection in ipairs(state.Connections) do connection:Disconnect() end
	tracked[vehicle] = nil
end

local function registerVehicle(vehicle)
	if tracked[vehicle] or not vehicle:IsA("Model") then return end
	local state = { Vehicle = vehicle, Connections = {}, Tier = "Silent", Route = "External", LocalDriver = false }
	tracked[vehicle] = state
	table.insert(state.Connections, vehicle.Destroying:Connect(function() cleanupVehicle(vehicle) end))
	for _, attribute in ipairs({ "ResolvedAudioProfileId", "AudioProfileRevision", "DriverUserId" }) do
		table.insert(state.Connections, vehicle:GetAttributeChangedSignal(attribute):Connect(function()
			state.ForceRefresh = true
		end))
	end
end

local function cameraPosition()
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position or Vector3.zero
end

local function refreshPriorities()
	local remotes = {}
	local origin = cameraPosition()
	for vehicle, state in pairs(tracked) do
		if not vehicle.Parent then cleanupVehicle(vehicle) continue end
		local localDriver = isLocalDriver(vehicle)
		state.LocalDriver = localDriver
		if localDriver then
			state.NextTier = "Detailed"
			state.NextRoute = "Internal"
		else
			local root = rootFor(vehicle)
			local distance = root and (root.Position - origin).Magnitude or math.huge
			table.insert(remotes, { State = state, Distance = distance })
		end
	end
	table.sort(remotes, function(a, b) return a.Distance < b.Distance end)
	local maxDistance = tonumber(global:GetAttribute("ExternalMaxDistanceStuds")) or 240
	local maxDetailed = math.max(0, math.floor(tonumber(quality:GetAttribute("MaxDetailedRemoteVehicles")) or 6))
	local maxSimple = math.max(0, math.floor(tonumber(quality:GetAttribute("MaxSimpleRemoteVehicles")) or 6))
	for index, item in ipairs(remotes) do
		item.State.NextRoute = "External"
		if item.Distance > maxDistance then item.State.NextTier = "Silent"
		elseif index <= maxDetailed then item.State.NextTier = "Detailed"
		elseif index <= maxDetailed + maxSimple then item.State.NextTier = "Simple"
		else item.State.NextTier = "Silent" end
	end
	for vehicle, state in pairs(tracked) do
		local profileId = Catalog.ResolveProfileId(vehicle)
		local profileChanged = state.Graph and state.Graph.ProfileId ~= profileId
		local desiredTier = enabled() and (state.NextTier or "Silent") or "Silent"
		if state.ForceRefresh or profileChanged or state.Tier ~= desiredTier or state.Route ~= state.NextRoute then
			state.ForceRefresh = false
			state.Tier = desiredTier
			state.Route = state.NextRoute or "External"
			makeGraph(state, state.Route, state.Tier)
		end
	end
end

function Controller.Start()
	if started then return Controller end
	started = true
	Bus.Start()
	runtimeRoot = SoundService:FindFirstChild("NTR_AudioRuntime_Local")
	if runtimeRoot then runtimeRoot:Destroy() end
	runtimeRoot = Instance.new("Folder")
	runtimeRoot.Name = "NTR_AudioRuntime_Local"
	runtimeRoot.Parent = SoundService
	ensureOutputGraph()
	local root = vehiclesRoot()
	if not root then warn("[NTR Audio Phase 1] PlayerVehicles runtime root missing; vehicle audio is inactive.") return Controller end
	for _, vehicle in ipairs(root:GetChildren()) do registerVehicle(vehicle) end
	childAddedConnection = root.ChildAdded:Connect(function(vehicle) task.defer(registerVehicle, vehicle) end)
	childRemovedConnection = root.ChildRemoved:Connect(cleanupVehicle)
	cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		task.defer(ensureOutputGraph)
	end)
	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		updateAccumulator += dt
		priorityAccumulator += dt
		local updateInterval = 1 / math.max(1, tonumber(quality:GetAttribute("ParameterUpdateHz")) or 15)
		local priorityInterval = 1 / math.max(1, tonumber(quality:GetAttribute("PriorityUpdateHz")) or 4)
		if priorityAccumulator >= priorityInterval then priorityAccumulator = 0; refreshPriorities() end
		if updateAccumulator >= updateInterval then
			local step = updateAccumulator; updateAccumulator = 0
			for _, state in pairs(tracked) do updateGraph(state, step) end
		end
	end)
	debugLog("VehicleAudioController started")
	return Controller
end

function Controller.Stop()
	if not started then return end
	started = false
	if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
	if childAddedConnection then childAddedConnection:Disconnect(); childAddedConnection = nil end
	if childRemovedConnection then childRemovedConnection:Disconnect(); childRemovedConnection = nil end
	if cameraConnection then cameraConnection:Disconnect(); cameraConnection = nil end
	local vehicles = {}
	for vehicle in pairs(tracked) do table.insert(vehicles, vehicle) end
	for _, vehicle in ipairs(vehicles) do cleanupVehicle(vehicle) end
	if createdListenerWire and listenerWire and listenerWire.Parent then listenerWire:Destroy() end
	if createdListener and listener and listener.Parent then listener:Destroy() end
	if createdOutput and deviceOutput and deviceOutput.Parent then deviceOutput:Destroy() end
	if runtimeRoot and runtimeRoot.Parent then runtimeRoot:Destroy() end
	runtimeRoot = nil
end

function Controller.Counts()
	local vehicles, graphs = 0, 0
	for _, state in pairs(tracked) do vehicles += 1; if state.Graph then graphs += 1 end end
	return { Vehicles = vehicles, Graphs = graphs, VehicleFaders = Bus.Count("Vehicle") }
end

return Controller
]=]

local VEHICLE_AUDIO_SERVER_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE1_STATE_SERVICE_V1
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audioConfig = kit:WaitForChild("Config"):WaitForChild("Audio")
local global = audioConfig:WaitForChild("Global")
local profiles = audioConfig:WaitForChild("VehicleProfiles")
local Contract = require(kit.Shared.Modules.Common.Audio:WaitForChild("VehicleAudioStateContract"))
local remote = kit.Shared.Remotes.Audio:WaitForChild("VehicleAudioState")

local records = setmetatable({}, { __mode = "k" })
local rate = {}

local function vehiclesRoot()
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local runtime = world:WaitForChild("Runtime")
	return runtime:WaitForChild("PlayerVehicles")
end

local root = vehiclesRoot()

local function validProfileId(raw)
	local value = tostring(raw or "")
	return value ~= "" and profiles:FindFirstChild(value) ~= nil and value or nil
end

local function stampProfile(vehicle)
	local fallback = validProfileId(global:GetAttribute("FallbackProfileId")) or "GENERIC_STANDARD_AUDIO"
	local resolved = validProfileId(vehicle:GetAttribute("ResolvedAudioProfileId"))
	local standard = validProfileId(vehicle:GetAttribute("StandardAudioProfileId")) or fallback
	if not resolved then
		vehicle:SetAttribute("ResolvedAudioProfileId", standard)
		vehicle:SetAttribute("AudioProfileSource", "Standard")
		vehicle:SetAttribute("AudioProfileRevision", math.max(1, tonumber(vehicle:GetAttribute("AudioProfileRevision")) or 0))
	end
end

local function resetState(vehicle, running)
	vehicle:SetAttribute("NTRAudioIgnition", running and "Running" or "Off")
	vehicle:SetAttribute("NTRAudioDrive", "Idle")
	vehicle:SetAttribute("NTRAudioDrift", "None")
	vehicle:SetAttribute("NTRAudioBoost", "Off")
	vehicle:SetAttribute("NTRAudioStateRevision", (tonumber(vehicle:GetAttribute("NTRAudioStateRevision")) or 0) + 1)
end

local function driverSeated(player, vehicle)
	if not player or not vehicle then return false end
	if tonumber(vehicle:GetAttribute("DriverUserId")) ~= player.UserId then return false end
	local character = player.Character
	local seat = vehicle:FindFirstChild("DriverSeat", true)
	return character ~= nil and seat ~= nil and seat:IsA("VehicleSeat") and seat.Occupant ~= nil and seat.Occupant.Parent == character
end

local function refreshOccupancy(vehicle)
	local driverId = tonumber(vehicle:GetAttribute("DriverUserId"))
	local player = driverId and Players:GetPlayerByUserId(driverId)
	resetState(vehicle, player ~= nil and driverSeated(player, vehicle))
end

local function cleanup(vehicle)
	local record = records[vehicle]
	if not record then return end
	for _, connection in ipairs(record.Connections) do connection:Disconnect() end
	records[vehicle] = nil
end

local function bindSeat(vehicle, seat)
	local record = records[vehicle]
	if not record or not (seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat") or record.Seat == seat then return end
	if record.SeatConnection then record.SeatConnection:Disconnect() end
	record.Seat = seat
	record.SeatConnection = seat:GetPropertyChangedSignal("Occupant"):Connect(function() refreshOccupancy(vehicle) end)
	table.insert(record.Connections, record.SeatConnection)
	refreshOccupancy(vehicle)
end

local function register(vehicle)
	if records[vehicle] or not vehicle:IsA("Model") then return end
	stampProfile(vehicle)
	local record = { Connections = {}, LastClientRevision = 0 }
	records[vehicle] = record
	table.insert(record.Connections, vehicle:GetAttributeChangedSignal("DriverUserId"):Connect(function() refreshOccupancy(vehicle) end))
	local seat = vehicle:FindFirstChild("DriverSeat", true)
	if seat and seat:IsA("VehicleSeat") then bindSeat(vehicle, seat) end
	table.insert(record.Connections, vehicle.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "DriverSeat" and descendant:IsA("VehicleSeat") then bindSeat(vehicle, descendant) end
	end))
	table.insert(record.Connections, vehicle.Destroying:Connect(function() cleanup(vehicle) end))
	refreshOccupancy(vehicle)
end

local function withinRate(player)
	local now = os.clock()
	local record = rate[player]
	if not record or now - record.WindowStarted >= 1 then
		record = { WindowStarted = now, Count = 0 }
		rate[player] = record
	end
	record.Count += 1
	return record.Count <= math.max(4, tonumber(global:GetAttribute("StateRateLimitPerSecond")) or 20)
end

remote.OnServerEvent:Connect(function(player, vehicle, payload)
	if global:GetAttribute("AudioSystemEnabled") ~= true or global:GetAttribute("VehicleAudioEnabled") == false then return end
	if not withinRate(player) then return end
	if not (vehicle and vehicle:IsA("Model") and vehicle.Parent == root and records[vehicle]) then return end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId then return end
	if not driverSeated(player, vehicle) then return end
	local ok, stateOrReason = Contract.Validate(payload)
	if not ok then return end
	local record = records[vehicle]
	if stateOrReason.Revision <= record.LastClientRevision then return end
	record.LastClientRevision = stateOrReason.Revision
	vehicle:SetAttribute("NTRAudioIgnition", stateOrReason.Ignition)
	vehicle:SetAttribute("NTRAudioDrive", stateOrReason.Drive)
	vehicle:SetAttribute("NTRAudioDrift", stateOrReason.Drift)
	vehicle:SetAttribute("NTRAudioBoost", stateOrReason.Boost)
	vehicle:SetAttribute("NTRAudioStateRevision", (tonumber(vehicle:GetAttribute("NTRAudioStateRevision")) or 0) + 1)
end)

root.ChildAdded:Connect(function(child) task.defer(register, child) end)
root.ChildRemoved:Connect(cleanup)
Players.PlayerRemoving:Connect(function(player) rate[player] = nil end)
for _, vehicle in ipairs(root:GetChildren()) do register(vehicle) end

print("[NTR Audio Phase 1] VehicleAudioStateService active.")
]=]

local AUDIO_RUNTIME_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE1_RUNTIME_CLIENT_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(kit.Shared.Modules.Client.Audio:WaitForChild("VehicleAudioController"))
	controller.Start()
	return controller
end)

if not ok then
	warn("[NTR Audio Phase 1] Runtime failed safely: " .. tostring(result))
end
]=]

for label, source in pairs({
	VehicleAudioStateContract = STATE_CONTRACT_SOURCE,
	AudioBusController = AUDIO_BUS_SOURCE,
	VehicleAudioCatalog = VEHICLE_CATALOG_SOURCE,
	VehicleAudioController = VEHICLE_AUDIO_CLIENT_SOURCE,
	VehicleAudioStateService = VEHICLE_AUDIO_SERVER_SOURCE,
	AudioRuntimeController = AUDIO_RUNTIME_SOURCE,
}) do
	compile(label, source)
end

local kit = assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"), "ReplicatedStorage.NeoTokyoRacers missing")
local shared = assert(kit:FindFirstChild("Shared"), "NeoTokyoRacers.Shared missing")
local modules = assert(shared:FindFirstChild("Modules"), "Shared.Modules missing")
local clientModules = assert(modules:FindFirstChild("Client"), "Shared.Modules.Client missing")
local commonModules = assert(modules:FindFirstChild("Common"), "Shared.Modules.Common missing")
local remotes = assert(shared:FindFirstChild("Remotes"), "Shared.Remotes missing")
local config = assert(kit:FindFirstChild("Config"), "NeoTokyoRacers.Config missing")
local clientRoot = assert(find(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient"), "NeoTokyoRacersClient missing")
local controllers = assert(clientRoot:FindFirstChild("Controllers"), "NeoTokyoRacersClient.Controllers missing")
local services = assert(find(ServerScriptService, "NeoTokyoRacers.Services"), "ServerScriptService.NeoTokyoRacers.Services missing")
local categories = assert(find(kit, "Assets.Vehicles.Categories"), "Vehicle Categories root missing")
local worldVehicles = assert(find(workspace, "NeoTokyoRacersWorld.Runtime.PlayerVehicles"), "Workspace runtime PlayerVehicles missing")
assert(worldVehicles:IsA("Folder"), "PlayerVehicles must be a Folder")

local driving = assert(find(clientModules, "Controllers.DrivingControllerV47"), "DrivingControllerV47 missing")
for _, marker in ipairs({ "V75", "NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE" }) do
	assert(string.find(driving.Source, marker, 1, true), "Current driving source marker missing: " .. marker)
end
for _, attributeName in ipairs({ "Accelerating", "Braking", "Boosting", "DriftingLeft", "DriftingRight" }) do
	assert(string.find(driving.Source, "SetAttribute(\"" .. attributeName .. "\"", 1, true), "Driving state output missing: " .. attributeName)
end

local existingMixer = assert(find(clientModules, "Audio.AudioMixController"), "Confirmed AudioMixController missing")
assert(hasMarker(existingMixer.Source, "NTR_LOADING_SYSTEM_PHASE1_AUDIO_MIXER_V1_1"), "Confirmed loading audio mixer marker missing")
compile("ConfirmedAudioMixController", existingMixer.Source)

for _, groupName in ipairs({ "NTR_LoadingMusic", "NTR_GameplayMusic", "NTR_Vehicle", "NTR_Ambience", "NTR_GameplaySFX", "NTR_UI" }) do
	local group = SoundService:FindFirstChild(groupName)
	assert(group and group:IsA("SoundGroup"), "Confirmed SoundService group missing: " .. groupName)
end

for _, className in ipairs({ "AudioPlayer", "AudioEmitter", "AudioListener", "AudioDeviceOutput", "AudioFader", "Wire" }) do
	local ok, object = pcall(Instance.new, className)
	assert(ok and object, "Current Studio does not support required modular audio class: " .. className)
	object:Destroy()
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

local function auditInstalled()
	local audioConfig = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio", "Folder")
	local global = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.Global", "Folder")
	installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.Quality", "Folder")
	local profiles = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.VehicleProfiles", "Folder")
	local fallback = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.VehicleProfiles.GENERIC_STANDARD_AUDIO", "Folder")
	assert(global:GetAttribute("SchemaVersion") == 1, "Audio schema version must be 1")
	assert(global:GetAttribute("FallbackProfileId") == "GENERIC_STANDARD_AUDIO", "Fallback profile mismatch")
	assert(audioConfig:GetAttribute("InstallerRevision") == REVISION, "Audio installer revision mismatch")
	assert(profiles:FindFirstChild(fallback.Name) == fallback, "Fallback profile parent mismatch")
	installedObject("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common.Audio.VehicleAudioStateContract", "ModuleScript", STATE_REVISION)
	installedObject("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.AudioBusController", "ModuleScript", BUS_REVISION)
	installedObject("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.VehicleAudioCatalog", "ModuleScript", CATALOG_REVISION)
	installedObject("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.VehicleAudioController", "ModuleScript", CLIENT_REVISION)
	installedObject("ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Audio.VehicleAudioState", "RemoteEvent")
	installedObject("ServerScriptService.NeoTokyoRacers.Services.Audio.VehicleAudioStateService_Active", "Script", SERVER_REVISION)
	installedObject("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.AudioRuntimeController_Active", "LocalScript", RUNTIME_REVISION)
	local cockpitCount = 0
	for _, item in ipairs(categories:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("CockpitId") ~= nil then
			cockpitCount += 1
			local profileId = tostring(item:GetAttribute("StandardAudioProfileId") or "")
			assert(profileId ~= "" and profiles:FindFirstChild(profileId), item:GetFullName() .. " has invalid StandardAudioProfileId")
		end
	end
	assert(cockpitCount > 0, "No cockpit templates found for Standard audio coverage")
	return global, fallback, cockpitCount
end

if MODE == "AUDIT" then
	local global, fallback, cockpitCount = auditInstalled()
	local audible = 0
	for _, attributeName in ipairs({ "IgnitionAssetId", "ShutdownAssetId", "IdleAssetId", "EngineLowAssetId", "EngineHighAssetId", "AccelerationAssetId", "CoastAssetId", "DriftEnterAssetId", "DriftLoopAssetId", "BoostEnterAssetId", "BoostLoopAssetId", "BoostReleaseAssetId", "DriverWindAssetId" }) do
		if tostring(fallback:GetAttribute(attributeName) or "") ~= "" then audible += 1 end
	end
	info(("AUDIT PASS: %d cockpit templates resolve Standard audio; %d/13 fallback assets populated; enabled=%s. No Studio objects changed."):format(cockpitCount, audible, tostring(global:GetAttribute("AudioSystemEnabled"))))
	return
end

if MODE == "DISABLE" then
	local global = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.Global", "Folder")
	global:SetAttribute("AudioSystemEnabled", false)
	info("DISABLE PASS: AudioSystemEnabled=false. Installed hierarchy and tuning were preserved.")
	return
end

assert(MODE == "INSTALL", "MODE must be INSTALL, AUDIT, or DISABLE")

local created = {}
local attributeSnapshots = {}
local sourceSnapshots = {}

local function writeSource(object, source, marker)
	if object.Source ~= "" then
		assert(hasMarker(object.Source, marker), object:GetFullName() .. " has unknown existing source")
	end
	local canDisable = object:IsA("Script") or object:IsA("LocalScript")
	table.insert(sourceSnapshots, { Object = object, Source = object.Source, Disabled = canDisable and object.Disabled or nil })
	object.Source = source
	if object:IsA("Script") or object:IsA("LocalScript") then object.Disabled = false end
end

local function rollback(problem)
	for index = #sourceSnapshots, 1, -1 do
		local snapshot = sourceSnapshots[index]
		pcall(function()
			snapshot.Object.Source = snapshot.Source
			if snapshot.Disabled ~= nil then snapshot.Object.Disabled = snapshot.Disabled end
		end)
	end
	for index = #attributeSnapshots, 1, -1 do
		local snapshot = attributeSnapshots[index]
		pcall(function()
			if snapshot.HadValue then snapshot.Object:SetAttribute(snapshot.Name, snapshot.Value)
			else snapshot.Object:SetAttribute(snapshot.Name, nil) end
		end)
	end
	for index = #created, 1, -1 do
		pcall(function() if created[index].Parent then created[index]:Destroy() end end)
	end
	error("[" .. PHASE .. "] rolled back: " .. tostring(problem), 0)
end

local ok, problem = xpcall(function()
	local audioConfig = ensureClass(config, "Audio", "Folder", created)
	local global = ensureClass(audioConfig, "Global", "Folder", created)
	local qualityConfig = ensureClass(audioConfig, "Quality", "Folder", created)
	local profiles = ensureClass(audioConfig, "VehicleProfiles", "Folder", created)
	local fallback = ensureClass(profiles, "GENERIC_STANDARD_AUDIO", "Folder", created)

	setDefaultAttribute(attributeSnapshots, audioConfig, "InstallerRevision", REVISION)
	if audioConfig:GetAttribute("InstallerRevision") ~= REVISION then
		snapshotAttribute(attributeSnapshots, audioConfig, "InstallerRevision")
		audioConfig:SetAttribute("InstallerRevision", REVISION)
	end
	for name, value in pairs({
		SchemaVersion = 1,
		AudioSystemEnabled = false,
		VehicleAudioEnabled = true,
		FallbackProfileId = "GENERIC_STANDARD_AUDIO",
		DebugAudio = false,
		ExternalMinDistanceStuds = 12,
		ExternalMaxDistanceStuds = 240,
		EngineHighFullSpeedMph = 120,
		LayerSmoothingPerSecond = 7,
		OneShotMaxLifetimeSeconds = 12,
		StateRateLimitPerSecond = 20,
	}) do setDefaultAttribute(attributeSnapshots, global, name, value) end
	for name, value in pairs({
		ParameterUpdateHz = 15,
		PriorityUpdateHz = 4,
		MaxDetailedRemoteVehicles = 6,
		MaxSimpleRemoteVehicles = 6,
		MaxConcurrentOneShotsPerVehicle = 8,
		AcousticSimulationEnabled = false,
	}) do setDefaultAttribute(attributeSnapshots, qualityConfig, name, value) end

	local layers = { "Ignition", "Shutdown", "Idle", "EngineLow", "EngineHigh", "Acceleration", "Coast", "DriftEnter", "DriftLoop", "BoostEnter", "BoostLoop", "BoostRelease", "DriverWind" }
	local gainDefaults = { Ignition=.85,Shutdown=.75,Idle=.34,EngineLow=.55,EngineHigh=.56,Acceleration=.48,Coast=.28,DriftEnter=.55,DriftLoop=.52,BoostEnter=.72,BoostLoop=.65,BoostRelease=.55,DriverWind=.38 }
	for _, layer in ipairs(layers) do
		setDefaultAttribute(attributeSnapshots, fallback, layer .. "AssetId", "")
		setDefaultAttribute(attributeSnapshots, fallback, layer .. "Gain", gainDefaults[layer] or .5)
		setDefaultAttribute(attributeSnapshots, fallback, layer .. "Pitch", 1)
	end
	setDefaultAttribute(attributeSnapshots, fallback, "DisplayName", "Generic Standard Vehicle Audio")
	setDefaultAttribute(attributeSnapshots, fallback, "ProfileRevision", 1)

	local commonAudio = ensureClass(commonModules, "Audio", "Folder", created)
	local clientAudio = ensureClass(clientModules, "Audio", "Folder", created)
	local audioRemotes = ensureClass(remotes, "Audio", "Folder", created)
	local audioServices = ensureClass(services, "Audio", "Folder", created)
	local audioControllers = ensureClass(controllers, "Audio", "Folder", created)

	local stateContract = ensureClass(commonAudio, "VehicleAudioStateContract", "ModuleScript", created)
	local bus = ensureClass(clientAudio, "AudioBusController", "ModuleScript", created)
	local catalog = ensureClass(clientAudio, "VehicleAudioCatalog", "ModuleScript", created)
	local vehicleController = ensureClass(clientAudio, "VehicleAudioController", "ModuleScript", created)
	ensureClass(audioRemotes, "VehicleAudioState", "RemoteEvent", created)
	local server = ensureClass(audioServices, "VehicleAudioStateService_Active", "Script", created)
	local runtime = ensureClass(audioControllers, "AudioRuntimeController_Active", "LocalScript", created)

	writeSource(stateContract, STATE_CONTRACT_SOURCE, STATE_REVISION)
	writeSource(bus, AUDIO_BUS_SOURCE, BUS_REVISION)
	writeSource(catalog, VEHICLE_CATALOG_SOURCE, CATALOG_REVISION)
	writeSource(vehicleController, VEHICLE_AUDIO_CLIENT_SOURCE, CLIENT_REVISION)
	writeSource(server, VEHICLE_AUDIO_SERVER_SOURCE, SERVER_REVISION)
	writeSource(runtime, AUDIO_RUNTIME_SOURCE, RUNTIME_REVISION)

	local cockpitCount = 0
	for _, item in ipairs(categories:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("CockpitId") ~= nil then
			cockpitCount += 1
			setDefaultAttribute(attributeSnapshots, item, "StandardAudioProfileId", "GENERIC_STANDARD_AUDIO")
		end
	end
	assert(cockpitCount > 0, "No cockpit templates found for Standard audio coverage")

	local installedGlobal, installedFallback, auditedCockpits = auditInstalled()
	assert(installedGlobal == global and installedFallback == fallback, "Final audio config identity mismatch")
	assert(auditedCockpits == cockpitCount, "Final cockpit coverage count changed")
end, debug.traceback)

if not ok then rollback(problem) end

local global, fallback, cockpitCount = auditInstalled()
local audible = 0
for _, attributeName in ipairs({ "IgnitionAssetId", "ShutdownAssetId", "IdleAssetId", "EngineLowAssetId", "EngineHighAssetId", "AccelerationAssetId", "CoastAssetId", "DriftEnterAssetId", "DriftLoopAssetId", "BoostEnterAssetId", "BoostLoopAssetId", "BoostReleaseAssetId", "DriverWindAssetId" }) do
	if tostring(fallback:GetAttribute(attributeName) or "") ~= "" then audible += 1 end
end

info(("INSTALL PASS: %s installed for %d cockpit templates."):format(REVISION, cockpitCount))
info(("Fallback profile assets populated: %d/13. AudioSystemEnabled remains %s by design."):format(audible, tostring(global:GetAttribute("AudioSystemEnabled"))))
info("Populate GENERIC_STANDARD_AUDIO AssetId attributes, then enable AudioSystemEnabled for Play verification.")
info("No driving, VFX, bootstrap, garage UI, persistence, economy, music, ambience, or world acoustic source was changed.")
