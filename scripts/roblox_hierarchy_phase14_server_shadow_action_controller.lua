-- Neo Tokyo Racers - Phase 14 Server Shadow Action Controller
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates a disabled shadow server Script in the new architecture containing
--   the exact current V56 action controller block. This is a switch candidate
--   for a later phase, not a live change.
--
-- Safe effects:
--   - Reads HOVER_RACING_V2_Server.Source.
--   - Verifies the current V56 hash matches the Phase 12 snapshot.
--   - Writes a disabled Script under ServerScriptService.NeoTokyoRacers.Services.Garage.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit, disable, rename, delete, or replace HOVER_RACING_V2_Server.
--   - Enable the shadow script.
--   - Replace GarageInvoke.OnServerInvoke.
--   - Change client UI, driving, VFX, mobile controls, LOD, lighting, traffic,
--     assets, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SCRIPT_ID = "roblox_hierarchy_phase14_server_shadow_action_controller"
local BEGIN_MARKER = "-- V56_CONSOLIDATED_ACTION_CONTROLLER_BEGIN"
local END_MARKER = "-- V56_CONSOLIDATED_ACTION_CONTROLLER_END"

local function log(message)
	print("[NTR Phase14 Server Shadow] " .. message)
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

local function readSnapshotHash(snapshotModule)
	if not snapshotModule or not snapshotModule:IsA("ModuleScript") then
		return nil, "Snapshot module missing."
	end

	local attrHash = snapshotModule:GetAttribute("Hash")
	if typeof(attrHash) == "string" and attrHash ~= "" then
		return attrHash, nil, nil
	end

	local ok, snapshot = pcall(require, snapshotModule)
	if not ok then
		return nil, "Snapshot module could not be required: " .. tostring(snapshot)
	end
	if typeof(snapshot) ~= "table" or typeof(snapshot.Hash) ~= "string" then
		return nil, "Snapshot module did not return a table with Hash."
	end
	return snapshot.Hash, nil, snapshot
end

local function readPhase12ReportHash(reportsFolder)
	local report = reportsFolder and reportsFolder:FindFirstChild("Phase12_ServerActionSnapshotReport")
	if report and report:IsA("StringValue") then
		local attrHash = report:GetAttribute("V56Hash")
		if typeof(attrHash) == "string" and attrHash ~= "" then
			return attrHash, nil
		end
		local textHash = string.match(report.Value or "", "V56 block hash:%s*([%w_]+)")
		if textHash and textHash ~= "" then
			return textHash, nil
		end
	end
	return nil, "Phase12 report hash missing."
end

local currentServerFolder = ServerScriptService:FindFirstChild("HOVER_RACING_V2_SERVER")
local currentServer = currentServerFolder and currentServerFolder:FindFirstChild("HOVER_RACING_V2_Server")
if not currentServer or not currentServer:IsA("Script") then
	error("Could not find ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server. No changes applied.")
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local serverRoot = folder(ServerScriptService, "NeoTokyoRacers")
local services = folder(serverRoot, "Services")
local garageServices = folder(services, "Garage")
local snapshotModule = garageServices:FindFirstChild("V56ActionLayerSnapshot")
local expectedHash, snapshotError = readSnapshotHash(snapshotModule)
if not expectedHash then
	local reportHash, reportError = readPhase12ReportHash(reportsFolder)
	if reportHash then
		expectedHash = reportHash
		log("Snapshot module hash unavailable, using Phase 12 report hash: " .. tostring(expectedHash))
	else
		error("Could not read Phase 12 snapshot hash: " .. tostring(snapshotError) .. "; " .. tostring(reportError) .. ". Rerun Phase 12 first.")
	end
end

local source = currentServer.Source
local beginStart, beginEnd = string.find(source, BEGIN_MARKER, 1, true)
local endStart, endEnd = string.find(source, END_MARKER, 1, true)
if not beginStart or not endStart or endStart <= beginStart then
	error("Could not find V56 begin/end markers in live server source. No changes applied.")
end

local v56Block = string.sub(source, beginStart, endEnd)
local currentHash = simpleHash(v56Block)
if currentHash ~= expectedHash then
	error("Current V56 hash " .. tostring(currentHash) .. " does not match snapshot hash " .. tostring(expectedHash) .. ". Rerun Phase 12/13 before creating a shadow controller.")
end

local shadowScript = garageServices:FindFirstChild("GarageActionController_Shadow_Disabled")
if shadowScript and not shadowScript:IsA("Script") then
	error("Existing " .. shadowScript:GetFullName() .. " is a " .. shadowScript.ClassName .. ", expected Script. No changes applied.")
end
if not shadowScript then
	shadowScript = Instance.new("Script")
	shadowScript.Name = "GarageActionController_Shadow_Disabled"
	shadowScript.Disabled = true
	shadowScript.Parent = garageServices
end

local createdBy = shadowScript:GetAttribute("CreatedBy")
if shadowScript.Source ~= "" and createdBy ~= SCRIPT_ID then
	error("Shadow script already exists and was not created by this phase. No changes applied.")
end

local shadowSource = table.concat({
	"-- Neo Tokyo Racers shadow server action controller.",
	"-- Disabled switch candidate generated from the current V56 action block.",
	"-- Do not enable while HOVER_RACING_V2_Server still owns GarageInvoke.OnServerInvoke.",
	"-- Source hash: " .. currentHash,
	"",
	v56Block,
	"",
}, "\n")

shadowScript.Disabled = true
shadowScript.Source = shadowSource
shadowScript:SetAttribute("CreatedBy", SCRIPT_ID)
shadowScript:SetAttribute("MigrationStatus", "ShadowSwitchCandidate")
shadowScript:SetAttribute("LiveEnabled", false)
shadowScript:SetAttribute("SourceHash", currentHash)
shadowScript:SetAttribute("SourceScriptPath", currentServer:GetFullName())
shadowScript:SetAttribute("DoNotEnableWithLegacyServer", true)

local reportLines = {}
local function line(text)
	table.insert(reportLines, text)
end

line("# Neo Tokyo Racers Phase 14 Server Shadow Action Controller")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Disabled shadow action controller generated from the live V56 block. No live behaviour changed.")
line("")
line("## Summary")
line("")
line("- Source script: " .. currentServer:GetFullName())
line("- Shadow script: " .. shadowScript:GetFullName())
line("- Source hash: " .. currentHash)
line("- Matches Phase 12 snapshot: true")
line("- Shadow script disabled: " .. tostring(shadowScript.Disabled))
line("")
line("## Safety")
line("")
line("- Do not enable the shadow script while HOVER_RACING_V2_Server is still active.")
line("- The next phase should perform a controlled switch: disable the legacy server action owner, enable the shadow action controller, then run Phase 13/13B and full gameplay tests.")

local reportValue = reportsFolder:FindFirstChild("Phase14_ServerShadowActionControllerReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase14_ServerShadowActionControllerReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase14_ServerShadowActionControllerReport"
	reportValue.Parent = reportsFolder
end
reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("SourceHash", currentHash)
reportValue:SetAttribute("ShadowScript", shadowScript:GetFullName())

log("Created disabled shadow action controller: " .. shadowScript:GetFullName())
log("Hash verified: " .. currentHash)
print(reportValue.Value)
