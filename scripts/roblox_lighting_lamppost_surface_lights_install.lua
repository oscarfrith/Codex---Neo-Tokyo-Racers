-- Neo Tokyo Racers - Lamppost Surface Lights
-- Run this entire file once in the Roblox Studio Command Bar.
--
-- Copies the template light named "SurfaceLight lamppost" onto every MeshPart
-- named "lamppost neon". Installed lights are enabled only during night mode.

local CollectionService = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")

local TEMPLATE_NAME = "SurfaceLight lamppost"
local TARGET_NAME = "lamppost neon"
local LIGHT_TAG = "NTR_NightLamppostLight"
local CONTROLLER_NAME = "NightLamppostLightController_Active"
local TEMPLATE_ATTRIBUTE = "NTRLamppostLightTemplate"

local templates = {}

for _, instance in ipairs(game:GetDescendants()) do
	if instance:IsA("SurfaceLight")
		and instance.Name == TEMPLATE_NAME
		and instance:GetAttribute(TEMPLATE_ATTRIBUTE) == true
	then
		table.insert(templates, instance)
	end
end

if #templates == 0 then
	for _, instance in ipairs(game:GetDescendants()) do
		if instance:IsA("SurfaceLight") and instance.Name == TEMPLATE_NAME then
			table.insert(templates, instance)
		end
	end
end

if #templates == 0 then
	error("[NTR Lamppost Lights] Aborted without changes. No SurfaceLight named " .. TEMPLATE_NAME .. " was found.")
end

local template = templates[1]
template:SetAttribute(TEMPLATE_ATTRIBUTE, true)

if #templates > 1 then
	warn(string.format(
		"[NTR Lamppost Lights] Found %d unmarked lights named %q. Using the first as the template and cleaning duplicate target lights.",
		#templates,
		TEMPLATE_NAME
	))
end

local targets = {}

for _, instance in ipairs(game:GetDescendants()) do
	if instance:IsA("MeshPart") and string.lower(instance.Name) == TARGET_NAME then
		table.insert(targets, instance)
	end
end

local installedCount = 0
local refreshedCount = 0
local skippedTemplateParent = 0

for _, target in ipairs(targets) do
	if template.Parent == target then
		for _, child in ipairs(target:GetChildren()) do
			if child ~= template
				and child:IsA("SurfaceLight")
				and child.Name == TEMPLATE_NAME
			then
				child:Destroy()
				refreshedCount += 1
			end
		end

		CollectionService:AddTag(template, LIGHT_TAG)
		template.Enabled = false
		skippedTemplateParent += 1
		continue
	end

	for _, child in ipairs(target:GetChildren()) do
		if child:IsA("SurfaceLight") and child.Name == TEMPLATE_NAME then
			child:Destroy()
			refreshedCount += 1
		end
	end

	local light = template:Clone()
	light:SetAttribute(TEMPLATE_ATTRIBUTE, nil)
	light.Enabled = false
	light.Parent = target
	CollectionService:AddTag(light, LIGHT_TAG)
	installedCount += 1
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
	error("[NTR Lamppost Lights] Existing controller path is not a LocalScript: " .. controller:GetFullName())
end

if not controller then
	controller = Instance.new("LocalScript")
	controller.Name = CONTROLLER_NAME
	controller.Parent = worldControllers
end

controller.Source = [==[
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local LIGHT_TAG = "NTR_NightLamppostLight"
local PRESET_ATTRIBUTE = "NTR_LightingPreset"
local NIGHT_BRIGHTNESS_THRESHOLD = 1

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

local function applyToLight(instance, isNight)
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

	for _, instance in ipairs(CollectionService:GetTagged(LIGHT_TAG)) do
		applyToLight(instance, isNight)
	end
end

CollectionService:GetInstanceAddedSignal(LIGHT_TAG):Connect(function(instance)
	applyToLight(instance, readNightMode())
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

print("[NTR Lamppost Lights] Template:", template:GetFullName())
print(string.format(
	"[NTR Lamppost Lights] Complete. Targets %d, installed %d, refreshed %d, template parent skipped %d.",
	#targets,
	installedCount,
	refreshedCount,
	skippedTemplateParent
))
print("[NTR Lamppost Lights] Enter Play mode and use N for night, M for day.")
