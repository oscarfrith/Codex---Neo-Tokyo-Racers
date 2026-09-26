-- Pure road routing for the free-roam route guide: road-graph loading, snapping,
-- A* shortest route and route progress. No game access, instances or state, so it
-- can be tested by loading the source directly. Positions are world X/Z Vector2s.
local RoadRouting = {}

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

	-- Drop zero-length steps and total the length.
	local cleaned, length = { bestPoints[1] }, 0
	for i = 2, #bestPoints do
		local step = (bestPoints[i] - cleaned[#cleaned]).Magnitude
		if step > 0.05 then
			cleaned[#cleaned + 1] = bestPoints[i]
			length += step
		end
	end
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

function RoadRouting.FormatDistance(studs, studsPerMile)
	local miles = math.max(0, studs) / math.max(1, studsPerMile or 5760)
	if miles < 0.1 then return "<0.1 MI" end
	return string.format("%.1f MI", miles)
end

return RoadRouting
