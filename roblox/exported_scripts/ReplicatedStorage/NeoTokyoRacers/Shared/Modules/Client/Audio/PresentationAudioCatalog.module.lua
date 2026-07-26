-- NTR_PRESENTATION_AUDIO_CATALOG_V1
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog = {}
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audio = kit.Config:WaitForChild("Audio")
local root = audio:WaitForChild("Presentation")
local global = root:WaitForChild("Global")

local function assetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

local function split(path)
	local result = {}
	for segment in string.gmatch(tostring(path or ""), "[^%.]+") do table.insert(result, segment) end
	return result
end

local function cueFolder(cueId)
	local at = root
	for _, segment in ipairs(split(cueId)) do
		at = at and at:FindFirstChild(segment)
	end
	return at and at:IsA("Folder") and at or nil
end

function Catalog.GlobalBool(name, fallback)
	local value = global:GetAttribute(name)
	if typeof(value) == "boolean" then return value end
	return fallback == true
end

function Catalog.GlobalNumber(name, fallback)
	local value = global:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

function Catalog.Enabled(scope)
	if audio:WaitForChild("Global"):GetAttribute("AudioSystemEnabled") ~= true then return false end
	if global:GetAttribute("PresentationAudioEnabled") ~= true then return false end
	local key = tostring(scope or "") .. "AudioEnabled"
	return global:GetAttribute(key) ~= false
end

function Catalog.MasterGain(scope)
	return math.max(0, Catalog.GlobalNumber(tostring(scope or "") .. "MasterGain", 1))
end

function Catalog.AssetId(raw)
	return assetId(raw)
end

function Catalog.Get(cueId)
	local folder = cueFolder(cueId)
	if not folder then return nil end
	return {
		Id = tostring(cueId),
		Enabled = folder:GetAttribute("Enabled") ~= false,
		AssetId = assetId(folder:GetAttribute("AssetId")),
		Gain = math.max(0, tonumber(folder:GetAttribute("Gain")) or 1),
		Pitch = math.clamp(tonumber(folder:GetAttribute("Pitch")) or 1, 0.1, 4),
		CooldownSeconds = math.max(0, tonumber(folder:GetAttribute("CooldownSeconds")) or 0),
		MaximumVoices = math.max(1, math.floor(tonumber(folder:GetAttribute("MaximumVoices")) or 1)),
		Bus = tostring(folder:GetAttribute("Bus") or "UI"),
		ProfileLayer = tostring(folder:GetAttribute("ProfileLayer") or ""),
		FadeInSeconds = math.max(0, tonumber(folder:GetAttribute("FadeInSeconds")) or 0.15),
		FadeOutSeconds = math.max(0, tonumber(folder:GetAttribute("FadeOutSeconds")) or 0.2),
		CrossfadeSeconds = math.max(0, tonumber(folder:GetAttribute("CrossfadeSeconds")) or 0.25),
		MissingPreviewGraceSeconds = math.max(0, tonumber(folder:GetAttribute("MissingPreviewGraceSeconds")) or 0.5),
	}
end

function Catalog.Root()
	return root
end

return Catalog
