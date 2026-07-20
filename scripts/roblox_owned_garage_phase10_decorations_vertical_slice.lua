-- Neo Tokyo Racers - Owned Garage Phase 10 canonical Decorations vertical slice
-- Run once in Roblox Studio Edit mode after confirmed Phase 9 V1.1.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 10 Decorations]"
local REVISION="NTR_OWNED_GARAGE_PHASE10_DECORATIONS_V1"
local BASE="NTR_OWNED_GARAGE_PHASE9_STRUCTURE_V1_1_ASSET_TEMPLATES"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path) local object=root; for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end; return object end
local function replaceOnce(source,old,new,label) local a,b=string.find(source,old,1,true); assert(a,label.." anchor missing"); assert(not string.find(source,old,b+1,true),label.." anchor not unique"); return source:sub(1,a-1)..new..source:sub(b+1) end
local function compile(name,source) local fn,problem=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(problem)) end
local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage config missing")
local installed=config:GetAttribute("OwnedGarageRevision")
assert(installed==BASE or installed==REVISION,"Confirmed Phase 9 Structure baseline is not current")
local data=assert(find(kit,"Shared.Modules.Data"),"Shared data missing")
local garage=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"Client UI missing")
local storageRoot=assert(find(ServerStorage,"NeoTokyoRacers.OwnedGarage"),"OwnedGarage storage root missing")
local template=assert(storageRoot:FindFirstChild("Templates") and storageRoot.Templates:FindFirstChild("StarterTwoBay"),"StarterTwoBay template missing")
local propertyCatalog=assert(data:FindFirstChild("OwnedGaragePropertyCatalog"),"Property catalog missing")
local profile=assert(garage:FindFirstChild("OwnedGarageProfileRuntime"),"Profile runtime missing")
local assignment=assert(garage:FindFirstChild("OwnedGarageDisplayAssignmentRuntime"),"Assignment runtime missing")
local commands=assert(garage:FindFirstChild("OwnedGarageAuthoritativeCommandRuntime"),"Command runtime missing")
local management=assert(garage:FindFirstChild("OwnedGarageManagementRuntime"),"Management runtime missing")
local controller=assert(ui:FindFirstChild("OwnedGarageWorkspaceController"),"Workspace controller missing")
local anchors=assert(template:FindFirstChild("DecorationAnchors"),"DecorationAnchors missing")
for index=1,3 do assert(anchors:FindFirstChild("DecorationAnchor"..index) and anchors["DecorationAnchor"..index]:IsA("BasePart"),"DecorationAnchor"..index.." missing") end

local decorationCatalogSource=[==[
-- NTR_OWNED_GARAGE_DECORATION_CATALOG_V1
local Catalog={Version=1}
local categories={
	{CategoryId="Plants",DisplayName="PLANTS",IconKey="Leaf",SortOrder=10},
	{CategoryId="Paintings",DisplayName="PAINTINGS",IconKey="Image",SortOrder=20},
	{CategoryId="Furniture",DisplayName="FURNITURE",IconKey="Chair",SortOrder=30},
	{CategoryId="Lighting",DisplayName="LIGHTING",IconKey="Light",SortOrder=40},
	{CategoryId="Storage",DisplayName="STORAGE",IconKey="Box",SortOrder=50},
	{CategoryId="Signs",DisplayName="SIGNS",IconKey="Sign",SortOrder=60},
}
local items={
	{ItemId="PLANT_NEON_FERN",CategoryId="Plants",AssetName="NeonFern",DisplayName="Neon Fern",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="PLANT_TALL_PALM",CategoryId="Plants",AssetName="TallPalm",DisplayName="Tall Palm",Price=3500,SortOrder=20},
	{ItemId="PAINTING_CITY_GRID",CategoryId="Paintings",AssetName="CityGrid",DisplayName="City Grid",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="PAINTING_NIGHT_RUN",CategoryId="Paintings",AssetName="NightRun",DisplayName="Night Run",Price=4500,SortOrder=20},
	{ItemId="FURNITURE_LOW_BENCH",CategoryId="Furniture",AssetName="LowBench",DisplayName="Low Bench",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="FURNITURE_LOUNGE_CHAIR",CategoryId="Furniture",AssetName="LoungeChair",DisplayName="Lounge Chair",Price=6000,SortOrder=20},
	{ItemId="LIGHTING_FLOOR_LAMP",CategoryId="Lighting",AssetName="FloorLamp",DisplayName="Floor Lamp",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="LIGHTING_NEON_TOTEM",CategoryId="Lighting",AssetName="NeonTotem",DisplayName="Neon Totem",Price=7000,SortOrder=20},
	{ItemId="STORAGE_TOOL_CRATE",CategoryId="Storage",AssetName="ToolCrate",DisplayName="Tool Crate",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="STORAGE_PARTS_LOCKER",CategoryId="Storage",AssetName="PartsLocker",DisplayName="Parts Locker",Price=5000,SortOrder=20},
	{ItemId="SIGN_KANDA",CategoryId="Signs",AssetName="KandaSign",DisplayName="Kanda Sign",Price=0,SortOrder=10,DefaultOwned=true},
	{ItemId="SIGN_RACER_CREW",CategoryId="Signs",AssetName="RacerCrew",DisplayName="Racer Crew",Price=5500,SortOrder=20},
}
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
function Catalog.Categories() return clone(categories) end
function Catalog.Items(categoryId) local r={}; for _,item in ipairs(items) do if not categoryId or item.CategoryId==tostring(categoryId) then table.insert(r,clone(item)) end end; table.sort(r,function(a,b) if a.SortOrder~=b.SortOrder then return a.SortOrder<b.SortOrder end return a.ItemId<b.ItemId end); return r end
function Catalog.ById(itemId) for _,item in ipairs(items) do if item.ItemId==tostring(itemId or "") then return clone(item) end end end
function Catalog.IsAnchor(anchorId,anchorIds) for _,id in ipairs(anchorIds or {}) do if id==tostring(anchorId or "") then return true end end; return false end
function Catalog.Normalize(value,anchorIds)
	value=type(value)=="table" and value or {}; value.OwnedItems=type(value.OwnedItems)=="table" and value.OwnedItems or {}; value.Placements=type(value.Placements)=="table" and value.Placements or {}
	for _,item in ipairs(items) do if item.DefaultOwned then value.OwnedItems[item.ItemId]=true end end
	for anchorId,itemId in pairs(value.Placements) do if not Catalog.IsAnchor(anchorId,anchorIds) or not Catalog.ById(itemId) then value.Placements[anchorId]=nil end end
	return value
end
function Catalog.Validate(value,anchorIds) value=Catalog.Normalize(value,anchorIds); for anchorId,itemId in pairs(value.Placements) do if not (Catalog.IsAnchor(anchorId,anchorIds) and Catalog.ById(itemId) and value.OwnedItems[itemId]) then return false,"Invalid decoration placement." end end; return true end
function Catalog.ClientState(value,anchorIds)
	value=Catalog.Normalize(clone(value),anchorIds); local byCategory={}; for _,category in ipairs(categories) do byCategory[category.CategoryId]=Catalog.Items(category.CategoryId) end
	local anchorList={}; for index,anchorId in ipairs(anchorIds or {}) do table.insert(anchorList,{AnchorId=anchorId,DisplayName="DISPLAY POSITION "..index,SortOrder=index}) end
	return {Version=Catalog.Version,Categories=Catalog.Categories(),ItemsByCategory=byCategory,Anchors=anchorList,OwnedItems=clone(value.OwnedItems),Placements=clone(value.Placements)}
end
return Catalog
]==]
compile("OwnedGarageDecorationCatalog",decorationCatalogSource)

local projected={}; local expectedMarkers={}
local function project(object,marker,transform) local source=object.Source; if not source:find(marker,1,true) then source=transform(source) end; assert(source:find(marker,1,true),object.Name.." marker missing"); compile(object.Name,source); projected[object]=source; expectedMarkers[object]=marker end

project(propertyCatalog,"NTR_OWNED_GARAGE_PROPERTY_CATALOG_V5_DECORATION_ANCHORS",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V4_EXTERIOR_SPAWNS","-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V4_EXTERIOR_SPAWNS\n-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V5_DECORATION_ANCHORS","property marker")
	return replaceOnce(source,'DecorationAnchorIds={"DecorationAnchor1","DecorationAnchor2"}','DecorationAnchorIds={"DecorationAnchor1","DecorationAnchor2","DecorationAnchor3"}',"third decoration anchor")
end)

project(profile,"NTR_OWNED_GARAGE_DECORATION_PROFILE_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_STRUCTURE_PROFILE_V1","-- NTR_OWNED_GARAGE_STRUCTURE_PROFILE_V1\n-- NTR_OWNED_GARAGE_DECORATION_PROFILE_V1","profile marker")
	local old=[=[local Runtime={SchemaVersion=2}]=]
	local new=[=[local DecorationCatalogCache
local function DecorationCatalog()
	if not DecorationCatalogCache then local source=script:FindFirstChild("OwnedGarageDecorationCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGarageDecorationCatalog"); DecorationCatalogCache=require(source) end
	return DecorationCatalogCache
end
local Runtime={SchemaVersion=2}]=]
	source=replaceOnce(source,old,new,"decoration catalog resolver")
	source=replaceOnce(source,'property.Customisation.Decorations=type(property.Customisation.Decorations)=="table" and property.Customisation.Decorations or {}; property.Customisation.Structure=StyleCatalog().NormalizeStructure(property.Customisation.Structure,definition.StructureSections)','property.Customisation.Decorations=DecorationCatalog().Normalize(property.Customisation.Decorations,definition.DecorationAnchorIds); property.Customisation.Structure=StyleCatalog().NormalizeStructure(property.Customisation.Structure,definition.StructureSections)',"decoration normalize")
	source=replaceOnce(source,'local definition=Catalog().ById(garageId); local structureValid','local definition=Catalog().ById(garageId); local decorationValid,decorationMessage=DecorationCatalog().Validate(property.Customisation.Decorations,definition and definition.DecorationAnchorIds or {}); if not decorationValid then return false,decorationMessage end; local structureValid',"decoration validation")
	local addition=[==[
function Runtime.ConfigureDecoration(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local property=garage.Properties[garageId]; local definition=Catalog().ById(garageId); local action=tostring(args.Action or ""); local anchorId=tostring(args.AnchorId or ""); local itemId=tostring(args.ItemId or "")
	if not (property and property.Owned and definition) then return false,"Garage is not owned." end; if not DecorationCatalog().IsAnchor(anchorId,definition.DecorationAnchorIds) then return false,"Decoration position is invalid." end
	local decorations=DecorationCatalog().Normalize(property.Customisation.Decorations,definition.DecorationAnchorIds); property.Customisation.Decorations=decorations
	if action=="Purchase" then local item=DecorationCatalog().ById(itemId); if not item then return false,"Decoration is invalid." end; if decorations.OwnedItems[itemId] then return false,"Decoration is already owned." end; local cost=math.max(0,math.floor(tonumber(item.Price) or 0)); if (tonumber(profile.Cash) or 0)<cost then return false,"Not enough cash." end; profile.Cash=(tonumber(profile.Cash) or 0)-cost; decorations.OwnedItems[itemId]=true; decorations.Placements[anchorId]=itemId
	elseif action=="Place" then if not (DecorationCatalog().ById(itemId) and decorations.OwnedItems[itemId]) then return false,"Purchase this decoration first." end; decorations.Placements[anchorId]=itemId
	elseif action=="Clear" then decorations.Placements[anchorId]=nil
	else return false,"Unknown decoration action." end
	garage.Revision+=1; return true,action=="Clear" and "Decoration removed." or "Decoration updated."
end
]==]
	return replaceOnce(source,"function Runtime.NewRequestId()",addition.."function Runtime.NewRequestId()","decoration command")
end)

project(assignment,"NTR_OWNED_GARAGE_DECORATION_TRANSACTION_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_STRUCTURE_TRANSACTION_V1","-- NTR_OWNED_GARAGE_STRUCTURE_TRANSACTION_V1\n-- NTR_OWNED_GARAGE_DECORATION_TRANSACTION_V1","assignment marker")
	source=replaceOnce(source,'tostring(args.Color or "")','tostring(args.Color or ""),tostring(args.AnchorId or ""),tostring(args.ItemId or "")',"decoration fingerprint")
	return replaceOnce(source,'elseif operation=="ConfigureStructure" then success,message=Profile.ConfigureStructure(profile,args)','elseif operation=="ConfigureStructure" then success,message=Profile.ConfigureStructure(profile,args)\n\t\telseif operation=="ConfigureDecoration" then success,message=Profile.ConfigureDecoration(profile,args)',"decoration transaction route")
end)

project(commands,"NTR_OWNED_GARAGE_DECORATION_COMMAND_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_STRUCTURE_COMMAND_V1","-- NTR_OWNED_GARAGE_STRUCTURE_COMMAND_V1\n-- NTR_OWNED_GARAGE_DECORATION_COMMAND_V1","command marker")
	return replaceOnce(source,"ConfigureStructure=true}","ConfigureStructure=true,ConfigureDecoration=true}","decoration allowlist")
end)

project(management,"NTR_OWNED_GARAGE_DECORATION_MANAGEMENT_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_STRUCTURE_ASSET_RUNTIME_V1","-- NTR_OWNED_GARAGE_STRUCTURE_ASSET_RUNTIME_V1\n-- NTR_OWNED_GARAGE_DECORATION_MANAGEMENT_V1","management marker")
	source=replaceOnce(source,'local styleCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog"))','local styleCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageInteriorStyleCatalog")); local decorationCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageDecorationCatalog"))',"decoration catalog require")
	local functionBlock=[==[
	local function applyDecorations(profile,session)
		local property=profile.OwnedGarage.Properties[session.PropertyId]; local definition=catalog.ById(session.PropertyId); local anchorIds=definition and definition.DecorationAnchorIds or {}; local decorations=decorationCatalog.Normalize(property and property.Customisation and property.Customisation.Decorations,anchorIds); local anchorRoot=session.Interior:FindFirstChild("DecorationAnchors"); if not anchorRoot then return false,"Decoration anchors are missing." end
		local assets=ServerStorage:FindFirstChild("NeoTokyoRacers"); assets=assets and assets:FindFirstChild("OwnedGarage"); assets=assets and assets:FindFirstChild("DecorationAssets"); if not assets then return false,"Decoration assets are missing." end
		local runtime=session.Interior:FindFirstChild("DecorationRuntime"); if not runtime then runtime=Instance.new("Folder"); runtime.Name="DecorationRuntime"; runtime.Parent=session.Interior end; runtime:ClearAllChildren()
		for _,anchorId in ipairs(anchorIds) do local itemId=decorations.Placements[anchorId]; if session.DecorationPreview and session.DecorationPreview.AnchorId==anchorId then itemId=session.DecorationPreview.ItemId end; if itemId then local item=decorationCatalog.ById(itemId); local anchor=anchorRoot:FindFirstChild(anchorId); local category= item and assets:FindFirstChild(item.CategoryId); local asset=category and category:FindFirstChild(item.AssetName); if not (item and anchor and anchor:IsA("BasePart") and asset and asset:IsA("Model")) then return false,"Decoration asset missing: "..tostring(itemId).."/"..tostring(anchorId) end; local clone=asset:Clone(); clone.Name=anchorId; for _,object in ipairs(clone:GetDescendants()) do if object:IsA("LuaSourceContainer") or object:IsA("ProximityPrompt") or object:IsA("Seat") or object:IsA("VehicleSeat") then object:Destroy() elseif object:IsA("BasePart") then local localCFrame=object.CFrame; object.CFrame=anchor.CFrame*localCFrame; object.Anchored=true; object.CanTouch=false; object.CanQuery=false; object.CanCollide=false; object.CastShadow=false end end; clone:SetAttribute("DecorationAnchorId",anchorId); clone:SetAttribute("DecorationItemId",itemId); clone:SetAttribute("DecorationPreview",session.DecorationPreview and session.DecorationPreview.AnchorId==anchorId or false); clone.Parent=runtime end end
		return true
	end
]==]
	source=replaceOnce(source,"\tlocal function renderDisplays(player,profile,session)",functionBlock.."\tlocal function renderDisplays(player,profile,session)","decoration renderer")
	source=replaceOnce(source,'applyInteriorStyles(profile,session); local configured,configureMessage=configurePrompts(player,profile,session)','local styled,styleMessage=applyInteriorStyles(profile,session); if not styled then sessions[player]=nil; scheduleUnload(interior,player); return nil,styleMessage end; local decorated,decorationMessage=applyDecorations(profile,session); if not decorated then sessions[player]=nil; scheduleUnload(interior,player); return nil,decorationMessage end; local configured,configureMessage=configurePrompts(player,profile,session)',"session decoration presentation")
	source=replaceOnce(source,'((operation=="SetSurfaceStyle" or operation=="ConfigureStructure") and "Structure" or (operation=="SetAccessMode" and "Access"))','((operation=="SetSurfaceStyle" or operation=="ConfigureStructure") and "Structure" or (operation=="ConfigureDecoration" and "Decorations" or (operation=="SetAccessMode" and "Access")))',"decoration capability")
	source=replaceOnce(source,'elseif operation=="SetSurfaceStyle" or operation=="ConfigureStructure" then applyInteriorStyles(committed,session) end; return result end','elseif operation=="SetSurfaceStyle" or operation=="ConfigureStructure" then applyInteriorStyles(committed,session) elseif operation=="ConfigureDecoration" then applyDecorations(committed,session) end; return result end',"decoration failure presentation")
	source=replaceOnce(source,'elseif operation=="SetSurfaceStyle" or operation=="ConfigureStructure" then session.StructurePreview=nil; presented=applyInteriorStyles(committed,session) end;','elseif operation=="SetSurfaceStyle" or operation=="ConfigureStructure" then session.StructurePreview=nil; presented=applyInteriorStyles(committed,session) elseif operation=="ConfigureDecoration" then session.DecorationPreview=nil; presented=applyDecorations(committed,session) end;',"decoration success presentation")
	source=replaceOnce(source,'DecorationCategories=catalog.DecorationCategories(),Structure= currentProperty','DecorationCategories=catalog.DecorationCategories(),Decorations=currentProperty and decorationCatalog.ClientState(currentProperty.Customisation.Decorations,(catalog.ById(session.PropertyId) or {}).DecorationAnchorIds or {}) or nil,Structure= currentProperty',"decoration state")
	source=replaceOnce(source,'or action=="CancelStructurePreview"','or action=="CancelStructurePreview" or action=="PreviewDecoration" or action=="CancelDecorationPreview"',"decoration controls")
	source=replaceOnce(source,'\t\t\telseif action=="EnterSelectedGarage" then','\t\t\telseif action=="PreviewDecoration" then local session=sessions[player]; local definition=session and catalog.ById(session.PropertyId); local anchorId=tostring(args.AnchorId or ""); local item=decorationCatalog.ById(args.ItemId); if not (session and item and decorationCatalog.IsAnchor(anchorId,definition and definition.DecorationAnchorIds)) then return {Success=false,Message="Decoration preview is invalid."} end; session.DecorationPreview={AnchorId=anchorId,ItemId=item.ItemId}; local rendered,message=applyDecorations(profile,session); return {Success=rendered==true,Message=message or "Decoration preview ready."}\n\t\t\telseif action=="CancelDecorationPreview" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; session.DecorationPreview=nil; local rendered,message=applyDecorations(profile,session); return {Success=rendered==true,Message=message or "Decoration preview cleared."}\n\t\t\telseif action=="EnterSelectedGarage" then',"decoration preview routes")
	return replaceOnce(source,'\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end','\t\t\telseif action=="ConfigureDecoration" then return managedOperation(player,profile,"ConfigureDecoration",{AnchorId=tostring(args.AnchorId or ""),ItemId=tostring(args.ItemId or ""),Action=tostring(args.Action or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision})\n\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end',"decoration mutation route")
end)

project(controller,"NTR_OWNED_GARAGE_DECORATION_UI_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_STRUCTURE_UI_V1_1_CAPABILITY_ASSETS","-- NTR_OWNED_GARAGE_STRUCTURE_UI_V1_1_CAPABILITY_ASSETS\n-- NTR_OWNED_GARAGE_DECORATION_UI_V1","UI marker")
	source=replaceOnce(source,'local selectedSlot; local selectedVehicle; local selectedSection="FrontWall"; local selectedStyle; local selectedChannel="Primary"','local selectedSlot; local selectedVehicle; local selectedSection="FrontWall"; local selectedStyle; local selectedChannel="Primary"; local selectedDecorationCategory; local selectedDecorationAnchor; local selectedDecorationItem',"decoration UI state")
	source=replaceOnce(source,'local function cancelPreview() previewGeneration+=1; previewReady=false; selectedVehicle=nil; if state and state.InGarage then task.spawn(function() request("CancelDisplayPreview",{}); request("CancelStructurePreview",{}) end) end end','local function cancelPreview() previewGeneration+=1; previewReady=false; selectedVehicle=nil; if state and state.InGarage then task.spawn(function() request("CancelDisplayPreview",{}); request("CancelStructurePreview",{}); request("CancelDecorationPreview",{}) end) end end',"cancel preview")
	source=replaceOnce(source,'local function close() generation+=1; closeModal(); setManagementOpen(false); workspace:Hide(); if state and state.InGarage then task.spawn(function() request("CancelDisplayPreview",{}); request("CancelStructurePreview",{}); request("SetManagementOpen",{Open=false}) end) end end','local function close() generation+=1; closeModal(); setManagementOpen(false); workspace:Hide(); if state and state.InGarage then task.spawn(function() request("CancelDisplayPreview",{}); request("CancelStructurePreview",{}); request("CancelDecorationPreview",{}); request("SetManagementOpen",{Open=false}) end) end end',"close preview")
	source=replaceOnce(source,'or page==item.Id; table.insert(result','or (item.Id=="Decorations" and string.sub(page,1,10)=="Decoration") or page==item.Id; table.insert(result',"decoration tab state")
	local branch=[==[
		elseif string.sub(page,1,10)=="Decoration" then
			local decorations=state.Decorations or {}; local function itemById(id) for _,list in pairs(decorations.ItemsByCategory or {}) do for _,item in ipairs(list) do if item.ItemId==id then return item end end end end
			if page=="Decorations" then for _,item in ipairs(decorations.Categories or {}) do local category=item; table.insert(cards,{Id=category.CategoryId,DisplayName=category.DisplayName,Footer="CHOOSE CATEGORY",OnSelect=function() selectedDecorationCategory=category.CategoryId; selectedDecorationAnchor=nil; selectedDecorationItem=nil; page="DecorationAnchors"; render(true) end}) end; view=context("Choose a decoration category.",cards)
			elseif page=="DecorationAnchors" then for _,item in ipairs(decorations.Anchors or {}) do local anchor=item; local currentId=decorations.Placements and decorations.Placements[anchor.AnchorId]; local current=itemById(currentId); table.insert(cards,{Id=anchor.AnchorId,DisplayName=current and current.DisplayName or "EMPTY POSITION",Footer=current and "DISPLAYED" or "CHOOSE POSITION",EmptyPlus=current==nil,Selected=anchor.AnchorId==selectedDecorationAnchor,OnSelect=function() selectedDecorationAnchor=anchor.AnchorId; selectedDecorationItem=nil; page="DecorationItems"; render(true) end}) end; view=context("Choose a position for this decoration.",cards)
			elseif page=="DecorationItems" then local list=(decorations.ItemsByCategory and decorations.ItemsByCategory[selectedDecorationCategory]) or {}; local currentId=decorations.Placements and decorations.Placements[selectedDecorationAnchor]; for _,item in ipairs(list) do local decoration=item; local owned=decorations.OwnedItems and decorations.OwnedItems[decoration.ItemId]; local current=currentId==decoration.ItemId; table.insert(cards,{Id=decoration.ItemId,CardKind="Listing",VehicleName=string.upper(selectedDecorationCategory or "DECORATION"),DisplayName=decoration.DisplayName,Price=owned and nil or decoration.Price,Footer=current and "CURRENT" or (owned and "OWNED" or "LOCKED"),SemanticState=current and "Equipped" or (owned and "Available" or "Locked"),Selected=decoration.ItemId==selectedDecorationItem,OnSelect=function() selectedDecorationItem=decoration.ItemId; request("PreviewDecoration",{AnchorId=selectedDecorationAnchor,ItemId=decoration.ItemId}); render(false) end}) end; view=context("Choose a decoration to preview.",cards); local chosen=itemById(selectedDecorationItem); if chosen then local owned=decorations.OwnedItems and decorations.OwnedItems[chosen.ItemId]; local current=currentId==chosen.ItemId; view.SelectedAction={RowId=chosen.ItemId,Text=current and "REMOVE" or (owned and "PLACE" or "BUY"),OnActivate=function() if current then operate("ConfigureDecoration",{AnchorId=selectedDecorationAnchor,Action="Clear"},"DecorationAnchors",nil,nil,"DECORATION REMOVED") elseif owned then operate("ConfigureDecoration",{AnchorId=selectedDecorationAnchor,ItemId=chosen.ItemId,Action="Place"},"DecorationAnchors",nil,nil,"DECORATION PLACED") else operate("ConfigureDecoration",{AnchorId=selectedDecorationAnchor,ItemId=chosen.ItemId,Action="Purchase"},"DecorationAnchors",nil,nil,"DECORATION PURCHASED") end end} end
			end
			view.BackVisible=true; view.BackText="BACK"; view.OnBack=function() request("CancelDecorationPreview",{}); selectedDecorationItem=nil; if page=="Decorations" then page="DisplaySpaces" elseif page=="DecorationAnchors" then page="Decorations" else page="DecorationAnchors" end; render(true) end
]==]
	return replaceOnce(source,"\t\telse\n\t\t\tview=context(page..\" is definition-ready and activates in its dedicated implementation phase.\",{})",branch.."\t\telse\n\t\t\tview=context(page..\" is definition-ready and activates in its dedicated implementation phase.\",{})","decoration pages")
end)

local sourceSnapshots={}; for object in pairs(projected) do sourceSnapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")} end
local created={}; local anchorSnapshots={}; local configSnapshot={Revision=config:GetAttribute("OwnedGarageRevision"),RunId=config:GetAttribute("OwnedGarageInstallRunId"),Enabled=config:GetAttribute("EnableDecorations"),Contract=config:GetAttribute("DecorationContractVersion"),Assets=config:GetAttribute("DecorationAssetContractVersion")}
local function create(className,name,parent) local object=Instance.new(className); object.Name=name; object.Parent=parent; table.insert(created,object); return object end
local function folder(parent,name) local object=parent:FindFirstChild(name); if object then assert(object:IsA("Folder"),object:GetFullName().." must be a Folder"); return object end; return create("Folder",name,parent) end
local function part(parent,name,size,cframe,color,material)
	local object=create("Part",name,parent); object.Size=size; object.CFrame=cframe; object.Color=color; object.Material=material or Enum.Material.SmoothPlastic; object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false; object.CastShadow=false; return object
end
local definitions={
	Plants={{"NeonFern",Vector3.new(2.4,.8,2.4),Vector3.new(0,.4,0)},{"TallPalm",Vector3.new(2.8,1,2.8),Vector3.new(0,.5,0)}},
	Paintings={{"CityGrid",Vector3.new(5,3,.25),Vector3.new(0,2.2,0)},{"NightRun",Vector3.new(6,3.5,.25),Vector3.new(0,2.4,0)}},
	Furniture={{"LowBench",Vector3.new(5,1.2,2),Vector3.new(0,.6,0)},{"LoungeChair",Vector3.new(3,2.8,3),Vector3.new(0,1.4,0)}},
	Lighting={{"FloorLamp",Vector3.new(1.2,5,1.2),Vector3.new(0,2.5,0)},{"NeonTotem",Vector3.new(1.5,6,1.5),Vector3.new(0,3,0)}},
	Storage={{"ToolCrate",Vector3.new(3,2,2.4),Vector3.new(0,1,0)},{"PartsLocker",Vector3.new(3,5,2),Vector3.new(0,2.5,0)}},
	Signs={{"KandaSign",Vector3.new(5,2,.35),Vector3.new(0,2,0)},{"RacerCrew",Vector3.new(6,2.5,.35),Vector3.new(0,2.2,0)}},
}
local ok,problem=pcall(function()
	local decorationCatalog=data:FindFirstChild("OwnedGarageDecorationCatalog"); if not decorationCatalog then decorationCatalog=create("ModuleScript","OwnedGarageDecorationCatalog",data) else assert(decorationCatalog:IsA("ModuleScript"),"OwnedGarageDecorationCatalog must be a ModuleScript") end; local catalogSnapshot={Source=decorationCatalog.Source,Revision=decorationCatalog:GetAttribute("OwnedGarageRevision"),RunId=decorationCatalog:GetAttribute("OwnedGarageInstallRunId")}; if not sourceSnapshots[decorationCatalog] then sourceSnapshots[decorationCatalog]=catalogSnapshot end; decorationCatalog.Source=decorationCatalogSource; decorationCatalog:SetAttribute("OwnedGarageRevision",REVISION); decorationCatalog:SetAttribute("OwnedGarageInstallRunId",RUN_ID)
	for object,source in pairs(projected) do object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	for index=1,3 do local anchor=anchors["DecorationAnchor"..index]; anchorSnapshots[anchor]={Id=anchor:GetAttribute("DecorationAnchorId"),Version=anchor:GetAttribute("DecorationAnchorContractVersion"),Categories=anchor:GetAttribute("AllowedDecorationCategories")}; anchor:SetAttribute("DecorationAnchorId",anchor.Name); anchor:SetAttribute("DecorationAnchorContractVersion",1); anchor:SetAttribute("AllowedDecorationCategories","*") end
	local assetsRoot=folder(storageRoot,"DecorationAssets")
	for categoryId,list in pairs(definitions) do local category=folder(assetsRoot,categoryId); for index,item in ipairs(list) do local model=category:FindFirstChild(item[1]); if not model then model=create("Model",item[1],category); model:SetAttribute("DecorationAssetContractVersion",1); model:SetAttribute("PlaceholderTemplate",true); model:SetAttribute("CategoryId",categoryId); local primary=part(model,"Primary",item[2],CFrame.new(item[3]),index==1 and Color3.fromRGB(38,45,58) or Color3.fromRGB(75,81,92),Enum.Material.Metal); primary:SetAttribute("DecorationChannel","Primary"); local accentSize=Vector3.new(math.max(.25,item[2].X*.75),math.max(.25,item[2].Y*.18),math.max(.15,item[2].Z*1.05)); local accent=part(model,"Detail",accentSize,CFrame.new(item[3]+Vector3.new(0,item[2].Y*.3,0)),index==1 and Color3.fromRGB(26,210,220) or Color3.fromRGB(224,58,178),Enum.Material.Neon); accent:SetAttribute("DecorationChannel","Detail"); model.PrimaryPart=primary end; assert(model:IsA("Model") and model:FindFirstChild("Primary"),"Decoration template invalid: "..categoryId.."/"..item[1]) end end
	config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID); config:SetAttribute("EnableDecorations",true); config:SetAttribute("DecorationContractVersion",1); config:SetAttribute("DecorationAssetContractVersion",1)
	assert(propertyCatalog.Source:find('DecorationAnchorIds={"DecorationAnchor1","DecorationAnchor2","DecorationAnchor3"}',1,true),"Three-anchor catalogue contract missing")
	assert(decorationCatalog.Source:find("NTR_OWNED_GARAGE_DECORATION_CATALOG_V1",1,true),"Decoration catalogue marker missing")
	for object,marker in pairs(expectedMarkers) do assert(object.Source:find(marker,1,true),"Exact decoration marker missing: "..object.Name.." / "..marker) end
	local optionCount=0; for _,list in pairs(definitions) do optionCount+=#list end; assert(optionCount==12,"Decoration option count invalid")
end)
if not ok then
	for object,snapshot in pairs(sourceSnapshots) do if object.Parent then object.Source=snapshot.Source; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	for anchor,snapshot in pairs(anchorSnapshots) do if anchor.Parent then anchor:SetAttribute("DecorationAnchorId",snapshot.Id); anchor:SetAttribute("DecorationAnchorContractVersion",snapshot.Version); anchor:SetAttribute("AllowedDecorationCategories",snapshot.Categories) end end
	for index=#created,1,-1 do local object=created[index]; if object and object.Parent then object:Destroy() end end
	config:SetAttribute("OwnedGarageRevision",configSnapshot.Revision); config:SetAttribute("OwnedGarageInstallRunId",configSnapshot.RunId); config:SetAttribute("EnableDecorations",configSnapshot.Enabled); config:SetAttribute("DecorationContractVersion",configSnapshot.Contract); config:SetAttribute("DecorationAssetContractVersion",configSnapshot.Assets)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end
print(TAG.." PASS sources=7 anchors=3 categories=6 options=12 decorationsEnabled=true revision="..REVISION.." runId="..RUN_ID)
print(TAG.." READY: category/position/item UI, preview, purchase/place/remove persistence, and editable decoration templates installed.")
