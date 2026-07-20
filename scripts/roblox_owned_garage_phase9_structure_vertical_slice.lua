-- Neo Tokyo Racers - Owned Garage Phase 9 canonical Structure vertical slice
-- Run once in Roblox Studio Edit mode after confirmed Phase 8 transition completion.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Studio Edit mode.")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerScriptService=game:GetService("ServerScriptService")
local ServerStorage=game:GetService("ServerStorage")
local StarterPlayer=game:GetService("StarterPlayer")
local TAG="[NTR Owned Garage Phase 9 Structure]"
local REVISION="NTR_OWNED_GARAGE_PHASE9_STRUCTURE_V1_1_ASSET_TEMPLATES"
local BASE="NTR_OWNED_GARAGE_PHASE8_TRANSITION_COMPLETION_V1"
local V1="NTR_OWNED_GARAGE_PHASE9_STRUCTURE_V1"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path) local object=root; for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end; return object end
local function replaceOnce(source,old,new,label) local a,b=string.find(source,old,1,true); assert(a,label.." anchor missing"); assert(not string.find(source,old,b+1,true),label.." anchor not unique"); return source:sub(1,a-1)..new..source:sub(b+1) end
local function replaceFirst(source,old,new,label) local a,b=string.find(source,old,1,true); assert(a,label.." anchor missing"); return source:sub(1,a-1)..new..source:sub(b+1) end
local function compile(name,source) local fn,problem=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(problem)) end
local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage config missing")
local installed=config:GetAttribute("OwnedGarageRevision")
assert(installed==BASE or installed==V1 or installed==REVISION,"Confirmed Phase 8/9 Structure baseline is not current")
local data=assert(find(kit,"Shared.Modules.Data"),"Shared data missing")
local garage=assert(find(ServerScriptService,"NeoTokyoRacers.Services.Garage"),"Garage services missing")
local ui=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"Client UI missing")
local template=assert(find(ServerStorage,"NeoTokyoRacers.OwnedGarage.Templates.StarterTwoBay"),"StarterTwoBay template missing")
local catalog=assert(data:FindFirstChild("OwnedGarageInteriorStyleCatalog"),"Style catalog missing")
local profile=assert(garage:FindFirstChild("OwnedGarageProfileRuntime"),"Profile runtime missing")
local assignment=assert(garage:FindFirstChild("OwnedGarageDisplayAssignmentRuntime"),"Assignment runtime missing")
local commands=assert(garage:FindFirstChild("OwnedGarageAuthoritativeCommandRuntime"),"Command runtime missing")
local management=assert(garage:FindFirstChild("OwnedGarageManagementRuntime"),"Management runtime missing")
local controller=assert(ui:FindFirstChild("OwnedGarageWorkspaceController"),"Workspace controller missing")

local catalogSource=[==[
-- NTR_OWNED_GARAGE_INTERIOR_STYLE_CATALOG_V1
-- NTR_OWNED_GARAGE_STRUCTURE_CATALOG_V2
-- NTR_OWNED_GARAGE_STRUCTURE_ASSET_CATALOG_V1
local Catalog={Version=2,Channels={"Primary","Secondary","Detail"}}
local sections={{Id="FrontWall",Name="Front Wall",Order=10},{Id="LeftWall",Name="Left Wall",Order=20},{Id="RightWall",Name="Right Wall",Order=30},{Id="BackWall",Name="Back Wall",Order=40},{Id="Floor",Name="Floor",Order=50},{Id="Ceiling",Name="Ceiling",Order=60}}
local presets={
	{Name="Midnight",Price=0,Material="Metal",Colors={Primary={18,23,31},Secondary={38,45,58},Detail={26,210,220}}},
	{Name="Graphite",Price=6000,Material="Metal",Colors={Primary={48,54,64},Secondary={75,81,92},Detail={224,58,178}}},
	{Name="Urban Concrete",Price=9000,Material="Concrete",Colors={Primary={76,79,84},Secondary={112,115,120},Detail={255,156,54}}},
	{Name="Studio White",Price=12000,Material="SmoothPlastic",Colors={Primary={170,176,184},Secondary={105,112,123},Detail={50,190,255}}},
}
local allowed={Metal=true,Concrete=true,SmoothPlastic=true,DiamondPlate=true,WoodPlanks=true,Marble=true}
local function clone(v) if type(v)~="table" then return v end; local c={}; for k,x in pairs(v) do c[k]=clone(x) end; return c end
local function styleId(section,index) return string.upper(section).."_OPTION_"..index end
function Catalog.Sections() return clone(sections) end
function Catalog.Materials() local r={}; for id in pairs(allowed) do table.insert(r,id) end; table.sort(r); return r end
function Catalog.Styles(section) local r={}; for index,p in ipairs(presets) do table.insert(r,{SectionId=section,StyleId=styleId(section,index),AssetOption=string.format("Option%02d",index),DisplayName=p.Name,Price=p.Price,SortOrder=index,Default=index==1,Colors=clone(p.Colors),Materials={Primary=p.Material,Secondary=p.Material,Detail="Metal"}}) end; return r end
function Catalog.ById(section,id) for _,item in ipairs(Catalog.Styles(section)) do if item.StyleId==tostring(id or "") then return item end end end
function Catalog.EncodeColor(value) if typeof(value)=="Color3" then return {math.floor(value.R*255+.5),math.floor(value.G*255+.5),math.floor(value.B*255+.5)} end; if type(value)=="table" then return {math.clamp(tonumber(value[1] or value.R) or 255,0,255),math.clamp(tonumber(value[2] or value.G) or 255,0,255),math.clamp(tonumber(value[3] or value.B) or 255,0,255)} end; return {255,255,255} end
function Catalog.DecodeColor(value) local c=Catalog.EncodeColor(value); return Color3.fromRGB(c[1],c[2],c[3]) end
function Catalog.NormalizeStructure(value,sectionIds)
	value=type(value)=="table" and value or {}; value.Sections=type(value.Sections)=="table" and value.Sections or {}; value.OwnedStyles=type(value.OwnedStyles)=="table" and value.OwnedStyles or {}
	for _,section in ipairs(sectionIds or {}) do local first=Catalog.Styles(section)[1]; value.OwnedStyles[first.StyleId]=true; local item=type(value.Sections[section])=="table" and value.Sections[section] or {}; local selected=Catalog.ById(section,item.StyleId) or first; item.StyleId=selected.StyleId; item.Colors=type(item.Colors)=="table" and item.Colors or {}; item.Materials=type(item.Materials)=="table" and item.Materials or {}; for _,channel in ipairs(Catalog.Channels) do item.Colors[channel]=Catalog.EncodeColor(item.Colors[channel] or selected.Colors[channel]); local material=tostring(item.Materials[channel] or selected.Materials[channel]); item.Materials[channel]=allowed[material] and material or selected.Materials[channel] end; value.Sections[section]=item end
	return value
end
function Catalog.ValidateStructure(value,sectionIds) value=Catalog.NormalizeStructure(value,sectionIds); for _,section in ipairs(sectionIds or {}) do local item=value.Sections[section]; if not (Catalog.ById(section,item.StyleId) and value.OwnedStyles[item.StyleId]) then return false,"Invalid or unowned structure style." end; for _,channel in ipairs(Catalog.Channels) do if not allowed[item.Materials[channel]] then return false,"Invalid structure material." end end end; return true end
function Catalog.ClientState(value,sectionIds) value=Catalog.NormalizeStructure(clone(value),sectionIds); local result={Sections=Catalog.Sections(),Styles={},Selected=value.Sections,OwnedStyles=clone(value.OwnedStyles),Materials=Catalog.Materials(),Channels=clone(Catalog.Channels)}; for _,section in ipairs(sectionIds or {}) do result.Styles[section]=Catalog.Styles(section); for _,channel in ipairs(Catalog.Channels) do result.Selected[section].Colors[channel]=Catalog.DecodeColor(result.Selected[section].Colors[channel]) end end; return result end
-- Legacy staged API remains readable until all historical callers retire.
function Catalog.List() local r={}; for _,section in ipairs(sections) do for _,item in ipairs(Catalog.Styles(section.Id)) do table.insert(r,item) end end; return r end
function Catalog.DefaultStyles() return {} end
function Catalog.IsValid() return false end
function Catalog.ByIdLegacy() return nil end
return Catalog
]==]
compile(catalog.Name,catalogSource)

local projected={[catalog]=catalogSource}
local function project(object,marker,transform) local source=object.Source; if not source:find(marker,1,true) then source=transform(source) end; assert(source:find(marker,1,true),object.Name.." marker missing"); compile(object.Name,source); projected[object]=source end

project(profile,"NTR_OWNED_GARAGE_STRUCTURE_PROFILE_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V2_NAMESPACED","-- NTR_OWNED_GARAGE_PROFILE_RUNTIME_V2_NAMESPACED\n-- NTR_OWNED_GARAGE_STRUCTURE_PROFILE_V1","profile marker")
	source=replaceOnce(source,'property.Customisation.SurfaceStyles=type(property.Customisation.SurfaceStyles)=="table" and property.Customisation.SurfaceStyles or {}; property.Customisation.Decorations=type(property.Customisation.Decorations)=="table" and property.Customisation.Decorations or {}; for surfaceGroup,styleId in pairs(StyleCatalog().DefaultStyles()) do if not StyleCatalog().IsValid(surfaceGroup,property.Customisation.SurfaceStyles[surfaceGroup]) then property.Customisation.SurfaceStyles[surfaceGroup]=styleId end end','property.Customisation.SurfaceStyles=type(property.Customisation.SurfaceStyles)=="table" and property.Customisation.SurfaceStyles or {}; property.Customisation.Decorations=type(property.Customisation.Decorations)=="table" and property.Customisation.Decorations or {}; property.Customisation.Structure=StyleCatalog().NormalizeStructure(property.Customisation.Structure,definition.StructureSections)',"structure normalize")
	source=replaceOnce(source,'\t\t\tfor surfaceGroup,styleId in pairs(property.Customisation.SurfaceStyles or {}) do if not StyleCatalog().IsValid(surfaceGroup,styleId) then return false,"Invalid interior style: "..tostring(surfaceGroup).."/"..tostring(styleId) end end','\t\t\tlocal definition=Catalog().ById(garageId); local structureValid,structureMessage=StyleCatalog().ValidateStructure(property.Customisation.Structure,definition and definition.StructureSections or {}); if not structureValid then return false,structureMessage end',"structure validation")
	local addition=[==[
function Runtime.ConfigureStructure(profile,args)
	args=type(args)=="table" and args or {}; local garage=Runtime.Ensure(profile,false); local garageId=tostring(args.GarageId or garage.ActiveGarageId or ""); local property=garage.Properties[garageId]; local definition=Catalog().ById(garageId); local section=tostring(args.SectionId or ""); local action=tostring(args.Action or "")
	if not (property and property.Owned and definition) then return false,"Garage is not owned." end; local validSection=false; for _,id in ipairs(definition.StructureSections or {}) do if id==section then validSection=true end end; if not validSection then return false,"Structure section is invalid." end
	local structure=StyleCatalog().NormalizeStructure(property.Customisation.Structure,definition.StructureSections); property.Customisation.Structure=structure; local item=structure.Sections[section]
	if action=="Purchase" then local style=StyleCatalog().ById(section,args.StyleId); if not style then return false,"Structure style is invalid." end; if structure.OwnedStyles[style.StyleId] then return false,"Structure style is already owned." end; local cost=math.max(0,math.floor(tonumber(style.Price) or 0)); if (tonumber(profile.Cash) or 0)<cost then return false,"Not enough cash." end; profile.Cash=(tonumber(profile.Cash) or 0)-cost; structure.OwnedStyles[style.StyleId]=true; item.StyleId=style.StyleId; item.Colors=clone(style.Colors); item.Materials=clone(style.Materials)
	elseif action=="Equip" then local style=StyleCatalog().ById(section,args.StyleId); if not (style and structure.OwnedStyles[style.StyleId]) then return false,"Purchase this structure style first." end; item.StyleId=style.StyleId
	elseif action=="SetColour" then local channel=tostring(args.Channel or ""); if channel~="Primary" and channel~="Secondary" and channel~="Detail" then return false,"Colour channel is invalid." end; item.Colors[channel]=StyleCatalog().EncodeColor(args.Color)
	elseif action=="SetMaterial" then local channel=tostring(args.Channel or ""); local material=tostring(args.Material or ""); local allowed=false; for _,id in ipairs(StyleCatalog().Materials()) do if id==material then allowed=true end end; if (channel~="Primary" and channel~="Secondary" and channel~="Detail") or not allowed then return false,"Material selection is invalid." end; item.Materials[channel]=material
	else return false,"Unknown structure action." end
	garage.Revision+=1; return true,"Structure updated."
end
]==]
	return replaceOnce(source,"function Runtime.NewRequestId()",addition.."function Runtime.NewRequestId()","structure command")
end)

project(assignment,"NTR_OWNED_GARAGE_STRUCTURE_TRANSACTION_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V2_REVISIONED","-- NTR_OWNED_GARAGE_DISPLAY_ASSIGNMENT_RUNTIME_V2_REVISIONED\n-- NTR_OWNED_GARAGE_STRUCTURE_TRANSACTION_V1","assignment marker")
	source=replaceOnce(source,'tostring(args.AccessMode or "")','tostring(args.AccessMode or ""),tostring(args.SectionId or ""),tostring(args.Action or ""),tostring(args.StyleId or ""),tostring(args.Channel or ""),tostring(args.Material or ""),tostring(args.Color or "")',"structure fingerprint")
	return replaceOnce(source,'\t\telseif operation=="SetAccessMode" then success,message=Profile.SetAccessMode(profile,args)','\t\telseif operation=="SetAccessMode" then success,message=Profile.SetAccessMode(profile,args)\n\t\telseif operation=="ConfigureStructure" then success,message=Profile.ConfigureStructure(profile,args)',"structure transaction route")
end)

project(commands,"NTR_OWNED_GARAGE_STRUCTURE_COMMAND_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_AUTHORITATIVE_COMMAND_RUNTIME_V1","-- NTR_OWNED_GARAGE_AUTHORITATIVE_COMMAND_RUNTIME_V1\n-- NTR_OWNED_GARAGE_STRUCTURE_COMMAND_V1","command marker")
	return replaceOnce(source,"SetSurfaceStyle=true,SetAccessMode=true","SetSurfaceStyle=true,SetAccessMode=true,ConfigureStructure=true","command allowlist")
end)

project(management,"NTR_OWNED_GARAGE_STRUCTURE_MANAGEMENT_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V7_VERIFIED_TRANSITIONS","-- NTR_OWNED_GARAGE_MANAGEMENT_RUNTIME_V7_VERIFIED_TRANSITIONS\n-- NTR_OWNED_GARAGE_STRUCTURE_MANAGEMENT_V1","management marker")
	local old='\tlocal function applyInteriorStyles(profile,session)\n\t\tlocal property=profile.OwnedGarage.Properties[session.PropertyId]; local selected=property and property.Customisation and property.Customisation.SurfaceStyles or {}\n\t\tfor _,part in ipairs(session.Interior:GetDescendants()) do if part:IsA("BasePart") then local surfaceGroup=part:GetAttribute("SurfaceGroup"); local style=surfaceGroup and styleCatalog.ById(selected[surfaceGroup]); if style and style.SurfaceGroup==surfaceGroup then part.Color=style.Color; local material=Enum.Material[style.Material]; if material then part.Material=material end end end end\n\t\treturn true\n\tend'
	local new='\tlocal function applyInteriorStyles(profile,session)\n\t\tlocal property=profile.OwnedGarage.Properties[session.PropertyId]; local definition=catalog.ById(session.PropertyId); local structure=styleCatalog.NormalizeStructure(property and property.Customisation and property.Customisation.Structure,definition and definition.StructureSections or {}); local preview=session.StructurePreview\n\t\tfor _,part in ipairs(session.Interior:GetDescendants()) do if part:IsA("BasePart") then local section=part:GetAttribute("StructureSection"); local channel=tostring(part:GetAttribute("StructureChannel") or "Primary"); local item=section and structure.Sections[section]; if preview and preview.SectionId==section then item=preview end; if item then part.Color=styleCatalog.DecodeColor(item.Colors[channel] or item.Colors.Primary); local material=Enum.Material[item.Materials[channel] or item.Materials.Primary]; if material then part.Material=material end end end end\n\t\treturn true\n\tend'
	source=replaceOnce(source,old,new,"section presentation")
	source=replaceOnce(source,'(operation=="SetSurfaceStyle" and "Structure" or (operation=="SetAccessMode" and "Access"))','((operation=="SetSurfaceStyle" or operation=="ConfigureStructure") and "Structure" or (operation=="SetAccessMode" and "Access"))',"structure capability")
	source=replaceOnce(source,'elseif operation=="SetSurfaceStyle" then applyInteriorStyles(committed,session) end; return result end','elseif operation=="SetSurfaceStyle" or operation=="ConfigureStructure" then applyInteriorStyles(committed,session) end; return result end',"failure presentation")
	source=replaceOnce(source,'elseif operation=="SetSurfaceStyle" then presented=applyInteriorStyles(committed,session) end;','elseif operation=="SetSurfaceStyle" or operation=="ConfigureStructure" then session.StructurePreview=nil; presented=applyInteriorStyles(committed,session) end;',"success presentation")
	source=replaceOnce(source,'DecorationCategories=catalog.DecorationCategories(),Capabilities=','DecorationCategories=catalog.DecorationCategories(),Structure= currentProperty and styleCatalog.ClientState(currentProperty.Customisation.Structure,(catalog.ById(session.PropertyId) or {}).StructureSections or {}) or nil,Capabilities=',"structure state")
	source=replaceOnce(source,'or action=="CancelDisplayPreview"','or action=="CancelDisplayPreview" or action=="PreviewStructure" or action=="CancelStructurePreview"',"structure controls")
	source=replaceOnce(source,'\t\t\telseif action=="EnterSelectedGarage" then','\t\t\telseif action=="PreviewStructure" then local session=sessions[player]; local definition=session and catalog.ById(session.PropertyId); local section=tostring(args.SectionId or ""); local style=definition and styleCatalog.ById(section,args.StyleId); if not (session and style) then return {Success=false,Message="Structure preview is invalid."} end; session.StructurePreview={SectionId=section,StyleId=style.StyleId,Colors=style.Colors,Materials=style.Materials}; applyInteriorStyles(profile,session); return {Success=true,Message="Structure preview ready."}\n\t\t\telseif action=="CancelStructurePreview" then local session=sessions[player]; if not session then return {Success=false,Message="Garage session is not active."} end; session.StructurePreview=nil; applyInteriorStyles(profile,session); return {Success=true,Message="Structure preview cleared."}\n\t\t\telseif action=="EnterSelectedGarage" then',"preview routes")
	return replaceOnce(source,'\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end','\t\t\telseif action=="ConfigureStructure" then return managedOperation(player,profile,"ConfigureStructure",{SectionId=tostring(args.SectionId or ""),Action=tostring(args.Action or ""),StyleId=tostring(args.StyleId or ""),Channel=tostring(args.Channel or ""),Material=tostring(args.Material or ""),Color=args.Color,RequestId=args.RequestId,BaseRevision=args.BaseRevision})\n\t\t\telseif action=="SetAccessMode" then return managedOperation(player,profile,"SetAccessMode",{AccessMode=tostring(args.AccessMode or ""),RequestId=args.RequestId,BaseRevision=args.BaseRevision}) end',"structure mutation route")
end)

project(controller,"NTR_OWNED_GARAGE_STRUCTURE_UI_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V7_AUTHORITATIVE_SELECTED_ACTION","-- NTR_OWNED_GARAGE_WORKSPACE_CONTROLLER_V7_AUTHORITATIVE_SELECTED_ACTION\n-- NTR_OWNED_GARAGE_STRUCTURE_UI_V1","workspace marker")
	source=replaceOnce(source,'local selectedSlot; local selectedVehicle; local previewReady=false','local selectedSlot; local selectedVehicle; local selectedSection="FrontWall"; local selectedStyle; local selectedChannel="Primary"; local previewReady=false',"structure selection state")
	source=replaceOnce(source,'if state and state.InGarage then task.spawn(function() request("CancelDisplayPreview",{}) end) end','if state and state.InGarage then task.spawn(function() request("CancelDisplayPreview",{}); request("CancelStructurePreview",{}) end) end',"preview cancellation ownership")
	source=replaceOnce(source,'task.spawn(function() request("CancelDisplayPreview",{}); request("SetManagementOpen",{Open=false}) end)','task.spawn(function() request("CancelDisplayPreview",{}); request("CancelStructurePreview",{}); request("SetManagementOpen",{Open=false}) end)',"close preview cancellation")
	source=replaceOnce(source,'local function operate(action,args,nextPage,expectedSlotId,expectedVehicleId)','local function operate(action,args,nextPage,expectedSlotId,expectedVehicleId,successMessage)',"generic mutation message")
	source=replaceFirst(source,'workspace:Message("VEHICLE DISPLAYED")','workspace:Message(successMessage or "VEHICLE DISPLAYED")',"first success message")
	source=replaceOnce(source,'workspace:Message("VEHICLE DISPLAYED")','workspace:Message(successMessage or "VEHICLE DISPLAYED")',"second success message")
	source=replaceOnce(source,'local selected=(item.Id=="DisplayCars" and (page=="DisplaySpaces" or page=="DisplayVehicles")) or page==item.Id','local selected=(item.Id=="DisplayCars" and (page=="DisplaySpaces" or page=="DisplayVehicles")) or (item.Id=="Structure" and string.sub(page,1,9)=="Structure") or page==item.Id',"structure tab state")
	local old='\t\telse\n\t\t\tview=context(page.." is definition-ready and activates in its dedicated implementation phase.",{}); view.EmptyMessage=string.upper(page).." COMING NEXT"; view.BackVisible=true; view.BackText="BACK"; view.OnBack=function() page="DisplaySpaces"; render(true) end\n\t\tend'
	local new=[==[
		elseif string.sub(page,1,9)=="Structure" then
			local structure=state.Structure or {}; local sectionList=structure.Sections or {}; local selectedData=structure.Selected and structure.Selected[selectedSection]; local function sectionName(id) for _,item in ipairs(sectionList) do if item.Id==id then return item.Name end end return id end
			if page=="Structure" then for _,item in ipairs(sectionList) do local section=item; table.insert(cards,{Id=section.Id,DisplayName=section.Name,Footer="CHOOSE STRUCTURE",Selected=section.Id==selectedSection,OnSelect=function() selectedSection=section.Id; selectedStyle=nil; page="StructureStyles"; render(true) end}) end; view=context("Choose a structure location.",cards)
			elseif page=="StructureStyles" then for _,item in ipairs((structure.Styles and structure.Styles[selectedSection]) or {}) do local style=item; local owned=structure.OwnedStyles and structure.OwnedStyles[style.StyleId]; local current=selectedData and selectedData.StyleId==style.StyleId; table.insert(cards,{Id=style.StyleId,CardKind="Listing",DisplayName=style.DisplayName,Price=owned and nil or style.Price,Footer=current and "CURRENT" or (owned and "OWNED" or "LOCKED"),SemanticState=current and "Equipped" or (owned and "Available" or "Locked"),Selected=style.StyleId==selectedStyle,OnSelect=function() selectedStyle=style.StyleId; request("PreviewStructure",{SectionId=selectedSection,StyleId=style.StyleId}); render(false) end}) end; view=context("Choose a style for "..sectionName(selectedSection)..".",cards); local chosen; for _,item in ipairs((structure.Styles and structure.Styles[selectedSection]) or {}) do if item.StyleId==selectedStyle then chosen=item end end; if chosen then local owned=structure.OwnedStyles and structure.OwnedStyles[chosen.StyleId]; view.SelectedAction={RowId=chosen.StyleId,Text=owned and "CUSTOMISE" or "BUY",OnActivate=function() if owned then operate("ConfigureStructure",{SectionId=selectedSection,Action="Equip",StyleId=chosen.StyleId},"StructureCustomise",nil,nil,"STRUCTURE EQUIPPED") else operate("ConfigureStructure",{SectionId=selectedSection,Action="Purchase",StyleId=chosen.StyleId},"StructureCustomise",nil,nil,"STRUCTURE PURCHASED") end end} end
			elseif page=="StructureCustomise" then cards={{Id="Colour",DisplayName="Colour",Footer="PRIMARY / SECONDARY / DETAIL",OnSelect=function() page="StructureColour"; render(true) end},{Id="Material",DisplayName="Material",Footer="PRIMARY / SECONDARY / DETAIL",OnSelect=function() page="StructureMaterial"; render(true) end}}; view=context("Customise "..sectionName(selectedSection)..".",cards)
			elseif page=="StructureColour" then view=context("Adjust structure colours.",{}); view.ColorChannels=structure.Channels or {"Primary","Secondary","Detail"}; view.SelectedChannel=selectedChannel; view.Colors=selectedData and selectedData.Colors or {}; view.OnChannel=function(channel) selectedChannel=channel; render(true) end; view.OnColor=function(channel,color,commit) if commit then operate("ConfigureStructure",{SectionId=selectedSection,Action="SetColour",Channel=channel,Color=color},"StructureColour",nil,nil,"COLOUR SAVED") end end
			elseif page=="StructureMaterial" then for _,material in ipairs(structure.Materials or {}) do local name=material; table.insert(cards,{Id=name,DisplayName=name,Footer=(selectedData and selectedData.Materials and selectedData.Materials[selectedChannel]==name) and "CURRENT" or selectedChannel,Selected=selectedData and selectedData.Materials and selectedData.Materials[selectedChannel]==name,OnSelect=function() operate("ConfigureStructure",{SectionId=selectedSection,Action="SetMaterial",Channel=selectedChannel,Material=name},"StructureMaterial",nil,nil,"MATERIAL SAVED") end}) end; view=context("Choose "..selectedChannel.." material.",cards)
			end
			view.BackVisible=true; view.BackText="BACK"; view.OnBack=function() request("CancelStructurePreview",{}); if page=="Structure" then page="DisplaySpaces" elseif page=="StructureStyles" then page="Structure" elseif page=="StructureCustomise" then page="StructureStyles" else page="StructureCustomise" end; render(true) end
		else
			view=context(page.." is definition-ready and activates in its dedicated implementation phase.",{}); view.EmptyMessage=string.upper(page).." COMING NEXT"; view.BackVisible=true; view.BackText="BACK"; view.OnBack=function() page="DisplaySpaces"; render(true) end
		end
]==]
	return replaceOnce(source,old,new,"structure pages")
end)

project(management,"NTR_OWNED_GARAGE_STRUCTURE_ASSET_RUNTIME_V1",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_STRUCTURE_MANAGEMENT_V1","-- NTR_OWNED_GARAGE_STRUCTURE_MANAGEMENT_V1\n-- NTR_OWNED_GARAGE_STRUCTURE_ASSET_RUNTIME_V1","asset runtime marker")
	source=replaceOnce(source,'local ServerScriptService=game:GetService("ServerScriptService")\nlocal Workspace=game:GetService("Workspace")','local ServerScriptService=game:GetService("ServerScriptService")\nlocal ServerStorage=game:GetService("ServerStorage")\nlocal Workspace=game:GetService("Workspace")',"ServerStorage service")
	local old=[==[
	local function applyInteriorStyles(profile,session)
		local property=profile.OwnedGarage.Properties[session.PropertyId]; local definition=catalog.ById(session.PropertyId); local structure=styleCatalog.NormalizeStructure(property and property.Customisation and property.Customisation.Structure,definition and definition.StructureSections or {}); local preview=session.StructurePreview
		for _,part in ipairs(session.Interior:GetDescendants()) do if part:IsA("BasePart") then local section=part:GetAttribute("StructureSection"); local channel=tostring(part:GetAttribute("StructureChannel") or "Primary"); local item=section and structure.Sections[section]; if preview and preview.SectionId==section then item=preview end; if item then part.Color=styleCatalog.DecodeColor(item.Colors[channel] or item.Colors.Primary); local material=Enum.Material[item.Materials[channel] or item.Materials.Primary]; if material then part.Material=material end end end end
		return true
	end
]==]
	local new=[==[
	local function applyInteriorStyles(profile,session)
		local property=profile.OwnedGarage.Properties[session.PropertyId]; local definition=catalog.ById(session.PropertyId); local sections=definition and definition.StructureSections or {}; local structure=styleCatalog.NormalizeStructure(property and property.Customisation and property.Customisation.Structure,sections); local preview=session.StructurePreview
		local storageRoot=ServerStorage:FindFirstChild("NeoTokyoRacers"); storageRoot=storageRoot and storageRoot:FindFirstChild("OwnedGarage"); storageRoot=storageRoot and storageRoot:FindFirstChild("StructureAssets"); local templateRoot=storageRoot and storageRoot:FindFirstChild(tostring(definition and definition.TemplateId or "")); local slots=session.Interior:FindFirstChild("StructureSlots"); if not (templateRoot and slots) then return false,"Structure asset contract is missing." end
		local runtime=session.Interior:FindFirstChild("StructureRuntime"); if not runtime then runtime=Instance.new("Folder"); runtime.Name="StructureRuntime"; runtime.Parent=session.Interior end
		for _,base in ipairs(session.Interior:GetDescendants()) do if base:IsA("BasePart") and base:GetAttribute("StructureSection") and not base:IsDescendantOf(runtime) and not base:IsDescendantOf(slots) then base.Transparency=1; base.CanCollide=false; base.CanTouch=false; base.CanQuery=false end end
		for _,section in ipairs(sections) do
			local item=structure.Sections[section]; if preview and preview.SectionId==section then item=preview end; local style=item and styleCatalog.ById(section,item.StyleId); local slot=slots:FindFirstChild(section); local sectionRoot=templateRoot:FindFirstChild(section); local asset=style and sectionRoot and sectionRoot:FindFirstChild(style.AssetOption)
			if not (style and slot and slot:IsA("BasePart") and asset and asset:IsA("Model")) then return false,"Structure asset missing: "..tostring(section).."/"..tostring(style and style.AssetOption or "") end
			local oldModel=runtime:FindFirstChild(section); if oldModel then oldModel:Destroy() end; local clone=asset:Clone(); clone.Name=section
			for _,object in ipairs(clone:GetDescendants()) do if object:IsA("LuaSourceContainer") or object:IsA("ProximityPrompt") or object:IsA("Seat") or object:IsA("VehicleSeat") then object:Destroy() elseif object:IsA("BasePart") then local localCFrame=object.CFrame; object.CFrame=slot.CFrame*localCFrame; object.Anchored=true; object.CanTouch=false; object.CanQuery=false; object.CastShadow=false; local channel=tostring(object:GetAttribute("StructureChannel") or "Primary"); object.Color=styleCatalog.DecodeColor(item.Colors[channel] or item.Colors.Primary); local material=Enum.Material[item.Materials[channel] or item.Materials.Primary]; if material then object.Material=material end end end
			clone:SetAttribute("StructureSection",section); clone:SetAttribute("StructureStyleId",style.StyleId); clone:SetAttribute("StructurePreview",preview and preview.SectionId==section or false); clone.Parent=runtime
		end
		return true
	end
]==]
	return replaceOnce(source,old,new,"asset-backed structure presentation")
end)

project(controller,"NTR_OWNED_GARAGE_STRUCTURE_UI_V1_1_CAPABILITY_ASSETS",function(source)
	source=replaceOnce(source,"-- NTR_OWNED_GARAGE_STRUCTURE_UI_V1","-- NTR_OWNED_GARAGE_STRUCTURE_UI_V1\n-- NTR_OWNED_GARAGE_STRUCTURE_UI_V1_1_CAPABILITY_ASSETS","capability UI marker")
	source=replaceOnce(source,'table.insert(result,{Id=item.Id,Text=item.Text,Image=item.Image,ImageZoom=.5,Selected=selected,OnSelect=function() if item.Id=="DisplayCars" then page="DisplaySpaces" else page=item.Id end; cancelPreview(); render(true) end})','table.insert(result,{Id=item.Id,Text=item.Text,Image=item.Image,ImageZoom=.5,Selected=selected,OnSelect=function() if item.Enabled~=true then workspace:Message(string.upper(item.Text).." COMING LATER"); return end; if item.Id=="DisplayCars" then page="DisplaySpaces" else page=item.Id end; cancelPreview(); render(true) end})',"disabled category guard")
	return replaceOnce(source,'CardKind="Listing",DisplayName=style.DisplayName,Price=owned','CardKind="Listing",VehicleName=sectionName(selectedSection),DisplayName=style.DisplayName,Price=owned',"structure card lineage")
end)

local sectionMap={BackWall={"BackWall"},LeftWall={"LeftWall"},RightWall={"RightWall"},Floor={"Floor"},Ceiling={"Roof"},FrontWall={"FrontWallLeft","FrontWallRight","FrontDoorLintel"}}
local sourceSnapshots={}; local attrSnapshots={}; local created={}; local configSnapshot={Revision=config:GetAttribute("OwnedGarageRevision"),RunId=config:GetAttribute("OwnedGarageInstallRunId"),StructureVersion=config:GetAttribute("StructureContractVersion"),AssetVersion=config:GetAttribute("StructureAssetContractVersion"),EnableStructure=config:GetAttribute("EnableStructure")}
for object in pairs(projected) do sourceSnapshots[object]={Source=object.Source,Revision=object:GetAttribute("OwnedGarageRevision"),RunId=object:GetAttribute("OwnedGarageInstallRunId")} end
local function create(className,name,parent) local object=Instance.new(className); object.Name=name; object.Parent=parent; table.insert(created,object); return object end
local function folder(parent,name) local object=parent:FindFirstChild(name); if object then assert(object:IsA("Folder"),object:GetFullName().." must be a Folder"); return object end; return create("Folder",name,parent) end
local ok,problem=pcall(function()
	for section,names in pairs(sectionMap) do for _,name in ipairs(names) do local part=assert(template:FindFirstChild(name),"Template part missing: "..name); assert(part:IsA("BasePart"),name.." must be a BasePart"); attrSnapshots[part]={Section=part:GetAttribute("StructureSection"),Channel=part:GetAttribute("StructureChannel")}; part:SetAttribute("StructureSection",section); part:SetAttribute("StructureChannel",name=="FrontDoorLintel" and "Detail" or (name=="FrontWallRight" and "Secondary" or "Primary")) end end
	local garageStorage=assert(template.Parent and template.Parent.Parent,"OwnedGarage storage root missing"); local assetsRoot=folder(garageStorage,"StructureAssets"); local templateAssets=folder(assetsRoot,"StarterTwoBay"); local slots=folder(template,"StructureSlots")
	for section,names in pairs(sectionMap) do
		local firstPart=assert(template:FindFirstChild(names[1]),"Structure source missing: "..section); local slot=slots:FindFirstChild(section)
		if not slot then slot=create("Part",section,slots); slot.Anchored=true; slot.CanCollide=false; slot.CanTouch=false; slot.CanQuery=false; slot.CastShadow=false; slot.Transparency=1; slot.Size=Vector3.new(1,1,1); slot.CFrame=firstPart.CFrame end
		assert(slot:IsA("BasePart"),slot:GetFullName().." must be a BasePart"); slot:SetAttribute("StructureSection",section); slot:SetAttribute("StructureSlotContractVersion",1)
		local sectionFolder=folder(templateAssets,section)
		for optionIndex=1,4 do local optionName=string.format("Option%02d",optionIndex); local option=sectionFolder:FindFirstChild(optionName)
			if not option then option=create("Model",optionName,sectionFolder); option:SetAttribute("TemplateId","StarterTwoBay"); option:SetAttribute("SectionId",section); option:SetAttribute("StyleId",string.upper(section).."_OPTION_"..optionIndex); option:SetAttribute("StructureAssetContractVersion",1); option:SetAttribute("PlaceholderTemplate",optionIndex>1)
				for _,partName in ipairs(names) do local sourcePart=assert(template:FindFirstChild(partName),"Structure source missing: "..partName); local clone=sourcePart:Clone(); clone:ClearAllChildren(); clone.Name=partName; clone.CFrame=slot.CFrame:ToObjectSpace(sourcePart.CFrame); clone.Anchored=true; clone.CanTouch=false; clone.CanQuery=false; clone:SetAttribute("StructureSection",section); clone:SetAttribute("StructureChannel",sourcePart:GetAttribute("StructureChannel") or "Primary"); clone.Parent=option; if not option.PrimaryPart then option.PrimaryPart=clone end end
			end
			assert(option:IsA("Model") and #option:GetChildren()>0,"Structure option is empty: "..section.."/"..optionName)
		end
	end
	for object,source in pairs(projected) do object.Source=source; object:SetAttribute("OwnedGarageRevision",REVISION); object:SetAttribute("OwnedGarageInstallRunId",RUN_ID) end
	config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID); config:SetAttribute("StructureContractVersion",1); config:SetAttribute("StructureAssetContractVersion",1); config:SetAttribute("EnableStructure",true)
	for object in pairs(projected) do assert(object.Source:find("NTR_OWNED_GARAGE_STRUCTURE",1,true) or object==catalog,"Structure marker missing: "..object.Name) end
	for section,names in pairs(sectionMap) do for _,name in ipairs(names) do local part=template:FindFirstChild(name); assert(part:GetAttribute("StructureSection")==section,"Section attribute failed: "..name) end; local slot=slots:FindFirstChild(section); local sectionFolder=templateAssets:FindFirstChild(section); assert(slot and slot:IsA("BasePart") and sectionFolder,"Structure contract missing: "..section); for index=1,4 do assert(sectionFolder:FindFirstChild(string.format("Option%02d",index)),"Structure option missing: "..section.."/"..index) end end
end)
if not ok then
	for object,snapshot in pairs(sourceSnapshots) do if object.Parent then object.Source=snapshot.Source; object:SetAttribute("OwnedGarageRevision",snapshot.Revision); object:SetAttribute("OwnedGarageInstallRunId",snapshot.RunId) end end
	for part,snapshot in pairs(attrSnapshots) do if part.Parent then part:SetAttribute("StructureSection",snapshot.Section); part:SetAttribute("StructureChannel",snapshot.Channel) end end
	for index=#created,1,-1 do local object=created[index]; if object and object.Parent then object:Destroy() end end
	config:SetAttribute("OwnedGarageRevision",configSnapshot.Revision); config:SetAttribute("OwnedGarageInstallRunId",configSnapshot.RunId); config:SetAttribute("StructureContractVersion",configSnapshot.StructureVersion); config:SetAttribute("StructureAssetContractVersion",configSnapshot.AssetVersion); config:SetAttribute("EnableStructure",configSnapshot.EnableStructure)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end
print(TAG.." PASS sources=6 sections=6 options=24 attributedParts=8 structureEnabled=true revision="..REVISION.." runId="..RUN_ID)
print(TAG.." READY: asset-backed section preview/persistence and editable StarterTwoBay structure templates installed.")
