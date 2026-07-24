-- Neo Tokyo Racers - Audio System Phase 3 Acoustics + Activation Readiness
-- Run this complete file in the Roblox Studio Command Bar in Edit mode.
--
-- Additive scope only: bounded native vehicle acoustics, context ambience
-- reverb, quality budgets, diagnostics, and a guarded future activation mode.
-- No wall emitters, manual occlusion raycasts, world geometry, driving, UI,
-- VFX, persistence, economy, or Phase 1/2 source is patched.
--
-- Modes: INSTALL, AUDIT, ACTIVATE, DISABLE

local MODE = "INSTALL"

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run Audio Phase 3 in Studio Edit mode.")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "NTR Audio System Phase 3 V1"
local REVISION = "NTR_AUDIO_SYSTEM_PHASE3_ACOUSTICS_ACTIVATION_V1"
local CONTROLLER_REVISION = "NTR_AUDIO_SYSTEM_PHASE3_ACOUSTICS_CONTROLLER_V1"
local RUNTIME_REVISION = "NTR_AUDIO_SYSTEM_PHASE3_ACOUSTICS_RUNTIME_V1"
local EFFECT_REVISION = "NTR_AUDIO_SYSTEM_PHASE3_CONTEXT_REVERB_V1"

local function info(message)
	print(("[%s] %s"):format(PHASE, tostring(message)))
end

local function find(root, path)
	local current = root
	for segment in string.gmatch(path, "[^.]+") do current = current and current:FindFirstChild(segment) end
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
	table.insert(snapshots, { Object=object, Name=name, HadValue=object:GetAttribute(name) ~= nil, Value=object:GetAttribute(name) })
end

local function setDefaultAttribute(snapshots, object, name, value)
	if object:GetAttribute(name) == nil then
		snapshotAttribute(snapshots, object, name)
		object:SetAttribute(name, value)
	end
end

local ACOUSTICS_CONTROLLER_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE3_ACOUSTICS_CONTROLLER_V1
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Controller = {}
local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audioConfig = kit.Config:WaitForChild("Audio")
local audioGlobal = audioConfig:WaitForChild("Global")
local acoustics = audioConfig:WaitForChild("Acoustics")
local contextConfig = audioConfig.Context:WaitForChild("Contexts")
local contextController = require(kit.Shared.Modules.Client.Audio:WaitForChild("ContextAudioController"))
local ambienceGroup = SoundService:WaitForChild("NTR_Ambience")
local reverb = ambienceGroup:WaitForChild("NTR_ContextAmbienceReverb")

local emitters = setmetatable({}, { __mode = "k" })
local originalEmitterState = setmetatable({}, { __mode = "k" })
local originalListenerState = setmetatable({}, { __mode = "k" })
local connections = {}
local heartbeatConnection = nil
local runtimeRoot = nil
local elapsed = 0
local started = false
local originalGlobalAcoustics = false
local globalWasApplied = false
local lastSelectedCount = -1
local lastContextId = nil

local function debugLog(message)
	if acoustics:GetAttribute("DebugAcoustics") == true then print("[NTR Audio Phase 3] " .. tostring(message)) end
end

local function masterEnabled()
	return audioGlobal:GetAttribute("AudioSystemEnabled") == true
		and acoustics:GetAttribute("AcousticsEnabled") == true
end

local function property(object, name, value)
	local readOk, current = pcall(function() return object[name] end)
	if readOk and current == value then return true end
	return pcall(function() object[name] = value end)
end

local function registerEmitter(object)
	if object:IsA("AudioEmitter") and object.Name == "NTR_VehicleAudioEmitter_Runtime" then
		emitters[object] = true
		if originalEmitterState[object] == nil then
			local ok, value = pcall(function() return object.AcousticSimulationEnabled end)
			originalEmitterState[object] = ok and value or false
		end
	end
end

local function unregisterEmitter(object)
	if not emitters[object] then return end
	local original = originalEmitterState[object]
	if object.Parent and original ~= nil then property(object, "AcousticSimulationEnabled", original) end
	emitters[object] = nil
	originalEmitterState[object] = nil
end

local function listener()
	local camera = Workspace.CurrentCamera
	return camera and camera:FindFirstChildWhichIsA("AudioListener", true) or nil
end

local function setListenerEnabled(value)
	local item = listener()
	if not item then return false end
	local stale = {}
	for previous in pairs(originalListenerState) do
		if previous ~= item then table.insert(stale, previous) end
	end
	for _, previous in ipairs(stale) do
		local original = originalListenerState[previous]
		if previous.Parent then property(previous, "AcousticSimulationEnabled", original == true) end
		originalListenerState[previous] = nil
	end
	if originalListenerState[item] == nil then
		local ok, original = pcall(function() return item.AcousticSimulationEnabled end)
		originalListenerState[item] = ok and original or false
	end
	return property(item, "AcousticSimulationEnabled", value)
end

local function restoreListeners()
	for item, original in pairs(originalListenerState) do
		if item.Parent then property(item, "AcousticSimulationEnabled", original) end
		originalListenerState[item] = nil
	end
end

local function setGlobalEnabled(value)
	if value then
		if property(SoundService, "AcousticSimulationEnabled", true) then globalWasApplied = true end
	elseif globalWasApplied then
		property(SoundService, "AcousticSimulationEnabled", originalGlobalAcoustics)
		globalWasApplied = false
	end
end

local function cameraPosition()
	local camera = Workspace.CurrentCamera
	return camera and camera.CFrame.Position or Vector3.zero
end

local function emitterPosition(emitter)
	local parent = emitter.Parent
	if parent and parent:IsA("BasePart") then return parent.Position end
	if parent and parent:IsA("Attachment") then return parent.WorldPosition end
	if parent and parent:IsA("Model") then return parent:GetPivot().Position end
	return nil
end

local function mobileBudget()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) < 800
end

local function applyNativeAcoustics()
	local active = masterEnabled() and acoustics:GetAttribute("NativeVehicleAcousticsEnabled") == true
	if not active then
		for emitter in pairs(emitters) do
			if emitter.Parent then property(emitter, "AcousticSimulationEnabled", originalEmitterState[emitter] == true) end
		end
		restoreListeners()
		setGlobalEnabled(false)
		if lastSelectedCount ~= 0 then lastSelectedCount = 0; debugLog("native emitters=0") end
		return
	end
	setGlobalEnabled(true)
	if not setListenerEnabled(true) then
		debugLog("AudioListener unavailable; native acoustics waiting")
		return
	end
	local rows = {}
	local origin = cameraPosition()
	local maxDistance = math.max(1, tonumber(acoustics:GetAttribute("NativeAcousticsMaxDistanceStuds")) or 180)
	for emitter in pairs(emitters) do
		if not emitter.Parent then
			emitters[emitter] = nil
		else
			local position = emitterPosition(emitter)
			local distance = position and (position - origin).Magnitude or math.huge
			table.insert(rows, { Emitter=emitter, Distance=distance })
		end
	end
	table.sort(rows, function(a, b) return a.Distance < b.Distance end)
	local capName = mobileBudget() and "MaxNativeAcousticEmittersMobile" or "MaxNativeAcousticEmittersDesktop"
	local cap = math.max(0, math.floor(tonumber(acoustics:GetAttribute(capName)) or (mobileBudget() and 2 or 4)))
	local selected = 0
	for index, row in ipairs(rows) do
		local wanted = index <= cap and row.Distance <= maxDistance
		property(row.Emitter, "AcousticSimulationEnabled", wanted)
		if wanted then selected += 1 end
	end
	if selected ~= lastSelectedCount then lastSelectedCount = selected; debugLog("native emitters=" .. selected) end
end

local function applyContextReverb()
	local state = contextController.State()
	local contextId = state and state.ContextId or nil
	local definition = contextId and contextConfig:FindFirstChild(contextId) or nil
	local active = masterEnabled() and acoustics:GetAttribute("ContextAmbienceReverbEnabled") == true
		and definition ~= nil and definition:GetAttribute("ReverbEnabled") == true
	if not active then
		property(reverb, "Enabled", false)
		if lastContextId ~= nil then lastContextId = nil; debugLog("context reverb=off") end
		return
	end
	property(reverb, "DecayTime", math.clamp(tonumber(definition:GetAttribute("ReverbDecayTime")) or 1.5, 0.1, 20))
	property(reverb, "Density", math.clamp(tonumber(definition:GetAttribute("ReverbDensity")) or 0.8, 0, 1))
	property(reverb, "Diffusion", math.clamp(tonumber(definition:GetAttribute("ReverbDiffusion")) or 0.9, 0, 1))
	property(reverb, "DryLevel", math.clamp(tonumber(definition:GetAttribute("ReverbDryLevel")) or 0, -80, 10))
	property(reverb, "WetLevel", math.clamp(tonumber(definition:GetAttribute("ReverbWetLevel")) or -12, -80, 10))
	property(reverb, "Enabled", true)
	if lastContextId ~= contextId then lastContextId = contextId; debugLog("context reverb=" .. contextId) end
end

local function update()
	applyNativeAcoustics()
	applyContextReverb()
end

function Controller.Start()
	if started then return Controller end
	started = true
	local ok, current = pcall(function() return SoundService.AcousticSimulationEnabled end)
	originalGlobalAcoustics = ok and current or false
	runtimeRoot = SoundService:FindFirstChild("NTR_AcousticsRuntime_Local")
	if runtimeRoot then runtimeRoot:Destroy() end
	runtimeRoot = Instance.new("Folder")
	runtimeRoot.Name = "NTR_AcousticsRuntime_Local"
	runtimeRoot.Parent = SoundService
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local vehicles = world and world:FindFirstChild("Runtime") and world.Runtime:FindFirstChild("PlayerVehicles")
	if vehicles then
		for _, object in ipairs(vehicles:GetDescendants()) do registerEmitter(object) end
		table.insert(connections, vehicles.DescendantAdded:Connect(registerEmitter))
		table.insert(connections, vehicles.DescendantRemoving:Connect(unregisterEmitter))
	else
		warn("[NTR Audio Phase 3] PlayerVehicles missing; vehicle acoustics inactive.")
	end
	for _, attributeName in ipairs({ "AudioSystemEnabled" }) do
		table.insert(connections, audioGlobal:GetAttributeChangedSignal(attributeName):Connect(update))
	end
	for _, attributeName in ipairs({ "AcousticsEnabled", "NativeVehicleAcousticsEnabled", "ContextAmbienceReverbEnabled" }) do
		table.insert(connections, acoustics:GetAttributeChangedSignal(attributeName):Connect(update))
	end
	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local interval = 1 / math.max(0.5, tonumber(acoustics:GetAttribute("AcousticsUpdateHz")) or 2)
		if elapsed >= interval then elapsed = 0; update() end
	end)
	update()
	debugLog("AcousticsController started")
	return Controller
end

function Controller.Stop()
	if not started then return end
	started = false
	if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	for emitter, original in pairs(originalEmitterState) do
		if emitter.Parent then property(emitter, "AcousticSimulationEnabled", original) end
	end
	table.clear(emitters)
	table.clear(originalEmitterState)
	restoreListeners()
	setGlobalEnabled(false)
	property(reverb, "Enabled", false)
	if runtimeRoot and runtimeRoot.Parent then runtimeRoot:Destroy() end
	runtimeRoot = nil
end

function Controller.State()
	local emitterCount = 0
	for _ in pairs(emitters) do emitterCount += 1 end
	return { RegisteredEmitters=emitterCount, NativeSelected=math.max(0, lastSelectedCount), ReverbContext=lastContextId }
end

return Controller
]=]

local ACOUSTICS_RUNTIME_SOURCE = [=[
-- NTR_AUDIO_SYSTEM_PHASE3_ACOUSTICS_RUNTIME_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local controller = require(kit.Shared.Modules.Client.Audio:WaitForChild("AcousticsController"))
	controller.Start()
	return controller
end)

if not ok then warn("[NTR Audio Phase 3] Acoustics runtime failed safely: " .. tostring(result)) end
]=]

compile("AcousticsController", ACOUSTICS_CONTROLLER_SOURCE)
compile("AcousticsRuntime", ACOUSTICS_RUNTIME_SOURCE)

local kit = assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"), "ReplicatedStorage.NeoTokyoRacers missing")
local audioConfig = assert(find(kit, "Config.Audio"), "Audio config missing")
local audioGlobal = assert(audioConfig:FindFirstChild("Global"), "Audio.Global missing")
local vehicleProfiles = assert(audioConfig:FindFirstChild("VehicleProfiles"), "VehicleProfiles missing")
local context = assert(audioConfig:FindFirstChild("Context"), "Phase 2 Context config missing")
local contextGlobal = assert(context:FindFirstChild("Global"), "Phase 2 Context.Global missing")
local contextDefinitions = assert(context:FindFirstChild("Contexts"), "Phase 2 Contexts missing")
assert(audioConfig:GetAttribute("InstallerRevision") == "NTR_AUDIO_SYSTEM_PHASE1_STANDARD_VEHICLE_AUDIO_V1", "Confirmed Phase 1 revision missing")
assert(context:GetAttribute("InstallerRevision") == "NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_MUSIC_AMBIENCE_V1", "Confirmed Phase 2 revision missing")

local clientAudio = assert(find(kit, "Shared.Modules.Client.Audio"), "Client Audio modules missing")
for name, marker in pairs({
	VehicleAudioController = "NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CLIENT_V1",
	ContextAudioController = "NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CONTROLLER_V1",
}) do
	local module = assert(clientAudio:FindFirstChild(name), name .. " missing")
	assert(hasMarker(module.Source, marker), name .. " confirmed marker missing")
	compile("Confirmed" .. name, module.Source)
end

local controllers = assert(find(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio"), "Client Audio controllers missing")
local ambienceGroup = assert(SoundService:FindFirstChild("NTR_Ambience"), "NTR_Ambience missing")
assert(ambienceGroup:IsA("SoundGroup"), "NTR_Ambience must be SoundGroup")

do
	local emitter = Instance.new("AudioEmitter")
	local listener = Instance.new("AudioListener")
	local emitterOk = pcall(function() emitter.AcousticSimulationEnabled = false end)
	local listenerOk = pcall(function() listener.AcousticSimulationEnabled = false end)
	local globalOk = pcall(function() SoundService.AcousticSimulationEnabled = SoundService.AcousticSimulationEnabled end)
	emitter:Destroy(); listener:Destroy()
	assert(emitterOk and listenerOk and globalOk, "Current Studio lacks required native acoustic simulation properties")
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

local function populatedCounts()
	local vehicleAssets = 0
	local critical = 0
	local fallbackId = tostring(audioGlobal:GetAttribute("FallbackProfileId") or "GENERIC_STANDARD_AUDIO")
	local fallback = vehicleProfiles:FindFirstChild(fallbackId)
	if fallback then
		for _, layer in ipairs({ "Ignition", "Shutdown", "Idle", "EngineLow", "EngineHigh", "Acceleration", "Coast", "DriftEnter", "DriftLoop", "BoostEnter", "BoostLoop", "BoostRelease", "DriverWind" }) do
			local filled = tostring(fallback:GetAttribute(layer .. "AssetId") or "") ~= ""
			if filled then vehicleAssets += 1 end
			if filled and (layer == "Ignition" or layer == "Idle" or layer == "EngineLow" or layer == "Acceleration" or layer == "Coast") then critical += 1 end
		end
	end
	local populatedContexts = 0
	local tracks = 0
	for _, definition in ipairs(contextDefinitions:GetChildren()) do
		local contextTracks = 0
		for _, descendant in ipairs(definition:GetDescendants()) do
			if descendant:IsA("StringValue") and descendant.Value ~= "" then contextTracks += 1; tracks += 1 end
		end
		if contextTracks > 0 then populatedContexts += 1 end
	end
	return vehicleAssets, critical, populatedContexts, tracks
end

local function auditInstalled()
	local acoustics = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.Acoustics", "Folder")
	assert(acoustics:GetAttribute("InstallerRevision") == REVISION, "Phase 3 installer revision mismatch")
	assert(acoustics:GetAttribute("SchemaVersion") == 1, "Phase 3 schema must be 1")
	installedObject("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Audio.AcousticsController", "ModuleScript", CONTROLLER_REVISION)
	installedObject("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Audio.AcousticsRuntimeController_Active", "LocalScript", RUNTIME_REVISION)
	local effect = installedObject("SoundService.NTR_Ambience.NTR_ContextAmbienceReverb", "ReverbSoundEffect")
	assert(effect:GetAttribute("NTRAudioOwnerRevision") == EFFECT_REVISION, "Context reverb ownership marker mismatch")
	for contextId, enabled in pairs({ FREE_ROAM_ON_FOOT=false, FREE_ROAM_DRIVING=false, DEALERSHIP_INTERIOR=true, OWNED_GARAGE_INTERIOR=true }) do
		local definition = contextDefinitions:FindFirstChild(contextId)
		assert(definition and definition:GetAttribute("ReverbEnabled") == enabled, contextId .. " reverb default mismatch")
	end
	return acoustics, effect
end

if MODE == "AUDIT" then
	local acoustics = auditInstalled()
	local vehicleAssets, critical, populatedContexts, tracks = populatedCounts()
	info(("AUDIT PASS: vehicle assets=%d/13 critical=%d/5; populated contexts=%d/4 tracks=%d; acoustics=%s audio=%s. No Studio objects changed."):format(vehicleAssets, critical, populatedContexts, tracks, tostring(acoustics:GetAttribute("AcousticsEnabled")), tostring(audioGlobal:GetAttribute("AudioSystemEnabled"))))
	return
end

if MODE == "ACTIVATE" then
	local acoustics = auditInstalled()
	local vehicleAssets, critical, populatedContexts, tracks = populatedCounts()
	local minimumVehicle = math.max(1, math.floor(tonumber(acoustics:GetAttribute("MinimumVehicleAssetsForActivation")) or 5))
	local minimumCritical = math.max(1, math.floor(tonumber(acoustics:GetAttribute("MinimumCriticalVehicleAssetsForActivation")) or 5))
	local minimumContexts = math.max(1, math.floor(tonumber(acoustics:GetAttribute("MinimumPopulatedContextsForActivation")) or 2))
	assert(vehicleAssets >= minimumVehicle, ("Activation blocked: vehicle assets %d/%d"):format(vehicleAssets, minimumVehicle))
	assert(critical >= minimumCritical, ("Activation blocked: critical vehicle assets %d/%d"):format(critical, minimumCritical))
	assert(populatedContexts >= minimumContexts, ("Activation blocked: populated contexts %d/%d"):format(populatedContexts, minimumContexts))
	local previous = {
		Audio = audioGlobal:GetAttribute("AudioSystemEnabled"),
		Context = contextGlobal:GetAttribute("ContextAudioEnabled"),
		Acoustics = acoustics:GetAttribute("AcousticsEnabled"),
	}
	local ok, problem = pcall(function()
		audioGlobal:SetAttribute("AudioSystemEnabled", true)
		contextGlobal:SetAttribute("ContextAudioEnabled", tracks > 0)
		acoustics:SetAttribute("AcousticsEnabled", true)
	end)
	if not ok then
		pcall(function()
			audioGlobal:SetAttribute("AudioSystemEnabled", previous.Audio)
			contextGlobal:SetAttribute("ContextAudioEnabled", previous.Context)
			acoustics:SetAttribute("AcousticsEnabled", previous.Acoustics)
		end)
		error("Activation rolled back: " .. tostring(problem), 0)
	end
	info(("ACTIVATE PASS: audio enabled with %d vehicle assets and %d tracks across %d contexts."):format(vehicleAssets, tracks, populatedContexts))
	return
end

if MODE == "DISABLE" then
	local acoustics = installedObject("ReplicatedStorage.NeoTokyoRacers.Config.Audio.Acoustics", "Folder")
	audioGlobal:SetAttribute("AudioSystemEnabled", false)
	contextGlobal:SetAttribute("ContextAudioEnabled", false)
	acoustics:SetAttribute("AcousticsEnabled", false)
	info("DISABLE PASS: vehicle, context, and acoustic playback disabled; definitions and assets preserved.")
	return
end

assert(MODE == "INSTALL", "MODE must be INSTALL, AUDIT, ACTIVATE, or DISABLE")

local created = {}
local attributes = {}
local properties = {}
local sources = {}

local function setProperty(object, name, value)
	table.insert(properties, { Object=object, Name=name, Value=object[name] })
	object[name] = value
end

local function writeSource(object, source, marker)
	if object.Source ~= "" then assert(hasMarker(object.Source, marker), object:GetFullName() .. " has unknown existing source") end
	local canDisable = object:IsA("Script") or object:IsA("LocalScript")
	table.insert(sources, { Object=object, Source=object.Source, Disabled=canDisable and object.Disabled or nil })
	object.Source = source
	if canDisable then object.Disabled = false end
end

local function rollback(problem)
	for index = #sources, 1, -1 do
		local snapshot = sources[index]
		pcall(function() snapshot.Object.Source=snapshot.Source; if snapshot.Disabled ~= nil then snapshot.Object.Disabled=snapshot.Disabled end end)
	end
	for index = #properties, 1, -1 do
		local snapshot = properties[index]
		pcall(function() snapshot.Object[snapshot.Name]=snapshot.Value end)
	end
	for index = #attributes, 1, -1 do
		local snapshot = attributes[index]
		pcall(function() if snapshot.HadValue then snapshot.Object:SetAttribute(snapshot.Name,snapshot.Value) else snapshot.Object:SetAttribute(snapshot.Name,nil) end end)
	end
	for index = #created, 1, -1 do pcall(function() if created[index].Parent then created[index]:Destroy() end end) end
	error("[" .. PHASE .. "] rolled back: " .. tostring(problem), 0)
end

local ok, problem = xpcall(function()
	local acoustics = ensureClass(audioConfig, "Acoustics", "Folder", created)
	setDefaultAttribute(attributes, acoustics, "InstallerRevision", REVISION)
	if acoustics:GetAttribute("InstallerRevision") ~= REVISION then
		snapshotAttribute(attributes, acoustics, "InstallerRevision")
		acoustics:SetAttribute("InstallerRevision", REVISION)
	end
	for name, value in pairs({
		SchemaVersion = 1,
		AcousticsEnabled = false,
		NativeVehicleAcousticsEnabled = true,
		ContextAmbienceReverbEnabled = true,
		AcousticsUpdateHz = 2,
		MaxNativeAcousticEmittersDesktop = 4,
		MaxNativeAcousticEmittersMobile = 2,
		NativeAcousticsMaxDistanceStuds = 180,
		MinimumVehicleAssetsForActivation = 5,
		MinimumCriticalVehicleAssetsForActivation = 5,
		MinimumPopulatedContextsForActivation = 2,
		DebugAcoustics = false,
	}) do setDefaultAttribute(attributes, acoustics, name, value) end

	for contextId, reverbEnabled in pairs({ FREE_ROAM_ON_FOOT=false, FREE_ROAM_DRIVING=false, DEALERSHIP_INTERIOR=true, OWNED_GARAGE_INTERIOR=true }) do
		local definition = assert(contextDefinitions:FindFirstChild(contextId), "Missing context " .. contextId)
		setDefaultAttribute(attributes, definition, "ReverbEnabled", reverbEnabled)
		setDefaultAttribute(attributes, definition, "ReverbDecayTime", contextId == "OWNED_GARAGE_INTERIOR" and 1.8 or 1.35)
		setDefaultAttribute(attributes, definition, "ReverbDensity", 0.82)
		setDefaultAttribute(attributes, definition, "ReverbDiffusion", 0.9)
		setDefaultAttribute(attributes, definition, "ReverbDryLevel", 0)
		setDefaultAttribute(attributes, definition, "ReverbWetLevel", contextId == "OWNED_GARAGE_INTERIOR" and -10 or -13)
	end

	local effect = ambienceGroup:FindFirstChild("NTR_ContextAmbienceReverb")
	if effect then
		assert(effect:IsA("ReverbSoundEffect"), effect:GetFullName() .. " must be ReverbSoundEffect")
		assert(effect:GetAttribute("NTRAudioOwnerRevision") == EFFECT_REVISION, effect:GetFullName() .. " has unknown ownership")
	else
		effect = ensureClass(ambienceGroup, "NTR_ContextAmbienceReverb", "ReverbSoundEffect", created)
	end
	setDefaultAttribute(attributes, effect, "NTRAudioOwnerRevision", EFFECT_REVISION)
	setProperty(effect, "Enabled", false)
	setProperty(effect, "Priority", 10)
	setProperty(effect, "DecayTime", 1.5)
	setProperty(effect, "Density", 0.82)
	setProperty(effect, "Diffusion", 0.9)
	setProperty(effect, "DryLevel", 0)
	setProperty(effect, "WetLevel", -12)

	local controller = ensureClass(clientAudio, "AcousticsController", "ModuleScript", created)
	local runtime = ensureClass(controllers, "AcousticsRuntimeController_Active", "LocalScript", created)
	writeSource(controller, ACOUSTICS_CONTROLLER_SOURCE, CONTROLLER_REVISION)
	writeSource(runtime, ACOUSTICS_RUNTIME_SOURCE, RUNTIME_REVISION)
	auditInstalled()
end, debug.traceback)

if not ok then rollback(problem) end

local acoustics = auditInstalled()
local vehicleAssets, critical, populatedContexts, tracks = populatedCounts()
info("INSTALL PASS: bounded native acoustics, context reverb, and activation readiness installed.")
info(("Readiness: vehicle assets=%d/13 critical=%d/5; populated contexts=%d/4 tracks=%d."):format(vehicleAssets, critical, populatedContexts, tracks))
info(("AudioSystemEnabled=%s AcousticsEnabled=%s. ACTIVATE will hard-stop until configured readiness thresholds pass."):format(tostring(audioGlobal:GetAttribute("AudioSystemEnabled")), tostring(acoustics:GetAttribute("AcousticsEnabled"))))
info("No Phase 1/2 source, wall emitter, manual raycast, world geometry, driving, UI, VFX, persistence, or economy owner changed.")
