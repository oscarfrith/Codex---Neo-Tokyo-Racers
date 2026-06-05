-- Neo Tokyo Racers - Lighting Phase R: FogColor Property Repair
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Fixes this load warning:
--     Could not apply property: Lighting Fogcolor Fogcolor is not a valid member of Lighting "Lighting"
--
-- Cause:
--   Roblox Lighting uses `FogColor` with a capital C. The active lighting
--   presets currently contain `Fogcolor`, so LightingService_Active rejects it.
--
-- Safe effects:
--   - Replaces `Fogcolor =` with `FogColor =` in lighting preset ModuleScripts.
--   - Adds a one-line compatibility alias to LightingService_Active so older
--     preset copies with `Fogcolor` are normalized before assignment.
--   - Does not touch UI, driving, garage/server action, VFX, LOD, traffic,
--     gameplay objects, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SCRIPT_ID = "roblox_lighting_phaseR_fogcolor_property_repair"
local LIGHTING_SERVICE_PATH = "ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Active"

local function log(message)
	print("[NTR Lighting Phase R] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function resolvePath(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(token)
		if not current then
			return nil
		end
	end
	return current
end

local function sourceOf(instance)
	local ok, result = pcall(function()
		return instance.Source
	end)
	if ok and typeof(result) == "string" then
		return result
	end
	return nil
end

local function replaceAllPlain(text, old, new)
	local count = 0
	local searchFrom = 1

	while true do
		local startIndex, endIndex = string.find(text, old, searchFrom, true)
		if not startIndex then
			break
		end

		text = string.sub(text, 1, startIndex - 1) .. new .. string.sub(text, endIndex + 1)
		count += 1
		searchFrom = startIndex + #new
	end

	return text, count
end

local function collectLightingPresetModules()
	local results = {}
	local seen = {}

	local function add(instance)
		if instance and instance:IsA("ModuleScript") and not seen[instance] then
			seen[instance] = true
			table.insert(results, instance)
		end
	end

	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local sharedLightingPresets = shared and shared:FindFirstChild("LightingPresets")
	add(sharedLightingPresets and sharedLightingPresets:FindFirstChild("LightingPresets"))

	local ntr = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	if ntr then
		for _, descendant in ipairs(ntr:GetDescendants()) do
			if descendant:IsA("ModuleScript") and descendant.Name == "LightingPresets" then
				add(descendant)
			end
		end
	end

	for _, descendant in ipairs(ReplicatedStorage:GetDescendants()) do
		if descendant:IsA("ModuleScript") and descendant.Name == "LightingPresets" then
			add(descendant)
		end
	end

	table.sort(results, function(a, b)
		return safeFullName(a) < safeFullName(b)
	end)

	return results
end

local function patchPresetSource(source)
	local total = 0
	local changed
	source, changed = replaceAllPlain(source, "Fogcolor =", "FogColor =")
	total += changed
	source, changed = replaceAllPlain(source, "Fogcolor=", "FogColor=")
	total += changed
	return source, total
end

local function patchLightingServiceSource(source)
	if string.find(source, "propertyName == \"Fogcolor\"", 1, true) then
		return source, 0
	end

	local target = "for propertyName, value in pairs(properties) do\n\t\tlocal success, err = pcall(function()"
	local replacement = "for propertyName, value in pairs(properties) do\n\t\tif instance == Lighting and propertyName == \"Fogcolor\" then\n\t\t\tpropertyName = \"FogColor\"\n\t\tend\n\n\t\tlocal success, err = pcall(function()"

	local changed
	source, changed = replaceAllPlain(source, target, replacement)
	if changed > 0 then
		return source, changed
	end

	source, changed = string.gsub(
		source,
		"(for%s+propertyName,%s*value%s+in%s+pairs%(%s*properties%s*%)%s+do%s*)local%s+success,%s*err%s*=%s*pcall%(%s*function%(%s*%)",
		"%1if instance == Lighting and propertyName == \"Fogcolor\" then\n\t\t\tpropertyName = \"FogColor\"\n\t\tend\n\n\t\tlocal success, err = pcall(function()",
		1
	)
	return source, changed
end

local changedLines = {}
local presetModules = collectLightingPresetModules()
local presetReplacementCount = 0

for _, module in ipairs(presetModules) do
	local source = sourceOf(module)
	if source then
		local patched, changed = patchPresetSource(source)
		if changed > 0 and patched ~= source then
			module.Source = patched
			module:SetAttribute("PhaseRFogColorPatchedBy", SCRIPT_ID)
			module:SetAttribute("PhaseRFogColorPatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
			table.insert(changedLines, safeFullName(module) .. " -- Fogcolor -> FogColor x" .. tostring(changed))
			presetReplacementCount += changed
		end
	end
end

local servicePatchCount = 0
local lightingService = resolvePath(LIGHTING_SERVICE_PATH)
if lightingService and lightingService:IsA("Script") then
	local source = sourceOf(lightingService)
	if source then
		local patched, changed = patchLightingServiceSource(source)
		if changed > 0 and patched ~= source then
			lightingService.Source = patched
			lightingService:SetAttribute("PhaseRFogColorPatchedBy", SCRIPT_ID)
			lightingService:SetAttribute("PhaseRFogColorPatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
			table.insert(changedLines, safeFullName(lightingService) .. " -- added Fogcolor compatibility alias")
			servicePatchCount += changed
		end
	end
else
	table.insert(changedLines, LIGHTING_SERVICE_PATH .. " -- not found; preset typo repair still attempted")
end

local remainingPresetHits = {}
for _, module in ipairs(collectLightingPresetModules()) do
	local source = sourceOf(module)
	if source and string.find(source, "Fogcolor", 1, true) then
		table.insert(remainingPresetHits, safeFullName(module))
	end
end

local output = {
	"# Neo Tokyo Racers Lighting Phase R FogColor Property Repair",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Lighting preset modules checked: " .. tostring(#presetModules),
	"- Preset Fogcolor replacements: " .. tostring(presetReplacementCount),
	"- LightingService compatibility patch applied: " .. tostring(servicePatchCount > 0),
	"- Remaining preset Fogcolor hits: " .. tostring(#remainingPresetHits),
	"",
	"## Changes",
	"",
}

if #changedLines == 0 then
	table.insert(output, "- None. The place may already be repaired.")
else
	for _, item in ipairs(changedLines) do
		table.insert(output, "- " .. item)
	end
end

if #remainingPresetHits > 0 then
	table.insert(output, "")
	table.insert(output, "## Remaining Fogcolor Hits")
	table.insert(output, "")
	for _, item in ipairs(remainingPresetHits) do
		table.insert(output, "- " .. item)
	end
end

log("FogColor property repair complete.")
log("Preset replacements: " .. tostring(presetReplacementCount) .. "; service alias added: " .. tostring(servicePatchCount > 0) .. "; remaining hits: " .. tostring(#remainingPresetHits))
print(table.concat(output, "\n"))
