-- Pure Courier rules (Street Life design 4.6). No game services, no instances and no requires, so
-- scripts/activities/courier/tests.lua can loadstring it. All numbers are tunable through
-- ReplicatedStorage.Config.Activities.Courier attributes; CourierRules.ReadConfig bounds every value.
local CourierRules = {}

CourierRules.MPH_PER_STUD_PER_SECOND = 0.625
CourierRules.VARIANTS = { "Standard", "Hot", "Fragile" }

-- key = { default, minimum, maximum }
CourierRules.Tunables = {
	MinRank = { 1, 1, 100 },
	HubRadius = { 30, 5, 200 },
	HubHeightTolerance = { 25, 5, 200 },
	MinDistance = { 600, 100, 20000 },
	MaxDistance = { 2000, 150, 20000 },
	RoadDistanceFactor = { 1.3, 1, 4 },
	BasePay = { 1500, 0, 1000000 },
	PayPerStud = { 0.6, 0, 100 },
	MaxTimeBonus = { 0.3, 0, 5 },
	HotPayMultiplier = { 1.4, 1, 10 },
	HotTimeFactor = { 0.75, 0.2, 1 },
	FragilePayMultiplier = { 1.25, 1, 10 },
	FragileImpactPenalty = { 0.15, 0, 1 },
	FragileFloor = { 0.4, 0, 1 },
	FragileImpactMph = { 45, 5, 1000 },
	ImpactWindowSeconds = { 0.2, 0.05, 2 },
	ImpactCooldownSeconds = { 0.75, 0, 10 },
	AvgSpeedMph = { 70, 5, 1000 },
	GraceSeconds = { 25, 0, 600 },
	MinTimeLimit = { 30, 5, 3600 },
	MaxTimeLimit = { 300, 10, 3600 },
	DeliverRadius = { 40, 5, 500 },
	DeliverMaxMph = { 25, 1, 1000 },
	MaxPlausibleMph = { 400, 50, 5000 },
	SegmentSeconds = { 1, 0.25, 10 },
	SegmentToleranceStuds = { 30, 0, 2000 },
	Star3Fraction = { 0.5, 0, 1 },
	Star2Fraction = { 0.25, 0, 1 },
	XpBase = { 20, 0, 100000 },
	XpPerStuds = { 100, 1, 100000 },
	ChainStep = { 0.1, 0, 1 },
	ChainMax = { 1.5, 1, 10 },
	ChainWindowSeconds = { 90, 0, 3600 },
	TickHz = { 10, 1, 60 },
}

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- get(key) returns the raw attribute value (or nil). Returns a table with every tunable bounded,
-- plus Enabled (boolean, default true).
function CourierRules.ReadConfig(get)
	local config = {}
	for key, spec in pairs(CourierRules.Tunables) do
		local raw = get and tonumber(get(key)) or nil
		if not finite(raw) then raw = spec[1] end
		config[key] = math.clamp(raw, spec[2], spec[3])
	end
	local enabled = get and get("Enabled")
	config.Enabled = enabled ~= false
	config.MaxDistance = math.max(config.MaxDistance, config.MinDistance + 50)
	config.MaxTimeLimit = math.max(config.MaxTimeLimit, config.MinTimeLimit)
	config.Star2Fraction = math.min(config.Star2Fraction, config.Star3Fraction)
	return config
end

function CourierRules.Defaults()
	return CourierRules.ReadConfig(nil)
end

function CourierRules.ValidVariant(variant)
	if type(variant) ~= "string" then return nil end
	for _, name in ipairs(CourierRules.VARIANTS) do
		if name == variant then return name end
	end
	return nil
end

function CourierRules.StudsPerSecond(mph)
	return mph / CourierRules.MPH_PER_STUD_PER_SECOND
end

function CourierRules.Mph(studsPerSecond)
	return studsPerSecond * CourierRules.MPH_PER_STUD_PER_SECOND
end

-- Horizontal (X/Z) distance between two Vector3-like values.
function CourierRules.FlatDistance(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- True when a vehicle root at `position` stands on the hub pad at `hubPosition`.
function CourierRules.OnHub(position, hubPosition, config)
	return CourierRules.FlatDistance(position, hubPosition) <= config.HubRadius
		and math.abs(position.Y - hubPosition.Y) <= config.HubHeightTolerance
end

-- hubs: array of { Id, Position }. Returns (hub, flatDistance) or nil.
function CourierRules.NearestHub(hubs, position)
	local best, bestDistance = nil, math.huge
	for _, hub in ipairs(hubs) do
		local distance = CourierRules.FlatDistance(position, hub.Position)
		if distance < bestDistance then best, bestDistance = hub, distance end
	end
	return best, best and bestDistance or nil
end

-- Road distance used for pay and the timer: the routed length when available and sane, otherwise the
-- straight distance scaled by RoadDistanceFactor. Never below the straight distance or above 4x it.
function CourierRules.TripDistance(straight, routed, config)
	straight = math.max(0, straight)
	local distance = (finite(routed) and routed > 0) and routed or straight * config.RoadDistanceFactor
	return math.clamp(distance, straight, math.max(straight * 4, straight + 1))
end

function CourierRules.TimeLimit(distance, variant, config)
	local travel = math.max(0, distance) / CourierRules.StudsPerSecond(config.AvgSpeedMph)
	local factor = variant == "Hot" and config.HotTimeFactor or 1
	local limit = (travel + config.GraceSeconds) * factor
	return math.clamp(math.floor(limit + 0.5), config.MinTimeLimit, config.MaxTimeLimit)
end

function CourierRules.Stars(remaining, timeLimit, config)
	if remaining < 0 then return 0 end
	local fraction = timeLimit > 0 and remaining / timeLimit or 0
	if fraction >= config.Star3Fraction then return 3 end
	if fraction >= config.Star2Fraction then return 2 end
	return 1
end

function CourierRules.VariantMultiplier(variant, impacts, config)
	if variant == "Hot" then return config.HotPayMultiplier end
	if variant == "Fragile" then
		local kept = math.max(config.FragileFloor, 1 - config.FragileImpactPenalty * math.max(0, impacts or 0))
		return config.FragilePayMultiplier * kept
	end
	return 1
end

function CourierRules.Pay(distance, remaining, timeLimit, variant, impacts, chain, config)
	local base = config.BasePay + config.PayPerStud * math.max(0, distance)
	local fraction = timeLimit > 0 and math.clamp(remaining / timeLimit, 0, 1) or 0
	local timeBonus = 1 + config.MaxTimeBonus * fraction
	local total = base * timeBonus * CourierRules.VariantMultiplier(variant, impacts, config) * math.max(1, chain or 1)
	return math.max(0, math.floor(total + 0.5))
end

function CourierRules.Xp(distance, config)
	return math.max(0, math.floor(config.XpBase + math.max(0, distance) / config.XpPerStuds))
end

-- Chain multiplier for a run starting at `now`, given the previous completed run.
function CourierRules.ChainForStart(lastChain, lastCompletedAt, now, config)
	if type(lastChain) ~= "number" or type(lastCompletedAt) ~= "number" then return 1 end
	if now - lastCompletedAt > config.ChainWindowSeconds then return 1 end
	local chain = math.min(lastChain + config.ChainStep, config.ChainMax)
	return math.floor(chain * 100 + 0.5) / 100
end

function CourierRules.Delivered(distanceToDrop, speedMph, config)
	return distanceToDrop <= config.DeliverRadius and speedMph < config.DeliverMaxMph
end

-- Speed limit (mph) for integrity checks: the race integrity limit when the server supplies a valid one
-- (RaceIntegrity.limitMph, which already allows 1.25x the highest vehicle cap), else MaxPlausibleMph.
function CourierRules.LimitMph(raceLimitMph, config)
	if finite(raceLimitMph) and raceLimitMph >= 50 then return raceLimitMph end
	return config.MaxPlausibleMph
end

-- Minimum plausible time: covering the routed trip distance faster than limitMph is rejected.
function CourierRules.PlausibleTime(distance, elapsed, limitMph)
	return elapsed >= math.max(0, distance) / CourierRules.StudsPerSecond(limitMph)
end

-- Movement check over one sampling segment (catches teleports; small slack for replication jitter).
function CourierRules.SegmentAllowed(distance, elapsed, limitMph, config)
	return distance <= math.max(0, elapsed) * CourierRules.StudsPerSecond(limitMph) + config.SegmentToleranceStuds
end

-- Fragile impact detection. samples is an array of { t, speed } (mph), oldest first, owned by the caller.
-- Records the new sample, prunes old ones and returns true when the speed dropped by more than
-- FragileImpactMph within ImpactWindowSeconds and the cooldown since lastImpactAt has passed.
function CourierRules.RecordSpeed(samples, now, speedMph, lastImpactAt, config)
	local peak = nil
	local keep = 1
	for index = 1, #samples do
		local sample = samples[index]
		if now - sample.t <= config.ImpactWindowSeconds + 1e-6 then
			samples[keep] = sample
			keep += 1
			peak = peak and math.max(peak, sample.speed) or sample.speed
		end
	end
	for index = #samples, keep, -1 do samples[index] = nil end
	table.insert(samples, { t = now, speed = speedMph })
	if not peak or peak - speedMph <= config.FragileImpactMph then return false end
	if type(lastImpactAt) == "number" and now - lastImpactAt < config.ImpactCooldownSeconds then return false end
	return true
end

-- Settles a finished run. run = { Distance, Straight, TimeLimit, Variant, Impacts, Chain, LimitMph?, Invalid? }.
-- Distance is the routed trip distance used for pay; it is also the minimum-time distance.
-- Returns { Ok, Reason?, Cash, Xp, Stars, Remaining }.
function CourierRules.Settle(run, elapsed, config)
	if run.Invalid then
		return { Ok = false, Reason = "Delivery rejected: " .. tostring(run.Invalid), Cash = 0, Xp = 0, Stars = 0, Remaining = 0 }
	end
	if not CourierRules.PlausibleTime(run.Distance, elapsed, CourierRules.LimitMph(run.LimitMph, config)) then
		return { Ok = false, Reason = "Delivery rejected: implausible time", Cash = 0, Xp = 0, Stars = 0, Remaining = 0 }
	end
	local remaining = run.TimeLimit - elapsed
	if remaining < 0 then
		return { Ok = false, Reason = "Out of time", Cash = 0, Xp = 0, Stars = 0, Remaining = remaining }
	end
	return {
		Ok = true,
		Cash = CourierRules.Pay(run.Distance, remaining, run.TimeLimit, run.Variant, run.Impacts, run.Chain, config),
		Xp = CourierRules.Xp(run.Distance, config),
		Stars = CourierRules.Stars(remaining, run.TimeLimit, config),
		Remaining = remaining,
	}
end

return CourierRules
