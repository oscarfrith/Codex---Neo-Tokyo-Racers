-- Neo Tokyo Racers - Phase 16 Runtime Helper Owner Switch
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Moves the small runtime helper LocalScript owners into the new
--   NeoTokyoRacersClient.Controllers.Runtime architecture without changing
--   their source logic.
--
-- Default mode:
--   SWITCH
--
-- Modes:
--   STAGE_ONLY = copy/update target scripts, keep old scripts live
--   SWITCH     = enable new runtime owners, disable old root helper scripts
--   ROLLBACK   = re-enable old root helper scripts, disable new owners
--
-- Safe effects:
--   - Copies exact source from current active runtime helper scripts.
--   - Writes new LocalScripts under StarterPlayerScripts.NeoTokyoRacersClient.
--   - Toggles only the three runtime helper owner scripts listed below.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit HOVER_RACING_V2_Client.
--   - Edit DrivingControllerV47 or driving mechanics.
--   - Edit server actions, garage/customisation UI, LOD, lighting, traffic, or assets.
--   - Delete, rename, or move any live scripts.

local MODE = "SWITCH" -- "STAGE_ONLY", "SWITCH", or "ROLLBACK"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_hierarchy_phase16_runtime_helper_owner_switch"

local function log(message)
	print("[NTR Phase16 Runtime Switch] " .. message)
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

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
local runtimeControllers = folder(controllers, "Runtime")

local owners = {
	{
		Label = "Cached thrust visual runtime",
		OldName = "HOVER_RACING_V64_CachedThrustVisualRuntime",
		NewName = "RuntimeVFXController_Active",
	},
	{
		Label = "Mobile drive controls",
		OldName = "HOVER_RACING_V67_MobileDriveControls",
		NewName = "MobileDriveControlsController_Active",
	},
	{
		Label = "Mobile/desktop HUD suppressor",
		OldName = "HOVER_RACING_V71_MobilePcHudSuppressor",
		NewName = "DriveHudController_Active",
	},
}

local reportLines = {}
local function line(text)
	table.insert(reportLines, text)
end

line("# Neo Tokyo Racers Phase 16 Runtime Helper Owner Switch")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Mode: `" .. MODE .. "`")
line("")
line("This phase moves small runtime helper LocalScript ownership into the new runtime architecture without changing the source logic.")
line("")
line("## Results")
line("")

for _, owner in ipairs(owners) do
	local oldScript = starterPlayerScripts:FindFirstChild(owner.OldName)
	if not oldScript or not oldScript:IsA("LocalScript") then
		error("Missing expected old runtime helper LocalScript: StarterPlayerScripts." .. owner.OldName .. ". No changes applied.")
	end

	local newScript = runtimeControllers:FindFirstChild(owner.NewName)
	if newScript and not newScript:IsA("LocalScript") then
		error("Existing " .. newScript:GetFullName() .. " is a " .. newScript.ClassName .. ", expected LocalScript. No changes applied.")
	end
	if not newScript then
		newScript = Instance.new("LocalScript")
		newScript.Name = owner.NewName
		newScript.Disabled = true
		newScript.Parent = runtimeControllers
	end

	local createdBy = newScript:GetAttribute("CreatedBy")
	if newScript.Source ~= "" and createdBy ~= SCRIPT_ID then
		error("Target " .. newScript:GetFullName() .. " already exists and was not created by this phase. No changes applied.")
	end

	local sourceHash = simpleHash(oldScript.Source)
	newScript.Source = oldScript.Source
	newScript:SetAttribute("CreatedBy", SCRIPT_ID)
	newScript:SetAttribute("MigrationStatus", "RuntimeOwnerSwitchCandidate")
	newScript:SetAttribute("SourceScriptPath", oldScript:GetFullName())
	newScript:SetAttribute("SourceHash", sourceHash)
	newScript:SetAttribute("LiveReplacementFor", owner.OldName)

	if MODE == "STAGE_ONLY" then
		newScript.Disabled = true
	elseif MODE == "SWITCH" then
		newScript.Disabled = false
		oldScript.Disabled = true
	elseif MODE == "ROLLBACK" then
		newScript.Disabled = true
		oldScript.Disabled = false
	end

	line("- " .. owner.Label)
	line("  - Old: `" .. oldScript:GetFullName() .. "` -> " .. scriptState(oldScript))
	line("  - New: `" .. newScript:GetFullName() .. "` -> " .. scriptState(newScript))
	line("  - Source hash: `" .. sourceHash .. "`")
	line("")
end

local activeOldCount = 0
local activeNewCount = 0
for _, owner in ipairs(owners) do
	local oldScript = starterPlayerScripts:FindFirstChild(owner.OldName)
	local newScript = runtimeControllers:FindFirstChild(owner.NewName)
	if oldScript and oldScript:IsA("LocalScript") and not oldScript.Disabled then
		activeOldCount += 1
	end
	if newScript and newScript:IsA("LocalScript") and not newScript.Disabled then
		activeNewCount += 1
	end
end

line("## Summary")
line("")
line("- Active old helper scripts: " .. tostring(activeOldCount))
line("- Active new runtime helper scripts: " .. tostring(activeNewCount))
line("")

if MODE == "SWITCH" then
	line("Expected after fresh Play test: V64/V67/V71 behaviour should be unchanged, but Output script names should come from the new runtime owner scripts.")
elseif MODE == "ROLLBACK" then
	line("Rollback mode restored old root runtime helper scripts and disabled the new runtime owner scripts.")
else
	line("Stage-only mode prepared target scripts but did not change live ownership.")
end

local reportValue = reportsFolder:FindFirstChild("Phase16_RuntimeHelperOwnerSwitchReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase16_RuntimeHelperOwnerSwitchReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase16_RuntimeHelperOwnerSwitchReport"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("Mode", MODE)
reportValue:SetAttribute("ActiveOldHelperScripts", activeOldCount)
reportValue:SetAttribute("ActiveNewRuntimeHelperScripts", activeNewCount)

log("Phase 16 complete in mode: " .. MODE)
log("Active old helper scripts: " .. tostring(activeOldCount) .. "; active new runtime helper scripts: " .. tostring(activeNewCount))
log("Report: " .. reportValue:GetFullName())
print(reportValue.Value)
