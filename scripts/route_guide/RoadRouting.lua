-- Pure road routing for the free-roam route guide: road-graph loading, snapping,
-- A* shortest route and route progress. No game access, instances or state, so it
-- can be tested by loading the source directly. Positions are world X/Z Vector2s.
local RoadRouting = {}

local SPIKE_STUDS = 120 -- a route vertex that doubles back (turn >= 120 degrees) with a leg shorter than this is dropped
local SPIKE_COSINE = math.cos(math.rad(120))

local function closestOnSegment(point, a, b)
	local ab = b - a
	local lengthSquared = ab:Dot(ab)
	local t = lengthSquared > 0 and math.clamp((point - a):Dot(ab) / lengthSquared, 0, 1) or 0
	local closest = a + ab * t
	return closest, (point - closest).Magnitude, t
end

-- data = { Nodes = {x,z,...}, Edges = {a,b,length,...}, Points = { {x,z,...}, ... } } (1-based node ids)
function RoadRouting.LoadGraph(data)
	assert(type(data) == "table" and type(data.Nodes) == "table" and type(data.Edges) == "table", "Road graph data required")
	local nodes, edges, adjacent = {}, {}, {}
	for i = 1, #data.Nodes, 2 do
		nodes[#nodes + 1] = Vector2.new(data.Nodes[i], data.Nodes[i + 1])
		adjacent[#nodes] = {}
	end
	local points = data.Points or {}
	for k = 1, #data.Edges, 3 do
		local index = #edges + 1
		local a, b = data.Edges[k], data.Edges[k + 1]
		assert(nodes[a] and nodes[b], "Road graph edge references a missing node")
		local polyline = { nodes[a] }
		local interior = points[index] or {}
		for j = 1, #interior, 2 do
			polyline[#polyline + 1] = Vector2.new(interior[j], interior[j + 1])
		end
		polyline[#polyline + 1] = nodes[b]
		local cumulative, length = { 0 }, 0
		for s = 2, #polyline do
			length += (polyline[s] - polyline[s - 1]).Magnitude
			cumulative[s] = length
		end
		edges[index] = { A = a, B = b, Length = length, Points = polyline, Cumulative = cumulative }
		table.insert(adjacent[a], { To = b, Edge = index })
		table.insert(adjacent[b], { To = a, Edge = index })
	end
	return { Nodes = nodes, Edges = edges, Adjacent = adjacent }
end

-- Nearest point on any road. Returns { Edge, Point, Distance, Along } or nil.
function RoadRouting.Snap(graph, point)
	local best
	for index, edge in ipairs(graph.Edges) do
		local polyline, cumulative = edge.Points, edge.Cumulative
		for s = 1, #polyline - 1 do
			local closest, distance, t = closestOnSegment(point, polyline[s], polyline[s + 1])
			if not best or distance < best.Distance then
				best = {
					Edge = index,
					Point = closest,
					Distance = distance,
					Along = cumulative[s] + (cumulative[s + 1] - cumulative[s]) * t,
				}
			end
		end
	end
	return best
end

-- Points of an edge strictly between two along-distances, in travel order.
local function interiorBetween(edge, fromAlong, toAlong)
	local result = {}
	local polyline, cumulative = edge.Points, edge.Cumulative
	if fromAlong <= toAlong then
		for s = 1, #polyline do
			if cumulative[s] > fromAlong and cumulative[s] < toAlong then result[#result + 1] = polyline[s] end
		end
	else
		for s = #polyline, 1, -1 do
			if cumulative[s] < fromAlong and cumulative[s] > toAlong then result[#result + 1] = polyline[s] end
		end
	end
	return result
end

local function heapPush(heap, item)
	heap[#heap + 1] = item
	local i = #heap
	while i > 1 do
		local parent = i // 2
		if heap[parent].Priority <= heap[i].Priority then break end
		heap[parent], heap[i] = heap[i], heap[parent]
		i = parent
	end
end

local function heapPop(heap)
	local top = heap[1]
	local last = table.remove(heap)
	if #heap > 0 then
		heap[1] = last
		local i = 1
		while true do
			local left, right, smallest = i * 2, i * 2 + 1, i
			if left <= #heap and heap[left].Priority < heap[smallest].Priority then smallest = left end
			if right <= #heap and heap[right].Priority < heap[smallest].Priority then smallest = right end
			if smallest == i then break end
			heap[i], heap[smallest] = heap[smallest], heap[i]
			i = smallest
		end
	end
	return top
end

-- Shortest road route between two world X/Z points. Returns { Points = {Vector2}, Length } or nil.
function RoadRouting.FindRoute(graph, fromPoint, toPoint)
	local start, goal = RoadRouting.Snap(graph, fromPoint), RoadRouting.Snap(graph, toPoint)
	if not start or not goal then return nil end
	local startEdge, goalEdge = graph.Edges[start.Edge], graph.Edges[goal.Edge]

	local bestCost, bestPoints = math.huge, nil
	if start.Edge == goal.Edge then
		bestCost = math.abs(goal.Along - start.Along)
		bestPoints = { start.Point }
		for _, p in ipairs(interiorBetween(startEdge, start.Along, goal.Along)) do bestPoints[#bestPoints + 1] = p end
		bestPoints[#bestPoints + 1] = goal.Point
	end

	-- A* from the snapped start (virtual) to the two ends of the goal edge.
	local goalCost = { [goalEdge.A] = goal.Along, [goalEdge.B] = goalEdge.Length - goal.Along }
	local distance, previous, closed, heap = {}, {}, {}, {}
	local function seed(node, cost)
		if cost < (distance[node] or math.huge) then
			distance[node] = cost
			previous[node] = { Start = true }
			heapPush(heap, { Node = node, Priority = cost + (graph.Nodes[node] - goal.Point).Magnitude })
		end
	end
	seed(startEdge.A, start.Along)
	seed(startEdge.B, startEdge.Length - start.Along)
	local bestNode = nil
	while #heap > 0 do
		local item = heapPop(heap)
		-- Priorities are admissible (straight line <= road distance), so nothing left can beat bestCost.
		if item.Priority >= bestCost then break end
		local node = item.Node
		if not closed[node] then
			closed[node] = true
			local base = distance[node]
			local finish = goalCost[node]
			if finish and base + finish < bestCost then
				bestCost, bestNode = base + finish, node
			end
			for _, link in ipairs(graph.Adjacent[node]) do
				local cost = base + graph.Edges[link.Edge].Length
				if cost < (distance[link.To] or math.huge) then
					distance[link.To] = cost
					previous[link.To] = { Node = node, Edge = link.Edge }
					heapPush(heap, { Node = link.To, Priority = cost + (graph.Nodes[link.To] - goal.Point).Magnitude })
				end
			end
		end
	end

	if bestNode then
		-- Walk back to the start, then emit points in travel order.
		local chain, node = {}, bestNode
		while previous[node] and not previous[node].Start do
			table.insert(chain, 1, { From = previous[node].Node, To = node, Edge = previous[node].Edge })
			node = previous[node].Node
		end
		local firstNode = node
		local points = { start.Point }
		local towardA = firstNode == startEdge.A
		for _, p in ipairs(interiorBetween(startEdge, start.Along, towardA and 0 or startEdge.Length)) do points[#points + 1] = p end
		points[#points + 1] = graph.Nodes[firstNode]
		for _, step in ipairs(chain) do
			local edge = graph.Edges[step.Edge]
			local forward = step.From == edge.A
			for _, p in ipairs(interiorBetween(edge, forward and 0 or edge.Length, forward and edge.Length or 0)) do points[#points + 1] = p end
			points[#points + 1] = graph.Nodes[step.To]
		end
		local endAtA = bestNode == goalEdge.A
		for _, p in ipairs(interiorBetween(goalEdge, endAtA and 0 or goalEdge.Length, goal.Along)) do points[#points + 1] = p end
		points[#points + 1] = goal.Point
		bestPoints = points
	end
	if not bestPoints then return nil end

	-- Drop zero-length steps, then short doubling-back spikes (where two roads merge at a shallow
	-- angle the junction node can sit a few studs beyond the fork), and total the length.
	local cleaned = { bestPoints[1] }
	for i = 2, #bestPoints do
		if (bestPoints[i] - cleaned[#cleaned]).Magnitude > 0.05 then cleaned[#cleaned + 1] = bestPoints[i] end
	end
	local i = 2
	while i < #cleaned do
		local incoming, outgoing = cleaned[i] - cleaned[i - 1], cleaned[i + 1] - cleaned[i]
		if math.min(incoming.Magnitude, outgoing.Magnitude) < SPIKE_STUDS and incoming.Unit:Dot(outgoing.Unit) <= SPIKE_COSINE then
			table.remove(cleaned, i)
			i = math.max(2, i - 1)
		else
			i += 1
		end
	end
	local length = 0
	for k = 2, #cleaned do length += (cleaned[k] - cleaned[k - 1]).Magnitude end
	return { Points = cleaned, Length = length, StartOffRoad = start.Distance, GoalOffRoad = goal.Distance }
end

-- Cumulative distances for a route's points (1-based, first = 0).
function RoadRouting.Cumulative(points)
	local cumulative, total = { 0 }, 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
		cumulative[i] = total
	end
	return cumulative
end

-- Progress along a route near a hint segment. Returns segmentIndex, projectedPoint, distanceFromRoute, remaining.
function RoadRouting.Progress(points, cumulative, position, hint, window)
	local first = math.max(1, (hint or 1) - 1)
	local last = math.min(#points - 1, (hint or 1) + (window or 12))
	local bestIndex, bestPoint, bestDistance, bestT
	for s = first, last do
		local closest, distance, t = closestOnSegment(position, points[s], points[s + 1])
		if not bestDistance or distance < bestDistance then
			bestIndex, bestPoint, bestDistance, bestT = s, closest, distance, t
		end
	end
	if not bestIndex then return 1, points[1], (position - points[1]).Magnitude, cumulative[#cumulative] or 0 end
	local travelled = cumulative[bestIndex] + (cumulative[bestIndex + 1] - cumulative[bestIndex]) * bestT
	return bestIndex, bestPoint, bestDistance, math.max(0, cumulative[#cumulative] - travelled)
end

local function turnAngle(a, b, c)
	local u, v = b - a, c - b
	return math.atan2(u.X * v.Y - u.Y * v.X, u.X * v.X + u.Y * v.Y)
end

-- Rounds route corners so they draw as smooth curves. Each vertex that turns by at least
-- minTurnDegrees (default 10) is replaced by a quadratic curve that starts `radius` studs before
-- it and ends `radius` studs after it, measured along the route, so dense approaches (sampled
-- arcs) are absorbed instead of producing extra kinks. The radius shrinks to half the gap to a
-- neighbouring corner and never passes the route ends. `samples` is the number of curve steps
-- for a 90 degree turn (scaled by the turn). Endpoints are kept exactly; gentler vertices (the
-- generator samples arcs in steps of 9 degrees or less) are left untouched.
function RoadRouting.Smooth(points, radius, samples, minTurnDegrees)
	local n = #points
	if n < 3 or (radius or 0) <= 0 then return points end
	samples = math.max(1, samples or 4)
	local minTurn = math.rad(minTurnDegrees or 10)
	local cumulative = RoadRouting.Cumulative(points)
	local corners = {}
	for i = 2, n - 1 do
		if (points[i] - points[i - 1]).Magnitude > 1e-3 and (points[i + 1] - points[i]).Magnitude > 1e-3
			and math.abs(turnAngle(points[i - 1], points[i], points[i + 1])) >= minTurn then
			corners[#corners + 1] = i
		end
	end
	if #corners == 0 then return points end

	local function at(distance)
		distance = math.clamp(distance, 0, cumulative[n])
		local lo, hi = 1, n
		while hi - lo > 1 do
			local mid = (lo + hi) // 2
			if cumulative[mid] <= distance then lo = mid else hi = mid end
		end
		local span = cumulative[hi] - cumulative[lo]
		local t = span > 0 and (distance - cumulative[lo]) / span or 0
		return points[lo]:Lerp(points[hi], t)
	end

	local result = { points[1] }
	local function push(point)
		if (point - result[#result]).Magnitude > 1e-4 then result[#result + 1] = point end
	end
	local cursor, lastEnd = 2, 0
	for k, i in ipairs(corners) do
		local previousCorner = k > 1 and cumulative[corners[k - 1]] or 0
		local nextCorner = k < #corners and cumulative[corners[k + 1]] or cumulative[n]
		local r = math.min(radius,
			(cumulative[i] - previousCorner) * (k > 1 and 0.5 or 1),
			(nextCorner - cumulative[i]) * (k < #corners and 0.5 or 1))
		local start = math.max(cumulative[i] - r, lastEnd)
		if r >= 0.05 and start < cumulative[i] then
			while cursor < n and cumulative[cursor] <= start do
				if cumulative[cursor] > lastEnd + 1e-9 then push(points[cursor]) end
				cursor += 1
			end
			local a, v, b = at(start), points[i], at(cumulative[i] + r)
			local steps = math.max(2, math.ceil(samples * math.abs(turnAngle(a, v, b)) / (math.pi / 2)))
			for s = 0, steps do
				local t = s / steps
				push(a * ((1 - t) * (1 - t)) + v * (2 * (1 - t) * t) + b * (t * t))
			end
			lastEnd = cumulative[i] + r
			while cursor < n and cumulative[cursor] <= lastEnd do cursor += 1 end
		end
	end
	for j = cursor, n do
		if cumulative[j] > lastEnd + 1e-9 or j == n then push(points[j]) end
	end
	if (result[#result] - points[n]).Magnitude <= 1e-4 then result[#result] = points[n] else result[#result + 1] = points[n] end
	return result
end

function RoadRouting.FormatDistance(studs, studsPerMile)
	local miles = math.max(0, studs) / math.max(1, studsPerMile or 5760)
	if miles < 0.1 then return "<0.1 MI" end
	return string.format("%.1f MI", miles)
end

return RoadRouting
