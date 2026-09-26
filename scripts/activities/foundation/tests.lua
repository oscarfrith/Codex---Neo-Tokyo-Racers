-- Pure tests for ProgressionRules (Driver Rank). Loaded over loopback; no game modules, no instances.
local Rules = assert(loadstring(game:GetService("HttpService"):GetAsync("http://127.0.0.1:8767/activities/foundation/ProgressionRules.lua")))()
local results, failures = {}, 0
local function check(name, ok, detail)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end

local s = Rules.Settings()
check("default curve rank 1", Rules.XpForRank(1, s) == 250, Rules.XpForRank(1, s))
check("curve grows", Rules.XpForRank(10, s) > Rules.XpForRank(9, s) and Rules.XpForRank(10, s) == math.floor(250 * 10 ^ 1.35 + 0.5), Rules.XpForRank(10, s))
check("settings clamp bad values", Rules.Settings(function(k) return k == "XpBase" and -5 or (k == "MaxRank" and 0/0) or nil end).XpBase == 1)
check("settings NaN falls back", Rules.Settings(function(k) return k == "MaxRank" and 0/0 or nil end).MaxRank == 100)

local state = Rules.Normalize(nil, s)
check("normalize defaults", state.Rank == 1 and state.Xp == 0 and state.LifetimeXp == 0)
local broken = Rules.Normalize({ Rank = -3, Xp = "x", LifetimeXp = 1e20 }, s)
check("normalize repairs", broken.Rank == 1 and broken.Xp == 0 and broken.LifetimeXp == 1e12)

local reached = Rules.Apply(state, 100, s)
check("xp below threshold", #reached == 0 and state.Xp == 100 and state.Rank == 1 and state.LifetimeXp == 100)
reached = Rules.Apply(state, 150, s)
check("exact threshold ranks up", #reached == 1 and reached[1] == 2 and state.Rank == 2 and state.Xp == 0)
local big = Rules.Normalize({}, s)
reached = Rules.Apply(big, 5000, s)
check("multi rank-up", #reached >= 3 and big.Rank == reached[#reached] + 0 and big.Xp < Rules.XpForRank(big.Rank, s), #reached .. " ranks, rank " .. big.Rank)
check("negative xp ignored", #Rules.Apply(big, -50, s) == 0 and big.LifetimeXp == 5000)

local capped = Rules.Settings(function(k) return k == "MaxRank" and 3 or nil end)
local top = Rules.Normalize({}, capped)
Rules.Apply(top, 1e6, capped)
check("max rank caps and zeroes xp", top.Rank == 3 and top.Xp == 0 and top.LifetimeXp == 1e6)
check("no xp gain past max", #Rules.Apply(top, 500, capped) == 0 and top.Rank == 3 and top.LifetimeXp == 1e6 + 500)

check("rank cash", Rules.RankCash(12, s) == 6000)
local xp, carry = Rules.DriveXp(25, 0, s)
check("drive xp with carry", xp == 2 and math.abs(carry - 0.5) < 1e-9)
xp, carry = Rules.DriveXp(5, carry, s)
check("drive carry completes", xp == 1 and math.abs(carry) < 1e-9)
check("race xp min", Rules.RaceXp(1000, s) == 10)
check("race xp scales", Rules.RaceXp(20000, s) == 40)
check("race xp zero", Rules.RaceXp(0, s) == 0)

return { failures = failures, results = results }
