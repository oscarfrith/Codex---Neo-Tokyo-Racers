-- Neo Tokyo Racers - Phase 13 Server Parity Harness
-- Run in Roblox Studio Command Bar, preferably Play mode with one test player.
--
-- Purpose:
--   Verifies the live V56 server action layer still matches the Phase 12
--   snapshot before any service extraction or GarageInvoke switch.
--
-- Safe effects:
--   - Reads HOVER_RACING_V2_Server.Source.
--   - Reads Phase 12 snapshot/extraction plan metadata.
--   - Writes a report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit, disable, rename, delete, or replace any live script.
--   - Call GarageInvoke or any purchase, colour, upgrade, spawn, exit, or
--     re-enter actions.
--   - Change cash, profile ownership, vehicle spawn, UI, driving, VFX, mobile
--     controls, LOD, lighting, traffic, assets, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SCRIPT_ID = "roblox_hierarchy_phase13_server_parity_harness"
local BEGIN_MARKER = "-- V56_CONSOLIDATED_ACTION_CONTROLLER_BEGIN"
local END_MARKER = "-- V56_CONSOLIDATED_ACTION_CONTROLLER_END"

local function log(message)
	print("[NTR Phase13 Server Parity] " .. message)
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

	local ok, snapshot = pcall(require, snapshotModule)
	if not ok then
		return nil, "Snapshot module could not be required: " .. tostring(snapshot)
	end
	if typeof(snapshot) ~= "table" then
		return nil, "Snapshot module did not return a table."
	end
	if typeof(snapshot.Hash) ~= "string" then
		return nil, "Snapshot table is missing Hash."
	end
	return snapshot.Hash, nil, snapshot
end

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")

local currentServerFolder = ServerScriptService:FindFirstChild("HOVER_RACING_V2_SERVER")
local currentServer = currentServerFolder and currentServerFolder:FindFirstChild("HOVER_RACING_V2_Server")
if not currentServer or not currentServer:IsA("Script") then
	error("Could not find ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server. No changes applied.")
end

local garageServices = ServerScriptService:FindFirstChild("NeoTokyoRacers")
	and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
	and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Garage")
local snapshotModule = garageServices and garageServices:FindFirstChild("V56ActionLayerSnapshot")

local expectedHash, snapshotError, snapshot = readSnapshotHash(snapshotModule)

local source = currentServer.Source
local beginStart, beginEnd = string.find(source, BEGIN_MARKER, 1, true)
local endStart, endEnd = string.find(source, END_MARKER, 1, true)
local currentBlock = nil
local currentHash = nil
local markerOk = beginStart ~= nil and endStart ~= nil and endStart > beginStart
if markerOk then
	currentBlock = string.sub(source, beginStart, endEnd)
	currentHash = simpleHash(currentBlock)
end

local hashMatches = expectedHash ~= nil and currentHash == expectedHash

local reportLines = {}
local function line(text)
	table.insert(reportLines, text)
end

line("# Neo Tokyo Racers Phase 13 Server Parity Harness")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Read-only server parity check. No remote actions were called.")
line("")
line("## Summary")
line("")
line("- Source script: " .. currentServer:GetFullName())
line("- Snapshot module: " .. (snapshotModule and snapshotModule:GetFullName() or "Missing"))
line("- Snapshot hash: " .. tostring(expectedHash))
line("- Current hash: " .. tostring(currentHash))
line("- Hash matches snapshot: " .. tostring(hashMatches))
line("- V56 markers found: " .. tostring(markerOk))
line("- GetInitial shape check: Not run in server harness")
line("")

line("## Result")
line("")
if markerOk and hashMatches then
	line("Status: Server action layer matches the Phase 12 snapshot. Run the client GetInitial shape checker next, then proceed to shadow service extraction.")
else
	line("Status: Stop before extraction. Resolve hash, marker, or GetInitial parity issue first.")
end
line("")

line("## Notes")
line("")
if snapshotError then
	line("- Snapshot issue: " .. snapshotError)
end
if snapshot and snapshot.SourceScriptPath then
	line("- Snapshot source path: " .. tostring(snapshot.SourceScriptPath))
end
line("- Roblox does not allow reading RemoteFunction.OnServerInvoke from this server command context.")
line("- Use the Phase 13 client GetInitial shape checker for the non-mutating response-shape test.")

local reportValue = reportsFolder:FindFirstChild("Phase13_ServerParityHarnessReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase13_ServerParityHarnessReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase13_ServerParityHarnessReport"
	reportValue.Parent = reportsFolder
end

reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("ExpectedHash", tostring(expectedHash))
reportValue:SetAttribute("CurrentHash", tostring(currentHash))
reportValue:SetAttribute("HashMatches", hashMatches)
reportValue:SetAttribute("GetInitialShapeStatus", "UseClientShapeChecker")

log("Parity report saved to " .. reportValue:GetFullName())
log("Hash matches: " .. tostring(hashMatches) .. "; GetInitial shape: use client checker")
print(reportValue.Value)
