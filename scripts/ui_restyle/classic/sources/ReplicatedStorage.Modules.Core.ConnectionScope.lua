-- Owns subscriptions and other resources for one explicit binding. destroy is repeat-safe and releases in
-- reverse order; one failing cleanup never prevents the rest.
local Scope={}
Scope.__index=Scope
function Scope.new() return setmetatable({connections={},destroyed=false},Scope) end
function Scope:connect(signal,callback)
	assert(not self.destroyed,"Cannot bind a destroyed scope")
	local connection=signal:Connect(callback)
	table.insert(self.connections,connection)
	return connection
end
-- Tracks a connection, Instance, cleanup function, thread or object with destroy/Destroy/Disconnect.
function Scope:add(item)
	assert(not self.destroyed,"Cannot add to a destroyed scope")
	assert(item~=nil,"Cannot add nil to a scope")
	table.insert(self.connections,item)
	return item
end
function Scope:task(callback,...)
	return self:add(task.spawn(callback,...))
end
local function release(item)
	local kind=typeof(item)
	if kind=="RBXScriptConnection" then item:Disconnect()
	elseif kind=="Instance" then item:Destroy()
	elseif kind=="function" then item()
	elseif kind=="thread" then if coroutine.status(item)~="dead" then task.cancel(item) end
	elseif kind=="table" then
		local method=item.destroy or item.Destroy or item.Disconnect
		if method then method(item) end
	end
end
function Scope:destroy()
	if self.destroyed then return end
	self.destroyed=true
	local items=self.connections
	self.connections={}
	for index=#items,1,-1 do
		local ok,err=pcall(release,items[index])
		if not ok then warn("[ConnectionScope] cleanup failed: "..tostring(err)) end
	end
end
return Scope
