-- UI restyle probe: write_start (datamodel: Client, Play). READ-ONLY, returns immediately.
-- Connects `Changed` on every instance under the named roots and counts property changes in
-- shared.UIRestyleProbe.write. Run write_stop.lua (same datamodel) to disconnect and read them.
-- It counts from outside the code under test, so shared modules are included.
-- Limits (read before quoting numbers):
--   * The engine does not fire Changed when a property is set to the value it already has, so
--     this counts effective property changes: a lower bound on writes.
--   * Engine-derived properties (AbsolutePosition, AbsoluteSize, TextBounds, ...) are counted
--     separately as `derived`, not as writes.
--   * Attribute writes do not fire Changed and are not counted.
--   * Properties set on an instance before it is parented under a root are not seen.
local ARGS = {
	label = "",
	guis = nil,          -- nil = every LayerCollector under PlayerGui; or names / dotted paths, e.g.
	                     -- {"DesktopFreeRoamHud"} or {"Hud.DesignRoot.Static", "Hud.DesignRoot.Live"}.
	                     -- One root = one row in the result, so pass static and live layers separately.
	maxInstances = 6000, -- cap on Changed connections; truncation is reported
	followNew = true,    -- also connect instances added under a root while running (within the cap)
	maxFrames = 6000,    -- per-frame samples kept for median / p95
	force = false,       -- true = disconnect and discard a write session that is already running
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
if not playerGui then
	return HttpService:JSONEncode({ probe = "write_start", ok = false, error = "PlayerGui not found (run on the Client datamodel in Play)" })
end

local store = shared.UIRestyleProbe
if type(store) ~= "table" then
	store = {}
	shared.UIRestyleProbe = store
end
_G.UIRestyleProbe = store

if store.write then
	if not ARGS.force then
		return HttpService:JSONEncode({ probe = "write_start", ok = false, error = "already_running", label = store.write.label, runningSeconds = os.clock() - store.write.t0 })
	end
	for _, connection in ipairs(store.write.conns) do
		connection:Disconnect()
	end
	store.write = nil
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
store.write = state

return HttpService:JSONEncode({
	probe = "write_start", ok = true, label = ARGS.label, roots = #state.roots,
	connected = state.connected, skipped = state.skipped, truncated = state.skipped > 0,
	maxInstances = state.max, missing = missing,
})
