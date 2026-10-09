--!strict
-- RACE-01 server-side race integrity. Checkpoint touches are server-detected, but vehicle physics is
-- client-owned, so a client can move its car through gates in order. Gates are fixed parts: the straight
-- line between consecutive gates is a lower bound on distance travelled, so for a legitimate run it can
-- never exceed max speed x elapsed (+ gate-size tolerance). Mode (ServerStorage.Config.Racing attributes):
--   Off     - no checks
--   Log     - report violations only
--   Enforce - run still finishes; rewards, personal best and leaderboard are withheld for flagged runs
local ServerStorage = game:GetService("ServerStorage")

local RaceIntegrity = {}
local MPH_TO_STUDS = 1 / 0.625

local function settings(): Instance?
	local config = ServerStorage:FindFirstChild("Config")
	return config and config:FindFirstChild("Racing")
end

local function number(name: string, fallback: number, minimum: number, maximum: number): number
	local folder = settings()
	local value = folder and folder:GetAttribute(name)
	if type(value) ~= "number" or value ~= value then return fallback end
	return math.clamp(value, minimum, maximum)
end

-- The driving caps (Config.Vehicles.Dynamics attributes) bound real speed; the limit never drops below
-- 1.25x the highest of them, so raising vehicle caps cannot create false positives.
local capCache, capCachedAt = 0, -math.huge
local function drivingCapMph(): number
	if os.clock() - capCachedAt < 10 then return capCache end
	capCachedAt = os.clock()
	local highest = 320
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local config = ReplicatedStorage:FindFirstChild("Config")
	local vehicles = config and config:FindFirstChild("Vehicles")
	local dynamics = vehicles and vehicles:FindFirstChild("Dynamics")
	if dynamics then
		for _, folder in ipairs(dynamics:GetChildren()) do
			for _, key in ipairs({ "AbsoluteTopSpeedSafetyMph", "PhysicalTopSpeedMaxMph" }) do
				local value = folder:GetAttribute(key)
				if type(value) == "number" and value == value and value < 5000 then highest = math.max(highest, value) end
			end
		end
	end
	capCache = highest
	return highest
end

function RaceIntegrity.limitMph(): number
	return math.max(number("RaceIntegrityMaxSpeedMph", 400, 50, 2000), 1.25 * drivingCapMph())
end

local FeatureFlags = require(ServerStorage:WaitForChild("Modules"):WaitForChild("Core"):WaitForChild("FeatureFlags"))

-- A valid Creator Dashboard config "RaceIntegrityMode" (Off/Log/Enforce) overrides the attribute, so Enforce
-- can be switched live; any other dashboard value is ignored and the attribute applies.
function RaceIntegrity.mode(): string
	local folder = settings()
	local flag = FeatureFlags.Get("RaceIntegrityMode", nil)
	if flag == "Off" or flag == "Log" or flag == "Enforce" then return flag end
	local value = folder and folder:GetAttribute("RaceIntegrityMode")
	if value == "Log" or value == "Enforce" then return value end
	return "Off"
end

-- Pure check, exported for tests and reuse.
function RaceIntegrity.segmentAllowed(distance: number, elapsed: number, maxStudsPerSecond: number, tolerance: number): boolean
	return distance <= maxStudsPerSecond * math.max(elapsed, 0) + tolerance
end

function RaceIntegrity.begin(subject: any, position: Vector3?, clock: number)
	subject.Integrity = { Position = position, Clock = clock, Size = 0, Violations = 0, Detail = nil }
end

-- Record a gate crossing; returns false when the segment from the previous gate/start is implausible.
function RaceIntegrity.gate(subject: any, gatePart: BasePart, clock: number, label: string): boolean
	local state = subject.Integrity
	if not state or RaceIntegrity.mode() == "Off" then return true end
	local ok = true
	if state.Position then
		local distance = (gatePart.Position - state.Position).Magnitude
		local elapsed = clock - state.Clock
		local maxSpeed = RaceIntegrity.limitMph() * MPH_TO_STUDS
		-- Touches are processed when client-owned physics replicates; bursts/hitches compress measured gaps.
		local jitter = number("RaceIntegrityJitterSeconds", 0.35, 0, 3)
		local tolerance = number("RaceIntegrityToleranceStuds", 24, 0, 500) + 0.5 * (gatePart.Size.Magnitude + state.Size)
		ok = RaceIntegrity.segmentAllowed(distance, elapsed + jitter, maxSpeed, tolerance)
		if not ok then
			state.Violations += 1
			state.Detail = string.format("%s: %.0f studs in %.2fs (%.0f mph avg, limit %.0f mph)", label, distance, elapsed,
				distance / math.max(elapsed, 1e-3) * 0.625, maxSpeed * 0.625)
			warn("[RACE-01] " .. RaceIntegrity.mode() .. " implausible segment " .. state.Detail)
		end
	end
	state.Position = gatePart.Position
	state.Clock = clock
	state.Size = gatePart.Size.Magnitude
	return ok
end

-- True when the run may earn rewards/PB/leaderboard entries.
function RaceIntegrity.accepted(subject: any): boolean
	local state = subject.Integrity
	return RaceIntegrity.mode() ~= "Enforce" or not state or state.Violations == 0
end

return RaceIntegrity
