-- Neo Tokyo Racers - Architecture Phase Q: Garage Controller Header Repair
-- Run in Roblox Studio Command Bar, Edit mode, after Phase P if Play still
-- errors in GarageActionController_Shadow_Disabled near line 23.
--
-- Purpose:
--   Replaces only the startup header of the active V56 garage action controller
--   with known-good migrated NeoTokyoRacers paths.
--
-- Why this exists:
--   Phase P repaired one nil-index pattern, but a later Play test reported:
--     line 23: attempt to call a nil value
--
-- Safe effects:
--   - Edits only ServerScriptService.NeoTokyoRacers.Services.Garage
--     .GarageActionController_Shadow_Disabled.Source.
--   - Does not create backup folders/scripts.
--   - Does not create, move, rename, delete, enable, or disable gameplay objects.
--   - Does not touch UI, driving, VFX, LOD, lighting, traffic, or
--     Workspace.Test + WIP Assets.
--
-- Fragility note:
--   This intentionally uses a small source-text replacement. It requires the
--   active garage controller to still contain the V56 marker and
--   `local V56_STARTING_CASH`. If those are missing, it stops and prints the
--   current first 80 lines instead of guessing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_architecture_phaseQ_garage_controller_header_repair"
local GARAGE_CONTROLLER_PATH = "ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled"
local BEGIN_MARKER = "-- V56_CONSOLIDATED_ACTION_CONTROLLER_BEGIN"
local ANCHOR = "local V56_STARTING_CASH"

local function log(message)
	print("[NTR Phase Q] " .. message)
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

local function lineNumberForIndex(source, index)
	local prefix = string.sub(source, 1, math.max(index - 1, 0))
	local _, count = string.gsub(prefix, "\n", "")
	return count + 1
end

local function numberedExcerpt(source, firstLine, lastLine)
	local lines = {}
	local currentLine = 1
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		if currentLine >= firstLine and currentLine <= lastLine then
			table.insert(lines, string.format("%03d: %s", currentLine, line))
		end
		currentLine += 1
		if currentLine > lastLine then
			break
		end
	end
	return table.concat(lines, "\n")
end

local function pathExists(path, className)
	local instance = resolvePath(path)
	if not instance then
		return false, path .. " is missing"
	end
	if className and not instance:IsA(className) then
		return false, path .. " is " .. instance.ClassName .. ", expected " .. className
	end
	return true
end

local problems = {}
for _, check in ipairs({
	{ "ReplicatedStorage.NeoTokyoRacers", "Folder" },
	{ "ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage", "Folder" },
	{ "ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage.GarageInvoke", "RemoteFunction" },
	{ "ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories", "Folder" },
	{ "Workspace.NeoTokyoRacersWorld", "Folder" },
	{ "Workspace.NeoTokyoRacersWorld.Runtime", "Folder" },
	{ "Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles", "Folder" },
}) do
	local ok, message = pathExists(check[1], check[2])
	if not ok then
		table.insert(problems, message)
	end
end

local controller = resolvePath(GARAGE_CONTROLLER_PATH)
if not controller or not controller:IsA("Script") then
	table.insert(problems, GARAGE_CONTROLLER_PATH .. " was not found as a Script")
end

if #problems > 0 then
	local lines = {
		"Phase Q stopped before changing anything.",
		"Required migrated paths are missing or mismatched:",
		"",
	}
	for _, problem in ipairs(problems) do
		table.insert(lines, "- " .. problem)
	end
	error(table.concat(lines, "\n"))
end

local source = sourceOf(controller)
if not source then
	error("Could not read " .. safeFullName(controller) .. ".Source. No changes applied.")
end

local beginStart = string.find(source, BEGIN_MARKER, 1, true)
local anchorStart = string.find(source, ANCHOR, 1, true)
if not beginStart or not anchorStart or anchorStart <= beginStart then
	local output = {
		"# Neo Tokyo Racers Phase Q Garage Controller Header Repair",
		"",
		"Phase Q stopped before changing anything.",
		"Could not find the expected V56 header anchors.",
		"",
		"## Current First 80 Lines",
		"",
		numberedExcerpt(source, 1, 80),
	}
	print(table.concat(output, "\n"))
	error("Phase Q could not find the expected V56 marker/header anchors. Paste the printed first 80 lines back into Codex.")
end

local replacementHeader = table.concat({
	BEGIN_MARKER,
	"do",
	"	local Players = game:GetService(\"Players\")",
	"	local ReplicatedStorage = game:GetService(\"ReplicatedStorage\")",
	"	local Workspace = game:GetService(\"Workspace\")",
	"",
	"	local V56_KIT_NAME = \"NeoTokyoRacers\"",
	"	local V56_WORLD_NAME = \"NeoTokyoRacersWorld\"",
	"	local V56_kit = ReplicatedStorage:WaitForChild(V56_KIT_NAME)",
	"	local V56_remotes = V56_kit:WaitForChild(\"Shared\"):WaitForChild(\"Remotes\"):WaitForChild(\"Garage\")",
	"	local V56_invoke = V56_remotes:WaitForChild(\"GarageInvoke\")",
	"	local V56_categoriesRoot = V56_kit:WaitForChild(\"Assets\"):WaitForChild(\"Vehicles\"):WaitForChild(\"Categories\")",
	"	local V56_world = Workspace:WaitForChild(V56_WORLD_NAME)",
	"	local V56_runtime = V56_world:WaitForChild(\"Runtime\")",
	"	local V56_vehiclesRoot = V56_runtime:WaitForChild(\"PlayerVehicles\")",
	"",
}, "\n")

local patchedSource = string.sub(source, 1, beginStart - 1)
	.. replacementHeader
	.. string.sub(source, anchorStart)

if patchedSource == source then
	log("Header was already in the Phase Q shape.")
else
	controller.Source = patchedSource
	controller:SetAttribute("PhaseQHeaderRepairedBy", SCRIPT_ID)
	controller:SetAttribute("PhaseQHeaderRepairedAt", os.date("%Y-%m-%d %H:%M:%S"))
end

local finalSource = sourceOf(controller) or patchedSource
local finalAnchorStart = string.find(finalSource, ANCHOR, 1, true)
local finalAnchorLine = finalAnchorStart and lineNumberForIndex(finalSource, finalAnchorStart) or -1

local legacyHits = {}
for _, token in ipairs({ "HOVER_RACING_V2_KIT", "HOVER_RACING_V2_WORLD", "PLAYER_VEHICLES_Runtime" }) do
	if string.find(finalSource, token, 1, true) then
		table.insert(legacyHits, token)
	end
end

local output = {
	"# Neo Tokyo Racers Phase Q Garage Controller Header Repair",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Controller: " .. safeFullName(controller),
	"- Header replaced: " .. tostring(patchedSource ~= source),
	"- V56_STARTING_CASH now starts at line: " .. tostring(finalAnchorLine),
	"- Legacy runtime/kit tokens remaining in controller source: " .. tostring(#legacyHits),
	"",
	"## Current First 35 Lines",
	"",
	numberedExcerpt(finalSource, 1, 35),
}

if #legacyHits > 0 then
	table.insert(output, "")
	table.insert(output, "## Remaining Legacy Tokens")
	table.insert(output, "")
	for _, token in ipairs(legacyHits) do
		table.insert(output, "- " .. token)
	end
end

log("Garage controller header repair complete.")
log("Header replaced: " .. tostring(patchedSource ~= source) .. "; legacy tokens remaining: " .. tostring(#legacyHits))
print(table.concat(output, "\n"))
