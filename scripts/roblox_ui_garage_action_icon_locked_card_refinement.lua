-- Neo Tokyo Racers - Garage action icon and locked module card refinement
-- NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1
-- Run once from the Roblox Studio Command Bar in EDIT mode.

local MODE = "INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1"

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), "Missing " .. parent:GetFullName() .. "." .. name .. " (" .. className .. ")")
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local replacementConfig = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")
local clientRoot = need(need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder")
local ui = need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder")
local shared = need(ui, "GarageReplacementComponents", "ModuleScript")
local workspace = need(ui, "GarageWorkspaceController", "ModuleScript")
local application = need(ui, "ModuleShopUIController", "ModuleScript")

assert(string.find(shared.Source, "NTR_GARAGE_MODULE_INSTANCE_CARD_RENDERER_V1", 1, true), "Shared module listing-card baseline missing")
assert(string.find(workspace.Source, "NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1", 1, true), "Shared garage card forwarding baseline missing")
assert(string.find(application.Source, "NTR_GARAGE_MODULE_PRESENTATION_REFINEMENT_V1", 1, true), "Garage presentation baseline missing")

local configDefaults = {
	CustomiseActionIconScale = 0.5,
	LockedModuleIconSize = 68,
	LockedModuleIconYScale = 0.46,
}

local sharedSource = shared.Source
if not string.find(sharedSource, REVISION, 1, true) then
	local oldHeader = [==[
	local vehicle=Racing.Label(card,{Name="VehicleName",Text=string.upper(props.VehicleName or props.Eyebrow or "UNIVERSAL"),Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,20),TextSize=13,Role="Heading"}); vehicle.ZIndex=card.ZIndex+2
	local variant=tostring(props.Variant or props.DisplayName or "STANDARD"); local variantColour=variant=="Power" and pink or (variant=="Lightweight" and Color3.fromRGB(100,205,232) or grey)
	local tag=Instance.new("Frame"); tag.Name="Variant"; tag.BackgroundColor3=variantColour; tag.BorderSizePixel=0; tag.Position=UDim2.fromOffset(12,35); tag.Size=UDim2.fromOffset(112,25); tag.ZIndex=card.ZIndex+2; tag.Parent=card; Racing.Corner(tag,4); local tagText=Racing.Label(tag,{Text=string.upper(variant),Size=UDim2.fromScale(1,1),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"}); tagText.ZIndex=tag.ZIndex+1
	if props.Badge then local rating=Instance.new("Frame"); rating.Name="ModuleRating"; rating.AnchorPoint=Vector2.new(1,0); rating.Position=UDim2.new(1,-12,0,35); rating.Size=UDim2.fromOffset(54,25); rating.BackgroundColor3=props.BadgeColor or grey; rating.BorderSizePixel=0; rating.ZIndex=card.ZIndex+2; rating.Parent=card; Racing.Corner(rating,4); local text=Racing.Label(rating,{Text=tostring(props.Badge),Size=UDim2.fromScale(1,1),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Metric"}); text.ZIndex=rating.ZIndex+1 end
]==]
	local newHeader = [==[
	-- NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1
	-- Locked shop cards intentionally reserve the complete upper area for one clear lock symbol.
	if state~="Locked" then
		local vehicle=Racing.Label(card,{Name="VehicleName",Text=string.upper(props.VehicleName or props.Eyebrow or "UNIVERSAL"),Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,20),TextSize=13,Role="Heading"}); vehicle.ZIndex=card.ZIndex+2
		local variant=tostring(props.Variant or props.DisplayName or "STANDARD"); local variantColour=variant=="Power" and pink or (variant=="Lightweight" and Color3.fromRGB(100,205,232) or grey)
		local tag=Instance.new("Frame"); tag.Name="Variant"; tag.BackgroundColor3=variantColour; tag.BorderSizePixel=0; tag.Position=UDim2.fromOffset(12,35); tag.Size=UDim2.fromOffset(112,25); tag.ZIndex=card.ZIndex+2; tag.Parent=card; Racing.Corner(tag,4); local tagText=Racing.Label(tag,{Text=string.upper(variant),Size=UDim2.fromScale(1,1),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"}); tagText.ZIndex=tag.ZIndex+1
		if props.Badge then local rating=Instance.new("Frame"); rating.Name="ModuleRating"; rating.AnchorPoint=Vector2.new(1,0); rating.Position=UDim2.new(1,-12,0,35); rating.Size=UDim2.fromOffset(54,25); rating.BackgroundColor3=props.BadgeColor or grey; rating.BorderSizePixel=0; rating.ZIndex=card.ZIndex+2; rating.Parent=card; Racing.Corner(rating,4); local text=Racing.Label(rating,{Text=tostring(props.Badge),Size=UDim2.fromScale(1,1),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Metric"}); text.ZIndex=rating.ZIndex+1 end
	end
]==]
	sharedSource = replaceOnce(sharedSource, oldHeader, newHeader, "locked-card dedicated upper layout")
	sharedSource = replaceOnce(sharedSource,
		[[if state=="Locked" and props.LockImage and props.LockImage~="" then local lock=Instance.new("ImageLabel"); lock.Name="LockIcon"; lock.BackgroundTransparency=1; lock.BorderSizePixel=0; lock.Image=props.LockImage; lock.AnchorPoint=Vector2.new(.5,.5); lock.Position=UDim2.fromScale(.5,.56); lock.Size=UDim2.fromOffset(42,42); lock.ZIndex=card.ZIndex+2; lock.Parent=card end]],
		[[if state=="Locked" and props.LockImage and props.LockImage~="" then local lockSize=math.max(1,tonumber(props.LockIconSize) or 68); local lockY=math.clamp(tonumber(props.LockIconYScale) or .46,0,1); local lock=Instance.new("ImageLabel"); lock.Name="LockIcon"; lock.BackgroundTransparency=1; lock.BorderSizePixel=0; lock.Image=props.LockImage; lock.AnchorPoint=Vector2.new(.5,.5); lock.Position=UDim2.fromScale(.5,lockY); lock.Size=UDim2.fromOffset(lockSize,lockSize); lock.ZIndex=card.ZIndex+2; lock.Parent=card end]],
		"configurable enlarged locked-card icon")
end
compile("GarageReplacementComponents", sharedSource)

local workspaceSource = workspace.Source
if not string.find(workspaceSource, REVISION, 1, true) then
	workspaceSource = replaceOnce(workspaceSource,
		[[function WorkspaceUI:RenderCards(context)
]],
		[[function WorkspaceUI:RenderCards(context)
	-- NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1
]],
		"workspace refinement marker")
	workspaceSource = replaceOnce(workspaceSource,
		[[SemanticState=row.SemanticState,LockImage=row.LockImage,Size=UDim2.fromOffset]],
		[[SemanticState=row.SemanticState,LockImage=row.LockImage,LockIconSize=N("LockedModuleIconSize",68),LockIconYScale=N("LockedModuleIconYScale",.46),Size=UDim2.fromOffset]],
		"locked-card tuning forwarding")
end
compile("GarageWorkspaceController", workspaceSource)

local applicationSource = application.Source
if not string.find(applicationSource, REVISION, 1, true) then
	applicationSource = replaceOnce(applicationSource,
		[[renderCustomise=function()
]],
		[[renderCustomise=function()
	-- NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1
]],
		"application refinement marker")
	applicationSource = replaceOnce(applicationSource,
		[[State.Stage="Customise"; local target=State.CustomizeTarget; local c=common("Customise");]],
		[[State.Stage="Customise"; local target=State.CustomizeTarget; local actionIconScale=math.clamp(tonumber(replacementConfig:GetAttribute("CustomiseActionIconScale")) or .5,.1,1.5); local c=common("Customise");]],
		"shared customise action icon scale")

	applicationSource = replaceOnce(applicationSource,
		[[Id="Neon",Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),DisplayName="Neon Lights"]],
		[[Id="Neon",Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),ImageZoom=actionIconScale,DisplayName="Neon Lights"]],
		"neon action icon scale")
	applicationSource = replaceOnce(applicationSource,
		[[Id=u.UpgradeId,Image=imageValue(replacementConfig:GetAttribute("ModulePerformanceIcon")),DisplayName=u.DisplayName or u.UpgradeId]],
		[[Id=u.UpgradeId,Image=imageValue(replacementConfig:GetAttribute("ModulePerformanceIcon")),ImageZoom=actionIconScale,DisplayName=u.DisplayName or u.UpgradeId]],
		"performance upgrade icon scale")
	applicationSource = replaceOnce(applicationSource,
		[[Id="Colour",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),DisplayName=target=="Cockpit" and "Change Colour" or "Colour"]],
		[[Id="Colour",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),ImageZoom=actionIconScale,DisplayName=target=="Cockpit" and "Change Colour" or "Colour"]],
		"colour action icon scale")
	applicationSource = replaceOnce(applicationSource,
		[[Id="Cosmetics",Image=imageValue(replacementConfig:GetAttribute("ModuleCosmeticsIcon")),DisplayName="Cosmetics"]],
		[[Id="Cosmetics",Image=imageValue(replacementConfig:GetAttribute("ModuleCosmeticsIcon")),ImageZoom=actionIconScale,DisplayName="Cosmetics"]],
		"cosmetics action icon scale")
	applicationSource = replaceOnce(applicationSource,
		[[Id="Performance",Image=imageValue(replacementConfig:GetAttribute("ModulePerformanceIcon")),DisplayName="Performance"]],
		[[Id="Performance",Image=imageValue(replacementConfig:GetAttribute("ModulePerformanceIcon")),ImageZoom=actionIconScale,DisplayName="Performance"]],
		"performance overview icon scale")
end
compile("ModuleShopUIController", applicationSource)

local failures = {}
local function expect(ok, message)
	if not ok then table.insert(failures, message) end
end
expect(string.find(sharedSource, REVISION, 1, true) ~= nil, "shared locked-card marker missing")
expect(string.find(sharedSource, [[if state~="Locked" then]], 1, true) ~= nil, "locked-card header suppression missing")
expect(string.find(sharedSource, [[props.LockIconSize]], 1, true) ~= nil, "configurable lock size missing")
expect(string.find(workspaceSource, [[N("LockedModuleIconSize",68)]], 1, true) ~= nil, "lock size forwarding missing")
expect(string.find(workspaceSource, [[N("LockedModuleIconYScale",.46)]], 1, true) ~= nil, "lock position forwarding missing")
expect(string.find(applicationSource, [[CustomiseActionIconScale]], 1, true) ~= nil, "customise action icon scale missing")
local iconScaleUses = 0
for _ in string.gmatch(applicationSource, "ImageZoom=actionIconScale") do iconScaleUses += 1 end
expect(iconScaleUses == 5, "expected five shared action icon scale uses, found " .. tostring(iconScaleUses))
if #failures > 0 then error("[NTR Garage Icon Refinement] AUDIT FAIL: " .. table.concat(failures, " | "), 0) end

print("[NTR Garage Icon Refinement] PREFLIGHT PASS")
if MODE == "AUDIT" then return end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

local oldSharedSource = shared.Source
local oldWorkspaceSource = workspace.Source
local oldApplicationSource = application.Source
local oldAttributes = {}
for name in pairs(configDefaults) do
	oldAttributes[name] = { Present = replacementConfig:GetAttribute(name) ~= nil, Value = replacementConfig:GetAttribute(name) }
end

local ok, err = xpcall(function()
	for name, value in pairs(configDefaults) do
		if replacementConfig:GetAttribute(name) == nil then replacementConfig:SetAttribute(name, value) end
	end
	shared.Source = sharedSource
	workspace.Source = workspaceSource
	application.Source = applicationSource
	assert(shared.Source == sharedSource and workspace.Source == workspaceSource and application.Source == applicationSource, "Source readback mismatch")
	assert(replacementConfig:GetAttribute("CustomiseActionIconScale") ~= nil, "CustomiseActionIconScale assignment missing")
	assert(replacementConfig:GetAttribute("LockedModuleIconSize") ~= nil, "LockedModuleIconSize assignment missing")
	assert(replacementConfig:GetAttribute("LockedModuleIconYScale") ~= nil, "LockedModuleIconYScale assignment missing")
	print("[NTR Garage Icon Refinement] INSTALL PASS")
	print("Restart Play. Verify Colour/Cosmetics/Performance/Neon artwork is half-size and locked module cards show only the enlarged raised lock plus their unlock requirement.")
end, debug.traceback)

if not ok then
	pcall(function() shared.Source = oldSharedSource end)
	pcall(function() workspace.Source = oldWorkspaceSource end)
	pcall(function() application.Source = oldApplicationSource end)
	for name, state in pairs(oldAttributes) do
		pcall(function() replacementConfig:SetAttribute(name, state.Present and state.Value or nil) end)
	end
	error("[NTR Garage Icon Refinement] INSTALL ABORTED and rolled back: " .. tostring(err), 0)
end
