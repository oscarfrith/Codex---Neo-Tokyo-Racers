-- Neo Tokyo Racers - Owned Garage Phase 14 V2.2 responsive navigation closure
-- Run once in the Roblox Studio Command Bar while NOT playing.
-- Canonical refinement from the user-confirmed/mirrored Phase 14 V2.1 flow.

local RunService=game:GetService("RunService")
assert(not RunService:IsRunning(),"Run this installer in Roblox Studio Edit mode.")
local HttpService=game:GetService("HttpService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local TAG="[NTR Owned Garage Phase 14 V2.2]"
local BASE="NTR_OWNED_GARAGE_PHASE14_V2_1_SHARED_CATEGORY_CARD_PARITY"
local REVISION="NTR_OWNED_GARAGE_PHASE14_V2_2_RESPONSIVE_NAVIGATION_CLOSURE"
local RUN_ID=HttpService:GenerateGUID(false)

local function find(root,path) local object=root; for segment in string.gmatch(path,"[^.]+") do object=object and object:FindFirstChild(segment) end; return object end
local function compile(source,name) local fn,problem=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(problem)) end
local function count(source,needle) local n=0; local cursor=1; while true do local a,b=source:find(needle,cursor,true); if not a then return n end; n+=1; cursor=b+1 end end
local function replaceOnce(source,needle,replacement,label) local n=count(source,needle); assert(n==1,label.." anchor count was "..n); local a,b=source:find(needle,1,true); return source:sub(1,a-1)..replacement..source:sub(b+1) end

local kit=assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"),"NeoTokyoRacers missing")
local config=assert(find(kit,"Config.Runtime.OwnedGarage_EditAttributes"),"OwnedGarage config missing")
local controller=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.OwnedGarageWorkspaceController"),"OwnedGarageWorkspaceController missing")
local workspaceController=assert(find(StarterPlayer,"StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.GarageWorkspaceController"),"GarageWorkspaceController missing")
assert(controller:IsA("LuaSourceContainer") and workspaceController:IsA("LuaSourceContainer"),"Workspace source contract missing")
compile(controller.Source,controller.Name); compile(workspaceController.Source,workspaceController.Name)
assert(workspaceController.Source:find("Shared.ModuleCategoryCard",1,true),"Shared ModuleCategoryCard renderer missing")
assert(workspaceController.Source:find("CategoryScrollKey",1,true) and workspaceController.Source:find("ScrollMemory.Category",1,true),"Shared sidebar scroll-memory contract missing")

local source=controller.Source
local sourceInstalled=source:find(REVISION,1,true)~=nil
if not sourceInstalled then
	assert(source:find(BASE,1,true),"Confirmed V2.1 workspace marker missing")
	source=replaceOnce(source,"-- "..BASE.."\n","-- "..BASE.."\n-- "..REVISION.."\n","V2.2 revision")
	source=replaceOnce(source,
		'\tlocal function tabs() return locationTabs() or modeTabs() end\n\tlocal function context(subtitle,cards)',
		'\tlocal function tabs() return locationTabs() or modeTabs() end\n\tlocal function railScrollKey()\n\t\tif string.sub(page,1,14)=="BuildStructure" or string.sub(page,1,14)=="StyleStructure" then return "OwnedGarageRail:Structure" end\n\t\tif string.sub(page,1,16)=="BuildDecorations" or string.sub(page,1,16)=="StyleDecorations" then return "OwnedGarageRail:Decorations" end\n\t\treturn "OwnedGarageRail:Modes"\n\tend\n\tlocal function context(subtitle,cards)',
		"stable rail scroll helper")
	source=replaceOnce(source,'CategoryScrollKey="OwnedGarageRail:"..page','CategoryScrollKey=railScrollKey()',"stable rail key consumer")
	source=replaceOnce(source,
		'else view=context("Choose an equipped decoration location to style.",{}); view.EmptyMessage="CHOOSE AN EQUIPPED DECORATION LOCATION" end;',
		'else local emptyCards={}; if selectedDecorationAnchor and not placement then table.insert(emptyCards,{Id="InstallAsset",DisplayName="Install Asset",Image=icon("Decorations"),Footer="OPEN BUILD GARAGE",OnSelect=function() selectedDecorationItem=nil; page="BuildDecorations"; render(true) end}) end; local subtitle=not selectedDecorationAnchor and "Choose an equipped decoration location to style." or (not placement and "This location is empty. Install an asset before styling." or "This equipped asset has no editable colour channels."); view=context(subtitle,emptyCards); view.EmptyMessage=not selectedDecorationAnchor and "CHOOSE AN EQUIPPED DECORATION LOCATION" or (placement and "NO EDITABLE COLOUR CHANNELS" or "INSTALL AN ASSET TO STYLE THIS LOCATION") end;',
		"empty Style decoration route")
	assert(source:find(REVISION,1,true),"Projected V2.2 marker missing")
	assert(source:find('return "OwnedGarageRail:Structure"',1,true) and source:find('return "OwnedGarageRail:Decorations"',1,true),"Projected stable rail keys missing")
	assert(source:find('DisplayName="Install Asset"',1,true) and source:find('page="BuildDecorations"',1,true),"Projected empty-location route missing")
	compile(source,controller.Name.."_Projected")
end

local original=controller.Source
local oldRevision=config:GetAttribute("OwnedGarageRevision")
local oldRunId=config:GetAttribute("OwnedGarageInstallRunId")
local oldNavigationVersion=config:GetAttribute("OwnedGarageNavigationContractVersion")
local oldControllerRevision=controller:GetAttribute("OwnedGarageRevision")
local oldControllerRunId=controller:GetAttribute("OwnedGarageInstallRunId")
local ok,problem=pcall(function()
	if not sourceInstalled then controller.Source=source end
	assert(controller.Source:find(REVISION,1,true),"V2.2 source marker did not persist"); compile(controller.Source,controller.Name)
	config:SetAttribute("OwnedGarageRevision",REVISION); config:SetAttribute("OwnedGarageInstallRunId",RUN_ID); config:SetAttribute("OwnedGarageNavigationContractVersion",3); controller:SetAttribute("OwnedGarageRevision",REVISION); controller:SetAttribute("OwnedGarageInstallRunId",RUN_ID)
	assert(config:GetAttribute("OwnedGarageNavigationContractVersion")==3,"Navigation contract version did not persist")
end)
if not ok then pcall(function() controller.Source=original end); pcall(function() config:SetAttribute("OwnedGarageRevision",oldRevision); config:SetAttribute("OwnedGarageInstallRunId",oldRunId); config:SetAttribute("OwnedGarageNavigationContractVersion",oldNavigationVersion); controller:SetAttribute("OwnedGarageRevision",oldControllerRevision); controller:SetAttribute("OwnedGarageInstallRunId",oldControllerRunId) end); error(TAG.." INSTALL ROLLED BACK: "..tostring(problem)) end

print(TAG.." PASS sourceWrites="..(sourceInstalled and 0 or 1).." stableRailScroll=true emptyStyleRoute=BuildDecorations navigationContract=3 revision="..REVISION.." runId="..RUN_ID)
print(TAG.." READY: nested Build/Style pages retain their shared location-rail position, and empty Style decoration locations offer a shared-card route to Build Garage.")
