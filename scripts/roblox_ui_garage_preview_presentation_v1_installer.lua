-- Neo Tokyo Racers - Canonical garage preview presentation V1
-- NTR_GARAGE_PREVIEW_PRESENTATION_V1
-- Run once in the Studio Edit Command Bar, then restart Play.
-- Adds client-only preview hover VFX, visual wobble, and authored garage lighting.
-- It does not alter server lighting, saved vehicle data, or driving physics.

local MODE="INSTALL" -- INSTALL or AUDIT
local REVISION="NTR_GARAGE_PREVIEW_PRESENTATION_V1"
local PREFIX="[NTR Garage Preview Presentation V1]"

local ReplicatedStorage=game:GetService("ReplicatedStorage")
local StarterPlayer=game:GetService("StarterPlayer")

local function need(parent,name,className)
	local object=parent:FindFirstChild(name)
	assert(object,parent:GetFullName().."."..name.." missing")
	if className then assert(object:IsA(className),object:GetFullName().." must be "..className) end
	return object
end

local function compile(name,source)
	local fn,err=loadstring(source,"="..name)
	assert(fn,name.." compile failed: "..tostring(err))
end

local kit=need(ReplicatedStorage,"NeoTokyoRacers","Folder")
local config=need(need(need(kit,"Config","Folder"),"UI","Folder"),"GarageReplacement","Folder")
local shared=need(ReplicatedStorage,"Shared","Folder")
local lightingPresetsFolder=need(shared,"LightingPresets","Folder")
local lightingPresets=need(lightingPresetsFolder,"LightingPresets","ModuleScript")
local skyPresets=need(shared,"SkyPresets","Folder")
local eightPMSky=need(skyPresets,"EightPMSky","Sky")
local clientRoot=need(need(StarterPlayer,"StarterPlayerScripts","StarterPlayerScripts"),"NeoTokyoRacersClient","Folder")
local previewRoot=need(need(clientRoot,"Controllers","Folder"),"Preview","Folder")
local thrustOwner=need(previewRoot,"ThrustPreviewController_Active","LocalScript")
assert(string.find(thrustOwner.Source,"ForceThrustPreview",1,true),"Thrust preview owner does not expose the confirmed ForceThrustPreview contract")

local scriptName="GaragePreviewPresentationController_Active"
local existing=previewRoot:FindFirstChild(scriptName)
if existing then assert(existing:IsA("LocalScript"),existing:GetFullName().." must be a LocalScript") end

local defaults={
	PreviewHoverVFXEnabled=true,
	PreviewWobbleEnabled=true,
	PreviewWobbleAmountDegrees=1.15,
	PreviewWobbleSpeed=1.15,
	PreviewWobbleRandomiseAmount=.65,
	PreviewWobblePitchMultiplier=.75,
	PreviewWobbleRollMultiplier=1,
	PreviewWobbleSmoothing=4.5,
	PreviewBobAmountStuds=.08,
	PreviewPresentationPollSeconds=.10,
	PreviewLightingEnabled=true,
	PreviewLightingPreset="EightPM",
}

local source=[==[
-- NTR_GARAGE_PREVIEW_PRESENTATION_V1
-- Client-only presentation owner. Never changes saved modules, vehicle physics, or server lighting attributes.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Lighting=game:GetService("Lighting")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")

local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("GarageReplacement")
local shared=ReplicatedStorage:WaitForChild("Shared")
local presets=require(shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets"))
local skies=shared:WaitForChild("SkyPresets")

local EFFECTS={
	Atmosphere={ClassName="Atmosphere",Name="Atmosphere"},
	Bloom={ClassName="BloomEffect",Name="Bloom"},
	ColorCorrection={ClassName="ColorCorrectionEffect",Name="ColorCorrection"},
	DepthOfField={ClassName="DepthOfFieldEffect",Name="DepthOfField"},
	SunRays={ClassName="SunRaysEffect",Name="SunRays"},
}

local active=false
local pollElapsed=0
local previewRoot=nil
local previewVehicle=nil
local previewBase=nil
local wobbleClock=0
local currentPitch=0
local currentRoll=0
local wobbling=false
local seedA=math.random()*500
local seedB=math.random()*500
local lightingOwned=false
local lightingSnapshot=nil
local lastGaragePreset=nil
local applyingLighting=false

local function number(name,fallback)
	local value=config:GetAttribute(name)
	return typeof(value)=="number" and value or fallback
end

local function boolean(name,fallback)
	local value=config:GetAttribute(name)
	return typeof(value)=="boolean" and value or fallback
end

local function text(name,fallback)
	local value=config:GetAttribute(name)
	return typeof(value)=="string" and value~="" and value or fallback
end

local function findPreviewRoot()
	local client=Workspace:FindFirstChild("_NTR_ClientOnly")
	return (client and client:FindFirstChild("VehiclePreview")) or Workspace:FindFirstChild("HOVER_RACING_V2_LOCAL_PREVIEW")
end

local function findPreviewVehicle(root)
	if not root then return nil end
	for _,child in ipairs(root:GetChildren()) do
		if child:IsA("Model") then return child end
	end
	return nil
end

local function canonicalGarageVisible()
	local gui=playerGui:FindFirstChild("CanonicalGarageGui")
	if not gui or not gui:IsA("ScreenGui") or not gui.Enabled then return false end
	local canvas=gui:FindFirstChild("CanonicalCanvas",true)
	if not canvas then return false end
	for _,name in ipairs({"CanonicalGarageBrowser","CanonicalGarageWorkspace"}) do
		local root=canvas:FindFirstChild(name,true)
		if root and root:IsA("GuiObject") and root.Visible then return true end
	end
	return false
end

local function garageOpen()
	return player:GetAttribute("NTR_GarageSessionActive")==true or canonicalGarageVisible()
end

local function setProperties(instance,properties)
	if not instance or not properties then return end
	for property,value in pairs(properties) do
		pcall(function() instance[property]=value end)
	end
end

local function findEffect(definition)
	local named=Lighting:FindFirstChild(definition.Name)
	if named and named:IsA(definition.ClassName) then return named end
	for _,child in ipairs(Lighting:GetChildren()) do
		if child:IsA(definition.ClassName) then return child end
	end
	return nil
end

local function replaceSky(skyName)
	for _,child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then child:Destroy() end
	end
	local template=skyName and skies:FindFirstChild(skyName)
	if template and template:IsA("Sky") then
		local clone=template:Clone()
		clone.Name="ActiveSky"
		clone.Parent=Lighting
	end
end

local function applyPreset(name)
	if applyingLighting then return false end
	local preset=presets[name]
	if not preset then
		warn("[NTR Garage Preview Presentation] Missing lighting preset "..tostring(name))
		return false
	end
	applyingLighting=true
	setProperties(Lighting,preset.Lighting)
	for section,definition in pairs(EFFECTS) do
		local properties=preset[section]
		if properties then
			local effect=findEffect(definition)
			if not effect then
				effect=Instance.new(definition.ClassName)
				effect.Name=definition.Name
				effect.Parent=Lighting
			end
			setProperties(effect,properties)
		end
	end
	replaceSky(preset.SkyName)
	applyingLighting=false
	return true
end

local function captureLighting(targetName)
	local target=presets[targetName]
	if not target then return nil end
	local snapshot={Lighting={},Effects={},Sky=nil}
	for property in pairs(target.Lighting or {}) do
		local ok,value=pcall(function() return Lighting[property] end)
		if ok then snapshot.Lighting[property]=value end
	end
	for section,definition in pairs(EFFECTS) do
		local targetProperties=target[section]
		if targetProperties then
			local effect=findEffect(definition)
			local record={Instance=effect,Created=effect==nil,Properties={}}
			if effect then
				for property in pairs(targetProperties) do
					local ok,value=pcall(function() return effect[property] end)
					if ok then record.Properties[property]=value end
				end
			end
			snapshot.Effects[section]=record
		end
	end
	for _,child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then snapshot.Sky=child:Clone(); break end
	end
	return snapshot
end

local function restoreSnapshot(snapshot)
	if not snapshot then return end
	setProperties(Lighting,snapshot.Lighting)
	for section,record in pairs(snapshot.Effects) do
		local definition=EFFECTS[section]
		local effect=record.Instance
		if effect and effect.Parent then
			setProperties(effect,record.Properties)
		elseif not record.Created then
			effect=findEffect(definition)
			setProperties(effect,record.Properties)
		elseif record.Created then
			local created=findEffect(definition)
			if created then created:Destroy() end
		end
	end
	for _,child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") then child:Destroy() end end
	if snapshot.Sky then snapshot.Sky.Parent=Lighting; snapshot.Sky=nil end
end

local function beginGarageLighting()
	if lightingOwned or not boolean("PreviewLightingEnabled",true) then return end
	local presetName=text("PreviewLightingPreset","EightPM")
	lightingSnapshot=captureLighting(presetName)
	if not lightingSnapshot then return end
	if applyPreset(presetName) then
		lightingOwned=true
		lastGaragePreset=presetName
	end
end

local function endGarageLighting()
	if not lightingOwned then return end
	lightingOwned=false
	local authoritative=Lighting:GetAttribute("NTR_LightingPreset")
	if typeof(authoritative)=="string" and presets[authoritative] then
		applyPreset(authoritative)
	else
		restoreSnapshot(lightingSnapshot)
	end
	if lightingSnapshot and lightingSnapshot.Sky then lightingSnapshot.Sky:Destroy() end
	lightingSnapshot=nil
	lastGaragePreset=nil
end

local function restoreVehicle()
	if previewVehicle and previewVehicle.Parent and previewBase then
		pcall(function() previewVehicle:PivotTo(previewBase) end)
	end
	previewVehicle=nil
	previewBase=nil
	wobbleClock=0
	currentPitch=0
	currentRoll=0
	wobbling=false
end

local function releasePreview()
	restoreVehicle()
	if previewRoot and previewRoot.Parent then previewRoot:SetAttribute("ForceThrustPreview",false) end
	previewRoot=nil
end

local function refreshPreview()
	local root=findPreviewRoot()
	if root~=previewRoot then
		if previewRoot and previewRoot.Parent then previewRoot:SetAttribute("ForceThrustPreview",false) end
		restoreVehicle()
		previewRoot=root
	end
	if previewRoot then previewRoot:SetAttribute("ForceThrustPreview",boolean("PreviewHoverVFXEnabled",true)) end
	local vehicle=findPreviewVehicle(previewRoot)
	if vehicle~=previewVehicle then
		restoreVehicle()
		previewVehicle=vehicle
		if vehicle then
			previewBase=vehicle:GetPivot()
			seedA=math.random()*500
			seedB=math.random()*500
		end
	end
end

local function setActive(wanted)
	if wanted==active then return end
	active=wanted
	if active then
		beginGarageLighting()
		refreshPreview()
	else
		releasePreview()
		endGarageLighting()
	end
end

local function updatePresentation(dt)
	if not previewVehicle or not previewVehicle.Parent or not previewBase then return end
	if not boolean("PreviewWobbleEnabled",true) then
		if wobbling then
			pcall(function() previewVehicle:PivotTo(previewBase) end)
			currentPitch,currentRoll=0,0
			wobbling=false
		end
		return
	end
	wobbling=true
	local speed=math.max(.05,number("PreviewWobbleSpeed",1.15))
	wobbleClock+=dt*speed
	local amount=math.rad(math.max(0,number("PreviewWobbleAmountDegrees",1.15)))
	local randomise=math.clamp(number("PreviewWobbleRandomiseAmount",.65),0,1)
	local wavePitch=math.sin(wobbleClock*1.07+seedA)
	local waveRoll=math.sin(wobbleClock*.83+seedB)
	local noisePitch=math.noise(seedA,wobbleClock*.30,0)
	local noiseRoll=math.noise(seedB,wobbleClock*.27,1)
	local targetPitch=(wavePitch*(1-randomise)+noisePitch*randomise)*amount*number("PreviewWobblePitchMultiplier",.75)
	local targetRoll=(waveRoll*(1-randomise)+noiseRoll*randomise)*amount*number("PreviewWobbleRollMultiplier",1)
	local alpha=1-math.exp(-math.max(.1,number("PreviewWobbleSmoothing",4.5))*dt)
	currentPitch+=(targetPitch-currentPitch)*alpha
	currentRoll+=(targetRoll-currentRoll)*alpha
	local bob=math.sin(wobbleClock*1.65+seedA*.1)*number("PreviewBobAmountStuds",.08)
	local ok=pcall(function()
		previewVehicle:PivotTo(previewBase*CFrame.new(0,bob,0)*CFrame.Angles(currentPitch,0,currentRoll))
	end)
	if not ok then previewVehicle=nil; previewBase=nil end
end

Lighting:GetAttributeChangedSignal("NTR_LightingPreset"):Connect(function()
	if active and lightingOwned then task.defer(function() if active and lightingOwned then applyPreset(text("PreviewLightingPreset","EightPM")) end end) end
end)

RunService.RenderStepped:Connect(function(dt)
	pollElapsed+=dt
	local interval=math.max(.05,number("PreviewPresentationPollSeconds",.10))
	if pollElapsed>=interval then
		pollElapsed=0
		setActive(garageOpen())
		if active then
			refreshPreview()
			local enabled=boolean("PreviewLightingEnabled",true)
			if enabled and not lightingOwned then beginGarageLighting() elseif not enabled and lightingOwned then endGarageLighting() end
			local presetName=text("PreviewLightingPreset","EightPM")
			if lightingOwned and presetName~=lastGaragePreset then applyPreset(presetName); lastGaragePreset=presetName end
		end
	end
	if active then updatePresentation(dt) end
end)
]==]

compile(scriptName,source)
assert(#source<199000,"Presentation owner source exceeds Studio's safe Source limit")

local function audit(target)
	local pass,fail=0,0
	local function check(ok,message)
		if ok then pass+=1; print(PREFIX.." PASS - "..message) else fail+=1; warn(PREFIX.." FAIL - "..message) end
	end
	check(target and target:IsA("LocalScript"),"isolated client owner exists")
	check(target and not target.Disabled,"client owner enabled")
	check(target and string.find(target.Source,REVISION,1,true)~=nil,"revision marker present")
	check(target and string.find(target.Source,"ForceThrustPreview",1,true)~=nil,"confirmed thrust-preview bridge reused")
	check(target and string.find(target.Source,"previewBase*CFrame",1,true)~=nil,"wobble is visual and base-relative")
	check(target and string.find(target.Source,'Lighting:GetAttribute("NTR_LightingPreset")',1,true)~=nil,"authoritative lighting restoration exists")
	check(target and not string.find(target.Source,'Lighting:SetAttribute("NTR_LightingPreset"',1,true),"server lighting stage attribute is untouched")
	check(require(lightingPresets).EightPM~=nil and eightPMSky.Parent==skyPresets,"authored EightPM preset and sky exist")
	check(typeof(config:GetAttribute("PreviewWobbleAmountDegrees"))=="number" and typeof(config:GetAttribute("PreviewLightingPreset"))=="string","presentation tuning attributes exist")
	print(string.format("%s RESULT %d PASS / %d FAIL",PREFIX,pass,fail))
	return fail==0
end

if MODE=="AUDIT" then assert(existing,"Presentation owner is not installed"); assert(audit(existing),"Audit failed"); return end
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")
if existing and string.find(existing.Source,REVISION,1,true) then assert(audit(existing),"Existing installation audit failed"); print(PREFIX.." ALREADY INSTALLED"); return end

local oldAttributes={}
for name in pairs(defaults) do
	local value=config:GetAttribute(name)
	oldAttributes[name]={Had=value~=nil,Value=value}
end
local oldScript=existing and {Source=existing.Source,Disabled=existing.Disabled} or nil
local target=existing or Instance.new("LocalScript")
target.Name=scriptName

local ok,err=pcall(function()
	for name,value in pairs(defaults) do if config:GetAttribute(name)==nil then config:SetAttribute(name,value) end end
	target.Disabled=true
	target.Source=source
	target.Parent=previewRoot
	target.Disabled=false
	assert(audit(target),"Post-install audit failed")
end)

if not ok then
	if oldScript then
		target.Disabled=true
		target.Source=oldScript.Source
		target.Disabled=oldScript.Disabled
	else
		target:Destroy()
	end
	for name,record in pairs(oldAttributes) do config:SetAttribute(name,record.Had and record.Value or nil) end
	error("Garage preview presentation install rolled back: "..tostring(err))
end

print(PREFIX.." INSTALL COMPLETE")
print(PREFIX.." Restart Play and verify dealership/customisation previews: hover thrust VFX, gentle pad-relative wobble, EightPM lighting, clean model changes, and restoration on Drive/Exit.")
