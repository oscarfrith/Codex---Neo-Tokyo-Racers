-- Neo Tokyo Racers - Persistence Phase 8
-- Adds a compact garage-capacity panel and upgrade button to the live garage UI.
--
-- Run from Roblox Studio Command Bar in Edit mode or Play mode.
-- This is a guarded exact-source patch against the active client bootstrap.

local StarterPlayer = game:GetService("StarterPlayer")

local function assertChild(parent, name)
	local child = parent:FindFirstChild(name)
	assert(child, "Missing " .. parent:GetFullName() .. "." .. name)
	return child
end

local scriptsFolder = assertChild(StarterPlayer, "StarterPlayerScripts")
local clientRoot = assertChild(scriptsFolder, "NeoTokyoRacersClient")
local bootstrap = assertChild(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(not source:find("NTR_PERSISTENCE_PHASE8_CAPACITY_UI_BEGIN", 1, true), "Persistence Phase 8 capacity UI is already installed.")

local function replaceOnce(haystack, needle, replacement, label)
	local found = haystack:find(needle, 1, true)
	assert(found, "Phase 8 preflight failed. Could not find source anchor: " .. label)
	local updated, count = haystack:gsub(needle:gsub("([^%w])", "%%%1"), replacement, 1)
	assert(count == 1, "Phase 8 preflight failed. Anchor was not unique: " .. label)
	return updated
end

local helperAnchor = [[local function showTop(title, subtitle)
	UI.Title.Text = string.upper(title or "NEON HOVER RACING")
	UI.Subtitle.Text = subtitle or ""
	UI.Cash.Text = "$" .. tostring((State.Profile and State.Profile.Cash) or 0)
end]]

local helperReplacement = [[-- NTR_PERSISTENCE_PHASE8_CAPACITY_UI_BEGIN
local function NTR_phase8GarageCapacitySummary()
	local profile = State.Profile or {}
	local garage = profile.Garage or {}
	local capacity = tonumber(garage.Capacity) or tonumber(profile.GarageCapacity) or 2
	local maxCapacity = tonumber(garage.MaxCapacity) or capacity
	local ownedCount = tonumber(garage.OwnedVehicleCount)

	if not ownedCount then
		ownedCount = 0
		for _, owned in pairs(profile.OwnedCockpits or {}) do
			if owned == true then ownedCount += 1 end
		end
	end

	return ownedCount, capacity, maxCapacity, tonumber(garage.NextCapacityUpgradePrice)
end

local function NTR_phase8RenderGarageCapacityPanel()
	if not UI.GarageCapacityPanel then return end
	local ownedCount, capacity, maxCapacity, nextPrice = NTR_phase8GarageCapacitySummary()

	UI.GarageCapacityCount.Text = tostring(ownedCount) .. "/" .. tostring(capacity) .. " spaces"

	if capacity >= maxCapacity then
		UI.GarageCapacityPrice.Text = "Max garage size"
		UI.GarageCapacityUpgradeButton.Text = "MAXED"
		UI.GarageCapacityUpgradeButton.AutoButtonColor = false
		UI.GarageCapacityUpgradeButton.BackgroundColor3 = Theme.Disabled
	elseif nextPrice then
		UI.GarageCapacityPrice.Text = "Next: $" .. tostring(nextPrice)
		UI.GarageCapacityUpgradeButton.Text = "UPGRADE"
		UI.GarageCapacityUpgradeButton.AutoButtonColor = true
		UI.GarageCapacityUpgradeButton.BackgroundColor3 = Theme.Buy
	else
		UI.GarageCapacityPrice.Text = "Upgrade available soon"
		UI.GarageCapacityUpgradeButton.Text = "UPGRADE"
		UI.GarageCapacityUpgradeButton.AutoButtonColor = true
		UI.GarageCapacityUpgradeButton.BackgroundColor3 = Theme.Buy
	end
end
-- NTR_PERSISTENCE_PHASE8_CAPACITY_UI_END

local function showTop(title, subtitle)
	UI.Title.Text = string.upper(title or "NEON HOVER RACING")
	UI.Subtitle.Text = subtitle or ""
	UI.Cash.Text = "$" .. tostring((State.Profile and State.Profile.Cash) or 0)
	NTR_phase8RenderGarageCapacityPanel()
end]]

source = replaceOnce(source, helperAnchor, helperReplacement, "showTop helper block")

local uiAnchor = [[	local getMore = button(UI.CashPanel, "Get More", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 70), Theme.CardHot)
	getMore.MouseButton1Click:Connect(showCashShop)

	UI.NextPanel = panel(gui, "NextPinnedBottomRight", UDim2.fromOffset(178, BOTTOM_HEIGHT), UDim2.new(1, -18, 1, -BOTTOM_MARGIN), Vector2.new(1, 1))]]

local uiReplacement = [[	local getMore = button(UI.CashPanel, "Get More", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 70), Theme.CardHot)
	getMore.MouseButton1Click:Connect(showCashShop)

	-- NTR_PERSISTENCE_PHASE8_CAPACITY_PANEL_BEGIN
	UI.GarageCapacityPanel = panel(gui, "GarageCapacityPinnedLeft", UDim2.fromOffset(190, 112), UDim2.new(0, 18, 1, -BOTTOM_MARGIN - BOTTOM_HEIGHT - 12), Vector2.new(0, 1))
	label(UI.GarageCapacityPanel, "Garage Spaces", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 6), 10, Enum.TextXAlignment.Center)
	UI.GarageCapacityCount = label(UI.GarageCapacityPanel, "0/2 spaces", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 28), 17, Enum.TextXAlignment.Center)
	UI.GarageCapacityCount.Name = "GarageCapacityCount"
	UI.GarageCapacityCount.TextColor3 = Theme.Accent
	UI.GarageCapacityPrice = label(UI.GarageCapacityPanel, "Next: $0", UDim2.new(1, -16, 0, 20), UDim2.fromOffset(8, 55), 10, Enum.TextXAlignment.Center)
	UI.GarageCapacityPrice.Name = "GarageCapacityPrice"
	UI.GarageCapacityPrice.TextColor3 = Theme.Cash
	UI.GarageCapacityUpgradeButton = button(UI.GarageCapacityPanel, "Upgrade", UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 78), Theme.Buy)
	UI.GarageCapacityUpgradeButton.Name = "GarageCapacityUpgradeButton"
	UI.GarageCapacityUpgradeButton.MouseButton1Click:Connect(function()
		local result = callServer("UpgradeGarageCapacity", {})
		if result.Success then
			NTR_phase8RenderGarageCapacityPanel()
			UI.Subtitle.Text = result.Message or "Garage capacity upgraded."
		else
			NTR_phase8RenderGarageCapacityPanel()
			UI.Subtitle.Text = result.Message or "Could not upgrade garage capacity."
		end
	end)
	-- NTR_PERSISTENCE_PHASE8_CAPACITY_PANEL_END

	UI.NextPanel = panel(gui, "NextPinnedBottomRight", UDim2.fromOffset(178, BOTTOM_HEIGHT), UDim2.new(1, -18, 1, -BOTTOM_MARGIN), Vector2.new(1, 1))]]

source = replaceOnce(source, uiAnchor, uiReplacement, "cash panel / next panel setup block")

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase8CapacityUI", true)

print("[NTR Persistence Phase 8] Installed garage capacity UI panel and upgrade button.")
print("[NTR Persistence Phase 8] Next: run scripts/roblox_persistence_phase8_garage_capacity_ui_source_audit.lua, then Play and run scripts/roblox_persistence_phase8_garage_capacity_ui_client_smoke.lua from the CLIENT Command Bar.")
