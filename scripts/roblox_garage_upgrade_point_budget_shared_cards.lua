-- Neo Tokyo Racers - Physical module upgrade budgets and shared listing cards
-- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1
-- Run once from the Roblox Studio Command Bar in EDIT mode.

local MODE = "INSTALL" -- INSTALL or AUDIT
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local REVISION = "NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1"
local PREFIX = "[NTR Garage Upgrade Budgets]"

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
local categories = need(need(need(kit, "Assets", "Folder"), "Vehicles", "Folder"), "Categories", "Folder")
local performance = need(need(need(need(kit, "Shared", "Folder"), "Modules", "Folder"), "Common", "Folder"), "Performance", "Folder")
local resolver = need(performance, "VehiclePerformanceResolver", "ModuleScript")
local clientRoot = need(need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts"), "NeoTokyoRacersClient", "Folder")
local ui = need(need(clientRoot, "Controllers", "Folder"), "UI", "Folder")
local sharedCards = need(ui, "GarageReplacementComponents", "ModuleScript")
local workspace = need(ui, "GarageWorkspaceController", "ModuleScript")
local application = need(ui, "ModuleShopUIController", "ModuleScript")
local replacementConfig = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")

assert(string.find(resolver.Source, "NTR_CANONICAL_PERFORMANCE_RESOLVER_MODULE_RATINGS_V1", 1, true), "Canonical resolver baseline missing")
assert(string.find(sharedCards.Source, "NTR_GARAGE_MODULE_INSTANCE_CARD_RENDERER_V1", 1, true), "Shared listing-card baseline missing")
assert(string.find(workspace.Source, "NTR_GARAGE_WORKSPACE_CONTROLLER_V3", 1, true), "Garage workspace baseline missing")
assert(string.find(application.Source, "NTR_GARAGE_APPLICATION_CONTROLLER_CANONICAL_V3", 1, true), "Garage application baseline missing")

local resolverSource = resolver.Source
if not string.find(resolverSource, REVISION, 1, true) then
	resolverSource = replaceOnce(resolverSource,
		[[function Resolver.ClearCache() table.clear(baseRatingCache) end]],
		[[function Resolver.UpgradePreview(root,profile,slotId,module,instance,pathId) -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1
	local template=Resolver.FindModule(root,module); if not template then return nil,nil,"Module template not found" end
	local ok,preview=V2Upgrades.PreviewPoint(template,instance and instance.V2UpgradePoints or {},pathId)
	if not ok then return nil,nil,preview end
	local proposed={}; for key,value in pairs(instance or {}) do proposed[key]=value end; proposed.V2UpgradePoints=preview.Allocation
	local after,before,errorMessage=Resolver.Selected(root,profile,slotId,template,proposed)
	return after,before,errorMessage,preview
end
function Resolver.ClearCache() table.clear(baseRatingCache) end]], "resolver next-point preview")
end
compile("VehiclePerformanceResolver", resolverSource)

local sharedSource = sharedCards.Source
if not string.find(sharedSource, REVISION, 1, true) then
	sharedSource = replaceOnce(sharedSource,
		[[	local accent=selected and blue or ((state=="InUse" or state=="Locked") and grey or pink); local fill=state=="Equipped" and Color3.fromRGB(92,31,73) or Racing.Colour("Panel",Color3.fromRGB(15,19,24))]],
		[[	local accent=selected and blue or ((state=="InUse" or state=="Locked" or state=="Unavailable") and grey or pink); local invested=state=="Equipped" or state=="Invested"; local fill=invested and Color3.fromRGB(92,31,73) or Racing.Colour("Panel",Color3.fromRGB(15,19,24)) -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1]], "shared upgrade semantic colours")
	sharedSource = replaceOnce(sharedSource,
		[[	local surface=gradient(card,state=="Equipped" and Color3.fromRGB(118,38,91) or Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),90)]],
		[[	local surface=gradient(card,invested and Color3.fromRGB(118,38,91) or Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),90)]], "shared invested gradient")
	sharedSource = replaceOnce(sharedSource,
		[[		local variant=tostring(props.Variant or props.DisplayName or "STANDARD"); local variantColour=variant=="Power" and pink or (variant=="Lightweight" and Color3.fromRGB(100,205,232) or grey)]],
		[[		local variant=tostring(props.TagText or props.Variant or props.DisplayName or "STANDARD"); local variantColour=props.TagColor or (variant=="Power" and pink or (variant=="Lightweight" and Color3.fromRGB(100,205,232) or grey))]], "shared configurable listing tag")
	sharedSource = replaceOnce(sharedSource,
		[[	local footerColour=(state=="InUse" or state=="Locked") and grey or Racing.Colour("Text")]],
		[[	local footerColour=(state=="InUse" or state=="Locked" or state=="Unavailable") and grey or Racing.Colour("Text")]], "shared unavailable footer")
end
compile("GarageReplacementComponents", sharedSource)

local workspaceSource = workspace.Source
if not string.find(workspaceSource, REVISION, 1, true) then
	workspaceSource = replaceOnce(workspaceSource,
		[[	self.Popup=Shared.Popup(self.Root)]],
		[[	self.Budget=Shared.Panel(self.Root,"UpgradeBudget",{StrokeColor=outline,StrokeTransparency=.32,StrokeWidth=1.4,NoGlow=true}); self.Budget.Visible=false; self.Budget.ZIndex=30 -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1
	self.Popup=Shared.Popup(self.Root)]], "workspace budget surface")
	workspaceSource = replaceOnce(workspaceSource,
		[[	local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("DesktopMinScale",.68); local shell=Shared.LayoutGarageShell(self,{Number=N,Viewport=viewport,MinimumScale=minimum,Actions={self.Exit,self.Next,self.Back}})]],
		[[	local viewport=(Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1600,900); local minimum=UserInputService.TouchEnabled and N("MobileMinScale",.42) or N("DesktopMinScale",.68); local shell=Shared.LayoutGarageShell(self,{Number=N,Viewport=viewport,MinimumScale=minimum,Actions={self.Exit,self.Next,self.Back}})
	self.Budget.AnchorPoint=Vector2.new(.5,1); self.Budget.Position=UDim2.fromOffset(shell.Width*.5,shell.CarouselTop-N("UpgradeBudgetPopupClearance",48)); self.Budget.Size=UDim2.fromOffset(N("UpgradeBudgetWidth",430),N("UpgradeBudgetHeight",34))]], "workspace budget layout")
	workspaceSource = replaceOnce(workspaceSource,
		[[function WorkspaceUI:RenderCards(context)
	-- NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1
	self.Paint.Visible=false; self.Scroller.Visible=true; clear(self.Scroller); self.Popup:Hide(); local selectedCard]],
		[[function WorkspaceUI:RenderBudget(context)
	clear(self.Budget); local budget=context.UpgradeBudget; self.Budget.Visible=typeof(budget)=="table"; if not self.Budget.Visible then return end
	local capacity=math.max(0,math.floor(tonumber(budget.Capacity) or 0)); local used=math.clamp(math.floor(tonumber(budget.Used) or 0),0,capacity)
	local budgetTitle=generated(Racing.Label(self.Budget,{Text=string.upper(budget.Label or "UPGRADE POINTS"),Position=UDim2.fromOffset(10,0),Size=UDim2.fromOffset(126,N("UpgradeBudgetHeight",34)),TextSize=11,Role="Heading"})); budgetTitle.ZIndex=self.Budget.ZIndex+2
	local pipWidth=N("UpgradeBudgetPipWidth",18); local pipGap=N("UpgradeBudgetPipGap",5); local totalWidth=capacity*pipWidth+math.max(0,capacity-1)*pipGap; local startX=(N("UpgradeBudgetWidth",430)-totalWidth)*.5
	for index=1,capacity do local pip=generated(Instance.new("Frame")); pip.Name="Point"..index; pip.Position=UDim2.fromOffset(startX+(index-1)*(pipWidth+pipGap),9); pip.Size=UDim2.fromOffset(pipWidth,16); pip.BorderSizePixel=0; pip.BackgroundColor3=index<=used and (used==capacity and Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)) or Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))) or Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)); pip.ZIndex=self.Budget.ZIndex+2; pip.Parent=self.Budget; Racing.Corner(pip,4); if index<=used and used<capacity then local gradient=Instance.new("UIGradient"); gradient.Color=ColorSequence.new(Racing.Colour("ElectricBlue",Color3.fromRGB(25,116,255)),Racing.Colour("Telemetry",Color3.fromRGB(43,225,218))); gradient.Parent=pip end end
	local budgetUsed=generated(Racing.Label(self.Budget,{Text=tostring(used).."/"..tostring(capacity).." USED",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,0),Size=UDim2.fromOffset(88,N("UpgradeBudgetHeight",34)),TextSize=11,XAlignment=Enum.TextXAlignment.Right,Role="Metric"})); budgetUsed.ZIndex=self.Budget.ZIndex+2
end
function WorkspaceUI:RenderCards(context)
	-- NTR_GARAGE_ACTION_ICON_LOCKED_CARD_REFINEMENT_V1
	self.Paint.Visible=false; self.Scroller.Visible=true; self:RenderBudget(context); clear(self.Scroller); self.Popup:Hide(); local selectedCard]], "workspace budget renderer")
	workspaceSource = replaceOnce(workspaceSource,
		[[Rating=row.Badge,RatingColor=row.BadgeColor,Badge=row.Badge,BadgeColor=row.BadgeColor,Selected=selected,VehicleName=row.VehicleName,Variant=row.Variant,Price=row.Price]],
		[[Rating=row.Badge,RatingColor=row.BadgeColor,Badge=row.Badge,BadgeColor=row.BadgeColor,Selected=selected,VehicleName=row.VehicleName,Variant=row.Variant,TagText=row.TagText,TagColor=row.TagColor,Price=row.Price]], "workspace card tag forwarding")
	workspaceSource = replaceOnce(workspaceSource,
		[[function WorkspaceUI:RenderPaint(context)
	self.Popup:Hide(); self.Scroller.Visible=false; self.Paint.Visible=true; clear(self.Paint)]],
		[[function WorkspaceUI:RenderPaint(context)
	self.Popup:Hide(); self.Budget.Visible=false; self.Scroller.Visible=false; self.Paint.Visible=true; clear(self.Paint)]], "hide budget for paint")
	workspaceSource = replaceOnce(workspaceSource,
		[[		if self.Popup.Shell.Visible and selectedCard and selectedCard.Parent then expect(math.abs((self.Popup.Shell.AbsolutePosition.X+self.Popup.Shell.AbsoluteSize.X*.5)-(selectedCard.AbsolutePosition.X+selectedCard.AbsoluteSize.X*.5))<=3,"action popup is not card-centred") end]],
		[[		if self.Popup.Shell.Visible and selectedCard and selectedCard.Parent then expect(math.abs((self.Popup.Shell.AbsolutePosition.X+self.Popup.Shell.AbsoluteSize.X*.5)-(selectedCard.AbsolutePosition.X+selectedCard.AbsoluteSize.X*.5))<=3,"action popup is not card-centred"); if self.Budget.Visible then expect(self.Budget.AbsolutePosition.Y+self.Budget.AbsoluteSize.Y<=self.Popup.Shell.AbsolutePosition.Y-6,"upgrade budget overlaps action popup") end end]], "budget popup geometry audit")
	workspaceSource = replaceOnce(workspaceSource,
		[[	for _,parent in ipairs({self.CategoryList,self.Scroller,self.Paint,self.Stats,self.Cash,self.Capacity}) do clear(parent) end]],
		[[	self.Budget.Visible=false; for _,parent in ipairs({self.CategoryList,self.Scroller,self.Paint,self.Stats,self.Cash,self.Capacity,self.Budget}) do clear(parent) end]], "workspace budget cleanup")
end
compile("GarageWorkspaceController", workspaceSource)

local applicationSource = application.Source
if not string.find(applicationSource, REVISION, 1, true) then
	applicationSource = replaceOnce(applicationSource,
		[[local function currentPerformance()
	local instanceNow,instanceBase=InstancePreview.Performance(State,categoriesRoot)
	if instanceNow then return instanceNow,instanceBase end
	local base=PerformanceResolver.Profile(categoriesRoot,State.PreviewProfile or State.Profile)
	return base,base
end]],
		[[local function currentPerformance()
	local instanceNow,instanceBase=InstancePreview.Performance(State,categoriesRoot)
	if instanceNow then return instanceNow,instanceBase end
	if State.Stage=="Customise" and State.CustomizeMode=="Upgrades" and State.PreviewUpgradeId then
		local moduleId,instanceId=installedForSlot(State.CustomizeTarget); local instance=instanceId and State.Profile and State.Profile.OwnedModuleInstances and State.Profile.OwnedModuleInstances[instanceId]
		local after,before=PerformanceResolver.UpgradePreview(categoriesRoot,State.PreviewProfile or State.Profile,State.CustomizeTarget,{ModuleId=moduleId},instance,State.PreviewUpgradeId)
		if after then return after,before end
	end
	local base=PerformanceResolver.Profile(categoriesRoot,State.PreviewProfile or State.Profile)
	return base,base
end -- NTR_GARAGE_UPGRADE_POINT_BUDGET_SHARED_CARDS_V1]], "application next-point stats preview")
	local upgradeStart = string.find(applicationSource, [[	elseif State.CustomizeMode=="Upgrades" then]], 1, true)
	local upgradeEnd = string.find(applicationSource, [[
	else
		table.insert(c.Cards,{Id="Colour"]], upgradeStart or 1, true)
	assert(upgradeStart and upgradeEnd, "Missing customisation upgrade-card replacement range")
	local upgradeBlock = [==[
	elseif State.CustomizeMode=="Upgrades" then
		local moduleId,m=installedModule(); local upgrades=(m and m.Upgrades) or {}; local variant=ModuleCards.Variant(m)
		local _,instanceId=installedForSlot(target); local instance=instanceId and State.Profile and State.Profile.OwnedModuleInstances and State.Profile.OwnedModuleInstances[instanceId]
		local allocation=(instance and instance.V2UpgradePoints) or ((State.Profile.ModuleUpgradeLevels or {})[moduleId] or {}); local template=PerformanceResolver.FindModule(categoriesRoot,{ModuleId=moduleId})
		local capacity=math.max(0,math.floor(tonumber(template and template:GetAttribute("UpgradePointCapacity")) or 0)); local used=0; for _,points in pairs(allocation) do used+=math.max(0,math.floor(tonumber(points) or 0)) end; used=math.min(used,capacity)
		c.UpgradeBudget={Label="Upgrade Points",Used=used,Capacity=capacity}
		if #upgrades==0 then c.EmptyMessage="UPGRADE DATA UNAVAILABLE FOR THIS MODULE"; warn("[NTR Garage Upgrades] Missing catalogue paths for "..tostring(moduleId)) end
		local tagColor=variant=="Power" and Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)) or (variant=="Lightweight" and Color3.fromRGB(100,205,232) or Color3.fromRGB(132,142,145))
		local friendly={TopSpeed="TOP SPEED",EngineOutput="ENGINE OUTPUT",Weight="WEIGHT",LateralGrip="LATERAL GRIP",SteeringResponse="STEERING RESPONSE",HoverStability="HOVER STABILITY",DriftControl="DRIFT CONTROL",DriftGrip="DRIFT GRIP",DriftChargeRate="DRIFT CHARGE",BrakingForce="BRAKING",BoostForce="BOOST FORCE",BoostDuration="BOOST DURATION",BoostRecharge="BOOST RECHARGE",BoostRechargeDelay="RECHARGE DELAY",BoostEfficiency="BOOST EFFICIENCY",Drag="DRAG",Downforce="DOWNFORCE"}
		local function effectText(upgrade) local bestName,bestValue; for name,value in pairs(upgrade.EffectsPerLevel or {}) do if typeof(value)=="number" and value~=0 and (not bestValue or math.abs(value)>math.abs(bestValue)) then bestName,bestValue=name,value end end; if not bestName then return "PERFORMANCE UPGRADE" end; local rounded=math.abs(bestValue)>=1 and tostring(math.floor(math.abs(bestValue)*10+.5)/10) or string.format("%.2f",math.abs(bestValue)); return (bestValue>0 and "+" or "-")..rounded.." "..tostring(friendly[bestName] or string.upper(bestName)) end
		for _,u in ipairs(upgrades) do
			local level=math.clamp(math.floor(tonumber(allocation[u.UpgradeId]) or 0),0,tonumber(u.MaxLevel) or 3); local max=tonumber(u.MaxLevel) or 3; local selected=State.PreviewUpgradeId==u.UpgradeId; local maxed=level>=max; local budgetFull=used>=capacity; local available=not maxed and not budgetFull
			local pointCost=template and template:GetAttribute("Point"..tostring(used+1).."CostGuide"); local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0); local footer=maxed and "MAX LEVEL" or (budgetFull and "POINT LIMIT REACHED" or effectText(u)); local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade")
			table.insert(c.Cards,{Id=u.UpgradeId,CardKind="Listing",VehicleName=sourceVehicleName(m),Variant=u.DisplayName or u.UpgradeId,TagColor=tagColor,Price=available and price or nil,Footer=footer,SemanticState=semantic,DisplayName=u.DisplayName or u.UpgradeId,Badge=tostring(level).."/"..tostring(max),BadgeColor=maxed and Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)) or (level>0 and Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)) or Color3.fromRGB(132,142,145)),Selected=selected,ActionText=selected and available and ("UPGRADE $"..tostring(price)) or nil,OnSelect=function() State.PreviewUpgradeId=u.UpgradeId; renderCustomise() end,OnAction=function() local r=action:Call("UpgradeModule",{SlotId=target,ModuleId=moduleId,UpgradeId=u.UpgradeId}); State.PreviewUpgradeId=nil; if r.Success then buildPreview(); renderCustomise() else message(r.Message) end end})
		end
]==]
	applicationSource = string.sub(applicationSource, 1, upgradeStart - 1) .. upgradeBlock .. string.sub(applicationSource, upgradeEnd)
end
compile("ModuleShopUIController", applicationSource)

local coreTypes = {Engine=true, Stabilisers=true, Boost=true}
local function activeModules()
	local result = {}
	for _, item in ipairs(categories:GetDescendants()) do
		if item:IsA("Model") and item:GetAttribute("ModuleId") and item:GetAttribute("RetiredFromCatalog") ~= true then table.insert(result, item) end
	end
	return result
end

local modules = activeModules()
local function variant(module) return tostring(module:GetAttribute("VariantName") or module:GetAttribute("Tier") or "") end
local function sourcePathsFor(standard)
	for _, sibling in ipairs(standard.Parent:GetChildren()) do
		if sibling:IsA("Model") and variant(sibling)=="Lightweight" and sibling:GetAttribute("ModuleType")==standard:GetAttribute("ModuleType") then
			local root=sibling:FindFirstChild("VehiclePerformanceV2UpgradePaths"); if root and root:IsA("Folder") then return root end
		end
	end
end

local function sourceHas(object, marker) return string.find(object.Source, marker, 1, true) ~= nil end
local function audit()
	local pass, fail = 0, 0
	local function check(condition, message) if condition then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end end
	check(sourceHas(resolver,REVISION),"resolver supports next-point previews")
	check(sourceHas(sharedCards,REVISION),"shared listing cards support upgrade states")
	check(sourceHas(workspace,REVISION),"workspace owns the themed budget strip and popup clearance audit")
	check(sourceHas(application,REVISION),"application uses shared upgrade listing cards")
	local standard,lightPower,badStandard,badSix=0,0,0,0
	for _,module in ipairs(modules) do
		local kind=variant(module); local moduleType=tostring(module:GetAttribute("ModuleType") or "")
		if kind=="Standard" and coreTypes[moduleType] then standard+=1; local root=module:FindFirstChild("VehiclePerformanceV2UpgradePaths"); if module:GetAttribute("UpgradePointCapacity")~=2 or not root or #root:GetChildren()~=3 then badStandard+=1 end
		elseif (kind=="Lightweight" or kind=="Power") and coreTypes[moduleType] then lightPower+=1; if module:GetAttribute("UpgradePointCapacity")~=6 then badSix+=1 end end
	end
	check(standard==24,"24 Standard core modules found")
	check(lightPower==48,"48 Lightweight/Power core modules found")
	check(badStandard==0,"every Standard core module has three paths and a two-point budget")
	check(badSix==0,"every Lightweight/Power core module retains a six-point budget")
	check(tonumber(replacementConfig:GetAttribute("UpgradeBudgetPopupClearance"))>=44,"budget strip reserves popup clearance")
	local result=require(resolver); local targets={bruiser_02={"E",200},bruiser_03={"D",375},bruiser_01={"C",525},bruiser_04={"B",662},bruiser_05={"A",787},bruiser_06={"S",925}}
	for cockpitId,target in pairs(targets) do local calculated=result.Factory(categories,{CockpitId=cockpitId}); local overall=calculated and calculated.Overall or {}; check(overall.Tier==target[1] and math.abs((tonumber(overall.PerformanceIndex) or 0)-target[2])<=3,cockpitId.." stock rating unchanged") end
	print(string.format("%s SUMMARY - PASS=%d FAIL=%d",PREFIX,pass,fail)); assert(fail==0,"Post-install audit failed")
end

if MODE=="AUDIT" then audit(); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local alreadySources=sourceHas(resolver,REVISION) and sourceHas(sharedCards,REVISION) and sourceHas(workspace,REVISION) and sourceHas(application,REVISION)
local alreadyAssets=true; for _,module in ipairs(modules) do if variant(module)=="Standard" and coreTypes[tostring(module:GetAttribute("ModuleType") or "")] and (module:GetAttribute("UpgradePointCapacity")~=2 or not module:FindFirstChild("VehiclePerformanceV2UpgradePaths")) then alreadyAssets=false; break end end
if alreadySources and alreadyAssets then audit(); print(PREFIX.." already installed; no changes made"); return end

local oldSources={[resolver]=resolver.Source,[sharedCards]=sharedCards.Source,[workspace]=workspace.Source,[application]=application.Source}
local changedAttributes={}; local createdRoots={}
local function remember(object,name) changedAttributes[object]=changedAttributes[object] or {}; if changedAttributes[object][name]==nil then changedAttributes[object][name]={Present=object:GetAttribute(name)~=nil,Value=object:GetAttribute(name)} end end
local function setAttribute(object,name,value) remember(object,name); object:SetAttribute(name,value) end
local function rollback(reason)
	for object,source in pairs(oldSources) do pcall(function() object.Source=source end) end
	for _,root in ipairs(createdRoots) do pcall(function() root:Destroy() end) end
	for object,attributes in pairs(changedAttributes) do for name,record in pairs(attributes) do pcall(function() object:SetAttribute(name,record.Present and record.Value or nil) end) end end
	error(PREFIX.." rolled back: "..tostring(reason),0)
end

local ok,err=pcall(function()
	for _,module in ipairs(modules) do
		local kind=variant(module); local moduleType=tostring(module:GetAttribute("ModuleType") or "")
		if kind=="Standard" and coreTypes[moduleType] then
			setAttribute(module,"UpgradePointCapacity",2); setAttribute(module,"MaxPointsPerPath",3); setAttribute(module,"Upgradable",true)
			local base=math.max(0,math.floor(tonumber(module:GetAttribute("UpgradePrice")) or 0)); setAttribute(module,"Point1CostGuide",base); setAttribute(module,"Point2CostGuide",math.floor(base*1.25+.5))
			if not module:FindFirstChild("VehiclePerformanceV2UpgradePaths") then local source=sourcePathsFor(module); assert(source,"No Lightweight path source for "..module:GetFullName()); local root=source:Clone(); root.Name="VehiclePerformanceV2UpgradePaths"; root.Parent=module; table.insert(createdRoots,root) end
		elseif (kind=="Lightweight" or kind=="Power") and coreTypes[moduleType] then setAttribute(module,"UpgradePointCapacity",6); setAttribute(module,"Upgradable",true) end
	end
	for name,value in pairs({UpgradeBudgetWidth=430,UpgradeBudgetHeight=34,UpgradeBudgetPopupClearance=48,UpgradeBudgetPipWidth=18,UpgradeBudgetPipGap=5}) do if replacementConfig:GetAttribute(name)==nil then setAttribute(replacementConfig,name,value) end end
	resolver.Source=resolverSource; sharedCards.Source=sharedSource; workspace.Source=workspaceSource; application.Source=applicationSource
	audit()
end)
if not ok then rollback(err) end
print(PREFIX.." INSTALL COMPLETE - Restart Play and test Standard 2-point, Lightweight/Power 6-point allocation, preview deltas, popup clearance, and persistence.")
