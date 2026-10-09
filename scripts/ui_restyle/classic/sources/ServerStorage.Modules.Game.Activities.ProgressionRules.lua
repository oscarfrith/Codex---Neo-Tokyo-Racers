-- Pure Driver Rank rules (no game access): XP curve, applying XP, and XP from existing Cash sources.
-- State shape (saved as profile.Progression): { Xp = xp into the current rank, Rank, LifetimeXp }.
local Rules = {}

Rules.Defaults = { XpBase = 250, XpExponent = 1.35, MaxRank = 100, RankCashPerRank = 500, DriveXpPerCash = 0.1, RaceXpDivisor = 500, RaceXpMin = 10 }

local function whole(value, fallback, minimum, maximum)
	value = tonumber(value)
	if value == nil or value ~= value or math.abs(value) == math.huge then value = fallback end
	return math.clamp(math.floor(value), minimum, maximum)
end

function Rules.Settings(read)
	read = read or function() return nil end
	local d = Rules.Defaults
	local function number(key, minimum, maximum)
		local value = tonumber(read(key))
		if value == nil or value ~= value or math.abs(value) == math.huge then value = d[key] end
		return math.clamp(value, minimum, maximum)
	end
	return {
		XpBase = number("XpBase", 1, 1e6),
		XpExponent = number("XpExponent", 0.5, 3),
		MaxRank = math.floor(number("MaxRank", 1, 1000)),
		RankCashPerRank = math.floor(number("RankCashPerRank", 0, 1e6)),
		DriveXpPerCash = number("DriveXpPerCash", 0, 10),
		RaceXpDivisor = number("RaceXpDivisor", 1, 1e6),
		RaceXpMin = math.floor(number("RaceXpMin", 0, 1e5)),
	}
end

-- XP needed to go from `rank` to `rank + 1`.
function Rules.XpForRank(rank, settings)
	settings = settings or Rules.Settings()
	return math.max(1, math.floor(settings.XpBase * math.max(1, rank) ^ settings.XpExponent + 0.5))
end

function Rules.Normalize(state, settings)
	settings = settings or Rules.Settings()
	state = type(state) == "table" and state or {}
	-- Never lower a saved rank if MaxRank is tuned down; ranks at or above MaxRank simply stop gaining XP.
	state.Rank = whole(state.Rank, 1, 1, 1e6)
	state.Xp = whole(state.Xp, 0, 0, 1e9)
	state.LifetimeXp = whole(state.LifetimeXp, 0, 0, 1e12)
	if state.Rank >= settings.MaxRank then state.Xp = 0 end
	return state
end

-- Adds XP in place. Returns the list of ranks reached (empty when no rank-up).
function Rules.Apply(state, amount, settings)
	settings = settings or Rules.Settings()
	Rules.Normalize(state, settings)
	amount = whole(amount, 0, 0, 1e7)
	local reached = {}
	if amount <= 0 then return reached end
	state.LifetimeXp += amount
	if state.Rank >= settings.MaxRank then return reached end
	state.Xp += amount
	while state.Rank < settings.MaxRank do
		local need = Rules.XpForRank(state.Rank, settings)
		if state.Xp < need then break end
		state.Xp -= need
		state.Rank += 1
		table.insert(reached, state.Rank)
	end
	if state.Rank >= settings.MaxRank then state.Xp = 0 end
	return reached
end

function Rules.RankCash(rank, settings)
	settings = settings or Rules.Settings()
	return math.max(0, math.floor(settings.RankCashPerRank * rank))
end

-- XP owed for drive cash, carrying the fractional remainder between grants.
function Rules.DriveXp(cash, carry, settings)
	settings = settings or Rules.Settings()
	local total = (tonumber(carry) or 0) + math.max(0, tonumber(cash) or 0) * settings.DriveXpPerCash
	local xp = math.floor(total)
	return xp, total - xp
end

function Rules.RaceXp(cash, settings)
	settings = settings or Rules.Settings()
	local amount = math.max(0, tonumber(cash) or 0)
	if amount <= 0 then return 0 end
	return math.max(settings.RaceXpMin, math.floor(amount / settings.RaceXpDivisor))
end

return Rules
