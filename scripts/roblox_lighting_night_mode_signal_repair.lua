-- Neo Tokyo Racers - Night Mode Signal Repair
-- Run this entire file in the Roblox Studio Command Bar.
--
-- Fixes the day/night visual signal used by window MaterialVariants and
-- lamppost SurfaceLights. This does not delete assets or create backups.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local SCRIPT_ID = "roblox_lighting_night_mode_signal_repair"
local PRESET_ATTRIBUTE = "NTR_LightingPreset"
local WINDOW_TAG = "NTR_WindowMaterial"
local LAMPPOST_LIGHT_TAG = "NTR_NightLamppostLight"
local DAY_VARIANT_NAME = "Windows Day"
local NIGHT_VARIANT_NAME = "Windows Night"
local TEMP_PREVIEW_NAME = "TEMP_LightingPreview"
local WINDOW_CONTROLLER_NAME = "WindowMaterialController_Active"
local LAMPPOST_CONTROLLER_NAME = "NightLamppostLightController_Active"
local LIGHTING_SERVICE_NAME = "LightingService_Active"

local function assertChild(parent, name)
	local child = parent:FindFirstChild(name)
	if not child then
		error(("[NTR Lighting Repair] Missing %s under %s"):format(name, parent:GetFullName()))
	end
	return child
end

local function findMaterialVariant(name)
	local candidate = MaterialService:FindFirstChild(name, true)
	if candidate and candidate:IsA("MaterialVariant") then
		return candidate
	end
	return nil
end

local dayVariant = findMaterialVariant(DAY_VARIANT_NAME)
local nightVariant = findMaterialVariant(NIGHT_VARIANT_NAME)

if not dayVariant or not nightVariant then
	error(("[NTR Lighting Repair] Missing MaterialVariants %q and/or %q in MaterialService. Re-run the Phase AP material setup first."):format(
		DAY_VARIANT_NAME,
		NIGHT_VARIANT_NAME
	))
end

if dayVariant.BaseMaterial ~= nightVariant.BaseMaterial then
	error(("[NTR Lighting Repair] %q and %q must use the same BaseMaterial."):format(DAY_VARIANT_NAME, NIGHT_VARIANT_NAME))
end

local starterPlayerScripts = StarterPlayer:WaitForChild("StarterPlayerScripts")
local clientRoot = starterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
if not clientRoot then
	clientRoot = Instance.new("Folder")
	clientRoot.Name = "NeoTokyoRacersClient"
	clientRoot.Parent = starterPlayerScripts
end

local controllers = clientRoot:FindFirstChild("Controllers")
if not controllers then
	controllers = Instance.new("Folder")
	controllers.Name = "Controllers"
	controllers.Parent = clientRoot
end

local worldControllers = controllers:FindFirstChild("World")
if not worldControllers then
	worldControllers = Instance.new("Folder")
	worldControllers.Name = "World"
	worldControllers.Parent = controllers
end

local function getOrCreateLocalScript(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA("LocalScript") then
		error("[NTR Lighting Repair] Existing object is not a LocalScript: " .. existing:GetFullName())
	end

	if not existing then
		existing = Instance.new("LocalScript")
		existing.Name = name
		existing.Parent = parent
	end

	return existing
end

local function getOrCreateTempPreview()
	local existing = starterPlayerScripts:FindFirstChild(TEMP_PREVIEW_NAME)
	if existing and not existing:IsA("LocalScript") then
		error("[NTR Lighting Repair] Existing TEMP_LightingPreview is not a LocalScript: " .. existing:GetFullName())
	end

	if not existing then
		existing = Instance.new("LocalScript")
		existing.Name = TEMP_PREVIEW_NAME
		existing.Parent = starterPlayerScripts
	end

	return existing
end

local runtimeControllerSource = [==[
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")

local WINDOW_TAG = "NTR_WindowMaterial"
local LIGHT_TAG = "NTR_NightLamppostLight"
local DAY_VARIANT_NAME = "Windows Day"
local NIGHT_VARIANT_NAME = "Windows Night"
local PRESET_ATTRIBUTE = "NTR_LightingPreset"
local NIGHT_BRIGHTNESS_THRESHOLD = 1

local function findMaterialVariant(name)
	local candidate = MaterialService:FindFirstChild(name, true)
	if candidate and candidate:IsA("MaterialVariant") then
		return candidate
	end
	return nil
end

local function readNightMode()
	local presetName = Lighting:GetAttribute(PRESET_ATTRIBUTE)
	if type(presetName) == "string" then
		local normalized = string.lower(presetName)
		if string.find(normalized, "night", 1, true) then
			return true
		end
		if string.find(normalized, "day", 1, true) then
			return false
		end
	end

	if Lighting.Brightness <= NIGHT_BRIGHTNESS_THRESHOLD then
		return true
	end

	local clockTime = Lighting.ClockTime
	return clockTime < 6 or clockTime >= 18
end

local currentNightMode = nil

local function applyWindow(instance, isNight)
	if not instance:IsA("MeshPart") then
		return
	end

	local variant = findMaterialVariant(isNight and NIGHT_VARIANT_NAME or DAY_VARIANT_NAME)
	if not variant then
		warn("[NTR Lighting Runtime] Missing MaterialVariant:", isNight and NIGHT_VARIANT_NAME or DAY_VARIANT_NAME)
		return
	end

	instance.Material = variant.BaseMaterial
	instance.MaterialVariant = variant.Name
end

local function applyLight(instance, isNight)
	if instance:IsA("SurfaceLight") then
		instance.Enabled = isNight
	end
end

local function refreshAll(force)
	local isNight = readNightMode()
	if not force and currentNightMode == isNight then
		return
	end

	currentNightMode = isNight

	for _, instance in ipairs(CollectionService:GetTagged(WINDOW_TAG)) do
		applyWindow(instance, isNight)
	end

	for _, instance in ipairs(CollectionService:GetTagged(LIGHT_TAG)) do
		applyLight(instance, isNight)
	end
end

CollectionService:GetInstanceAddedSignal(WINDOW_TAG):Connect(function(instance)
	applyWindow(instance, readNightMode())
end)

CollectionService:GetInstanceAddedSignal(LIGHT_TAG):Connect(function(instance)
	applyLight(instance, readNightMode())
end)

Lighting:GetAttributeChangedSignal(PRESET_ATTRIBUTE):Connect(function()
	refreshAll(false)
end)

Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
	refreshAll(false)
end)

Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
	refreshAll(false)
end)

refreshAll(true)
]==]

local tempPreviewSource = [==[
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PRESET_ATTRIBUTE = "NTR_LightingPreset"

local Shared = ReplicatedStorage:WaitForChild("Shared")

local LightingPresets = require(
	Shared
		:WaitForChild("LightingPresets")
		:WaitForChild("LightingPresets")
)

local SkyPresets = Shared:WaitForChild("SkyPresets")

local function getOrCreateEffect(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end

	local newEffect = Instance.new(className)
	newEffect.Name = name
	newEffect.Parent = Lighting
	return newEffect
end

local atmosphere = getOrCreateEffect("Atmosphere", "Atmosphere")
local colorCorrection = getOrCreateEffect("ColorCorrectionEffect", "ColorCorrection")
local bloom = getOrCreateEffect("BloomEffect", "Bloom")
local sunRays = getOrCreateEffect("SunRaysEffect", "SunRays")
local depthOfField = getOrCreateEffect("DepthOfFieldEffect", "DepthOfField")

local function applyProperties(instance, properties)
	if not properties then
		return
	end

	for propertyName, value in pairs(properties) do
		if instance == Lighting and propertyName == "Fogcolor" then
			propertyName = "FogColor"
		end

		local success, err = pcall(function()
			instance[propertyName] = value
		end)

		if not success then
			warn("[Lighting Preview] Could not apply property:", instance.Name, propertyName, err)
		end
	end
end

local function clearCurrentSky()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
end

local function applySky(skyName)
	if not skyName then
		warn("[Lighting Preview] Preset has no SkyName.")
		return
	end

	local skyTemplate = SkyPresets:FindFirstChild(skyName)
	if not skyTemplate then
		warn("[Lighting Preview] Sky preset not found:", skyName)
		return
	end

	if not skyTemplate:IsA("Sky") then
		warn("[Lighting Preview] Sky preset is not a Sky object:", skyName, skyTemplate.ClassName)
		return
	end

	clearCurrentSky()

	local newSky = skyTemplate:Clone()
	newSky.Name = "ActiveSky"
	newSky.Parent = Lighting
	print("[Lighting Preview] Applied sky:", skyName)
end

local function applyPreset(presetName)
	local preset = LightingPresets[presetName]
	if not preset then
		warn("[Lighting Preview] Preset does not exist:", presetName)
		return
	end

	Lighting:SetAttribute(PRESET_ATTRIBUTE, nil)
	Lighting:SetAttribute(PRESET_ATTRIBUTE, presetName)

	applyProperties(Lighting, preset.Lighting)
	applyProperties(atmosphere, preset.Atmosphere)
	applyProperties(colorCorrection, preset.ColorCorrection)
	applyProperties(bloom, preset.Bloom)
	applyProperties(sunRays, preset.SunRays)
	applyProperties(depthOfField, preset.DepthOfField)
	applySky(preset.SkyName)

	-- Pulse it again after the property pass so listeners receive a clean mode
	-- signal even if the attribute already had this value.
	Lighting:SetAttribute(PRESET_ATTRIBUTE, nil)
	Lighting:SetAttribute(PRESET_ATTRIBUTE, presetName)

	print("[Lighting Preview] Applied preset:", presetName)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.N then
		applyPreset("ClearNight")
	elseif input.KeyCode == Enum.KeyCode.M then
		applyPreset("Day")
	end
end)

print("[Lighting Preview] Press N for ClearNight, M for Day.")
]==]

local lightingServicePatch = [==[
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PRESET_ATTRIBUTE = "NTR_LightingPreset"
local Shared = ReplicatedStorage:WaitForChild("Shared")

local LightingPresets = require(
	Shared
		:WaitForChild("LightingPresets")
		:WaitForChild("LightingPresets")
)

local SkyPresets = Shared:WaitForChild("SkyPresets")

-- Change this between "Day" and "ClearNight" for testing.
local CURRENT_PRESET = "Day"

local function getOrCreateEffect(className, name)
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing
	end

	local newEffect = Instance.new(className)
	newEffect.Name = name
	newEffect.Parent = Lighting
	return newEffect
end

local atmosphere = getOrCreateEffect("Atmosphere", "Atmosphere")
local colorCorrection = getOrCreateEffect("ColorCorrectionEffect", "ColorCorrection")
local bloom = getOrCreateEffect("BloomEffect", "Bloom")
local sunRays = getOrCreateEffect("SunRaysEffect", "SunRays")
local depthOfField = getOrCreateEffect("DepthOfFieldEffect", "DepthOfField")

local function applyProperties(instance, properties)
	if not properties then
		return
	end

	for propertyName, value in pairs(properties) do
		if instance == Lighting and propertyName == "Fogcolor" then
			propertyName = "FogColor"
		end

		local success, err = pcall(function()
			instance[propertyName] = value
		end)

		if not success then
			warn("Could not apply property:", instance.Name, propertyName, err)
		end
	end
end

local function clearCurrentSky()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
end

local function applySky(skyName)
	if not skyName then
		return
	end

	local skyTemplate = SkyPresets:FindFirstChild(skyName)
	if not skyTemplate then
		warn("Sky preset not found:", skyName)
		return
	end

	clearCurrentSky()

	local newSky = skyTemplate:Clone()
	newSky.Name = "ActiveSky"
	newSky.Parent = Lighting
end

local function applyLightingPreset(presetName)
	local preset = LightingPresets[presetName]
	if not preset then
		warn("Lighting preset does not exist:", presetName)
		return
	end

	Lighting:SetAttribute(PRESET_ATTRIBUTE, nil)
	Lighting:SetAttribute(PRESET_ATTRIBUTE, presetName)

	applyProperties(Lighting, preset.Lighting)
	applyProperties(atmosphere, preset.Atmosphere)
	applyProperties(colorCorrection, preset.ColorCorrection)
	applyProperties(bloom, preset.Bloom)
	applyProperties(sunRays, preset.SunRays)
	applyProperties(depthOfField, preset.DepthOfField)
	applySky(preset.SkyName)

	Lighting:SetAttribute(PRESET_ATTRIBUTE, nil)
	Lighting:SetAttribute(PRESET_ATTRIBUTE, presetName)

	print("Applied lighting preset:", presetName)
end

applyLightingPreset(CURRENT_PRESET)
]==]

local windowController = getOrCreateLocalScript(worldControllers, WINDOW_CONTROLLER_NAME)
windowController.Source = runtimeControllerSource
windowController.Disabled = false
windowController:SetAttribute("PatchedBy", SCRIPT_ID)
windowController:SetAttribute("PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))

local lamppostController = getOrCreateLocalScript(worldControllers, LAMPPOST_CONTROLLER_NAME)
lamppostController.Source = runtimeControllerSource
lamppostController.Disabled = false
lamppostController:SetAttribute("PatchedBy", SCRIPT_ID)
lamppostController:SetAttribute("PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))

local tempPreview = getOrCreateTempPreview()
tempPreview.Source = tempPreviewSource
tempPreview.Disabled = false
tempPreview:SetAttribute("PatchedBy", SCRIPT_ID)
tempPreview:SetAttribute("PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))

local lightingService = nil
local services = ServerScriptService:FindFirstChild("NeoTokyoRacers")
if services then
	services = services:FindFirstChild("Services")
end
if services then
	local world = services:FindFirstChild("World")
	if world then
		local lightingFolder = world:FindFirstChild("Lighting")
		if lightingFolder then
			lightingService = lightingFolder:FindFirstChild(LIGHTING_SERVICE_NAME)
		end
	end
end

if lightingService then
	if not lightingService:IsA("Script") then
		error("[NTR Lighting Repair] LightingService_Active exists but is not a Script: " .. lightingService:GetFullName())
	end

	lightingService.Source = lightingServicePatch
	lightingService.Disabled = false
	lightingService:SetAttribute("PatchedBy", SCRIPT_ID)
	lightingService:SetAttribute("PatchedAt", os.date("%Y-%m-%d %H:%M:%S"))
else
	warn("[NTR Lighting Repair] LightingService_Active not found; patched client preview/controllers only.")
end

local function isWindowCandidate(instance)
	if not instance:IsA("MeshPart") then
		return false
	end

	if instance:GetAttribute("NTRWindowMaterialManaged") == true then
		return true
	end

	if instance.MaterialVariant == DAY_VARIANT_NAME or instance.MaterialVariant == NIGHT_VARIANT_NAME then
		return true
	end

	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("SurfaceAppearance")
			and (child.Name == "Windows" or child.Name == "SurfaceAppearance Windows")
		then
			return true
		end
	end

	return false
end

local function currentIsNight()
	local presetName = Lighting:GetAttribute(PRESET_ATTRIBUTE)
	if type(presetName) == "string" then
		local normalized = string.lower(presetName)
		if string.find(normalized, "night", 1, true) then
			return true
		end
		if string.find(normalized, "day", 1, true) then
			return false
		end
	end

	if Lighting.Brightness <= 1 then
		return true
	end

	return Lighting.ClockTime < 6 or Lighting.ClockTime >= 18
end

local isNight = currentIsNight()
local activeVariant = isNight and nightVariant or dayVariant
local taggedWindows = 0
local taggedLights = 0
local enabledLights = 0

for _, instance in ipairs(game:GetDescendants()) do
	if isWindowCandidate(instance) then
		CollectionService:AddTag(instance, WINDOW_TAG)
		instance:SetAttribute("NTRWindowMaterialManaged", true)
		instance.Material = activeVariant.BaseMaterial
		instance.MaterialVariant = activeVariant.Name
		taggedWindows += 1
	elseif instance:IsA("SurfaceLight")
		and instance.Name == "SurfaceLight lamppost"
		and instance.Parent
		and instance.Parent:IsA("MeshPart")
		and string.lower(instance.Parent.Name) == "lamppost neon"
	then
		CollectionService:AddTag(instance, LAMPPOST_LIGHT_TAG)
		instance.Enabled = isNight
		taggedLights += 1
		if instance.Enabled then
			enabledLights += 1
		end
	end
end

if Lighting:GetAttribute(PRESET_ATTRIBUTE) == nil then
	Lighting:SetAttribute(PRESET_ATTRIBUTE, isNight and "ClearNight" or "Day")
end

print("[NTR Lighting Repair] Root cause: TEMP_LightingPreview and LightingService did not publish the NTR_LightingPreset mode signal that the Phase AP window/lamppost controllers listen for.")
print("[NTR Lighting Repair] Installed robust shared runtime source into WindowMaterialController_Active and NightLamppostLightController_Active.")
print("[NTR Lighting Repair] Patched TEMP_LightingPreview" .. (lightingService and " and LightingService_Active." or "."))
print(string.format(
	"[NTR Lighting Repair] Retagged/refreshed %d windows and %d lamppost lights. Current mode: %s; enabled lamppost lights now: %d.",
	taggedWindows,
	taggedLights,
	isNight and "ClearNight" or "Day",
	enabledLights
))
print("[NTR Lighting Repair] Test in Play mode: press N for night and M for day.")
