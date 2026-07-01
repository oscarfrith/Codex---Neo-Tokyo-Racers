-- Neo Tokyo Racers - Persistence Phase 10
-- Refines the garage property UI layout and modal behavior after Phase 9.
--
-- Run from Roblox Studio Command Bar in Edit mode after:
-- 1. scripts/roblox_persistence_phase9_garage_property_menu.lua
-- 2. scripts/roblox_persistence_phase9_register_limit_repair.lua
--
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
assert(source:find("NTR_PERSISTENCE_PHASE9_REGISTER_REPAIR", 1, true), "Run the Phase 9 register-limit repair before Phase 10.")
assert(not source:find("NTR_PERSISTENCE_PHASE10_GARAGE_UI_LAYOUT_MODAL", 1, true), "Persistence Phase 10 garage UI layout/modal repair is already installed.")

local function replaceOnce(haystack, needle, replacement, label)
	local found = haystack:find(needle, 1, true)
	assert(found, "Phase 10 preflight failed. Could not find source anchor: " .. label)
	local updated, count = haystack:gsub(needle:gsub("([^%w])", "%%%1"), replacement, 1)
	assert(count == 1, "Phase 10 preflight failed. Anchor was not unique: " .. label)
	return updated
end

local layoutCalcAnchor = [=[	local bottomY = vh - BOTTOM_MARGIN
	local leftCashTop = vh - BOTTOM_MARGIN - BOTTOM_HEIGHT
	local categoryH = math.max(1, leftCashTop - gap - topY)
	local centerX = margin + leftW + gap]=]

local layoutCalcReplacement = [=[	local bottomY = vh - BOTTOM_MARGIN
	-- NTR_PERSISTENCE_PHASE10_GARAGE_UI_LAYOUT_MODAL
	local leftPanelH = BOTTOM_HEIGHT
	local leftStackGap = 10
	local cashBottomY = bottomY
	local garageBottomY = cashBottomY - leftPanelH - leftStackGap
	local categoryBottomY = garageBottomY - leftPanelH - gap
	local categoryH = math.max(96, categoryBottomY - topY)
	local centerX = margin + leftW + gap]=]

source = replaceOnce(source, layoutCalcAnchor, layoutCalcReplacement, "dealership left-column layout calculations")

local categoryLayoutAnchor = [=[	if UI.CategoryPanel then
		UI.CategoryPanel.Position = UDim2.fromOffset(margin, topY)
		UI.CategoryPanel.Size = UDim2.fromOffset(leftW, categoryH)
	end
	if UI.CockpitGridPanel then]=]

local categoryLayoutReplacement = [=[	if UI.CategoryPanel then
		UI.CategoryPanel.Position = UDim2.fromOffset(margin, topY)
		UI.CategoryPanel.Size = UDim2.fromOffset(leftW, categoryH)
	end
	if UI.GarageCapacityPanel then
		UI.GarageCapacityPanel.AnchorPoint = Vector2.new(0, 1)
		UI.GarageCapacityPanel.Position = UDim2.fromOffset(margin, garageBottomY)
		UI.GarageCapacityPanel.Size = UDim2.fromOffset(leftW, leftPanelH)
	end
	if UI.CashPanel then
		UI.CashPanel.AnchorPoint = Vector2.new(0, 1)
		UI.CashPanel.Position = UDim2.fromOffset(margin, cashBottomY)
		UI.CashPanel.Size = UDim2.fromOffset(leftW, leftPanelH)
	end
	if UI.CockpitGridPanel then]=]

source = replaceOnce(source, categoryLayoutAnchor, categoryLayoutReplacement, "dealership left-column panel layout")

local closeAnchor = [=[function NTRPersistencePhase9.OpenGaragePropertyShop()
	if not UI.GaragePropertyShop then return end
	UI.GaragePropertyShop.Visible = true
	NTRPersistencePhase9.RenderGaragePropertyShop()
end]=]

local closeReplacement = [=[function NTRPersistencePhase9.SetGaragePropertyShopVisible(isVisible)
	if UI.GaragePropertyBackdrop then
		UI.GaragePropertyBackdrop.Visible = isVisible == true
	end
	if UI.GaragePropertyShop then
		UI.GaragePropertyShop.Visible = isVisible == true
	end
end

function NTRPersistencePhase9.OpenGaragePropertyShop()
	if not UI.GaragePropertyShop then return end
	NTRPersistencePhase9.SetGaragePropertyShopVisible(true)
	NTRPersistencePhase9.RenderGaragePropertyShop()
end]=]

source = replaceOnce(source, closeAnchor, closeReplacement, "Phase 9 modal open helper")

local shopCreateAnchor = [=[	UI.GaragePropertyShop = panel(gui, "GaragePropertyShopPopup", UserInputService.TouchEnabled and UDim2.new(0.92, 0, 0.72, 0) or UDim2.fromOffset(650, 390), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UI.GaragePropertyShop.Visible = false
	pad(UI.GaragePropertyShop, 14)
	UI.GaragePropertyShopBody = new("Frame", { Name = "GaragePropertyShopBody", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, UI.GaragePropertyShop)
	local closeGarageShop = button(UI.GaragePropertyShop, "X", UDim2.fromOffset(34, 30), UDim2.new(1, -36, 0, 2), Theme.Exit)
	closeGarageShop.Name = "GaragePropertyShopClose"
	closeGarageShop.MouseButton1Click:Connect(function()
		UI.GaragePropertyShop.Visible = false
	end)]=]

local shopCreateReplacement = [=[	UI.GaragePropertyBackdrop = new("TextButton", {
		Name = "GaragePropertyModalBackdrop",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		Text = "",
		Visible = false,
		ZIndex = 90,
	}, gui)
	UI.GaragePropertyShop = panel(gui, "GaragePropertyShopPopup", UserInputService.TouchEnabled and UDim2.new(0.92, 0, 0.72, 0) or UDim2.fromOffset(650, 390), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	UI.GaragePropertyShop.Visible = false
	UI.GaragePropertyShop.ZIndex = 100
	pad(UI.GaragePropertyShop, 14)
	UI.GaragePropertyShopBody = new("Frame", { Name = "GaragePropertyShopBody", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 101 }, UI.GaragePropertyShop)
	local closeGarageShop = button(UI.GaragePropertyShop, "X", UDim2.fromOffset(34, 30), UDim2.new(1, -36, 0, 2), Theme.Exit)
	closeGarageShop.Name = "GaragePropertyShopClose"
	closeGarageShop.ZIndex = 102
	closeGarageShop.MouseButton1Click:Connect(function()
		NTRPersistencePhase9.SetGaragePropertyShopVisible(false)
	end)
	UI.GaragePropertyBackdrop.MouseButton1Click:Connect(function()
		NTRPersistencePhase9.SetGaragePropertyShopVisible(false)
	end)]=]

source = replaceOnce(source, shopCreateAnchor, shopCreateReplacement, "Phase 9 garage property shop creation block")

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase10GarageUILayoutModal", true)

print("[NTR Persistence Phase 10] PASS: garage spaces now stacks above cash, Categories shrinks around it, and garage property shop has a dimmed modal backdrop.")
print("[NTR Persistence Phase 10] Next: run scripts/roblox_persistence_phase10_garage_ui_layout_modal_audit.lua, then Play and run scripts/roblox_persistence_phase10_garage_ui_layout_modal_client_smoke.lua from the CLIENT Command Bar.")
