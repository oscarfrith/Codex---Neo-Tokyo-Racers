-- Pure world-jobs rules (docs/architecture/map-markers-contract.md "World jobs"). Shared by the server
-- (JobBoard, TaxiJob, CourierJob) and the client (JobClient: live pay estimate from the server's
-- snapshot). No services, no instances and no requires, so tests.lua can loadstring it. Positions are
-- world X/Z: Vector2 (X, Y=Z) or Vector3 (X, Z). All tunables are bounded here.
local JobRules = {}

JobRules.MPH_PER_STUD = 0.625 -- 1 stud/s = 0.625 mph
JobRules.KINDS = { "Taxi", "Courier" }

-- Board tunables: ReplicatedStorage.Config.Activities.Jobs attributes. key = { default, min, max }.
JobRules.BoardTunables = {
	TaxiOffers = { 6, 0, 20 },
	CourierOffers = { 5, 0, 20 },
	KerbOffset = { 48, 20, 120 }, -- fallback centre -> spot distance when no kerb edge is detected
	KerbSearchMin = { 26, 5, 100 },
	KerbSearchMax = { 76, 20, 160 },
	KerbSearchStep = { 4, 1, 20 },
	KerbRise = { 0.3, 0.05, 5 }, -- height change that counts as leaving the road surface
	PavementMargin = { 7, 0, 40 }, -- studs past the detected kerb edge
	IntersectionClearance = { 90, 0, 400 }, -- keep spots this far from graph nodes along the edge
	MinOfferSpacing = { 350, 0, 3000 },
	MinPlayerSpacing = { 250, 0, 2000 },
	FreshnessRadius = { 300, 0, 3000 },
	FreshnessMemory = { 16, 0, 100 },
	OfferTtlMin = { 360, 30, 3600 },
	OfferTtlMax = { 600, 30, 7200 },
	ExtendNearStuds = { 250, 0, 2000 },
	ExtendSeconds = { 45, 0, 600 },
	MaxExtensions = { 2, 0, 10 },
	TripMinStuds = { 1800, 200, 20000 },
	TripMaxStuds = { 4500, 300, 30000 },
	DestinationCandidates = { 40, 4, 200 },
	RecentTripMemory = { 10, 0, 100 },
	DuplicateTripStuds = { 500, 0, 5000 },
	DirectionSpreadDegrees = { 40, 0, 180 },
	SectorColumns = { 3, 1, 10 },
	SectorRows = { 4, 1, 10 },
	SpotTries = { 40, 5, 400 },
	StreamRadius = { 600, 100, 3000 },
	StreamHysteresis = { 150, 0, 1000 },
	PromptDistance = { 45, 5, 100 },
	AcceptRadius = { 60, 10, 200 },
	AcceptHeight = { 30, 5, 200 },
	AcceptMaxMph = { 18, 1, 100 },
	GroundTolerance = { 12, 1, 100 },
	PavementMinRise = { 0.25, -5, 10 }, -- pavement sits above the road (road parts Y 100.5, pavements Y 101)
	PavementMaxRise = { 1.5, 0, 20 }, -- higher means a planter, bush wall or divider, not pavement
	ClearHeight = { 40, 0, 400 },
	ProbeHeight = { 60, 10, 1000 },
	RoadY = { 101, -10000, 10000 }, -- probe reference height (ActivityService uses Y = 101)
	TripTickHz = { 10, 1, 30 },
	AbandonFactor = { 4, 1.5, 20 },
	AbandonGraceSeconds = { 120, 0, 3600 },
	RoadFactor = { 1.25, 1, 3 }, -- client projection: straight -> road distance
}

local function finite(value)
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then return nil end
	return n
end
JobRules.Finite = finite

-- Generic bounded reader: get(key) -> raw attribute (or nil).
function JobRules.ReadConfig(tunables, get)
	local config = {}
	for key, spec in pairs(tunables) do
		local raw = get and finite(get(key)) or nil
		config[key] = math.clamp(raw or spec[1], spec[2], spec[3])
	end
	local enabled = get and get("Enabled")
	config.Enabled = enabled ~= false
	return config
end

function JobRules.ReadBoardConfig(get)
	local config = JobRules.ReadConfig(JobRules.BoardTunables, get)
	config.OfferTtlMax = math.max(config.OfferTtlMax, config.OfferTtlMin)
	config.TripMaxStuds = math.max(config.TripMaxStuds, config.TripMinStuds + 100)
	config.KerbSearchMax = math.max(config.KerbSearchMax, config.KerbSearchMin + config.KerbSearchStep)
	for _, key in ipairs({ "TaxiOffers", "CourierOffers", "SectorColumns", "SectorRows", "FreshnessMemory", "RecentTripMemory",
		"MaxExtensions", "SpotTries", "DestinationCandidates" }) do
		config[key] = math.floor(config[key])
	end
	return config
end

function JobRules.Mph(studsPerSecond)
	return math.max(0, finite(studsPerSecond) or 0) * JobRules.MPH_PER_STUD
end

function JobRules.StudsPerSecond(mph)
	return math.max(0, finite(mph) or 0) / JobRules.MPH_PER_STUD
end

local function xz(p)
	if typeof(p) == "Vector3" then return p.X, p.Z end
	return p.X, p.Y
end

-- Horizontal distance between any two Vector2/Vector3 positions.
function JobRules.Flat(a, b)
	local ax, az = xz(a)
	local bx, bz = xz(b)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

function JobRules.InBounds(p, bounds)
	local x, z = xz(p)
	return x >= bounds.MinX and x <= bounds.MaxX and z >= bounds.MinZ and z <= bounds.MaxZ
end

-- Geometry ---------------------------------------------------------------------------------------

-- Point and unit tangent at `along` studs on a polyline (Vector2 points with cumulative lengths).
function JobRules.PointAlong(points, cumulative, along)
	local count = #points
	if count == 0 then return nil, nil end
	if count == 1 then return points[1], Vector2.new(1, 0) end
	along = math.clamp(finite(along) or 0, 0, cumulative[count])
	for s = 1, count - 1 do
		if along <= cumulative[s + 1] or s == count - 1 then
			local span = cumulative[s + 1] - cumulative[s]
			local t = span > 0 and math.clamp((along - cumulative[s]) / span, 0, 1) or 0
			local direction = points[s + 1] - points[s]
			local tangent = direction.Magnitude > 1e-6 and direction.Unit or Vector2.new(1, 0)
			return points[s] + direction * t, tangent
		end
	end
	return points[count], Vector2.new(1, 0)
end

-- Road direction averaged over +-window studs (the generated graph polylines are pixel-jagged, so a
-- single segment's direction can skew the kerb normal).
function JobRules.SmoothTangent(points, cumulative, along, window)
	local total = cumulative[#cumulative] or 0
	local a = JobRules.PointAlong(points, cumulative, math.max(0, along - window))
	local b = JobRules.PointAlong(points, cumulative, math.min(total, along + window))
	if a and b and (b - a).Magnitude > 1e-3 then return (b - a).Unit end
	local _, tangent = JobRules.PointAlong(points, cumulative, along)
	return tangent
end

-- Left-hand normal of a tangent; side = 1 or -1 picks the road side.
function JobRules.Normal(tangent, side)
	return Vector2.new(-tangent.Y, tangent.X) * (side < 0 and -1 or 1)
end

function JobRules.KerbPoint(centre, tangent, side, offset)
	return centre + JobRules.Normal(tangent, side) * offset
end

-- Usable edges (long enough to keep IntersectionClearance from both ends), weighted by usable length.
-- graph is a RoadRouting.LoadGraph result. bounds optional: edges with no point inside are skipped.
function JobRules.BuildEdgeTable(graph, clearance, bounds)
	local items, total = {}, 0
	for index, edge in ipairs(graph.Edges) do
		local usable = (edge.Length or 0) - 2 * clearance
		local inside = bounds == nil
		if not inside and edge.Points then
			for _, p in ipairs(edge.Points) do
				if JobRules.InBounds(p, bounds) then inside = true break end
			end
		end
		if usable > 10 and inside then
			total += usable
			table.insert(items, { Edge = index, Start = total - usable, Usable = usable })
		end
	end
	return { Items = items, Total = total, Clearance = clearance }
end

-- u1, u2 in [0, 1). Returns edgeIndex, along (studs from the edge's node A) or nil.
function JobRules.SampleEdge(edgeTable, u1, u2)
	if edgeTable.Total <= 0 or #edgeTable.Items == 0 then return nil end
	local target = math.clamp(u1, 0, 0.999999) * edgeTable.Total
	local lo, hi = 1, #edgeTable.Items
	while lo < hi do
		local mid = (lo + hi) // 2
		local item = edgeTable.Items[mid]
		if target < item.Start + item.Usable then hi = mid else lo = mid + 1 end
	end
	local item = edgeTable.Items[lo]
	return item.Edge, edgeTable.Clearance + math.clamp(u2, 0, 1) * item.Usable
end

-- Kerb detection from outward samples ordered by Offset: { Offset, Hit = bool, IsRoad = bool, Rise = bool }.
-- The kerb edge is the first non-road hit that either rises (Rise: at least KerbRise above the road) or
-- is followed by another non-road hit; a single flat non-road sample between road samples is a lane
-- marking and is skipped. The spot is PavementMargin past the edge. A missing hit before the kerb (void /
-- off the map) rejects. With allowFallback, an all-road strip uses KerbOffset.
-- Returns (spotOffset, how) or (nil, reason).
function JobRules.FindKerb(samples, config, allowFallback)
	for index, sample in ipairs(samples) do
		if not sample.Hit then return nil, "Void" end
		if not sample.IsRoad then
			local following = samples[index + 1]
			if sample.Rise or following == nil or (following.Hit and not following.IsRoad) then
				return sample.Offset + config.PavementMargin, "Kerb"
			end
		end
	end
	if allowFallback then return config.KerbOffset, "Fallback" end
	return nil, "NoKerb"
end

-- Ground at the chosen spot. ground = { Hit, Y, NormalY, Water, Collides }.
function JobRules.GroundOk(ground, roadY, config)
	if not ground or not ground.Hit then return false, "NoGround" end
	if ground.Water then return false, "Water" end
	if ground.Collides == false then return false, "NotSolid" end
	if (finite(ground.NormalY) or 0) < 0.7 then return false, "Slope" end
	if math.abs((finite(ground.Y) or math.huge) - roadY) > config.GroundTolerance then return false, "Height" end
	if ground.Surface == false then return false, "Surface" end
	local rise = (finite(ground.Y) or math.huge) - roadY
	if config.PavementMinRise and rise < config.PavementMinRise then return false, "NotPavement" end
	if config.PavementMaxRise and rise > config.PavementMaxRise then return false, "NotPavement" end
	return true, nil
end

-- A kerb spot must be nearer its own road than any other (not in a crossing road at a junction).
function JobRules.OffOtherRoads(nearestRoadDistance, spotOffset)
	return (finite(nearestRoadDistance) or 0) >= spotOffset * 0.8
end

-- Spacing and freshness ----------------------------------------------------------------------------

-- ctx = { Offers = {pos}, Players = {pos}, Recent = {pos}, Bounds }. relax 0 strict, 1 = radii x0.6,
-- 2 = offers x0.5 only (freshness and players ignored). Returns ok, reason.
function JobRules.SpotAllowed(point, ctx, config, relax)
	relax = relax or 0
	if ctx.Bounds and not JobRules.InBounds(point, ctx.Bounds) then return false, "Bounds" end
	local scale = relax >= 2 and 0.5 or relax == 1 and 0.6 or 1
	for _, other in ipairs(ctx.Offers or {}) do
		if JobRules.Flat(point, other) < config.MinOfferSpacing * scale then return false, "Offer" end
	end
	if relax < 2 then
		for _, other in ipairs(ctx.Players or {}) do
			if JobRules.Flat(point, other) < config.MinPlayerSpacing * scale then return false, "Player" end
		end
		for _, other in ipairs(ctx.Recent or {}) do
			if JobRules.Flat(point, other) < config.FreshnessRadius * scale then return false, "Recent" end
		end
	end
	return true, nil
end

-- Ring buffer push (newest last), trimmed to `limit`.
function JobRules.Remember(list, item, limit)
	table.insert(list, item)
	while #list > math.max(0, math.floor(limit)) do table.remove(list, 1) end
	return list
end

function JobRules.SectorOf(p, bounds, columns, rows)
	local x, z = xz(p)
	local cx = math.clamp(math.floor((x - bounds.MinX) / math.max(1, bounds.MaxX - bounds.MinX) * columns), 0, columns - 1)
	local cz = math.clamp(math.floor((z - bounds.MinZ) / math.max(1, bounds.MaxZ - bounds.MinZ) * rows), 0, rows - 1)
	return cz * columns + cx + 1
end

-- Pickup score: spread offers across sectors (fewer active offers in the sector = better).
function JobRules.ScorePickup(point, sectorCounts, bounds, config, jitter)
	local sector = JobRules.SectorOf(point, bounds, config.SectorColumns, config.SectorRows)
	return -(sectorCounts[sector] or 0) + (jitter or 0)
end

-- Road distances (Dijkstra) -------------------------------------------------------------------------

local function heapPush(heap, node, cost)
	heap[#heap + 1] = { node, cost }
	local i = #heap
	while i > 1 do
		local parent = i // 2
		if heap[parent][2] <= heap[i][2] then break end
		heap[parent], heap[i] = heap[i], heap[parent]
		i = parent
	end
end

local function heapPop(heap)
	local top = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		heap[1] = last
		local i = 1
		while true do
			local l, r, s = i * 2, i * 2 + 1, i
			if l <= #heap and heap[l][2] < heap[s][2] then s = l end
			if r <= #heap and heap[r][2] < heap[s][2] then s = r end
			if s == i then break end
			heap[i], heap[s] = heap[s], heap[i]
			i = s
		end
	end
	return top
end

-- Shortest road distance from a point `along` studs on edge `startEdge` to every node.
function JobRules.RoadDistances(graph, startEdge, along)
	local edge = graph.Edges[startEdge]
	local dist, heap = {}, {}
	local function seed(node, cost)
		if cost < (dist[node] or math.huge) then
			dist[node] = cost
			heapPush(heap, node, cost)
		end
	end
	seed(edge.A, along)
	seed(edge.B, edge.Length - along)
	while #heap > 0 do
		local item = heapPop(heap)
		local node, cost = item[1], item[2]
		if cost <= (dist[node] or math.huge) then
			for _, link in ipairs(graph.Adjacent[node] or {}) do
				local next = cost + graph.Edges[link.Edge].Length
				if next < (dist[link.To] or math.huge) then
					dist[link.To] = next
					heapPush(heap, link.To, next)
				end
			end
		end
	end
	return dist
end

-- Road distance from (startEdge, startAlong) to (edgeIndex, along) using a RoadDistances table.
function JobRules.RoadDistanceTo(graph, dist, startEdge, startAlong, edgeIndex, along)
	local edge = graph.Edges[edgeIndex]
	local best = math.min((dist[edge.A] or math.huge) + along, (dist[edge.B] or math.huge) + (edge.Length - along))
	if edgeIndex == startEdge then best = math.min(best, math.abs(along - startAlong)) end
	return best
end

-- Destinations ---------------------------------------------------------------------------------------

function JobRules.Bearing(from, to)
	local fx, fz = xz(from)
	local tx, tz = xz(to)
	return math.atan2(tz - fz, tx - fx)
end

function JobRules.AngleBetween(a, b)
	local d = math.abs((a - b) % (2 * math.pi))
	return math.min(d, 2 * math.pi - d)
end

function JobRules.TargetLength(config, u)
	return config.TripMinStuds + math.clamp(u, 0, 1) * (config.TripMaxStuds - config.TripMinStuds)
end

-- Band for a relax pass: 0 = [TripMin, TripMax]; 1 = widened (x0.75 / x1.3).
function JobRules.TripBand(config, relax)
	if (relax or 0) >= 1 then return config.TripMinStuds * 0.75, config.TripMaxStuds * 1.3 end
	return config.TripMinStuds, config.TripMaxStuds
end

-- candidate = { Point, Road }. ctx = { Pickup, TargetLength, Band = {min,max}, RecentTrips = {{Pickup, Drop}},
-- RecentDrops = {pos}, SectorCounts = {}, Bounds }. Returns score (higher better) or nil when rejected.
function JobRules.ScoreDestination(candidate, ctx, config)
	local road = finite(candidate.Road)
	local low, high = ctx.Band[1], ctx.Band[2]
	if not road or road < low or road > high then return nil end
	if ctx.Bounds and not JobRules.InBounds(candidate.Point, ctx.Bounds) then return nil end
	for _, trip in ipairs(ctx.RecentTrips or {}) do
		if JobRules.Flat(trip.Pickup, ctx.Pickup) < config.DuplicateTripStuds
			and JobRules.Flat(trip.Drop, candidate.Point) < config.DuplicateTripStuds then
			return nil -- near-duplicate of a recent trip
		end
	end
	local width = math.max(1, high - low)
	local score = -2 * math.abs(road - (ctx.TargetLength or road)) / width
	local spread = math.rad(config.DirectionSpreadDegrees)
	if spread > 0 then
		local bearing = JobRules.Bearing(ctx.Pickup, candidate.Point)
		for _, trip in ipairs(ctx.RecentTrips or {}) do
			local difference = JobRules.AngleBetween(bearing, JobRules.Bearing(trip.Pickup, trip.Drop))
			if difference < spread then score -= 0.6 * (1 - difference / spread) end
		end
	end
	for _, drop in ipairs(ctx.RecentDrops or {}) do
		if JobRules.Flat(drop, candidate.Point) < config.FreshnessRadius then score -= 1.5 end
	end
	if ctx.Bounds and ctx.SectorCounts then
		local sector = JobRules.SectorOf(candidate.Point, ctx.Bounds, config.SectorColumns, config.SectorRows)
		score -= 0.4 * (ctx.SectorCounts[sector] or 0)
	end
	return score
end

-- Offer expiry: "Keep", "Extend" (a player is closing in) or "Expire".
function JobRules.ExpiryDecision(now, expiresAt, extensions, nearestPlayer, config)
	if now < expiresAt then return "Keep" end
	if (finite(nearestPlayer) or math.huge) <= config.ExtendNearStuds and (extensions or 0) < config.MaxExtensions then
		return "Extend"
	end
	return "Expire"
end

-- Accepting / arriving ------------------------------------------------------------------------------

-- Car root against the offer spot. Returns ok, player-facing message.
function JobRules.CanAcceptAt(flatDistance, heightDifference, mph, config)
	if (finite(flatDistance) or math.huge) > config.AcceptRadius or math.abs(finite(heightDifference) or math.huge) > config.AcceptHeight then
		return false, "Pull up closer to the kerb."
	end
	if (finite(mph) or math.huge) > config.AcceptMaxMph then return false, "Slow down to pick up." end
	return true, nil
end

-- trip config (TaxiRules/CourierRules.ReadConfig): DropRadius, DropMaxMph.
function JobRules.Arrived(flatDistance, mph, tripConfig)
	return (finite(flatDistance) or math.huge) <= tripConfig.DropRadius and (finite(mph) or math.huge) < tripConfig.DropMaxMph
end

-- Crash: the horizontal speed dropped by more than CrashImpactMph from the peak inside the window.
-- samples: { { T, Mph } }.
function JobRules.IsImpact(samples, now, currentMph, tripConfig)
	local peak = 0
	for _, sample in ipairs(samples) do
		if now - sample.T <= tripConfig.ImpactWindowSeconds + 1e-6 and sample.Mph > peak then peak = sample.Mph end
	end
	return peak - (finite(currentMph) or 0) > tripConfig.CrashImpactMph
end

-- Anti-teleport: movement counted per step is capped at what the speed limit allows (+2 studs).
function JobRules.CapStep(delta, dt, limitStudsPerSecond)
	local d = math.max(0, finite(delta) or 0)
	local step = math.clamp(finite(dt) or 0, 0, 1)
	local limit = math.max(1, finite(limitStudsPerSecond) or 1)
	return math.min(d, limit * step + 2)
end

function JobRules.LimitMph(raceLimitMph, tripConfig)
	local value = finite(raceLimitMph)
	if value and value >= 50 then return value end
	return tripConfig.LimitFallbackMph
end

-- A finished trip pays only when the server-counted driven distance covers DrivenMinFraction of the
-- road distance (and at least the straight distance x the same fraction) and the time is plausible.
function JobRules.Plausible(driven, distance, straight, elapsed, limitStudsPerSecond, tripConfig)
	local road = math.max(0, finite(distance) or 0)
	local need = math.max(road, math.max(0, finite(straight) or 0)) * tripConfig.DrivenMinFraction
	if (finite(driven) or 0) < need then return false, "Distance" end
	if (finite(elapsed) or 0) < road / math.max(1, finite(limitStudsPerSecond) or 1) then return false, "Time" end
	return true, nil
end

-- Pay ------------------------------------------------------------------------------------------------

-- Par time for a trip: road distance at ReferenceMph plus TripGraceSeconds.
function JobRules.ReferenceSeconds(distance, tripConfig)
	return math.max(0, finite(distance) or 0) / math.max(1, JobRules.StudsPerSecond(tripConfig.ReferenceMph)) + tripConfig.TripGraceSeconds
end

function JobRules.SpeedMultiplier(referenceSeconds, elapsed, tripConfig)
	local ratio = math.max(1, finite(referenceSeconds) or 1) / math.max(1, finite(elapsed) or 1)
	local value = 1 + tripConfig.SpeedSensitivity * (ratio - 1)
	return math.clamp(value, tripConfig.SpeedMultiplierMin, tripConfig.SpeedMultiplierMax)
end

function JobRules.DamageFactor(crashes, tripConfig)
	local count = math.max(0, math.floor(finite(crashes) or 0))
	return math.max(tripConfig.CrashFloor, 1 - tripConfig.CrashPenalty * count)
end

function JobRules.Xp(distance, tripConfig)
	return math.max(0, math.floor(tripConfig.TripXpBase + math.max(0, finite(distance) or 0) / tripConfig.TripXpPerStuds + 0.5))
end

-- Full breakdown. Base = TripBasePay + TripPayPerStud x road distance; x speed multiplier; x damage factor.
-- SpeedBonus is the Cash the speed multiplier added (negative when slow); CrashPenalty the Cash crashes cost.
function JobRules.Pay(tripConfig, distance, elapsed, crashes)
	local road = math.max(0, finite(distance) or 0)
	local reference = JobRules.ReferenceSeconds(road, tripConfig)
	local base = tripConfig.TripBasePay + tripConfig.TripPayPerStud * road
	local speed = JobRules.SpeedMultiplier(reference, elapsed, tripConfig)
	local damage = JobRules.DamageFactor(crashes, tripConfig)
	local afterSpeed = base * speed
	local total = math.max(0, math.floor(afterSpeed * damage + 0.5))
	local roundedBase = math.floor(base + 0.5)
	local speedBonus = math.floor(afterSpeed + 0.5) - roundedBase
	return {
		Base = roundedBase,
		SpeedMultiplier = speed,
		SpeedBonus = speedBonus,
		DamageFactor = damage,
		CrashPenalty = roundedBase + speedBonus - total,
		Total = total,
		Xp = JobRules.Xp(road, tripConfig),
		ReferenceSeconds = reference,
	}
end

-- Client strip estimate: pay if the rest of the trip is driven at reference pace.
function JobRules.ProjectedPay(tripConfig, distance, elapsed, remainingStuds, crashes)
	local rest = math.max(0, finite(remainingStuds) or 0) / math.max(1, JobRules.StudsPerSecond(tripConfig.ReferenceMph))
	return JobRules.Pay(tripConfig, distance, (finite(elapsed) or 0) + rest, crashes).Total
end

function JobRules.AbandonSeconds(referenceSeconds, config)
	return referenceSeconds * config.AbandonFactor + config.AbandonGraceSeconds
end

-- trip = { Distance, Straight, Driven, Crashes }. Returns { Ok, Reason?, Cash, Xp, Breakdown }.
function JobRules.Settle(trip, elapsed, limitStudsPerSecond, tripConfig)
	local ok, why = JobRules.Plausible(trip.Driven, trip.Distance, trip.Straight, elapsed, limitStudsPerSecond, tripConfig)
	if not ok then
		return { Ok = false, Reason = why == "Time" and "Trip rejected: implausible time" or "Trip rejected: route not driven", Cash = 0, Xp = 0 }
	end
	local breakdown = JobRules.Pay(tripConfig, trip.Distance, elapsed, trip.Crashes)
	return { Ok = true, Cash = breakdown.Total, Xp = breakdown.Xp, Breakdown = breakdown }
end

-- Snapshot of the pay tunables sent to the client (so its estimate uses the server's numbers).
JobRules.PAY_KEYS = { "TripBasePay", "TripPayPerStud", "TripXpBase", "TripXpPerStuds", "ReferenceMph", "TripGraceSeconds",
	"SpeedSensitivity", "SpeedMultiplierMin", "SpeedMultiplierMax", "CrashPenalty", "CrashFloor" }

function JobRules.PaySnapshot(tripConfig)
	local snapshot = {}
	for _, key in ipairs(JobRules.PAY_KEYS) do snapshot[key] = tripConfig[key] end
	return snapshot
end

-- Client-supplied snapshot is only ever used for display; still bound it so bad data cannot error.
function JobRules.SafeSnapshot(snapshot)
	local safe = {}
	local defaults = { TripBasePay = 0, TripPayPerStud = 0, TripXpBase = 0, TripXpPerStuds = 100, ReferenceMph = 85, TripGraceSeconds = 10,
		SpeedSensitivity = 0.75, SpeedMultiplierMin = 1, SpeedMultiplierMax = 1, CrashPenalty = 0, CrashFloor = 1 }
	for key, default in pairs(defaults) do
		safe[key] = type(snapshot) == "table" and finite(snapshot[key]) or default
	end
	safe.TripXpPerStuds = math.max(1, safe.TripXpPerStuds)
	safe.SpeedMultiplierMax = math.max(safe.SpeedMultiplierMax, safe.SpeedMultiplierMin)
	return safe
end

-- Formatting -------------------------------------------------------------------------------------------

function JobRules.Money(amount)
	local n = math.floor(math.abs(finite(amount) or 0) + 0.5)
	local text = tostring(n)
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
	return ((finite(amount) or 0) < 0 and "-$" or "$") .. formatted
end

function JobRules.Clock(seconds)
	seconds = math.max(0, math.floor(finite(seconds) or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function JobRules.Miles(studs)
	local miles = math.max(0, finite(studs) or 0) / 5760
	if miles < 0.1 then return "<0.1 MI" end
	return string.format("%.1f MI", miles)
end

function JobRules.ValidOfferId(value)
	return type(value) == "string" and #value > 0 and #value <= 80 and value:match("^[%w_%-]+$") ~= nil
end

return JobRules
