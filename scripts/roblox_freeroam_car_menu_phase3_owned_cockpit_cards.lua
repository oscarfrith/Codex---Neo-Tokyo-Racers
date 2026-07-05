-- Neo Tokyo Racers - Free Roam Car Menu Phase 3
-- Owned cockpit cards in the free-roam car pop-out.
--
-- This is a guarded source patch against the isolated
-- FreeRoamNavController_Active LocalScript. It does not patch the large
-- dealership/customisation bootstrap. If an anchor is missing, refresh the
-- Studio mirror before creating another patch.

local PHASE = "NTR Free Roam Car Menu Phase 3 Owned Cockpit Cards"
local MARKER = "NTR_FREEROAM_CAR_MENU_PHASE3_OWNED_COCKPIT_CARDS"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local function info(message)
	print("[" .. PHASE .. "] " .. message)
end

local function escapePattern(text)
	return text:gsub("([^%w])", "%%%1")
end

local function replaceOnce(source, old, new, label)
	local nextSource, count = string.gsub(source, escapePattern(old), new, 1)
	assert(count == 1, "Could not replace " .. label)
	return nextSource
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, existing:GetFullName() .. " must be a " .. className)
		return existing
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function ensureNumber(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new("NumberValue")
		item.Name = name
		item.Value = value
		item.Parent = parent
	end
	assert(item:IsA("NumberValue"), item:GetFullName() .. " must be a NumberValue")
	return item
end

local function activeFreeRoamNav()
	local starterScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local root = starterScripts:WaitForChild("NeoTokyoRacersClient")
	local controllers = root:WaitForChild("Controllers")
	local ui = controllers:WaitForChild("UI")
	local scriptObject = ui:WaitForChild("FreeRoamNavController_Active")
	assert(scriptObject:IsA("LocalScript"), "FreeRoamNavController_Active path is not a LocalScript.")
	return scriptObject
end

local function ensureConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local configRoot = ensureChild(kit, "Folder", "Config")
	local uiRoot = ensureChild(configRoot, "Folder", "UI")
	local nav = ensureChild(uiRoot, "Folder", "FreeRoamNav")

	ensureNumber(nav, "CarPanelWidthDesktop", 392)
	ensureNumber(nav, "CarPanelWidthTouch", 196)
	ensureNumber(nav, "CarPanelMinWidthDesktop", 320)
	ensureNumber(nav, "CarPanelMinWidthTouch", 168)
	ensureNumber(nav, "CarPanelCardGap", 8)
	ensureNumber(nav, "CarPanelPadding", 8)
	ensureNumber(nav, "CarPanelBottomPadding", 8)
	ensureNumber(nav, "CarPanelDespawnHeight", 34)
	ensureNumber(nav, "CarPanelDesktopColumns", 2)
	ensureNumber(nav, "CarPanelMobileColumns", 1)
	ensureNumber(nav, "CarPanelMaxCardWidthDesktop", 184)
	ensureNumber(nav, "CarPanelMaxCardWidthTouch", 180)
	ensureNumber(nav, "CarPanelImageToTextGap", 6)
	ensureNumber(nav, "CarPanelCardBottomPadding", 7)

	info("Ensured FreeRoamNav car-panel tuning values.")
end

ensureConfig()

local scriptObject = activeFreeRoamNav()
local source = scriptObject.Source

if findPlain(source, MARKER) then
	info("Phase 3 marker already present; no source changes needed.")
	return
end

assert(findPlain(source, "-- NTR Free Roam Map Stack Phase 2"), "Expected Free Roam Map Stack Phase 2 source.")
assert(findPlain(source, "local cachedProfile = nil"), "Could not find cachedProfile anchor.")
assert(findPlain(source, "local function showActionPanel(kind)"), "Could not find showActionPanel.")
assert(findPlain(source, "local function updateLayout()"), "Could not find updateLayout.")

source = replaceOnce(source, "-- NTR Free Roam Map Stack Phase 2", "-- NTR Free Roam Map Stack Phase 2\n-- " .. MARKER, "Phase 3 marker")
source = replaceOnce(source, "local cachedProfile = nil\nlocal lastProfileRead = 0", "local cachedProfile = nil\nlocal cachedCatalog = nil\nlocal lastProfileRead = 0", "cached catalog state")

local readProfileOld = [=[
local function readProfile()
	if cachedProfile and os.clock() - lastProfileRead < 2 then
		return cachedProfile
	end
	local ok, result = pcall(function()
		return garageInvoke:InvokeServer("GetInitial", {})
	end)
	lastProfileRead = os.clock()
	if ok and type(result) == "table" then
		cachedProfile = result.Profile or result
		return cachedProfile
	end
	return nil
end
]=]

local readProfileNew = [=[
local function readProfile()
	if cachedProfile and os.clock() - lastProfileRead < 2 then
		return cachedProfile
	end
	local ok, result = pcall(function()
		return garageInvoke:InvokeServer("GetInitial", {})
	end)
	lastProfileRead = os.clock()
	if ok and type(result) == "table" then
		cachedProfile = result.Profile or result
		cachedCatalog = result.Catalog or cachedCatalog
		return cachedProfile
	end
	return nil
end
]=]

source = replaceOnce(source, readProfileOld, readProfileNew, "profile/catalog read cache")

local helperBlock = [=[

-- NTR_FREEROAM_CAR_MENU_PHASE3_HELPERS
local function carPanelNumber(name, fallback)
	return readNumber(config, name, fallback)
end

local function carPanelCardConfigNumber(name, fallback)
	local configRoot = kit:FindFirstChild("Config")
	local ui = configRoot and configRoot:FindFirstChild("UI")
	local cards = ui and ui:FindFirstChild("CockpitMenuCards")
	local item = cards and cards:FindFirstChild(name)
	return item and item:IsA("NumberValue") and item.Value or fallback
end

local function carPanelCockpitIdForVehicle(profile, vehicle)
	local cockpitInstance = vehicle and vehicle.CockpitInstanceId and profile and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
	return cockpitInstance and tostring(cockpitInstance.TemplateId or "") or tostring((vehicle and vehicle.CockpitId) or "")
end

local function carPanelVehicleRatingParts(profile, vehicleId)
	local summary = profile and profile.VehicleSummaries and profile.VehicleSummaries[vehicleId]
	local overall = summary and summary.Overall or {}
	local tier = tostring(overall.Tier or "--")
	local index = tonumber(overall.PerformanceIndex)
	return tier, (index and tostring(math.floor(index)) or "---"), index or -math.huge
end

local function carPanelTierColor(tier)
	tier = string.upper(tostring(tier or ""))
	if tier == "S" then return Color3.fromRGB(224, 78, 255) end
	if tier == "A" then return Color3.fromRGB(178, 92, 255) end
	if tier == "B" then return Color3.fromRGB(79, 139, 238) end
	if tier == "C" then return Color3.fromRGB(71, 195, 202) end
	if tier == "D" then return Color3.fromRGB(93, 202, 126) end
	if tier == "E" then return Color3.fromRGB(145, 162, 171) end
	return theme.Accent
end

local function carPanelCatalogCockpit(cockpitId)
	cockpitId = tostring(cockpitId or "")
	if cockpitId == "" then return nil end
	for _, category in ipairs((cachedCatalog and cachedCatalog.Categories) or {}) do
		for _, cockpit in ipairs((category and category.Cockpits) or {}) do
			if tostring(cockpit.CockpitId or "") == cockpitId then
				return cockpit
			end
		end
	end
	return nil
end

local function carPanelReadImageObject(object)
	if not object then return "" end
	for _, name in ipairs({ "MenuImage", "CockpitImage", "ThumbnailImage", "ImageId", "Image" }) do
		local image = assetImage(object:GetAttribute(name))
		if image ~= "" then return image end
		local child = object:FindFirstChild(name)
		if child then
			if child:IsA("StringValue") then
				image = assetImage(child.Value)
			elseif child:IsA("Decal") or child:IsA("Texture") then
				image = assetImage(child.Texture)
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				image = assetImage(child.Image)
			end
			if image ~= "" then return image end
		end
	end
	for _, child in ipairs(object:GetDescendants()) do
		local lower = string.lower(child.Name)
		if string.find(lower, "menuimage", 1, true) or string.find(lower, "cockpitimage", 1, true) or string.find(lower, "thumbnail", 1, true) then
			local image = ""
			if child:IsA("StringValue") then
				image = assetImage(child.Value)
			elseif child:IsA("Decal") or child:IsA("Texture") then
				image = assetImage(child.Texture)
			elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
				image = assetImage(child.Image)
			end
			if image ~= "" then return image end
		end
	end
	return ""
end

local function carPanelCockpitModel(cockpitId)
	cockpitId = tostring(cockpitId or "")
	if cockpitId == "" then return nil end
	local vehicles = kit:FindFirstChild("Assets") and kit.Assets:FindFirstChild("Vehicles")
	local categories = vehicles and vehicles:FindFirstChild("Categories")
	if not categories then return nil end
	for _, category in ipairs(categories:GetChildren()) do
		local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
		if root then
			for _, cockpit in ipairs(root:GetDescendants()) do
				if cockpit:IsA("Model") then
					local candidateId = tostring(cockpit:GetAttribute("CockpitId") or cockpit.Name)
					if candidateId == cockpitId or cockpit.Name == cockpitId then
						return cockpit
					end
				end
			end
		end
	end
	return nil
end

local function carPanelCockpitImage(cockpitId, cockpit)
	local fromCatalog = assetImage(cockpit and (cockpit.MenuImage or cockpit.CockpitImage or cockpit.ThumbnailImage or cockpit.ImageId or cockpit.Image) or "")
	if fromCatalog ~= "" then return fromCatalog end
	local model = carPanelCockpitModel(cockpitId)
	local image = carPanelReadImageObject(model)
	if image ~= "" then return image end
	local current = model and model.Parent
	local vehicles = kit:FindFirstChild("Assets") and kit.Assets:FindFirstChild("Vehicles")
	local categories = vehicles and vehicles:FindFirstChild("Categories")
	while current and current ~= categories do
		image = carPanelReadImageObject(current)
		if image ~= "" then return image end
		current = current.Parent
	end
	return ""
end

local function carPanelCockpitName(cockpitId, cockpit)
	local model = carPanelCockpitModel(cockpitId)
	return tostring((cockpit and (cockpit.DisplayName or cockpit.Name or cockpit.CockpitId))
		or (model and (model:GetAttribute("DisplayName") or model.Name))
		or cockpitId
		or "Vehicle")
end

local function carPanelOwnedRows(profile)
	local rows = {}
	for vehicleId, vehicle in pairs((profile and profile.Vehicles) or {}) do
		local cockpitId = carPanelCockpitIdForVehicle(profile, vehicle)
		if cockpitId ~= "" then
			local cockpit = carPanelCatalogCockpit(cockpitId)
			local tier, ratingIndex, sortRating = carPanelVehicleRatingParts(profile, vehicleId)
			table.insert(rows, {
				VehicleId = vehicleId,
				CockpitId = cockpitId,
				Cockpit = cockpit,
				Name = carPanelCockpitName(cockpitId, cockpit),
				Image = carPanelCockpitImage(cockpitId, cockpit),
				Tier = tier,
				RatingIndex = ratingIndex,
				SortRating = sortRating,
				Selected = tostring(vehicleId) == tostring(profile and profile.CurrentVehicleId or ""),
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.Selected ~= b.Selected then
			return a.Selected
		end
		if a.SortRating ~= b.SortRating then
			return a.SortRating > b.SortRating
		end
		if a.Name == b.Name then
			return tostring(a.VehicleId) < tostring(b.VehicleId)
		end
		return a.Name < b.Name
	end)
	return rows
end

local function carPanelLayoutForWidth(width)
	local pad = math.max(4, carPanelCardConfigNumber("CardOuterPadding", 8))
	local imageSize = math.max(1, width - pad * 2)
	local nameH = touch and carPanelCardConfigNumber("MobileNameHeight", 16) or carPanelCardConfigNumber("DesktopNameHeight", 18)
	local nameY = pad + imageSize + carPanelNumber("CarPanelImageToTextGap", 6)
	local cardH = nameY + nameH + carPanelNumber("CarPanelCardBottomPadding", 7)
	return pad, imageSize, nameY, nameH, cardH
end

local function carPanelRenderCockpitCard(parent, row, width)
	local pad, imageSize, nameY, nameH, cardH = carPanelLayoutForWidth(width)
	local card = Instance.new("TextButton")
	card.Name = "VehicleCard_" .. tostring(row.VehicleId)
	card.AutoButtonColor = true
	card.BackgroundColor3 = row.Selected and theme.Selected or theme.Card
	card.BackgroundTransparency = row.Selected and 0.08 or theme.ButtonTransparency
	card.BorderSizePixel = 0
	card.Text = ""
	card.ClipsDescendants = true
	card.Size = UDim2.fromOffset(width, cardH)
	card.ZIndex = parent.ZIndex + 1
	card.Parent = parent
	corner(card, 6)
	stroke(card, row.Selected and carPanelTierColor(row.Tier) or readColor(config, "ButtonOutline", Color3.fromRGB(230, 88, 205)), row.Selected and 0.05 or 0.45, row.Selected and 1.6 or 1)

	local imageBox = Instance.new("Frame")
	imageBox.Name = "ImageBox"
	imageBox.BackgroundColor3 = Color3.fromRGB(18, 27, 31)
	imageBox.BorderSizePixel = 0
	imageBox.ClipsDescendants = true
	imageBox.Position = UDim2.fromOffset(pad, pad)
	imageBox.Size = UDim2.fromOffset(imageSize, imageSize)
	imageBox.ZIndex = card.ZIndex + 1
	imageBox.Parent = card
	corner(imageBox, carPanelCardConfigNumber("ImageCornerRadius", 4))
	stroke(imageBox, theme.Accent, 0.75, 1)

	if row.Image ~= "" then
		local inset = carPanelCardConfigNumber("ImageInnerPadding", 4)
		local zoom = math.clamp(carPanelCardConfigNumber("ImageZoom", 1), 0.5, 2)
		local image = Instance.new("ImageLabel")
		image.Name = "CockpitImage"
		image.BackgroundTransparency = 1
		image.Image = row.Image
		image.ScaleType = string.lower(tostring(readString(config, "CarPanelImageScaleType", "Fit"))) == "crop" and Enum.ScaleType.Crop or Enum.ScaleType.Fit
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.new(zoom, -inset * 2, zoom, -inset * 2)
		image.ZIndex = imageBox.ZIndex + 1
		image.Parent = imageBox
	else
		local fallback = Instance.new("Frame")
		fallback.Name = "FallbackBar"
		fallback.BackgroundColor3 = theme.Accent
		fallback.BorderSizePixel = 0
		fallback.AnchorPoint = Vector2.new(0.5, 0.5)
		fallback.Position = UDim2.fromScale(0.5, 0.5)
		fallback.Size = UDim2.fromOffset(math.min(72, imageSize * 0.58), math.max(10, imageSize * 0.12))
		fallback.ZIndex = imageBox.ZIndex + 1
		fallback.Parent = imageBox
		corner(fallback, 3)
	end

	local badgeW = math.max(46, math.floor(imageSize * 0.38 + 0.5))
	local badgeH = math.max(16, math.floor(imageSize * 0.14 + 0.5))
	local badge = Instance.new("Frame")
	badge.Name = "TierRatingBadge"
	badge.BackgroundColor3 = carPanelTierColor(row.Tier)
	badge.BackgroundTransparency = 0.02
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromOffset(pad + imageSize - badgeW - 5, pad + 5)
	badge.Size = UDim2.fromOffset(badgeW, badgeH)
	badge.ZIndex = imageBox.ZIndex + 4
	badge.Parent = card
	corner(badge, 4)
	local badgeText = makeLabel(badge, "Text", tostring(row.Tier) .. " " .. tostring(row.RatingIndex), UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), touch and 8 or 9, Color3.fromRGB(244, 250, 255))
	badgeText.ZIndex = badge.ZIndex + 1

	local name = makeLabel(card, "Name", row.Name, UDim2.new(1, -pad * 2, 0, nameH), UDim2.fromOffset(pad, nameY), touch and 9 or 10, theme.Text)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextWrapped = true
	name.ZIndex = card.ZIndex + 2

	card.MouseButton1Click:Connect(function()
		setStatus(row.Selected and "CURRENT VEHICLE" or "USE CUSTOMISATION ZONE TO SELECT", row.Selected)
	end)
	return card
end

local function carPanelLayoutExisting()
	if not actionBody then return end
	local scroll = actionBody:FindFirstChild("VehicleCards")
	local grid = scroll and scroll:FindFirstChild("Grid")
	local despawn = actionBody:FindFirstChild("DespawnVehicle")
	if not scroll or not grid then return end
	local panelW = math.max(1, actionPanel.AbsoluteSize.X)
	local panelH = math.max(1, actionPanel.AbsoluteSize.Y)
	local pad = carPanelNumber("CarPanelPadding", 8)
	local gap = carPanelNumber("CarPanelCardGap", 8)
	local bottomPad = carPanelNumber("CarPanelBottomPadding", 8)
	local buttonH = touch and math.max(32, carPanelNumber("CarPanelDespawnHeight", 34)) or carPanelNumber("CarPanelDespawnHeight", 34)
	local columns = touch and carPanelNumber("CarPanelMobileColumns", 1) or carPanelNumber("CarPanelDesktopColumns", 2)
	columns = math.max(1, math.floor(columns + 0.5))
	local rawCardW = math.floor((panelW - pad * 2 - gap * (columns - 1)) / columns)
	local maxCard = touch and carPanelNumber("CarPanelMaxCardWidthTouch", 180) or carPanelNumber("CarPanelMaxCardWidthDesktop", 184)
	local cardW = math.max(70, math.min(maxCard, rawCardW))
	local _, _, _, _, cardH = carPanelLayoutForWidth(cardW)
	scroll.Position = UDim2.fromOffset(pad, 0)
	scroll.Size = UDim2.fromOffset(math.max(1, panelW - pad * 2), math.max(1, panelH - buttonH - bottomPad * 2))
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.CellSize = UDim2.fromOffset(cardW, cardH)
	if despawn and despawn:IsA("GuiObject") then
		despawn.Position = UDim2.new(0, pad, 1, -(buttonH + bottomPad))
		despawn.Size = UDim2.new(1, -pad * 2, 0, buttonH)
	end
	task.defer(function()
		if scroll and scroll.Parent and grid and grid.Parent then
			scroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + gap)
		end
	end)
end

local function carPanelRender()
	if not actionBody then return end
	local profile = readProfile() or {}
	local rows = carPanelOwnedRows(profile)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "VehicleCards"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = touch and 3 or 4
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.ZIndex = actionBody.ZIndex + 1
	scroll.Parent = actionBody
	local grid = Instance.new("UIGridLayout")
	grid.Name = "Grid"
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	grid.VerticalAlignment = Enum.VerticalAlignment.Top
	grid.Parent = scroll

	if #rows == 0 then
		local empty = makeLabel(scroll, "Empty", "NO OWNED VEHICLES", UDim2.new(1, -8, 0, 40), UDim2.fromOffset(4, 6), touch and 9 or 10, theme.Muted)
		empty.LayoutOrder = 1
	else
		for index, row in ipairs(rows) do
			local card = carPanelRenderCockpitCard(scroll, row, 120)
			card.LayoutOrder = index
		end
	end

	makeActionButton(actionBody, "DespawnVehicle", "DESPAWN", 0, theme.Exit, exitVehicle)
	carPanelLayoutExisting()
end

local function carPanelSetChrome(enabled)
	if not actionTitle or not actionBody or not actionPanel then return end
	actionTitle.Visible = not enabled
	actionBody.Position = enabled and UDim2.fromOffset(0, 8) or UDim2.fromOffset(0, 42)
	actionBody.Size = enabled and UDim2.new(1, 0, 1, -14) or UDim2.new(1, 0, 1, -48)
	for _, name in ipairs({ "TopHighlight", "BottomShadow" }) do
		local item = actionPanel:FindFirstChild(name)
		if item and item:IsA("GuiObject") then
			item.Visible = not enabled
		end
	end
end
]=]

source = replaceOnce(source, "local function showActionPanel(kind)\n", helperBlock .. "\nlocal function showActionPanel(kind)\n", "Phase 3 helper block")

local showActionCarOld = [=[
	clearActionBody()
	if kind == "Car" then
		actionTitle.Text = "CAR"
		local profile = readProfile() or {}
		local vehicleId = tostring(profile.CurrentVehicleId or profile.SelectedVehicleId or profile.CurrentCockpit or profile.SelectedCockpit or "CURRENT BUILD")
		makeLabel(actionBody, "Current", vehicleId, UDim2.new(1, -16, 0, 42), UDim2.fromOffset(8, 0), 10, theme.Text)
		makeActionButton(actionBody, "ExitVehicle", "EXIT VEHICLE", 50, theme.Exit, exitVehicle)
		makeActionButton(actionBody, "Customise", "CUSTOMISE", 88, theme.Buy, openDealership)
	elseif kind == "Race" then
]=]

local showActionCarNew = [=[
	clearActionBody()
	carPanelSetChrome(kind == "Car")
	if kind == "Car" then
		actionTitle.Text = ""
		carPanelRender()
	elseif kind == "Race" then
]=]

source = replaceOnce(source, showActionCarOld, showActionCarNew, "car action panel contents")

local updateLayoutOld = [=[
	local panelW = math.max(touch and 164 or 190, math.min(touch and 212 or 244, stackW * 0.98))
	actionPanel.Position = UDim2.new(1, -(rightMargin + stackW + 8), 0, topMargin)
	actionPanel.Size = UDim2.fromOffset(panelW, totalH)
]=]

local updateLayoutNew = [=[
	local defaultPanelW = math.max(touch and 164 or 190, math.min(touch and 212 or 244, stackW * 0.98))
	local panelW = defaultPanelW
	if activePanel == "Car" and actionPanel.Visible then
		local desiredW = touch and carPanelNumber("CarPanelWidthTouch", 196) or carPanelNumber("CarPanelWidthDesktop", 392)
		local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", 168) or carPanelNumber("CarPanelMinWidthDesktop", 320)
		local maxAvailableW = math.max(minPanelW, viewport.X - rightMargin - stackW - 18)
		panelW = math.floor(math.clamp(desiredW, minPanelW, maxAvailableW))
	end
	actionPanel.Position = UDim2.new(1, -(rightMargin + stackW + 8), 0, topMargin)
	actionPanel.Size = UDim2.fromOffset(panelW, totalH)
	if activePanel == "Car" and actionPanel.Visible then
		carPanelLayoutExisting()
	end
]=]

source = replaceOnce(source, updateLayoutOld, updateLayoutNew, "car panel responsive width")

assert(findPlain(source, MARKER), "Phase 3 marker was not installed.")
assert(findPlain(source, "carPanelRender()"), "Car panel renderer was not installed.")
assert(findPlain(source, "DESPAWN"), "Despawn button was not installed.")

scriptObject.Source = source

info("Installed free-roam car menu cockpit cards.")
info("Car pop-out now shows owned cockpit cards, 2 columns on desktop/laptop and 1 on mobile.")
info("The old vehicle-id text, Exit Vehicle button, Customise button, and car-panel bevel bars are hidden for the Car panel.")
info("Restart Play, click the free-roam Car button, and verify the owned cards plus fixed Despawn button.")
