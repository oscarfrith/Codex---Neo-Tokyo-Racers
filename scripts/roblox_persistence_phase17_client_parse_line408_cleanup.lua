-- Persistence Phase 17 client parse cleanup.
--
-- Run from Roblox Studio Command Bar in Edit mode if Play still reports:
-- NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:408:
-- "Incomplete statement: expected assignment or a function call"
--
-- Scope:
-- - Client bootstrap source only.
-- - Joins dangling continuation lines near line 408 that begin with `or` / `and`.
-- - Prints the line-408 neighbourhood before and after the cleanup.
-- - If no auto-fix is found, stores the line window in ReplicatedStorage so it
--   can be copied back into Codex.
--
-- This is a guarded source cleanup, not a gameplay rewrite.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Client Parse Cleanup"
local TARGET_LINE = 408
local SCAN_RADIUS = 40

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function trim(text)
	return tostring(text or ""):match("^%s*(.-)%s*$")
end

local function splitLines(source)
	local lines = {}
	source = tostring(source or "")
	source = string.gsub(source, "\r\n", "\n")
	source = string.gsub(source, "\r", "\n")
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		table.insert(lines, line)
	end
	return lines
end

local function joinLines(lines)
	return table.concat(lines, "\n")
end

local function printWindow(lines, center, label)
	info(label .. " around line " .. tostring(center) .. ":")
	local first = math.max(1, center - 6)
	local last = math.min(#lines, center + 6)
	local output = {}
	for index = first, last do
		local text = string.format("%04d: %s", index, tostring(lines[index] or ""))
		table.insert(output, text)
		print(text)
	end
	return table.concat(output, "\n")
end

local function writeDump(text)
	local folder = ReplicatedStorage:FindFirstChild("NTR_DEBUG")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "NTR_DEBUG"
		folder.Parent = ReplicatedStorage
	end

	local dump = folder:FindFirstChild("COPY_THIS_LINE408_SOURCE_DUMP")
	if not dump then
		dump = Instance.new("StringValue")
		dump.Name = "COPY_THIS_LINE408_SOURCE_DUMP"
		dump.Parent = folder
	end
	dump.Value = text
	pcall(function()
		Selection:Set({ dump })
	end)
	info("Stored line-window dump at ReplicatedStorage.NTR_DEBUG.COPY_THIS_LINE408_SOURCE_DUMP.Value")
	warn("========== COPY LINE 408 SOURCE DUMP BELOW ==========")
	warn(text)
	warn("========== COPY LINE 408 SOURCE DUMP ABOVE ==========")
end

local function startsWithContinuation(line)
	local stripped = tostring(line or ""):match("^%s*(.*)$")
	return string.sub(stripped, 1, 3) == "or " or string.sub(stripped, 1, 4) == "and "
end

local clientRoot = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")

local bootstrap = clientRoot:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(string.find(source, "NTR_PERSISTENCE_PHASE16_MODULE_SORTING", 1, true), "Expected Phase 16 client helper to be present.")

local lines = splitLines(source)
local beforeDump = printWindow(lines, 408, "BEFORE cleanup")
writeDump(beforeDump)

local fixes = {}
local scanStart = math.max(2, TARGET_LINE - SCAN_RADIUS)
local scanEnd = math.min(#lines, TARGET_LINE + SCAN_RADIUS)
local index = scanStart
while index <= scanEnd and index <= #lines do
	if startsWithContinuation(lines[index]) then
		local current = trim(lines[index])
		lines[index - 1] = tostring(lines[index - 1] or "") .. " " .. current
		table.remove(lines, index)
		table.insert(fixes, "Joined dangling continuation at original line " .. tostring(index) .. ": " .. current)
		scanEnd -= 1
	else
		index += 1
	end
end

if #fixes == 0 then
	warn("[NTR " .. PHASE .. "] No dangling `or` / `and` continuation lines were found near line 408.")
	warn("[NTR " .. PHASE .. "] Copy ReplicatedStorage.NTR_DEBUG.COPY_THIS_LINE408_SOURCE_DUMP.Value and paste it to Codex so the exact line 408 source can be targeted.")
	return
end

local newSource = joinLines(lines)
bootstrap.Source = newSource
bootstrap:SetAttribute("PersistencePhase17Line408ParseCleanup", true)

local afterLines = splitLines(bootstrap.Source)
local afterDump = printWindow(afterLines, 408, "AFTER cleanup")
writeDump("BEFORE:\n" .. beforeDump .. "\n\nAFTER:\n" .. afterDump)

for _, fix in ipairs(fixes) do
	info(fix)
end

local finalLines = splitLines(bootstrap.Source)
local finalStart = math.max(2, TARGET_LINE - SCAN_RADIUS)
local finalEnd = math.min(#finalLines, TARGET_LINE + SCAN_RADIUS)
for lineNumber = finalStart, finalEnd do
	assert(not startsWithContinuation(finalLines[lineNumber]), "A dangling `or` / `and` continuation still exists near line " .. tostring(lineNumber) .. ".")
end

info("PASS: cleaned dangling continuation lines from the client bootstrap.")
info("Next: stop Play, start a fresh Play session, and confirm the line 408 parse error is gone.")
