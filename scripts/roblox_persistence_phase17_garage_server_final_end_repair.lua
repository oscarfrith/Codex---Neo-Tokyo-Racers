-- Persistence Phase 17 garage server final-end repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if Play reports:
-- GarageActionController_Shadow_Disabled: Expected 'end' ... got <eof>
--
-- The confirmed active garage controller is wrapped in a top-level `do` and
-- should end with:
--   print("[V56] Consolidated server action controller is active.")
-- end
-- -- V56_CONSOLIDATED_ACTION_CONTROLLER_END
--
-- This restores only that final missing `end` if it is absent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 17 Garage Server Final End Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function dumpTail(source)
	local folder = ReplicatedStorage:FindFirstChild("NTR_DEBUG")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "NTR_DEBUG"
		folder.Parent = ReplicatedStorage
	end
	local dump = folder:FindFirstChild("COPY_THIS_GARAGE_SERVER_TAIL_DUMP")
	if not dump then
		dump = Instance.new("StringValue")
		dump.Name = "COPY_THIS_GARAGE_SERVER_TAIL_DUMP"
		dump.Parent = folder
	end

	local lines = {}
	source = string.gsub(tostring(source or ""), "\r\n", "\n")
	source = string.gsub(source, "\r", "\n")
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		table.insert(lines, line)
	end

	local output = {}
	local first = math.max(1, #lines - 24)
	for index = first, #lines do
		table.insert(output, string.format("%04d: %s", index, tostring(lines[index] or "")))
	end
	dump.Value = table.concat(output, "\n")
	warn("========== COPY GARAGE SERVER TAIL DUMP BELOW ==========")
	warn(dump.Value)
	warn("========== COPY GARAGE SERVER TAIL DUMP ABOVE ==========")
	info("Stored tail dump at ReplicatedStorage.NTR_DEBUG.COPY_THIS_GARAGE_SERVER_TAIL_DUMP.Value")
end

local garage = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")

assert(garage:IsA("Script"), "Expected active garage controller to be a Script.")

local source = garage.Source
assert(string.find(source, "V56_CONSOLIDATED_ACTION_CONTROLLER_END", 1, true), "Expected V56 end marker to be present.")

local cleanTail = [[
	print("[V56] Consolidated server action controller is active.")
end
-- V56_CONSOLIDATED_ACTION_CONTROLLER_END]]

if string.find(source, cleanTail, 1, true) then
	info("PASS: garage server already has the final closing end before the V56 marker.")
	return
end

local missingEndTail = [[
	print("[V56] Consolidated server action controller is active.")
-- V56_CONSOLIDATED_ACTION_CONTROLLER_END]]

local first = string.find(source, missingEndTail, 1, true)
if not first then
	dumpTail(source)
	error("Could not find the expected missing-final-end tail. Paste the garage server tail dump so Codex can target the exact source.")
end

local second = string.find(source, missingEndTail, first + #missingEndTail, true)
assert(not second, "Found the missing-final-end tail more than once. Aborting so the repair stays targeted.")

source = string.sub(source, 1, first - 1) .. cleanTail .. string.sub(source, first + #missingEndTail)
garage.Source = source
garage:SetAttribute("PersistencePhase17ServerFinalEndRepair", true)

assert(string.find(garage.Source, cleanTail, 1, true), "Final closing end was not restored.")

info("PASS: restored the final garage controller `end` before V56_CONSOLIDATED_ACTION_CONTROLLER_END.")
info("Next: stop Play, start a fresh Play session, and confirm the garage server EOF error is gone.")
