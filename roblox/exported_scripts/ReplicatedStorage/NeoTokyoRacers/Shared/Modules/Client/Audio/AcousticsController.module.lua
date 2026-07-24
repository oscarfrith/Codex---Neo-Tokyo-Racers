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
