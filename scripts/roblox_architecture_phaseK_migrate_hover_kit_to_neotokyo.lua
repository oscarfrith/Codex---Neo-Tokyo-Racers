-- Neo Tokyo Racers - Architecture Phase K: Move HOVER_RACING_V2_KIT Into NeoTokyoRacers
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Migrates the old ReplicatedStorage.HOVER_RACING_V2_KIT root into the
--   ReplicatedStorage.NeoTokyoRacers architecture, then patches live source
--   references away from the old kit path.
--
-- Design:
--   - Moves old kit domains into clean NeoTokyoRacers domains.
--   - Preserves stable inner folder shapes where current gameplay code depends
--     on them, so the migration is much less fragile than a full internal rename.
--   - Adds Shared.Modules.Core.PathResolver for future code.
--   - Aborts before moving anything if live source still contains legacy kit
--     references after the planned source patch.
--
-- Does NOT:
--   - Create in-game backup folders.
--   - Touch Workspace.Test + WIP Assets.
--   - Rewrite gameplay logic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_architecture_phaseK_migrate_hover_kit_to_neotokyo"
local LEGACY_KIT_NAME = "HOVER_RACING_V2_KIT"
local NTR_NAME = "NeoTokyoRacers"

local function log(message)
	print("[NTR Phase K] " .. message)
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

local function copyAttributes(source, destination)
	for key, value in pairs(source:GetAttributes()) do
		local valueType = typeof(value)
		if valueType == "string" or valueType == "number" or valueType == "boolean" or valueType == "Color3" or valueType == "Vector3" then
			destination:SetAttribute(key, value)
		end
	end
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

local function patchSourceText(source)
	local total = 0

	local function replace(old, new)
		local changed
		source, changed = replaceAllPlain(source, old, new)
		total += changed
	end

	replace('"HOVER_RACING_V2_KIT"', '"NeoTokyoRacers"')
	replace("'HOVER_RACING_V2_KIT'", "'NeoTokyoRacers'")
	replace(".HOVER_RACING_V2_KIT", ".NeoTokyoRacers")

	local rootPathReplacements = {
		{
			old = "ReplicatedStorage.NeoTokyoRacers.CLIENT_MODULES",
			new = "ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client",
		},
		{
			old = "ReplicatedStorage.NeoTokyoRacers.SHARED_MODULES",
			new = "ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Common",
		},
		{
			old = "ReplicatedStorage.NeoTokyoRacers.REMOTES_DoNotRename",
			new = "ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage",
		},
		{
			old = "ReplicatedStorage.NeoTokyoRacers.VEHICLE_CATEGORIES",
			new = "ReplicatedStorage.NeoTokyoRacers.Assets.Vehicles.Categories",
		},
		{
			old = "ReplicatedStorage.NeoTokyoRacers.VFX_TEMPLATES",
			new = "ReplicatedStorage.NeoTokyoRacers.Assets.VFX.VehicleTemplates",
		},
		{
			old = "ReplicatedStorage.NeoTokyoRacers.UI_THEME_DoNotRename",
			new = "ReplicatedStorage.NeoTokyoRacers.Config.UI.Theme",
		},
		{
			old = "ReplicatedStorage.NeoTokyoRacers.PAINT_PRESETS_EditColoursHere",
			new = "ReplicatedStorage.NeoTokyoRacers.Config.UI.PaintPresets",
		},
		{
			old = "ReplicatedStorage.NeoTokyoRacers.00_EDIT_ME_FIRST",
			new = "ReplicatedStorage.NeoTokyoRacers.Config.Editable",
		},
		{
			old = "ReplicatedStorage.NeoTokyoRacers.CONFIG",
			new = "ReplicatedStorage.NeoTokyoRacers.Config.Runtime",
		},
	}

	for _, pathReplacement in ipairs(rootPathReplacements) do
		replace(pathReplacement.old, pathReplacement.new)
	end

	replace('local CONFIG_ROOT_NAME = "00_EDIT_ME_FIRST"', 'local CONFIG_ROOT_NAME = "Editable"')
	replace("local CONFIG_ROOT_NAME = '00_EDIT_ME_FIRST'", "local CONFIG_ROOT_NAME = 'Editable'")
	replace('local VFX_FOLDER_NAME = "VFX_TEMPLATES"', 'local VFX_FOLDER_NAME = "VehicleTemplates"')
	replace("local VFX_FOLDER_NAME = 'VFX_TEMPLATES'", "local VFX_FOLDER_NAME = 'VehicleTemplates'")
	replace('local THEME_FOLDER_NAME = "UI_THEME_DoNotRename"', 'local THEME_FOLDER_NAME = "Theme"')
	replace("local THEME_FOLDER_NAME = 'UI_THEME_DoNotRename'", "local THEME_FOLDER_NAME = 'Theme'")
	replace("Reads UI_THEME_DoNotRename values", "Reads Config.UI.Theme values")

	replace('kit and kit:FindFirstChild(CONFIG_ROOT_NAME)', 'kit and kit:WaitForChild("Config"):FindFirstChild(CONFIG_ROOT_NAME)')
	replace("kit and kit:FindFirstChild(CONFIG_ROOT_NAME)", "kit and kit:WaitForChild('Config'):FindFirstChild(CONFIG_ROOT_NAME)")
	replace('kit:FindFirstChild(CONFIG_ROOT_NAME)', 'kit:WaitForChild("Config"):FindFirstChild(CONFIG_ROOT_NAME)')
	replace("kit:FindFirstChild(CONFIG_ROOT_NAME)", "kit:WaitForChild('Config'):FindFirstChild(CONFIG_ROOT_NAME)")
	replace('kit:WaitForChild(CONFIG_ROOT_NAME)', 'kit:WaitForChild("Config"):WaitForChild(CONFIG_ROOT_NAME)')
	replace("kit:WaitForChild(CONFIG_ROOT_NAME)", "kit:WaitForChild('Config'):WaitForChild(CONFIG_ROOT_NAME)")

	replace('kit:FindFirstChild(VFX_FOLDER_NAME)', 'kit:WaitForChild("Assets"):WaitForChild("VFX"):FindFirstChild(VFX_FOLDER_NAME)')
	replace("kit:FindFirstChild(VFX_FOLDER_NAME)", "kit:WaitForChild('Assets'):WaitForChild('VFX'):FindFirstChild(VFX_FOLDER_NAME)")
	replace('kit:WaitForChild(VFX_FOLDER_NAME)', 'kit:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild(VFX_FOLDER_NAME)')
	replace("kit:WaitForChild(VFX_FOLDER_NAME)", "kit:WaitForChild('Assets'):WaitForChild('VFX'):WaitForChild(VFX_FOLDER_NAME)")

	replace('kit:FindFirstChild(THEME_FOLDER_NAME)', 'kit:WaitForChild("Config"):WaitForChild("UI"):FindFirstChild(THEME_FOLDER_NAME)')
	replace("kit:FindFirstChild(THEME_FOLDER_NAME)", "kit:WaitForChild('Config'):WaitForChild('UI'):FindFirstChild(THEME_FOLDER_NAME)")
	replace('kit:WaitForChild(THEME_FOLDER_NAME)', 'kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild(THEME_FOLDER_NAME)')
	replace("kit:WaitForChild(THEME_FOLDER_NAME)", "kit:WaitForChild('Config'):WaitForChild('UI'):WaitForChild(THEME_FOLDER_NAME)")
	replace('kit:WaitForChild(THEME_FOLDER_NAME, 5)', 'kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild(THEME_FOLDER_NAME)')
	replace("kit:WaitForChild(THEME_FOLDER_NAME, 5)", "kit:WaitForChild('Config'):WaitForChild('UI'):WaitForChild(THEME_FOLDER_NAME)")

	for _, quote in ipairs({ '"', "'" }) do
		local function q(text)
			return quote .. text .. quote
		end

		replace(":WaitForChild(" .. q("CLIENT_MODULES") .. ")", ":WaitForChild(" .. q("Shared") .. "):WaitForChild(" .. q("Modules") .. "):WaitForChild(" .. q("Client") .. ")")
		replace(":FindFirstChild(" .. q("CLIENT_MODULES") .. ")", ":WaitForChild(" .. q("Shared") .. "):WaitForChild(" .. q("Modules") .. "):WaitForChild(" .. q("Client") .. ")")

		replace(":WaitForChild(" .. q("SHARED_MODULES") .. ")", ":WaitForChild(" .. q("Shared") .. "):WaitForChild(" .. q("Modules") .. "):WaitForChild(" .. q("Common") .. ")")
		replace(":FindFirstChild(" .. q("SHARED_MODULES") .. ")", ":WaitForChild(" .. q("Shared") .. "):WaitForChild(" .. q("Modules") .. "):WaitForChild(" .. q("Common") .. ")")

		replace(":WaitForChild(" .. q("REMOTES_DoNotRename") .. ")", ":WaitForChild(" .. q("Shared") .. "):WaitForChild(" .. q("Remotes") .. "):WaitForChild(" .. q("Garage") .. ")")
		replace(":FindFirstChild(" .. q("REMOTES_DoNotRename") .. ")", ":WaitForChild(" .. q("Shared") .. "):WaitForChild(" .. q("Remotes") .. "):WaitForChild(" .. q("Garage") .. ")")

		replace(":WaitForChild(" .. q("VEHICLE_CATEGORIES") .. ")", ":WaitForChild(" .. q("Assets") .. "):WaitForChild(" .. q("Vehicles") .. "):WaitForChild(" .. q("Categories") .. ")")
		replace(":FindFirstChild(" .. q("VEHICLE_CATEGORIES") .. ")", ":WaitForChild(" .. q("Assets") .. "):WaitForChild(" .. q("Vehicles") .. "):WaitForChild(" .. q("Categories") .. ")")

		replace(":WaitForChild(" .. q("VFX_TEMPLATES") .. ")", ":WaitForChild(" .. q("Assets") .. "):WaitForChild(" .. q("VFX") .. "):WaitForChild(" .. q("VehicleTemplates") .. ")")
		replace(":WaitForChild(" .. q("VFX_TEMPLATES") .. ", 10)", ":WaitForChild(" .. q("Assets") .. "):WaitForChild(" .. q("VFX") .. "):WaitForChild(" .. q("VehicleTemplates") .. ")")
		replace(":FindFirstChild(" .. q("VFX_TEMPLATES") .. ")", ":WaitForChild(" .. q("Assets") .. "):WaitForChild(" .. q("VFX") .. "):WaitForChild(" .. q("VehicleTemplates") .. ")")

		replace(":WaitForChild(" .. q("UI_THEME_DoNotRename") .. ")", ":WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("UI") .. "):WaitForChild(" .. q("Theme") .. ")")
		replace(":WaitForChild(" .. q("UI_THEME_DoNotRename") .. ", 5)", ":WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("UI") .. "):WaitForChild(" .. q("Theme") .. ")")
		replace(":FindFirstChild(" .. q("UI_THEME_DoNotRename") .. ")", ":WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("UI") .. "):WaitForChild(" .. q("Theme") .. ")")

		replace(":WaitForChild(" .. q("PAINT_PRESETS_EditColoursHere") .. ")", ":WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("UI") .. "):WaitForChild(" .. q("PaintPresets") .. ")")
		replace(":FindFirstChild(" .. q("PAINT_PRESETS_EditColoursHere") .. ")", ":WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("UI") .. "):WaitForChild(" .. q("PaintPresets") .. ")")

		replace(":WaitForChild(" .. q("CONFIG") .. ")", ":WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("Runtime") .. ")")
		replace(":FindFirstChild(" .. q("CONFIG") .. ")", ":WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("Runtime") .. ")")

		replace(":WaitForChild(" .. q("00_EDIT_ME_FIRST") .. ")", ":WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("Editable") .. ")")
		replace(":FindFirstChild(" .. q("00_EDIT_ME_FIRST") .. ")", ":WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("Editable") .. ")")

		local helperPathByLegacyName = {
			CLIENT_MODULES = "kit:WaitForChild(" .. q("Shared") .. "):WaitForChild(" .. q("Modules") .. "):WaitForChild(" .. q("Client") .. ")",
			SHARED_MODULES = "kit:WaitForChild(" .. q("Shared") .. "):WaitForChild(" .. q("Modules") .. "):WaitForChild(" .. q("Common") .. ")",
			REMOTES_DoNotRename = "kit:WaitForChild(" .. q("Shared") .. "):WaitForChild(" .. q("Remotes") .. "):WaitForChild(" .. q("Garage") .. ")",
			VEHICLE_CATEGORIES = "kit:WaitForChild(" .. q("Assets") .. "):WaitForChild(" .. q("Vehicles") .. "):WaitForChild(" .. q("Categories") .. ")",
			VFX_TEMPLATES = "kit:WaitForChild(" .. q("Assets") .. "):WaitForChild(" .. q("VFX") .. "):WaitForChild(" .. q("VehicleTemplates") .. ")",
			UI_THEME_DoNotRename = "kit:WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("UI") .. "):WaitForChild(" .. q("Theme") .. ")",
			PAINT_PRESETS_EditColoursHere = "kit:WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("UI") .. "):WaitForChild(" .. q("PaintPresets") .. ")",
			CONFIG = "kit:WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("Runtime") .. ")",
			["00_EDIT_ME_FIRST"] = "kit:WaitForChild(" .. q("Config") .. "):WaitForChild(" .. q("Editable") .. ")",
		}

		for legacyName, replacementPath in pairs(helperPathByLegacyName) do
			replace("requireChild(kit, " .. q(legacyName) .. ")", replacementPath)
			replace("findChild(kit, " .. q(legacyName) .. ")", replacementPath)
			replace("ensureFolder(kit, " .. q(legacyName) .. ")", replacementPath)
			replace("getOrCreate(kit, " .. q("Folder") .. ", " .. q(legacyName) .. ")", replacementPath)
		end

		replace(".CLIENT_MODULES", ".Shared.Modules.Client")
		replace(".SHARED_MODULES", ".Shared.Modules.Common")
		replace(".REMOTES_DoNotRename", ".Shared.Remotes.Garage")
		replace(".VEHICLE_CATEGORIES", ".Assets.Vehicles.Categories")
		replace(".VFX_TEMPLATES", ".Assets.VFX.VehicleTemplates")
		replace(".UI_THEME_DoNotRename", ".Config.UI.Theme")
		replace(".PAINT_PRESETS_EditColoursHere", ".Config.UI.PaintPresets")
		replace(".00_EDIT_ME_FIRST", ".Config.Editable")
		replace(".CONFIG", ".Config.Runtime")
	end

	return source, total
end

local legacyTokens = {
	"HOVER_RACING_V2_KIT",
	"CLIENT_MODULES",
	"SHARED_MODULES",
	"REMOTES_DoNotRename",
	"VEHICLE_CATEGORIES",
	"VFX_TEMPLATES",
	"UI_THEME_DoNotRename",
	"PAINT_PRESETS_EditColoursHere",
	"00_EDIT_ME_FIRST",
}

local function remainingLegacyTokens(source)
	local found = {}
	for _, token in ipairs(legacyTokens) do
		if string.find(source, token, 1, true) then
			table.insert(found, token)
		end
	end
	return found
end

local function isSourceObject(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript") or instance:IsA("ModuleScript")
end

local function collectSourceObjects()
	local roots = {
		ReplicatedStorage,
		ServerScriptService,
		StarterPlayer,
		StarterGui,
	}

	local results = {}
	for _, root in ipairs(roots) do
		for _, instance in ipairs(root:GetDescendants()) do
			if isSourceObject(instance) and not underTestWip(instance) then
				table.insert(results, instance)
			end
		end
	end
	return results
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

local function preflightSources()
	local blockers = {}
	local patchableCount = 0

	for _, instance in ipairs(collectSourceObjects()) do
		local source = sourceOf(instance)
		if source then
			local patched, replacementCount = patchSourceText(source)
			if replacementCount > 0 then
				patchableCount += 1
			end

			local leftovers = remainingLegacyTokens(patched)
			if #leftovers > 0 then
				table.insert(blockers, safeFullName(instance) .. " still contains: " .. table.concat(leftovers, ", "))
			end
		end
	end

	if #blockers > 0 then
		local message = {
			"Phase K preflight stopped before moving anything.",
			"Some source objects still contain old kit path tokens after the planned patch.",
			"Paste this blocker list back into Codex so the patcher can be taught the exact source shape:",
			"",
		}
		for index, blocker in ipairs(blockers) do
			if index <= 30 then
				table.insert(message, "- " .. blocker)
			elseif index == 31 then
				table.insert(message, "- ... plus " .. tostring(#blockers - 30) .. " more.")
				break
			end
		end
		error(table.concat(message, "\n"))
	end

	return patchableCount
end

local moveLog = {}

local function mergeInstances(source, destination)
	if source == destination then
		return
	end

	if source:IsA("Folder") and destination:IsA("Folder") then
		copyAttributes(source, destination)
		for _, childInstance in ipairs(source:GetChildren()) do
			local existing = destination:FindFirstChild(childInstance.Name)
			if existing then
				mergeInstances(childInstance, existing)
			else
				childInstance.Parent = destination
				table.insert(moveLog, safeFullName(childInstance))
			end
		end
		source:Destroy()
		return
	end

	if source.ClassName ~= destination.ClassName then
		error(("Migration conflict: cannot merge %s <%s> into %s <%s>. No changes applied past this point."):format(
			safeFullName(source),
			source.ClassName,
			safeFullName(destination),
			destination.ClassName
		))
	end

	copyAttributes(source, destination)

	if source:IsA("ModuleScript") or source:IsA("Script") or source:IsA("LocalScript") then
		destination.Source = source.Source
	elseif source:IsA("ValueBase") then
		destination.Value = source.Value
	end

	for _, childInstance in ipairs(source:GetChildren()) do
		local existing = destination:FindFirstChild(childInstance.Name)
		if existing then
			mergeInstances(childInstance, existing)
		else
			childInstance.Parent = destination
		end
	end

	source:Destroy()
end

local function moveChild(sourceParent, sourceName, destinationParent, destinationName)
	local source = sourceParent and sourceParent:FindFirstChild(sourceName)
	if not source then
		return nil
	end

	local targetName = destinationName or sourceName
	local existing = destinationParent:FindFirstChild(targetName)
	if existing then
		mergeInstances(source, existing)
		table.insert(moveLog, sourceName .. " merged into " .. safeFullName(existing))
		return existing
	end

	source.Name = targetName
	source.Parent = destinationParent
	source:SetAttribute("MigratedBy", SCRIPT_ID)
	source:SetAttribute("LegacyName", sourceName)
	table.insert(moveLog, sourceName .. " -> " .. safeFullName(source))
	return source
end

local function writePathResolver(coreModules)
	local resolver = child(coreModules, "ModuleScript", "PathResolver")
	resolver.Source = [=[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ROOT_NAME = "NeoTokyoRacers"

local PathResolver = {}

local function root()
	return ReplicatedStorage:WaitForChild(ROOT_NAME)
end

local function waitPath(parent, ...)
	local current = parent
	for _, name in ipairs({ ... }) do
		current = current:WaitForChild(name)
	end
	return current
end

function PathResolver.Root()
	return root()
end

function PathResolver.Assets()
	return waitPath(root(), "Assets")
end

function PathResolver.VehicleCategories()
	return waitPath(root(), "Assets", "Vehicles", "Categories")
end

function PathResolver.VehicleVFXTemplates()
	return waitPath(root(), "Assets", "VFX", "VehicleTemplates")
end

function PathResolver.WorldAssets()
	return waitPath(root(), "Assets", "World")
end

function PathResolver.SharedModules()
	return waitPath(root(), "Shared", "Modules")
end

function PathResolver.ClientModules()
	return waitPath(root(), "Shared", "Modules", "Client")
end

function PathResolver.CommonModules()
	return waitPath(root(), "Shared", "Modules", "Common")
end

function PathResolver.GarageRemotes()
	return waitPath(root(), "Shared", "Remotes", "Garage")
end

function PathResolver.RuntimeConfig()
	return waitPath(root(), "Config", "Runtime")
end

function PathResolver.EditableConfig()
	return waitPath(root(), "Config", "Editable")
end

function PathResolver.UITheme()
	return waitPath(root(), "Config", "UI", "Theme")
end

function PathResolver.PaintPresets()
	return waitPath(root(), "Config", "UI", "PaintPresets")
end

function PathResolver.RuntimeVehicles()
	local world = Workspace:WaitForChild("HOVER_RACING_V2_WORLD")
	return world:WaitForChild("PLAYER_VEHICLES_Runtime")
end

return PathResolver
]=]
	resolver:SetAttribute("CreatedBy", SCRIPT_ID)
	resolver:SetAttribute("MigrationStatus", "LivePathResolver")
	return resolver
end

local function applySourcePatches()
	local patchedCount = 0
	local replacements = 0

	for _, instance in ipairs(collectSourceObjects()) do
		local source = sourceOf(instance)
		if source then
			local patched, replacementCount = patchSourceText(source)
			if replacementCount > 0 and patched ~= source then
				instance.Source = patched
				instance:SetAttribute("PhaseKSourcePatchedBy", SCRIPT_ID)
				instance:SetAttribute("PhaseKSourcePatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
				patchedCount += 1
				replacements += replacementCount
			end
		end
	end

	return patchedCount, replacements
end

local function finalSourceAudit()
	local hits = {}
	for _, instance in ipairs(collectSourceObjects()) do
		local source = sourceOf(instance)
		if source then
			local leftovers = remainingLegacyTokens(source)
			if #leftovers > 0 then
				table.insert(hits, safeFullName(instance) .. " still contains: " .. table.concat(leftovers, ", "))
			end
		end
	end
	table.sort(hits)
	return hits
end

local legacyKit = ReplicatedStorage:FindFirstChild(LEGACY_KIT_NAME)
if legacyKit and not legacyKit:IsA("Folder") then
	error("ReplicatedStorage." .. LEGACY_KIT_NAME .. " exists but is " .. legacyKit.ClassName .. ", expected Folder.")
end

local patchableCount = preflightSources()

local ntr = folder(ReplicatedStorage, NTR_NAME)
ntr:SetAttribute("PhaseKMigrationApplied", true)
ntr:SetAttribute("PhaseKMigrationAppliedAt", os.date("%Y-%m-%d %H:%M:%S"))

if legacyKit then
	copyAttributes(legacyKit, ntr)
	ntr:SetAttribute("LegacyKitWasMigrated", true)
	ntr:SetAttribute("LegacyKitOldPath", "ReplicatedStorage." .. LEGACY_KIT_NAME)
end

local assets = folder(ntr, "Assets")
local vehicleAssets = folder(assets, "Vehicles")
local vfxAssets = folder(assets, "VFX")
folder(assets, "World")

local config = folder(ntr, "Config")
local configUI = folder(config, "UI")
folder(config, "Gameplay")
folder(config, "Vehicles")
folder(config, "VFX")
folder(config, "World")

local shared = folder(ntr, "Shared")
local sharedModules = folder(shared, "Modules")
local coreModules = folder(sharedModules, "Core")
folder(sharedModules, "Vehicle")
folder(sharedModules, "UI")
folder(sharedModules, "Input")
folder(sharedModules, "VFX")
local sharedRemotes = folder(shared, "Remotes")

local compatibility = folder(ntr, "Compatibility")
local reportsRoot = folder(compatibility, "MigrationReports")
local remainders = folder(compatibility, "LegacyKitRemainders")

writePathResolver(coreModules)

if legacyKit then
	moveChild(legacyKit, "VEHICLE_CATEGORIES", vehicleAssets, "Categories")
	moveChild(legacyKit, "VFX_TEMPLATES", vfxAssets, "VehicleTemplates")
	moveChild(legacyKit, "REMOTES_DoNotRename", sharedRemotes, "Garage")
	moveChild(legacyKit, "CLIENT_MODULES", sharedModules, "Client")
	moveChild(legacyKit, "SHARED_MODULES", sharedModules, "Common")
	moveChild(legacyKit, "UI_THEME_DoNotRename", configUI, "Theme")
	moveChild(legacyKit, "PAINT_PRESETS_EditColoursHere", configUI, "PaintPresets")
	moveChild(legacyKit, "CONFIG", config, "Runtime")
	moveChild(legacyKit, "00_EDIT_ME_FIRST", config, "Editable")

	for _, leftover in ipairs(legacyKit:GetChildren()) do
		local existing = remainders:FindFirstChild(leftover.Name)
		if existing then
			mergeInstances(leftover, existing)
		else
			leftover.Parent = remainders
			leftover:SetAttribute("MigratedBy", SCRIPT_ID)
			leftover:SetAttribute("MigrationNote", "Unmapped legacy kit child kept for review after Phase K.")
			table.insert(moveLog, "unmapped " .. leftover.Name .. " -> " .. safeFullName(leftover))
		end
	end

	if #legacyKit:GetChildren() == 0 then
		legacyKit:Destroy()
	end
end

local patchedCount, replacementCount = applySourcePatches()
local finalHits = finalSourceAudit()

local reportLines = {
	"# Neo Tokyo Racers Phase K Kit Migration",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Legacy kit existed: " .. tostring(legacyKit ~= nil),
	"- Source objects patchable in preflight: " .. tostring(patchableCount),
	"- Source objects patched: " .. tostring(patchedCount),
	"- Text replacements applied: " .. tostring(replacementCount),
	"- Move/merge operations: " .. tostring(#moveLog),
	"- Final legacy source hits: " .. tostring(#finalHits),
	"",
	"## Moved / Merged",
	"",
}

if #moveLog == 0 then
	table.insert(reportLines, "- None.")
else
	for _, item in ipairs(moveLog) do
		table.insert(reportLines, "- " .. item)
	end
end

table.insert(reportLines, "")
table.insert(reportLines, "## Final Source Audit")
table.insert(reportLines, "")

if #finalHits == 0 then
	table.insert(reportLines, "- No legacy kit source references found.")
else
	for _, hit in ipairs(finalHits) do
		table.insert(reportLines, "- " .. hit)
	end
end

local report = reportsRoot:FindFirstChild("PhaseK_HoverKitMigration")
if report and not report:IsA("StringValue") then
	report.Name = "PhaseK_HoverKitMigration_OldNonStringValue"
	report = nil
end
if not report then
	report = Instance.new("StringValue")
	report.Name = "PhaseK_HoverKitMigration"
	report.Parent = reportsRoot
end
report.Value = table.concat(reportLines, "\n")
report:SetAttribute("CreatedBy", SCRIPT_ID)
report:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))

log("Phase K migration complete.")
log("Report: " .. safeFullName(report))
log("Source patched: " .. tostring(patchedCount) .. "; replacements: " .. tostring(replacementCount) .. "; final legacy hits: " .. tostring(#finalHits))

if #finalHits > 0 then
	warn("[NTR Phase K] Migration completed but legacy source references remain. Paste the report back into Codex before deleting any compatibility remainders.")
else
	log("No legacy kit source references remain.")
end

print(report.Value)
