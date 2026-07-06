-- Neo Tokyo Racers - Free Roam Vehicle Spawn Phase 2
-- Creates explicit road-centre spawn markers and spawn tuning config.
--
-- This does not patch vehicle spawning yet. It prepares the reliable target
-- data that Phase 3 will use for click-to-spawn / click-to-swap.

local PHASE = "NTR Free Roam Vehicle Spawn Phase 2 Road Markers"
local ROAD_SPAWN_TAG = "NTR_RoadSpawnPoint"
local MODE = "INSTALL" -- "AUDIT" or "INSTALL"

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

local function ensureConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = ensureChild(kit, "Folder", "Config")
	local runtime = ensureChild(config, "Folder", "Runtime")
	local spawnConfig = ensureChild(runtime, "Folder", "FreeRoamVehicleSpawn")

	ensureNumber(spawnConfig, "MaxSpawnSpeedMph", 10, false)
	ensureNumber(spawnConfig, "SpawnCooldownSeconds", 1, false)
	ensureNumber(spawnConfig, "RoadSearchRadius", 300, false)
	ensureNumber(spawnConfig, "SpawnHeightOffset", 4, false)
	ensureNumber(spawnConfig, "SpawnClearanceRadius", 16, false)
	ensureNumber(spawnConfig, "StudsPerSecondToMph", 0.625, false)
	ensureBool(spawnConfig, "AllowFallbackToPlayerOffset", false, false)

	return spawnConfig
end

local function lowerName(instance)
	return string.lower(instance and instance.Name or "")
end

local function ancestorNameContains(instance, text)
	local current = instance.Parent
	while current do
		if string.find(lowerName(current), text, 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function isUsableRoadSurface(part)
	if not part:IsA("BasePart") then
		return false
	end

	local lower = lowerName(part)
	local exactRoadName = lower == "road" or lower == "road asphalt"
	if not exactRoadName then
		return false
	end

	local banned = { "marking", "divider", "edge", "light", "crossing", "lamp" }
	for _, text in ipairs(banned) do
		if string.find(lower, text, 1, true) or ancestorNameContains(part, text) then
			return false
		end
	end

	local size = part.Size
	local long = math.max(size.X, size.Z)
	local short = math.min(size.X, size.Z)
	if long < 18 or short < 6 or size.Y > 10 then
		return false
	end

	return true
end

local function flattenUnit(vector, fallback)
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 0.001 then
		return fallback or Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function markerCFrameForPart(part)
	local size = part.Size
	local pos = part.Position + Vector3.new(0, size.Y * 0.5 + 4, 0)
	local forward
	if size.X >= size.Z then
		forward = flattenUnit(part.CFrame.RightVector, Vector3.new(1, 0, 0))
	else
		forward = flattenUnit(part.CFrame.LookVector, Vector3.new(0, 0, -1))
	end
	return CFrame.lookAt(pos, pos + forward)
end

local function coordKey(position)
	local function bucket(value)
		return math.floor((value / 12) + 0.5) * 12
	end
	local function part(value)
		if value < 0 then
			return "M" .. tostring(math.abs(value))
		end
		return "P" .. tostring(value)
	end
	return part(bucket(position.X)) .. "_" .. part(bucket(position.Z))
end

local function collectRoadParts(cityRoot)
	local seen = {}
	local parts = {}
	local skipped = 0
	for _, inst in ipairs(cityRoot:GetDescendants()) do
		if inst:IsA("BasePart") then
			if isUsableRoadSurface(inst) then
				local key = coordKey(inst.Position)
				if not seen[key] then
					seen[key] = true
					table.insert(parts, inst)
				else
					skipped += 1
				end
			end
		end
	end
	table.sort(parts, function(a, b)
		if math.abs(a.Position.X - b.Position.X) > 0.01 then
			return a.Position.X < b.Position.X
		end
		return a.Position.Z < b.Position.Z
	end)
	return parts, skipped
end

local function createOrUpdateMarker(folder, index, part)
	local cf = markerCFrameForPart(part)
	local key = coordKey(part.Position)
	local markerName = "RoadSpawn_" .. key
	local marker = folder:FindFirstChild(markerName)
	if marker and not marker:IsA("BasePart") then
		error(marker:GetFullName() .. " exists but is not a BasePart")
	end
	if not marker then
		marker = Instance.new("Part")
		marker.Name = markerName
		marker.Parent = folder
	end

	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Transparency = 1
	marker.Size = Vector3.new(4, 1, 4)
	marker.CFrame = cf
	marker:SetAttribute("NTRGeneratedRoadSpawn", true)
	marker:SetAttribute("GeneratedBy", PHASE)
	marker:SetAttribute("SourceRoadPath", part:GetFullName())
	marker:SetAttribute("SourceRoadName", part.Name)
	marker:SetAttribute("RoadSpawnIndex", index)
	local yawRadians = 0
	pcall(function()
		yawRadians = math.atan2(cf.LookVector.X, cf.LookVector.Z)
	end)
	marker:SetAttribute("SpawnYawDegrees", math.deg(yawRadians))
	CollectionService:AddTag(marker, ROAD_SPAWN_TAG)
	return marker
end

info("Starting Phase 2 in MODE=" .. MODE .. ".")

local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
local city = world:FindFirstChild("City") or Workspace:FindFirstChild("GeneratedCityBlocks")
assert(city, "Could not find Workspace.NeoTokyoRacersWorld.City or Workspace.GeneratedCityBlocks.")

local roadParts, skippedDuplicates = collectRoadParts(city)
info("Usable exact road/asphalt surface parts: " .. tostring(#roadParts))
info("Skipped near-duplicate road centers: " .. tostring(skippedDuplicates))
for index = 1, math.min(16, #roadParts) do
	local part = roadParts[index]
	local size = part.Size
	info(string.format(
		"Candidate %02d: %s | size=(%.1f, %.1f, %.1f) pos=(%.1f, %.1f, %.1f)",
		index,
		part:GetFullName(),
		size.X,
		size.Y,
		size.Z,
		part.Position.X,
		part.Position.Y,
		part.Position.Z
	))
end

if MODE ~= "INSTALL" then
	info("AUDIT mode only. No markers/config were changed.")
	return
end

assert(#roadParts > 0, "No usable exact Road/Road Asphalt parts found. Do not install spawn markers from broad path-edge meshes.")

local spawnPoints = ensureChild(world, "Folder", "SpawnPoints")
local markerFolder = ensureChild(spawnPoints, "Folder", "RoadSpawnMarkers")
markerFolder:SetAttribute("RoadSpawnTag", ROAD_SPAWN_TAG)
markerFolder:SetAttribute("GeneratedBy", PHASE)
markerFolder:SetAttribute("SourceCityRoot", city:GetFullName())

local spawnConfig = ensureConfig()
local createdOrUpdated = 0
for index, part in ipairs(roadParts) do
	createOrUpdateMarker(markerFolder, index, part)
	createdOrUpdated += 1
end

info("Road spawn markers created/updated: " .. tostring(createdOrUpdated))
info("Marker folder: " .. markerFolder:GetFullName())
info("Tagged markers now visible to CollectionService: " .. tostring(#CollectionService:GetTagged(ROAD_SPAWN_TAG)))
info("Config folder: " .. spawnConfig:GetFullName())
warnLine("Phase 2 only prepares markers/config. Run Phase 3 later for click-to-spawn behavior.")
