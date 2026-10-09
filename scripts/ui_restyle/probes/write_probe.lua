-- UI restyle probe: write_probe (datamodel: Client, Play). READ-ONLY, BLOCKS for ARGS.seconds.
-- Single-call form of write_start/write_stop: `Changed` on every instance under the named roots
-- for ARGS.seconds (plan 5.3: 10 seconds, static and live layers as separate roots).
-- Use it for parked / steady-state samples, or when shared state does not persist between
-- execute_luau calls. See write_start.lua for what is and is not counted (effective changes
-- only; derived properties separate; attributes not counted).
local ARGS = {
	label = "",
	seconds = 10,        -- capped at 25
	guis = nil,          -- nil = every LayerCollector under PlayerGui; or names / dotted paths
	maxInstances = 6000, -- cap on Changed connections; truncation is reported
	followNew = true,    -- also connect instances added under a root while running (within the cap)
	maxFrames = 6000,
	top = 15,
	detail = false,      -- true = longer lists
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
	return HttpService:JSONEncode({ probe = "write_probe", ok = false, error = "PlayerGui not found (run on the Client datamodel in Play)" })
end

local DERIVED = {
	AbsolutePosition = true, AbsoluteSize = true, AbsoluteRotation = true, AbsoluteContentSize = true,
	AbsoluteCanvasSize = true, AbsoluteWindowSize = true, TextBounds = true, TextFits = true,
	ContentText = true, IsLoaded = true, GuiState = true, LocalizedText = true,
}

local state = {
	kind = "write", label = ARGS.label, t0 = os.clock(), conns = {}, roots = {}, records = {},
	byProp = {}, derivedByProp = {}, connected = 0, max = ARGS.maxInstances or 6000, skipped = 0,
	hookedNew = 0, total = 0, derivedTotal = 0, frames = 0, frameWrites = 0, perFrame = {},
	maxFrames = ARGS.maxFrames or 6000,
}

local function relativePath(item)
	local parts = {}
	local current = item
	while current and current ~= playerGui do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local function connect(item, root)
	if state.connected >= state.max then
		state.skipped += 1
		return
	end
	state.connected += 1
	root.instances += 1
	local isValue = item:IsA("ValueBase")
	local record = nil
	table.insert(state.conns, item.Changed:Connect(function(property)
		if isValue then
			property = "Value"
		end
		if DERIVED[property] then
			root.derived += 1
			state.derivedTotal += 1
			state.derivedByProp[property] = (state.derivedByProp[property] or 0) + 1
			return
		end
		root.writes += 1
		state.total += 1
		state.frameWrites += 1
		state.byProp[property] = (state.byProp[property] or 0) + 1
		if not record then
			record = { root = root.name, class = item.ClassName, path = relativePath(item), n = 0, props = {} }
			table.insert(state.records, record)
		end
		record.n += 1
		record.props[property] = (record.props[property] or 0) + 1
	end))
end

local function hookRoot(item, name)
	local root = { name = name, inst = item, writes = 0, derived = 0, instances = 0 }
	table.insert(state.roots, root)
	connect(item, root)
	for _, descendant in ipairs(item:GetDescendants()) do
		connect(descendant, root)
	end
	if ARGS.followNew then
		table.insert(state.conns, item.DescendantAdded:Connect(function(descendant)
			state.hookedNew += 1
			connect(descendant, root)
		end))
	end
end

local missing = {}
if ARGS.guis then
	for _, path in ipairs(ARGS.guis) do
		local item = playerGui
		for part in string.gmatch(path, "[^%.]+") do
			item = item and item:FindFirstChild(part)
		end
		if item then
			hookRoot(item, path)
		else
			table.insert(missing, path)
		end
	end
else
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("LayerCollector") then
			hookRoot(child, child.Name)
		end
	end
end

table.insert(state.conns, RunService.RenderStepped:Connect(function()
	state.frames += 1
	if state.frames <= state.maxFrames then
		state.perFrame[state.frames] = state.frameWrites
	end
	state.frameWrites = 0
end))

state.t0 = os.clock()
task.wait(math.clamp(tonumber(ARGS.seconds) or 10, 0.1, 25))
local seconds = os.clock() - state.t0
for _, connection in ipairs(state.conns) do
	connection:Disconnect()
end

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
	probe = "write_probe", ok = true, label = state.label, seconds = seconds, frames = state.frames,
	connected = state.connected, skipped = state.skipped, truncated = state.skipped > 0,
	hookedNew = state.hookedNew,
	writes = state.total, derived = state.derivedTotal,
	writesPerSecond = seconds > 0 and state.total / seconds or 0,
	writesPerFrameMean = state.frames > 0 and state.total / state.frames or nil,
	writesPerFrameMedian = percentile(0.5), writesPerFrameP95 = percentile(0.95),
	writesPerFrameMax = maxPerFrame, dirtyFrames = dirtyFrames, frameSamples = #samples,
	roots = {}, missing = missing,
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
