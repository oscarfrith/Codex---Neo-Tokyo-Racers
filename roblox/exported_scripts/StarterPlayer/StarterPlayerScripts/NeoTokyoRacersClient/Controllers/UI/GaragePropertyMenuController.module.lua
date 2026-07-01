-- Neo Tokyo Racers - GaragePropertyMenuController
-- Persistence Phase 13: renders buyable, owned garage properties.

local GaragePropertyMenuController = {}

local function formatCash(value)
	return "$" .. tostring(value or 0)
end

local function profileFrom(ctx)
	return ctx and ctx.State and ctx.State.Profile or {}
end

local function garageFrom(ctx)
	local profile = profileFrom(ctx)
	return typeof(profile.Garage) == "table" and profile.Garage or {}
end

local function ownedPropertiesFrom(ctx)
	local garage = garageFrom(ctx)
	return typeof(garage.OwnedGarageProperties) == "table" and garage.OwnedGarageProperties or {}
end

function GaragePropertyMenuController.IsOwned(ctx, propertyId)
	return ownedPropertiesFrom(ctx)[tostring(propertyId or "")] ~= nil
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
			Price = 50000,
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

	local _, capacity, maxCapacity = ctx.capacitySummary()
	for _, property in ipairs(GaragePropertyMenuController.ListProperties(ctx)) do
		local owned = GaragePropertyMenuController.IsOwned(ctx, property.PropertyId)
		local available = property.Available == true and not owned and capacity < maxCapacity
		local card = ctx.button(list, "", UDim2.fromOffset(190, 218), UDim2.fromScale(0, 0), available and theme.Card or theme.Disabled)
		card.AutoButtonColor = available

		GaragePropertyMenuController.RenderThumbnail(ctx, card, property)
		ctx.label(card, property.DisplayName or "Garage", UDim2.new(1, -14, 0, 24), UDim2.fromOffset(7, 86), 12, Enum.TextXAlignment.Left)
		ctx.label(card, property.District or "Neo Tokyo", UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 110), 9, Enum.TextXAlignment.Left).TextColor3 = theme.Muted
		ctx.label(card, "+" .. tostring(property.Spaces or 1) .. " car space", UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 132), 10, Enum.TextXAlignment.Left).TextColor3 = theme.Accent

		local priceText = owned and "Owned" or (available and formatCash(property.Price or 0) or "Coming soon")
		ctx.label(card, priceText, UDim2.new(1, -14, 0, 20), UDim2.fromOffset(7, 154), 11, Enum.TextXAlignment.Left).TextColor3 = owned and theme.Accent or (available and theme.Cash or theme.Muted)

		local buy = ctx.button(card, owned and "Owned" or (available and "Buy" or "Locked"), UDim2.new(1, -14, 0, 30), UDim2.fromOffset(7, 181), available and theme.Buy or theme.Disabled)
		buy.AutoButtonColor = available
		buy.MouseButton1Click:Connect(function()
			if owned then
				ui.Subtitle.Text = "You already own this garage."
				return
			end
			if not available then
				ui.Subtitle.Text = "This garage location will unlock in a later phase."
				return
			end

			local result = ctx.callServer("BuyGarageProperty", { PropertyId = property.PropertyId })
			if result.Success then
				if ctx.State and result.Profile then
					ctx.State.Profile = result.Profile
				end
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
