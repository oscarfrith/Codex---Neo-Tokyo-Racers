-- Neo Tokyo Racers - Dealership / Customisation Split Phase 3
-- Separate owned cockpit instance cards with rating labels.
--
-- One-file workflow:
-- 1. Run from Roblox Studio Command Bar in Edit mode after Phase 2 is confirmed.
-- 2. Restart Play, own two copies of the same cockpit, and open the customisation
--    zone to verify they appear as separate cards.
-- 3. Optionally run this same file from the CLIENT Command Bar during Play for
--    a lightweight VehicleSummaries smoke check.
--
-- Scope:
-- - Adds per-owned-vehicle summaries to the profile response.
-- - Changes customisation mode to render one card per owned vehicle instance.
-- - Removes the aggregated "Owned xN" card text in customisation mode.
-- - Shows each instance's tier and performance index, for example "A 920".
-- - Uses VehicleId when opening customisation so duplicate cockpits are distinct.
--
-- This uses guarded source replacement against the large active client
-- bootstrap and garage server controller. If an anchor is missing, refresh the
-- Studio mirror before writing another patch.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local PHASE = "Dealership Customisation Split Phase 3"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_INSTANCE_CARDS"

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
	local profile = result.Profile or {}
	local vehicleCount = countDictionary(profile.Vehicles)
	local summaryCount = countDictionary(profile.VehicleSummaries)
	info("Client smoke GetInitial OK. vehicles=" .. tostring(vehicleCount) .. " vehicleSummaries=" .. tostring(summaryCount))
	assert(summaryCount >= math.min(vehicleCount, 1), "Expected VehicleSummaries for owned vehicles.")
	for vehicleId, summary in pairs(profile.VehicleSummaries or {}) do
		local overall = summary.Overall or {}
		info("Vehicle " .. tostring(vehicleId) .. " cockpit=" .. tostring(summary.CockpitId) .. " rating=" .. tostring(overall.Tier or "--") .. " " .. tostring(overall.PerformanceIndex or "---"))
	end
	return
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
		info("Server VehicleSummaries patch already installed.")
	else
		assert(findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE2_OWNED_ZONE"), "Run and confirm Phase 2 before Phase 3.")
		local oldSelectTail = [=[		local ok, message = V89_syncLegacyFromCurrentVehicle(profile)
		if ok then
			V85_attachDefaultModuleInstancesToCurrentVehicle(profile)
			V89_syncLegacyFromCurrentVehicle(profile)
		end
		return ok, message
	end
]=]
		local newSelectTail = oldSelectTail .. [=[

	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_INSTANCE_CARDS
	local function V90_cloneForSummary(value)
		if typeof(value) == "table" then
			local copy = {}
			for key, child in pairs(value) do
				copy[key] = V90_cloneForSummary(child)
			end
			return copy
		end
		return value
	end

	local function V90_restoreProfileSelection(profile, snapshot)
		profile.CurrentVehicleId = snapshot.CurrentVehicleId
		profile.CurrentCategory = snapshot.CurrentCategory
		profile.CurrentCockpit = snapshot.CurrentCockpit
		profile.CockpitColors = V90_cloneForSummary(snapshot.CockpitColors)
		profile.ThrustColor = snapshot.ThrustColor
		profile.InstalledModules = V90_cloneForSummary(snapshot.InstalledModules)
		profile.ModuleColors = V90_cloneForSummary(snapshot.ModuleColors)
		profile.NeonOwned = V90_cloneForSummary(snapshot.NeonOwned)
	end

	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_SUMMARY_REPAIR
	local function V90_numberAttribute(instance, name, fallback)
		local value = instance and instance:GetAttribute(name)
		return typeof(value) == "number" and value or fallback
	end

	local function V90_addModuleStats(totals, module)
		if not module then return totals end
		for _, name in ipairs({ "TopSpeed", "Acceleration", "Handling", "Drift", "Braking", "Weight", "Boost", "BoostForce", "EngineOutput", "LateralGrip", "SteeringResponse", "HoverStability", "DriftControl", "DriftGrip", "DriftChargeRate", "BrakingForce", "BoostDuration", "BoostRecharge", "BoostRechargeDelay", "BoostEfficiency", "Drag", "Downforce" }) do
			local value = module:GetAttribute(name)
			if typeof(value) == "number" then
				totals[name] = (totals[name] or 0) + value
			end
			local delta = module:GetAttribute("PerformanceDelta_" .. name)
			if typeof(delta) == "number" then
				totals[name] = (totals[name] or 0) + delta
			end
		end
		return totals
	end

	local function V90_summaryTotals(profile)
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
	end

	local function V90_vehicleSummaries(profile)
		V84_ensureInstanceInventory(profile)
		local snapshot = {
			CurrentVehicleId = profile.CurrentVehicleId,
			CurrentCategory = profile.CurrentCategory,
			CurrentCockpit = profile.CurrentCockpit,
			CockpitColors = V90_cloneForSummary(profile.CockpitColors or {}),
			ThrustColor = profile.ThrustColor,
			InstalledModules = V90_cloneForSummary(profile.InstalledModules or {}),
			ModuleColors = V90_cloneForSummary(profile.ModuleColors or {}),
			NeonOwned = V90_cloneForSummary(profile.NeonOwned or {}),
		}
		local summaries = {}
		for vehicleId, vehicle in pairs(profile.Vehicles or {}) do
			if typeof(vehicle) == "table" then
				profile.CurrentVehicleId = vehicleId
				local ok = V89_syncLegacyFromCurrentVehicle(profile)
				if ok then
					local cockpit = V56_findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
					local performance = V77_ModuleUpgrades.CalculateProfile(
						profile._Player,
						profile,
						V90_summaryTotals(profile),
						cockpit,
						V56_findModule,
						V56_moduleTypeForModel
					)
					summaries[vehicleId] = {
						VehicleId = vehicleId,
						CockpitId = profile.CurrentCockpit,
						DisplayName = vehicle.DisplayName or profile.CurrentCockpit,
						Overall = performance and performance.Overall or nil,
					}
				end
			end
		end
		V90_restoreProfileSelection(profile, snapshot)
		return summaries
	end
]=]
		source = replaceOnce(source, oldSelectTail, newSelectTail, "VehicleSummaries helper")
		source = replaceOnce(
			source,
			[=[			OwnedModuleInstances = profile.OwnedModuleInstances,
			OwnedCockpits = profile.OwnedCockpits,]=],
			[=[			OwnedModuleInstances = profile.OwnedModuleInstances,
			VehicleSummaries = V90_vehicleSummaries(profile),
			OwnedCockpits = profile.OwnedCockpits,]=],
			"VehicleSummaries profile response"
		)
		serverScript.Source = source
		info("Patched server profile response with per-vehicle summaries.")
	end
end

do
	local source = bootstrap.Source
	if findPlain(source, MARKER) then
		info("Client owned instance card patch already installed.")
	else
		assert(findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE2_OWNED_ZONE"), "Run and confirm Phase 2 before Phase 3.")

		local oldPanel = [=[local function renderDealershipPanel()
	if not UI.StatsPanel then return end
	applyDealershipLayout()
	clear(UI.StatsPanel)
	local cockpit = getCockpit(State.SelectedCockpit) or {}
	local customisationMode = State.ShopMode == "Customisation"
	NTRVehiclePhaseAO.renderStats(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))
	-- NTR_DEALERSHIP_MODULE_SLOTS_TEXT_REMOVED
	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY
	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE2_OWNED_ZONE
	local owned = State.Profile and State.Profile.OwnedCockpits and State.Profile.OwnedCockpits[State.SelectedCockpit]
	local copyCount = NTRPersistencePhase15.CountCockpitCopies(State.Profile, State.SelectedCockpit)
	if customisationMode and copyCount <= 0 then
		label(UI.StatsPanel, "No owned cockpits yet.", UDim2.new(1, -12, 0, 44), UDim2.new(0, 6, 1, UserInputService.TouchEnabled and -92 or -110), 12, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
		return
	end
	if owned or customisationMode then
		local copyText = label(UI.StatsPanel, "Owned copies: " .. tostring(copyCount), UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -104 or -116), 10, Enum.TextXAlignment.Center)
		copyText.TextColor3 = Theme.Muted
	end
	if customisationMode then
		local customiseButton = button(UI.StatsPanel, "Customise", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)
		customiseButton.MouseButton1Click:Connect(function()
			local result = callServer("SelectVehicleInstance", { CockpitId = State.SelectedCockpit })
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
		end)
		return
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

		local newPanel = [=[local function renderDealershipPanel()
	if not UI.StatsPanel then return end
	applyDealershipLayout()
	clear(UI.StatsPanel)
	local cockpit = getCockpit(State.SelectedCockpit) or {}
	local customisationMode = State.ShopMode == "Customisation"
	NTRVehiclePhaseAO.renderStats(UI.StatsPanel, NTRVehiclePhaseAK.dealershipStatsWithIncludedDefaults(cockpit))
	-- NTR_DEALERSHIP_MODULE_SLOTS_TEXT_REMOVED
	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY
	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE2_OWNED_ZONE
	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_INSTANCE_CARDS
	local owned = State.Profile and State.Profile.OwnedCockpits and State.Profile.OwnedCockpits[State.SelectedCockpit]
	if customisationMode then
		if not State.SelectedVehicleId then
			label(UI.StatsPanel, "No owned cockpits yet.", UDim2.new(1, -12, 0, 44), UDim2.new(0, 6, 1, UserInputService.TouchEnabled and -92 or -110), 12, Enum.TextXAlignment.Center).TextColor3 = Theme.Muted
			return
		end
		local summary = State.Profile and State.Profile.VehicleSummaries and State.Profile.VehicleSummaries[State.SelectedVehicleId]
		local overall = summary and summary.Overall or {}
		local ratingIndex = tonumber(overall.PerformanceIndex)
		local rating = tostring(overall.Tier or "--") .. " " .. (ratingIndex and tostring(math.floor(ratingIndex)) or "---")
		local ratingText = label(UI.StatsPanel, rating, UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -104 or -116), 14, Enum.TextXAlignment.Center)
		ratingText.TextColor3 = Theme.Accent
		local customiseButton = button(UI.StatsPanel, "Customise", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)
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
		end)
		return
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

		local oldShop = [=[renderCockpitShop = function()
	local customisationMode = State.ShopMode == "Customisation"
	showTop(customisationMode and "Customisation" or "Dealership", customisationMode and "Choose one of your owned cockpits to customise." or "Choose a vehicle category, then pick a cockpit.")
	updateNav()
	local categoryPool = buttonPool("CategoryList", UI.CategoryList)
	local cockpitPool = buttonPool("CockpitGrid", UI.CockpitGrid)
	categoryPool:Begin()
	cockpitPool:Begin()
	UI.CockpitGrid.CanvasPosition = Vector2.zero

	if customisationMode and NTRPersistencePhase15.CountCockpitCopies(State.Profile, State.SelectedCockpit) <= 0 then
		for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do
			for _, cockpit in ipairs(category.Cockpits or {}) do
				if NTRPersistencePhase15.CountCockpitCopies(State.Profile, cockpit.CockpitId) > 0 then
					State.CategoryId = category.CategoryId
					State.SelectedCockpit = cockpit.CockpitId
					break
				end
			end
			if NTRPersistencePhase15.CountCockpitCopies(State.Profile, State.SelectedCockpit) > 0 then
				break
			end
		end
	end

	applyDealershipLayout()
	renderDealershipPanel()

	for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do
		local b = pooledButton(categoryPool, category.DisplayName or category.CategoryId, UDim2.new(1, 0, 0, 54), UDim2.fromScale(0, 0), category.CategoryId == State.CategoryId and Theme.CardHot or Theme.Card)
		categoryPool:Connect(b, b.MouseButton1Click, function()
			State.CategoryId = category.CategoryId
			renderCockpitShop()
		end)
	end

	local category = getCategory()
	for _, cockpit in ipairs((category and category.Cockpits) or {}) do
		local copyCount = NTRPersistencePhase15.CountCockpitCopies(State.Profile, cockpit.CockpitId)
		if not customisationMode or copyCount > 0 then
			local card = pooledButton(cockpitPool, "", UDim2.fromOffset(118, 118), UDim2.fromScale(0, 0), cockpit.CockpitId == State.SelectedCockpit and Theme.CardHot or Theme.Card)
			local icon = new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 27, 31), Size = UDim2.new(1, -18, 0, 42), Position = UDim2.fromOffset(9, 9), BorderSizePixel = 0 }, card)
			icon:SetAttribute("PooledDynamic", true)
			corner(icon, 4)
			stroke(icon, Theme.Accent, 0.75, 1)
			local carShape = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromOffset(72, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55) }, icon)
			corner(carShape, 3)
			pooledLabel(card, cockpit.DisplayName or cockpit.CockpitId, UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 55), 9, Enum.TextXAlignment.Left)
			local bottomText = customisationMode and ("Owned x" .. tostring(copyCount)) or ("$" .. tostring(cockpit.Price or 0))
			pooledLabel(card, bottomText, UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 86), 9, Enum.TextXAlignment.Left).TextColor3 = customisationMode and Theme.Accent or Theme.Cash
			cockpitPool:Connect(card, card.MouseButton1Click, function()
				State.SelectedCockpit = cockpit.CockpitId
				buildPreview()
				renderCockpitShop()
			end)
		end
	end
	categoryPool:End()
	cockpitPool:End()
	applyDealershipLayout()
end]=]

		local newShop = [=[renderCockpitShop = function()
	local customisationMode = State.ShopMode == "Customisation"
	showTop(customisationMode and "Customisation" or "Dealership", customisationMode and "Choose one of your owned cockpits to customise." or "Choose a vehicle category, then pick a cockpit.")
	updateNav()
	local categoryPool = buttonPool("CategoryList", UI.CategoryList)
	local cockpitPool = buttonPool("CockpitGrid", UI.CockpitGrid)
	categoryPool:Begin()
	cockpitPool:Begin()
	UI.CockpitGrid.CanvasPosition = Vector2.zero

	local function cockpitIdForVehicle(vehicle)
		local cockpitInstance = vehicle and vehicle.CockpitInstanceId and State.Profile and State.Profile.OwnedCockpitInstances and State.Profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		return cockpitInstance and tostring(cockpitInstance.TemplateId or "") or ""
	end

	local function vehicleRating(vehicleId)
		local summary = State.Profile and State.Profile.VehicleSummaries and State.Profile.VehicleSummaries[vehicleId]
		local overall = summary and summary.Overall or {}
		local tier = tostring(overall.Tier or "--")
		local index = tonumber(overall.PerformanceIndex)
		return tier .. " " .. (index and tostring(math.floor(index)) or "---")
	end

	local function cockpitInCategory(category, cockpitId)
		for _, cockpit in ipairs((category and category.Cockpits) or {}) do
			if cockpit.CockpitId == cockpitId then
				return cockpit
			end
		end
		return nil
	end

	if customisationMode then
		local selectedVehicle = State.SelectedVehicleId and State.Profile and State.Profile.Vehicles and State.Profile.Vehicles[State.SelectedVehicleId]
		if not selectedVehicle then
			State.SelectedVehicleId = State.Profile and State.Profile.CurrentVehicleId or nil
		end
		local currentCategory = getCategory()
		local selectedInCategory = false
		if State.SelectedVehicleId and currentCategory then
			local vehicle = State.Profile and State.Profile.Vehicles and State.Profile.Vehicles[State.SelectedVehicleId]
			selectedInCategory = cockpitInCategory(currentCategory, cockpitIdForVehicle(vehicle)) ~= nil
		end
		if not selectedInCategory then
			State.SelectedVehicleId = nil
			for vehicleId, vehicle in pairs((State.Profile and State.Profile.Vehicles) or {}) do
				local cockpitId = cockpitIdForVehicle(vehicle)
				if cockpitInCategory(currentCategory, cockpitId) then
					State.SelectedVehicleId = vehicleId
					State.SelectedCockpit = cockpitId
					break
				end
			end
		else
			State.SelectedCockpit = cockpitIdForVehicle(State.Profile.Vehicles[State.SelectedVehicleId])
		end
	end

	applyDealershipLayout()
	renderDealershipPanel()

	for _, category in ipairs((State.Catalog and State.Catalog.Categories) or {}) do
		local b = pooledButton(categoryPool, category.DisplayName or category.CategoryId, UDim2.new(1, 0, 0, 54), UDim2.fromScale(0, 0), category.CategoryId == State.CategoryId and Theme.CardHot or Theme.Card)
		categoryPool:Connect(b, b.MouseButton1Click, function()
			State.CategoryId = category.CategoryId
			State.SelectedVehicleId = nil
			renderCockpitShop()
		end)
	end

	local category = getCategory()
	if customisationMode then
		local rows = {}
		for vehicleId, vehicle in pairs((State.Profile and State.Profile.Vehicles) or {}) do
			local cockpitId = cockpitIdForVehicle(vehicle)
			local cockpit = cockpitInCategory(category, cockpitId)
			if cockpit then
				table.insert(rows, { VehicleId = vehicleId, Vehicle = vehicle, Cockpit = cockpit, CockpitId = cockpitId })
			end
		end
		table.sort(rows, function(a, b)
			local aName = tostring((a.Cockpit and a.Cockpit.DisplayName) or a.CockpitId or "")
			local bName = tostring((b.Cockpit and b.Cockpit.DisplayName) or b.CockpitId or "")
			if aName == bName then return tostring(a.VehicleId) < tostring(b.VehicleId) end
			return aName < bName
		end)
		for index, row in ipairs(rows) do
			local card = pooledButton(cockpitPool, "", UDim2.fromOffset(118, 118), UDim2.fromScale(0, 0), row.VehicleId == State.SelectedVehicleId and Theme.CardHot or Theme.Card)
			local icon = new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 27, 31), Size = UDim2.new(1, -18, 0, 42), Position = UDim2.fromOffset(9, 9), BorderSizePixel = 0 }, card)
			icon:SetAttribute("PooledDynamic", true)
			corner(icon, 4)
			stroke(icon, Theme.Accent, 0.75, 1)
			local carShape = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromOffset(72, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55) }, icon)
			corner(carShape, 3)
			local nameText = tostring(row.Cockpit.DisplayName or row.CockpitId) .. " #" .. tostring(index)
			pooledLabel(card, nameText, UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 55), 9, Enum.TextXAlignment.Left)
			pooledLabel(card, vehicleRating(row.VehicleId), UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 86), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Accent
			cockpitPool:Connect(card, card.MouseButton1Click, function()
				State.SelectedVehicleId = row.VehicleId
				State.SelectedCockpit = row.CockpitId
				buildPreview()
				renderCockpitShop()
			end)
		end
	else
		for _, cockpit in ipairs((category and category.Cockpits) or {}) do
			local card = pooledButton(cockpitPool, "", UDim2.fromOffset(118, 118), UDim2.fromScale(0, 0), cockpit.CockpitId == State.SelectedCockpit and Theme.CardHot or Theme.Card)
			local icon = new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 27, 31), Size = UDim2.new(1, -18, 0, 42), Position = UDim2.fromOffset(9, 9), BorderSizePixel = 0 }, card)
			icon:SetAttribute("PooledDynamic", true)
			corner(icon, 4)
			stroke(icon, Theme.Accent, 0.75, 1)
			local carShape = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromOffset(72, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55) }, icon)
			corner(carShape, 3)
			pooledLabel(card, cockpit.DisplayName or cockpit.CockpitId, UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 55), 9, Enum.TextXAlignment.Left)
			pooledLabel(card, "$" .. tostring(cockpit.Price or 0), UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 86), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Cash
			cockpitPool:Connect(card, card.MouseButton1Click, function()
				State.SelectedCockpit = cockpit.CockpitId
				State.SelectedVehicleId = nil
				buildPreview()
				renderCockpitShop()
			end)
		end
	end
	categoryPool:End()
	cockpitPool:End()
	applyDealershipLayout()
end]=]

		source = replaceOnce(source, oldPanel, newPanel, "instance-card customisation panel")
		source = replaceOnce(source, oldShop, newShop, "instance-card customisation grid")
		bootstrap.Source = source
		info("Patched customisation mode to show one card per owned vehicle instance.")
	end
end

info("Install complete. Restart Play, open the customisation zone, and verify duplicate cockpits appear as separate rating-labelled cards.")
