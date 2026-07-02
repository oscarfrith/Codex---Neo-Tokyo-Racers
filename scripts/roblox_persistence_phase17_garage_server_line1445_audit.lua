-- Persistence Phase 17 garage server line-1445 audit.
--
-- Run from Roblox Studio Command Bar in Edit mode after the latest Phase 17
-- server repairs if Play/smoke reports:
--
--   GarageActionController_Shadow_Disabled:1445: attempt to call a nil value
--
-- This script is read-only. It prints the live Studio source around line 1445
-- and audits the helper definitions/calls most likely to be involved in
-- GetInitial startup failures.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PHASE = "Persistence Phase 17 Garage Server Line 1445 Audit"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assert(garage:IsA("Script"), "Expected active garage controller to be a Script.")

local source = garage.Source
local lines = string.split(source, "\n")
local targetLine = 1445
local fromLine = math.max(1, targetLine - 18)
local toLine = math.min(#lines, targetLine + 18)

local debugFolder = ReplicatedStorage:FindFirstChild("NTR_DEBUG") or Instance.new("Folder")
debugFolder.Name = "NTR_DEBUG"
debugFolder.Parent = ReplicatedStorage

local dump = {}
table.insert(dump, "Line count: " .. tostring(#lines))
for lineNumber = fromLine, toLine do
	table.insert(dump, string.format("%04d: %s", lineNumber, lines[lineNumber] or ""))
end

local dumpValue = debugFolder:FindFirstChild("PHASE17_GARAGE_LINE1445_DUMP") or Instance.new("StringValue")
dumpValue.Name = "PHASE17_GARAGE_LINE1445_DUMP"
dumpValue.Value = table.concat(dump, "\n")
dumpValue.Parent = debugFolder

print("========== COPY PHASE 17 GARAGE LINE 1445 DUMP BELOW ==========")
print(dumpValue.Value)
print("========== COPY PHASE 17 GARAGE LINE 1445 DUMP ABOVE ==========")

local checks = {
	{ Label = "V80_mirrorLegacyProfileToPersistence definition", Pattern = "local function V80_mirrorLegacyProfileToPersistence" },
	{ Label = "V84_generateId definition", Pattern = "local function V84_generateId(prefix)" },
	{ Label = "V84_countDictionary definition", Pattern = "local function V84_countDictionary(dictionary)" },
	{ Label = "V84_cloneDictionary definition", Pattern = "local function V84_cloneDictionary(dictionary)" },
	{ Label = "V84_createVehicleInstance definition", Pattern = "local function V84_createVehicleInstance(profile, cockpitId, sourceName)" },
	{ Label = "V84_ensureInstanceInventory definition", Pattern = "local function V84_ensureInstanceInventory(profile)" },
	{ Label = "V84_buyCockpitInstance definition", Pattern = "local function V84_buyCockpitInstance(profile, args)" },
	{ Label = "V84_buyModuleInstance definition", Pattern = "local function V84_buyModuleInstance(profile, args)" },
	{ Label = "V84_equipModuleInstance definition", Pattern = "local function V84_equipModuleInstance(profile, args)" },
	{ Label = "V85 attach forward declaration", Pattern = "local V85_attachDefaultModuleInstancesToCurrentVehicle" },
	{ Label = "V85 attach assignment", Pattern = "V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)" },
	{ Label = "V86_moduleFitsSlot definition", Pattern = "local function V86_moduleFitsSlot" },
	{ Label = "V56_totalStats definition", Pattern = "local function V56_totalStats(profile)" },
	{ Label = "V56_catalog definition", Pattern = "local function V56_catalog()" },
	{ Label = "V56_profileForClient definition", Pattern = "local function V56_profileForClient(profile)" },
}

for _, check in ipairs(checks) do
	local index = string.find(source, check.Pattern, 1, true)
	if index then
		local before = string.sub(source, 1, index)
		local _, lineNumber = string.gsub(before, "\n", "\n")
		info("PASS: " .. check.Label .. " near line " .. tostring(lineNumber + 1))
	else
		info("WARNING: missing " .. check.Label .. " (" .. check.Pattern .. ")")
	end
end

local duplicateAttachPattern = "V85_attachDefaultModuleInstancesToCurrentVehicle%s*=%s*function%(profile%)%s+V85_attachDefaultModuleInstancesToCurrentVehicle%s*=%s*function%(profile%)"
local _, duplicateAttachCount = string.gsub(source, duplicateAttachPattern, "")
if duplicateAttachCount > 0 then
	info("WARNING: duplicate V85 attach header still appears " .. tostring(duplicateAttachCount) .. " time(s).")
else
	info("PASS: no duplicate V85 attach header pattern found.")
end

info("If the exact failing line is not obvious from the dump, copy the dump block above back to Codex.")
