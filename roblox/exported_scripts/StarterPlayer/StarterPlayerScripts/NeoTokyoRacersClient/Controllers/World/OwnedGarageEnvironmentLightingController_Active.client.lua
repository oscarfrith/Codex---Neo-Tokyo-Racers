-- NTR_OWNED_GARAGE_CLEAR_NIGHT_ENVIRONMENT_V1_2_PROMPT_LIFECYCLE
-- Local presentation only: the server-owned city lighting cycle remains authoritative.
local Lighting=game:GetService("Lighting")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local player=Players.LocalPlayer
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local settings=kit.Config.Runtime:WaitForChild("OwnedGarage_EditAttributes")
local shared=ReplicatedStorage:WaitForChild("Shared")
local presets=require(shared:WaitForChild("LightingPresets"):WaitForChild("LightingPresets"))
local skies=shared:WaitForChild("SkyPresets")

local EFFECT_SPECS={
	Atmosphere={"Atmosphere","Atmosphere"},
	ColorCorrection={"ColorCorrectionEffect","ColorCorrection"},
	Bloom={"BloomEffect","Bloom"},
	SunRays={"SunRaysEffect","SunRays"},
	DepthOfField={"DepthOfFieldEffect","DepthOfField"},
}

local effects={}
local inside=false
local generation=0
local lastCityPreset
local reapplyQueued=false
local queueInterior=function() end

local function configuredPreset()
	local name=settings:GetAttribute("InteriorEnvironmentPreset")
	return type(name)=="string" and name~="" and name or "ClearNight"
end

local function validPreset(name)
	return type(name)=="string" and type(presets[name])=="table"
end

local function getEffect(section)
	local cached=effects[section]
	if cached and cached.Parent==Lighting then return cached end
	local spec=EFFECT_SPECS[section]
	if not spec then return nil end
	local existing=Lighting:FindFirstChild(spec[2])
	if existing and existing.ClassName~=spec[1] then existing:Destroy(); existing=nil end
	if not existing then existing=Instance.new(spec[1]); existing.Name=spec[2]; existing.Parent=Lighting end
	effects[section]=existing
	return existing
end

local function applyProperties(instance,properties)
	for propertyName,value in pairs(properties or {}) do
		if instance==Lighting and propertyName=="Fogcolor" then propertyName="FogColor" end
		local ok,problem=pcall(function()
			if instance[propertyName]~=value then instance[propertyName]=value end
		end)
		if not ok then warn("[NTR Owned Garage Environment] Could not apply "..instance.Name.."."..propertyName..": "..tostring(problem)) end
	end
end

local function applySky(name)
	if type(name)~="string" or name=="" then return end
	local template=skies:FindFirstChild(name)
	if not (template and template:IsA("Sky")) then
		warn("[NTR Owned Garage Environment] Missing Sky preset: "..name)
		return
	end
	local active
	for _,child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") and child.Name=="ActiveSky" and child:GetAttribute("NTR_OwnedGarageSkyPreset")==name then active=child end
	end
	if active then
		for _,child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") and child~=active then child:Destroy() end end
		return
	end
	for _,child in ipairs(Lighting:GetChildren()) do if child:IsA("Sky") then child:Destroy() end end
	local clone=template:Clone(); clone.Name="ActiveSky"; clone:SetAttribute("NTR_OwnedGarageSkyPreset",name); clone.Parent=Lighting
end

local function applyPreset(name)
	local preset=validPreset(name) and presets[name] or nil
	if not preset then
		warn("[NTR Owned Garage Environment] Missing lighting preset: "..tostring(name))
		return false
	end
	local ok,problem=pcall(function()
		applyProperties(Lighting,preset.Lighting)
		for section in pairs(EFFECT_SPECS) do applyProperties(getEffect(section),preset[section]) end
		applySky(preset.SkyName)
	end)
	if not ok then warn("[NTR Owned Garage Environment] Preset application failed: "..tostring(problem)) end
	return ok
end

local function applyInterior(expectedGeneration)
	if expectedGeneration~=generation or not inside then return end
	if settings:GetAttribute("InteriorEnvironmentLightingEnabled")==false then return end
	applyPreset(configuredPreset())
end

queueInterior=function()
	if not inside then return end
	generation+=1
	if reapplyQueued then return end
	reapplyQueued=true
	task.delay(.05,function()
		reapplyQueued=false
		applyInterior(generation)
	end)
end

local function update()
	generation+=1
	local token=generation
	local physicallyInside=player:GetAttribute("NTR_OwnedGarageInside")==true
	local nextActive=physicallyInside and settings:GetAttribute("InteriorEnvironmentLightingEnabled")~=false
	if nextActive then
		local cityPreset=Lighting:GetAttribute("NTR_LightingPreset")
		if validPreset(cityPreset) then lastCityPreset=cityPreset end
		inside=true
		queueInterior()
	elseif inside then
		inside=false
		local cityPreset=Lighting:GetAttribute("NTR_LightingPreset")
		if validPreset(cityPreset) then lastCityPreset=cityPreset end
		local fallback=settings:GetAttribute("InteriorEnvironmentFallbackCityPreset")
		local restore=validPreset(lastCityPreset) and lastCityPreset or (validPreset(fallback) and fallback or "Day")
		task.defer(function()
			if token==generation and not inside then applyPreset(restore) end
		end)
	else
		inside=false
	end
end

Lighting:GetAttributeChangedSignal("NTR_LightingPreset"):Connect(function()
	local cityPreset=Lighting:GetAttribute("NTR_LightingPreset")
	if validPreset(cityPreset) then lastCityPreset=cityPreset end
	queueInterior()
end)

settings:GetAttributeChangedSignal("InteriorEnvironmentPreset"):Connect(function()
	queueInterior()
end)
settings:GetAttributeChangedSignal("InteriorEnvironmentLightingEnabled"):Connect(update)
player:GetAttributeChangedSignal("NTR_OwnedGarageInside"):Connect(update)

update()
script:SetAttribute("OwnedGarageEnvironmentStarted",true)
print("[NTR Owned Garage] ClearNight interior environment owner active.")
