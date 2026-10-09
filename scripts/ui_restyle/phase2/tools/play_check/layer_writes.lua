-- Pulse Play check: layer_writes. CLIENT side, READ-ONLY. Run during Play as the source of an unparented
-- ModuleScript (no loadstring). It requires no game module, fires no remote, writes nothing and creates no instance;
-- it only connects to change signals, waits ARGS.seconds, and disconnects them all. Returns ONE JSON string:
--   { ok, seconds, guis = [{name, uiStyle, changed, byProperty = {Enabled = n, ...}, descendantAdded,
--     descendantRemoving, descendantChanged, topDescendants = [{path, changed}]}] }
-- Use: a resting Pulse layer should show 0 writes (PC 5.1: no churn); a Classic gui whose Enabled a Pulse owner must
-- not touch should show byProperty.Enabled = 0 while the Pulse screen opens and closes.
local ARGS = {
	guis = {}, -- ScreenGui names under PlayerGui; empty = every ScreenGui present when the check starts
	seconds = 5,
	descendants = true, -- also count property changes of the descendants present at the start, and adds / removals
	maxConnections = 6000, -- cap on descendant connections, over all guis
	top = 8, -- busiest descendants listed per gui
}

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
	return HttpService:JSONEncode({ check = "layer_writes", ok = false, error = "PlayerGui not found" })
end

local wanted = {}
for _, name in ipairs(ARGS.guis) do
	wanted[name] = true
end
local connections, rows, missing = {}, {}, {}
local connectionBudget = ARGS.maxConnections
local capped = false

local function relativePath(object, gui)
	local parts = {}
	local current = object
	while current and current ~= gui do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

local function watch(gui)
	local row = {
		name = gui.Name,
		uiStyle = tostring(gui:GetAttribute("UIStyle")),
		changed = 0,
		byProperty = {},
		descendantAdded = 0,
		descendantRemoving = 0,
		descendantChanged = 0,
		watchedDescendants = 0,
	}
	local perDescendant = {}
	table.insert(connections, gui.Changed:Connect(function(property)
		row.changed += 1
		row.byProperty[property] = (row.byProperty[property] or 0) + 1
	end))
	table.insert(connections, gui.AttributeChanged:Connect(function(attribute)
		local key = "@" .. attribute
		row.changed += 1
		row.byProperty[key] = (row.byProperty[key] or 0) + 1
	end))
	if ARGS.descendants then
		table.insert(connections, gui.DescendantAdded:Connect(function()
			row.descendantAdded += 1
		end))
		table.insert(connections, gui.DescendantRemoving:Connect(function()
			row.descendantRemoving += 1
		end))
		for _, descendant in ipairs(gui:GetDescendants()) do
			if connectionBudget <= 0 then
				capped = true
				break
			end
			connectionBudget -= 1
			row.watchedDescendants += 1
			table.insert(connections, descendant.Changed:Connect(function(property)
				row.descendantChanged += 1
				local entry = perDescendant[descendant]
				if not entry then
					entry = { path = relativePath(descendant, gui), changed = 0, properties = {} }
					perDescendant[descendant] = entry
				end
				entry.changed += 1
				entry.properties[property] = (entry.properties[property] or 0) + 1
			end))
		end
	end
	row._perDescendant = perDescendant
	table.insert(rows, row)
end

local seen = {}
for _, child in ipairs(playerGui:GetChildren()) do
	if child:IsA("ScreenGui") and (next(wanted) == nil or wanted[child.Name]) then
		seen[child.Name] = true
		watch(child)
	end
end
for name in pairs(wanted) do
	if not seen[name] then
		table.insert(missing, name)
	end
end
local guiAdded, guiRemoved = {}, {}
table.insert(connections, playerGui.ChildAdded:Connect(function(child)
	table.insert(guiAdded, child.Name)
end))
table.insert(connections, playerGui.ChildRemoved:Connect(function(child)
	table.insert(guiRemoved, child.Name)
end))

local started = os.clock()
task.wait(ARGS.seconds)
local elapsed = os.clock() - started
for _, connection in ipairs(connections) do
	connection:Disconnect()
end

local totalWrites = 0
for _, row in ipairs(rows) do
	local list = {}
	for _, entry in pairs(row._perDescendant) do
		table.insert(list, entry)
	end
	table.sort(list, function(a, b)
		return a.changed > b.changed
	end)
	row.topDescendants = {}
	for index = 1, math.min(ARGS.top, #list) do
		table.insert(row.topDescendants, list[index])
	end
	row._perDescendant = nil
	totalWrites += row.changed + row.descendantChanged + row.descendantAdded + row.descendantRemoving
end
table.sort(rows, function(a, b)
	return a.name < b.name
end)
table.sort(missing)

return HttpService:JSONEncode({
	check = "layer_writes",
	ok = #missing == 0,
	seconds = elapsed,
	totalWrites = totalWrites,
	missing = missing,
	connectionsCapped = capped,
	screenGuisAdded = guiAdded,
	screenGuisRemoved = guiRemoved,
	guis = rows,
})
