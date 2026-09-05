local VehicleStatsCache = {}

local DEFAULTS = {
	TopSpeed = 126,
	Acceleration = 42,
	Braking = 44,
	Handling = 48,
	Drift = 46,
	Boost = 0,
	BoostDuration = 2,
	BoostRecharge = 9,
	Weight = 118,
}

local function readNumber(vehicle, name, fallback)
	if not vehicle then return fallback end
	local attr = vehicle:GetAttribute(name)
	if typeof(attr) == "number" then return attr end
	local statsFolder = vehicle:FindFirstChild("TOTAL_STATS_Runtime")
	local value = statsFolder and statsFolder:FindFirstChild(name)
	if value and value:IsA("NumberValue") then return value.Value end
	return fallback
end

function VehicleStatsCache.Snapshot(vehicle)
	local stats = {}
	for name, fallback in pairs(DEFAULTS) do
		stats[name] = readNumber(vehicle, name, fallback)
	end

	local weight = math.clamp(stats.Weight, 60, 260)
	stats.Weight = weight
	stats.MaxMph = math.clamp(stats.TopSpeed, 40, 260)
	stats.AccelerationWeighted = math.max(stats.Acceleration, 8) * math.clamp(118 / weight, 0.58, 1.25)
	stats.HandlingWeighted = math.max(stats.Handling, 10) * math.clamp(125 / weight, 0.62, 1.22)
	stats.DriftWeighted = math.max(stats.Drift, 10) * math.clamp(122 / weight, 0.65, 1.2)
	stats.BrakingWeighted = math.max(stats.Braking, 16) * math.clamp(115 / weight, 0.68, 1.15)
	stats.BoostPower = math.max(stats.Boost, 0)
	stats.BoostDuration = math.max(stats.BoostDuration, 1)
	stats.BoostRecharge = math.max(stats.BoostRecharge, 4)
	return stats
end

return VehicleStatsCache
