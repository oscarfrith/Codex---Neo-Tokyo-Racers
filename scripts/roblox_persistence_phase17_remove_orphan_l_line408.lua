-- Persistence Phase 17 line 408 orphan-character repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if the client bootstrap
-- reports:
-- NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:408:
-- "Incomplete statement: expected assignment or a function call"
--
-- The confirmed bad source window showed a single stray line:
--   l
-- immediately before:
--   -- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4
--
-- This removes only that exact orphan line.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Orphan Line Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(string.find(source, "NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4", 1, true), "Expected Phase 17 V4 client helper marker to be present.")

local badBlock = "\nend\nl\n-- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4"
local goodBlock = "\nend\n-- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4"

local first = string.find(source, badBlock, 1, true)
if not first then
	local alternateBadBlock = "\nend\nl\r\n-- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4"
	first = string.find(source, alternateBadBlock, 1, true)
	if first then
		badBlock = alternateBadBlock
	end
end

assert(first, "Could not find the exact orphan `l` line before the Phase 17 V4 marker. Run scripts/roblox_persistence_phase17_client_parse_line408_cleanup.lua and paste the new source dump.")

local second = string.find(source, badBlock, first + #badBlock, true)
assert(not second, "Found more than one orphan line pattern. Aborting so the cleanup stays targeted.")

source = string.sub(source, 1, first - 1) .. goodBlock .. string.sub(source, first + #badBlock)
bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17OrphanLine408Repair", true)

assert(not string.find(bootstrap.Source, "\nend\nl\n-- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4", 1, true), "The orphan `l` line still exists after repair.")
assert(string.find(bootstrap.Source, "\nend\n-- NTR_PERSISTENCE_PHASE17_MODULE_TABS_V4", 1, true), "The Phase 17 V4 marker is not in the expected clean position after repair.")

info("PASS: removed the orphan `l` line before the Phase 17 V4 client helper marker.")
info("Next: stop Play, start a fresh Play session, and confirm the line 408 parse error is gone.")
