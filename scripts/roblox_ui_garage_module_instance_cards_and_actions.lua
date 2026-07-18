-- Neo Tokyo Racers - Canonical garage module-instance cards and separated actions
-- NTR_GARAGE_MODULE_INSTANCE_CARDS_V1
-- Run once in EDIT mode. Installs one shared view model, one shared card renderer,
-- and keeps BuyModuleInstance separate from EquipModuleInstance.

local MODE = "INSTALL" -- INSTALL or AUDIT
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

assert(not RunService:IsRunning(), "Run this installer in Edit mode, not Play mode")

local function need(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), "Missing " .. parent:GetFullName() .. "." .. name .. " (" .. className .. ")")
	return object
end

local function compile(name, source)
	local fn, err = loadstring(source, "=" .. name)
	assert(fn, name .. " compile failed: " .. tostring(err))
end

local function replaceRange(source, firstAnchor, lastAnchor, replacement, label)
	local first = string.find(source, firstAnchor, 1, true)
	assert(first, "Missing source start anchor: " .. label)
	local last = string.find(source, lastAnchor, first + #firstAnchor, true)
	assert(last, "Missing source end anchor: " .. label)
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last)
end

local function replaceOnce(source, before, after, label)
	local first, last = string.find(source, before, 1, true)
	assert(first, "Missing source anchor: " .. label)
	assert(not string.find(source, before, last + 1, true), "Duplicate source anchor: " .. label)
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, last + 1)
end

local starterScripts = need(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = need(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = need(clientRoot, "Controllers", "Folder")
local ui = need(controllers, "UI", "Folder")
local application = need(ui, "ModuleShopUIController", "ModuleScript")
local components = need(ui, "GarageReplacementComponents", "ModuleScript")
local garageServer = need(need(need(ServerScriptService, "NeoTokyoRacers", "Folder"), "Services", "Folder"), "Garage", "Folder")
local actionController = need(garageServer, "GarageActionController_Shadow_Disabled", "Script")
local kit = need(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local replacementConfig = need(need(need(kit, "Config", "Folder"), "UI", "Folder"), "GarageReplacement", "Folder")

local viewModelSource = [==[
-- NTR_GARAGE_MODULE_INSTANCE_VIEW_MODEL_V1
local ViewModel={}
local variantOrder={Standard=1,Lightweight=2,Power=3}

function ViewModel.Variant(module)
	local name=string.lower(tostring(module and (module.DisplayName or module.ModuleId) or ""))
	if string.find(name,"lightweight",1,true) then return "Lightweight" end
	if string.find(name,"power",1,true) then return "Power" end
	return "Standard"
end

function ViewModel.Rating(module,instance)
	return math.floor(tonumber(instance and (instance.Rating or instance.PerformanceRating)) or tonumber(module and (module.Rating or module.PerformanceRating or module.PerformanceIndex)) or 0)
end

function ViewModel.Owned(context)
	local rows={}
	for instanceId,item in pairs(context.Instances or {}) do
		local module=context.ResolveModule(item.TemplateId)
		if module and context.Fits(module,context.Slot) then
			local owner=tostring(item.EquippedVehicleId or "")
			local state,status
			if tostring(instanceId)==tostring(context.InstalledInstanceId or "") then state,status="Equipped","EQUIPPED"
			elseif owner~="" and owner~=tostring(context.CurrentVehicleId or "") then state,status="InUse","IN USE BY "..string.upper(context.VehicleName(owner))
			else state,status="Available","AVAILABLE" end
			table.insert(rows,{Id=tostring(instanceId),Module=module,Item=item,State=state,Status=status,Variant=ViewModel.Variant(module),VehicleName=context.SourceVehicleName(module),Rating=ViewModel.Rating(module,item),OwnerVehicleId=owner})
		end
	end
	table.sort(rows,function(a,b)
		if a.Rating~=b.Rating then return a.Rating>b.Rating end
		if a.VehicleName~=b.VehicleName then return a.VehicleName<b.VehicleName end
		if variantOrder[a.Variant]~=variantOrder[b.Variant] then return variantOrder[a.Variant]<variantOrder[b.Variant] end
		return a.Id<b.Id
	end)
	return rows
end

function ViewModel.Shop(context)
	local rows={}
	for _,module in ipairs(context.Modules or {}) do
		local locked=context.IsLocked(module)
		table.insert(rows,{Id=tostring(module.ModuleId),Module=module,State=locked and "Locked" or "Shop",Status=locked and ("BUY "..string.upper(context.SourceVehicleName(module)).." TO UNLOCK") or ("OWNED x"..tostring(context.OwnedCount(module.ModuleId))),Variant=ViewModel.Variant(module),VehicleName=context.SourceVehicleName(module),Rating=ViewModel.Rating(module),SourceRating=context.SourceRating(module),Locked=locked,Price=tonumber(module.Price) or 0})
	end
	table.sort(rows,function(a,b)
		if a.Locked~=b.Locked then return not a.Locked end
		if a.SourceRating~=b.SourceRating then return a.SourceRating<b.SourceRating end
		if a.VehicleName~=b.VehicleName then return a.VehicleName<b.VehicleName end
		if variantOrder[a.Variant]~=variantOrder[b.Variant] then return variantOrder[a.Variant]<variantOrder[b.Variant] end
		return a.Id<b.Id
	end)
	return rows
end

return ViewModel
]==]
compile("GarageModuleCardViewModel", viewModelSource)

local applicationSource = application.Source
if not string.find(applicationSource, "NTR_GARAGE_MODULE_INSTANCE_ACTIONS_V1", 1, true) then
	local requireAnchor = [[local Browser=require(uiFolder:WaitForChild("GarageBrowserController")); local WorkspaceUI=require(uiFolder:WaitForChild("GarageWorkspaceController")); local Shared=require(uiFolder:WaitForChild("GarageReplacementComponents"))]]
	local requireReplacement = requireAnchor .. [[; local ModuleCards=require(uiFolder:WaitForChild("GarageModuleCardViewModel")); local replacementConfig=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")]]
	assert(string.find(applicationSource, requireAnchor, 1, true), "Missing application shared-controller require anchor")
	applicationSource = replaceOnce(applicationSource, requireAnchor, requireReplacement, "application shared-controller require")

	local modalAnchor = [[local function showCash()]]
	local confirmation = [==[
-- NTR_GARAGE_MODULE_INSTANCE_ACTIONS_V1
local function confirmModuleMove(vehicleName,onConfirm)
	local p=modalBase("MOVE EQUIPPED MODULE"); p.Size=UDim2.fromOffset(560,238)
	local body=Racing.Label(p,{Text="Equipping this module will remove it from "..tostring(vehicleName)..". Would you like to continue?",Position=UDim2.fromOffset(34,67),Size=UDim2.new(1,-68,0,72),TextSize=15,XAlignment=Enum.TextXAlignment.Center}); body.TextWrapped=true; body.ZIndex=102
	local no=Racing.Button(p,{Text="NO",Position=UDim2.new(.5,-158,1,-66),Size=UDim2.fromOffset(142,40),Color=Color3.fromRGB(166,61,70)}); no.ZIndex=103
	local yes=Racing.Button(p,{Text="YES",Position=UDim2.new(.5,16,1,-66),Size=UDim2.fromOffset(142,40),Color=Racing.Colour("PanelBlue",Color3.fromRGB(8,42,84)),StrokeColor=Racing.Colour("ElectricBlue")}); yes.ZIndex=103
	no.Activated:Connect(function() if modal then modal:Destroy(); modal=nil end end)
	yes.Activated:Connect(function() if modal then modal:Destroy(); modal=nil end; onConfirm() end)
end
local function showCash()]==]
	assert(string.find(applicationSource, modalAnchor, 1, true), "Missing application modal anchor")
	applicationSource = replaceOnce(applicationSource, modalAnchor, confirmation, "application modal helper")

	local replacement = [==[
local function vehicleDisplayName(vehicleId)
	local p=State.Profile or {}; local vehicle=p.Vehicles and p.Vehicles[vehicleId]; if not vehicle then return "ANOTHER VEHICLE" end
	local owned=p.OwnedCockpitInstances and p.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local category=categoryById(vehicle.CategoryId or State.CategoryId); local source=owned and cockpit(owned.TemplateId,category); return tostring(source and (source.DisplayName or source.CockpitId) or "ANOTHER VEHICLE")
end
local function sourceVehicleName(m) local _,name=moduleLineage(m); return tostring(name) end
local function sourceVehicleRating(m) local category=currentCategory(); local source=m and cockpit(m.SourceCockpitId,category); local value=source and performanceForCockpit(source); return math.floor(tonumber(value and value.Overall and value.Overall.PerformanceIndex) or 0) end
local function equipInstance(row,allowReassign)
	local r=action:Call("EquipModuleInstance",{ModuleInstanceId=row.Id,VehicleId=State.Profile.CurrentVehicleId,SlotId=State.SelectedSlot,AllowReassign=allowReassign==true})
	if r.Success then State.ModuleMode="Slots"; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewModules={}; buildPreview(); renderBuild() else message(r.Message) end
end
renderBuild=function()
	State.Stage="Build"; browser:Hide(); local c=common("Build Modules"); c.Subtitle=State.ModuleMode=="Slots" and "Choose a fixed module slot." or "Preview, then buy or equip."; c.NextText="Customise"; c.ShowLeft=State.ModuleMode~="Slots"; c.LeftItems={}; c.Cards={}
	if State.ModuleMode=="Slots" then
		for _,art in ipairs(workspaceUI:ArtworkDefinitions("Build")) do local s=slot(art.TargetId); if s then local installed=installedForSlot(s.SlotId); table.insert(c.Cards,{Id=s.SlotId,ImageKey=art.TargetId,DisplayName=art.DisplayName,Badge=installed and "EQUIPPED" or nil,BadgeColor=tierColor("S"),OnSelect=function() State.SelectedSlot=s.SlotId; State.ModuleMode="Options"; State.ModuleOptionMode="Owned"; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; section(s.SlotId); renderBuild() end}) end end
	else
		for _,mode in ipairs({"Owned","Buy"}) do table.insert(c.LeftItems,{Id=mode,Text=mode.." Modules",Selected=State.ModuleOptionMode==mode,OnSelect=function() State.ModuleOptionMode=mode; State.SelectedModuleId=nil; State.SelectedModuleInstanceId=nil; State.PreviewModules={}; buildPreview(); renderBuild() end}) end
		local s=slot(State.SelectedSlot); local _,installedInstance=installedForSlot(State.SelectedSlot)
		if State.ModuleOptionMode=="Owned" then
			local rows=ModuleCards.Owned({Instances=State.Profile.OwnedModuleInstances,Slot=s,ResolveModule=moduleById,Fits=moduleFits,CurrentVehicleId=State.Profile.CurrentVehicleId,InstalledInstanceId=installedInstance,VehicleName=vehicleDisplayName,SourceVehicleName=sourceVehicleName})
			for _,row in ipairs(rows) do
				local selected=State.SelectedModuleInstanceId==row.Id
				table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and row.State~="Equipped" and "EQUIP" or nil,OnSelect=function() State.SelectedModuleId=row.Module.ModuleId; State.SelectedModuleInstanceId=row.Id; State.PreviewModules={[State.SelectedSlot]=row.Module.ModuleId}; buildPreview(); renderBuild() end,OnAction=function() if row.State=="InUse" then confirmModuleMove(vehicleDisplayName(row.OwnerVehicleId),function() equipInstance(row,true) end) else equipInstance(row,false) end end})
			end
		else
			local rows=ModuleCards.Shop({Modules=modulesForSlot(State.SelectedSlot),IsLocked=function(m) local source=tostring(m.SourceCockpitId or ""); return source~="" and ownedCockpitCount(source)==0 end,SourceVehicleName=sourceVehicleName,SourceRating=sourceVehicleRating,OwnedCount=ownedModuleCount})
			for _,row in ipairs(rows) do
				local selected=State.SelectedModuleId==row.Id
				table.insert(c.Cards,{Id=row.Id,CardKind="Listing",VehicleName=row.VehicleName,Variant=row.Variant,Price=row.Price,Footer=row.Status,SemanticState=row.State,DisplayName=row.Variant,Selected=selected,Locked=row.Locked,LockImage=imageValue(replacementConfig:GetAttribute("ModuleLockIcon")),Badge=row.Rating>0 and tostring(row.Rating) or nil,BadgeColor=Color3.fromRGB(132,142,145),ActionText=selected and not row.Locked and "BUY" or nil,OnSelect=function() State.SelectedModuleId=row.Id; State.SelectedModuleInstanceId=nil; State.PreviewModules={[State.SelectedSlot]=row.Id}; buildPreview(); renderBuild() end,OnAction=function() local buy=action:Call("BuyModuleInstance",{ModuleId=row.Id}); if not buy.Success then message(buy.Message); return end; State.SelectedModuleId=row.Id; State.SelectedModuleInstanceId=nil; buildPreview(); renderBuild(); message("Module purchased. Open Owned Modules to equip it.") end})
			end
		end
	end
	c.OnBack=function() if State.ModuleMode=="Options" then State.ModuleMode="Slots"; State.ModuleOptionMode=nil; State.PreviewModules={}; buildPreview(); renderBuild() else renderPaint() end end; c.OnNext=function() local e,s,b=coreReady(); if not(e and s and b) then message("Equip one engine, stabilisers, and boost first."); return end; State.CustomizeTarget="ALL"; State.CustomizeMode="Colour"; renderCustomise() end; workspaceUI:Show(c)
end
]==]
	applicationSource = replaceRange(applicationSource, "local function ownedGroups(s)", "local function installedModule()", replacement, "module option renderer")
end
compile("ModuleShopUIController", applicationSource)

local componentsSource = components.Source
if not string.find(componentsSource, "NTR_GARAGE_MODULE_INSTANCE_CARD_RENDERER_V1", 1, true) then
	local renderer = [==[
-- NTR_GARAGE_MODULE_INSTANCE_CARD_RENDERER_V1
function M.ModuleListingCard(parent,props)
	props=props or {}; local selected=props.Selected==true; local state=tostring(props.SemanticState or "Shop")
	local pink=Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)); local blue=Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)); local grey=Color3.fromRGB(132,142,145)
	local accent=selected and blue or ((state=="InUse" or state=="Locked") and grey or pink); local fill=state=="Equipped" and Color3.fromRGB(92,31,73) or Racing.Colour("Panel",Color3.fromRGB(15,19,24))
	local card=Racing.Button(parent,{Name=props.Name or "ModuleListingCard",Text="",Size=props.Size or UDim2.fromOffset(210,146),Color=fill,StrokeColor=accent,FocusColor=blue,StrokeWidth=selected and 2 or 1.35}); card:SetAttribute("CanonicalGarageCard",true); card:SetAttribute("ModuleSemanticState",state); card.ClipsDescendants=false
	local surface=gradient(card,state=="Equipped" and Color3.fromRGB(118,38,91) or Racing.Colour("PanelSoft",Color3.fromRGB(25,31,39)),Racing.Colour("PanelDeep",Color3.fromRGB(9,12,16)),90); surface.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(1,.28)})
	local vehicle=Racing.Label(card,{Name="VehicleName",Text=string.upper(props.VehicleName or props.Eyebrow or "UNIVERSAL"),Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,20),TextSize=13,Role="Heading"}); vehicle.ZIndex=card.ZIndex+2
	local variant=tostring(props.Variant or props.DisplayName or "STANDARD"); local variantColour=variant=="Power" and pink or (variant=="Lightweight" and Color3.fromRGB(100,205,232) or grey)
	local tag=Instance.new("Frame"); tag.Name="Variant"; tag.BackgroundColor3=variantColour; tag.BorderSizePixel=0; tag.Position=UDim2.fromOffset(12,35); tag.Size=UDim2.fromOffset(112,25); tag.ZIndex=card.ZIndex+2; tag.Parent=card; Racing.Corner(tag,4); local tagText=Racing.Label(tag,{Text=string.upper(variant),Size=UDim2.fromScale(1,1),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Heading"}); tagText.ZIndex=tag.ZIndex+1
	if props.Badge then local rating=Instance.new("Frame"); rating.Name="ModuleRating"; rating.AnchorPoint=Vector2.new(1,0); rating.Position=UDim2.new(1,-12,0,35); rating.Size=UDim2.fromOffset(54,25); rating.BackgroundColor3=props.BadgeColor or grey; rating.BorderSizePixel=0; rating.ZIndex=card.ZIndex+2; rating.Parent=card; Racing.Corner(rating,4); local text=Racing.Label(rating,{Text=tostring(props.Badge),Size=UDim2.fromScale(1,1),TextSize=11,XAlignment=Enum.TextXAlignment.Center,Role="Metric"}); text.ZIndex=rating.ZIndex+1 end
	if props.Price~=nil and state~="Locked" then local price=Racing.Label(card,{Name="Price",Text="$"..tostring(props.Price),Position=UDim2.fromOffset(12,67),Size=UDim2.new(1,-24,0,23),TextSize=14,Color=Color3.fromRGB(89,255,102),Role="Heading"}); price.ZIndex=card.ZIndex+2 end
	if state=="Locked" and props.LockImage and props.LockImage~="" then local lock=Instance.new("ImageLabel"); lock.Name="LockIcon"; lock.BackgroundTransparency=1; lock.BorderSizePixel=0; lock.Image=props.LockImage; lock.AnchorPoint=Vector2.new(.5,.5); lock.Position=UDim2.fromScale(.5,.56); lock.Size=UDim2.fromOffset(42,42); lock.ZIndex=card.ZIndex+2; lock.Parent=card end
	local divider=Instance.new("Frame"); divider.BackgroundColor3=accent; divider.BackgroundTransparency=.48; divider.BorderSizePixel=0; divider.Position=UDim2.new(0,12,1,-39); divider.Size=UDim2.new(1,-24,0,1); divider.ZIndex=card.ZIndex+2; divider.Parent=card
	local footerColour=(state=="InUse" or state=="Locked") and grey or Racing.Colour("Text")
	local footer=Racing.Label(card,{Name="Status",Text=string.upper(props.Footer or ""),Position=UDim2.new(0,12,1,-34),Size=UDim2.new(1,-24,0,25),TextSize=10,Color=footerColour,XAlignment=Enum.TextXAlignment.Center,Role="Metric"}); footer.ZIndex=card.ZIndex+2
	return card
end
]==]
	componentsSource = replaceRange(componentsSource, "function M.ModuleListingCard(parent,props)", "function M.Popup(root)", renderer, "shared module listing card")
end
compile("GarageReplacementComponents", componentsSource)

local serverSource = actionController.Source
if not string.find(serverSource, "NTR_GARAGE_MODULE_REASSIGN_CONFIRM_V1", 1, true) then
	local guardAfter = [[		-- NTR_GARAGE_MODULE_REASSIGN_CONFIRM_V1
		local priorVehicleId = tostring(moduleInstance.EquippedVehicleId or "")
		if priorVehicleId ~= "" and priorVehicleId ~= vehicleId and args.AllowReassign ~= true then
			return false, "That module copy is already installed on another vehicle."
		end
]]
	serverSource = replaceRange(serverSource, "\t\tif moduleInstance.EquippedVehicleId ~= nil and moduleInstance.EquippedVehicleId ~= vehicleId then", "\t\tlocal module =", guardAfter, "server reassignment guard")
	-- Use an equals-delimited long string because the source text itself ends in `]`.
	local installAnchor = [==[		local previousInstanceId = vehicle.InstalledModules[slotId]]==]
	local installAfter = [==[		if priorVehicleId ~= "" and priorVehicleId ~= vehicleId then
			local priorVehicle = profile.Vehicles[priorVehicleId]
			if priorVehicle and typeof(priorVehicle.InstalledModules) == "table" then
				for priorSlotId, priorInstanceId in pairs(priorVehicle.InstalledModules) do if tostring(priorInstanceId)==moduleInstanceId then priorVehicle.InstalledModules[priorSlotId]=nil end end
			end
		end
		local previousInstanceId = vehicle.InstalledModules[slotId]]==]
	assert(string.find(serverSource, installAnchor, 1, true), "Missing server install anchor")
	serverSource = replaceOnce(serverSource, installAnchor, installAfter, "server prior-vehicle detach")
end
compile("GarageActionController", serverSource)

local existingViewModel = ui:FindFirstChild("GarageModuleCardViewModel")
if existingViewModel then assert(existingViewModel:IsA("ModuleScript"), "GarageModuleCardViewModel exists with the wrong class") end

local function audit()
	local failures={}
	local function expect(ok,text) if not ok then table.insert(failures,text) end end
	expect(string.find(applicationSource,"NTR_GARAGE_MODULE_INSTANCE_ACTIONS_V1",1,true)~=nil,"client action marker missing")
	expect(string.find(applicationSource,"local equip=action:Call(\"EquipModuleInstance\"",1,true)==nil,"legacy buy-then-equip chain remains")
	expect(string.find(componentsSource,"NTR_GARAGE_MODULE_INSTANCE_CARD_RENDERER_V1",1,true)~=nil,"shared renderer marker missing")
	expect(string.find(serverSource,"NTR_GARAGE_MODULE_REASSIGN_CONFIRM_V1",1,true)~=nil,"server reassignment marker missing")
	if #failures>0 then error("[NTR Garage Module Instance Cards] AUDIT FAIL: "..table.concat(failures," | "),0) end
	print("[NTR Garage Module Instance Cards] AUDIT PASS - separate copies, Buy/Equip split, shared semantic cards, confirmed reassignment")
end

audit()
if MODE=="AUDIT" then return end
assert(MODE=="INSTALL", "MODE must be INSTALL or AUDIT")

local originals={{application,application.Source},{components,components.Source},{actionController,actionController.Source}}
local createdViewModel=false
local oldViewModelSource=existingViewModel and existingViewModel.Source or nil
local oldLockIcon=replacementConfig:GetAttribute("ModuleLockIcon")
local ok,err=xpcall(function()
	local viewModel=existingViewModel
	if not viewModel then viewModel=Instance.new("ModuleScript"); viewModel.Name="GarageModuleCardViewModel"; viewModel.Parent=ui; createdViewModel=true end
	viewModel.Source=viewModelSource
	if replacementConfig:GetAttribute("ModuleLockIcon")==nil then replacementConfig:SetAttribute("ModuleLockIcon","") end
	components.Source=componentsSource
	application.Source=applicationSource
	actionController.Source=serverSource
	assert(components.Source==componentsSource and application.Source==applicationSource and actionController.Source==serverSource,"Source readback mismatch")
	print("[NTR Garage Module Instance Cards] INSTALL PASS")
	print("Restart Play. Buying must leave the new copy available; select it under Owned Modules and use the centred EQUIP action.")
end,debug.traceback)
if not ok then
	for i=#originals,1,-1 do pcall(function() originals[i][1].Source=originals[i][2] end) end
	if createdViewModel then pcall(function() ui.GarageModuleCardViewModel:Destroy() end) end
	if existingViewModel and oldViewModelSource then pcall(function() existingViewModel.Source=oldViewModelSource end) end
	pcall(function() replacementConfig:SetAttribute("ModuleLockIcon",oldLockIcon) end)
	error("[NTR Garage Module Instance Cards] INSTALL ABORTED and rolled back: "..tostring(err),0)
end
