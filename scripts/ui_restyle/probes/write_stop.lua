-- UI restyle probe: write_stop (datamodel: Client, Play). READ-ONLY.
-- Disconnects the session opened by write_start.lua and returns its counters.
-- See write_start.lua for what is and is not counted.
local ARGS = {
	top = 15,        -- instance paths in the top list
	detail = false,  -- true = longer lists (top 40 paths, all classes, all properties)
}

local HttpService = game:GetService("HttpService")

local store = shared.UIRestyleProbe
if type(store) ~= "table" then
	store = _G.UIRestyleProbe
end
local state = type(store) == "table" and store.write or nil
if not state then
	return HttpService:JSONEncode({
		probe = "write_stop", ok = false, error = "no_session",
		hint = "write_start did not run in this datamodel, or shared/_G did not persist between calls; use write_probe.lua (blocking) instead",
	})
end

local seconds = os.clock() - state.t0
for _, connection in ipairs(state.conns) do
	connection:Disconnect()
end
store.write = nil

local function topOf(map, limit)
	local list = {}
	for key, count in pairs(map) do
		table.insert(list, { key, count })
	end
	table.sort(list, function(a, b)
		if a[2] == b[2] then
			return tostring(a[1]) < tostring(b[1])
		end
		return a[2] > b[2]
	end)
	local out = {}
	for index = 1, math.min(limit, #list) do
		out[index] = list[index]
	end
	return out, #list
end

local samples = {}
local dirtyFrames = 0
local maxPerFrame = 0
for index = 1, #state.perFrame do
	local value = state.perFrame[index]
	samples[index] = value
	if value > 0 then
		dirtyFrames += 1
	end
	if value > maxPerFrame then
		maxPerFrame = value
	end
end
table.sort(samples)
local function percentile(fraction)
	if #samples == 0 then
		return nil
	end
	return samples[math.clamp(math.ceil(#samples * fraction), 1, #samples)]
end

local limit = ARGS.detail and 40 or (ARGS.top or 15)
local listLimit = ARGS.detail and 200 or 15

local result = {
	probe = "write_stop", ok = true, label = state.label, seconds = seconds, frames = state.frames,
	connected = state.connected, skipped = state.skipped, truncated = state.skipped > 0,
	hookedNew = state.hookedNew,
	writes = state.total, derived = state.derivedTotal,
	writesPerSecond = seconds > 0 and state.total / seconds or 0,
	writesPerFrameMean = state.frames > 0 and state.total / state.frames or nil,
	writesPerFrameMedian = percentile(0.5), writesPerFrameP95 = percentile(0.95),
	writesPerFrameMax = maxPerFrame, dirtyFrames = dirtyFrames, frameSamples = #samples,
	roots = {},
}
if state.frames == 0 then
	result.warning = "RenderStepped never fired: the Studio window is minimised or covered; per-frame figures are void"
end

for _, root in ipairs(state.roots) do
	table.insert(result.roots, {
		name = root.name, instances = root.instances, writes = root.writes, derived = root.derived,
		writesPerSecond = seconds > 0 and root.writes / seconds or 0,
		writesPerFrameMean = state.frames > 0 and root.writes / state.frames or nil,
		alive = root.inst.Parent ~= nil,
	})
end
table.sort(result.roots, function(a, b)
	if a.writes == b.writes then
		return a.name < b.name
	end
	return a.writes > b.writes
end)
if not ARGS.detail then
	-- Keep the reply small: drop silent roots, report how many were dropped.
	local kept = {}
	local silent = 0
	for _, root in ipairs(result.roots) do
		if root.writes > 0 or root.derived > 0 or #state.roots <= 4 then
			table.insert(kept, root)
		else
			silent += 1
		end
	end
	result.roots = kept
	result.silentRoots = silent
end

local byClass = {}
for _, record in ipairs(state.records) do
	byClass[record.class] = (byClass[record.class] or 0) + record.n
end
result.byClass = topOf(byClass, listLimit)
result.byProperty = topOf(state.byProp, listLimit)
result.derivedByProperty = topOf(state.derivedByProp, listLimit)

table.sort(state.records, function(a, b)
	if a.n == b.n then
		return a.path < b.path
	end
	return a.n > b.n
end)
local top = {}
for index = 1, math.min(limit, #state.records) do
	local record = state.records[index]
	top[index] = {
		path = record.path, class = record.class, root = record.root, writes = record.n,
		perFrame = state.frames > 0 and record.n / state.frames or nil,
		props = topOf(record.props, 5),
	}
end
result.top = top
result.instancesWritten = #state.records

return HttpService:JSONEncode(result)
