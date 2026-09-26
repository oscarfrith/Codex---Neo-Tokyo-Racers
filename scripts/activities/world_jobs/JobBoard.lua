-- Canonical feature implementation; startup is owned by the composition root (ServerBase).
-- World jobs board (docs/architecture/map-markers-contract.md "World jobs"). Server authority for:
--   * offers: N taxi fares + M parcels dotted over the Core District road network, each at a verified
--     kerb spot beside the road with a long, varied routed trip, published to
--     ReplicatedStorage.ActivityState.JobOffers (Configuration per offer); expire/relocate, replenish;
--   * JobAccept: proximity/speed/driving/busy validation, then ActivityService.Begin(kind);
--   * the trip engine shared by Taxi and Courier: driven distance (anti-teleport), crashes, arrival,
--     settlement (JobRules) and the single payout via ActivityPayout.Pay.
-- Kind specifics (NPC rigs, seating, config) live in the providers TaxiJob and CourierJob, which
-- register with JobBoard.RegisterProvider and own their ActivityService kinds.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local JobBoard = {}

local state = "idle"
local ActivityService, ActivityPayout, ProgressionService, JobRules, RoadRouting
local RaceIntegrity -- optional shared speed limit (anti-teleport)

local providers = {} -- [kind] = provider (see RegisterProvider)
local offers = {} -- [offerId] = offer
local trips = {} -- [player] = trip
local recentSpots = {} -- recent pickup and drop positions (freshness)
local recentTrips = {} -- { Pickup, Drop } of recent offers (variety)
local recentDrops = {}
local offersFolder
local edgeCache -- { Key, Table }
local rng = Random.new()
local generating = false
local fillRequested = false
local nextFillAt = 0 -- backoff after a round that found no valid spot
local configRoot

-- provider = {
--   ReadConfig = () -> tripConfig,              -- TaxiRules/CourierRules.ReadConfig on the kind's folder
--   Enabled = () -> boolean,                     -- config Enabled + feature flag
--   Reason = "TaxiFare" | "JobPayout", PayLabel = string, Boards = boolean?,
--   CanAccept = ((player, vehicle, offer) -> (boolean, string?))?,
--   OnAccept = (player, trip, offer, vehicle) -> (),  -- must call JobBoard.StartDriving(trip) or FailTrip
--   OnEnd = ((player, trip, outcome: "Complete"|"Failed"|"Cancelled"|"Lost") -> ())?,
--   OfferNear = ((offer, near: boolean) -> ())?,       -- a player came within / left StreamRadius
--   OfferRemoved = ((offer, taken: boolean) -> ())?,
--   DecorateOffer = ((offer) -> ())?,                  -- may set offer.Label
-- }
function JobBoard.RegisterProvider(kind, provider)
	assert(type(kind) == "string" and kind ~= "" and type(provider) == "table", "JobBoard provider needs a kind and table")
	assert(type(provider.ReadConfig) == "function" and type(provider.OnAccept) == "function", "JobBoard provider needs ReadConfig and OnAccept")
	provider.Kind = kind
	providers[kind] = provider
	fillRequested = true
end

local function call(provider, name, ...)
	local fn = provider and provider[name]
	if type(fn) ~= "function" then return true end
	local ok, err = pcall(fn, ...)
	if not ok then warn("[JobBoard] " .. tostring(provider.Kind) .. "." .. name .. " failed: " .. tostring(err)) end
	return ok, err
end

-- Config ----------------------------------------------------------------------------------------

local function boardConfig()
	local folder = configRoot and configRoot:FindFirstChild("Jobs")
	return JobRules.ReadBoardConfig(function(key) return folder and folder:GetAttribute(key) end)
end

local function bounds()
	local core = configRoot:FindFirstChild("Core")
	return {
		MinX = ActivityService.Number(core, "DistrictMinX", -250),
		MaxX = ActivityService.Number(core, "DistrictMaxX", 2600),
		MinZ = ActivityService.Number(core, "DistrictMinZ", -4150),
		MaxZ = ActivityService.Number(core, "DistrictMaxZ", 550),
	}
end

local function kindEnabled(kind)
	local provider = providers[kind]
	if not provider then return false end
	if provider.Enabled then
		local ok, value = pcall(provider.Enabled)
		return ok and value == true
	end
	return true
end

local function rootOf(vehicle)
	return vehicle and (vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true))
end

local function horizontalMph(part)
	local v = part.AssemblyLinearVelocity
	return JobRules.Mph(Vector3.new(v.X, 0, v.Z).Magnitude)
end

local function playerPositions()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(ActivityService.GetVehicle(player))
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local position = (root and root.Position) or (hrp and hrp.Position)
		if position then table.insert(list, position) end
	end
	return list
end

local function nearestDistance(position, positions)
	local best = math.huge
	for _, other in ipairs(positions) do best = math.min(best, JobRules.Flat(position, other)) end
	return best
end

local function push(player, payload)
	if player and player.Parent == Players then ActivityService.Push(player, payload) end
end

-- World probing (kerb verification) -------------------------------------------------------------

local function excludeList()
	local list = {}
	local world = Workspace:FindFirstChild("World")
	local runtime = world and world:FindFirstChild("Runtime")
	if runtime then table.insert(list, runtime) end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then table.insert(list, player.Character) end
	end
	return list
end

local function probeParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	params.IgnoreWater = false
	return params
end

local function isWater(hit)
	return hit ~= nil and hit.Material == Enum.Material.Water
end

-- Surfaces a fare or parcel must never stand on (by part or ancestor name): foliage, planters,
-- dividers and the bare baseplate beyond built pavements.
local REJECT_SURFACE = { "bush", "foliage", "divider", "tree", "plant", "grass", "hedge", "baseplate" }
local function surfaceOk(instance)
	local node, depth = instance, 0
	while node and node ~= Workspace and depth < 5 do
		local name = string.lower(node.Name)
		for _, word in ipairs(REJECT_SURFACE) do
			if string.find(name, word, 1, true) then return false end
		end
		node, depth = node.Parent, depth + 1
	end
	return true
end

local function collides(instance)
	if instance:IsA("Terrain") then return true end
	return instance:IsA("BasePart") and instance.CanCollide
end

-- candidate = { Centre: Vector2, Tangent: Vector2, Side }. Returns { Position, Facing, Offset } or nil, reason.
local function verifyKerb(candidate, board, allowFallback, graph)
	local params = probeParams()
	local centre, tangent = candidate.Centre, candidate.Tangent
	local top = board.RoadY + board.ProbeHeight
	local centreHit = Workspace:Raycast(Vector3.new(centre.X, top, centre.Y), Vector3.new(0, -board.ProbeHeight * 2, 0), params)
	if not centreHit then return nil, "NoRoad" end
	if isWater(centreHit) then return nil, "Water" end
	local roadY = centreHit.Position.Y
	local normal = JobRules.Normal(tangent, candidate.Side)
	local samples = {}
	local offset = board.KerbSearchMin
	while offset <= board.KerbSearchMax + 1e-3 do
		local p = centre + normal * offset
		local hit = Workspace:Raycast(Vector3.new(p.X, roadY + 25, p.Y), Vector3.new(0, -50, 0), params)
		local sample = { Offset = offset, Hit = hit ~= nil and not isWater(hit), IsRoad = false, Rise = false }
		if hit then
			local dy = hit.Position.Y - roadY
			local sameMaterial = hit.Material == centreHit.Material
			if math.abs(dy) < board.KerbRise then
				if hit.Instance == centreHit.Instance then
					sample.IsRoad = not hit.Instance:IsA("Terrain") or sameMaterial
				else
					sample.IsRoad = sameMaterial and hit.Instance.Name == centreHit.Instance.Name
				end
			end
			sample.Rise = dy >= board.KerbRise
		end
		table.insert(samples, sample)
		if not sample.Hit then break end
		offset += board.KerbSearchStep
	end
	local kerbOffset, how = JobRules.FindKerb(samples, board, allowFallback)
	if not kerbOffset then return nil, how end
	-- Try a few distances onto the pavement: bush walls and planters often line the kerb.
	local margins = { 0 }
	if how == "Kerb" then margins = { 0, -3, 4, 8, -5 } end
	local spotOffset, spot2, groundHit, why
	for _, extra in ipairs(margins) do
		spotOffset = kerbOffset + extra
		spot2 = centre + normal * spotOffset
		groundHit = Workspace:Raycast(Vector3.new(spot2.X, roadY + 25, spot2.Y), Vector3.new(0, -50, 0), params)
		local ground = groundHit and {
			Hit = true, Y = groundHit.Position.Y, NormalY = groundHit.Normal.Y, Water = isWater(groundHit),
			Collides = collides(groundHit.Instance), Surface = surfaceOk(groundHit.Instance),
		}
		local groundOk
		groundOk, why = JobRules.GroundOk(ground, roadY, board)
		if groundOk then break end
		groundHit = nil
	end
	if not groundHit then return nil, why end
	local position = groundHit.Position
	local cover = board.ClearHeight > 0 and Workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, board.ClearHeight, 0), params)
	if cover then
		-- A roof, overpass or large canopy (not a thin lamp arm or sign) means inside/under a structure.
		local part = cover.Instance
		if part:IsA("Terrain") or not part:IsA("BasePart") or math.max(part.Size.X, part.Size.Z) >= 30 then
			return nil, "Covered"
		end
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = params.FilterDescendantsInstances
	for _, part in ipairs(Workspace:GetPartBoundsInBox(CFrame.new(position + Vector3.new(0, 4.25, 0)), Vector3.new(5, 6.5, 5), overlap)) do
		if part.CanCollide and part.Transparency < 1 then return nil, "Blocked" end
	end
	local snap = RoadRouting.Snap(graph, spot2)
	if snap and not JobRules.OffOtherRoads(snap.Distance, spotOffset) then return nil, "OtherRoad" end
	return { Position = position, Facing = Vector3.new(-normal.X, 0, -normal.Y), Offset = spotOffset, How = how }
end

-- Candidate sampling ----------------------------------------------------------------------------

local function edgeTable(board, graph, area)
	local key = table.concat({ board.IntersectionClearance, area.MinX, area.MaxX, area.MinZ, area.MaxZ, #graph.Edges }, ":")
	if not edgeCache or edgeCache.Key ~= key then
		edgeCache = { Key = key, Table = JobRules.BuildEdgeTable(graph, board.IntersectionClearance, area) }
	end
	return edgeCache.Table
end

local function sampleCandidate(graph, edges, board)
	local edgeIndex, along = JobRules.SampleEdge(edges, rng:NextNumber(), rng:NextNumber())
	local edge = edgeIndex and graph.Edges[edgeIndex]
	if not (edge and edge.Points and edge.Cumulative) then return nil end
	local centre = JobRules.PointAlong(edge.Points, edge.Cumulative, along)
	if not centre then return nil end
	local tangent = JobRules.SmoothTangent(edge.Points, edge.Cumulative, along, 25)
	local side = rng:NextNumber() < 0.5 and -1 or 1
	return {
		Edge = edgeIndex, Along = along, Centre = centre, Tangent = tangent, Side = side,
		Point = JobRules.KerbPoint(centre, tangent, side, board.KerbOffset),
	}
end

local function sectorCounts(positions, area, board)
	local counts = {}
	for _, position in ipairs(positions) do
		local sector = JobRules.SectorOf(position, area, board.SectorColumns, board.SectorRows)
		counts[sector] = (counts[sector] or 0) + 1
	end
	return counts
end

local function chooseDestination(pickup, board, graph, edges, area, relax)
	local dist = JobRules.RoadDistances(graph, pickup.Edge, pickup.Along)
	local low, high = JobRules.TripBand(board, relax)
	local ctx = {
		Pickup = pickup.Position, TargetLength = JobRules.TargetLength(board, rng:NextNumber()), Band = { low, high },
		RecentTrips = recentTrips, RecentDrops = recentDrops, SectorCounts = sectorCounts(recentDrops, area, board), Bounds = area,
	}
	local scored = {}
	for _ = 1, board.DestinationCandidates do
		local candidate = sampleCandidate(graph, edges, board)
		if candidate then
			candidate.Road = JobRules.RoadDistanceTo(graph, dist, pickup.Edge, pickup.Along, candidate.Edge, candidate.Along)
			local score = JobRules.ScoreDestination(candidate, ctx, board)
			if score then
				candidate.Score = score + rng:NextNumber() * 0.35
				table.insert(scored, candidate)
			end
		end
	end
	table.sort(scored, function(a, b) return a.Score > b.Score end)
	for index = 1, math.min(6, #scored) do
		task.wait() -- spread raycast work across frames
		local spot = verifyKerb(scored[index], board, relax >= 1, graph)
		if spot then return scored[index], spot end
	end
	return nil
end

-- Offers ----------------------------------------------------------------------------------------

local function offerPositions()
	local list = {}
	for _, offer in pairs(offers) do table.insert(list, offer.Position) end
	return list
end

local function countOffers(kind)
	local count = 0
	for _, offer in pairs(offers) do
		if offer.Kind == kind then count += 1 end
	end
	return count
end

local function target(board, kind)
	if kind == "Taxi" then return board.TaxiOffers end
	if kind == "Courier" then return board.CourierOffers end
	return 0
end

local function removeOffer(offer, reason, taken)
	if offers[offer.Id] ~= offer then return end
	offers[offer.Id] = nil
	offer.Removed = true
	if offer.Instance then offer.Instance:Destroy() end
	offer.Instance = nil
	call(providers[offer.Kind], "OfferRemoved", offer, taken == true)
	fillRequested = true
end

local function publish(kind, board, pickup, spot, destination, destinationSpot)
	local provider = providers[kind]
	local tripConfig = provider.ReadConfig()
	local distance = destination.Road
	local now = Workspace:GetServerTimeNow()
	local offer = {
		Id = ActivityService.NewId(kind == "Taxi" and "Fare" or "Parcel"),
		Kind = kind,
		Position = spot.Position,
		Facing = spot.Facing,
		Destination = destinationSpot.Position,
		DestinationFacing = destinationSpot.Facing,
		Distance = distance,
		Straight = JobRules.Flat(spot.Position, destinationSpot.Position),
		Estimate = JobRules.Pay(tripConfig, distance, JobRules.ReferenceSeconds(distance, tripConfig), 0).Total,
		ExpiresAt = now + rng:NextNumber(board.OfferTtlMin, board.OfferTtlMax),
		Extensions = 0,
		Near = false,
	}
	call(provider, "DecorateOffer", offer)
	local item = Instance.new("Configuration")
	item.Name = offer.Id
	item:SetAttribute("Kind", kind)
	item:SetAttribute("Position", offer.Position)
	item:SetAttribute("Facing", offer.Facing)
	item:SetAttribute("Distance", math.floor(distance + 0.5))
	item:SetAttribute("Estimate", offer.Estimate)
	item:SetAttribute("ExpiresAt", offer.ExpiresAt)
	if type(offer.Label) == "string" then item:SetAttribute("Label", offer.Label) end
	item.Parent = offersFolder
	offer.Instance = item
	offers[offer.Id] = offer
	JobRules.Remember(recentSpots, spot.Position, board.FreshnessMemory)
	JobRules.Remember(recentSpots, destinationSpot.Position, board.FreshnessMemory)
	JobRules.Remember(recentDrops, destinationSpot.Position, board.RecentTripMemory)
	JobRules.Remember(recentTrips, { Pickup = spot.Position, Drop = destinationSpot.Position }, board.RecentTripMemory)
	return offer
end

-- One offer of `kind`, or nil when no valid spot/route was found. Yields between candidates.
local function generateOffer(kind, board)
	local graph = ActivityService.RoadGraph()
	local area = bounds()
	local edges = edgeTable(board, graph, area)
	if edges.Total <= 0 then return nil end
	for relax = 0, 2 do
		local ctx = { Offers = offerPositions(), Players = playerPositions(), Recent = recentSpots, Bounds = area }
		local counts = sectorCounts(ctx.Offers, area, board)
		local candidates = {}
		for _ = 1, board.SpotTries do
			local candidate = sampleCandidate(graph, edges, board)
			if candidate and JobRules.SpotAllowed(candidate.Point, ctx, board, relax) then
				candidate.Score = JobRules.ScorePickup(candidate.Point, counts, area, board, rng:NextNumber() * 0.8)
				table.insert(candidates, candidate)
				if #candidates >= 8 then break end
			end
		end
		table.sort(candidates, function(a, b) return a.Score > b.Score end)
		for _, candidate in ipairs(candidates) do
			local spot = verifyKerb(candidate, board, relax >= 2, graph)
			if spot and JobRules.SpotAllowed(spot.Position, ctx, board, relax) then
				candidate.Position = spot.Position
				local destination, destinationSpot = chooseDestination(candidate, board, graph, edges, area, relax >= 1 and 1 or 0)
				if not destination and relax == 0 then
					destination, destinationSpot = chooseDestination(candidate, board, graph, edges, area, 1)
				end
				if destination and providers[kind] and kindEnabled(kind) then
					return publish(kind, board, candidate, spot, destination, destinationSpot)
				end
			end
			task.wait() -- spread raycast and Dijkstra cost over frames
		end
	end
	return nil
end

local function fill()
	if generating then return end
	generating = true
	fillRequested = false
	local ok, err = pcall(function()
		local failures = {}
		while true do
			local board = boardConfig()
			if not board.Enabled then break end
			local chosen
			for kind in pairs(providers) do
				if not failures[kind] and kindEnabled(kind) and countOffers(kind) < target(board, kind) then
					if not chosen or countOffers(kind) / math.max(1, target(board, kind)) < countOffers(chosen) / math.max(1, target(board, chosen)) then
						chosen = kind
					end
				end
			end
			if not chosen then break end
			if not generateOffer(chosen, board) then
				failures[chosen] = true
				nextFillAt = os.clock() + 10
				warn("[JobBoard] no valid " .. chosen .. " spot this round; retrying in 10 s")
			end
			task.wait(0.05)
		end
	end)
	generating = false
	if not ok then warn("[JobBoard] fill failed: " .. tostring(err)) end
end

local function requestFill()
	fillRequested = true
end

-- Trips -------------------------------------------------------------------------------------------

local function limitStudsPerSecond(tripConfig)
	local raceLimit
	if RaceIntegrity then
		local ok, value = pcall(RaceIntegrity.limitMph)
		if ok then raceLimit = value end
	end
	return JobRules.StudsPerSecond(JobRules.LimitMph(raceLimit, tripConfig))
end

local REASONS = {
	LeftVehicle = "You left your car.",
	VehicleGone = "Your car was removed.",
	Died = "You were knocked out.",
	Player = "Cancelled.",
	Left = "Left the game.",
}

local function closeTrip(player, trip)
	if trips[player] ~= trip or trip.Closed then return false end
	trips[player] = nil
	trip.Closed = true
	return true
end

function JobBoard.CurrentTrip(player)
	return trips[player]
end

function JobBoard.FindTripByRig(rig)
	for _, trip in pairs(trips) do
		if trip.Rig == rig then return trip end
	end
	return nil
end

function JobBoard.FailTrip(player, trip, reason)
	if not closeTrip(player, trip) then return end
	pcall(ActivityService.End, player, trip.RecordId, "Failed")
	call(providers[trip.Kind], "OnEnd", player, trip, "Failed")
	push(player, { Type = trip.Kind .. ":Failed", TripId = trip.Id, Reason = reason })
end

-- ActivityService OnCancel for the Taxi/Courier kinds (the record is already cleared; no pay).
function JobBoard.HandleCancel(player, record, reason)
	local trip = trips[player]
	if not trip or (record and trip.RecordId ~= record.Id) then return end
	closeTrip(player, trip)
	call(providers[trip.Kind], "OnEnd", player, trip, "Cancelled")
	push(player, { Type = trip.Kind .. ":Cancelled", TripId = trip.Id, Reason = REASONS[reason] or tostring(reason or "Cancelled.") })
end

-- Providers call this when the cargo/fare is aboard; the pay clock and driven distance start here.
function JobBoard.StartDriving(trip)
	if trip.Closed or trip.Phase == "Driving" then return end
	trip.Phase = "Driving"
	local now = os.clock()
	trip.StartedAt = now
	trip.LastAt = now
	local root = rootOf(ActivityService.GetVehicle(trip.Player))
	trip.LastPosition = root and root.Position or nil
	trip.Driven = 0
	push(trip.Player, { Type = trip.Kind .. ":Driving", TripId = trip.Id, ServerStartTime = Workspace:GetServerTimeNow() })
end

local function payout(player, trip, result, elapsed)
	local provider = providers[trip.Kind]
	local request = {
		Cash = result.Cash, Xp = result.Xp, Reason = provider.Reason, JobCeiling = true, Label = provider.PayLabel,
		CommandId = trip.Kind .. ":" .. trip.Id .. ":" .. player.UserId,
	}
	local ok, paid = pcall(ActivityPayout.Pay, player, table.clone(request))
	if not ok or type(paid) ~= "table" or not paid.Ok then
		warn("[JobBoard] payout attempt 1 failed; retrying", request.CommandId, ok and type(paid) == "table" and paid.Message or paid)
		task.wait(3)
		if player.Parent ~= Players then return end
		ok, paid = pcall(ActivityPayout.Pay, player, table.clone(request)) -- same CommandId: idempotent
	end
	if player.Parent ~= Players then return end
	if not ok or type(paid) ~= "table" or not paid.Ok then
		warn("[JobBoard] payout failed", request.CommandId, ok and type(paid) == "table" and paid.Message or paid)
		push(player, { Type = trip.Kind .. ":Failed", TripId = trip.Id, Reason = (ok and type(paid) == "table" and paid.Message) or "Payout failed; please try again later." })
		return
	end
	local breakdown = result.Breakdown
	-- A retry after a committed-but-lost reply reports Amount 0; the player was paid the requested amount.
	local shownCash = (paid.Cash == 0 and not paid.Capped) and request.Cash or paid.Cash
	push(player, {
		Type = trip.Kind .. ":Completed", TripId = trip.Id,
		Cash = shownCash, Xp = paid.Xp, Capped = paid.Capped == true,
		Total = breakdown.Total, Base = breakdown.Base, SpeedBonus = breakdown.SpeedBonus,
		SpeedMultiplier = breakdown.SpeedMultiplier, CrashPenalty = breakdown.CrashPenalty,
		Crashes = trip.Crashes, Seconds = math.floor(elapsed + 0.5), Distance = math.floor(trip.Distance + 0.5),
	})
end

local function complete(player, trip, elapsed)
	local result = JobRules.Settle(trip, elapsed, trip.LimitSps, trip.Config)
	if not result.Ok then
		JobBoard.FailTrip(player, trip, result.Reason)
		return
	end
	-- Leave the busy state before paying so a cancel cannot race the (yielding) payout; the CommandId
	-- keeps the grant idempotent.
	if not closeTrip(player, trip) then return end
	pcall(ActivityService.End, player, trip.RecordId, "Complete")
	call(providers[trip.Kind], "OnEnd", player, trip, "Complete")
	task.spawn(payout, player, trip, result, elapsed)
end

local function stepTrip(player, trip, now)
	local current = ActivityService.Current(player)
	if not current or current.Id ~= trip.RecordId then
		if closeTrip(player, trip) then call(providers[trip.Kind], "OnEnd", player, trip, "Lost") end
		return
	end
	if trip.Phase ~= "Driving" then
		if now - trip.AcceptedAt > 20 then JobBoard.FailTrip(player, trip, "The pickup fell through.") end
		return
	end
	local config = trip.Config
	local elapsed = now - trip.StartedAt
	if elapsed > trip.AbandonAfter then
		JobBoard.FailTrip(player, trip, trip.Kind == "Taxi" and "Your fare gave up and got out." or "The delivery took too long.")
		return
	end
	local vehicle = ActivityService.GetVehicle(player)
	local root = rootOf(vehicle)
	if not root then
		trip.LastPosition, trip.LastAt = nil, nil -- no distance is credited across a gap
		return -- ActivityService cancels on despawn / exit grace
	end
	local position = root.Position
	if trip.LastPosition then
		trip.Driven += JobRules.CapStep(JobRules.Flat(position, trip.LastPosition), now - trip.LastAt, trip.LimitSps)
	end
	trip.LastPosition, trip.LastAt = position, now
	local mph = horizontalMph(root)
	local samples = trip.Samples
	table.insert(samples, { T = now, Mph = mph })
	while samples[1] and now - samples[1].T > 1 do table.remove(samples, 1) end
	if now - trip.LastImpactAt >= config.ImpactCooldownSeconds and JobRules.IsImpact(samples, now, mph, config) then
		trip.LastImpactAt = now
		trip.Crashes += 1
		push(player, { Type = trip.Kind .. ":Crash", TripId = trip.Id, Crashes = trip.Crashes, DamageFactor = JobRules.DamageFactor(trip.Crashes, config) })
	end
	if JobRules.Arrived(JobRules.Flat(position, trip.Destination), mph, config) and ActivityService.GetDrivenVehicle(player) == vehicle then
		complete(player, trip, elapsed)
	end
end

-- JobAccept ---------------------------------------------------------------------------------------

local function accept(player, args)
	local board = boardConfig()
	if not board.Enabled then return { Ok = false, Message = "Jobs are closed right now." } end
	local offerId = args.OfferId
	if not JobRules.ValidOfferId(offerId) then return { Ok = false, Message = "Unknown job." } end
	local offer = offers[offerId]
	if not offer then return { Ok = false, Message = "That job was just taken." } end
	local provider = providers[offer.Kind]
	if not provider or not kindEnabled(offer.Kind) then return { Ok = false, Message = "That job is closed right now." } end
	local tripConfig = provider.ReadConfig()
	if tripConfig.MinRank > 1 then
		local okRank, rank = pcall(ProgressionService.GetRank, player)
		if okRank and tonumber(rank) and rank < tripConfig.MinRank then
			return { Ok = false, Message = string.format("This job unlocks at rank %d.", tripConfig.MinRank) }
		end
	end
	if trips[player] then return { Ok = false, Message = "Finish your current job first." } end
	local busy, reason = ActivityService.IsBusy(player)
	if busy then return { Ok = false, Message = reason or "You are busy right now." } end
	local vehicle = ActivityService.GetDrivenVehicle(player)
	local root = rootOf(vehicle)
	if not root then return { Ok = false, Message = "Drive your own car up to the job." } end
	local near, message = JobRules.CanAcceptAt(JobRules.Flat(root.Position, offer.Position), root.Position.Y - offer.Position.Y, horizontalMph(root), board)
	if not near then return { Ok = false, Message = message } end
	if provider.CanAccept then
		local okCheck, can, why = pcall(provider.CanAccept, player, vehicle, offer)
		if not okCheck or not can then return { Ok = false, Message = (okCheck and why) or "You can't take this job right now." } end
	end
	if offers[offerId] ~= offer then return { Ok = false, Message = "That job was just taken." } end
	local record, err = ActivityService.Begin(player, offer.Kind, { OfferId = offerId })
	if not record then return { Ok = false, Message = err or "You are busy right now." } end
	removeOffer(offer, "Taken", true)
	local reference = JobRules.ReferenceSeconds(offer.Distance, tripConfig)
	local trip = {
		Id = ActivityService.NewId("Trip"), Kind = offer.Kind, Player = player, RecordId = record.Id, OfferId = offerId,
		Pickup = offer.Position, Destination = offer.Destination, DestinationFacing = offer.DestinationFacing,
		Distance = offer.Distance, Straight = offer.Straight, Label = offer.Label,
		Config = tripConfig, Reference = reference, AbandonAfter = JobRules.AbandonSeconds(reference, board),
		LimitSps = limitStudsPerSecond(tripConfig), Crashes = 0, Driven = 0, Samples = {}, LastImpactAt = -math.huge,
		Phase = "Accepted", AcceptedAt = os.clock(), StartedAt = os.clock(), LastAt = os.clock(),
	}
	trips[player] = trip
	push(player, {
		Type = offer.Kind .. ":Started", TripId = trip.Id, OfferId = offerId, Pickup = offer.Position,
		Destination = offer.Destination, Distance = math.floor(offer.Distance + 0.5), ReferenceSeconds = reference,
		Estimate = offer.Estimate, Pay = JobRules.PaySnapshot(tripConfig), Boarding = provider.Boards == true, Label = offer.Label,
	})
	local okAccept, acceptError = pcall(provider.OnAccept, player, trip, offer, vehicle)
	if not okAccept then
		warn("[JobBoard] " .. offer.Kind .. ".OnAccept failed: " .. tostring(acceptError))
		JobBoard.FailTrip(player, trip, "The job could not start.")
		return { Ok = false, Message = "The job could not start." }
	end
	requestFill()
	return { Ok = true, Kind = offer.Kind, Distance = math.floor(offer.Distance + 0.5), Estimate = offer.Estimate }
end

-- Loop --------------------------------------------------------------------------------------------

local tripHz = 10

local function boardTick()
	local board = boardConfig()
	tripHz = board.TripTickHz
	local now = Workspace:GetServerTimeNow()
	local positions = playerPositions()
	for _, offer in pairs(offers) do
		if not board.Enabled or not kindEnabled(offer.Kind) or countOffers(offer.Kind) > target(board, offer.Kind) then
			removeOffer(offer, "Disabled", false)
		else
			local nearest = nearestDistance(offer.Position, positions)
			local decision = JobRules.ExpiryDecision(now, offer.ExpiresAt, offer.Extensions, nearest, board)
			if decision == "Expire" then
				removeOffer(offer, "Expired", false)
			else
				if decision == "Extend" then
					offer.Extensions += 1
					offer.ExpiresAt = now + board.ExtendSeconds
					if offer.Instance then offer.Instance:SetAttribute("ExpiresAt", offer.ExpiresAt) end
				end
				local limit = offer.Near and (board.StreamRadius + board.StreamHysteresis) or board.StreamRadius
				local near = nearest <= limit
				if near ~= offer.Near then
					offer.Near = near
					task.spawn(call, providers[offer.Kind], "OfferNear", offer, near) -- rig building may yield
				end
			end
		end
	end
	if board.Enabled then
		for kind in pairs(providers) do
			if kindEnabled(kind) and countOffers(kind) < target(board, kind) then fillRequested = true end
		end
	end
	if fillRequested and not generating and os.clock() >= nextFillAt then task.spawn(fill) end
end

function JobBoard.start()
	if state ~= "idle" then return end
	state = "starting"
	local ok, message = xpcall(function()
		local activities = ServerStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Activities")
		ActivityService = require(activities:WaitForChild("ActivityService"))
		ActivityPayout = require(activities:WaitForChild("ActivityPayout"))
		ProgressionService = require(activities:WaitForChild("ProgressionService"))
		local shared = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game")
		JobRules = require(shared:WaitForChild("Activities"):WaitForChild("JobRules"))
		RoadRouting = require(shared:WaitForChild("World"):WaitForChild("RoadRouting"))
		configRoot = ReplicatedStorage:WaitForChild("Config"):WaitForChild("Activities")
		local racing = ServerStorage.Modules.Game:FindFirstChild("Racing")
		local integrity = racing and racing:FindFirstChild("RaceIntegrity")
		if integrity then
			local okRequire, module = pcall(require, integrity)
			if okRequire and type(module) == "table" and type(module.limitMph) == "function" then RaceIntegrity = module end
		end

		-- Runtime-only offer folder (not saved in the place).
		local activityState = ReplicatedStorage:FindFirstChild("ActivityState")
		if not activityState then
			activityState = Instance.new("Folder")
			activityState.Name = "ActivityState"
			activityState.Parent = ReplicatedStorage
		end
		offersFolder = activityState:FindFirstChild("JobOffers")
		if offersFolder then offersFolder:ClearAllChildren() else
			offersFolder = Instance.new("Folder")
			offersFolder.Name = "JobOffers"
			offersFolder.Parent = activityState
		end

		ActivityService.Register("Jobs", {
			Actions = { JobAccept = accept },
			RequiresVehicle = false, -- never begun; owns the JobAccept action only
		})

		Players.PlayerRemoving:Connect(function(player)
			-- ActivityService cancels the record (-> HandleCancel); this only drops a stale reference.
			task.defer(function()
				local trip = trips[player]
				if trip and closeTrip(player, trip) then call(providers[trip.Kind], "OnEnd", player, trip, "Lost") end
			end)
		end)

		local boardAccumulator, tripAccumulator = 1, 0
		RunService.Heartbeat:Connect(function(dt)
			boardAccumulator += dt
			tripAccumulator += dt
			if boardAccumulator >= 1 then
				boardAccumulator = 0
				local okTick, err = pcall(boardTick)
				if not okTick then warn("[JobBoard] board tick failed: " .. tostring(err)) end
			end
			if next(trips) == nil then tripAccumulator = 0 return end
			if tripAccumulator < 1 / tripHz then return end
			tripAccumulator = 0
			local now = os.clock()
			for player, trip in pairs(trips) do
				local okStep, err = pcall(stepTrip, player, trip, now)
				if not okStep then
					warn("[JobBoard] trip step failed: " .. tostring(err))
					JobBoard.FailTrip(player, trip, "Job error.")
				end
			end
		end)
	end, debug.traceback)
	state = ok and "ready" or "failed"
	assert(ok, message)
end

return JobBoard
