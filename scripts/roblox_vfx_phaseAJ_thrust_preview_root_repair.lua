-- Neo Tokyo Racers - VFX Phase AJ: Thrust Preview Root Repair
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Repairs thrust VFX preview after the dealership intro flow moved the
--   customisation preview vehicle from:
--     Workspace.HOVER_RACING_V2_LOCAL_PREVIEW
--   to the local-only root:
--     Workspace._NTR_ClientOnly.VehiclePreview
--
-- Root cause:
--   The active preview vehicle now lives under the local-only dealership root,
--   but the older thrust preview/VFX runtime helpers still resolve only the
--   old HOVER_RACING_V2_LOCAL_PREVIEW folder. That means ForceThrustPreview
--   and ThrustColor are set on the new preview root, while the VFX runtime
--   watches the old/missing root.
--
-- Safe design:
--   - Patches only current thrust preview/VFX source objects if present.
--   - Keeps the old preview root as a fallback.
--   - Does not create, clone, move, or delete preview vehicles.
--   - Does not touch driving, garage server actions, cockpit lights, LOD,
--     lighting, traffic, world objects, or Workspace.Test + WIP Assets.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.

local MODE = "PATCH" -- "AUDIT" or "PATCH"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_vfx_phaseAJ_thrust_preview_root_repair"
local OLD_PREVIEW_ROOT_NAME = "HOVER_RACING_V2_LOCAL_PREVIEW"
local CLIENT_ONLY_ROOT_NAME = "_NTR_ClientOnly"
local DEALERSHIP_PREVIEW_ROOT_NAME = "VehiclePreview"

local function log(message)
	print("[NTR VFX Phase AJ] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error(("Existing %s is %s, expected %s. No changes applied."):format(
				safeFullName(existing),
				existing.ClassName,
				className
			))
		end
		return existing
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function folder(parent, name)
	return child(parent, "Folder", name)
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

local function simpleHash(text)
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
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

local function sourceLooksPatched(source)
	return string.find(source, CLIENT_ONLY_ROOT_NAME, 1, true) ~= nil
		and string.find(source, DEALERSHIP_PREVIEW_ROOT_NAME, 1, true) ~= nil
end

local function patchPreviewRootReturn(source)
	if sourceLooksPatched(source) then
		return source, 0, "already compatible"
	end

	if not string.find(source, OLD_PREVIEW_ROOT_NAME, 1, true) then
		return source, 0, "old preview root token not present"
	end

	if not string.find(source, "local function getPreviewRoot()", 1, true) then
		return source, 0, "blocked: old root token found, but getPreviewRoot shape was not found"
	end

	local replacement = table.concat({
		'local clientOnlyRoot = Workspace:FindFirstChild("' .. CLIENT_ONLY_ROOT_NAME .. '")',
		'	local dealershipPreview = clientOnlyRoot and clientOnlyRoot:FindFirstChild("' .. DEALERSHIP_PREVIEW_ROOT_NAME .. '")',
		"	if dealershipPreview then",
		"		return dealershipPreview",
		"	end",
		'	return Workspace:FindFirstChild("' .. OLD_PREVIEW_ROOT_NAME .. '")',
	}, "\n")

	local patched, count = replaceAllPlain(
		source,
		'return Workspace:FindFirstChild("' .. OLD_PREVIEW_ROOT_NAME .. '")',
		replacement
	)

	if count == 0 then
		patched, count = replaceAllPlain(
			source,
			'return workspace:FindFirstChild("' .. OLD_PREVIEW_ROOT_NAME .. '")',
			replacement
		)
	end

	if count == 0 then
		return source, 0, "blocked: getPreviewRoot exists, but the expected return line was not found"
	end

	return patched, count, "patched preview root resolver"
end

local targets = {
	{
		Label = "cached thrust visual runtime module",
		Path = "ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Visuals.CachedThrustVisualRuntime",
		Required = true,
	},
	{
		Label = "active thrust preview controller",
		Path = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active",
		Required = false,
	},
	{
		Label = "disabled legacy thrust preview fallback",
		Path = "StarterPlayer.StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly",
		Required = false,
	},
}

if MODE ~= "AUDIT" and MODE ~= "PATCH" then
	error("Invalid MODE: " .. tostring(MODE) .. ". Use AUDIT or PATCH.")
end

local results = {}
local blockers = {}
local patchedCount = 0
local replacementCount = 0

for _, target in ipairs(targets) do
	local instance = resolvePath(target.Path)
	if not instance then
		if target.Required then
			table.insert(blockers, target.Path .. " -- missing required target")
		else
			table.insert(results, target.Label .. ": missing optional target")
		end
		continue
	end

	if not (instance:IsA("LocalScript") or instance:IsA("ModuleScript")) then
		table.insert(blockers, target.Path .. " -- found " .. instance.ClassName .. ", expected LocalScript/ModuleScript")
		continue
	end

	local source = sourceOf(instance)
	if not source then
		table.insert(blockers, target.Path .. " -- source could not be read")
		continue
	end

	local patched, replacements, note = patchPreviewRootReturn(source)
	if string.sub(note, 1, 8) == "blocked:" then
		table.insert(blockers, target.Path .. " -- " .. note)
		continue
	end

	if replacements > 0 then
		if MODE == "PATCH" then
			instance.Source = patched
			instance:SetAttribute("PhaseAJPatchedBy", SCRIPT_ID)
			instance:SetAttribute("PhaseAJPatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
			instance:SetAttribute("PhaseAJOldSourceHash", simpleHash(source))
			instance:SetAttribute("PhaseAJNewSourceHash", simpleHash(patched))
		end
		patchedCount += 1
		replacementCount += replacements
	end

	table.insert(results, target.Label .. ": " .. note .. " (" .. tostring(replacements) .. " replacement(s))")
end

if #blockers > 0 then
	local message = {
		"Phase AJ stopped before changing anything.",
		"One or more required source objects did not match the expected safe patch shape:",
		"",
	}
	for _, blocker in ipairs(blockers) do
		table.insert(message, "- " .. blocker)
	end
	error(table.concat(message, "\n"))
end

local ntr = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
if not ntr or not ntr:IsA("Folder") then
	error("ReplicatedStorage.NeoTokyoRacers was not found. No report was written.")
end

local compatibility = folder(ntr, "Compatibility")
local reportsRoot = folder(compatibility, "MigrationReports")

local reportLines = {
	"# Neo Tokyo Racers VFX Phase AJ Thrust Preview Root Repair",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Mode: " .. MODE,
	"- Source objects patched: " .. tostring(patchedCount),
	"- Text replacements applied: " .. tostring(replacementCount),
	"- New preview root supported: Workspace." .. CLIENT_ONLY_ROOT_NAME .. "." .. DEALERSHIP_PREVIEW_ROOT_NAME,
	"- Old preview root kept as fallback: Workspace." .. OLD_PREVIEW_ROOT_NAME,
	"",
	"## Results",
	"",
}

for _, result in ipairs(results) do
	table.insert(reportLines, "- " .. result)
end

table.insert(reportLines, "")
table.insert(reportLines, "## Required Play Test")
table.insert(reportLines, "")
table.insert(reportLines, "1. Stop Play and start a fresh Play session.")
table.insert(reportLines, "2. Open the dealership/garage from the desk.")
table.insert(reportLines, "3. Buy/select a cockpit so Workspace._NTR_ClientOnly.VehiclePreview exists on the client.")
table.insert(reportLines, "4. Go to Customise > Thrust colour.")
table.insert(reportLines, "5. Confirm engine/boost/stabiliser thrust VFX preview turns on and recolours while editing.")
table.insert(reportLines, "6. Spawn and drive, then confirm runtime thrust, boost, and drift VFX still respond.")

local report = reportsRoot:FindFirstChild("PhaseAJ_ThrustPreviewRootRepair")
if report and not report:IsA("StringValue") then
	report.Name = "PhaseAJ_ThrustPreviewRootRepair_OldNonStringValue"
	report = nil
end
if not report then
	report = Instance.new("StringValue")
	report.Name = "PhaseAJ_ThrustPreviewRootRepair"
	report.Parent = reportsRoot
end

report.Value = table.concat(reportLines, "\n")
report:SetAttribute("CreatedBy", SCRIPT_ID)
report:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
report:SetAttribute("Mode", MODE)
report:SetAttribute("PatchedSourceObjects", patchedCount)
report:SetAttribute("ReplacementCount", replacementCount)

log("Phase AJ complete in mode: " .. MODE)
log("Patched source objects: " .. tostring(patchedCount) .. "; replacements: " .. tostring(replacementCount))
log("Report: " .. safeFullName(report))
print(report.Value)
