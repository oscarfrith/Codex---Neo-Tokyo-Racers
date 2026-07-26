-- Neo Tokyo Racers - Parked / Exit-Coasting External 3D Audio V1
-- Run in the Roblox Studio Edit-mode Command Bar.
-- Change MODE to "AUDIT" after INSTALL passes. "DISABLE" restores seat-exit silence.

local MODE = "INSTALL"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local REVISION = "NTR_AUDIO_PARKED_EXTERNAL_3D_V1"
local CLIENT_REVISION = "NTR_AUDIO_VEHICLE_CLIENT_V3_PARKED_EXTERNAL"
local SERVER_REVISION = "NTR_AUDIO_STATE_SERVICE_V3_PARKED_RUNNING"

local function child(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), ("Missing %s.%s (%s)"):format(parent:GetFullName(), name, className))
	return object
end

local kit = child(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local audio = child(child(kit, "Config", "Folder"), "Audio", "Folder")
local global = child(audio, "Global", "Folder")
local descriptions = child(global, "Descriptions", "Folder")
local shared = child(kit, "Shared", "Folder")
local modules = child(shared, "Modules", "Folder")
local clientModules = child(modules, "Client", "Folder")
local clientAudio = child(clientModules, "Audio", "Folder")
local controller = child(clientAudio, "VehicleAudioController", "ModuleScript")
local services = child(child(ServerScriptService, "NeoTokyoRacers", "Folder"), "Services", "Folder")
local audioServices = child(services, "Audio", "Folder")
local stateService = child(audioServices, "VehicleAudioStateService_Active", "Script")

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

local OLD_REFRESH_OCCUPANCY = [=[
local function refreshOccupancy(vehicle)
	local driverId = tonumber(vehicle:GetAttribute("DriverUserId"))
	local player = driverId and Players:GetPlayerByUserId(driverId)
	resetState(vehicle, player ~= nil and driverSeated(player, vehicle))
end
]=]

local NEW_REFRESH_OCCUPANCY = [=[
local function refreshOccupancy(vehicle)
	local driverId = tonumber(vehicle:GetAttribute("DriverUserId"))
	local player = driverId and Players:GetPlayerByUserId(driverId)
	local seated = player ~= nil and driverSeated(player, vehicle)
	-- Seat occupancy selects internal/external presentation; it no longer doubles as
	-- engine power. Runtime player vehicles stay audibly powered while parked/coasting.
	local keepRunning = seated or global:GetAttribute("ParkedVehicleAudioEnabled") ~= false
	resetState(vehicle, keepRunning)
end
]=]

local function projectService(source)
	if has(source, SERVER_REVISION) then return source end
	assert(has(source, "NTR_AUDIO_STATE_SERVICE_V2_CUES"), "Unknown VehicleAudioStateService baseline")
	assert(has(source, "NTR_VEHICLE_PRESENTATION_STATE_TRANSPORT_V1"), "Validated presentation transport marker missing")
	source = replaceOnce(source, "NTR_AUDIO_STATE_SERVICE_V2_CUES", SERVER_REVISION, "server revision")
	source = replaceOnce(source, OLD_REFRESH_OCCUPANCY, NEW_REFRESH_OCCUPANCY, "server occupancy/power boundary")
	source = replaceOnce(source,
		'root.ChildAdded:Connect(function(child) task.defer(register, child) end)',
		'global:GetAttributeChangedSignal("ParkedVehicleAudioEnabled"):Connect(function()\n\tfor vehicle in pairs(records) do refreshOccupancy(vehicle) end\nend)\nroot.ChildAdded:Connect(function(child) task.defer(register, child) end)',
		"server live parked-audio config refresh")
	return source
end

local OLD_TARGET_BLOCK = [=[
	local running = semantic.Ignition == "Running" or semantic.Ignition == "Starting"
	local accelerating = semantic.Drive == "Accelerating"
	local coasting = running and not accelerating and speedMph >= Catalog.GlobalNumber("CoastStartMph", 8)
	local drifting = semantic.Drift ~= "None"
	if drifting then state.DriftElapsed = (state.DriftElapsed or 0) + dt else state.DriftElapsed = 0 end
	local driftStart = Catalog.GlobalNumber("DriftLoopStartGainMultiplier", 0.15)
	local driftRamp = rangeAlpha(state.DriftElapsed, Catalog.GlobalNumber("DriftRampDelaySeconds", 0.1), Catalog.GlobalNumber("DriftRampFullSeconds", 2.5))
	driftRamp = driftRamp ^ Catalog.GlobalNumber("DriftRampCurveExponent", 1.3)
	local driftGainMultiplier = driftStart + (1 - driftStart) * driftRamp
	local gains = graph.Profile.Gains
	local mix = routeMultiplier(graph, false)
	setTarget(graph, "Idle", running and gains.Idle * (1 - idleAlpha * 0.75) * mix or 0)
	setTarget(graph, "EngineLow", running and gains.EngineLow * lowShape * mix or 0)
	setTarget(graph, "EngineHigh", running and gains.EngineHigh * highAlpha * mix or 0)
	setTarget(graph, "Acceleration", accelerating and gains.Acceleration * mix or 0)
	setTarget(graph, "Coast", coasting and gains.Coast * rangeAlpha(speedMph, Catalog.GlobalNumber("CoastStartMph", 8), Catalog.GlobalNumber("CoastFullGainMph", 50)) * mix or 0)
	setTarget(graph, "DriftLoop", drifting and gains.DriftLoop * driftGainMultiplier * mix or 0)
	setTarget(graph, "BoostLoop", boosting and gains.BoostLoop * mix or 0)
	setTarget(graph, "DriverWind", state.LocalDriver and gains.DriverWind * rangeAlpha(speedMph, Catalog.GlobalNumber("WindStartMph", 18), Catalog.GlobalNumber("WindFullGainMph", 128)) * mix or 0)
]=]

local NEW_TARGET_BLOCK = [=[
	local running = semantic.Ignition == "Running" or semantic.Ignition == "Starting"
	local accelerating = semantic.Drive == "Accelerating"
	local coasting = running and not accelerating and speedMph >= Catalog.GlobalNumber("CoastStartMph", 8)
	local drifting = semantic.Drift ~= "None"
	local seat = seatFor(state.Vehicle)
	local unoccupied = not (seat and seat.Occupant ~= nil)
	local exitedPresentation = running and unoccupied
	local parkedAudioEnabled = Catalog.GlobalBool("ParkedVehicleAudioEnabled", true)
	local exitCoasting = exitedPresentation and parkedAudioEnabled
		and Catalog.GlobalBool("ExitCoastAudioEnabled", true)
		and state.Vehicle:GetAttribute("NTR_ExitCoasting") == true
	local parked = exitedPresentation and parkedAudioEnabled and not exitCoasting
	if drifting then state.DriftElapsed = (state.DriftElapsed or 0) + dt else state.DriftElapsed = 0 end
	local driftStart = Catalog.GlobalNumber("DriftLoopStartGainMultiplier", 0.15)
	local driftRamp = rangeAlpha(state.DriftElapsed, Catalog.GlobalNumber("DriftRampDelaySeconds", 0.1), Catalog.GlobalNumber("DriftRampFullSeconds", 2.5))
	driftRamp = driftRamp ^ Catalog.GlobalNumber("DriftRampCurveExponent", 1.3)
	local driftGainMultiplier = driftStart + (1 - driftStart) * driftRamp
	local gains = graph.Profile.Gains
	local mix = routeMultiplier(graph, false)
	local coastAlpha = rangeAlpha(speedMph, Catalog.GlobalNumber("CoastStartMph", 8), Catalog.GlobalNumber("CoastFullGainMph", 50))
	local idleTarget = running and gains.Idle * (1 - idleAlpha * 0.75) * mix or 0
	local engineLowTarget = running and gains.EngineLow * lowShape * mix or 0
	local engineHighTarget = running and gains.EngineHigh * highAlpha * mix or 0
	local coastTarget = coasting and gains.Coast * coastAlpha * mix or 0
	if exitedPresentation and not parkedAudioEnabled then
		idleTarget, engineLowTarget, engineHighTarget, coastTarget = 0, 0, 0, 0
	elseif exitCoasting then
		local coastMix = Catalog.GlobalNumber("ExitCoastGainMultiplier", 1)
		idleTarget = gains.Idle * (1 - idleAlpha * 0.75) * Catalog.GlobalNumber("ExitCoastIdleGainMultiplier", 0.25) * coastMix * mix
		engineLowTarget = gains.EngineLow * lowShape * Catalog.GlobalNumber("ExitCoastEngineLowGainMultiplier", 0.45) * coastMix * mix
		engineHighTarget = Catalog.GlobalBool("ExitCoastSuppressEngineHigh", true) and 0 or (gains.EngineHigh * highAlpha * coastMix * mix)
		coastTarget = gains.Coast * coastAlpha * coastMix * mix
	elseif parked then
		idleTarget = gains.Idle * Catalog.GlobalNumber("ParkedIdleGainMultiplier", 0.75) * mix
		engineLowTarget = gains.EngineLow * Catalog.GlobalNumber("ParkedEngineLowGainMultiplier", 0.35) * mix
		engineHighTarget, coastTarget = 0, 0
	end
	setTarget(graph, "Idle", idleTarget)
	setTarget(graph, "EngineLow", engineLowTarget)
	setTarget(graph, "EngineHigh", engineHighTarget)
	setTarget(graph, "Acceleration", exitedPresentation and 0 or (accelerating and gains.Acceleration * mix or 0))
	setTarget(graph, "Coast", coastTarget)
	setTarget(graph, "DriftLoop", exitedPresentation and 0 or (drifting and gains.DriftLoop * driftGainMultiplier * mix or 0))
	setTarget(graph, "BoostLoop", exitedPresentation and 0 or (boosting and gains.BoostLoop * mix or 0))
	setTarget(graph, "DriverWind", state.LocalDriver and gains.DriverWind * rangeAlpha(speedMph, Catalog.GlobalNumber("WindStartMph", 18), Catalog.GlobalNumber("WindFullGainMph", 128)) * mix or 0)
]=]

local function projectController(source)
	if has(source, CLIENT_REVISION) then return source end
	assert(has(source, "NTR_AUDIO_VEHICLE_CLIENT_V2_TUNING_CUES"), "Unknown VehicleAudioController baseline")
	source = replaceOnce(source, "NTR_AUDIO_VEHICLE_CLIENT_V2_TUNING_CUES", CLIENT_REVISION, "client revision")
	source = replaceOnce(source, OLD_TARGET_BLOCK, NEW_TARGET_BLOCK, "parked/coasting target mix")
	source = replaceOnce(source,
		'\t\tlocal seconds = fadeSeconds(layerName, layer.Target > layer.Gain)',
		'\t\tlocal rising = layer.Target > layer.Gain\n\t\tlocal seconds = exitedPresentation and Catalog.GlobalNumber(rising and "ParkedFadeInSeconds" or "ParkedFadeOutSeconds", rising and 0.2 or 0.3) or fadeSeconds(layerName, rising)',
		"parked fade response")
	return source
end

local projected = {
	{ Object = stateService, Source = projectService(stateService.Source), Marker = SERVER_REVISION },
	{ Object = controller, Source = projectController(controller.Source), Marker = CLIENT_REVISION },
}
for _, item in ipairs(projected) do
	assert(has(item.Source, item.Marker), item.Marker .. " projection failed")
	compile(item.Object:GetFullName(), item.Source)
end

local defaults = {
	ParkedVehicleAudioEnabled = true,
	ParkedIdleGainMultiplier = 0.75,
	ParkedEngineLowGainMultiplier = 0.35,
	ParkedFadeInSeconds = 0.20,
	ParkedFadeOutSeconds = 0.30,
	ExitCoastAudioEnabled = true,
	ExitCoastGainMultiplier = 1.0,
	ExitCoastEngineLowGainMultiplier = 0.45,
	ExitCoastIdleGainMultiplier = 0.25,
	ExitCoastSuppressEngineHigh = true,
}

local help = {
	ParkedVehicleAudioEnabled = "Keeps unoccupied runtime player vehicles audibly powered through the existing external 3D route; false restores seat-exit silence.",
	ParkedIdleGainMultiplier = "Multiplier applied to the profile's IdleGain after an unoccupied vehicle has settled into its parked presentation.",
	ParkedEngineLowGainMultiplier = "Multiplier applied to the profile's EngineLowGain while an unoccupied vehicle is parked; EngineHigh and Coast are suppressed.",
	ParkedFadeInSeconds = "Response time used when an exited vehicle's parked/coasting loop targets rise after the graph switches to external 3D presentation.",
	ParkedFadeOutSeconds = "Response time used when an exited vehicle's parked/coasting loop targets fall or the parked-audio feature is disabled.",
	ExitCoastAudioEnabled = "Uses the server-owned NTR_ExitCoasting state to play a reduced idle/low-engine/coast mix until authoritative parking; false uses the parked idle mix immediately.",
	ExitCoastGainMultiplier = "Overall multiplier for the complete exit-coasting mix before the normal external-vehicle and profile master gains apply.",
	ExitCoastEngineLowGainMultiplier = "Additional multiplier for EngineLowGain while an exited vehicle is still coasting.",
	ExitCoastIdleGainMultiplier = "Additional multiplier for the speed-faded IdleGain while an exited vehicle is still coasting.",
	ExitCoastSuppressEngineHigh = "When true, removes the speed-driven EngineHigh loop after exit so the unloaded car uses only Coast, reduced EngineLow and reduced Idle.",
}

local preservedGlobal = global:GetAttributes()
local sourceSnapshots, attributeSnapshots, valueSnapshots, created = {}, {}, {}, {}

local function snapshotAttribute(object, name)
	table.insert(attributeSnapshots, { Object = object, Name = name, HadValue = object:GetAttribute(name) ~= nil, Value = object:GetAttribute(name) })
end

local function setDefaultAttribute(object, name, value)
	if object:GetAttribute(name) == nil then snapshotAttribute(object, name); object:SetAttribute(name, value) end
end

local function setDescription(name, value)
	local object = descriptions:FindFirstChild(name)
	if object then
		assert(object:IsA("StringValue"), object:GetFullName() .. " must be StringValue")
		table.insert(valueSnapshots, { Object = object, Value = object.Value })
	else
		object = Instance.new("StringValue")
		object.Name = name
		object.Parent = descriptions
		table.insert(created, object)
	end
	object.Value = value
end

local function assertPreserved()
	for name, value in pairs(preservedGlobal) do
		assert(global:GetAttribute(name) == value, "Existing audio attribute changed unexpectedly: " .. name)
	end
end

local function audit()
	assert(audio:GetAttribute("ParkedExternalAudioRevision") == REVISION, "Parked external-audio revision missing")
	for _, item in ipairs(projected) do
		assert(has(item.Object.Source, item.Marker), item.Object:GetFullName() .. " parked-audio marker missing")
	end
	for name in pairs(defaults) do
		assert(global:GetAttribute(name) ~= nil, "Parked-audio config missing: " .. name)
		child(descriptions, name, "StringValue")
	end
	print("[NTR Parked External 3D Audio V1] AUDIT PASS | existing profile/assets preserved | external graph reused")
end

if MODE == "AUDIT" then audit(); return end
assert(not RunService:IsRunning(), "Run INSTALL/DISABLE in Edit mode, not during Play")
if MODE == "DISABLE" then
	global:SetAttribute("ParkedVehicleAudioEnabled", false)
	print("[NTR Parked External 3D Audio V1] DISABLE PASS | seat-exit silence restored; config/assets retained")
	return
end
assert(MODE == "INSTALL", "MODE must be INSTALL, AUDIT, or DISABLE")

local ok, problem = pcall(function()
	for _, item in ipairs(projected) do
		if item.Object.Source ~= item.Source then
			table.insert(sourceSnapshots, { Object = item.Object, Source = item.Object.Source })
			item.Object.Source = item.Source
		end
	end
	snapshotAttribute(audio, "ParkedExternalAudioRevision")
	audio:SetAttribute("ParkedExternalAudioRevision", REVISION)
	for name, value in pairs(defaults) do setDefaultAttribute(global, name, value) end
	for name, value in pairs(help) do setDescription(name, value) end
	assertPreserved()
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
			if snapshot.HadValue then snapshot.Object:SetAttribute(snapshot.Name, snapshot.Value) else snapshot.Object:SetAttribute(snapshot.Name, nil) end
		end)
	end
	for index = #created, 1, -1 do
		local object = created[index]
		pcall(function() if object.Parent then object:Destroy() end end)
	end
	error("[NTR Parked External 3D Audio V1] INSTALL ROLLBACK: " .. tostring(problem))
end

print("[NTR Parked External 3D Audio V1] INSTALL PASS | unoccupied vehicles stay powered through bounded external 3D audio")
