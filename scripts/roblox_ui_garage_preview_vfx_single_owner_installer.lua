-- Neo Tokyo Racers - Garage preview VFX single-owner repair
-- NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1
-- Run once in the Studio Edit Command Bar, then restart Play.
--
-- Root cause repaired here:
--   1. CachedThrustVisualRuntime historically treated ForceThrustPreview as
--      accelerating + boosting + drifting at the same time.
--   2. ThrustPreviewController also attached its own VehicleVFXController,
--      duplicating the cached runtime's template hosts.
--
-- After this install CachedThrustVisualRuntime is the only preview template
-- owner. PreviewVFXMode selects Idle or ThrustColour without duplicating VFX.

local MODE="INSTALL" -- INSTALL or AUDIT
local REVISION="NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1"
local PREFIX="[NTR Garage Preview VFX Single Owner V1]"

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

local function countPlain(source,needle)
	local count,index=0,1
	while true do
		local first,last=string.find(source,needle,index,true)
		if not first then return count end
		count+=1; index=last+1
	end
end

local function compile(name,source)
	local fn,err=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(err))
end

local kit=need(ReplicatedStorage,"NeoTokyoRacers","Folder")
local sharedModules=need(need(kit,"Shared","Folder"),"Modules","Folder")
local cachedRuntime=need(need(need(sharedModules,"Client","Folder"),"Visuals","Folder"),"CachedThrustVisualRuntime","ModuleScript")

local clientRoot=need(need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts"),"NeoTokyoRacersClient","Folder")
local previewFolder=need(need(clientRoot,"Controllers","Folder"),"Preview","Folder")
local thrustScript=need(previewFolder,"ThrustPreviewController_Active","LocalScript")
local presentationScript=need(previewFolder,"GaragePreviewPresentationController_Active","LocalScript")

local originals={
	Cached=cachedRuntime.Source,
	Thrust=thrustScript.Source,
	ThrustDisabled=thrustScript.Disabled,
	Presentation=presentationScript.Source,
	PresentationDisabled=presentationScript.Disabled,
}

local function audit()
	local cached,thrust,presentation=cachedRuntime.Source,thrustScript.Source,presentationScript.Source
	local pass,fail=0,0
	local function check(ok,message)
		if ok then pass+=1; print(PREFIX.." PASS - "..message)
		else fail+=1; warn(PREFIX.." FAIL - "..message) end
	end

	check(string.find(cached,REVISION,1,true)~=nil,"cached runtime revision installed")
	check(string.find(thrust,REVISION,1,true)~=nil,"preview colour bridge revision installed")
	check(string.find(presentation,REVISION,1,true)~=nil,"presentation revision installed")
	check(string.find(cached,'local mode=tostring(readAttr(cache,"PreviewVFXMode") or "Idle")',1,true)~=nil,"cached runtime reads explicit preview mode")
	check(string.find(cached,'local full=mode=="ThrustColour"',1,true)~=nil,"full VFX are limited to thrust-colour mode")
	check(string.find(cached,"if preview and forcePreview then",1,true)==nil,"legacy all-effects ForceThrustPreview branch removed")
	check(string.find(cached,'GetAttributeChangedSignal("PreviewVFXMode")',1,true)~=nil,"mode changes invalidate cached VFX state")
	check(countPlain(cached,"vfxControllerModule.Attach(cache.Model, templates")==1,"cached runtime contains exactly one template attachment path")
	check(string.find(thrust,"controllerModule.Attach(vehicle,templates",1,true)==nil,"preview bridge cannot attach duplicate template VFX")
	check(string.find(thrust,"previewController:Update",1,true)==nil,"preview bridge cannot drive a second VFX controller")
	check(string.find(thrust,"object.Enabled=full",1,true)==nil,"preview bridge no longer competes for effect enabled state")
	check(string.find(presentation,'SetAttribute("ForceThrustPreview",false)',1,true)~=nil,"presentation keeps legacy all-effects flag disabled")
	check(string.find(presentation,'GetAttribute("PreviewVFXMode")==nil',1,true)~=nil,"presentation seeds idle mode without overwriting active thrust mode")
	check(not thrustScript.Disabled,"preview colour/input bridge remains enabled")
	check(not presentationScript.Disabled,"garage presentation owner remains enabled")

	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail))
	return fail==0
end

local installed={
	Cached=string.find(originals.Cached,REVISION,1,true)~=nil,
	Thrust=string.find(originals.Thrust,REVISION,1,true)~=nil,
	Presentation=string.find(originals.Presentation,REVISION,1,true)~=nil,
}
local installedCount=(installed.Cached and 1 or 0)+(installed.Thrust and 1 or 0)+(installed.Presentation and 1 or 0)

if MODE=="AUDIT" then
	assert(installedCount==3,"Single-owner repair is not fully installed ("..tostring(installedCount).."/3 markers)")
	assert(audit(),"Audit failed")
	return
end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")
if installedCount==3 then assert(audit(),"Existing installation audit failed"); print(PREFIX.." ALREADY INSTALLED"); return end
assert(installedCount==0,"Partial prior installation detected ("..tostring(installedCount).."/3). Refresh the mirror/live source before retrying.")

assert(string.find(originals.Cached,"local function runtimeState(cache)",1,true),"Cached thrust runtime baseline missing")
assert(string.find(originals.Thrust,"NTR_GARAGE_CAMERA_VFX_REFINEMENT_V1_1",1,true),"Confirmed V1.1 preview-VFX baseline missing")
assert(string.find(originals.Presentation,"NTR_GARAGE_PREVIEW_PRESENTATION_V1",1,true),"Confirmed garage presentation baseline missing")

local cached=originals.Cached
cached=replaceOnce(cached,
[[	if preview and forcePreview then
		return {
			Driving = true,
			ForcePreview = true,
			Accelerating = true,
			Boosting = true,
			DriftLeft = true,
			DriftRight = true,
			AnyDrift = true,
		}
	end]],
[[	if preview then
		-- PreviewVFXMode is the only garage VFX state contract. The legacy
		-- ForceThrustPreview flag must never turn every effect on in a preview.
		local mode=tostring(readAttr(cache,"PreviewVFXMode") or "Idle")
		local full=mode=="ThrustColour"
		return {
			Driving=true,
			ForcePreview=false,
			Accelerating=full,
			Boosting=full,
			DriftLeft=full,
			DriftRight=full,
			AnyDrift=full,
		}
	end]],
	"preview state no longer aliases ForceThrustPreview to every effect")
cached=replaceOnce(cached,
[[		table.insert(cache.Connections, controlRoot:GetAttributeChangedSignal("ForceThrustPreview"):Connect(function()
			cache.LastStateKey = nil
		end))]],
[[		table.insert(cache.Connections, controlRoot:GetAttributeChangedSignal("ForceThrustPreview"):Connect(function()
			cache.LastStateKey = nil
		end))
		table.insert(cache.Connections, controlRoot:GetAttributeChangedSignal("PreviewVFXMode"):Connect(function()
			cache.LastStateKey = nil
		end))]],
	"preview mode invalidation signal")
cached="-- "..REVISION.."\n"..cached

local thrust=originals.Thrust
thrust=replaceOnce(thrust,
[[	if previewVehicle~=vehicle then if previewController then previewController:Destroy() end; previewController=nil; previewVehicle=vehicle end; if force and vehicle and not previewController and controllerModule then previewController=controllerModule.Attach(vehicle,templates,UserInputService.TouchEnabled) elseif not force and previewController then previewController:Destroy(); previewController=nil end]],
[[	-- CachedThrustVisualRuntime is the single template-VFX owner. This bridge
	-- deliberately never attaches a second VehicleVFXController.
	if previewController then previewController:Destroy(); previewController=nil end
	previewVehicle=vehicle]],
	"remove duplicate preview template attachment")

local updateStart=string.find(thrust,"\tif previewController and cachedPreviewForce then",1,true)
assert(updateStart,"Missing source anchor: duplicate preview controller update")
local updateEnd=string.find(thrust,"\nend)",updateStart,true)
assert(updateEnd,"Missing source boundary: duplicate preview controller update")
local updateBlock=string.sub(thrust,updateStart,updateEnd-1)
assert(string.find(updateBlock,"previewController:Update",1,true),"Unexpected preview update block shape")
thrust=replaceOnce(thrust,updateBlock,"\t-- Template VFX state is updated only by CachedThrustVisualRuntime.","remove duplicate preview template update")

-- V1.1's embedded classifier may still colour the effects, but it must not
-- compete with the cached runtime for Enabled state.
thrust=replaceOnce(thrust,
	[[pcall(function() object.Enabled=full or kind=="Idle" or kind=="Hover" end)]],
	[[do end]],
	"remove competing embedded enabled-state write")
thrust="-- "..REVISION.."\n"..thrust

local presentation=originals.Presentation
presentation=replaceOnce(presentation,
	[[if previewRoot then previewRoot:SetAttribute("ForceThrustPreview",boolean("PreviewHoverVFXEnabled",true)) end]],
	[[if previewRoot then
		previewRoot:SetAttribute("ForceThrustPreview",false)
		if previewRoot:GetAttribute("PreviewVFXMode")==nil then previewRoot:SetAttribute("PreviewVFXMode","Idle") end
	end]],
	"presentation no longer requests the legacy all-effects preview")
presentation="-- "..REVISION.."\n"..presentation

compile("CachedThrustVisualRuntime",cached)
compile("ThrustPreviewController_Active",thrust)
compile("GaragePreviewPresentationController_Active",presentation)
assert(#cached<199000,"CachedThrustVisualRuntime projected Source exceeds Studio's safe limit")
assert(#thrust<199000,"ThrustPreviewController projected Source exceeds Studio's safe limit")
assert(#presentation<199000,"GaragePreviewPresentationController projected Source exceeds Studio's safe limit")

local ok,err=pcall(function()
	cachedRuntime.Source=cached
	thrustScript.Disabled=true; thrustScript.Source=thrust; thrustScript.Disabled=false
	presentationScript.Disabled=true; presentationScript.Source=presentation; presentationScript.Disabled=false
	assert(audit(),"Post-install audit failed")
end)
if not ok then
	cachedRuntime.Source=originals.Cached
	thrustScript.Disabled=true; thrustScript.Source=originals.Thrust; thrustScript.Disabled=originals.ThrustDisabled
	presentationScript.Disabled=true; presentationScript.Source=originals.Presentation; presentationScript.Disabled=originals.PresentationDisabled
	error("Garage preview VFX single-owner install rolled back: "..tostring(err))
end

print(PREFIX.." INSTALL COMPLETE")
print(PREFIX.." Restart Play. Normal garage preview must show engine idle + hover only. Open Thrust Colour to show acceleration, boost, and stabiliser VFX; leave that page to return to idle. No duplicate template hosts may be created by ThrustPreviewController.")
