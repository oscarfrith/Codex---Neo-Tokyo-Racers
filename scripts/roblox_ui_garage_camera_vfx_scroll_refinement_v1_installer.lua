-- Neo Tokyo Racers - Garage camera, preview VFX, and scroll refinement V1
-- NTR_GARAGE_CAMERA_VFX_SCROLL_REFINEMENT_V1
-- Run once in the Studio Edit Command Bar, then restart Play.
-- Requires the confirmed NTR_GARAGE_CATEGORY_CAMERA_ANGLES_V1 live baseline.

local MODE="INSTALL" -- INSTALL or AUDIT
local REVISION="NTR_GARAGE_CAMERA_VFX_SCROLL_REFINEMENT_V1"
local PREFIX="[NTR Garage Camera/VFX/Scroll Refinement V1]"

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local function need(parent,name,className)
	local object=parent:FindFirstChild(name)
	assert(object,parent:GetFullName().."."..name.." missing")
	if className then assert(object:IsA(className),object:GetFullName().." must be "..className) end
	return object
end

local function replaceOnce(source,before,after,label)
	local first,last=string.find(source,before,1,true)
	assert(first,"Missing source anchor: "..label)
	assert(not string.find(source,before,last+1,true),"Duplicate source anchor: "..label)
	return string.sub(source,1,first-1)..after..string.sub(source,last+1)
end

local function compile(name,source)
	local fn,err=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(err))
end

local kit=need(ReplicatedStorage,"NeoTokyoRacers","Folder")
local config=need(need(need(kit,"Config","Folder"),"UI","Folder"),"GarageReplacement","Folder")
local clientRoot=need(need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts"),"NeoTokyoRacersClient","Folder")
local controllers=need(clientRoot,"Controllers","Folder")
local previewRoot=need(controllers,"Preview","Folder")
local uiRoot=need(controllers,"UI","Folder")
local cameraModule=need(previewRoot,"PreviewCameraController","ModuleScript")
local thrustScript=need(previewRoot,"ThrustPreviewController_Active","LocalScript")
local workspaceModule=need(uiRoot,"GarageWorkspaceController","ModuleScript")
local browserModule=need(uiRoot,"GarageBrowserController","ModuleScript")
local applicationModule=need(uiRoot,"ModuleShopUIController","ModuleScript")

local originals={Camera=cameraModule.Source,Thrust=thrustScript.Source,ThrustDisabled=thrustScript.Disabled,Workspace=workspaceModule.Source,Browser=browserModule.Source,Application=applicationModule.Source}
local requiredCameraBaseline="NTR_GARAGE_CATEGORY_CAMERA_ANGLES_V1"

local defaults={
	PreviewCameraYawOffsetDegrees=-45,
	PreviewIdleHoverIntensity=1,
	PreviewThrustThrottleIntensity=1,
	PreviewThrustBoostIntensity=1,
	PreviewThrustStabiliserIntensity=1,
	PreviewThrustHoverIntensity=1,
}

local function markerCount()
	local count=0
	for _,source in ipairs({originals.Camera,originals.Thrust,originals.Workspace,originals.Browser,originals.Application}) do if string.find(source,REVISION,1,true) then count+=1 end end
	return count
end

local function audit()
	local camera,thrust,workspace,browser,application=cameraModule.Source,thrustScript.Source,workspaceModule.Source,browserModule.Source,applicationModule.Source
	local pass,fail=0,0
	local function check(ok,message)
		if ok then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end
	end
	for name,source in pairs({Camera=camera,Thrust=thrust,Workspace=workspace,Browser=browser,Application=application}) do check(string.find(source,REVISION,1,true)~=nil,name.." revision marker present") end
	check(string.find(camera,'number("PreviewCameraYawOffsetDegrees",-45)',1,true)~=nil,"global configurable anti-clockwise camera offset installed")
	check(string.find(thrust,'cachedPreviewMode=="ThrustColour"',1,true)~=nil,"preview VFX has explicit idle and thrust-colour modes")
	check(string.find(thrust,'Throttle=0,Boost=0,Drift=0',1,true)~=nil,"normal preview excludes acceleration, boost, and stabiliser VFX")
	check(string.find(application,'root:SetAttribute("PreviewVFXMode",mode)',1,true)~=nil,"canonical application publishes preview VFX mode")
	check(string.find(workspace,"WorkspaceScrollMemory",1,true)~=nil and string.find(workspace,"QueueScrollRestore",1,true)~=nil,"workspace carousel and rail scroll memory installed")
	check(string.find(browser,"BrowserScrollMemory",1,true)~=nil and string.find(browser,"QueueScrollRestore",1,true)~=nil,"browser carousel scroll memory installed")
	check(string.find(application,'CategoryScrollKey="CustomiseRail"',1,true)~=nil,"customise rail uses a stable scroll key")
	check(typeof(config:GetAttribute("PreviewCameraYawOffsetDegrees"))=="number" and typeof(config:GetAttribute("PreviewIdleHoverIntensity"))=="number","camera and VFX tuning attributes exist")
	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail))
	return fail==0
end

local installed=markerCount()
if MODE=="AUDIT" then assert(installed==5,"Expected all five revision markers; found "..tostring(installed)); assert(audit(),"Audit failed"); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")
if installed==5 then assert(audit(),"Existing installation audit failed"); print(PREFIX.." ALREADY INSTALLED"); return end
assert(installed==0,"Partial prior installation detected ("..tostring(installed).."/5 markers). Stop and refresh the mirror/live source before retrying.")
assert(string.find(originals.Camera,requiredCameraBaseline,1,true),"Confirmed category-camera V1 baseline missing. Run the prior camera installer first; this installer will not patch a stale camera owner.")

local camera=originals.Camera
camera=replaceOnce(camera,
	[[return math.rad(number(attribute,fallback))]],
	[[return math.rad(number(attribute,fallback)+number("PreviewCameraYawOffsetDegrees",-45))]],
	"global preview camera yaw offset")
camera="-- "..REVISION.."\n"..camera

local thrust=originals.Thrust
thrust=replaceOnce(thrust,
	[[local cachedPreviewRoot,cachedPreviewVehicle,cachedPreviewColor,cachedPreviewForce]],
	[[local cachedPreviewRoot,cachedPreviewVehicle,cachedPreviewColor,cachedPreviewForce,cachedPreviewMode]],
	"cached preview VFX mode")
thrust=replaceOnce(thrust,
	[[local root=getPreviewRoot(); local vehicle=getPreviewVehicle(root); local color=root and (root:GetAttribute("ThrustColor") or Color3.new(1,1,1)); local force=root and root:GetAttribute("ForceThrustPreview")==true
	if root~=cachedPreviewRoot or vehicle~=cachedPreviewVehicle or color~=cachedPreviewColor or force~=cachedPreviewForce then cachedPreviewRoot,cachedPreviewVehicle,cachedPreviewColor,cachedPreviewForce=root,vehicle,color,force; applyThrustOnly(root,color or Color3.new(1,1,1),force and true or nil) end]],
	[[local root=getPreviewRoot(); local vehicle=getPreviewVehicle(root); local color=root and (root:GetAttribute("ThrustColor") or Color3.new(1,1,1)); local force=root and root:GetAttribute("ForceThrustPreview")==true; local mode=root and tostring(root:GetAttribute("PreviewVFXMode") or "Idle") or "Idle"
	if root~=cachedPreviewRoot or vehicle~=cachedPreviewVehicle or color~=cachedPreviewColor or force~=cachedPreviewForce or mode~=cachedPreviewMode then cachedPreviewRoot,cachedPreviewVehicle,cachedPreviewColor,cachedPreviewForce,cachedPreviewMode=root,vehicle,color,force,mode; applyThrustOnly(root,color or Color3.new(1,1,1),nil) end]],
	"preview VFX mode discovery")
thrust=replaceOnce(thrust,
	[[if previewController and cachedPreviewForce then previewController:Update(dt,{Throttle=1,Boost=1,Drift=1,DriftLeft=1,DriftRight=1,HoverDust=0,Brake=0}) end]],
	[[if previewController and cachedPreviewForce then
		if cachedPreviewMode=="ThrustColour" then previewController:Update(dt,{Throttle=number("PreviewThrustThrottleIntensity",1),Boost=number("PreviewThrustBoostIntensity",1),Drift=number("PreviewThrustStabiliserIntensity",1),DriftLeft=number("PreviewThrustStabiliserIntensity",1),DriftRight=number("PreviewThrustStabiliserIntensity",1),HoverDust=number("PreviewThrustHoverIntensity",1),Brake=0})
		else previewController:Update(dt,{Throttle=0,Boost=0,Drift=0,DriftLeft=0,DriftRight=0,HoverDust=number("PreviewIdleHoverIntensity",1),Brake=0}) end
	end]],
	"idle versus thrust-colour VFX state")
thrust="-- "..REVISION.."\n"..thrust

local workspace=originals.Workspace
local workspaceScroll=[[
-- WorkspaceScrollMemory preserves user position across card rerenders without sharing positions between unrelated views.
function WorkspaceUI:CaptureScroll()
	self.ScrollMemory=self.ScrollMemory or {Carousel={},Category={}}; local context=self.Context; if not context then return end
	if context.CarouselScrollKey then self.ScrollMemory.Carousel[context.CarouselScrollKey]=self.Scroller.CanvasPosition.X end
	if context.CategoryScrollKey then self.ScrollMemory.Category[context.CategoryScrollKey]=self.CategoryList.CanvasPosition.Y end
end
function WorkspaceUI:QueueScrollRestore(context)
	task.defer(function()
		RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait(); if not (self.Root.Visible and self.Context==context) then return end
		self.ScrollMemory=self.ScrollMemory or {Carousel={},Category={}}; self:UpdateCarousel(); self:UpdateCategoryArrows()
		local x=context.CarouselScrollKey and self.ScrollMemory.Carousel[context.CarouselScrollKey]; if x then local maximum=math.max(0,self.Scroller.AbsoluteCanvasSize.X-self.Scroller.AbsoluteWindowSize.X); self.Scroller.CanvasPosition=Vector2.new(math.clamp(x,0,maximum),0) end
		local y=context.CategoryScrollKey and self.ScrollMemory.Category[context.CategoryScrollKey]; if y then local maximum=math.max(0,self.CategoryList.AbsoluteCanvasSize.Y-self.CategoryList.AbsoluteWindowSize.Y); self.CategoryList.CanvasPosition=Vector2.new(0,math.clamp(y,0,maximum)) end
		self:RefreshCarouselArrows(); self:UpdateCategoryArrows()
	end)
end
]]
workspace=replaceOnce(workspace,
	[[function WorkspaceUI:Show(context)]],
	workspaceScroll..[[function WorkspaceUI:Show(context)]],
	"workspace keyed scroll owner")
workspace=replaceOnce(workspace,
	[[function WorkspaceUI:Show(context)
	self:DisconnectDynamic(); self.Context=context]],
	[[function WorkspaceUI:Show(context)
	self:CaptureScroll(); self:DisconnectDynamic(); self.Context=context]],
	"workspace capture before rerender")
workspace=replaceOnce(workspace,
	[[self:RenderLeft(context); self:RenderStats(context); self:RenderEconomy(context); local selectedCard; if context.ColorChannels then self:RenderPaint(context) else selectedCard=self:RenderCards(context) end; self:Layout(); self:Audit(selectedCard)]],
	[[self:RenderLeft(context); self:RenderStats(context); self:RenderEconomy(context); local selectedCard; if context.ColorChannels then self:RenderPaint(context) else selectedCard=self:RenderCards(context) end; self:Layout(); self:QueueScrollRestore(context); self:Audit(selectedCard)]],
	"workspace restore after rerender")
workspace=replaceOnce(workspace,
	[[function WorkspaceUI:Hide()
	self:DisconnectDynamic();]],
	[[function WorkspaceUI:Hide()
	self:CaptureScroll(); self:DisconnectDynamic();]],
	"workspace capture on hide")
workspace="-- "..REVISION.."\n"..workspace

local browser=originals.Browser
local browserScroll=[[
-- BrowserScrollMemory preserves the vehicle carousel when selecting a visible card.
function Browser:CaptureScroll()
	self.ScrollMemory=self.ScrollMemory or {}; local context=self.Context; if context and context.CarouselScrollKey then self.ScrollMemory[context.CarouselScrollKey]=self.Scroller.CanvasPosition.X end
end
function Browser:QueueScrollRestore(context)
	task.defer(function()
		RunService.Heartbeat:Wait(); RunService.Heartbeat:Wait(); if not (self.Root.Visible and self.Context==context) then return end
		self:UpdateCarousel(); local x=context.CarouselScrollKey and self.ScrollMemory and self.ScrollMemory[context.CarouselScrollKey]; if x then local maximum=math.max(0,self.Scroller.AbsoluteCanvasSize.X-self.Scroller.AbsoluteWindowSize.X); self.Scroller.CanvasPosition=Vector2.new(math.clamp(x,0,maximum),0) end; self:RefreshCarouselArrows()
	end)
end
]]
browser=replaceOnce(browser,
	[[function Browser:Show(context)]],
	browserScroll..[[function Browser:Show(context)]],
	"browser keyed scroll owner")
browser=replaceOnce(browser,
	[[function Browser:Show(context)
	self.Context=context;]],
	[[function Browser:Show(context)
	self:CaptureScroll(); self.Context=context;]],
	"browser capture before rerender")
browser=replaceOnce(browser,
	[[self:RenderStats(selected); self:RenderEconomy(context); task.defer(function() self:Layout(); self:QueueCarouselUpdate() end)]],
	[[self:RenderStats(selected); self:RenderEconomy(context); task.defer(function() self:Layout(); self:QueueCarouselUpdate(); self:QueueScrollRestore(context) end)]],
	"browser restore after rerender")
browser=replaceOnce(browser,
	[[function Browser:Hide()
	self.Root.Visible=false;]],
	[[function Browser:Hide()
	self:CaptureScroll(); self.Root.Visible=false;]],
	"browser capture on hide")
browser="-- "..REVISION.."\n"..browser

local application=originals.Application
application=replaceOnce(application,
	[[local function buildPreview()
	local before=InstancePreview.ProfileFingerprint(State.Profile); State.GarageCameraActive=true
	local vehicle,err=PreviewVehicle.Build({State=State,CategoriesRoot=categoriesRoot,Preview=preview,Workspace=Workspace})
	if before~=InstancePreview.ProfileFingerprint(State.Profile) then error("[NTR Module Instance Preview] Read-only invariant failed: preview mutated the client profile") end
	if not vehicle then warn("[NTR Canonical Garage] Preview: "..tostring(err)) end
end]],
	[[local function buildPreview()
	local before=InstancePreview.ProfileFingerprint(State.Profile); State.GarageCameraActive=true
	local vehicle,err=PreviewVehicle.Build({State=State,CategoriesRoot=categoriesRoot,Preview=preview,Workspace=Workspace})
	if preview.Root then preview.Root:SetAttribute("PreviewVFXMode",State.PreviewVFXMode or "Idle") end
	if before~=InstancePreview.ProfileFingerprint(State.Profile) then error("[NTR Module Instance Preview] Read-only invariant failed: preview mutated the client profile") end
	if not vehicle then warn("[NTR Canonical Garage] Preview: "..tostring(err)) end
end
local function setPreviewVFXMode(mode) State.PreviewVFXMode=mode; local root=preview.Root; if root and root.Parent then root:SetAttribute("PreviewVFXMode",mode) end end]],
	"canonical preview VFX mode publisher")
application=replaceOnce(application,
	[[local function common(title) local owned,cap=capacity(); return]],
	[[local function common(title) setPreviewVFXMode(State.Stage=="Customise" and State.CustomizeTarget=="THRUST_COLOR" and "ThrustColour" or "Idle"); local owned,cap=capacity(); return]],
	"workspace page VFX mode")
application=replaceOnce(application,
	[[State.Stage="Browser"; hideAll();]],
	[[State.Stage="Browser"; setPreviewVFXMode("Idle"); hideAll();]],
	"browser idle VFX mode")
application=replaceOnce(application,
	[[browser:Show({Mode=State.ShopMode,State=State,Category=browserCategory(),]],
	[[browser:Show({Mode=State.ShopMode,State=State,CarouselScrollKey="Browser|"..tostring(State.ShopMode).."|"..tostring(State.BrowseAll and "ALL" or State.CategoryId),Category=browserCategory(),]],
	"browser carousel scroll key")
application=replaceOnce(application,
	[[local c=common("Garage"); c.Subtitle=]],
	[[local c=common("Garage"); c.CarouselScrollKey="Hub"; c.Subtitle=]],
	"hub carousel scroll key")
application=replaceOnce(application,
	[[local c=common("Build Modules"); c.Subtitle=]],
	[[local c=common("Build Modules"); c.CarouselScrollKey="Build|"..tostring(State.ModuleMode).."|"..tostring(State.SelectedSlot).."|"..tostring(State.ModuleOptionMode); c.CategoryScrollKey="BuildRail"; c.Subtitle=]],
	"build scroll keys")
application=replaceOnce(application,
	[[local c=common("Customise"); c.Subtitle=]],
	[[local c=common("Customise"); c.CarouselScrollKey="Customise|"..tostring(target).."|"..tostring(State.CustomizeMode); c.CategoryScrollKey="CustomiseRail"; c.Subtitle=]],
	"customise scroll keys")
application="-- "..REVISION.."\n"..application

compile("PreviewCameraController",camera)
compile("ThrustPreviewController_Active",thrust)
compile("GarageWorkspaceController",workspace)
compile("GarageBrowserController",browser)
compile("ModuleShopUIController",application)
for name,source in pairs({Camera=camera,Thrust=thrust,Workspace=workspace,Browser=browser,Application=application}) do assert(#source<199000,name.." projected Source exceeds Studio's safe limit") end

local oldAttributes={}
for name in pairs(defaults) do local value=config:GetAttribute(name); oldAttributes[name]={Had=value~=nil,Value=value} end

local ok,err=pcall(function()
	for name,value in pairs(defaults) do if config:GetAttribute(name)==nil then config:SetAttribute(name,value) end end
	cameraModule.Source=camera
	thrustScript.Disabled=true; thrustScript.Source=thrust
	workspaceModule.Source=workspace
	browserModule.Source=browser
	applicationModule.Source=application
	thrustScript.Disabled=false
	assert(audit(),"Post-install audit failed")
end)
if not ok then
	cameraModule.Source=originals.Camera
	thrustScript.Disabled=true; thrustScript.Source=originals.Thrust; thrustScript.Disabled=originals.ThrustDisabled
	workspaceModule.Source=originals.Workspace
	browserModule.Source=originals.Browser
	applicationModule.Source=originals.Application
	for name,record in pairs(oldAttributes) do config:SetAttribute(name,record.Had and record.Value or nil) end
	error("Garage camera/VFX/scroll refinement rolled back: "..tostring(err))
end

print(PREFIX.." INSTALL COMPLETE")
print(PREFIX.." Restart Play and verify: every preset camera shifted 45 degrees anti-clockwise; normal previews show idle engine + hover only; thrust-colour editing shows full thrust VFX; horizontal and vertical menu positions survive card selection rerenders.")
