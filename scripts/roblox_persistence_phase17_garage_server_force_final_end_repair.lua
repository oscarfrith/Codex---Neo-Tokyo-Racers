-- Persistence Phase 17 garage server force-final-end repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if Play still reports:
-- GarageActionController_Shadow_Disabled: Expected 'end' ... got <eof>
--
-- This is more tolerant than the first final-end repair. It finds the final
-- `-- V56_CONSOLIDATED_ACTION_CONTROLLER_END` marker and inserts one closing
-- `end` immediately before it when the previous non-empty line is not already
-- `end`.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 17 Garage Server Force Final End Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function splitLines(source)
	local lines = {}
	source = string.gsub(tostring(source or ""), "\r\n", "\n")
	source = string.gsub(source, "\r", "\n")
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		table.insert(lines, line)
	end
	return lines
end

local function writeTailDump(lines, label)
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

	local output = { label }
	local first = math.max(1, #lines - 30)
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

local lines = splitLines(garage.Source)
local markerLine = nil
for index = #lines, 1, -1 do
	if string.find(lines[index], "V56_CONSOLIDATED_ACTION_CONTROLLER_END", 1, true) then
		markerLine = index
		break
	end
end

if not markerLine then
	writeTailDump(lines, "No V56_CONSOLIDATED_ACTION_CONTROLLER_END marker found.")
	error("Could not find V56_CONSOLIDATED_ACTION_CONTROLLER_END. Paste the tail dump so Codex can target the exact live source.")
end

local previousNonEmpty = markerLine - 1
while previousNonEmpty >= 1 and string.match(lines[previousNonEmpty], "^%s*$") do
	previousNonEmpty -= 1
end

local previousText = previousNonEmpty >= 1 and tostring(lines[previousNonEmpty] or "") or ""
if string.match(previousText, "^%s*end%s*$") then
	writeTailDump(lines, "Marker is already preceded by an `end`; no force insert was made.")
	error("The final marker is already preceded by `end`, so the missing close is elsewhere. Paste the tail dump.")
end

table.insert(lines, markerLine, "end")
garage.Source = table.concat(lines, "\n")
garage:SetAttribute("PersistencePhase17ForceFinalEndRepair", true)

local afterLines = splitLines(garage.Source)
writeTailDump(afterLines, "Inserted one final `end` before V56_CONSOLIDATED_ACTION_CONTROLLER_END.")

info("PASS: inserted one closing `end` before V56_CONSOLIDATED_ACTION_CONTROLLER_END.")
info("Next: stop Play, start a fresh Play session, and confirm the garage server EOF error is gone.")
