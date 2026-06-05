-- Neo Tokyo Racers - Cleanup Phase G Full Hierarchy + Deletion Candidate Audit
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Produces a full hierarchy/cleanup audit after the architecture migrations.
--   It identifies old inactive folders, disabled legacy scripts, empty legacy
--   roots, old report folders, and rollback items that can be reviewed before
--   deletion.
--
-- Safe effects:
--   - Creates/updates chunked text reports under:
--     ReplicatedStorage.NeoTokyoRacers.Compatibility.CleanupReports
--   - Replaces only previous CleanupPhaseG report StringValues.
--   - Prints a concise summary to Output.
--
-- Does NOT:
--   - Move, rename, disable, enable, delete, clone, or edit gameplay objects.
--   - Touch Test + WIP Assets.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_cleanup_phaseG_full_hierarchy_cleanup_audit"
local CHUNK_SIZE = 180000
local MAX_TREE_DEPTH = 10
local MAX_TREE_NODES_PER_ROOT = 4500

local function log(message)
	print("[NTR Cleanup Phase G] " .. message)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA(className) then
			error("Existing " .. existing:GetFullName() .. " is a " .. existing.ClassName .. ", expected " .. className .. ". No changes applied.")
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

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	if ok then
		return result
	end
	return instance.Name
end

local function isScriptLike(instance)
	return instance:IsA("Script") or instance:IsA("LocalScript")
end

local function isBlockModel(instance)
	return instance:IsA("Model") and string.match(instance.Name, "^Block_S%d+_R%d+_B%d+$") ~= nil
end

local function underTestWip(instance)
	return string.find(safeFullName(instance), "Test %+ WIP Assets") ~= nil
end

local function startsWith(text, prefix)
	return string.sub(text, 1, #prefix) == prefix
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

local function tagsText(instance)
	local ok, tags = pcall(function()
		return CollectionService:GetTags(instance)
	end)
	if not ok or #tags == 0 then
		return ""
	end
	table.sort(tags)
	return " tags{" .. table.concat(tags, ", ") .. "}"
end

local function scriptText(instance)
	if not isScriptLike(instance) then
		return ""
	end
	return " Disabled=" .. tostring(instance.Disabled)
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

local activeExpected = {
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.NeoTokyoRacersClient_Bootstrap_Shadow_Disabled"] = true,
	["StarterPlayer.StarterPlayerScripts.TEMP_LightingPreview"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriverSeatPositionService_Active"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Active"] = true,
	["ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.RuntimeVFXController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.MobileDriveControlsController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Runtime.DriveHudController_Active"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Preview.ThrustPreviewController_Active"] = true,
}

local neverDeleteRoots = {
	["Workspace.Test + WIP Assets"] = true,
	["ReplicatedStorage.HOVER_RACING_V2_KIT"] = true,
	["ReplicatedStorage.NeoTokyoRacers"] = true,
	["ServerScriptService.NeoTokyoRacers"] = true,
	["StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient"] = true,
	["Workspace.NeoTokyoRacersWorld"] = true,
}

local function classifyCandidate(instance)
	local path = safeFullName(instance)
	if underTestWip(instance) then
		return nil, "excluded Test + WIP Assets"
	end
	if neverDeleteRoots[path] then
		return nil, "protected current root"
	end

	if isScriptLike(instance) and instance.Disabled then
		if startsWith(instance.Name, "HOVER_RACING") then
			return "AutoCandidate", "disabled legacy HOVER_RACING script"
		end
		if instance.Name == "LOD System" then
			return "AutoCandidate", "disabled legacy LOD script"
		end
		if string.find(instance.Name, "_Shadow", 1, true) or string.find(instance.Name, "_Bootstrap_Disabled", 1, true) then
			return "ReviewCandidate", "disabled shadow/bootstrap rollback script"
		end
	end

	if instance:IsA("Folder") then
		if path == "Workspace.GeneratedCityBlocks" then
			local blockCount = 0
			for _, descendant in ipairs(instance:GetDescendants()) do
				if isBlockModel(descendant) then
					blockCount += 1
				end
			end
			if blockCount == 0 then
				return "AutoCandidate", "legacy city root has no block models after World Phase F"
			end
			return "ReviewCandidate", "legacy city root still contains block models"
		end

		if path == "ServerStorage.NeoTokyoRacers_LegacyArchive" then
			return "ReviewCandidate", "legacy archive folder; delete only after confirming backup is enough"
		end

		if path == "ReplicatedStorage.NTR_AUDIT_REPORTS" or path == "ReplicatedStorage.NTR_INVENTORY_REPORTS" then
			return "AutoCandidate", "old standalone report folder superseded by NeoTokyoRacers.Compatibility reports"
		end

		if path == "ServerScriptService.HOVER_RACING_V2_SERVER" or path == "ServerScriptService.HOVER_RACING_SERVER" then
			return "ReviewCandidate", "legacy server script container"
		end

		if path == "ServerScriptService.Lighting" then
			return "ReviewCandidate", "legacy lighting script container"
		end
	end

	return nil, nil
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

local classCounts = {}
local activeScripts = {}
local disabledScripts = {}
local unexpectedActive = {}
local moduleScripts = {}
local blockModels = {}
local autoCandidates = {}
local reviewCandidates = {}
local warnings = {}

for _, root in ipairs(rootServices) do
	for _, instance in ipairs(root:GetDescendants()) do
		classCounts[instance.ClassName] = (classCounts[instance.ClassName] or 0) + 1

		if isScriptLike(instance) then
			local path = safeFullName(instance)
			if instance.Disabled then
				table.insert(disabledScripts, path)
			else
				table.insert(activeScripts, path)
				if not activeExpected[path] then
					table.insert(unexpectedActive, path)
				end
			end
		elseif instance:IsA("ModuleScript") then
			table.insert(moduleScripts, safeFullName(instance))
		end

		if isBlockModel(instance) then
			table.insert(blockModels, safeFullName(instance))
		end

		local kind, reason = classifyCandidate(instance)
		if kind == "AutoCandidate" then
			table.insert(autoCandidates, safeFullName(instance) .. " -- " .. reason)
		elseif kind == "ReviewCandidate" then
			table.insert(reviewCandidates, safeFullName(instance) .. " -- " .. reason)
		end
	end
end

table.sort(activeScripts)
table.sort(disabledScripts)
table.sort(unexpectedActive)
table.sort(moduleScripts)
table.sort(blockModels)
table.sort(autoCandidates)
table.sort(reviewCandidates)

local treeLines = {}
local function addTree(line)
	table.insert(treeLines, line)
end

local function writeTree(instance, depth, maxDepth, counter)
	if counter.count >= MAX_TREE_NODES_PER_ROOT then
		if not counter.truncated then
			addTree(string.rep("  ", depth) .. "... truncated after " .. tostring(MAX_TREE_NODES_PER_ROOT) .. " nodes for this root")
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
			.. scriptText(instance)
			.. attributesText(instance)
			.. tagsText(instance)
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

for _, root in ipairs(rootServices) do
	addTree("")
	addTree("## " .. root.Name)
	writeTree(root, 0, MAX_TREE_DEPTH, { count = 0, truncated = false })
end

local classKeys = {}
for className in pairs(classCounts) do
	table.insert(classKeys, className)
end
table.sort(classKeys)

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Cleanup Phase G Full Hierarchy Audit")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Read-only audit. Nothing was moved, renamed, disabled, enabled, deleted, cloned, or edited.")
line("")
line("## Summary")
line("")
line("- Active scripts: " .. tostring(#activeScripts))
line("- Disabled scripts: " .. tostring(#disabledScripts))
line("- Unexpected active scripts: " .. tostring(#unexpectedActive))
line("- ModuleScripts: " .. tostring(#moduleScripts))
line("- City block models found: " .. tostring(#blockModels))
line("- Auto cleanup candidates: " .. tostring(#autoCandidates))
line("- Review-before-delete candidates: " .. tostring(#reviewCandidates))
line("")

line("## Important Warning")
line("")
line("- This report is not a delete script.")
line("- Paste the cleanup candidate sections back into Codex before deleting anything.")
line("- `Workspace.Test + WIP Assets` is intentionally excluded.")
line("- Current active NeoTokyoRacers systems are protected from cleanup candidate classification.")
line("")

line("## Class Counts")
line("")
for _, className in ipairs(classKeys) do
	line("- " .. className .. ": " .. tostring(classCounts[className]))
end
line("")

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

listSection("Unexpected Active Scripts", unexpectedActive)
listSection("Active Scripts", activeScripts)
listSection("Disabled Scripts", disabledScripts)
listSection("Auto Cleanup Candidates", autoCandidates)
listSection("Review Before Delete Candidates", reviewCandidates)

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

line("## Full Hierarchy Tree")
for _, treeLine in ipairs(treeLines) do
	line(treeLine)
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsRoot = folder(compatibility, "CleanupReports")

for _, childInstance in ipairs(reportsRoot:GetChildren()) do
	if string.match(childInstance.Name, "^CleanupPhaseG_FullHierarchyAudit_%d%d%d$") then
		childInstance:Destroy()
	end
end

local reportText = table.concat(report, "\n")
local chunkCount = math.max(1, math.ceil(#reportText / CHUNK_SIZE))
for index = 1, chunkCount do
	local value = Instance.new("StringValue")
	value.Name = string.format("CleanupPhaseG_FullHierarchyAudit_%03d", index)
	value.Value = string.sub(reportText, ((index - 1) * CHUNK_SIZE) + 1, index * CHUNK_SIZE)
	value:SetAttribute("CreatedBy", SCRIPT_ID)
	value:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
	value:SetAttribute("ChunkIndex", index)
	value:SetAttribute("ChunkCount", chunkCount)
	value.Parent = reportsRoot
end

local summary = reportsRoot:FindFirstChild("CleanupPhaseG_Summary")
if not summary or not summary:IsA("StringValue") then
	if summary then
		summary.Name = "CleanupPhaseG_Summary_OldNonStringValue"
	end
	summary = Instance.new("StringValue")
	summary.Name = "CleanupPhaseG_Summary"
	summary.Parent = reportsRoot
end
summary.Value = table.concat({
	"# Cleanup Phase G Summary",
	"",
	"Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"),
	"",
	"- Active scripts: " .. tostring(#activeScripts),
	"- Disabled scripts: " .. tostring(#disabledScripts),
	"- Unexpected active scripts: " .. tostring(#unexpectedActive),
	"- ModuleScripts: " .. tostring(#moduleScripts),
	"- City block models found: " .. tostring(#blockModels),
	"- Auto cleanup candidates: " .. tostring(#autoCandidates),
	"- Review-before-delete candidates: " .. tostring(#reviewCandidates),
	"- Report chunks: " .. tostring(chunkCount),
}, "\n")
summary:SetAttribute("CreatedBy", SCRIPT_ID)
summary:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))

log("Full hierarchy cleanup audit complete.")
log("Report folder: " .. reportsRoot:GetFullName())
log("Report chunks: " .. tostring(chunkCount))
log("Unexpected active: " .. tostring(#unexpectedActive) .. "; auto candidates: " .. tostring(#autoCandidates) .. "; review candidates: " .. tostring(#reviewCandidates))
print(summary.Value)
