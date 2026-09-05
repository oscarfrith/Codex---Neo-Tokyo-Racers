local Lifecycle=(function()
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

end)()
local Compatibility=(function()
-- In-memory garage fields attached to the one ProfileServer session table.
-- No cache, DataStore, remotes, startup or independent inventory owner.
local Compatibility = {}
local transient={}
for name in string.gmatch("_Player CurrentCategory CurrentCockpit OwnedCockpits CockpitColors ThrustColor OwnedModules InstalledModules ModuleColors NeonOwned UpgradeLevels GarageCapacity OwnedGarageProperties GarageProperties GarageDisplaySpaces ModuleUpgradeLevels", "%S+") do transient[name]=true end
function Compatibility.attach(profile, view)
	for key in pairs(transient) do if view[key]~=nil then profile[key]=view[key] end end
	if not profile.CurrentVehicleId then profile.CurrentVehicleId=view.CurrentVehicleId end
	return profile
end
function Compatibility.persistent(profile)
	local data={}
	for key,value in pairs(profile) do if not transient[key] then data[key]=value end end
	return data
end
function Compatibility.commit(profile)
	local garage=profile.Garage
	local vehicles,cockpits=0,0
	for _ in pairs(profile.Vehicles or {}) do vehicles+=1 end
	for _ in pairs(profile.OwnedCockpits or {}) do cockpits+=1 end
	garage.Capacity=math.max(2,tonumber(profile.GarageCapacity) or 2,vehicles,cockpits)
	garage.OwnedGarageProperties=profile.OwnedGarageProperties or garage.OwnedGarageProperties
	-- Preserve the existing mapper's missing-display-slot initialisation.
	local i=0
	for id in pairs(profile.Vehicles or {}) do
		i+=1; local key="Space"..i
		garage.DisplaySpaces[key]=garage.DisplaySpaces[key] or {}
		garage.DisplaySpaces[key].VehicleId=garage.DisplaySpaces[key].VehicleId or id
	end
end
return Compatibility

end)()
-- The build runner supplies the actual Lifecycle and Compatibility modules.
local passed={}
local function test(name,callback) callback(); table.insert(passed,name) end
test("explicit dependency validation",function() assert(Lifecycle.validate({{name="A"},{name="B",dependencies={"A"}}}).B) end)
test("missing dependency rejected",function() assert(not pcall(Lifecycle.validate,{{name="A",dependencies={"Missing"}}})) end)
test("dependency cycle rejected",function() assert(not pcall(Lifecycle.validate,{{name="A",dependencies={"B"}},{name="B",dependencies={"A"}}})) end)
test("duplicate startup rejected",function() assert(not pcall(Lifecycle.validate,{{name="A"},{name="A"}})) end)
local started={}
local states=Lifecycle.start({{name="Broken"},{name="Dependent",dependencies={"Broken"}},{name="Independent"}},function(entry)
	return {start=function() started[entry.name]=true; if entry.name=="Broken" then error("injected failure") end end}
end)
local deadline=os.clock()+2
while states.Dependent.status=="pending" and os.clock()<deadline do task.wait(.05) end
test("failure blocks dependents but not unrelated services",function()
	assert(states.Broken.status=="failed" and states.Dependent.status=="blocked" and states.Independent.status=="ready")
	assert(not started.Dependent and started.Independent)
end)
local profile={Cash=200,Vehicles={v={CategoryId="bruiser"}},OwnedCockpitInstances={},OwnedModuleInstances={},Garage={Capacity=2,DisplaySpaces={},OwnedGarageProperties={}},Racing={Kept=true},Onboarding={Kept=true}}
local vehicles=profile.Vehicles
test("garage view preserves authoritative cash and inventory identity",function()
	assert(Compatibility.attach(profile,{Cash=0,Vehicles={},CurrentCategory="bruiser",OwnedCockpits={},GarageCapacity=2})==profile)
	assert(profile.Cash==200 and profile.Vehicles==vehicles)
end)
test("reward visible to garage without cache projection",function() local garage=profile; profile.Cash+=50; garage.Cash-=10; assert(profile.Cash==240) end)
test("persistent snapshot excludes runtime fields and preserves unrelated data",function()
	profile._Player=workspace; profile.ModuleColors={}; profile.CockpitColors={}
	local saved=Compatibility.persistent(profile)
	assert(saved._Player==nil and saved.ModuleColors==nil and saved.CockpitColors==nil and saved.CurrentCategory==nil)
	assert(saved.Cash==240 and saved.Vehicles==vehicles and saved.Racing.Kept and saved.Onboarding.Kept)
end)
test("garage commit retains racing onboarding and cash",function()
	Compatibility.commit(profile)
	assert(profile.Cash==240 and profile.Racing.Kept and profile.Onboarding.Kept and profile.Garage.DisplaySpaces.Space1.VehicleId=="v")
end)
return game.HttpService:JSONEncode({status="PASS",count=#passed,tests=passed,real_datastore_access=false})
