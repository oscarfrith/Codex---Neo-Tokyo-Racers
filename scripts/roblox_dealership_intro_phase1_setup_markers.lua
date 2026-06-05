-- Neo Tokyo Racers - Dealership Intro Phase 1: Setup Markers
-- Run in Roblox Studio Command Bar, Edit mode.
--
-- Purpose:
--   Creates a safe, editable dealership intro marker hierarchy under:
--     Workspace.NeoTokyoRacersWorld.Dealership.Intro
--
-- Safe design:
--   - Safe to rerun.
--   - Reuses existing folders and marker parts.
--   - Sets default tuning attributes only when missing, so manual tuning survives reruns.
--   - Does not create backup folders.
--   - Does not delete, move, enable, disable, clone, or edit unrelated systems.

local Workspace = game:GetService("Workspace")

local SCRIPT_ID = "roblox_dealership_intro_phase1_setup_markers"

local WORLD_NAME = "NeoTokyoRacersWorld"
local DEALERSHIP_NAME = "Dealership"
local INTRO_NAME = "Intro"

local INTRO_ATTRIBUTE_DEFAULTS = {
	Enabled = true,
	DeskActivationDistance = 5,
	AutoOpenGarageAtDesk = true,
	ShowPathArrows = true,
	ShowObjectiveText = true,
	IntroObjectiveText = "Go to the dealership desk",
	DeskPromptText = "Open Garage",
	OnlyRunForNewPlayers = false,
	CameraIntroEnabled = true,
	CameraIntroDuration = 1.25,
	PathArrowSpacing = 12,
	PathArrowHeightOffset = 2,
	Debug = false,
}

local DESK_TRIGGER_ATTRIBUTE_DEFAULTS = {
	TriggerType = "GarageDesk",
	ActivationDistance = 5,
}

local MARKERS = {
	{
		folder = "Spawn",
		name = "IntroSpawnPoint",
		size = Vector3.new(6, 1, 6),
		offset = Vector3.new(0, 4, -24),
		color = Color3.fromRGB(80, 220, 140),
		transparency = 0.35,
		markerType = "IntroSpawn",
	},
	{
		folder = "Desk",
		name = "GarageDeskTrigger",
		size = Vector3.new(6, 5, 6),
		offset = Vector3.new(0, 4, -2),
		color = Color3.fromRGB(120, 255, 190),
		transparency = 0.45,
		markerType = "GarageDeskTrigger",
		attributes = DESK_TRIGGER_ATTRIBUTE_DEFAULTS,
	},
	{
		folder = "Camera",
		name = "DealershipLookCameraPoint",
		size = Vector3.new(3, 3, 3),
		offset = Vector3.new(-12, 8, -16),
		color = Color3.fromRGB(120, 180, 255),
		transparency = 0.4,
		markerType = "CameraPoint",
	},
	{
		folder = "Camera",
		name = "GaragePreviewCameraPoint",
		size = Vector3.new(3, 3, 3),
		offset = Vector3.new(12, 8, -8),
		color = Color3.fromRGB(80, 150, 255),
		transparency = 0.4,
		markerType = "CameraPoint",
	},
	{
		folder = "Preview",
		name = "VehiclePreviewPoint",
		size = Vector3.new(8, 1, 8),
		offset = Vector3.new(12, 4, 6),
		color = Color3.fromRGB(255, 220, 90),
		transparency = 0.35,
		markerType = "VehiclePreview",
	},
	{
		folder = "Path",
		name = "PathNode_01",
		size = Vector3.new(3, 1, 3),
		offset = Vector3.new(0, 3, -18),
		color = Color3.fromRGB(255, 120, 210),
		transparency = 0.35,
		markerType = "PathNode",
	},
	{
		folder = "Path",
		name = "PathNode_02",
		size = Vector3.new(3, 1, 3),
		offset = Vector3.new(0, 3, -12),
		color = Color3.fromRGB(255, 120, 210),
		transparency = 0.35,
		markerType = "PathNode",
	},
	{
		folder = "Path",
		name = "PathNode_03",
		size = Vector3.new(3, 1, 3),
		offset = Vector3.new(0, 3, -6),
		color = Color3.fromRGB(255, 120, 210),
		transparency = 0.35,
		markerType = "PathNode",
	},
	{
		folder = "Path",
		name = "PathNode_04",
		size = Vector3.new(3, 1, 3),
		offset = Vector3.new(0, 3, 0),
		color = Color3.fromRGB(255, 120, 210),
		transparency = 0.35,
		markerType = "PathNode",
	},
}

local created = {}
local reused = {}
local warnings = {}
local attributesAdded = {}
local attributesPreserved = {}

local function log(message)
	print("[NTR Dealership Intro Phase 1] " .. message)
end

local function warnLine(message)
	table.insert(warnings, message)
	warn("[NTR Dealership Intro Phase 1] " .. message)
end

local function safeFullName(instance)
	local ok, result = pcall(function()
		return instance:GetFullName()
	end)
	return ok and result or instance.Name
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if not existing:IsA("Folder") then
			error(("Existing %s is %s, expected Folder. No changes applied to that object."):format(
				safeFullName(existing),
				existing.ClassName
			))
		end
		table.insert(reused, safeFullName(existing) .. " -> Folder")
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	table.insert(created, safeFullName(folder) .. " -> Folder")
	return folder
end

local function setDefaultAttribute(instance, name, value)
	if instance:GetAttribute(name) == nil then
		instance:SetAttribute(name, value)
		table.insert(attributesAdded, safeFullName(instance) .. "." .. name .. " = " .. tostring(value))
	else
		table.insert(attributesPreserved, safeFullName(instance) .. "." .. name .. " = " .. tostring(instance:GetAttribute(name)))
	end
end

local function setDefaultAttributes(instance, defaults)
	for name, value in pairs(defaults) do
		setDefaultAttribute(instance, name, value)
	end
end

local function markerBaseCFrame()
	local world = Workspace:FindFirstChild(WORLD_NAME)
	local spawnPoint = world
		and world:FindFirstChild("SpawnPoints")
		and world.SpawnPoints:FindFirstChild("VehicleSpawnPoint")

	if spawnPoint and spawnPoint:IsA("BasePart") then
		return spawnPoint.CFrame, "Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint"
	end

	warnLine("Workspace.NeoTokyoRacersWorld.SpawnPoints.VehicleSpawnPoint was not found as a BasePart. Markers will be placed near world origin and should be moved in Studio.")
	return CFrame.new(0, 5, 0), "world origin fallback"
end

local function ensureMarkerPart(parent, spec, baseCFrame, baseSource)
	local existing = parent:FindFirstChild(spec.name)
	local part
	local wasCreated = false

	if existing then
		if not existing:IsA("BasePart") then
			warnLine(("Existing %s is %s, expected BasePart. Leaving it unchanged except no part properties can be applied."):format(
				safeFullName(existing),
				existing.ClassName
			))
			return existing, false
		end

		part = existing
		table.insert(reused, safeFullName(part) .. " -> " .. part.ClassName)
	else
		part = Instance.new("Part")
		part.Name = spec.name
		part.CFrame = baseCFrame * CFrame.new(spec.offset)
		part.Parent = parent
		wasCreated = true
		table.insert(created, safeFullName(part) .. " -> Part at " .. baseSource)
	end

	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.Size = spec.size
	part.Color = spec.color
	part.Transparency = spec.transparency
	part.Material = Enum.Material.Neon
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	setDefaultAttribute(part, "CreatedBy", SCRIPT_ID)
	setDefaultAttribute(part, "MarkerType", spec.markerType)
	setDefaultAttribute(part, "EditableMarker", true)
	setDefaultAttribute(part, "CreatedFromBase", baseSource)

	if wasCreated then
		part:SetAttribute("NeedsManualPositionReview", true)
	else
		setDefaultAttribute(part, "NeedsManualPositionReview", false)
	end

	if spec.attributes then
		setDefaultAttributes(part, spec.attributes)
	end

	return part, wasCreated
end

local world = ensureFolder(Workspace, WORLD_NAME)
local dealership = ensureFolder(world, DEALERSHIP_NAME)
local intro = ensureFolder(dealership, INTRO_NAME)

setDefaultAttribute(intro, "CreatedBy", SCRIPT_ID)
setDefaultAttributes(intro, INTRO_ATTRIBUTE_DEFAULTS)

local baseCFrame, baseSource = markerBaseCFrame()

local markerFolders = {}
for _, folderName in ipairs({ "Spawn", "Desk", "Camera", "Preview", "Path" }) do
	markerFolders[folderName] = ensureFolder(intro, folderName)
end

local createdParts = 0
local reusedParts = 0

for _, spec in ipairs(MARKERS) do
	local _, wasCreated = ensureMarkerPart(markerFolders[spec.folder], spec, baseCFrame, baseSource)
	if wasCreated then
		createdParts += 1
	else
		reusedParts += 1
	end
end

local report = {}
local function line(text)
	table.insert(report, text)
end

line("# Neo Tokyo Racers Dealership Intro Phase 1 Setup Markers")
line("")
line("Generated in Studio: " .. os.date("%Y-%m-%d %H:%M:%S"))
line("")
line("## Summary")
line("")
line("- Intro path: " .. safeFullName(intro))
line("- Base placement source: " .. baseSource)
line("- Marker parts created: " .. tostring(createdParts))
line("- Marker parts reused: " .. tostring(reusedParts))
line("- Folders/objects created: " .. tostring(#created))
line("- Folders/objects reused: " .. tostring(#reused))
line("- Missing attributes added: " .. tostring(#attributesAdded))
line("- Existing attributes preserved: " .. tostring(#attributesPreserved))
line("- Warnings: " .. tostring(#warnings))
line("")

line("## Created")
line("")
if #created == 0 then
	line("- None.")
else
	for _, item in ipairs(created) do
		line("- " .. item)
	end
end
line("")

line("## Reused")
line("")
if #reused == 0 then
	line("- None.")
else
	for _, item in ipairs(reused) do
		line("- " .. item)
	end
end
line("")

line("## Warnings")
line("")
if #warnings == 0 then
	line("- None.")
else
	for _, item in ipairs(warnings) do
		line("- " .. item)
	end
end
line("")

line("## Next Steps")
line("")
line("1. In Studio, expand Workspace.NeoTokyoRacersWorld.Dealership.Intro.")
line("2. Move the visible translucent marker parts into their final dealership positions.")
line("3. Leave the attributes on Intro and GarageDeskTrigger unless intentionally tuning the next runtime phase.")
line("4. Rerun the Phase 0 audit to verify the planned intro path and marker objects now exist.")

log("Setup complete. Created marker parts: " .. tostring(createdParts) .. "; reused marker parts: " .. tostring(reusedParts))
log("Intro folder: " .. safeFullName(intro))
print(table.concat(report, "\n"))
