-- Neo Tokyo Racers - Dealership / Customisation Split Phase 5
-- Customise wording plus shared cockpit menu images.
--
-- Run in Roblox Studio Command Bar while in Edit mode.
--
-- This uses guarded source-text patches against the active dealership bootstrap
-- and isolated free-roam nav controller. If either source shape has drifted from
-- the confirmed Phase 4 / Free Roam Map Stack shape, the script stops rather
-- than guessing.

local MARKER = "NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE5_COCKPIT_MENU_IMAGES"

local function info(message)
	print("[NTR Dealership/Customisation Phase 5] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceOnce(source, old, new, label)
	local startIndex, endIndex = string.find(source, old, 1, true)
	assert(startIndex, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
	return string.sub(source, 1, startIndex - 1) .. new .. string.sub(source, endIndex + 1), 1
end

local function countPlain(source, needle)
	local count = 0
	local index = 1
	while true do
		local startIndex, endIndex = string.find(source, needle, index, true)
		if not startIndex then break end
		count += 1
		index = endIndex + 1
	end
	return count
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local assets = kit:WaitForChild("Assets")
local vehicleAssets = assets:WaitForChild("Vehicles")
local categoriesRoot = vehicleAssets:WaitForChild("Categories")

local function ensureCockpitMenuImageAttributes()
	local count = 0
	for _, category in ipairs(categoriesRoot:GetChildren()) do
		local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
		if root then
			for _, cockpit in ipairs(root:GetChildren()) do
				if cockpit:IsA("Model") then
					if cockpit:GetAttribute("MenuImage") == nil then
						cockpit:SetAttribute("MenuImage", "")
						count += 1
					end
				end
			end
		end
	end
	info("Ensured MenuImage attribute on " .. tostring(count) .. " cockpit model(s) that did not already have it.")
end

local function activeBootstrap()
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local root = playerScripts:WaitForChild("NeoTokyoRacersClient")
	local scriptObject = root:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
	assert(scriptObject:IsA("LocalScript"), "Active bootstrap path is not a LocalScript.")
	return scriptObject
end

local function activeGarageServer()
	local services = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
	local garage = services:WaitForChild("Garage")
	local scriptObject = garage:WaitForChild("GarageActionController_Shadow_Disabled")
	assert(scriptObject:IsA("Script"), "Active garage action controller path is not a Script.")
	return scriptObject
end

local function activeFreeRoamNav()
	local playerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
	local root = playerScripts:WaitForChild("NeoTokyoRacersClient")
	local controllers = root:WaitForChild("Controllers")
	local ui = controllers:WaitForChild("UI")
	local scriptObject = ui:WaitForChild("FreeRoamNavController_Active")
	assert(scriptObject:IsA("LocalScript"), "FreeRoamNavController_Active path is not a LocalScript.")
	return scriptObject
end

local function auditGarageCatalogMenuImageFlow()
	local scriptObject = activeGarageServer()
	local source = scriptObject.Source
	assert(findPlain(source, [=[local item = V56_primitiveAttributes(cockpit)]=]), "Garage catalog no longer appears to copy cockpit primitive attributes; inspect before using MenuImage.")
	info("Garage catalog already copies primitive cockpit attributes, so MenuImage will flow to dealership/customisation cards without a server source patch.")
end

local function patchBootstrap()
	local scriptObject = activeBootstrap()
	local source = scriptObject.Source
	local changed = false
	assert(
		findPlain(source, [=[local function vehicleRatingParts(vehicleId)]=])
			and findPlain(source, [=[local function tierBadgeColor(tier)]=])
			and (
				findPlain(source, [=[		local customiseButton = button(UI.StatsPanel, "Build Modules",]=])
				or findPlain(source, [=[		local customiseButton = button(UI.StatsPanel, "Customise",]=])
			),
		"Run/confirm Phase 4 before Phase 5; the expected rating badge / Build Modules client shape was not found."
	)

	local oldButtonLabel = [=[		local customiseButton = button(UI.StatsPanel, "Build Modules", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)]=]
	local newButtonLabel = [=[		local customiseButton = button(UI.StatsPanel, "Customise", UDim2.new(1, 0, 0, UserInputService.TouchEnabled and 58 or 76), UDim2.new(0, 0, 1, UserInputService.TouchEnabled and -70 or -88), Theme.Buy)]=]
	if findPlain(source, oldButtonLabel) then
		source = replaceOnce(source, oldButtonLabel, newButtonLabel, "customisation-zone button label")
		changed = true
		info("Renamed customisation-zone action button to Customise.")
	elseif findPlain(source, newButtonLabel) then
		info("Customisation-zone action button already says Customise.")
	else
		error("Could not find the customisation-zone button label. Refresh the Studio mirror before creating another patch.")
	end

	local helper = [=[
-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE5_COCKPIT_MENU_IMAGES
local function NTR_phase5AssetImage(value)
	local text = tostring(value or "")
	if text == "" then return "" end
	if string.find(text, "rbxassetid://", 1, true) or string.find(text, "rbxthumb://", 1, true) then
		return text
	end
	if tonumber(text) then
		return "rbxassetid://" .. text
	end
	return text
end

local function NTR_phase5CockpitMenuImage(cockpit)
	return NTR_phase5AssetImage(cockpit and (cockpit.MenuImage or cockpit.ThumbnailImage or cockpit.ImageId or cockpit.Image) or "")
end

local function NTR_phase5RenderCockpitMenuImage(card, cockpit)
	local icon = new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 27, 31), Size = UDim2.new(1, -18, 0, 42), Position = UDim2.fromOffset(9, 9), BorderSizePixel = 0, ClipsDescendants = true }, card)
	icon:SetAttribute("PooledDynamic", true)
	corner(icon, 4)
	stroke(icon, Theme.Accent, 0.75, 1)
	local imageId = NTR_phase5CockpitMenuImage(cockpit)
	if imageId ~= "" then
		local image = new("ImageLabel", { BackgroundTransparency = 1, Image = imageId, ScaleType = Enum.ScaleType.Fit, Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), BorderSizePixel = 0 }, icon)
		image:SetAttribute("PooledDynamic", true)
	else
		local carShape = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromOffset(72, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55) }, icon)
		carShape:SetAttribute("PooledDynamic", true)
		corner(carShape, 3)
	end
end

]=]

	if not findPlain(source, [=[local function NTR_phase5RenderCockpitMenuImage(card, cockpit)]=]) then
		source = replaceOnce(source, [=[renderCockpitShop = function()]=], helper .. [=[renderCockpitShop = function()]=], "cockpit menu image helpers")
		changed = true
		info("Inserted cockpit MenuImage render helpers.")
	else
		info("Cockpit MenuImage render helpers already exist.")
	end

	local oldVisual = [=[			local icon = new("Frame", { BackgroundColor3 = Color3.fromRGB(18, 27, 31), Size = UDim2.new(1, -18, 0, 42), Position = UDim2.fromOffset(9, 9), BorderSizePixel = 0 }, card)
			icon:SetAttribute("PooledDynamic", true)
			corner(icon, 4)
			stroke(icon, Theme.Accent, 0.75, 1)
			local carShape = new("Frame", { BackgroundColor3 = Theme.Accent, BorderSizePixel = 0, Size = UDim2.fromOffset(72, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55) }, icon)
			corner(carShape, 3)]=]
	local customVisual = [=[			NTR_phase5RenderCockpitMenuImage(card, row.Cockpit)]=]
	local dealershipVisual = [=[			NTR_phase5RenderCockpitMenuImage(card, cockpit)]=]
	local visualCount = countPlain(source, oldVisual)
	if visualCount > 0 then
		source = replaceOnce(source, oldVisual, customVisual, "customisation cockpit card image renderer")
		changed = true
		if countPlain(source, oldVisual) > 0 then
			source = replaceOnce(source, oldVisual, dealershipVisual, "dealership cockpit card image renderer")
			changed = true
		end
		info("Replaced " .. tostring(visualCount) .. " cockpit card fallback renderer(s) with MenuImage render calls.")
	elseif findPlain(source, customVisual) and findPlain(source, dealershipVisual) then
		info("Cockpit card MenuImage render calls already exist.")
	else
		error("Could not find the cockpit card visual renderers. Refresh the Studio mirror before creating another patch.")
	end

	if changed then
		scriptObject.Source = source
		info("Patched dealership/customisation cards to use cockpit MenuImage.")
	else
		info("Dealership/customisation bootstrap already had all Phase 5 changes.")
	end
end

local function patchFreeRoam()
	local scriptObject = activeFreeRoamNav()
	local source = scriptObject.Source
	local changed = false
	assert(
		findPlain(source, [=[local function makeStackButton(parent, name, iconValueName, fallbackText, callback, fullWidth)]=])
			and findPlain(source, [=[stack.Name = "MapStack"]=])
			and findPlain(source, [=[player:SetAttribute("NTR_FreeRoamMapStackReady", true)]=]),
		"FreeRoamNavController_Active is not the expected map-stack controller."
	)

	local helper = [=[

-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE5_COCKPIT_MENU_IMAGES
local function currentCockpitMenuImage()
	local profile = readProfile() or {}
	local cockpitId = ""
	if profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId] then
		local vehicle = profile.Vehicles[profile.CurrentVehicleId]
		if vehicle.CockpitId then
			cockpitId = tostring(vehicle.CockpitId)
		elseif vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId] then
			cockpitId = tostring(profile.OwnedCockpitInstances[vehicle.CockpitInstanceId].TemplateId or "")
		end
	end
	if cockpitId == "" then
		cockpitId = tostring(profile.CurrentCockpit or profile.SelectedCockpit or "")
	end
	if cockpitId == "" then return "" end

	local vehicles = kit:FindFirstChild("Assets") and kit.Assets:FindFirstChild("Vehicles")
	local categories = vehicles and vehicles:FindFirstChild("Categories")
	if not categories then return "" end
	for _, category in ipairs(categories:GetChildren()) do
		local root = category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS")
		if root then
			for _, cockpit in ipairs(root:GetChildren()) do
				if cockpit:IsA("Model") and tostring(cockpit:GetAttribute("CockpitId") or cockpit.Name) == cockpitId then
					return assetImage(cockpit:GetAttribute("MenuImage") or cockpit:GetAttribute("ThumbnailImage") or cockpit:GetAttribute("ImageId") or cockpit:GetAttribute("Image") or "")
				end
			end
		end
	end
	return ""
end

local function ensureImageIcon(button, scale)
	local icon = button and button:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then return icon end
	if not button then return nil end
	icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Size = UDim2.fromOffset(32, 32)
	icon:SetAttribute("NTRIconScale", scale or 0.48)
	icon.ZIndex = button.ZIndex + 3
	icon.Parent = button
	return icon
end

local function updateCarButtonImage()
	if not carButton then return end
	local imageId = currentCockpitMenuImage()
	if imageId == "" then
		imageId = assetImage(readString(config, "CarIcon", ""))
	end
	local fallback = carButton:FindFirstChild("Fallback")
	if imageId ~= "" then
		local icon = ensureImageIcon(carButton, 0.48)
		if icon then
			icon.Image = imageId
			icon.Visible = true
		end
		if fallback and fallback:IsA("GuiObject") then
			fallback.Visible = false
		end
	elseif fallback and fallback:IsA("GuiObject") then
		fallback.Visible = true
	end
end
]=]

	if not findPlain(source, [=[local function currentCockpitMenuImage()]=]) then
		source = replaceOnce(source, [=[local function attachIcon(button, iconValueName, fallbackText, iconScale)]=], helper .. "\n\n" .. [=[local function attachIcon(button, iconValueName, fallbackText, iconScale)]=], "free-roam cockpit image helpers")
		changed = true
		info("Inserted free-roam current cockpit image helpers.")
	else
		info("Free-roam cockpit image helpers already exist.")
	end

	local oldRefresh = [=[	carButton.Size = UDim2.fromOffset(stackW, carH)
	layoutButtonIcon(carButton)]=]
	local newRefresh = [=[	carButton.Size = UDim2.fromOffset(stackW, carH)
	updateCarButtonImage()
	layoutButtonIcon(carButton)]=]
	if findPlain(source, oldRefresh) then
		source = replaceOnce(source, oldRefresh, newRefresh, "free-roam car image refresh")
		changed = true
		info("Hooked free-roam car button layout to refresh the cockpit image.")
	elseif findPlain(source, newRefresh) then
		info("Free-roam car button image refresh already exists.")
	else
		error("Could not find the free-roam car button layout refresh. Refresh the Studio mirror before creating another patch.")
	end

	if changed then
		scriptObject.Source = source
		info("Patched free-roam car button to prefer the current cockpit MenuImage.")
	else
		info("Free-roam nav already had all Phase 5 changes.")
	end
end

ensureCockpitMenuImageAttributes()
auditGarageCatalogMenuImageFlow()
patchBootstrap()
patchFreeRoam()

info("Install complete. Set a cockpit model's MenuImage attribute to rbxassetid://... and restart Play to verify dealership, customisation, and free-roam use the same image.")
