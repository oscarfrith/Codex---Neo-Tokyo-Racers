-- Neo Tokyo Racers - Dealership / Customisation Split Phase 2
-- Owned-cockpit customisation zone.
--
-- One-file workflow:
-- 1. Run from Roblox Studio Command Bar in Edit mode after Phase 1 is confirmed.
-- 2. Restart Play, walk into the new customisation zone, and verify the owned
--    cockpit menu.
-- 3. Optionally run this same file from the CLIENT Command Bar during Play for
--    a lightweight owned-cockpit/select-action smoke check.
--
-- Scope:
-- - Adds Workspace.NeoTokyoRacersWorld.Dealership.Customisation.CustomisationDeskTrigger.
-- - Installs an isolated CockpitCustomisationZoneClient_Active LocalScript.
-- - Adds a SelectVehicleInstance garage action for choosing an owned vehicle.
-- - Reuses the existing dealership-looking cockpit grid in Customisation mode,
--   filtering the grid to owned cockpits only.
--
-- This uses guarded source replacement against the large active client
-- bootstrap and garage server controller. If an anchor is missing, refresh the
-- Studio mirror before writing another patch.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local PHASE = "Dealership Customisation Split Phase 2"
local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE2_OWNED_ZONE"
local OPEN_EVENT_NAME = "OpenOwnedCockpitCustomisation"
local ZONE_CLIENT_NAME = "CockpitCustomisationZoneClient_Active"

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

local function ensureFolder(parent, name)
	local item = parent:FindFirstChild(name)
	if item and not item:IsA("Folder") then
		error(item:GetFullName() .. " must be a Folder")
	end
	if not item then
		item = Instance.new("Folder")
		item.Name = name
		item.Parent = parent
	end
	return item
end

local function countDictionary(dictionary)
	local count = 0
	for _ in pairs(dictionary or {}) do
		count += 1
	end
	return count
end

local function ownedCockpitCounts(profile)
	local counts = {}
	for _, instance in pairs((profile and profile.OwnedCockpitInstances) or {}) do
		local templateId = tostring(instance.TemplateId or "")
		if templateId ~= "" then
			counts[templateId] = (counts[templateId] or 0) + 1
		end
	end
	for cockpitId, owned in pairs((profile and profile.OwnedCockpits) or {}) do
		if owned == true and (counts[cockpitId] or 0) <= 0 then
			counts[cockpitId] = 1
		end
	end
	return counts
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
	local counts = ownedCockpitCounts(profile)
	local ownedKinds = countDictionary(counts)
	info("Client smoke GetInitial OK. ownedCockpitKinds=" .. tostring(ownedKinds) .. " currentVehicleId=" .. tostring(profile.CurrentVehicleId))

	if ownedKinds > 0 then
		local selectedCockpitId = nil
		for cockpitId in pairs(counts) do
			selectedCockpitId = cockpitId
			break
		end
		local selectResult = invoke:InvokeServer("SelectVehicleInstance", { CockpitId = selectedCockpitId })
		assert(typeof(selectResult) == "table" and selectResult.Success == true, "SelectVehicleInstance failed: " .. tostring(selectResult and selectResult.Message))
		info("SelectVehicleInstance OK for " .. tostring(selectedCockpitId) .. ".")
	else
		info("No owned cockpits yet. Buy one from the dealership, then walk into the customisation zone.")
	end
	return
end

if RunService:IsRunning() then
	runClientSmoke()
	return
end

local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
local dealership = world:WaitForChild("Dealership")
local intro = dealership:FindFirstChild("Intro")
local deskTrigger = intro and intro:FindFirstChild("Desk") and intro.Desk:FindFirstChild("GarageDeskTrigger")
local customisationFolder = ensureFolder(dealership, "Customisation")
local customisationTrigger = customisationFolder:FindFirstChild("CustomisationDeskTrigger")
if customisationTrigger and not customisationTrigger:IsA("BasePart") then
	error(customisationTrigger:GetFullName() .. " must be a BasePart")
end
if not customisationTrigger then
	customisationTrigger = Instance.new("Part")
	customisationTrigger.Name = "CustomisationDeskTrigger"
	customisationTrigger.Size = Vector3.new(10, 6, 10)
	customisationTrigger.Anchored = true
	customisationTrigger.CanCollide = false
	customisationTrigger.CanQuery = false
	customisationTrigger.CanTouch = false
	customisationTrigger.Transparency = 0.55
	customisationTrigger.Material = Enum.Material.Neon
	customisationTrigger.Color = Color3.fromRGB(67, 255, 202)
	if deskTrigger and deskTrigger:IsA("BasePart") then
		customisationTrigger.CFrame = deskTrigger.CFrame * CFrame.new(14, 0, 0)
	else
		customisationTrigger.CFrame = CFrame.new(0, 5, 0)
	end
	customisationTrigger.Parent = customisationFolder
end
customisationTrigger:SetAttribute("ActivationDistance", 12)
customisationTrigger:SetAttribute("Enabled", true)
customisationTrigger:SetAttribute(MARKER, true)
info("Ensured customisation trigger at " .. customisationTrigger:GetFullName() .. ". Move it in Studio if you want a better exact placement.")

local clientRoot = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
local controllers = clientRoot:WaitForChild("Controllers")
local introFolder = ensureFolder(controllers, "Intro")

local zoneClient = introFolder:FindFirstChild(ZONE_CLIENT_NAME)
if zoneClient and not zoneClient:IsA("LocalScript") then
	error(zoneClient:GetFullName() .. " must be a LocalScript")
end
if not zoneClient then
	zoneClient = Instance.new("LocalScript")
	zoneClient.Name = ZONE_CLIENT_NAME
	zoneClient.Parent = introFolder
end

zoneClient.Source = [=[
-- Neo Tokyo Racers - Cockpit Customisation Zone Client
-- Installed by Dealership / Customisation Split Phase 2.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local OPEN_EVENT_NAME = "OpenOwnedCockpitCustomisation"

local function waitForRoot()
	while true do
		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			return root
		end
		task.wait(0.1)
	end
end

local function waitForTrigger()
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local dealership = world:WaitForChild("Dealership")
	local customisation = dealership:WaitForChild("Customisation")
	local trigger = customisation:WaitForChild("CustomisationDeskTrigger")
	if trigger:IsA("BasePart") then
		return trigger
	end
	warn("[NTR Customisation Zone] CustomisationDeskTrigger is not a BasePart.")
	return nil
end

local function openCustomisation()
	local event = script.Parent:FindFirstChild(OPEN_EVENT_NAME)
	if not event then
		event = script.Parent:WaitForChild(OPEN_EVENT_NAME, 5)
	end
	if event and event:IsA("BindableEvent") then
		event:Fire()
	else
		warn("[NTR Customisation Zone] " .. OPEN_EVENT_NAME .. " was not available.")
	end
end

local root = waitForRoot()
local trigger = waitForTrigger()
if not trigger then
	return
end

local wasInside = false
local dismissedUntilLeave = false

while true do
	if not root.Parent then
		root = waitForRoot()
	end
	local enabled = trigger:GetAttribute("Enabled") ~= false
	local activationDistance = tonumber(trigger:GetAttribute("ActivationDistance")) or 12
	local distance = (root.Position - trigger.Position).Magnitude
	local inside = enabled and distance <= activationDistance
	local reopenDistance = math.max(activationDistance + 3, activationDistance * 1.5)

	if dismissedUntilLeave and distance >= reopenDistance then
		dismissedUntilLeave = false
		wasInside = false
	end

	if inside and not wasInside and not dismissedUntilLeave then
		openCustomisation()
		dismissedUntilLeave = true
	end

	wasInside = inside
	task.wait(0.15)
end
]=]
zoneClient:SetAttribute(MARKER, true)
info("Installed isolated " .. zoneClient:GetFullName() .. ".")

local serverScript = ServerScriptService
	:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Services")
	:WaitForChild("Garage")
	:WaitForChild("GarageActionController_Shadow_Disabled")
assert(serverScript:IsA("Script"), "Expected GarageActionController_Shadow_Disabled to be a Script.")

local bootstrap = clientRoot:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

do
	local source = serverScript.Source
	if findPlain(source, MARKER) then
		info("Server SelectVehicleInstance patch already installed.")
	else
		assert(findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY"), "Run and confirm Phase 1 before Phase 2.")
		local selectFunction = [=[

	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE2_OWNED_ZONE
	local function V89_syncLegacyFromCurrentVehicle(profile)
		V84_ensureInstanceInventory(profile)
		local vehicleId = profile.CurrentVehicleId
		local vehicle = vehicleId and profile.Vehicles and profile.Vehicles[vehicleId]
		if typeof(vehicle) ~= "table" then
			return false, "Vehicle instance not found."
		end
		local cockpitInstance = vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
		if typeof(cockpitInstance) ~= "table" then
			return false, "Cockpit instance not found."
		end
		local cockpitId = tostring(cockpitInstance.TemplateId or "")
		if cockpitId == "" then
			return false, "Cockpit template missing."
		end
		profile.CurrentCategory = tostring(vehicle.CategoryId or profile.CurrentCategory or "bruiser")
		profile.CurrentCockpit = cockpitId
		profile.OwnedCockpits = typeof(profile.OwnedCockpits) == "table" and profile.OwnedCockpits or {}
		profile.OwnedCockpits[cockpitId] = true
		profile.CockpitColors = V84_cloneDictionary(vehicle.CockpitColors or profile.CockpitColors or {})
		profile.ThrustColor = vehicle.ThrustColor or profile.ThrustColor
		profile.InstalledModules = {}
		profile.ModuleColors = {}
		profile.NeonOwned = {}
		for slotId, moduleInstanceId in pairs(vehicle.InstalledModules or {}) do
			local moduleInstance = profile.OwnedModuleInstances and profile.OwnedModuleInstances[moduleInstanceId]
			if typeof(moduleInstance) == "table" and moduleInstance.TemplateId then
				profile.InstalledModules[slotId] = tostring(moduleInstance.TemplateId)
				profile.ModuleColors[slotId] = V84_cloneDictionary(moduleInstance.Colors or {})
				profile.NeonOwned[slotId] = moduleInstance.NeonOwned == true
			end
		end
		return true, "Vehicle selected."
	end

	local function V89_selectVehicleInstance(profile, args)
		args = typeof(args) == "table" and args or {}
		V84_ensureInstanceInventory(profile)
		local requestedVehicleId = tostring(args.VehicleId or "")
		local requestedCockpitId = tostring(args.CockpitId or "")
		local selectedVehicleId = nil
		if requestedVehicleId ~= "" and profile.Vehicles[requestedVehicleId] then
			selectedVehicleId = requestedVehicleId
		elseif requestedCockpitId ~= "" then
			for vehicleId, vehicle in pairs(profile.Vehicles or {}) do
				local cockpitInstance = vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
				if typeof(cockpitInstance) == "table" and tostring(cockpitInstance.TemplateId or "") == requestedCockpitId then
					selectedVehicleId = vehicleId
					break
				end
			end
		end
		if not selectedVehicleId then
			return false, "Owned vehicle not found."
		end
		profile.CurrentVehicleId = selectedVehicleId
		local ok, message = V89_syncLegacyFromCurrentVehicle(profile)
		if ok then
			V85_attachDefaultModuleInstancesToCurrentVehicle(profile)
			V89_syncLegacyFromCurrentVehicle(profile)
		end
		return ok, message
	end
]=]
		source = replaceOnce(
			source,
			[=[	end


	-- NTR_PERSISTENCE_PHASE17_TOTAL_STATS_REPAIR]=],
			[=[	end
]=] .. selectFunction .. [=[

	-- NTR_PERSISTENCE_PHASE17_TOTAL_STATS_REPAIR]=],
			"SelectVehicleInstance server helper"
		)
		source = replaceOnce(
			source,
			[=[			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
				V88_syncInstanceDataFromLegacy(profile)
				V80_mirrorLegacyProfileToPersistence(player, profile, action, false)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }
			elseif action == "BuyCockpitInstance" then]=],
			[=[			if action == "GetInitial" then
				V56_setLeaderstats(player, profile)
				V88_syncInstanceDataFromLegacy(profile)
				V80_mirrorLegacyProfileToPersistence(player, profile, action, false)
				return { Success = true, Catalog = V56_catalog(), Profile = V56_profileForClient(profile) }
			elseif action == "SelectVehicleInstance" then
				ok, message = V89_selectVehicleInstance(profile, args)
				V56_setLeaderstats(player, profile)
			elseif action == "BuyCockpitInstance" then]=],
			"SelectVehicleInstance action branch"
		)
		serverScript.Source = source
		info("Patched server action layer with SelectVehicleInstance.")
	end
end

do
	local source = bootstrap.Source
	if findPlain(source, MARKER) then
		info("Client customisation-mode cockpit grid patch already installed.")
	else
		assert(findPlain(source, "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE1_BUY_ONLY"), "Run and confirm Phase 1 before Phase 2.")
		local oldPanel = [=[local function renderDealershipPanel()
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

		local oldShop = [=[renderCockpitShop = function()
	showTop("Dealership", "Choose a vehicle category, then pick a cockpit.")
	updateNav()
	local categoryPool = buttonPool("CategoryList", UI.CategoryList)
	local cockpitPool = buttonPool("CockpitGrid", UI.CockpitGrid)
	categoryPool:Begin()
	cockpitPool:Begin()
	UI.CockpitGrid.CanvasPosition = Vector2.zero
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
			buildPreview()
			renderCockpitShop()
		end)
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

		local oldOpenBlock = [=[local NTR_DEALERSHIP_INTRO_OPEN_EVENT_NAME = "OpenGarageFromIntro"
local NTR_dealershipIntroGarageInitialized = false

local function NTR_openGarageFromDealershipIntro()
	if NTR_dealershipIntroGarageInitialized then
		if UI and UI.Gui then
			UI.Gui.Enabled = true
			if State then
				State.GarageCameraActive = false
				State.NoPreviewYet = true
				State.Phase5PreviewOrbitInitialized = false
			end
			if showStage then
				showStage("CockpitShop")
			else
				UI.CockpitShop.Visible = true
			end
			if renderCockpitShop then
				renderCockpitShop()
			end
		end
		return
	end

	NTR_dealershipIntroGarageInitialized = true
	task.defer(init)
end]=]

		local newOpenBlock = [=[local NTR_DEALERSHIP_INTRO_OPEN_EVENT_NAME = "OpenGarageFromIntro"
local NTR_CUSTOMISATION_OPEN_EVENT_NAME = "OpenOwnedCockpitCustomisation"
local NTR_dealershipIntroGarageInitialized = false

local function NTR_openGarageWithMode(mode)
	State.ShopMode = mode or "Dealership"
	if NTR_dealershipIntroGarageInitialized then
		if UI and UI.Gui then
			UI.Gui.Enabled = true
			if State then
				State.GarageCameraActive = false
				State.NoPreviewYet = true
				State.Phase5PreviewOrbitInitialized = false
			end
			if showStage then
				showStage("CockpitShop")
			else
				UI.CockpitShop.Visible = true
			end
			if renderCockpitShop then
				renderCockpitShop()
			end
		end
		return
	end

	NTR_dealershipIntroGarageInitialized = true
	task.defer(init)
end

local function NTR_openGarageFromDealershipIntro()
	NTR_openGarageWithMode("Dealership")
end

local function NTR_openOwnedCockpitCustomisation()
	NTR_openGarageWithMode("Customisation")
end]=]

		local oldEventRegistration = [=[	openEvent.Event:Connect(NTR_openGarageFromDealershipIntro)
	script:SetAttribute("DealershipIntroGarageGateActive", true)
	script:SetAttribute("DealershipIntroPhase7ReopenGateActive", true)
	print("[NTR Dealership Intro Phase 7] Garage opens at desk and can reopen after exit once the player leaves and re-enters the desk zone.")]=]

		local newEventRegistration = [=[	openEvent.Event:Connect(NTR_openGarageFromDealershipIntro)

	local customisationEvent = introFolder:FindFirstChild(NTR_CUSTOMISATION_OPEN_EVENT_NAME)
	if customisationEvent and not customisationEvent:IsA("BindableEvent") then
		warn("[NTR Dealership Customisation Split Phase 2] " .. customisationEvent:GetFullName() .. " exists but is " .. customisationEvent.ClassName .. ", expected BindableEvent.")
		return
	end
	if not customisationEvent then
		customisationEvent = Instance.new("BindableEvent")
		customisationEvent.Name = NTR_CUSTOMISATION_OPEN_EVENT_NAME
		customisationEvent.Parent = introFolder
	end
	customisationEvent.Event:Connect(NTR_openOwnedCockpitCustomisation)

	script:SetAttribute("DealershipIntroGarageGateActive", true)
	script:SetAttribute("DealershipIntroPhase7ReopenGateActive", true)
	script:SetAttribute("DealershipCustomisationSplitPhase2Active", true)
	print("[NTR Dealership Customisation Split Phase 2] Dealership opens in buy mode; customisation zone opens owned-cockpit mode.")]=]

		source = replaceOnce(source, oldPanel, newPanel, "customisation-mode dealership panel")
		source = replaceOnce(source, oldShop, newShop, "customisation-mode cockpit grid")
		source = replaceOnce(source, oldOpenBlock, newOpenBlock, "customisation mode open hook")
		source = replaceOnce(source, oldEventRegistration, newEventRegistration, "customisation open event registration")
		bootstrap.Source = source
		info("Patched client bootstrap for owned-cockpit customisation mode.")
	end
end

info("Install complete. Restart Play, buy/own a cockpit, then walk into Dealership.Customisation.CustomisationDeskTrigger to open the owned-cockpit customisation menu.")
