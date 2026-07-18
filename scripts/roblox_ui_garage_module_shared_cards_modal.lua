-- Neo Tokyo Racers - Shared physical-module cards and centred modal
-- NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1
-- Run once in Roblox Studio EDIT mode from the Command Bar.

local MODE="INSTALL" -- INSTALL or AUDIT
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Edit mode, not Play mode")

local REVISION="NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1"

local function need(parent,name,className)
	local object=parent:FindFirstChild(name)
	assert(object and object:IsA(className),"Missing "..parent:GetFullName().."."..name.." ("..className..")")
	return object
end

local function compile(name,source)
	local fn,err=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(err))
end

local function replaceOnce(source,before,after,label)
	local first,last=string.find(source,before,1,true)
	assert(first,"Missing source anchor: "..label)
	assert(not string.find(source,before,last+1,true),"Duplicate source anchor: "..label)
	return string.sub(source,1,first-1)..after..string.sub(source,last+1)
end

local function replaceRange(source,firstMarker,nextMarker,replacement,label)
	local first=string.find(source,firstMarker,1,true)
	assert(first,"Missing source start anchor: "..label)
	assert(not string.find(source,firstMarker,first+#firstMarker,true),"Duplicate source start anchor: "..label)
	local nextAt=string.find(source,nextMarker,first+#firstMarker,true)
	assert(nextAt,"Missing source end anchor: "..label)
	return string.sub(source,1,first-1)..replacement..string.sub(source,nextAt)
end

local garage=need(need(need(ServerScriptService,"NeoTokyoRacers","Folder"),"Services","Folder"),"Garage","Folder")
local transactionRuntime=need(garage,"GarageModuleTransactionRuntime","ModuleScript")
assert(string.find(transactionRuntime.Source,"NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1",1,true),"Atomic module transaction baseline missing")

local starterScripts=need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts")
local clientRoot=need(starterScripts,"NeoTokyoRacersClient","Folder")
local ui=need(need(clientRoot,"Controllers","Folder"),"UI","Folder")
local viewModel=need(ui,"GarageModuleCardViewModel","ModuleScript")
local shared=need(ui,"GarageReplacementComponents","ModuleScript")
local workspace=need(ui,"GarageWorkspaceController","ModuleScript")
local application=need(ui,"ModuleShopUIController","ModuleScript")

assert(string.find(viewModel.Source,"NTR_GARAGE_MODULE_INSTANCE_VIEW_MODEL_V1",1,true) or string.find(viewModel.Source,REVISION,1,true),"Physical module view-model baseline missing")
assert(string.find(shared.Source,"NTR_GARAGE_MODULE_INSTANCE_CARD_RENDERER_V1",1,true),"Shared listing-card renderer baseline missing")
assert(string.find(workspace.Source,"NTR_GARAGE_WORKSPACE_CONTROLLER_V3",1,true),"Canonical workspace renderer baseline missing")
assert(string.find(application.Source,"NTR_GARAGE_MODULE_ATOMIC_TRANSACTIONS_V1",1,true),"Atomic module client flow baseline missing")

local viewModelSource=[==[
-- NTR_GARAGE_MODULE_INSTANCE_VIEW_MODEL_V1
-- NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1
local ViewModel={}
local variantOrder={Standard=1,Lightweight=2,Power=3}
local stateOrder={Equipped=1,Available=2,InUse=3}

function ViewModel.Variant(module)
	local explicit=tostring(module and module.VariantName or "")
	if explicit=="Standard" or explicit=="Lightweight" or explicit=="Power" then return explicit end
	local name=string.lower(tostring(module and (module.DisplayName or module.ModuleId) or ""))
	if string.find(name,"lightweight",1,true) then return "Lightweight" end
	if string.find(name,"power",1,true) then return "Power" end
	return "Standard"
end

function ViewModel.Rating(module,instance)
	return math.floor(tonumber(instance and (instance.Rating or instance.PerformanceRating or instance.PerformanceIndex)) or tonumber(module and (module.Rating or module.PerformanceRating or module.PerformanceIndex)) or 0)
end

function ViewModel.Owned(context)
	local rows={}
	for instanceId,item in pairs(context.Instances or {}) do
		local module=context.ResolveModule(item.TemplateId)
		if module and context.Fits(module,context.Slot) then
			local owner=tostring(item.EquippedVehicleId or ""); local state,status
			if tostring(instanceId)==tostring(context.InstalledInstanceId or "") then state,status="Equipped","EQUIPPED"
			elseif owner~="" and owner~=tostring(context.CurrentVehicleId or "") then state,status="InUse","IN USE BY "..string.upper(context.VehicleName(owner))
			else state,status="Available","AVAILABLE" end
			table.insert(rows,{Id=tostring(instanceId),Module=module,Item=item,State=state,Status=status,Variant=ViewModel.Variant(module),VehicleName=context.SourceVehicleName(module),Rating=ViewModel.Rating(module,item),OwnerVehicleId=owner})
		end
	end
	table.sort(rows,function(a,b)
		local aState=stateOrder[a.State] or 99; local bState=stateOrder[b.State] or 99
		if aState~=bState then return aState<bState end
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
compile("GarageModuleCardViewModel",viewModelSource)

local workspaceSource=workspace.Source
if not string.find(workspaceSource,REVISION,1,true) then
	local oldProps=[[local selected=row.Selected==true; local props={DisplayName=row.DisplayName or row.Id or "",Eyebrow=row.Eyebrow,Meta=row.Meta,Footer=row.Footer,Image=self:ResolveImage(row.ImageKey or row.Id,row.Image),Rating=row.Badge,RatingColor=row.BadgeColor,Selected=selected,Size=UDim2.fromOffset(N("WorkspaceCardWidth",210),N("WorkspaceCardHeight",146)),ImageHeight=N("ModuleCardImageHeight",104),ImageZoom=row.ImageZoom or 1.04}]]
	local newProps=[[-- NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1
		local selected=row.Selected==true; local props={DisplayName=row.DisplayName or row.Id or "",Eyebrow=row.Eyebrow,Meta=row.Meta,Footer=row.Footer,Image=self:ResolveImage(row.ImageKey or row.Id,row.Image),Rating=row.Badge,RatingColor=row.BadgeColor,Badge=row.Badge,BadgeColor=row.BadgeColor,Selected=selected,VehicleName=row.VehicleName,Variant=row.Variant,Price=row.Price,SemanticState=row.SemanticState,LockImage=row.LockImage,Size=UDim2.fromOffset(N("WorkspaceCardWidth",210),N("WorkspaceCardHeight",146)),ImageHeight=N("ModuleCardImageHeight",104),ImageZoom=row.ImageZoom or 1.04}]]
	workspaceSource=replaceOnce(workspaceSource,oldProps,newProps,"shared listing-card property forwarding")
end
compile("GarageWorkspaceController",workspaceSource)

local applicationSource=application.Source
if not string.find(applicationSource,REVISION,1,true) then
	local modalReplacement=[==[
-- NTR_GARAGE_MODULE_SHARED_CARDS_MODAL_V1
local function modalBase(title)
	if modal then modal:Destroy() end
	local host=Shared.CanonicalHost(); modal=Instance.new("Frame"); modal.Name="CanonicalGarageModal"; modal.Active=true; modal.BackgroundColor3=Color3.new(0,0,0); modal.BackgroundTransparency=.22; modal.BorderSizePixel=0; modal.Position=UDim2.fromOffset(0,0); modal.Size=UDim2.fromScale(1,1); modal.ZIndex=100; modal.Parent=host.Canvas
	local panel=Shared.Panel(modal,"Panel",{StrokeColor=Racing.Colour("ElectricBlue"),NoGlow=true}); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(620,420); panel.ZIndex=101
	Racing.Label(panel,{Text=title,Position=UDim2.fromOffset(18,12),Size=UDim2.new(1,-76,0,34),TextSize=18,Role="Heading"}).ZIndex=102
	local x=Racing.Button(panel,{Text="X",Position=UDim2.new(1,-50,0,10),Size=UDim2.fromOffset(38,32),Color=Color3.fromRGB(166,61,70)}); x.ZIndex=103; x.Activated:Connect(function() if modal then modal:Destroy(); modal=nil end end)
	task.defer(function() RunService.Heartbeat:Wait(); if not (modal and modal.Parent and panel.Parent) then return end; local canvas=host.Canvas; local fills=math.abs(modal.AbsolutePosition.X-canvas.AbsolutePosition.X)<=2 and math.abs(modal.AbsolutePosition.Y-canvas.AbsolutePosition.Y)<=2 and math.abs(modal.AbsoluteSize.X-canvas.AbsoluteSize.X)<=2 and math.abs(modal.AbsoluteSize.Y-canvas.AbsoluteSize.Y)<=2; local centred=math.abs((panel.AbsolutePosition.X+panel.AbsoluteSize.X*.5)-(modal.AbsolutePosition.X+modal.AbsoluteSize.X*.5))<=2 and math.abs((panel.AbsolutePosition.Y+panel.AbsoluteSize.Y*.5)-(modal.AbsolutePosition.Y+modal.AbsoluteSize.Y*.5))<=2; if fills and centred then print("[NTR Garage Module Cards] MODAL GEOMETRY PASS") else warn("[NTR Garage Module Cards] MODAL GEOMETRY FAIL fills="..tostring(fills).." centred="..tostring(centred)) end end)
	return panel
end
]==]
	applicationSource=replaceRange(applicationSource,"local function modalBase(title)","-- NTR_GARAGE_MODULE_INSTANCE_ACTIONS_V1",modalReplacement,"canonical full-canvas modal")

	local lineageReplacement=[==[
local function moduleLineage(m)
	local category=currentCategory() or {}; local categoryDisplay=tostring(category.DisplayName or category.CategoryId or "Vehicle"); local categoryName=string.upper(categoryDisplay)
	local function fullName(name) name=tostring(name or ""); if name=="" then return categoryDisplay.." Vehicle" end; if string.find(string.lower(name),string.lower(categoryDisplay),1,true)==1 then return name end; return categoryDisplay.." "..name end
	local direct=tostring(m and m.SourceCockpitDisplayName or ""); if direct~="" then return categoryName,fullName(direct) end
	local sourceId=tostring(m and m.SourceCockpitId or ""); local source=sourceId~="" and cockpit(sourceId,category) or nil
	return categoryName,fullName(source and (source.DisplayName or source.CockpitId) or (sourceId~="" and sourceId or "Vehicle"))
end
]==]
	applicationSource=replaceRange(applicationSource,"local function moduleLineage(m)","local function ownedModuleCount(moduleId)",lineageReplacement,"authoritative module source vehicle name")
end
compile("ModuleShopUIController",applicationSource)

local failures={}
local function expect(ok,message) if not ok then table.insert(failures,message) end end
expect(string.find(viewModelSource,"local stateOrder={Equipped=1,Available=2,InUse=3}",1,true)~=nil,"owned-state order missing")
expect(string.find(workspaceSource,"VehicleName=row.VehicleName",1,true)~=nil,"vehicle name forwarding missing")
expect(string.find(workspaceSource,"Price=row.Price",1,true)~=nil,"green price forwarding missing")
expect(string.find(workspaceSource,"SemanticState=row.SemanticState",1,true)~=nil,"semantic card state forwarding missing")
expect(string.find(workspaceSource,"Badge=row.Badge",1,true)~=nil,"module rating badge forwarding missing")
expect(string.find(applicationSource,"SourceCockpitDisplayName",1,true)~=nil,"authoritative source vehicle display name missing")
expect(string.find(applicationSource,"modal.Size=UDim2.fromScale(1,1)",1,true)~=nil,"full-canvas modal backdrop missing")
expect(string.find(applicationSource,"MODAL GEOMETRY PASS",1,true)~=nil,"runtime modal geometry audit missing")
if #failures>0 then error("[NTR Garage Module Cards] AUDIT FAIL: "..table.concat(failures," | "),0) end
print("[NTR Garage Module Cards] PREFLIGHT PASS")
if MODE=="AUDIT" then return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")

local oldViewModelSource=viewModel.Source; local oldWorkspaceSource=workspace.Source; local oldApplicationSource=application.Source
local ok,err=xpcall(function()
	viewModel.Source=viewModelSource; workspace.Source=workspaceSource; application.Source=applicationSource
	assert(viewModel.Source==viewModelSource and workspace.Source==workspaceSource and application.Source==applicationSource,"Source readback mismatch")
	print("[NTR Garage Module Cards] INSTALL PASS")
	print("Restart Play. Verify source vehicle names and green prices; owned order EQUIPPED > AVAILABLE > IN USE; pink/grey/cyan card semantics; and a full-screen centred reassignment confirmation at desktop and mobile sizes.")
end,debug.traceback)
if not ok then
	pcall(function() viewModel.Source=oldViewModelSource end); pcall(function() workspace.Source=oldWorkspaceSource end); pcall(function() application.Source=oldApplicationSource end)
	error("[NTR Garage Module Cards] INSTALL ABORTED and rolled back: "..tostring(err),0)
end
