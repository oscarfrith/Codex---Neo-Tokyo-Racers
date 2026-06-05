-- Neo Tokyo Racers - Phase 15 Server Action Owner Switch
-- Run in Roblox Studio Command Bar, Edit mode, then Play fresh.
--
-- Purpose:
--   Switches the live server action owner from the legacy
--   HOVER_RACING_V2_Server script to the new shadow action controller created
--   by Phase 14.
--
-- Modes:
--   MODE = "SWITCH"   -> disable legacy action owner, enable shadow owner.
--   MODE = "ROLLBACK" -> re-enable legacy action owner, disable shadow owner.
--
-- Safe effects:
--   - Verifies the shadow script exists and hash matches Phase 12/14.
--   - Toggles Disabled on only these two server scripts:
--       ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server
--       ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit script Source.
--   - Delete, clone, move, or rename anything.
--   - Touch client UI, driving, VFX, mobile controls, LOD, lighting, traffic,
--     assets, or Workspace.Test + WIP Assets.

local MODE = "SWITCH" -- Change to "ROLLBACK" to undo the owner switch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SCRIPT_ID = "roblox_hierarchy_phase15_server_action_owner_switch"
local EXPECTED_HASH_ATTRIBUTE = "SourceHash"

local function log(message)
	print("[NTR Phase15 Server Switch] " .. message)
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

local function getPhase12Hash()
	local ntr = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	local compatibility = ntr and ntr:FindFirstChild("Compatibility")
	local reportsFolder = compatibility and compatibility:FindFirstChild("MigrationReports")
	local phase12Report = reportsFolder and reportsFolder:FindFirstChild("Phase12_ServerActionSnapshotReport")
	if phase12Report and phase12Report:IsA("StringValue") then
		local attrHash = phase12Report:GetAttribute("V56Hash")
		if typeof(attrHash) == "string" and attrHash ~= "" then
			return attrHash
		end
		local textHash = string.match(phase12Report.Value or "", "V56 block hash:%s*([%w_]+)")
		if textHash and textHash ~= "" then
			return textHash
		end
	end

	local shadow = findScript("ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled")
	if shadow then
		local shadowHash = shadow:GetAttribute(EXPECTED_HASH_ATTRIBUTE)
		if typeof(shadowHash) == "string" and shadowHash ~= "" then
			return shadowHash
		end
	end

	return nil
end

MODE = string.upper(tostring(MODE or ""))
if MODE ~= "SWITCH" and MODE ~= "ROLLBACK" then
	error("MODE must be SWITCH or ROLLBACK. No changes applied.")
end

local legacyServer = findScript("ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server")
if not legacyServer or not legacyServer:IsA("Script") then
	error("Could not find legacy HOVER_RACING_V2_Server script. No changes applied.")
end

local shadowServer = findScript("ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled")
if not shadowServer or not shadowServer:IsA("Script") then
	error("Could not find GarageActionController_Shadow_Disabled. Run Phase 14 first. No changes applied.")
end

local shadowHash = shadowServer:GetAttribute(EXPECTED_HASH_ATTRIBUTE)
if typeof(shadowHash) ~= "string" or shadowHash == "" then
	error("Shadow action controller is missing SourceHash. Run Phase 14 first. No changes applied.")
end

local expectedHash = getPhase12Hash()
if expectedHash and shadowHash ~= expectedHash then
	error("Shadow SourceHash " .. tostring(shadowHash) .. " does not match expected hash " .. tostring(expectedHash) .. ". No changes applied.")
end

local beforeLegacyDisabled = legacyServer.Disabled
local beforeShadowDisabled = shadowServer.Disabled

if MODE == "SWITCH" then
	shadowServer.Disabled = false
	legacyServer.Disabled = true
	shadowServer:SetAttribute("LiveEnabled", true)
	shadowServer:SetAttribute("ServerActionOwner", true)
	legacyServer:SetAttribute("LiveEnabled", false)
	legacyServer:SetAttribute("ServerActionOwner", false)
elseif MODE == "ROLLBACK" then
	legacyServer.Disabled = false
	shadowServer.Disabled = true
	legacyServer:SetAttribute("LiveEnabled", true)
	legacyServer:SetAttribute("ServerActionOwner", true)
	shadowServer:SetAttribute("LiveEnabled", false)
	shadowServer:SetAttribute("ServerActionOwner", false)
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local reportLines = {}
local function line(text)
	table.insert(reportLines, text)
end

line("# Neo Tokyo Racers Phase 15 Server Action Owner Switch")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Mode: " .. MODE)
line("- Legacy script: " .. legacyServer:GetFullName())
line("- Shadow script: " .. shadowServer:GetFullName())
line("- Shadow hash: " .. tostring(shadowHash))
line("- Expected hash: " .. tostring(expectedHash))
line("- Legacy disabled before: " .. tostring(beforeLegacyDisabled))
line("- Shadow disabled before: " .. tostring(beforeShadowDisabled))
line("- Legacy disabled after: " .. tostring(legacyServer.Disabled))
line("- Shadow disabled after: " .. tostring(shadowServer.Disabled))
line("")
line("## Required Test")
line("")
if MODE == "SWITCH" then
	line("1. Stop Play if currently running.")
	line("2. Start a fresh Play test.")
	line("3. Confirm Output shows the V56 controller running from GarageActionController_Shadow_Disabled, not HOVER_RACING_V2_Server.")
	line("4. Run Phase 13 in Server context.")
	line("5. Run Phase 13B in Client context.")
	line("6. Test cash, dealership, purchases, customisation, spawn, driving, exit/re-enter.")
	line("7. If anything fails, rerun this script with MODE = ROLLBACK.")
else
	line("Rollback applied. Start a fresh Play test and confirm HOVER_RACING_V2_Server is active again.")
end

local reportValue = reportsFolder:FindFirstChild("Phase15_ServerActionOwnerSwitchReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase15_ServerActionOwnerSwitchReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase15_ServerActionOwnerSwitchReport"
	reportValue.Parent = reportsFolder
end
reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("Mode", MODE)
reportValue:SetAttribute("ShadowHash", tostring(shadowHash))
reportValue:SetAttribute("LegacyDisabled", legacyServer.Disabled)
reportValue:SetAttribute("ShadowDisabled", shadowServer.Disabled)

log("Mode " .. MODE .. " complete.")
log("Legacy disabled: " .. tostring(legacyServer.Disabled) .. "; shadow disabled: " .. tostring(shadowServer.Disabled))
print(reportValue.Value)
