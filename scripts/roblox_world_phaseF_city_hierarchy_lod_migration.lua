-- Neo Tokyo Racers - World Phase F City Hierarchy + LOD Root Migration
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Moves city block models out of Workspace.GeneratedCityBlocks into:
--     Workspace.NeoTokyoRacersWorld.City["Block S#"].Block_S#_R#_B#
--   and patches the LOD client root lookup so it uses the new City root while
--   retaining a fallback to the old GeneratedCityBlocks folder.
--
-- Safe effects:
--   - Creates Workspace.NeoTokyoRacersWorld.City if missing.
--   - Moves only block models named like Block_S1_R1_B1.
--   - Patches only LOD client scripts that contain the exact old root line.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Delete GeneratedCityBlocks.
--   - Delete, clone, or rename blocks.
--   - Touch vehicle, UI, VFX, garage, mobile controls, server actions, lighting,
--     traffic, race, or Test + WIP Assets systems.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_world_phaseF_city_hierarchy_lod_migration"

local OLD_ROOT_NAME = "GeneratedCityBlocks"
local WORLD_ROOT_NAME = "NeoTokyoRacersWorld"
local CITY_ROOT_NAME = "City"
local BLOCK_GROUP_PREFIX = "Block S"

local OLD_ROOT_LINE = [[local ROOT = workspace:WaitForChild("GeneratedCityBlocks")]]
local NEW_ROOT_BLOCK = [=[
local function resolveCityRoot()
	local worldRoot = workspace:FindFirstChild("NeoTokyoRacersWorld")
	local cityRoot = worldRoot and worldRoot:FindFirstChild("City")
	if cityRoot then
		return cityRoot
	end

	return workspace:WaitForChild("GeneratedCityBlocks")
end

local ROOT = resolveCityRoot()
]=]

local function log(message)
	print("[NTR World Phase F] " .. message)
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

local function isBlockModel(instance)
	return instance:IsA("Model") and string.match(instance.Name, "^Block_S%d+_R%d+_B%d+$") ~= nil
end

local function blockSegmentName(blockName)
	local segment = string.match(blockName, "^Block_(S%d+)_R%d+_B%d+$")
	if not segment then
		return nil
	end
	return BLOCK_GROUP_PREFIX .. string.sub(segment, 2)
end

local function findScript(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = current:FindFirstChild(token)
		if not current then
			return nil
		end
	end
	return current
end

local function simpleHash(text)
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

local function patchLodSource(scriptObject, patchedScripts, skippedScripts)
	if not scriptObject or not scriptObject:IsA("LocalScript") then
		return
	end

	local source = scriptObject.Source
	if string.find(source, "local function resolveCityRoot()", 1, true) then
		table.insert(skippedScripts, scriptObject:GetFullName() .. " already patched")
		return
	end

	local startIndex, endIndex = string.find(source, OLD_ROOT_LINE, 1, true)
	if not startIndex then
		table.insert(skippedScripts, scriptObject:GetFullName() .. " root line not found")
		return
	end

	local newSource = string.sub(source, 1, startIndex - 1) .. NEW_ROOT_BLOCK .. string.sub(source, endIndex + 1)
	scriptObject.Source = newSource
	scriptObject:SetAttribute("CityRootMigrationPatchedBy", SCRIPT_ID)
	scriptObject:SetAttribute("CityRootMigrationPatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
	scriptObject:SetAttribute("CityRootMigrationHash", simpleHash(newSource))
	table.insert(patchedScripts, scriptObject:GetFullName())
end

local oldRoot = Workspace:FindFirstChild(OLD_ROOT_NAME)
if not oldRoot then
	error("Workspace." .. OLD_ROOT_NAME .. " was not found. No changes applied.")
end

local worldRoot = folder(Workspace, WORLD_ROOT_NAME)
local cityRoot = folder(worldRoot, CITY_ROOT_NAME)

local movedBlocks = {}
local alreadyPlaced = {}
local skippedBlocks = {}
local groupCounts = {}

for _, instance in ipairs(oldRoot:GetDescendants()) do
	if isBlockModel(instance) then
		local groupName = blockSegmentName(instance.Name)
		if groupName then
			local groupFolder = folder(cityRoot, groupName)
			instance.Parent = groupFolder
			table.insert(movedBlocks, instance:GetFullName())
			groupCounts[groupName] = (groupCounts[groupName] or 0) + 1
		else
			table.insert(skippedBlocks, instance:GetFullName() .. " segment parse failed")
		end
	end
end

for _, instance in ipairs(cityRoot:GetDescendants()) do
	if isBlockModel(instance) then
		local expectedGroupName = blockSegmentName(instance.Name)
		if expectedGroupName and instance.Parent and instance.Parent.Name == expectedGroupName then
			table.insert(alreadyPlaced, instance:GetFullName())
		end
	end
end

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local activeLod = findScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active")
local legacyLod = starterPlayerScripts:FindFirstChild("LOD System")
local shadowLod = findScript("StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Shadow")

local patchedScripts = {}
local skippedScripts = {}
patchLodSource(activeLod, patchedScripts, skippedScripts)
patchLodSource(legacyLod, patchedScripts, skippedScripts)
patchLodSource(shadowLod, patchedScripts, skippedScripts)

local totalBlocks = 0
for _, instance in ipairs(cityRoot:GetDescendants()) do
	if isBlockModel(instance) then
		totalBlocks += 1
	end
end

local remainingOldBlocks = 0
for _, instance in ipairs(oldRoot:GetDescendants()) do
	if isBlockModel(instance) then
		remainingOldBlocks += 1
	end
end

local groupNames = {}
for groupName in pairs(groupCounts) do
	table.insert(groupNames, groupName)
end
table.sort(groupNames)

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers World Phase F City Hierarchy + LOD Migration")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Old root: Workspace." .. OLD_ROOT_NAME)
line("- New root: " .. cityRoot:GetFullName())
line("- Blocks moved this run: " .. tostring(#movedBlocks))
line("- Blocks currently under new City root: " .. tostring(totalBlocks))
line("- Blocks remaining under old root: " .. tostring(remainingOldBlocks))
line("- LOD scripts patched: " .. tostring(#patchedScripts))
line("- LOD scripts skipped: " .. tostring(#skippedScripts))
line("- Skipped block issues: " .. tostring(#skippedBlocks))
line("")

line("## Block Groups Updated")
line("")
if #groupNames == 0 then
	line("- None moved this run.")
else
	for _, groupName in ipairs(groupNames) do
		line("- " .. groupName .. ": " .. tostring(groupCounts[groupName]))
	end
end
line("")

line("## LOD Scripts Patched")
line("")
if #patchedScripts == 0 then
	line("- None.")
else
	for _, path in ipairs(patchedScripts) do
		line("- " .. path)
	end
end
line("")

line("## LOD Scripts Skipped")
line("")
if #skippedScripts == 0 then
	line("- None.")
else
	for _, path in ipairs(skippedScripts) do
		line("- " .. path)
	end
end
line("")

line("## Skipped Block Issues")
line("")
if #skippedBlocks == 0 then
	line("- None.")
else
	for _, item in ipairs(skippedBlocks) do
		line("- " .. item)
	end
end
line("")

line("## Required Test")
line("")
line("- Start a fresh Play test.")
line("- Output should still show `LOD Script Running` from `LODClient_Active`.")
line("- Output should show the current expected registered block count.")
line("- Drive/teleport around the city and confirm near blocks, LOD4 foliage, and FarLOD5 proxies still appear/disappear correctly.")
line("- If the registered block count is 0, stop and check that blocks are inside `Workspace.NeoTokyoRacersWorld.City`.")

local reportValue = reportsFolder:FindFirstChild("WorldPhaseF_CityHierarchyLodMigration")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "WorldPhaseF_CityHierarchyLodMigration_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "WorldPhaseF_CityHierarchyLodMigration"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(report, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("BlocksMoved", #movedBlocks)
reportValue:SetAttribute("TotalCityBlocks", totalBlocks)
reportValue:SetAttribute("RemainingOldBlocks", remainingOldBlocks)
reportValue:SetAttribute("LodScriptsPatched", #patchedScripts)

log("City hierarchy migration complete.")
log("Blocks moved: " .. tostring(#movedBlocks) .. "; total under City: " .. tostring(totalBlocks) .. "; remaining old blocks: " .. tostring(remainingOldBlocks))
log("LOD scripts patched: " .. tostring(#patchedScripts))
print(reportValue.Value)
