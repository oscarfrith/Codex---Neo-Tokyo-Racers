-- Neo Tokyo Racers - Dealership / Customisation Split Phase 4
-- Correct instance ratings, tier badge, and Build Modules entry.
--
-- Run from Roblox Studio Command Bar in Edit mode after Phase 3 + summary repair.
--
-- Scope:
-- - Replaces the Phase 3 summary fallback with a closer copy of the main
--   V56_totalStats logic so owned-cockpit card ratings match the vehicle build.
-- - Adds a colour-coded tier badge on each owned vehicle card.
-- - Changes the customisation-zone action to open Build Modules / ModuleShop
--   instead of the final Customise colour/performance screen.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local PHASE = "Dealership Customisation Split Phase 4"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE4_RATING_BADGE_BUILD_MODULES"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another Phase 4 patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Aborting.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before)
end

local function runClientSmoke()
	local player = Players.LocalPlayer
	assert(player, "Client smoke must be run from the CLIENT Command Bar during Play.")
	local invoke = ReplicatedStorage
		:WaitForChild("NeoTokyoRacers")
		:WaitForChild("Shared")
		:WaitForChild("Remotes")
		:WaitForChild("Garage")
		:WaitForChild("GarageInvoke")
	local result = invoke:InvokeServer("GetInitial", {})
	assert(typeof(result) == "table" and result.Success == true, "GetInitial failed: " .. tostring(result and result.Message))
	local count = 0
	for vehicleId, summary in pairs((result.Profile and result.Profile.VehicleSummaries) or {}) do
		count += 1
		local overall = summary.Overall or {}
		info("Vehicle " .. tostring(vehicleId) .. " rating=" .. tostring(overall.Tier or "--") .. " " .. tostring(overall.PerformanceIndex or "---"))
	end
	info("Vehicle summary smoke OK. count=" .. tostring(count))
end

if RunService:IsRunning() then
	runClientSmoke()
	return
end

local serverScript = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")
assert(serverScript:IsA("Script"), "Expected GarageActionController_Shadow_Disabled to be a Script.")

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

do
	local source = serverScript.Source
	if findPlain(source, MARKER) then
		info("Server rating repair already installed.")
	else
		assert(findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_SUMMARY_REPAIR"), "Run Phase 3 summary repair before Phase 4.")

		local oldSummaryTotals = [=[	local function V90_summaryTotals(profile)
		if typeof(V56_totalStats) == "function" then
			return V56_totalStats(profile)
		end
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local totals = {
			TopSpeed = V90_numberAttribute(cockpit, "TopSpeed", V90_numberAttribute(cockpit, "MaxSpeed", 126)),
			Acceleration = V90_numberAttribute(cockpit, "Acceleration", 42),
			Handling = V90_numberAttribute(cockpit, "Handling", 48),
			Drift = V90_numberAttribute(cockpit, "Drift", 46),
			Braking = V90_numberAttribute(cockpit, "Braking", 44),
			Weight = V90_numberAttribute(cockpit, "Weight", 118),
			Boost = V90_numberAttribute(cockpit, "Boost", 0),
		}
		for _, moduleId in pairs(profile.InstalledModules or {}) do
			V90_addModuleStats(totals, V56_findModule(profile.CurrentCategory, moduleId))
		end
		return totals
	end]=]

		local newSummaryTotals = [=[	local function V90_summaryTotals(profile)
		-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE4_RATING_BADGE_BUILD_MODULES
		if typeof(V56_totalStats) == "function" then
			return V56_totalStats(profile)
		end
		local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		local totals = {
			TopSpeed = V90_numberAttribute(cockpit, "TopSpeed", V90_numberAttribute(cockpit, "MaxSpeed", 126)),
			Acceleration = V90_numberAttribute(cockpit, "Acceleration", 42),
			Handling = V90_numberAttribute(cockpit, "Handling", 48),
			Drift = V90_numberAttribute(cockpit, "Drift", 46),
			Braking = V90_numberAttribute(cockpit, "Braking", 44),
			Weight = V90_numberAttribute(cockpit, "Weight", 118),
			Boost = V90_numberAttribute(cockpit, "Boost", 0),
			BoostDuration = V90_numberAttribute(cockpit, "BoostDuration", 2),
			BoostRecharge = V90_numberAttribute(cockpit, "BoostRecharge", 9),
			BoostRechargeDelay = V90_numberAttribute(cockpit, "BoostRechargeDelay", 0),
		}
		for _, moduleId in pairs(profile.InstalledModules or {}) do
			local module = V56_findModule(profile.CurrentCategory, moduleId)
			if module then
				for _, stat in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "BoostDuration", "BoostRecharge", "BoostRechargeDelay" }) do
					totals[stat] = (totals[stat] or 0) + V90_numberAttribute(module, stat, 0)
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
	end]=]

		source = replaceOnce(source, oldSummaryTotals, newSummaryTotals, "exact vehicle summary totals")
		serverScript.Source = source
		info("Patched VehicleSummaries to use the main total-stat logic shape.")
	end
end

do
	local source = bootstrap.Source
	if findPlain(source, MARKER) then
		info("Client tier badge / Build Modules patch already installed.")
	else
		assert(findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_INSTANCE_CARDS"), "Run Phase 3 before Phase 4.")

		local oldAction = [=[		local customiseButton = button(UI.StatsPanel, "Customise", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)
		customiseButton.MouseButton1Click:Connect(function()
			local result = callServer("SelectVehicleInstance", { VehicleId = State.SelectedVehicleId, CockpitId = State.SelectedCockpit })
			if result.Success then
				NTR_phase4UnlockPreviewAfterPurchase()
				State.CustomizeTarget = "ALL"
				State.CustomizeMode = "Colour"
				setCameraSection("Engine1")
				showStage("Customise")
				renderCustomise()
			else
				UI.Subtitle.Text = result.Message or "Could not open customisation."
				renderDealershipPanel()
			end
		end)]=]

		local newAction = [=[		local customiseButton = button(UI.StatsPanel, "Build Modules", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)
		customiseButton.MouseButton1Click:Connect(function()
			local result = callServer("SelectVehicleInstance", { VehicleId = State.SelectedVehicleId, CockpitId = State.SelectedCockpit })
			if result.Success then
				NTR_phase4UnlockPreviewAfterPurchase()
				State.ModuleMode = "Slots"
				State.SelectedModuleId = nil
				State.SelectedModuleInstanceId = nil
				State.CustomizeTarget = "ALL"
				State.CustomizeMode = "Colour"
				local firstSlot = sortedSlots()[1]
				State.SelectedSlot = firstSlot and firstSlot.SlotId or State.SelectedSlot or "Engine1"
				setCameraSection(State.SelectedSlot or "Engine1")
				showStage("ModuleShop")
				renderModuleShop()
			else
				UI.Subtitle.Text = result.Message or "Could not open build modules."
				renderDealershipPanel()
			end
		end)]=]

		local oldRatingHelpers = [=[	local function vehicleRating(vehicleId)
		local summary = State.Profile and State.Profile.VehicleSummaries and State.Profile.VehicleSummaries[vehicleId]
		local overall = summary and summary.Overall or {}
		local tier = tostring(overall.Tier or "--")
		local index = tonumber(overall.PerformanceIndex)
		return tier .. " " .. (index and tostring(math.floor(index)) or "---")
	end]=]

		local newRatingHelpers = [=[	local function vehicleRatingParts(vehicleId)
		local summary = State.Profile and State.Profile.VehicleSummaries and State.Profile.VehicleSummaries[vehicleId]
		local overall = summary and summary.Overall or {}
		local tier = tostring(overall.Tier or "--")
		local index = tonumber(overall.PerformanceIndex)
		return tier, (index and tostring(math.floor(index)) or "---")
	end

	local function vehicleRating(vehicleId)
		local tier, index = vehicleRatingParts(vehicleId)
		return tier .. " " .. index
	end

	local function tierBadgeColor(tier)
		if NTRVehiclePhaseAO and typeof(NTRVehiclePhaseAO.tierColor) == "function" then
			return NTRVehiclePhaseAO.tierColor(tier)
		end
		return Theme.Accent
	end]=]

		local oldCardRating = [=[			pooledLabel(card, vehicleRating(row.VehicleId), UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 86), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Accent
			cockpitPool:Connect(card, card.MouseButton1Click, function()]=]

		local newCardRating = [=[			local tier, ratingIndex = vehicleRatingParts(row.VehicleId)
			local tierBadge = new("Frame", { BackgroundColor3 = tierBadgeColor(tier), BackgroundTransparency = 0.05, BorderSizePixel = 0, Size = UDim2.fromOffset(26, 18), Position = UDim2.fromOffset(7, 86) }, card)
			tierBadge:SetAttribute("PooledDynamic", true)
			corner(tierBadge, 3)
			pooledLabel(tierBadge, tier, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 10, Enum.TextXAlignment.Center)
			pooledLabel(card, ratingIndex, UDim2.new(1, -44, 0, 20), UDim2.fromOffset(38, 86), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Accent
			cockpitPool:Connect(card, card.MouseButton1Click, function()]=]

		source = replaceOnce(source, oldAction, newAction, "open Build Modules from customisation zone")
		source = replaceOnce(source, oldRatingHelpers, newRatingHelpers, "rating parts and tier badge helpers")
		source = replaceOnce(source, oldCardRating, newCardRating, "tier badge card rendering")
		bootstrap.Source = source
		info("Patched customisation cards with tier badges and Build Modules entry.")
	end
end

info("Install complete. Restart Play, open the customisation zone, and verify ratings, tier badges, and Build Modules entry.")
