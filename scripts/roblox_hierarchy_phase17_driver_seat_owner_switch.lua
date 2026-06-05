-- Neo Tokyo Racers - Phase 17 Driver Seat Owner Switch
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Moves the driver seat position keeper into the new
--   ServerScriptService.NeoTokyoRacers.Services.Vehicle architecture without
--   changing its source logic.
--
-- Default mode:
--   SWITCH
--
-- Modes:
--   STAGE_ONLY = copy/update target script, keep old script live
--   SWITCH     = enable new vehicle service owner, disable old script
--   ROLLBACK   = re-enable old script, disable new owner
--
-- Safe effects:
--   - Copies exact source from HOVER_RACING_V2_DriverSeatPosition.
--   - Writes DriverSeatPositionService_Active under the new vehicle service root.
--   - Toggles only the old/new driver seat owner scripts.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit driving physics or DrivingControllerV47.
--   - Edit vehicle spawn/build logic.
--   - Edit client UI, runtime helpers, VFX, mobile controls, server actions,
--     LOD, lighting, traffic, or assets.
--   - Delete, rename, or move any live scripts.

local MODE = "SWITCH" -- "STAGE_ONLY", "SWITCH", or "ROLLBACK"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SCRIPT_ID = "roblox_hierarchy_phase17_driver_seat_owner_switch"

local function log(message)
	print("[NTR Phase17 Driver Seat Switch] " .. message)
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

local legacyServerFolder = ServerScriptService:FindFirstChild("HOVER_RACING_V2_SERVER")
local oldScript = legacyServerFolder and legacyServerFolder:FindFirstChild("HOVER_RACING_V2_DriverSeatPosition")
if not oldScript or not oldScript:IsA("Script") then
	error("Missing expected old driver seat script: ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_DriverSeatPosition. No changes applied.")
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local serverRoot = folder(ServerScriptService, "NeoTokyoRacers")
local services = folder(serverRoot, "Services")
local vehicleServices = folder(services, "Vehicle")

local newScript = vehicleServices:FindFirstChild("DriverSeatPositionService_Active")
if newScript and not newScript:IsA("Script") then
	error("Existing " .. newScript:GetFullName() .. " is a " .. newScript.ClassName .. ", expected Script. No changes applied.")
end
if not newScript then
	newScript = Instance.new("Script")
	newScript.Name = "DriverSeatPositionService_Active"
	newScript.Disabled = true
	newScript.Parent = vehicleServices
end

local createdBy = newScript:GetAttribute("CreatedBy")
if newScript.Source ~= "" and createdBy ~= SCRIPT_ID then
	error("Target " .. newScript:GetFullName() .. " already exists and was not created by this phase. No changes applied.")
end

local sourceHash = simpleHash(oldScript.Source)
newScript.Source = oldScript.Source
newScript:SetAttribute("CreatedBy", SCRIPT_ID)
newScript:SetAttribute("MigrationStatus", "DriverSeatOwnerSwitchCandidate")
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

line("# Neo Tokyo Racers Phase 17 Driver Seat Owner Switch")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Mode: `" .. MODE .. "`")
line("")
line("This phase moves driver seat position keeper ownership into the new vehicle service architecture without changing source logic.")
line("")
line("## Results")
line("")
line("- Old: `" .. oldScript:GetFullName() .. "` -> " .. scriptState(oldScript))
line("- New: `" .. newScript:GetFullName() .. "` -> " .. scriptState(newScript))
line("- Source hash: `" .. sourceHash .. "`")
line("")
line("## Expected Test")
line("")
line("- Fresh Play output should show `Hover Racing driver seat position keeper running.` from `DriverSeatPositionService_Active`.")
line("- Vehicle spawn should still seat the player correctly.")
line("- Exit/re-enter should still work.")
line("- The configured seat offset should still be respected.")
line("")
if MODE == "ROLLBACK" then
	line("Rollback mode restored the old driver seat keeper and disabled the new owner.")
elseif MODE == "SWITCH" then
	line("Switch mode enabled the new driver seat owner and disabled the old owner.")
else
	line("Stage-only mode prepared the target owner but did not change live ownership.")
end

local reportValue = reportsFolder:FindFirstChild("Phase17_DriverSeatOwnerSwitchReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase17_DriverSeatOwnerSwitchReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase17_DriverSeatOwnerSwitchReport"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("Mode", MODE)
reportValue:SetAttribute("SourceHash", sourceHash)
reportValue:SetAttribute("OldScriptState", scriptState(oldScript))
reportValue:SetAttribute("NewScriptState", scriptState(newScript))

log("Phase 17 complete in mode: " .. MODE)
log("Old: " .. scriptState(oldScript) .. "; new: " .. scriptState(newScript))
log("Report: " .. reportValue:GetFullName())
print(reportValue.Value)
