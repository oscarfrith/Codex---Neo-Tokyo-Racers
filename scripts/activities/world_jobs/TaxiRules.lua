-- Canonical feature implementation (pure rules; no services, instances or game requires).
-- World taxi fares (map-markers-contract "World jobs"): the Taxi trip tunables and the few taxi-only
-- decisions. The shared trip maths (pay, speed bonus, crash penalty, plausibility) lives in JobRules;
-- TaxiJob passes the table from ReadConfig into it. Every value is bounded here.
local TaxiRules = {}

TaxiRules.KIND = "Taxi"
TaxiRules.REASON = "TaxiFare"

-- ReplicatedStorage.Config.Activities.Taxi attributes. key = { default, min, max }.
-- MinRank, ImpactWindowSeconds and ImpactCooldownSeconds are existing attributes (same meaning).
TaxiRules.Tunables = {
	MinRank = { 1, 1, 100 },
	TripBasePay = { 200, 0, 100000 },
	TripPayPerStud = { 0.11, 0, 10 },
	TripXpBase = { 25, 0, 10000 },
	TripXpPerStuds = { 120, 1, 100000 },
	ReferenceMph = { 85, 10, 1000 },
	TripGraceSeconds = { 10, 0, 300 },
	SpeedSensitivity = { 0.75, 0, 5 },
	SpeedMultiplierMin = { 0.6, 0.1, 1 },
	SpeedMultiplierMax = { 1.5, 1, 5 },
	CrashPenalty = { 0.12, 0, 1 },
	CrashFloor = { 0.4, 0, 1 },
	CrashImpactMph = { 35, 5, 500 },
	ImpactWindowSeconds = { 0.25, 0.05, 2 },
	ImpactCooldownSeconds = { 1, 0.1, 10 },
	DropRadius = { 60, 10, 300 },
	DropMaxMph = { 15, 1, 100 },
	DrivenMinFraction = { 0.6, 0.1, 1 },
	LimitFallbackMph = { 400, 50, 5000 },
	BoardSeconds = { 2.5, 0, 10 }, -- the fare walks to the car before getting in
	BoardWalkStuds = { 8, 2, 40 }, -- close enough to hop in early
	ExitWalkSeconds = { 5, 1, 20 }, -- after drop-off the fare walks to the kerb, then despawns
}

local function finite(value)
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then return nil end
	return n
end

-- read(key) -> raw attribute or nil. Returns bounded config plus Enabled (default true).
function TaxiRules.ReadConfig(read)
	local config = {}
	for key, spec in pairs(TaxiRules.Tunables) do
		local raw = read and finite(read(key)) or nil
		config[key] = math.clamp(raw or spec[1], spec[2], spec[3])
	end
	config.SpeedMultiplierMax = math.max(config.SpeedMultiplierMax, config.SpeedMultiplierMin)
	config.MinRank = math.floor(config.MinRank)
	local enabled = read and read("Enabled")
	config.Enabled = enabled ~= false
	local animation = read and read("HailAnimationId")
	config.HailAnimationId = type(animation) == "string" and animation or ""
	return config
end

function TaxiRules.Defaults()
	return TaxiRules.ReadConfig(nil)
end

-- Where the fare waits to board: beside the passenger seat on the kerb side (seat -X side, the same
-- side PassengerService uses for exits). Plain maths on a seat position + right vector.
function TaxiRules.BoardingPoint(seatPosition, seatRight, sideStuds)
	return seatPosition - seatRight * (sideStuds or 6)
end

-- Boarding ends when the fare is close enough or the time is up.
function TaxiRules.BoardingDone(distance, waited, config)
	return (finite(distance) or math.huge) <= config.BoardWalkStuds or (finite(waited) or 0) >= config.BoardSeconds
end

return TaxiRules
