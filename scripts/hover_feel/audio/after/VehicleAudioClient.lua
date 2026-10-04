-- Canonical feature implementation; startup is owned by the composition root.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Controller = {}
local localPlayer = Players.LocalPlayer
local kit = game:GetService("ReplicatedStorage")
local audioModules = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio")
local commonAudio = game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio")
local Bus = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("AudioBusClient"))
local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("VehicleAudioCatalog"))
local Contract = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("VehicleAudioStateContract"))
local MobileDriveState = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("MobileDriveInputState"))
local stateRemote = game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Audio"):WaitForChild("VehicleAudioState")
local global = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Audio"):WaitForChild("Global")
local quality = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Audio"):WaitForChild("Quality")

local MPH_PER_STUD = 0.625
local HALF_PI = math.pi / 2
local tracked = setmetatable({}, { __mode = "k" })
local started = false
local heartbeatConnection = nil
local childAddedConnection = nil
local childRemovedConnection = nil
local cameraConnection = nil
local updateAccumulator = 0
local feelAccumulator = 0
local localFeelInterval = 1 / 60
local voiceSleepSeconds = 2
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
	if global:GetAttribute("DebugAudio") == true then print("[VehicleAudioClient] " .. tostring(message)) end
end

local function vehiclesRoot()
	local world = game:GetService("Workspace"):FindFirstChild("World")
	local runtime = world and game:GetService("Workspace"):WaitForChild("World"):FindFirstChild("Runtime")
	return runtime and game:GetService("Workspace"):WaitForChild("World"):WaitForChild("Runtime"):FindFirstChild("PlayerVehicles")
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
		deviceOutput.Name = "AudioDeviceOutput_Runtime"
		deviceOutput.Parent = runtimeRoot
		createdOutput = true
	end
	if camera then listener = camera:FindFirstChildWhichIsA("AudioListener", true) end
	if not listener and camera then
		listener = Instance.new("AudioListener")
		listener.Name = "AudioListener_Runtime"
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
		listenerWire.Name = "ListenerToOutput"
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

local function newRoutedSource(graph, layer, assetId, looped, pitch, route, emitter, deferPlay)
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
	if looped and not deferPlay then pcall(function() player:Play() end) end
	return { Player = player, Fader = fader, Gain = 0, Target = 0 }
end

local function destroyGraph(state)
	local graph = state.Graph
	if not graph then return end
	for _, layer in pairs(graph.Layers) do
		if layer.Fader then Bus.Unregister(layer.Fader) end
	end
	for fader in pairs(graph.OneShotFaders) do Bus.Unregister(fader) end
	for _, voice in ipairs(graph.FeelVoices) do Bus.Unregister(voice.Fader) end
	if graph.Emitter and graph.Emitter.Parent then graph.Emitter:Destroy() end
	if graph.Root and graph.Root.Parent then graph.Root:Destroy() end
	state.Graph = nil
end

-- Feel drive is optional per profile (FeelDriveEnabled) and switched for every profile by
-- Global.FeelAudioEnabled. Every feel player is created with the graph: a voice held at zero gain stops
-- playing and restarts when it is next needed, so the created count is bounded by buildFeel.
local function feelGloballyEnabled()
	return global:GetAttribute("FeelAudioEnabled") ~= false
end

local function qualityNumber(name, fallback)
	local value = tonumber(quality:GetAttribute(name))
	return value ~= nil and value or fallback
end

local function mobileBudget()
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
	return UserInputService.TouchEnabled and math.min(viewport.X, viewport.Y) < 800
end

local function newFeelVoice(graph, name, assetId, looped)
	local voice = newRoutedSource(graph, name, assetId or "", looped, 1, graph.Route, graph.Emitter, true)
	if not voice then return nil end
	voice.Playing = false
	voice.Silent = 0
	voice.Applied = 0
	table.insert(graph.FeelVoices, voice)
	return voice
end

local function thinned(list, count)
	if #list <= count then return list end
	local result = {}
	if count <= 0 then return result end
	if count == 1 then return { list[math.ceil(#list / 2)] } end
	for index = 1, count do
		table.insert(result, list[1 + math.floor((index - 1) * (#list - 1) / (count - 1) + 0.5)])
	end
	return result
end

local function buildFeel(graph)
	local profile = graph.Profile
	local tuning = profile.Feel
	local localRoute = graph.Route == "Internal"
	local feel = {
		Context = { Running = false, Drive = "Idle", Drifting = false, Boosting = false, Exited = false, EngineMix = 0, DriveMix = 0 },
		State = {
			Load = 0, LoadSlow = 0, LoadHeld = 0, Rev = 0, Spool = 0, Duck = 0, EngineMix = 0, LifePitch = 0, LifeLevel = 0,
			DriftChargePeak = 0, DriftChargeIdle = 0, LastImpactAt = -math.huge, LastBlowOffAt = -math.huge, ReadyCheck = 1,
			BoostDuck = 0,
		},
		PopBags = { Pop = {}, Bang = {} },
		LastPop = {},
		Loops = {},
		OneShots = {},
		Rev = nil,
		RevReady = false,
		RevBlend = 0,
		LegacyStopped = false,
		EngineDuck = 1,
		BoostScale = 1,
	}
	graph.Feel = feel
	-- Rev layer players: the local driver gets both load sets and the twin copies inside the quality
	-- budget; any other vehicle gets at most three on-load loops.
	local mobile = mobileBudget()
	local budget
	if localRoute then
		budget = math.clamp(math.floor(qualityNumber(mobile and "MaxRevLayerPlayersMobile" or "MaxRevLayerPlayers", mobile and 8 or 14)), 1, 16)
	else
		budget = math.clamp(math.floor(qualityNumber("MaxRemoteRevLayerPlayers", 3)), 1, 3)
	end
	local layers = {}
	for _, layer in ipairs(tuning.RevLayers) do
		if localRoute or layer.Load ~= "Off" then table.insert(layers, layer) end
	end
	if #layers > budget then
		-- Over budget: the off-load set goes first, then the ladder is thinned evenly.
		local onLoad = {}
		for _, layer in ipairs(layers) do
			if layer.Load ~= "Off" then table.insert(onLoad, layer) end
		end
		layers = thinned(#onLoad > 0 and onLoad or layers, budget)
	end
	if #layers > 0 then
		local rev = { Voices = {}, OnLadder = {}, OffLadder = {}, OnWeights = {}, OffWeights = {} }
		local hasOn, hasOff = false, false
		for _, layer in ipairs(layers) do
			local voice = newFeelVoice(graph, "Rev_" .. layer.Name, layer.AssetId, true)
			if voice then
				voice.Layer = layer
				voice.Load = localRoute and layer.Load or "Any"
				voice.Frequency = tuning.RevPitchBase + (1 - tuning.RevPitchBase) * layer.Rev
				voice.LogFrequency = math.log(voice.Frequency)
				voice.Detune = 1
				if voice.Load == "On" then hasOn = true elseif voice.Load == "Off" then hasOff = true end
				table.insert(rev.Voices, voice)
				budget -= 1
			end
		end
		for _, voice in ipairs(rev.Voices) do
			-- A load set with no partner set plays at every load.
			if (voice.Load == "On" and not hasOff) or (voice.Load == "Off" and not hasOn) then voice.Load = "Any" end
			if voice.Load ~= "Off" then table.insert(rev.OnLadder, voice) end
			if voice.Load ~= "On" then table.insert(rev.OffLadder, voice) end
		end
		-- Opposite detune on neighbouring loops keeps an overlap from cancelling.
		local detune = tuning.RevNeighbourDetune
		for index, voice in ipairs(rev.OnLadder) do voice.Detune = 1 + (index % 2 == 0 and detune or -detune) end
		for index, voice in ipairs(rev.OffLadder) do
			if voice.Load == "Off" then voice.Detune = 1 + (index % 2 == 0 and detune or -detune) end
		end
		local twinGain = tuning.TwinEngineGain
		local twinAllowed = localRoute and twinGain > 0 and tuning.TwinEngineDetune > 0
			and quality:GetAttribute("TwinEngineEnabled") ~= false
			and (not mobile or quality:GetAttribute("TwinEngineOnMobile") == true)
		if twinAllowed then
			for _, voice in ipairs(rev.OnLadder) do
				if budget <= 0 then break end
				if voice.Layer.Twin then
					local twin = newFeelVoice(graph, "RevTwin_" .. voice.Layer.Name, voice.Layer.AssetId, true)
					if twin then
						twin.StartFraction = 0.37
						voice.Twin = twin
						voice.TwinShare = 1 / math.sqrt(1 + twinGain * twinGain)
						budget -= 1
					end
				end
			end
		end
		feel.Rev = rev
	end
	if localRoute then
		for _, name in ipairs(Catalog.FeelLoopLayers) do feel.Loops[name] = newFeelVoice(graph, name, profile.Assets[name], true) end
		for _, name in ipairs(Catalog.FeelOneShotLayers) do feel.OneShots[name] = newFeelVoice(graph, name, profile.Assets[name], false) end
	end
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
		FeelVoices = {},
		Feel = nil,
		FeelGlobal = feelGloballyEnabled(),
		ProfileRevision = profile.Folder:GetAttribute("ProfileRevision"),
	}
	if route == "External" then
		local emitter = Instance.new("AudioEmitter")
		emitter.Name = "VehicleAudioEmitter_Runtime"
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
	local feelWanted = tier == "Detailed" and profile.Feel ~= nil and graph.FeelGlobal
	local revDriven = feelWanted and #profile.Feel.RevLayers > 0
	for _, layerName in ipairs(wanted) do
		if route == "External" and layerName == "DriverWind" then continue end
		-- An external rev graph keeps only the speed-shaped engine loops beside its reduced rev set. Those loops
		-- stay the engine voice until a rev layer has loaded (updateFeel hands over), so a rev asset that never
		-- loads leaves the standard engine in place.
		if revDriven and route == "External" and not Catalog.RevSupersededLayers[layerName] then continue end
		local layer = newRoutedSource(graph, layerName, profile.Assets[layerName] or "", true, profile.Pitches[layerName], route, graph.Emitter)
		if layer then graph.Layers[layerName] = layer end
	end
	if feelWanted and (route == "Internal" or revDriven) then buildFeel(graph) end
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
-- Local startup is deliberately separate from the replaceable per-vehicle graph:
-- loading ducking and External -> Internal route rebuilds cannot cut it off.
local function loadingPresentationActive()
	local playerScripts = localPlayer:FindFirstChild("PlayerScripts")
	local client = playerScripts and game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):FindFirstChild("Runtime")
	local controllers = client and game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):FindFirstChild("Runtime")
	local ui = controllers and game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):FindFirstChild("UI")
	local state = ui and game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI"):FindFirstChild("LoadingPresentationState")
	return (state ~= nil and state:GetAttribute("Active") == true)
		or localPlayer:GetAttribute("FirstDrivePresentationPending")==true
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
		print("[Audio] reliable ignition prepared for " .. state.Vehicle:GetFullName())
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
		print("[Audio] reliable ignition playback confirmed for " .. state.Vehicle:GetFullName())
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
			warn(("[Audio] reliable ignition failed to start after %d attempts for %s"):format(handle.PlayAttempts, state.Vehicle:GetFullName()))
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
	if not ok and global:GetAttribute("DebugReliableIgnition") == true then warn("[Audio] ignition Play failed: " .. tostring(problem)) end
	if not handle.LifetimeScheduled then
		handle.LifetimeScheduled = true
		task.delay(math.max(2, Catalog.GlobalNumber("OneShotMaxLifetimeSeconds", 12)), function()
			if state.LocalIgnitionCue == handle then cleanupLocalIgnition(state) end
		end)
	end
	task.defer(function() confirmLocalIgnition(state, handle) end)
	if global:GetAttribute("DebugReliableIgnition") == true then
		print(("[Audio] reliable ignition play requested attempt %d for %s"):format(handle.PlayAttempts, state.Vehicle:GetFullName()))
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
		Ignition = tostring(vehicle:GetAttribute("AudioIgnition") or Contract.Defaults.Ignition),
		Drive = tostring(vehicle:GetAttribute("AudioDrive") or Contract.Defaults.Drive),
		Drift = tostring(vehicle:GetAttribute("AudioDrift") or Contract.Defaults.Drift),
		Boost = tostring(vehicle:GetAttribute("AudioBoost") or Contract.Defaults.Boost),
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

local function smoothstep(first, last, value)
	local alpha = rangeAlpha(value, first, last)
	return alpha * alpha * (3 - 2 * alpha)
end

local function follow(current, target, dt, seconds)
	return current + (target - current) * (1 - math.exp(-dt / math.max(0.001, seconds)))
end

-- Slow mean-reverting noise with a spread of about one, so a steady loop never sounds static.
local function stepLife(value, dt, seconds)
	local theta = math.min(0.5, dt / seconds)
	local gaussian = math.sqrt(-2 * math.log(1 - math.random())) * math.cos(2 * math.pi * math.random())
	return math.clamp(value - value * theta + math.sqrt(2 * theta) * gaussian, -2.5, 2.5)
end

local function playerReady(player)
	local ok, ready = pcall(function() return player.IsReady end)
	return not ok or ready == true
end

-- Moves a feel loop toward its gain and sets its pitch. A voice silent for voiceSleepSeconds stops
-- playing; an asset that has not loaded is skipped until it has.
local function driveVoice(voice, target, pitch, dt, riseSeconds, fallSeconds)
	if not voice then return end
	target = math.max(0, target)
	voice.Gain = follow(voice.Gain, target, dt, target > voice.Gain and riseSeconds or fallSeconds)
	if target <= 0 and voice.Gain < 0.0005 then voice.Gain = 0 end
	if voice.Gain > 0 then
		voice.Silent = 0
		if not voice.Playing then
			if playerReady(voice.Player) then
				if voice.StartFraction then
					pcall(function() voice.Player.TimePosition = voice.Player.TimeLength * voice.StartFraction end)
				end
				pcall(function() voice.Player:Play() end)
				voice.Playing = true
			else
				voice.Gain = 0
			end
		end
		if voice.Playing then voice.Player.PlaybackSpeed = math.clamp(pitch, 0.5, 2) end
	elseif voice.Playing then
		voice.Silent += dt
		if voice.Silent >= voiceSleepSeconds then
			pcall(function() voice.Player:Stop() end)
			voice.Playing = false
		end
	end
	-- Bus.SetGain looks its SoundGroup up on every call, so a change under about 0.1 dB is not written.
	local change = math.abs(voice.Gain - voice.Applied)
	if change > math.max(0.002, voice.Applied * 0.012) or (voice.Gain == 0 and voice.Applied ~= 0) then
		voice.Applied = voice.Gain
		Bus.SetGain(voice.Fader, voice.Gain)
	end
end

-- Restarts a feel one-shot from its beginning. Its player already exists, so nothing is created per event.
local function fireVoice(voice, gain, pitch)
	if not voice or gain <= 0 or not playerReady(voice.Player) then return false end
	voice.Player.PlaybackSpeed = math.clamp(pitch, 0.5, 2)
	Bus.SetGain(voice.Fader, gain)
	pcall(function()
		voice.Player:Stop()
		voice.Player.TimePosition = 0
		voice.Player:Play()
	end)
	return true
end

local function feelOneShotGain(graph, layerName)
	return (graph.Profile.Gains[layerName] or 0.5) * routeMultiplier(graph, true)
end

local function feelPitch(graph, layerName, alpha)
	local range = graph.Profile.PitchRanges[layerName]
	local base = graph.Profile.Pitches[layerName] or 1
	if not range then return base end
	return base * (range.Min + (range.Max - range.Min) * math.clamp(alpha, 0, 1))
end

-- Equal-power crossfade between the two loops either side of the engine frequency, in the log domain.
local function ladderWeights(ladder, logFrequency, weights)
	local count = #ladder
	if count == 0 then return end
	if count == 1 or logFrequency <= ladder[1].LogFrequency then weights[ladder[1]] = 1; return end
	if logFrequency >= ladder[count].LogFrequency then weights[ladder[count]] = 1; return end
	for index = 1, count - 1 do
		local lower, upper = ladder[index], ladder[index + 1]
		if logFrequency <= upper.LogFrequency then
			local span = upper.LogFrequency - lower.LogFrequency
			local alpha = span > 0 and (logFrequency - lower.LogFrequency) / span or 1
			weights[lower] = math.cos(alpha * HALF_PI)
			weights[upper] = math.sin(alpha * HALF_PI)
			return
		end
	end
end

local impactTiers = { "ImpactLight", "ImpactMedium", "ImpactHeavy", "ImpactSevere" }
local impactTierStuds = { 9, 25, 55, 110 }

local function playImpact(graph, strength)
	local feel = graph.Feel
	local now = os.clock()
	if now - feel.State.LastImpactAt < math.max(0, Catalog.GlobalNumber("ImpactMinIntervalSeconds", 0.12)) then return end
	local tier = 0
	for index, name in ipairs(impactTiers) do
		if strength >= Catalog.GlobalNumber(name .. "Studs", impactTierStuds[index]) then tier = index end
	end
	if tier == 0 then return end
	-- An empty tier borrows the nearest populated one, lighter first.
	local chosen
	for index = tier, 1, -1 do
		if feel.OneShots[impactTiers[index]] then chosen = index; break end
	end
	if not chosen then
		for index = tier + 1, #impactTiers do
			if feel.OneShots[impactTiers[index]] then chosen = index; break end
		end
	end
	if not chosen then return end
	local floor = Catalog.GlobalNumber(impactTiers[tier] .. "Studs", impactTierStuds[tier])
	local ceiling = tier < #impactTiers and Catalog.GlobalNumber(impactTiers[tier + 1] .. "Studs", impactTierStuds[tier + 1]) or floor * 2
	local name = impactTiers[chosen]
	local gain = feelOneShotGain(graph, name) * (0.65 + 0.35 * rangeAlpha(strength, floor, ceiling))
	local pitch = (graph.Profile.Pitches[name] or 1) * (0.96 + 0.08 * math.random())
	if fireVoice(feel.OneShots[name], gain, pitch) then feel.State.LastImpactAt = now end
end

local popLayers = { Pop = { "Pop1", "Pop2", "Pop3", "Pop4" }, Bang = { "Bang1", "Bang2" } }

-- Exhaust pops: each slot has its own persistent voice and the slots are drawn from a shuffled bag, so a
-- run of pops overlaps without retriggering the one still sounding. The producer spaces them.
local function playPop(graph, strength)
	local feel = graph.Feel
	local tuning = graph.Profile.Feel
	if strength <= 0 then return end
	local kind = "Pop"
	if strength >= tuning.PopBangStrength and (feel.OneShots.Bang1 or feel.OneShots.Bang2) then kind = "Bang" end
	local bag = feel.PopBags[kind]
	if #bag == 0 then
		for _, name in ipairs(popLayers[kind]) do
			if feel.OneShots[name] then table.insert(bag, name) end
		end
		for index = #bag, 2, -1 do
			local other = math.random(index)
			bag[index], bag[other] = bag[other], bag[index]
		end
		if #bag > 1 and bag[#bag] == feel.LastPop[kind] then bag[#bag], bag[1] = bag[1], bag[#bag] end
	end
	local name = table.remove(bag)
	if not name then return end
	feel.LastPop[kind] = name
	local jitter = 1 + tuning.PopPitchJitter * (2 * math.random() - 1)
	fireVoice(feel.OneShots[name], feelOneShotGain(graph, name) * strength, (graph.Profile.Pitches[name] or 1) * jitter)
end

-- Continuous drive of the feel voices. updateGraph owns the semantic context (running, held, parked, mix);
-- this owns load, rev, spool, slip and the Feel* events. Missing Feel* attributes fall back to that context.
local function updateFeel(state, dt)
	local graph = state.Graph
	local feel = graph and graph.Feel
	local root = rootFor(state.Vehicle)
	if not (feel and root) then return end
	dt = math.clamp(dt, 0.001, 0.25)
	local vehicle = state.Vehicle
	local tuning = graph.Profile.Feel
	local context = feel.Context
	local f = feel.State
	local localDriver = state.LocalDriver
	local driving = context.DriveMix > 0
	voiceSleepSeconds = math.max(0.25, Catalog.GlobalNumber("FeelVoiceSleepSeconds", 2))
	local fadeIn = Catalog.GlobalNumber("FeelLayerFadeInSeconds", 0.05)
	local fadeOut = Catalog.GlobalNumber("FeelLayerFadeOutSeconds", 0.12)

	local throttle, slip, boostKind, driftCharge, hover
	if localDriver and driving then
		throttle = tonumber(vehicle:GetAttribute("FeelThrottle"))
		slip = tonumber(vehicle:GetAttribute("FeelSlip"))
		driftCharge = tonumber(vehicle:GetAttribute("FeelDriftCharge"))
		hover = tonumber(vehicle:GetAttribute("FeelHover"))
		local kind = vehicle:GetAttribute("FeelBoostKind")
		if typeof(kind) == "string" then boostKind = kind end
	end
	local feelLive = throttle ~= nil
	if boostKind == nil then boostKind = (context.Boosting and not context.Exited) and "Boost" or "" end
	local speedMph = root.AssemblyLinearVelocity.Magnitude * MPH_PER_STUD

	-- Load follower: fast attack, slower release, then an equal-power swap between the thrust and coast sets.
	local loadTarget = 0
	if context.Running and not context.Exited then
		if throttle then
			loadTarget = context.Drive == "Reversing" and math.abs(throttle) * tuning.ReverseLoad or math.max(0, throttle)
		elseif context.Drive == "Accelerating" then
			loadTarget = 1
		elseif context.Drive == "Reversing" then
			loadTarget = tuning.ReverseLoad
		end
	end
	loadTarget = math.clamp(loadTarget, 0, 1)
	f.Load = follow(f.Load, loadTarget, dt, loadTarget > f.Load and tuning.LoadAttackSeconds or tuning.LoadReleaseSeconds)
	f.LoadSlow = follow(f.LoadSlow, f.Load, dt, tuning.BarkSeconds)
	local load = math.clamp(f.Load, 0, 1) ^ tuning.LoadExponent
	local bark = tuning.BarkGain * math.max(0, f.Load - f.LoadSlow)
	local onWeight = math.sin(load * HALF_PI)
	local offWeight = math.cos(load * HALF_PI)

	local boostAmount = boostKind == "Boost" and 1 or (boostKind == "Mini" and tuning.BoostLoopMiniGain or 0)
	feel.BoostScale = boostKind == "Mini" and tuning.BoostLoopMiniGain or 1
	local revTarget = 0
	if context.Running then
		revTarget = math.clamp(tuning.RevThrottleWeight * load + tuning.RevSpeedWeight * speedMph / tuning.RevReferenceMph + tuning.RevBoostWeight * boostAmount, 0, 1)
	end
	f.Rev = follow(f.Rev, revTarget, dt, revTarget > f.Rev and tuning.RevRiseSeconds or tuning.RevFallSeconds)
	local revValue = f.Rev

	local lifePitch, lifeLevel = 1, 1
	if localDriver then
		f.LifePitch = stepLife(f.LifePitch, dt, tuning.LifeSeconds)
		f.LifeLevel = stepLife(f.LifeLevel, dt, tuning.LifeSeconds)
		lifePitch = 1 + tuning.LifePitchDepth * f.LifePitch
		lifeLevel = 10 ^ (tuning.LifeLevelDb * f.LifeLevel / 20)
	end

	-- Stabiliser strain rises with sideways slip; the engine ducks under it.
	local slipAmount = math.abs(slip or 0)
	if context.Drifting then slipAmount = math.max(slipAmount, tuning.SlipDriftFloor) end
	local slipIntensity = driving and smoothstep(tuning.SlipStart, tuning.SlipFull, slipAmount) or 0
	local duckTarget = feel.Loops.SlipStrain and slipIntensity or 0
	f.Duck = follow(f.Duck, duckTarget, dt, duckTarget > f.Duck and tuning.SlipDuckInSeconds or tuning.SlipDuckOutSeconds)
	-- The engine also steps back a little under a boost that has its own loop, so the boost reads clearly.
	local boostDuckTarget = (boostAmount > 0 and (graph.Layers.BoostLoop or feel.Loops.BoostBody)) and 1 or 0
	f.BoostDuck = follow(f.BoostDuck, boostDuckTarget, dt, boostDuckTarget > f.BoostDuck and tuning.BoostDuckInSeconds or tuning.BoostDuckOutSeconds)
	feel.EngineDuck = 10 ^ (-(tuning.SlipDuckDb * f.Duck + tuning.BoostDuckDb * f.BoostDuck) / 20)

	local engineFade
	if context.Exited then
		engineFade = Catalog.GlobalNumber(context.EngineMix > f.EngineMix and "ParkedFadeInSeconds" or "ParkedFadeOutSeconds", context.EngineMix > f.EngineMix and 0.2 or 0.3)
	else
		engineFade = fadeSeconds("Idle", context.EngineMix > f.EngineMix)
	end
	f.EngineMix = follow(f.EngineMix, context.EngineMix, dt, engineFade)
	if context.EngineMix <= 0 and f.EngineMix < 0.0005 then f.EngineMix = 0 end

	local rev = feel.Rev
	if rev then
		local frequency = tuning.RevPitchBase + (1 - tuning.RevPitchBase) * revValue
		local logFrequency = math.log(frequency)
		table.clear(rev.OnWeights)
		table.clear(rev.OffWeights)
		ladderWeights(rev.OnLadder, logFrequency, rev.OnWeights)
		ladderWeights(rev.OffLadder, logFrequency, rev.OffWeights)
		-- The speed-shaped engine loops stay the voice until one rev layer has loaded, then the two swap
		-- equal-power over RevHandoverSeconds. If none ever loads, RevBlend stays 0.
		if not feel.RevReady then
			f.ReadyCheck += dt
			if f.ReadyCheck >= 0.2 then
				f.ReadyCheck = 0
				for _, voice in ipairs(rev.Voices) do
					if playerReady(voice.Player) then feel.RevReady = true; break end
				end
			end
		end
		if feel.RevReady and feel.RevBlend < 1 then
			feel.RevBlend = math.min(1, feel.RevBlend + dt / math.max(0.01, Catalog.GlobalNumber("RevHandoverSeconds", 0.4)))
		end
		local engineGain = f.EngineMix * tuning.RevMasterGain * feel.EngineDuck * lifeLevel * math.sin(feel.RevBlend * HALF_PI)
		local smoothing = Catalog.GlobalNumber("RevLayerSmoothingSeconds", 0.025)
		for _, voice in ipairs(rev.Voices) do
			local layer = voice.Layer
			local on, off = rev.OnWeights[voice] or 0, rev.OffWeights[voice] or 0
			local weight
			if voice.Load == "On" then
				weight = on * onWeight * (1 + bark)
			elseif voice.Load == "Off" then
				weight = off * offWeight
			else
				-- One loop in both sets is the same signal, so its two shares add linearly.
				weight = on * onWeight * onWeight * (1 + bark) + off * offWeight * offWeight * tuning.RevOffLoadGain
			end
			local gain = layer.Gain * weight * engineGain
			local pitch = math.clamp(layer.Pitch * frequency / voice.Frequency, layer.PitchMin, layer.PitchMax) * voice.Detune
			if voice.Twin then
				-- Twin engine: a second copy slightly sharp, drifting the opposite way, beats against the first.
				driveVoice(voice, gain * voice.TwinShare, pitch * lifePitch, dt, smoothing, smoothing * 2)
				driveVoice(voice.Twin, gain * voice.TwinShare * tuning.TwinEngineGain, pitch * (1 + tuning.TwinEngineDetune) * (2 - lifePitch), dt, smoothing, smoothing * 2)
			else
				driveVoice(voice, gain, pitch * lifePitch, dt, smoothing, smoothing * 2)
			end
		end
	end
	if not localDriver then return end

	-- Forced induction: spool rises with load and rev, falls on lift; a lift after sustained load, or the
	-- end of a boost, vents it through the blow-off.
	local driveMix = context.DriveMix
	local spoolTarget = driving and math.max(load * (tuning.TurboSpoolRevFloor + (1 - tuning.TurboSpoolRevFloor) * revValue), boostAmount) or 0
	f.Spool = follow(f.Spool, spoolTarget, dt, spoolTarget > f.Spool and tuning.TurboSpoolUpSeconds or tuning.TurboSpoolDownSeconds)
	local now = os.clock()
	local lifted = loadTarget <= tuning.BlowOffLiftThreshold
	local boostEnded = f.BoostKind ~= nil and f.BoostKind ~= "" and boostKind == ""
	if (lifted and f.LoadHeld >= tuning.BlowOffMinLoadSeconds) or (boostEnded and Catalog.GlobalNumber("BoostEndVent", 0) > 0) then
		if driving and f.Spool >= tuning.BlowOffMinSpool and now - f.LastBlowOffAt >= tuning.BlowOffMinIntervalSeconds then
			-- Below FlutterBelowSpool the vent is the flutter; either slot stands in for the other when one is empty.
			local vent = "BlowOff"
			if not feel.OneShots.BlowOff or (f.Spool < tuning.FlutterBelowSpool and feel.OneShots.TurboFlutter) then vent = "TurboFlutter" end
			if fireVoice(feel.OneShots[vent], feelOneShotGain(graph, vent) * f.Spool, graph.Profile.Pitches[vent] or 1) then
				f.LastBlowOffAt = now
				f.Spool *= tuning.BlowOffSpoolKeep
			end
		end
		if lifted then f.LoadHeld = 0 end
	elseif loadTarget >= tuning.BlowOffLoadThreshold then
		f.LoadHeld += dt
	elseif lifted then
		f.LoadHeld = 0
	end
	local spool = math.clamp(f.Spool, 0, 1)
	driveVoice(feel.Loops.TurboWhistle, graph.Profile.Gains.TurboWhistle * spool ^ tuning.TurboGainExponent * driveMix, feelPitch(graph, "TurboWhistle", spool), dt, fadeIn, fadeOut)
	driveVoice(feel.Loops.SuperchargerWhine, graph.Profile.Gains.SuperchargerWhine * revValue ^ tuning.SuperchargerGainExponent
		* (tuning.SuperchargerOffLoadGain + (1 - tuning.SuperchargerOffLoadGain) * load) * driveMix, feelPitch(graph, "SuperchargerWhine", revValue), dt, fadeIn, fadeOut)
	-- Turbine: two loops an octave apart. Pitch climbs TurbineOctaves over the rev range and the pair
	-- crossfades equal-power across the octave between them.
	local turbineGain = smoothstep(tuning.TurbineStartRev, 1, revValue) * (tuning.TurbineOffLoadGain + (1 - tuning.TurbineOffLoadGain) * load) * driveMix
	local turbineOctave = tuning.TurbineOctaveStart + tuning.TurbineOctaves * revValue
	local turbineBlend = feel.Loops.TurbineHigh and 1 or 0
	if feel.Loops.TurbineLow and feel.Loops.TurbineHigh then turbineBlend = math.clamp(turbineOctave, 0, 1) end
	driveVoice(feel.Loops.TurbineLow, graph.Profile.Gains.TurbineLow * turbineGain * math.cos(turbineBlend * HALF_PI),
		(graph.Profile.Pitches.TurbineLow or 1) * 2 ^ turbineOctave, dt, fadeIn, fadeOut)
	driveVoice(feel.Loops.TurbineHigh, graph.Profile.Gains.TurbineHigh * turbineGain * math.sin(turbineBlend * HALF_PI),
		(graph.Profile.Pitches.TurbineHigh or 1) * 2 ^ (turbineOctave - 1), dt, fadeIn, fadeOut)
	driveVoice(feel.Loops.EnergyHum, graph.Profile.Gains.EnergyHum * math.max(0, 1 + tuning.EnergyHumHoverGain * math.clamp(hover or 0, -1, 1)) * driveMix,
		feelPitch(graph, "EnergyHum", speedMph / tuning.RevReferenceMph), dt, fadeIn, fadeOut)
	driveVoice(feel.Loops.SlipStrain, graph.Profile.Gains.SlipStrain * slipIntensity * driveMix, feelPitch(graph, "SlipStrain", slipIntensity), dt, fadeIn, fadeOut)
	driveVoice(feel.Loops.BoostBody, graph.Profile.Gains.BoostBody * boostAmount * driveMix, feelPitch(graph, "BoostBody", revValue), dt,
		tuning.BoostFadeInSeconds, fadeSeconds("BoostLoop", false))
	driveVoice(feel.Loops.WindBuffet, graph.Profile.Gains.WindBuffet * smoothstep(tuning.WindBuffetStartMph, tuning.WindBuffetFullMph, speedMph) * driveMix,
		feelPitch(graph, "WindBuffet", rangeAlpha(speedMph, tuning.WindBuffetStartMph, tuning.WindBuffetFullMph)), dt, fadeSeconds("DriverWind", true), fadeSeconds("DriverWind", false))

	-- Drift charge: a tone that climbs with the charge, then a release when the mini-boost fires.
	local charge = driving and math.clamp(driftCharge or 0, 0, 1) or 0
	if charge > 0 then
		f.DriftChargePeak = math.max(f.DriftChargePeak, charge)
		f.DriftChargeIdle = 0
	else
		f.DriftChargeIdle += dt
		if f.DriftChargeIdle > 0.5 then f.DriftChargePeak = 0 end
	end
	driveVoice(feel.Loops.DriftCharge, graph.Profile.Gains.DriftCharge * smoothstep(tuning.DriftChargeStart, math.max(tuning.DriftChargeStart + 0.01, tuning.DriftChargeFull), charge) * driveMix,
		feelPitch(graph, "DriftCharge", charge), dt, fadeIn, fadeOut)
	if driving and f.BoostKind == "" and boostKind ~= "" then
		local mini = boostKind == "Mini"
		fireVoice(feel.OneShots.BoostIgnition, feelOneShotGain(graph, "BoostIgnition") * (mini and tuning.BoostIgnitionMiniGain or 1),
			(graph.Profile.Pitches.BoostIgnition or 1) * (mini and tuning.BoostIgnitionMiniPitch or 1))
		if mini then
			fireVoice(feel.OneShots.DriftChargeRelease, feelOneShotGain(graph, "DriftChargeRelease") * math.max(0.4, f.DriftChargePeak), graph.Profile.Pitches.DriftChargeRelease or 1)
			f.DriftChargePeak = 0
		end
	end
	f.BoostKind = boostKind

	-- Impacts and landings arrive as revision counters. The first value seen is a baseline, not an event.
	if not feelLive then
		f.ImpactRevision, f.LandRevision, f.PopRevision = nil, nil, nil
		return
	end
	local popRevision = tonumber(vehicle:GetAttribute("FeelPopRevision")) or 0
	if f.PopRevision == nil then
		f.PopRevision = popRevision
	elseif popRevision ~= f.PopRevision then
		f.PopRevision = popRevision
		playPop(graph, math.clamp(tonumber(vehicle:GetAttribute("FeelPopStrength")) or 0, 0, 1))
	end
	local impactRevision = tonumber(vehicle:GetAttribute("FeelImpactRevision")) or 0
	if f.ImpactRevision == nil then
		f.ImpactRevision = impactRevision
	elseif impactRevision ~= f.ImpactRevision then
		f.ImpactRevision = impactRevision
		playImpact(graph, tonumber(vehicle:GetAttribute("FeelImpactStrength")) or 0)
	end
	local landRevision = tonumber(vehicle:GetAttribute("FeelLandRevision")) or 0
	if f.LandRevision == nil then
		f.LandRevision = landRevision
	elseif landRevision ~= f.LandRevision then
		f.LandRevision = landRevision
		local strength = tonumber(vehicle:GetAttribute("FeelLandStrength")) or 0
		if strength >= tuning.LandMinStuds then
			local scale = tuning.LandMinGain + (1 - tuning.LandMinGain) * rangeAlpha(strength, tuning.LandMinStuds, tuning.LandFullStuds)
			fireVoice(feel.OneShots.LandingThump, feelOneShotGain(graph, "LandingThump") * scale, graph.Profile.Pitches.LandingThump or 1)
		end
	end
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
		local cueRevision = tonumber(state.Vehicle:GetAttribute("AudioCueRevision")) or 0
		if cueRevision > (state.LastRemoteCueRevision or 0) then
			state.LastRemoteCueRevision = cueRevision
			local candidate = tostring(state.Vehicle:GetAttribute("AudioCue") or "")
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
		and state.Vehicle:GetAttribute("ExitCoasting") == true
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
	local engineHeld = holdLocalEngineLoopsForIgnition(state) or (state.LocalDriver and localPlayer:GetAttribute("FirstDrivePresentationPending")==true)
	if engineHeld then
		idleTarget, engineLowTarget, engineHighTarget, coastTarget = 0, 0, 0, 0
	end
	local feel = graph.Feel
	local standardEngine = (feel and feel.Rev) and math.cos(feel.RevBlend * HALF_PI) or 1
	setTarget(graph, "Idle", idleTarget * standardEngine)
	setTarget(graph, "EngineLow", engineLowTarget * standardEngine)
	setTarget(graph, "EngineHigh", engineHighTarget * standardEngine)
	local firstDriveHeld=state.LocalDriver and localPlayer:GetAttribute("FirstDrivePresentationPending")==true
	setTarget(graph, "Acceleration", firstDriveHeld and 0 or (exitedPresentation and 0 or (accelerating and gains.Acceleration * mix or 0)))
	setTarget(graph, "Coast", coastTarget)
	setTarget(graph, "DriftLoop", firstDriveHeld and 0 or (exitedPresentation and 0 or (drifting and gains.DriftLoop * driftGainMultiplier * mix or 0)))
	setTarget(graph, "BoostLoop", firstDriveHeld and 0 or (exitedPresentation and 0 or (boosting and gains.BoostLoop * (feel and feel.BoostScale or 1) * mix or 0)))
	local windAlpha = rangeAlpha(speedMph, Catalog.GlobalNumber("WindStartMph", 18), Catalog.GlobalNumber("WindFullGainMph", 128))
	if feel then
		-- Feel profile: wind grows with the power curve (speed / DriverWindFullMph) ^ DriverWindExponent from DriverWindStartMph.
		local tuning = graph.Profile.Feel
		windAlpha = math.clamp(speedMph / tuning.DriverWindFullMph, 0, 1) ^ tuning.DriverWindExponent
			* rangeAlpha(speedMph, tuning.DriverWindStartMph * 0.6, tuning.DriverWindStartMph)
	end
	setTarget(graph, "DriverWind", firstDriveHeld and 0 or (state.LocalDriver and gains.DriverWind * windAlpha * mix or 0))
	for layerName, layer in pairs(graph.Layers) do
		local rising = layer.Target > layer.Gain
		local seconds = exitedPresentation and Catalog.GlobalNumber(rising and "ParkedFadeInSeconds" or "ParkedFadeOutSeconds", rising and 0.2 or 0.3) or fadeSeconds(layerName, rising)
		if feel and rising and layerName == "BoostLoop" then seconds = graph.Profile.Feel.BoostFadeInSeconds end
		local alpha = 1 - math.exp(-dt / seconds)
		layer.Gain += (layer.Target - layer.Gain) * alpha
		local revPitch = feel and graph.Profile.RevPitches[layerName]
		Bus.SetGain(layer.Fader, (feel and layerName == "Acceleration") and layer.Gain * feel.EngineDuck or layer.Gain)
		if revPitch then
			layer.Player.PlaybackSpeed = math.clamp((graph.Profile.Pitches[layerName] or 1) * (revPitch.Min + (revPitch.Max - revPitch.Min) * feel.State.Rev), 0.5, 2)
		elseif feel and layerName == "DriverWind" then
			local tuning = graph.Profile.Feel
			local multiplier = tuning.DriverWindSpeedPitchMin + (tuning.DriverWindSpeedPitchMax - tuning.DriverWindSpeedPitchMin) * math.clamp(speedMph / tuning.DriverWindFullMph, 0, 1)
			layer.Player.PlaybackSpeed = math.clamp((graph.Profile.Pitches.DriverWind or 1) * multiplier, 0.5, 2)
		elseif layerName == "EngineLow" then
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
	if feel then
		-- The rev engine takes the gain the speed-shaped engine loops would have had in each presentation.
		local engineMix = running and mix or 0
		if exitedPresentation and not parkedAudioEnabled then
			engineMix = 0
		elseif exitCoasting then
			engineMix = mix * Catalog.GlobalNumber("ExitCoastGainMultiplier", 1) * Catalog.GlobalNumber("ExitCoastEngineLowGainMultiplier", 0.45)
		elseif parked then
			engineMix = mix * Catalog.GlobalNumber("ParkedIdleGainMultiplier", 0.75)
		end
		local context = feel.Context
		context.Running = running
		context.Drive = semantic.Drive
		context.Drifting = drifting
		context.Boosting = boosting
		context.Exited = exitedPresentation
		context.EngineMix = engineHeld and 0 or engineMix
		context.DriveMix = (running and not exitedPresentation and not engineHeld) and mix or 0
		-- The local driver's feel voices are stepped from Heartbeat at LocalFeelUpdateHz instead.
		if not state.LocalDriver then updateFeel(state, dt) end
		-- Once the rev layers have taken over and the standard engine loops have faded, their players stop.
		if feel.Rev and feel.RevBlend >= 1 and not feel.LegacyStopped then
			local silent = true
			for name in pairs(Catalog.RevSupersededLayers) do
				local layer = graph.Layers[name]
				if layer and layer.Gain > 0.001 then silent = false end
			end
			if silent then
				feel.LegacyStopped = true
				for name in pairs(Catalog.RevSupersededLayers) do
					local layer = graph.Layers[name]
					if layer then pcall(function() layer.Player:Stop() end) end
				end
			end
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
	local mobile = mobileBudget()
	localFeelInterval = 1 / math.clamp(qualityNumber(mobile and "LocalFeelUpdateHzMobile" or "LocalFeelUpdateHz", mobile and 30 or 60), 1, 240)
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
		-- A feel profile rebuilds when the global switch flips or its ProfileRevision is edited.
		local graph = state.Graph
		local feelChanged = graph ~= nil and graph.Profile.Feel ~= nil
			and (graph.FeelGlobal ~= feelGloballyEnabled() or graph.ProfileRevision ~= graph.Profile.Folder:GetAttribute("ProfileRevision"))
		local desiredTier = enabled() and (state.NextTier or "Silent") or "Silent"
		if state.ForceRefresh or profileChanged or feelChanged or state.Tier ~= desiredTier or state.Route ~= state.NextRoute then
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
	runtimeRoot = SoundService:FindFirstChild("AudioRuntime_Local")
	if runtimeRoot then runtimeRoot:Destroy() end
	runtimeRoot = Instance.new("Folder")
	runtimeRoot.Name = "AudioRuntime_Local"
	runtimeRoot.Parent = SoundService
	ensureOutputGraph()
	local root = vehiclesRoot()
	if not root then warn("[VehicleAudioClient] PlayerVehicles runtime root missing; vehicle audio is inactive.") return Controller end
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
		feelAccumulator += dt
		if feelAccumulator >= localFeelInterval then
			local feelStep = feelAccumulator; feelAccumulator = 0
			for _, state in pairs(tracked) do
				if state.LocalDriver and state.Graph and state.Graph.Feel then updateFeel(state, feelStep) end
			end
		end
		if updateAccumulator >= updateInterval then
			local step = updateAccumulator; updateAccumulator = 0
			for _, state in pairs(tracked) do
				if state.Graph then
					updateGraph(state, step)
				elseif state.LocalDriver then
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
	local vehicles, graphs, feelVoices = 0, 0, 0
	for _, state in pairs(tracked) do
		vehicles += 1
		if state.Graph then graphs += 1; feelVoices += #state.Graph.FeelVoices end
	end
	return { Vehicles = vehicles, Graphs = graphs, VehicleFaders = Bus.Count("Vehicle"), FeelVoices = feelVoices }
end

return Controller
