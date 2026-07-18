-- Neo Tokyo Racers - Canonical garage flow refinement V2.1
-- NTR_GARAGE_FLOW_REFINEMENT_V2_1
-- Run once in the Studio Edit Command Bar, then restart Play.
-- Narrow presentation/lifecycle follow-up to confirmed V2.

local MODE="INSTALL" -- INSTALL or AUDIT
local REVISION="NTR_GARAGE_FLOW_REFINEMENT_V2_1"
local PREFIX="[NTR Garage Flow Refinement V2.1]"
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local function need(parent,name,className)
	local object=parent:FindFirstChild(name); assert(object,parent:GetFullName().."."..name.." missing")
	if className then assert(object:IsA(className),object:GetFullName().." must be "..className) end
	return object
end
local function compile(name,source) local fn,err=loadstring(source,"="..name); assert(fn,name.." compile failed: "..tostring(err)) end
local function replaceOnce(source,before,after,label)
	local first,last=string.find(source,before,1,true); assert(first,"Missing source anchor: "..label)
	assert(not string.find(source,before,last+1,true),"Duplicate source anchor: "..label)
	return string.sub(source,1,first-1)..after..string.sub(source,last+1)
end

local kit=need(ReplicatedStorage,"NeoTokyoRacers","Folder")
local clientRoot=need(need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts"),"NeoTokyoRacersClient","Folder")
local uiRoot=need(need(clientRoot,"Controllers","Folder"),"UI","Folder")
local workspaceController=need(uiRoot,"GarageWorkspaceController","ModuleScript")
local applicationController=need(uiRoot,"ModuleShopUIController","ModuleScript")
local workspaceSource,applicationSource=workspaceController.Source,applicationController.Source

assert(string.find(workspaceSource,"NTR_GARAGE_FLOW_REFINEMENT_V2",1,true),"Confirmed V2 Workspace baseline missing; refresh the mirror/live source before another patch")
assert(string.find(applicationSource,"NTR_GARAGE_FLOW_REFINEMENT_V2",1,true),"Confirmed V2 application baseline missing; refresh the mirror/live source before another patch")
assert(string.find(applicationSource,"NTR_GARAGE_TRANSIENT_MODULE_PREVIEW_LIFECYCLE_V1",1,true),"Transient preview cleanup owner missing")
assert(not string.find(workspaceSource,REVISION,1,true) and not string.find(applicationSource,REVISION,1,true),"V2.1 is already installed; use MODE=AUDIT")

workspaceSource=replaceOnce(workspaceSource,
	[[local categoryLayout=Instance.new("UIListLayout"); categoryLayout.Padding=UDim.new(0,8); categoryLayout.Parent=self.CategoryList]],
	[[local categoryLayout=Instance.new("UIListLayout"); categoryLayout.Padding=UDim.new(0,8); categoryLayout.Parent=self.CategoryList; self.CategoryLayout=categoryLayout -- NTR_GARAGE_FLOW_REFINEMENT_V2_1]],
	"shared left-card layout owner")
workspaceSource=replaceOnce(workspaceSource,
	[[clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false
	self.Categories.BackgroundTransparency=context.LeftFloating and 1 or .12; local surface=self.Categories:FindFirstChild("SurfaceGradient"); if surface and surface:IsA("UIGradient") then surface.Enabled=not context.LeftFloating end]],
	[[clear(self.CategoryList); self.Categories.Visible=context.ShowLeft~=false
	self.Categories.BackgroundTransparency=context.LeftFloating and 1 or .12; local surface=self.Categories:FindFirstChild("SurfaceGradient"); if surface and surface:IsA("UIGradient") then surface.Enabled=not context.LeftFloating end; if self.CategoryLayout then self.CategoryLayout.HorizontalAlignment=context.LeftSharedCardSize and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left end]],
	"left-card shared centring")
workspaceSource=replaceOnce(workspaceSource,
	[[local cardHeight=context.LeftCardHeight or N("CustomiseCategoryCardHeight",118); local imageHeight=context.LeftCardImageHeight or N("CustomiseCategoryImageHeight",78)]],
	[[local cardHeight=context.LeftSharedCardSize and N("WorkspaceCardHeight",146) or (context.LeftCardHeight or N("CustomiseCategoryCardHeight",118)); local imageHeight=context.LeftSharedCardSize and N("ModuleCardImageHeight",104) or (context.LeftCardImageHeight or N("CustomiseCategoryImageHeight",78))]],
	"left-card shared dimensions")
workspaceSource=replaceOnce(workspaceSource,
	[[button=generated(Shared.ModuleCategoryCard(self.CategoryList,{DisplayName=item.Text or item.Id or "",Image=self:ResolveImage(item.ImageKey or item.Id,item.Image),Selected=item.Selected==true,Size=UDim2.new(1,0,0,cardHeight),ImageHeight=imageHeight,ImageZoom=item.ImageZoom or 1.04}))]],
	[[local cardSize=context.LeftSharedCardSize and UDim2.fromOffset(N("WorkspaceCardWidth",210),cardHeight) or UDim2.new(1,0,0,cardHeight); button=generated(Shared.ModuleCategoryCard(self.CategoryList,{DisplayName=item.Text or item.Id or "",Image=self:ResolveImage(item.ImageKey or item.Id,item.Image),Selected=item.Selected==true,Size=cardSize,ImageHeight=imageHeight,ImageZoom=item.ImageZoom or 1.04}))]],
	"left-card shared geometry")
workspaceSource="-- "..REVISION.."\n"..workspaceSource

applicationSource=replaceOnce(applicationSource,
	[[local function colourChannels(target) if target=="THRUST_COLOR" then return {"ThrustColor"} end; if target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end; if target=="ALL" then return {"Primary","Secondary","Detail"} end; return {"Primary","Secondary","Detail","Neon"} end]],
	[[local function colourChannels(target) if target=="THRUST_COLOR" then return {"ThrustColor"} end; if target=="Cockpit" then return {"Primary","Secondary","Detail","FrontLights","RearLights"} end; if target=="ALL" then return {"Primary","Secondary","Detail","Neon"} end; return {"Primary","Secondary","Detail","Neon"} end -- NTR_GARAGE_FLOW_REFINEMENT_V2_1]],
	"restore All neon colour tab")
applicationSource=replaceOnce(applicationSource,
	[[c.ShowLeft=true; c.LeftFloating=true; c.LeftCardMode=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78; c.LeftItems={{Id="BuildModules",Text="Build Modules",Image=navIcon("BuildModulesIcon"),Selected=true,OnSelect=function()]],
	[[c.ShowLeft=true; c.LeftFloating=true; c.LeftCardMode=true; c.LeftSharedCardSize=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("WorkspaceCardHeight")) or 146; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("ModuleCardImageHeight")) or 104; c.LeftItems={{Id="BuildModules",Text="Build Modules",Image=navIcon("BuildModulesIcon"),ImageZoom=.5,Selected=true,OnSelect=function()]],
	"Build sidebar shared card geometry")
applicationSource=replaceOnce(applicationSource,
	[[{Id="CustomiseModules",Text="Customise Modules",Image=navIcon("CustomiseModulesIcon"),Selected=false,OnSelect=function()]],
	[[{Id="CustomiseModules",Text="Customise Modules",Image=navIcon("CustomiseModulesIcon"),ImageZoom=.5,Selected=false,OnSelect=function()]],
	"Build sidebar customise artwork scale")
applicationSource=replaceOnce(applicationSource,
	[[c.LeftCardMode=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryCardHeight")) or 118; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("CustomiseCategoryImageHeight")) or 78; c.LeftItems={}; c.Cards={}]],
	[[c.LeftCardMode=true; c.LeftFloating=true; c.LeftSharedCardSize=true; c.LeftAlignCarouselBottom=true; c.LeftCardHeight=tonumber(replacementConfig:GetAttribute("WorkspaceCardHeight")) or 146; c.LeftCardImageHeight=tonumber(replacementConfig:GetAttribute("ModuleCardImageHeight")) or 104; c.LeftItems={}; c.Cards={}]],
	"floating Customise sidebar shared geometry")
applicationSource=replaceOnce(applicationSource,
	[[table.insert(c.LeftItems,{Id=id,Text=id=="THRUST_COLOR" and "Thrust" or art.DisplayName,ImageKey=art.TargetId,Image=art.Image,Selected=target==id,OnSelect=function() State.CustomizeTarget=id;]],
	[[table.insert(c.LeftItems,{Id=id,Text=id=="THRUST_COLOR" and "Thrust" or art.DisplayName,ImageKey=art.TargetId,Image=art.Image,ImageZoom=.5,Selected=target==id,OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget=id;]],
	"Customise rail transient cleanup and shared artwork scale")
applicationSource="-- "..REVISION.."\n"..applicationSource

compile("GarageWorkspaceController",workspaceSource); compile("ModuleShopUIController",applicationSource)
assert(#workspaceSource<199000,"GarageWorkspaceController projected Source exceeds safe Studio limit")
assert(#applicationSource<199000,"ModuleShopUIController projected Source exceeds safe Studio limit")

local function audit()
	local pass,fail=0,0; local function check(ok,message) if ok then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end end
	check(string.find(workspaceController.Source,REVISION,1,true)~=nil,"Workspace V2.1 owner installed")
	check(string.find(applicationController.Source,REVISION,1,true)~=nil,"application V2.1 owner installed")
	check(string.find(applicationController.Source,'if target=="ALL" then return {"Primary","Secondary","Detail","Neon"}',1,true)~=nil,"All Change Colour exposes Neon")
	check(string.find(applicationController.Source,"c.LeftSharedCardSize=true",1,true)~=nil,"sidebars use shared bottom-card geometry")
	check(string.find(applicationController.Source,"c.LeftFloating=true",1,true)~=nil,"Customise sidebar is floating")
	check(string.find(applicationController.Source,"OnSelect=function() clearTransientModulePreview(); State.CustomizeTarget=id",1,true)~=nil,"category navigation clears transient neon preview")
	check(string.find(workspaceController.Source,"HorizontalAlignment=context.LeftSharedCardSize",1,true)~=nil,"shared-size sidebar cards are centred")
	check(string.find(applicationController.Source,"State.PreviewNeonSlot=nil",1,true)~=nil,"existing neon cleanup owner retained")
	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail)); return fail==0
end

if MODE=="AUDIT" then assert(audit(),"Audit failed"); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")
local oldWorkspace,oldApplication=workspaceController.Source,applicationController.Source
local ok,err=pcall(function()
	workspaceController.Source=workspaceSource; applicationController.Source=applicationSource
	assert(audit(),"Post-install audit failed")
end)
if not ok then workspaceController.Source=oldWorkspace; applicationController.Source=oldApplication; error("Garage flow refinement V2.1 rolled back: "..tostring(err)) end
print(PREFIX.." INSTALL COMPLETE - restart Play and verify All/Change Colour Neon, both shared-size floating rails, and neon preview cleanup across every category/page boundary.")
