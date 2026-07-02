-- Persistence Phase 17 garage server duplicate attach-header repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if Play reports:
-- GarageActionController_Shadow_Disabled: Expected 'end' ... got <eof>
--
-- The refreshed Studio mirror confirmed this malformed line in the active
-- garage controller:
--
--   V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile) V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)
--
-- That opens two functions but the body only closes one. This repair replaces
-- only that exact duplicated header with one valid function header.

local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 17 Garage Server Duplicate Attach Header Repair"

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
assert(string.find(source, "NTR_PERSISTENCE_PHASE17_MODULE_SLOT_GUARD", 1, true), "Expected Phase 17 server slot guard to be present.")

local good = "V85_attachDefaultModuleInstancesToCurrentVehicle = function(profile)"
local bad = good .. "\t" .. good

local first = string.find(source, bad, 1, true)
assert(first, "Could not find the duplicated V85_attachDefaultModuleInstancesToCurrentVehicle header. Refresh mirror or paste the server source around the Phase 17 slot guard.")

local second = string.find(source, bad, first + #bad, true)
assert(not second, "Duplicated attach header appears more than once. Aborting so the repair stays targeted.")

source = string.sub(source, 1, first - 1) .. good .. string.sub(source, first + #bad)
garage.Source = source
garage:SetAttribute("PersistencePhase17DuplicateAttachHeaderRepair", true)

assert(not string.find(garage.Source, bad, 1, true), "Duplicated attach header still exists after repair.")
assert(string.find(garage.Source, "\n\t" .. good .. "\n", 1, true), "Clean attach header is not in the expected shape after repair.")

info("PASS: removed the duplicated V85_attachDefaultModuleInstancesToCurrentVehicle function header.")
info("Next: stop Play, start a fresh Play session, and confirm the garage server EOF error is gone.")
