-- Owns the in-memory record of which Pulse surfaces are open, by kind; owns no instance, attribute, remote or anything Classic reads.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Presence. Requires: none.
local Presence = {}

export type Kind = "FullMenu" | "Garage" | "Results" | "Map" | "Modal" | "SidePanel" | "Race" | "Loading"

local KINDS = {
	FullMenu = true,
	Garage = true,
	Results = true,
	Map = true,
	Modal = true,
	SidePanel = true,
	Race = true,
	Loading = true,
}

local warned = {}
local function warnOnce(message)
	if warned[message] then
		return
	end
	warned[message] = true
	warn("[Pulse.Presence] " .. message)
end

-- A Luau signal, not a BindableEvent: this module creates no instance. Connections have Disconnect, which is all
-- Core.ConnectionScope needs to release them. Same shape as Kit.Text.ReadyChanged.
local function newSignal()
	local connections = {}
	local signal = {}

	function signal:Connect(callback)
		local connection = { Connected = true }
		function connection:Disconnect()
			if not self.Connected then
				return
			end
			self.Connected = false
			local index = table.find(connections, self)
			if index then
				table.remove(connections, index)
			end
		end
		connection.Callback = callback
		table.insert(connections, connection)
		return connection
	end

	function signal:Once(callback)
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end)
		return connection
	end

	function signal:Wait()
		local thread = coroutine.running()
		local connection
		connection = self:Connect(function(...)
			connection:Disconnect()
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread, ...)
			end
		end)
		return coroutine.yield()
	end

	local function fire(...)
		for _, connection in table.clone(connections) do
			if connection.Connected then
				task.spawn(connection.Callback, ...)
			end
		end
	end

	return signal, fire
end

local changed, fireChanged = newSignal()

-- Fires (surface, kind, open) when a surface starts or stops being open under a kind.
Presence.Changed = changed

local total = 0
local byKind: { [string]: number } = {}
local bySurface: { [string]: number } = {}
local byPair: { [string]: { [string]: number } } = {} -- surface -> kind -> open count

-- Returns a release function, repeat-safe. Each full-screen view calls Open when it shows and the release when it hides.
-- A surface opened twice stays open until both releases have run; Changed fires on the first and the last only.
function Presence.Open(surface: string, kind: Kind): () -> ()
	if type(surface) ~= "string" or surface == "" then
		error("[Pulse.Presence] Open needs a surface name", 2)
	end
	if KINDS[kind] ~= true then
		error("[Pulse.Presence] unknown kind '" .. tostring(kind) .. "'", 2)
	end

	local kinds = byPair[surface]
	if not kinds then
		kinds = {}
		byPair[surface] = kinds
	end
	local pairCount = (kinds[kind] or 0) + 1
	kinds[kind] = pairCount
	bySurface[surface] = (bySurface[surface] or 0) + 1
	byKind[kind] = (byKind[kind] or 0) + 1
	total += 1
	if pairCount == 1 then
		fireChanged(surface, kind, true)
	end

	local released = false
	return function()
		if released then
			return
		end
		released = true
		local left = (kinds[kind] or 1) - 1
		kinds[kind] = if left > 0 then left else nil
		if next(kinds) == nil and byPair[surface] == kinds then
			byPair[surface] = nil
		end
		local surfaceLeft = (bySurface[surface] or 1) - 1
		bySurface[surface] = if surfaceLeft > 0 then surfaceLeft else nil
		local kindLeft = (byKind[kind] or 1) - 1
		byKind[kind] = if kindLeft > 0 then kindLeft else nil
		total = math.max(0, total - 1)
		if left <= 0 then
			fireChanged(surface, kind, false)
		end
	end
end

-- True while anything is open (no argument), or while a surface of that kind is open.
function Presence.Any(kind: Kind?): boolean
	if kind == nil then
		return total > 0
	end
	if KINDS[kind] ~= true then
		warnOnce("Any asked for unknown kind '" .. tostring(kind) .. "'")
		return false
	end
	return (byKind[kind] or 0) > 0
end

function Presence.Is(surface: string): boolean
	return (bySurface[surface] or 0) > 0
end

return Presence
