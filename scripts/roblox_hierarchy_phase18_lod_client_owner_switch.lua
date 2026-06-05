-- Neo Tokyo Racers - Phase 18 LOD Client Owner Switch
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Moves the live LOD client LocalScript into the new
--   StarterPlayerScripts.NeoTokyoRacersClient.Controllers.World architecture
--   without changing its source logic.
--
-- Default mode:
--   SWITCH
--
-- Modes:
--   STAGE_ONLY = copy/update target script, keep old script live
--   SWITCH     = enable new LOD client owner, disable old root script
--   ROLLBACK   = re-enable old root script, disable new owner
--
-- Safe effects:
--   - Copies exact source from StarterPlayerScripts["LOD System"].
--   - Writes LODClient_Active under the new world controller root.
--   - Toggles only the old/new LOD client owner scripts.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit LOD thresholds or behaviour.
--   - Edit city assets, FarLOD5 assets, traffic, lighting, vehicles, UI,
--     driving, VFX, mobile controls, server actions, or Workspace.Test + WIP Assets.
--   - Delete, rename, or move any live scripts.

local MODE = "SWITCH" -- "STAGE_ONLY", "SWITCH", or "ROLLBACK"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_hierarchy_phase18_lod_client_owner_switch"

local function log(message)
	print("[NTR Phase18 LOD Switch] " .. message)
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

local function simpleHash(text)
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

local function scriptState(scriptObject)
	if not scriptObject then
		return "missing"
	end
	return scriptObject.Disabled and "disabled" or "enabled"
end

if MODE ~= "STAGE_ONLY" and MODE ~= "SWITCH" and MODE ~= "ROLLBACK" then
	error("Invalid MODE: " .. tostring(MODE) .. ". Use STAGE_ONLY, SWITCH, or ROLLBACK.")
end

local starterPlayerScripts = child(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local oldScript = starterPlayerScripts:FindFirstChild("LOD System")
if not oldScript or not oldScript:IsA("LocalScript") then
	error("Missing expected old LOD LocalScript: StarterPlayerScripts['LOD System']. No changes applied.")
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
local worldControllers = folder(controllers, "World")

local newScript = worldControllers:FindFirstChild("LODClient_Active")
if newScript and not newScript:IsA("LocalScript") then
	error("Existing " .. newScript:GetFullName() .. " is a " .. newScript.ClassName .. ", expected LocalScript. No changes applied.")
end
if not newScript then
	newScript = Instance.new("LocalScript")
	newScript.Name = "LODClient_Active"
	newScript.Disabled = true
	newScript.Parent = worldControllers
end

local createdBy = newScript:GetAttribute("CreatedBy")
if newScript.Source ~= "" and createdBy ~= SCRIPT_ID then
	error("Target " .. newScript:GetFullName() .. " already exists and was not created by this phase. No changes applied.")
end

local sourceHash = simpleHash(oldScript.Source)
newScript.Source = oldScript.Source
newScript:SetAttribute("CreatedBy", SCRIPT_ID)
newScript:SetAttribute("MigrationStatus", "LODClientOwnerSwitchCandidate")
newScript:SetAttribute("SourceScriptPath", oldScript:GetFullName())
newScript:SetAttribute("SourceHash", sourceHash)
newScript:SetAttribute("LiveReplacementFor", oldScript.Name)

if MODE == "STAGE_ONLY" then
	newScript.Disabled = true
elseif MODE == "SWITCH" then
	newScript.Disabled = false
	oldScript.Disabled = true
elseif MODE == "ROLLBACK" then
	newScript.Disabled = true
	oldScript.Disabled = false
end

local reportLines = {}
local function line(text)
	table.insert(reportLines, text)
end

line("# Neo Tokyo Racers Phase 18 LOD Client Owner Switch")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Mode: `" .. MODE .. "`")
line("")
line("This phase moves LOD client ownership into the new world controller architecture without changing source logic.")
line("")
line("## Results")
line("")
line("- Old: `" .. oldScript:GetFullName() .. "` -> " .. scriptState(oldScript))
line("- New: `" .. newScript:GetFullName() .. "` -> " .. scriptState(newScript))
line("- Source hash: `" .. sourceHash .. "`")
line("")
line("## Expected Test")
line("")
line("- Fresh Play output should show `LOD Script Running` from `LODClient_Active`.")
line("- Output should show `Registered blocks: 84` or the current expected block count.")
line("- Driving around the city should not show obvious missing near blocks or broken FarLOD5 visibility.")
line("- Vehicle/dealership/runtime behaviour should be unchanged.")
line("")
if MODE == "ROLLBACK" then
	line("Rollback mode restored the old LOD client and disabled the new owner.")
elseif MODE == "SWITCH" then
	line("Switch mode enabled the new LOD client owner and disabled the old owner.")
else
	line("Stage-only mode prepared the target owner but did not change live ownership.")
end

local reportValue = reportsFolder:FindFirstChild("Phase18_LODClientOwnerSwitchReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase18_LODClientOwnerSwitchReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase18_LODClientOwnerSwitchReport"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("Mode", MODE)
reportValue:SetAttribute("SourceHash", sourceHash)
reportValue:SetAttribute("OldScriptState", scriptState(oldScript))
reportValue:SetAttribute("NewScriptState", scriptState(newScript))

log("Phase 18 complete in mode: " .. MODE)
log("Old: " .. scriptState(oldScript) .. "; new: " .. scriptState(newScript))
log("Report: " .. reportValue:GetFullName())
print(reportValue.Value)
