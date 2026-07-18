-- Neo Tokyo Racers - Upgrade card hierarchy and budget presentation refinement
-- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1_1
-- Run once from the Roblox Studio Command Bar in EDIT mode.

local MODE = "INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1_1"
local V1 = "NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1"
local PREFIX = "[NTR Garage Upgrade Card Refinement]"

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
local clientRoot = need(need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder")
local ui = need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder")
local sharedCards = need(ui, "GarageReplacementComponents", "ModuleScript")
local workspace = need(ui, "GarageWorkspaceController", "ModuleScript")
local application = need(ui, "ModuleShopUIController", "ModuleScript")
local replacementConfig = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")

assert(string.find(sharedCards.Source, "NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1", 1, true), "Shared upgrade-card baseline missing")
assert(string.find(workspace.Source, "NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1", 1, true), "Workspace budget baseline missing")
assert(string.find(application.Source, "NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1", 1, true), "Application upgrade-budget baseline missing")

local sharedSource = sharedCards.Source
if not string.find(sharedSource, REVISION, 1, true) then
	local v1Price = [[	local priceText=props.PriceText or (props.Price~=nil and ("$"..tostring(props.Price)) or nil); if priceText~=nil and state~="Locked" then local price=Racing.Label(card,{Name="Price",Text=tostring(priceText),Position=UDim2.fromOffset(12,67),Size=UDim2.new(1,-24,0,23),TextSize=14,Color=props.PriceColor or Color3.fromRGB(89,255,102),Role="Heading"}); price.ZIndex=card.ZIndex+2 end -- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1]]
	local finalPrice = [[	local priceText=props.PriceText or (props.Price~=nil and ("$"..tostring(props.Price)) or nil); if priceText~=nil and state~="Locked" then local price=Racing.Label(card,{Name="Price",Text=tostring(priceText),Position=UDim2.fromOffset(12,74),Size=UDim2.new(1,-24,0,23),TextSize=14,Color=props.PriceColor or Color3.fromRGB(89,255,102),Role="Heading"}); price.ZIndex=card.ZIndex+2 end -- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1_1]]
	if string.find(sharedSource, v1Price, 1, true) then
		sharedSource = replaceOnce(sharedSource, v1Price, finalPrice, "V1 shared status position")
	else
		sharedSource = replaceOnce(sharedSource,
			[[	if props.Price~=nil and state~="Locked" then local price=Racing.Label(card,{Name="Price",Text="$"..tostring(props.Price),Position=UDim2.fromOffset(12,67),Size=UDim2.new(1,-24,0,23),TextSize=14,Color=Color3.fromRGB(89,255,102),Role="Heading"}); price.ZIndex=card.ZIndex+2 end]],
			finalPrice, "shared exact price text")
	end
end
compile("GarageReplacementComponents", sharedSource)

local workspaceSource = workspace.Source
if not string.find(workspaceSource, REVISION, 1, true) then
	if not string.find(workspaceSource, V1, 1, true) then workspaceSource = replaceOnce(workspaceSource,
		[[function WorkspaceUI:RenderBudget(context)
	clear(self.Budget); local budget=context.UpgradeBudget; self.Budget.Visible=typeof(budget)=="table"; if not self.Budget.Visible then return end
	local capacity=math.max(0,math.floor(tonumber(budget.Capacity) or 0)); local used=math.clamp(math.floor(tonumber(budget.Used) or 0),0,capacity)
	local budgetTitle=generated(Racing.Label(self.Budget,{Text=string.upper(budget.Label or "UPGRADE POINTS"),Position=UDim2.fromOffset(10,0),Size=UDim2.fromOffset(126,N("UpgradeBudgetHeight",34)),TextSize=11,Role="Heading"})); budgetTitle.ZIndex=self.Budget.ZIndex+2
	local pipWidth=N("UpgradeBudgetPipWidth",18); local pipGap=N("UpgradeBudgetPipGap",5); local totalWidth=capacity*pipWidth+math.max(0,capacity-1)*pipGap; local startX=(N("UpgradeBudgetWidth",430)-totalWidth)*.5
	for index=1,capacity do local pip=generated(Instance.new("Frame")); pip.Name="Point"..index; pip.Position=UDim2.fromOffset(startX+(index-1)*(pipWidth+pipGap),9); pip.Size=UDim2.fromOffset(pipWidth,16); pip.BorderSizePixel=0; pip.BackgroundColor3=index<=used and (used==capacity and Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)) or Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))) or Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)); pip.ZIndex=self.Budget.ZIndex+2; pip.Parent=self.Budget; Racing.Corner(pip,4); if index<=used and used<capacity then local gradient=Instance.new("UIGradient"); gradient.Color=ColorSequence.new(Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))); gradient.Parent=pip end end
	local budgetUsed=generated(Racing.Label(self.Budget,{Text=tostring(used).."/"..tostring(capacity).." USED",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,0),Size=UDim2.fromOffset(88,N("UpgradeBudgetHeight",34)),TextSize=11,XAlignment=Enum.TextXAlignment.Right,Role="Metric"})); budgetUsed.ZIndex=self.Budget.ZIndex+2
end]],
		[[function WorkspaceUI:RenderBudget(context)
	clear(self.Budget); local budget=context.UpgradeBudget; self.Budget.Visible=typeof(budget)=="table"; if not self.Budget.Visible then return end
	local capacity=math.max(0,math.floor(tonumber(budget.Capacity) or 0)); local used=math.clamp(math.floor(tonumber(budget.Used) or 0),0,capacity); local width=N("UpgradeBudgetWidth",480); local height=N("UpgradeBudgetHeight",42); local textSize=N("UpgradeBudgetTextSize",13)
	local budgetTitle=generated(Racing.Label(self.Budget,{Text=string.upper(budget.Label or "UPGRADE POINTS"),Position=UDim2.fromOffset(12,0),Size=UDim2.fromOffset(150,height),TextSize=textSize,Role="Heading"})); budgetTitle.ZIndex=self.Budget.ZIndex+2
	local pipWidth=N("UpgradeBudgetPipWidth",18); local pipGap=N("UpgradeBudgetPipGap",5); local totalWidth=capacity*pipWidth+math.max(0,capacity-1)*pipGap; local startX=(width-totalWidth)*.5; local pipY=(height-16)*.5
	for index=1,capacity do local pip=generated(Instance.new("Frame")); pip.Name="Point"..index; pip.Position=UDim2.fromOffset(startX+(index-1)*(pipWidth+pipGap),pipY); pip.Size=UDim2.fromOffset(pipWidth,16); pip.BorderSizePixel=0; pip.BackgroundColor3=index<=used and (used==capacity and Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)) or Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))) or Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)); pip.ZIndex=self.Budget.ZIndex+2; pip.Parent=self.Budget; Racing.Corner(pip,4); if index<=used and used<capacity then local gradient=Instance.new("UIGradient"); gradient.Color=ColorSequence.new(Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))); gradient.Parent=pip end end
	local budgetUsed=generated(Racing.Label(self.Budget,{Text=tostring(used).."/"..tostring(capacity).." USED",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,0),Size=UDim2.fromOffset(100,height),TextSize=textSize,XAlignment=Enum.TextXAlignment.Right,Role="Heading"})); budgetUsed.ZIndex=self.Budget.ZIndex+2
end -- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1]], "larger budget hierarchy")
	workspaceSource = replaceOnce(workspaceSource,
		[[Rating=row.Badge,RatingColor=row.BadgeColor,Badge=row.Badge,BadgeColor=row.BadgeColor,Selected=selected,VehicleName=row.VehicleName,Variant=row.Variant,TagText=row.TagText,TagColor=row.TagColor,Price=row.Price,SemanticState=row.SemanticState]],
		[[Rating=row.Badge,RatingColor=row.BadgeColor,Badge=row.Badge,BadgeColor=row.BadgeColor,Selected=selected,VehicleName=row.VehicleName,Variant=row.Variant,TagText=row.TagText,TagColor=row.TagColor,Price=row.Price,PriceText=row.PriceText,PriceColor=row.PriceColor,SemanticState=row.SemanticState]], "workspace price presentation forwarding") end
	workspaceSource = replaceOnce(workspaceSource,
		[[	local budgetUsed=generated(Racing.Label(self.Budget,{Text=tostring(used).."/"..tostring(capacity).." USED",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12,0,0),Size=UDim2.fromOffset(100,height),TextSize=textSize,XAlignment=Enum.TextXAlignment.Right,Role="Heading"})); budgetUsed.ZIndex=self.Budget.ZIndex+2]],
		[[	local budgetUsed=generated(Racing.Label(self.Budget,{Text=tostring(used).."/"..tostring(capacity).." USED",Position=UDim2.new(1,-112,0,0),Size=UDim2.fromOffset(100,height),TextSize=textSize,XAlignment=Enum.TextXAlignment.Right,Role="Heading"})); budgetUsed.ZIndex=self.Budget.ZIndex+2 -- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1_1]], "keep used label inside budget")
end
compile("GarageWorkspaceController", workspaceSource)

local applicationSource = application.Source
if not string.find(applicationSource, REVISION, 1, true) then
	if not string.find(applicationSource, V1, 1, true) then applicationSource = replaceOnce(applicationSource,
		[[		local tagColor=variant=="Power" and Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)) or (variant=="Lightweight" and Color3.fromRGB(100,205,232) or Color3.fromRGB(132,142,145))]],
		[[		local levelColours={Color3.fromRGB(132,142,145),Color3.fromRGB(242,201,76),Color3.fromRGB(242,145,51),Color3.fromRGB(220,68,68)} -- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1]], "upgrade level palette")
	applicationSource = replaceOnce(applicationSource,
		[[			local pointCost=template and template:GetAttribute("Point"..tostring(used+1).."CostGuide"); local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0); local footer=maxed and "MAX LEVEL" or (budgetFull and "POINT LIMIT REACHED" or effectText(u)); local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade")
			table.insert(c.Cards,{Id=u.UpgradeId,CardKind="Listing",VehicleName=sourceVehicleName(m),Variant=u.DisplayName or u.UpgradeId,TagColor=tagColor,Price=available and price or nil,Footer=footer,SemanticState=semantic,DisplayName=u.DisplayName or u.UpgradeId,Badge=tostring(level).."/"..tostring(max),BadgeColor=maxed and Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)) or (level>0 and Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)) or Color3.fromRGB(132,142,145)),Selected=selected,ActionText=selected and available and ("UPGRADE $"..tostring(price)) or nil,OnSelect=function() State.PreviewUpgradeId=u.UpgradeId; renderCustomise() end,OnAction=function() local r=action:Call("UpgradeModule",{SlotId=target,ModuleId=moduleId,UpgradeId=u.UpgradeId}); State.PreviewUpgradeId=nil; if r.Success then buildPreview(); renderCustomise() else message(r.Message) end end})]],
		[[			local pointCost=template and template:GetAttribute("Point"..tostring(used+1).."CostGuide"); local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0); local footer=(maxed or budgetFull) and "" or effectText(u); local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade"); local priceText=maxed and "MAX LEVEL" or (budgetFull and "POINT LIMIT REACHED" or ("$"..tostring(price))); local priceColor=(maxed or available) and Color3.fromRGB(89,255,102) or Color3.fromRGB(132,142,145); local levelColor=levelColours[math.clamp(level,0,3)+1]
			table.insert(c.Cards,{Id=u.UpgradeId,CardKind="Listing",VehicleName=u.DisplayName or u.UpgradeId,TagText="LEVEL "..tostring(level),TagColor=levelColor,PriceText=priceText,PriceColor=priceColor,Footer=footer,SemanticState=semantic,DisplayName=u.DisplayName or u.UpgradeId,Selected=selected,ActionText=selected and available and "UPGRADE" or nil,OnSelect=function() State.PreviewUpgradeId=u.UpgradeId; renderCustomise() end,OnAction=function() local r=action:Call("UpgradeModule",{SlotId=target,ModuleId=moduleId,UpgradeId=u.UpgradeId}); State.PreviewUpgradeId=nil; if r.Success then buildPreview(); renderCustomise() else message(r.Message) end end})]], "upgrade card information hierarchy") end
	applicationSource = replaceOnce(applicationSource,
		[=[			local pointCost=template and template:GetAttribute("Point"..tostring(used+1).."CostGuide"); local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0); local footer=(maxed or budgetFull) and "" or effectText(u); local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade"); local priceText=maxed and "MAX LEVEL" or (budgetFull and "POINT LIMIT REACHED" or ("$"..tostring(price))); local priceColor=(maxed or available) and Color3.fromRGB(89,255,102) or Color3.fromRGB(132,142,145); local levelColor=levelColours[math.clamp(level,0,3)+1]]=],
		[=[			local pointCost=template and template:GetAttribute("Point"..tostring(used+1).."CostGuide"); local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0); local footer=(maxed or budgetFull) and "" or effectText(u); local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade"); local priceText=maxed and "MAX LEVEL" or (budgetFull and "POINT LIMIT REACHED" or ("$"..tostring(price))); local priceColor=available and Color3.fromRGB(89,255,102) or Color3.fromRGB(132,142,145); local levelColor=levelColours[math.clamp(level,0,3)+1] -- NTR_GARAGE_UPGRADE_CARD_HIERARCHY_REFINEMENT_V1_1]=], "grey terminal status text")
end
compile("ModuleShopUIController", applicationSource)

local function sourceHas(object, marker)
	return string.find(object.Source, marker, 1, true) ~= nil
end

local function audit()
	local pass, fail = 0, 0
	local function check(condition, message)
		if condition then pass += 1; print(PREFIX .. " PASS - " .. message) else fail += 1; warn(PREFIX .. " FAIL - " .. message) end
	end
	check(sourceHas(sharedCards, REVISION), "shared listing card accepts exact price/status text")
	check(sourceHas(workspace, REVISION), "workspace renders the larger in-card budget hierarchy")
	check(sourceHas(application, REVISION), "upgrade cards use upgrade-name and level hierarchy")
	check(tonumber(replacementConfig:GetAttribute("UpgradeBudgetWidth")) == 480, "budget width is 480")
	check(tonumber(replacementConfig:GetAttribute("UpgradeBudgetHeight")) == 42, "budget height is 42")
	check(tonumber(replacementConfig:GetAttribute("UpgradeBudgetTextSize")) == 13, "both budget labels match module-card name size")
	check(tonumber(replacementConfig:GetAttribute("UpgradeBudgetPopupClearance")) >= 44, "budget retains card-popup clearance")
	print(string.format("%s SUMMARY - PASS=%d FAIL=%d", PREFIX, pass, fail))
	assert(fail == 0, "Post-install audit failed")
end

if MODE == "AUDIT" then audit(); return end
assert(MODE == "INSTALL", "MODE must be INSTALL or AUDIT")

local alreadyInstalled = sourceHas(sharedCards, REVISION) and sourceHas(workspace, REVISION) and sourceHas(application, REVISION)
if alreadyInstalled and replacementConfig:GetAttribute("UpgradeBudgetWidth") == 480 and replacementConfig:GetAttribute("UpgradeBudgetHeight") == 42 and replacementConfig:GetAttribute("UpgradeBudgetTextSize") == 13 then
	audit(); print(PREFIX .. " already installed; no changes made"); return
end

local oldSources = {[sharedCards]=sharedCards.Source, [workspace]=workspace.Source, [application]=application.Source}
local oldAttributes = {}
local function setConfig(name, value)
	oldAttributes[name] = {Present=replacementConfig:GetAttribute(name) ~= nil, Value=replacementConfig:GetAttribute(name)}
	replacementConfig:SetAttribute(name, value)
end
local function rollback(reason)
	for object, source in pairs(oldSources) do pcall(function() object.Source = source end) end
	for name, record in pairs(oldAttributes) do pcall(function() replacementConfig:SetAttribute(name, record.Present and record.Value or nil) end) end
	error(PREFIX .. " rolled back: " .. tostring(reason), 0)
end

local ok, err = pcall(function()
	setConfig("UpgradeBudgetWidth", 480)
	setConfig("UpgradeBudgetHeight", 42)
	setConfig("UpgradeBudgetTextSize", 13)
	if (tonumber(replacementConfig:GetAttribute("UpgradeBudgetPopupClearance")) or 0) < 44 then setConfig("UpgradeBudgetPopupClearance", 48) end
	sharedCards.Source = sharedSource
	workspace.Source = workspaceSource
	application.Source = applicationSource
	audit()
end)
if not ok then rollback(err) end
print(PREFIX .. " INSTALL COMPLETE - Restart Play and verify level colours, MAX LEVEL/POINT LIMIT states, the price-free UPGRADE popup, and budget clearance.")
