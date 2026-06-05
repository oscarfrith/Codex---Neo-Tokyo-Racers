-- Neo Tokyo Racers - Architecture Phase N: Runtime World Path Repair
-- Run in Roblox Studio Command Bar, Edit mode, after Phase M runtime probe.
--
-- Purpose:
--   Repairs the remaining live references to the removed
--   Workspace.HOVER_RACING_V2_WORLD runtime root.
--
-- It retargets runtime systems to:
--   Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles
--   Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad
--   Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint
--
-- Safe design:
--   - Preflights every source patch first.
--   - Aborts before changing anything if old runtime tokens would remain.
--   - Creates only a missing VehicleSpawnPoint marker if needed.
--   - Updates stale ObjectValues to point at migrated live objects.
--   - Does not delete gameplay objects.
--   - Does not touch Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_architecture_phaseN_runtime_world_path_repair"
local NTR_NAME = "NeoTokyoRacers"

local OLD_WORLD = "HOVER_RACING_V2_WORLD"
local OLD_RUNTIME = "PLAYER_VEHICLES_Runtime"

local NEW_WORLD = "NeoTokyoRacersWorld"
local NEW_RUNTIME_FOLDER = "Runtime"
local NEW_RUNTIME_VEHICLES = "PlayerVehicles"
local NEW_GARAGES_FOLDER = "Garages"
local NEW_PREVIEW_PAD = "GaragePreviewPad"
local NEW_SPAWN_FOLDER = "SpawnPoints"
local NEW_SPAWN_POINT = "VehicleSpawnPoint"

local function log(message)
	print("[NTR Phase N] " .. message)
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

local function waitPath(parent, ...)
	local current = parent
	for _, name in ipairs({ ... }) do
		current = current:WaitForChild(name)
	end
	return current
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

local function sourceRuntimeTokens(source)
	local found = {}
	if string.find(source, OLD_WORLD, 1, true) then
		table.insert(found, OLD_WORLD)
	end
	if string.find(source, OLD_RUNTIME, 1, true) then
		table.insert(found, OLD_RUNTIME)
	end
	return found
end

local CORE_PATH_RESOLVER_SOURCE = [=[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ROOT_NAME = "NeoTokyoRacers"
local WORLD_NAME = "NeoTokyoRacersWorld"

local PathResolver = {}

local function root()
	return ReplicatedStorage:WaitForChild(ROOT_NAME)
end

local function world()
	return Workspace:WaitForChild(WORLD_NAME)
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

function PathResolver.World()
	return world()
end

function PathResolver.Runtime()
	return waitPath(world(), "Runtime")
end

function PathResolver.RuntimeVehicles()
	return waitPath(world(), "Runtime", "PlayerVehicles")
end

function PathResolver.GaragePreviewPad()
	return waitPath(world(), "Garages", "GaragePreviewPad")
end

function PathResolver.VehicleSpawnPoint()
	return waitPath(world(), "SpawnPoints", "VehicleSpawnPoint")
end

return PathResolver
]=]

local function patchSourceText(source)
	local total = 0
	local sourceHadOldWorld = string.find(source, OLD_WORLD, 1, true) ~= nil

	local function replace(old, new)
		local changed
		source, changed = replaceAllPlain(source, old, new)
		total += changed
	end

	local function replacePattern(pattern, new)
		local changed
		source, changed = string.gsub(source, pattern, new)
		total += changed
	end

	local newRuntimePath = 'Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("Runtime"):WaitForChild("PlayerVehicles")'
	local newRuntimeFindExpression = '(function() local world = Workspace:FindFirstChild("NeoTokyoRacersWorld"); local runtime = world and world:FindFirstChild("Runtime"); return runtime and runtime:FindFirstChild("PlayerVehicles") end)()'

	replace('local VEHICLES_NAME = "PLAYER_VEHICLES_Runtime"', 'local RUNTIME_FOLDER_NAME = "Runtime"\nlocal VEHICLES_NAME = "PlayerVehicles"')
	replace("local VEHICLES_NAME = 'PLAYER_VEHICLES_Runtime'", "local RUNTIME_FOLDER_NAME = 'Runtime'\nlocal VEHICLES_NAME = 'PlayerVehicles'")
	replace('local VEHICLE_ROOT_NAME = "PLAYER_VEHICLES_Runtime"', 'local RUNTIME_FOLDER_NAME = "Runtime"\nlocal VEHICLE_ROOT_NAME = "PlayerVehicles"')
	replace("local VEHICLE_ROOT_NAME = 'PLAYER_VEHICLES_Runtime'", "local RUNTIME_FOLDER_NAME = 'Runtime'\nlocal VEHICLE_ROOT_NAME = 'PlayerVehicles'")

	replacePattern('local%s+world%s*=%s*Workspace:FindFirstChild%("HOVER_RACING_V2_WORLD"%)%s*return%s+world%s+and%s+world:FindFirstChild%("PLAYER_VEHICLES_Runtime"%)',
		'local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")\n\tlocal runtime = world and world:FindFirstChild("Runtime")\n\treturn runtime and runtime:FindFirstChild("PlayerVehicles")')
	replacePattern("local%s+world%s*=%s*Workspace:FindFirstChild%('HOVER_RACING_V2_WORLD'%)%s*return%s+world%s+and%s+world:FindFirstChild%('PLAYER_VEHICLES_Runtime'%)",
		"local world = Workspace:FindFirstChild('NeoTokyoRacersWorld')\n\tlocal runtime = world and world:FindFirstChild('Runtime')\n\treturn runtime and runtime:FindFirstChild('PlayerVehicles')")
	replacePattern('local%s+world%s*=%s*Workspace:WaitForChild%("HOVER_RACING_V2_WORLD"%)%s*return%s+world:WaitForChild%("PLAYER_VEHICLES_Runtime"%)',
		'local world = Workspace:WaitForChild("NeoTokyoRacersWorld")\n\tlocal runtime = world:WaitForChild("Runtime")\n\treturn runtime:WaitForChild("PlayerVehicles")')
	replacePattern("local%s+world%s*=%s*Workspace:WaitForChild%('HOVER_RACING_V2_WORLD'%)%s*return%s+world:WaitForChild%('PLAYER_VEHICLES_Runtime'%)",
		"local world = Workspace:WaitForChild('NeoTokyoRacersWorld')\n\tlocal runtime = world:WaitForChild('Runtime')\n\treturn runtime:WaitForChild('PlayerVehicles')")

	replace('Workspace:WaitForChild("HOVER_RACING_V2_WORLD"):WaitForChild("PLAYER_VEHICLES_Runtime")', newRuntimePath)
	replace("Workspace:WaitForChild('HOVER_RACING_V2_WORLD'):WaitForChild('PLAYER_VEHICLES_Runtime')", "Workspace:WaitForChild('NeoTokyoRacersWorld'):WaitForChild('Runtime'):WaitForChild('PlayerVehicles')")
	replace('Workspace:FindFirstChild("HOVER_RACING_V2_WORLD"):FindFirstChild("PLAYER_VEHICLES_Runtime")', newRuntimeFindExpression)
	replace("Workspace:FindFirstChild('HOVER_RACING_V2_WORLD'):FindFirstChild('PLAYER_VEHICLES_Runtime')", "(function() local world = Workspace:FindFirstChild('NeoTokyoRacersWorld'); local runtime = world and world:FindFirstChild('Runtime'); return runtime and runtime:FindFirstChild('PlayerVehicles') end)()")
	replace('Workspace:WaitForChild("HOVER_RACING_V2_WORLD"):WaitForChild("GaragePreviewPad")', 'Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("Garages"):WaitForChild("GaragePreviewPad")')
	replace("Workspace:WaitForChild('HOVER_RACING_V2_WORLD'):WaitForChild('GaragePreviewPad')", "Workspace:WaitForChild('NeoTokyoRacersWorld'):WaitForChild('Garages'):WaitForChild('GaragePreviewPad')")
	replace('Workspace:WaitForChild("HOVER_RACING_V2_WORLD"):WaitForChild("VehicleSpawnPoint")', 'Workspace:WaitForChild("NeoTokyoRacersWorld"):WaitForChild("SpawnPoints"):WaitForChild("VehicleSpawnPoint")')
	replace("Workspace:WaitForChild('HOVER_RACING_V2_WORLD'):WaitForChild('VehicleSpawnPoint')", "Workspace:WaitForChild('NeoTokyoRacersWorld'):WaitForChild('SpawnPoints'):WaitForChild('VehicleSpawnPoint')")

	for _, variableName in ipairs({ "world", "hoverWorld", "runtimeWorld", "worldRoot", "driveWorld", "V56_world" }) do
		replace(variableName .. ':WaitForChild("PLAYER_VEHICLES_Runtime")', variableName .. ':WaitForChild("Runtime"):WaitForChild("PlayerVehicles")')
		replace(variableName .. ":WaitForChild('PLAYER_VEHICLES_Runtime')", variableName .. ":WaitForChild('Runtime'):WaitForChild('PlayerVehicles')")
		replace(variableName .. ':FindFirstChild("PLAYER_VEHICLES_Runtime")', '(' .. variableName .. ':FindFirstChild("Runtime") and ' .. variableName .. '.Runtime:FindFirstChild("PlayerVehicles"))')
		replace(variableName .. ":FindFirstChild('PLAYER_VEHICLES_Runtime')", "(" .. variableName .. ":FindFirstChild('Runtime') and " .. variableName .. ".Runtime:FindFirstChild('PlayerVehicles'))")
		replace(variableName .. ':WaitForChild(VEHICLES_NAME)', variableName .. ':WaitForChild("Runtime"):WaitForChild(VEHICLES_NAME)')
		replace(variableName .. ':FindFirstChild(VEHICLES_NAME)', '(' .. variableName .. ':FindFirstChild("Runtime") and ' .. variableName .. ':FindFirstChild("Runtime"):FindFirstChild(VEHICLES_NAME))')
		replace(variableName .. ':WaitForChild(VEHICLE_ROOT_NAME)', variableName .. ':WaitForChild("Runtime"):WaitForChild(VEHICLE_ROOT_NAME)')
		replace(variableName .. ':FindFirstChild(VEHICLE_ROOT_NAME)', '(' .. variableName .. ':FindFirstChild("Runtime") and ' .. variableName .. ':FindFirstChild("Runtime"):FindFirstChild(VEHICLE_ROOT_NAME))')

		if sourceHadOldWorld then
			replace(variableName .. ':WaitForChild("GaragePreviewPad")', variableName .. ':WaitForChild("Garages"):WaitForChild("GaragePreviewPad")')
			replace(variableName .. ":WaitForChild('GaragePreviewPad')", variableName .. ":WaitForChild('Garages'):WaitForChild('GaragePreviewPad')")
			replace(variableName .. ':FindFirstChild("GaragePreviewPad")', '(' .. variableName .. ':FindFirstChild("Garages") and ' .. variableName .. '.Garages:FindFirstChild("GaragePreviewPad"))')
			replace(variableName .. ":FindFirstChild('GaragePreviewPad')", "(" .. variableName .. ":FindFirstChild('Garages') and " .. variableName .. ".Garages:FindFirstChild('GaragePreviewPad'))")
			replace(variableName .. ':WaitForChild("VehicleSpawnPoint")', variableName .. ':WaitForChild("SpawnPoints"):WaitForChild("VehicleSpawnPoint")')
			replace(variableName .. ":WaitForChild('VehicleSpawnPoint')", variableName .. ":WaitForChild('SpawnPoints'):WaitForChild('VehicleSpawnPoint')")
			replace(variableName .. ':FindFirstChild("VehicleSpawnPoint")', '(' .. variableName .. ':FindFirstChild("SpawnPoints") and ' .. variableName .. '.SpawnPoints:FindFirstChild("VehicleSpawnPoint"))')
			replace(variableName .. ":FindFirstChild('VehicleSpawnPoint')", "(" .. variableName .. ":FindFirstChild('SpawnPoints') and " .. variableName .. ".SpawnPoints:FindFirstChild('VehicleSpawnPoint'))")
		end
	end

	replace("Workspace.HOVER_RACING_V2_WORLD.PLAYER_VEHICLES_Runtime", "Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles")
	replace("Workspace.HOVER_RACING_V2_WORLD.GaragePreviewPad", "Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad")
	replace("Workspace.HOVER_RACING_V2_WORLD.VehicleSpawnPoint", "Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint")
	replace("Workspace.HOVER_RACING_V2_WORLD", "Workspace.NeoTokyoRacersWorld")

	replace('"HOVER_RACING_V2_WORLD"', '"NeoTokyoRacersWorld"')
	replace("'HOVER_RACING_V2_WORLD'", "'NeoTokyoRacersWorld'")
	replace('"PLAYER_VEHICLES_Runtime"', '"PlayerVehicles"')
	replace("'PLAYER_VEHICLES_Runtime'", "'PlayerVehicles'")

	return source, total
end

local function plannedSourceFor(instance, source)
	if safeFullName(instance) == "ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Core.PathResolver" then
		if source ~= CORE_PATH_RESOLVER_SOURCE then
			return CORE_PATH_RESOLVER_SOURCE, 1
		end
		return source, 0
	end

	return patchSourceText(source)
end

local function collectSourceObjects()
	local roots = {
		ReplicatedStorage,
		ServerScriptService,
		ServerStorage,
		StarterGui,
		StarterPlayer,
		Workspace,
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

local function preflightSources()
	local blockers = {}
	local patchableCount = 0

	for _, instance in ipairs(collectSourceObjects()) do
		local source = sourceOf(instance)
		if source then
			local patched, replacementCount = plannedSourceFor(instance, source)
			if replacementCount > 0 and patched ~= source then
				patchableCount += 1
			end

			local leftovers = sourceRuntimeTokens(patched)
			if #leftovers > 0 then
				table.insert(blockers, safeFullName(instance) .. " still contains: " .. table.concat(leftovers, ", "))
			end
		end
	end

	if #blockers > 0 then
		local message = {
			"Phase N preflight stopped before changing anything.",
			"Some source objects still contain old runtime-world tokens after the planned patch.",
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

local function applySourcePatches()
	local patchedCount = 0
	local replacements = 0

	for _, instance in ipairs(collectSourceObjects()) do
		local source = sourceOf(instance)
		if source then
			local patched, replacementCount = plannedSourceFor(instance, source)
			if replacementCount > 0 and patched ~= source then
				instance.Source = patched
				instance:SetAttribute("PhaseNSourcePatchedBy", SCRIPT_ID)
				instance:SetAttribute("PhaseNSourcePatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
				patchedCount += 1
				replacements += replacementCount
			end
		end
	end

	return patchedCount, replacements
end

local function collectFinalSourceHits()
	local hits = {}
	for _, instance in ipairs(collectSourceObjects()) do
		local source = sourceOf(instance)
		if source then
			local leftovers = sourceRuntimeTokens(source)
			if #leftovers > 0 then
				table.insert(hits, safeFullName(instance) .. " still contains: " .. table.concat(leftovers, ", "))
			end
		end
	end
	table.sort(hits)
	return hits
end

local function ensureVehicleSpawnPoint(newWorld)
	local garages = waitPath(newWorld, NEW_GARAGES_FOLDER)
	local previewPad = garages:FindFirstChild(NEW_PREVIEW_PAD)
	if not previewPad or not previewPad:IsA("BasePart") then
		error("Could not place VehicleSpawnPoint because Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad was not found as a BasePart.")
	end

	local spawnPoints = folder(newWorld, NEW_SPAWN_FOLDER)
	local existing = spawnPoints:FindFirstChild(NEW_SPAWN_POINT)
	if existing then
		if not existing:IsA("BasePart") then
			error(("Existing %s is %s, expected BasePart."):format(safeFullName(existing), existing.ClassName))
		end
		return existing, false
	end

	local spawnPoint = Instance.new("Part")
	spawnPoint.Name = NEW_SPAWN_POINT
	spawnPoint.Size = Vector3.new(8, 1, 8)
	spawnPoint.Anchored = true
	spawnPoint.CanCollide = false
	spawnPoint.Transparency = 1
	spawnPoint.CFrame = previewPad.CFrame * CFrame.new(0, 4, -18)
	spawnPoint:SetAttribute("CreatedBy", SCRIPT_ID)
	spawnPoint:SetAttribute("Purpose", "Vehicle spawn marker for NeoTokyoRacers runtime.")
	spawnPoint:SetAttribute("NeedsManualPositionReview", true)
	pcall(function()
		spawnPoint.CanTouch = false
		spawnPoint.CanQuery = true
	end)
	spawnPoint.Parent = spawnPoints
	return spawnPoint, true
end

local function setObjectValue(path, target, changes)
	local instance = resolvePath(path)
	if not instance then
		return
	end
	if not instance:IsA("ObjectValue") then
		table.insert(changes, path .. " -- skipped, found " .. instance.ClassName .. " instead of ObjectValue")
		return
	end
	if instance.Value ~= target then
		instance.Value = target
		instance:SetAttribute("PhaseNRepairedBy", SCRIPT_ID)
		instance:SetAttribute("PhaseNRepairedAt", os.date("%Y-%m-%d %H:%M:%S"))
		table.insert(changes, path .. " -> " .. safeFullName(target))
	end
end

local function renameAndSetObjectValue(path, newName, target, changes)
	local instance = resolvePath(path)
	if not instance then
		return
	end
	if not instance:IsA("ObjectValue") then
		table.insert(changes, path .. " -- skipped rename, found " .. instance.ClassName .. " instead of ObjectValue")
		return
	end

	local parent = instance.Parent
	local existing = parent and parent:FindFirstChild(newName)
	if existing and existing ~= instance then
		if existing:IsA("ObjectValue") then
			existing.Value = target
			existing:SetAttribute("PhaseNRepairedBy", SCRIPT_ID)
			table.insert(changes, safeFullName(existing) .. " -> " .. safeFullName(target))
		end
		table.insert(changes, safeFullName(instance) .. " -- left with old name because " .. newName .. " already exists")
		return
	end

	instance.Name = newName
	instance.Value = target
	instance:SetAttribute("PhaseNRepairedBy", SCRIPT_ID)
	instance:SetAttribute("PhaseNRepairedAt", os.date("%Y-%m-%d %H:%M:%S"))
	table.insert(changes, path .. " renamed to " .. safeFullName(instance) .. " -> " .. safeFullName(target))
end

local ntr = ReplicatedStorage:FindFirstChild(NTR_NAME)
if not ntr or not ntr:IsA("Folder") then
	error("ReplicatedStorage.NeoTokyoRacers was not found. Run Phase K before Phase N.")
end

local newWorld = Workspace:FindFirstChild(NEW_WORLD)
if not newWorld or not newWorld:IsA("Folder") then
	error("Workspace.NeoTokyoRacersWorld was not found. Run the world hierarchy migration before Phase N.")
end

local runtimeVehicles = resolvePath("Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles")
if not runtimeVehicles or not runtimeVehicles:IsA("Folder") then
	error("Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles was not found. Phase N cannot retarget runtime code safely.")
end

local previewPad = resolvePath("Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad")
if not previewPad then
	error("Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad was not found. Phase N cannot retarget preview code safely.")
end

local oldWorld = Workspace:FindFirstChild(OLD_WORLD)
if oldWorld then
	error("Workspace.HOVER_RACING_V2_WORLD still exists. This repair is intended for the post-migration state where the old root is already gone.")
end

local patchableCount = preflightSources()

local spawnPoint, spawnPointCreated = ensureVehicleSpawnPoint(newWorld)
local objectValueChanges = {}

setObjectValue("ReplicatedStorage.NeoTokyoRacers.Config.Editable.02_IMPORTANT_LINKS_DoNotRename.Remotes", waitPath(ntr, "Shared", "Remotes", "Garage"), objectValueChanges)
setObjectValue("ReplicatedStorage.NeoTokyoRacers.Config.Editable.02_IMPORTANT_LINKS_DoNotRename.VehicleCategories", waitPath(ntr, "Assets", "Vehicles", "Categories"), objectValueChanges)
renameAndSetObjectValue("ReplicatedStorage.NeoTokyoRacers.Config.Editable.02_IMPORTANT_LINKS_DoNotRename.UI_THEME_DoNotRename", "Theme", waitPath(ntr, "Config", "UI", "Theme"), objectValueChanges)

setObjectValue("ReplicatedStorage.NeoTokyoRacers.LiveReferences.ActiveKit", ntr, objectValueChanges)
setObjectValue("ReplicatedStorage.NeoTokyoRacers.LiveReferences.VehicleCategories", waitPath(ntr, "Assets", "Vehicles", "Categories"), objectValueChanges)

setObjectValue("Workspace.NeoTokyoRacersWorld.City.GeneratedCityBlocks_CurrentLive", waitPath(newWorld, "City"), objectValueChanges)
setObjectValue("Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles_CurrentLive", runtimeVehicles, objectValueChanges)
setObjectValue("Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad_CurrentLive", previewPad, objectValueChanges)
setObjectValue("Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint_CurrentLive", spawnPoint, objectValueChanges)

local patchedCount, replacementCount = applySourcePatches()
local finalHits = collectFinalSourceHits()

local compatibility = folder(ntr, "Compatibility")
local reportsRoot = folder(compatibility, "MigrationReports")

local reportLines = {
	"# Neo Tokyo Racers Phase N Runtime World Path Repair",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Old runtime root existed: false",
	"- Preflight patchable source objects: " .. tostring(patchableCount),
	"- Source objects patched: " .. tostring(patchedCount),
	"- Text replacements applied: " .. tostring(replacementCount),
	"- VehicleSpawnPoint created: " .. tostring(spawnPointCreated),
	"- ObjectValues repaired: " .. tostring(#objectValueChanges),
	"- Final old runtime source hits: " .. tostring(#finalHits),
	"",
	"## ObjectValue Repairs",
	"",
}

if #objectValueChanges == 0 then
	table.insert(reportLines, "- None.")
else
	for _, item in ipairs(objectValueChanges) do
		table.insert(reportLines, "- " .. item)
	end
end

table.insert(reportLines, "")
table.insert(reportLines, "## Final Source Audit")
table.insert(reportLines, "")

if #finalHits == 0 then
	table.insert(reportLines, "- No HOVER_RACING_V2_WORLD or PLAYER_VEHICLES_Runtime source references remain.")
else
	for _, hit in ipairs(finalHits) do
		table.insert(reportLines, "- " .. hit)
	end
end

local report = reportsRoot:FindFirstChild("PhaseN_RuntimeWorldPathRepair")
if report and not report:IsA("StringValue") then
	report.Name = "PhaseN_RuntimeWorldPathRepair_OldNonStringValue"
	report = nil
end
if not report then
	report = Instance.new("StringValue")
	report.Name = "PhaseN_RuntimeWorldPathRepair"
	report.Parent = reportsRoot
end

report.Value = table.concat(reportLines, "\n")
report:SetAttribute("CreatedBy", SCRIPT_ID)
report:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))

log("Runtime world path repair complete.")
log("Source patched: " .. tostring(patchedCount) .. "; replacements: " .. tostring(replacementCount) .. "; final old runtime hits: " .. tostring(#finalHits))
log("VehicleSpawnPoint created: " .. tostring(spawnPointCreated))
log("Report: " .. safeFullName(report))

if #finalHits > 0 then
	warn("[NTR Phase N] Old runtime source references remain. Paste the report back into Codex before running cleanup.")
end

print(report.Value)
