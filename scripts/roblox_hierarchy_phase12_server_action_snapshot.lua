-- Neo Tokyo Racers - Phase 12 Server Action Snapshot
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Captures the current live V56 server action block into the new architecture
--   as a non-live snapshot/parity reference before real service extraction.
--
-- Safe effects:
--   - Reads HOVER_RACING_V2_Server.Source.
--   - Writes snapshot/metadata ModuleScripts under the staged server/service roots.
--   - Writes a text report under ReplicatedStorage.NeoTokyoRacers.Compatibility.
--
-- Does NOT:
--   - Edit, disable, rename, delete, or replace HOVER_RACING_V2_Server.
--   - Replace GarageInvoke.OnServerInvoke.
--   - Enable the future server bootstrap.
--   - Change client UI, driving, VFX, mobile controls, LOD, lighting, traffic,
--     assets, or Workspace.Test + WIP Assets.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SCRIPT_ID = "roblox_hierarchy_phase12_server_action_snapshot"
local BEGIN_MARKER = "-- V56_CONSOLIDATED_ACTION_CONTROLLER_BEGIN"
local END_MARKER = "-- V56_CONSOLIDATED_ACTION_CONTROLLER_END"

local function log(message)
	print("[NTR Phase12 Server Snapshot] " .. message)
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

local function writeModule(parent, name, source)
	local module = parent:FindFirstChild(name)
	if module and not module:IsA("ModuleScript") then
		error("Existing " .. module:GetFullName() .. " is a " .. module.ClassName .. ", expected ModuleScript. No changes applied.")
	end
	if not module then
		module = Instance.new("ModuleScript")
		module.Name = name
		module.Parent = parent
	end

	local createdBy = module:GetAttribute("CreatedBy")
	if module.Source ~= "" and createdBy ~= SCRIPT_ID then
		log("Skipped existing manually-created module: " .. module:GetFullName())
		return module, false
	end

	module.Source = source
	module:SetAttribute("CreatedBy", SCRIPT_ID)
	module:SetAttribute("MigrationStatus", "SnapshotOnly")
	module:SetAttribute("LiveEnabled", false)
	return module, true
end

local function simpleHash(text)
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (hash * 16777619) % 4294967296
	end
	return string.format("%08x", hash)
end

local function findLineNumber(source, index)
	local prefix = string.sub(source, 1, math.max(index - 1, 0))
	local _, count = string.gsub(prefix, "\n", "")
	return count + 1
end

local currentServerFolder = ServerScriptService:FindFirstChild("HOVER_RACING_V2_SERVER")
local currentServer = currentServerFolder and currentServerFolder:FindFirstChild("HOVER_RACING_V2_Server")
if not currentServer or not currentServer:IsA("Script") then
	error("Could not find ServerScriptService.HOVER_RACING_V2_SERVER.HOVER_RACING_V2_Server. No changes applied.")
end

local source = currentServer.Source
local beginStart, beginEnd = string.find(source, BEGIN_MARKER, 1, true)
local endStart, endEnd = string.find(source, END_MARKER, 1, true)
if not beginStart or not endStart or endStart <= beginStart then
	error("Could not find V56 begin/end markers in live server source. No changes applied.")
end

local v56Block = string.sub(source, beginStart, endEnd)
local beginLine = findLineNumber(source, beginStart)
local endLine = findLineNumber(source, endEnd)
local blockHash = simpleHash(v56Block)

local functionNames = {}
for name in string.gmatch(v56Block, "local%s+function%s+(V56_[%w_]+)") do
	table.insert(functionNames, name)
end
table.sort(functionNames)

local actionNames = {}
for action in string.gmatch(v56Block, "action%s*==%s*\"([%w_]+)\"") do
	actionNames[action] = true
end
local sortedActions = {}
for action in pairs(actionNames) do
	table.insert(sortedActions, action)
end
table.sort(sortedActions)

local ntr = folder(ReplicatedStorage, "NeoTokyoRacers")
local compatibility = folder(ntr, "Compatibility")
local reportsFolder = folder(compatibility, "MigrationReports")
local shared = folder(ntr, "Shared")
local sharedModules = folder(shared, "Modules")
local sharedData = folder(sharedModules, "Data")

local serverRoot = folder(ServerScriptService, "NeoTokyoRacers")
local services = folder(serverRoot, "Services")
local garageServices = folder(services, "Garage")
local vehicleServices = folder(services, "Vehicle")
local playerServices = folder(services, "Player")
local economyServices = folder(services, "Economy")

local snapshotSource = table.concat({
	"-- Auto-generated V56 server action snapshot.",
	"-- Snapshot only. Do not require from live gameplay.",
	"",
	"return {",
	"	CapturedAt = " .. string.format("%q", os.date("%Y-%m-%d %H:%M:%S")) .. ",",
	"	SourceScriptPath = " .. string.format("%q", currentServer:GetFullName()) .. ",",
	"	BeginLine = " .. tostring(beginLine) .. ",",
	"	EndLine = " .. tostring(endLine) .. ",",
	"	Hash = " .. string.format("%q", blockHash) .. ",",
	"	Source = " .. string.format("%q", v56Block) .. ",",
	"}",
	"",
}, "\n")

local planSource = table.concat({
	"-- Auto-generated V56 server service extraction plan.",
	"-- Snapshot only. Current live server remains HOVER_RACING_V2_Server.",
	"",
	"return {",
	"	SourceScriptPath = " .. string.format("%q", currentServer:GetFullName()) .. ",",
	"	V56Hash = " .. string.format("%q", blockHash) .. ",",
	"	V56LineRange = { " .. tostring(beginLine) .. ", " .. tostring(endLine) .. " },",
	"	Actions = {",
}, "\n")

for _, action in ipairs(sortedActions) do
	planSource ..= "\n		" .. string.format("%q", action) .. ","
end

planSource ..= "\n	},\n	Functions = {"
for _, fn in ipairs(functionNames) do
	planSource ..= "\n		" .. string.format("%q", fn) .. ","
end

planSource ..= [=[

	},
	ServiceGroups = {
		ProfileService = {
			"V56_defaultProfile",
			"V56_normalizeProfile",
			"V56_getProfile",
			"V56_setLeaderstats",
		},
		EconomyService = {
			"V56_value",
			"V56_number",
			"V56_string",
		},
		VehicleCatalogService = {
			"V56_slug",
			"V56_categoryFolder",
			"V56_findByAttribute",
			"V56_findCockpit",
			"V56_findModule",
			"V56_moduleTypeFromText",
			"V56_moduleTypeForModel",
			"V56_defaultSlots",
			"V56_nearestModuleFolder",
			"V56_readModule",
			"V56_catalog",
		},
		VehicleStatsService = {
			"V56_totalStats",
			"V56_profileForClient",
			"V56_primitiveAttributes",
		},
		VehicleBuildService = {
			"V56_resolvePaintChannel",
			"V56_pathHas",
			"V56_applyColors",
			"V56_getSlotMount",
			"V56_pivotModuleToSlot",
			"V56_weldVehicle",
			"V56_makeDriverSeat",
			"V56_folderHasBuyableNeon",
			"V56_buildVehicle",
		},
		VehicleSpawnService = {
			"V56_clearPlayerVehicle",
			"V56_seatPlayer",
			"V56_exitVehicle",
			"V56_reEnterVehicle",
		},
		GarageActionService = {
			"V56_invoke.OnServerInvoke",
			"Init",
			"BuyCockpit",
			"SetCockpitColor",
			"BuyModule",
			"SetModuleColor",
			"Upgrade",
			"BuyNeon",
			"SetThrustColor",
			"SpawnVehicle",
			"ExitVehicle",
			"ReEnterVehicle",
		},
	},
	NextSafeStep = "Create service modules from this plan, then run parity tests before switching GarageInvoke.",
}
]=]

local reportLines = {}
local function line(text)
	table.insert(reportLines, text)
end

line("# Neo Tokyo Racers Phase 12 Server Action Snapshot")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("Read-only capture with staged snapshot writes. No live server action behaviour was changed.")
line("")
line("## Summary")
line("")
line("- Source script: " .. currentServer:GetFullName())
line("- V56 line range: " .. tostring(beginLine) .. "-" .. tostring(endLine))
line("- V56 block hash: " .. blockHash)
line("- Captured functions: " .. tostring(#functionNames))
line("- Captured actions: " .. tostring(#sortedActions))
line("")
line("## Actions")
line("")
for _, action in ipairs(sortedActions) do
	line("- " .. action)
end
line("")
line("## Functions")
line("")
for _, fn in ipairs(functionNames) do
	line("- " .. fn)
end
line("")
line("## Safety")
line("")
line("- Current HOVER_RACING_V2_Server remains live.")
line("- Current GarageInvoke.OnServerInvoke remains live.")
line("- New service modules remain scaffold/snapshot only.")
line("- Next phase should create a shadow service implementation or parity harness before any live switch.")

local reportValue = reportsFolder:FindFirstChild("Phase12_ServerActionSnapshotReport")
if not reportValue or not reportValue:IsA("StringValue") then
	if reportValue then
		reportValue.Name = "Phase12_ServerActionSnapshotReport_OldNonStringValue"
	end
	reportValue = Instance.new("StringValue")
	reportValue.Name = "Phase12_ServerActionSnapshotReport"
	reportValue.Parent = reportsFolder
end
reportValue.Value = table.concat(reportLines, "\n")
reportValue:SetAttribute("CreatedBy", SCRIPT_ID)
reportValue:SetAttribute("LastGenerated", os.date("%Y-%m-%d %H:%M:%S"))
reportValue:SetAttribute("V56Hash", blockHash)

local snapshotModule = writeModule(garageServices, "V56ActionLayerSnapshot", snapshotSource)
local planModule = writeModule(sharedData, "ServerServiceExtractionPlan", planSource)

if snapshotModule and snapshotModule:IsA("ModuleScript") then
	snapshotModule:SetAttribute("Hash", blockHash)
	snapshotModule:SetAttribute("BeginLine", beginLine)
	snapshotModule:SetAttribute("EndLine", endLine)
	snapshotModule:SetAttribute("SourceScriptPath", currentServer:GetFullName())
end

if planModule and planModule:IsA("ModuleScript") then
	planModule:SetAttribute("V56Hash", blockHash)
	planModule:SetAttribute("SourceScriptPath", currentServer:GetFullName())
end

for _, module in ipairs({
	garageServices:FindFirstChild("GarageActionService"),
	vehicleServices:FindFirstChild("VehicleBuildService"),
	vehicleServices:FindFirstChild("VehicleCatalogService"),
	vehicleServices:FindFirstChild("VehicleSpawnService"),
	vehicleServices:FindFirstChild("VehicleStatsService"),
	playerServices:FindFirstChild("ProfileService"),
	economyServices:FindFirstChild("EconomyService"),
}) do
	if module and module:IsA("ModuleScript") then
		module:SetAttribute("V56SnapshotHash", blockHash)
		module:SetAttribute("V56SnapshotSource", snapshotModule:GetFullName())
		module:SetAttribute("ExtractionPlan", planModule:GetFullName())
		module:SetAttribute("LiveEnabled", false)
	end
end

log("Captured V56 action layer snapshot: lines " .. tostring(beginLine) .. "-" .. tostring(endLine) .. ", hash " .. blockHash)
log("Snapshot module: " .. snapshotModule:GetFullName())
log("Extraction plan: " .. planModule:GetFullName())
log("Report: " .. reportValue:GetFullName())
print(reportValue.Value)
