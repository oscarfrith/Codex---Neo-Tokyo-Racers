-- Neo Tokyo Racers - Cleanup Phase M: Runtime Root Probe
-- Run in Roblox Studio Command Bar, Edit mode, after Phase M audit.
--
-- Purpose:
--   Investigates the Phase M missing path:
--     Workspace.HOVER_RACING_V2_WORLD
--
-- This is read-only. It checks whether live sources still reference the old
-- runtime world root, whether the old/new runtime objects exist, and whether
-- stale ObjectValues are safe cleanup candidates or a sign that spawn/runtime
-- paths need a migration first.
--
-- Safe effects:
--   - None. This script only reads objects/source and prints to Output.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local TOKENS = {
	"HOVER_RACING_V2_WORLD",
	"PLAYER_VEHICLES_Runtime",
	"GaragePreviewPad",
	"VehicleSpawnPoint",
	"PlayerVehicles_CurrentLive",
	"GaragePreviewPad_CurrentLive",
	"VehicleSpawnPoint_CurrentLive",
	"RuntimeVehicles",
}

local PATHS_TO_CHECK = {
	"Workspace.HOVER_RACING_V2_WORLD",
	"Workspace.HOVER_RACING_V2_WORLD.PLAYER_VEHICLES_Runtime",
	"Workspace.HOVER_RACING_V2_WORLD.GaragePreviewPad",
	"Workspace.HOVER_RACING_V2_WORLD.VehicleSpawnPoint",
	"Workspace.NeoTokyoRacersWorld",
	"Workspace.NeoTokyoRacersWorld.Runtime",
	"Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles",
	"Workspace.NeoTokyoRacersWorld.Garages",
	"Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad",
	"Workspace.NeoTokyoRacersWorld.SpawnPoints",
	"Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint",
	"Workspace.NeoTokyoRacersWorld.City.GeneratedCityBlocks_CurrentLive",
	"Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles_CurrentLive",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Core.PathResolver",
}

local SOURCE_ROOTS = {
	ReplicatedStorage,
	ServerScriptService,
	ServerStorage,
	StarterGui,
	StarterPlayer,
	Workspace,
}

local function log(message)
	print("[NTR Runtime Root Probe] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function underTestWip(instance)
	return string.find(safeFullName(instance), "Test %+ WIP Assets") ~= nil
end

local function isSourceObject(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
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

local function tokenHits(source)
	local hits = {}
	for _, token in ipairs(TOKENS) do
		if string.find(source, token, 1, true) then
			table.insert(hits, token)
		end
	end
	return hits
end

local sourceHits = {}
for _, root in ipairs(SOURCE_ROOTS) do
	for _, instance in ipairs(root:GetDescendants()) do
		if isSourceObject(instance) and not underTestWip(instance) then
			local source = sourceOf(instance)
			if source then
				local hits = tokenHits(source)
				if #hits > 0 then
					table.insert(sourceHits, safeFullName(instance) .. " -- " .. table.concat(hits, ", "))
				end
			end
		end
	end
end
table.sort(sourceHits)

local pathLines = {}
for _, path in ipairs(PATHS_TO_CHECK) do
	local instance = resolvePath(path)
	if instance then
		local suffix = ""
		if instance:IsA("ObjectValue") then
			suffix = " -> " .. (instance.Value and safeFullName(instance.Value) or "nil")
		end
		table.insert(pathLines, "- " .. path .. " : exists <" .. instance.ClassName .. ">" .. suffix)
	else
		table.insert(pathLines, "- " .. path .. " : missing")
	end
end

local output = {
	"# Runtime Root Probe",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"## Runtime Paths",
	"",
	table.concat(pathLines, "\n"),
	"",
	"## Source Hits",
	"",
}

if #sourceHits == 0 then
	table.insert(output, "- None.")
else
	for _, hit in ipairs(sourceHits) do
		table.insert(output, "- " .. hit)
	end
end

table.insert(output, "")
table.insert(output, "## Reading")
table.insert(output, "")

local oldWorld = resolvePath("Workspace.HOVER_RACING_V2_WORLD")
local oldSourceDependent = false
for _, hit in ipairs(sourceHits) do
	if string.find(hit, "HOVER_RACING_V2_WORLD", 1, true) or string.find(hit, "PLAYER_VEHICLES_Runtime", 1, true) then
		oldSourceDependent = true
		break
	end
end

if oldWorld then
	table.insert(output, "- Old runtime root still exists. Do not delete it unless source/runtime owners have been migrated.")
elseif oldSourceDependent then
	table.insert(output, "- Old runtime root is missing, but source still references it. Fix runtime/spawn paths before deleting stale ObjectValues.")
else
	table.insert(output, "- Old runtime root is missing and no source references were found by this probe. Stale ObjectValues are likely safe cleanup candidates.")
end

local newRuntime = resolvePath("Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles")
if newRuntime then
	table.insert(output, "- New runtime vehicle folder exists at Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles.")
else
	table.insert(output, "- New runtime vehicle folder was not found at Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles.")
end

log("Runtime root probe complete. Paste everything below back into Codex.")
print(table.concat(output, "\n"))
