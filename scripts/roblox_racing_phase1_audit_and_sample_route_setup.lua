-- Neo Tokyo Racers - Racing Phase 1 Audit + Sample Route Setup
-- Default mode is read-only. It does not change Studio unless MODE is changed.
--
-- Usage:
--   1. Run with MODE = "AUDIT" first.
--   2. If the output looks sensible, change MODE to "SETUP_SAMPLE" and rerun
--      to create editable route/config placeholders. This still installs no
--      gameplay services, no rewards, and no client race HUD.

local MODE = "AUDIT" -- "AUDIT" or "SETUP_SAMPLE"

local PHASE = "NTR Racing Phase 1"

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local SAMPLE_ROUTE_ID = "ShiftedCanalSprint"
local SAMPLE_TT_EVENT_ID = "shifted_canal_sprint_tt"
local SAMPLE_RACE_EVENT_ID = "shifted_canal_sprint_race"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function warnLine(message)
	warn("[" .. PHASE .. "] " .. tostring(message))
end

local function child(parent, ...)
	local current = parent
	for _, name in ipairs({ ... }) do
		current = current and current:FindFirstChild(name)
	end
	return current
end

local function ensureFolder(parent, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	if existing then
		error("Cannot create Folder " .. name .. " because " .. existing:GetFullName() .. " already exists as " .. existing.ClassName)
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function ensurePart(parent, name, cframe, size, color, transparency)
	local part = parent:FindFirstChild(name)
	if part and not part:IsA("BasePart") then
		error("Cannot create Part " .. name .. " because " .. part:GetFullName() .. " already exists as " .. part.ClassName)
	end
	if not part then
		part = Instance.new("Part")
		part.Name = name
		part.Parent = parent
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = size
	part.CFrame = cframe
	return part
end

local function setTag(instance, tag)
	if not CollectionService:HasTag(instance, tag) then
		CollectionService:AddTag(instance, tag)
	end
end

local function countChildrenOfClass(parent, className)
	local count = 0
	if not parent then return count end
	for _, childItem in ipairs(parent:GetChildren()) do
		if childItem:IsA(className) then
			count += 1
		end
	end
	return count
end

local function sourceContains(scriptObject, needle)
	if not scriptObject or not scriptObject:IsA("LuaSourceContainer") then
		return false
	end
	local ok, source = pcall(function()
		return scriptObject.Source
	end)
	return ok and string.find(source, needle, 1, true) ~= nil
end

local function auditRoutes()
	info("Route hierarchy audit")
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	if not world then
		warnLine("  Missing Workspace.NeoTokyoRacersWorld")
		return
	end

	local routes = world:FindFirstChild("RaceRoutes")
	if not routes then
		warnLine("  Missing Workspace.NeoTokyoRacersWorld.RaceRoutes")
		return
	end

	info("  RaceRoutes found. Attributes=" .. tostring(#routes:GetAttributes()) .. " children=" .. tostring(#routes:GetChildren()))
	if #routes:GetChildren() == 0 then
		warnLine("  RaceRoutes is empty. Run SETUP_SAMPLE after reviewing this audit to create the first editable route scaffold.")
	end

	for _, route in ipairs(routes:GetChildren()) do
		if route:IsA("Folder") or route:IsA("Model") then
			local startZones = route:FindFirstChild("StartZones")
			local checkpoints = route:FindFirstChild("Checkpoints")
			local spawnGrid = route:FindFirstChild("SpawnGrid")
			local finish = route:FindFirstChild("FinishLine")
			info("  Route " .. route.Name)
			info("    RouteId=" .. tostring(route:GetAttribute("RouteId")) .. " DisplayName=" .. tostring(route:GetAttribute("DisplayName")))
			info("    StartZones=" .. tostring(startZones and #startZones:GetChildren() or 0))
			info("    SpawnGrid=" .. tostring(spawnGrid and #spawnGrid:GetChildren() or 0))
			info("    Checkpoints=" .. tostring(checkpoints and #checkpoints:GetChildren() or 0))
			info("    FinishLine=" .. tostring(finish ~= nil))

			if checkpoints then
				local seen = {}
				for _, checkpoint in ipairs(checkpoints:GetChildren()) do
					local index = checkpoint:GetAttribute("CheckpointIndex")
					if typeof(index) == "number" then
						if seen[index] then
							warnLine("    Duplicate CheckpointIndex " .. tostring(index) .. " on " .. checkpoint.Name)
						end
						seen[index] = true
					else
						warnLine("    Missing numeric CheckpointIndex on " .. checkpoint.Name)
					end
				end
			end
		end
	end
end

local function auditRacingConfig()
	info("Racing config/remotes audit")
	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	if not kit then
		warnLine("  Missing ReplicatedStorage.NeoTokyoRacers")
		return
	end

	local racingConfig = child(kit, "Config", "Racing")
	local ttCatalog = racingConfig and racingConfig:FindFirstChild("TimeTrialCatalog")
	local raceCatalog = racingConfig and racingConfig:FindFirstChild("RaceCatalog")
	local rewards = racingConfig and racingConfig:FindFirstChild("Rewards")
	local tierRules = racingConfig and racingConfig:FindFirstChild("TierRules")
	info("  Config.Racing exists=" .. tostring(racingConfig ~= nil))
	info("  TimeTrialCatalog events=" .. tostring(ttCatalog and #ttCatalog:GetChildren() or 0))
	info("  RaceCatalog events=" .. tostring(raceCatalog and #raceCatalog:GetChildren() or 0))
	info("  Rewards exists=" .. tostring(rewards ~= nil))
	info("  TierRules exists=" .. tostring(tierRules ~= nil))

	local racingRemotes = child(kit, "Shared", "Remotes", "Racing")
	info("  Shared.Remotes.Racing exists=" .. tostring(racingRemotes ~= nil))
	if racingRemotes then
		info("  RaceRequest=" .. tostring(racingRemotes:FindFirstChild("RaceRequest") ~= nil))
		info("  RaceEvent=" .. tostring(racingRemotes:FindFirstChild("RaceEvent") ~= nil))
	end
end

local function auditExistingServicesAndClients()
	info("Racing service/client audit")
	local racingServices = child(ServerScriptService, "NeoTokyoRacers", "Services", "Racing")
	info("  Server Racing folder exists=" .. tostring(racingServices ~= nil) .. " children=" .. tostring(racingServices and #racingServices:GetChildren() or 0))

	local racingClients = child(StarterPlayer, "StarterPlayerScripts", "NeoTokyoRacersClient", "Controllers", "Racing")
	info("  Client Racing folder exists=" .. tostring(racingClients ~= nil) .. " children=" .. tostring(racingClients and #racingClients:GetChildren() or 0))

	local uiRoot = child(StarterPlayer, "StarterPlayerScripts", "NeoTokyoRacersClient", "Controllers", "UI")
	local nav = uiRoot and uiRoot:FindFirstChild("FreeRoamNavController_Active")
	if nav and nav:IsA("LocalScript") then
		info("  FreeRoamNav Race button=" .. tostring(sourceContains(nav, 'showActionPanel("Race")')))
		info("  FreeRoamNav Race placeholder=" .. tostring(sourceContains(nav, "Race cards and route tracking can go here next.")))
	else
		warnLine("  Missing FreeRoamNavController_Active; Race panel integration point not found.")
	end
end

local function auditRoadMarkers()
	info("Road marker audit")
	local roadFolder = child(Workspace, "NeoTokyoRacersWorld", "SpawnPoints", "RoadSpawnMarkers")
	local tagged = CollectionService:GetTagged("NTR_RoadSpawnPoint")
	info("  RoadSpawnMarkers folder exists=" .. tostring(roadFolder ~= nil) .. " parts=" .. tostring(countChildrenOfClass(roadFolder, "Part")))
	info("  Tagged NTR_RoadSpawnPoint instances=" .. tostring(#tagged))
	for index = 1, math.min(6, #tagged) do
		local marker = tagged[index]
		if marker:IsA("BasePart") then
			info(string.format("    Marker %02d: %s pos=(%.1f, %.1f, %.1f)", index, marker:GetFullName(), marker.Position.X, marker.Position.Y, marker.Position.Z))
		end
	end
end

local function auditProfileRewardHooks()
	info("Profile/reward hook audit")
	local playerServices = child(ServerScriptService, "NeoTokyoRacers", "Services", "Player")
	local profileService = playerServices and playerServices:FindFirstChild("ProfileService_Active")
	local bridge = playerServices and playerServices:FindFirstChild("LegacyGarageProfileBridge_Active")
	info("  ProfileService_Active exists=" .. tostring(profileService ~= nil))
	info("  LegacyGarageProfileBridge_Active exists=" .. tostring(bridge ~= nil))

	local garage = child(ServerScriptService, "NeoTokyoRacers", "Services", "Garage")
	local garageAction = garage and garage:FindFirstChild("GarageActionController_Shadow_Disabled")
	info("  GarageActionController exists=" .. tostring(garageAction ~= nil))
	if garageAction and garageAction:IsA("Script") then
		info("  Garage controller mirrors profile to persistence=" .. tostring(sourceContains(garageAction, "V80_mirrorLegacyProfileToPersistence")))
		info("  Garage controller owns cash leaderstats=" .. tostring(sourceContains(garageAction, "V56_setLeaderstats")))
	end
	info("  Recommendation: first reward phase should install an isolated RaceRewardService rather than patching GarageActionController unless an audit proves no cleaner binding exists.")
end

local function auditLiveVehicles()
	info("Live vehicle performance audit")
	if not RunService:IsRunning() then
		info("  Studio is not in Play mode; skipping live vehicle checks.")
		return
	end

	local vehiclesRoot = child(Workspace, "NeoTokyoRacersWorld", "Runtime", "PlayerVehicles")
	if not vehiclesRoot then
		warnLine("  Missing Runtime.PlayerVehicles")
		return
	end

	local count = 0
	for _, vehicle in ipairs(vehiclesRoot:GetChildren()) do
		if vehicle:IsA("Model") then
			count += 1
			info("  Vehicle " .. vehicle.Name
				.. " OwnerUserId=" .. tostring(vehicle:GetAttribute("OwnerUserId"))
				.. " DriverUserId=" .. tostring(vehicle:GetAttribute("DriverUserId"))
				.. " PerformanceTier=" .. tostring(vehicle:GetAttribute("PerformanceTier"))
				.. " PerformanceIndex=" .. tostring(vehicle:GetAttribute("PerformanceIndex")))
		end
	end
	info("  Runtime vehicle count=" .. tostring(count))
	if count == 0 then
		warnLine("  No spawned vehicles found. For the next audit, enter Play, spawn a vehicle, then rerun AUDIT to confirm PerformanceTier/Index are visible.")
	end
end

local function nearestRoadMarkerCFrames()
	local tagged = CollectionService:GetTagged("NTR_RoadSpawnPoint")
	local markers = {}
	for _, marker in ipairs(tagged) do
		if marker:IsA("BasePart") then
			table.insert(markers, marker)
		end
	end
	table.sort(markers, function(a, b)
		return a.Name < b.Name
	end)

	local cframes = {}
	for index = 1, math.min(6, #markers) do
		local marker = markers[index]
		table.insert(cframes, marker.CFrame + Vector3.new(0, 5, 0))
	end
	return cframes
end

local function fallbackCFrames()
	local basePart = child(Workspace, "NeoTokyoRacersWorld", "SpawnPoints", "VehicleSpawnPoint")
		or child(Workspace, "NeoTokyoRacersWorld", "Dealership", "Spawn", "VehicleExitSpawnPoint")
	local base = CFrame.new(0, 10, 0)
	if basePart and basePart:IsA("BasePart") then
		base = basePart.CFrame
	end
	return {
		base * CFrame.new(0, 4, -40),
		base * CFrame.new(0, 4, -120),
		base * CFrame.new(80, 4, -180),
		base * CFrame.new(150, 4, -110),
		base * CFrame.new(100, 4, -20),
		base * CFrame.new(0, 4, 20),
	}
end

local function setCommonEventAttributes(folder, eventId, displayName, mode, routeId)
	folder:SetAttribute("EventId", eventId)
	folder:SetAttribute("DisplayName", displayName)
	folder:SetAttribute("Mode", mode)
	folder:SetAttribute("RouteId", routeId)
	folder:SetAttribute("AllowedVehicleTiers", "E,D,C,B,A,S")
	folder:SetAttribute("RecommendedTier", "D")
	folder:SetAttribute("Laps", 1)
	folder:SetAttribute("EntryFee", 0)
	folder:SetAttribute("BaseReward", mode == "TimeTrial" and 500 or 750)
	folder:SetAttribute("DailyFirstWinMultiplier", 2.00)
end

local function setMedalTimes(folder)
	local times = {
		E = { 105, 92, 82, 76 },
		D = { 96, 84, 74, 68 },
		C = { 88, 76, 67, 62 },
		B = { 81, 70, 62, 57 },
		A = { 75, 65, 58, 53 },
		S = { 70, 60, 54, 50 },
	}
	for tier, values in pairs(times) do
		folder:SetAttribute(tier .. "_BronzeSeconds", values[1])
		folder:SetAttribute(tier .. "_SilverSeconds", values[2])
		folder:SetAttribute(tier .. "_GoldSeconds", values[3])
		folder:SetAttribute(tier .. "_PlatinumSeconds", values[4])
	end
end

local function setupSampleRouteAndConfig()
	info("SETUP_SAMPLE selected. Creating editable route/config placeholders only.")
	local world = Workspace:WaitForChild("NeoTokyoRacersWorld")
	local routes = ensureFolder(world, "RaceRoutes")
	routes:SetAttribute("NTR_RacingPhase1Ready", true)

	local route = ensureFolder(routes, SAMPLE_ROUTE_ID)
	route:SetAttribute("RouteId", SAMPLE_ROUTE_ID)
	route:SetAttribute("DisplayName", "Shifted Canal Sprint")
	route:SetAttribute("AuthoringNote", "Phase 1 sample route. Move/resize checkpoints before installing gameplay.")

	local cframes = nearestRoadMarkerCFrames()
	if #cframes < 6 then
		cframes = fallbackCFrames()
		warnLine("  Not enough tagged road markers found for full sample route. Used fallback positions near the vehicle/dealership spawn.")
	end

	local startZones = ensureFolder(route, "StartZones")
	local timeTrialZone = ensurePart(startZones, "TimeTrialStartZone", cframes[1], Vector3.new(34, 12, 34), Color3.fromRGB(70, 255, 190), 0.72)
	timeTrialZone:SetAttribute("EventId", SAMPLE_TT_EVENT_ID)
	timeTrialZone:SetAttribute("RouteId", SAMPLE_ROUTE_ID)
	timeTrialZone:SetAttribute("Mode", "TimeTrial")
	timeTrialZone:SetAttribute("PromptActionText", "Start Time Trial")
	timeTrialZone:SetAttribute("Enabled", true)
	setTag(timeTrialZone, "NTR_TimeTrialStartZone")

	local raceZone = ensurePart(startZones, "RaceStartZone", cframes[1] * CFrame.new(42, 0, 0), Vector3.new(34, 12, 34), Color3.fromRGB(230, 88, 205), 0.72)
	raceZone:SetAttribute("EventId", SAMPLE_RACE_EVENT_ID)
	raceZone:SetAttribute("RouteId", SAMPLE_ROUTE_ID)
	raceZone:SetAttribute("Mode", "Race")
	raceZone:SetAttribute("PromptActionText", "Join Race")
	raceZone:SetAttribute("Enabled", true)
	setTag(raceZone, "NTR_RaceStartZone")

	local spawnGrid = ensureFolder(route, "SpawnGrid")
	for index = 1, 6 do
		local grid = ensurePart(spawnGrid, string.format("Grid_%02d", index), cframes[1] * CFrame.new((index - 3.5) * 11, 0, -22), Vector3.new(8, 1, 12), Color3.fromRGB(255, 226, 249), 0.55)
		grid:SetAttribute("GridIndex", index)
		grid:SetAttribute("RouteId", SAMPLE_ROUTE_ID)
	end

	local checkpoints = ensureFolder(route, "Checkpoints")
	for index = 1, 4 do
		local checkpoint = ensurePart(checkpoints, string.format("Checkpoint_%03d", index), cframes[index + 1], Vector3.new(38, 22, 12), Color3.fromRGB(70, 255, 190), 0.65)
		checkpoint:SetAttribute("CheckpointIndex", index)
		checkpoint:SetAttribute("RouteId", SAMPLE_ROUTE_ID)
		checkpoint:SetAttribute("IsFinish", false)
		checkpoint:SetAttribute("RadiusStuds", 20)
		setTag(checkpoint, "NTR_RaceCheckpoint")
	end

	local finish = ensurePart(route, "FinishLine", cframes[6], Vector3.new(44, 24, 14), Color3.fromRGB(255, 226, 80), 0.58)
	finish:SetAttribute("CheckpointIndex", 5)
	finish:SetAttribute("RouteId", SAMPLE_ROUTE_ID)
	finish:SetAttribute("IsFinish", true)
	finish:SetAttribute("RadiusStuds", 24)
	setTag(finish, "NTR_RaceFinishLine")

	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local config = ensureFolder(kit, "Config")
	local racing = ensureFolder(config, "Racing")
	local ttCatalog = ensureFolder(racing, "TimeTrialCatalog")
	local raceCatalog = ensureFolder(racing, "RaceCatalog")
	local rewards = ensureFolder(racing, "Rewards")
	local timeTrialRewards = ensureFolder(rewards, "TimeTrial")
	local raceRewards = ensureFolder(rewards, "Race")
	local tierRules = ensureFolder(racing, "TierRules")

	timeTrialRewards:SetAttribute("RewardRoundToNearest", 250)
	timeTrialRewards:SetAttribute("FinishedRewardMultiplier", 0)
	timeTrialRewards:SetAttribute("BronzeRewardMultiplier", 0.55)
	timeTrialRewards:SetAttribute("SilverRewardMultiplier", 0.75)
	timeTrialRewards:SetAttribute("GoldRewardMultiplier", 1.00)
	timeTrialRewards:SetAttribute("PlatinumRewardMultiplier", 1.30)
	timeTrialRewards:SetAttribute("RepeatRewardMultiplier", 0.35)
	timeTrialRewards:SetAttribute("FirstPlatinumBonus", 250)
	timeTrialRewards:SetAttribute("TierMultiplier_E", 1.00)
	timeTrialRewards:SetAttribute("TierMultiplier_D", 1.15)
	timeTrialRewards:SetAttribute("TierMultiplier_C", 1.35)
	timeTrialRewards:SetAttribute("TierMultiplier_B", 1.60)
	timeTrialRewards:SetAttribute("TierMultiplier_A", 1.90)
	timeTrialRewards:SetAttribute("TierMultiplier_S", 2.25)
	raceRewards:SetAttribute("RewardRoundToNearest", 250)
	raceRewards:SetAttribute("BronzePlaceMax", 3)
	raceRewards:SetAttribute("SilverPlaceMax", 2)
	raceRewards:SetAttribute("GoldPlaceMax", 1)
	raceRewards:SetAttribute("BronzeRewardMultiplier", 0.65)
	raceRewards:SetAttribute("SilverRewardMultiplier", 0.85)
	raceRewards:SetAttribute("GoldRewardMultiplier", 1.00)
	raceRewards:SetAttribute("DNFRewardMultiplier", 0)

	tierRules:SetAttribute("DefaultAllowedVehicleTiers", "E,D,C,B,A,S")
	tierRules:SetAttribute("RaceBracket_ED", "E,D")
	tierRules:SetAttribute("RaceBracket_CB", "C,B")
	tierRules:SetAttribute("RaceBracket_AS", "A,S")
	tierRules:SetAttribute("UseSpawnedVehiclePerformanceTier", true)

	local tt = ensureFolder(ttCatalog, "ShiftedCanalSprint")
	setCommonEventAttributes(tt, SAMPLE_TT_EVENT_ID, "Shifted Canal Sprint", "TimeTrial", SAMPLE_ROUTE_ID)
	tt:SetAttribute("MinPlayers", 1)
	tt:SetAttribute("MaxPlayers", 1)
	setMedalTimes(tt)

	local race = ensureFolder(raceCatalog, "ShiftedCanalSprint")
	setCommonEventAttributes(race, SAMPLE_RACE_EVENT_ID, "Shifted Canal Sprint", "Race", SAMPLE_ROUTE_ID)
	race:SetAttribute("MinPlayers", 2)
	race:SetAttribute("MaxPlayers", 6)

	info("SETUP_SAMPLE complete. Move/resize route parts in Studio before installing any gameplay service.")
	info("Created/updated route: Workspace.NeoTokyoRacersWorld.RaceRoutes." .. SAMPLE_ROUTE_ID)
	info("Created/updated config: ReplicatedStorage.NeoTokyoRacers.Config.Racing")
end

local function runAudit()
	info("Starting audit. No changes will be made.")
	auditRoutes()
	auditRacingConfig()
	auditExistingServicesAndClients()
	auditRoadMarkers()
	auditProfileRewardHooks()
	auditLiveVehicles()
	info("Audit complete.")
end

if MODE == "AUDIT" then
	runAudit()
elseif MODE == "SETUP_SAMPLE" then
	setupSampleRouteAndConfig()
	runAudit()
else
	error("Unknown MODE: " .. tostring(MODE) .. ". Use AUDIT or SETUP_SAMPLE.")
end
