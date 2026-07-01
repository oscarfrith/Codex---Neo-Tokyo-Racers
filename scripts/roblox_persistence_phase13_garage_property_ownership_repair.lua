-- Neo Tokyo Racers - Persistence Phase 13 repair/completion
-- Use this if the first Phase 13 installer stopped at:
-- "Could not find source anchor for garage mirror mutating action."
--
-- Run from Roblox Studio Command Bar in Edit mode.
-- This completes the server/client Phase 13 pieces independently, so it is safe
-- after a partial Phase 13 install.

local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 13 Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function waitPath(root, ...)
	local item = root
	for _, name in ipairs({ ... }) do
		item = item:WaitForChild(name)
	end
	return item
end

local function replaceOnce(source, oldText, newText, label)
	local first = string.find(source, oldText, 1, true)
	if not first then
		error("Could not find source anchor for " .. label .. ". A fresh Studio mirror is needed before another Phase 13 patch.")
	end
	local second = string.find(source, oldText, first + #oldText, true)
	if second then
		error("Source anchor for " .. label .. " appears more than once. Aborting.")
	end
	return string.sub(source, 1, first - 1) .. newText .. string.sub(source, first + #oldText)
end

local function insertAfter(source, anchor, insertion, label)
	if string.find(source, insertion, 1, true) then
		return source, false
	end
	local first = string.find(source, anchor, 1, true)
	if not first then
		error("Could not find source anchor for " .. label .. ". A fresh Studio mirror is needed before another Phase 13 patch.")
	end
	return string.sub(source, 1, first + #anchor - 1) .. insertion .. string.sub(source, first + #anchor), true
end

local function ensureMirrorMutatingAction(source)
	if string.find(source, "BuyGarageProperty = true", 1, true) then
		return source, false
	end

	local tableStart = string.find(source, "local V80_mutatingActions = {", 1, true)
	if not tableStart then
		error("Could not find V80_mutatingActions table. Refresh the Studio mirror before another Phase 13 patch.")
	end

	local tableEnd = string.find(source, "\n\t}", tableStart, true)
	if not tableEnd then
		error("Could not find the end of V80_mutatingActions table. Refresh the Studio mirror before another Phase 13 patch.")
	end

	local cockpitLineStart = string.find(source, "BuyCockpit = true,", tableStart, true)
	if cockpitLineStart and cockpitLineStart < tableEnd then
		local lineEnd = string.find(source, "\n", cockpitLineStart, true)
		return string.sub(source, 1, lineEnd) .. "\t\tBuyGarageProperty = true,\n" .. string.sub(source, lineEnd + 1), true
	end

	local startLineEnd = string.find(source, "\n", tableStart, true)
	return string.sub(source, 1, startLineEnd) .. "\t\tBuyGarageProperty = true,\n" .. string.sub(source, startLineEnd + 1), true
end

local garage = waitPath(ServerScriptService, "NeoTokyoRacers", "Services", "Garage", "GarageActionController_Shadow_Disabled")
assert(garage:IsA("Script"), "GarageActionController_Shadow_Disabled must be a Script.")

local source = garage.Source
assert(string.find(source, "NTR_PERSISTENCE_PHASE7_GARAGE_CAPACITY_UPGRADE", 1, true), "Run Persistence Phase 7 before Phase 13 repair.")

local changed = false

if not string.find(source, "OwnedGarageProperties = {}", 1, true) then
	source = replaceOnce(source, [[			GarageCapacity = 2,
			ModuleUpgradeLevels = {},
]], [[			GarageCapacity = 2,
			-- NTR_PERSISTENCE_PHASE13_GARAGE_PROPERTIES
			OwnedGarageProperties = {},
			ModuleUpgradeLevels = {},
]], "garage default owned properties")
	changed = true
end

if not string.find(source, "profile.OwnedGarageProperties = typeof(profile.OwnedGarageProperties)", 1, true) then
	source = replaceOnce(source, [[		profile.GarageCapacity = math.max(1, math.floor(tonumber(profile.GarageCapacity) or 2))
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
]], [[		profile.GarageCapacity = math.max(1, math.floor(tonumber(profile.GarageCapacity) or 2))
		profile.OwnedGarageProperties = typeof(profile.OwnedGarageProperties) == "table" and profile.OwnedGarageProperties or {}
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
]], "garage normalize owned properties")
	changed = true
end

local didInsert
source, didInsert = ensureMirrorMutatingAction(source)
changed = changed or didInsert

if not string.find(source, "local V83_cachedGarageCatalog = nil", 1, true) then
	source = replaceOnce(source, [[	local function V82_profileGarageCapacity(profile)
		local capacity = tonumber(profile and profile.GarageCapacity) or V81_garageCapacity()
		return math.max(1, math.floor(capacity))
	end

	local function V82_maxGarageCapacity()
		return math.max(1, math.floor(tonumber(V82_persistenceConfigAttribute("MaxGarageCapacity", 10)) or 10))
	end
]], [[	local V83_cachedGarageCatalog = nil

	local function V83_garageCatalog()
		if V83_cachedGarageCatalog then
			return V83_cachedGarageCatalog
		end
		local shared = V56_kit:FindFirstChild("Shared")
		local modules = shared and shared:FindFirstChild("Modules")
		local data = modules and modules:FindFirstChild("Data")
		local catalogModule = data and data:FindFirstChild("GaragePropertyCatalog")
		if catalogModule and catalogModule:IsA("ModuleScript") then
			local ok, result = pcall(require, catalogModule)
			if ok and typeof(result) == "table" then
				V83_cachedGarageCatalog = result
				return result
			end
		end
		return nil
	end

	local function V83_garageProperties()
		local catalogModule = V83_garageCatalog()
		if catalogModule and typeof(catalogModule.List) == "function" then
			local ok, properties = pcall(catalogModule.List)
			if ok and typeof(properties) == "table" then
				return properties
			end
		end
		return {}
	end

	local function V83_propertyById(propertyId)
		propertyId = tostring(propertyId or "")
		local catalogModule = V83_garageCatalog()
		if catalogModule and typeof(catalogModule.ById) == "function" then
			local ok, property = pcall(catalogModule.ById, propertyId)
			if ok and typeof(property) == "table" then
				return property
			end
		end
		for _, property in ipairs(V83_garageProperties()) do
			if tostring(property.PropertyId) == propertyId then
				return property
			end
		end
		return nil
	end

	local function V83_startingGarageCapacity()
		return math.max(1, math.floor(tonumber(V82_persistenceConfigAttribute("StartingGarageCapacity", 2)) or 2))
	end

	local function V83_ownedGarageProperties(profile)
		profile.OwnedGarageProperties = typeof(profile.OwnedGarageProperties) == "table" and profile.OwnedGarageProperties or {}
		return profile.OwnedGarageProperties
	end

	local function V83_isGaragePropertyOwned(profile, propertyId)
		local owned = V83_ownedGarageProperties(profile)
		return owned[tostring(propertyId or "")] ~= nil
	end

	local function V83_ownedGaragePropertySpaces(profile)
		local spaces = 0
		for propertyId in pairs(V83_ownedGarageProperties(profile)) do
			local property = V83_propertyById(propertyId)
			if property then
				spaces += math.max(0, math.floor(tonumber(property.Spaces) or 0))
			end
		end
		return spaces
	end

	local function V83_totalCatalogGarageCapacity()
		local capacity = V83_startingGarageCapacity()
		for _, property in ipairs(V83_garageProperties()) do
			if property.Available == true then
				capacity += math.max(0, math.floor(tonumber(property.Spaces) or 0))
			end
		end
		return math.max(V83_startingGarageCapacity(), capacity)
	end

	local function V83_backfillLegacyGarageCapacity(profile)
		local legacyCapacity = math.max(V83_startingGarageCapacity(), math.floor(tonumber(profile and profile.GarageCapacity) or V83_startingGarageCapacity()))
		local owned = V83_ownedGarageProperties(profile)
		local current = V83_startingGarageCapacity() + V83_ownedGaragePropertySpaces(profile)
		if current >= legacyCapacity then
			return
		end
		for _, property in ipairs(V83_garageProperties()) do
			local propertyId = tostring(property.PropertyId or "")
			if property.Available == true and propertyId ~= "" and owned[propertyId] == nil then
				owned[propertyId] = {
					TemplateId = propertyId,
					DisplayName = tostring(property.DisplayName or propertyId),
					Spaces = math.max(1, math.floor(tonumber(property.Spaces) or 1)),
					AcquiredAtUnix = 0,
					Source = "LegacyCapacityBridge",
				}
				current += math.max(0, math.floor(tonumber(property.Spaces) or 0))
				if current >= legacyCapacity then
					break
				end
			end
		end
	end

	local function V82_profileGarageCapacity(profile)
		if profile then
			V83_backfillLegacyGarageCapacity(profile)
		end
		local propertyCapacity = V83_startingGarageCapacity() + V83_ownedGaragePropertySpaces(profile or {})
		local legacyCapacity = tonumber(profile and profile.GarageCapacity) or V81_garageCapacity()
		return math.max(V83_startingGarageCapacity(), math.floor(propertyCapacity), math.floor(legacyCapacity or 0))
	end

	local function V82_maxGarageCapacity()
		local configured = math.max(1, math.floor(tonumber(V82_persistenceConfigAttribute("MaxGarageCapacity", 10)) or 10))
		return math.min(configured, V83_totalCatalogGarageCapacity())
	end
]], "garage property helper block")
	changed = true
end

if not string.find(source, "function V83_buyGarageProperty", 1, true) then
	source = replaceOnce(source, [[	local function V82_upgradeGarageCapacity(profile)
		if not profile then
			return false, "Garage profile missing."
		end
		profile.GarageCapacity = V82_profileGarageCapacity(profile)
		local maxCapacity = V82_maxGarageCapacity()
		if profile.GarageCapacity >= maxCapacity then
			return false, "Garage capacity is already maxed."
		end
		local price = V82_capacityUpgradePrice(profile)
		if (profile.Cash or 0) < price then
			return false, "Not enough cash."
		end
		profile.Cash -= price
		profile.GarageCapacity = math.min(maxCapacity, profile.GarageCapacity + V82_capacityUpgradeStep())
		return true, "Garage capacity upgraded."
	end
]], [[	local function V83_nextBuyableGarageProperty(profile)
		for _, property in ipairs(V83_garageProperties()) do
			local propertyId = tostring(property.PropertyId or "")
			if property.Available == true and propertyId ~= "" and not V83_isGaragePropertyOwned(profile, propertyId) then
				return property
			end
		end
		return nil
	end

	local function V83_nextGaragePropertyPrice(profile)
		local property = V83_nextBuyableGarageProperty(profile)
		return property and math.max(0, math.floor(tonumber(property.Price) or V82_capacityUpgradePrice(profile))) or nil
	end

	local function V83_buyGarageProperty(profile, args)
		if not profile then
			return false, "Garage profile missing."
		end
		args = typeof(args) == "table" and args or {}
		local propertyId = tostring(args.PropertyId or "")
		local property = V83_propertyById(propertyId)
		if not property then
			return false, "Garage property is not available."
		end
		if property.Available ~= true then
			return false, "This garage location is not for sale yet."
		end
		if V83_isGaragePropertyOwned(profile, propertyId) then
			return false, "You already own this garage."
		end
		local maxCapacity = V82_maxGarageCapacity()
		if V82_profileGarageCapacity(profile) >= maxCapacity then
			return false, "Garage collection is already at the current maximum."
		end
		local price = math.max(0, math.floor(tonumber(property.Price) or V82_capacityUpgradePrice(profile)))
		if (profile.Cash or 0) < price then
			return false, "Not enough cash."
		end
		profile.Cash -= price
		V83_ownedGarageProperties(profile)[propertyId] = {
			TemplateId = propertyId,
			DisplayName = tostring(property.DisplayName or propertyId),
			District = tostring(property.District or ""),
			Spaces = math.max(1, math.floor(tonumber(property.Spaces) or 1)),
			AcquiredAtUnix = os.time(),
			Source = "BuyGarageProperty",
		}
		profile.GarageCapacity = V82_profileGarageCapacity(profile)
		return true, "Garage property purchased."
	end

	local function V82_upgradeGarageCapacity(profile)
		local property = V83_nextBuyableGarageProperty(profile)
		if not property then
			return false, "No garage properties are available right now."
		end
		return V83_buyGarageProperty(profile, { PropertyId = property.PropertyId })
	end
]], "garage BuyGarageProperty implementation")
	changed = true
end

if not string.find(source, "OwnedGarageProperties = V83_ownedGarageProperties(profile)", 1, true) then
	source = replaceOnce(source, [[			Garage = {
				Capacity = V82_profileGarageCapacity(profile),
				MaxCapacity = V82_maxGarageCapacity(),
				NextCapacityUpgradePrice = V82_capacityUpgradePrice(profile),
				OwnedVehicleCount = V81_ownedCockpitCount(profile),
			},
]], [[			Garage = {
				Capacity = V82_profileGarageCapacity(profile),
				MaxCapacity = V82_maxGarageCapacity(),
				NextCapacityUpgradePrice = V83_nextGaragePropertyPrice(profile) or V82_capacityUpgradePrice(profile),
				NextGaragePropertyPrice = V83_nextGaragePropertyPrice(profile),
				OwnedVehicleCount = V81_ownedCockpitCount(profile),
				OwnedGarageProperties = V83_ownedGarageProperties(profile),
			},
]], "garage profile response property data")
	changed = true
end

if not string.find(source, 'action == "BuyGarageProperty"', 1, true) then
	source = replaceOnce(source, [[			elseif action == "UpgradeGarageCapacity" then
				ok, message = V82_upgradeGarageCapacity(profile)
				V56_setLeaderstats(player, profile)
			elseif action == "BuyCockpit" then
]], [[			elseif action == "BuyGarageProperty" then
				ok, message = V83_buyGarageProperty(profile, args)
				V56_setLeaderstats(player, profile)
			elseif action == "UpgradeGarageCapacity" then
				ok, message = V82_upgradeGarageCapacity(profile)
				V56_setLeaderstats(player, profile)
			elseif action == "BuyCockpit" then
]], "garage BuyGarageProperty action")
	changed = true
end

garage.Source = source
garage:SetAttribute("PersistencePhase13GaragePropertyOwnershipRepair", true)

local clientRoot = waitPath(StarterPlayer, "StarterPlayerScripts", "NeoTokyoRacersClient")
local bootstrap = waitPath(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local bootstrapSource = bootstrap.Source
assert(string.find(bootstrapSource, "NTR_PERSISTENCE_PHASE12_GARAGE_MENU_CONTROLLER", 1, true), "Run and test Persistence Phase 12 before Phase 13 repair.")
if not string.find(bootstrapSource, "NTR_PERSISTENCE_PHASE13_GARAGE_PROPERTIES", 1, true) then
	bootstrapSource = replaceOnce(bootstrapSource, [[		UI = UI,
		Theme = Theme,
		kit = kit,
]], [[		UI = UI,
		Theme = Theme,
		kit = kit,
		-- NTR_PERSISTENCE_PHASE13_GARAGE_PROPERTIES
		State = State,
]], "client garage menu context state")
	bootstrap.Source = bootstrapSource
	changed = true
end

local menuController = waitPath(clientRoot, "Controllers", "UI", "GaragePropertyMenuController")
assert(menuController:IsA("ModuleScript"), "GaragePropertyMenuController must be a ModuleScript.")
menuController.Source = [=[
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
]=]
menuController:SetAttribute("PersistencePhase13GaragePropertyOwnershipRepair", true)
changed = true

assert(string.find(garage.Source, "BuyGarageProperty = true", 1, true), "Repair did not add BuyGarageProperty to mirror mutating actions.")
assert(string.find(garage.Source, 'action == "BuyGarageProperty"', 1, true), "Repair did not add BuyGarageProperty action.")
assert(string.find(garage.Source, "OwnedGarageProperties = V83_ownedGarageProperties(profile)", 1, true), "Repair did not expose OwnedGarageProperties in profile response.")
assert(string.find(bootstrap.Source, "State = State", 1, true), "Repair did not pass State to GaragePropertyMenuController.")
assert(string.find(menuController.Source, 'ctx.callServer("BuyGarageProperty"', 1, true), "Repair did not switch GaragePropertyMenuController to BuyGarageProperty.")

if changed then
	info("PASS: completed missing Phase 13 server/client source patches.")
else
	info("PASS: Phase 13 server/client source patches were already complete.")
end
info("Next: enter Play mode and run scripts/roblox_persistence_phase13_garage_property_ownership_client_smoke.lua from the CLIENT Command Bar.")
