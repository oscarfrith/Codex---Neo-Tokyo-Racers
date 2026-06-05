-- Neo Tokyo Racers - Cleanup Phase M: Post Kit Migration Audit
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Audits the place after Architecture Phase K/L moved and removed
--   ReplicatedStorage.HOVER_RACING_V2_KIT.
--
-- It looks for:
--   - Missing migrated NeoTokyoRacers folders.
--   - Unexpected active scripts.
--   - Any remaining legacy kit source tokens.
--   - Stale ObjectValues, attributes, or StringValues pointing at old paths.
--   - Empty compatibility/remainder folders and old report clutter.
--   - Legacy-named roots that should be reviewed but not deleted blindly.
--
-- Safe effects:
--   - Creates/updates chunked text reports under:
--     ReplicatedStorage.NeoTokyoRacers.Compatibility.CleanupReports
--   - Replaces only previous CleanupPhaseM report StringValues.
--   - Prints a concise summary to Output.
--
-- Does NOT:
--   - Move, rename, disable, enable, delete, clone, or edit gameplay objects.
--   - Touch Workspace.Test + WIP Assets.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_cleanup_phaseM_post_kit_migration_audit"
local LEGACY_KIT_NAME = "HOVER_RACING_V2_KIT"
local NTR_NAME = "NeoTokyoRacers"
local CHUNK_SIZE = 180000
local MAX_FOCUS_TREE_DEPTH = 7
local MAX_FOCUS_TREE_NODES_PER_ROOT = 1800

local function log(message)
	print("[NTR Cleanup Phase M] " .. message)
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

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
end

local function underTestWip(instance)
	return string.find(safeFullName(instance), "Test %+ WIP Assets") ~= nil
end

local function isScriptLike(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript")
end

local function isSourceObject(instance)
	return isScriptLike(instance) or instance:IsA("ModuleScript")
end

local function isBlockModel(instance)
	return instance:IsA("Model") and string.match(instance.Name, "^Block_S%d+_R%d+_B%d+$") ~= nil
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

local function valueToText(value)
	local valueType = typeof(value)
	if valueType == "Color3" then
		return ("Color3(%d,%d,%d)"):format(math.floor(value.R * 255 + 0.5), math.floor(value.G * 255 + 0.5), math.floor(value.B * 255 + 0.5))
	elseif valueType == "Vector3" then
		return ("Vector3(%.2f, %.2f, %.2f)"):format(value.X, value.Y, value.Z)
	elseif valueType == "EnumItem" then
		return tostring(value)
	elseif valueType == "Instance" then
		return safeFullName(value)
	end
	return tostring(value)
end

local function sourceText(instance)
	if not isSourceObject(instance) then
		return ""
	end
	local source = sourceOf(instance)
	return source and (" SourceLength=" .. tostring(#source)) or ""
end

local function attributesText(instance)
	local ok, attrs = pcall(function()
		return instance:GetAttributes()
	end)
	if not ok or not attrs then
		return ""
	end

	local keys = {}
	for key in pairs(attrs) do
		table.insert(keys, key)
	end
	table.sort(keys)
	if #keys == 0 then
		return ""
	end

	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. "=" .. valueToText(attrs[key]))
	end
	return " attrs{" .. table.concat(parts, ", ") .. "}"
end

local function childSummary(instance)
	local counts = {}
	for _, childInstance in ipairs(instance:GetChildren()) do
		counts[childInstance.ClassName] = (counts[childInstance.ClassName] or 0) + 1
	end

	local keys = {}
	for key in pairs(counts) do
		table.insert(keys, key)
	end
	table.sort(keys)

	local parts = {}
	for _, key in ipairs(keys) do
		table.insert(parts, key .. "=" .. tostring(counts[key]))
	end
	if #parts == 0 then
		return ""
	end
	return " children{" .. table.concat(parts, ", ") .. "}"
end

local function scriptStateText(instance)
	if not isScriptLike(instance) then
		return ""
	end
	return " Disabled=" .. tostring(instance.Disabled)
end

local function sortedChildren(instance)
	local children = instance:GetChildren()
	table.sort(children, function(a, b)
		if a.ClassName == b.ClassName then
			return a.Name < b.Name
		end
		return a.ClassName < b.ClassName
	end)
	return children
end

local function isReportPath(path)
	return string.find(path, ".Compatibility.MigrationReports.", 1, true) ~= nil
		or string.find(path, ".Compatibility.CleanupReports.", 1, true) ~= nil
end

local function addUnique(list, seen, item)
	if not seen[item] then
		seen[item] = true
		table.insert(list, item)
	end
end

local legacyTextTokens = {
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
	"ReplicatedStorage.NeoTokyoRacers.CLIENT_MODULES",
	"ReplicatedStorage.NeoTokyoRacers.SHARED_MODULES",
	"ReplicatedStorage.NeoTokyoRacers.REMOTES_DoNotRename",
	"ReplicatedStorage.NeoTokyoRacers.VEHICLE_CATEGORIES",
	"ReplicatedStorage.NeoTokyoRacers.VFX_TEMPLATES",
	"ReplicatedStorage.NeoTokyoRacers.UI_THEME_DoNotRename",
	"ReplicatedStorage.NeoTokyoRacers.PAINT_PRESETS_EditColoursHere",
	"ReplicatedStorage.NeoTokyoRacers.00_EDIT_ME_FIRST",
	"Workspace.HOVER_RACING_V2_WORLD",
}

local legacyNameSet = {}
for _, token in ipairs({
	LEGACY_KIT_NAME,
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
}) do
	legacyNameSet[token] = true
end

local function legacyTokensInText(text)
	local found = {}
	for _, token in ipairs(legacyTextTokens) do
		if string.find(text, token, 1, true) then
			table.insert(found, token)
		end
	end
	return found
end

local expectedActiveScripts = {
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled",
	"StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview",
	"ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled",
	"ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriverSeatPositionService_Active",
	"ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Active",
	"ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active",
	"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active",
}

local expectedActiveSet = {}
for _, path in ipairs(expectedActiveScripts) do
	expectedActiveSet[path] = true
end

local requiredPaths = {
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
	"ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage.GarageInvoke",
	"ReplicatedStorage.NeoTokyoRacers.Shared.Remotes.Garage.GaragePush",
	"Workspace.NeoTokyoRacersWorld",
	"Workspace.NeoTokyoRacersWorld.Runtime",
	"Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles",
	"Workspace.NeoTokyoRacersWorld.Garages",
	"Workspace.NeoTokyoRacersWorld.Garages.GaragePreviewPad",
	"Workspace.NeoTokyoRacersWorld.SpawnPoints",
	"Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint",
}

local requiredPathSet = {}
for _, path in ipairs(requiredPaths) do
	requiredPathSet[path] = true
end

local rootServices = {
	ReplicatedStorage,
	ServerScriptService,
	ServerStorage,
	StarterPlayer,
	StarterGui,
	Workspace,
	Lighting,
	SoundService,
}

local allInstances = {}
for _, root in ipairs(rootServices) do
	for _, instance in ipairs(root:GetDescendants()) do
		table.insert(allInstances, instance)
	end
end

local activeScripts = {}
local disabledScripts = {}
local unexpectedActive = {}
local missingExpectedActive = {}
local moduleScripts = {}
local blockModels = {}
local classCounts = {}
local sourceLegacyHits = {}
local attributeLegacyHits = {}
local stringValueLegacyHits = {}
local reportTextLegacyHits = {}
local legacyNamedInstances = {}
local staleObjectValues = {}
local emptyFolders = {}
local autoCandidates = {}
local reviewCandidates = {}
local warnings = {}

local autoSeen = {}
local reviewSeen = {}

for _, instance in ipairs(allInstances) do
	local path = safeFullName(instance)
	classCounts[instance.ClassName] = (classCounts[instance.ClassName] or 0) + 1

	if isScriptLike(instance) then
		if instance.Disabled then
			table.insert(disabledScripts, path)
		else
			table.insert(activeScripts, path)
			if not expectedActiveSet[path] then
				table.insert(unexpectedActive, path)
			end
		end
	elseif instance:IsA("ModuleScript") then
		table.insert(moduleScripts, path)
	end

	if isBlockModel(instance) then
		table.insert(blockModels, path)
	end

	if not underTestWip(instance) then
		if isSourceObject(instance) then
			local source = sourceOf(instance)
			if source then
				local tokens = legacyTokensInText(source)
				if #tokens > 0 then
					table.insert(sourceLegacyHits, path .. " -- " .. table.concat(tokens, ", "))
				end
			end
		end

		local okAttrs, attrs = pcall(function()
			return instance:GetAttributes()
		end)
		if okAttrs and attrs then
			for key, value in pairs(attrs) do
				if typeof(value) == "string" then
					local tokens = legacyTokensInText(value)
					if #tokens > 0 then
						table.insert(attributeLegacyHits, path .. " attr " .. key .. " -- " .. table.concat(tokens, ", "))
					end
				end
			end
		end

		if instance:IsA("StringValue") then
			local tokens = legacyTokensInText(instance.Value)
			if #tokens > 0 then
				if isReportPath(path) then
					table.insert(reportTextLegacyHits, path .. " -- " .. table.concat(tokens, ", "))
				else
					table.insert(stringValueLegacyHits, path .. " -- " .. table.concat(tokens, ", "))
				end
			end
		end

		if legacyNameSet[instance.Name] then
			table.insert(legacyNamedInstances, path .. " <" .. instance.ClassName .. ">")
		elseif string.find(instance.Name, "HOVER_RACING_V2_KIT", 1, true) then
			table.insert(legacyNamedInstances, path .. " <" .. instance.ClassName .. ">")
		end

		if instance:IsA("ObjectValue") then
			local isReferenceMarker = instance:GetAttribute("ReferenceOnly") == true
				or string.find(instance.Name, "CurrentLive", 1, true) ~= nil
				or string.find(instance.Name, "Previous", 1, true) ~= nil
				or string.find(instance.Name, "Shadow", 1, true) ~= nil
				or string.find(instance.Name, "Legacy", 1, true) ~= nil

			if instance.Value == nil and isReferenceMarker then
				table.insert(staleObjectValues, path .. " -- nil reference marker")
				addUnique(autoCandidates, autoSeen, path .. " -- nil migration/reference ObjectValue")
			elseif instance.Value then
				local valuePath = safeFullName(instance.Value)
				local tokens = legacyTokensInText(valuePath)
				if #tokens > 0 then
					table.insert(staleObjectValues, path .. " -> " .. valuePath)
				end
			end
		end

		if instance:IsA("Folder") and #instance:GetChildren() == 0 then
			table.insert(emptyFolders, path)
		end
	end
end

for _, path in ipairs(expectedActiveScripts) do
	local instance = resolvePath(path)
	if not instance then
		table.insert(missingExpectedActive, path .. " -- missing")
	elseif not isScriptLike(instance) then
		table.insert(missingExpectedActive, path .. " -- found " .. instance.ClassName .. ", expected Script/LocalScript")
	elseif instance.Disabled then
		table.insert(missingExpectedActive, path .. " -- disabled")
	end
end

local missingRequired = {}
for _, path in ipairs(requiredPaths) do
	if not resolvePath(path) then
		table.insert(missingRequired, path)
	end
end

local legacyKit = ReplicatedStorage:FindFirstChild(LEGACY_KIT_NAME)
if legacyKit then
	table.insert(warnings, "ReplicatedStorage." .. LEGACY_KIT_NAME .. " still exists after Phase L.")
	addUnique(reviewCandidates, reviewSeen, "ReplicatedStorage." .. LEGACY_KIT_NAME .. " -- old kit root still exists; investigate before deleting")
end

if #sourceLegacyHits > 0 then
	table.insert(warnings, "Source legacy token hits found. Do not run deletion cleanup until these are fixed.")
end

if #unexpectedActive > 0 then
	table.insert(warnings, "Unexpected active scripts found.")
end

if #missingExpectedActive > 0 then
	table.insert(warnings, "Expected active scripts missing/disabled.")
end

local ntr = ReplicatedStorage:FindFirstChild(NTR_NAME)
if not ntr or not ntr:IsA("Folder") then
	error("ReplicatedStorage.NeoTokyoRacers was not found. Run Phase K before this audit.")
end

local compatibility = ntr:FindFirstChild("Compatibility")
if compatibility then
	local legacyRemainders = compatibility:FindFirstChild("LegacyKitRemainders")
	if legacyRemainders then
		if #legacyRemainders:GetChildren() == 0 then
			addUnique(autoCandidates, autoSeen, safeFullName(legacyRemainders) .. " -- empty Phase K remainder folder")
		else
			addUnique(reviewCandidates, reviewSeen, safeFullName(legacyRemainders) .. " -- contains " .. tostring(#legacyRemainders:GetChildren()) .. " unmapped migrated item(s)")
		end
	end

	local migrationReports = compatibility:FindFirstChild("MigrationReports")
	if migrationReports then
		addUnique(reviewCandidates, reviewSeen, safeFullName(migrationReports) .. " -- migration report archive; keep until the new layout has been play-tested enough")
	end

	local cleanupReports = compatibility:FindFirstChild("CleanupReports")
	if cleanupReports then
		for _, childInstance in ipairs(cleanupReports:GetChildren()) do
			if childInstance:IsA("StringValue") and not string.match(childInstance.Name, "^CleanupPhaseM_") then
				addUnique(reviewCandidates, reviewSeen, safeFullName(childInstance) .. " -- old cleanup report value")
			end
		end
	end
end

local hoverWorld = Workspace:FindFirstChild("HOVER_RACING_V2_WORLD")
if hoverWorld then
	addUnique(reviewCandidates, reviewSeen, safeFullName(hoverWorld) .. " -- old runtime world root still exists after Phase N; investigate before deleting")
end

for _, path in ipairs(emptyFolders) do
	if requiredPathSet[path] then
		-- Required architecture containers are allowed to be empty.
	elseif path == "ReplicatedStorage.NeoTokyoRacers.Compatibility.LegacyKitRemainders" then
		addUnique(autoCandidates, autoSeen, path .. " -- empty Phase K remainder folder")
	elseif startsWith(path, "ReplicatedStorage.NeoTokyoRacers.Config.") then
		addUnique(reviewCandidates, reviewSeen, path .. " -- empty future config placeholder")
	elseif startsWith(path, "ReplicatedStorage.NeoTokyoRacers.Shared.Modules.") then
		addUnique(reviewCandidates, reviewSeen, path .. " -- empty future shared module placeholder")
	elseif startsWith(path, "ReplicatedStorage.NeoTokyoRacers.Compatibility.") then
		addUnique(reviewCandidates, reviewSeen, path .. " -- empty compatibility folder")
	end
end

for _, item in ipairs(attributeLegacyHits) do
	if string.find(item, " attr LegacyKitOldPath ", 1, true) then
		addUnique(reviewCandidates, reviewSeen, item .. " -- informational Phase K metadata")
	else
		addUnique(reviewCandidates, reviewSeen, item .. " -- stale legacy path metadata")
	end
end

for _, item in ipairs(stringValueLegacyHits) do
	addUnique(reviewCandidates, reviewSeen, item .. " -- stale legacy path text value")
end

for _, item in ipairs(legacyNamedInstances) do
	addUnique(reviewCandidates, reviewSeen, item .. " -- legacy-named instance")
end

for _, item in ipairs(reportTextLegacyHits) do
	addUnique(reviewCandidates, reviewSeen, item .. " -- report text mentions old paths")
end

table.sort(activeScripts)
table.sort(disabledScripts)
table.sort(unexpectedActive)
table.sort(missingExpectedActive)
table.sort(moduleScripts)
table.sort(blockModels)
table.sort(sourceLegacyHits)
table.sort(attributeLegacyHits)
table.sort(stringValueLegacyHits)
table.sort(reportTextLegacyHits)
table.sort(legacyNamedInstances)
table.sort(staleObjectValues)
table.sort(emptyFolders)
table.sort(autoCandidates)
table.sort(reviewCandidates)
table.sort(warnings)
table.sort(missingRequired)

local classKeys = {}
for className in pairs(classCounts) do
	table.insert(classKeys, className)
end
table.sort(classKeys)

local focusTreeLines = {}
local function addTree(line)
	table.insert(focusTreeLines, line)
end

local function writeTree(instance, depth, maxDepth, counter)
	if counter.count >= MAX_FOCUS_TREE_NODES_PER_ROOT then
		if not counter.truncated then
			addTree(string.rep("  ", depth) .. "... truncated after " .. tostring(MAX_FOCUS_TREE_NODES_PER_ROOT) .. " nodes for this root")
			counter.truncated = true
		end
		return
	end

	counter.count += 1
	addTree(
		string.rep("  ", depth)
			.. "- "
			.. instance.Name
			.. " <"
			.. instance.ClassName
			.. ">"
			.. scriptStateText(instance)
			.. sourceText(instance)
			.. attributesText(instance)
			.. childSummary(instance)
	)

	if depth >= maxDepth then
		local childCount = #instance:GetChildren()
		if childCount > 0 then
			addTree(string.rep("  ", depth + 1) .. "... " .. tostring(childCount) .. " children hidden by depth limit")
		end
		return
	end

	for _, childInstance in ipairs(sortedChildren(instance)) do
		writeTree(childInstance, depth + 1, maxDepth, counter)
	end
end

local focusRoots = {
	ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),
	ServerScriptService:FindFirstChild("NeoTokyoRacers"),
	StarterPlayer:FindFirstChild("StarterPlayerScripts") and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient"),
	Workspace:FindFirstChild("NeoTokyoRacersWorld"),
	Workspace:FindFirstChild("HOVER_RACING_V2_WORLD"),
}

for _, root in ipairs(focusRoots) do
	if root then
		addTree("")
		addTree("## " .. safeFullName(root))
		writeTree(root, 0, MAX_FOCUS_TREE_DEPTH, { count = 0, truncated = false })
	end
end

local reportLines = {}
local function line(text)
	table.insert(reportLines, text)
end

local function listSection(title, items)
	line("## " .. title)
	line("")
	if #items == 0 then
		line("- None.")
	else
		for _, item in ipairs(items) do
			line("- " .. item)
		end
	end
	line("")
end

line("# Neo Tokyo Racers Cleanup Phase M Post Kit Migration Audit")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Read-only audit. Nothing was moved, renamed, disabled, enabled, deleted, cloned, or edited.")
line("")
line("## Summary")
line("")
line("- Legacy kit exists: " .. tostring(legacyKit ~= nil))
line("- Missing required migrated paths: " .. tostring(#missingRequired))
line("- Active scripts: " .. tostring(#activeScripts))
line("- Disabled scripts: " .. tostring(#disabledScripts))
line("- Unexpected active scripts: " .. tostring(#unexpectedActive))
line("- Missing expected active scripts: " .. tostring(#missingExpectedActive))
line("- ModuleScripts: " .. tostring(#moduleScripts))
line("- City block models found: " .. tostring(#blockModels))
line("- Source legacy token hits: " .. tostring(#sourceLegacyHits))
line("- Attribute legacy token hits: " .. tostring(#attributeLegacyHits))
line("- StringValue legacy token hits: " .. tostring(#stringValueLegacyHits))
line("- Report text legacy mentions: " .. tostring(#reportTextLegacyHits))
line("- Stale ObjectValue references: " .. tostring(#staleObjectValues))
line("- Empty folders: " .. tostring(#emptyFolders))
line("- Auto cleanup candidates: " .. tostring(#autoCandidates))
line("- Review-before-delete candidates: " .. tostring(#reviewCandidates))
line("- Warnings: " .. tostring(#warnings))
line("")

line("## Important Warning")
line("")
line("- This report is not a delete script.")
line("- Paste the candidate sections back into Codex before deleting anything.")
line("- `Workspace.Test + WIP Assets` is intentionally excluded.")
line("- Runtime systems should now use `Workspace.NeoTokyoRacersWorld.Runtime.PlayerVehicles` and related NeoTokyoRacersWorld folders.")
line("")

listSection("Warnings", warnings)
listSection("Missing Required Migrated Paths", missingRequired)
listSection("Unexpected Active Scripts", unexpectedActive)
listSection("Missing Expected Active Scripts", missingExpectedActive)
listSection("Source Legacy Token Hits", sourceLegacyHits)
listSection("Stale ObjectValues", staleObjectValues)
listSection("Attribute Legacy Token Hits", attributeLegacyHits)
listSection("StringValue Legacy Token Hits Outside Reports", stringValueLegacyHits)
listSection("Legacy-Named Instances", legacyNamedInstances)
listSection("Auto Cleanup Candidates", autoCandidates)
listSection("Review Before Delete Candidates", reviewCandidates)

line("## Class Counts")
line("")
for _, className in ipairs(classKeys) do
	line("- " .. className .. ": " .. tostring(classCounts[className]))
end
line("")

listSection("Active Scripts", activeScripts)
listSection("Disabled Scripts", disabledScripts)

line("## City Block Models")
line("")
if #blockModels == 0 then
	line("- None found.")
else
	for i, path in ipairs(blockModels) do
		if i <= 300 then
			line("- " .. path)
		elseif i == 301 then
			line("- ... truncated city block list after 300 entries")
			break
		end
	end
end
line("")

listSection("Report Text Legacy Mentions", reportTextLegacyHits)

line("## Focus Hierarchy Tree")
for _, treeLine in ipairs(focusTreeLines) do
	line(treeLine)
end

local compatibilityFolder = folder(ntr, "Compatibility")
local reportsRoot = folder(compatibilityFolder, "CleanupReports")

for _, childInstance in ipairs(reportsRoot:GetChildren()) do
	if string.match(childInstance.Name, "^CleanupPhaseM_PostKitMigrationAudit_%d%d%d$") or childInstance.Name == "CleanupPhaseM_Summary" then
		childInstance:Destroy()
	end
end

local reportText = table.concat(reportLines, "\n")
local chunkCount = math.max(1, math.ceil(#reportText / CHUNK_SIZE))
for index = 1, chunkCount do
	local value = Instance.new("StringValue")
	value.Name = string.format("CleanupPhaseM_PostKitMigrationAudit_%03d", index)
	value.Value = string.sub(reportText, ((index - 1) * CHUNK_SIZE) + 1, index * CHUNK_SIZE)
	value:SetAttribute("CreatedBy", SCRIPT_ID)
	value:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
	value:SetAttribute("ChunkIndex", index)
	value:SetAttribute("ChunkCount", chunkCount)
	value.Parent = reportsRoot
end

local summary = Instance.new("StringValue")
summary.Name = "CleanupPhaseM_Summary"
summary.Value = table.concat({
	"# Cleanup Phase M Summary",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Legacy kit exists: " .. tostring(legacyKit ~= nil),
	"- Missing required migrated paths: " .. tostring(#missingRequired),
	"- Active scripts: " .. tostring(#activeScripts),
	"- Disabled scripts: " .. tostring(#disabledScripts),
	"- Unexpected active scripts: " .. tostring(#unexpectedActive),
	"- Missing expected active scripts: " .. tostring(#missingExpectedActive),
	"- Source legacy token hits: " .. tostring(#sourceLegacyHits),
	"- Stale ObjectValue references: " .. tostring(#staleObjectValues),
	"- Auto cleanup candidates: " .. tostring(#autoCandidates),
	"- Review-before-delete candidates: " .. tostring(#reviewCandidates),
	"- Warnings: " .. tostring(#warnings),
	"- Report chunks: " .. tostring(chunkCount),
}, "\n")
summary:SetAttribute("CreatedBy", SCRIPT_ID)
summary:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
summary.Parent = reportsRoot

log("Post kit migration cleanup audit complete.")
log("Report folder: " .. safeFullName(reportsRoot))
log("Report chunks: " .. tostring(chunkCount))
log("Legacy kit exists: " .. tostring(legacyKit ~= nil) .. "; source hits: " .. tostring(#sourceLegacyHits) .. "; auto candidates: " .. tostring(#autoCandidates) .. "; review candidates: " .. tostring(#reviewCandidates))
print(summary.Value)
