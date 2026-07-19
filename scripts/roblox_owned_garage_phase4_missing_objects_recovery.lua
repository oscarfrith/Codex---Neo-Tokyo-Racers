-- Neo Tokyo Racers - Owned Garage Phase 4 focused hierarchy recovery
-- Current Phase 4 installer. Run in Studio Edit mode only.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 4 Recovery]"
local REVISION="NTR_OWNED_GARAGE_PHASE4_MANAGEMENT_WORKSPACE_RECOVERY_V1"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path)
	local object=root
	for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end
	return object
end
local function source(object) local ok,value=pcall(function() return object.Source end); return ok and value or "" end
local function has(object,marker) return object~=nil and string.find(source(object),marker,1,true)~=nil end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local data=assert(find(kit,"Shared.Modules.Data"),"Shared.Modules.Data missing")
local services=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"UI controllers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage_EditAttributes missing")

for _,check in ipairs({
	{find(data,"OwnedGaragePropertyCatalog"),"NTR_OWNED_GARAGE_PROPERTY_CATALOG_V1","property catalogue"},
	{find(services,"OwnedGarageProfileRuntime"),"function Runtime.SetSurfaceStyle","Phase 4 profile source"},
	{find(services,"OwnedGarageDisplayAssignmentRuntime"),'operation=="SetSurfaceStyle"',"Phase 4 assignment source"},
	{find(services,"OwnedGarageManagementRuntime"),'Type="OpenManagement"',"Phase 4 management source"},
	{find(ui,"OwnedGarageBrowserController"),"NTR_OWNED_GARAGE_BROWSER_CONTROLLER_V1","owned browser"},
	{find(ui,"GarageWorkspaceController"),"return WorkspaceUI","shared workspace"},
	{find(ui,"GarageReplacementComponents"),"return M","shared garage components"},
}) do assert(has(check[1],check[2]),"Baseline mismatch: "..check[3]) end

local styleSource=[==[
-- NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1
local Catalog={}
local styles={
	{StyleId="FLOOR_MIDNIGHT",SurfaceGroup="Floor",DisplayName="Midnight Metal",Color=Color3.fromRGB(18,23,31),Material="Metal",SortOrder=10,Default=true},
	{StyleId="FLOOR_GRAPHITE",SurfaceGroup="Floor",DisplayName="Graphite",Color=Color3.fromRGB(48,54,64),Material="Metal",SortOrder=11},
	{StyleId="FLOOR_CLEAN",SurfaceGroup="Floor",DisplayName="Clean Composite",Color=Color3.fromRGB(115,122,132),Material="SmoothPlastic",SortOrder=12},
	{StyleId="WALL_MIDNIGHT",SurfaceGroup="Walls",DisplayName="Midnight Walls",Color=Color3.fromRGB(27,34,45),Material="Metal",SortOrder=20,Default=true},
	{StyleId="WALL_CONCRETE",SurfaceGroup="Walls",DisplayName="Urban Concrete",Color=Color3.fromRGB(76,79,84),Material="Concrete",SortOrder=21},
	{StyleId="WALL_WHITE",SurfaceGroup="Walls",DisplayName="Studio White",Color=Color3.fromRGB(170,176,184),Material="SmoothPlastic",SortOrder=22},
	{StyleId="ROOF_DARK",SurfaceGroup="Roof",DisplayName="Dark Roof",Color=Color3.fromRGB(12,16,23),Material="Metal",SortOrder=30,Default=true},
	{StyleId="ROOF_GRAPHITE",SurfaceGroup="Roof",DisplayName="Graphite Roof",Color=Color3.fromRGB(50,56,67),Material="Metal",SortOrder=31},
	{StyleId="PAD_CYAN",SurfaceGroup="DisplayPads",DisplayName="Cyan Display Pads",Color=Color3.fromRGB(24,61,74),Material="Metal",SortOrder=40,Default=true},
	{StyleId="PAD_MAGENTA",SurfaceGroup="DisplayPads",DisplayName="Magenta Display Pads",Color=Color3.fromRGB(82,28,66),Material="Metal",SortOrder=41},
	{StyleId="PAD_GUNMETAL",SurfaceGroup="DisplayPads",DisplayName="Gunmetal Display Pads",Color=Color3.fromRGB(42,47,55),Material="Metal",SortOrder=42},
	{StyleId="DOOR_STEEL",SurfaceGroup="Doors",DisplayName="Steel Door",Color=Color3.fromRGB(44,54,70),Material="Metal",SortOrder=50,Default=true},
	{StyleId="DOOR_RED",SurfaceGroup="Doors",DisplayName="Signal Red Door",Color=Color3.fromRGB(126,42,52),Material="Metal",SortOrder=51},
}
local function clone(value) if type(value)~="table" then return value end; local copy={}; for key,child in pairs(value) do copy[key]=clone(child) end; return copy end
function Catalog.List() local result=clone(styles); table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end); return result end
function Catalog.ById(styleId) for _,style in ipairs(styles) do if style.StyleId==tostring(styleId or "") then return clone(style) end end end
function Catalog.ForSurface(group) local result={}; for _,style in ipairs(styles) do if style.SurfaceGroup==tostring(group or "") then table.insert(result,clone(style)) end end; table.sort(result,function(a,b) return a.SortOrder<b.SortOrder end); return result end
function Catalog.DefaultStyles() local result={}; for _,style in ipairs(styles) do if style.Default then result[style.SurfaceGroup]=style.StyleId end end; return result end
function Catalog.IsValid(group,styleId) local style=Catalog.ById(styleId); return style~=nil and style.SurfaceGroup==tostring(group or "") end
return Catalog
]==]

local workspaceSource=[==[
-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V1
local Controller={}; local started=false
function Controller.Start()
	if started then return true,"AlreadyStarted" end
	local ReplicatedStorage=game:GetService("ReplicatedStorage"); local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers"); local uiFolder=script.Parent; local Racing=require(kit.Shared.Modules.UI:WaitForChild("RacingUIComponents")); local WorkspaceUI=require(uiFolder:WaitForChild("GarageWorkspaceController")); local Shared=require(uiFolder:WaitForChild("GarageReplacementComponents")); local styleCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog")); local remote=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageInvoke"); local push=kit.Shared.Remotes.Garage:WaitForChild("OwnedGarageEvent"); local openEvent=uiFolder:WaitForChild("OpenOwnedGarageWorkspace")
	local workspace=WorkspaceUI.new(); workspace.Root.Name="OwnedGarageCanonicalWorkspace"; workspace.Audit=function(self) Shared.AuditPresentation(self.Root,"Owned Garage Workspace") end
	local state; local page="DisplaySlots"; local selectedSlot="Space01"; local selectedVehicle; local selectedStyle; local selectedAccess; local busy=false; local imageCache={}; local render
	local function request(action,args) local ok,result=pcall(function() return remote:InvokeServer(action,args or {}) end); if ok and type(result)=="table" then return result end; return {Success=false,Message="Garage management is unavailable."} end
	local function imageFor(cockpitId) cockpitId=tostring(cockpitId or ""); if imageCache[cockpitId]~=nil then return imageCache[cockpitId] end; local image=""; local categories=kit.Assets.Vehicles:FindFirstChild("Categories"); if categories then for _,candidate in ipairs(categories:GetDescendants()) do if candidate:IsA("Model") and tostring(candidate:GetAttribute("CockpitId") or "")==cockpitId then image=tostring(candidate:GetAttribute("PreviewImage") or candidate:GetAttribute("Image") or ""); break end end end; imageCache[cockpitId]=image; return image end
	local function vehicleById(id) for _,vehicle in ipairs(state and state.Vehicles or {}) do if vehicle.VehicleId==tostring(id or "") then return vehicle end end end
	local function property() for _,item in ipairs(state and state.Properties or {}) do if item.PropertyId==state.CurrentPropertyId then return item end end return state and state.Properties and state.Properties[1] end
	local function close() workspace:Hide() end
	local function refresh(nextPage) local result=request("GetManagementState",{}); if not result.Success or not result.InGarage then warn("[NTR Owned Garage] "..tostring(result.Message or "Management requires an active garage interior.")); close(); return false end; state=result; if nextPage then page=nextPage end; return true end
	local function operate(action,args,nextPage) if busy then return end; busy=true; local result=request(action,args); busy=false; if not result.Success then workspace:Message(result.Message or "Garage update failed."); return end; if refresh(nextPage) then render() end end
	local function tabs() return {{Id="Display",Text="DISPLAY CARS",Selected=page=="DisplaySlots" or page=="DisplayVehicles",OnSelect=function() page="DisplaySlots"; selectedVehicle=nil; render() end},{Id="Interior",Text="INTERIOR",Selected=page=="Interior",OnSelect=function() page="Interior"; selectedStyle=nil; render() end},{Id="Access",Text="ACCESS",Selected=page=="Access",OnSelect=function() page="Access"; selectedAccess=nil; render() end}} end
	local function info(title,body) return function(parent) local heading=Racing.Label(parent,{Text=string.upper(title),Size=UDim2.new(1,0,0,30),TextSize=16,Role="Heading",XAlignment=Enum.TextXAlignment.Center}); heading:SetAttribute("GeneratedGarageWorkspace",true); heading.LayoutOrder=1; local copy=Racing.Label(parent,{Text=body,Size=UDim2.new(1,0,0,78),TextSize=12,XAlignment=Enum.TextXAlignment.Center}); copy.TextWrapped=true; copy:SetAttribute("GeneratedGarageWorkspace",true); copy.LayoutOrder=2 end end
	local function context(subtitle,cards) local item=property(); return {Title="GARAGE MANAGEMENT",Subtitle=subtitle,ShowLeft=true,LeftItems=tabs(),Cards=cards,Cash=state.Cash or 0,CapacityText=tostring(item and item.Filled or 0).."/"..tostring(item and item.Capacity or 0).." DISPLAY SPACES",NextVisible=false,ExitVisible=true,ExitText="CLOSE",OnExit=close,OnCash=function() end,OnCapacity=function() end,CarouselScrollKey="OwnedGarage:"..page,CategoryScrollKey="OwnedGarageTabs",RenderStats=info("OWNER WORKSPACE","Choose display vehicles, edit the interior, or prepare property access. Changes are validated and saved.")} end
	local function hidePlus() for _,container in ipairs({workspace.Cash,workspace.Capacity}) do for _,child in ipairs(container:GetChildren()) do if child:IsA("GuiButton") and child.Text=="+" then child.Visible=false end end end end
	render=function()
		if not state then return end; local cards={}; local view
		if page=="DisplaySlots" then
			local found=false; for _,slot in ipairs(state.Slots or {}) do if slot.SlotId==selectedSlot then found=true end end; if not found and state.Slots and state.Slots[1] then selectedSlot=state.Slots[1].SlotId end
			for index,slot in ipairs(state.Slots or {}) do local vehicle=vehicleById(slot.VehicleId); local row={Id=slot.SlotId,DisplayName=slot.DisplayName,Badge="SPACE "..index,Image=vehicle and imageFor(vehicle.CockpitId) or "",Selected=slot.SlotId==selectedSlot,Footer=vehicle and "DISPLAYED" or "EMPTY",ActionText="CHOOSE VEHICLE"}; row.OnSelect=function() selectedSlot=slot.SlotId; render() end; row.OnAction=function() page="DisplayVehicles"; selectedVehicle=tostring(slot.VehicleId or ""); if selectedVehicle=="false" then selectedVehicle="" end; render() end; table.insert(cards,row) end
			view=context("Choose a display space to manage.",cards); view.RenderStats=info("DISPLAY CARS","Each saved vehicle can appear in only one display space. Reassigning it clears its former display reference without deleting it.")
		elseif page=="DisplayVehicles" then
			local assigned=""; for _,slot in ipairs(state.Slots or {}) do if slot.SlotId==selectedSlot and slot.VehicleId and slot.VehicleId~=false then assigned=tostring(slot.VehicleId) end end; if not selectedVehicle or selectedVehicle=="" then selectedVehicle=assigned~="" and assigned or (state.Vehicles and state.Vehicles[1] and state.Vehicles[1].VehicleId) end
			for _,vehicle in ipairs(state.Vehicles or {}) do local current=vehicle.VehicleId==assigned; local row={Id=vehicle.VehicleId,DisplayName=vehicle.DisplayName,Image=imageFor(vehicle.CockpitId),Badge=current and "DISPLAYED" or nil,Selected=vehicle.VehicleId==selectedVehicle,Footer=current and "CURRENT SPACE" or "OWNED VEHICLE",ActionText=current and "REMOVE FROM DISPLAY" or "DISPLAY HERE"}; row.OnSelect=function() selectedVehicle=vehicle.VehicleId; render() end; row.OnAction=function() if current then operate("ClearDisplay",{SlotId=selectedSlot},"DisplaySlots") else operate("AssignDisplay",{SlotId=selectedSlot,VehicleId=vehicle.VehicleId},"DisplaySlots") end end; table.insert(cards,row) end
			view=context("Choose the saved vehicle for "..selectedSlot..".",cards); view.BackVisible=true; view.BackText="DISPLAY SPACES"; view.OnBack=function() page="DisplaySlots"; render() end; view.EmptyMessage="NO OWNED VEHICLES AVAILABLE"
		elseif page=="Interior" then
			local styles=state.InteriorStyles or styleCatalog.List(); if not selectedStyle and styles[1] then selectedStyle=styles[1].StyleId end
			for _,style in ipairs(styles) do local current=state.SurfaceStyles and state.SurfaceStyles[style.SurfaceGroup]==style.StyleId; local row={Id=style.StyleId,DisplayName=style.DisplayName,Badge=string.upper(style.SurfaceGroup),Selected=style.StyleId==selectedStyle,Footer=current and "CURRENT" or string.upper(style.Material or "STYLE"),SemanticState=current and "Equipped" or "Shop",CardKind="Listing",ActionText=current and nil or "APPLY STYLE"}; row.OnSelect=function() selectedStyle=style.StyleId; render() end; row.OnAction=function() operate("SetInteriorStyle",{SurfaceGroup=style.SurfaceGroup,StyleId=style.StyleId},"Interior") end; table.insert(cards,row) end
			view=context("Choose editable surface styles for this property.",cards); view.RenderStats=info("INTERIOR","Surface presets are catalogue-driven and saved per garage property.")
		else
			local modes={{Id="Private",Text="PRIVATE",Body="Only the owner can enter."},{Id="FriendsOnly",Text="FRIENDS ONLY",Body="Reserved for friend access."},{Id="InviteOnly",Text="INVITE ONLY",Body="Reserved for invitations."},{Id="Public",Text="PUBLIC",Body="Reserved for public visits."}}; selectedAccess=selectedAccess or state.AccessMode
			for _,mode in ipairs(modes) do local current=mode.Id==state.AccessMode; local row={Id=mode.Id,DisplayName=mode.Text,Badge=current and "CURRENT" or "ACCESS",Selected=mode.Id==selectedAccess,Footer=mode.Body,SemanticState=current and "Equipped" or "Shop",CardKind="Listing",ActionText=current and nil or "SET ACCESS"}; row.OnSelect=function() selectedAccess=mode.Id; render() end; row.OnAction=function() operate("SetAccessMode",{AccessMode=mode.Id},"Access") end; table.insert(cards,row) end
			view=context("Choose the saved access policy for this garage.",cards); view.RenderStats=info("ACCESS","The policy is persistent. Visitor admission remains disabled until its later activation gate.")
		end
		workspace:Show(view); hidePlus()
	end
	local function open() if refresh("DisplaySlots") then selectedSlot="Space01"; selectedVehicle=nil; selectedStyle=nil; selectedAccess=nil; render() end end
	openEvent.Event:Connect(function() if workspace.Root.Visible then close() else open() end end); push.OnClientEvent:Connect(function(message) if type(message)=="table" and message.Type=="OpenManagement" then open() elseif type(message)=="table" and message.Type=="DriveOut" then close() end end)
	started=true; print("[NTR Owned Garage] Workspace controller active."); return true,"Started"
end
return Controller
]==]

local function compile(name,text)
	local module=Instance.new("ModuleScript"); module.Name=name; module.Source=text; module.Parent=ReplicatedStorage
	local ok,result=pcall(require,module); module:Destroy(); assert(ok and type(result)=="table",name.." compile failed: "..tostring(result)); return result
end
local styles=compile("NTR_Phase4StyleCompile",styleSource)
local workspace=compile("NTR_Phase4WorkspaceCompile",workspaceSource)
assert(#styles.List()>=10 and styles.IsValid("Walls","WALL_CONCRETE"),"Style catalogue audit failed")
assert(type(workspace.Start)=="function","Workspace controller contract failed")

local snapshots={}; local created={}; local oldConfigRevision=config:GetAttribute("OwnedGarageRevision"); local oldConfigRunId=config:GetAttribute("OwnedGarageInstallRunId")
local ok,problem=pcall(function()
	local function module(parent,name,text,marker)
		local object=parent:FindFirstChild(name)
		if object then assert(object:IsA("ModuleScript"),object:GetFullName().." has the wrong class"); snapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")}
		else object=Instance.new("ModuleScript"); object.Name=name; table.insert(created,object) end
		object.Source=text; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID); if not object.Parent then object.Parent=parent end
		assert(has(object,marker),name.." source verification failed"); return object
	end
	local style=module(data,"OwnedGarageInteriorStyleCatalog",styleSource,"NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1")
	local controller=module(ui,"OwnedGarageWorkspaceController",workspaceSource,"NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V1")
	local event=ui:FindFirstChild("OpenOwnedGarageWorkspace")
	if event then assert(event:IsA("BindableEvent"),event:GetFullName().." has the wrong class"); snapshots[event]={Revision=event:GetAttribute("OwnedGarageRevision"),RunId=event:GetAttribute("OwnedGarageInstallRunId"),Inert=event:GetAttribute("OwnedGarageStagingInert")}
	else event=Instance.new("BindableEvent"); event.Name="OpenOwnedGarageWorkspace"; event.Parent=ui; table.insert(created,event) end
	event:SetAttribute("OwnedGarageRevision",REVISION); event:SetAttribute("OwnedGarageInstallRunId",RUN_ID); event:SetAttribute("OwnedGarageStagingInert",true)
	config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID)
	assert(style.Parent==data and controller.Parent==ui and event.Parent==ui,"Exact-parent audit failed")
end)
if not ok then
	for object,snapshot in pairs(snapshots) do if object.Parent then if snapshot.Source then object.Source=snapshot.Source end; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId); object:SetAttribute("OwnedGarageStagingInert",snapshot.Inert) end end
	for _,object in ipairs(created) do if object.Parent then object:Destroy() end end
	config:SetAttribute("OwnedGarageRevision",oldConfigRevision); config:SetAttribute("OwnedGarageInstallRunId",oldConfigRunId)
	error(TAG.." ROLLED BACK: "..tostring(problem))
end

print(TAG.." PASS objects=3 revision="..REVISION.." runId="..RUN_ID.." placeId="..tostring(game.PlaceId))
print(TAG.." INACTIVE: no service, controller, UI, profile, vehicle, HOME, or legacy-owner activation occurred.")
