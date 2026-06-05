-- Neo Tokyo Racers - Phase 20 Thrust Preview Owner Switch
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Moves the thrust preview / mobile touch visibility helper into the new
--   NeoTokyoRacersClient.Controllers.Preview architecture without changing
--   its source logic.
--
-- Default mode:
--   SWITCH
--
-- Modes:
--   STAGE_ONLY = copy/update target script, keep old script live
--   SWITCH     = enable new preview owner, disable old root script
--   ROLLBACK   = re-enable old root script, disable new owner
--
-- Safe effects:
--   - Copies exact source from HOVER_RACING_V46_ThrustPreviewOnly.
--   - Writes ThrustPreviewController_Active under the new preview controller root.
--   - Toggles only the old/new thrust preview owner scripts.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit VFX logic, camera logic, mobile controls, or touch controls.
--   - Edit HOVER_RACING_V2_Client.
--   - Edit server actions, dealership/customisation UI, driving physics, LOD,
--     lighting, traffic, or assets.
--   - Delete, rename, or move any live scripts.

local MODE = "SWITCH" -- "STAGE_ONLY", "SWITCH", or "ROLLBACK"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_hierarchy_phase20_thrust_preview_owner_switch"

local function log(message)
	print("[NTR Phase20 Thrust Preview Switch] " .. message)
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
local oldScript = starterPlayerScripts:FindFirstChild("HOVER_RACING_V46_ThrustPreviewOnly")
if not oldScript or not oldScript:IsA("LocalScript") then
	error("Missing expected old thrust preview LocalScript: StarterPlayerScripts.HOVER_RACING_V46_ThrustPreviewOnly. No changes applied.")
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local clientRoot = folder(starterPlayerScripts, "NeoTokyoRacersClient")
local controllers = folder(clientRoot, "Controllers")
local previewControllers = folder(controllers, "Preview")

local newScript = previewControllers:FindFirstChild("ThrustPreviewController_Active")
if newScript and not newScript:IsA("LocalScript") then
	error("Existing " .. newScript:GetFullName() .. " is a " .. newScript.ClassName .. ", expected LocalScript. No changes applied.")
end
if not newScript then
	newScript = Instance.new("LocalScript")
	newScript.Name = "ThrustPreviewController_Active"
	newScript.Disabled = true
	newScript.Parent = previewControllers
end

local createdBy = newScript:GetAttribute("CreatedBy")
if newScript.Source ~= "" and createdBy ~= SCRIPT_ID then
	error("Target " .. newScript:GetFullName() .. " already exists and was not created by this phase. No changes applied.")
end

local sourceHash = simpleHash(oldScript.Source)
newScript.Source = oldScript.Source
newScript:SetAttribute("CreatedBy", SCRIPT_ID)
newScript:SetAttribute("MigrationStatus", "ThrustPreviewOwnerSwitchCandidate")
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

line("# Neo Tokyo Racers Phase 20 Thrust Preview Owner Switch")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Mode: `" .. MODE .. "`")
line("")
line("This phase moves thrust preview ownership into the new preview controller architecture without changing source logic.")
line("")
line("## Results")
line("")
line("- Old: `" .. oldScript:GetFullName() .. "` -> " .. scriptState(oldScript))
line("- New: `" .. newScript:GetFullName() .. "` -> " .. scriptState(newScript))
line("- Source hash: `" .. sourceHash .. "`")
line("")
line("## Expected Test")
line("")
line("- Fresh Play should keep dealership/customisation preview behaviour unchanged.")
line("- Thrust colour preview should still show chosen colours during customisation.")
line("- Mobile Roblox touch controls should still hide while in menus and behave as before while driving.")
line("- Drive camera handoff should still work after spawning.")
line("- Vehicle, VFX, mobile controls, LOD, lighting, traffic, exit, and re-entry should be unchanged.")
line("")
if MODE == "ROLLBACK" then
	line("Rollback mode restored the old thrust preview owner and disabled the new owner.")
elseif MODE == "SWITCH" then
	line("Switch mode enabled the new thrust preview owner and disabled the old owner.")
else
	line("Stage-only mode prepared the target owner but did not change live ownership.")
end

local reportValue = reportsFolder:FindFirstChild("Phase20_ThrustPreviewOwnerSwitchReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase20_ThrustPreviewOwnerSwitchReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase20_ThrustPreviewOwnerSwitchReport"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("Mode", MODE)
reportValue:SetAttribute("SourceHash", sourceHash)
reportValue:SetAttribute("OldScriptState", scriptState(oldScript))
reportValue:SetAttribute("NewScriptState", scriptState(newScript))

log("Phase 20 complete in mode: " .. MODE)
log("Old: " .. scriptState(oldScript) .. "; new: " .. scriptState(newScript))
log("Report: " .. reportValue:GetFullName())
print(reportValue.Value)
