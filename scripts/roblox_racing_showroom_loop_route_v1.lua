-- Neo Tokyo Racers - Showroom Loop route authoring installer V1.1
--
-- Run in Roblox Studio Edit mode from the Command Bar.
--
-- Modes:
--   REPAIR   - preserve the mirrored 17-checkpoint route, repair its finish
--              and segment contract, publish matching Race/TT/HUD config,
--              enable both entrances, and audit the result.
--   PREPARE  - clone the confirmed ShiftedCanalSprint content contract,
--              translate it to the showroom area, create 17 checkpoints,
--              and keep both entrances/catalog events inactive.
--   COMPILE  - apply the movable StartPivot to the entrances, grid, finish,
--              and browser teleport point. It never moves checkpoints.
--   AUDIT    - read-only validation of the draft or active route.
--   ACTIVATE - require a clean authoring audit, publish the two event
--              definitions atomically, enable the entrances, and hide aids.
--   ROLLBACK - remove only the Showroom Loop live event definitions, disable
--              its entrances, and reveal the preserved authoring route.
--
-- Recommended sequence:
--   1. PREPARE once.
--   2. Move/rotate ShowroomLoop.Authoring.StartPivot, then use COMPILE.
--   3. Move every Checkpoint_001..Checkpoint_017 at least once.
--   4. Move/add arrow groups inside the prepared CheckpointA-B folders.
--   5. AUDIT, then ACTIVATE only after 0 BLOCKER.
--
-- This installer does not patch script source, create in-game backups, alter
-- ShiftedCanalSprint, or create another racing runtime owner.

local MODE = "REPAIR" -- "REPAIR", "PREPARE", "COMPILE", "AUDIT", "ACTIVATE", "ROLLBACK"

local SOURCE_ROUTE_ID = "ShiftedCanalSprint"
local ROUTE_ID = "ShowroomLoop"
local DISPLAY_NAME = "Showroom Loop"
local RACE_EVENT_ID = "showroom_loop_race"
local TIME_TRIAL_EVENT_ID = "showroom_loop_tt"
local CHECKPOINT_COUNT = 17
local START_POSITION = Vector3.new(1400, 101, -1250)
local START_YAW_DEGREES = 0

local INSTALLER_VERSION = "NTR_SHOWROOM_LOOP_ROUTE_V1_1"
local LEGACY_INSTALLER_VERSION = "NTR_SHOWROOM_LOOP_ROUTE_V1"
local PHASE = "NTR Showroom Loop V1.1"
local ROUTE_MARKER_ATTRIBUTE = "NTR_ShowroomLoopInstallerVersion"
local AUTHORING_ACCEPTED_ATTRIBUTE = "NTR_ShowroomLoopAuthoredCheckpointCount"
local INITIAL_CFRAME_ATTRIBUTE = "NTR_ShowroomLoopInitialCFrame"
local START_LOCAL_CFRAME_ATTRIBUTE = "NTR_ShowroomLoopStartLocalCFrame"
local AUTHORING_LABEL_NAME = "NTR_ShowroomLoopAuthoringLabel"
local PROMPT_NAME = "NTR_RaceEntryPrompt"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local blockers = 0
local warnings = 0
local infos = 0

local function line(kind, message)
	if kind == "BLOCKER" then
		blockers += 1
		warn(string.format("[%s] BLOCKER: %s", PHASE, tostring(message)))
	elseif kind == "WARN" then
		warnings += 1
		warn(string.format("[%s] WARN: %s", PHASE, tostring(message)))
	else
		infos += 1
		print(string.format("[%s] %s: %s", PHASE, kind, tostring(message)))
	end
end

local function resetAuditCounts()
	blockers = 0
	warnings = 0
	infos = 0
end

local function child(parent, ...)
	local current = parent
	for _, name in ipairs({ ... }) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function requireEditMode()
	assert(not RunService:IsRunning(), PHASE .. " must run in Studio Edit mode, not during Play.")
end

local function roots()
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	assert(world, "Missing Workspace.NeoTokyoRacersWorld")
	local routes = world:FindFirstChild("RaceRoutes")
	assert(routes, "Missing Workspace.NeoTokyoRacersWorld.RaceRoutes")

	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	assert(kit, "Missing ReplicatedStorage.NeoTokyoRacers")
	local racing = child(kit, "Config", "Racing")
	assert(racing, "Missing ReplicatedStorage.NeoTokyoRacers.Config.Racing")
	local raceCatalog = racing:FindFirstChild("RaceCatalog")
	local timeTrialCatalog = racing:FindFirstChild("TimeTrialCatalog")
	local hudMapCatalog = racing:FindFirstChild("HudMapCatalog")
	assert(raceCatalog, "Missing Config.Racing.RaceCatalog")
	assert(timeTrialCatalog, "Missing Config.Racing.TimeTrialCatalog")
	assert(hudMapCatalog, "Missing Config.Racing.HudMapCatalog")

	return routes, raceCatalog, timeTrialCatalog, hudMapCatalog
end

local function sortedIndexedParts(folder, attributeName)
	local result = {}
	for _, item in ipairs(folder and folder:GetChildren() or {}) do
		if item:IsA("BasePart") then
			local index = tonumber(string.match(item.Name, "(%d+)$"))
				or tonumber(item:GetAttribute(attributeName))
			if index then
				table.insert(result, { Index = index, Part = item })
			end
		end
	end
	table.sort(result, function(a, b)
		if a.Index == b.Index then
			return a.Part.Name < b.Part.Name
		end
		return a.Index < b.Index
	end)
	return result
end

local function sourceContract(routes, raceCatalog, timeTrialCatalog, hudMapCatalog)
	local route = routes:FindFirstChild(SOURCE_ROUTE_ID)
	assert(route, "Missing confirmed source route " .. SOURCE_ROUTE_ID)
	assert(route:GetAttribute("RouteId") == SOURCE_ROUTE_ID, "Source route RouteId changed")
	assert(route:GetAttribute("RouteType") == "Circuit", "Source route is no longer a Circuit")

	local checkpoints = sortedIndexedParts(route:FindFirstChild("Checkpoints"), "CheckpointIndex")
	assert(#checkpoints == 14, "Expected 14 source checkpoints, found " .. tostring(#checkpoints))
	assert(#sortedIndexedParts(route:FindFirstChild("SpawnGrid"), "GridIndex") == 6, "Expected 6 source grid positions")
	assert(route:FindFirstChild("FinishLine") and route.FinishLine:IsA("BasePart"), "Missing source FinishLine")
	assert(child(route, "StartZones", "RaceStartZone"), "Missing source RaceStartZone")
	assert(child(route, "StartZones", "TimeTrialStartZone"), "Missing source TimeTrialStartZone")
	assert(child(route, "TeleportPoints", "RaceBrowserTeleportPoint"), "Missing source browser teleport point")

	local sourceRace = raceCatalog:FindFirstChild(SOURCE_ROUTE_ID)
	local sourceTimeTrial = timeTrialCatalog:FindFirstChild(SOURCE_ROUTE_ID)
	local sourceHudMap = hudMapCatalog:FindFirstChild(SOURCE_ROUTE_ID)
	assert(sourceRace and sourceRace:GetAttribute("EventId") == "shifted_canal_sprint_race", "Source Race event contract changed")
	assert(sourceTimeTrial and sourceTimeTrial:GetAttribute("EventId") == "shifted_canal_sprint_tt", "Source Time Trial event contract changed")
	assert(sourceHudMap and sourceHudMap:IsA("Folder"), "Source HUD map config is missing")
	return route, sourceRace, sourceTimeTrial, sourceHudMap
end

local function installerOwns(route)
	local marker = route and route:GetAttribute(ROUTE_MARKER_ATTRIBUTE)
	return marker == INSTALLER_VERSION or marker == LEGACY_INSTALLER_VERSION
end

local function desiredPivotCFrame()
	return CFrame.new(START_POSITION) * CFrame.Angles(0, math.rad(START_YAW_DEGREES), 0)
end

local function transformRouteParts(route, sourcePivot, targetPivot)
	for _, item in ipairs(route:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CFrame = targetPivot * sourcePivot:ToObjectSpace(item.CFrame)
		end
	end
end

local function replaceRouteReferences(route)
	route.Name = ROUTE_ID
	route:SetAttribute("RouteId", ROUTE_ID)
	route:SetAttribute("DisplayName", DISPLAY_NAME)
	route:SetAttribute("RouteType", "Circuit")
	route:SetAttribute("AuthoringNote", "Showroom Loop V1 draft. Move all checkpoints and compile StartPivot before activation.")
	route:SetAttribute(ROUTE_MARKER_ATTRIBUTE, INSTALLER_VERSION)

	for _, item in ipairs(route:GetDescendants()) do
		for attributeName, value in pairs(item:GetAttributes()) do
			if value == SOURCE_ROUTE_ID then
				item:SetAttribute(attributeName, ROUTE_ID)
			elseif value == "shifted_canal_sprint_race" then
				item:SetAttribute(attributeName, RACE_EVENT_ID)
			elseif value == "shifted_canal_sprint_tt" then
				item:SetAttribute(attributeName, TIME_TRIAL_EVENT_ID)
			end
		end
	end

	local raceZone = child(route, "StartZones", "RaceStartZone")
	local timeTrialZone = child(route, "StartZones", "TimeTrialStartZone")
	raceZone:SetAttribute("EventId", RACE_EVENT_ID)
	raceZone:SetAttribute("RouteId", ROUTE_ID)
	raceZone:SetAttribute("Mode", "Race")
	raceZone:SetAttribute("PromptActionText", "Join Race")
	raceZone:SetAttribute("Enabled", false)
	timeTrialZone:SetAttribute("EventId", TIME_TRIAL_EVENT_ID)
	timeTrialZone:SetAttribute("RouteId", ROUTE_ID)
	timeTrialZone:SetAttribute("Mode", "TimeTrial")
	timeTrialZone:SetAttribute("PromptActionText", "Start Time Trial")
	timeTrialZone:SetAttribute("Enabled", false)

	for _, zone in ipairs({ raceZone, timeTrialZone }) do
		local prompt = zone:FindFirstChild(PROMPT_NAME)
		if prompt then
			prompt:Destroy()
		end
	end

	local media = route:FindFirstChild("Media")
	for _, name in ipairs({ "TrackImage", "MapImage" }) do
		local value = media and media:FindFirstChild(name)
		if value and value:IsA("StringValue") then
			value.Value = ""
		end
	end
	route:SetAttribute("TrackImage", nil)
	route:SetAttribute("MapImage", nil)
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing:IsA("Folder"), existing:GetFullName() .. " must be a Folder")
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensureBillboard(part, text)
	local billboard = part:FindFirstChild(AUTHORING_LABEL_NAME)
	if billboard and not billboard:IsA("BillboardGui") then
		billboard:Destroy()
		billboard = nil
	end
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = AUTHORING_LABEL_NAME
		billboard.AlwaysOnTop = true
		billboard.LightInfluence = 0
		billboard.MaxDistance = 1200
		billboard.Size = UDim2.fromOffset(220, 46)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, math.max(5, part.Size.Y * 0.55 + 2), 0)
		billboard.Parent = part

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundColor3 = Color3.fromRGB(10, 12, 20)
		label.BackgroundTransparency = 0.15
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.fromRGB(255, 225, 90)
		label.TextScaled = true
		label.TextStrokeTransparency = 0.35
		label.Parent = billboard
	end
	local label = billboard:FindFirstChild("Label")
	if label and label:IsA("TextLabel") then
		label.Text = text
	end
	billboard.Enabled = true
	return billboard
end

local function ensureStartPivot(route)
	local authoring = ensureFolder(route, "Authoring")
	local pivot = authoring:FindFirstChild("StartPivot")
	if pivot and not pivot:IsA("BasePart") then
		error(pivot:GetFullName() .. " must be a BasePart")
	end
	if not pivot then
		pivot = Instance.new("Part")
		pivot.Name = "StartPivot"
		pivot.Size = Vector3.new(18, 1, 18)
		pivot.CFrame = desiredPivotCFrame()
		pivot.Anchored = true
		pivot.CanCollide = false
		pivot.CanTouch = false
		pivot.CanQuery = true
		pivot.Material = Enum.Material.Neon
		pivot.Color = Color3.fromRGB(255, 205, 45)
		pivot.Transparency = 0.2
		pivot.Parent = authoring
	end
	pivot:SetAttribute("AuthoringPurpose", "Move and rotate this part, then run COMPILE. Checkpoints are never moved by COMPILE.")
	pivot:SetAttribute(ROUTE_MARKER_ATTRIBUTE, INSTALLER_VERSION)
	ensureBillboard(pivot, "SHOWROOM LOOP START PIVOT")
	return pivot
end

local function configureCheckpoint(part, index, initialCFrame)
	part.Name = string.format("Checkpoint_%03d", index)
	part:SetAttribute("CheckpointIndex", index)
	part:SetAttribute("RouteId", ROUTE_ID)
	part:SetAttribute("IsFinish", false)
	if part:GetAttribute("RadiusStuds") == nil then
		part:SetAttribute("RadiusStuds", 20)
	end
	if part:GetAttribute(INITIAL_CFRAME_ATTRIBUTE) == nil then
		part:SetAttribute(INITIAL_CFRAME_ATTRIBUTE, initialCFrame or part.CFrame)
	end
	ensureBillboard(part, string.format("CHECKPOINT %02d", index))
end

local function ensureCheckpointCount(route, pivot)
	local checkpointsFolder = route:FindFirstChild("Checkpoints")
	assert(checkpointsFolder, "Showroom Loop is missing Checkpoints")
	local checkpoints = sortedIndexedParts(checkpointsFolder, "CheckpointIndex")
	assert(#checkpoints >= 1, "Showroom Loop has no checkpoint template")

	local byIndex = {}
	for _, entry in ipairs(checkpoints) do
		assert(not byIndex[entry.Index], "Duplicate checkpoint index " .. tostring(entry.Index))
		byIndex[entry.Index] = entry.Part
	end

	local template = checkpoints[#checkpoints].Part
	for index = 1, CHECKPOINT_COUNT do
		local part = byIndex[index]
		if not part then
			part = template:Clone()
			for _, childItem in ipairs(part:GetChildren()) do
				childItem:Destroy()
			end
			local column = (index - 15) % 3
			local row = math.floor((index - 15) / 3)
			part.CFrame = pivot.CFrame
				* CFrame.new((column - 1) * 50, 10, -90 - row * 42)
			part.Parent = checkpointsFolder
			byIndex[index] = part
		end
		configureCheckpoint(part, index, part.CFrame)
	end

	for _, entry in ipairs(sortedIndexedParts(checkpointsFolder, "CheckpointIndex")) do
		if entry.Index > CHECKPOINT_COUNT then
			error("Unexpected checkpoint beyond " .. tostring(CHECKPOINT_COUNT) .. ": " .. entry.Part.Name)
		end
	end

	local finish = route:FindFirstChild("FinishLine")
	assert(finish and finish:IsA("BasePart"), "Showroom Loop is missing FinishLine")
	finish:SetAttribute("CheckpointIndex", CHECKPOINT_COUNT + 1)
	finish:SetAttribute("RouteId", ROUTE_ID)
	finish:SetAttribute("IsFinish", true)
end

local function configureSegmentFolder(folder, fromIndex, toIndex)
	folder.Name = "Checkpoint" .. tostring(fromIndex) .. "-" .. tostring(toIndex)
	folder:SetAttribute("FromCheckpointIndex", fromIndex)
	folder:SetAttribute("ToCheckpointIndex", toIndex)
	folder:SetAttribute("SegmentKey", folder.Name)
	folder:SetAttribute("RouteId", ROUTE_ID)
	folder:SetAttribute("Enabled", true)
end

local function ensureArrowSegments(route)
	local arrows = route:FindFirstChild("ArrowMarkers")
	assert(arrows and arrows:IsA("Folder"), "Showroom Loop is missing ArrowMarkers")

	local oldClosing = arrows:FindFirstChild("Checkpoint14-0")
	local finalClosing = arrows:FindFirstChild("Checkpoint" .. CHECKPOINT_COUNT .. "-0")
	if oldClosing and not finalClosing then
		oldClosing.Name = "Checkpoint" .. CHECKPOINT_COUNT .. "-0"
		finalClosing = oldClosing
	end

	for fromIndex = 0, CHECKPOINT_COUNT - 1 do
		local toIndex = fromIndex + 1
		local name = "Checkpoint" .. fromIndex .. "-" .. toIndex
		local folder = arrows:FindFirstChild(name)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = arrows
		end
		assert(folder:IsA("Folder"), folder:GetFullName() .. " must be a Folder")
		configureSegmentFolder(folder, fromIndex, toIndex)
	end

	finalClosing = arrows:FindFirstChild("Checkpoint" .. CHECKPOINT_COUNT .. "-0")
	if not finalClosing then
		finalClosing = Instance.new("Folder")
		finalClosing.Name = "Checkpoint" .. CHECKPOINT_COUNT .. "-0"
		finalClosing.Parent = arrows
	end
	configureSegmentFolder(finalClosing, CHECKPOINT_COUNT, 0)
	arrows:SetAttribute("NTR_Phase10B_FolderSegments", true)
end

local function startLayoutParts(route)
	local result = {}
	for _, containerName in ipairs({ "StartZones", "SpawnGrid", "TeleportPoints" }) do
		local container = route:FindFirstChild(containerName)
		for _, item in ipairs(container and container:GetDescendants() or {}) do
			if item:IsA("BasePart") then
				table.insert(result, item)
			end
		end
	end
	local finish = route:FindFirstChild("FinishLine")
	if finish and finish:IsA("BasePart") then
		table.insert(result, finish)
	end
	return result
end

local function captureStartOffsets(route, pivot)
	for _, part in ipairs(startLayoutParts(route)) do
		part:SetAttribute(START_LOCAL_CFRAME_ATTRIBUTE, pivot.CFrame:ToObjectSpace(part.CFrame))
	end
end

local function compileStartLayout(route)
	local pivot = ensureStartPivot(route)
	local count = 0
	for _, part in ipairs(startLayoutParts(route)) do
		local localCFrame = part:GetAttribute(START_LOCAL_CFRAME_ATTRIBUTE)
		assert(typeof(localCFrame) == "CFrame", "Missing start-layout offset on " .. part:GetFullName())
		part.CFrame = pivot.CFrame * localCFrame
		count += 1
	end
	line("PASS", "Compiled " .. tostring(count) .. " start-layout parts from Authoring.StartPivot; checkpoints were untouched.")
end

local function setAuthoringVisible(route, visible)
	local pivot = child(route, "Authoring", "StartPivot")
	if pivot and pivot:IsA("BasePart") then
		pivot.Transparency = visible and 0.2 or 1
		pivot.CanQuery = visible
		local label = pivot:FindFirstChild(AUTHORING_LABEL_NAME)
		if label and label:IsA("BillboardGui") then
			label.Enabled = visible
		end
	end
	local checkpoints = route:FindFirstChild("Checkpoints")
	for _, entry in ipairs(sortedIndexedParts(checkpoints, "CheckpointIndex")) do
		local label = entry.Part:FindFirstChild(AUTHORING_LABEL_NAME)
		if label and label:IsA("BillboardGui") then
			label.Enabled = visible
		end
	end
end

local function setEntrancesEnabled(route, enabled)
	for _, name in ipairs({ "RaceStartZone", "TimeTrialStartZone" }) do
		local zone = child(route, "StartZones", name)
		assert(zone and zone:IsA("BasePart"), "Missing " .. name)
		zone:SetAttribute("Enabled", enabled == true)
		if not enabled then
			local prompt = zone:FindFirstChild(PROMPT_NAME)
			if prompt then
				prompt:Destroy()
			end
		end
	end
end

local function eventIdConflicts(catalog, desiredEventId, allowedFolder)
	for _, event in ipairs(catalog:GetChildren()) do
		if event ~= allowedFolder and tostring(event:GetAttribute("EventId") or "") == desiredEventId then
			return event
		end
	end
	return nil
end

local function eventPairState(raceCatalog, timeTrialCatalog)
	local raceEvent = raceCatalog:FindFirstChild(ROUTE_ID)
	local timeTrialEvent = timeTrialCatalog:FindFirstChild(ROUTE_ID)
	return raceEvent, timeTrialEvent
end

local EVENT_OVERRIDE_ATTRIBUTES = {
	RouteId = true,
	DisplayName = true,
	SharedMenuDisplayName = true,
	Mode = true,
	EventId = true,
	TrackImage = true,
	MapImage = true,
	RaceHudMapImage = true,
}

local function auditInheritedEvent(label, source, target)
	for attributeName, sourceValue in pairs(source:GetAttributes()) do
		if not EVENT_OVERRIDE_ATTRIBUTES[attributeName] and target:GetAttribute(attributeName) ~= sourceValue then
			line("BLOCKER", label .. " config drifted from Shifted Canal at " .. attributeName)
		end
	end
end

local function auditHudMapSchema(source, target)
	for _, sourceChild in ipairs(source:GetChildren()) do
		local targetChild = target:FindFirstChild(sourceChild.Name)
		if not targetChild or targetChild.ClassName ~= sourceChild.ClassName then
			line("BLOCKER", "HUD map config is missing matching " .. sourceChild.Name)
		elseif sourceChild:IsA("ValueBase")
			and sourceChild.Name ~= "Enabled"
			and sourceChild.Name ~= "Image"
			and sourceChild.Name ~= "UseConfiguredWorldAnchor"
			and sourceChild.Name ~= "AnchorPartName"
			and targetChild.Value ~= sourceChild.Value
		then
			line("BLOCKER", "HUD map config drifted from Shifted Canal at " .. sourceChild.Name)
		end
	end
end

local function audit(requirePlacement)
	resetAuditCounts()
	local routes, raceCatalog, timeTrialCatalog, hudMapCatalog = roots()
	local _, sourceRace, sourceTimeTrial, sourceHudMap = sourceContract(routes, raceCatalog, timeTrialCatalog, hudMapCatalog)
	local route = routes:FindFirstChild(ROUTE_ID)
	if not route then
		line("BLOCKER", "Missing route " .. ROUTE_ID .. ". Run PREPARE.")
		return false
	end
	if not installerOwns(route) then
		line("BLOCKER", "Route exists but is not owned by this installer.")
		return false
	end

	if route:GetAttribute("RouteId") == ROUTE_ID then line("PASS", "RouteId is unique and correct.") else line("BLOCKER", "RouteId is incorrect.") end
	if route:GetAttribute("DisplayName") == DISPLAY_NAME then line("PASS", "DisplayName is Showroom Loop.") else line("BLOCKER", "DisplayName is incorrect.") end
	if route:GetAttribute("RouteType") == "Circuit" then line("PASS", "RouteType is Circuit.") else line("BLOCKER", "RouteType must remain Circuit.") end

	local checkpoints = sortedIndexedParts(route:FindFirstChild("Checkpoints"), "CheckpointIndex")
	if #checkpoints == CHECKPOINT_COUNT then
		line("PASS", "Found exactly " .. tostring(CHECKPOINT_COUNT) .. " checkpoints.")
	else
		line("BLOCKER", "Expected " .. tostring(CHECKPOINT_COUNT) .. " checkpoints, found " .. tostring(#checkpoints))
	end

	local seen = {}
	local unchanged = 0
	local previousPart = nil
	for expectedIndex = 1, CHECKPOINT_COUNT do
		local entry = checkpoints[expectedIndex]
		if not entry or entry.Index ~= expectedIndex then
			line("BLOCKER", "Checkpoint sequence is not contiguous at index " .. tostring(expectedIndex))
		else
			local part = entry.Part
			if seen[entry.Index] then
				line("BLOCKER", "Duplicate checkpoint index " .. tostring(entry.Index))
			end
			seen[entry.Index] = true
			if part.Name ~= string.format("Checkpoint_%03d", expectedIndex) then
				line("BLOCKER", "Checkpoint name/index mismatch: " .. part.Name)
			end
			if part:GetAttribute("RouteId") ~= ROUTE_ID then
				line("BLOCKER", part.Name .. " has the wrong RouteId")
			end
			local initial = part:GetAttribute(INITIAL_CFRAME_ATTRIBUTE)
			if typeof(initial) == "CFrame" and part.CFrame == initial then
				unchanged += 1
			end
			if previousPart and (part.Position - previousPart.Position).Magnitude < 12 then
				line("BLOCKER", part.Name .. " is less than 12 studs from " .. previousPart.Name)
			end
			previousPart = part
		end
	end
	if unchanged == 0 then
		line("PASS", "All " .. tostring(CHECKPOINT_COUNT) .. " checkpoints have been moved from their generated authoring positions.")
	elseif requirePlacement and route:GetAttribute(AUTHORING_ACCEPTED_ATTRIBUTE) ~= CHECKPOINT_COUNT then
		line("BLOCKER", tostring(unchanged) .. " checkpoints are still at generated positions; move each checkpoint before activation.")
	else
		line("WARN", tostring(unchanged) .. " checkpoints match generated positions, but the mirrored 17-checkpoint authoring contract is explicitly accepted.")
	end

	local finish = route:FindFirstChild("FinishLine")
	if finish and finish:IsA("BasePart")
		and finish:GetAttribute("RouteId") == ROUTE_ID
		and finish:GetAttribute("CheckpointIndex") == CHECKPOINT_COUNT + 1
	then
		line("PASS", "FinishLine is configured after checkpoint " .. tostring(CHECKPOINT_COUNT) .. ".")
	else
		line("BLOCKER", "FinishLine attributes are invalid.")
	end

	local grids = sortedIndexedParts(route:FindFirstChild("SpawnGrid"), "GridIndex")
	if #grids == 6 then line("PASS", "Six grid positions are present.") else line("BLOCKER", "Expected six grid positions.") end
	for expectedIndex = 1, 6 do
		local entry = grids[expectedIndex]
		if not entry or entry.Index ~= expectedIndex or entry.Part:GetAttribute("RouteId") ~= ROUTE_ID then
			line("BLOCKER", "Grid sequence/RouteId is invalid at " .. tostring(expectedIndex))
		end
	end

	local raceEvent, timeTrialEvent = eventPairState(raceCatalog, timeTrialCatalog)
	local hudMap = hudMapCatalog:FindFirstChild(ROUTE_ID)
	local active = raceEvent ~= nil or timeTrialEvent ~= nil
	if (raceEvent == nil) ~= (timeTrialEvent == nil) then
		line("BLOCKER", "Only one live Showroom Loop event definition exists.")
	elseif active then
		if raceEvent:GetAttribute("EventId") == RACE_EVENT_ID and raceEvent:GetAttribute("RouteId") == ROUTE_ID then
			line("PASS", "Live Race event points to Showroom Loop.")
			auditInheritedEvent("Race", sourceRace, raceEvent)
		else
			line("BLOCKER", "Live Race event identifiers are invalid.")
		end
		if timeTrialEvent:GetAttribute("EventId") == TIME_TRIAL_EVENT_ID and timeTrialEvent:GetAttribute("RouteId") == ROUTE_ID then
			line("PASS", "Live Time Trial event points to Showroom Loop.")
			auditInheritedEvent("Time Trial", sourceTimeTrial, timeTrialEvent)
		else
			line("BLOCKER", "Live Time Trial event identifiers are invalid.")
		end
	else
		line("INFO", "Route is an inactive draft; no Showroom Loop catalog entries are published.")
	end
	if active and hudMap and hudMap:IsA("Folder") then
		local enabled = hudMap:FindFirstChild("Enabled")
		local image = hudMap:FindFirstChild("Image")
		if enabled and enabled:IsA("BoolValue") and enabled.Value == false
			and image and image:IsA("StringValue") and image.Value == ""
		then
			line("PASS", "HUD map config matches the shared schema and remains safely disabled pending calibration.")
			auditHudMapSchema(sourceHudMap, hudMap)
		else
			line("BLOCKER", "Showroom Loop HUD map must be disabled with blank route artwork until calibrated.")
		end
	elseif active then
		line("BLOCKER", "Live Showroom Loop events are missing HudMapCatalog.ShowroomLoop.")
	elseif hudMap then
		line("BLOCKER", "Draft route has a live HUD map config without paired Race/TT events.")
	end

	local raceConflict = eventIdConflicts(raceCatalog, RACE_EVENT_ID, raceEvent)
	local timeTrialConflict = eventIdConflicts(timeTrialCatalog, TIME_TRIAL_EVENT_ID, timeTrialEvent)
	if raceConflict then line("BLOCKER", "Race EventId conflict at " .. raceConflict:GetFullName()) end
	if timeTrialConflict then line("BLOCKER", "Time Trial EventId conflict at " .. timeTrialConflict:GetFullName()) end
	if not raceConflict and not timeTrialConflict then line("PASS", "Both EventIds are unique.") end

	local expectedEnabled = active
	for _, name in ipairs({ "RaceStartZone", "TimeTrialStartZone" }) do
		local zone = child(route, "StartZones", name)
		if not zone or not zone:IsA("BasePart") then
			line("BLOCKER", "Missing " .. name)
		elseif zone:GetAttribute("RouteId") ~= ROUTE_ID then
			line("BLOCKER", name .. " has the wrong RouteId")
		elseif zone:GetAttribute("Enabled") ~= expectedEnabled then
			line("BLOCKER", name .. " enabled state does not match catalog activation")
		end
	end

	local arrows = route:FindFirstChild("ArrowMarkers")
	local emptySegments = 0
	if not arrows then
		line("BLOCKER", "Missing ArrowMarkers")
	else
		local expectedSegments = {}
		for fromIndex = 0, CHECKPOINT_COUNT - 1 do
			local segmentName = "Checkpoint" .. fromIndex .. "-" .. (fromIndex + 1)
			expectedSegments[segmentName] = true
			local segment = arrows:FindFirstChild(segmentName)
			if not segment or not segment:IsA("Folder") then
				line("BLOCKER", "Missing arrow segment Checkpoint" .. fromIndex .. "-" .. (fromIndex + 1))
			elseif #segment:GetChildren() == 0 then
				emptySegments += 1
			end
		end
		local closingName = "Checkpoint" .. CHECKPOINT_COUNT .. "-0"
		expectedSegments[closingName] = true
		local closing = arrows:FindFirstChild(closingName)
		if not closing or not closing:IsA("Folder") then
			line("BLOCKER", "Missing closing arrow segment Checkpoint" .. tostring(CHECKPOINT_COUNT) .. "-0")
		elseif #closing:GetChildren() == 0 then
			emptySegments += 1
		end
		for _, item in ipairs(arrows:GetChildren()) do
			if string.match(item.Name, "^Checkpoint%d+%-%d+$") and not expectedSegments[item.Name] then
				line("BLOCKER", "Obsolete arrow segment remains: " .. item.Name)
			end
		end
	end
	if emptySegments > 0 then
		line("WARN", tostring(emptySegments) .. " arrow segments are empty; navigation may need more authored arrows.")
	else
		line("PASS", "All " .. tostring(CHECKPOINT_COUNT + 1) .. " arrow segments contain authored assets.")
	end

	local pivot = child(route, "Authoring", "StartPivot")
	if pivot and pivot:IsA("BasePart") then
		line("PASS", string.format("StartPivot is at %.1f, %.1f, %.1f.", pivot.Position.X, pivot.Position.Y, pivot.Position.Z))
	else
		line("BLOCKER", "Missing Authoring.StartPivot")
	end

	print(string.format("[%s] SUMMARY: %d BLOCKER / %d WARN / %d INFO+PASS", PHASE, blockers, warnings, infos))
	return blockers == 0
end

local function prepare()
	requireEditMode()
	local routes, raceCatalog, timeTrialCatalog, hudMapCatalog = roots()
	local sourceRoute = sourceContract(routes, raceCatalog, timeTrialCatalog, hudMapCatalog)
	local existing = routes:FindFirstChild(ROUTE_ID)
	if existing then
		assert(installerOwns(existing),
			"Refusing to overwrite unrelated " .. existing:GetFullName())
		local existingRace, existingTimeTrial = eventPairState(raceCatalog, timeTrialCatalog)
		assert(not existingRace and not existingTimeTrial,
			"Showroom Loop is active or partially published. Use AUDIT, or ROLLBACK before PREPARE.")
		line("INFO", "Showroom Loop draft already exists; preserving all current placement.")
		setEntrancesEnabled(existing, false)
		setAuthoringVisible(existing, true)
		audit(false)
		return
	end

	local raceEvent, timeTrialEvent = eventPairState(raceCatalog, timeTrialCatalog)
	assert(not raceEvent and not timeTrialEvent, "Live Showroom Loop events already exist without the route")
	assert(not eventIdConflicts(raceCatalog, RACE_EVENT_ID, nil), "Race EventId already exists")
	assert(not eventIdConflicts(timeTrialCatalog, TIME_TRIAL_EVENT_ID, nil), "Time Trial EventId already exists")

	local sourceRaceZone = child(sourceRoute, "StartZones", "RaceStartZone")
	local sourcePivot = sourceRaceZone.CFrame
	local targetPivot = desiredPivotCFrame()

	local route = sourceRoute:Clone()
	replaceRouteReferences(route)
	transformRouteParts(route, sourcePivot, targetPivot)
	route.Parent = routes

	local pivot = ensureStartPivot(route)
	ensureCheckpointCount(route, pivot)
	ensureArrowSegments(route)
	captureStartOffsets(route, pivot)
	setEntrancesEnabled(route, false)
	setAuthoringVisible(route, true)

	line("PASS", "Prepared inactive Showroom Loop at the requested showroom-area position.")
	line("INFO", "Move/rotate Authoring.StartPivot and run COMPILE; then move all " .. tostring(CHECKPOINT_COUNT) .. " checkpoints.")
	audit(false)
end

local function compile()
	requireEditMode()
	local routes, raceCatalog, timeTrialCatalog, hudMapCatalog = roots()
	sourceContract(routes, raceCatalog, timeTrialCatalog, hudMapCatalog)
	local route = routes:FindFirstChild(ROUTE_ID)
	assert(installerOwns(route), "Run PREPARE first")
	local raceEvent, timeTrialEvent = eventPairState(raceCatalog, timeTrialCatalog)
	assert(not raceEvent and not timeTrialEvent, "Showroom Loop is active. Run ROLLBACK before recompiling its start layout.")
	compileStartLayout(route)
	setEntrancesEnabled(route, false)
	setAuthoringVisible(route, true)
	audit(false)
end

local function copyEvent(source, temporaryName, mode)
	local clone = source:Clone()
	clone.Name = temporaryName
	clone:SetAttribute("RouteId", ROUTE_ID)
	clone:SetAttribute("DisplayName", DISPLAY_NAME)
	clone:SetAttribute("SharedMenuDisplayName", DISPLAY_NAME)
	clone:SetAttribute("Mode", mode)
	clone:SetAttribute("EventId", mode == "Race" and RACE_EVENT_ID or TIME_TRIAL_EVENT_ID)
	clone:SetAttribute("TrackImage", "")
	clone:SetAttribute("MapImage", "")
	clone:SetAttribute("RaceHudMapImage", "")
	if mode == "Race" then
		clone:SetAttribute("Laps", 2)
		clone:SetAttribute("MinPlayers", 2)
		clone:SetAttribute("MaxPlayers", 6)
	else
		clone:SetAttribute("Laps", 1)
		clone:SetAttribute("DefaultLapCount", 1)
		clone:SetAttribute("MinLapCount", 1)
		clone:SetAttribute("MaxLapCount", 10)
		clone:SetAttribute("AllowInfiniteLaps", true)
		clone:SetAttribute("MinPlayers", 1)
		clone:SetAttribute("MaxPlayers", 1)
	end
	return clone
end

local function copyHudMapConfig(source, temporaryName)
	local clone = source:Clone()
	clone.Name = temporaryName
	local enabled = clone:FindFirstChild("Enabled")
	local image = clone:FindFirstChild("Image")
	local useConfiguredWorldAnchor = clone:FindFirstChild("UseConfiguredWorldAnchor")
	local anchorPartName = clone:FindFirstChild("AnchorPartName")
	assert(enabled and enabled:IsA("BoolValue"), "Source HUD map config is missing Enabled")
	assert(image and image:IsA("StringValue"), "Source HUD map config is missing Image")
	assert(useConfiguredWorldAnchor and useConfiguredWorldAnchor:IsA("BoolValue"), "Source HUD map config is missing UseConfiguredWorldAnchor")
	assert(anchorPartName and anchorPartName:IsA("StringValue"), "Source HUD map config is missing AnchorPartName")
	enabled.Value = false
	image.Value = ""
	useConfiguredWorldAnchor.Value = false
	anchorPartName.Value = "FinishLine"
	clone:SetAttribute("NTR_ShowroomLoopNeedsMapCalibration", true)
	return clone
end

local function activate()
	requireEditMode()
	local routes, raceCatalog, timeTrialCatalog, hudMapCatalog = roots()
	local _, sourceRace, sourceTimeTrial, sourceHudMap = sourceContract(routes, raceCatalog, timeTrialCatalog, hudMapCatalog)
	local route = routes:FindFirstChild(ROUTE_ID)
	assert(installerOwns(route), "Run PREPARE first")

	local existingRace, existingTimeTrial = eventPairState(raceCatalog, timeTrialCatalog)
	local existingHudMap = hudMapCatalog:FindFirstChild(ROUTE_ID)
	if existingRace and existingTimeTrial and existingHudMap then
		assert(audit(true), "Existing Showroom Loop activation is invalid; run ROLLBACK before repair.")
		line("INFO", "Showroom Loop is already active and valid; no event definitions were duplicated.")
		return
	end
	assert(not existingRace and not existingTimeTrial and not existingHudMap,
		"Partial live config state detected; run ROLLBACK before ACTIVATE")
	assert(audit(true), "Activation blocked by the audit above")

	local raceTemp = copyEvent(sourceRace, ROUTE_ID .. "__INSTALLING", "Race")
	local timeTrialTemp = copyEvent(sourceTimeTrial, ROUTE_ID .. "__INSTALLING", "TimeTrial")
	local hudMapTemp = copyHudMapConfig(sourceHudMap, ROUTE_ID .. "__INSTALLING")
	local ok, installError = pcall(function()
		raceTemp.Parent = raceCatalog
		timeTrialTemp.Parent = timeTrialCatalog
		hudMapTemp.Parent = hudMapCatalog
		raceTemp.Name = ROUTE_ID
		timeTrialTemp.Name = ROUTE_ID
		hudMapTemp.Name = ROUTE_ID
		setEntrancesEnabled(route, true)
		setAuthoringVisible(route, false)
	end)
	if not ok then
		if raceTemp.Parent then raceTemp:Destroy() end
		if timeTrialTemp.Parent then timeTrialTemp:Destroy() end
		if hudMapTemp.Parent then hudMapTemp:Destroy() end
		setEntrancesEnabled(route, false)
		setAuthoringVisible(route, true)
		error("Activation rolled back after failure: " .. tostring(installError))
	end

	line("PASS", "Activated Showroom Loop Race and Time Trial events.")
	line("INFO", "Cloned the Shifted Canal Race, Time Trial and HUD map config contracts.")
	line("INFO", "Route-specific media remains blank and the HUD map marker is disabled until Showroom Loop calibration exists.")
	audit(true)
end

local function rollback()
	requireEditMode()
	local routes, raceCatalog, timeTrialCatalog, hudMapCatalog = roots()
	local route = routes:FindFirstChild(ROUTE_ID)
	assert(installerOwns(route), "No installer-owned Showroom Loop route found")

	for _, catalog in ipairs({ raceCatalog, timeTrialCatalog, hudMapCatalog }) do
		local event = catalog:FindFirstChild(ROUTE_ID)
		if event then
			event:Destroy()
		end
		local temporary = catalog:FindFirstChild(ROUTE_ID .. "__INSTALLING")
		if temporary then
			temporary:Destroy()
		end
	end
	setEntrancesEnabled(route, false)
	setAuthoringVisible(route, true)
	line("PASS", "Rolled back live Showroom Loop events while preserving all route authoring work.")
	audit(false)
end

local function repair()
	requireEditMode()
	local routes, raceCatalog, timeTrialCatalog, hudMapCatalog = roots()
	sourceContract(routes, raceCatalog, timeTrialCatalog, hudMapCatalog)
	local route = routes:FindFirstChild(ROUTE_ID)
	assert(installerOwns(route), "No installer-owned Showroom Loop route found; run PREPARE first")

	local existingRace, existingTimeTrial = eventPairState(raceCatalog, timeTrialCatalog)
	local existingHudMap = hudMapCatalog:FindFirstChild(ROUTE_ID)
	if existingRace and existingTimeTrial and existingHudMap then
		assert(audit(true), "Existing Showroom Loop V1.1 state failed audit; use ROLLBACK before repair.")
		line("INFO", "Showroom Loop V1.1 is already installed and valid; REPAIR made no changes.")
		return
	end
	assert(not existingRace and not existingTimeTrial and not existingHudMap,
		"Showroom Loop already has live or partial config. Run AUDIT; use ROLLBACK before structural repair.")

	local checkpoints = sortedIndexedParts(route:FindFirstChild("Checkpoints"), "CheckpointIndex")
	assert(#checkpoints == CHECKPOINT_COUNT,
		"Mirror mismatch: expected exactly " .. tostring(CHECKPOINT_COUNT) .. " authored checkpoints, found " .. tostring(#checkpoints))
	for expectedIndex = 1, CHECKPOINT_COUNT do
		local entry = checkpoints[expectedIndex]
		assert(entry and entry.Index == expectedIndex,
			"Checkpoint sequence is not contiguous at " .. tostring(expectedIndex))
		configureCheckpoint(entry.Part, expectedIndex, entry.Part.CFrame)
	end

	local pivot = ensureStartPivot(route)
	ensureCheckpointCount(route, pivot)
	ensureArrowSegments(route)
	route:SetAttribute(ROUTE_MARKER_ATTRIBUTE, INSTALLER_VERSION)
	route:SetAttribute(AUTHORING_ACCEPTED_ATTRIBUTE, CHECKPOINT_COUNT)
	route:SetAttribute("AuthoringNote", "Showroom Loop V1.1: 17-checkpoint circuit; paired config generated from Shifted Canal.")
	line("PASS", "Repaired the mirrored 17-checkpoint contract without moving route geometry.")
	line("PASS", "FinishLine is now checkpoint 18 and the closing arrow segment is Checkpoint17-0.")
	activate()
end

requireEditMode()
if MODE == "REPAIR" then
	repair()
elseif MODE == "PREPARE" then
	prepare()
elseif MODE == "COMPILE" then
	compile()
elseif MODE == "AUDIT" then
	audit(false)
elseif MODE == "ACTIVATE" then
	activate()
elseif MODE == "ROLLBACK" then
	rollback()
else
	error("Unknown MODE: " .. tostring(MODE))
end
