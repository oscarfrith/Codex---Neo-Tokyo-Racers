-- Neo Tokyo Racers - Vehicle Audio Tuning + Cues V1
-- Run in the Roblox Studio Edit-mode Command Bar.
-- Change MODE to "AUDIT" after INSTALL passes. "DISABLE" suppresses only this expansion.

local MODE = "INSTALL"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local REVISION = "NTR_AUDIO_VEHICLE_TUNING_CUES_V1"
local CATALOG_REVISION = "NTR_AUDIO_VEHICLE_CATALOG_V2_TUNING_CUES"
local CLIENT_REVISION = "NTR_AUDIO_VEHICLE_CLIENT_V2_TUNING_CUES"
local CONTRACT_REVISION = "NTR_AUDIO_STATE_CONTRACT_V2_CUES"
local SERVER_REVISION = "NTR_AUDIO_STATE_SERVICE_V2_CUES"

local function child(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), ("Missing %s.%s (%s)"):format(parent:GetFullName(), name, className))
	return object
end

local kit = child(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local config = child(kit, "Config", "Folder")
local audio = child(config, "Audio", "Folder")
local global = child(audio, "Global", "Folder")
local quality = child(audio, "Quality", "Folder")
local profiles = child(audio, "VehicleProfiles", "Folder")
local profile = child(profiles, "GENERIC_STANDARD_AUDIO", "Folder")
local shared = child(kit, "Shared", "Folder")
local modules = child(shared, "Modules", "Folder")
local common = child(modules, "Common", "Folder")
local commonAudio = child(common, "Audio", "Folder")
local client = child(modules, "Client", "Folder")
local clientAudio = child(client, "Audio", "Folder")
local catalog = child(clientAudio, "VehicleAudioCatalog", "ModuleScript")
local controller = child(clientAudio, "VehicleAudioController", "ModuleScript")
local contract = child(commonAudio, "VehicleAudioStateContract", "ModuleScript")
local services = child(child(ServerScriptService, "NeoTokyoRacers", "Folder"), "Services", "Folder")
local audioServices = child(services, "Audio", "Folder")
local stateService = child(audioServices, "VehicleAudioStateService_Active", "Script")
local mobileState = child(child(client, "Controllers", "Folder"), "MobileDriveInputState", "ModuleScript")
local starterClient = child(child(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder")
local runtime = child(child(child(starterClient, "Controllers", "Folder"), "Audio", "Folder"), "AudioRuntimeController_Active", "LocalScript")

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

local function projectCatalog(source)
	if has(source, CATALOG_REVISION) then return source end
	assert(has(source, "NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CATALOG_V1"), "Unknown VehicleAudioCatalog baseline")
	source = replaceOnce(source, "NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CATALOG_V1", CATALOG_REVISION, "catalog revision")
	source = replaceOnce(source,
		'Catalog.OneShotLayers = { "Ignition", "Shutdown", "DriftEnter", "BoostEnter", "BoostRelease" }',
		'Catalog.OneShotLayers = { "Ignition", "Shutdown", "AccelerationEnter", "AccelerationRelease", "DriftEnter", "BoostEnter", "BoostRelease", "BoostRecharge", "BoostEmpty", "FullBoostSpent" }',
		"catalog one-shot layers")
	source = replaceOnce(source,
		'\tShutdown = 0.75,\n\tIdle = 0.34,',
		'\tShutdown = 0.75,\n\tAccelerationEnter = 0.55,\n\tAccelerationRelease = 0.45,\n\tIdle = 0.34,',
		"catalog acceleration gains")
	source = replaceOnce(source,
		'\tBoostRelease = 0.55,\n\tDriverWind = 0.38,',
		'\tBoostRelease = 0.55,\n\tBoostRecharge = 0.45,\n\tBoostEmpty = 0.65,\n\tFullBoostSpent = 0.85,\n\tDriverWind = 0.38,',
		"catalog boost gains")
	source = replaceOnce(source,
		'local profile = { Id = folder.Name, Folder = folder, Assets = {}, Gains = {}, Pitches = {} }',
		'local profile = { Id = folder.Name, Folder = folder, Assets = {}, Gains = {}, Pitches = {}, MasterGain = math.clamp(tonumber(folder:GetAttribute("ProfileMasterGain")) or 1, 0, 3) }',
		"catalog profile master gain")
	return source
end

local function projectContract(source)
	if has(source, CONTRACT_REVISION) then return source end
	assert(has(source, "NTR_AUDIO_SYSTEM_PHASE1_STATE_CONTRACT_V1"), "Unknown VehicleAudioStateContract baseline")
	source = replaceOnce(source, "NTR_AUDIO_SYSTEM_PHASE1_STATE_CONTRACT_V1", CONTRACT_REVISION, "contract revision")
	source = replaceOnce(source,
		'}\n\nContract.Defaults = {',
		'}\n\nContract.Cues = { AccelerationEnter = true, AccelerationRelease = true, BoostEmpty = true, FullBoostSpent = true }\n\nContract.Defaults = {',
		"contract cue enum")
	source = replaceOnce(source,
		'\tresult.Revision = revision\n\treturn true, result',
		'\tresult.Revision = revision\n\tlocal cue = tostring(payload.Cue or "")\n\tif cue ~= "" and not Contract.Cues[cue] then return false, "InvalidCue" end\n\tresult.Cue = cue\n\treturn true, result',
		"contract cue validation")
	return source
end

local function projectService(source)
	if has(source, SERVER_REVISION) then return source end
	assert(has(source, "NTR_AUDIO_SYSTEM_PHASE1_STATE_SERVICE_V1"), "Unknown VehicleAudioStateService baseline")
	source = replaceOnce(source, "NTR_AUDIO_SYSTEM_PHASE1_STATE_SERVICE_V1", SERVER_REVISION, "service revision")
	source = replaceOnce(source,
		'\tvehicle:SetAttribute("NTRAudioBoost", "Off")\n\tvehicle:SetAttribute("NTRAudioStateRevision",',
		'\tvehicle:SetAttribute("NTRAudioBoost", "Off")\n\tvehicle:SetAttribute("NTRAudioCue", "")\n\tvehicle:SetAttribute("NTRAudioStateRevision",',
		"service cue reset")
	source = replaceOnce(source,
		'\tvehicle:SetAttribute("NTRAudioBoost", stateOrReason.Boost)\n\tvehicle:SetAttribute("NTRAudioStateRevision",',
		'\tvehicle:SetAttribute("NTRAudioBoost", stateOrReason.Boost)\n\tif stateOrReason.Cue ~= "" then\n\t\tvehicle:SetAttribute("NTRAudioCue", stateOrReason.Cue)\n\t\tvehicle:SetAttribute("NTRAudioCueRevision", (tonumber(vehicle:GetAttribute("NTRAudioCueRevision")) or 0) + 1)\n\tend\n\tvehicle:SetAttribute("NTRAudioStateRevision",',
		"service cue replication")
	return source
end

local NEW_ONESHOT_FUNCTIONS = [=[
local function routeMultiplier(graph, oneShot)
	local routeGain = graph.Route == "Internal" and Catalog.GlobalNumber("LocalDriverGain", 1) or Catalog.GlobalNumber("ExternalVehicleGain", 0.9)
	local oneShotGain = oneShot and Catalog.GlobalNumber("OneShotMasterGain", 1) or 1
	return graph.Profile.MasterGain * routeGain * oneShotGain
end

local function stopManagedOneShot(state, channel, fadeSeconds)
	local graph = state.Graph
	local handle = graph and graph.ManagedOneShots[channel]
	if not handle then return end
	graph.ManagedOneShots[channel] = nil
	if handle.Cleaned then return end
	local fade = math.max(0, tonumber(fadeSeconds) or 0)
	if fade <= 0 or not handle.Fader.Parent then handle.Cleanup(); return end
	local TweenService = game:GetService("TweenService")
	local tween = TweenService:Create(handle.Fader, TweenInfo.new(fade, Enum.EasingStyle.Linear), { Volume = 0 })
	tween.Completed:Once(handle.Cleanup)
	tween:Play()
end

local function playOneShot(state, layerName, managedChannel)
	local graph = state.Graph
	if not graph then return nil end
	if managedChannel then stopManagedOneShot(state, managedChannel, Catalog.GlobalNumber("ManagedCueCancelFadeSeconds", 0.05)) end
	local activeCount = 0
	for _ in pairs(graph.OneShotFaders) do activeCount += 1 end
	if activeCount >= math.max(1, math.floor(tonumber(quality:GetAttribute("MaxConcurrentOneShotsPerVehicle")) or 8)) then return nil end
	local assetId = graph.Profile.Assets[layerName] or ""
	if assetId == "" then return nil end
	local player = newPlayer(graph.Root, "OneShot_" .. layerName, assetId, false, graph.Profile.Pitches[layerName])
	if not player then return nil end
	local fader = Instance.new("AudioFader")
	fader.Name = "OneShotFader_" .. layerName
	fader.Parent = graph.Root
	local oneShotWires = { wire(player, fader, graph.Root, "OneShotWire_" .. layerName .. "_PlayerToFader") }
	if graph.Route == "Internal" then
		table.insert(oneShotWires, wire(fader, deviceOutput, graph.Root, "OneShotWire_" .. layerName .. "_FaderToOutput"))
	elseif graph.Emitter then
		table.insert(oneShotWires, wire(fader, graph.Emitter, graph.Root, "OneShotWire_" .. layerName .. "_FaderToEmitter"))
	else
		player:Destroy(); fader:Destroy(); return nil
	end
	graph.OneShotFaders[fader] = true
	Bus.Register("Vehicle", fader, (graph.Profile.Gains[layerName] or 0.5) * routeMultiplier(graph, true))
	local handle = { Player = player, Fader = fader, Cleaned = false }
	function handle.Cleanup()
		if handle.Cleaned then return end
		handle.Cleaned = true
		if managedChannel and graph.ManagedOneShots[managedChannel] == handle then graph.ManagedOneShots[managedChannel] = nil end
		Bus.Unregister(fader)
		graph.OneShotFaders[fader] = nil
		for _, oneShotWire in ipairs(oneShotWires) do if oneShotWire.Parent then oneShotWire:Destroy() end end
		if player.Parent then player:Destroy() end
		if fader.Parent then fader:Destroy() end
	end
	if managedChannel then graph.ManagedOneShots[managedChannel] = handle end
	player.Ended:Once(handle.Cleanup)
	task.delay(math.max(2, Catalog.GlobalNumber("OneShotMaxLifetimeSeconds", 12)), handle.Cleanup)
	pcall(function() player:Play() end)
	return handle
end
]=]

local OLD_ONESHOT_FUNCTION = [=[
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
]=]

local OLD_UPDATE_BLOCK = [=[
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
]=]

local NEW_UPDATE_BLOCK = [=[
local function setTarget(graph, name, value)
	local layer = graph and graph.Layers[name]
	if layer then layer.Target = math.max(0, value) end
end

local function rangeAlpha(value, first, last)
	if last <= first then return value >= last and 1 or 0 end
	return math.clamp((value - first) / (last - first), 0, 1)
end

local function cueEnabled()
	return Catalog.GlobalBool("VehicleAudioCueExpansionEnabled", true)
end

local function conditionLocalAcceleration(state, semantic, dt)
	if not state.LocalDriver or not cueEnabled() then return nil end
	local raw = semantic.Drive == "Accelerating"
	state.AccelerationEnterTimer = state.AccelerationEnterTimer or 0
	state.AccelerationReleaseTimer = state.AccelerationReleaseTimer or 0
	state.AccelerationActiveSeconds = state.AccelerationActiveSeconds or 0
	state.AccelerationAudioActive = state.AccelerationAudioActive == true
	local cue
	if raw then
		state.AccelerationReleaseTimer = 0
		if state.AccelerationAudioActive then
			state.AccelerationActiveSeconds += dt
		else
			state.AccelerationEnterTimer += dt
			if state.AccelerationEnterTimer >= Catalog.GlobalNumber("AccelerationEnterConfirmSeconds", 0.06) then
				state.AccelerationAudioActive = true
				state.AccelerationActiveSeconds = 0
				state.AccelerationEnterTimer = 0
				cue = "AccelerationEnter"
			end
		end
	else
		state.AccelerationEnterTimer = 0
		if state.AccelerationAudioActive then
			state.AccelerationReleaseTimer += dt
			if state.AccelerationReleaseTimer >= Catalog.GlobalNumber("AccelerationReleaseConfirmSeconds", 0.12) then
				state.AccelerationAudioActive = false
				state.AccelerationReleaseTimer = 0
				if state.AccelerationActiveSeconds >= Catalog.GlobalNumber("AccelerationMinimumActiveSeconds", 0.18) then cue = "AccelerationRelease" end
			end
		end
	end
	semantic.Drive = state.AccelerationAudioActive and "Accelerating" or semantic.Drive
	if not state.AccelerationAudioActive and raw then semantic.Drive = "Idle" end
	if cue then
		local now = os.clock()
		local cooldown = Catalog.GlobalNumber("AccelerationRetriggerCooldownSeconds", 0.25)
		if now - (state.AccelerationLastCueAt or -math.huge) < cooldown then cue = nil else state.AccelerationLastCueAt = now end
	end
	return cue
end

local function fadeSeconds(layerName, rising)
	local prefix = "Engine"
	if layerName == "Acceleration" then prefix = "Acceleration"
	elseif layerName == "DriftLoop" then prefix = "Drift"
	elseif layerName == "BoostLoop" then prefix = "Boost"
	elseif layerName == "DriverWind" then prefix = "Wind" end
	local fallback = 1 / math.max(0.1, Catalog.GlobalNumber("LayerSmoothingPerSecond", 7))
	return math.max(0.001, Catalog.GlobalNumber(prefix .. (rising and "FadeInSeconds" or "FadeOutSeconds"), fallback))
end

local function publishLocalState(state, semantic, cue)
	if not state.LocalDriver or (sameState(state.LastPublished, semantic) and not cue) then return end
	localRevision += 1
	state.LastPublished = table.clone(semantic)
	stateRemote:FireServer(state.Vehicle, {
		Ignition = semantic.Ignition,
		Drive = semantic.Drive,
		Drift = semantic.Drift,
		Boost = semantic.Boost,
		Cue = cue or "",
		Revision = localRevision,
	})
end

local function updateGraph(state, dt)
	local graph = state.Graph
	local root = rootFor(state.Vehicle)
	if not (graph and root) then return end
	local semantic = semanticState(state.Vehicle, state.LocalDriver)
	local remoteBoostCue, remoteAccelerationCue
	if not state.LocalDriver then
		local cueRevision = tonumber(state.Vehicle:GetAttribute("NTRAudioCueRevision")) or 0
		if cueRevision > (state.LastRemoteCueRevision or 0) then
			state.LastRemoteCueRevision = cueRevision
			local candidate = tostring(state.Vehicle:GetAttribute("NTRAudioCue") or "")
			if candidate == "BoostEmpty" or candidate == "FullBoostSpent" then
				remoteBoostCue = candidate
				state.SuppressNextBoostRelease = true
			elseif candidate == "AccelerationEnter" or candidate == "AccelerationRelease" then
				remoteAccelerationCue = candidate
			end
		end
	end
	local accelerationCue = conditionLocalAcceleration(state, semantic, dt)
	local rawBoosting = semantic.Boost ~= "Off"
	if state.LocalDriver and cueEnabled() then
		state.BoostReleaseTimer = rawBoosting and 0 or ((state.BoostReleaseTimer or 0) + dt)
		if not rawBoosting and state.BoostAudioActive and state.BoostReleaseTimer < Catalog.GlobalNumber("BoostContinuousReleaseGraceSeconds", 0.08) then
			semantic.Boost = "Normal"
		end
	end
	local boosting = semantic.Boost ~= "Off"
	state.BoostAudioActive = boosting
	local charge = state.LocalDriver and math.clamp((tonumber(MobileDriveState.BoostPercent) or 100) / 100, 0, 1) or nil
	local boostCue
	if state.LocalDriver and cueEnabled() and charge then
		local previousCharge = state.LastBoostCharge
		local draining = previousCharge ~= nil and charge < previousCharge - 0.001 and rawBoosting
		local recharging = previousCharge ~= nil and charge > previousCharge + 0.001 and not rawBoosting
		if rawBoosting and not state.RawBoosting then
			state.BoostSessionStartCharge = math.max(charge, previousCharge or charge)
			state.BoostSessionHadDrain = false
			state.BoostSessionFullEligible = charge >= Catalog.GlobalNumber("FullBoostStartThreshold", 0.98)
		end
		if draining then state.BoostSessionHadDrain = true end
		if state.RawBoosting and not rawBoosting and state.BoostSessionHadDrain then
			if charge <= Catalog.GlobalNumber("BoostEmptyThreshold", 0.01) then
				local consumed = math.max(0, (state.BoostSessionStartCharge or charge) - charge)
				if state.BoostSessionFullEligible and consumed >= Catalog.GlobalNumber("FullBoostMinimumConsumedFraction", 0.95) then
					boostCue = "FullBoostSpent"
				else
					boostCue = "BoostEmpty"
				end
			end
		end
		local missingEnough = charge <= 1 - Catalog.GlobalNumber("BoostRechargeMinimumMissingCharge", 0.05)
		if recharging and missingEnough then
			if not state.RechargeActive then
				local now = os.clock()
				if now - (state.LastRechargeCueAt or -math.huge) >= Catalog.GlobalNumber("BoostRechargeRetriggerCooldownSeconds", 0.2) then
					playOneShot(state, "BoostRecharge", "BoostRecharge")
					state.LastRechargeCueAt = now
				end
			end
			state.RechargeActive = true
		end
		if rawBoosting then
			state.RechargeActive = false
			stopManagedOneShot(state, "BoostRecharge", Catalog.GlobalNumber("BoostRechargeCancelFadeSeconds", 0.08))
		end
		if charge >= 0.999 then
			state.RechargeActive = false
			if Catalog.GlobalBool("BoostRechargeStopAtFull", true) then stopManagedOneShot(state, "BoostRecharge", Catalog.GlobalNumber("BoostRechargeCancelFadeSeconds", 0.08)) end
		end
		state.RawBoosting = rawBoosting
		state.LastBoostCharge = charge
	end
	if state.LocalDriver then
		state.OutboundCueQueue = state.OutboundCueQueue or {}
		if boostCue then table.insert(state.OutboundCueQueue, boostCue) end
		if accelerationCue then table.insert(state.OutboundCueQueue, accelerationCue) end
	end
	local outboundCue = state.LocalDriver and table.remove(state.OutboundCueQueue, 1) or nil
	publishLocalState(state, semantic, outboundCue)

	local speedMph = root.AssemblyLinearVelocity.Magnitude * MPH_PER_STUD
	local idleAlpha = rangeAlpha(speedMph, Catalog.GlobalNumber("IdleFadeStartMph", 5), Catalog.GlobalNumber("IdleFadeEndMph", 45))
	local highAlpha = rangeAlpha(speedMph, Catalog.GlobalNumber("EngineHighFadeStartMph", 35), Catalog.GlobalNumber("EngineHighFullSpeedMph", 120))
	local lowPeak = Catalog.GlobalNumber("EngineLowPeakMph", 42)
	local lowRise = rangeAlpha(speedMph, 0, lowPeak)
	local lowFall = 1 - rangeAlpha(speedMph, lowPeak, Catalog.GlobalNumber("EngineHighFullSpeedMph", 120))
	local lowShape = Catalog.GlobalNumber("EngineLowFloorMultiplier", 0.3) + (1 - Catalog.GlobalNumber("EngineLowFloorMultiplier", 0.3)) * math.min(lowRise, lowFall)
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
	for layerName, layer in pairs(graph.Layers) do
		local seconds = fadeSeconds(layerName, layer.Target > layer.Gain)
		local alpha = 1 - math.exp(-dt / seconds)
		layer.Gain += (layer.Target - layer.Gain) * alpha
		Bus.SetGain(layer.Fader, layer.Gain)
		if layerName == "EngineLow" then
			local pitchAlpha = rangeAlpha(speedMph, 0, math.max(1, lowPeak))
			local multiplier = Catalog.GlobalNumber("EngineLowPitchMin", 0.82) + (Catalog.GlobalNumber("EngineLowPitchMax", 1.2) - Catalog.GlobalNumber("EngineLowPitchMin", 0.82)) * pitchAlpha
			layer.Player.PlaybackSpeed = math.clamp((graph.Profile.Pitches.EngineLow or 1) * multiplier, 0.5, 2)
		elseif layerName == "EngineHigh" then
			local multiplier = Catalog.GlobalNumber("EngineHighPitchMin", 0.86) + (Catalog.GlobalNumber("EngineHighPitchMax", 1.2) - Catalog.GlobalNumber("EngineHighPitchMin", 0.86)) * highAlpha
			layer.Player.PlaybackSpeed = math.clamp((graph.Profile.Pitches.EngineHigh or 1) * multiplier, 0.5, 2)
		elseif layerName == "DriftLoop" then
			local multiplier = Catalog.GlobalNumber("DriftPitchStartMultiplier", 0.95) + (Catalog.GlobalNumber("DriftPitchEndMultiplier", 1.08) - Catalog.GlobalNumber("DriftPitchStartMultiplier", 0.95)) * driftRamp
			layer.Player.PlaybackSpeed = math.clamp((graph.Profile.Pitches.DriftLoop or 1) * multiplier, 0.5, 2)
		end
	end

	local previous = state.LastSemantic
	if accelerationCue then playOneShot(state, accelerationCue, "AccelerationTransient") end
	if boostCue then
		state.SuppressNextBoostRelease = true
		if boostCue == "FullBoostSpent" and not Catalog.GlobalBool("FullBoostReplacesEmpty", true) then playOneShot(state, "BoostEmpty") end
		playOneShot(state, boostCue, "BoostTransient")
	end
	if remoteBoostCue then playOneShot(state, remoteBoostCue, "BoostTransient") end
	if remoteAccelerationCue then playOneShot(state, remoteAccelerationCue, "AccelerationTransient") end
	if previous then
		if previous.Ignition ~= semantic.Ignition then
			if semantic.Ignition == "Running" then playOneShot(state, "Ignition") elseif semantic.Ignition == "Off" then playOneShot(state, "Shutdown") end
		end
		if previous.Drift == "None" and semantic.Drift ~= "None" then playOneShot(state, "DriftEnter") end
		if previous.Boost == "Off" and semantic.Boost ~= "Off" then playOneShot(state, "BoostEnter", "BoostTransient") end
		if previous.Boost ~= "Off" and semantic.Boost == "Off" then
			if not boostCue and not state.SuppressNextBoostRelease then playOneShot(state, "BoostRelease", "BoostTransient") end
			state.SuppressNextBoostRelease = false
		end
	elseif semantic.Ignition == "Running" then
		playOneShot(state, "Ignition")
	end
	state.LastSemantic = semantic
end
]=]

local function projectController(source)
	if has(source, CLIENT_REVISION) then return source end
	assert(has(source, "NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CLIENT_V1"), "Unknown VehicleAudioController baseline")
	source = replaceOnce(source, "NTR_AUDIO_SYSTEM_PHASE1_VEHICLE_CLIENT_V1", CLIENT_REVISION, "controller revision")
	source = replaceOnce(source,
		'local Contract = require(commonAudio:WaitForChild("VehicleAudioStateContract"))',
		'local Contract = require(commonAudio:WaitForChild("VehicleAudioStateContract"))\nlocal MobileDriveState = require(kit.Shared.Modules.Client.Controllers:WaitForChild("MobileDriveInputState"))',
		"controller boost telemetry dependency")
	source = replaceOnce(source,
		'\t\tOneShotFaders = setmetatable({}, { __mode = "k" }),\n\t\tRoute = route,',
		'\t\tOneShotFaders = setmetatable({}, { __mode = "k" }),\n\t\tManagedOneShots = {},\n\t\tRoute = route,',
		"controller managed channels")
	source = replaceOnce(source,
		'pcall(function() emitter:SetDistanceAttenuation({ [0] = 1, [minDistance] = 1, [maxDistance * 0.55] = 0.28, [maxDistance] = 0 }) end)',
		'local midDistance = math.clamp(Catalog.GlobalNumber("ExternalMidDistanceStuds", maxDistance * 0.55), minDistance, maxDistance)\n\t\tlocal midGain = math.clamp(Catalog.GlobalNumber("ExternalMidDistanceGain", 0.28), 0, 1)\n\t\tpcall(function() emitter:SetDistanceAttenuation({ [0] = 1, [minDistance] = 1, [midDistance] = midGain, [maxDistance] = 0 }) end)',
		"controller distance curve")
	source = replaceOnce(source, OLD_ONESHOT_FUNCTION, NEW_ONESHOT_FUNCTIONS, "controller managed one-shot block")
	-- Remove the original publisher because the replacement update block installs the cue-aware publisher.
	source = replaceOnce(source, [=[
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

]=], "", "controller old publisher")
	source = replaceOnce(source, OLD_UPDATE_BLOCK, NEW_UPDATE_BLOCK, "controller tuning/cue update block")
	return source
end

assert(has(runtime.Source, "NTR_AUDIO_SYSTEM_PHASE1_RUNTIME_CLIENT_V1"), "Audio runtime baseline marker missing")
assert(string.find(mobileState.Source, "BoostPercent = 100", 1, true), "Shared boost percentage state is unavailable")

local projected = {
	{ Object = catalog, Source = projectCatalog(catalog.Source), Marker = CATALOG_REVISION },
	{ Object = contract, Source = projectContract(contract.Source), Marker = CONTRACT_REVISION },
	{ Object = stateService, Source = projectService(stateService.Source), Marker = SERVER_REVISION },
	{ Object = controller, Source = projectController(controller.Source), Marker = CLIENT_REVISION },
}
for _, item in ipairs(projected) do
	assert(has(item.Source, item.Marker), item.Marker .. " projection failed")
	compile(item.Object:GetFullName(), item.Source)
end

local newProfileLayers = {
	AccelerationEnter = 0.55,
	AccelerationRelease = 0.45,
	BoostRecharge = 0.45,
	BoostEmpty = 0.65,
	FullBoostSpent = 0.85,
}

-- The installer only adds missing attributes. Keep an explicit pre-install record so
-- any accidental mutation of an existing tuning or asset value fails the transaction.
local preservedAttributeSets = {
	{ Object = global, Values = global:GetAttributes() },
	{ Object = quality, Values = quality:GetAttributes() },
	{ Object = profile, Values = profile:GetAttributes() },
}

local function assertExistingAttributesPreserved()
	for _, record in ipairs(preservedAttributeSets) do
		for name, value in pairs(record.Values) do
			assert(record.Object:GetAttribute(name) == value, record.Object:GetFullName() .. "." .. name .. " changed unexpectedly")
		end
	end
end

local globalDefaults = {
	VehicleAudioCueExpansionEnabled = true,
	LocalDriverGain = 1,
	ExternalVehicleGain = 0.9,
	OneShotMasterGain = 1,
	ManagedCueCancelFadeSeconds = 0.05,
	IdleFadeStartMph = 5,
	IdleFadeEndMph = 45,
	EngineLowPeakMph = 42,
	EngineLowFloorMultiplier = 0.3,
	EngineHighFadeStartMph = 35,
	EngineHighFullSpeedMph = 120,
	CoastStartMph = 8,
	CoastFullGainMph = 50,
	WindStartMph = 18,
	WindFullGainMph = 128,
	EngineLowPitchMin = 0.82,
	EngineLowPitchMax = 1.2,
	EngineHighPitchMin = 0.86,
	EngineHighPitchMax = 1.2,
	EngineFadeInSeconds = 0.14,
	EngineFadeOutSeconds = 0.18,
	AccelerationFadeInSeconds = 0.10,
	AccelerationFadeOutSeconds = 0.18,
	DriftFadeInSeconds = 0.16,
	DriftFadeOutSeconds = 0.25,
	BoostFadeInSeconds = 0.08,
	BoostFadeOutSeconds = 0.14,
	WindFadeInSeconds = 0.35,
	WindFadeOutSeconds = 0.45,
	AccelerationEnterConfirmSeconds = 0.06,
	AccelerationReleaseConfirmSeconds = 0.12,
	AccelerationMinimumActiveSeconds = 0.18,
	AccelerationRetriggerCooldownSeconds = 0.25,
	DriftLoopStartGainMultiplier = 0.15,
	DriftRampDelaySeconds = 0.10,
	DriftRampFullSeconds = 2.5,
	DriftRampCurveExponent = 1.3,
	DriftPitchStartMultiplier = 0.95,
	DriftPitchEndMultiplier = 1.08,
	BoostRechargeCancelFadeSeconds = 0.08,
	BoostRechargeMinimumMissingCharge = 0.05,
	BoostRechargeRetriggerCooldownSeconds = 0.20,
	BoostRechargeStopAtFull = true,
	BoostContinuousReleaseGraceSeconds = 0.08,
	FullBoostStartThreshold = 0.98,
	BoostEmptyThreshold = 0.01,
	FullBoostMinimumConsumedFraction = 0.95,
	FullBoostReplacesEmpty = true,
	ExternalMidDistanceStuds = 132,
	ExternalMidDistanceGain = 0.28,
}

local descriptions = {
	SchemaVersion = "Version of the shared audio configuration shape; this is structural metadata and should not be used as a tuning value.",
	AudioSystemEnabled = "Master playback gate for the complete NTR audio system; leave false until required assets and contexts pass the Phase 3 activation audit.",
	VehicleAudioEnabled = "Vehicle-audio subsystem gate beneath AudioSystemEnabled; false disables vehicle presentation while leaving other audio contexts available.",
	FallbackProfileId = "Stable vehicle sound-profile folder ID used when a vehicle has no valid resolved or standard audio profile.",
	DebugAudio = "Enables additional vehicle-audio diagnostic output when true; keep false for normal play and release builds.",
	ExternalMinDistanceStuds = "3D distance inside which an external vehicle retains full attenuation gain.",
	ExternalMaxDistanceStuds = "3D distance where an external vehicle's emitter attenuation reaches zero and priority may become silent.",
	LayerSmoothingPerSecond = "Legacy common layer response used only as a fallback if a specific fade-time attribute is missing.",
	OneShotMaxLifetimeSeconds = "Safety lifetime after which any unfinished vehicle one-shot graph is cleaned up.",
	StateRateLimitPerSecond = "Maximum accepted vehicle-audio state messages per driver each second before the server silently rate-limits extras.",
	VehicleAudioCueExpansionEnabled = "Enables the conditioned accelerator cues, duration-based drift ramp and boost recharge/depletion cues without changing driving physics.",
	LocalDriverGain = "Master multiplier for every vehicle layer heard by the vehicle's own driver through the non-positional internal route.",
	ExternalVehicleGain = "Master multiplier for vehicle audio heard by other players through the vehicle's 3D emitter.",
	OneShotMasterGain = "Additional master multiplier applied only to one-shot vehicle cues; looping layers are unaffected.",
	ManagedCueCancelFadeSeconds = "Default fade time used when a managed one-shot must be replaced by another cue on the same channel.",
	IdleFadeStartMph = "Vehicle speed where the idle layer begins reducing from its configured gain.",
	IdleFadeEndMph = "Vehicle speed where the idle layer reaches its minimum high-speed contribution.",
	EngineLowPeakMph = "Vehicle speed where the low-engine loop reaches its strongest contribution and completes its initial pitch rise.",
	EngineLowFloorMultiplier = "Minimum fraction of EngineLowGain retained at the edges of the low-engine speed range.",
	EngineHighFadeStartMph = "Vehicle speed where the high-engine layer starts fading in.",
	EngineHighFullSpeedMph = "Vehicle speed where the high-engine layer reaches full configured gain and maximum configured pitch multiplier.",
	CoastStartMph = "Minimum vehicle speed required before the coast loop may become audible while not accelerating.",
	CoastFullGainMph = "Vehicle speed where the coast loop reaches its complete configured gain.",
	WindStartMph = "Driver speed where the internal wind layer begins fading in.",
	WindFullGainMph = "Driver speed where the internal wind layer reaches its complete configured gain.",
	EngineLowPitchMin = "Playback-speed multiplier applied to EngineLow at the bottom of its speed response.",
	EngineLowPitchMax = "Playback-speed multiplier applied to EngineLow at EngineLowPeakMph.",
	EngineHighPitchMin = "Playback-speed multiplier applied to EngineHigh when its speed fade begins.",
	EngineHighPitchMax = "Playback-speed multiplier applied to EngineHigh at EngineHighFullSpeedMph.",
	EngineFadeInSeconds = "Response time used when idle, low-engine, high-engine or coast target gain rises.",
	EngineFadeOutSeconds = "Response time used when idle, low-engine, high-engine or coast target gain falls.",
	AccelerationFadeInSeconds = "Response time for the sustained Acceleration loop to fade in after acceleration is confirmed.",
	AccelerationFadeOutSeconds = "Response time for the sustained Acceleration loop to fade out after release is confirmed.",
	DriftFadeInSeconds = "Response time for DriftLoop to follow a rising duration-based drift target.",
	DriftFadeOutSeconds = "Response time for DriftLoop to fade after drifting stops.",
	BoostFadeInSeconds = "Response time for BoostLoop to fade in.",
	BoostFadeOutSeconds = "Response time for BoostLoop to fade out.",
	WindFadeInSeconds = "Response time for driver wind to follow a rising speed target.",
	WindFadeOutSeconds = "Response time for driver wind to follow a falling speed target.",
	AccelerationEnterConfirmSeconds = "How long actual forward acceleration must remain active before AccelerationEnter and the conditioned acceleration loop begin.",
	AccelerationReleaseConfirmSeconds = "How long acceleration must remain inactive before AccelerationRelease is allowed; brief taps inside this window do not chatter.",
	AccelerationMinimumActiveSeconds = "Minimum confirmed acceleration-session duration required before a release cue can play.",
	AccelerationRetriggerCooldownSeconds = "Minimum time between accelerator transient cues on the same vehicle.",
	DriftLoopStartGainMultiplier = "Fraction of DriftLoopGain used at the start of a drift before the duration ramp builds.",
	DriftRampDelaySeconds = "Time after drift begins before its duration-based gain and pitch ramp starts.",
	DriftRampFullSeconds = "Continuous drift duration where DriftLoop reaches full configured gain and final pitch multiplier.",
	DriftRampCurveExponent = "Shape of the drift buildup; above 1 delays intensity, below 1 makes it build earlier.",
	DriftPitchStartMultiplier = "Playback-speed multiplier applied to DriftLoop at drift start.",
	DriftPitchEndMultiplier = "Playback-speed multiplier applied to DriftLoop when the duration ramp is full.",
	BoostRechargeCancelFadeSeconds = "Fade time used to cancel the driver-only recharge one-shot when boost resumes or charge becomes full.",
	BoostRechargeMinimumMissingCharge = "Minimum missing fraction of the boost tank required before a recharge cue may begin; 0.05 means at least 5 percent missing.",
	BoostRechargeRetriggerCooldownSeconds = "Minimum time between recharge one-shot starts during interrupted recharge sessions.",
	BoostRechargeStopAtFull = "When true, an unfinished recharge one-shot is faded out as soon as boost reaches full charge.",
	BoostContinuousReleaseGraceSeconds = "Short off-state tolerance that prevents a one-frame boost interruption from breaking a full-use session.",
	FullBoostStartThreshold = "Minimum starting boost fraction required for the FullBoostSpent cue; 0.98 means 98 percent.",
	BoostEmptyThreshold = "Remaining boost fraction considered empty when selecting depletion cues.",
	FullBoostMinimumConsumedFraction = "Minimum fraction that must be drained continuously for FullBoostSpent to qualify.",
	FullBoostReplacesEmpty = "When true, FullBoostSpent replaces BoostEmpty for a qualifying complete uninterrupted boost use.",
	ExternalMidDistanceStuds = "Middle control point of the external 3D distance attenuation curve.",
	ExternalMidDistanceGain = "Remaining external gain at ExternalMidDistanceStuds before audio fades to zero at the maximum distance.",
}

local qualityDescriptions = {
	ParameterUpdateHz = "How often each active vehicle graph recalculates speed-driven gain, pitch, cue timers and charge presentation; higher values cost more client work.",
	PriorityUpdateHz = "How often nearby remote vehicles are re-ranked into detailed, simple or silent audio tiers.",
	MaxDetailedRemoteVehicles = "Maximum nearest remote vehicles allowed to run the complete loop-layer graph on one client.",
	MaxSimpleRemoteVehicles = "Additional nearest remote vehicles allowed to run only the simplified low-engine graph on one client.",
	MaxConcurrentOneShotsPerVehicle = "Hard cap on simultaneous transient AudioPlayers for one vehicle, including managed cue channels.",
	AcousticSimulationEnabled = "Legacy Phase 1 acoustic gate retained for compatibility; Phase 3 acoustics config remains the canonical native-acoustics owner.",
}

local layerPurposes = {
	Ignition = "one-shot when a valid driver starts a vehicle audio session",
	Shutdown = "one-shot when the running vehicle audio session shuts down",
	AccelerationEnter = "managed one-shot after forward acceleration passes its confirmation window",
	AccelerationRelease = "managed one-shot after a confirmed acceleration session remains released",
	Idle = "loop strongest near stationary and reduced as vehicle speed rises",
	EngineLow = "low-speed engine loop shaped around EngineLowPeakMph",
	EngineHigh = "high-speed engine loop faded in between its configured speed thresholds",
	Acceleration = "sustained loop while conditioned forward acceleration remains active",
	Coast = "loop while running above CoastStartMph without accelerating",
	DriftEnter = "one-shot when a drift begins",
	DriftLoop = "continuous drift layer whose gain and pitch build with uninterrupted drift duration",
	BoostEnter = "one-shot when boost begins",
	BoostLoop = "continuous layer while boost presentation remains active",
	BoostRelease = "one-shot when boost is released without emptying the tank",
	BoostRecharge = "driver-only cancellable one-shot when boost charge actually begins rising",
	BoostEmpty = "one-shot when a non-full qualifying boost session drains the tank",
	FullBoostSpent = "special one-shot when a near-full tank is continuously consumed to empty",
	DriverWind = "driver-only loop faded in by vehicle speed",
}

local sourceSnapshots, attributeSnapshots, valueSnapshots, created = {}, {}, {}, {}

local function snapshotAttribute(object, name)
	table.insert(attributeSnapshots, { Object = object, Name = name, HadValue = object:GetAttribute(name) ~= nil, Value = object:GetAttribute(name) })
end

local function setDefaultAttribute(object, name, value)
	if object:GetAttribute(name) == nil then snapshotAttribute(object, name); object:SetAttribute(name, value) end
end

local function ensureFolder(parent, name)
	local object = parent:FindFirstChild(name)
	if object then assert(object:IsA("Folder"), object:GetFullName() .. " must be Folder"); return object end
	object = Instance.new("Folder"); object.Name = name; object.Parent = parent; table.insert(created, object); return object
end

local function setDescription(parent, name, value)
	local object = parent:FindFirstChild(name)
	if object then
		assert(object:IsA("StringValue"), object:GetFullName() .. " must be StringValue")
		table.insert(valueSnapshots, { Object = object, Value = object.Value })
	else
		object = Instance.new("StringValue"); object.Name = name; object.Parent = parent; table.insert(created, object)
	end
	object.Value = value
end

local function audit()
	assert(audio:GetAttribute("VehicleTuningCueRevision") == REVISION, "Audio expansion revision missing")
	for _, item in ipairs(projected) do assert(has(item.Object.Source, item.Marker), item.Object:GetFullName() .. " expansion marker missing") end
	for name in pairs(globalDefaults) do assert(global:GetAttribute(name) ~= nil, "Global attribute missing: " .. name) end
	assert(profile:GetAttribute("ProfileMasterGain") ~= nil, "ProfileMasterGain missing")
	for layer in pairs(newProfileLayers) do
		for _, suffix in ipairs({ "AssetId", "Gain", "Pitch" }) do assert(profile:GetAttribute(layer .. suffix) ~= nil, layer .. suffix .. " missing") end
	end
	local globalDocs = child(global, "Descriptions", "Folder")
	local qualityDocs = child(quality, "Descriptions", "Folder")
	local profileDocs = child(profile, "Descriptions", "Folder")
	for name in pairs(descriptions) do child(globalDocs, name, "StringValue") end
	for name in pairs(qualityDescriptions) do child(qualityDocs, name, "StringValue") end
	for layer in pairs(layerPurposes) do
		for _, suffix in ipairs({ "AssetId", "Gain", "Pitch" }) do child(profileDocs, layer .. suffix, "StringValue") end
	end
	print(("[NTR Audio Tuning + Cues] AUDIT PASS | profile attributes preserved | %d new cue layers | documented config"):format(5))
end

if MODE == "AUDIT" then audit(); return end
if MODE == "DISABLE" then
	global:SetAttribute("VehicleAudioCueExpansionEnabled", false)
	print("[NTR Audio Tuning + Cues] DISABLE PASS | expansion cues suppressed; existing audio config/assets preserved")
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
	snapshotAttribute(audio, "VehicleTuningCueRevision")
	audio:SetAttribute("VehicleTuningCueRevision", REVISION)
	for name, value in pairs(globalDefaults) do setDefaultAttribute(global, name, value) end
	setDefaultAttribute(profile, "ProfileMasterGain", 1)
	for layer, gain in pairs(newProfileLayers) do
		setDefaultAttribute(profile, layer .. "AssetId", "")
		setDefaultAttribute(profile, layer .. "Gain", gain)
		setDefaultAttribute(profile, layer .. "Pitch", 1)
	end
	local globalDocs = ensureFolder(global, "Descriptions")
	local qualityDocs = ensureFolder(quality, "Descriptions")
	local profileDocs = ensureFolder(profile, "Descriptions")
	for name, description in pairs(descriptions) do setDescription(globalDocs, name, description) end
	for name, description in pairs(qualityDescriptions) do setDescription(qualityDocs, name, description) end
	setDescription(profileDocs, "ProfileMasterGain", "Master multiplier for every loop and one-shot in this complete vehicle sound package; use it to normalise packages without retuning every layer.")
	setDescription(profileDocs, "DisplayName", "Editor-facing name of this complete vehicle sound package; changing it does not change the stable profile folder ID.")
	setDescription(profileDocs, "ProfileRevision", "Editor-managed revision number for the complete sound package's assets and tuning values.")
	for layer, purpose in pairs(layerPurposes) do
		setDescription(profileDocs, layer .. "AssetId", "Roblox audio asset ID for the " .. purpose .. ". Blank disables this layer without affecting the rest of the profile.")
		setDescription(profileDocs, layer .. "Gain", "Linear mix multiplier for the " .. purpose .. "; 0 is silent, 1 is the asset's base level, and values above 1 amplify it.")
		setDescription(profileDocs, layer .. "Pitch", "Base playback-speed/pitch multiplier for the " .. purpose .. "; 1 is original, below 1 is lower/slower, and above 1 is higher/faster.")
	end
	assertExistingAttributesPreserved()
	audit()
end)

if not ok then
	for index = #sourceSnapshots, 1, -1 do local snapshot = sourceSnapshots[index]; pcall(function() snapshot.Object.Source = snapshot.Source end) end
	for index = #valueSnapshots, 1, -1 do local snapshot = valueSnapshots[index]; pcall(function() snapshot.Object.Value = snapshot.Value end) end
	for index = #attributeSnapshots, 1, -1 do
		local snapshot = attributeSnapshots[index]
		pcall(function() if snapshot.HadValue then snapshot.Object:SetAttribute(snapshot.Name, snapshot.Value) else snapshot.Object:SetAttribute(snapshot.Name, nil) end end)
	end
	for index = #created, 1, -1 do local object = created[index]; pcall(function() if object.Parent then object:Destroy() end end) end
	error("[NTR Audio Tuning + Cues] INSTALL ROLLBACK: " .. tostring(problem))
end

print("[NTR Audio Tuning + Cues] INSTALL PASS | existing attributes/assets preserved | audio remains governed by the current master enable")
