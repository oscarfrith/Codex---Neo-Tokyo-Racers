-- Runner supplies actual ProfileStore and GarageRequestGuard source as lexical modules.
local passed={}
local function test(name,fn) fn(); table.insert(passed,name) end
local now=1000
local store={data=nil,metadata={Other="preserved"},users={123},failures=0,calls=0}
local function copy(v) if type(v)~="table" then return v end local r={} for k,x in pairs(v) do r[k]=copy(x) end return r end
function store:UpdateAsync(key,callback)
	self.calls+=1
	if self.failures>0 then self.failures-=1; error("injected outage") end
	local info={GetMetadata=function() return copy(self.metadata) end,GetUserIds=function() return copy(self.users) end}
	local data,users,metadata=callback(copy(self.data),info)
	if not data then return nil end
	if self.beforeCommit then self.beforeCommit(); self.beforeCommit=nil end
	self.data,self.users,self.metadata=copy(data),copy(users),copy(metadata)
	return copy(data),{GetMetadata=function() return copy(metadata) end}
end
local transport=ProfileStore.new(store,{now=function() return now end,wait=function() end})
test("acquire preserves value and metadata",function()
	assert(transport:acquire("p","a",{Cash=10})); assert(store.data.Cash==10 and store.metadata.Other=="preserved" and store.users[1]==123)
end)
test("second server rejected",function() local ok,err=transport:acquire("p","b",{Cash=0}); assert(not ok and err=="SessionLocked") end)
test("clean lease renewal",function() now+=60; assert(transport:write("p","a",{Cash=10})); assert(store.metadata.NTRSessionLeaseUntil==now+180) end)
test("retry bounded",function() store.failures=3; local calls=store.calls; assert(not transport:write("p","a",{Cash=0})); assert(store.calls-calls==3 and store.data.Cash==10) end)
test("retry recovers",function() store.failures=1; assert(transport:write("p","a",{Cash=11})); assert(store.data.Cash==11) end)
test("cancelled callback cannot write",function() assert(not transport:write("p","a",{Cash=0},false,function() return false end)); assert(store.data.Cash==11) end)
test("expired takeover fences stale writer",function()
	now+=181; assert(transport:acquire("p","b",{Cash=0})); local ok,err=transport:write("p","a",{Cash=0}); assert(not ok and err=="SessionLost" and store.data.Cash==11)
end)
test("release keeps profile and unrelated metadata",function() assert(transport:write("p","b",nil,true)); assert(store.data.Cash==11 and not store.metadata.NTRSessionToken and store.metadata.Other=="preserved") end)
test("invalid stored type rejected",function() local original=store.data; store.data="bad"; assert(not transport:acquire("p","c",{})); store.data=original end)
assert(transport:acquire("p","c",{}))
local session={Key="p",SessionId="c",Profile={Cash=20},Revision=1,Dirty=true}
test("mutation during save remains dirty and nested write is busy",function()
	store.beforeCommit=function()
		session.Profile.Cash=21; session.Revision+=1
		local ok,err=transport:save(session,copy); assert(not ok and err=="Busy")
	end
	assert(transport:save(session,copy)); assert(session.Dirty and store.data.Cash==20)
	assert(transport:save(session,copy)); assert(not session.Dirty and store.data.Cash==21)
end)
test("failed save retains dirty",function() session.Dirty=true; store.failures=3; assert(not transport:save(session,copy)); assert(session.Dirty and not session.Saving) end)
test("encoding failure releases mutex",function() assert(not transport:save(session,function() error("bad encode") end)); assert(not session.Saving and session.Dirty) end)
test("no-save session never accesses store",function() local calls=store.calls; assert(transport:save({NoSave=true},function() error("must not encode") end)); assert(store.calls==calls) end)
test("close releases once",function() assert(transport:save(session,copy,true)); local calls=store.calls; assert(transport:save(session,copy,true)); assert(store.calls==calls and not store.metadata.NTRSessionToken) end)
test("deadline rejects write",function() assert(transport:acquire("p","d",{})); local s={Key="p",SessionId="d",Profile={},Dirty=true}; assert(not transport:save(s,copy,true,0)); assert(s.Dirty and not s.Released) end)
local player={}
local guard=GarageRequestGuard.new(function() return now end)
test("valid action and colour",function() assert(guard.check(player,"SetCockpitColor",{Color=Color3.new(1,0,0),Channel="Primary",Scope="WholeVehicle"})) end)
test("invalid and oversized payloads rejected",function()
	assert(not guard.check(player,"Fake",{})); assert(not guard.check(player,"BuyCockpit",{CockpitId=string.rep("x",241)}))
	assert(not guard.check(player,"GetInitial",{Unknown={}})); assert(not guard.check(player,"SetCockpitColor",{Color=Color3.new(0/0,0,0)}))
end)
test("request budget refills and forget releases",function()
	guard.forget(player); for _=1,20 do assert(guard.check(player,"GetInitial",{})) end
	assert(not guard.check(player,"GetInitial",{})); now+=1; assert(guard.check(player,"GetInitial",{})); guard.forget(player)
end)
test("overlap rejected and request mutex released",function()
	local result=guard.run(player,"GetInitial",{},function()
		local nested=guard.run(player,"GetInitial",{},function() error("must not run") end); assert(not nested.Success)
		return {Success=true}
	end)
	assert(result.Success); assert(guard.run(player,"GetInitial",{},function() return {Success=true} end).Success)
end)
return game:GetService("HttpService"):JSONEncode({status="PASS",passed=passed,count=#passed,real_datastore_access=false})
