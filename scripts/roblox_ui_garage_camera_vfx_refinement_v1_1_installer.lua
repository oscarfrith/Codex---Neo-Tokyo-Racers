-- Neo Tokyo Racers - Garage camera and preview VFX refinement V1.1
-- NTR_GARAGE_CAMERA_VFX_REFINEMENT_V1_1
-- Run once in the Studio Edit Command Bar, then restart Play.
-- Corrects the V1 camera offset and gates embedded preview-model effects by mode.

local MODE="INSTALL" -- INSTALL or AUDIT
local REVISION="NTR_GARAGE_CAMERA_VFX_REFINEMENT_V1_1"
local REQUIRED="NTR_GARAGE_CAMERA_VFX_SCROLL_REFINEMENT_V1"
local PREFIX="[NTR Garage Camera/VFX Refinement V1.1]"

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
local previewRoot=need(need(clientRoot,"Controllers","Folder"),"Preview","Folder")
local cameraModule=need(previewRoot,"PreviewCameraController","ModuleScript")
local thrustScript=need(previewRoot,"ThrustPreviewController_Active","LocalScript")

local originalCamera=cameraModule.Source
local originalThrust=thrustScript.Source
local originalThrustDisabled=thrustScript.Disabled
local oldOffset=config:GetAttribute("PreviewCameraYawOffsetDegrees")
local hadOffset=oldOffset~=nil

local function audit()
	local camera,thrust=cameraModule.Source,thrustScript.Source
	local pass,fail=0,0
	local function check(ok,message)
		if ok then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end
	end
	check(string.find(camera,REVISION,1,true)~=nil,"camera correction installed")
	check(string.find(thrust,REVISION,1,true)~=nil,"embedded preview VFX gate installed")
	check(string.find(camera,'number("PreviewCameraYawOffsetDegrees",45)',1,true)~=nil,"camera fallback is 45 degrees in the corrected direction")
	check(config:GetAttribute("PreviewCameraYawOffsetDegrees")==45,"live camera offset attribute is +45 degrees")
	check(string.find(thrust,'kind=="Idle" or kind=="Hover"',1,true)~=nil,"normal preview permits only idle and hover embedded effects")
	check(string.find(thrust,'mode=="ThrustColour"',1,true)~=nil,"thrust-colour mode enables the full embedded set")
	check(string.find(thrust,'NTR_VFXRuntimeHost',1,true)~=nil,"embedded gate does not fight shared runtime VFX hosts")
	check(string.find(thrust,'applyPreviewEffects(root,color,mode)',1,true)~=nil,"preview mode is applied when root, vehicle, colour, or mode changes")
	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail))
	return fail==0
end

local cameraInstalled=string.find(originalCamera,REVISION,1,true)~=nil
local thrustInstalled=string.find(originalThrust,REVISION,1,true)~=nil
if MODE=="AUDIT" then assert(cameraInstalled and thrustInstalled,"V1.1 is not fully installed"); assert(audit(),"Audit failed"); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")
if cameraInstalled and thrustInstalled then assert(audit(),"Existing installation audit failed"); print(PREFIX.." ALREADY INSTALLED"); return end
assert(not cameraInstalled and not thrustInstalled,"Partial V1.1 installation detected. Refresh the live source before retrying.")
assert(string.find(originalCamera,REQUIRED,1,true) and string.find(originalThrust,REQUIRED,1,true),"Confirmed V1 camera/VFX/scroll baseline missing. Run the prior installer first; V1.1 will not patch another baseline.")

local camera=replaceOnce(originalCamera,
	[[number("PreviewCameraYawOffsetDegrees",-45)]],
	[[number("PreviewCameraYawOffsetDegrees",45)]],
	"corrected camera offset fallback")
camera="-- "..REVISION.."\n"..camera

local thrust=originalThrust
local embeddedGate=[[
local function isPreviewToggle(object) return object:IsA("ParticleEmitter") or object:IsA("Fire") or object:IsA("Smoke") or object:IsA("Beam") or object:IsA("Trail") or object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") end
local function insideRuntimeHost(object,root) local current=object; while current and current~=root do if current:GetAttribute("NTR_VFXRuntimeHost")==true then return true end; current=current.Parent end; return false end
local function previewEffectKind(object,root)
	local current=object
	while current and current~=root.Parent do
		local lower=string.lower(current.Name)
		if string.find(lower,"engineoff",1,true) or string.find(lower,"engineidle",1,true) then return "Idle" end
		if string.find(lower,"engineon",1,true) or string.find(lower,"enginethrust",1,true) then return "Acceleration" end
		if string.find(lower,"booston",1,true) or string.find(lower,"boostjet",1,true) then return "Boost" end
		if string.find(lower,"stabiliseron",1,true) or string.find(lower,"stabilizeron",1,true) or string.find(lower,"stabiliserjet",1,true) or string.find(lower,"stabilizerjet",1,true) then return "Stabiliser" end
		if string.find(lower,"hover",1,true) or string.find(lower,"dust",1,true) then return "Hover" end
		if current==root then break end; current=current.Parent
	end
	return nil
end
local function applyPreviewEffects(root,color,mode)
	if not root then return end; local full=mode=="ThrustColour"
	for _,object in ipairs(root:GetDescendants()) do
		if object:IsA("BasePart") and hasChannel(object,"ThrustColor") then object.Color=color; object.Material=Enum.Material.Neon; object.Transparency=0
		elseif isPreviewToggle(object) and not insideRuntimeHost(object,root) then local kind=previewEffectKind(object,root); if kind then applyFireColour(object,color); pcall(function() object.Enabled=full or kind=="Idle" or kind=="Hover" end) end end
	end
end
]]
thrust=replaceOnce(thrust,
	[[local function isThrustFire(object) local lower=string.lower(object.Name); return string.find(lower,"booston_fire",1,true) or string.find(lower,"engineoff_fire",1,true) or string.find(lower,"engineon_fire",1,true) or string.find(lower,"stabiliseron_fire",1,true) or string.find(lower,"stabilizeron_fire",1,true) end
local function applyFireColour(object,color) if object:IsA("ParticleEmitter") then object.Color=ColorSequence.new(color) elseif object:IsA("Fire") then object.Color=color; object.SecondaryColor=color elseif object:IsA("Smoke") then object.Color=color elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then object.Color=color end end
local function applyThrustOnly(root,color,forceEnabled) if not root then return end; for _,object in ipairs(root:GetDescendants()) do if object:IsA("BasePart") and hasChannel(object,"ThrustColor") then object.Color=color; object.Material=Enum.Material.Neon; object.Transparency=0 elseif isThrustFire(object) then applyFireColour(object,color); if forceEnabled~=nil then pcall(function() object.Enabled=forceEnabled end) end end end end]],
	[[local function applyFireColour(object,color) if object:IsA("ParticleEmitter") then object.Color=ColorSequence.new(color) elseif object:IsA("Fire") then object.Color=color; object.SecondaryColor=color elseif object:IsA("Smoke") then object.Color=color elseif object:IsA("PointLight") or object:IsA("SpotLight") or object:IsA("SurfaceLight") then object.Color=color end end
]]..embeddedGate,
	"embedded preview effect classifier")
thrust=replaceOnce(thrust,
	[[applyThrustOnly(root,color or Color3.new(1,1,1),nil)]],
	[[applyPreviewEffects(root,color or Color3.new(1,1,1),mode)]],
	"apply embedded effects by preview mode")
thrust="-- "..REVISION.."\n"..thrust

compile("PreviewCameraController",camera)
compile("ThrustPreviewController_Active",thrust)
assert(#camera<199000 and #thrust<199000,"Projected Source exceeds Studio's safe limit")

local ok,err=pcall(function()
	config:SetAttribute("PreviewCameraYawOffsetDegrees",45)
	cameraModule.Source=camera
	thrustScript.Disabled=true; thrustScript.Source=thrust; thrustScript.Disabled=false
	assert(audit(),"Post-install audit failed")
end)
if not ok then
	config:SetAttribute("PreviewCameraYawOffsetDegrees",hadOffset and oldOffset or nil)
	cameraModule.Source=originalCamera
	thrustScript.Disabled=true; thrustScript.Source=originalThrust; thrustScript.Disabled=originalThrustDisabled
	error("Garage camera/VFX V1.1 install rolled back: "..tostring(err))
end

print(PREFIX.." INSTALL COMPLETE")
print(PREFIX.." Restart Play. Verify the camera has moved 90 degrees from the V1 result; normal previews show idle engine and hover only; full acceleration/boost/stabiliser effects appear only while editing Thrust Colour.")
