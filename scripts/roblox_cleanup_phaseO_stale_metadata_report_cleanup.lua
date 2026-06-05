-- Neo Tokyo Racers - Cleanup Phase O: Stale Metadata + Report Cleanup
-- Run in Roblox Studio Command Bar, Edit mode, after Phase N and Phase M are clean.
--
-- Purpose:
--   Removes the remaining non-gameplay cleanup clutter after the kit/runtime
--   migrations:
--     - empty legacy remainder folder
--     - old cleanup/migration report folders
--     - stale LegacyName / LegacyKitOldPath attributes
--     - stale LivePath attributes on repaired ObjectValues
--     - old path text in README/StringValue notes
--     - empty future placeholder folders that are not required by live systems
--
-- Destructive effects:
--   - Deletes exact old report/remainder folders and exact empty placeholders.
--   - Clears exact stale metadata attributes.
--   - Updates StringValue text that still mentions old paths.
--
-- Guard rails:
--   - Aborts if the old kit or old runtime world root exists.
--   - Aborts if required NeoTokyoRacers paths are missing.
--   - Aborts if live source still contains old kit/runtime tokens.
--   - Does not touch Workspace.Test + WIP Assets.
--   - Does not delete gameplay assets, active scripts, remotes, vehicle folders,
--     config values, or live runtime folders.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_cleanup_phaseO_stale_metadata_report_cleanup"
local NTR_NAME = "NeoTokyoRacers"

local LEGACY_TOKENS = {
	"HOVER_RACING_V2_KIT",
	"HOVER_RACING_V2_WORLD",
	"PLAYER_VEHICLES_Runtime",
	"CLIENT_MODULES",
	"SHARED_MODULES",
	"REMOTES_DoNotRename",
	"VEHICLE_CATEGORIES",
	"VFX_TEMPLATES",
	"UI_THEME_DoNotRename",
	"PAINT_PRESETS_EditColoursHere",
	"00_EDIT_ME_FIRST",
}

local REQUIRED_PATHS = {
	"ReplicatedStorage.NeoTokyoRacers",
	"ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories",
	"ReplicatedStorage.NeoTokyoRacers.Assets.VFX.VehicleTemplates",
	"ReplicatedStorage.NeoTokyoRacers.Assets.World",
	"ReplicatedStorage.NeoTokyoRacers.Config.Runtime",
	"ReplicatedStorage.NeoTokyoRacers.Config.Editable",
	"ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme",
	"ReplicatedStorage.NeoTokyoRacers.Config.UI.PaintPresets",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Core.PathResolver",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage.GarageInvoke",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage.GaragePush",
	"Workspace.NeoTokyoRacersWorld",
	"Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles",
	"Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad",
	"Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint",
}

local ATTRIBUTES_TO_CLEAR = {
	{ path = "ReplicatedStorage.NeoTokyoRacers", attribute = "LegacyKitOldPath" },
	{ path = "ReplicatedStorage.NeoTokyoRacers.Assets.VFX.VehicleTemplates", attribute = "LegacyName" },
	{ path = "ReplicatedStorage.NeoTokyoRacers.Config.Editable", attribute = "LegacyName" },
	{ path = "ReplicatedStorage.NeoTokyoRacers.Config.UI.PaintPresets", attribute = "LegacyName" },
	{ path = "ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme", attribute = "LegacyName" },
	{ path = "ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client", attribute = "LegacyName" },
	{ path = "ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common", attribute = "LegacyName" },
}

local LIVE_PATH_ATTRIBUTES = {
	{
		path = "Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad_CurrentLive",
		value = "Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad",
	},
	{
		path = "Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles_CurrentLive",
		value = "Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles",
	},
	{
		path = "Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint_CurrentLive",
		value = "Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint",
	},
}

local DELETE_IF_EMPTY_PATHS = {
	"ReplicatedStorage.NeoTokyoRacers.Compatibility.LegacyKitRemainders",
	"ReplicatedStorage.NeoTokyoRacers.Config.Gameplay",
	"ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DRIVING_CAMERA_ASSIST_EditAttributes",
	"ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DRIVING_MECHANICS_EditAttributes",
	"ReplicatedStorage.NeoTokyoRacers.Config.Runtime.HOVER_WOBBLE_EditAttributes",
	"ReplicatedStorage.NeoTokyoRacers.Config.VFX",
	"ReplicatedStorage.NeoTokyoRacers.Config.Vehicles",
	"ReplicatedStorage.NeoTokyoRacers.Config.World",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Input",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Net",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Runtime",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Utility",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.VFX",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Vehicle",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Modules.World",
}

local DELETE_REPORT_FOLDERS = {
	"ReplicatedStorage.NeoTokyoRacers.Compatibility.CleanupReports",
	"ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports",
}

local SOURCE_ROOTS = {
	ReplicatedStorage,
	ServerScriptService,
	ServerStorage,
	StarterGui,
	StarterPlayer,
	Workspace,
}

local TEXT_ROOTS = {
	ReplicatedStorage,
	ServerScriptService,
	ServerStorage,
	StarterGui,
	StarterPlayer,
	Workspace,
	Lighting,
	SoundService,
}

local function log(message)
	print("[NTR Cleanup Phase O] " .. message)
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

local function textHasLegacyToken(text)
	for _, token in ipairs(LEGACY_TOKENS) do
		if string.find(text, token, 1, true) then
			return true
		end
	end
	return false
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

local function modernizeText(text)
	local total = 0
	local function replace(old, new)
		local changed
		text, changed = replaceAllPlain(text, old, new)
		total += changed
	end

	replace("Workspace.HOVER_RACING_V2_WORLD.PLAYER_VEHICLES_Runtime", "Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles")
	replace("Workspace.HOVER_RACING_V2_WORLD.GaragePreviewPad", "Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad")
	replace("Workspace.HOVER_RACING_V2_WORLD.VehicleSpawnPoint", "Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint")
	replace("Workspace.HOVER_RACING_V2_WORLD", "Workspace.NeoTokyoRacersWorld")

	replace("ReplicatedStorage.HOVER_RACING_V2_KIT.CLIENT_MODULES", "ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client")
	replace("ReplicatedStorage.HOVER_RACING_V2_KIT.SHARED_MODULES", "ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common")
	replace("ReplicatedStorage.HOVER_RACING_V2_KIT.REMOTES_DoNotRename", "ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage")
	replace("ReplicatedStorage.HOVER_RACING_V2_KIT.VEHICLE_CATEGORIES", "ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories")
	replace("ReplicatedStorage.HOVER_RACING_V2_KIT.VFX_TEMPLATES", "ReplicatedStorage.NeoTokyoRacers.Assets.VFX.VehicleTemplates")
	replace("ReplicatedStorage.HOVER_RACING_V2_KIT.UI_THEME_DoNotRename", "ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme")
	replace("ReplicatedStorage.HOVER_RACING_V2_KIT.PAINT_PRESETS_EditColoursHere", "ReplicatedStorage.NeoTokyoRacers.Config.UI.PaintPresets")
	replace("ReplicatedStorage.HOVER_RACING_V2_KIT.00_EDIT_ME_FIRST", "ReplicatedStorage.NeoTokyoRacers.Config.Editable")
	replace("ReplicatedStorage.HOVER_RACING_V2_KIT.CONFIG", "ReplicatedStorage.NeoTokyoRacers.Config.Runtime")
	replace("ReplicatedStorage.HOVER_RACING_V2_KIT", "ReplicatedStorage.NeoTokyoRacers")

	replace("HOVER_RACING_V2_KIT", "NeoTokyoRacers")
	replace("HOVER_RACING_V2_WORLD", "NeoTokyoRacersWorld")
	replace("PLAYER_VEHICLES_Runtime", "Runtime.PlayerVehicles")
	replace("CLIENT_MODULES", "Shared.Modules.Client")
	replace("SHARED_MODULES", "Shared.Modules.Common")
	replace("REMOTES_DoNotRename", "Shared.Remotes.Garage")
	replace("VEHICLE_CATEGORIES", "Assets.Vehicles.Categories")
	replace("VFX_TEMPLATES", "Assets.VFX.VehicleTemplates")
	replace("UI_THEME_DoNotRename", "Config.UI.Theme")
	replace("PAINT_PRESETS_EditColoursHere", "Config.UI.PaintPresets")
	replace("00_EDIT_ME_FIRST", "Config.Editable")

	return text, total
end

local function collectSourceLegacyHits()
	local hits = {}
	for _, root in ipairs(SOURCE_ROOTS) do
		for _, instance in ipairs(root:GetDescendants()) do
			if isSourceObject(instance) and not underTestWip(instance) then
				local source = sourceOf(instance)
				if source and textHasLegacyToken(source) then
					table.insert(hits, safeFullName(instance))
				end
			end
		end
	end
	table.sort(hits)
	return hits
end

local function preflight()
	local missing = {}
	for _, path in ipairs(REQUIRED_PATHS) do
		if not resolvePath(path) then
			table.insert(missing, path)
		end
	end

	if #missing > 0 then
		error("Phase O stopped because required migrated paths are missing:\n- " .. table.concat(missing, "\n- "))
	end

	if ReplicatedStorage:FindFirstChild("HOVER_RACING_V2_KIT") then
		error("Phase O stopped because ReplicatedStorage.HOVER_RACING_V2_KIT still exists.")
	end

	if Workspace:FindFirstChild("HOVER_RACING_V2_WORLD") then
		error("Phase O stopped because Workspace.HOVER_RACING_V2_WORLD still exists.")
	end

	local sourceHits = collectSourceLegacyHits()
	if #sourceHits > 0 then
		error("Phase O stopped because source still contains old migration tokens:\n- " .. table.concat(sourceHits, "\n- "))
	end
end

local function destroyPath(path, changes)
	local instance = resolvePath(path)
	if not instance then
		return
	end
	if underTestWip(instance) then
		error("Refusing to delete under Test + WIP Assets: " .. safeFullName(instance))
	end
	instance:Destroy()
	table.insert(changes, "Deleted " .. path)
end

local function destroyIfEmpty(path, changes)
	local instance = resolvePath(path)
	if not instance then
		return
	end
	if underTestWip(instance) then
		error("Refusing to delete under Test + WIP Assets: " .. safeFullName(instance))
	end
	if not instance:IsA("Folder") then
		table.insert(changes, "Skipped " .. path .. " because it is " .. instance.ClassName .. ", expected Folder")
		return
	end
	if #instance:GetChildren() > 0 then
		table.insert(changes, "Skipped non-empty folder " .. path)
		return
	end
	instance:Destroy()
	table.insert(changes, "Deleted empty folder " .. path)
end

preflight()

local changes = {}
local textValuesChanged = 0
local textReplacements = 0
local attributesCleared = 0
local attributesUpdated = 0

for _, path in ipairs(DELETE_REPORT_FOLDERS) do
	destroyPath(path, changes)
end

for _, item in ipairs(ATTRIBUTES_TO_CLEAR) do
	local instance = resolvePath(item.path)
	if instance and instance:GetAttribute(item.attribute) ~= nil then
		instance:SetAttribute(item.attribute, nil)
		attributesCleared += 1
		table.insert(changes, "Cleared " .. item.path .. " attr " .. item.attribute)
	end
end

for _, item in ipairs(LIVE_PATH_ATTRIBUTES) do
	local instance = resolvePath(item.path)
	if instance then
		instance:SetAttribute("LivePath", item.value)
		instance:SetAttribute("PhaseORepairedBy", SCRIPT_ID)
		attributesUpdated += 1
		table.insert(changes, "Updated " .. item.path .. " attr LivePath")
	end
end

for _, root in ipairs(TEXT_ROOTS) do
	for _, instance in ipairs(root:GetDescendants()) do
		if instance:IsA("StringValue") and not underTestWip(instance) then
			local path = safeFullName(instance)
			if string.find(path, ".Compatibility.CleanupReports.", 1, true) == nil
				and string.find(path, ".Compatibility.MigrationReports.", 1, true) == nil
				and textHasLegacyToken(instance.Value) then
				local updated, count = modernizeText(instance.Value)
				if count > 0 and updated ~= instance.Value then
					instance.Value = updated
					instance:SetAttribute("PhaseOTextUpdatedBy", SCRIPT_ID)
					instance:SetAttribute("PhaseOTextUpdatedAt", os.date("%Y-%m-%d %H:%M:%S"))
					textValuesChanged += 1
					textReplacements += count
					table.insert(changes, "Updated text " .. path .. " replacements=" .. tostring(count))
				end
			end
		end
	end
end

for _, path in ipairs(DELETE_IF_EMPTY_PATHS) do
	destroyIfEmpty(path, changes)
end

local remainingSourceHits = collectSourceLegacyHits()
if #remainingSourceHits > 0 then
	warn("[NTR Cleanup Phase O] Source legacy hits remain after cleanup. Paste this output back into Codex.")
end

local output = {
	"# Cleanup Phase O Summary",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Report/remainder/empty-folder changes: " .. tostring(#changes),
	"- Attributes cleared: " .. tostring(attributesCleared),
	"- LivePath attributes updated: " .. tostring(attributesUpdated),
	"- StringValues updated: " .. tostring(textValuesChanged),
	"- Text replacements applied: " .. tostring(textReplacements),
	"- Remaining source legacy hits: " .. tostring(#remainingSourceHits),
	"",
	"## Changes",
	"",
}

if #changes == 0 then
	table.insert(output, "- None.")
else
	for _, item in ipairs(changes) do
		table.insert(output, "- " .. item)
	end
end

log("Stale metadata/report cleanup complete.")
log("Attributes cleared: " .. tostring(attributesCleared) .. "; StringValues updated: " .. tostring(textValuesChanged) .. "; remaining source hits: " .. tostring(#remainingSourceHits))
log("Run Cleanup Phase M again to confirm the final action sections are clean.")
print(table.concat(output, "\n"))
