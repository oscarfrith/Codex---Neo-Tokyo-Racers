-- UI restyle probe: churn_start (datamodel: Client, Play). READ-ONLY, returns immediately.
-- Connects DescendantAdded / DescendantRemoving under each ScreenGui and keeps counters in
-- shared.UIRestyleProbe.churn. Run churn_stop.lua (same datamodel) to disconnect and read them.
-- Creates no instances, requires nothing, fires nothing.
local ARGS = {
	label = "",      -- free text copied into the result
	guis = nil,      -- nil = every LayerCollector under PlayerGui (and any added while running);
	                 -- or {"SharedInRaceHUD", "DesktopFreeRoamHud.DesignRoot"} (names or dotted paths)
	force = false,   -- true = disconnect and discard a churn session that is already running
	maxNameKeys = 400, -- cap on distinct "root|Class|Name" keys kept for the top list
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
	return HttpService:JSONEncode({ probe = "churn_start", ok = false, error = "PlayerGui not found (run on the Client datamodel in Play)" })
end

local store = shared.UIRestyleProbe
if type(store) ~= "table" then
	store = {}
	shared.UIRestyleProbe = store
end
_G.UIRestyleProbe = store

if store.churn then
	if not ARGS.force then
		return HttpService:JSONEncode({ probe = "churn_start", ok = false, error = "already_running", label = store.churn.label, runningSeconds = os.clock() - store.churn.t0 })
	end
	for _, connection in ipairs(store.churn.conns) do
		connection:Disconnect()
	end
	store.churn = nil
end

local state = {
	kind = "churn", label = ARGS.label, t0 = os.clock(), conns = {}, roots = {}, order = {},
	names = {}, nameKeys = 0, nameKeysDropped = 0, frames = 0,
	guiAdded = {}, guiRemoved = {}, followNew = ARGS.guis == nil,
	maxNameKeys = ARGS.maxNameKeys or 400,
}

local function bump(root, item, field)
	root[field] += 1
	local byClass = field == "added" and root.addedByClass or root.removedByClass
	local class = item.ClassName
	byClass[class] = (byClass[class] or 0) + 1
	local key = root.name .. "|" .. class .. "|" .. item.Name
	local entry = state.names[key]
	if not entry then
		if state.nameKeys >= state.maxNameKeys then
			state.nameKeysDropped += 1
			return
		end
		entry = { 0, 0 }
		state.names[key] = entry
		state.nameKeys += 1
	end
	if field == "added" then
		entry[1] += 1
	else
		entry[2] += 1
	end
end

local function hook(item, name, addedDuringRun)
	if state.roots[item] then
		return
	end
	local root = {
		name = name, inst = item, added = 0, removed = 0, startCount = #item:GetDescendants(),
		addedByClass = {}, removedByClass = {}, addedDuringRun = addedDuringRun,
	}
	state.roots[item] = root
	table.insert(state.order, root)
	table.insert(state.conns, item.DescendantAdded:Connect(function(descendant)
		bump(root, descendant, "added")
	end))
	table.insert(state.conns, item.DescendantRemoving:Connect(function(descendant)
		bump(root, descendant, "removed")
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
	table.insert(state.conns, playerGui.ChildAdded:Connect(function(child)
		table.insert(state.guiAdded, child.Name)
		if child:IsA("LayerCollector") then
			hook(child, child.Name, true)
		end
	end))
	table.insert(state.conns, playerGui.ChildRemoved:Connect(function(child)
		table.insert(state.guiRemoved, child.Name)
	end))
end

table.insert(state.conns, RunService.RenderStepped:Connect(function()
	state.frames += 1
end))

store.churn = state

return HttpService:JSONEncode({
	probe = "churn_start", ok = true, label = ARGS.label, roots = #state.order,
	connections = #state.conns, missing = missing, followNew = state.followNew,
})
