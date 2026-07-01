-- Neo Tokyo Racers - Persistence Phase 9 register-limit repair
-- Repairs the client startup error:
-- "Out of local registers when trying to allocate V75Driving: exceeded limit 200"
--
-- Run from Roblox Studio Command Bar in Edit mode.
-- This is a guarded source patch against the active client bootstrap after Phase 9.

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
assert(source:find("NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_BEGIN", 1, true), "Phase 9 garage property menu markers were not found.")
assert(not source:find("NTR_PERSISTENCE_PHASE9_REGISTER_REPAIR", 1, true), "Phase 9 register-limit repair is already installed.")

local blockStart = source:find("-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_BEGIN", 1, true)
local blockEnd = source:find("-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_END", blockStart, true)
assert(blockStart and blockEnd, "Could not find the complete Phase 9 helper block.")

local blockEndLine = source:find("\n", blockEnd, true)
if not blockEndLine then
	blockEndLine = #source
end

local repairedBlock = [=[
-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_BEGIN
-- NTR_PERSISTENCE_PHASE9_REGISTER_REPAIR
NTRPersistencePhase9 = NTRPersistencePhase9 or {}

function NTRPersistencePhase9.GarageProperties()
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

function NTRPersistencePhase9.GarageCardThumbnail(parent, property)
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

function NTRPersistencePhase9.RenderGaragePropertyShop()
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
	for _, property in ipairs(NTRPersistencePhase9.GarageProperties()) do
		local available = property.Available == true and capacity < maxCapacity
		local card = button(list, "", UDim2.fromOffset(190, 218), UDim2.fromScale(0, 0), available and Theme.Card or Theme.Disabled)
		card.AutoButtonColor = available
		NTRPersistencePhase9.GarageCardThumbnail(card, property)
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
				NTRPersistencePhase9.RenderGaragePropertyShop()
			else
				UI.Subtitle.Text = result.Message or "Could not buy this garage property."
			end
		end)
	end
end

function NTRPersistencePhase9.OpenGaragePropertyShop()
	if not UI.GaragePropertyShop then return end
	UI.GaragePropertyShop.Visible = true
	NTRPersistencePhase9.RenderGaragePropertyShop()
end
-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_END
]=]

source = source:sub(1, blockStart - 1) .. repairedBlock .. source:sub(blockEndLine + 1)

local oldCall = "NTR_phase9OpenGaragePropertyShop()"
local newCall = "NTRPersistencePhase9.OpenGaragePropertyShop()"
local callCount
source, callCount = source:gsub(oldCall:gsub("([^%w])", "%%%1"), newCall)
assert(callCount >= 1, "Could not update the Buy More button call to the repaired Phase 9 table function.")

assert(not source:find("local function NTR_phase9", 1, true), "Repair did not remove all Phase 9 top-level local helper functions.")
assert(source:find("function NTRPersistencePhase9.OpenGaragePropertyShop", 1, true), "Repair did not install the table-owned Phase 9 opener.")

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase9RegisterLimitRepair", true)

print("[NTR Persistence Phase 9 Register Repair] PASS: moved Phase 9 helpers onto NTRPersistencePhase9 table.")
print("[NTR Persistence Phase 9 Register Repair] Restart Play. The client bootstrap should no longer hit the V75Driving local-register limit.")
