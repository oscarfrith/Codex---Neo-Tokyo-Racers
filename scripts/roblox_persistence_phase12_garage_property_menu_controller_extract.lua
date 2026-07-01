-- Neo Tokyo Racers - Persistence Phase 12
-- Extracts the garage property menu rendering into a client UI ModuleScript.
--
-- Run from Roblox Studio Command Bar in Edit mode after Phase 11.
-- This is a guarded marker replacement against the active client bootstrap.

local StarterPlayer = game:GetService("StarterPlayer")

local function assertChild(parent, name)
	local child = parent:FindFirstChild(name)
	assert(child, "Missing " .. parent:GetFullName() .. "." .. name)
	return child
end

local function ensureFolder(parent, name)
	local child = parent:FindFirstChild(name)
	if child then
		assert(child:IsA("Folder"), "Expected " .. child:GetFullName() .. " to be a Folder.")
		return child
	end

	child = Instance.new("Folder")
	child.Name = name
	child.Parent = parent
	return child
end

local scriptsFolder = assertChild(StarterPlayer, "StarterPlayerScripts")
local clientRoot = assertChild(scriptsFolder, "NeoTokyoRacersClient")
local bootstrap = assertChild(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local controllers = ensureFolder(clientRoot, "Controllers")
local uiControllers = ensureFolder(controllers, "UI")

local moduleScript = uiControllers:FindFirstChild("GaragePropertyMenuController")
if not moduleScript then
	moduleScript = Instance.new("ModuleScript")
	moduleScript.Name = "GaragePropertyMenuController"
	moduleScript.Parent = uiControllers
else
	assert(moduleScript:IsA("ModuleScript"), "Expected GaragePropertyMenuController to be a ModuleScript.")
end

moduleScript.Source = [=[
-- Neo Tokyo Racers - GaragePropertyMenuController
-- Renders the garage property purchase gallery used by the dealership UI.

local GaragePropertyMenuController = {}

local function formatCash(value)
	return "$" .. tostring(value or 0)
end

function GaragePropertyMenuController.ListProperties(ctx)
	local kit = ctx and ctx.kit
	if kit then
		local ok, garageCatalog = pcall(function()
			return require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("Data"):WaitForChild("GaragePropertyCatalog"))
		end)
		if ok and garageCatalog and garageCatalog.List then
			return garageCatalog.List()
		end
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

function GaragePropertyMenuController.RenderThumbnail(ctx, parent, property)
	local imageId = tostring(property.Image or "")
	if imageId ~= "" then
		local image = ctx.new("ImageLabel", {
			BackgroundColor3 = Color3.fromRGB(12, 20, 17),
			BorderSizePixel = 0,
			Image = imageId,
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.new(1, -14, 0, 74),
			Position = UDim2.fromOffset(7, 7),
		}, parent)
		ctx.corner(image, 4)
		return image
	end

	local theme = ctx.Theme
	local preview = ctx.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(12, 20, 24),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -14, 0, 74),
		Position = UDim2.fromOffset(7, 7),
	}, parent)
	ctx.corner(preview, 4)
	ctx.stroke(preview, theme.Accent, 0.45, 1)

	local floor = ctx.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(22, 38, 40),
		BorderSizePixel = 0,
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.new(0, 10, 1, -24),
	}, preview)
	ctx.corner(floor, 3)

	local door = ctx.new("Frame", {
		BackgroundColor3 = theme.CardHot,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(64, 34),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -19),
	}, preview)
	ctx.corner(door, 3)

	ctx.new("Frame", { BackgroundColor3 = theme.Accent, BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 3), Position = UDim2.fromOffset(8, 8) }, door)
	ctx.new("Frame", { BackgroundColor3 = theme.Accent, BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 3), Position = UDim2.fromOffset(8, 18) }, door)
	ctx.new("Frame", { BackgroundColor3 = theme.Cash, BorderSizePixel = 0, Size = UDim2.fromOffset(42, 4), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12) }, preview)

	return preview
end

function GaragePropertyMenuController.Render(ctx)
	local ui = ctx.UI
	local theme = ctx.Theme
	if not ui or not ui.GaragePropertyShopBody then
		return
	end

	ctx.clear(ui.GaragePropertyShopBody)

	ctx.label(ui.GaragePropertyShopBody, "Garage Properties", UDim2.new(1, -54, 0, 30), UDim2.fromOffset(4, 0), 18, Enum.TextXAlignment.Left)
	ctx.label(ui.GaragePropertyShopBody, "Buy apartment-block garage spaces around the city to expand your collection.", UDim2.new(1, -8, 0, 34), UDim2.fromOffset(4, 34), 10, Enum.TextXAlignment.Left).TextColor3 = theme.Muted

	local list = ctx.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 1, -76),
		Position = UDim2.fromOffset(0, 76),
	}, ui.GaragePropertyShopBody)

	ctx.new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(10, 10),
		CellSize = ctx.UserInputService.TouchEnabled and UDim2.fromOffset(176, 214) or UDim2.fromOffset(190, 218),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)

	local _, capacity, maxCapacity, nextPrice = ctx.capacitySummary()
	for _, property in ipairs(GaragePropertyMenuController.ListProperties(ctx)) do
		local available = property.Available == true and capacity < maxCapacity
		local card = ctx.button(list, "", UDim2.fromOffset(190, 218), UDim2.fromScale(0, 0), available and theme.Card or theme.Disabled)
		card.AutoButtonColor = available

		GaragePropertyMenuController.RenderThumbnail(ctx, card, property)
		ctx.label(card, property.DisplayName or "Garage", UDim2.new(1, -14, 0, 24), UDim2.fromOffset(7, 86), 12, Enum.TextXAlignment.Left)
		ctx.label(card, property.District or "Neo Tokyo", UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 110), 9, Enum.TextXAlignment.Left).TextColor3 = theme.Muted
		ctx.label(card, "+" .. tostring(property.Spaces or 1) .. " car space", UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 132), 10, Enum.TextXAlignment.Left).TextColor3 = theme.Accent

		local priceText = available and formatCash(nextPrice or property.Price or 0) or "Coming soon"
		ctx.label(card, priceText, UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 154), 11, Enum.TextXAlignment.Left).TextColor3 = available and theme.Cash or theme.Muted

		local buy = ctx.button(card, available and "Buy" or "Locked", UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 181), available and theme.Buy or theme.Disabled)
		buy.AutoButtonColor = available
		buy.MouseButton1Click:Connect(function()
			if not available then
				ui.Subtitle.Text = "This garage location will unlock in a later phase."
				return
			end

			local result = ctx.callServer("UpgradeGarageCapacity", { PropertyId = property.PropertyId })
			if result.Success then
				ui.Subtitle.Text = "Garage property purchased."
				ctx.renderGarageCapacityPanel()
				GaragePropertyMenuController.Render(ctx)
			else
				ui.Subtitle.Text = result.Message or "Could not buy this garage property."
			end
		end)
	end
end

return GaragePropertyMenuController
]=]

local source = bootstrap.Source
assert(source:find("NTR_PERSISTENCE_PHASE11_GARAGE_SPACES_COCKPIT_ONLY", 1, true), "Run Phase 11 cockpit-only visibility patch before Phase 12.")
assert(source:find("NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_BEGIN", 1, true), "Phase 9 garage property menu markers were not found.")
assert(not source:find("NTR_PERSISTENCE_PHASE12_GARAGE_MENU_CONTROLLER", 1, true), "Persistence Phase 12 controller extraction is already installed.")

local blockStart = source:find("-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_BEGIN", 1, true)
local blockEnd = source:find("-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_END", blockStart, true)
assert(blockStart and blockEnd, "Could not find the complete Phase 9 helper block.")

local blockEndLine = source:find("\n", blockEnd, true)
if not blockEndLine then
	blockEndLine = #source
end

local replacementBlock = [=[
-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_BEGIN
-- NTR_PERSISTENCE_PHASE9_REGISTER_REPAIR
-- NTR_PERSISTENCE_PHASE12_GARAGE_MENU_CONTROLLER
NTRPersistencePhase9 = NTRPersistencePhase9 or {}

function NTRPersistencePhase9.Controller()
	if NTRPersistencePhase9._Controller then
		return NTRPersistencePhase9._Controller
	end

	local ok, controller = pcall(function()
		return require(script.Parent:WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("GaragePropertyMenuController"))
	end)

	if ok and controller then
		NTRPersistencePhase9._Controller = controller
		return controller
	end

	if UI and UI.Subtitle then
		UI.Subtitle.Text = "Garage property menu failed to load."
	end
	warn("[NTR Persistence Phase 12] GaragePropertyMenuController failed to require: " .. tostring(controller))
	return nil
end

function NTRPersistencePhase9.Context()
	return {
		UI = UI,
		Theme = Theme,
		kit = kit,
		UserInputService = UserInputService,
		new = new,
		label = label,
		button = button,
		corner = corner,
		stroke = stroke,
		clear = clear,
		callServer = callServer,
		capacitySummary = NTR_phase8GarageCapacitySummary,
		renderGarageCapacityPanel = NTR_phase8RenderGarageCapacityPanel,
	}
end

function NTRPersistencePhase9.RenderGaragePropertyShop()
	local controller = NTRPersistencePhase9.Controller()
	if controller and controller.Render then
		return controller.Render(NTRPersistencePhase9.Context())
	end
end

function NTRPersistencePhase9.SetGaragePropertyShopVisible(isVisible)
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
end
-- NTR_PERSISTENCE_PHASE9_GARAGE_PROPERTY_MENU_END
]=]

source = source:sub(1, blockStart - 1) .. replacementBlock .. source:sub(blockEndLine + 1)

assert(source:find("GaragePropertyMenuController", 1, true), "Phase 12 replacement did not reference the controller module.")
assert(not source:find("function NTRPersistencePhase9.GarageCardThumbnail", 1, true), "Phase 12 replacement did not remove the old thumbnail renderer from the bootstrap.")
assert(not source:find("function NTRPersistencePhase9.GarageProperties", 1, true), "Phase 12 replacement did not remove the old property list renderer from the bootstrap.")

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase12GarageMenuController", true)
moduleScript:SetAttribute("PersistencePhase12GarageMenuController", true)

print("[NTR Persistence Phase 12] PASS: garage property menu rendering was extracted to Controllers.UI.GaragePropertyMenuController.")
print("[NTR Persistence Phase 12] Next: run scripts/roblox_persistence_phase12_garage_property_menu_controller_audit.lua, then Play and run scripts/roblox_persistence_phase12_garage_property_menu_controller_client_smoke.lua from the CLIENT Command Bar.")
