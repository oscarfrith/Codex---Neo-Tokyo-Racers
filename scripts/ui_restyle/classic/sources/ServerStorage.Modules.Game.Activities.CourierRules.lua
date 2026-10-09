-- Pure world courier rules (map-markers-contract "World jobs"). No game services, instances or requires.
-- One standard job: pick a parcel up at the kerb, deliver it to a far kerb drop. No variants, no hubs,
-- no chains. The shared trip maths lives in JobRules; CourierJob passes ReadConfig's table into it.
local CourierRules = {}

CourierRules.KIND = "Courier"
CourierRules.REASON = "JobPayout"

-- ReplicatedStorage.Config.Activities.Courier attributes. key = { default, min, max }.
-- MinRank, ImpactWindowSeconds and ImpactCooldownSeconds are existing attributes (same meaning).
-- The old variant/hub attributes (HubRadius, HotPayMultiplier, Fragile*, Chain*, BasePay, ...) are unused.
CourierRules.Tunables = {
	MinRank = { 1, 1, 100 },
	TripBasePay = { 150, 0, 100000 },
	TripPayPerStud = { 0.1, 0, 10 },
	TripXpBase = { 20, 0, 10000 },
	TripXpPerStuds = { 150, 1, 100000 },
	ReferenceMph = { 85, 10, 1000 },
	TripGraceSeconds = { 8, 0, 300 },
	SpeedSensitivity = { 0.75, 0, 5 },
	SpeedMultiplierMin = { 0.6, 0.1, 1 },
	SpeedMultiplierMax = { 1.5, 1, 5 },
	CrashPenalty = { 0.15, 0, 1 },
	CrashFloor = { 0.35, 0, 1 },
	CrashImpactMph = { 35, 5, 500 },
	ImpactWindowSeconds = { 0.25, 0.05, 2 },
	ImpactCooldownSeconds = { 0.75, 0.1, 10 },
	DropRadius = { 60, 10, 300 },
	DropMaxMph = { 15, 1, 100 },
	DrivenMinFraction = { 0.6, 0.1, 1 },
	LimitFallbackMph = { 400, 50, 5000 },
}

local function finite(value)
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then return nil end
	return n
end

function CourierRules.ReadConfig(get)
	local config = {}
	for key, spec in pairs(CourierRules.Tunables) do
		local raw = get and finite(get(key)) or nil
		config[key] = math.clamp(raw or spec[1], spec[2], spec[3])
	end
	config.SpeedMultiplierMax = math.max(config.SpeedMultiplierMax, config.SpeedMultiplierMin)
	config.MinRank = math.floor(config.MinRank)
	local enabled = get and get("Enabled")
	config.Enabled = enabled ~= false
	return config
end

function CourierRules.Defaults()
	return CourierRules.ReadConfig(nil)
end

-- Parcel labels shown on the pickup prompt / toast (flavour only, chosen by the server).
CourierRules.PARCELS = { "Parts crate", "Hover coil", "Neon tubes", "Food order", "Circuit boards", "Paint cans", "Tyre set", "Mystery box" }

function CourierRules.ParcelName(index)
	local count = #CourierRules.PARCELS
	local i = math.floor(finite(index) or 1)
	return CourierRules.PARCELS[((i - 1) % count) + 1]
end

return CourierRules
