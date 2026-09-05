local ProfileStore=(function()
-- Pure transport helper: no profile ownership, global loops or DataStore lookup.
local ProfileStore = {}
ProfileStore.__index = ProfileStore
local TOKEN, UNTIL = "NTRSessionToken", "NTRSessionLeaseUntil"

function ProfileStore.new(store, options)
	options = options or {}
	return setmetatable({store=store, now=options.now or os.time, clock=options.clock or os.clock,
		wait=options.wait or task.wait, lease=options.lease or 180, attempts=options.attempts or 3}, ProfileStore)
end

function ProfileStore:update(key, transform, valid)
	local lastError = "Cancelled"
	for attempt = 1, self.attempts do
		if valid and not valid() then return false, "Cancelled" end
		local rejection
		local ok, value, info = pcall(function()
			return self.store:UpdateAsync(key, function(old, keyInfo)
				rejection = nil -- UpdateAsync may rerun this callback after a conflict.
				if valid and not valid() then rejection="Cancelled"; return nil end
				local metadata = keyInfo and table.clone(keyInfo:GetMetadata()) or {}
				local users = keyInfo and keyInfo:GetUserIds() or {}
				local nextValue, reason = transform(old, metadata)
				if nextValue == nil then rejection=reason or "Rejected"; return nil end
				return nextValue, users, metadata
			end)
		end)
		if ok then
			if rejection or value == nil then return false, rejection or "Rejected" end
			return true, value, info
		end
		lastError = tostring(value)
		if attempt < self.attempts then self.wait(attempt) end
	end
	return false, lastError
end

function ProfileStore:acquire(key, token, defaultData, valid)
	return self:update(key, function(old, metadata)
		if old ~= nil and type(old) ~= "table" then return nil, "InvalidStoredProfile" end
		if metadata[TOKEN] and metadata[TOKEN] ~= token and (tonumber(metadata[UNTIL]) or 0) > self.now() then
			return nil, "SessionLocked"
		end
		metadata[TOKEN], metadata[UNTIL] = token, self.now() + self.lease
		return old or defaultData
	end, valid)
end

function ProfileStore:write(key, token, data, release, valid)
	return self:update(key, function(old, metadata)
		if metadata[TOKEN] ~= token or (tonumber(metadata[UNTIL]) or 0) <= self.now() then
			return nil, "SessionLost"
		end
		if release then metadata[TOKEN], metadata[UNTIL] = nil, nil
		else metadata[UNTIL] = self.now() + self.lease end
		return data or old
	end, valid)
end

-- Serialises snapshot capture AND writes. No queued stale snapshots or unbounded waiters.
function ProfileStore:save(session, encode, release, deadline)
	if session.Released then return true, "Already closed" end
	if session.Saving then return false, "Busy" end
	session.Saving = true
	local revision = session.Revision or 0
	local ok, result, detail = pcall(function()
		if session.NoSave then return true, "Save suppressed" end
		local data = encode(session.Profile)
		local success, value, info = self:write(session.Key, session.SessionId, data, release, function()
			return not session.Released and (not deadline or self.clock() < deadline)
		end)
		if success and not release then
			local metadata = info and info:GetMetadata()
			session.LeaseUntil = metadata and metadata[UNTIL] or 0
		end
		return success, success and "Saved" or value
	end)
	session.Saving = false
	local success = ok and result == true
	if success then
		session.Dirty = (session.Revision or 0) ~= revision
		session.LastSaveUnix = self.now()
		session.LastError = ""
		if release then session.Released = true end
	else session.LastError = tostring(ok and detail or result) end
	return success, success and detail or session.LastError
end

return ProfileStore

end)()
local GarageRequestGuard=(function()
-- Bounded validation before expensive compatibility/profile work.
local Guard = {}
local actions = {}
for action in string.gmatch("EnsureCustomisationAccess GetInitial SelectVehicleInstance BuyCockpitInstance BuyModuleInstance EquipModuleInstance BuyGarageProperty UpgradeGarageCapacity BuyCockpit BuyVehicleCosmetic SetVehicleCosmeticColor SetAllNeonColor SetCockpitColor BuyModule SetModuleColor UpgradeModule Upgrade BuyNeon SetThrustColor DespawnVehicle ExitVehicle ReEnterVehicle SpawnOwnedVehicleFromFreeRoam SpawnVehicle", "%S+") do actions[action]=true end
local colours = {SetVehicleCosmeticColor=true,SetAllNeonColor=true,SetCockpitColor=true,SetModuleColor=true,SetThrustColor=true}
local strings = {CategoryId=true,CockpitId=true,ModuleId=true,VehicleId=true,SlotId=true,ModuleInstanceId=true,PropertyId=true,CosmeticId=true,Channel=true,Scope=true,UpgradeId=true}
local booleans = {AllowReassign=true,ReturnProfile=true}
local function finite(n) return n==n and math.abs(n)<math.huge end

function Guard.new(clock)
	local states = setmetatable({}, {__mode="k"})
	local api = {}
	clock = clock or os.clock
	function api.check(player, action, args)
		if type(action)~="string" or not actions[action] then return false,"Unknown garage action." end
		if args~=nil and type(args)~="table" then return false,"Invalid request." end
		local count=0
		for key,value in pairs(args or {}) do
			count+=1
			if count>20 then return false,"Request too large." end
			if strings[key] then
				if type(value)~="string" or #value>240 then return false,"Invalid identifier." end
			elseif booleans[key] then
				if type(value)~="boolean" then return false,"Invalid option." end
			elseif key=="Color" then
				if typeof(value)~="Color3" then return false,"Invalid colour." end
				for _,n in ipairs({value.R,value.G,value.B}) do if not finite(n) or n<0 or n>1 then return false,"Invalid colour." end end
			else return false,"Unknown request field." end
		end
		local now=clock()
		local state=states[player]
		if not state then state={time=now,tokens=120}; states[player]=state end
		state.tokens=math.min(120,state.tokens+math.max(0,now-state.time)*60); state.time=now
		local cost=colours[action] and 1 or 6
		if state.tokens<cost then return false,"Please wait before trying again." end
		state.tokens-=cost
		return true
	end
	function api.forget(player) states[player]=nil end
	function api.run(player, action, args, callback)
		local allowed, message = api.check(player, action, args)
		if not allowed then return {Ok=false,Success=false,Message=message} end
		local state=states[player]
		if state.busy then return {Ok=false,Success=false,Message="A garage request is already running. Please try again."} end
		state.busy=true
		local ok,result=pcall(callback)
		state.busy=false
		if not ok then warn("[GarageRequestGuard] "..tostring(result)); return {Ok=false,Success=false,Message="Garage request unavailable. Please try again."} end
		return result
	end
	return api
end
return Guard

end)()
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
