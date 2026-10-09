-- Owns the Pulse route table: which module each ClientBase entry name starts under Pulse; starts nothing and owns no UI.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Routes. Requires: none (the latch is passed to Compose).
local Players = game:GetService("Players")

local Routes = {}

local PULSE_PREFIX = "ReplicatedStorage.Modules.Game.UIPulse."
local WATCH_SECONDS = 15

-- Families in delivery order. A later phase appends its family here and its rows to Swap or Add.
Routes.Families = { "Toasts", "RaceMenu" }
-- Entry name -> the Pulse module that starts under that name while its family is active.
Routes.Swap = {
	SharedTopNotificationUI = { Family = "Toasts", Path = "ReplicatedStorage.Modules.Game.UIPulse.Toasts.ToastClient" },
	RaceBrowserClient = { Family = "RaceMenu", Path = "ReplicatedStorage.Modules.Game.UIPulse.RaceMenu.RaceMenuClient" },
}
-- Pulse-only entries, appended after the Classic list. Family nil = whenever the style is Pulse.
Routes.Add = {
	{ name = "PulseGallery", path = "ReplicatedStorage.Modules.Game.UIPulse.Dev.Gallery", dependencies = {}, tool = "PulseGalleryEnabled" },
}

local composedPaths = nil -- entry name -> path, set by a successful Compose
local composedSwitch = nil -- the latch Compose was given; Style is read from it at use, never cached
local watchNames = {} -- swapped and added entry names of the composed list
local watchStarted = false

-- Two or more dot-separated names of letters, digits and underscores.
local function validPath(path)
	if type(path) ~= "string" or path == "" then
		return false
	end
	local count = 0
	for segment in string.gmatch(path .. ".", "([^%.]*)%.") do
		if string.match(segment, "^[%w_]+$") == nil then
			return false
		end
		count += 1
	end
	return count >= 2
end

-- Same rules and messages as Core.ClientLifecycle.validate (lines 5 to 8), plus the shape of each entry.
local function validate(list, pulseNames)
	local index, visiting, visited = {}, {}, {}
	for position, entry in ipairs(list) do
		assert(type(entry.name) == "string" and entry.name ~= "", "Entry " .. position .. " has no name")
		assert(validPath(entry.path), "Bad path for " .. entry.name .. ": " .. tostring(entry.path))
		assert(entry.dependencies == nil or type(entry.dependencies) == "table", "Bad dependencies for " .. entry.name)
		assert(entry.tool == nil or type(entry.tool) == "string", "Bad tool flag for " .. entry.name)
		if pulseNames[entry.name] then
			assert(string.sub(entry.path, 1, #PULSE_PREFIX) == PULSE_PREFIX, "Pulse path outside UIPulse for " .. entry.name .. ": " .. entry.path)
		end
		assert(not index[entry.name], "Duplicate client " .. entry.name)
		index[entry.name] = entry
	end
	local function visit(name)
		assert(index[name], "Missing dependency " .. tostring(name))
		assert(not visiting[name], "Dependency cycle at " .. name)
		if visited[name] then
			return
		end
		visiting[name] = true
		for _, dependency in ipairs(index[name].dependencies or {}) do
			visit(dependency)
		end
		visiting[name] = nil
		visited[name] = true
	end
	for _, entry in ipairs(list) do
		visit(entry.name)
	end
end

-- Pure apart from switch.Commit (the last statement). Never yields. The input list and its entries are not changed.
function Routes.Compose(entries, switch)
	assert(type(entries) == "table", "Routes.Compose: entries must be a list")
	assert(type(switch) == "table" and type(switch.Active) == "function" and type(switch.Commit) == "function", "Routes.Compose: the latch is required")
	assert(switch.Style == "Pulse", "Routes.Compose: style is " .. tostring(switch.Style))

	local known = {}
	for _, family in ipairs(Routes.Families) do
		assert(type(family) == "string" and not known[family], "Routes.Families: bad or duplicate family " .. tostring(family))
		known[family] = true
	end
	local report = type(switch.Report) == "function" and switch.Report() or nil
	if type(report) == "table" and type(report.DevFamilies) == "table" then
		for _, family in ipairs(report.DevFamilies) do
			assert(known[family], "Unknown dev family " .. tostring(family))
		end
	end

	-- (1) Active families must be a prefix of Families: a family is never on while an earlier one is off.
	local active, activeSet, gapAt = {}, {}, nil
	for _, family in ipairs(Routes.Families) do
		if switch.Active(family) then
			assert(gapAt == nil, "Active families must be a prefix of Routes.Families: " .. family .. " is on while " .. tostring(gapAt) .. " is off")
			active[#active + 1] = family
			activeSet[family] = true
		elseif gapAt == nil then
			gapAt = family
		end
	end

	-- (2) A new list of shallow copies, same order.
	local list = {}
	for position, entry in ipairs(entries) do
		assert(type(entry) == "table", "Entry " .. position .. " is not a table")
		list[position] = table.clone(entry)
	end
	local pulseNames, watched = {}, {}
	local swapNames = {}
	for name in pairs(Routes.Swap) do
		swapNames[#swapNames + 1] = name
	end
	table.sort(swapNames)
	for _, name in ipairs(swapNames) do
		local swap = Routes.Swap[name]
		assert(type(swap) == "table" and known[swap.Family], "Swap for " .. name .. " names an unknown family " .. tostring(type(swap) == "table" and swap.Family or swap))
		if activeSet[swap.Family] then
			local target = nil
			for _, entry in ipairs(list) do
				if entry.name == name then
					target = entry
					break
				end
			end
			assert(target, "Swap target missing from the entry list: " .. name)
			target.path = swap.Path
			pulseNames[name] = true
			watched[#watched + 1] = name
		end
	end
	for position, add in ipairs(Routes.Add) do
		assert(type(add) == "table" and type(add.name) == "string", "Routes.Add row " .. position .. " has no name")
		assert(add.Family == nil or known[add.Family], "Routes.Add " .. add.name .. " names an unknown family " .. tostring(add.Family))
		if add.Family == nil or activeSet[add.Family] then
			local copy = table.clone(add)
			copy.Family = nil
			list[#list + 1] = copy
			pulseNames[add.name] = true
			watched[#watched + 1] = add.name
		end
	end

	-- (3) Validate the composed list, so lifecycle.start cannot throw on it.
	validate(list, pulseNames)

	-- (4) Name -> path for Resolve.
	local paths = {}
	for _, entry in ipairs(list) do
		paths[entry.name] = entry.path
	end
	composedPaths, composedSwitch, watchNames = paths, switch, watched

	-- (5) Last statement: tell the latch which families run.
	switch.Commit({ Families = active })
	return list
end

-- YIELDS. Returns the module ClientBase starts for that entry name (same require cache as ClientBase).
function Routes.Resolve(entryName)
	assert(composedPaths ~= nil and composedSwitch ~= nil, "Routes.Resolve: Compose has not succeeded")
	assert(composedSwitch.Style == "Pulse", "Routes.Resolve: style is " .. tostring(composedSwitch.Style))
	local path = composedPaths[entryName]
	assert(path, "Routes.Resolve: unknown entry " .. tostring(entryName))
	local item = game
	for part in string.gmatch(path, "[^%.]+") do
		item = item:WaitForChild(part)
	end
	return require(item)
end

-- Idempotent. One warning 15 s later listing swapped or added entries that are neither ready nor skipped.
function Routes.StartWatch()
	if watchStarted then
		return
	end
	watchStarted = true
	local names = watchNames
	task.delay(WATCH_SECONDS, function()
		local player = Players.LocalPlayer
		local playerScripts = player and player:FindFirstChild("PlayerScripts")
		local clientBase = playerScripts and playerScripts:FindFirstChild("ClientBase")
		local startupState = clientBase and clientBase:FindFirstChild("StartupState")
		if not startupState then
			warn("[Pulse.Routes] ClientBase.StartupState not found; start-up not checked")
			return
		end
		local late = {}
		for _, name in ipairs(names) do
			local status = startupState:GetAttribute(name)
			if status ~= "ready" and status ~= "skipped" then
				late[#late + 1] = name .. "=" .. tostring(status)
			end
		end
		if #late > 0 then
			warn("[Pulse.Routes] not ready after " .. WATCH_SECONDS .. " s: " .. table.concat(late, ", "))
		end
	end)
end

-- Test hook: forgets the composed list. Nothing in the game calls it.
function Routes._reset()
	composedPaths, composedSwitch, watchNames, watchStarted = nil, nil, {}, false
end

return Routes
