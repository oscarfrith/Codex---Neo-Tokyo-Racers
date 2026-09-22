-- Owns subscriptions for one explicit binding. destroy is repeat-safe.
local Scope={}
Scope.__index=Scope
function Scope.new() return setmetatable({connections={},destroyed=false},Scope) end
function Scope:connect(signal,callback)
	assert(not self.destroyed,"Cannot bind a destroyed scope")
	local connection=signal:Connect(callback)
	table.insert(self.connections,connection)
	return connection
end
function Scope:destroy()
	if self.destroyed then return end
	self.destroyed=true
	for _,connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
end
return Scope
