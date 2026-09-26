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

-- Progress
local points = { Vector2.new(0, 0), Vector2.new(100, 0), Vector2.new(100, 100) }
local cumulative = RoadRouting.Cumulative(points)
local segment, point, off, remaining = RoadRouting.Progress(points, cumulative, Vector2.new(100 + 3, 50), 1, 12)
check("progress on second segment", segment == 2 and near(point.X, 100) and near(point.Y, 50) and near(off, 3) and near(remaining, 50))
check("distance format", RoadRouting.FormatDistance(5760 * 0.84, 5760) == "0.8 MI" and RoadRouting.FormatDistance(100, 5760) == "<0.1 MI")

-- Real graph
local roads = RoadRouting.LoadGraph(graphData)
check("real graph loaded", #roads.Nodes > 200 and #roads.Edges > 300, #roads.Nodes .. " nodes, " .. #roads.Edges .. " edges")
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
		end
	end
end
check("routing under 25 ms", slowest < 0.025, string.format("%.1f ms", slowest * 1000))

return { failures = failures, results = results }
