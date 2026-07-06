-- Neo Tokyo Racers - Free Roam Vehicle Spawn Phase 2
-- Preferred first-pass road spawn marker setup from curated blockout roads.
--
-- Source:
--   Workspace["Test + WIP Assets"].Blockout.Roads
--
-- Output:
--   Workspace.NeoTokyoRacersWorld.SpawnPoints.RoadSpawnMarkers
--
-- This is hierarchy/config setup only. It does not patch click-to-spawn yet.

local PHASE = "NTR Free Roam Vehicle Spawn Phase 2 Blockout Road Markers"
local ROAD_SPAWN_TAG = "NTR_RoadSpawnPoint"
local MODE = "INSTALL" -- "AUDIT" or "INSTALL"
local CLEAR_PREVIOUS_PHASE2_MARKERS = true
local ROAD_COLOR_RGB = Vector3.new(95, 95, 95)
local ROAD_COLOR_TOLERANCE = 2

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function warnLine(message)
	warn("[" .. PHASE .. "] " .. tostring(message))
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, existing:GetFullName() .. " must be a " .. className)
		return existing
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function ensureNumber(parent, name, value, force)
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new("NumberValue")
		item.Name = name
		item.Parent = parent
	end
	assert(item:IsA("NumberValue"), item:GetFullName() .. " must be a NumberValue")
	if force or item.Value == 0 then
		item.Value = value
	end
	return item
end

local function ensureBool(parent, name, value, force)
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new("BoolValue")
		item.Name = name
		item.Parent = parent
	end
	assert(item:IsA("BoolValue"), item:GetFullName() .. " must be a BoolValue")
	if force then
		item.Value = value
	end
	return item
end

local function findCaseInsensitive(parent, name)
	if not parent then
		return nil
	end
	local exact = parent:FindFirstChild(name)
	if exact then
		return exact
	end
	local target = string.lower(name)
	for _, child in ipairs(parent:GetChildren()) do
		if string.lower(child.Name) == target then
			return child
		end
	end
	return nil
end

local function getRoadSourceRoot()
	local wip = Workspace:FindFirstChild("Test + WIP Assets")
	assert(wip, 'Missing Workspace["Test + WIP Assets"].')
	local blockout = findCaseInsensitive(wip, "Blockout")
	assert(blockout, 'Missing Workspace["Test + WIP Assets"].Blockout.')
	local roads = findCaseInsensitive(blockout, "Roads")
	assert(roads, 'Missing Workspace["Test + WIP Assets"].Blockout.Roads.')
	return roads
end

local function ensureSpawnConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = ensureChild(kit, "Folder", "Config")
	local runtime = ensureChild(config, "Folder", "Runtime")
	local spawnConfig = ensureChild(runtime, "Folder", "FreeRoamVehicleSpawn")

	ensureNumber(spawnConfig, "MaxSpawnSpeedMph", 10, false)
	ensureNumber(spawnConfig, "SpawnCooldownSeconds", 1, false)
	ensureNumber(spawnConfig, "RoadSearchRadius", 350, false)
	ensureNumber(spawnConfig, "SpawnHeightOffset", 4, false)
	ensureNumber(spawnConfig, "SpawnClearanceRadius", 16, false)
	ensureNumber(spawnConfig, "StudsPerSecondToMph", 0.625, false)
	ensureBool(spawnConfig, "AllowFallbackToPlayerOffset", false, false)

	return spawnConfig
end

local function rgbFromColor3(color)
	return Vector3.new(
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function colorMatchesRoadGrey(part)
	local rgb = rgbFromColor3(part.Color)
	return math.abs(rgb.X - ROAD_COLOR_RGB.X) <= ROAD_COLOR_TOLERANCE
		and math.abs(rgb.Y - ROAD_COLOR_RGB.Y) <= ROAD_COLOR_TOLERANCE
		and math.abs(rgb.Z - ROAD_COLOR_RGB.Z) <= ROAD_COLOR_TOLERANCE
end

local function collectRoadParts(root)
	local roads = {}
	local skippedWrongColor = 0
	local skippedNonPartRoads = 0
	for _, inst in ipairs(root:GetDescendants()) do
		if inst.Name == "Road" then
			if inst:IsA("BasePart") then
				if colorMatchesRoadGrey(inst) then
					table.insert(roads, inst)
				else
					skippedWrongColor += 1
				end
			else
				skippedNonPartRoads += 1
			end
		end
	end
	table.sort(roads, function(a, b)
		if math.abs(a.Position.X - b.Position.X) > 0.01 then
			return a.Position.X < b.Position.X
		end
		if math.abs(a.Position.Z - b.Position.Z) > 0.01 then
			return a.Position.Z < b.Position.Z
		end
		return a:GetFullName() < b:GetFullName()
	end)
	return roads, skippedWrongColor, skippedNonPartRoads
end

local function flatUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.001 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function roadForward(road)
	if road.Size.X >= road.Size.Z then
		return flatUnit(road.CFrame.RightVector, Vector3.new(1, 0, 0))
	end
	return flatUnit(road.CFrame.LookVector, Vector3.new(0, 0, -1))
end

local function markerCFrame(road, heightOffset)
	local position = road.Position + Vector3.new(0, road.Size.Y * 0.5 + heightOffset, 0)
	local forward = roadForward(road)
	return CFrame.lookAt(position, position + forward)
end

local function markerNameForIndex(index)
	return string.format("RoadSpawn_%04d", index)
end

local function yawDegreesFromCFrame(cf)
	local ok, radians = pcall(function()
		if math.atan2 then
			return math.atan2(cf.LookVector.X, cf.LookVector.Z)
		end
		return math.atan(cf.LookVector.X, cf.LookVector.Z)
	end)
	return math.deg(ok and radians or 0)
end

local function clearPreviousMarkers(folder)
	local removed = 0
	for _, child in ipairs(folder:GetChildren()) do
		if child:GetAttribute("NTRGeneratedRoadSpawn") == true then
			child:Destroy()
			removed += 1
		end
	end
	return removed
end

local function createMarker(folder, index, road, heightOffset)
	local cf = markerCFrame(road, heightOffset)
	local marker = Instance.new("Part")
	marker.Name = markerNameForIndex(index)
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	marker.CFrame = cf
	marker:SetAttribute("NTRGeneratedRoadSpawn", true)
	marker:SetAttribute("GeneratedBy", PHASE)
	marker:SetAttribute("SourceRoadPath", road:GetFullName())
	marker:SetAttribute("SourceRoadName", road.Name)
	marker:SetAttribute("SourceRoadSize", tostring(road.Size))
	marker:SetAttribute("RoadSpawnIndex", index)
	marker:SetAttribute("SpawnYawDegrees", yawDegreesFromCFrame(cf))
	marker.Parent = folder
	CollectionService:AddTag(marker, ROAD_SPAWN_TAG)
	return marker
end

info("Starting Phase 2 blockout road marker setup in MODE=" .. MODE .. ".")

local roadsRoot = getRoadSourceRoot()
local roads, skippedWrongColor, skippedNonPartRoads = collectRoadParts(roadsRoot)
info("Source root: " .. roadsRoot:GetFullName())
info("Road parts named exactly 'Road' with colour #5f5f5f / RGB(95, 95, 95): " .. tostring(#roads))
info("Skipped Road objects with different colour: " .. tostring(skippedWrongColor))
info("Skipped non-BasePart Road objects: " .. tostring(skippedNonPartRoads))

for index = 1, math.min(20, #roads) do
	local road = roads[index]
	local size = road.Size
	info(string.format(
		"Road %04d: %s | size=(%.1f, %.1f, %.1f) pos=(%.1f, %.1f, %.1f)",
		index,
		road:GetFullName(),
		size.X,
		size.Y,
		size.Z,
		road.Position.X,
		road.Position.Y,
		road.Position.Z
	))
end

if MODE ~= "INSTALL" then
	info("AUDIT mode only. No markers/config were changed.")
	return
end

assert(#roads > 0, "No BasePart named exactly 'Road' with Color RGB(95, 95, 95) / #5f5f5f found under the blockout roads root.")

local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
local spawnPoints = ensureChild(world, "Folder", "SpawnPoints")
local markerFolder = ensureChild(spawnPoints, "Folder", "RoadSpawnMarkers")
markerFolder:SetAttribute("RoadSpawnTag", ROAD_SPAWN_TAG)
markerFolder:SetAttribute("GeneratedBy", PHASE)
markerFolder:SetAttribute("SourceRoadRoot", roadsRoot:GetFullName())
markerFolder:SetAttribute("MarkerKind", "InvisiblePart")

local spawnConfig = ensureSpawnConfig()
local heightOffset = ensureNumber(spawnConfig, "SpawnMarkerHeightOffset", 4, false).Value

local removed = 0
if CLEAR_PREVIOUS_PHASE2_MARKERS then
	removed = clearPreviousMarkers(markerFolder)
end

local created = 0
for index, road in ipairs(roads) do
	createMarker(markerFolder, index, road, heightOffset)
	created += 1
end

info("Removed previous generated markers: " .. tostring(removed))
info("Created road spawn markers: " .. tostring(created))
info("Marker folder: " .. markerFolder:GetFullName())
info("Tagged NTR_RoadSpawnPoint markers: " .. tostring(#CollectionService:GetTagged(ROAD_SPAWN_TAG)))
info("Config folder: " .. spawnConfig:GetFullName())
warnLine("Inspect markers before Phase 3. If some blockout road parts sit under buildings/interiors, move/delete those markers manually or tag them disabled later.")
