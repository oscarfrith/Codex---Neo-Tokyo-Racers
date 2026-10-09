-- UI restyle probe: churn_probe (datamodel: Client, Play). READ-ONLY, BLOCKS for ARGS.seconds.
-- Single-call form of churn_start/churn_stop for when shared state does not persist between
-- execute_luau calls, or for idle baselines. The interaction must come from somewhere else while
-- this call is blocked (the user, or an input call already in flight).
local ARGS = {
	label = "",
	seconds = 10,    -- capped at 25
	guis = nil,      -- nil = every LayerCollector under PlayerGui; or names / dotted paths
	detail = false,  -- true adds per-root counts by class and a longer top list
	top = 15,
	maxNameKeys = 400,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
	return HttpService:JSONEncode({ probe = "churn_probe", ok = false, error = "PlayerGui not found (run on the Client datamodel in Play)" })
end

local conns = {}
local roots = {}
local order = {}
local names = {}
local nameKeys = 0
local nameKeysDropped = 0
local frames = 0
local guiAdded = {}
local guiRemoved = {}
local maxNameKeys = ARGS.maxNameKeys or 400

local function bump(root, item, isAdd)
	local class = item.ClassName
	if isAdd then
		root.added += 1
		root.addedByClass[class] = (root.addedByClass[class] or 0) + 1
	else
		root.removed += 1
		root.removedByClass[class] = (root.removedByClass[class] or 0) + 1
	end
	local key = root.name .. "|" .. class .. "|" .. item.Name
	local entry = names[key]
	if not entry then
		if nameKeys >= maxNameKeys then
			nameKeysDropped += 1
			return
		end
		entry = { 0, 0 }
		names[key] = entry
		nameKeys += 1
	end
	if isAdd then
		entry[1] += 1
	else
		entry[2] += 1
	end
end

local function hook(item, name, addedDuringRun)
	if roots[item] then
		return
	end
	local root = {
		name = name, inst = item, added = 0, removed = 0, startCount = #item:GetDescendants(),
		addedByClass = {}, removedByClass = {}, addedDuringRun = addedDuringRun,
	}
	roots[item] = root
	table.insert(order, root)
	table.insert(conns, item.DescendantAdded:Connect(function(descendant)
		bump(root, descendant, true)
	end))
	table.insert(conns, item.DescendantRemoving:Connect(function(descendant)
		bump(root, descendant, false)
	end))
end

local missing = {}
if ARGS.guis then
	for _, path in ipairs(ARGS.guis) do
		local item = playerGui
		for part in string.gmatch(path, "[^%.]+") do
			item = item and item:FindFirstChild(part)
		end
		if item then
			hook(item, path, false)
		else
			table.insert(missing, path)
		end
	end
else
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("LayerCollector") then
			hook(child, child.Name, false)
		end
	end
	table.insert(conns, playerGui.ChildAdded:Connect(function(child)
		table.insert(guiAdded, child.Name)
		if child:IsA("LayerCollector") then
			hook(child, child.Name, true)
		end
	end))
	table.insert(conns, playerGui.ChildRemoved:Connect(function(child)
		table.insert(guiRemoved, child.Name)
	end))
end
table.insert(conns, RunService.RenderStepped:Connect(function()
	frames += 1
end))

local t0 = os.clock()
task.wait(math.clamp(tonumber(ARGS.seconds) or 10, 0.1, 25))
local seconds = os.clock() - t0

for _, connection in ipairs(conns) do
	connection:Disconnect()
end

local result = {
	probe = "churn_probe", ok = true, label = ARGS.label, seconds = seconds, frames = frames,
	roots = {}, quiet = 0, guiAdded = guiAdded, guiRemoved = guiRemoved, missing = missing,
	nameKeysDropped = nameKeysDropped,
	totals = { added = 0, removed = 0, createdWithNewGuis = 0 },
}

for _, root in ipairs(order) do
	local alive = root.inst.Parent ~= nil
	local entry = {
		name = root.name, added = root.added, removed = root.removed,
		startCount = root.startCount, endCount = alive and #root.inst:GetDescendants() or 0,
		alive = alive, addedDuringRun = root.addedDuringRun or nil,
	}
	result.totals.added += root.added
	result.totals.removed += root.removed
	if root.addedDuringRun then
		result.totals.createdWithNewGuis += root.startCount + 1
	end
	if ARGS.detail then
		entry.addedByClass = root.addedByClass
		entry.removedByClass = root.removedByClass
	end
	if root.added > 0 or root.removed > 0 or root.addedDuringRun or not alive then
		table.insert(result.roots, entry)
	else
		result.quiet += 1
	end
end
table.sort(result.roots, function(a, b)
	return (a.added + a.removed) > (b.added + b.removed)
end)

local list = {}
for key, entry in pairs(names) do
	table.insert(list, { key = key, added = entry[1], removed = entry[2] })
end
table.sort(list, function(a, b)
	local left, right = a.added + a.removed, b.added + b.removed
	if left == right then
		return a.key < b.key
	end
	return left > right
end)
local limit = ARGS.detail and math.max(ARGS.top or 15, 40) or (ARGS.top or 15)
local top = {}
for index = 1, math.min(limit, #list) do
	top[index] = list[index]
end
result.top = top
result.distinctNameKeys = #list

local churn = result.totals.added + result.totals.removed
result.totals.perSecond = seconds > 0 and churn / seconds or 0
result.totals.perFrame = frames > 0 and churn / frames or nil

return HttpService:JSONEncode(result)
