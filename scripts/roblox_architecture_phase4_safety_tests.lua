local Lifecycle=(function()
-- Owns explicit client-session startup, not gameplay state. No individual feature hot reload.
local Lifecycle = {}
function Lifecycle.validate(entries)
	local index, visiting, visited = {}, {}, {}
	for _,entry in ipairs(entries) do assert(not index[entry.name],"Duplicate client "..entry.name); index[entry.name]=entry end
	local function visit(name)
		assert(index[name],"Missing dependency "..name)
		assert(not visiting[name],"Dependency cycle at "..name)
		if visited[name] then return end
		visiting[name]=true
		for _,dependency in ipairs(index[name].dependencies or {}) do visit(dependency) end
		visiting[name]=nil; visited[name]=true
	end
	for name in pairs(index) do visit(name) end
	return index
end
function Lifecycle.tool_enabled(is_studio, config, flag)
	return is_studio == true and config ~= nil and config:GetAttribute(flag) == true
end
function Lifecycle.start(entries, resolve, emit, enabled)
	Lifecycle.validate(entries)
	local states={}
	local function set(name,status,message)
		states[name]={status=status,message=message}
		if emit then emit(name,status,message) end
	end
	for _,entry in ipairs(entries) do set(entry.name,"pending") end
	for _,entry in ipairs(entries) do task.spawn(function()
		if entry.tool and not (enabled and enabled(entry.tool)) then set(entry.name,"skipped"); return end
		local deadline=os.clock()+30
		for _,dependency in ipairs(entry.dependencies or {}) do
			while states[dependency].status=="pending" or states[dependency].status=="starting" do
				if os.clock()>=deadline then set(entry.name,"blocked","Dependency timeout: "..dependency); return end
				task.wait(0.05)
			end
			if states[dependency].status~="ready" then set(entry.name,"blocked","Dependency failed: "..dependency); return end
		end
		set(entry.name,"starting")
		local ok,message=xpcall(function()
			local feature=resolve(entry)
			assert(type(feature)=="table" and type(feature.start)=="function","Client start missing")
			feature.start()
		end,debug.traceback)
		set(entry.name,ok and "ready" or "failed",not ok and tostring(message) or nil)
	end) end
	return states
end
return Lifecycle

end)()
local Scope=(function()
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

end)()
local passed=0
local function test(name,fn) fn(); passed+=1; print("PASS "..name) end
test("dependency validation",function()
	Lifecycle.validate({{name="A"},{name="B",dependencies={"A"}}})
	assert(not pcall(Lifecycle.validate,{{name="A"},{name="A"}}))
	assert(not pcall(Lifecycle.validate,{{name="A",dependencies={"Missing"}}}))
	assert(not pcall(Lifecycle.validate,{{name="A",dependencies={"B"}},{name="B",dependencies={"A"}}}))
end)
test("development tools require Studio AND explicit opt-in",function()
	local config={GetAttribute=function(_,key) return key=="Yes" end}
	assert(Lifecycle.tool_enabled(true,config,"Yes"))
	assert(not Lifecycle.tool_enabled(false,config,"Yes"))
	assert(not Lifecycle.tool_enabled(true,config,"No"))
	assert(not Lifecycle.tool_enabled(true,nil,"Yes"))
end)
test("startup failure isolation and tool skip before require",function()
	local calls={}
	local states=Lifecycle.start({{name="A"},{name="B",dependencies={"A"}},{name="C"},{name="Tool",tool="Off"}},function(entry)
		calls[entry.name]=true
		return {start=function() if entry.name=="A" then error("expected fixture failure") end end}
	end,nil,function() return false end)
	local deadline=os.clock()+2
	while states.B.status=="pending" and os.clock()<deadline do task.wait() end
	assert(states.A.status=="failed" and states.B.status=="blocked" and states.C.status=="ready" and states.Tool.status=="skipped")
	assert(not calls.B and not calls.Tool)
end)
test("subscription scope disconnects once and rejects reuse",function()
	local disconnected=0
	local signal={Connect=function() return {Disconnect=function() disconnected+=1 end} end}
	local scope=Scope.new()
	scope:connect(signal,function() end); scope:connect(signal,function() end)
	scope:destroy(); scope:destroy()
	assert(disconnected==2 and #scope.connections==0)
	assert(not pcall(function() scope:connect(signal,function() end) end))
end)
return "PASS "..passed.." Phase 4 helper groups"
