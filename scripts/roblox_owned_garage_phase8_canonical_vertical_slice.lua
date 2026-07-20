-- Neo Tokyo Racers - Owned Garage Phase 8 canonical vertical slice

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")

local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 8]"
local REVISION="NTR_OWNED_GARAGE_PHASE8_CANONICAL_VERTICAL_SLICE_V1_8"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end
	return object
end
local function has(object,marker) return object and object:IsA("LuaSourceContainer") and string.find(object.Source,marker,1,true)~=nil end
local function replaceOnce(source,old,new,label)
	local first,last=string.find(source,old,1,true); assert(first,label.." anchor missing"); assert(not string.find(source,old,last+1,true),label.." anchor is not unique")
	return string.sub(source,1,first-1)..new..string.sub(source,last+1)
end
local function compile(name,source) local fn,problem=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(problem)) end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage_EditAttributes missing")
local replacementConfig=assert(find(kit,"Config.UI.GarageReplacement"),"GarageReplacement config missing")
local garage=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"UI controllers missing")
local data=assert(find(kit,"Shared.Modules.Data"),"Shared data modules missing")

local installedRevision=config:GetAttribute("OwnedGarageRevision")
assert(installedRevision=="NTR_OWNED_GARAGE_PHASE7_REUSABLE_PROPERTY_FRAMEWORK_V1" or installedRevision=="NTR_OWNED_GARAGE_PHASE8_CANONICAL_VERTICAL_SLICE_V1_3" or installedRevision=="NTR_OWNED_GARAGE_PHASE8_CANONICAL_VERTICAL_SLICE_V1_4" or installedRevision=="NTR_OWNED_GARAGE_PHASE8_CANONICAL_VERTICAL_SLICE_V1_5" or installedRevision=="NTR_OWNED_GARAGE_PHASE8_CANONICAL_VERTICAL_SLICE_V1_6" or installedRevision=="NTR_OWNED_GARAGE_PHASE8_CANONICAL_VERTICAL_SLICE_V1_7" or installedRevision==REVISION,"Confirmed Phase 7/Phase 8 mixed baseline is not current")
local catalog=assert(data:FindFirstChild("OwnedGaragePropertyCatalog"),"OwnedGaragePropertyCatalog missing")
local profileRuntime=assert(garage:FindFirstChild("OwnedGarageProfileRuntime"),"OwnedGarageProfileRuntime missing")
local management=assert(garage:FindFirstChild("OwnedGarageManagementRuntime"),"OwnedGarageManagementRuntime missing")
local assignment=assert(garage:FindFirstChild("OwnedGarageDisplayAssignmentRuntime"),"OwnedGarageDisplayAssignmentRuntime missing")
local action=assert(garage:FindFirstChild("GarageActionController_Shadow_Disabled"),"GarageActionController missing")
local shared=assert(ui:FindFirstChild("GarageReplacementComponents"),"GarageReplacementComponents missing")
local workspaceBase=assert(ui:FindFirstChild("GarageWorkspaceController"),"GarageWorkspaceController missing")
local browser=assert(ui:FindFirstChild("OwnedGarageBrowserController"),"OwnedGarageBrowserController missing")
local workspace=assert(ui:FindFirstChild("OwnedGarageWorkspaceController"),"OwnedGarageWorkspaceController missing")
local interiorMode=assert(ui:FindFirstChild("GarageInteriorModeController"),"GarageInteriorModeController missing")
local clientStarter=assert(ui:FindFirstChild("OwnedGarageClient_Active"),"OwnedGarageClient_Active missing")
local desktop=assert(ui:FindFirstChild("DesktopFreeRoamHudController_Active"),"Desktop HUD missing")
local mobile=assert(ui:FindFirstChild("MobileFreeRoamHudController_Active"),"Mobile HUD missing")
local profileService=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Player.ProfileService_Active"),"ProfileService_Active missing")
local commandRuntime=garage:FindFirstChild("OwnedGarageAuthoritativeCommandRuntime")
assert(commandRuntime==nil or commandRuntime:IsA("ModuleScript"),"OwnedGarageAuthoritativeCommandRuntime must be a ModuleScript")
for object,marker in pairs({[catalog]="NTR_OWNED_GARAGE_PROPERTY_CATALOG_V2_DEFINITION_CONTRACT",[management]="NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V3_REUSABLE_FRAMEWORK",[assignment]="NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V2_REVISIONED"}) do assert(has(object,marker),"Phase 7 contract missing: "..marker) end
assert(string.find(profileRuntime.Source,'if tostring(assigned or "")==vehicleId then other.DisplaySpaces[otherSlot]=false end',1,true),"Duplicate-only vehicle move contract is missing")
assert(has(workspace,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V3_REVISIONED") or has(workspace,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V4_CANONICAL_VERTICAL_SLICE") or has(workspace,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V5_REFRESH_OWNER") or has(workspace,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V6_EXPLICIT_DISPLAY_COMMIT") or has(workspace,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V7_AUTHORITATIVE_SELECTED_ACTION"),"Confirmed Phase 7/Phase 8 workspace contract missing")

local workspaceControllerSource=[==[
-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V4_CANONICAL_VERTICAL_SLICE
-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V5_REFRESH_OWNER
-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V6_EXPLICIT_DISPLAY_COMMIT
-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V7_AUTHORITATIVE_SELECTED_ACTION
local Controller={}; local started=false; local closeCurrent=function() end; local isOpenCurrent=function() return false end
function Controller.Close(reason) closeCurrent(reason) end
function Controller.IsOpen() return isOpenCurrent() end
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local ReplicatedStorage=game:GetService("ReplicatedStorage"); local HttpService=game:GetService("HttpService"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui")
	local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers"); local uiFolder=script.Parent; local WorkspaceUI=require(uiFolder:WaitForChild("GarageWorkspaceController")); local Shared=require(uiFolder:WaitForChild("GarageReplacementComponents")); local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents")); local remote=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageInvoke"); local push=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageEvent"); local openEvent=uiFolder:WaitForChild("OpenOwnedGarageWorkspace"); local cfg=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes"); local replacement=kit.Config.UI:WaitForChild("GarageReplacement"); local navIcons=replacement:WaitForChild("NavigationIcons"); local icons=replacement:FindFirstChild("OwnedGarageIcons") or navIcons
	local workspace=WorkspaceUI.new(); workspace.Root.Name="OwnedGarageCanonicalWorkspace"
	local state; local page="DisplaySpaces"; local selectedSlot; local selectedVehicle; local previewReady=false; local previewGeneration=0; local busy=false; local refreshRunning=false; local queuedRevision; local generation=0; local modal
	local tierColours={E=Color3.fromRGB(132,142,145),D=Color3.fromRGB(105,190,129),C=Color3.fromRGB(74,204,211),B=Color3.fromRGB(82,137,235),A=Color3.fromRGB(244,188,65),S=Color3.fromRGB(236,92,168)}
	local function asset(value) return UI.Asset(value or "") end
	local iconFallback={DisplayCars="OwnedModulesIcon",Structure="BuildModulesIcon",Decorations="CustomiseModulesIcon",Lighting="BuyModulesIcon"}
	local function icon(name) return asset(icons:GetAttribute(name) or navIcons:GetAttribute(iconFallback[name] or "")) end
	local function navIcon(name) return asset(navIcons:GetAttribute(name) or navIcons:GetAttribute(name.."Icon")) end
	local function request(action,args) local startedAt=os.clock(); local ok,result=pcall(function() return remote:InvokeServer(action,args or {}) end); if cfg:GetAttribute("DebugTimingEnabled")==true then print("[NTR Owned Garage Timing] action="..action.." remoteMs="..math.floor((os.clock()-startedAt)*1000+.5)) end; if ok and type(result)=="table" then return result end; return {Success=false,Message="Garage management is unavailable."} end
	local function property() for _,item in ipairs(state and state.Properties or {}) do if item.PropertyId==state.CurrentPropertyId then return item end end; return state and state.Properties and state.Properties[1] end
	local function vehicle(id) for _,item in ipairs(state and state.Vehicles or {}) do if item.VehicleId==tostring(id or "") then return item end end end
	local function slot(id) for _,item in ipairs(state and state.Slots or {}) do if item.SlotId==tostring(id or "") then return item end end end
	local function closeModal() if modal then modal:Destroy(); modal=nil end end
	local function setManagementOpen(open) playerGui:SetAttribute("NTR_OwnedGarageManagementOpen",open==true) end
	local function cancelPreview() previewGeneration+=1; previewReady=false; selectedVehicle=nil; if state and state.InGarage then task.spawn(function() request("CancelDisplayPreview",{}) end) end end
	local function close() generation+=1; closeModal(); setManagementOpen(false); workspace:Hide(); if state and state.InGarage then task.spawn(function() request("CancelDisplayPreview",{}); request("SetManagementOpen",{Open=false}) end) end end
	closeCurrent=close; isOpenCurrent=function() return workspace.Root.Visible end
	local function refresh(token)
		if refreshRunning then return false end
		refreshRunning=true; local result=request("GetManagementState",{}); refreshRunning=false
		if token~=generation then return false end
		if not result.Success then workspace:Message(result.Message or "Garage state could not be refreshed. Please try again."); return false end
		if not result.InGarage then workspace:Message(result.Message or "Management requires an active garage interior."); close(); return false end
		state=result
		if queuedRevision and tonumber(queuedRevision) and tonumber(queuedRevision)<=tonumber(state.Revision or 0) then queuedRevision=nil end
		return true
	end
	local render
	local function operate(action,args,nextPage,expectedSlotId,expectedVehicleId)
		if busy then return end; args=type(args)=="table" and args or {}; args.BaseRevision=state and state.Revision or nil; args.RequestId=HttpService:GenerateGUID(false); busy=true; workspace:Message("SAVING GARAGE..."); local result=request(action,args); busy=false
		if not result.Success then if result.Conflict then local token=generation; if refresh(token) then render(true) end end; workspace:Message(result.Message or "Garage update failed."); return end
		local committedState=type(result.ManagementState)=="table" and result.ManagementState or nil
		if expectedSlotId and expectedVehicleId then
			local committed=false
			if committedState then for _,space in ipairs(committedState.Slots or {}) do if tostring(space.SlotId or "")==tostring(expectedSlotId) and tostring(space.VehicleId or "")==tostring(expectedVehicleId) then committed=true; break end end
			else local raw=result.State; local propertyState=raw and raw.Properties and raw.Properties[state and state.CurrentPropertyId]; committed=propertyState and propertyState.DisplaySpaces and tostring(propertyState.DisplaySpaces[expectedSlotId] or "")==tostring(expectedVehicleId) end
			if not committed then workspace:Message("Display was not committed. Your saved garage was left unchanged."); return end
		end
		if committedState and committedState.Success then state=committedState; queuedRevision=nil; page=nextPage or page; previewReady=false; selectedVehicle=nil; render(true); workspace:Message("VEHICLE DISPLAYED")
		else local token=generation; if refresh(token) then queuedRevision=nil; page=nextPage or page; previewReady=false; selectedVehicle=nil; render(true); workspace:Message("VEHICLE DISPLAYED") end end
	end
	local function preview(vehicleId)
		if busy or not selectedSlot then return end
		previewGeneration+=1; local previewToken=previewGeneration; local token=generation; local requestedVehicle=tostring(vehicleId or ""); local requestedSlot=selectedSlot; previewReady=false; selectedVehicle=nil; workspace:Message("LOADING VEHICLE PREVIEW...")
		task.spawn(function()
			local result=request("PreviewDisplay",{SlotId=requestedSlot,VehicleId=requestedVehicle})
			if token~=generation or previewToken~=previewGeneration or page~="DisplayVehicles" then return end
			if not result.Success then workspace:Message(result.Message or "Vehicle preview failed."); render(false); return end
			selectedVehicle=requestedVehicle; previewReady=true; render(false)
		end)
	end
	local function confirmUsedElsewhere(item,onYes)
		closeModal(); modal=Shared.ConfirmationModal(workspace.Root,{Title="VEHICLE ALREADY DISPLAYED",Body="This vehicle is displayed in "..tostring(item.DisplayedGarageName or "another garage")..". Move it here?",ConfirmText="CONTINUE",CancelText="CANCEL",OnConfirm=function() modal=nil; onYes() end,OnCancel=function() modal=nil end})
	end
	local function tabs()
		local definitions={{Id="DisplayCars",Text="Display Cars",Image=icon("DisplayCars"),Enabled=true},{Id="Structure",Text="Structure",Image=icon("Structure"),Enabled=state and state.Capabilities and state.Capabilities.Structure},{Id="Decorations",Text="Decorations",Image=icon("Decorations"),Enabled=state and state.Capabilities and state.Capabilities.Decorations},{Id="Lighting",Text="Lighting",Image=icon("Lighting"),Enabled=state and state.Capabilities and state.Capabilities.Lighting}}
		local result={}; for _,definition in ipairs(definitions) do local item=definition; local selected=(item.Id=="DisplayCars" and (page=="DisplaySpaces" or page=="DisplayVehicles")) or page==item.Id; table.insert(result,{Id=item.Id,Text=item.Text,Image=item.Image,ImageZoom=.5,Selected=selected,OnSelect=function() if item.Id=="DisplayCars" then page="DisplaySpaces" else page=item.Id end; cancelPreview(); render(true) end}) end; return result
	end
	local function context(subtitle,cards)
		local item=property(); return {Title="GARAGE MANAGEMENT",Subtitle=subtitle,ShowLeft=true,LeftItems=tabs(),LeftFloating=true,LeftCardMode=true,LeftSharedCardSize=true,LeftAlignCarouselBottom=true,Cards=cards,Cash=state and state.Cash or 0,CapacityText=tostring(item and item.Filled or 0).."/"..tostring(item and item.Capacity or 0).." DISPLAY SPACES",ShowStats=false,ShowCashPlus=true,ShowCapacityPlus=false,NextVisible=false,ExitVisible=true,ExitText="EXIT",ExitIcon=navIcon("Exit"),BackIcon=navIcon("Back"),OnExit=close,CarouselScrollKey="OwnedGarage:"..page,CategoryScrollKey="OwnedGarageTabs",RuntimeAudit=false}
	end
	render=function(full)
		if not state then return end; local cards={}; local view
		if page=="DisplaySpaces" then
			if not selectedSlot or not slot(selectedSlot) then selectedSlot=state.Slots and state.Slots[1] and state.Slots[1].SlotId end
			for _,space in ipairs(state.Slots or {}) do local spaceItem=space; local vehicleItem=vehicle(spaceItem.VehicleId); local row={Id=spaceItem.SlotId,CardKind="Vehicle",DisplayName=vehicleItem and vehicleItem.DisplayName or "EMPTY DISPLAY SPACE",Image=vehicleItem and asset(vehicleItem.Image) or "",Badge=vehicleItem and (tostring(vehicleItem.Tier).." "..tostring(vehicleItem.Rating)) or nil,BadgeColor=vehicleItem and tierColours[vehicleItem.Tier] or nil,Selected=spaceItem.SlotId==selectedSlot,Footer=vehicleItem and "DISPLAYED" or "ADD VEHICLE",EmptyPlus=vehicleItem==nil}; row.OnSelect=function() selectedSlot=spaceItem.SlotId; render(false) end; table.insert(cards,row) end
			view=context("Choose a display space to manage.",cards)
			local selectedSpace=slot(selectedSlot); view.SelectedAction={RowId=selectedSlot,Text=(selectedSpace and selectedSpace.VehicleId and selectedSpace.VehicleId~=false) and "CHANGE VEHICLE" or "ADD VEHICLE",OnActivate=function() previewReady=false; selectedVehicle=nil; page="DisplayVehicles"; render(true) end}
		elseif page=="DisplayVehicles" then
			local currentSlot=slot(selectedSlot); local assigned=tostring(currentSlot and currentSlot.VehicleId or ""); if assigned=="false" then assigned="" end
			local vehicles={}; for _,item in ipairs(state.Vehicles or {}) do table.insert(vehicles,item) end; table.sort(vehicles,function(a,b) if a.UsedInOtherGarage~=b.UsedInOtherGarage then return not a.UsedInOtherGarage end; if a.Rating~=b.Rating then return a.Rating>b.Rating end; return a.DisplayName<b.DisplayName end)
			for _,item in ipairs(vehicles) do local vehicleItem=item; local current=vehicleItem.VehicleId==assigned; local isReady=previewReady and vehicleItem.VehicleId==selectedVehicle; local row={Id=vehicleItem.VehicleId,CardKind="Vehicle",DisplayName=vehicleItem.DisplayName,Image=asset(vehicleItem.Image),Badge=tostring(vehicleItem.Tier).." "..tostring(vehicleItem.Rating),BadgeColor=tierColours[vehicleItem.Tier],Selected=isReady,Footer=current and "CURRENT DISPLAY" or (vehicleItem.UsedInOtherGarage and "USED IN "..string.upper(vehicleItem.DisplayedGarageName or "ANOTHER GARAGE") or "OWNED VEHICLE"),Muted=vehicleItem.UsedInOtherGarage}; row.OnSelect=function() preview(vehicleItem.VehicleId) end; table.insert(cards,row) end
			view=context(previewReady and "Preview ready. Press DISPLAY to save this vehicle." or "Choose a vehicle for this display space.",cards); view.BackVisible=true; view.BackText="BACK"; view.OnBack=function() cancelPreview(); page="DisplaySpaces"; render(true) end; view.EmptyMessage="NO OWNED VEHICLES AVAILABLE"
			local chosen=previewReady and vehicle(selectedVehicle) or nil; if chosen then local current=chosen.VehicleId==assigned; view.SelectedAction={RowId=chosen.VehicleId,Text=current and "DISPLAYED" or "DISPLAY",OnActivate=function() if current or busy or not previewReady then return end; local targetSlot=selectedSlot; local targetVehicle=chosen.VehicleId; local apply=function() operate("AssignDisplay",{SlotId=targetSlot,VehicleId=targetVehicle},"DisplaySpaces",targetSlot,targetVehicle) end; if chosen.UsedInOtherGarage then confirmUsedElsewhere(chosen,apply) else apply() end end} end
		else
			view=context(page.." is definition-ready and activates in its dedicated implementation phase.",{}); view.EmptyMessage=string.upper(page).." COMING NEXT"; view.BackVisible=true; view.BackText="BACK"; view.OnBack=function() page="DisplaySpaces"; render(true) end
		end
		local startedAt=os.clock(); if full~=false or not workspace.Root.Visible then workspace:Show(view) else workspace:RefreshCards(view) end; if cfg:GetAttribute("DebugTimingEnabled")==true then print("[NTR Owned Garage Timing] page="..page.." renderMs="..math.floor((os.clock()-startedAt)*1000+.5)) end
	end
	local function open(requested)
		generation+=1; local token=generation; page=type(requested)=="table" and tostring(requested.Page or "DisplaySpaces") or "DisplaySpaces"; selectedVehicle=nil; setManagementOpen(true)
		if state and state.InGarage then render(true) else workspace:Show(context("Loading garage management...",{})); workspace:Message("LOADING GARAGE...") end
		task.spawn(function() request("SetManagementOpen",{Open=true}); if refresh(token) then selectedSlot=(state.Slots and state.Slots[1] and state.Slots[1].SlotId) or nil; render(true) end end)
	end
	openEvent.Event:Connect(function(requested) if workspace.Root.Visible then close() else open(requested) end end)
	push.OnClientEvent:Connect(function(message)
		if type(message)~="table" then return end
		if message.Type=="OpenManagement" then if not workspace.Root.Visible then open() end
		elseif message.Type=="DriveOut" then close()
		elseif message.Type=="ManagementUpdated" and workspace.Root.Visible then
			local revision=tonumber(message.Revision); if revision and state and revision<=tonumber(state.Revision or 0) then return end
			if busy or refreshRunning then queuedRevision=math.max(tonumber(queuedRevision) or 0,revision or 0); return end
			local token=generation; task.spawn(function() if refresh(token) then render(true) end end)
		elseif message.Type=="DriveOutResult" and message.Success==false then workspace:Message(message.Message or "Could not drive out.") end
	end)
	started=true; print("[NTR Owned Garage] Canonical Phase 8 workspace active."); return true,"Started"
end
return Controller
]==]

local interiorModeSource=[==[
-- NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V2_PHASE8_EXISTING_OWNER
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local Players=game:GetService("Players"); local UserInputService=game:GetService("UserInputService"); local player=Players.LocalPlayer; local playerGui=player:WaitForChild("PlayerGui"); local kit=game:GetService("ReplicatedStorage"):WaitForChild("NeoTokyoRacers"); local UI=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents")); local Shared=require(script.Parent:WaitForChild("GarageReplacementComponents")); local remote=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageInvoke"); local push=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageEvent")
	local function publish() playerGui:SetAttribute("NTR_OwnedGarageInteriorMode",player:GetAttribute("NTR_OwnedGarageInside")==true) end
	local gui=Instance.new("ScreenGui"); gui.Name="NTR_OwnedGarageInteriorHUD"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false; gui.DisplayOrder=58; gui.Parent=playerGui
	local root=Instance.new("Frame"); root.Name="AccessControls"; root.BackgroundTransparency=1; root.Position=UDim2.fromOffset(18,18); root.Size=UDim2.fromOffset(UserInputService.TouchEnabled and 390 or 330,48); root.Parent=gui
	local access=Shared.ActionButton(root,{Name="Access",Text="PRIVATE",IconText="A",Size=UDim2.fromOffset(UserInputService.TouchEnabled and 190 or 158,46),Color=UI.Colour("PanelSoft"),StrokeColor=UI.Colour("Outline")})
	local invite=Shared.ActionButton(root,{Name="Invite",Text="INVITE",IconText="+",Size=UDim2.fromOffset(UserInputService.TouchEnabled and 190 or 158,46),Color=UI.Colour("PanelBlue"),StrokeColor=UI.Colour("Telemetry")}); invite.Position=UDim2.new(1,0,0,0); invite.AnchorPoint=Vector2.new(1,0)
	local toast=UI.Label(gui,{Name="GarageStatus",Text="",Position=UDim2.new(.5,-210,0,76),Size=UDim2.fromOffset(420,34),TextSize=12,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); toast.BackgroundColor3=UI.Colour("PanelDeep"); toast.BackgroundTransparency=.12; toast.Visible=false; UI.Corner(toast,6)
	local function show(text,good) toast.Text=tostring(text or ""); toast.TextColor3=good and UI.Colour("Telemetry") or UI.Colour("Danger"); toast.Visible=true; local stamp=os.clock(); toast:SetAttribute("Stamp",stamp); task.delay(2.4,function() if toast.Parent and toast:GetAttribute("Stamp")==stamp then toast.Visible=false end end) end
	local function request() local ok,result=pcall(function() return remote:InvokeServer("GetManagementState",{}) end); if ok and type(result)=="table" and result.Success then Shared.SetActionButton(access,string.upper(result.AccessMode or "PRIVATE"),nil,"A") end end
	local function update() local inside=player:GetAttribute("NTR_OwnedGarageInside")==true; local management=playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true; root.Visible=inside and not management; if root.Visible then task.spawn(request) end end
	access.Activated:Connect(function() local event=script.Parent:FindFirstChild("OpenOwnedGarageWorkspace"); if event then event:Fire({Page="Access"}) end end); invite.Activated:Connect(function() show("INVITATIONS ACTIVATE WITH THE VISITOR PHASE",false) end)
	player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(function() publish(); update() end); playerGui:GetAttributeChangedSignal("NTR_OwnedGarageManagementOpen"):Connect(update); push.OnClientEvent:Connect(function(message) if type(message)=="table" and message.Type=="DriveOutResult" then show(message.Message,message.Success==true) elseif type(message)=="table" and message.Type=="ManagementUpdated" and root.Visible then task.spawn(request) end end); publish(); update()
	started=true; print("[NTR Owned Garage] Interior access HUD active."); return true,"Started"
end
return Controller
]==]

local commandRuntimeSource=[==[
-- NTR_OWNED_GARAGE_AUTHORITATIVE_COMMAND_RUNTIME_V1
local Profile=require(script.Parent:WaitForChild("OwnedGarageProfileRuntime"))
local Assignment=require(script.Parent:WaitForChild("OwnedGarageDisplayAssignmentRuntime"))
local Runtime={ApiVersion=1}
local ALLOWED={Assign=true,Clear=true,SetActive=true,SetSurfaceStyle=true,SetAccessMode=true}
local function clone(value) if type(value)~="table" then return value end; local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy end
local function equal(a,b,seen)
	if type(a)~="table" or type(b)~="table" then return a==b end; seen=seen or {}; if seen[a]==b then return true end; seen[a]=b
	for key,value in pairs(a) do if not equal(value,b[key],seen) then return false end end
	for key in pairs(b) do if a[key]==nil then return false end end; return true
end
local function response(success,message,operation,baseRevision,revision,extra)
	local result={Success=success==true,Message=tostring(message or ""),Operation=tostring(operation or ""),BaseRevision=baseRevision,Revision=revision,ApiVersion=Runtime.ApiVersion}
	for key,value in pairs(type(extra)=="table" and extra or {}) do result[key]=value end; return result
end
local function dirty(commit,reason) if type(commit)~="function" then return false,"Dirty owner missing." end; return commit(reason) end
function Runtime.Execute(player,profile,command,commit)
	if type(profile)~="table" then return response(false,"Profile is not loaded.","",nil,0) end; command=type(command)=="table" and command or {}; local operation=tostring(command.Operation or ""); local current=math.max(0,math.floor(tonumber(profile.OwnedGarage and profile.OwnedGarage.Revision) or 0))
	if operation=="Ensure" then
		local before=clone(profile.OwnedGarage); local reset=command.Reset==true; local garage=Profile.Ensure(profile,reset); if reset then garage.TesterResetToken=tostring(command.ResetToken or "") end; local changed=not equal(before,garage)
		if changed then garage.Revision=current+1; local valid,message=Profile.Validate(profile); if not valid then if type(before)=="table" then Profile.Restore(profile,before) else profile.OwnedGarage=nil end; return response(false,message,operation,current,current) end; local marked,markMessage=dirty(commit,reset and "OwnedGarageTesterReset" or "OwnedGarageEnsure"); if not marked then if type(before)=="table" then Profile.Restore(profile,before) else profile.OwnedGarage=nil end; return response(false,markMessage,operation,current,current) end end
		return response(true,changed and "Owned garage state normalised." or "Owned garage state current.",operation,current,garage.Revision,{Changed=changed,ResetApplied=reset and changed,State=Profile.State(profile)})
	elseif operation=="Restore" then
		local baseRevision=tonumber(command.BaseRevision); if baseRevision~=current then return response(false,"Garage changed before compensation could complete.",operation,baseRevision,current,{Conflict=true}) end; if type(command.State)~="table" then return response(false,"Compensation state is missing.",operation,baseRevision,current) end
		local before=Profile.Snapshot(profile); local restored=clone(command.State); restored.Revision=current+1; Profile.Restore(profile,restored); local valid,message=Profile.Validate(profile); if not valid then Profile.Restore(profile,before); return response(false,message,operation,baseRevision,current) end; local marked,markMessage=dirty(commit,tostring(command.Reason or "OwnedGarageCompensation")); if not marked then Profile.Restore(profile,before); return response(false,markMessage,operation,baseRevision,current) end
		return response(true,"Owned garage compensation committed.",operation,baseRevision,current+1,{State=Profile.State(profile),Compensated=true})
	elseif not ALLOWED[operation] then return response(false,"Command not allowed.",operation,command.BaseRevision,current) end
	local args=type(command.Args)=="table" and command.Args or {}; args.BaseRevision=command.BaseRevision
	return Assignment.Apply(player,profile,tostring(command.RequestId or ""),operation,args,function() return dirty(commit,tostring(command.Reason or ("OwnedGarageCommand:"..operation))) end)
end
function Runtime.ForgetPlayer(player) Assignment.ForgetPlayer(player) end
return Runtime
]==]

compile("OwnedGarageWorkspaceController",workspaceControllerSource); compile("GarageInteriorModeController",interiorModeSource); compile("OwnedGarageAuthoritativeCommandRuntime",commandRuntimeSource)

local projected={}
local function project(object,marker,transform)
	local source=projected[object] or object.Source; if not string.find(source,marker,1,true) then source=transform(source); assert(string.find(source,marker,1,true),object.Name.." marker missing after projection") end; compile(object.Name,source); projected[object]=source
end
projected[workspace]=workspaceControllerSource
projected[interiorMode]=interiorModeSource

project(catalog,"NTR_OWNED_GARAGE_PROPERTY_CATALOG_V3_TEMPLATE_COMPATIBILITY",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V2_DEFINITION_CONTRACT","-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V2_DEFINITION_CONTRACT\n-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V3_TEMPLATE_COMPATIBILITY","catalog marker")
	source=replaceOnce(source,'TemplateId="StarterTwoBay",','TemplateId="StarterTwoBay",\n\t\tTemplateContractVersion=1,\n\t\tStateSchemaVersion=2,',"template compatibility")
	source=replaceOnce(source,'return {DefinitionVersion=Catalog.DefinitionVersion,PropertyId=property.PropertyId,TemplateId=property.TemplateId,','return {DefinitionVersion=Catalog.DefinitionVersion,PropertyId=property.PropertyId,TemplateId=property.TemplateId,TemplateContractVersion=property.TemplateContractVersion,StateSchemaVersion=property.StateSchemaVersion,',"client compatibility")
	return source
end)

project(action,"NTR_OWNED_GARAGE_PHASE8_VEHICLE_CARD_BRIDGE",function(source)
	local block=[=[
		elseif operation=="GetOwnedGarageVehicleCards" then
			-- NTR_OWNED_GARAGE_PHASE8_VEHICLE_CARD_BRIDGE
			local summaries=V90_vehicleSummaries(profile); local cards={}; local displayed={}
			for garageId,property in pairs((profile.OwnedGarage and profile.OwnedGarage.Properties) or {}) do for slotId,vehicleId in pairs(property.DisplaySpaces or {}) do if vehicleId and vehicleId~=false and tostring(vehicleId)~="" then displayed[tostring(vehicleId)]={GarageId=tostring(garageId),SlotId=tostring(slotId)} end end end
			for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if typeof(vehicle)=="table" then
				local id=tostring(vehicleId); local summary=summaries[id] or summaries[vehicleId] or {}; local cockpitInstance=vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local cockpitId=tostring((cockpitInstance and cockpitInstance.TemplateId) or summary.CockpitId or vehicle.CockpitId or ""); local categoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "BRUISER"); local cockpit=V56_findCockpit(categoryId,cockpitId); local image=""
				for _,key in ipairs({"MenuImage","CockpitImage","ThumbnailImage","ImageId","Image"}) do local value=cockpit and cockpit:GetAttribute(key); if value~=nil and tostring(value)~="" then image=tostring(value); break end; local child=cockpit and cockpit:FindFirstChild(key); if child and child:IsA("StringValue") and child.Value~="" then image=child.Value; break end end
				local overall=summary.Overall or {}; local location=displayed[id]; table.insert(cards,{VehicleId=id,CockpitId=cockpitId,CategoryId=categoryId,DisplayName=tostring(cockpit and cockpit:GetAttribute("DisplayName") or summary.DisplayName or vehicle.DisplayName or cockpitId or id),Image=image,Tier=tostring(overall.Tier or "E"),Rating=math.floor(tonumber(overall.PerformanceIndex) or 0),DisplayedGarageId=location and location.GarageId or nil,DisplayedSlotId=location and location.SlotId or nil})
			end end
			return {Success=true,Vehicles=cards}
]=]
	return replaceOnce(source,'\t\t\tV80_mirrorLegacyProfileToPersistence(player,profile,"OwnedGarageDriveOut",true); return {Success=true,Message="Vehicle spawned from garage.",Vehicle=vehicle,VehicleId=vehicleId}\n\t\tend\n\t\treturn {Success=false,Message="Unknown owned garage lifecycle operation."}', '\t\t\tV80_mirrorLegacyProfileToPersistence(player,profile,"OwnedGarageDriveOut",true); return {Success=true,Message="Vehicle spawned from garage.",Vehicle=vehicle,VehicleId=vehicleId}\n'..block..'\t\tend\n\t\treturn {Success=false,Message="Unknown owned garage lifecycle operation."}',"vehicle card bridge")
end)

project(action,"NTR_OWNED_GARAGE_PHASE8_VEHICLE_CARD_BRIDGE_V1_4_PLAYER_CONTEXT",function(source)
	source=replaceOnce(source,'local function V90_vehicleSummaries(profile)', 'local function V90_vehicleSummaries(profile,summaryPlayer)',"vehicle summary player signature")
	source=replaceOnce(source,'local performance = V77_ModuleUpgrades.CalculateProfile(\n\t\t\t\t\t\tprofile._Player,\n\t\t\t\t\t\tprofile,', 'local performance = V77_ModuleUpgrades.CalculateProfile(\n\t\t\t\t\t\tsummaryPlayer or profile._Player,\n\t\t\t\t\t\tprofile,',"vehicle summary player argument")
	source=replaceOnce(source,'-- NTR_OWNED_GARAGE_PHASE8_VEHICLE_CARD_BRIDGE\n\t\t\tlocal summaries=V90_vehicleSummaries(profile);', '-- NTR_OWNED_GARAGE_PHASE8_VEHICLE_CARD_BRIDGE\n\t\t\t-- NTR_OWNED_GARAGE_PHASE8_VEHICLE_CARD_BRIDGE_V1_4_PLAYER_CONTEXT\n\t\t\tlocal summaries=V90_vehicleSummaries(profile,player);',"owned garage summary player bridge")
	return source
end)

project(management,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V4_VERTICAL_SLICE",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V3_REUSABLE_FRAMEWORK","-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V3_REUSABLE_FRAMEWORK\n-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V4_VERTICAL_SLICE","management marker")
	source=replaceOnce(source,'local sessions={}; local slotByUserId={}; local promptConnections={}; local locks={}; local lastRequest={}; local stateCache=setmetatable({},{__mode="k"}); local driveOut,exitOnFoot','local sessions={}; local slotByUserId={}; local promptConnections={}; local locks={}; local lastRequest={}; local stateCache=setmetatable({},{__mode="k"}); local requestWindows=setmetatable({},{__mode="k"}); local driveOut,exitOnFoot',"rate state")
	local helper=[=[
	local function featureEnabled(name,default) local value=settings:GetAttribute("Enable"..name); if value==nil then return default end; return value==true end
	local function capabilities(propertyId) local result=catalog.Capabilities(propertyId); for name,value in pairs(result) do result[name]=value==true and featureEnabled(name,name=="DisplayCars") end; return result end
	local function applyPromptPolicy(session)
		if not (session and session.Interior) then return end; local blocked=session.ManagementOpen==true or session.Transition~=nil
		for _,prompt in ipairs(session.Interior:GetDescendants()) do if prompt:IsA("ProximityPrompt") and (prompt.Name=="DriveOutPrompt" or prompt.Name=="FootExitPrompt" or prompt.Name=="ManageGaragePrompt") then prompt.HoldDuration=0; prompt.Enabled=not blocked and prompt:GetAttribute("OwnedGarageAvailable")~=false end end
	end
	local function allowRequest(player,action)
		local now=os.clock(); local window=requestWindows[player]; if not window or now-window.Start>=1 then window={Start=now,Count=0}; requestWindows[player]=window end; window.Count+=1; local maximum=(action=="GetState" or action=="GetManagementState") and (tonumber(settings:GetAttribute("ReadRequestsPerSecond")) or 20) or (tonumber(settings:GetAttribute("MutationRequestsPerSecond")) or 12); return window.Count<=maximum
	end
]=]
	source=replaceOnce(source,'\tlocal function vehicleName(profile,vehicleId)',helper..'\tlocal function vehicleName(profile,vehicleId)',"management safeguards")
	source=replaceOnce(source,'\t\tfor _,slotId in ipairs({"Space01","Space02"}) do\n\t\t\tDisplay.Clear(session.Interior,slotId); local marker=markers:FindFirstChild(slotId); local prompt=marker and marker:FindFirstChild("DriveOutPrompt")\n\t\t\tif not prompt and marker then prompt=Instance.new("ProximityPrompt"); prompt.Name="DriveOutPrompt"; prompt.ActionText="Drive Out"; prompt.KeyboardKeyCode=Enum.KeyCode.E; prompt.GamepadKeyCode=Enum.KeyCode.ButtonX; prompt.HoldDuration=.15; prompt.MaxActivationDistance=12; prompt.RequiresLineOfSight=false; prompt.ClickablePrompt=true; prompt.Parent=marker; table.insert(promptConnections[session.Interior],prompt.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then driveOut(player,slotId) end end)) end\n\t\t\tlocal vehicleId=property.DisplaySpaces[slotId]; prompt.Enabled=vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~=""; prompt.ObjectText=prompt.Enabled and vehicleName(profile,vehicleId) or "Empty Display Space"\n\t\t\tif prompt.Enabled then local model,message=Display.Build(profile,tostring(vehicleId),marker,session.Interior); if not model then return false,message end end\n\t\tend\n\t\treturn true', '\t\tlocal definition=catalog.ById(session.PropertyId); for _,slotId in ipairs(definition and definition.DisplaySpaceIds or {}) do\n\t\t\tDisplay.Clear(session.Interior,slotId); local marker=markers:FindFirstChild(slotId); local prompt=marker and marker:FindFirstChild("DriveOutPrompt")\n\t\t\tif not prompt and marker then prompt=Instance.new("ProximityPrompt"); prompt.Name="DriveOutPrompt"; prompt.ActionText="Drive Out"; prompt.KeyboardKeyCode=Enum.KeyCode.E; prompt.GamepadKeyCode=Enum.KeyCode.ButtonX; prompt.HoldDuration=0; prompt.MaxActivationDistance=12; prompt.RequiresLineOfSight=false; prompt.ClickablePrompt=true; prompt.Parent=marker; table.insert(promptConnections[session.Interior],prompt.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then local result=driveOut(player,slotId); push:FireClient(player,{Type="DriveOutResult",Success=result.Success==true,Message=result.Message}) end end)) end\n\t\t\tlocal vehicleId=property.DisplaySpaces[slotId]; local available=vehicleId~=false and vehicleId~=nil and tostring(vehicleId)~=""; prompt:SetAttribute("OwnedGarageAvailable",available); prompt.ObjectText=available and vehicleName(profile,vehicleId) or "Empty Display Space"\n\t\t\tif available then local model,message=Display.Build(profile,tostring(vehicleId),marker,session.Interior); if not model then return false,message end end\n\t\tend; applyPromptPolicy(session); return true',"dynamic tap prompts")
	source=replaceOnce(source,'local foot=session.Interior:FindFirstChild("FootExitPrompt",true); if foot then foot.Enabled=true; table.insert(list,foot.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then exitOnFoot(player) end end)) end\n\t\tlocal desk=session.Interior:FindFirstChild("ManageGaragePrompt",true); if desk then desk.Enabled=true; table.insert(list,desk.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then push:FireClient(player,{Type="OpenManagement",PropertyId=session.PropertyId}) end end)) end\n\t\treturn renderDisplays(player,profile,session)', 'local foot=session.Interior:FindFirstChild("FootExitPrompt",true); if foot then foot.HoldDuration=0; foot:SetAttribute("OwnedGarageAvailable",true); table.insert(list,foot.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then exitOnFoot(player) end end)) end\n\t\tlocal desk=session.Interior:FindFirstChild("ManageGaragePrompt",true); if desk then desk.HoldDuration=0; desk:SetAttribute("OwnedGarageAvailable",true); table.insert(list,desk.Triggered:Connect(function(triggeringPlayer) if triggeringPlayer==player then push:FireClient(player,{Type="OpenManagement",PropertyId=session.PropertyId}) end end)) end\n\t\treturn renderDisplays(player,profile,session)',"desk/exit tap prompts")
	source=replaceOnce(source,'local interior,message=Interior.Create(pool,player.UserId,propertyId,definition.TemplateId,slotIndex(player)); if not interior then return nil,message end;', 'if #pool:GetChildren()>=(tonumber(settings:GetAttribute("MaxActiveInteriorsPerServer")) or 24) then return nil,"Garage interiors are currently at capacity." end; local interior,message=Interior.Create(pool,player.UserId,propertyId,definition.TemplateId,slotIndex(player)); if not interior then return nil,message end; if tonumber(interior:GetAttribute("OwnedGarageTemplateVersion"))~=tonumber(definition.TemplateContractVersion) then interior:Destroy(); return nil,"Garage template version is incompatible." end;',"interior limit/version")
	source=replaceOnce(source,'\t\tlocal session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; local property=', '\t\tlocal session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; if session.Transition then return {Success=false,Message="Garage transition already in progress."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; session.Transition="DriveOut"; applyPromptPolicy(session); local property=',"driveout transition start")
	source=replaceOnce(source,'\t\tif result.Success then sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); push:FireClient(player,{Type="DriveOut",VehicleId=tostring(vehicleId)}) end; return result', '\t\tif result.Success then sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); push:FireClient(player,{Type="DriveOut",VehicleId=tostring(vehicleId)}) else session.Transition=nil; applyPromptPolicy(session) end; return result',"driveout transition finish")
	source=replaceOnce(source,'local session=sessions[player]; if not session then return {Success=false,Message="Enter your garage before managing it."} end; args=type(args)=="table" and args or {}; args.GarageId=session.PropertyId', 'local session=sessions[player]; if not session then return {Success=false,Message="Enter your garage before managing it."} end; args=type(args)=="table" and args or {}; args.GarageId=session.PropertyId; local required=(operation=="Assign" or operation=="Clear") and "DisplayCars" or (operation=="SetSurfaceStyle" and "Structure" or (operation=="SetAccessMode" and "Access")); if required and capabilities(session.PropertyId)[required]~=true then return {Success=false,Message=required.." is not enabled for this garage."} end',"capability enforcement")
	source=replaceOnce(source,'for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if type(vehicle)=="table" then local cockpitInstance=profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]; local cockpitId=tostring((cockpitInstance and cockpitInstance.TemplateId) or vehicle.CockpitId or ""); table.insert(vehicles,{VehicleId=tostring(vehicleId),DisplayName=vehicleName(profile,vehicleId),CockpitId=cockpitId,CategoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or "")}) end end\n\t\ttable.sort(vehicles,function(a,b) if a.DisplayName~=b.DisplayName then return a.DisplayName<b.DisplayName end return a.VehicleId<b.VehicleId end)', 'local presentation=lifecycleCall("GetOwnedGarageVehicleCards",player,{}); if presentation.Success then vehicles=presentation.Vehicles or {} else for vehicleId,vehicle in pairs(profile.Vehicles or {}) do if type(vehicle)=="table" then table.insert(vehicles,{VehicleId=tostring(vehicleId),DisplayName=vehicleName(profile,vehicleId),CockpitId=tostring(vehicle.CockpitId or ""),CategoryId=tostring(vehicle.CategoryId or profile.CurrentCategory or ""),Tier="E",Rating=0,Image=""}) end end end; local propertyNames={}; for _,definition in ipairs(catalog.List()) do propertyNames[definition.PropertyId]=definition.DisplayName end; for _,vehicle in ipairs(vehicles) do vehicle.UsedInOtherGarage=vehicle.DisplayedGarageId~=nil and vehicle.DisplayedGarageId~=sessionPropertyId; vehicle.DisplayedGarageName=vehicle.DisplayedGarageId and propertyNames[vehicle.DisplayedGarageId] or nil end\n\t\ttable.sort(vehicles,function(a,b) if a.UsedInOtherGarage~=b.UsedInOtherGarage then return not a.UsedInOtherGarage end; if a.Rating~=b.Rating then return a.Rating>b.Rating end; return a.DisplayName<b.DisplayName end)',"canonical vehicle cards")
	source=replaceOnce(source,'Capabilities=session and catalog.Capabilities(session.PropertyId) or {}', 'Capabilities=session and capabilities(session.PropertyId) or {}',"effective capabilities")
	source=replaceOnce(source,'args=type(args)=="table" and args or {}; if locks[player] then return {Success=false,Message="Garage transition already in progress."} end;', 'args=type(args)=="table" and args or {}; if not allowRequest(player,action) then return {Success=false,Message="Garage requests are arriving too quickly.",RateLimited=true} end; if locks[player] then return {Success=false,Message="Garage transition already in progress."} end;',"rate enforcement")
	source=replaceOnce(source,'local now=os.clock(); if action~="GetState" and action~="GetManagementState" and now-(lastRequest[player] or 0)<(tonumber(settings:GetAttribute("TransitionCooldownSeconds")) or 1) then', 'local now=os.clock(); local controlAction=action=="GetState" or action=="GetManagementState" or action=="SetManagementOpen" or action=="PreviewDisplay" or action=="CancelDisplayPreview"; if not controlAction and now-(lastRequest[player] or 0)<(tonumber(settings:GetAttribute("TransitionCooldownSeconds")) or 1) then',"control action cooldown")
	source=replaceOnce(source,'locks[player]=nil; if action~="GetState" and action~="GetManagementState" then lastRequest[player]=now end;', 'locks[player]=nil; if not controlAction then lastRequest[player]=now end;',"control action timestamp")
	source=replaceOnce(source,'if action=="GetState" or action=="GetManagementState" then return stateFor(player,profile)', 'if action=="GetState" or action=="GetManagementState" then return stateFor(player,profile)\n\t\t\telseif action=="SetManagementOpen" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; session.ManagementOpen=args.Open==true; applyPromptPolicy(session); return {Success=true,Message="Management prompt policy updated."}\n\t\t\telseif action=="PreviewDisplay" then local session=sessions[player]; if not session or capabilities(session.PropertyId).DisplayCars~=true then return {Success=false,Message="Display preview is unavailable."} end; local slotId=tostring(args.SlotId or ""); local vehicleId=tostring(args.VehicleId or ""); if not catalog.IsSpace(session.PropertyId,slotId) or not (profile.Vehicles and profile.Vehicles[vehicleId]) then return {Success=false,Message="Display preview is invalid."} end; local marker=session.Interior:FindFirstChild("DisplaySpaceMarkers") and session.Interior.DisplaySpaceMarkers:FindFirstChild(slotId); if not marker then return {Success=false,Message="Display marker missing."} end; local property=profile.OwnedGarage.Properties[session.PropertyId]; for otherSlot,displayedId in pairs(property and property.DisplaySpaces or {}) do if tostring(displayedId or "")==vehicleId and tostring(otherSlot)~=slotId then Display.Clear(session.Interior,tostring(otherSlot)) end end; Display.Clear(session.Interior,slotId); local model,previewMessage=Display.Build(profile,vehicleId,marker,session.Interior); if not model then renderDisplays(player,profile,session); return {Success=false,Message=previewMessage} end; session.PreviewSlotId=slotId; return {Success=true,Message="Preview ready."}\n\t\t\telseif action=="CancelDisplayPreview" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; session.PreviewSlotId=nil; local rendered,renderMessage=renderDisplays(player,profile,session); return {Success=rendered==true,Message=renderMessage or "Display preview cleared."}',"management/preview actions")
	source=replaceOnce(source,'stateCache[player]=nil; Assignment.ForgetPlayer(player); slotByUserId[player.UserId]=nil;', 'stateCache[player]=nil; requestWindows[player]=nil; Assignment.ForgetPlayer(player); slotByUserId[player.UserId]=nil;',"request cleanup")
	return source
end)

project(management,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V5_AUTHORITATIVE_MUTATION_STATE",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V4_VERTICAL_SLICE","-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V4_VERTICAL_SLICE\n-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V5_AUTHORITATIVE_MUTATION_STATE","authoritative mutation marker")
	source=replaceOnce(source,'local sessions={}; local slotByUserId={}; local promptConnections={}; local locks={}; local lastRequest={}; local stateCache=setmetatable({},{__mode="k"}); local requestWindows=setmetatable({},{__mode="k"}); local driveOut,exitOnFoot','local sessions={}; local slotByUserId={}; local promptConnections={}; local locks={}; local lastRequest={}; local stateCache=setmetatable({},{__mode="k"}); local requestWindows=setmetatable({},{__mode="k"}); local stateFor; local driveOut,exitOnFoot',"state projection forward declaration")
	source=replaceOnce(source,'if not result.Success then if operation=="Assign" or operation=="Clear" then renderDisplays(player,profile,session) elseif operation=="SetSurfaceStyle" then applyInteriorStyles(profile,session) end else stateCache[player]=nil; push:FireClient(player,{Type="ManagementUpdated",Operation=operation,Revision=result.Revision}) end\n\t\treturn result','if not result.Success then if operation=="Assign" or operation=="Clear" then renderDisplays(player,profile,session) elseif operation=="SetSurfaceStyle" then applyInteriorStyles(profile,session) end else stateCache[player]=nil; result.ManagementState=stateFor(player,profile); push:FireClient(player,{Type="ManagementUpdated",Operation=operation,Revision=result.Revision}) end\n\t\treturn result',"authoritative mutation response")
	source=replaceOnce(source,'\tlocal function stateFor(player,profile)','\tstateFor=function(player,profile)',"state projection assignment")
	return source
end)

project(profileService,"NTR_PROFILE_SERVICE_OWNED_GARAGE_COMMAND_OWNER_V1",function(source)
	source=replaceOnce(source,"-- Neo Tokyo Racers ProfileService foundation.","-- Neo Tokyo Racers ProfileService foundation.\n-- NTR_PROFILE_SERVICE_OWNED_GARAGE_COMMAND_OWNER_V1","profile command marker")
	source=replaceOnce(source,'local services = ensureFolder(serverRoot, "Services")','local services = ensureFolder(serverRoot, "Services")\nlocal ownedGarageCommandRuntime = require(services:WaitForChild("Garage"):WaitForChild("OwnedGarageAuthoritativeCommandRuntime"))',"profile command runtime")
	source=replaceOnce(source,'local importProfileSnapshotBinding = ensureBindableFunction(bindings, "ImportProfileSnapshot")','local importProfileSnapshotBinding = ensureBindableFunction(bindings, "ImportProfileSnapshot")\nlocal executeOwnedGarageCommandBinding = ensureBindableFunction(bindings, "ExecuteOwnedGarageCommand")',"profile command binding")
	source=replaceOnce(source,'local sessions = {}\nlocal garageCleanupTransactions = {}','local sessions = {}\nlocal ownedGarageCommandLocks = {}\nlocal garageCleanupTransactions = {}',"profile command locks")
	local invoke=[==[
executeOwnedGarageCommandBinding.OnInvoke = function(player, command)
	local session = sessionFor(player)
	if not session then return {Success = false, Message = "Profile is not loaded."} end
	local userId = player.UserId
	if ownedGarageCommandLocks[userId] then return {Success = false, Message = "Owned garage command already in progress.", Busy = true} end
	ownedGarageCommandLocks[userId] = session
	local expectedGeneration = session.SessionGeneration
	local ok, result = pcall(function() return ownedGarageCommandRuntime.Execute(player, session.Profile, command, function(reason)
		local current = sessionFor(player)
		if current ~= session or current.SessionGeneration ~= expectedGeneration then return false, "Profile session changed during owned garage command." end
		return markDirty(player, reason)
	end) end)
	if ownedGarageCommandLocks[userId] == session then ownedGarageCommandLocks[userId] = nil end
	if not ok then return {Success = false, Message = "Owned garage command failed: " .. tostring(result)} end
	if type(result) == "table" then result.SessionGeneration = expectedGeneration; result.SessionId = session.SessionId end
	return result
end

]==]
	source=replaceOnce(source,"getProfileBinding.OnInvoke = function(player)",invoke.."getProfileBinding.OnInvoke = function(player)","profile command invoke")
	source=replaceOnce(source,'\tlocal userId = player.UserId\n\tlocal leavingSession = sessions[userId]','\tlocal userId = player.UserId\n\townedGarageCommandLocks[userId] = nil\n\townedGarageCommandRuntime.ForgetPlayer(player)\n\tlocal leavingSession = sessions[userId]',"profile command cleanup")
	return source
end)

project(management,"NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V6_PROFILE_COMMAND_BOUNDARY",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V5_AUTHORITATIVE_MUTATION_STATE","-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V5_AUTHORITATIVE_MUTATION_STATE\n-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V6_PROFILE_COMMAND_BOUNDARY","management command marker")
	source=replaceOnce(source,'local bindings=services.Player:WaitForChild("ProfileServiceBindings"); local getProfile=bindings:WaitForChild("GetProfile"); local markDirty=bindings:WaitForChild("MarkDirty"); local saveNow=bindings:WaitForChild("SaveNow"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")','local bindings=services.Player:WaitForChild("ProfileServiceBindings"); local getProfile=bindings:WaitForChild("GetProfile"); local executeOwnedGarageCommand=bindings:WaitForChild("ExecuteOwnedGarageCommand"); local saveNow=bindings:WaitForChild("SaveNow"); local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")',"management command binding")
	local oldProfile=[==[
	local function profileFor(player)
		local profile=getProfile:Invoke(player); if type(profile)~="table" then return nil,"Profile is not loaded." end
		local resetToken=tostring(settings:GetAttribute("TesterResetToken") or ""); local resetUserId=math.floor(tonumber(settings:GetAttribute("TesterResetUserId")) or 0); local existing=type(profile.OwnedGarage)=="table" and profile.OwnedGarage or nil; local shouldReset=player.UserId==resetUserId and resetToken~="" and tostring(existing and existing.TesterResetToken or "")~=resetToken; local oldVersion=existing and existing.SchemaVersion or nil
		Profile.Ensure(profile,shouldReset); if shouldReset then profile.OwnedGarage.TesterResetToken=resetToken; local marked,markMessage=markDirty:Invoke(player,"OwnedGarageTesterReset:"..resetToken); if not marked then return nil,tostring(markMessage or "Tester reset could not be marked dirty.") end; local saved,saveMessage=saveNow:Invoke(player); if not saved then warn("[NTR Owned Garage] Tester reset save deferred: "..tostring(saveMessage)) end elseif oldVersion~=Profile.SchemaVersion then markDirty:Invoke(player,"OwnedGarageSchemaV2") end
		return profile
	end
]==]
	local newProfile=[==[
	local function profileFor(player)
		local initial=getProfile:Invoke(player); if type(initial)~="table" then return nil,"Profile is not loaded." end
		local resetToken=tostring(settings:GetAttribute("TesterResetToken") or ""); local resetUserId=math.floor(tonumber(settings:GetAttribute("TesterResetUserId")) or 0); local existing=type(initial.OwnedGarage)=="table" and initial.OwnedGarage or nil; local shouldReset=player.UserId==resetUserId and resetToken~="" and tostring(existing and existing.TesterResetToken or "")~=resetToken
		local ensured=executeOwnedGarageCommand:Invoke(player,{Operation="Ensure",Reset=shouldReset,ResetToken=resetToken}); if type(ensured)~="table" or not ensured.Success then return nil,tostring(ensured and ensured.Message or "Owned garage state is unavailable.") end
		if ensured.ResetApplied then local saved,saveMessage=saveNow:Invoke(player); if not saved then warn("[NTR Owned Garage] Tester reset save deferred: "..tostring(saveMessage)) end end
		local profile=getProfile:Invoke(player); if type(profile)~="table" then return nil,"Profile is not loaded." end; return profile
	end
	local function command(player,operation,args,reason,requestId,baseRevision)
		return executeOwnedGarageCommand:Invoke(player,{Operation=operation,Args=args,Reason=reason,RequestId=requestId or Profile.NewRequestId(),BaseRevision=baseRevision})
	end
	local function compensate(player,snapshot,baseRevision,reason)
		local result=executeOwnedGarageCommand:Invoke(player,{Operation="Restore",State=snapshot,Reason=reason,RequestId=Profile.NewRequestId(),BaseRevision=baseRevision}); if type(result)~="table" or not result.Success then warn("[NTR Owned Garage] compensation failed: "..tostring(result and result.Message or "unavailable")); return false end; return true
	end
]==]
	source=replaceOnce(source,oldProfile,newProfile,"authoritative profile read/command helpers")
	local oldEnter=[==[
	local function enterWithVehicle(player,profile,propertyId,replacementSlotId)
		local driven=lifecycleCall("GetDrivenVehicle",player,{}); if not driven.Success then return {Success=false,Message=driven.Message or "Drive a vehicle into the garage."} end
		if tonumber(driven.SpeedMph) and driven.SpeedMph>(tonumber(settings:GetAttribute("DriveInMaxSpeedMph")) or 5) then return {Success=false,Message="Slow below "..tostring(settings:GetAttribute("DriveInMaxSpeedMph") or 5).." MPH."} end
		local property=profile.OwnedGarage.Properties[propertyId]; if not (property and property.Owned) then return {Success=false,Message="Garage is not owned."} end
		local slotId,reason=Runtime.ChooseSlot(property.DisplaySpaces,replacementSlotId); if reason=="Invalid" then return {Success=false,Message="That display space is not part of this garage."} end; if not slotId then return {Success=false,NeedsReplacement=true,Message="Garage display spaces are full.",Slots=replacementSlots(profile,propertyId)} end
		local session,message=ensureSession(player,profile,propertyId); if not session then return {Success=false,Message=message} end; local root=characterRoot(player); if not root then abandonSession(player,session); return {Success=false,Message="Character is not ready."} end
		local before=Profile.Snapshot(profile); local requestId=tostring(driven.RequestId or Profile.NewRequestId()); local result=Assignment.Apply(player,profile,requestId,"Assign",{GarageId=propertyId,SlotId=slotId,VehicleId=driven.VehicleId},function()
			local marked,markMessage=markDirty:Invoke(player,"OwnedGarageDriveIn"); if not marked then return false,markMessage end; local despawn=lifecycleCall("DespawnForGarage",player,{VehicleId=driven.VehicleId}); return despawn.Success==true,despawn.Message
		end)
		if not result.Success then abandonSession(player,session); return result end; local spawn=session.Interior:FindFirstChild("CharacterSpawn",true); local moved,moveMessage=teleportCharacter(player,spawn and spawn.CFrame)
		if not moved then Profile.Restore(profile,before); markDirty:Invoke(player,"OwnedGarageDriveInRollback"); lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame or settings:GetAttribute("CityVehicleExitCFrame")}); abandonSession(player,session); return {Success=false,Message=moveMessage} end
		setInside(player,session); renderDisplays(player,profile,session); return {Success=true,Message=reason=="Requested" and "Display vehicle replaced." or "Vehicle placed in garage.",PropertyId=propertyId,SlotId=slotId}
	end
]==]
	local newEnter=[==[
	local function enterWithVehicle(player,profile,propertyId,replacementSlotId)
		local driven=lifecycleCall("GetDrivenVehicle",player,{}); if not driven.Success then return {Success=false,Message=driven.Message or "Drive a vehicle into the garage."} end
		if tonumber(driven.SpeedMph) and driven.SpeedMph>(tonumber(settings:GetAttribute("DriveInMaxSpeedMph")) or 5) then return {Success=false,Message="Slow below "..tostring(settings:GetAttribute("DriveInMaxSpeedMph") or 5).." MPH."} end
		local property=profile.OwnedGarage.Properties[propertyId]; if not (property and property.Owned) then return {Success=false,Message="Garage is not owned."} end
		local slotId,reason=Runtime.ChooseSlot(property.DisplaySpaces,replacementSlotId); if reason=="Invalid" then return {Success=false,Message="That display space is not part of this garage."} end; if not slotId then return {Success=false,NeedsReplacement=true,Message="Garage display spaces are full.",Slots=replacementSlots(profile,propertyId)} end
		local session,message=ensureSession(player,profile,propertyId); if not session then return {Success=false,Message=message} end; local root=characterRoot(player); if not root then abandonSession(player,session); return {Success=false,Message="Character is not ready."} end
		local before=Profile.Snapshot(profile); local result=command(player,"Assign",{GarageId=propertyId,SlotId=slotId,VehicleId=driven.VehicleId},"OwnedGarageDriveIn",tostring(driven.RequestId or Profile.NewRequestId()),profile.OwnedGarage.Revision)
		if type(result)~="table" or not result.Success then abandonSession(player,session); return type(result)=="table" and result or {Success=false,Message="Owned garage command unavailable."} end
		local despawn=lifecycleCall("DespawnForGarage",player,{VehicleId=driven.VehicleId}); if not despawn.Success then compensate(player,before,result.Revision,"OwnedGarageDriveInDespawnRollback"); abandonSession(player,session); return {Success=false,Message=despawn.Message or "Vehicle could not enter the garage."} end
		local spawn=session.Interior:FindFirstChild("CharacterSpawn",true); local moved,moveMessage=teleportCharacter(player,spawn and spawn.CFrame); if not moved then lifecycleCall("SpawnFromGarage",player,{VehicleId=driven.VehicleId,SpawnCFrame=driven.VehicleCFrame or settings:GetAttribute("CityVehicleExitCFrame")}); compensate(player,before,result.Revision,"OwnedGarageDriveInTeleportRollback"); abandonSession(player,session); return {Success=false,Message=moveMessage} end
		setInside(player,session); local committed=getProfile:Invoke(player); local rendered,renderMessage=false,"Committed profile unavailable."; if type(committed)=="table" then rendered,renderMessage=renderDisplays(player,committed,session) end; return {Success=true,Message=reason=="Requested" and "Display vehicle replaced." or "Vehicle placed in garage.",PropertyId=propertyId,SlotId=slotId,Revision=result.Revision,PresentationWarning=rendered and nil or renderMessage}
	end
]==]
	source=replaceOnce(source,oldEnter,newEnter,"authoritative drive-in command")
	local oldDrive=[==[
	driveOut=function(player,slotId)
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; if session.Transition then return {Success=false,Message="Garage transition already in progress."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; session.Transition="DriveOut"; applyPromptPolicy(session); local property=profile.OwnedGarage.Properties[session.PropertyId]; local vehicleId=property and property.DisplaySpaces[slotId]; if vehicleId==false or vehicleId==nil or tostring(vehicleId)=="" then return {Success=false,Message="Display space is empty."} end
		local spawnCFrame=settings:GetAttribute("CityVehicleExitCFrame"); local result=Assignment.Apply(player,profile,Profile.NewRequestId(),"Clear",{GarageId=session.PropertyId,SlotId=slotId},function()
			local marked,markMessage=markDirty:Invoke(player,"OwnedGarageDriveOut"); if not marked then return false,markMessage end; local spawned=lifecycleCall("SpawnFromGarage",player,{VehicleId=tostring(vehicleId),SpawnCFrame=spawnCFrame}); return spawned.Success==true,spawned.Message
		end)
		if result.Success then sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); push:FireClient(player,{Type="DriveOut",VehicleId=tostring(vehicleId)}) else session.Transition=nil; applyPromptPolicy(session) end; return result
	end
]==]
	local newDrive=[==[
	driveOut=function(player,slotId)
		local session=sessions[player]; if not session then return {Success=false,Message="You are not inside an owned garage."} end; if session.Transition then return {Success=false,Message="Garage transition already in progress."} end; local profile,message=profileFor(player); if not profile then return {Success=false,Message=message} end; session.Transition="DriveOut"; applyPromptPolicy(session); local property=profile.OwnedGarage.Properties[session.PropertyId]; local vehicleId=property and property.DisplaySpaces[slotId]; if vehicleId==false or vehicleId==nil or tostring(vehicleId)=="" then session.Transition=nil; applyPromptPolicy(session); return {Success=false,Message="Display space is empty."} end
		local before=Profile.Snapshot(profile); local result=command(player,"Clear",{GarageId=session.PropertyId,SlotId=slotId},"OwnedGarageDriveOut",Profile.NewRequestId(),profile.OwnedGarage.Revision); if type(result)~="table" or not result.Success then session.Transition=nil; applyPromptPolicy(session); return type(result)=="table" and result or {Success=false,Message="Owned garage command unavailable."} end
		local spawnCFrame=settings:GetAttribute("CityVehicleExitCFrame"); local spawned=lifecycleCall("SpawnFromGarage",player,{VehicleId=tostring(vehicleId),SpawnCFrame=spawnCFrame}); if not spawned.Success then compensate(player,before,result.Revision,"OwnedGarageDriveOutSpawnRollback"); session.Transition=nil; applyPromptPolicy(session); local restored=getProfile:Invoke(player); if type(restored)=="table" then renderDisplays(player,restored,session) end; return {Success=false,Message=spawned.Message or "Vehicle could not leave the garage."} end
		sessions[player]=nil; setInside(player,nil); scheduleUnload(session.Interior,player); push:FireClient(player,{Type="DriveOut",VehicleId=tostring(vehicleId)}); return {Success=true,Message="Vehicle spawned from garage.",VehicleId=tostring(vehicleId),Revision=result.Revision}
	end
]==]
	source=replaceOnce(source,oldDrive,newDrive,"authoritative drive-out command")
	local oldManaged=[==[
	local function managedOperation(player,profile,operation,args)
		local session=sessions[player]; if not session then return {Success=false,Message="Enter your garage before managing it."} end; args=type(args)=="table" and args or {}; args.GarageId=session.PropertyId; local required=(operation=="Assign" or operation=="Clear") and "DisplayCars" or (operation=="SetSurfaceStyle" and "Structure" or (operation=="SetAccessMode" and "Access")); if required and capabilities(session.PropertyId)[required]~=true then return {Success=false,Message=required.." is not enabled for this garage."} end
		local requestId=tostring(args.RequestId or Profile.NewRequestId()); local result=Assignment.Apply(player,profile,requestId,operation,args,function()
			if operation=="Assign" or operation=="Clear" then local rendered,renderMessage=renderDisplays(player,profile,session); if not rendered then return false,renderMessage end elseif operation=="SetSurfaceStyle" then applyInteriorStyles(profile,session) end
			local marked,markMessage=markDirty:Invoke(player,"OwnedGarageManagement:"..operation); return marked==true,markMessage
		end)
		if not result.Success then if operation=="Assign" or operation=="Clear" then renderDisplays(player,profile,session) elseif operation=="SetSurfaceStyle" then applyInteriorStyles(profile,session) end else stateCache[player]=nil; result.ManagementState=stateFor(player,profile); push:FireClient(player,{Type="ManagementUpdated",Operation=operation,Revision=result.Revision}) end
		return result
	end
]==]
	local newManaged=[==[
	local function managedOperation(player,profile,operation,args)
		local session=sessions[player]; if not session then return {Success=false,Message="Enter your garage before managing it."} end; args=type(args)=="table" and args or {}; args.GarageId=session.PropertyId; local required=(operation=="Assign" or operation=="Clear") and "DisplayCars" or (operation=="SetSurfaceStyle" and "Structure" or (operation=="SetAccessMode" and "Access")); if required and capabilities(session.PropertyId)[required]~=true then return {Success=false,Message=required.." is not enabled for this garage."} end
		local result=command(player,operation,args,"OwnedGarageManagement:"..operation,tostring(args.RequestId or Profile.NewRequestId()),args.BaseRevision); local committed=getProfile:Invoke(player); if type(committed)~="table" then return {Success=false,Message="Committed profile could not be read."} end
		if type(result)~="table" then return {Success=false,Message="Owned garage command unavailable."} elseif not result.Success then if operation=="Assign" or operation=="Clear" then renderDisplays(player,committed,session) elseif operation=="SetSurfaceStyle" then applyInteriorStyles(committed,session) end; return result end
		local presented,presentationMessage=true,nil; if operation=="Assign" or operation=="Clear" then presented,presentationMessage=renderDisplays(player,committed,session) elseif operation=="SetSurfaceStyle" then presented=applyInteriorStyles(committed,session) end; if not presented then result.PresentationWarning=presentationMessage or "Saved state committed; physical presentation will retry." end
		stateCache[player]=nil; result.ManagementState=stateFor(player,committed); push:FireClient(player,{Type="ManagementUpdated",Operation=operation,Revision=result.Revision}); return result
	end
]==]
	source=replaceOnce(source,oldManaged,newManaged,"authoritative management command")
	return source
end)

project(shared,"NTR_OWNED_GARAGE_PHASE8_SHARED_PRESENTATION",function(source)
	source=replaceOnce(source,"-- NTR_GARAGE_REPLACEMENT_SHARED_COMPONENTS_V1","-- NTR_GARAGE_REPLACEMENT_SHARED_COMPONENTS_V1\n-- NTR_OWNED_GARAGE_PHASE8_SHARED_PRESENTATION","shared marker")
	source=replaceOnce(source,'local selected=props.Selected==true; local accent=selected and Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)) or Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175))', 'local selected=props.Selected==true; local accent=selected and Racing.Colour("Telemetry",Color3.fromRGB(43,225,218)) or (props.Muted and Color3.fromRGB(132,142,145) or Racing.Colour("OutlineSoft",Color3.fromRGB(214,74,175)))',"muted vehicle card")
	source=replaceOnce(source,'if props.Rating then local badge=', 'if props.EmptyPlus then local circle=Instance.new("Frame"); circle.Name="EmptyPlus"; circle.AnchorPoint=Vector2.new(.5,.5); circle.Position=UDim2.fromScale(.5,.43); circle.Size=UDim2.fromOffset(58,58); circle.BackgroundColor3=Racing.Colour("PanelSoft"); circle.BorderSizePixel=0; circle.ZIndex=card.ZIndex+5; circle.Parent=card; Racing.Corner(circle,29); local plus=Racing.Label(circle,{Text="+",Size=UDim2.fromScale(1,1),TextSize=34,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); plus.ZIndex=circle.ZIndex+1 end\n\tif props.Rating then local badge=',"empty plus")
	source=replaceOnce(source,'if not ownerConnection then ownerConnection = RunService.RenderStepped:Connect(suppressRetiredSurfaces) end', 'if next(retiredSurfaces)~=nil and not ownerConnection then ownerConnection = RunService.RenderStepped:Connect(suppressRetiredSurfaces) end',"empty presentation loop")
	source=replaceOnce(source,'function M.AuditPresentation(owner, labelText)\n\ttask.defer(function()', 'function M.AuditPresentation(owner, labelText)\n\tlocal cfg=kit.Config.UI:FindFirstChild("GarageReplacement"); if not (cfg and cfg:GetAttribute("RuntimeAuditEnabled")==true) then return end\n\ttask.defer(function()',"audit gate")
	local confirmation=[==[
function M.ConfirmationModal(root,options)
	options=options or {}; local shade=Instance.new("Frame"); shade.Name="CanonicalGarageConfirmation"; shade.Active=true; shade.BackgroundColor3=Color3.new(0,0,0); shade.BackgroundTransparency=.22; shade.BorderSizePixel=0; shade.Size=UDim2.fromScale(1,1); shade.ZIndex=300; shade.Parent=root
	local panel=M.Panel(shade,"Panel",{StrokeColor=Racing.Colour("ElectricBlue"),NoGlow=true}); panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(620,320); panel.ZIndex=301
	local title=Racing.Label(panel,{Text=options.Title or "CONFIRM",Position=UDim2.fromOffset(28,28),Size=UDim2.new(1,-56,0,42),TextSize=22,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); title.ZIndex=302
	local body=Racing.Label(panel,{Text=options.Body or "Continue?",Position=UDim2.fromOffset(42,88),Size=UDim2.new(1,-84,0,100),TextSize=14,XAlignment=Enum.TextXAlignment.Center}); body.TextWrapped=true; body.ZIndex=302
	local no=Racing.Button(panel,{Text=options.CancelText or "NO",Position=UDim2.new(.5,-158,1,-72),Size=UDim2.fromOffset(142,44),Color=Color3.fromRGB(166,61,70),ZIndex=303}); local yes=Racing.Button(panel,{Text=options.ConfirmText or "YES",Position=UDim2.new(.5,16,1,-72),Size=UDim2.fromOffset(142,44),Color=Racing.Colour("PanelBlue"),StrokeColor=Racing.Colour("ElectricBlue"),ZIndex=303})
	no.Activated:Connect(function() shade:Destroy(); if options.OnCancel then options.OnCancel() end end); yes.Activated:Connect(function() shade:Destroy(); if options.OnConfirm then options.OnConfirm() end end); return shade
end
]==]
	return replaceOnce(source,"\nreturn M","\n"..confirmation.."return M","shared confirmation")
end)

project(workspaceBase,"NTR_OWNED_GARAGE_PHASE8_INCREMENTAL_WORKSPACE",function(source)
	source=replaceOnce(source,"-- NTR_GARAGE_WORKSPACE_CONTROLLER_V3","-- NTR_GARAGE_WORKSPACE_CONTROLLER_V3\n-- NTR_OWNED_GARAGE_PHASE8_INCREMENTAL_WORKSPACE","workspace marker")
	source=replaceOnce(source,'DisplayName=row.DisplayName or row.Id or "",Eyebrow=row.Eyebrow', 'DisplayName=row.DisplayName or row.Id or "",EmptyPlus=row.EmptyPlus,Muted=row.Muted,Eyebrow=row.Eyebrow',"card props")
	source=replaceOnce(source,'function WorkspaceUI:RenderStats(context) clear(self.Stats); if context.RenderStats then context.RenderStats(self.Stats) else self:DrawPerformance(self.Stats,context.Performance,context.BaselinePerformance,context.TierColor) end end', 'function WorkspaceUI:RenderStats(context) clear(self.Stats); self.Stats.Visible=context.ShowStats~=false; if not self.Stats.Visible then return end; if context.RenderStats then context.RenderStats(self.Stats) else self:DrawPerformance(self.Stats,context.Performance,context.BaselinePerformance,context.TierColor) end end',"optional stats")
	source=replaceOnce(source,'local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Activated', 'local plus=generated(Racing.Button(self.Cash,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); plus.Visible=context.ShowCashPlus~=false; plus.Activated',"cash plus policy")
	source=replaceOnce(source,'local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Activated', 'local gp=generated(Racing.Button(self.Capacity,{Text="+",Position=UDim2.new(1,-40,.5,-15),Size=UDim2.fromOffset(32,30),StrokeColor=Racing.Colour("ElectricBlue")})); gp.Visible=context.ShowCapacityPlus~=false; gp.Activated',"capacity plus policy")
	source=replaceOnce(source,'function WorkspaceUI:Audit(selectedCard)\n\ttask.defer(function()', 'function WorkspaceUI:Audit(selectedCard)\n\tif not (cfg:GetAttribute("RuntimeAuditEnabled")==true and (not self.Context or self.Context.RuntimeAudit~=false)) then return end\n\ttask.defer(function()',"workspace audit gate")
	local refresh=[==[
function WorkspaceUI:RefreshCards(context)
	self:CaptureScroll(); self:DisconnectDynamic(); self.Context=context; self.Title.Text=string.upper(context.Title or "GARAGE"); self.Subtitle.Text=context.Subtitle or ""; self.Back.Visible=context.BackVisible==true; Shared.SetActionButton(self.Back,context.BackText or "BACK",context.BackIcon,context.BackIconText or "<"); local selected=self:RenderCards(context); self:QueueScrollRestore(context); self:Audit(selected); return selected
end
]==]
	return replaceOnce(source,"function WorkspaceUI:Show(context)",refresh.."function WorkspaceUI:Show(context)","incremental cards")
end)

project(workspaceBase,"NTR_OWNED_GARAGE_VEHICLE_CARD_KIND_V1_6",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PHASE8_INCREMENTAL_WORKSPACE","-- NTR_OWNED_GARAGE_PHASE8_INCREMENTAL_WORKSPACE\n-- NTR_OWNED_GARAGE_VEHICLE_CARD_KIND_V1_6","vehicle card marker")
	local oldCards=[=[
		local selected=row.Selected==true; local props={DisplayName=row.DisplayName or row.Id or "",EmptyPlus=row.EmptyPlus,Muted=row.Muted,Eyebrow=row.Eyebrow,Meta=row.Meta,Footer=row.Footer,Image=self:ResolveImage(row.ImageKey or row.Id,row.Image),Rating=row.Badge,RatingColor=row.BadgeColor,Badge=row.Badge,BadgeColor=row.BadgeColor,Selected=selected,VehicleName=row.VehicleName,Variant=row.Variant,TagText=row.TagText,TagColor=row.TagColor,Price=row.Price,PriceText=row.PriceText,PriceColor=row.PriceColor,SemanticState=row.SemanticState,LockImage=row.LockImage,LockIconSize=N("LockedModuleIconSize",68),LockIconYScale=N("LockedModuleIconYScale",.46),Size=UDim2.fromOffset(N("WorkspaceCardWidth",210),N("WorkspaceCardHeight",146)),ImageHeight=N("ModuleCardImageHeight",104),ImageZoom=row.ImageZoom or 1.04}
		local card=generated(row.CardKind=="Listing" and Shared.ModuleListingCard(self.Scroller,props) or Shared.ModuleCategoryCard(self.Scroller,props)); card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end); if selected then selectedCard=card; if row.ActionText and row.OnAction then self.Popup:Set(card,row.ActionText,row.OnAction,self.Scale) end end
]=]
	local newCards=[=[
		local selected=row.Selected==true; local vehicleCard=row.CardKind=="Vehicle"; local props={DisplayName=row.DisplayName or row.Id or "",EmptyPlus=row.EmptyPlus,Muted=row.Muted,Eyebrow=row.Eyebrow,Meta=row.Meta,Footer=row.Footer,Image=self:ResolveImage(row.ImageKey or row.Id,row.Image),Rating=row.Badge,RatingColor=row.BadgeColor,Badge=row.Badge,BadgeColor=row.BadgeColor,Selected=selected,VehicleName=row.VehicleName,Variant=row.Variant,TagText=row.TagText,TagColor=row.TagColor,Price=row.Price,PriceText=row.PriceText,PriceColor=row.PriceColor,SemanticState=row.SemanticState,LockImage=row.LockImage,LockIconSize=N("LockedModuleIconSize",68),LockIconYScale=N("LockedModuleIconYScale",.46),Size=vehicleCard and UDim2.fromOffset(N("CardWidth",226),N("CardHeight",146)) or UDim2.fromOffset(N("WorkspaceCardWidth",210),N("WorkspaceCardHeight",146)),ImageHeight=vehicleCard and N("CardImageHeight",136) or N("ModuleCardImageHeight",104),ImageZoom=row.ImageZoom or (vehicleCard and 1.06 or 1.04)}
		local card=generated(row.CardKind=="Listing" and Shared.ModuleListingCard(self.Scroller,props) or (vehicleCard and Shared.Card(self.Scroller,props) or Shared.ModuleCategoryCard(self.Scroller,props))); card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end); if selected then selectedCard=card; if row.ActionText and row.OnAction then self.Popup:Set(card,row.ActionText,row.OnAction,self.Scale) end end
]=]
	source=replaceOnce(source,oldCards,newCards,"shared dealership vehicle cards")
	local oldScroll='function WorkspaceUI:Scroll(direction) local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local step=(N("WorkspaceCardWidth",210)+12)*scale; self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*step,0,self.MaxScroll or 0),0); self:RefreshCarouselArrows() end'
	local newScroll='function WorkspaceUI:Scroll(direction) local scale=math.max(self.LayoutScale or self.Scale.Scale,.01); local logicalWidth=N("WorkspaceCardWidth",210); for _,child in ipairs(self.Scroller:GetChildren()) do if child:GetAttribute("CanonicalGarageCard") then logicalWidth=child.AbsoluteSize.X/math.max(scale,.01); break end end; local step=(logicalWidth+12)*scale; self.Scroller.CanvasPosition=Vector2.new(math.clamp(self.Scroller.CanvasPosition.X+direction*step,0,self.MaxScroll or 0),0); self:RefreshCarouselArrows() end'
	return replaceOnce(source,oldScroll,newScroll,"adaptive vehicle card scroll")
end)

project(workspaceBase,"NTR_OWNED_GARAGE_SELECTED_ACTION_CONTRACT_V1_7",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_VEHICLE_CARD_KIND_V1_6","-- NTR_OWNED_GARAGE_VEHICLE_CARD_KIND_V1_6\n-- NTR_OWNED_GARAGE_SELECTED_ACTION_CONTRACT_V1_7","selected action marker")
	source=replaceOnce(source,'self.Paint.Visible=false; self.Scroller.Visible=true; self:RenderBudget(context); clear(self.Scroller); self.Popup:Hide(); local selectedCard','self.Paint.Visible=false; self.Scroller.Visible=true; self:RenderBudget(context); clear(self.Scroller); self.Popup:Hide(); local selectedCard; local explicitActionCard; local legacyAction; local selectedAction=context.SelectedAction',"selected action state")
	source=replaceOnce(source,'local card=generated(row.CardKind=="Listing" and Shared.ModuleListingCard(self.Scroller,props) or (vehicleCard and Shared.Card(self.Scroller,props) or Shared.ModuleCategoryCard(self.Scroller,props))); card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end); if selected then selectedCard=card; if row.ActionText and row.OnAction then self.Popup:Set(card,row.ActionText,row.OnAction,self.Scale) end end','local card=generated(row.CardKind=="Listing" and Shared.ModuleListingCard(self.Scroller,props) or (vehicleCard and Shared.Card(self.Scroller,props) or Shared.ModuleCategoryCard(self.Scroller,props))); card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end); if selected then selectedCard=card; if row.ActionText and row.OnAction then legacyAction={Card=card,Text=row.ActionText,OnActivate=row.OnAction} end end; if selectedAction and tostring(selectedAction.RowId or "")==tostring(row.Id or "") then explicitActionCard=card end',"selected action capture")
	source=replaceOnce(source,'\tif context.EmptyMessage and #(context.Cards or {})==0 then','\tlocal action=selectedAction and explicitActionCard and {Card=explicitActionCard,Text=selectedAction.Text,OnActivate=selectedAction.OnActivate} or legacyAction; if action and action.Text and action.OnActivate then self.Popup:Set(action.Card,action.Text,action.OnActivate,self.Scale) end\n\tif context.EmptyMessage and #(context.Cards or {})==0 then',"selected action mount")
	return source
end)

project(browser,"NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V3_ASYNC_OPEN",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V2_HARDENED","-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V2_HARDENED\n-- NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V3_ASYNC_OPEN","browser marker")
	source=replaceOnce(source,'local C=function(name) return UI.Colour(name) end; local L=function(name,fallback) return UI.Layout(name,fallback) end; local T=function(name,fallback) return UI.Type(name,fallback) end; local state; local selected; local busy=false; local cards={}', 'local C=function(name) return UI.Colour(name) end; local L=function(name,fallback) return UI.Layout(name,fallback) end; local T=function(name,fallback) return UI.Type(name,fallback) end; local state; local selected; local busy=false; local cards={}; local generation=0',"browser generation")
	source=replaceOnce(source,'local function close() for _,child in ipairs(shell:GetChildren()) do if child.Name=="ReplacementPrompt" then child:Destroy() end end; overlay.Visible=false;', 'local function close() generation+=1; for _,child in ipairs(shell:GetChildren()) do if child.Name=="ReplacementPrompt" then child:Destroy() end end; overlay.Visible=false;',"browser close token")
	source=replaceOnce(source,'local function open()\n\t\tlocal result=request("GetState",{}); if not result.Success then overlay.Visible=true; presentation(true); setStatus(result.Message,false); task.defer(hardenTouch); return end; state=result; selected=nil; for _,property in ipairs(state.Properties or {}) do if property.PropertyId==state.ActiveGarageId then selected=property; break end end; selected=selected or (state.Properties and state.Properties[1]); render(); overlay.Visible=true; presentation(true); setStatus(""); task.defer(hardenTouch)\n\tend', 'local function open()\n\t\tgeneration+=1; local token=generation; overlay.Visible=true; presentation(true); if state then render() end; setStatus(state and "" or "LOADING GARAGES...",true); task.spawn(function() local result=request("GetState",{}); if token~=generation then return end; if not result.Success then setStatus(result.Message,false); return end; state=result; selected=nil; for _,property in ipairs(state.Properties or {}) do if property.PropertyId==state.ActiveGarageId then selected=property; break end end; selected=selected or (state.Properties and state.Properties[1]); render(); setStatus(""); task.defer(hardenTouch) end)\n\tend',"async browser open")
	return source
end)

project(clientStarter,"NTR_OWNED_GARAGE_PHASE8_INTERIOR_HUD_START",function(source)
	return replaceOnce(source,'local order={"OwnedGarageBrowserController","OwnedGarageWorkspaceController","GarageInteriorModeController","GarageInteriorTransitionController"}', '-- NTR_OWNED_GARAGE_PHASE8_INTERIOR_HUD_START\nlocal order={"OwnedGarageBrowserController","OwnedGarageWorkspaceController","GarageInteriorModeController","GarageInteriorTransitionController","GarageInteriorHudController"}',"HUD starter")
end)

project(clientStarter,"NTR_OWNED_GARAGE_PHASE8_EXISTING_INTERIOR_MODE_OWNER_V1_4",function(source)
	return replaceOnce(source,'-- NTR_OWNED_GARAGE_PHASE8_INTERIOR_HUD_START\nlocal order={"OwnedGarageBrowserController","OwnedGarageWorkspaceController","GarageInteriorModeController","GarageInteriorTransitionController","GarageInteriorHudController"}', '-- NTR_OWNED_GARAGE_PHASE8_INTERIOR_HUD_START\n-- NTR_OWNED_GARAGE_PHASE8_EXISTING_INTERIOR_MODE_OWNER_V1_4\nlocal order={"OwnedGarageBrowserController","OwnedGarageWorkspaceController","GarageInteriorModeController","GarageInteriorTransitionController"}',"existing interior HUD owner starter")
end)

project(desktop,"NTR_OWNED_GARAGE_PHASE8_HUD_POLICY",function(source)
	source=replaceOnce(source,"-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1","-- NTR_UI_PERFORMANCE_HARDENING_PHASE1_V1\n-- NTR_OWNED_GARAGE_PHASE8_HUD_POLICY","desktop marker")
	source=replaceOnce(source,'local moneyLabel\nlocal minimap', 'local moneyLabel\nlocal moneyPanel\nlocal garageAction\nlocal raceAction\nlocal dealershipAction\nlocal settingsAction\nlocal minimap',"desktop HUD refs")
	source=replaceOnce(source,'local garageAction = actionIcon(', 'garageAction = actionIcon(',"garage action ref")
	source=replaceOnce(source,'local raceAction = actionIcon(', 'raceAction = actionIcon(',"race action ref")
	source=replaceOnce(source,'local dealershipAction = actionIcon(', 'dealershipAction = actionIcon(',"shop action ref")
	source=replaceOnce(source,'local settingsAction = actionIcon(', 'settingsAction = actionIcon(',"settings action ref")
	source=replaceOnce(source,'money.BackgroundColor3 = C("PanelBlue")', 'moneyPanel=money\n\tmoney.BackgroundColor3 = C("PanelBlue")',"money ref")
	source=replaceOnce(source,'local driving = vehicle ~= nil\n\tactionBar.Visible = not racingPresentationActive', 'local driving = vehicle ~= nil\n\tlocal ownedGarageInside = player:GetAttribute("NTR_OwnedGarageInside") == true\n\tactionBar.Visible = not racingPresentationActive; if carButton then carButton.Visible=not ownedGarageInside end; if garageAction then garageAction.Visible=not ownedGarageInside end; if raceAction then raceAction.Visible=not ownedGarageInside end; if dealershipAction then dealershipAction.Visible=not ownedGarageInside end; if settingsAction then settingsAction.Visible=true end',"desktop action policy")
	source=replaceOnce(source,'-- NTR_OWNED_GARAGE_PHASE5_HUD_POLICY_V1\n\tlocal ownedGarageInside = player:GetAttribute("NTR_OwnedGarageInside") == true\n\tleftCluster.Visible = not racingPresentationActive and not carPanel.Visible\n\tif minimap then minimap.Visible = not ownedGarageInside end', '-- NTR_OWNED_GARAGE_PHASE5_HUD_POLICY_V1\n\tleftCluster.Visible = not racingPresentationActive and not carPanel.Visible\n\tif minimap then minimap.Visible = not ownedGarageInside end\n\tif moneyPanel then moneyPanel.Position=ownedGarageInside and UDim2.fromOffset(0,L("MinimapSize",245)+8) or UDim2.fromOffset(0,0) end',"desktop cash placement")
	return source
end)

project(mobile,"NTR_OWNED_GARAGE_PHASE8_HUD_POLICY",function(source)
	source=replaceOnce(source,"-- NTR_MOBILE_FREEROAM_UI_PHASE1O_MAJOR_MENU_SUPPRESSION","-- NTR_MOBILE_FREEROAM_UI_PHASE1O_MAJOR_MENU_SUPPRESSION\n-- NTR_OWNED_GARAGE_PHASE8_HUD_POLICY","mobile marker")
	source=replaceOnce(source,'suppressExactLegacyHud(); layout()', 'layout()',"remove per-frame hierarchy scan")
	source=replaceOnce(source,'local camera=workspace.CurrentCamera; local vp=camera and camera.ViewportSize or Vector2.new(1280,720); if vp==lastSize then return end; lastSize=vp', 'local camera=workspace.CurrentCamera; local vp=camera and camera.ViewportSize or Vector2.new(1280,720); local inside=player:GetAttribute("NTR_OwnedGarageInside")==true; if vp==lastSize and inside==lastInside then return end; lastSize=vp; lastInside=inside',"mobile garage layout invalidation")
	source=replaceOnce(source,'mapFrame.Position=UDim2.fromOffset(mapX,margin); mapFrame.Size=UDim2.fromOffset(mapSize,mapSize); cash.Position=UDim2.fromOffset(mapX,margin+mapSize+clusterGap); cash.Size=UDim2.fromOffset(mapSize,tiny and 30 or tonumber(read(config,"CashHeight",34)))', 'local cashHeight=tiny and 30 or tonumber(read(config,"CashHeight",34))\n\tif inside then\n\t\tnav.Position=UDim2.fromOffset(vp.X-margin-navSize,margin); nav.Size=UDim2.fromOffset(navSize,navSize); settingsButton.Position=UDim2.fromOffset(0,0)\n\t\tcash.Position=UDim2.fromOffset(margin,vp.Y-margin-cashHeight); cash.Size=UDim2.fromOffset(mapSize,cashHeight)\n\telse\n\t\tmapFrame.Position=UDim2.fromOffset(mapX,margin); mapFrame.Size=UDim2.fromOffset(mapSize,mapSize)\n\t\tcash.Position=UDim2.fromOffset(mapX,margin+mapSize+clusterGap); cash.Size=UDim2.fromOffset(mapSize,cashHeight)\n\tend',"mobile garage placement")
	source=replaceOnce(source,'mapFrame.Visible=not ownedGarageInside and not telemetryOnly and not localMajorMenuOpen cash.Visible=not telemetryOnly and not localMajorMenuOpen nav.Visible=not telemetryOnly and not localMajorMenuOpen', 'mapFrame.Visible=not ownedGarageInside and not telemetryOnly and not localMajorMenuOpen; cash.Visible=not telemetryOnly and not localMajorMenuOpen; nav.Visible=not telemetryOnly and not localMajorMenuOpen; carButton.Visible=not ownedGarageInside; garageButton.Visible=not ownedGarageInside; raceButton.Visible=not ownedGarageInside; shopButton.Visible=not ownedGarageInside; settingsButton.Visible=true',"mobile visibility")
	source=replaceOnce(source,'if os.clock()>=nextProfile then nextProfile=os.clock()+3; task.defer(function() local p=profile(false); cashText.Text="$"..tostring(math.floor(tonumber(p.Cash) or 0)) end) end', '-- Cash is event-driven from leaderstats; no recurring profile request.',"mobile cash polling")
	source=replaceOnce(source,'local displayedPos=nil; local displayedHeading=0; local displayedBoost=1; local lastSize=Vector2.zero; local nextProfile=0', 'local displayedPos=nil; local displayedHeading=0; local displayedBoost=1; local lastSize=Vector2.zero; local lastInside=nil\nlocal function bindCash() local stats=player:FindFirstChild("leaderstats"); local value=stats and stats:FindFirstChild("Cash"); if not value then return false end; local function update() cashText.Text="$"..tostring(math.floor(tonumber(value.Value) or 0)) end; update(); value:GetPropertyChangedSignal("Value"):Connect(update); return true end\nif not bindCash() then task.spawn(function() local stats=player:WaitForChild("leaderstats",15); if stats then stats:WaitForChild("Cash",15) end; bindCash() end) end',"event-driven mobile cash")
	return source
end)

project(desktop,"NTR_OWNED_GARAGE_MANAGEMENT_HUD_SUPPRESSION_V1_6",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PHASE8_HUD_POLICY","-- NTR_OWNED_GARAGE_PHASE8_HUD_POLICY\n-- NTR_OWNED_GARAGE_MANAGEMENT_HUD_SUPPRESSION_V1_6","desktop management HUD marker")
	return replaceOnce(source,'local enabled = readValue(config, "Enabled", true) == true and not majorMenuOpen','local ownedGarageManagementOpen = playerGui:GetAttribute("NTR_OwnedGarageManagementOpen") == true\n\tlocal enabled = readValue(config, "Enabled", true) == true and not majorMenuOpen and not ownedGarageManagementOpen',"desktop management HUD suppression")
end)

project(mobile,"NTR_OWNED_GARAGE_MANAGEMENT_HUD_SUPPRESSION_V1_6",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PHASE8_HUD_POLICY","-- NTR_OWNED_GARAGE_PHASE8_HUD_POLICY\n-- NTR_OWNED_GARAGE_MANAGEMENT_HUD_SUPPRESSION_V1_6","mobile management HUD marker")
	return replaceOnce(source,'local function majorMenu() return player:GetAttribute("NTR_GarageSessionActive")==true end','local function majorMenu() return player:GetAttribute("NTR_GarageSessionActive")==true or playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true end',"mobile management HUD suppression")
end)

if commandRuntime then projected[commandRuntime]=commandRuntimeSource end

local snapshots={}; local attributes={}; local NIL_ATTRIBUTE={}; local createdCommandRuntime=false
local attributeNames={"OwnedGarageRevision","OwnedGarageInstallRunId","TemplateContractVersion","StateSchemaVersion","ReadRequestsPerSecond","MutationRequestsPerSecond","MaxActiveInteriorsPerServer","DebugTimingEnabled","EnableDisplayCars","EnableStructure","EnableDecorations","EnableLighting","EnableAccess","EnableInvitations","EnableVisitors"}
for _,name in ipairs(attributeNames) do local value=config:GetAttribute(name); attributes[name]=value==nil and NIL_ATTRIBUTE or value end
local runtimeAuditValue=replacementConfig:GetAttribute("RuntimeAuditEnabled"); local replacementAttributes={RuntimeAuditEnabled=runtimeAuditValue==nil and NIL_ATTRIBUTE or runtimeAuditValue}
local ok,problem=pcall(function()
	if not commandRuntime then commandRuntime=Instance.new("ModuleScript"); commandRuntime.Name="OwnedGarageAuthoritativeCommandRuntime"; commandRuntime.Source=commandRuntimeSource; commandRuntime:SetAttribute("OwnedGarageRevision",REVISION); commandRuntime:SetAttribute("OwnedGarageInstallRunId",RUN_ID); commandRuntime.Parent=garage; createdCommandRuntime=true end
	for object,source in pairs(projected) do snapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}; object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID); config:SetAttribute("TemplateContractVersion",1); config:SetAttribute("StateSchemaVersion",2); config:SetAttribute("ReadRequestsPerSecond",20); config:SetAttribute("MutationRequestsPerSecond",12); config:SetAttribute("MaxActiveInteriorsPerServer",24); config:SetAttribute("DebugTimingEnabled",false); config:SetAttribute("EnableDisplayCars",true); config:SetAttribute("EnableStructure",false); config:SetAttribute("EnableDecorations",false); config:SetAttribute("EnableLighting",false); config:SetAttribute("EnableAccess",true); config:SetAttribute("EnableInvitations",false); config:SetAttribute("EnableVisitors",false); replacementConfig:SetAttribute("RuntimeAuditEnabled",false)
	for object,marker in pairs({[catalog]="NTR_OWNED_GARAGE_PROPERTY_CATALOG_V3_TEMPLATE_COMPATIBILITY",[action]="NTR_OWNED_GARAGE_PHASE8_VEHICLE_CARD_BRIDGE_V1_4_PLAYER_CONTEXT",[management]="NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V6_PROFILE_COMMAND_BOUNDARY",[profileService]="NTR_PROFILE_SERVICE_OWNED_GARAGE_COMMAND_OWNER_V1",[commandRuntime]="NTR_OWNED_GARAGE_AUTHORITATIVE_COMMAND_RUNTIME_V1",[shared]="NTR_OWNED_GARAGE_PHASE8_SHARED_PRESENTATION",[workspaceBase]="NTR_OWNED_GARAGE_SELECTED_ACTION_CONTRACT_V1_7",[browser]="NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V3_ASYNC_OPEN",[workspace]="NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V7_AUTHORITATIVE_SELECTED_ACTION",[clientStarter]="NTR_OWNED_GARAGE_PHASE8_EXISTING_INTERIOR_MODE_OWNER_V1_4",[interiorMode]="NTR_OWNED_GARAGE_INTERIOR_MODE_CONTROLLER_V2_PHASE8_EXISTING_OWNER",[desktop]="NTR_OWNED_GARAGE_MANAGEMENT_HUD_SUPPRESSION_V1_6",[mobile]="NTR_OWNED_GARAGE_MANAGEMENT_HUD_SUPPRESSION_V1_6"}) do assert(has(object,marker),"Phase 8 source contract missing: "..marker) end
	assert(commandRuntime.Parent==garage,"Authoritative command runtime was not committed")
	assert(has(management,"ExecuteOwnedGarageCommand") and not has(management,"markDirty:Invoke"),"Management command boundary is not authoritative")
	assert(config:GetAttribute("EnableDisplayCars")==true and config:GetAttribute("EnableStructure")==false and config:GetAttribute("TemplateContractVersion")==1,"Phase 8 feature gates invalid")
end)
if not ok then
	for object,snapshot in pairs(snapshots) do if object.Parent then object.Source=snapshot.Source; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	if createdCommandRuntime and commandRuntime and commandRuntime.Parent then commandRuntime:Destroy() end
	for name,value in pairs(attributes) do if value==NIL_ATTRIBUTE then config:SetAttribute(name,nil) else config:SetAttribute(name,value) end end; for name,value in pairs(replacementAttributes) do if value==NIL_ATTRIBUTE then replacementConfig:SetAttribute(name,nil) else replacementConfig:SetAttribute(name,value) end end
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS sources=13 newModules=1 apiVersion=2 templateContract=1 revision="..REVISION.." runId="..RUN_ID)
print(TAG.." READY: live-profile commands commit before presentation and preserve distinct slots.")
print(TAG.." FEATURE GATES: DisplayCars=true; Structure/Decorations/Lighting/Invitations/Visitors remain false for later approved phases.")
