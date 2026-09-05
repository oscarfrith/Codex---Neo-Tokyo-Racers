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
