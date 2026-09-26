-- Pure tests for the world jobs rules (JobRules, TaxiRules, CourierRules). Studio Edit; sources are loaded
-- over loopback (no game module require, no instances). Serve scripts/ on 127.0.0.1:8767 first.
local Http = game:GetService("HttpService")
local base = "http://127.0.0.1:8767/"
local function load(path) return assert(loadstring(Http:GetAsync(base .. path), path))() end
local Rules = load("activities/world_jobs/JobRules.lua")
local Taxi = load("activities/world_jobs/TaxiRules.lua")
local Courier = load("activities/world_jobs/CourierRules.lua")
local RoadRouting = load("route_guide/RoadRouting.lua")

local results, failures = {}, 0
local function check(name, ok, detail)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" (" .. tostring(detail) .. ")") or ""))
end
local function near(a, b, tolerance) return type(a) == "number" and math.abs(a - b) <= (tolerance or 1e-3) end
local function nearV(a, b, tolerance) return a ~= nil and (a - b).Magnitude <= (tolerance or 1e-3) end

-- Config -----------------------------------------------------------------------------------------------
local board = Rules.ReadBoardConfig(nil)
check("board defaults", board.TaxiOffers == 6 and board.CourierOffers == 5 and board.KerbOffset == 48
	and board.TripMinStuds == 1800 and board.TripMaxStuds == 4500 and board.StreamRadius == 600 and board.Enabled == true)
local odd = Rules.ReadBoardConfig(function(key)
	if key == "TripMaxStuds" then return 100 end
	if key == "KerbOffset" then return 0 / 0 end
	if key == "TaxiOffers" then return 1e9 end
	if key == "OfferTtlMin" then return 900 end
	if key == "OfferTtlMax" then return 60 end
	if key == "StreamRadius" then return "abc" end
	if key == "Enabled" then return false end
	return nil
end)
check("board bad values fall back", odd.KerbOffset == 48 and odd.StreamRadius == 600)
check("board values clamped", odd.TaxiOffers == 20)
check("board trip band kept ordered", odd.TripMaxStuds >= odd.TripMinStuds + 100, odd.TripMaxStuds)
check("board ttl kept ordered", odd.OfferTtlMax >= odd.OfferTtlMin)
check("board Enabled false honoured", odd.Enabled == false)

local taxi = Taxi.Defaults()
check("taxi defaults", taxi.TripBasePay == 200 and near(taxi.TripPayPerStud, 0.11) and taxi.Enabled and taxi.HailAnimationId == "" and taxi.MinRank == 1)
local taxiOdd = Taxi.ReadConfig(function(key)
	if key == "SpeedMultiplierMin" then return 0.9 end
	if key == "SpeedMultiplierMax" then return 0.5 end
	if key == "Enabled" then return false end
	if key == "HailAnimationId" then return "rbxassetid://1" end
	if key == "CrashPenalty" then return -3 end
	return nil
end)
check("taxi multiplier bounds ordered", taxiOdd.SpeedMultiplierMax >= taxiOdd.SpeedMultiplierMin, taxiOdd.SpeedMultiplierMax)
check("taxi clamps and flags", taxiOdd.CrashPenalty == 0 and taxiOdd.Enabled == false and taxiOdd.HailAnimationId == "rbxassetid://1")
local courier = Courier.Defaults()
check("courier defaults", courier.TripBasePay == 150 and near(courier.TripPayPerStud, 0.1) and courier.Enabled and courier.CrashPenalty == 0.15)
check("courier has no variants or hubs", Courier.VARIANTS == nil and Courier.Tunables.HubRadius == nil and Courier.Tunables.HotPayMultiplier == nil)
check("courier parcel names wrap", Courier.ParcelName(1) == Courier.PARCELS[1] and Courier.ParcelName(#Courier.PARCELS + 1) == Courier.PARCELS[1])
check("kind reasons", Taxi.REASON == "TaxiFare" and Courier.REASON == "JobPayout")

-- Geometry ---------------------------------------------------------------------------------------------
local poly = { Vector2.new(0, 0), Vector2.new(100, 0), Vector2.new(100, 100) }
local cum = { 0, 100, 200 }
local p, t = Rules.PointAlong(poly, cum, 50)
check("point along first segment", nearV(p, Vector2.new(50, 0)) and nearV(t, Vector2.new(1, 0)))
p, t = Rules.PointAlong(poly, cum, 150)
check("point along second segment", nearV(p, Vector2.new(100, 50)) and nearV(t, Vector2.new(0, 1)))
check("point along clamps", nearV((Rules.PointAlong(poly, cum, -5)), Vector2.new(0, 0)) and nearV((Rules.PointAlong(poly, cum, 999)), Vector2.new(100, 100)))
local jag = { Vector2.new(0, 0), Vector2.new(10, 3), Vector2.new(20, -3), Vector2.new(30, 3), Vector2.new(40, 0) }
check("smooth tangent ignores pixel jags", RoadRouting.Cumulative and (function()
	local tangent = Rules.SmoothTangent(jag, RoadRouting.Cumulative(jag), 20, 18)
	return tangent.X > 0.99
end)())
check("normal sides", nearV(Rules.Normal(Vector2.new(1, 0), 1), Vector2.new(0, 1)) and nearV(Rules.Normal(Vector2.new(1, 0), -1), Vector2.new(0, -1)))
check("kerb point offset", nearV(Rules.KerbPoint(Vector2.new(10, 10), Vector2.new(0, 1), 1, 48), Vector2.new(-38, 10)))
check("flat distance mixes Vector2/Vector3", near(Rules.Flat(Vector3.new(0, 50, 0), Vector2.new(3, 4)), 5) and near(Rules.Flat(Vector3.new(3, 0, 4), Vector3.new(0, 99, 0)), 5))

-- Synthetic 3x3 grid road graph, 1000-stud blocks (node id = row * 3 + col + 1, position = (col, row) * 1000).
local data = { Nodes = {}, Edges = {}, Points = {} }
for row = 0, 2 do
	for col = 0, 2 do
		table.insert(data.Nodes, col * 1000)
		table.insert(data.Nodes, row * 1000)
	end
end
local function id(row, col) return row * 3 + col + 1 end
for row = 0, 2 do
	for col = 0, 2 do
		if col < 2 then for _, v in ipairs({ id(row, col), id(row, col + 1), 1000 }) do table.insert(data.Edges, v) end; table.insert(data.Points, {}) end
		if row < 2 then for _, v in ipairs({ id(row, col), id(row + 1, col), 1000 }) do table.insert(data.Edges, v) end; table.insert(data.Points, {}) end
	end
end
local graph = RoadRouting.LoadGraph(data)
local function edgeBetween(a, b)
	for index, edge in ipairs(graph.Edges) do
		if (edge.A == a and edge.B == b) or (edge.A == b and edge.B == a) then return index, edge end
	end
end
local edges = Rules.BuildEdgeTable(graph, 90, nil)
check("edge table weights usable length", #edges.Items == 12 and near(edges.Total, 12 * 820), edges.Total)
local bounded = Rules.BuildEdgeTable(graph, 90, { MinX = -10, MaxX = 1500, MinZ = -10, MaxZ = 2500 })
check("edge table respects bounds", #bounded.Items == 10, #bounded.Items)
local tooShort = Rules.BuildEdgeTable(graph, 600, nil)
check("edge table skips short edges", #tooShort.Items == 0 and tooShort.Total == 0)
local e1, a1 = Rules.SampleEdge(edges, 0, 0)
local e2, a2 = Rules.SampleEdge(edges, 0.99999, 1)
check("sample edge first/last", e1 == edges.Items[1].Edge and near(a1, 90) and e2 == edges.Items[#edges.Items].Edge and near(a2, 910))
check("sample edge empty table", Rules.SampleEdge(tooShort, 0.5, 0.5) == nil)

-- Kerb detection
local function s(offset, hit, road, rise) return { Offset = offset, Hit = hit, IsRoad = road, Rise = rise or false } end
local k, how = Rules.FindKerb({ s(26, true, true), s(30, true, true), s(34, true, false, true) }, board, false)
check("kerb at first rise", k == 34 + board.PavementMargin and how == "Kerb", k)
k = Rules.FindKerb({ s(26, true, true), s(30, true, false), s(34, true, true), s(38, true, false), s(42, true, false) }, board, false)
check("lane marking skipped, persistent change is the kerb", k == 38 + board.PavementMargin, k)
k = Rules.FindKerb({ s(26, true, true), s(30, true, false) }, board, false)
check("last sample change accepted", k == 30 + board.PavementMargin, k)
k, how = Rules.FindKerb({ s(26, true, true), s(30, false, false) }, board, true)
check("void rejects", k == nil and how == "Void")
k, how = Rules.FindKerb({ s(26, true, true), s(30, true, true) }, board, false)
check("all road rejects without fallback", k == nil and how == "NoKerb")
k, how = Rules.FindKerb({ s(26, true, true), s(30, true, true) }, board, true)
check("all road uses fallback when relaxed", k == board.KerbOffset and how == "Fallback")

check("ground ok", (Rules.GroundOk({ Hit = true, Y = 101.4, NormalY = 1, Water = false, Collides = true }, 100.6, board)))
check("ground water/slope/height/solid/none rejected",
	not Rules.GroundOk({ Hit = true, Y = 101, NormalY = 1, Water = true }, 101, board)
	and not Rules.GroundOk({ Hit = true, Y = 101, NormalY = 0.4 }, 101, board)
	and not Rules.GroundOk({ Hit = true, Y = 140, NormalY = 1 }, 101, board)
	and not Rules.GroundOk({ Hit = true, Y = 101, NormalY = 1, Collides = false }, 101, board)
	and not Rules.GroundOk(nil, 101, board))
-- Pavement only: the real place has road parts at Y 100.5, pavements at Y 101, bare baseplate at Y 100 and bush walls / dividers higher.
check("pavement accepted", (Rules.GroundOk({ Hit = true, Y = 101, NormalY = 1, Collides = true }, 100.5, board)))
check("baseplate below road rejected", not Rules.GroundOk({ Hit = true, Y = 100, NormalY = 1, Collides = true }, 100.5, board))
check("road-level surface rejected", not Rules.GroundOk({ Hit = true, Y = 100.52, NormalY = 1, Collides = true }, 100.5, board))
check("divider / planter rejected", not Rules.GroundOk({ Hit = true, Y = 104.7, NormalY = 1, Collides = true }, 100.5, board))
check("foliage surface rejected", not Rules.GroundOk({ Hit = true, Y = 101.33, NormalY = 1, Collides = true, Surface = false }, 100.5, board))
check("kerb spot must be off other roads", not Rules.OffOtherRoads(40, 55) and Rules.OffOtherRoads(50, 55))

-- Spacing and freshness
local area = { MinX = 0, MaxX = 3000, MinZ = 0, MaxZ = 4000 }
local ctx = { Offers = { Vector3.new(500, 101, 500) }, Players = { Vector3.new(2000, 101, 2000) }, Recent = { Vector3.new(1000, 101, 3000) }, Bounds = area }
check("spot too near another offer", select(2, Rules.SpotAllowed(Vector2.new(700, 500), ctx, board, 0)) == "Offer")
check("relaxed spacing allows it", (Rules.SpotAllowed(Vector2.new(700, 500), ctx, board, 2)))
check("spot too near a player", select(2, Rules.SpotAllowed(Vector2.new(2100, 2000), ctx, board, 0)) == "Player")
check("relax 2 ignores players and freshness", (Rules.SpotAllowed(Vector2.new(2100, 2000), ctx, board, 2)) and (Rules.SpotAllowed(Vector2.new(1000, 3100), ctx, board, 2)))
check("spot at a recently used place", select(2, Rules.SpotAllowed(Vector2.new(1000, 3100), ctx, board, 0)) == "Recent")
check("spot outside the district", select(2, Rules.SpotAllowed(Vector2.new(-50, 100), ctx, board, 0)) == "Bounds")
check("clear spot allowed", (Rules.SpotAllowed(Vector2.new(2500, 500), ctx, board, 0)))
local ring = {}
for i = 1, 5 do Rules.Remember(ring, i, 3) end
check("remember trims oldest", #ring == 3 and ring[1] == 3 and ring[3] == 5)
check("sectors", Rules.SectorOf(Vector2.new(0, 0), area, 3, 4) == 1 and Rules.SectorOf(Vector2.new(2999, 3999), area, 3, 4) == 12
	and Rules.SectorOf(Vector2.new(-500, 99999), area, 3, 4) == 10)
check("pickup prefers emptier sectors", Rules.ScorePickup(Vector2.new(100, 100), { [1] = 3 }, area, board, 0) < Rules.ScorePickup(Vector2.new(2900, 100), { [1] = 3 }, area, board, 0))

-- Road distances
local startEdge = edgeBetween(id(0, 0), id(0, 1))
local startAlong = graph.Edges[startEdge].A == id(0, 0) and 0 or 1000
local dist = Rules.RoadDistances(graph, startEdge, startAlong)
check("dijkstra node distances", near(dist[id(0, 0)], 0) and near(dist[id(0, 1)], 1000) and near(dist[id(2, 2)], 4000), dist[id(2, 2)])
local goalEdge, goal = edgeBetween(id(2, 1), id(2, 2))
local road = Rules.RoadDistanceTo(graph, dist, startEdge, startAlong, goalEdge, 500)
local routed = RoadRouting.FindRoute(graph, Vector2.new(0, 0), Vector2.new(goal.A == id(2, 1) and 1500 or 1500, 2000))
check("road distance to an edge point", near(road, 3500), road)
check("matches RoadRouting.FindRoute", routed and near(routed.Length, road, 0.5), routed and routed.Length)
check("same-edge distance", near(Rules.RoadDistanceTo(graph, dist, startEdge, 100, startEdge, 600), 500))

-- Destinations
check("trip band and target", Rules.TripBand(board, 0) == 1800 and select(2, Rules.TripBand(board, 1)) == 4500 * 1.3 and near(Rules.TargetLength(board, 0.5), 3150))
check("angle wraps", near(Rules.AngleBetween(0.1, 2 * math.pi - 0.1), 0.2, 1e-6))
local pickup = Vector3.new(0, 101, 0)
local dctx = { Pickup = pickup, TargetLength = 3000, Band = { 1800, 4500 }, RecentTrips = {}, RecentDrops = {}, SectorCounts = {}, Bounds = { MinX = -5000, MaxX = 5000, MinZ = -5000, MaxZ = 5000 } }
check("destination outside band rejected", Rules.ScoreDestination({ Point = Vector2.new(1000, 0), Road = 1000 }, dctx, board) == nil
	and Rules.ScoreDestination({ Point = Vector2.new(4000, 4000), Road = 9000 }, dctx, board) == nil)
local close = Rules.ScoreDestination({ Point = Vector2.new(3000, 0), Road = 3000 }, dctx, board)
local far = Rules.ScoreDestination({ Point = Vector2.new(4400, 0), Road = 4400 }, dctx, board)
check("destination near target length preferred", close and far and close > far)
dctx.RecentTrips = { { Pickup = Vector3.new(0, 101, 0), Drop = Vector3.new(3000, 101, 0) } }
check("near-duplicate trip rejected", Rules.ScoreDestination({ Point = Vector2.new(3100, 50), Road = 3100 }, dctx, board) == nil)
dctx.RecentTrips = { { Pickup = Vector3.new(-2000, 101, 0), Drop = Vector3.new(1000, 101, 0) } }
local sameWay = Rules.ScoreDestination({ Point = Vector2.new(3000, 0), Road = 3000 }, dctx, board)
local otherWay = Rules.ScoreDestination({ Point = Vector2.new(0, 3000), Road = 3000 }, dctx, board)
check("new directions preferred", sameWay and otherWay and otherWay > sameWay, tostring(sameWay) .. "/" .. tostring(otherWay))
dctx.RecentTrips = {}
dctx.RecentDrops = { Vector3.new(0, 101, 3000) }
local fresh = Rules.ScoreDestination({ Point = Vector2.new(3000, 0), Road = 3000 }, dctx, board)
local stale = Rules.ScoreDestination({ Point = Vector2.new(0, 3000), Road = 3000 }, dctx, board)
check("recent drop area penalised", fresh and stale and fresh > stale)
check("destination outside district rejected", Rules.ScoreDestination({ Point = Vector2.new(9000, 0), Road = 3000 }, dctx, board) == nil)

-- Expiry
check("offer kept before expiry", Rules.ExpiryDecision(10, 20, 0, 5000, board) == "Keep")
check("offer extended when a player closes in", Rules.ExpiryDecision(30, 20, 0, 100, board) == "Extend")
check("offer expires after max extensions", Rules.ExpiryDecision(30, 20, board.MaxExtensions, 100, board) == "Expire")
check("offer expires when nobody is near", Rules.ExpiryDecision(30, 20, 0, 5000, board) == "Expire")

-- Accept / arrive / crash / anti-teleport
check("accept at the kerb slowly", (Rules.CanAcceptAt(30, 4, 10, board)))
check("accept too far", select(2, Rules.CanAcceptAt(90, 4, 5, board)) == "Pull up closer to the kerb.")
check("accept too high", not Rules.CanAcceptAt(20, 80, 5, board))
check("accept too fast", select(2, Rules.CanAcceptAt(20, 2, 40, board)) == "Slow down to pick up.")
check("arrived", Rules.Arrived(40, 10, taxi) and not Rules.Arrived(80, 5, taxi) and not Rules.Arrived(20, 30, taxi))
check("impact on a hard stop", Rules.IsImpact({ { T = 0, Mph = 100 }, { T = 0.1, Mph = 90 } }, 0.2, 40, taxi))
check("no impact when braking", not Rules.IsImpact({ { T = 0, Mph = 100 }, { T = 0.1, Mph = 90 } }, 0.2, 80, taxi))
check("no impact from an old peak", not Rules.IsImpact({ { T = 0, Mph = 100 } }, 1.0, 10, taxi))
check("cap step limits teleports", near(Rules.CapStep(1000, 0.1, 200), 22) and near(Rules.CapStep(5, 0.1, 200), 5) and near(Rules.CapStep(99999, 60, 200), 202))
check("speed limit selection", Rules.LimitMph(nil, taxi) == 400 and Rules.LimitMph(375, taxi) == 375 and Rules.LimitMph(10, taxi) == 400)
check("plausible trip", (Rules.Plausible(2900, 3000, 2500, 30, 600, taxi)))
check("not driven", select(2, Rules.Plausible(1000, 3000, 2500, 30, 600, taxi)) == "Distance")
check("too fast", select(2, Rules.Plausible(2900, 3000, 2500, 2, 600, taxi)) == "Time")
check("straight distance floor", not Rules.Plausible(1900, 1000, 3500, 30, 600, taxi))

-- Pay
local distance = 3000
local reference = Rules.ReferenceSeconds(distance, taxi)
check("reference seconds", near(reference, 3000 / (85 / 0.625) + 10, 1e-6), reference)
local par = Rules.Pay(taxi, distance, reference, 0)
check("par pay", par.Total == 530 and par.Base == 530 and par.SpeedBonus == 0 and par.CrashPenalty == 0 and near(par.SpeedMultiplier, 1), par.Total)
check("xp", par.Xp == 50, par.Xp)
local fast = Rules.Pay(taxi, distance, reference / 2, 0)
check("fast pays more, capped at max", fast.Total == 795 and fast.SpeedBonus == 265 and near(fast.SpeedMultiplier, 1.5), fast.Total)
local slow = Rules.Pay(taxi, distance, reference * 3, 0)
check("slow pays less, floored at min", slow.Total == 318 and slow.SpeedBonus == -212, slow.Total)
local crashed = Rules.Pay(taxi, distance, reference, 2)
check("crashes cost", crashed.Total == 403 and crashed.CrashPenalty == 127 and near(crashed.DamageFactor, 0.76), crashed.Total)
check("crash floor", Rules.Pay(taxi, distance, reference, 50).Total == 212)
check("breakdown adds up", fast.Base + fast.SpeedBonus - fast.CrashPenalty == fast.Total and crashed.Base + crashed.SpeedBonus - crashed.CrashPenalty == crashed.Total)
check("projected pay at arrival equals pay", Rules.ProjectedPay(taxi, distance, 20, 0, 1) == Rules.Pay(taxi, distance, 20, 1).Total)
check("projected pay drops when slow", Rules.ProjectedPay(taxi, distance, 20, 2000, 0) < Rules.ProjectedPay(taxi, distance, 20, 100, 0))
local settled = Rules.Settle({ Distance = 3000, Straight = 2400, Driven = 3100, Crashes = 0 }, reference, 600, taxi)
check("settle pays", settled.Ok and settled.Cash == 530 and settled.Xp == 50)
local rejected = Rules.Settle({ Distance = 3000, Straight = 2400, Driven = 200, Crashes = 0 }, reference, 600, taxi)
check("settle rejects undriven trips", not rejected.Ok and rejected.Cash == 0)
local snap = Rules.SafeSnapshot(Rules.PaySnapshot(taxi))
check("snapshot round trip", Rules.Pay(snap, distance, reference, 1).Total == Rules.Pay(taxi, distance, reference, 1).Total)
check("safe snapshot of junk", Rules.Pay(Rules.SafeSnapshot({ TripBasePay = "x" }), 1000, 10, 0).Total == 0)
check("abandon time", near(Rules.AbandonSeconds(30, board), 30 * 4 + 120))

-- Economy: 60 jobs/h at a 1.25x pace on the mean trip lands inside the ~$30-45k/h target (ceiling 40k).
local mean = (board.TripMinStuds + board.TripMaxStuds) / 2
local function hourly(cfg)
	local ref = Rules.ReferenceSeconds(mean, cfg)
	return Rules.Pay(cfg, mean, ref / 1.34, 0).Total * 60
end
check("taxi hourly in target", hourly(taxi) >= 30000 and hourly(taxi) <= 45000, hourly(taxi))
check("courier hourly in target", hourly(courier) >= 30000 and hourly(courier) <= 45000, hourly(courier))

-- Taxi boarding helpers
check("boarding point beside seat", nearV(Taxi.BoardingPoint(Vector3.new(0, 0, 0), Vector3.new(1, 0, 0), 6), Vector3.new(-6, 0, 0)))
check("boarding done when close or timed out", Taxi.BoardingDone(5, 0, taxi) and Taxi.BoardingDone(30, 3, taxi) and not Taxi.BoardingDone(30, 1, taxi))

-- Formatting and ids
check("money", Rules.Money(1234) == "$1,234" and Rules.Money(-212) == "-$212" and Rules.Money(0) == "$0" and Rules.Money(1234567) == "$1,234,567" and Rules.Money(999) == "$999")
check("clock and miles", Rules.Clock(83) == "1:23" and Rules.Miles(5760) == "1.0 MI" and Rules.Miles(10) == "<0.1 MI")
check("offer ids", Rules.ValidOfferId("Fare_12_ab12cd34") and not Rules.ValidOfferId("../x") and not Rules.ValidOfferId(string.rep("a", 81)) and not Rules.ValidOfferId(5))

return { failures = failures, results = results }
