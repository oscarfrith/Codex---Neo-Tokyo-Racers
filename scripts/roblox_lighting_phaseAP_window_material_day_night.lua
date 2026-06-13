-- Neo Tokyo Racers - Lighting Phase AP
-- Run this entire file once in the Roblox Studio Command Bar.
--
-- Migrates MeshParts with a direct SurfaceAppearance child named either
-- "Windows" or "SurfaceAppearance Windows" to MaterialVariants, then installs
-- a lightweight client controller that follows the current lighting mode.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local StarterPlayer = game:GetService("StarterPlayer")

local DAY_VARIANT_NAME = "Windows Day"
local NIGHT_VARIANT_NAME = "Windows Night"
local WINDOW_TAG = "NTR_WindowMaterial"
local CONTROLLER_NAME = "WindowMaterialController_Active"

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
	error(string.format(
		"[NTR Lighting Phase AP] Aborted without changes. MaterialService must contain MaterialVariants named %q and %q.",
		DAY_VARIANT_NAME,
		NIGHT_VARIANT_NAME
	))
end

if dayVariant.BaseMaterial ~= nightVariant.BaseMaterial then
	error(string.format(
		"[NTR Lighting Phase AP] Aborted without changes. %q and %q must use the same BaseMaterial.",
		DAY_VARIANT_NAME,
		NIGHT_VARIANT_NAME
	))
end

local function isWindowSurfaceAppearance(instance)
	return instance:IsA("SurfaceAppearance")
		and (instance.Name == "Windows" or instance.Name == "SurfaceAppearance Windows")
end

local matches = {}

for _, instance in ipairs(game:GetDescendants()) do
	if instance:IsA("MeshPart") then
		local matchingAppearances = {}

		for _, child in ipairs(instance:GetChildren()) do
			if isWindowSurfaceAppearance(child) then
				table.insert(matchingAppearances, child)
			end
		end

		if #matchingAppearances > 0 then
			table.insert(matches, {
				MeshPart = instance,
				Appearances = matchingAppearances,
			})
		end
	end
end

local migratedCount = 0
local removedAppearanceCount = 0
local textureClearWarnings = 0

for _, match in ipairs(matches) do
	local meshPart = match.MeshPart

	-- MaterialVariant only renders when the part uses the variant's BaseMaterial.
	meshPart.Material = dayVariant.BaseMaterial
	meshPart.MaterialVariant = DAY_VARIANT_NAME
	meshPart:SetAttribute("NTRWindowMaterialManaged", true)
	CollectionService:AddTag(meshPart, WINDOW_TAG)

	local textureCleared = pcall(function()
		meshPart.TextureID = ""
	end)

	if not textureCleared then
		textureCleared = pcall(function()
			meshPart.TextureContent = Content.none
		end)
	end

	if not textureCleared then
		textureClearWarnings += 1
		warn("[NTR Lighting Phase AP] Could not clear TextureContent:", meshPart:GetFullName())
	end

	for _, surfaceAppearance in ipairs(match.Appearances) do
		surfaceAppearance:Destroy()
		removedAppearanceCount += 1
	end

	migratedCount += 1
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

local controller = worldControllers:FindFirstChild(CONTROLLER_NAME)
if controller and not controller:IsA("LocalScript") then
	error("[NTR Lighting Phase AP] Existing controller path is not a LocalScript: " .. controller:GetFullName())
end

if not controller then
	controller = Instance.new("LocalScript")
	controller.Name = CONTROLLER_NAME
	controller.Parent = worldControllers
end

controller.Source = [==[
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")

local WINDOW_TAG = "NTR_WindowMaterial"
local DAY_VARIANT_NAME = "Windows Day"
local NIGHT_VARIANT_NAME = "Windows Night"
local PRESET_ATTRIBUTE = "NTR_LightingPreset"
local NIGHT_BRIGHTNESS_THRESHOLD = 1

local function waitForMaterialVariant(name)
	local variant = MaterialService:FindFirstChild(name, true)

	while not variant do
		MaterialService.DescendantAdded:Wait()
		variant = MaterialService:FindFirstChild(name, true)
	end

	return variant
end

local dayVariant = waitForMaterialVariant(DAY_VARIANT_NAME)
local nightVariant = waitForMaterialVariant(NIGHT_VARIANT_NAME)

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

	-- ClearNight currently uses ClockTime 12.1, so Brightness is the reliable
	-- fallback for the existing N/M lighting preview controller.
	return Lighting.Brightness <= NIGHT_BRIGHTNESS_THRESHOLD
end

local currentNightMode = nil

local function applyToPart(instance, isNight)
	if not instance:IsA("MeshPart") then
		return
	end

	local variant = isNight and nightVariant or dayVariant
	instance.Material = variant.BaseMaterial
	instance.MaterialVariant = variant.Name
end

local function refreshAll(force)
	local isNight = readNightMode()

	if not force and currentNightMode == isNight then
		return
	end

	currentNightMode = isNight

	for _, instance in ipairs(CollectionService:GetTagged(WINDOW_TAG)) do
		applyToPart(instance, isNight)
	end
end

CollectionService:GetInstanceAddedSignal(WINDOW_TAG):Connect(function(instance)
	applyToPart(instance, readNightMode())
end)

Lighting:GetAttributeChangedSignal(PRESET_ATTRIBUTE):Connect(function()
	refreshAll(false)
end)

Lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
	refreshAll(false)
end)

refreshAll(true)
]==]

controller.Disabled = false

print(string.format(
	"[NTR Lighting Phase AP] Complete. Migrated %d MeshParts, removed %d SurfaceAppearances, texture clear warnings %d.",
	migratedCount,
	removedAppearanceCount,
	textureClearWarnings
))
print("[NTR Lighting Phase AP] Test with N for ClearNight and M for Day in Play mode.")
