-- Neo Tokyo Racers - Owned Garage Phase 11 canonical Lighting vertical slice
-- Run once in Roblox Studio Edit mode after confirmed Phase 10 Decorations.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 11 Lighting]"
local REVISION="NTR_OWNED_GARAGE_PHASE11_LIGHTING_V1_1_HIERARCHY_RECOVERY"
local BASE="NTR_OWNED_GARAGE_PHASE10_DECORATIONS_V1"
local V1="NTR_OWNED_GARAGE_PHASE11_LIGHTING_V1"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path) local object=root; for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end; return object end
local function replaceOnce(source,old,new,label) local a,b=string.find(source,old,1,true); assert(a,label.." anchor missing"); assert(not string.find(source,old,b+1,true),label.." anchor not unique"); return source:sub(1,a-1)..new..source:sub(b+1) end
local function compile(name,source) local fn,problem=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(problem)) end
local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage config missing")
local installed=config:GetAttribute("OwnedGarageRevision")
assert(installed==BASE or installed==V1 or installed==REVISION,"Confirmed Phase 10 or partial Phase 11 Lighting baseline is not current")
local data=assert(find(kit,"Shared.Modules.Data"),"Shared data missing")
local garage=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"Client UI missing")
local storageRoot=assert(find(ServerStorage,"NeoTokyoRacers.OwnedGarage"),"OwnedGarage storage root missing")
local template=assert(storageRoot:FindFirstChild("Templates") and storageRoot.Templates:FindFirstChild("StarterTwoBay"),"StarterTwoBay template missing")
local roof=assert(template:FindFirstChild("Roof"),"StarterTwoBay Roof missing"); assert(roof:IsA("BasePart"),"StarterTwoBay Roof must be a BasePart")
local propertyCatalog=assert(data:FindFirstChild("OwnedGaragePropertyCatalog"),"Property catalog missing")
local profile=assert(garage:FindFirstChild("OwnedGarageProfileRuntime"),"Profile runtime missing")
local assignment=assert(garage:FindFirstChild("OwnedGarageDisplayAssignmentRuntime"),"Assignment runtime missing")
local commands=assert(garage:FindFirstChild("OwnedGarageAuthoritativeCommandRuntime"),"Command runtime missing")
local management=assert(garage:FindFirstChild("OwnedGarageManagementRuntime"),"Management runtime missing")
local controller=assert(ui:FindFirstChild("OwnedGarageWorkspaceController"),"Workspace controller missing")

local lightingCatalogSource=[==[
-- NTR_OWNED_GARAGE_LIGHTING_CATALOG_V1
local Catalog={Version=1}
local presets={
	{PresetId="MIDNIGHT_CYAN",DisplayName="Midnight Cyan",AssetName="StandardFixture",Price=0,SortOrder=10,DefaultOwned=true,PrimaryColor={30,210,225},AccentColor={224,58,178},Brightness=1.8,Range=30},
	{PresetId="SHOWROOM_WHITE",DisplayName="Showroom White",AssetName="StandardFixture",Price=5000,SortOrder=20,PrimaryColor={235,242,255},AccentColor={100,190,255},Brightness=2.2,Range=32},
	{PresetId="SAKURA_NIGHT",DisplayName="Sakura Night",AssetName="StandardFixture",Price=7500,SortOrder=30,PrimaryColor={245,80,190},AccentColor={120,70,255},Brightness=2,Range=30},
	{PresetId="AMBER_LOUNGE",DisplayName="Amber Lounge",AssetName="StandardFixture",Price=9000,SortOrder=40,PrimaryColor={255,160,70},AccentColor={255,80,45},Brightness=1.65,Range=28},
}
local levels={{Id="LOW",DisplayName="Low",Value=.65,SortOrder=10},{Id="BALANCED",DisplayName="Balanced",Value=1,SortOrder=20},{Id="HIGH",DisplayName="High",Value=1.3,SortOrder=30}}
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
function Catalog.Presets() return clone(presets) end
function Catalog.ById(id) for _,item in ipairs(presets) do if item.PresetId==tostring(id or "") then return clone(item) end end end
function Catalog.Levels() return clone(levels) end
function Catalog.Level(value) value=tonumber(value) or 1; local best=levels[1]; for _,item in ipairs(levels) do if math.abs(item.Value-value)<math.abs(best.Value-value) then best=item end end; return clone(best) end
function Catalog.DecodeColor(value) return Color3.fromRGB(tonumber(value and value[1]) or 255,tonumber(value and value[2]) or 255,tonumber(value and value[3]) or 255) end
function Catalog.Normalize(value)
	value=type(value)=="table" and value or {}; value.OwnedPresets=type(value.OwnedPresets)=="table" and value.OwnedPresets or {}; for _,preset in ipairs(presets) do if preset.DefaultOwned then value.OwnedPresets[preset.PresetId]=true end end
	local selected=Catalog.ById(value.PresetId) or presets[1]; value.PresetId=selected.PresetId; value.Intensity=Catalog.Level(value.Intensity).Value; return value
end
function Catalog.Validate(value) value=Catalog.Normalize(value); if not (Catalog.ById(value.PresetId) and value.OwnedPresets[value.PresetId]) then return false,"Invalid or unowned lighting preset." end; return true end
function Catalog.ClientState(value) value=Catalog.Normalize(clone(value)); return {Version=Catalog.Version,Presets=Catalog.Presets(),Levels=Catalog.Levels(),OwnedPresets=clone(value.OwnedPresets),PresetId=value.PresetId,Intensity=value.Intensity} end
return Catalog
]==]
compile("OwnedGarageLightingCatalog",lightingCatalogSource)

local projected={}; local expectedMarkers={}
local function project(object,marker,transform) local source=object.Source; if not source:find(marker,1,true) then source=transform(source) end; assert(source:find(marker,1,true),object.Name.." marker missing"); compile(object.Name,source); projected[object]=source; expectedMarkers[object]=marker end

project(propertyCatalog,"NTR_OWNED_GARAGE_PROPERTY_CATALOG_V6_LIGHTING_SLOTS",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V5_DECORATION_ANCHORS","-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V5_DECORATION_ANCHORS\n-- NTR_OWNED_GARAGE_PROPERTY_CATALOG_V6_LIGHTING_SLOTS","property marker")
	source=replaceOnce(source,"local Catalog={DefinitionVersion=2,StateApiVersion=2}","local Catalog={DefinitionVersion=3,StateApiVersion=3}","lighting API version")
	source=replaceOnce(source,'DecorationAnchorIds={"DecorationAnchor1","DecorationAnchor2","DecorationAnchor3"},','DecorationAnchorIds={"DecorationAnchor1","DecorationAnchor2","DecorationAnchor3"},\n\t\tLightingSlotIds={"Light01","Light02","Light03","Light04"},',"lighting slot definition")
	source=replaceOnce(source,'nonEmptyUnique(definition.SurfaceGroups,id.." SurfaceGroups")','nonEmptyUnique(definition.SurfaceGroups,id.." SurfaceGroups")\n\tnonEmptyUnique(definition.LightingSlotIds,id.." LightingSlotIds")',"lighting slot validation")
	return replaceOnce(source,'DecorationAnchorIds=clone(property.DecorationAnchorIds),Capabilities=','DecorationAnchorIds=clone(property.DecorationAnchorIds),LightingSlotIds=clone(property.LightingSlotIds),Capabilities=',"lighting client definition")
end)

project(profile,"NTR_OWNED_GARAGE_LIGHTING_PROFILE_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_DECORATION_PROFILE_V1","-- NTR_OWNED_GARAGE_DECORATION_PROFILE_V1\n-- NTR_OWNED_GARAGE_LIGHTING_PROFILE_V1","profile marker")
	source=replaceOnce(source,'local Runtime={SchemaVersion=2}','local LightingCatalogCache\nlocal function LightingCatalog()\n\tif not LightingCatalogCache then local source=script:FindFirstChild("OwnedGarageLightingCatalog") or ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Data:WaitForChild("OwnedGarageLightingCatalog"); LightingCatalogCache=require(source) end\n\treturn LightingCatalogCache\nend\nlocal Runtime={SchemaVersion=2}',"lighting catalog resolver")
	source=replaceOnce(source,'property.Customisation.Decorations=DecorationCatalog().Normalize(property.Customisation.Decorations,definition.DecorationAnchorIds); property.Customisation.Structure=','property.Customisation.Decorations=DecorationCatalog().Normalize(property.Customisation.Decorations,definition.DecorationAnchorIds); property.Customisation.Lighting=LightingCatalog().Normalize(property.Customisation.Lighting); property.Customisation.Structure=',"lighting normalize")
	source=replaceOnce(source,'local definition=Catalog().ById(garageId); local decorationValid','local definition=Catalog().ById(garageId); local lightingValid,lightingMessage=LightingCatalog().Validate(property.Customisation.Lighting); if not lightingValid then return false,lightingMessage end; local decorationValid',"lighting validation")
	local addition=[==[
function Runtime.ConfigureLighting(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local property=garage.Properties[garageId]; local action=tostring(args.Action or "")
	if not (property and property.Owned) then return false,"Garage is not owned." end; local lighting=LightingCatalog().Normalize(property.Customisation.Lighting); property.Customisation.Lighting=lighting
	if action=="Purchase" then local preset=LightingCatalog().ById(args.PresetId); if not preset then return false,"Lighting preset is invalid." end; if lighting.OwnedPresets[preset.PresetId] then return false,"Lighting preset is already owned." end; local cost=math.max(0,math.floor(tonumber(preset.Price) or 0)); if (tonumber(profile.Cash) or 0)<cost then return false,"Not enough cash." end; profile.Cash=(tonumber(profile.Cash) or 0)-cost; lighting.OwnedPresets[preset.PresetId]=true; lighting.PresetId=preset.PresetId
	elseif action=="Equip" then local preset=LightingCatalog().ById(args.PresetId); if not (preset and lighting.OwnedPresets[preset.PresetId]) then return false,"Purchase this lighting preset first." end; lighting.PresetId=preset.PresetId
	elseif action=="SetIntensity" then lighting.Intensity=LightingCatalog().Level(args.Intensity).Value
	else return false,"Unknown lighting action." end
	garage.Revision+=1; return true,"Garage lighting updated."
end
]==]
	return replaceOnce(source,"function Runtime.NewRequestId()",addition.."function Runtime.NewRequestId()","lighting command")
end)

project(assignment,"NTR_OWNED_GARAGE_LIGHTING_TRANSACTION_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_DECORATION_TRANSACTION_V1","-- NTR_OWNED_GARAGE_DECORATION_TRANSACTION_V1\n-- NTR_OWNED_GARAGE_LIGHTING_TRANSACTION_V1","assignment marker")
	source=replaceOnce(source,'tostring(args.ItemId or "")','tostring(args.ItemId or ""),tostring(args.PresetId or ""),tostring(args.Intensity or "")',"lighting fingerprint")
	return replaceOnce(source,'elseif operation=="ConfigureDecoration" then success,message=Profile.ConfigureDecoration(profile,args)','elseif operation=="ConfigureDecoration" then success,message=Profile.ConfigureDecoration(profile,args)\n\t\telseif operation=="ConfigureLighting" then success,message=Profile.ConfigureLighting(profile,args)',"lighting transaction route")
end)

project(commands,"NTR_OWNED_GARAGE_LIGHTING_COMMAND_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_DECORATION_COMMAND_V1","-- NTR_OWNED_GARAGE_DECORATION_COMMAND_V1\n-- NTR_OWNED_GARAGE_LIGHTING_COMMAND_V1","command marker")
	return replaceOnce(source,"ConfigureDecoration=true}","ConfigureDecoration=true,ConfigureLighting=true}","lighting allowlist")
end)

project(management,"NTR_OWNED_GARAGE_LIGHTING_MANAGEMENT_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_DECORATION_MANAGEMENT_V1","-- NTR_OWNED_GARAGE_DECORATION_MANAGEMENT_V1\n-- NTR_OWNED_GARAGE_LIGHTING_MANAGEMENT_V1","management marker")
	source=replaceOnce(source,'local decorationCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageDecorationCatalog"))','local decorationCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageDecorationCatalog")); local lightingCatalog=require(kit.Shared.Modules.Data:WaitForChild("OwnedGarageLightingCatalog"))',"lighting catalog require")
	local block=[==[
	local function applyLighting(profile,session)
		local property=profile.OwnedGarage.Properties[session.PropertyId]; local definition=catalog.ById(session.PropertyId); local lighting=lightingCatalog.Normalize(property and property.Customisation and property.Customisation.Lighting); if session.LightingPreview then lighting=session.LightingPreview end; local preset=lightingCatalog.ById(lighting.PresetId); local slots=session.Interior:FindFirstChild("LightingSlots"); if not (preset and slots) then return false,"Garage lighting contract is missing." end
		local assets=ServerStorage:FindFirstChild("NeoTokyoRacers"); assets=assets and assets:FindFirstChild("OwnedGarage"); assets=assets and assets:FindFirstChild("LightingAssets"); assets=assets and assets:FindFirstChild(tostring(definition and definition.TemplateId or "")); local asset=assets and assets:FindFirstChild(preset.AssetName); if not (asset and asset:IsA("Model")) then return false,"Garage lighting asset is missing." end
		local runtime=session.Interior:FindFirstChild("LightingRuntime"); if not runtime then runtime=Instance.new("Folder"); runtime.Name="LightingRuntime"; runtime.Parent=session.Interior end; runtime:ClearAllChildren(); local primary=lightingCatalog.DecodeColor(preset.PrimaryColor); local accent=lightingCatalog.DecodeColor(preset.AccentColor)
		for _,slotId in ipairs(definition and definition.LightingSlotIds or {}) do local slot=slots:FindFirstChild(slotId); if not (slot and slot:IsA("BasePart")) then return false,"Garage lighting slot missing: "..tostring(slotId) end; local clone=asset:Clone(); clone.Name=slotId; for _,object in ipairs(clone:GetDescendants()) do if object:IsA("LuaSourceContainer") or object:IsA("ProximityPrompt") or object:IsA("Seat") or object:IsA("VehicleSeat") then object:Destroy() elseif object:IsA("BasePart") then local localCFrame=object.CFrame; object.CFrame=slot.CFrame*localCFrame; object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false; object.CastShadow=false; local channel=tostring(object:GetAttribute("LightingChannel") or "Primary"); object.Color=channel=="Accent" and accent or primary elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then object.Color=primary; object.Brightness=math.max(0,tonumber(preset.Brightness) or 1)*math.clamp(tonumber(lighting.Intensity) or 1,.5,1.5); object.Range=math.min(36,math.max(8,tonumber(preset.Range) or 28)); object.Shadows=false; object.Enabled=true end end; clone:SetAttribute("LightingPresetId",preset.PresetId); clone:SetAttribute("LightingPreview",session.LightingPreview~=nil); clone.Parent=runtime end
		return true
	end
]==]
	source=replaceOnce(source,"\tlocal function renderDisplays(player,profile,session)",block.."\tlocal function renderDisplays(player,profile,session)","lighting renderer")
	source=replaceOnce(source,'local decorated,decorationMessage=applyDecorations(profile,session); if not decorated then sessions[player]=nil; scheduleUnload(interior,player); return nil,decorationMessage end; local configured','local decorated,decorationMessage=applyDecorations(profile,session); if not decorated then sessions[player]=nil; scheduleUnload(interior,player); return nil,decorationMessage end; local lit,lightingMessage=applyLighting(profile,session); if not lit then sessions[player]=nil; scheduleUnload(interior,player); return nil,lightingMessage end; local configured',"session lighting presentation")
	source=replaceOnce(source,'operation=="ConfigureDecoration" and "Decorations" or (operation=="SetAccessMode"','operation=="ConfigureDecoration" and "Decorations" or (operation=="ConfigureLighting" and "Lighting" or (operation=="SetAccessMode"',"lighting capability open")
	source=replaceOnce(source,'and "Access")))','and "Access"))))',"lighting capability close")
	source=replaceOnce(source,'elseif operation=="ConfigureDecoration" then applyDecorations(committed,session) end; return result end','elseif operation=="ConfigureDecoration" then applyDecorations(committed,session) elseif operation=="ConfigureLighting" then applyLighting(committed,session) end; return result end',"lighting failure presentation")
	source=replaceOnce(source,'elseif operation=="ConfigureDecoration" then session.DecorationPreview=nil; presented=applyDecorations(committed,session) end;','elseif operation=="ConfigureDecoration" then session.DecorationPreview=nil; presented=applyDecorations(committed,session) elseif operation=="ConfigureLighting" then session.LightingPreview=nil; presented=applyLighting(committed,session) end;',"lighting success presentation")
	source=replaceOnce(source,'Decorations=currentProperty and decorationCatalog.ClientState(currentProperty.Customisation.Decorations,(catalog.ById(session.PropertyId) or {}).DecorationAnchorIds or {}) or nil,Structure=','Decorations=currentProperty and decorationCatalog.ClientState(currentProperty.Customisation.Decorations,(catalog.ById(session.PropertyId) or {}).DecorationAnchorIds or {}) or nil,Lighting=currentProperty and lightingCatalog.ClientState(currentProperty.Customisation.Lighting) or nil,Structure=',"lighting state")
	source=replaceOnce(source,'or action=="CancelDecorationPreview"','or action=="CancelDecorationPreview" or action=="PreviewLighting" or action=="CancelLightingPreview"',"lighting controls")
	source=replaceOnce(source,'\t\t\telseif action=="EnterSelectedGarage" then','\t\t\telseif action=="PreviewLighting" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; local property=profile.OwnedGarage.Properties[session.PropertyId]; local lighting=lightingCatalog.Normalize(property.Customisation.Lighting); local preset=lightingCatalog.ById(args.PresetId or lighting.PresetId); if not preset then return {Success=false,Message="Lighting preview is invalid."} end; session.LightingPreview={PresetId=preset.PresetId,OwnedPresets=lighting.OwnedPresets,Intensity=lightingCatalog.Level(args.Intensity or lighting.Intensity).Value}; local rendered,message=applyLighting(profile,session); return {Success=rendered==true,Message=message or "Lighting preview ready."}\n\t\t\telseif action=="CancelLightingPreview" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; session.LightingPreview=nil; local rendered,message=applyLighting(profile,session); return {Success=rendered==true,Message=message or "Lighting preview cleared."}\n\t\t\telseif action=="EnterSelectedGarage" then',"lighting preview routes")
	return replaceOnce(source,'\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end','\t\t\telseif action=="ConfigureLighting" then return managedOperation(player,profile,"ConfigureLighting",{Action=tostring(args.Action or ""),PresetId=tostring(args.PresetId or ""),Intensity=args.Intensity,RequestId=args.RequestId,BaseRevision=args.BaseRevision})\n\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end',"lighting mutation route")
end)

project(controller,"NTR_OWNED_GARAGE_LIGHTING_UI_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_DECORATION_UI_V1","-- NTR_OWNED_GARAGE_DECORATION_UI_V1\n-- NTR_OWNED_GARAGE_LIGHTING_UI_V1","UI marker")
	source=replaceOnce(source,'local selectedDecorationCategory; local selectedDecorationAnchor; local selectedDecorationItem','local selectedDecorationCategory; local selectedDecorationAnchor; local selectedDecorationItem; local selectedLightingPreset; local selectedLightingIntensity',"lighting UI state")
	source=replaceOnce(source,'request("CancelDecorationPreview",{}) end) end end','request("CancelDecorationPreview",{}); request("CancelLightingPreview",{}) end) end end',"cancel lighting preview")
	source=replaceOnce(source,'request("CancelDecorationPreview",{}); request("SetManagementOpen"','request("CancelDecorationPreview",{}); request("CancelLightingPreview",{}); request("SetManagementOpen"',"close lighting preview")
	source=replaceOnce(source,'or page==item.Id; table.insert(result','or (item.Id=="Lighting" and string.sub(page,1,8)=="Lighting") or page==item.Id; table.insert(result',"lighting tab state")
	local branch=[==[
		elseif string.sub(page,1,8)=="Lighting" then
			local lighting=state.Lighting or {}; local function presetById(id) for _,item in ipairs(lighting.Presets or {}) do if item.PresetId==id then return item end end end
			if page=="Lighting" then cards={{Id="Presets",DisplayName="Presets",Footer="ROOM COLOUR / MOOD",OnSelect=function() selectedLightingPreset=nil; page="LightingPresets"; render(true) end},{Id="Intensity",DisplayName="Intensity",Footer="LOW / BALANCED / HIGH",OnSelect=function() selectedLightingIntensity=nil; page="LightingIntensity"; render(true) end}}; view=context("Choose a room-lighting control.",cards)
			elseif page=="LightingPresets" then for _,item in ipairs(lighting.Presets or {}) do local preset=item; local owned=lighting.OwnedPresets and lighting.OwnedPresets[preset.PresetId]; local current=lighting.PresetId==preset.PresetId; table.insert(cards,{Id=preset.PresetId,CardKind="Listing",VehicleName="ROOM LIGHTING",DisplayName=preset.DisplayName,Price=owned and nil or preset.Price,Footer=current and "CURRENT" or (owned and "OWNED" or "LOCKED"),SemanticState=current and "Equipped" or (owned and "Available" or "Locked"),Selected=preset.PresetId==selectedLightingPreset,OnSelect=function() selectedLightingPreset=preset.PresetId; request("PreviewLighting",{PresetId=preset.PresetId}); render(false) end}) end; view=context("Choose a room-lighting preset.",cards); local chosen=presetById(selectedLightingPreset); if chosen then local owned=lighting.OwnedPresets and lighting.OwnedPresets[chosen.PresetId]; local current=lighting.PresetId==chosen.PresetId; view.SelectedAction={RowId=chosen.PresetId,Text=current and "CURRENT" or (owned and "APPLY" or "BUY"),OnActivate=function() if current then return elseif owned then operate("ConfigureLighting",{Action="Equip",PresetId=chosen.PresetId},"Lighting",nil,nil,"LIGHTING APPLIED") else operate("ConfigureLighting",{Action="Purchase",PresetId=chosen.PresetId},"Lighting",nil,nil,"LIGHTING PURCHASED") end end} end
			elseif page=="LightingIntensity" then local currentLevel; for _,level in ipairs(lighting.Levels or {}) do if math.abs((tonumber(level.Value) or 1)-(tonumber(lighting.Intensity) or 1))<.01 then currentLevel=level.Id end end; for _,item in ipairs(lighting.Levels or {}) do local level=item; local current=level.Id==currentLevel; table.insert(cards,{Id=level.Id,CardKind="Listing",VehicleName="ROOM LIGHTING",DisplayName=level.DisplayName,Footer=current and "CURRENT" or "INTENSITY",SemanticState=current and "Equipped" or "Available",Selected=selectedLightingIntensity==level.Value or (selectedLightingIntensity==nil and current),OnSelect=function() selectedLightingIntensity=level.Value; request("PreviewLighting",{Intensity=level.Value}); render(false) end}) end; view=context("Choose garage light intensity.",cards); if selectedLightingIntensity and math.abs(selectedLightingIntensity-(tonumber(lighting.Intensity) or 1))>=.01 then local choice=selectedLightingIntensity; local choiceId=""; for _,level in ipairs(lighting.Levels or {}) do if level.Value==choice then choiceId=level.Id end end; view.SelectedAction={RowId=choiceId,Text="SAVE",OnActivate=function() operate("ConfigureLighting",{Action="SetIntensity",Intensity=choice},"Lighting",nil,nil,"LIGHTING INTENSITY SAVED") end} end
			end
			view.BackVisible=true; view.BackText="BACK"; view.OnBack=function() request("CancelLightingPreview",{}); selectedLightingPreset=nil; selectedLightingIntensity=nil; if page=="Lighting" then page="DisplaySpaces" else page="Lighting" end; render(true) end
]==]
	return replaceOnce(source,"\t\telse\n\t\t\tview=context(page..\" is definition-ready and activates in its dedicated implementation phase.\",{})",branch.."\t\telse\n\t\t\tview=context(page..\" is definition-ready and activates in its dedicated implementation phase.\",{})","lighting pages")
end)

local sourceSnapshots={}; for object in pairs(projected) do sourceSnapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")} end
local created={}; local slotSnapshots={}; local configSnapshot={Revision=config:GetAttribute("OwnedGarageRevision"),RunId=config:GetAttribute("OwnedGarageInstallRunId"),Enabled=config:GetAttribute("EnableLighting"),Contract=config:GetAttribute("LightingContractVersion"),Assets=config:GetAttribute("LightingAssetContractVersion")}
local function create(className,name,parent) local object=Instance.new(className); object.Name=name; object.Parent=parent; table.insert(created,object); return object end
local function folder(parent,name) local object=parent:FindFirstChild(name); if object then assert(object:IsA("Folder"),object:GetFullName().." must be a Folder"); return object end; return create("Folder",name,parent) end
local ok,problem=pcall(function()
	local lightingCatalog=data:FindFirstChild("OwnedGarageLightingCatalog"); if not lightingCatalog then lightingCatalog=create("ModuleScript","OwnedGarageLightingCatalog",data) else assert(lightingCatalog:IsA("ModuleScript"),"OwnedGarageLightingCatalog must be a ModuleScript") end; sourceSnapshots[lightingCatalog]=sourceSnapshots[lightingCatalog] or {Source=lightingCatalog.Source,Revision=lightingCatalog:GetAttribute("OwnedGarageRevision"),RunId=lightingCatalog:GetAttribute("OwnedGarageInstallRunId")}; lightingCatalog.Source=lightingCatalogSource; lightingCatalog:SetAttribute("OwnedGarageRevision",REVISION); lightingCatalog:SetAttribute("OwnedGarageInstallRunId",RUN_ID)
	for object,source in pairs(projected) do object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	local slots=folder(template,"LightingSlots"); local x=math.max(8,roof.Size.X*.23); local z=math.max(8,roof.Size.Z*.22); local offsets={Vector3.new(-x,-roof.Size.Y*.5-.45,-z),Vector3.new(x,-roof.Size.Y*.5-.45,-z),Vector3.new(-x,-roof.Size.Y*.5-.45,z),Vector3.new(x,-roof.Size.Y*.5-.45,z)}
	for index,offset in ipairs(offsets) do local id=string.format("Light%02d",index); local slot=slots:FindFirstChild(id); if not slot then slot=create("Part",id,slots); slot.Size=Vector3.new(1,1,1); slot.CFrame=roof.CFrame*CFrame.new(offset); slot.Anchored=true; slot.CanCollide=false; slot.CanTouch=false; slot.CanQuery=false; slot.CastShadow=false; slot.Transparency=1 else slotSnapshots[slot]={Id=slot:GetAttribute("LightingSlotId"),Version=slot:GetAttribute("LightingSlotContractVersion")} end; assert(slot:IsA("BasePart"),id.." must be a BasePart"); slot:SetAttribute("LightingSlotId",id); slot:SetAttribute("LightingSlotContractVersion",1) end
	local assetsRoot=folder(storageRoot,"LightingAssets"); local templateAssets=folder(assetsRoot,"StarterTwoBay"); local fixture=templateAssets:FindFirstChild("StandardFixture"); if not fixture then fixture=create("Model","StandardFixture",templateAssets); fixture:SetAttribute("LightingAssetContractVersion",1); fixture:SetAttribute("PlaceholderTemplate",true); local housing=create("Part","Housing",fixture); housing.Size=Vector3.new(4,.35,1.4); housing.CFrame=CFrame.new(); housing.Color=Color3.fromRGB(35,42,55); housing.Material=Enum.Material.Metal; housing.Anchored=true; housing.CanCollide=false; housing.CanTouch=false; housing.CanQuery=false; housing.CastShadow=false; housing:SetAttribute("LightingChannel","Primary"); local emitter=create("Part","Emitter",fixture); emitter.Size=Vector3.new(3.4,.12,1); emitter.CFrame=CFrame.new(0,-.24,0); emitter.Color=Color3.fromRGB(30,210,225); emitter.Material=Enum.Material.Neon; emitter.Anchored=true; emitter.CanCollide=false; emitter.CanTouch=false; emitter.CanQuery=false; emitter.CastShadow=false; emitter:SetAttribute("LightingChannel","Accent"); local light=create("PointLight","RoomLight",emitter); light.Brightness=1.8; light.Range=30; light.Shadows=false; light.Enabled=true; fixture.PrimaryPart=housing end; assert(fixture:IsA("Model") and fixture:FindFirstChild("Emitter"),"StandardFixture asset invalid")
	config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID); config:SetAttribute("EnableLighting",true); config:SetAttribute("LightingContractVersion",1); config:SetAttribute("LightingAssetContractVersion",1)
	task.wait()
	assert(data:FindFirstChild("OwnedGarageLightingCatalog")==lightingCatalog and lightingCatalog.Parent==data,"Lighting catalogue hierarchy did not persist inside the installer transaction")
	assert(lightingCatalog.Source:find("NTR_OWNED_GARAGE_LIGHTING_CATALOG_V1",1,true),"Lighting catalogue marker missing"); for object,marker in pairs(expectedMarkers) do assert(object.Source:find(marker,1,true),"Exact lighting marker missing: "..object.Name.." / "..marker) end; for index=1,4 do assert(slots:FindFirstChild(string.format("Light%02d",index)),"Lighting slot audit failed") end
end)
if not ok then
	for object,snapshot in pairs(sourceSnapshots) do if object.Parent then object.Source=snapshot.Source; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	for slot,snapshot in pairs(slotSnapshots) do if slot.Parent then slot:SetAttribute("LightingSlotId",snapshot.Id); slot:SetAttribute("LightingSlotContractVersion",snapshot.Version) end end
	for index=#created,1,-1 do local object=created[index]; if object and object.Parent then object:Destroy() end end
	config:SetAttribute("OwnedGarageRevision",configSnapshot.Revision); config:SetAttribute("OwnedGarageInstallRunId",configSnapshot.RunId); config:SetAttribute("EnableLighting",configSnapshot.Enabled); config:SetAttribute("LightingContractVersion",configSnapshot.Contract); config:SetAttribute("LightingAssetContractVersion",configSnapshot.Assets)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end
print(TAG.." PASS sources=7 slots=4 fixtures=1 presets=4 levels=3 catalogueParentVerified=true lightingEnabled=true revision="..REVISION.." runId="..RUN_ID)
print(TAG.." READY: garage-local preset/intensity preview and authoritative persistence installed; world lighting untouched.")
