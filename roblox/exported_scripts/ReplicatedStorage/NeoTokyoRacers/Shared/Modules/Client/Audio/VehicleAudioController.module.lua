-- NTR_AUDIO_VEHICLE_CLIENT_V3_PARKED_EXTERNAL
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
local MobileDriveState = require(kit.Shared.Modules.Client.Controllers:WaitForChild("MobileDriveInputState"))
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
		ManagedOneShots = {},
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
		local midDistance = math.clamp(Catalog.GlobalNumber("ExternalMidDistanceStuds", maxDistance * 0.55), minDistance, maxDistance)
		local midGain = math.clamp(Catalog.GlobalNumber("ExternalMidDistanceGain", 0.28), 0, 1)
		pcall(function() emitter:SetDistanceAttenuation({ [0] = 1, [minDistance] = 1, [midDistance] = midGain, [maxDistance] = 0 }) end)
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
	if holdLocalEngineLoopsForIgnition(state) then
		idleTarget, engineLowTarget, engineHighTarget, coastTarget = 0, 0, 0, 0
	end
	setTarget(graph, "Idle", idleTarget)
	setTarget(graph, "EngineLow", engineLowTarget)
	setTarget(graph, "EngineHigh", engineHighTarget)
	setTarget(graph, "Acceleration", exitedPresentation and 0 or (accelerating and gains.Acceleration * mix or 0))
	setTarget(graph, "Coast", coastTarget)
	setTarget(graph, "DriftLoop", exitedPresentation and 0 or (drifting and gains.DriftLoop * driftGainMultiplier * mix or 0))
	setTarget(graph, "BoostLoop", exitedPresentation and 0 or (boosting and gains.BoostLoop * mix or 0))
	setTarget(graph, "DriverWind", state.LocalDriver and gains.DriverWind * rangeAlpha(speedMph, Catalog.GlobalNumber("WindStartMph", 18), Catalog.GlobalNumber("WindFullGainMph", 128)) * mix or 0)
	for layerName, layer in pairs(graph.Layers) do
		local rising = layer.Target > layer.Gain
		local seconds = exitedPresentation and Catalog.GlobalNumber(rising and "ParkedFadeInSeconds" or "ParkedFadeOutSeconds", rising and 0.2 or 0.3) or fadeSeconds(layerName, rising)
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
		if previous.Ignition ~= semantic.Ignition and not state.LocalDriver then
			if semantic.Ignition == "Running" then playOneShot(state, "Ignition") elseif semantic.Ignition == "Off" then playOneShot(state, "Shutdown") end
		end
		if previous.Drift == "None" and semantic.Drift ~= "None" then playOneShot(state, "DriftEnter") end
		if previous.Boost == "Off" and semantic.Boost ~= "Off" then playOneShot(state, "BoostEnter", "BoostTransient") end
		if previous.Boost ~= "Off" and semantic.Boost == "Off" then
			if not boostCue and not state.SuppressNextBoostRelease then playOneShot(state, "BoostRelease", "BoostTransient") end
			state.SuppressNextBoostRelease = false
		end
	elseif semantic.Ignition == "Running" and tonumber(state.Vehicle:GetAttribute("OwnerUserId")) ~= localPlayer.UserId then
		playOneShot(state, "Ignition")
	end
	updateLocalIgnition(state)
	state.LastSemantic = semantic
end

local function cleanupVehicle(vehicle)
	local state = tracked[vehicle]
	if not state then return end
	cleanupLocalIgnition(state)
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
		local wasLocalDriver = state.LocalDriver
		state.LocalDriver = localDriver
		if wasLocalDriver and not localDriver and Catalog.GlobalBool("ReplayIgnitionOnRunningVehicleReentry", false) then
			cleanupLocalIgnition(state)
			state.LocalIgnitionPlayed = false
		end
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
			for _, state in pairs(tracked) do
				if state.Graph then
					updateGraph(state, step)
				elseif state.LocalDriver then
					-- NTR_VEHICLE_PRESENTATION_STATE_TRANSPORT_V1
					-- Keep validated semantic state replication alive when audio
					-- playback is disabled or this vehicle has a silent graph.
					publishLocalState(state, semanticState(state.Vehicle, true), nil)
				end
			end
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
