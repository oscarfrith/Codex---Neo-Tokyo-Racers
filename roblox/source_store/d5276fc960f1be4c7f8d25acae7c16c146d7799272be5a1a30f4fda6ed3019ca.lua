--!strict
-- Shared in-process signal (no Instances). Handlers run on their own thread, so one failing handler
-- cannot stop the others or the firer. Use for module-to-module events instead of new BindableEvents.
local Signal = {}
Signal.__index = Signal

export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	if not self.Connected then return end
	self.Connected = false
	local handlers = self._signal._handlers
	local index = table.find(handlers, self)
	if index then table.remove(handlers, index) end
end

function Signal.new()
	return setmetatable({ _handlers = {}, _destroyed = false }, Signal)
end

function Signal:Connect(callback: (...any) -> ())
	assert(type(callback) == "function", "Signal:Connect expects a function")
	assert(not self._destroyed, "Cannot connect to a destroyed signal")
	local connection = setmetatable({ Connected = true, _signal = self, _callback = callback }, Connection)
	table.insert(self._handlers, connection)
	return connection
end

function Signal:Once(callback: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	if self._destroyed then return end
	-- Snapshot so handlers may connect/disconnect while firing.
	for _, connection in ipairs(table.clone(self._handlers)) do
		if connection.Connected then task.spawn(connection._callback, ...) end
	end
end

function Signal:Wait(): ...any
	local thread = coroutine.running()
	self:Once(function(...) task.spawn(thread, ...) end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, connection in ipairs(table.clone(self._handlers)) do connection:Disconnect() end
end

function Signal:Destroy()
	if self._destroyed then return end
	self:DisconnectAll()
	self._destroyed = true
end

return Signal
