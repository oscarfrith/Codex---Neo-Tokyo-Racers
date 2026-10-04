-- Canonical feature implementation; startup is owned by the composition root.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = {}
local kit = game:GetService("ReplicatedStorage")
local audioConfig = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Audio")
local profiles = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Audio"):WaitForChild("VehicleProfiles")
local global = game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Audio"):WaitForChild("Global")

Catalog.LoopLayers = { "Idle", "EngineLow", "EngineHigh", "Acceleration", "Coast", "DriftLoop", "BoostLoop", "DriverWind" }
Catalog.OneShotLayers = { "Ignition", "Shutdown", "AccelerationEnter", "AccelerationRelease", "DriftEnter", "BoostEnter", "BoostRelease", "BoostRecharge", "BoostEmpty", "FullBoostSpent" }
-- Feel layers exist only for a profile with FeelDriveEnabled=true. They use the same AssetId/Gain/Pitch
-- attribute contract; a blank asset leaves the layer absent.
Catalog.FeelLoopLayers = { "TurboWhistle", "SuperchargerWhine", "TurbineLow", "TurbineHigh", "EnergyHum", "SlipStrain", "DriftCharge" }
Catalog.FeelOneShotLayers = { "BlowOff", "TurboFlutter", "BoostIgnition", "DriftChargeRelease", "ImpactLight", "ImpactMedium", "ImpactHeavy", "ImpactSevere", "LandingThump" }
-- Speed-shaped engine loops that a profile's rev layers take over from once a rev layer has loaded.
Catalog.RevSupersededLayers = { Idle = true, EngineLow = true, EngineHigh = true }

local defaultGains = {
	Ignition = 0.85,
	Shutdown = 0.75,
	AccelerationEnter = 0.55,
	AccelerationRelease = 0.45,
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
	BoostRecharge = 0.45,
	BoostEmpty = 0.65,
	FullBoostSpent = 0.85,
	DriverWind = 0.38,
	TurboWhistle = 0.3,
	SuperchargerWhine = 0.22,
	TurbineLow = 0.3,
	TurbineHigh = 0.3,
	EnergyHum = 0.25,
	SlipStrain = 0.3,
	DriftCharge = 0.3,
	BlowOff = 0.5,
	TurboFlutter = 0.5,
	BoostIgnition = 0.75,
	DriftChargeRelease = 0.6,
	ImpactLight = 0.5,
	ImpactMedium = 0.7,
	ImpactHeavy = 0.9,
	ImpactSevere = 1,
	LandingThump = 0.7,
}

-- PlaybackSpeed range each feel loop sweeps as its drive value goes from 0 to 1 (PitchMin/PitchMax attributes).
-- The turbine pair has no range: its pitch comes from TurbineOctaveStart and TurbineOctaves.
local defaultPitchRanges = {
	TurboWhistle = { 0.5, 1.85 },
	SuperchargerWhine = { 0.6, 1.6 },
	EnergyHum = { 0.92, 1.12 },
	SlipStrain = { 0.92, 1.06 },
	DriftCharge = { 0.8, 1.7 },
}

-- Profile-level feel tuning: attribute name = { default, minimum, maximum }. Every value is optional.
local feelDefaults = {
	RevThrottleWeight = { 0.25, 0, 1 },
	RevSpeedWeight = { 0.75, 0, 2 },
	RevBoostWeight = { 0.08, 0, 1 },
	RevReferenceMph = { 170, 10, 1000 },
	RevRiseSeconds = { 0.12, 0.001, 5 },
	RevFallSeconds = { 0.28, 0.001, 5 },
	RevPitchBase = { 0.125, 0.05, 0.95 },
	RevNeighbourDetune = { 0.003, 0, 0.006 },
	RevOffLoadGain = { 0.6, 0, 2 },
	RevMasterGain = { 1, 0, 3 },
	ReverseLoad = { 0.6, 0, 1 },
	LoadAttackSeconds = { 0.022, 0.001, 2 },
	LoadReleaseSeconds = { 0.085, 0.001, 2 },
	LoadExponent = { 0.8, 0.1, 4 },
	BarkGain = { 0.55, 0, 2 },
	BarkSeconds = { 0.13, 0.001, 2 },
	LifePitchDepth = { 0.0025, 0, 0.02 },
	LifeLevelDb = { 0.6, 0, 3 },
	LifeSeconds = { 1.4, 0.05, 20 },
	TwinEngineDetune = { 0.012, 0, 0.05 },
	TwinEngineGain = { 0.6, 0, 1 },
	TurboSpoolUpSeconds = { 0.9, 0.001, 10 },
	TurboSpoolDownSeconds = { 0.35, 0.001, 10 },
	TurboSpoolRevFloor = { 0.35, 0, 1 },
	TurboGainExponent = { 1.5, 0.1, 4 },
	BlowOffLoadThreshold = { 0.6, 0.05, 1 },
	BlowOffLiftThreshold = { 0.1, 0, 0.9 },
	BlowOffMinLoadSeconds = { 0.6, 0, 10 },
	BlowOffMinSpool = { 0.35, 0, 1 },
	BlowOffMinIntervalSeconds = { 0.7, 0, 10 },
	BlowOffSpoolKeep = { 0.25, 0, 1 },
	SuperchargerGainExponent = { 1.5, 0.1, 4 },
	SuperchargerOffLoadGain = { 0.35, 0, 1 },
	TurbineStartRev = { 0.3, 0, 0.99 },
	TurbineOffLoadGain = { 0.3, 0, 1 },
	TurbineOctaveStart = { -0.5, -2, 1 },
	TurbineOctaves = { 2, 0, 4 },
	FlutterBelowSpool = { 0.7, 0, 1 },
	EnergyHumHoverGain = { 0.5, 0, 2 },
	SlipStart = { 0.12, 0, 1 },
	SlipFull = { 0.6, 0.01, 1 },
	SlipDriftFloor = { 0.35, 0, 1 },
	SlipDuckDb = { 6, 0, 24 },
	SlipDuckInSeconds = { 0.06, 0.001, 2 },
	SlipDuckOutSeconds = { 0.35, 0.001, 5 },
	BoostLoopMiniGain = { 0.7, 0, 2 },
	BoostIgnitionMiniGain = { 0.6, 0, 2 },
	BoostIgnitionMiniPitch = { 1.15, 0.5, 2 },
	DriftChargeStart = { 0.04, 0, 0.9 },
	DriftChargeFull = { 0.3, 0.01, 1 },
	LandMinStuds = { 6, 0, 500 },
	LandFullStuds = { 60, 1, 1000 },
	LandMinGain = { 0.25, 0, 1 },
}

local function assetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

local function boundedNumber(owner, name, fallback, minValue, maxValue)
	local value = tonumber(owner:GetAttribute(name))
	if value == nil or value ~= value then value = fallback end
	return math.clamp(value, minValue, maxValue)
end

function Catalog.GlobalNumber(name, fallback)
	local value = tonumber(global:GetAttribute(name))
	return value ~= nil and value or fallback
end

function Catalog.GlobalBool(name, fallback)
	local value = global:GetAttribute(name)
	return typeof(value) == "boolean" and value or fallback
end

local function fallbackProfileId()
	return tostring(global:GetAttribute("FallbackProfileId") or "GENERIC_STANDARD_AUDIO")
end

-- Category voice: VehicleProfiles attribute CategoryProfile_<CategoryId> names the profile for every vehicle
-- of that category. It applies only while the vehicle carries the server's default stamp
-- (AudioProfileSource="Standard" on the fallback profile) or no stamp yet, so a package resolved by an
-- authoritative owner and a template's own StandardAudioProfileId both still win.
local function categoryProfileId(vehicle)
	local categoryId = vehicle:GetAttribute("CategoryId")
	if typeof(categoryId) ~= "string" or categoryId == "" or string.find(categoryId, "[^%w_]") then return nil end
	local mapped = profiles:GetAttribute("CategoryProfile_" .. categoryId)
	if typeof(mapped) ~= "string" or mapped == "" then return nil end
	local folder = profiles:FindFirstChild(mapped)
	return folder ~= nil and folder:IsA("Folder") and mapped or nil
end

function Catalog.ResolveProfileId(vehicle)
	local fallback = fallbackProfileId()
	if not vehicle then return fallback end
	local resolved = tostring(vehicle:GetAttribute("ResolvedAudioProfileId") or "")
	local standard = tostring(vehicle:GetAttribute("StandardAudioProfileId") or "")
	local defaultStamp = resolved == "" or (vehicle:GetAttribute("AudioProfileSource") == "Standard" and resolved == fallback)
	if defaultStamp and (standard == "" or standard == fallback) then
		local mapped = categoryProfileId(vehicle)
		if mapped then return mapped end
	end
	if resolved ~= "" and profiles:FindFirstChild(resolved) then return resolved end
	if standard ~= "" and profiles:FindFirstChild(standard) then return standard end
	return fallback
end

-- Rev layers: child Folders of <profile>.RevLayers, one engine loop each. Rev is the 0..1 position the loop
-- was recorded at; Load is "On" (thrust set), "Off" (coast set) or "Any". StandIn layers play only until a
-- layer that is not a stand-in has an asset.
local function readRevLayers(folder)
	local layers = {}
	local container = folder:FindFirstChild("RevLayers")
	if not container then return layers end
	local voiced = false
	for _, item in ipairs(container:GetChildren()) do
		if not (item:IsA("Folder") or item:IsA("Configuration")) then continue end
		local id = assetId(item:GetAttribute("AssetId"))
		if id == "" or item:GetAttribute("Enabled") == false then continue end
		local load = tostring(item:GetAttribute("Load") or "Any")
		if load ~= "On" and load ~= "Off" then load = "Any" end
		local pitchMin = boundedNumber(item, "PitchMin", 0.6, 0.5, 2)
		local layer = {
			Name = item.Name,
			AssetId = id,
			Rev = boundedNumber(item, "Rev", 0, 0, 1),
			Gain = boundedNumber(item, "Gain", 0.6, 0, 3),
			Pitch = boundedNumber(item, "Pitch", 1, 0.5, 2),
			PitchMin = pitchMin,
			PitchMax = math.max(pitchMin, boundedNumber(item, "PitchMax", 1.7, 0.5, 2)),
			Load = load,
			StandIn = item:GetAttribute("StandIn") == true,
			Twin = item:GetAttribute("Twin") ~= false,
		}
		if not layer.StandIn then voiced = true end
		table.insert(layers, layer)
	end
	if voiced then
		for index = #layers, 1, -1 do
			if layers[index].StandIn then table.remove(layers, index) end
		end
	end
	table.sort(layers, function(a, b)
		if a.Rev ~= b.Rev then return a.Rev < b.Rev end
		return a.Name < b.Name
	end)
	return layers
end

local function readFeel(folder, profile)
	if folder:GetAttribute("FeelDriveEnabled") ~= true then return nil end
	local feel = {}
	for name, spec in pairs(feelDefaults) do
		feel[name] = boundedNumber(folder, name, spec[1], spec[2], spec[3])
	end
	feel.RevLayers = readRevLayers(folder)
	for _, layer in ipairs(Catalog.FeelLoopLayers) do
		local range = defaultPitchRanges[layer]
		if range then
			local pitchMin = boundedNumber(folder, layer .. "PitchMin", range[1], 0.25, 4)
			profile.PitchRanges[layer] = { Min = pitchMin, Max = math.max(pitchMin, boundedNumber(folder, layer .. "PitchMax", range[2], 0.25, 4)) }
		end
	end
	-- An existing loop layer follows rev only when the profile gives it both RevPitchMin and RevPitchMax.
	for _, layer in ipairs(Catalog.LoopLayers) do
		local pitchMin = tonumber(folder:GetAttribute(layer .. "RevPitchMin"))
		local pitchMax = tonumber(folder:GetAttribute(layer .. "RevPitchMax"))
		if pitchMin and pitchMax then
			pitchMin = math.clamp(pitchMin, 0.25, 4)
			profile.RevPitches[layer] = { Min = pitchMin, Max = math.max(pitchMin, math.clamp(pitchMax, 0.25, 4)) }
		end
	end
	return feel
end

local function readLayer(folder, profile, layer)
	profile.Assets[layer] = assetId(folder:GetAttribute(layer .. "AssetId"))
	profile.Gains[layer] = math.clamp(tonumber(folder:GetAttribute(layer .. "Gain")) or defaultGains[layer] or 0.5, 0, 3)
	profile.Pitches[layer] = math.clamp(tonumber(folder:GetAttribute(layer .. "Pitch")) or 1, 0.5, 2)
end

function Catalog.GetProfile(profileId)
	local folder = profiles:FindFirstChild(tostring(profileId or ""))
	if not (folder and folder:IsA("Folder")) then
		folder = profiles:FindFirstChild(fallbackProfileId())
	end
	if not folder then return nil end
	local profile = { Id = folder.Name, Folder = folder, Assets = {}, Gains = {}, Pitches = {}, PitchRanges = {}, RevPitches = {}, MasterGain = math.clamp(tonumber(folder:GetAttribute("ProfileMasterGain")) or 1, 0, 3) }
	for _, layer in ipairs(Catalog.LoopLayers) do readLayer(folder, profile, layer) end
	for _, layer in ipairs(Catalog.OneShotLayers) do readLayer(folder, profile, layer) end
	profile.Feel = readFeel(folder, profile)
	if profile.Feel then
		for _, layer in ipairs(Catalog.FeelLoopLayers) do readLayer(folder, profile, layer) end
		for _, layer in ipairs(Catalog.FeelOneShotLayers) do readLayer(folder, profile, layer) end
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
