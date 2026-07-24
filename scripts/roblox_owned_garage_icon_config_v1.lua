-- Neo Tokyo Racers - Owned Garage icon configuration V1.1
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Adds one central designer-owned icon config and connects existing shared UI consumers.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Owned Garage Icon Config V1.1]"
local BASE="NTR_OWNED_GARAGE_PHASE14_V2_2_RESPONSIVE_NAVIGATION_CLOSURE"
local V1="NTR_OWNED_GARAGE_ICON_CONFIG_V1"
local REVISION="NTR_OWNED_GARAGE_ICON_CONFIG_V1_1_LOCATION_SCALE"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path) local object=root; for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end; return object end
local function compile(source,name) local fn,problem=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(problem)) end
local function count(source,needle) local n=0; local cursor=1; while true do local a,b=source:find(needle,cursor,true); if not a then return n end; n+=1; cursor=b+1 end end
local function replaceOnce(source,needle,replacement,label) local n=count(source,needle); assert(n==1,label.." anchor count was "..n); local a,b=source:find(needle,1,true); return source:sub(1,a-1)..replacement..source:sub(b+1) end
local function replaceEvery(source,needle,replacement,expected,label) local n=count(source,needle); assert(n==expected,label.." anchor count was "..n..", expected "..expected); local pieces={}; local cursor=1; while true do local a,b=source:find(needle,cursor,true); if not a then table.insert(pieces,source:sub(cursor)); break end; table.insert(pieces,source:sub(cursor,a-1)); table.insert(pieces,replacement); cursor=b+1 end; return table.concat(pieces) end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local replacement=assert(find(kit,"Config.UI.GarageReplacement"),"GarageReplacement config missing")
local navigation=assert(replacement:FindFirstChild("NavigationIcons"),"NavigationIcons missing")
local runtime=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage runtime config missing")
local uiRoot=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI"),"Client UI controllers missing")
local owned=assert(uiRoot:FindFirstChild("OwnedGarageWorkspaceController"),"OwnedGarageWorkspaceController missing")
local workspaceController=assert(uiRoot:FindFirstChild("GarageWorkspaceController"),"GarageWorkspaceController missing")
local interior=assert(uiRoot:FindFirstChild("GarageInteriorModeController"),"GarageInteriorModeController missing")
local browser=assert(uiRoot:FindFirstChild("OwnedGarageBrowserController"),"OwnedGarageBrowserController missing")
local containers={owned,workspaceController,interior,browser}
for _,container in ipairs(containers) do assert(container:IsA("LuaSourceContainer"),container:GetFullName().." is not a source container"); compile(container.Source,container.Name) end
assert(owned.Source:find(BASE,1,true),"Confirmed Phase 14 V2.2 owned workspace marker missing")

local defaults={
	Modes={DisplayCars=tostring(navigation:GetAttribute("OwnedModulesIcon") or ""),BuildGarage=tostring(navigation:GetAttribute("BuildModulesIcon") or ""),StyleGarage=tostring(navigation:GetAttribute("CustomiseModulesIcon") or "")},
	Families={Structure=tostring(navigation:GetAttribute("BuildModulesIcon") or ""),Decorations=tostring(navigation:GetAttribute("CustomiseModulesIcon") or ""),Lighting=tostring(navigation:GetAttribute("BuyModulesIcon") or "")},
	StructureLocations={FrontWall="",LeftWall="",RightWall="",BackWall="",Floor="",Ceiling=""},
	DecorationLocations={WorkshopWall="",StorageWall="",HangoutBay="",FeatureCorner="",IdentityWall="",DisplayPlatforms=""},
	Navigation={Back=tostring(navigation:GetAttribute("BackIcon") or ""),Exit=tostring(navigation:GetAttribute("ExitIcon") or "")},
	Access={Private=tostring(runtime:GetAttribute("InteriorHudPrivateIcon") or ""),FriendsOnly=tostring(runtime:GetAttribute("InteriorHudFriendsIcon") or ""),InviteOnly=tostring(runtime:GetAttribute("InteriorHudInviteOnlyIcon") or ""),Public=tostring(runtime:GetAttribute("InteriorHudPublicIcon") or ""),Invite=tostring(runtime:GetAttribute("InteriorHudInviteIcon") or "")},
	Browser={Enter="",Exit="",Cancel=""},
	Economy={Capacity=""},
	Actions={InstallAsset=""},
	Sizing={StructureLocationImageZoom=1,DecorationLocationImageZoom=1},
}

local projected={}
do
	local source=owned.Source
	if not source:find(V1,1,true) then
		source=replaceOnce(source,"-- "..BASE.."\n","-- "..BASE.."\n-- "..V1.."\n","owned V1 icon revision")
		source=replaceOnce(source,'local icons=replacement:FindFirstChild("OwnedGarageIcons") or navIcons','local icons=replacement:WaitForChild("OwnedGarageIcons")',"owned icon root")
		local old=[=[	local iconFallback={DisplayCars="OwnedModulesIcon",BuildGarage="BuildModulesIcon",StyleGarage="CustomiseModulesIcon",Structure="BuildModulesIcon",Decorations="CustomiseModulesIcon",Lighting="BuyModulesIcon"}
	local function icon(name) return asset(icons:GetAttribute(name) or navIcons:GetAttribute(iconFallback[name] or "")) end
	local function navIcon(name) return asset(navIcons:GetAttribute(name) or navIcons:GetAttribute(name.."Icon")) end]=]
		local new=[=[	local iconContract={ModeDisplayCars={"Modes","DisplayCars","OwnedModulesIcon"},ModeBuildGarage={"Modes","BuildGarage","BuildModulesIcon"},ModeStyleGarage={"Modes","StyleGarage","CustomiseModulesIcon"},FamilyStructure={"Families","Structure","BuildModulesIcon"},FamilyDecorations={"Families","Decorations","CustomiseModulesIcon"},FamilyLighting={"Families","Lighting","BuyModulesIcon"},NavigationBack={"Navigation","Back","BackIcon"},NavigationExit={"Navigation","Exit","ExitIcon"},EconomyCapacity={"Economy","Capacity"}}
	local function folderIcon(group,key) local folder=icons:FindFirstChild(group); local value=folder and folder:GetAttribute(key); return type(value)=="string" and value~="" and asset(value) or "" end
	local function namedIcon(name) local definition=iconContract[name]; if not definition then return "" end; local value=folderIcon(definition[1],definition[2]); if value~="" then return value end; local legacy=definition[3]; return legacy and asset(navIcons:GetAttribute(legacy)) or "" end
	local function scopedIcon(group,key,fallback) local value=folderIcon(group,key); return value~="" and value or namedIcon(fallback) end
	local function navIcon(name) return namedIcon("Navigation"..name) end]=]
		source=replaceOnce(source,old,new,"owned icon resolver")
		source=replaceOnce(source,'Image=icon("Structure"),ImageZoom','Image=scopedIcon("StructureLocations",section.Id,"FamilyStructure"),ImageZoom',"structure location icon")
		source=replaceOnce(source,'Image=icon("Decorations"),ImageZoom','Image=scopedIcon("DecorationLocations",zone.SlotId,"FamilyDecorations"),ImageZoom',"decoration location icon")
		source=replaceEvery(source,'icon("DisplayCars")','namedIcon("ModeDisplayCars")',2,"Display Cars icons")
		source=replaceEvery(source,'icon("BuildGarage")','namedIcon("ModeBuildGarage")',2,"Build Garage icons")
		source=replaceEvery(source,'icon("StyleGarage")','namedIcon("ModeStyleGarage")',2,"Style Garage icons")
		source=replaceEvery(source,'icon("Structure")','namedIcon("FamilyStructure")',1,"Structure family icon")
		source=replaceEvery(source,'icon("Decorations")','namedIcon("FamilyDecorations")',2,"Decoration family icons")
		source=replaceEvery(source,'icon("Lighting")','namedIcon("FamilyLighting")',1,"Lighting family icon")
		source=replaceOnce(source,'Id="InstallAsset",DisplayName="Install Asset",Image=namedIcon("FamilyDecorations")','Id="InstallAsset",DisplayName="Install Asset",Image=scopedIcon("Actions","InstallAsset","FamilyDecorations")',"Install Asset icon")
		source=replaceOnce(source,'ShowStats=false,ShowCashPlus=true','CapacityIcon=namedIcon("EconomyCapacity"),ShowStats=false,ShowCashPlus=true',"capacity icon context")
		compile(source,owned.Name.."_Projected")
	end
	if not source:find(REVISION,1,true) then
		source=replaceOnce(source,"-- "..V1.."\n","-- "..V1.."\n-- "..REVISION.."\n","owned V1.1 icon revision")
		local zoomAnchor=[=[	local function categoryCardImageZoom() return math.clamp(tonumber(cfg:GetAttribute("OwnedGarageCategoryCardImageZoom")) or .5,.2,1.2) end]=]
		local zoomReplacement=zoomAnchor..[=[
	local iconSizing=icons:WaitForChild("Sizing")
	local function locationIconZoom(name) return math.clamp(tonumber(iconSizing:GetAttribute(name)) or categoryCardImageZoom()*2,.2,1.5) end]=]
		source=replaceOnce(source,zoomAnchor,zoomReplacement,"location icon sizing helper")
		source=replaceOnce(source,'Image=scopedIcon("StructureLocations",section.Id,"FamilyStructure"),ImageZoom=categoryCardImageZoom()','Image=scopedIcon("StructureLocations",section.Id,"FamilyStructure"),ImageZoom=locationIconZoom("StructureLocationImageZoom")',"structure location icon scale")
		source=replaceOnce(source,'Image=scopedIcon("DecorationLocations",zone.SlotId,"FamilyDecorations"),ImageZoom=categoryCardImageZoom()','Image=scopedIcon("DecorationLocations",zone.SlotId,"FamilyDecorations"),ImageZoom=locationIconZoom("DecorationLocationImageZoom")',"decoration location icon scale")
		compile(source,owned.Name.."_LocationScaleProjected")
	end
	projected[owned]=source
end
do
	local source=workspaceController.Source
	if not source:find(V1,1,true) then
		source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS\n","-- NTR_OWNED_GARAGE_PHASE13_V1_3_AUTHORED_DEFAULTS_MATERIAL_TABS\n-- "..V1.."\n","workspace icon revision")
		source=replaceOnce(source,'icon.Image=asset("GarageIcon")','icon.Image=(type(context.CapacityIcon)=="string" and context.CapacityIcon~="") and context.CapacityIcon or asset("GarageIcon")',"capacity icon consumer")
		compile(source,workspaceController.Name.."_Projected")
	end
	projected[workspaceController]=source
end
do
	local source=interior.Source
	if not source:find(V1,1,true) then
		source=replaceOnce(source,"-- NTR_OWNED_GARAGE_ACCESS_HUD_DROPDOWNS_V2\n","-- NTR_OWNED_GARAGE_ACCESS_HUD_DROPDOWNS_V2\n-- "..V1.."\n","access icon revision")
		source=replaceOnce(source,'\tlocal function stringAttribute(name) local value=settings:GetAttribute(name); return typeof(value)=="string" and value or "" end','\tlocal function stringAttribute(name) local value=settings:GetAttribute(name); return typeof(value)=="string" and value or "" end\n\tlocal accessIconsConfig=kit.Config.UI:WaitForChild("GarageReplacement"):WaitForChild("OwnedGarageIcons"):WaitForChild("Access")\n\tlocal function accessIcon(name,legacyName) local value=accessIconsConfig:GetAttribute(name); if type(value)=="string" and value~="" then return UI.Asset(value) end; return stringAttribute(legacyName) end',"access icon config")
		source=replaceOnce(source,'Text="PRIVATE",IconText=utf8.char(128274)','Text="PRIVATE",Icon=accessIcon("Private","InteriorHudPrivateIcon"),IconText=utf8.char(128274)',"initial access icon")
		source=replaceOnce(source,'local function accessVisual(mode) return stringAttribute(accessIcons[mode] or ""),accessGlyphs[mode] or utf8.char(9679) end','local function accessVisual(mode) return accessIcon(mode,accessIcons[mode] or ""),accessGlyphs[mode] or utf8.char(9679) end',"access mode icons")
		source=replaceEvery(source,'stringAttribute("InteriorHudInviteIcon")','accessIcon("Invite","InteriorHudInviteIcon")',3,"Invite icons")
		compile(source,interior.Name.."_Projected")
	end
	projected[interior]=source
end
do
	local source=browser.Source
	if not source:find(V1,1,true) then
		source=replaceOnce(source,"-- NTR_OWNED_GARAGE_PHASE13_V1_2_STREAMING_CLIENT\n","-- NTR_OWNED_GARAGE_PHASE13_V1_2_STREAMING_CLIENT\n-- "..V1.."\n","browser icon revision")
		source=replaceOnce(source,'\tlocal settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")','\tlocal settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")\n\tlocal browserIcons=kit.Config.UI:WaitForChild("GarageReplacement"):WaitForChild("OwnedGarageIcons"):WaitForChild("Browser")\n\tlocal function browserIcon(name) local value=browserIcons:GetAttribute(name); return type(value)=="string" and value~="" and UI.Asset(value) or "" end',"browser icon config")
		source=replaceOnce(source,'Name="Exit",Text="EXIT",IconText=','Name="Exit",Text="EXIT",Icon=browserIcon("Exit"),IconText=',"browser Exit icon")
		source=replaceOnce(source,'Name="Enter",Text="ENTER GARAGE",IconText=','Name="Enter",Text="ENTER GARAGE",Icon=browserIcon("Enter"),IconText=',"browser Enter icon")
		source=replaceOnce(source,'Name="Cancel",Text="CANCEL",IconText=','Name="Cancel",Text="CANCEL",Icon=browserIcon("Cancel"),IconText=',"browser Cancel icon")
		compile(source,browser.Name.."_Projected")
	end
	projected[browser]=source
end

local originalSources={}; local originalSourceAttributes={}; for container in pairs(projected) do originalSources[container]=container.Source; originalSourceAttributes[container]={Revision=container:GetAttribute("OwnedGarageIconRevision"),RunId=container:GetAttribute("OwnedGarageIconInstallRunId")} end
local existingRoot=replacement:FindFirstChild("OwnedGarageIcons")
assert(not existingRoot or existingRoot:IsA("Folder"),"OwnedGarageIcons exists but is not a Folder")
local rootAttributes={ContractVersion=existingRoot and existingRoot:GetAttribute("ContractVersion"),Revision=existingRoot and existingRoot:GetAttribute("Revision"),InstallRunId=existingRoot and existingRoot:GetAttribute("InstallRunId"),EditNote=existingRoot and existingRoot:GetAttribute("EditNote")}
local groupSnapshots={}
if existingRoot then for group,values in pairs(defaults) do local folder=existingRoot:FindFirstChild(group); assert(not folder or folder:IsA("Folder"),"OwnedGarageIcons."..group.." is not a Folder"); local snapshot={Folder=folder,Values={}}; if folder then for key in pairs(values) do snapshot.Values[key]=folder:GetAttribute(key) end end; groupSnapshots[group]=snapshot end end

local ok,problem=pcall(function()
	local root=existingRoot
	if not root then root=Instance.new("Folder"); root.Name="OwnedGarageIcons"; root.Parent=replacement end
	local iconCount=0
	for group,values in pairs(defaults) do
		local folder=root:FindFirstChild(group); if not folder then folder=Instance.new("Folder"); folder.Name=group; folder.Parent=root end
		assert(folder:IsA("Folder"),group.." icon config is not a Folder")
		for key,value in pairs(values) do if folder:GetAttribute(key)==nil then folder:SetAttribute(key,value) end; assert(typeof(folder:GetAttribute(key))==typeof(value),group.."."..key.." attribute type invalid"); iconCount+=1 end
	end
	root:SetAttribute("ContractVersion",2); root:SetAttribute("Revision",REVISION); root:SetAttribute("InstallRunId",RUN_ID); root:SetAttribute("EditNote","Set icon String attributes to rbxassetid://ASSET_ID. Sizing numbers control Structure/Decoration location icon zoom. Blank icons use their family or glyph fallback.")
	for container,source in pairs(projected) do if container.Source~=source then container.Source=source end; container:SetAttribute("OwnedGarageIconRevision",REVISION); container:SetAttribute("OwnedGarageIconInstallRunId",RUN_ID); compile(container.Source,container.Name) end
	assert(owned.Source:find(REVISION,1,true),owned.Name.." V1.1 marker did not persist")
	for _,container in ipairs({workspaceController,interior,browser}) do assert(container.Source:find(V1,1,true),container.Name.." V1 icon marker did not persist") end
	assert(iconCount==32,"Icon and sizing configuration cardinality invalid")
	assert(root:FindFirstChild("StructureLocations") and root:FindFirstChild("DecorationLocations") and root:FindFirstChild("Access"),"Icon configuration hierarchy did not persist")
	assert(owned.Source:find('scopedIcon("StructureLocations",section.Id,"FamilyStructure")',1,true),"Structure location icon route missing")
	assert(owned.Source:find('scopedIcon("DecorationLocations",zone.SlotId,"FamilyDecorations")',1,true),"Decoration location icon route missing")
	assert(owned.Source:find('locationIconZoom("StructureLocationImageZoom")',1,true),"Structure location icon scale route missing")
	assert(owned.Source:find('locationIconZoom("DecorationLocationImageZoom")',1,true),"Decoration location icon scale route missing")
	local structureZoom=root.Sizing:GetAttribute("StructureLocationImageZoom"); local decorationZoom=root.Sizing:GetAttribute("DecorationLocationImageZoom")
	assert(type(structureZoom)=="number" and type(decorationZoom)=="number","Location icon sizing attributes invalid")
	assert(workspaceController.Source:find("context.CapacityIcon",1,true),"Capacity icon route missing")
	assert(interior.Source:find('accessIcon("Invite","InteriorHudInviteIcon")',1,true),"Access icon route missing")
	assert(browser.Source:find('browserIcon("Enter")',1,true),"Browser icon route missing")
end)
if not ok then
	for container,source in pairs(originalSources) do pcall(function() local attributes=originalSourceAttributes[container]; container.Source=source; container:SetAttribute("OwnedGarageIconRevision",attributes.Revision); container:SetAttribute("OwnedGarageIconInstallRunId",attributes.RunId) end) end
	pcall(function()
		local root=replacement:FindFirstChild("OwnedGarageIcons")
		if not existingRoot then if root then root:Destroy() end else
			for group,values in pairs(defaults) do local snapshot=groupSnapshots[group]; local folder=existingRoot:FindFirstChild(group); if not snapshot.Folder then if folder then folder:Destroy() end else for key in pairs(values) do snapshot.Folder:SetAttribute(key,snapshot.Values[key]) end end end
			existingRoot:SetAttribute("ContractVersion",rootAttributes.ContractVersion); existingRoot:SetAttribute("Revision",rootAttributes.Revision); existingRoot:SetAttribute("InstallRunId",rootAttributes.InstallRunId); existingRoot:SetAttribute("EditNote",rootAttributes.EditNote)
		end
	end)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

local writes=0; for container,source in pairs(projected) do if originalSources[container]~=source then writes+=1 end end
local sizing=replacement.OwnedGarageIcons.Sizing
print(TAG.." PASS sourceWrites="..writes.." groups=10 icons=30 sizing=2 structureZoom="..tostring(sizing:GetAttribute("StructureLocationImageZoom")).." decorationZoom="..tostring(sizing:GetAttribute("DecorationLocationImageZoom")).." revision="..REVISION.." runId="..RUN_ID)
print(TAG.." READY: tune OwnedGarageIcons.Sizing StructureLocationImageZoom and DecorationLocationImageZoom, then restart Play to see changes.")
