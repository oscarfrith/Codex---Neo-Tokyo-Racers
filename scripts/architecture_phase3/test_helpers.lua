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
