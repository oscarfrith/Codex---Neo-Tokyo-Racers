-- NTR_AUDIO_VEHICLE_CATALOG_V2_TUNING_CUES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = {}
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audioConfig = kit:WaitForChild("Config"):WaitForChild("Audio")
local profiles = audioConfig:WaitForChild("VehicleProfiles")
local global = audioConfig:WaitForChild("Global")

Catalog.LoopLayers = { "Idle", "EngineLow", "EngineHigh", "Acceleration", "Coast", "DriftLoop", "BoostLoop", "DriverWind" }
Catalog.OneShotLayers = { "Ignition", "Shutdown", "AccelerationEnter", "AccelerationRelease", "DriftEnter", "BoostEnter", "BoostRelease", "BoostRecharge", "BoostEmpty", "FullBoostSpent" }

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
	local profile = { Id = folder.Name, Folder = folder, Assets = {}, Gains = {}, Pitches = {}, MasterGain = math.clamp(tonumber(folder:GetAttribute("ProfileMasterGain")) or 1, 0, 3) }
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
