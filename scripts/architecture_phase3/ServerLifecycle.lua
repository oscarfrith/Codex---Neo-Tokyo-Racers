-- Explicit server-session composition. Owns startup state, never gameplay state.
local Lifecycle = {}
function Lifecycle.validate(entries)
	local index, visiting, visited = {}, {}, {}
	for _,entry in ipairs(entries) do assert(not index[entry.name],"Duplicate service "..entry.name); index[entry.name]=entry end
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
function Lifecycle.start(entries, resolve, emit)
	Lifecycle.validate(entries)
	local states={}
	local function set(name,status,message)
		states[name]={status=status,message=message}
		if emit then emit(name,status,message) end
	end
	for _,entry in ipairs(entries) do set(entry.name,"pending") end
	for _,entry in ipairs(entries) do task.spawn(function()
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
			local service=resolve(entry)
			assert(type(service)=="table" and type(service.start)=="function","Service start missing")
			service.start()
		end,debug.traceback)
		set(entry.name,ok and "ready" or "failed",not ok and tostring(message) or nil)
	end) end
	return states
end
return Lifecycle
