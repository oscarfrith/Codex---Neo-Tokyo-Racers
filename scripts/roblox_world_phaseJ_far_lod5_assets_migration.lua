-- Neo Tokyo Racers - World Phase J Far LOD5 Assets Migration
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Moves/renames ReplicatedStorage.FarLOD5 into the new architecture:
--     ReplicatedStorage.NeoTokyoRacers.Assets.World.FarLOD5Proxies
--   and patches the active LOD client to resolve the new location first.
--
-- Safe effects:
--   - Creates ReplicatedStorage.NeoTokyoRacers.Assets.World if missing.
--   - Moves the FarLOD5 folder without cloning or deleting proxy children.
--   - Patches only the active LOD client script if it still references the old
--     ReplicatedStorage.FarLOD5 lookup.
--   - Keeps a fallback to ReplicatedStorage.FarLOD5 inside the LOD resolver.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.MigrationReports.
--
-- Does NOT:
--   - Touch city blocks, HOVER_RACING_V2_KIT, vehicle, UI, VFX, garage,
--     mobile controls, server actions, lighting, traffic, or Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_world_phaseJ_far_lod5_assets_migration"

local OLD_FOLDER_NAME = "FarLOD5"
local NEW_FOLDER_NAME = "FarLOD5Proxies"
local ACTIVE_LOD_PATH = "StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World.LODClient_Active"

local RESOLVER_FUNCTION = [=[
local function resolveFarLod5Root()
	local ntrRoot = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local assetsRoot = ntrRoot and ntrRoot:FindFirstChild("Assets")
	local worldAssets = assetsRoot and assetsRoot:FindFirstChild("World")
	local farLod5Proxies = worldAssets and worldAssets:FindFirstChild("FarLOD5Proxies")
	if farLod5Proxies then
		return farLod5Proxies
	end

	return ReplicatedStorage:WaitForChild("FarLOD5")
end

]=]

local function log(message)
	print("[NTR World Phase J] " .. message)
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

local function simpleHash(text)
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

local function countDescendants(instance)
	if not instance then
		return 0
	end
	return #instance:GetDescendants()
end

local function countChildren(instance)
	if not instance then
		return 0
	end
	return #instance:GetChildren()
end

local function insertResolver(source)
	if string.find(source, "local function resolveFarLod5Root()", 1, true) then
		return source, false, "resolver already present"
	end

	local serviceLine = [[local ReplicatedStorage = game:GetService("ReplicatedStorage")]]
	local startIndex, endIndex = string.find(source, serviceLine, 1, true)
	if startIndex then
		return string.sub(source, 1, endIndex) .. "\n\n" .. RESOLVER_FUNCTION .. string.sub(source, endIndex + 1), true, "inserted after ReplicatedStorage service line"
	end

	return RESOLVER_FUNCTION .. source, true, "inserted at source start"
end

local function patchWaitForChildLookup(source)
	local replacements = 0

	source = string.gsub(source, 'ReplicatedStorage:WaitForChild%("FarLOD5"%)', function()
		replacements += 1
		return "resolveFarLod5Root()"
	end)

	source = string.gsub(source, "ReplicatedStorage:WaitForChild%('FarLOD5'%)", function()
		replacements += 1
		return "resolveFarLod5Root()"
	end)

	return source, replacements
end

local function patchFindFirstChildLookup(source)
	local replacements = 0

	source = string.gsub(source, 'ReplicatedStorage:FindFirstChild%("FarLOD5"%)', function()
		replacements += 1
		return "resolveFarLod5Root()"
	end)

	source = string.gsub(source, "ReplicatedStorage:FindFirstChild%('FarLOD5'%)", function()
		replacements += 1
		return "resolveFarLod5Root()"
	end)

	return source, replacements
end

local function patchLodClient(scriptObject)
	if not scriptObject or not scriptObject:IsA("LocalScript") then
		return false, "active LOD LocalScript not found", nil
	end

	local source = scriptObject.Source
	if string.find(source, "FarLOD5Proxies", 1, true) and string.find(source, "resolveFarLod5Root", 1, true) then
		return false, "LOD script already resolves FarLOD5Proxies", simpleHash(source)
	end

	local withResolver, insertedResolver, resolverDetail = insertResolver(source)
	local afterWait, waitReplacements = patchWaitForChildLookup(withResolver)
	local afterFind, findReplacements = patchFindFirstChildLookup(afterWait)
	local totalReplacements = waitReplacements + findReplacements

	if totalReplacements == 0 then
		return false, "old FarLOD5 lookup not found; " .. resolverDetail, simpleHash(source)
	end

	scriptObject.Source = afterFind
	local hash = simpleHash(afterFind)
	scriptObject:SetAttribute("FarLOD5AssetsMigrationPatchedBy", SCRIPT_ID)
	scriptObject:SetAttribute("FarLOD5AssetsMigrationPatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
	scriptObject:SetAttribute("FarLOD5AssetsMigrationHash", hash)
	scriptObject:SetAttribute("FarLOD5AssetsPath", "ReplicatedStorage.NeoTokyoRacers.Assets.World." .. NEW_FOLDER_NAME)

	return true, "patched LOD script; replacements=" .. tostring(totalReplacements) .. "; resolverInserted=" .. tostring(insertedResolver), hash
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local assetsRoot = folder(ntr, "Assets")
local worldAssets = folder(assetsRoot, "World")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local oldFolder = ReplicatedStorage:FindFirstChild(OLD_FOLDER_NAME)
local newFolder = worldAssets:FindFirstChild(NEW_FOLDER_NAME)

local moveStatus = ""
local oldChildCountBefore = countChildren(oldFolder)
local oldDescendantCountBefore = countDescendants(oldFolder)

if oldFolder and not oldFolder:IsA("Folder") then
	error("ReplicatedStorage." .. OLD_FOLDER_NAME .. " exists but is a " .. oldFolder.ClassName .. ", expected Folder. No changes applied.")
end
if newFolder and not newFolder:IsA("Folder") then
	error(worldAssets:GetFullName() .. "." .. NEW_FOLDER_NAME .. " exists but is a " .. newFolder.ClassName .. ", expected Folder. No changes applied.")
end

if oldFolder and not newFolder then
	oldFolder.Name = NEW_FOLDER_NAME
	oldFolder.Parent = worldAssets
	newFolder = oldFolder
	moveStatus = "moved and renamed old folder"
elseif oldFolder and newFolder then
	for _, childInstance in ipairs(oldFolder:GetChildren()) do
		if newFolder:FindFirstChild(childInstance.Name) then
			error("Cannot merge FarLOD5 child `" .. childInstance.Name .. "` because it already exists under " .. newFolder:GetFullName() .. ". No changes applied.")
		end
		childInstance.Parent = newFolder
	end
	oldFolder:Destroy()
	moveStatus = "merged old folder into existing new folder and removed old folder"
elseif newFolder then
	moveStatus = "new folder already exists; old folder absent"
else
	newFolder = folder(worldAssets, NEW_FOLDER_NAME)
	moveStatus = "old folder absent; created empty new folder"
end

newFolder:SetAttribute("WorldAssetType", "FarLOD5Proxies")
newFolder:SetAttribute("MigratedBy", SCRIPT_ID)
newFolder:SetAttribute("MigratedAt", os.date("%Y-%m-%d %H:%M:%S"))
newFolder:SetAttribute("OldPath", "ReplicatedStorage." .. OLD_FOLDER_NAME)

local activeLod = resolvePath(ACTIVE_LOD_PATH)
local lodPatched, lodDetail, lodHash = patchLodClient(activeLod)

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers World Phase J Far LOD5 Assets Migration")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Old path: ReplicatedStorage." .. OLD_FOLDER_NAME)
line("- New path: " .. newFolder:GetFullName())
line("- Move status: " .. moveStatus)
line("- Old child count before move: " .. tostring(oldChildCountBefore))
line("- Old descendant count before move: " .. tostring(oldDescendantCountBefore))
line("- New child count: " .. tostring(countChildren(newFolder)))
line("- New descendant count: " .. tostring(countDescendants(newFolder)))
line("- LOD script patched: " .. tostring(lodPatched))
line("- LOD script detail: " .. tostring(lodDetail))
line("- LOD script hash: " .. tostring(lodHash))
line("")
line("## Required Test")
line("")
line("- Start a fresh Play test.")
line("- Output should still show `LOD Script Running` from `LODClient_Active`.")
line("- Output should still show the expected registered block count.")
line("- Drive through the city and confirm near/mid/far LOD visibility still behaves normally.")
line("- If LOD5 proxies are later populated, add them under `ReplicatedStorage.NeoTokyoRacers.Assets.World.FarLOD5Proxies`.")

local reportValue = reportsFolder:FindFirstChild("WorldPhaseJ_FarLOD5AssetsMigration")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "WorldPhaseJ_FarLOD5AssetsMigration_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "WorldPhaseJ_FarLOD5AssetsMigration"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(report, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("NewPath", newFolder:GetFullName())
reportValue:SetAttribute("LodPatched", lodPatched)
reportValue:SetAttribute("LodHash", tostring(lodHash))

log("Far LOD5 assets migration complete.")
log("Move status: " .. moveStatus)
log("New path: " .. newFolder:GetFullName())
log("LOD patch: " .. tostring(lodPatched) .. " - " .. tostring(lodDetail))
print(reportValue.Value)
