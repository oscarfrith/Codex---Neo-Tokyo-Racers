-- NTR_GARAGE_PREVIEW_VFX_SINGLE_OWNER_V1
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
	if previewRoot then
		previewRoot:SetAttribute("ForceThrustPreview",false)
		if previewRoot:GetAttribute("PreviewVFXMode")==nil then previewRoot:SetAttribute("PreviewVFXMode","Idle") end
	end
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
