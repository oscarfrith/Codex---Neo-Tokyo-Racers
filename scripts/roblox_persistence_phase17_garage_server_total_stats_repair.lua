-- Persistence Phase 17 garage server total-stats repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if the Phase 17 smoke or
-- Play output reports:
--
--   GarageActionController_Shadow_Disabled:927: attempt to call a nil value
--
-- The refreshed mirror shows the active garage controller still calls
-- V56_totalStats(profile), but the helper block was lost during the Phase 17
-- repair sequence. This script restores only that helper before
-- V56_profileForClient.

local ServerScriptService = game:GetService("ServerScriptService")

local PHASE = "Persistence Phase 17 Garage Server Total Stats Repair"

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
assert(string.find(source, "V56_totalStats(profile)", 1, true), "Expected garage controller to call V56_totalStats.")
assert(string.find(source, "V77_ModuleUpgrades.CalculateProfile", 1, true), "Expected Phase AN/AO performance summary path to be present.")

if string.find(source, "local function V56_totalStats(profile)", 1, true) then
	garage:SetAttribute("PersistencePhase17TotalStatsRepair", "AlreadyPresent")
	info("PASS: V56_totalStats already exists; no source change was needed.")
else
	local anchor = "\n\tlocal function V56_profileForClient(profile)\n"
	local anchorAt = string.find(source, anchor, 1, true)
	assert(anchorAt, "Could not find V56_profileForClient anchor. Refresh the Studio mirror before another Phase 17 server patch.")

	local helper = [=[

	-- NTR_PERSISTENCE_PHASE17_TOTAL_STATS_REPAIR
	local function V56_totalStats(profile)
		V56_normalizeProfile(profile)
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local totals = {
			TopSpeed = V56_number(cockpit, "TopSpeed", V56_number(cockpit, "MaxSpeed", 126)),
			Acceleration = V56_number(cockpit, "Acceleration", 42),
			Handling = V56_number(cockpit, "Handling", 48),
			Drift = V56_number(cockpit, "Drift", 46),
			Braking = V56_number(cockpit, "Braking", 44),
			Weight = V56_number(cockpit, "Weight", 118),
			Boost = V56_number(cockpit, "Boost", 0),
			BoostDuration = V56_number(cockpit, "BoostDuration", 2),
			BoostRecharge = V56_number(cockpit, "BoostRecharge", 9),
			BoostRechargeDelay = V56_number(cockpit, "BoostRechargeDelay", 0),
		}
		local statNames = {
			"TopSpeed",
			"Acceleration",
			"Handling",
			"Drift",
			"Braking",
			"Weight",
			"Boost",
			"BoostDuration",
			"BoostRecharge",
			"BoostRechargeDelay",
		}
		for _, moduleId in pairs(profile.InstalledModules or {}) do
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			if module then
				for _, stat in ipairs(statNames) do
					totals[stat] = (totals[stat] or 0) + V56_number(module, stat, 0)
				end
			end
		end
		local category = V56_categoryFolder(profile.CurrentCategory)
		local upgradeRoot = category and category:FindFirstChild("UPGRADES_InvisiblePerformance")
		if upgradeRoot then
			for upgradeId, level in pairs(profile.UpgradeLevels or {}) do
				local upgrade = upgradeRoot:FindFirstChild("UPGRADE_" .. tostring(upgradeId))
				if upgrade then
					local statName = V56_string(upgrade, "StatName", V56_string(upgrade, "Stat", nil))
					local amount = V56_number(upgrade, "AmountPerLevel", V56_number(upgrade, "Amount", 0))
					if statName then
						totals[statName] = (totals[statName] or 0) + amount * (tonumber(level) or 0)
					end
				end
			end
		end
		return totals
	end
]=]

	source = string.sub(source, 1, anchorAt - 1) .. helper .. string.sub(source, anchorAt)
	garage.Source = source
	garage:SetAttribute("PersistencePhase17TotalStatsRepair", true)

	assert(string.find(garage.Source, "local function V56_totalStats(profile)", 1, true), "V56_totalStats was not installed.")
	assert(string.find(garage.Source, "NTR_PERSISTENCE_PHASE17_TOTAL_STATS_REPAIR", 1, true), "Phase 17 total-stats repair marker missing after install.")

	info("PASS: restored V56_totalStats before V56_profileForClient.")
	info("Next: stop Play, start a fresh Play session, then rerun scripts/roblox_persistence_phase17_module_owned_buy_tabs_client_smoke.lua from the CLIENT Command Bar.")
end
