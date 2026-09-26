-- Pure tests for RoadRouting and the generated road graph (Edit; sources loaded over loopback,
-- no game module require, no instances).
local Http = game:GetService("HttpService")
local base = "http://127.0.0.1:8767/route_guide/"
local RoadRouting = assert(loadstring(Http:GetAsync(base .. "RoadRouting.lua")))()
local graphData = assert(loadstring(Http:GetAsync(base .. "RoadGraphData.lua")))()
local results, failures = {}, 0
local function check(name, ok, detail)
	if not ok then failures += 1 end
	table.insert(results, (ok and "PASS " or "FAIL ") .. name .. (detail and (" (" .. detail .. ")") or ""))
end
local function near(a, b, tolerance) return math.abs(a - b) <= (tolerance or 1e-3) end

-- Synthetic square with a bent edge: A(0,0) B(100,0) C(100,100) D(0,100); A-D bends via (-50,50).
local square = RoadRouting.LoadGraph({
	Nodes = { 0, 0, 100, 0, 100, 100, 0, 100 },
	Edges = { 1, 2, 100, 2, 3, 100, 3, 4, 100, 4, 1, 0 },
	Points = { {}, {}, {}, { -50, 50 } },
})
check("edge lengths recomputed from points", near(square.Edges[4].Length, 2 * math.sqrt(50 ^ 2 + 50 ^ 2), 1e-3))
local snap = RoadRouting.Snap(square, Vector2.new(40, -7))
check("snap onto AB", snap.Edge == 1 and near(snap.Point.X, 40) and near(snap.Point.Y, 0) and near(snap.Along, 40) and near(snap.Distance, 7))
local same = RoadRouting.FindRoute(square, Vector2.new(20, 3), Vector2.new(80, -3))
check("same-edge route", same and near(same.Length, 60) and #same.Points == 2, same and tostring(same.Length))
local around = RoadRouting.FindRoute(square, Vector2.new(90, -2), Vector2.new(90, 102))
check("route via B and C", around and near(around.Length, 10 + 100 + 10), around and tostring(around.Length))
check("route starts at snapped start", around and near(around.Points[1].X, 90) and near(around.Points[1].Y, 0))
check("route ends at snapped goal", around and near(around.Points[#around.Points].X, 90) and near(around.Points[#around.Points].Y, 100))
local bent = RoadRouting.FindRoute(square, Vector2.new(-45, 45), Vector2.new(5, 0))
check("bent edge includes interior point", bent and #bent.Points >= 3, bent and tostring(#bent.Points))
local reverse = RoadRouting.FindRoute(square, Vector2.new(90, 102), Vector2.new(90, -2))
check("route is symmetric", reverse and around and near(reverse.Length, around.Length))
-- A junction node that overshoots a fork leaves a short spike; FindRoute drops it.
local fork = RoadRouting.LoadGraph({
	Nodes = { 0, 0, 100, 0, 90, 100 },
	Edges = { 1, 2, 100, 2, 3, 0 },
	Points = { {}, { 90, 5 } },
})
local spiked = RoadRouting.FindRoute(fork, Vector2.new(10, 2), Vector2.new(92, 95))
check("route drops short doubling-back spikes", spiked and #spiked.Points == 3 and near(spiked.Points[2].X, 90) and near(spiked.Points[2].Y, 5)
	and near(spiked.Length, math.sqrt(80 ^ 2 + 5 ^ 2) + 90, 1e-2), spiked and (#spiked.Points .. " pts, " .. string.format("%.2f", spiked.Length)))

-- Progress
local points = { Vector2.new(0, 0), Vector2.new(100, 0), Vector2.new(100, 100) }
local cumulative = RoadRouting.Cumulative(points)
local segment, point, off, remaining = RoadRouting.Progress(points, cumulative, Vector2.new(100 + 3, 50), 1, 12)
check("progress on second segment", segment == 2 and near(point.X, 100) and near(point.Y, 50) and near(off, 3) and near(remaining, 50))
local smooth = RoadRouting.Smooth({ Vector2.new(0, 0), Vector2.new(100, 0), Vector2.new(100, 100) }, 20, 4)
check("smooth keeps endpoints", smooth[1] == Vector2.new(0, 0) and smooth[#smooth] == Vector2.new(100, 100))
check("smooth rounds the corner within radius", #smooth == 7 and near(smooth[2].X, 80) and near(smooth[#smooth - 1].Y, 20))
local straightLine = RoadRouting.Smooth({ Vector2.new(0, 0), Vector2.new(50, 0.5), Vector2.new(100, 0) }, 20, 4)
check("smooth leaves near-straight vertices", #straightLine == 3)
local function maxTurn(list)
	local worst = 0
	for i = 2, #list - 1 do
		local u, v = list[i] - list[i - 1], list[i + 1] - list[i]
		worst = math.max(worst, math.abs(math.deg(math.atan2(u.X * v.Y - u.Y * v.X, u.X * v.X + u.Y * v.Y))))
	end
	return worst
end
-- Dense approach (points every 5 studs): the curve spans the radius along the route and absorbs the
-- points inside it instead of rounding each one.
local dense = {}
for x = 0, 100, 5 do dense[#dense + 1] = Vector2.new(x, 0) end
for y = 5, 100, 5 do dense[#dense + 1] = Vector2.new(100, y) end
local denseSmooth = RoadRouting.Smooth(dense, 20, 4)
check("smooth absorbs dense corner points", #denseSmooth == 37 and near(denseSmooth[17].X, 80) and near(denseSmooth[21].Y, 20)
	and maxTurn(denseSmooth) < 30 and denseSmooth[#denseSmooth] == Vector2.new(100, 100), #denseSmooth .. " pts, " .. string.format("%.1f", maxTurn(denseSmooth)) .. " deg")
local arc = {}
for degrees = 0, 80, 8 do arc[#arc + 1] = Vector2.new(200 * math.cos(math.rad(degrees)), 200 * math.sin(math.rad(degrees))) end
check("smooth leaves sampled arcs alone", #RoadRouting.Smooth(arc, 20, 4) == #arc)
check("distance format", RoadRouting.FormatDistance(5760 * 0.84, 5760) == "0.8 MI" and RoadRouting.FormatDistance(100, 5760) == "<0.1 MI")

-- Real graph
local roads = RoadRouting.LoadGraph(graphData)
check("real graph loaded", #roads.Nodes > 200 and #roads.Edges > 300, #roads.Nodes .. " nodes, " .. #roads.Edges .. " edges")
local straightEdges = 0
for _, edge in ipairs(roads.Edges) do
	if #edge.Points == 2 then straightEdges += 1 end
end
check("graph v2: fitted lines and arcs", graphData.GeneratorVersion == 2 and straightEdges >= #roads.Edges * 0.4,
	straightEdges .. " of " .. #roads.Edges .. " edges are single straight lines")
local places = {
	Dealership = Vector2.new(731, -1747), Garage = Vector2.new(1580, -1841),
	ShowroomLoop = Vector2.new(1380, -1229), WaterfrontSprint = Vector2.new(2199, -1329),
}
for name, where in pairs(places) do
	local s = RoadRouting.Snap(roads, where)
	check(name .. " is near a road", s and s.Distance < 160, s and string.format("%.0f studs", s.Distance))
end
local slowest = 0
for fromName, from in pairs(places) do
	for toName, to in pairs(places) do
		if fromName ~= toName then
			local t0 = os.clock()
			local found = RoadRouting.FindRoute(roads, from, to)
			slowest = math.max(slowest, os.clock() - t0)
			local straight = (to - from).Magnitude
			check(fromName .. " -> " .. toName, found and found.Length >= straight * 0.8 and found.Length <= straight * 4 + 600,
				found and string.format("%.0f road vs %.0f straight, %d pts", found.Length, straight, #found.Points) or "no route")
			-- As drawn: RouteGuide smooths with CornerRadius 50 and 8 steps per right angle.
			local drawn = found and RoadRouting.Smooth(found.Points, 50, 8)
			check(fromName .. " -> " .. toName .. " draws smoothly", drawn and #drawn < 400 and maxTurn(drawn) < 35,
				drawn and string.format("%d pts, max turn %.1f deg", #drawn, maxTurn(drawn)) or "no route")
		end
	end
end
check("routing under 25 ms", slowest < 0.025, string.format("%.1f ms", slowest * 1000))

return { failures = failures, results = results }
