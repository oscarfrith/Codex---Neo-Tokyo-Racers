-- Neo Tokyo Racers - Canonical garage category camera angles V1
-- NTR_GARAGE_CATEGORY_CAMERA_ANGLES_V1
-- Run once in the Studio Edit Command Bar, then restart Play.
-- Reuses the canonical preview camera owner and its existing smooth interpolation/input.

local MODE="INSTALL" -- INSTALL or AUDIT
local REVISION="NTR_GARAGE_CATEGORY_CAMERA_ANGLES_V1"
local PREFIX="[NTR Garage Category Camera Angles V1]"

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
local applicationModule=need(uiRoot,"ModuleShopUIController","ModuleScript")

local defaults={
	PreviewCameraFront45YawDegrees=135,
	PreviewCameraSideYawDegrees=90,
	PreviewCameraRear45YawDegrees=45,
	PreviewCameraRearYawDegrees=0,
	PreviewCameraFrontYawDegrees=180,
}

local originals={Camera=cameraModule.Source,Application=applicationModule.Source}

local function markerCount()
	local count=0
	for _,source in pairs(originals) do if string.find(source,REVISION,1,true) then count+=1 end end
	return count
end

local function audit()
	local camera,application=cameraModule.Source,applicationModule.Source
	local pass,fail=0,0
	local function check(ok,message)
		if ok then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end
	end
	check(string.find(camera,REVISION,1,true)~=nil,"shared preview camera mapping installed")
	check(string.find(application,REVISION,1,true)~=nil,"canonical navigation handoff installed")
	check(string.find(camera,'ALL="Front45"',1,true) and string.find(camera,'Cockpit="Front45"',1,true) and string.find(camera,'THRUST_COLOR="Front45"',1,true),"all, cockpit, and thrust use front 45")
	check(string.find(camera,'Stabilisers="Side"',1,true) and string.find(camera,'SidePods="Side"',1,true),"stabilisers and side pods use side profile")
	check(string.find(camera,'Engine2="Rear45"',1,true) and string.find(camera,'RearSpoiler="Rear45"',1,true),"rear engine and spoiler use rear 45")
	check(string.find(camera,'Boost="Rear"',1,true) and string.find(camera,'RearBumper="Rear"',1,true),"boost and rear bumper use direct rear")
	check(string.find(camera,'FrontBumper="Front"',1,true),"front bumper uses direct front")
	check(string.find(application,'State.CameraSection=id',1,true) and string.find(application,'State.CameraSection~=target',1,true),"category changes request their shared camera section")
	check(string.find(application,'State.ModuleMode=="Slots" and State.CameraSection~="ALL"',1,true),"module overview returns to front 45")
	check(typeof(config:GetAttribute("PreviewCameraFront45YawDegrees"))=="number" and typeof(config:GetAttribute("PreviewCameraRear45YawDegrees"))=="number","angle tuning attributes exist")
	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail))
	return fail==0
end

local installed=markerCount()
if MODE=="AUDIT" then assert(installed==2,"Expected both revision markers; found "..tostring(installed)); assert(audit(),"Audit failed"); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")
if installed==2 then assert(audit(),"Existing installation audit failed"); print(PREFIX.." ALREADY INSTALLED"); return end
assert(installed==0,"Partial prior installation detected ("..tostring(installed).."/2 markers). Refresh the mirror/live source before retrying.")

local camera=originals.Camera
camera=replaceOnce(camera,
	[[PreviewCameraController.DefaultFocus=Vector3.new(860,104,-1749); PreviewCameraController.DefaultYaw=math.rad(180); PreviewCameraController.DefaultPitch=math.rad(-12); PreviewCameraController.DefaultDistance=24.3; PreviewCameraController.SectionDistance=33
PreviewCameraController.YawBySlot={FrontBumper=math.rad(180),RearBumper=0,RearSpoiler=0,Boost=0,Engine1=math.rad(135),Engine2=math.rad(45),SidePods=math.rad(90),Stabilisers=math.rad(90)}]],
	[[PreviewCameraController.DefaultFocus=Vector3.new(860,104,-1749); PreviewCameraController.DefaultYaw=math.rad(135); PreviewCameraController.DefaultPitch=math.rad(-12); PreviewCameraController.DefaultDistance=24.3; PreviewCameraController.SectionDistance=33
PreviewCameraController.ViewBySection={ALL="Front45",Cockpit="Front45",THRUST_COLOR="Front45",Engine1="Front45",Stabilisers="Side",SidePods="Side",Engine2="Rear45",RearSpoiler="Rear45",Boost="Rear",RearBumper="Rear",FrontBumper="Front"}
PreviewCameraController.YawAttributeByView={Front45="PreviewCameraFront45YawDegrees",Side="PreviewCameraSideYawDegrees",Rear45="PreviewCameraRear45YawDegrees",Rear="PreviewCameraRearYawDegrees",Front="PreviewCameraFrontYawDegrees"}
PreviewCameraController.YawFallbackByView={Front45=135,Side=90,Rear45=45,Rear=0,Front=180}]],
	"camera semantic view map")
camera=replaceOnce(camera,
	[[function PreviewCameraController.SetCameraSection(state,slotId) transition(state,{Yaw=PreviewCameraController.YawBySlot[slotId] or PreviewCameraController.DefaultYaw,Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.SectionDistance}) end
function PreviewCameraController.Reset(state,focus) transition(state,{Focus=focus or state.TargetFocus or PreviewCameraController.DefaultFocus,Yaw=PreviewCameraController.DefaultYaw,Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.DefaultDistance}) end]],
	[[local function sectionYaw(slotId)
	local view=PreviewCameraController.ViewBySection[slotId] or "Front45"; local attribute=PreviewCameraController.YawAttributeByView[view]; local fallback=PreviewCameraController.YawFallbackByView[view] or 135
	return math.rad(number(attribute,fallback))
end
function PreviewCameraController.SetCameraSection(state,slotId) state.CameraSection=slotId or "ALL"; transition(state,{Yaw=sectionYaw(slotId),Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.SectionDistance}) end
function PreviewCameraController.Reset(state,focus) state.CameraSection="ALL"; transition(state,{Focus=focus or state.TargetFocus or PreviewCameraController.DefaultFocus,Yaw=sectionYaw("ALL"),Pitch=PreviewCameraController.DefaultPitch,Distance=PreviewCameraController.DefaultDistance}) end]],
	"camera semantic view resolver")
camera="-- "..REVISION.."\n"..camera

local application=originals.Application
application=replaceOnce(application,
	[[local function section(id) PreviewCamera.SetCameraSection(State,id) end]],
	[[local function section(id) State.CameraSection=id or "ALL"; PreviewCamera.SetCameraSection(State,id or "ALL") end]],
	"camera section state ownership")
application=replaceOnce(application,
	[[renderPaint=function()
	State.Stage="Paint";]],
	[[renderPaint=function()
	if State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Paint";]],
	"paint default view")
application=replaceOnce(application,
	[[renderHub=function()
	State.Stage="Hub";]],
	[[renderHub=function()
	if State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Hub";]],
	"hub default view")
application=replaceOnce(application,
	[[renderBuild=function()
	State.Stage="Build"; browser:Hide();]],
	[[renderBuild=function()
	if State.ModuleMode=="Slots" and State.CameraSection~="ALL" then section("ALL") end
	State.Stage="Build"; browser:Hide();]],
	"build overview default view")
application=replaceOnce(application,
	[[State.Stage="Customise"; local target=State.CustomizeTarget; local actionIconScale=]],
	[[State.Stage="Customise"; local target=State.CustomizeTarget; if State.CameraSection~=target then section(target) end; local actionIconScale=]],
	"customise target view handoff")
application="-- "..REVISION.."\n"..application

compile("PreviewCameraController",camera)
compile("ModuleShopUIController",application)
assert(#camera<199000 and #application<199000,"Projected ModuleScript source exceeds Studio's safe Source limit")

local oldAttributes={}
for name in pairs(defaults) do local value=config:GetAttribute(name); oldAttributes[name]={Had=value~=nil,Value=value} end

local ok,err=pcall(function()
	for name,value in pairs(defaults) do if config:GetAttribute(name)==nil then config:SetAttribute(name,value) end end
	cameraModule.Source=camera
	applicationModule.Source=application
	assert(audit(),"Post-install audit failed")
end)
if not ok then
	cameraModule.Source=originals.Camera
	applicationModule.Source=originals.Application
	for name,record in pairs(oldAttributes) do config:SetAttribute(name,record.Had and record.Value or nil) end
	error("Garage category camera angle install rolled back: "..tostring(err))
end

print(PREFIX.." INSTALL COMPLETE")
print(PREFIX.." Restart Play and verify: front 45 default/all/cockpit/thrust/front engine; side stabilisers/side pods; rear 45 rear engine/spoiler; direct rear boost/rear bumper; direct front front bumper.")
