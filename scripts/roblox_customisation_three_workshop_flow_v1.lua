-- Neo Tokyo Racers - Customisation Three Workshop Flow V1
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Reorganises the confirmed customisation workspace into Add Modules,
-- Upgrade Modules, and Paint Shop without replacing its layout, preview,
-- economy, persistence, vehicle, colour, VFX, or shared component owners.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Customisation Three Workshop Flow V1]"
local RUN_ID=HttpService:GenerateGUID(false)
local UI_MARKER="NTR_CUSTOMISATION_THREE_WORKSHOP_FLOW_V1"
local SERVER_MARKER="NTR_CUSTOMISATION_NEON_CAPABILITY_PROJECTION_V1"

local function countPlain(source,needle)
	local count=0
	local cursor=1
	while true do
		local first,last=source:find(needle,cursor,true)
		if not first then return count end
		count+=1
		cursor=last+1
	end
end

local function replaceBetween(source,firstMarker,lastMarker,replacement,label)
	assert(type(source)=="string",label.." source missing")
	assert(countPlain(source,firstMarker)==1,label.." first marker count changed")
	assert(countPlain(source,lastMarker)==1,label.." last marker count changed")
	local first=assert(source:find(firstMarker,1,true),label.." first marker missing")
	local last=assert(source:find(lastMarker,first+#firstMarker,true),label.." last marker missing")
	return source:sub(1,first-1)..replacement..source:sub(last)
end

local function replaceOnce(source,needle,replacement,label)
	assert(type(source)=="string",label.." source missing")
	assert(countPlain(source,needle)==1,label.." anchor count changed")
	local first=assert(source:find(needle,1,true),label.." anchor missing")
	return source:sub(1,first-1)..replacement..source:sub(first+#needle)
end

local function compile(source,name)
	local fn,problem=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(problem))
end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"ReplicatedStorage.NeoTokyoRacers missing")
local config=assert(kit:FindFirstChild("Config"),"NeoTokyoRacers.Config missing")
local uiConfig=assert(config:FindFirstChild("UI"),"NeoTokyoRacers.Config.UI missing")
local replacementConfig=assert(uiConfig:FindFirstChild("GarageReplacement"),"GarageReplacement config missing")
local navigationIcons=assert(replacementConfig:FindFirstChild("NavigationIcons"),"GarageReplacement.NavigationIcons missing")

local controllers=assert(
	StarterPlayer:FindFirstChild("StarterPlayerScripts")
		and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers:FindFirstChild("UI"),
	"NeoTokyoRacersClient.Controllers.UI missing"
)
local moduleShop=assert(controllers:FindFirstChild("ModuleShopUIController"),"ModuleShopUIController missing")
assert(moduleShop:IsA("ModuleScript"),moduleShop:GetFullName().." must be a ModuleScript")

local garageServices=assert(
	ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Garage"),
	"ServerScriptService.NeoTokyoRacers.Services.Garage missing"
)
local garageAction=assert(garageServices:FindFirstChild("GarageActionController_Shadow_Disabled"),"GarageActionController_Shadow_Disabled missing")
assert(garageAction:IsA("Script"),garageAction:GetFullName().." must be a Script")

local DECLARATION_OLD="local renderBrowser,renderPaint,renderHub,renderBuild,renderCustomise"
local DECLARATION_NEW="local renderBrowser,renderPaint,renderHub,renderBuild,renderUpgrade,renderPaintShop"
local UI_START="renderHub=function()"
local UI_END="local function open(mode,payload)"
local UI_SOURCE=[==[renderHub=function()
	-- NTR_CUSTOMISATION_THREE_WORKSHOP_FLOW_V1
	if State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Hub"
	browser:Hide()
	local c=common("Garage")
	c.CarouselScrollKey="Hub|ThreeWorkshops"
	c.Subtitle="Choose a workshop, or drive your vehicle."
	c.ShowLeft=false
	c.BackVisible=false
	c.NextText="Drive"
	c.NextIcon=navIcon("DriveIcon")
	c.NextIconText=">"
	c.Cards={
		{Id="AddModules",Image=navIcon("BuildModulesIcon"),ImageZoom=.5,DisplayName="Add Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() end},
		{Id="UpgradeModules",Image=navIcon("UpgradeModulesIcon"),ImageZoom=.5,DisplayName="Upgrade Modules",OnSelect=function() clearTransientModulePreview(); State.CustomizeMode="Upgrades"; local chosen=State.SelectedSlot; if not installedForSlot(chosen) then for _,candidate in ipairs(slots()) do if installedForSlot(candidate.SlotId) then chosen=candidate.SlotId; break end end end; State.CustomizeTarget=chosen or "Engine1"; renderUpgrade() end},
		{Id="PaintShop",Image=navIcon("PaintShopIcon"),ImageZoom=.5,DisplayName="Paint Shop",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Overview"; State.SelectedPaintAction=nil; renderPaintShop() end},
	}
	c.OnNext=driveFromGarage
	workspaceUI:Show(c)
end

local function moduleLineage(m)
	local category=currentCategory() or {}
	local categoryDisplay=tostring(category.DisplayName or category.CategoryId or "Vehicle")
	local categoryName=string.upper(categoryDisplay)
	local function fullName(name)
		name=tostring(name or "")
		if name=="" then return categoryDisplay.." Vehicle" end
		if string.find(string.lower(name),string.lower(categoryDisplay),1,true)==1 then return name end
		return categoryDisplay.." "..name
	end
	local direct=tostring(m and m.SourceCockpitDisplayName or "")
	if direct~="" then return categoryName,fullName(direct) end
	local sourceId=tostring(m and m.SourceCockpitId or "")
	local source=sourceId~="" and cockpit(sourceId,category) or nil
	return categoryName,fullName(source and (source.DisplayName or source.CockpitId) or (sourceId~="" and sourceId or "Vehicle"))
end

local function ownedModuleCount(moduleId)
	local count=0
	for _,item in pairs(State.Profile.OwnedModuleInstances or {}) do
		if tostring(item.TemplateId)==tostring(moduleId) then count+=1 end
	end
	return count
end

local function vehicleDisplayName(vehicleId)
	local p=State.Profile or {}
	local vehicle=p.Vehicles and p.Vehicles[vehicleId]
	if not vehicle then return "ANOTHER VEHICLE" end
	local owned=p.OwnedCockpitInstances and p.OwnedCockpitInstances[vehicle.CockpitInstanceId]
	local category=categoryById(vehicle.CategoryId or State.CategoryId)
	local source=owned and cockpit(owned.TemplateId,category)
	return tostring(source and (source.DisplayName or source.CockpitId) or "ANOTHER VEHICLE")
end

local function sourceVehicleName(m)
	local _,name=moduleLineage(m)
	return tostring(name)
end

local function sourceVehicleRating(m)
	local category=currentCategory()
	local source=m and cockpit(m.SourceCockpitId,category)
	local value=source and performanceForCockpit(source)
	return math.floor(tonumber(value and value.Overall and value.Overall.PerformanceIndex) or 0)
end

local function equipInstance(row,allowReassign)
	local r=action:Call("EquipModuleInstance",{ModuleInstanceId=row.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot,AllowReassign=allowReassign==true})
	if r.Success then
		State.ModuleMode="Slots"
		State.SelectedModuleId=nil
		State.SelectedModuleInstanceId=nil
		State.PreviewModules={}
		buildPreview()
		renderBuild()
	else
		message(r.Message)
	end
end

local function workshopRail(selected)
	return {
		{Id="AddModules",Text="Add Modules",Image=navIcon("BuildModulesIcon"),ImageZoom=.5,Selected=selected=="Add",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild() end},
		{Id="UpgradeModules",Text="Upgrade Modules",Image=navIcon("UpgradeModulesIcon"),ImageZoom=.5,Selected=selected=="Upgrade",OnSelect=function() clearTransientModulePreview(); State.CustomizeMode="Upgrades"; local chosen=State.SelectedSlot; if not installedForSlot(chosen) then for _,candidate in ipairs(slots()) do if installedForSlot(candidate.SlotId) then chosen=candidate.SlotId; break end end end; State.CustomizeTarget=chosen or "Engine1"; renderUpgrade() end},
		{Id="PaintShop",Text="Paint Shop",Image=navIcon("PaintShopIcon"),ImageZoom=.5,Selected=selected=="Paint",OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="ALL"; State.CustomizeMode="Overview"; State.SelectedPaintAction=nil; renderPaintShop() end},
	}
end

renderBuild=function()
	if State.ModuleMode=="Slots" and State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Build"
	browser:Hide()
	local c=common("Add Modules")
	c.CarouselScrollKey="AddModules|"..tostring(State.ModuleMode).."|"..tostring(State.SelectedSlot).."|"..tostring(State.ModuleOptionMode)
	c.CategoryScrollKey="WorkshopModeRail"
	c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or (State.ModuleMode=="Sources" and "Choose owned modules or buy modules." or "Preview, then buy or equip.")
	c.ShowLeft=true
	c.LeftFloating=true
	c.LeftCardMode=true
	c.LeftSharedCardSize=true
	c.LeftAlignCarouselBottom=true
	c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("WorkspaceCardHeight")) or 146
	c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("ModuleCardImageHeight")) or 104
	c.LeftItems=workshopRail("Add")
	c.BackVisible=true
	c.BackIcon=navIcon("BackIcon")
	c.BackIconText="<"
	c.NextText="Drive"
	c.NextIcon=navIcon("DriveIcon")
	c.NextIconText=">"
	c.Cards={}
	if State.ModuleMode=="Slots" then
		for _,art in ipairs(workspaceUI:ArtworkDefinitions("Build")) do
			local s=slot(art.TargetId)
			if s then
				local installed=installedForSlot(s.SlotId)
				table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,DisplayName=art.DisplayName,Badge=installed and "EQUIPPED" or nil,BadgeColor=tierColor("S"),OnSelect=function() clearTransientModulePreview(); State.SelectedSlot=s.SlotId; State.ModuleMode="Sources"; State.ModuleOptionMode=nil; section(s.SlotId); renderBuild() end})
			end
		end
	elseif State.ModuleMode=="Sources" then
		table.insert(c.Cards,{Id="Owned",Image=navIcon("OwnedModulesIcon"),ImageZoom=.5,DisplayName="Owned Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Owned"; renderBuild() end})
		table.insert(c.Cards,{Id="Buy",Image=navIcon("BuyModulesIcon"),ImageZoom=.5,DisplayName="Buy Modules",OnSelect=function() clearTransientModulePreview(); State.ModuleMode="Options"; State.ModuleOptionMode="Buy"; renderBuild() end})
	else
		local s=slot(State.SelectedSlot)
		local _,installedInstance=installedForSlot(State.SelectedSlot)
		if State.ModuleOptionMode=="Owned" then
			local rows=ModuleCards.Owned({Instances=State.Profile.OwnedModuleInstances,Slot=s,ResolveModule=moduleById,Fits=moduleFits,CurrentVehicleId=State.Profile.CurrentVehicleId,InstalledInstanceId=installedInstance,VehicleName=vehicleDisplayName,SourceVehicleName=sourceVehicleName,Rating=moduleRating})
			for _,row in ipairs(rows) do
				local selected=State.SelectedModuleInstanceId==row.Id
				table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and row.State~="Equipped" and "EQUIP" or nil,OnSelect=function() State.SelectedModuleId=row.Module.ModuleId; State.SelectedModuleInstanceId=row.Id; State.PreviewModules={[State.SelectedSlot]=row.Module.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() if row.State=="InUse" then confirmModuleMove(vehicleDisplayName(row.OwnerVehicleId),function() equipInstance(row,true) end) else equipInstance(row,false) end end})
			end
		else
			local rows=ModuleCards.Shop({Modules=modulesForSlot(State.SelectedSlot),IsLocked=function(m) local source=tostring(m.SourceCockpitId or ""); return source~="" and ownedCockpitCount(source)==0 end,SourceVehicleName=sourceVehicleName,SourceRating=sourceVehicleRating,OwnedCount=ownedModuleCount,Rating=moduleRating})
			for _,row in ipairs(rows) do
				local selected=State.SelectedModuleId==row.Id
				table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Price=row.Price,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Locked=row.Locked,LockImage=imageValue(replacementConfig:GetAttribute("ModuleLockIcon")),Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and not row.Locked and "BUY" or nil,OnSelect=function() State.SelectedModuleId=row.Id; State.SelectedModuleInstanceId=nil; State.PreviewModules={[State.SelectedSlot]=row.Id}; buildPreview(); renderBuild() end,OnAction=function() local buy=action:Call("BuyModuleInstance",{ModuleId=row.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot}); if not buy.Success then message(buy.Message); return end; clearTransientModulePreview(); State.ModuleMode="Slots"; State.ModuleOptionMode=nil; buildPreview(); renderBuild(); message("Module purchased and equipped.") end})
			end
		end
	end
	c.OnBack=function()
		clearTransientModulePreview()
		if State.ModuleMode=="Options" then
			State.ModuleMode="Sources"
			State.ModuleOptionMode=nil
			buildPreview()
			renderBuild()
		elseif State.ModuleMode=="Sources" then
			State.ModuleMode="Slots"
			buildPreview()
			renderBuild()
		else
			buildPreview()
			renderHub()
		end
	end
	c.OnNext=driveFromGarage
	workspaceUI:Show(c)
end

local function installedModuleFor(target)
	local id,instanceId=installedForSlot(target)
	return id,moduleById(id),instanceId
end

local function addModuleLocationRail(c,selected,onSelect)
	for _,art in ipairs(workspaceUI:ArtworkDefinitions("Build")) do
		local s=slot(art.TargetId)
		if s then
			local installed=installedForSlot(s.SlotId)
			table.insert(c.LeftItems,{Id=s.SlotId,Text=art.DisplayName,ImageKey=art.TargetId,Image=art.Image,ImageZoom=1.04,Selected=selected==s.SlotId,Muted=not installed,OnSelect=function() onSelect(s.SlotId) end})
		end
	end
end

local function addUpgradeCards(c,target)
	local moduleId,m,instanceId=installedModuleFor(target)
	if not moduleId then
		c.EmptyMessage="INSTALL A MODULE IN ADD MODULES FIRST"
		return
	end
	local upgrades=(m and m.Upgrades) or {}
	local instance=instanceId and State.Profile and State.Profile.OwnedModuleInstances and State.Profile.OwnedModuleInstances[instanceId]
	local allocation=(instance and instance.V2UpgradePoints) or ((State.Profile.ModuleUpgradeLevels or {})[moduleId] or {})
	local template=PerformanceResolver.FindModule(categoriesRoot,{ModuleId=moduleId})
	local capacity=math.max(0,math.floor(tonumber(template and template:GetAttribute("UpgradePointCapacity")) or 0))
	local used=0
	for _,points in pairs(allocation) do used+=math.max(0,math.floor(tonumber(points) or 0)) end
	used=math.min(used,capacity)
	c.UpgradeBudget={Label="Upgrade Points",Used=used,Capacity=capacity}
	if #upgrades==0 then
		c.EmptyMessage="UPGRADE DATA UNAVAILABLE FOR THIS MODULE"
		warn("[NTR Garage Upgrades] Missing catalogue paths for "..tostring(moduleId))
		return
	end
	local levelColours={Color3.fromRGB(132,142,145),Color3.fromRGB(242,201,76),Color3.fromRGB(242,145,51),Color3.fromRGB(220,68,68)}
	local friendly={TopSpeed="TOP SPEED",EngineOutput="ENGINE OUTPUT",Weight="WEIGHT",LateralGrip="LATERAL GRIP",SteeringResponse="STEERING RESPONSE",HoverStability="HOVER STABILITY",DriftControl="DRIFT CONTROL",DriftGrip="DRIFT GRIP",DriftChargeRate="DRIFT CHARGE",BrakingForce="BRAKING",BoostForce="BOOST FORCE",BoostDuration="BOOST DURATION",BoostRecharge="BOOST RECHARGE",BoostRechargeDelay="RECHARGE DELAY",BoostEfficiency="BOOST EFFICIENCY",Drag="DRAG",Downforce="DOWNFORCE"}
	local function effectText(upgrade)
		local bestName,bestValue
		for name,value in pairs(upgrade.EffectsPerLevel or {}) do
			if typeof(value)=="number" and value~=0 and (not bestValue or math.abs(value)>math.abs(bestValue)) then bestName,bestValue=name,value end
		end
		if not bestName then return "PERFORMANCE UPGRADE" end
		local rounded=math.abs(bestValue)>=1 and tostring(math.floor(math.abs(bestValue)*10+.5)/10) or string.format("%.2f",math.abs(bestValue))
		return (bestValue>0 and "+" or "-")..rounded.." "..tostring(friendly[bestName] or string.upper(bestName))
	end
	for _,u in ipairs(upgrades) do
		local level=math.clamp(math.floor(tonumber(allocation[u.UpgradeId]) or 0),0,tonumber(u.MaxLevel) or 3)
		local max=tonumber(u.MaxLevel) or 3
		local selected=State.PreviewUpgradeId==u.UpgradeId
		local maxed=level>=max
		local budgetFull=used>=capacity
		local available=not maxed and not budgetFull
		local pointCost=PerformanceResolver.UpgradeCost(categoriesRoot,{ModuleId=moduleId},instance,u.UpgradeId)
		local price=math.floor(tonumber(pointCost) or tonumber(u.BasePrice) or 0)
		local footer=(maxed or budgetFull) and "" or effectText(u)
		local semantic=(maxed or level>0) and "Invested" or (budgetFull and "Unavailable" or "Upgrade")
		local priceText=maxed and "MAX LEVEL" or (budgetFull and "LIMIT REACHED" or Shared.FormatMoney(price))
		local priceColor=available and Color3.fromRGB(89,255,102) or Color3.fromRGB(132,142,145)
		local levelColor=levelColours[math.clamp(level,0,3)+1]
		table.insert(c.Cards,{Id=u.UpgradeId,CardKind="Listing",VehicleName=u.DisplayName or u.UpgradeId,TagText="LEVEL "..tostring(level),TagColor=levelColor,PriceText=priceText,PriceColor=priceColor,Footer=footer,SemanticState=semantic,DisplayName=u.DisplayName or u.UpgradeId,Selected=selected,ActionText=selected and available and "UPGRADE" or nil,OnSelect=function() State.PreviewUpgradeId=u.UpgradeId; renderUpgrade() end,OnAction=function() local r=action:Call("UpgradeModule",{SlotId=target,ModuleId=moduleId,UpgradeId=u.UpgradeId}); State.PreviewUpgradeId=nil; if r.Success then renderUpgrade() else message(r.Message) end end})
	end
end

renderUpgrade=function()
	State.Stage="Customise"
	State.CustomizeMode="Upgrades"
	local target=State.CustomizeTarget
	if not slot(target) then
		local candidates=slots()
		target=candidates[1] and candidates[1].SlotId or "Engine1"
		State.CustomizeTarget=target
	end
	if State.CameraSection~=target then section(target) end
	browser:Hide()
	local c=common("Upgrade Modules")
	c.CarouselScrollKey="UpgradeModules|"..tostring(target)
	c.CategoryScrollKey="UpgradeModuleRail"
	c.Subtitle="Choose an installed module location, then invest its upgrade points."
	c.BackVisible=true
	c.BackIcon=navIcon("BackIcon")
	c.BackIconText="<"
	c.NextText="Drive"
	c.NextIcon=navIcon("DriveIcon")
	c.NextIconText=">"
	c.LeftCardMode=true
	c.LeftFloating=true
	c.LeftAlignCarouselBottom=true
	c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118
	c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78
	c.LeftItems={}
	c.Cards={}
	addModuleLocationRail(c,target,function(id)
		clearTransientModulePreview()
		State.CustomizeTarget=id
		State.CustomizeMode="Upgrades"
		section(id)
		renderUpgrade()
	end)
	addUpgradeCards(c,target)
	c.OnBack=function() clearTransientModulePreview(); buildPreview(); renderHub() end
	c.OnNext=driveFromGarage
	buildPreview()
	workspaceUI:Show(c)
end

local function paintChannels(target)
	if target=="THRUST_COLOR" then return {"ThrustColor"} end
	if target=="UNDERGLOW" then return {"Neon"} end
	if target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end
	if target=="ALL" then return {"Primary","Secondary","Detail"} end
	local result={"Primary","Secondary","Detail"}
	if State.Profile.NeonOwned and State.Profile.NeonOwned[target]==true then table.insert(result,"Neon") end
	return result
end

local function hasOwnedNeon()
	for _,s in ipairs(slots()) do
		if installedForSlot(s.SlotId) and State.Profile.NeonOwned and State.Profile.NeonOwned[s.SlotId]==true then return true end
	end
	return false
end

local function firstBulkNeon()
	for _,s in ipairs(slots()) do
		if State.Profile.NeonOwned and State.Profile.NeonOwned[s.SlotId]==true then
			local value=((State.Profile.ModuleColors or {})[s.SlotId] or {}).Neon
			if typeof(value)=="Color3" then return value end
		end
	end
	return Color3.new(1,1,1)
end

local function paintColours(target,channels)
	local colours={}
	for _,channel in ipairs(channels) do
		local value
		if target=="THRUST_COLOR" then
			value=State.Profile.ThrustColor
		elseif target=="UNDERGLOW" then
			value=firstBulkNeon()
		elseif target=="Cockpit" or target=="ALL" then
			value=(State.Profile.CockpitColors or {})[channel]
		else
			value=((State.Profile.ModuleColors or {})[target] or {})[channel]
		end
		colours[channel]=typeof(value)=="Color3" and value or Color3.new(1,1,1)
	end
	return colours
end

local function paintTargetRail(c,target)
	for _,art in ipairs(workspaceUI:ArtworkDefinitions("Customise")) do
		local id=art.TargetId
		local special=id=="ALL" or id=="Cockpit" or id=="THRUST_COLOR"
		local physical=slot(id)~=nil
		if special or physical then
			table.insert(c.LeftItems,{Id=id,Text=id=="THRUST_COLOR" and "Thrust" or art.DisplayName,ImageKey=art.TargetId,Image=art.Image,ImageZoom=1.04,Selected=target==id,Muted=physical and not installedForSlot(id),OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget=id; State.CustomizeMode="Overview"; State.SelectedPaintAction=nil; State.SelectedColorChannel=id=="THRUST_COLOR" and "ThrustColor" or "Primary"; if physical then section(id) else section("ALL") end; renderPaintShop() end})
			if id=="THRUST_COLOR" then
				table.insert(c.LeftItems,{Id="UNDERGLOW",Text="Underglow",Image=navIcon("UnderglowIcon"),ImageZoom=1.04,Selected=target=="UNDERGLOW",Muted=not hasOwnedNeon(),OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget="UNDERGLOW"; State.CustomizeMode="Overview"; State.SelectedPaintAction=nil; State.SelectedColorChannel="Neon"; section("ALL"); renderPaintShop() end})
			end
		end
	end
end

local function addPaintOverviewCards(c,target,actionIconScale)
	local physical=slot(target)~=nil
	if physical and not installedForSlot(target) then
		c.EmptyMessage="INSTALL A MODULE IN ADD MODULES FIRST"
		return
	end
	if target=="UNDERGLOW" and not hasOwnedNeon() then
		c.EmptyMessage="BUY NEON LIGHTS FOR A MODULE FIRST"
		return
	end
	table.insert(c.Cards,{Id="Paint",Image=imageValue(replacementConfig:GetAttribute("ModuleColourIcon")),ImageZoom=actionIconScale,DisplayName="Paint",OnSelect=function() State.SelectedPaintAction=nil; State.PreviewNeonSlot=nil; State.CustomizeMode="Colour"; local channels=paintChannels(target); State.SelectedColorChannel=channels[1]; renderPaintShop() end})
	if not physical then return end
	local _,module=installedModuleFor(target)
	local available=module and module.NeonAvailable==true
	local owned=State.Profile.NeonOwned and State.Profile.NeonOwned[target]==true
	local price=math.max(0,math.floor(tonumber(module and module.NeonPrice) or 5000))
	local selected=State.SelectedPaintAction=="Neon"
	if not available then
		table.insert(c.Cards,{Id="Neon",Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),ImageZoom=actionIconScale,DisplayName="Neon Lights",Footer="NOT AVAILABLE FOR THIS MODULE",SemanticState="Unavailable"})
		return
	end
	local affordable=(tonumber(State.Profile.Cash) or 0)>=price
	table.insert(c.Cards,{
		Id="Neon",
		Image=imageValue(replacementConfig:GetAttribute("ModuleNeonIcon")),
		ImageZoom=actionIconScale,
		DisplayName="Neon Lights",
		Badge=owned and "OWNED" or Shared.FormatMoney(price),
		BadgeColor=owned and tierColor("S") or (affordable and Color3.fromRGB(89,255,102) or Color3.fromRGB(225,56,70)),
		Selected=selected,
		ActionText=selected and (owned and "CUSTOMISE" or "BUY") or nil,
		OnSelect=function()
			State.SelectedPaintAction="Neon"
			State.PreviewNeonSlot=not owned and target or nil
			renderPaintShop()
		end,
		OnAction=function()
			if owned then
				State.PreviewNeonSlot=nil
				State.SelectedPaintAction=nil
				State.CustomizeMode="Colour"
				State.SelectedColorChannel="Neon"
				renderPaintShop()
				return
			end
			local r=action:Call("BuyNeon",{SlotId=target})
			State.PreviewNeonSlot=nil
			State.SelectedPaintAction=nil
			if r.Success then
				State.CustomizeMode="Colour"
				State.SelectedColorChannel="Neon"
				renderPaintShop()
			else
				renderPaintShop()
				message(r.Message)
			end
		end,
	})
end

renderPaintShop=function()
	State.Stage="Customise"
	local target=State.CustomizeTarget or "ALL"
	if target~="ALL" and target~="Cockpit" and target~="THRUST_COLOR" and target~="UNDERGLOW" and not slot(target) then target="ALL"; State.CustomizeTarget=target end
	if slot(target) and State.CameraSection~=target then section(target) elseif not slot(target) and State.CameraSection~="ALL" then section("ALL") end
	browser:Hide()
	setPreviewVFXMode(target=="THRUST_COLOR" and "ThrustColour" or "Idle")
	local actionIconScale=math.clamp(tonumber(replacementConfig:GetAttribute("CustomiseActionIconScale")) or .5,.1,1.5)
	local c=common("Paint Shop")
	c.CarouselScrollKey="PaintShop|"..tostring(target).."|"..tostring(State.CustomizeMode)
	c.CategoryScrollKey="PaintShopTargetRail"
	c.Subtitle=State.CustomizeMode=="Colour" and "Choose a paint channel and colour." or "Choose a vehicle area to paint or light."
	c.ShowStats=false
	c.BackVisible=true
	c.BackIcon=navIcon("BackIcon")
	c.BackIconText="<"
	c.NextText="Drive"
	c.NextIcon=navIcon("DriveIcon")
	c.NextIconText=">"
	c.LeftCardMode=true
	c.LeftFloating=true
	c.LeftAlignCarouselBottom=true
	c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118
	c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78
	c.LeftItems={}
	c.Cards={}
	paintTargetRail(c,target)
	if State.CustomizeMode=="Colour" then
		local channels=paintChannels(target)
		local selected=State.SelectedColorChannel
		local valid=false
		for _,channel in ipairs(channels) do if channel==selected then valid=true; break end end
		if not valid then selected=channels[1]; State.SelectedColorChannel=selected end
		c.ColorChannels=channels
		c.SelectedChannel=selected
		c.Colors=paintColours(target,channels)
		c.OnChannel=function(channel) State.SelectedColorChannel=channel; renderPaintShop() end
		c.OnColor=function(channel,color,commit) handlePaint(target=="UNDERGLOW" and "ALL" or target,channel,color,commit) end
	else
		addPaintOverviewCards(c,target,actionIconScale)
	end
	c.OnBack=function()
		clearTransientModulePreview()
		State.SelectedPaintAction=nil
		if State.CustomizeMode=="Colour" then
			State.CustomizeMode="Overview"
			renderPaintShop()
		else
			buildPreview()
			renderHub()
		end
	end
	c.OnNext=driveFromGarage
	buildPreview()
	workspaceUI:Show(c)
end
]==]

local SERVER_START="\tlocal function V56_readModule(item, root)"
local SERVER_END="\tlocal function V56_catalog()"
local SERVER_SOURCE=[==[	local function V56_readModule(item, root)
		-- NTR_CUSTOMISATION_NEON_CAPABILITY_PROJECTION_V1
		local moduleType = V56_moduleTypeForModel(item, root)
		local moduleFolder = V56_string(item, "ModuleFolder", V56_nearestModuleFolder(root, item))
		local enginePosition = V56_string(item, "EnginePosition", "")
		local rearEngine = item:GetAttribute("RearEngine") == true
		if enginePosition == "" then
			if rearEngine or moduleFolder == "Engines_B" or string.find(tostring(item:GetAttribute("ModuleId") or item.Name or ""), "ENGINE_B", 1, true) then
				enginePosition = "Rear"
			elseif moduleFolder == "Engines" then
				enginePosition = "Front"
			end
		end
		local neonAvailable=false
		local neonFolder=item:FindFirstChild("NEON_OptionalLights",true)
		if neonFolder then
			for _,descendant in ipairs(neonFolder:GetDescendants()) do
				if descendant:IsA("BasePart") or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") or descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then
					neonAvailable=true
					break
				end
			end
		end
		return {
			ModuleId = V56_string(item, "ModuleId", item.Name),
			DisplayName = V56_string(item, "DisplayName", V56_string(item, "ModuleName", item.Name)),
			ModuleType = moduleType,
			ModuleSlot = V56_string(item, "ModuleSlot", moduleType),
			ModuleFolder = moduleFolder,
			EnginePosition = enginePosition,
			RearEngine = rearEngine or enginePosition == "Rear",
			SourceCockpitId = V85_moduleSourceCockpitId(item),
			SourceCockpitDisplayName = (select(2, V85_findSourceCockpit(nil, item)) and V56_string(select(2, V85_findSourceCockpit(nil, item)), "DisplayName", V85_moduleSourceCockpitId(item))) or V85_moduleSourceCockpitId(item),
			VariantName = V85_moduleVariantName(item),
			VariantOrder = V85_moduleVariantOrder(item),
			Price = V85_modulePurchasePrice(item),
			NeonAvailable = neonAvailable,
			NeonPrice = math.max(0, V56_number(item, "NeonPrice", 5000)),
			Power = V56_number(item, "Power", 0),
			Weight = V56_number(item, "Weight", 0),
			TopSpeed = V56_number(item, "TopSpeed", 0),
			Acceleration = V56_number(item, "Acceleration", 0),
			Handling = V56_number(item, "Handling", 0),
			Drift = V56_number(item, "Drift", 0),
			Braking = V56_number(item, "Braking", 0),
			Boost = V56_number(item, "Boost", 0),
			BoostDuration = V56_number(item, "BoostDuration", 0),
			BoostRecharge = V56_number(item, "BoostRecharge", 0),
			BoostRechargeDelay = V56_number(item, "BoostRechargeDelay", 0),
			Upgrades = V77_ModuleUpgrades.CatalogForModuleType(moduleType, item),
		}
	end
]==]

local uiSource=moduleShop.Source
assert(uiSource:find("NTR_GARAGE_FLOW_REFINEMENT_V2_1",1,true),"Confirmed customisation flow baseline missing")
assert(uiSource:find("NTR_GARAGE_CUSTOMISE_COMPACT_RAIL_V2_2",1,true),"Confirmed compact rail baseline missing")
local projectedUI=uiSource
if not projectedUI:find(UI_MARKER,1,true) then
	projectedUI=replaceOnce(projectedUI,DECLARATION_OLD,DECLARATION_NEW,"ModuleShopUIController declarations")
	projectedUI=replaceBetween(projectedUI,UI_START,UI_END,UI_SOURCE,"ModuleShopUIController workshop flow")
end

local serverSource=garageAction.Source
assert(serverSource:find("V56_CONSOLIDATED_ACTION_CONTROLLER_BEGIN",1,true),"Consolidated garage server baseline missing")
assert(serverSource:find("NTR_GARAGE_MODULE_INSTANCE_CUSTOMISATION_BRIDGE_V1",1,true),"Module-instance customisation server baseline missing")
assert(serverSource:find("NTR_GARAGE_VEHICLE_PREVIEW_PAINT_SCOPE_V1",1,true),"Vehicle paint-scope server baseline missing")
local projectedServer=serverSource
if not projectedServer:find(SERVER_MARKER,1,true) then
	projectedServer=replaceBetween(projectedServer,SERVER_START,SERVER_END,SERVER_SOURCE,"GarageActionController neon capability")
end
if not projectedServer:find("NTR_CUSTOMISATION_NEON_PRICE_GUARD_V1",1,true) then
	projectedServer=replaceOnce(
		projectedServer,
		'\t\t\t\t\tlocal price = V56_number(module, "NeonPrice", 5000)',
		'\t\t\t\t\tlocal price = math.max(0, V56_number(module, "NeonPrice", 5000)) -- NTR_CUSTOMISATION_NEON_PRICE_GUARD_V1',
		"GarageActionController neon price guard"
	)
end
if not projectedServer:find("NTR_CUSTOMISATION_BULK_NEON_OWNERSHIP_GUARD_V1",1,true) then
	projectedServer=replaceOnce(
		projectedServer,
		'\t\t\t\t\t\tfor installedSlot in pairs(profile.InstalledModules) do\n\t\t\t\t\t\t\tprofile.ModuleColors[installedSlot] = profile.ModuleColors[installedSlot] or {}\n\t\t\t\t\t\t\tprofile.ModuleColors[installedSlot][channel] = color\n\t\t\t\t\t\tend',
		'\t\t\t\t\t\tfor installedSlot in pairs(profile.InstalledModules) do\n\t\t\t\t\t\t\tif channel ~= "Neon" or profile.NeonOwned[installedSlot] == true then -- NTR_CUSTOMISATION_BULK_NEON_OWNERSHIP_GUARD_V1\n\t\t\t\t\t\t\t\tprofile.ModuleColors[installedSlot] = profile.ModuleColors[installedSlot] or {}\n\t\t\t\t\t\t\t\tprofile.ModuleColors[installedSlot][channel] = color\n\t\t\t\t\t\t\tend\n\t\t\t\t\t\tend',
		"GarageActionController bulk neon ownership guard"
	)
end

compile(projectedUI,"ModuleShopUIController_Projected")
compile(projectedServer,"GarageActionController_Projected")

local iconDefaults={
	UpgradeModulesIcon=tostring(navigationIcons:GetAttribute("CustomiseModulesIcon") or ""),
	PaintShopIcon=tostring(replacementConfig:GetAttribute("ModuleColourIcon") or ""),
	UnderglowIcon=tostring(replacementConfig:GetAttribute("ModuleNeonIcon") or ""),
}
local oldIcons={}
for name in pairs(iconDefaults) do
	local value=navigationIcons:GetAttribute(name)
	oldIcons[name]={Present=value~=nil,Value=value}
end
local oldUISource=moduleShop.Source
local oldServerSource=garageAction.Source
local oldUIRevision=moduleShop:GetAttribute("CustomisationWorkshopRevision")
local oldUIRunId=moduleShop:GetAttribute("CustomisationWorkshopRunId")
local oldServerRevision=garageAction:GetAttribute("CustomisationCapabilityRevision")

local ok,problem=pcall(function()
	for name,value in pairs(iconDefaults) do
		if navigationIcons:GetAttribute(name)==nil then navigationIcons:SetAttribute(name,value) end
		assert(type(navigationIcons:GetAttribute(name))=="string",name.." must be a string asset id")
	end
	moduleShop.Source=projectedUI
	garageAction.Source=projectedServer
	moduleShop:SetAttribute("CustomisationWorkshopRevision",UI_MARKER)
	moduleShop:SetAttribute("CustomisationWorkshopRunId",RUN_ID)
	garageAction:SetAttribute("CustomisationCapabilityRevision",SERVER_MARKER)

	assert(moduleShop.Source:find(UI_MARKER,1,true),"Workshop UI source did not persist")
	assert(garageAction.Source:find(SERVER_MARKER,1,true),"Neon capability source did not persist")
	assert(moduleShop:GetAttribute("CustomisationWorkshopRevision")==UI_MARKER,"Workshop revision attribute did not persist")
	assert(garageAction:GetAttribute("CustomisationCapabilityRevision")==SERVER_MARKER,"Capability revision attribute did not persist")
	assert(moduleShop.Source:find('DisplayName="Add Modules"',1,true),"Add Modules route missing")
	assert(moduleShop.Source:find('DisplayName="Upgrade Modules"',1,true),"Upgrade Modules route missing")
	assert(moduleShop.Source:find('DisplayName="Paint Shop"',1,true),"Paint Shop route missing")
	assert(moduleShop.Source:find('Text="Underglow"',1,true),"Underglow rail target missing")
	assert(moduleShop.Source:find('DisplayName="Neon Lights"',1,true),"Neon Lights action missing")
	assert(garageAction.Source:find("NeonPrice = math.max",1,true),"Authoritative neon price projection missing")
	assert(garageAction.Source:find("NTR_CUSTOMISATION_NEON_PRICE_GUARD_V1",1,true),"Neon price mutation guard missing")
	assert(garageAction.Source:find("NTR_CUSTOMISATION_BULK_NEON_OWNERSHIP_GUARD_V1",1,true),"Bulk neon ownership guard missing")
	compile(moduleShop.Source,"ModuleShopUIController_Committed")
	compile(garageAction.Source,"GarageActionController_Committed")
end)

if not ok then
	pcall(function()
		moduleShop.Source=oldUISource
		garageAction.Source=oldServerSource
		moduleShop:SetAttribute("CustomisationWorkshopRevision",oldUIRevision)
		moduleShop:SetAttribute("CustomisationWorkshopRunId",oldUIRunId)
		garageAction:SetAttribute("CustomisationCapabilityRevision",oldServerRevision)
		for name,snapshot in pairs(oldIcons) do
			if snapshot.Present then navigationIcons:SetAttribute(name,snapshot.Value) else navigationIcons:SetAttribute(name,nil) end
		end
	end)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS ui=three-workshops upgradeRail=module-only paintRail=capability-driven neonPrice=server underglow=bulk-module-neon runId="..RUN_ID)
print(TAG.." READY: restart Studio, enter owned vehicle customisation, and complete the desktop/mobile Add, Upgrade, Paint, neon purchase/customise, Back, Drive, vehicle-switch, and rejoin checks.")
