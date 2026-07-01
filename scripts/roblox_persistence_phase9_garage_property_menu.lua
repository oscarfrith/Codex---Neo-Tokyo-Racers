-- Neo Tokyo Racers - Persistence Phase 9
-- Replaces the direct garage-space upgrade button with a garage-property shop menu.
--
-- Run from Roblox Studio Command Bar in Edit mode or Play mode after Phase 8.
-- This is a guarded exact-source patch against the Phase 8 client bootstrap source.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function assertChild(parent, name)
	local child = parent:FindFirstChild(name)
	assert(child, "Missing " .. parent:GetFullName() .. "." .. name)
	return child
end

local kit = assertChild(ReplicatedStorage, "NeoTokyoRacers")
local shared = assertChild(kit, "Shared")
local modules = assertChild(shared, "Modules")
local dataModules = modules:FindFirstChild("Data")
if not dataModules then
	dataModules = Instance.new("Folder")
	dataModules.Name = "Data"
	dataModules.Parent = modules
end

local catalog = dataModules:FindFirstChild("GaragePropertyCatalog")
if not catalog then
	catalog = Instance.new("ModuleScript")
	catalog.Name = "GaragePropertyCatalog"
	catalog.Parent = dataModules
end

catalog.Source = [=[
-- Neo Tokyo Racers garage property catalogue.
-- Phase 9 client-facing seed data. Server ownership will move here in a later phase.

local GaragePropertyCatalog = {}

GaragePropertyCatalog.Properties = {
	{
		PropertyId = "APT_BLOCK_A_SLOT_01",
		DisplayName = "Kanda Lift Bay",
		District = "Kanda Stack Apartments",
		Description = "Compact apartment-block garage with one extra vehicle space.",
		Spaces = 1,
		Price = nil,
		Image = "",
		Available = true,
	},
	{
		PropertyId = "APT_BLOCK_B_SLOT_02",
		DisplayName = "Shibuya Twin Bay",
		District = "Shibuya Heights",
		Description = "Two-display garage concept. Server purchase support comes later.",
		Spaces = 2,
		Price = nil,
		Image = "",
		Available = false,
	},
	{
		PropertyId = "HARBOR_STACK_SLOT_03",
		DisplayName = "Harbor Stack Garage",
		District = "Harbor Megablock",
		Description = "Larger collector space concept for future progression tiers.",
		Spaces = 3,
		Price = nil,
		Image = "",
		Available = false,
	},
}

function GaragePropertyCatalog.List()
	return GaragePropertyCatalog.Properties
end

return GaragePropertyCatalog
]=]

local scriptsFolder = assertChild(StarterPlayer, "StarterPlayerScripts")
local clientRoot = assertChild(scriptsFolder, "NeoTokyoRacersClient")
local bootstrap = assertChild(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(source:find("NTR_PERSISTENCE_PHASE8_CAPACITY_UI_BEGIN", 1, true), "Phase 8 capacity UI must be installed before Phase 9.")
assert(source:find("NTR_PERSISTENCE_PHASE8_CAPACITY_PANEL_BEGIN", 1, true), "Phase 8 capacity panel must be installed before Phase 9.")
assert(not source:find("NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_BEGIN", 1, true), "Persistence Phase 9 garage property menu is already installed.")

local function replaceOnce(haystack, needle, replacement, label)
	local found = haystack:find(needle, 1, true)
	assert(found, "Phase 9 preflight failed. Could not find source anchor: " .. label)
	local updated, count = haystack:gsub(needle:gsub("([^%w])", "%%%1"), replacement, 1)
	assert(count == 1, "Phase 9 preflight failed. Anchor was not unique: " .. label)
	return updated
end

local helperAnchor = [=[local function NTR_phase8RenderGarageCapacityPanel()
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
-- NTR_PERSISTENCE_PHASE8_CAPACITY_UI_END]=]

local helperReplacement = [=[local function NTR_phase8RenderGarageCapacityPanel()
	if not UI.GarageCapacityPanel then return end
	local ownedCount, capacity, maxCapacity = NTR_phase8GarageCapacitySummary()

	UI.GarageCapacityCount.Text = tostring(ownedCount) .. "/" .. tostring(capacity) .. " spaces"
	if UI.GarageCapacityPrice then
		UI.GarageCapacityPrice.Visible = false
	end

	if capacity >= maxCapacity then
		UI.GarageCapacityUpgradeButton.Text = "MAXED"
		UI.GarageCapacityUpgradeButton.AutoButtonColor = false
		UI.GarageCapacityUpgradeButton.BackgroundColor3 = Theme.Disabled
	else
		UI.GarageCapacityUpgradeButton.Text = "BUY MORE"
		UI.GarageCapacityUpgradeButton.AutoButtonColor = true
		UI.GarageCapacityUpgradeButton.BackgroundColor3 = Theme.Buy
	end
end

-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_BEGIN
local function NTR_phase9GarageProperties()
	local ok, garageCatalog = pcall(function()
		return require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("GaragePropertyCatalog"))
	end)
	if ok and garageCatalog and garageCatalog.List then
		return garageCatalog.List()
	end
	return {
		{
			PropertyId = "APT_BLOCK_A_SLOT_01",
			DisplayName = "Kanda Lift Bay",
			District = "Kanda Stack Apartments",
			Description = "Compact apartment-block garage with one extra vehicle space.",
			Spaces = 1,
			Available = true,
		},
	}
end

local function NTR_phase9GarageCardThumbnail(parent, property)
	local imageId = tostring(property.Image or "")
	if imageId ~= "" then
		local image = new("ImageLabel", {
			BackgroundColor3 = Color3.fromRGB(12, 20, 17),
			BorderSizePixel = 0,
			Image = imageId,
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.new(1, -14, 0, 74),
			Position = UDim2.fromOffset(7, 7),
		}, parent)
		corner(image, 4)
		return image
	end

	local preview = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 20, 24),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -14, 0, 74),
		Position = UDim2.fromOffset(7, 7),
	}, parent)
	corner(preview, 4)
	stroke(preview, Theme.Accent, 0.45, 1)

	local floor = new("Frame", { BackgroundColor3 = Color3.fromRGB(22, 38, 40), BorderSizePixel = 0, Size = UDim2.new(1, -20, 0, 18), Position = UDim2.new(0, 10, 1, -24) }, preview)
	corner(floor, 3)
	local door = new("Frame", { BackgroundColor3 = Theme.CardHot, BorderSizePixel = 0, Size = UDim2.fromOffset(64, 34), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -19) }, preview)
	corner(door, 3)
	new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 3), Position = UDim2.fromOffset(8, 8) }, door)
	new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 3), Position = UDim2.fromOffset(8, 18) }, door)
	new("Frame", { BackgroundColor3 = Theme.Cash, BorderSizePixel = 0, Size = UDim2.fromOffset(42, 4), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12) }, preview)
	return preview
end

local function NTR_phase9RenderGaragePropertyShop()
	if not UI.GaragePropertyShopBody then return end
	clear(UI.GaragePropertyShopBody)

	label(UI.GaragePropertyShopBody, "Garage Properties", UDim2.new(1, -54, 0, 30), UDim2.fromOffset(4, 0), 18, Enum.TextXAlignment.Left)
	label(UI.GaragePropertyShopBody, "Buy apartment-block garage spaces around the city to expand your collection.", UDim2.new(1, -8, 0, 34), UDim2.fromOffset(4, 34), 10, Enum.TextXAlignment.Left).TextColor3 = Theme.Muted

	local list = new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 1, -76),
		Position = UDim2.fromOffset(0, 76),
	}, UI.GaragePropertyShopBody)
	new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(10, 10),
		CellSize = UserInputService.TouchEnabled and UDim2.fromOffset(176, 214) or UDim2.fromOffset(190, 218),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)

	local _, capacity, maxCapacity, nextPrice = NTR_phase8GarageCapacitySummary()
	for _, property in ipairs(NTR_phase9GarageProperties()) do
		local available = property.Available == true and capacity < maxCapacity
		local card = button(list, "", UDim2.fromOffset(190, 218), UDim2.fromScale(0, 0), available and Theme.Card or Theme.Disabled)
		card.AutoButtonColor = available
		NTR_phase9GarageCardThumbnail(card, property)
		label(card, property.DisplayName or "Garage", UDim2.new(1, -14, 0, 24), UDim2.fromOffset(7, 86), 12, Enum.TextXAlignment.Left)
		label(card, property.District or "Neo Tokyo", UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 110), 9, Enum.TextXAlignment.Left).TextColor3 = Theme.Muted
		label(card, "+" .. tostring(property.Spaces or 1) .. " car space", UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 132), 10, Enum.TextXAlignment.Left).TextColor3 = Theme.Accent

		local priceText = available and ("$" .. tostring(nextPrice or property.Price or 0)) or "Coming soon"
		label(card, priceText, UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 154), 11, Enum.TextXAlignment.Left).TextColor3 = available and Theme.Cash or Theme.Muted

		local buy = button(card, available and "Buy" or "Locked", UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 181), available and Theme.Buy or Theme.Disabled)
		buy.AutoButtonColor = available
		buy.MouseButton1Click:Connect(function()
			if not available then
				UI.Subtitle.Text = "This garage location will unlock in a later phase."
				return
			end

			local result = callServer("UpgradeGarageCapacity", { PropertyId = property.PropertyId })
			if result.Success then
				UI.Subtitle.Text = "Garage property purchased."
				NTR_phase8RenderGarageCapacityPanel()
				NTR_phase9RenderGaragePropertyShop()
			else
				UI.Subtitle.Text = result.Message or "Could not buy this garage property."
			end
		end)
	end
end

local function NTR_phase9OpenGaragePropertyShop()
	if not UI.GaragePropertyShop then return end
	UI.GaragePropertyShop.Visible = true
	NTR_phase9RenderGaragePropertyShop()
end
-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_END
-- NTR_PERSISTENCE_PHASE8_CAPACITY_UI_END]=]

source = replaceOnce(source, helperAnchor, helperReplacement, "Phase 8 capacity render helper")

local panelAnchor = [=[	-- NTR_PERSISTENCE_PHASE8_CAPACITY_PANEL_BEGIN
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
	-- NTR_PERSISTENCE_PHASE8_CAPACITY_PANEL_END]=]

local panelReplacement = [=[	-- NTR_PERSISTENCE_PHASE8_CAPACITY_PANEL_BEGIN
	UI.GarageCapacityPanel = panel(gui, "GarageCapacityPinnedLeft", UDim2.fromOffset(202, BOTTOM_HEIGHT), UDim2.new(0, 216, 1, -BOTTOM_MARGIN), Vector2.new(0, 1))
	label(UI.GarageCapacityPanel, "Garage Spaces", UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 6), 10, Enum.TextXAlignment.Center)
	UI.GarageCapacityCount = label(UI.GarageCapacityPanel, "0/2 spaces", UDim2.new(1, -16, 0, 28), UDim2.fromOffset(8, 29), 17, Enum.TextXAlignment.Center)
	UI.GarageCapacityCount.Name = "GarageCapacityCount"
	UI.GarageCapacityCount.TextColor3 = Theme.Accent
	UI.GarageCapacityPrice = label(UI.GarageCapacityPanel, "", UDim2.new(1, -16, 0, 1), UDim2.fromOffset(8, 55), 1, Enum.TextXAlignment.Center)
	UI.GarageCapacityPrice.Name = "GarageCapacityPrice"
	UI.GarageCapacityPrice.Visible = false
	UI.GarageCapacityUpgradeButton = button(UI.GarageCapacityPanel, "Buy More", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 66), Theme.Buy)
	UI.GarageCapacityUpgradeButton.Name = "GarageCapacityUpgradeButton"
	UI.GarageCapacityUpgradeButton.MouseButton1Click:Connect(function()
		local _, capacity, maxCapacity = NTR_phase8GarageCapacitySummary()
		if capacity >= maxCapacity then
			UI.Subtitle.Text = "Garage collection is already at the current maximum."
			return
		end
		NTR_phase9OpenGaragePropertyShop()
	end)

	UI.GaragePropertyShop = panel(gui, "GaragePropertyShopPopup", UserInputService.TouchEnabled and UDim2.new(0.92, 0, 0.72, 0) or UDim2.fromOffset(650, 390), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UI.GaragePropertyShop.Visible = false
	pad(UI.GaragePropertyShop, 14)
	UI.GaragePropertyShopBody = new("Frame", { Name = "GaragePropertyShopBody", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, UI.GaragePropertyShop)
	local closeGarageShop = button(UI.GaragePropertyShop, "X", UDim2.fromOffset(34, 30), UDim2.new(1, -36, 0, 2), Theme.Exit)
	closeGarageShop.Name = "GaragePropertyShopClose"
	closeGarageShop.MouseButton1Click:Connect(function()
		UI.GaragePropertyShop.Visible = false
	end)
	-- NTR_PERSISTENCE_PHASE8_CAPACITY_PANEL_END]=]

source = replaceOnce(source, panelAnchor, panelReplacement, "Phase 8 capacity panel block")

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase9GaragePropertyMenu", true)
catalog:SetAttribute("PersistencePhase9GaragePropertyCatalog", true)

print("[NTR Persistence Phase 9] Installed garage property menu UI.")
print("[NTR Persistence Phase 9] The first listed garage currently calls the Phase 7 capacity action as a temporary backend.")
print("[NTR Persistence Phase 9] Next: run scripts/roblox_persistence_phase9_garage_property_menu_audit.lua, then Play and run scripts/roblox_persistence_phase9_garage_property_menu_client_smoke.lua from the CLIENT Command Bar.")
