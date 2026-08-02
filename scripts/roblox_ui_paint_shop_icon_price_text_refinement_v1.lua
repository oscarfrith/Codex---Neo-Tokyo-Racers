-- Neo Tokyo Racers - Paint Shop underglow sidebar icon and price text refinement V1
-- NTR_PAINT_SHOP_ICON_PRICE_TEXT_REFINEMENT_V1
-- Run from the Roblox Studio Command Bar in EDIT mode.

local MODE = "INSTALL" -- INSTALL, AUDIT, or ROLLBACK

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this script in Edit mode, not Play mode")

local REVISION = "NTR_PAINT_SHOP_ICON_PRICE_TEXT_REFINEMENT_V1"
local TAG = "[NTR Paint Shop Icon/Price V1]"

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), "Missing " .. parent:GetFullName() .. "." .. name .. " (" .. className .. ")")
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function countPlain(source, needle)
	local count = 0
	local position = 1
	while true do
		local first, last = string.find(source, needle, position, true)
		if not first then return count end
		count += 1
		position = last + 1
	end
end

local function replaceOnce(source, before, after, label)
	local count = countPlain(source, before)
	assert(count == 1, label .. " expected exactly one source anchor, found " .. tostring(count))
	local first, last = string.find(source, before, 1, true)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local replacement = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")
local navigationIcons = need(replacement, "NavigationIcons", "Folder")
local cosmetics = need(replacement, "VehicleCosmetics", "Folder")
local underglowCosmetic = need(cosmetics, "Underglow", "Folder")

local starterScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = need(starterScripts, "NeoTokyoRacersClient", "Folder")
local ui = need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder")
local shared = need(ui, "GarageReplacementComponents", "ModuleScript")
local workspace = need(ui, "GarageWorkspaceController", "ModuleScript")
local application = need(ui, "ModuleShopUIController", "ModuleScript")

assert(string.find(shared.Source, "NTR_GARAGE_MODULE_CARD_VARIANTS_V3", 1, true), "Shared garage card baseline missing")
assert(string.find(workspace.Source, "NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1", 1, true), "Workspace card forwarding baseline missing")
assert(string.find(application.Source, "NTR_CUSTOMISATION_VEHICLE_COSMETIC_UI_V1", 1, true), "Vehicle cosmetic Paint Shop baseline missing")

local oldSharedBadge = [[	if props.Rating then local badge=Instance.new("Frame"); badge.Name="RatingBadge"; badge.AnchorPoint=Vector2.new(1,0); badge.Position=UDim2.new(1,-8,0,8); badge.Size=UDim2.fromOffset(68,21); badge.BackgroundColor3=props.RatingColor or accent; badge.BorderSizePixel=0; badge.ZIndex=card.ZIndex+6; badge.Parent=card; Racing.Corner(badge,4); local t=Racing.Label(badge,{Text=props.Rating,Size=UDim2.fromScale(1,1),TextSize=9,XAlignment=Enum.TextXAlignment.Center}); t.ZIndex=badge.ZIndex+1 end]]
local newSharedBadge = [[	-- NTR_PAINT_SHOP_ICON_PRICE_TEXT_REFINEMENT_V1
	if props.Rating then
		if props.RatingStyle=="TextOnlyPrice" then
			local price=Racing.Label(card,{Name="RatingPriceText",Text=tostring(props.Rating),Position=UDim2.new(1,-8,0,8),Size=UDim2.fromOffset(96,21),TextSize=13,Color=props.RatingColor or accent,XAlignment=Enum.TextXAlignment.Right,Truncate=Enum.TextTruncate.None,Role="Heading"}); price.AnchorPoint=Vector2.new(1,0); price.ZIndex=card.ZIndex+6
		else
			local badge=Instance.new("Frame"); badge.Name="RatingBadge"; badge.AnchorPoint=Vector2.new(1,0); badge.Position=UDim2.new(1,-8,0,8); badge.Size=UDim2.fromOffset(68,21); badge.BackgroundColor3=props.RatingColor or accent; badge.BorderSizePixel=0; badge.ZIndex=card.ZIndex+6; badge.Parent=card; Racing.Corner(badge,4); local t=Racing.Label(badge,{Text=props.Rating,Size=UDim2.fromScale(1,1),TextSize=9,XAlignment=Enum.TextXAlignment.Center}); t.ZIndex=badge.ZIndex+1
		end
	end]]

local oldWorkspaceForward = [[Rating=row.Badge,RatingColor=row.BadgeColor,Badge=row.Badge]]
local newWorkspaceForward = [[Rating=row.Badge,RatingColor=row.BadgeColor,RatingStyle=row.BadgeStyle,Badge=row.Badge]]

local oldSidebarIcon = [[Image=navIcon("UnderglowIcon"),ImageZoom=1.04,Selected=target=="UNDERGLOW"]]
local newSidebarIcon = [[Image=navIcon("UnderglowSidebarIcon"),ImageZoom=1.04,Selected=target=="UNDERGLOW"]]
local oldCosmeticPrice = [[Badge=Shared.FormatMoney(price),BadgeColor=affordable]]
local newCosmeticPrice = [[Badge=Shared.FormatMoney(price),BadgeStyle="TextOnlyPrice",BadgeColor=affordable]]
local oldNeonPrice = [[Badge=owned and "OWNED" or Shared.FormatMoney(price),
		BadgeColor=owned]]
local newNeonPrice = [[Badge=owned and "OWNED" or Shared.FormatMoney(price),
		BadgeStyle=owned and nil or "TextOnlyPrice",
		BadgeColor=owned]]

local sharedSource = shared.Source
local workspaceSource = workspace.Source
local applicationSource = application.Source

if MODE == "INSTALL" then
	if not string.find(sharedSource, REVISION, 1, true) then
		sharedSource = replaceOnce(sharedSource, oldSharedBadge, newSharedBadge, "shared text-only price renderer")
		workspaceSource = replaceOnce(workspaceSource, oldWorkspaceForward, newWorkspaceForward, "workspace badge-style forwarding")
		applicationSource = replaceOnce(applicationSource, oldSidebarIcon, newSidebarIcon, "sidebar-only underglow icon")
		applicationSource = replaceOnce(applicationSource, oldCosmeticPrice, newCosmeticPrice, "vehicle cosmetic text-only price")
		applicationSource = replaceOnce(applicationSource, oldNeonPrice, newNeonPrice, "module neon text-only price")
	else
		assert(string.find(workspaceSource, newWorkspaceForward, 1, true), "Installed shared card style forwarding is incomplete")
		assert(string.find(applicationSource, newSidebarIcon, 1, true), "Installed sidebar icon route is incomplete")
	end
elseif MODE == "ROLLBACK" then
	if string.find(sharedSource, REVISION, 1, true) then
		sharedSource = replaceOnce(sharedSource, newSharedBadge, oldSharedBadge, "rollback shared text-only price renderer")
		workspaceSource = replaceOnce(workspaceSource, newWorkspaceForward, oldWorkspaceForward, "rollback badge-style forwarding")
		applicationSource = replaceOnce(applicationSource, newSidebarIcon, oldSidebarIcon, "rollback sidebar icon route")
		applicationSource = replaceOnce(applicationSource, newCosmeticPrice, oldCosmeticPrice, "rollback vehicle cosmetic price")
		applicationSource = replaceOnce(applicationSource, newNeonPrice, oldNeonPrice, "rollback module neon price")
	end
else
	assert(MODE == "AUDIT", "MODE must be INSTALL, AUDIT, or ROLLBACK")
end

compile("GarageReplacementComponents_Projected", sharedSource)
compile("GarageWorkspaceController_Projected", workspaceSource)
compile("ModuleShopUIController_Projected", applicationSource)

local function audit(sShared, sWorkspace, sApplication, expectInstalled)
	local failures = {}
	local function expect(ok, message) if not ok then table.insert(failures, message) end end
	local sidebarIcon = navigationIcons:GetAttribute("UnderglowSidebarIcon")
	local purchaseIcon = underglowCosmetic:GetAttribute("Icon")
	if expectInstalled then
		expect(string.find(sShared, REVISION, 1, true) ~= nil, "shared price renderer marker missing")
		expect(countPlain(sShared, [[props.RatingStyle=="TextOnlyPrice"]]) == 1, "text-only price renderer is not singular")
		expect(countPlain(sWorkspace, [[RatingStyle=row.BadgeStyle]]) == 1, "badge style forwarding is not singular")
		expect(countPlain(sApplication, [[navIcon("UnderglowSidebarIcon")]]) == 1, "sidebar-only underglow icon route missing")
		expect(countPlain(sApplication, [[BadgeStyle="TextOnlyPrice"]]) == 1, "vehicle cosmetic price style missing")
		expect(countPlain(sApplication, [[BadgeStyle=owned and nil or "TextOnlyPrice"]]) == 1, "module neon price style missing")
		expect(type(sidebarIcon) == "string" and sidebarIcon ~= "", "UnderglowSidebarIcon config is empty")
		expect(type(purchaseIcon) == "string" and purchaseIcon ~= "", "VehicleCosmetics.Underglow.Icon changed or is empty")
	else
		expect(string.find(sShared, REVISION, 1, true) == nil, "shared price renderer marker remains after rollback")
		expect(string.find(sWorkspace, [[RatingStyle=row.BadgeStyle]], 1, true) == nil, "badge style forwarding remains after rollback")
		expect(string.find(sApplication, [[navIcon("UnderglowSidebarIcon")]], 1, true) == nil, "sidebar-only icon route remains after rollback")
	end
	if #failures > 0 then error(TAG .. " AUDIT FAIL: " .. table.concat(failures, " | "), 0) end
end

if MODE == "AUDIT" then
	audit(sharedSource, workspaceSource, applicationSource, true)
	print(TAG .. " AUDIT PASS")
	return
end

local oldSharedSource = shared.Source
local oldWorkspaceSource = workspace.Source
local oldApplicationSource = application.Source
local oldSidebarIconValue = navigationIcons:GetAttribute("UnderglowSidebarIcon")
local purchaseIconBefore = underglowCosmetic:GetAttribute("Icon")

local ok, problem = xpcall(function()
	if MODE == "INSTALL" and navigationIcons:GetAttribute("UnderglowSidebarIcon") == nil then
		local defaultIcon = navigationIcons:GetAttribute("UnderglowIcon")
		if type(defaultIcon) ~= "string" or defaultIcon == "" then defaultIcon = purchaseIconBefore end
		assert(type(defaultIcon) == "string" and defaultIcon ~= "", "No existing underglow icon is available for the sidebar default")
		navigationIcons:SetAttribute("UnderglowSidebarIcon", defaultIcon)
	end
	shared.Source = sharedSource
	workspace.Source = workspaceSource
	application.Source = applicationSource
	assert(shared.Source == sharedSource and workspace.Source == workspaceSource and application.Source == applicationSource, "Committed source readback mismatch")
	assert(underglowCosmetic:GetAttribute("Icon") == purchaseIconBefore, "Bottom Underglow purchase icon was modified")
	audit(shared.Source, workspace.Source, application.Source, MODE == "INSTALL")
end, debug.traceback)

if not ok then
	pcall(function() shared.Source = oldSharedSource end)
	pcall(function() workspace.Source = oldWorkspaceSource end)
	pcall(function() application.Source = oldApplicationSource end)
	pcall(function() navigationIcons:SetAttribute("UnderglowSidebarIcon", oldSidebarIconValue) end)
	error(TAG .. " " .. MODE .. " ABORTED and rolled back: " .. tostring(problem), 0)
end

if MODE == "INSTALL" then
	print(TAG .. " INSTALL PASS")
	print("Set ReplicatedStorage.NeoTokyoRacers.Config.UI.GarageReplacement.NavigationIcons.UnderglowSidebarIcon to the desired rbxassetid:// value, restart Play, and verify the Paint Shop.")
else
	print(TAG .. " ROLLBACK PASS (the harmless UnderglowSidebarIcon tuning attribute is preserved if it already existed)")
end
