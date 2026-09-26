-- Canonical feature implementation (pure rules; no services, instances or game requires).
-- Sky Taxi maths and decisions: fares, stars, impacts, distance bands, estimates, request
-- cooldowns and argument validation. TaxiJob reads config attributes and passes them in as a
-- plain table; every value is bounded here so a bad attribute can never produce a bad payout.
local TaxiRules = {}

TaxiRules.MPH_PER_STUD = 0.625 -- 1 stud/s = 0.625 mph

-- Defaults and bounds for every tunable (Config.Activities.Taxi attributes of the same name).
TaxiRules.Defaults = {
	MinRank = { 1, 1, 100 },
	FareBase = { 1000, 0, 10000 },
	FarePerStud = { 0.5, 0, 5 },
	XpBase = { 50, 0, 1000 },
	XpPerStud = { 0.04, 0, 1 },
	NpcMinStuds = { 300, 50, 2000 },
	NpcMaxStuds = { 900, 100, 4000 },
	DestMinStuds = { 800, 100, 4000 },
	DestMaxStuds = { 2500, 200, 6000 },
	PickupRadius = { 25, 8, 80 },
	ArriveRadius = { 35, 8, 100 },
	StopMph = { 10, 1, 40 },
	ImpactMph = { 25, 5, 200 },
	ImpactWindowSeconds = { 0.2, 0.05, 1 },
	ImpactCooldownSeconds = { 1, 0.1, 5 },
	StarLossPerImpact = { 1, 0, 5 },
	SlowFactor = { 1.25, 1, 5 },
	VerySlowFactor = { 1.75, 1, 10 },
	EstimateStudsPerSecond = { 80, 10, 400 },
	EstimateBaseSeconds = { 20, 0, 120 },
	FareTimeoutSeconds = { 240, 30, 900 },
	NextFareSeconds = { 4, 0, 60 },
	RequestTimeoutSeconds = { 180, 30, 900 },
	AcceptWindowSeconds = { 120, 30, 600 },
	RequestCooldownSeconds = { 20, 0, 600 },
	PairCooldownSeconds = { 300, 0, 3600 },
	PlayerMinRideStuds = { 300, 50, 5000 },
	PlayerFareBase = { 1000, 0, 10000 },
	PlayerFarePerStud = { 0.5, 0, 5 },
	PlayerFareMaxStuds = { 3000, 100, 10000 },
	MinDrivenFraction = { 0.7, 0.1, 1 },
	FallbackLimitMph = { 400, 50, 2000 },
}

-- Star multipliers (index = stars, 1..5).
TaxiRules.StarMultiplier = { 0.5, 0.7, 0.85, 1.0, 1.15 }

local function finite(value: any): number?
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then return nil end
	return n
end

-- Resolve a config table from a raw attribute reader: read(key) -> any.
function TaxiRules.ResolveConfig(read: ((string) -> any)?): { [string]: number }
	local config = {}
	for key, spec in pairs(TaxiRules.Defaults) do
		local raw = read and finite(read(key)) or nil
		config[key] = math.clamp(raw or spec[1], spec[2], spec[3])
	end
	-- Keep bands ordered.
	config.NpcMaxStuds = math.max(config.NpcMaxStuds, config.NpcMinStuds + 50)
	config.DestMaxStuds = math.max(config.DestMaxStuds, config.DestMinStuds + 50)
	config.VerySlowFactor = math.max(config.VerySlowFactor, config.SlowFactor)
	return config
end

function TaxiRules.Mph(studsPerSecond: number): number
	return math.max(0, finite(studsPerSecond) or 0) * TaxiRules.MPH_PER_STUD
end

function TaxiRules.Flat(ax: number, az: number, bx: number, bz: number): number
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Driver is stopped at a point: within radius (flat studs) and slower than StopMph.
function TaxiRules.IsStoppedAt(distance: number, speedMph: number, radius: number, stopMph: number): boolean
	distance, speedMph = finite(distance) or math.huge, finite(speedMph) or math.huge
	return distance <= radius and speedMph < stopMph
end

-- Impact: the speed dropped by more than ImpactMph from the highest sample inside the window.
-- samples: array of { T = seconds, Mph = number } (any order); now = current time.
function TaxiRules.IsImpact(samples: { { T: number, Mph: number } }, now: number, currentMph: number, config): boolean
	local peak = 0
	for _, sample in ipairs(samples) do
		if now - sample.T <= config.ImpactWindowSeconds and sample.Mph > peak then peak = sample.Mph end
	end
	return peak - (finite(currentMph) or 0) > config.ImpactMph
end

-- Estimated drive time for a road distance.
function TaxiRules.EstimateSeconds(routeStuds: number, config): number
	local studs = math.max(0, finite(routeStuds) or 0)
	return math.floor(config.EstimateBaseSeconds + studs / config.EstimateStudsPerSecond + 0.5)
end

-- Stars 1..5: start at 5, lose StarLossPerImpact per impact, 1 for slow and 2 for very slow.
function TaxiRules.Stars(impacts: number, elapsedSeconds: number, estimateSeconds: number, config): number
	local stars = 5 - math.max(0, math.floor(finite(impacts) or 0)) * config.StarLossPerImpact
	local elapsed = math.max(0, finite(elapsedSeconds) or 0)
	local estimate = math.max(1, finite(estimateSeconds) or 1)
	if elapsed > estimate * config.VerySlowFactor then
		stars -= 2
	elseif elapsed > estimate * config.SlowFactor then
		stars -= 1
	end
	return math.clamp(math.floor(stars + 0.5), 1, 5)
end

-- NPC fare: (FareBase + FarePerStud * distance) x star multiplier. Distance is the server's
-- pickup -> destination road length (never client-reported).
function TaxiRules.Fare(distanceStuds: number, stars: number, config): (number, number)
	local distance = math.clamp(finite(distanceStuds) or 0, 0, config.DestMaxStuds * 4)
	local multiplier = TaxiRules.StarMultiplier[math.clamp(math.floor(finite(stars) or 1), 1, 5)]
	local cash = math.floor((config.FareBase + config.FarePerStud * distance) * multiplier + 0.5)
	local xp = math.floor((config.XpBase + config.XpPerStud * distance) * multiplier + 0.5)
	return math.max(0, cash), math.max(0, xp)
end

-- Player ride bonus (game-funded, paid to the driver only). Returns 0,0 below the minimum ride.
function TaxiRules.PlayerFare(riddenStuds: number, config): (number, number)
	local ridden = math.max(0, finite(riddenStuds) or 0)
	if ridden < config.PlayerMinRideStuds then return 0, 0 end
	local counted = math.min(ridden, config.PlayerFareMaxStuds)
	local cash = math.floor(config.PlayerFareBase + config.PlayerFarePerStud * counted + 0.5)
	local xp = math.floor(config.XpBase + config.XpPerStud * counted + 0.5)
	return cash, xp
end

-- Distance bands.
function TaxiRules.NpcBand(config): (number, number)
	return config.NpcMinStuds, config.NpcMaxStuds
end

function TaxiRules.DestinationBand(config): (number, number)
	return config.DestMinStuds, config.DestMaxStuds
end

function TaxiRules.InBand(distance: number, minimum: number, maximum: number): boolean
	local d = finite(distance)
	return d ~= nil and d >= minimum and d <= maximum
end

-- Cooldowns. `last` is nil when never used.
function TaxiRules.CooldownRemaining(last: number?, now: number, seconds: number): number
	if last == nil then return 0 end
	return math.max(0, seconds - (now - last))
end

function TaxiRules.PairKey(driverUserId: number, riderUserId: number): string
	return tostring(driverUserId) .. ":" .. tostring(riderUserId)
end

-- A player ride pays only when it was long enough and the pair is off cooldown.
function TaxiRules.PlayerRidePays(riddenStuds: number, pairLastPaidAt: number?, now: number, config): (boolean, string?)
	if (finite(riddenStuds) or 0) < config.PlayerMinRideStuds then return false, "TooShort" end
	if TaxiRules.CooldownRemaining(pairLastPaidAt, now, config.PairCooldownSeconds) > 0 then return false, "PairCooldown" end
	return true, nil
end

-- Anti-teleport: the server only counts movement a car could plausibly make in `dt` seconds at
-- `limitStudsPerSecond` (+ a small tolerance), so a client-side teleport adds at most one capped step.
function TaxiRules.CapStep(delta: number, dt: number, limitStudsPerSecond: number): number
	local d = math.max(0, finite(delta) or 0)
	local step = math.clamp(finite(dt) or 0, 0, 1)
	local limit = math.max(1, finite(limitStudsPerSecond) or 1)
	return math.min(d, limit * step + 2)
end

-- A delivered NPC fare pays only when the server-counted driven distance covers MinDrivenFraction
-- of the route and the elapsed time is at least what the route takes at the speed limit.
function TaxiRules.FarePlausible(driven: number, distance: number, elapsed: number, limitStudsPerSecond: number, config): (boolean, string?)
	local route = math.max(0, finite(distance) or 0)
	if (finite(driven) or 0) < route * config.MinDrivenFraction then return false, "Distance" end
	local limit = math.max(1, finite(limitStudsPerSecond) or 1)
	if (finite(elapsed) or 0) < route / limit then return false, "Time" end
	return true, nil
end

-- Validation helpers (client args are untrusted).
function TaxiRules.ValidateDutyArgs(args: any): (boolean?, string?)
	if type(args) ~= "table" or type(args.OnDuty) ~= "boolean" then return nil, "Invalid duty request." end
	return args.OnDuty, nil
end

function TaxiRules.ValidateUserId(value: any): number?
	local n = finite(value)
	if n == nil or n <= 0 or n ~= math.floor(n) or n > 2 ^ 53 then return nil end
	return n
end

-- Plain text (no glyphs): "4/5 STARS".
function TaxiRules.FormatStars(stars: number): string
	local n = math.clamp(math.floor(finite(stars) or 0), 0, 5)
	return n .. "/5 STARS"
end

return TaxiRules
