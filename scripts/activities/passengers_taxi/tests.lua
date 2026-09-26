-- Pure tests for TaxiRules (Edit; source loaded over loopback, no game module require, no instances).
local Http = game:GetService("HttpService")
local base = "http://127.0.0.1:8767/activities/passengers_taxi/"
local TaxiRules = assert(loadstring(Http:GetAsync(base .. "TaxiRules.lua")))()
local results, failures = {}, 0
local function check(name, ok, detail)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. detail .. ")") or ""))
end

-- Config resolution: defaults, clamping, non-finite rejection, band ordering.
local config = TaxiRules.ResolveConfig(nil)
check("default fare base", config.FareBase == 1000 and config.FarePerStud == 0.5)
local attrs = { FareBase = 1e9, FarePerStud = 0 / 0, NpcMinStuds = 800, NpcMaxStuds = 300, ImpactMph = "x" }
local tuned = TaxiRules.ResolveConfig(function(key) return attrs[key] end)
check("fare base clamped", tuned.FareBase == 10000, tostring(tuned.FareBase))
check("NaN falls back to default", tuned.FarePerStud == 0.5)
check("non-number falls back", tuned.ImpactMph == 25)
check("npc band kept ordered", tuned.NpcMaxStuds >= tuned.NpcMinStuds + 50, tuned.NpcMinStuds .. "-" .. tuned.NpcMaxStuds)

-- Units.
check("mph conversion", TaxiRules.Mph(16) == 10)
check("mph negative/NaN safe", TaxiRules.Mph(-5) == 0 and TaxiRules.Mph(0 / 0) == 0)
check("flat distance", TaxiRules.Flat(0, 0, 3, 4) == 5)

-- Stop checks.
check("stopped inside radius", TaxiRules.IsStoppedAt(20, 5, 25, 10))
check("too fast to stop", not TaxiRules.IsStoppedAt(20, 12, 25, 10))
check("too far to stop", not TaxiRules.IsStoppedAt(30, 2, 25, 10))
check("NaN distance never stops", not TaxiRules.IsStoppedAt(0 / 0, 0, 25, 10))

-- Impacts.
local samples = { { T = 9.85, Mph = 90 }, { T = 9.95, Mph = 70 } }
check("impact: 90 -> 50 within window", TaxiRules.IsImpact(samples, 10, 50, config))
check("no impact: gentle braking", not TaxiRules.IsImpact(samples, 10, 80, config))
check("no impact: old peak outside window", not TaxiRules.IsImpact({ { T = 9.5, Mph = 120 } }, 10, 40, config))

-- Estimates and stars.
check("estimate", TaxiRules.EstimateSeconds(1600, config) == 40, tostring(TaxiRules.EstimateSeconds(1600, config)))
check("clean fast ride = 5 stars", TaxiRules.Stars(0, 30, 40, config) == 5)
check("two impacts = 3 stars", TaxiRules.Stars(2, 30, 40, config) == 3)
check("slow ride loses 1", TaxiRules.Stars(0, 55, 40, config) == 4)
check("very slow ride loses 2", TaxiRules.Stars(0, 80, 40, config) == 3)
check("stars floor at 1", TaxiRules.Stars(20, 999, 40, config) == 1)
check("stars NaN-safe", TaxiRules.Stars(0 / 0, 0 / 0, 0 / 0, config) >= 1)

-- Fares.
local cash, xp = TaxiRules.Fare(2000, 4, config)
check("4-star fare = base + perStud", cash == 2000 and xp == 130, cash .. " / " .. xp)
local cash5 = TaxiRules.Fare(2000, 5, config)
local cash1 = TaxiRules.Fare(2000, 1, config)
check("stars scale pay", cash5 > cash and cash1 < cash, cash1 .. " < " .. cash .. " < " .. cash5)
local huge = TaxiRules.Fare(1e12, 5, config)
check("fare distance clamped", huge <= math.floor((config.FareBase + config.FarePerStud * config.DestMaxStuds * 4) * 1.15 + 0.5), tostring(huge))
check("fare never negative", (TaxiRules.Fare(-500, 3, config)) >= 0)
check("bad star index safe", (TaxiRules.Fare(1000, 99, config)) > 0 and (TaxiRules.Fare(1000, -3, config)) > 0)

-- Player rides.
check("short ride pays nothing", (TaxiRules.PlayerFare(200, config)) == 0)
local pc = TaxiRules.PlayerFare(1000, config)
check("player fare", pc == 1500, tostring(pc))
check("player fare capped", (TaxiRules.PlayerFare(1e9, config)) == math.floor(config.PlayerFareBase + config.PlayerFarePerStud * config.PlayerFareMaxStuds + 0.5))
local pays, why = TaxiRules.PlayerRidePays(1000, nil, 100, config)
check("first ride pays", pays and why == nil)
pays, why = TaxiRules.PlayerRidePays(1000, 50, 100, config)
check("pair cooldown blocks pay", not pays and why == "PairCooldown")
pays, why = TaxiRules.PlayerRidePays(1000, 50, 50 + config.PairCooldownSeconds + 1, config)
check("pair cooldown expires", pays)
pays, why = TaxiRules.PlayerRidePays(100, nil, 100, config)
check("too short reported", not pays and why == "TooShort")

-- Bands and cooldowns.
local lo, hi = TaxiRules.NpcBand(config)
check("npc band", lo == 300 and hi == 900)
lo, hi = TaxiRules.DestinationBand(config)
check("destination band", lo == 800 and hi == 2500)
check("in band", TaxiRules.InBand(500, 300, 900) and not TaxiRules.InBand(1000, 300, 900) and not TaxiRules.InBand(0 / 0, 0, 1))
check("cooldown remaining", TaxiRules.CooldownRemaining(nil, 10, 20) == 0 and TaxiRules.CooldownRemaining(5, 10, 20) == 15)
check("pair key", TaxiRules.PairKey(1, 2) == "1:2" and TaxiRules.PairKey(2, 1) ~= TaxiRules.PairKey(1, 2))

-- Validation.
check("duty args ok", TaxiRules.ValidateDutyArgs({ OnDuty = true }) == true and TaxiRules.ValidateDutyArgs({ OnDuty = false }) == false)
check("duty args rejected", TaxiRules.ValidateDutyArgs({ OnDuty = "yes" }) == nil and TaxiRules.ValidateDutyArgs(nil) == nil)
check("user id valid", TaxiRules.ValidateUserId(12345) == 12345 and TaxiRules.ValidateUserId("777") == 777)
check("user id rejected", TaxiRules.ValidateUserId(-1) == nil and TaxiRules.ValidateUserId(1.5) == nil
	and TaxiRules.ValidateUserId(0 / 0) == nil and TaxiRules.ValidateUserId(math.huge) == nil and TaxiRules.ValidateUserId({}) == nil)
check("star format", TaxiRules.FormatStars(3) == "3/5 STARS" and TaxiRules.FormatStars(99) == "5/5 STARS")

-- Anti-teleport (server-counted distance).
check("cap step passes normal driving", TaxiRules.CapStep(10, 0.1, 640) == 10)
check("cap step clamps a teleport", TaxiRules.CapStep(2000, 0.1, 640) == 66, tostring(TaxiRules.CapStep(2000, 0.1, 640)))
check("cap step NaN/negative safe", TaxiRules.CapStep(0 / 0, 0.1, 640) == 0 and TaxiRules.CapStep(-5, 0.1, 640) == 0)
check("cap step huge dt bounded", TaxiRules.CapStep(1e6, 1e6, 640) == 642)
check("fare plausible when driven", (TaxiRules.FarePlausible(1500, 2000, 60, 640, config)))
local plausible, reason = TaxiRules.FarePlausible(300, 2000, 60, 640, config)
check("teleport fare rejected (distance)", not plausible and reason == "Distance")
plausible, reason = TaxiRules.FarePlausible(2000, 2000, 1, 640, config)
check("too-fast fare rejected (time)", not plausible and reason == "Time")
check("fare plausible NaN-safe", not (TaxiRules.FarePlausible(0 / 0, 2000, 60, 640, config)))

return { failures = failures, results = results }
