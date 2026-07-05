-- Neo Tokyo Racers - Dealership / Customisation Split Phase 1
-- Buy-only dealership foundation.
--
-- One-file workflow:
-- 1. Run from Roblox Studio Command Bar in Edit mode to install.
-- 2. Restart Play, reach the dealership desk, and verify the UI manually.
-- 3. Optionally run this same file from the CLIENT Command Bar during Play for
--    a lightweight catalog/profile smoke check.
--
-- Scope:
-- - Sets the starter Bruiser cockpit price to 15000.
-- - Stops fresh session profiles from owning bruiser_01 by default.
-- - Changes the dealership cockpit action to one buy button:
--   "Buy $..." for unowned cockpits, "Buy Another $..." for owned cockpits.
-- - Keeps existing players' saved/legacy cockpit ownership intact.
-- - Does not add the separate customisation zone yet.
--
-- This uses guarded source replacement against the large active client
-- bootstrap and garage server controller. If an anchor is missing, refresh the
-- Studio mirror before writing another patch.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local PHASE = "Dealership Customisation Split Phase 1"
local STARTER_COCKPIT_ID = "bruiser_01"
local STARTER_COCKPIT_PRICE = 15000
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another dealership/customisation split patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Aborting.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before), true
end

local function countDictionary(dictionary)
	local count = 0
	for _ in pairs(dictionary or {}) do
		count += 1
	end
	return count
end

local function findStarterCockpit()
	local ntr = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local vehicles = ntr:WaitForChild("Assets"):WaitForChild("Vehicles")
	local categories = vehicles:WaitForChild("Categories")
	for _, item in ipairs(categories:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("CockpitId") == STARTER_COCKPIT_ID then
			return item
		end
	end
	return nil
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

	local starterPrice = nil
	for _, category in ipairs((result.Catalog and result.Catalog.Categories) or {}) do
		for _, cockpit in ipairs(category.Cockpits or {}) do
			if cockpit.CockpitId == STARTER_COCKPIT_ID then
				starterPrice = tonumber(cockpit.Price)
			end
		end
	end
	assert(starterPrice == STARTER_COCKPIT_PRICE, "Expected " .. STARTER_COCKPIT_ID .. " price " .. tostring(STARTER_COCKPIT_PRICE) .. ", got " .. tostring(starterPrice))

	local profile = result.Profile or {}
	local owned = profile.OwnedCockpits and profile.OwnedCockpits[STARTER_COCKPIT_ID] == true
	local vehicleCount = countDictionary(profile.Vehicles)
	local cockpitInstanceCount = countDictionary(profile.OwnedCockpitInstances)

	info("Client smoke GetInitial OK.")
	info(STARTER_COCKPIT_ID .. " catalog price=" .. tostring(starterPrice) .. "; owned=" .. tostring(owned) .. "; vehicles=" .. tostring(vehicleCount) .. "; cockpitInstances=" .. tostring(cockpitInstanceCount))
	if owned then
		info("This player already owns the starter cockpit, so the dealership should show Buy Another, not Select.")
	else
		info("This player does not own the starter cockpit, so the dealership should show Buy $" .. tostring(STARTER_COCKPIT_PRICE) .. ".")
	end
	return
end

if RunService:IsRunning() then
	runClientSmoke()
	return
end

local starterCockpit = findStarterCockpit()
assert(starterCockpit, "Could not find starter cockpit model with CockpitId=" .. STARTER_COCKPIT_ID)
local oldPrice = starterCockpit:GetAttribute("Price")
starterCockpit:SetAttribute("Price", STARTER_COCKPIT_PRICE)
starterCockpit:SetAttribute(MARKER, true)
info("Set " .. starterCockpit:GetFullName() .. ".Price from " .. tostring(oldPrice) .. " to " .. tostring(STARTER_COCKPIT_PRICE) .. ".")

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
		info("Server profile starter-ownership patch already installed.")
	else
		assert(findPlain(source, "BuyCockpitInstance"), "Expected Phase 14 BuyCockpitInstance support before installing Phase 1.")
		source = replaceOnce(
			source,
			[=[			OwnedCockpits = { bruiser_01 = true },]=],
			[=[			OwnedCockpits = {}, -- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY]=],
			"default profile starter ownership"
		)
		source = replaceOnce(
			source,
			[=[		profile.OwnedCockpits = profile.OwnedCockpits or { bruiser_01 = true }]=],
			[=[		profile.OwnedCockpits = profile.OwnedCockpits or {} -- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY]=],
			"normalize profile starter ownership"
		)
		serverScript.Source = source
		info("Patched fresh session profiles so the starter cockpit is no longer granted for free.")
	end
end

do
	local source = bootstrap.Source
	if findPlain(source, MARKER) then
		info("Client buy-only dealership panel patch already installed.")
	else
		assert(findPlain(source, "NTR_PERSISTENCE_PHASE15_DUPLICATE_COPY_UI"), "Expected Phase 15 duplicate-copy UI baseline before installing Phase 1.")
		local oldPanel = [=[local function renderDealershipPanel()
	if not UI.StatsPanel then return end
	applyDealershipLayout()
	clear(UI.StatsPanel)
	local cockpit = getCockpit(State.SelectedCockpit) or {}
	NTRVehiclePhaseAO.renderStats(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))
	-- NTR_DEALERSHIP_MODULE_SLOTS_TEXT_REMOVED
	local owned = State.Profile and State.Profile.OwnedCockpits and State.Profile.OwnedCockpits[State.SelectedCockpit]
	local copyCount = NTRPersistencePhase15.CountCockpitCopies(State.Profile, State.SelectedCockpit)
	if owned then
		local copyText = label(UI.StatsPanel, "Owned copies: " .. tostring(copyCount), UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -132 or -142), 10, Enum.TextXAlignment.Center)
		copyText.TextColor3 = Theme.Muted
	end
	local text = owned and "Select" or ("Buy $" .. tostring(cockpit.Price or 0))
	local selectHeight = owned and (UserInputService.TouchEnabled and 42 or 46) or (UserInputService.TouchEnabled and 58 or 76)
	local selectY = owned and (UserInputService.TouchEnabled and -104 or -112) or (UserInputService.TouchEnabled and -70 or -88)
	local selectButton = button(UI.StatsPanel, text, UDim2.new(1, 0, 0, selectHeight), UDim2.new(0, 0, 1, selectY), owned and Theme.CardHot or Theme.Buy)
	selectButton.MouseButton1Click:Connect(function()
		local result = callServer("BuyCockpit", { CockpitId = State.SelectedCockpit })
		if result.Success then
			NTR_phase4UnlockPreviewAfterPurchase()
			-- NTR_VEHICLE_PHASE_AK_COCKPIT_PAINT_CAMERA_REPAIR
			setCameraSection("Engine1")
			showStage("CockpitPaint")
			renderCockpitPaint()
		else
			UI.Subtitle.Text = result.Message or "Could not buy cockpit."
		end
	end)
	if owned then
		local buyAnother = button(UI.StatsPanel, "Buy Another $" .. tostring(cockpit.Price or 0), UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 42 or 46), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -54 or -56), Theme.Buy)
		buyAnother.MouseButton1Click:Connect(function()
			local result = callServer("BuyCockpitInstance", { CockpitId = State.SelectedCockpit })
			if result.Success then
				NTR_phase4UnlockPreviewAfterPurchase()
				UI.Subtitle.Text = "Bought another " .. tostring(cockpit.DisplayName or "cockpit") .. "."
				setCameraSection("Engine1")
				showStage("CockpitPaint")
				renderCockpitPaint()
			else
				UI.Subtitle.Text = result.Message or "Could not buy another cockpit."
				renderDealershipPanel()
			end
		end)
	end
end]=]

		local newPanel = [=[local function renderDealershipPanel()
	if not UI.StatsPanel then return end
	applyDealershipLayout()
	clear(UI.StatsPanel)
	local cockpit = getCockpit(State.SelectedCockpit) or {}
	NTRVehiclePhaseAO.renderStats(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))
	-- NTR_DEALERSHIP_MODULE_SLOTS_TEXT_REMOVED
	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY
	local owned = State.Profile and State.Profile.OwnedCockpits and State.Profile.OwnedCockpits[State.SelectedCockpit]
	local copyCount = NTRPersistencePhase15.CountCockpitCopies(State.Profile, State.SelectedCockpit)
	if owned then
		local copyText = label(UI.StatsPanel, "Owned copies: " .. tostring(copyCount), UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -104 or -116), 10, Enum.TextXAlignment.Center)
		copyText.TextColor3 = Theme.Muted
	end
	local actionText = (owned and "Buy Another $" or "Buy $") .. tostring(cockpit.Price or 0)
	local actionButton = button(UI.StatsPanel, actionText, UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)
	actionButton.MouseButton1Click:Connect(function()
		local result = callServer("BuyCockpitInstance", { CockpitId = State.SelectedCockpit })
		if result.Success then
			NTR_phase4UnlockPreviewAfterPurchase()
			if owned then
				UI.Subtitle.Text = "Bought another " .. tostring(cockpit.DisplayName or "cockpit") .. "."
			end
			setCameraSection("Engine1")
			showStage("CockpitPaint")
			renderCockpitPaint()
		else
			UI.Subtitle.Text = result.Message or (owned and "Could not buy another cockpit." or "Could not buy cockpit.")
			renderDealershipPanel()
		end
	end)
end]=]

		source = replaceOnce(source, oldPanel, newPanel, "buy-only dealership panel")
		bootstrap.Source = source
		info("Patched dealership cockpit panel to remove Select and use Buy / Buy Another only.")
	end
end

info("Install complete. Restart Play, enter the dealership desk, then verify the right panel shows Buy or Buy Another and never Select.")
