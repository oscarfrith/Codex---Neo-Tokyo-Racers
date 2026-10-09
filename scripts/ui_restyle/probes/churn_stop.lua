-- UI restyle probe: churn_stop (datamodel: Client, Play). READ-ONLY.
-- Disconnects the session opened by churn_start.lua and returns its counters.
local ARGS = {
	detail = false,  -- true adds per-root counts by class and a longer top list
	top = 15,        -- entries in the top "root|Class|Name" list
	quietRoots = false, -- true lists roots with zero churn too
}

local HttpService = game:GetService("HttpService")

local store = shared.UIRestyleProbe
if type(store) ~= "table" then
	store = _G.UIRestyleProbe
end
local state = type(store) == "table" and store.churn or nil
if not state then
	return HttpService:JSONEncode({
		probe = "churn_stop", ok = false, error = "no_session",
		hint = "churn_start did not run in this datamodel, or shared/_G did not persist between calls; use churn_probe.lua (blocking) instead",
	})
end

for _, connection in ipairs(state.conns) do
	connection:Disconnect()
end
store.churn = nil

local seconds = os.clock() - state.t0
local result = {
	probe = "churn_stop", ok = true, label = state.label, seconds = seconds, frames = state.frames,
	roots = {}, quiet = 0, guiAdded = state.guiAdded, guiRemoved = state.guiRemoved,
	nameKeysDropped = state.nameKeysDropped,
	totals = { added = 0, removed = 0, createdWithNewGuis = 0 },
}

for _, root in ipairs(state.order) do
	local alive = root.inst.Parent ~= nil
	local entry = {
		name = root.name, added = root.added, removed = root.removed,
		startCount = root.startCount, endCount = alive and #root.inst:GetDescendants() or 0,
		alive = alive, addedDuringRun = root.addedDuringRun or nil,
	}
	result.totals.added += root.added
	result.totals.removed += root.removed
	if root.addedDuringRun then
		-- A ScreenGui created during the run arrives with startCount descendants already built.
		result.totals.createdWithNewGuis += root.startCount + 1
	end
	if ARGS.detail then
		entry.addedByClass = root.addedByClass
		entry.removedByClass = root.removedByClass
	end
	if root.added > 0 or root.removed > 0 or root.addedDuringRun or not alive or ARGS.quietRoots then
		table.insert(result.roots, entry)
	else
		result.quiet += 1
	end
end

table.sort(result.roots, function(a, b)
	return (a.added + a.removed) > (b.added + b.removed)
end)

local names = {}
for key, entry in pairs(state.names) do
	table.insert(names, { key = key, added = entry[1], removed = entry[2] })
end
table.sort(names, function(a, b)
	local left, right = a.added + a.removed, b.added + b.removed
	if left == right then
		return a.key < b.key
	end
	return left > right
end)
local limit = ARGS.detail and math.max(ARGS.top or 15, 40) or (ARGS.top or 15)
local top = {}
for index = 1, math.min(limit, #names) do
	top[index] = names[index]
end
result.top = top
result.distinctNameKeys = #names

local churn = result.totals.added + result.totals.removed
result.totals.perSecond = seconds > 0 and churn / seconds or 0
result.totals.perFrame = state.frames > 0 and churn / state.frames or nil

return HttpService:JSONEncode(result)
