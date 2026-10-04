-- Canonical feature implementation; startup is owned by the composition root.
local Runtime = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LOCAL_PLAYER = Players.LocalPlayer

local DEFAULT_THRUST = Color3.fromRGB(255, 255, 255)
local VISUAL_RATE = 1 / 30
local SCAN_RATE = 0.5
local UI_RATE = 0.2

local connection
local visualTimer = 0
local scanTimer = 0
local uiTimer = 0
local tracked = setmetatable({}, { __mode = "k" })
local raceVisibilityActive = false 
local raceParticipants = {}
local raceEvent = nil


local function newWeakSet()
	return setmetatable({}, { __mode = "k" })
end

local controls
local controlsDisabled = false

local kit = game:GetService("ReplicatedStorage")
local VehicleCosmetics = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehicleCosmeticCatalog")) 
local templates = game:GetService("ReplicatedStorage"):WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("VehicleTemplates")
local vfxControllerModule
pcall(function()
	vfxControllerModule = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehiclePreviewVFXClient"))
end)

-- Hover feel: continuous VFX inputs for the local player's driven vehicle.
-- Tunables are attributes on ReplicatedStorage.Config.Vehicles.StabiliserVFX
-- (the folder VehiclePreviewVFXClient already reads); these are the fallbacks.
local FEEL_DEFAULTS = {
	FeelVFXEnabled = true,
	FeelThrottleAttackSeconds = 0.06,
	FeelThrottleReleaseSeconds = 0.28,
	FeelThrottleCutoff = 0.1,
	FeelJetFloor = 0.4,
	FeelBoostPulsePeak = 1.35,
	FeelBoostPulseSeconds = 0.15,
	FeelDriftFloor = 0.45,
	FeelDriftSlipFull = 0.5,
	FeelDustFloor = 0.45,
	FeelDustSpeedGain = 0.5,
	FeelDustSpeedFullMph = 140,
	FeelDustSquashGain = 0.45,
	FeelDustReleaseSeconds = 0.2,
	FeelBrakeMinMph = 25,
	FeelBrakeFullMph = 110,
	FeelBrakeFloor = 0.35,
	FeelImpactMinInterval = 0.12,
	FeelImpactSparksLight = 6,
	FeelImpactSparksMedium = 14,
	FeelImpactSparksHeavy = 26,
	FeelImpactSparksSevere = 40,
	FeelLandMinStuds = 12,
	FeelLandFullStuds = 70,
	FeelLandDustMin = 6,
	FeelLandDustMax = 28,
}
local FEEL_IMPACT_LIGHT = 9
local FEEL_IMPACT_MEDIUM = 25
local FEEL_IMPACT_HEAVY = 55
local FEEL_IMPACT_SEVERE = 110
local FEEL_MPH_PER_STUD = 0.625
local FEEL_LEGACY_HOVER_DUST = 0.45

local feelConfig = table.clone(FEEL_DEFAULTS)

local function refreshFeelConfig()
	local config = ReplicatedStorage:FindFirstChild("Config")
	local vehicles = config and config:FindFirstChild("Vehicles")
	local folder = vehicles and vehicles:FindFirstChild("StabiliserVFX")
	for name, fallback in pairs(FEEL_DEFAULTS) do
		local value = folder and folder:GetAttribute(name)
		if typeof(value) == typeof(fallback) and value == value and value ~= math.huge and value ~= -math.huge then
			feelConfig[name] = value
		else
			feelConfig[name] = fallback
		end
	end
end

local function feelNumber(model, name)
	local value = model:GetAttribute(name)
	if type(value) == "number" and value == value then
		return value
	end
	return nil
end

local function smoothToward(current, target, dt, attackSeconds, releaseSeconds)
	local tau = target > current and attackSeconds or releaseSeconds
	if tau <= 0.001 then return target end
	return current + (target - current) * (1 - math.exp(-dt / tau))
end

local function lower(text)
	return string.lower(tostring(text or ""))
end

local function pathText(instance)
	local parts = {}
	local current = instance
	while current and current ~= Workspace do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return lower(table.concat(parts, "/"))
end

local function pathHas(instance, token)
	return string.find(pathText(instance), lower(token), 1, true) ~= nil
end

local function tableCount(t)
	local count = 0
	for _ in pairs(t) do
		count += 1
	end
	return count
end

local function clearRaceParticipants()
	table.clear(raceParticipants)
end

local function setRaceParticipants(list)
	clearRaceParticipants()
	for _, userId in ipairs(list or {}) do
		raceParticipants[tonumber(userId)] = true
	end
end

local function localIsRaceParticipant()
	return raceParticipants[LOCAL_PLAYER.UserId] == true
end

local function modelOwnerUserId(model)
	return tonumber(model and model:GetAttribute("OwnerUserId"))
end

local function shouldRenderVehicleVFX(model)
	local ownerId = modelOwnerUserId(model)
	local vehicleIsParticipant = ownerId and raceParticipants[ownerId] == true
	local modelClaimsRace = model and model:GetAttribute("RaceParticipant") == true
	if raceVisibilityActive == true then
		if localIsRaceParticipant() then
			return vehicleIsParticipant == true
		end
		return vehicleIsParticipant ~= true and modelClaimsRace ~= true
	end
	return modelClaimsRace ~= true
end

local function isToggleable(object)
	return object:IsA("ParticleEmitter")
		or object:IsA("Beam")
		or object:IsA("Trail")
		or object:IsA("Fire")
		or object:IsA("Smoke")
		or object:IsA("Sparkles")
		or object:IsA("PointLight")
		or object:IsA("SpotLight")
		or object:IsA("SurfaceLight")
end

local function setEnabled(object, enabled)
	if isToggleable(object) and object.Enabled ~= enabled then
		object.Enabled = enabled
	end
end

local function colourObject(object, colour)
	if object:IsA("ParticleEmitter") then
		object.Color = ColorSequence.new(colour)
		object.LockedToPart = true
		object.VelocityInheritance = 0
	elseif object:IsA("Fire") then
		object.Color = colour
		object.SecondaryColor = colour
	elseif object:IsA("Smoke") then
		object.Color = colour
	elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
		object.Color = colour
	end
end

local function resolvePaintChannel(object)
	local current = object
	while current do
		if current.Name == "THRUST_COLOR_WhiteByDefault" then return "ThrustColor" end
		if current.Name == "NEON_OptionalLights" then return "Neon" end
		if current.Name == "PRIMARY_ReplaceWithPrimaryMeshes" then return "Primary" end
		if current.Name == "SECONDARY_ReplaceWithSecondaryMeshes" then return "Secondary" end
		if current.Name == "DETAIL_ReplaceWithDetailMeshes" then return "Detail" end
		current = current.Parent
	end
	current = object
	while current do
		local channel = current:GetAttribute("PaintChannel")
		if typeof(channel) == "string" and channel ~= "" then
			return channel
		end
		current = current.Parent
	end
	return nil
end

local function belongsToThrustModule(object)
	local text = pathText(object)
	return string.find(text, "engine", 1, true) ~= nil
		or string.find(text, "boost", 1, true) ~= nil
		or string.find(text, "stabiliser", 1, true) ~= nil
		or string.find(text, "stabilizer", 1, true) ~= nil
end

local function classifyVFX(object)
	local text = pathText(object)
	if string.find(text, "engineoff_", 1, true) or string.find(text, "engineoff", 1, true) then return "EngineOff" end
	if string.find(text, "engineon_", 1, true) or string.find(text, "engineon", 1, true) then return "EngineOn" end
	if string.find(text, "booston_", 1, true) or string.find(text, "booston", 1, true) then return "BoostOn" end
	if string.find(text, "stabiliseron_", 1, true) or string.find(text, "stabilizeron_", 1, true) or string.find(text, "stabiliseron", 1, true) or string.find(text, "stabilizeron", 1, true) then return "StabiliserOn" end
	return nil
end

local function sideFromName(object)
	local text = pathText(object)
	if string.find(text, "left", 1, true) or string.find(text, "_l", 1, true) then return "Left" end
	if string.find(text, "right", 1, true) or string.find(text, "_r", 1, true) then return "Right" end
	return nil
end

local function worldPosition(object)
	if object:IsA("Attachment") then return object.WorldPosition end
	if object:IsA("BasePart") then return object.Position end
	local parent = object.Parent
	while parent do
		if parent:IsA("Attachment") then return parent.WorldPosition end
		if parent:IsA("BasePart") then return parent.Position end
		parent = parent.Parent
	end
	return nil
end

local function sideFromPosition(model, object)
	local root = model and (model.PrimaryPart or model:FindFirstChild("CockpitRoot_DoNotRename", true))
	local pos = root and worldPosition(object)
	if not (root and pos) then return nil end
	local localX = root.CFrame:PointToObjectSpace(pos).X
	if localX < -0.15 then return "Left" end
	if localX > 0.15 then return "Right" end
	return nil
end

local function getPreviewRoot()
	local clientOnlyRoot = Workspace:FindFirstChild("ClientOnly")
	local dealershipPreview = clientOnlyRoot and clientOnlyRoot:FindFirstChild("VehiclePreview")
	if dealershipPreview then
		return dealershipPreview
	end
	return Workspace:FindFirstChild("LocalVehiclePreview")
end

local function isPreviewModel(model)
	local preview = getPreviewRoot()
	return preview and (model == preview or model:IsDescendantOf(preview))
end

local function controlRootFor(model)
	local preview = getPreviewRoot()
	if preview and (model == preview or model:IsDescendantOf(preview)) then
		return preview
	end
	return model
end

local function readAttr(cache, name)
	local value = cache.Model:GetAttribute(name)
	if value ~= nil then return value end
	if cache.ControlRoot and cache.ControlRoot ~= cache.Model then
		return cache.ControlRoot:GetAttribute(name)
	end
	return nil
end

local function thrustColour(cache)
	local value = readAttr(cache, "ThrustColor")
	if typeof(value) == "Color3" then return value end
	return DEFAULT_THRUST
end

local function runtimeState(cache)
	local forcePreview = readAttr(cache, "ForceThrustPreview") == true
	local driveReady = readAttr(cache, "DriveReady") == true
	local preview = isPreviewModel(cache.Model)
	local ownerUserId = tonumber(cache.Model and cache.Model:GetAttribute("OwnerUserId"))
	local localVehicle = ownerUserId == LOCAL_PLAYER.UserId
	local driving = driveReady or forcePreview
	local accelerating = readAttr(cache, "Accelerating") == true
	local boosting = readAttr(cache, "Boosting") == true
	local driftLeft = readAttr(cache, "DriftingLeft") == true
	local driftRight = readAttr(cache, "DriftingRight") == true

	if preview then
		-- PreviewVFXMode remains the only garage VFX state contract.
		local mode=tostring(readAttr(cache,"PreviewVFXMode") or "Idle")
		local full=mode=="ThrustColour"
		return {
			Driving=true,
			ForcePreview=false,
			Accelerating=full,
			Boosting=full,
			DriftLeft=full,
			DriftRight=full,
			AnyDrift=full,
		}
	end

	if not localVehicle then
		-- Reuse the existing server-validated semantic presentation transport.
		-- Local driving attributes remain immediate; remote vehicles consume
		-- replicated server attributes and still pass through the race VFX gate.
		local ignition=tostring(readAttr(cache,"AudioIgnition") or "Off")
		local drive=tostring(readAttr(cache,"AudioDrive") or "Idle")
		local boost=tostring(readAttr(cache,"AudioBoost") or "Off")
		local drift=tostring(readAttr(cache,"AudioDrift") or "None")
		driving=driveReady or ignition=="Running"
		accelerating=drive=="Accelerating"
		boosting=boost~="Off"
		driftLeft=drift=="Left"
		driftRight=drift=="Right"
	end

	return {
		Driving = driving,
		ForcePreview = false,
		Accelerating = accelerating,
		Boosting = boosting,
		DriftLeft = driftLeft,
		DriftRight = driftRight,
		AnyDrift = driftLeft or driftRight,
		Local = localVehicle,
	}
end

local function stateKey(state)
	return table.concat({
		state.Driving and "1" or "0",
		state.ForcePreview and "1" or "0",
		state.Accelerating and "1" or "0",
		state.Boosting and "1" or "0",
		state.DriftLeft and "1" or "0",
		state.DriftRight and "1" or "0",
	}, ":")
end

local function enabledFor(kind, side, state)
	if state.ForcePreview then return true end
	if kind == "EngineOff" then return state.Driving and not state.Accelerating end
	if kind == "EngineOn" then return state.Driving and state.Accelerating end
	if kind == "BoostOn" then return state.Driving and state.Boosting end
	if kind == "StabiliserOn" then
		if side == "Left" then return state.Driving and state.DriftLeft end
		if side == "Right" then return state.Driving and state.DriftRight end
		return state.Driving and state.AnyDrift
	end
	return nil
end

local function addToSet(set, object)
	if object and object.Parent then
		set[object] = true
	end
end

local function scanOne(cache, object)
	if not (object and object.Parent) then return end
	if cache.Known[object] then return end

	local useful = false

	if object:IsA("BasePart") then
		if resolvePaintChannel(object) == "ThrustColor" and belongsToThrustModule(object) then
			addToSet(cache.ThrustParts, object)
			useful = true
		end
		if pathHas(object, "templatehost_invisible") or object:GetAttribute("TemplateRole") == "VFXHost" then
			addToSet(cache.InvisibleHosts, object)
			useful = true
		end
	end

	local kind = classifyVFX(object)
	if VehicleCosmetics.IsProtectedVehicleLight(object) then kind=nil end
	if kind and isToggleable(object) then
		local side = sideFromName(object) or sideFromPosition(cache.Model, object)
		cache.VFXObjects[object] = {
			Kind = kind,
			Side = side,
		}
		useful = true
		if object:IsA("ParticleEmitter") or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then
			addToSet(cache.ColourObjects, object)
		end
	elseif kind and (object:IsA("ParticleEmitter") or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight")) then
		addToSet(cache.ColourObjects, object)
		useful = true
	end

	if useful then
		cache.Known[object] = true
	end
end


local function scanTree(cache, root)
	scanOne(cache, root)
	for _, descendant in ipairs(root:GetDescendants()) do
		scanOne(cache, descendant)
	end
end

local function forgetObject(cache, object)
	cache.Known[object] = nil
	cache.ThrustParts[object] = nil
	cache.ColourObjects[object] = nil
	cache.InvisibleHosts[object] = nil
	cache.VFXObjects[object] = nil
end

local function forgetTree(cache, root)
	forgetObject(cache, root)
	local ok, descendants = pcall(function()
		return root and root:GetDescendants() or {}
	end)
	if ok then
		for _, descendant in ipairs(descendants) do
			forgetObject(cache, descendant)
		end
	end
end

local function cleanupDead(cache)
	for object in pairs(cache.Known) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.Known[object] = nil
		end
	end
	for object in pairs(cache.ThrustParts) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.ThrustParts[object] = nil
		end
	end
	for object in pairs(cache.ColourObjects) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.ColourObjects[object] = nil
		end
	end
	for object in pairs(cache.InvisibleHosts) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.InvisibleHosts[object] = nil
		end
	end
	for object in pairs(cache.VFXObjects) do
		if not object.Parent or not object:IsDescendantOf(cache.Model) then
			cache.VFXObjects[object] = nil
		end
	end
end


local function applyColour(cache, colour)
	for part in pairs(cache.ThrustParts) do
		if part.Parent then
			if part.Color ~= colour then part.Color = colour end
			if part.Material ~= Enum.Material.Neon then part.Material = Enum.Material.Neon end
			if part.Transparency ~= 0 then part.Transparency = 0 end
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end
	for object in pairs(cache.ColourObjects) do
		if object.Parent then
			colourObject(object, colour)
		end
	end
	for part in pairs(cache.InvisibleHosts) do
		if part.Parent then
			part.Transparency = 1
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end
end

local function attachTemplateController(cache)
	if cache.Controller or not (vfxControllerModule and templates) then return end
	if typeof(vfxControllerModule) ~= "table" or typeof(vfxControllerModule.Attach) ~= "function" then return end
	local ok, controller = pcall(function()
		return vfxControllerModule.Attach(cache.Model, templates, UserInputService.TouchEnabled)
	end)
	if ok and controller then
		cache.Controller = controller
		scanTree(cache, cache.Model)
	end
end

local function feelRoot(cache)
	local root = cache.FeelRoot
	if root and root.Parent then return root end
	root = cache.Model.PrimaryPart or cache.Model:FindFirstChild("CockpitRoot_DoNotRename", true)
	cache.FeelRoot = root
	return root
end

-- Returns the per-vehicle feel memory with this tick's controller inputs, or
-- nil when the vehicle keeps today's boolean behaviour (preview, remote
-- vehicles, not driving, or FeelVFXEnabled = false). Each input falls back to
-- its boolean on its own when its Feel attribute is missing.
local function feelInputs(cache, state, dt)
	if state.Local ~= true or state.Driving ~= true or state.ForcePreview or feelConfig.FeelVFXEnabled ~= true then
		cache.Feel = nil
		return nil
	end

	local model = cache.Model
	local feel = cache.Feel
	if not feel then
		feel = {
			Throttle = state.Accelerating and 1 or 0,
			Dust = FEEL_LEGACY_HOVER_DUST,
			BoostOn = state.Boosting,
			PulseTimer = math.huge,
			ImpactRevision = feelNumber(model, "FeelImpactRevision"),
			LandRevision = feelNumber(model, "FeelLandRevision"),
			LastImpactBurst = 0,
			LastLandBurst = 0,
			ThrottleOut = 0,
			BoostOut = 0,
			DriftLeftOut = 0,
			DriftRightOut = 0,
			DustOut = 0,
			BrakeOut = 0,
		}
		cache.Feel = feel
	end

	-- Throttle: forward part of FeelThrottle, fast attack and slower release.
	local throttle = state.Accelerating and 1 or 0
	local feelThrottle = feelNumber(model, "FeelThrottle")
	if feelThrottle then
		feel.Throttle = smoothToward(
			feel.Throttle,
			math.clamp(feelThrottle, 0, 1),
			dt,
			feelConfig.FeelThrottleAttackSeconds,
			feelConfig.FeelThrottleReleaseSeconds
		)
		throttle = feel.Throttle >= feelConfig.FeelThrottleCutoff and feel.Throttle or 0
	else
		feel.Throttle = throttle
	end
	feel.ThrottleOut = throttle

	-- Boost: 1 while boosting, plus a short ignition pulse above 1.
	local boost = state.Boosting and 1 or 0
	local boostKind = model:GetAttribute("FeelBoostKind")
	if type(boostKind) == "string" then
		local boostOn = state.Boosting or boostKind ~= ""
		if boostOn and not feel.BoostOn then
			feel.PulseTimer = 0
		end
		feel.BoostOn = boostOn
		boost = boostOn and 1 or 0
		local pulseSeconds = feelConfig.FeelBoostPulseSeconds
		if boostOn and pulseSeconds > 0 and feel.PulseTimer < pulseSeconds then
			local peak = math.clamp(feelConfig.FeelBoostPulsePeak, 1, 2)
			boost = 1 + (peak - 1) * (1 - feel.PulseTimer / pulseSeconds)
			feel.PulseTimer += dt
		end
	else
		feel.BoostOn = state.Boosting
	end
	feel.BoostOut = boost

	-- Drift: the side booleans scaled by how hard the car is sliding.
	local driftLeft = state.DriftLeft and 1 or 0
	local driftRight = state.DriftRight and 1 or 0
	local slip = feelNumber(model, "FeelSlip")
	if slip then
		local driftFloor = math.clamp(feelConfig.FeelDriftFloor, 0, 1)
		local slipAlpha = math.clamp(math.abs(slip) / math.max(feelConfig.FeelDriftSlipFull, 0.05), 0, 1)
		local driftScale = driftFloor + (1 - driftFloor) * slipAlpha
		driftLeft *= driftScale
		driftRight *= driftScale
	end
	feel.DriftLeftOut = driftLeft
	feel.DriftRightOut = driftRight

	-- Hover dust: grounded only; more with speed and with hover squash.
	local speedMph = feelNumber(model, "FeelSpeedMph")
	local grounded = model:GetAttribute("FeelGrounded")
	local dust = FEEL_LEGACY_HOVER_DUST
	if type(grounded) == "boolean" then
		local target = 0
		if grounded then
			local speedAlpha = math.clamp((speedMph or 0) / math.max(feelConfig.FeelDustSpeedFullMph, 1), 0, 1)
			local squash = math.clamp(feelNumber(model, "FeelHover") or 0, 0, 1)
			target = math.clamp(
				feelConfig.FeelDustFloor + feelConfig.FeelDustSpeedGain * speedAlpha + feelConfig.FeelDustSquashGain * squash,
				0,
				1
			)
		end
		feel.Dust = smoothToward(feel.Dust, target, dt, 0.05, feelConfig.FeelDustReleaseSeconds)
		dust = feel.Dust >= 0.02 and feel.Dust or 0
	else
		feel.Dust = dust
	end
	feel.DustOut = dust

	-- Brake sparks: the existing Braking attribute, scaled by speed.
	local brake = 0
	if model:GetAttribute("Braking") == true and grounded ~= false then
		if not speedMph then
			local root = feelRoot(cache)
			speedMph = root and root.AssemblyLinearVelocity.Magnitude * FEEL_MPH_PER_STUD or 0
		end
		local minMph = feelConfig.FeelBrakeMinMph
		if speedMph > minMph then
			local brakeFloor = math.clamp(feelConfig.FeelBrakeFloor, 0, 1)
			local speedAlpha = math.clamp((speedMph - minMph) / math.max(feelConfig.FeelBrakeFullMph - minMph, 1), 0, 1)
			brake = brakeFloor + (1 - brakeFloor) * speedAlpha
		end
	end
	feel.BrakeOut = brake

	return feel
end

local function feelRevisionAdvanced(feel, key, revision)
	if revision == nil then return false end
	local last = feel[key]
	feel[key] = revision
	return revision > (last or 0)
end

-- One-off bursts through the template controller's existing emitters:
-- BrakeSparks on an impact, HoverDust on a landing. No instances are created.
local function feelBursts(cache, feel, hiddenByRace)
	local model = cache.Model
	local impact = feelRevisionAdvanced(feel, "ImpactRevision", feelNumber(model, "FeelImpactRevision"))
	local landed = feelRevisionAdvanced(feel, "LandRevision", feelNumber(model, "FeelLandRevision"))
	if hiddenByRace or not (impact or landed) then return end
	local controller = cache.Controller
	if not controller or typeof(controller.Burst) ~= "function" then return end

	local now = os.clock()
	local minInterval = math.max(feelConfig.FeelImpactMinInterval, 0.12)

	if impact and now - feel.LastImpactBurst >= minInterval then
		local strength = feelNumber(model, "FeelImpactStrength") or 0
		local count = 0
		if strength >= FEEL_IMPACT_SEVERE then
			count = feelConfig.FeelImpactSparksSevere
		elseif strength >= FEEL_IMPACT_HEAVY then
			count = feelConfig.FeelImpactSparksHeavy
		elseif strength >= FEEL_IMPACT_MEDIUM then
			count = feelConfig.FeelImpactSparksMedium
		elseif strength >= FEEL_IMPACT_LIGHT then
			count = feelConfig.FeelImpactSparksLight
		end
		if count > 0 then
			feel.LastImpactBurst = now
			pcall(function()
				controller:Burst("Sparks", count)
			end)
		end
	end

	if landed and now - feel.LastLandBurst >= minInterval then
		local strength = feelNumber(model, "FeelLandStrength") or 0
		local minStuds = feelConfig.FeelLandMinStuds
		if strength >= minStuds then
			local alpha = math.clamp((strength - minStuds) / math.max(feelConfig.FeelLandFullStuds - minStuds, 1), 0, 1)
			local count = feelConfig.FeelLandDustMin + (feelConfig.FeelLandDustMax - feelConfig.FeelLandDustMin) * alpha
			feel.LastLandBurst = now
			pcall(function()
				controller:Burst("Dust", count)
			end)
		end
	end
end

local function updateTemplateController(cache, state, dt)
	if not cache.Controller or typeof(cache.Controller.Update) ~= "function" then return end
	local hiddenByRace = shouldRenderVehicleVFX(cache.Model) ~= true 
	local throttle = (not hiddenByRace and state.Accelerating) and 1 or 0
	local boost = (not hiddenByRace and state.Boosting) and 1 or 0
	local drift = (not hiddenByRace and state.AnyDrift) and 1 or 0
	local driftLeft = (not hiddenByRace and state.DriftLeft) and 1 or 0
	local driftRight = (not hiddenByRace and state.DriftRight) and 1 or 0
	local hoverDust = (not hiddenByRace and state.Driving) and FEEL_LEGACY_HOVER_DUST or 0
	local brake = 0
	local jetFloor = nil
	local boostCeiling = nil
	if state.ForcePreview and not hiddenByRace then
		throttle = 1
		boost = 1
		drift = 1
	end
	local feel = feelInputs(cache, state, dt)
	if feel then
		-- Keep the by-name toggles (applyVFXState) on the same thresholds as the
		-- controller, so both writers of Enabled agree on every tick.
		state.Accelerating = feel.ThrottleOut > 0.05
		state.Boosting = feel.BoostOut > 0.05
		state.DriftLeft = feel.DriftLeftOut > 0.05
		state.DriftRight = feel.DriftRightOut > 0.05
		state.AnyDrift = state.DriftLeft or state.DriftRight
		if not hiddenByRace then
			throttle = feel.ThrottleOut
			boost = feel.BoostOut
			driftLeft = feel.DriftLeftOut
			driftRight = feel.DriftRightOut
			drift = math.max(driftLeft, driftRight)
			hoverDust = feel.DustOut
			brake = feel.BrakeOut
			jetFloor = feelConfig.FeelJetFloor
			boostCeiling = feelConfig.FeelBoostPulsePeak
		end
		-- Local driving vehicle only: vehicles without an authored BrakeSparks
		-- socket get one burst-only spark source, owned by the controller.
		if not feel.SparksResolved and typeof(cache.Controller.EnsureImpactSparks) == "function" then
			local ok, resolved = pcall(function()
				return cache.Controller:EnsureImpactSparks()
			end)
			feel.SparksResolved = (not ok) or resolved == true
		end
		feelBursts(cache, feel, hiddenByRace)
	end
	pcall(function()
		cache.Controller:Update(dt, {
			Throttle = throttle,
			Boost = boost,
			Drift = drift,
			DriftLeft = driftLeft,
			DriftRight = driftRight,
			HoverDust = hoverDust,
			Brake = brake,
			JetFloor = jetFloor,
			BoostCeiling = boostCeiling,
		})
	end)
end

local function applyVFXState(cache, state)
	local visibleByRace = shouldRenderVehicleVFX(cache.Model) == true 
	local key = stateKey(state) .. "|RaceVisible=" .. tostring(visibleByRace)
	if cache.LastStateKey == key then return end
	cache.LastStateKey = key
	for object, meta in pairs(cache.VFXObjects) do
		if object.Parent then
			local enabled = visibleByRace and enabledFor(meta.Kind, meta.Side, state) or false
			if enabled ~= nil then
				setEnabled(object, enabled)
			end
		end
	end
end

local function updateCache(cache, dt)
	if not cache.Model.Parent then return false end
	attachTemplateController(cache)
	local state = runtimeState(cache)
	updateTemplateController(cache, state, dt)
	local colour = thrustColour(cache)
	if cache.LastColour ~= colour or cache.NeedsColour then
		cache.LastColour = colour
		cache.NeedsColour = false
		applyColour(cache, colour)
	else
		for part in pairs(cache.ThrustParts) do
			if part.Parent and (part.Transparency ~= 0 or part.Material ~= Enum.Material.Neon) then
				part.Color = colour
				part.Material = Enum.Material.Neon
				part.Transparency = 0
			end
		end
	end
	applyVFXState(cache, state)
	return true
end

local function destroyCache(cache)
	for _, item in ipairs(cache.Connections) do
		item:Disconnect()
	end
	if cache.Controller and typeof(cache.Controller.Destroy) == "function" then
		pcall(function() cache.Controller:Destroy() end)
	end
	cache.Controller = nil
	cache.Known = newWeakSet()
	cache.ThrustParts = newWeakSet()
	cache.ColourObjects = newWeakSet()
	cache.VFXObjects = newWeakSet()
	cache.InvisibleHosts = newWeakSet()
	tracked[cache.Model] = nil
end


local function trackModel(model)
	if not model or not model:IsA("Model") then return end
	local existing = tracked[model]
	local controlRoot = controlRootFor(model)
	if existing then
		existing.ControlRoot = controlRoot
		return
	end

	local cache = {
		Model = model,
		ControlRoot = controlRoot,
		Known = newWeakSet(),
		ThrustParts = newWeakSet(),
		ColourObjects = newWeakSet(),
		VFXObjects = newWeakSet(),
		InvisibleHosts = newWeakSet(),
		Connections = {},
		NeedsColour = true,
		LastColour = nil,
		LastStateKey = nil,
		Controller = nil,
	}
	tracked[model] = cache
	scanTree(cache, model)

	table.insert(cache.Connections, model.DescendantAdded:Connect(function(descendant)
		scanTree(cache, descendant)
		cache.NeedsColour = true
		cache.LastStateKey = nil
	end))
	table.insert(cache.Connections, model.DescendantRemoving:Connect(function(descendant)
		forgetTree(cache, descendant)
		cache.NeedsColour = true
		cache.LastStateKey = nil
	end))
	table.insert(cache.Connections, model.Destroying:Connect(function()
		destroyCache(cache)
	end))

	if controlRoot then
		table.insert(cache.Connections, controlRoot:GetAttributeChangedSignal("ThrustColor"):Connect(function()
			cache.NeedsColour = true
		end))
		table.insert(cache.Connections, controlRoot:GetAttributeChangedSignal("ForceThrustPreview"):Connect(function()
			cache.LastStateKey = nil
		end))
		table.insert(cache.Connections, controlRoot:GetAttributeChangedSignal("PreviewVFXMode"):Connect(function()
			cache.LastStateKey = nil
		end))
	end
	table.insert(cache.Connections, model:GetAttributeChangedSignal("ThrustColor"):Connect(function()
		cache.NeedsColour = true
	end))
	for _, attr in ipairs({ "DriveReady", "Accelerating", "Boosting", "DriftingLeft", "DriftingRight", "RaceParticipant", "RaceRunId" }) do
		table.insert(cache.Connections, model:GetAttributeChangedSignal(attr):Connect(function()
			cache.LastStateKey = nil
		end))
	end

	updateCache(cache, 0)
end


local function runtimeVehicles()
	local world = game:GetService("Workspace"):FindFirstChild("World")
	local vehiclesRoot = world and (world and game:GetService("Workspace"):WaitForChild("World"):FindFirstChild("Runtime") and game:GetService("Workspace"):WaitForChild("World").Runtime:FindFirstChild("PlayerVehicles"))
	if not vehiclesRoot then return end
	for _, child in ipairs(vehiclesRoot:GetChildren()) do
		if child:IsA("Model") then
			trackModel(child)
		end
	end
end

local function previewVehicles()
	local preview = getPreviewRoot()
	if not preview then return end
	if preview:IsA("Model") then
		trackModel(preview)
		return
	end
	for _, child in ipairs(preview:GetChildren()) do
		if child:IsA("Model") then
			trackModel(child)
		end
	end
end

local function scanCandidates()
	refreshFeelConfig()
	runtimeVehicles()
	previewVehicles()
	for model, cache in pairs(tracked) do
		if not model.Parent then
			destroyCache(cache)
		else
			cleanupDead(cache)
		end
	end
end

local function playerVehicle()
	local world = game:GetService("Workspace"):FindFirstChild("World")
	local vehiclesRoot = world and (world and game:GetService("Workspace"):WaitForChild("World"):FindFirstChild("Runtime") and game:GetService("Workspace"):WaitForChild("World").Runtime:FindFirstChild("PlayerVehicles"))
	if not vehiclesRoot then return nil end
	for _, vehicle in ipairs(vehiclesRoot:GetChildren()) do
		if vehicle:GetAttribute("OwnerUserId") == LOCAL_PLAYER.UserId then
			return vehicle
		end
	end
	return nil
end

local function garageOpen()
	return LOCAL_PLAYER:GetAttribute("GarageSessionActive") == true
end

local function driveOpen()
	local gui = LOCAL_PLAYER:FindFirstChild("PlayerGui") and LOCAL_PLAYER.PlayerGui:FindFirstChild("DriveHUD")
	return gui and gui.Enabled == true
end

local function setRobloxTouchControls(enabled)
	local playerGui = LOCAL_PLAYER:FindFirstChild("PlayerGui")
	local touchGui = playerGui and playerGui:FindFirstChild("TouchGui")
	if touchGui and touchGui:IsA("ScreenGui") then
		touchGui.Enabled = enabled
	end
	if controls then
		if enabled and controlsDisabled then
			controlsDisabled = false
			pcall(function() controls:Enable() end)
		elseif not enabled and not controlsDisabled then
			controlsDisabled = true
			pcall(function() controls:Disable() end)
		end
	end
end

local function updateCameraAndTouchControls()
	
	-- DrivingControllerV47 owns the driving camera now. Keep only the
	-- mobile touch-control visibility behavior from the visual runtime.
	if UserInputService.TouchEnabled then
		setRobloxTouchControls(not garageOpen() and not driveOpen())
	end
end


local function initControls()
	task.defer(function()
		local scripts = LOCAL_PLAYER:WaitForChild("PlayerScripts", 10)
		local playerModule = scripts and scripts:FindFirstChild("PlayerModule")
		if not playerModule then return end
		local ok, module = pcall(require, playerModule)
		if ok and module and module.GetControls then
			controls = module:GetControls()
		end
	end)
end

local function connectRaceVisibility()
	if raceEvent then return end
	local remotes = game:GetService("ReplicatedStorage")
		and game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		and game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):FindFirstChild("Racing")
	local event = remotes and game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("Racing"):FindFirstChild("RaceEvent")
	if not (event and event:IsA("RemoteEvent")) then return end
	raceEvent = event
	event.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		local kind = tostring(payload.Type or "")
		if kind == "RaceVisibilityUpdate" then
			raceVisibilityActive = payload.Active == true
			setRaceParticipants(payload.Participants or {})
			for _, cache in pairs(tracked) do
				cache.LastStateKey = nil
			end
		elseif kind == "RaceExitedToStart" or kind == "RaceEnded" or kind == "RaceDNF" or kind == "TimeTrialEnded" or kind == "TimeTrialFinished" then
			raceParticipants[LOCAL_PLAYER.UserId] = nil
			if next(raceParticipants) == nil then
				raceVisibilityActive = false
			end
			for _, cache in pairs(tracked) do
				cache.LastStateKey = nil
			end
		end
	end)
end

function Runtime.Start()
	if connection then return end
	initControls()
	connectRaceVisibility()
	scanCandidates()
	connection = RunService.RenderStepped:Connect(function(dt)
		visualTimer += dt
		scanTimer += dt
		uiTimer += dt

		if scanTimer >= SCAN_RATE then
			scanTimer = 0
			scanCandidates()
		end

		if visualTimer >= VISUAL_RATE then
			local stepDt = visualTimer
			visualTimer = 0
			for _, cache in pairs(tracked) do
				if not updateCache(cache, stepDt) then
					destroyCache(cache)
				end
			end
		end

		if uiTimer >= UI_RATE then
			uiTimer = 0
			updateCameraAndTouchControls()
		end


	end)
end

function Runtime.Stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
	for _, cache in pairs(tracked) do
		destroyCache(cache)
	end
	tracked = {}
end

function Runtime.DebugCounts()
	local vehicles = 0
	local thrustParts = 0
	local vfxObjects = 0
	for _, cache in pairs(tracked) do
		vehicles += 1
		thrustParts += tableCount(cache.ThrustParts)
		vfxObjects += tableCount(cache.VFXObjects)
	end
	return {
		Vehicles = vehicles,
		ThrustParts = thrustParts,
		VFXObjects = vfxObjects,
		TemplatesAttached = templates ~= nil and vfxControllerModule ~= nil,
	}
end

return Runtime

