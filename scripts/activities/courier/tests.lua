-- Pure tests for CourierRules (Edit; source loaded over loopback, no game module require, no instances).
-- Serve scripts/ on 127.0.0.1:8767 first.
local Http = game:GetService("HttpService")
local base = "http://127.0.0.1:8767/activities/courier/"
local Rules = assert(loadstring(Http:GetAsync(base .. "CourierRules.lua")))()
local results, failures = {}, 0
local function check(name, ok, detail)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. tostring(detail) .. ")") or ""))
end
local function near(a, b, tolerance) return type(a) == "number" and math.abs(a - b) <= (tolerance or 1e-3) end

local cfg = Rules.Defaults()

-- Config reading and bounds
check("defaults", cfg.BasePay == 1500 and cfg.PayPerStud == 0.6 and cfg.MinDistance == 600 and cfg.MaxDistance == 2000 and cfg.Enabled == true)
local odd = Rules.ReadConfig(function(key)
	if key == "BasePay" then return "abc" end
	if key == "PayPerStud" then return 0 / 0 end
	if key == "ChainMax" then return 1e9 end
	if key == "MinDistance" then return 5000 end
	if key == "MaxDistance" then return 1000 end
	if key == "HubRadius" then return math.huge end
	if key == "Enabled" then return false end
	return nil
end)
check("bad values fall back to defaults", odd.BasePay == 1500 and odd.PayPerStud == 0.6 and odd.HubRadius == 30)
check("values are clamped", odd.ChainMax == 10)
check("max distance kept above min", odd.MaxDistance > odd.MinDistance, odd.MaxDistance)
check("Enabled false honoured", odd.Enabled == false)

-- Variants
check("variant Standard/Hot/Fragile valid", Rules.ValidVariant("Standard") == "Standard" and Rules.ValidVariant("Hot") == "Hot" and Rules.ValidVariant("Fragile") == "Fragile")
check("variant rejects junk", Rules.ValidVariant("hot") == nil and Rules.ValidVariant(5) == nil and Rules.ValidVariant(nil) == nil)

-- Distances and hubs
check("flat distance ignores Y", near(Rules.FlatDistance(Vector3.new(0, 0, 0), Vector3.new(3, 50, 4)), 5))
check("on hub inside radius", Rules.OnHub(Vector3.new(10, 103, 10), Vector3.new(0, 100.6, 0), cfg))
check("off hub outside radius", not Rules.OnHub(Vector3.new(25, 103, 25), Vector3.new(0, 100.6, 0), cfg))
check("off hub far above", not Rules.OnHub(Vector3.new(0, 200, 0), Vector3.new(0, 100.6, 0), cfg))
local hubs = { { Id = "A", Position = Vector3.new(0, 100, 0) }, { Id = "B", Position = Vector3.new(1000, 100, 0) } }
local hub, hubDistance = Rules.NearestHub(hubs, Vector3.new(800, 100, 30))
check("nearest hub", hub and hub.Id == "B" and near(hubDistance, math.sqrt(200 ^ 2 + 30 ^ 2)))
check("nearest hub with none", Rules.NearestHub({}, Vector3.zero) == nil)
check("trip uses routed length", near(Rules.TripDistance(1000, 1300, cfg), 1300))
check("trip falls back to factor", near(Rules.TripDistance(1000, nil, cfg), 1300) and near(Rules.TripDistance(1000, 0 / 0, cfg), 1300))
check("trip never below straight", near(Rules.TripDistance(1000, 500, cfg), 1000))
check("trip capped at 4x straight", near(Rules.TripDistance(1000, 9000, cfg), 4000))

-- Time limits
check("standard time limit", Rules.TimeLimit(1400, "Standard", cfg) == 38, Rules.TimeLimit(1400, "Standard", cfg))
check("hot is tighter", Rules.TimeLimit(3000, "Hot", cfg) == 39 and Rules.TimeLimit(3000, "Standard", cfg) == 52,
	Rules.TimeLimit(3000, "Hot", cfg) .. "/" .. Rules.TimeLimit(3000, "Standard", cfg))
check("time limit min clamp", Rules.TimeLimit(0, "Hot", cfg) == cfg.MinTimeLimit)
check("time limit max clamp", Rules.TimeLimit(1e6, "Standard", cfg) == cfg.MaxTimeLimit)

-- Pay, XP, stars
check("standard pay with half time left", near(Rules.Pay(1000, 20, 40, "Standard", 0, 1, cfg), 2415, 1), Rules.Pay(1000, 20, 40, "Standard", 0, 1, cfg))
check("no time left means no bonus", near(Rules.Pay(1000, 0, 40, "Standard", 0, 1, cfg), 2100, 1))
check("time bonus capped at +30%", near(Rules.Pay(1000, 99, 40, "Standard", 0, 1, cfg), 2730, 1))
check("hot pays x1.4", near(Rules.Pay(1000, 20, 40, "Hot", 0, 1, cfg), 3381, 1))
check("fragile clean pays x1.25", near(Rules.Pay(1000, 20, 40, "Fragile", 0, 1, cfg), 3019, 1))
check("fragile loses 15% per impact", near(Rules.Pay(1000, 20, 40, "Fragile", 2, 1, cfg), 2113, 1))
check("fragile floor 40%", near(Rules.Pay(1000, 20, 40, "Fragile", 10, 1, cfg), 1208, 1))
check("impacts ignored for standard", Rules.Pay(1000, 20, 40, "Standard", 5, 1, cfg) == Rules.Pay(1000, 20, 40, "Standard", 0, 1, cfg))
check("chain multiplies pay", near(Rules.Pay(1000, 20, 40, "Standard", 0, 1.5, cfg), 3623, 1))
check("xp 20 + distance/100", Rules.Xp(1000, cfg) == 30 and Rules.Xp(1550, cfg) == 35 and Rules.Xp(0, cfg) == 20)
check("stars 3/2/1/0", Rules.Stars(20, 40, cfg) == 3 and Rules.Stars(15, 40, cfg) == 2 and Rules.Stars(5, 40, cfg) == 1 and Rules.Stars(-1, 40, cfg) == 0)

-- Chain
check("first run chain 1", Rules.ChainForStart(nil, nil, 10, cfg) == 1)
check("chain steps +0.1 in window", near(Rules.ChainForStart(1, 100, 150, cfg), 1.1))
check("chain capped at 1.5", near(Rules.ChainForStart(1.5, 100, 150, cfg), 1.5) and near(Rules.ChainForStart(1.45, 100, 150, cfg), 1.5))
check("chain resets after window", Rules.ChainForStart(1.2, 100, 191, cfg) == 1)

-- Delivery and plausibility
check("delivered inside radius and slow", Rules.Delivered(39, 24, cfg))
check("not delivered outside radius", not Rules.Delivered(41, 10, cfg))
check("not delivered while fast", not Rules.Delivered(10, 25, cfg))
check("limit uses race integrity limit when valid", Rules.LimitMph(500, cfg) == 500)
check("limit falls back to MaxPlausibleMph", Rules.LimitMph(nil, cfg) == 400 and Rules.LimitMph(0 / 0, cfg) == 400 and Rules.LimitMph(10, cfg) == 400)
check("implausible time rejected", not Rules.PlausibleTime(640, 0.99, 400))
check("plausible time accepted", Rules.PlausibleTime(640, 1, 400))
check("segment allowed within limit + small tolerance", Rules.SegmentAllowed(660, 1, 400, cfg))
check("segment teleport rejected", not Rules.SegmentAllowed(700, 1, 400, cfg))

-- Fragile impacts
local samples = {}
check("impact: first sample never counts", not Rules.RecordSpeed(samples, 0, 100, nil, cfg))
check("impact: small drop ignored", not Rules.RecordSpeed(samples, 0.1, 90, nil, cfg))
check("impact: 60 mph drop within 0.2 s counts", Rules.RecordSpeed(samples, 0.2, 40, nil, cfg))
check("impact: cooldown blocks double count", not Rules.RecordSpeed(samples, 0.3, 0, 0.2, cfg))
check("impact: old samples pruned", #samples <= 3, #samples)
local braking = {}
Rules.RecordSpeed(braking, 0, 100, nil, cfg)
Rules.RecordSpeed(braking, 0.1, 80, nil, cfg)
local b1 = Rules.RecordSpeed(braking, 0.2, 60, nil, cfg)
local b2 = Rules.RecordSpeed(braking, 0.3, 40, nil, cfg)
check("impact: steady braking is not an impact", not b1 and not b2)
local slow = {}
Rules.RecordSpeed(slow, 0, 100, nil, cfg)
check("impact: drop over longer than window ignored", not Rules.RecordSpeed(slow, 0.5, 0, nil, cfg))

-- Settle
local run = { Distance = 1000, Straight = 800, TimeLimit = 40, Variant = "Standard", Impacts = 0, Chain = 1 }
local good = Rules.Settle(run, 20, cfg)
check("settle ok", good.Ok and near(good.Cash, 2415, 1) and good.Xp == 30 and good.Stars == 3, good.Cash)
local late = Rules.Settle(run, 41, cfg)
check("settle late fails", not late.Ok and late.Reason == "Out of time" and late.Cash == 0)
local fast = Rules.Settle(run, 0.5, cfg)
check("settle implausible fails", not fast.Ok and fast.Cash == 0 and string.find(fast.Reason, "implausible") ~= nil)
local routed = Rules.Settle({ Distance = 1300, Straight = 800, TimeLimit = 40, Variant = "Standard", Impacts = 0, Chain = 1, LimitMph = 400 }, 1.5, cfg)
check("settle minimum time uses routed distance", not routed.Ok and routed.Cash == 0)
local limited = Rules.Settle({ Distance = 1300, Straight = 800, TimeLimit = 40, Variant = "Standard", Impacts = 0, Chain = 1, LimitMph = 1000 }, 1.5, cfg)
check("settle honours run LimitMph", limited.Ok)
local flagged = Rules.Settle({ Distance = 1000, Straight = 800, TimeLimit = 40, Variant = "Hot", Impacts = 0, Chain = 1, Invalid = "implausible movement" }, 20, cfg)
check("settle invalid run fails", not flagged.Ok and flagged.Cash == 0 and flagged.Xp == 0)

return { failures = failures, results = results }
