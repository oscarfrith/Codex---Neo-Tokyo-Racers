-- Neo Tokyo Racers - RaceRouteDefinition
-- NTR_RACING_PHASE3_ROUTE_DEFINITION

local Workspace = game:GetService("Workspace")

local RouteDefinition = {}

local function numberAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "number" and value or fallback
end

local function stringAttribute(instance, name, fallback)
	local value = instance and instance:GetAttribute(name)
	return typeof(value) == "string" and value or fallback
end

local function indexedNameFallback(instance, fallback)
	local text = instance and instance.Name or ""
	local digits = string.match(text, "(%d+)$")
	return digits and tonumber(digits) or fallback
end

local function worldRoot()
	return Workspace:FindFirstChild("NeoTokyoRacersWorld")
end

function RouteDefinition.GetRoutesRoot()
	local world = worldRoot()
	return world and world:FindFirstChild("RaceRoutes")
end

function RouteDefinition.GetRouteFolder(routeId)
	local routes = RouteDefinition.GetRoutesRoot()
	return routes and routes:FindFirstChild(tostring(routeId or ""))
end

local function collectParts(folder, indexAttribute)
	local result = {}
	if not folder then return result end
	for _, item in ipairs(folder:GetChildren()) do
		if item:IsA("BasePart") then
			local nameIndex = indexedNameFallback(item, nil)
			local index = nameIndex or numberAttribute(item, indexAttribute, nil)
			if index ~= nil then
				table.insert(result, {
					Index = index,
					Name = item.Name,
					Part = item,
					CFrame = item.CFrame,
					Size = item.Size,
					RouteId = stringAttribute(item, "RouteId", nil),
				})
			end
		end
	end
	table.sort(result, function(a, b)
		if a.Index == b.Index then
			return a.Name < b.Name
		end
		return a.Index < b.Index
	end)
	return result
end

local function collectStartZones(route)
	local zones = {}
	local root = route and route:FindFirstChild("StartZones")
	if not root then return zones end
	for _, item in ipairs(root:GetChildren()) do
		if item:IsA("BasePart") then
			table.insert(zones, {
				Name = item.Name,
				Part = item,
				Mode = stringAttribute(item, "Mode", item.Name == "RaceStartZone" and "Race" or "TimeTrial"),
				EventId = stringAttribute(item, "EventId", nil),
				PromptActionText = stringAttribute(item, "PromptActionText", nil),
				CFrame = item.CFrame,
				Size = item.Size,
			})
		end
	end
	table.sort(zones, function(a, b)
		return a.Name < b.Name
	end)
	return zones
end

local function collectSpawnGrid(route)
	local grid = collectParts(route and route:FindFirstChild("SpawnGrid"), "GridIndex")
	for _, item in ipairs(grid) do
		item.GridIndex = item.Index
	end
	return grid
end

local function collectArrowMarkers(route)
	local arrows = collectParts(route and route:FindFirstChild("ArrowMarkers"), "ArrowIndex")
	for _, item in ipairs(arrows) do
		local part = item.Part
		item.ArrowIndex = item.Index
		item.TargetCheckpointIndex = numberAttribute(part, "TargetCheckpointIndex", item.Index)
		item.DisplayMode = stringAttribute(part, "DisplayMode", "WhenNext")
		item.ArrowStyle = stringAttribute(part, "ArrowStyle", "Chevron")
		item.ArrowAssetId = stringAttribute(part, "ArrowAssetId", "")
		item.Scale = numberAttribute(part, "Scale", 1)
		item.ColorRole = stringAttribute(part, "ColorRole", "Accent")
	end
	return arrows
end

local function mediaSummary(route)
	local media = route and route:FindFirstChild("Media")
	local trackImage = stringAttribute(route, "TrackImage", "")
	local mapImage = stringAttribute(route, "MapImage", "")
	if media then
		local trackValue = media:FindFirstChild("TrackImage")
		local mapValue = media:FindFirstChild("MapImage")
		if trackImage == "" and trackValue and trackValue:IsA("StringValue") then
			trackImage = trackValue.Value
		end
		if mapImage == "" and mapValue and mapValue:IsA("StringValue") then
			mapImage = mapValue.Value
		end
	end
	return {
		TrackImage = trackImage,
		MapImage = mapImage,
	}
end

function RouteDefinition.GetRouteDefinition(routeId)
	local route = RouteDefinition.GetRouteFolder(routeId)
	if not route then
		return nil, "Route not found: " .. tostring(routeId)
	end

	local checkpoints = collectParts(route:FindFirstChild("Checkpoints"), "CheckpointIndex")
	for _, checkpoint in ipairs(checkpoints) do
		checkpoint.IsFinish = false
	end

	local finishPart = route:FindFirstChild("FinishLine")
	local maxCheckpointIndex = 0
	for _, checkpoint in ipairs(checkpoints) do
		maxCheckpointIndex = math.max(maxCheckpointIndex, checkpoint.Index or 0)
	end
	local finishIndex = math.max(numberAttribute(finishPart, "CheckpointIndex", maxCheckpointIndex + 1), maxCheckpointIndex + 1)
	local finish = nil
	if finishPart and finishPart:IsA("BasePart") then
		finish = {
			Index = finishIndex,
			Name = finishPart.Name,
			Part = finishPart,
			CFrame = finishPart.CFrame,
			Size = finishPart.Size,
			RouteId = stringAttribute(finishPart, "RouteId", nil),
			IsFinish = true,
		}
	end

	local orderedGates = {}
	for _, checkpoint in ipairs(checkpoints) do
		table.insert(orderedGates, checkpoint)
	end
	if finish then
		table.insert(orderedGates, finish)
	end
	table.sort(orderedGates, function(a, b)
		if a.Index == b.Index then
			return tostring(a.Name) < tostring(b.Name)
		end
		return a.Index < b.Index
	end)

	local startZones = collectStartZones(route)
	local spawnGrid = collectSpawnGrid(route)
	return {
		RouteId = stringAttribute(route, "RouteId", tostring(routeId)),
		DisplayName = stringAttribute(route, "DisplayName", tostring(routeId)),
		SourceType = stringAttribute(route, "SourceType", "Official"),
		CreatorUserId = numberAttribute(route, "CreatorUserId", 0),
		Version = numberAttribute(route, "Version", 1),
		Folder = route,
		StartZones = startZones,
		SpawnGrid = spawnGrid,
		Checkpoints = checkpoints,
		FinishLine = finish,
		Gates = orderedGates,
		ArrowMarkers = collectArrowMarkers(route),
		Media = mediaSummary(route),
		ValidationSummary = {
			CheckpointCount = #checkpoints,
			HasFinish = finish ~= nil,
			GateCount = #orderedGates,
			SpawnCount = #spawnGrid,
			StartZoneCount = #startZones,
		},
	}
end

function RouteDefinition.GetGate(routeDefinition, gateIndex)
	if not routeDefinition then return nil end
	return routeDefinition.Gates and routeDefinition.Gates[gateIndex] or nil
end

function RouteDefinition.GetGateCount(routeDefinition)
	return routeDefinition and routeDefinition.Gates and #routeDefinition.Gates or 0
end

function RouteDefinition.GetFirstSpawnCFrame(routeDefinition)
	local grid = routeDefinition and routeDefinition.SpawnGrid
	if grid and grid[1] and grid[1].Part then
		return grid[1].Part.CFrame
	end
	local zones = routeDefinition and routeDefinition.StartZones
	if zones and zones[1] and zones[1].Part then
		return zones[1].Part.CFrame
	end
	local gate = RouteDefinition.GetGate(routeDefinition, 1)
	if gate and gate.Part then
		return gate.Part.CFrame
	end
	return CFrame.new()
end

return RouteDefinition
