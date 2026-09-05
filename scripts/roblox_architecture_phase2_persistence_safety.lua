-- Canonical Phase 2 installer. Run in Edit mode. Change MODE only for audit/rollback.
local MODE = "INSTALL" -- INSTALL | AUDIT | ROLLBACK
assert(game.PlaceId == 121304917315753, "Wrong place")
assert(not game:GetService("RunService"):IsRunning(), "Edit mode required")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK", "Unknown mode")
local edits = {{path=[====[ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService_Active]====],before=2125090400,after=63692043,beforeBytes=32612,afterBytes=34513,edits={{[====[local sessions = {}]====],[====[local ProfileStore = require(playerServices:WaitForChild("ProfileStore"))
local sessions = {}]====]},{[====[local userId = player.UserId
	local cleanupTransaction]====],[====[local userId = player.UserId
	local active = sessions[userId]
	if active and (active.Closing or active.Released or not active.Loaded
		or not active.NoSave and (active.LeaseUntil or 0) <= os.time()) then return nil end
	local cleanupTransaction]====]},{[====[local loadedData = nil
	local loadError = nil
	if dataStoreEnabled() then
		local ok, result = pcall(function()
			return getStore():GetAsync(profileKey(player))
		end)
		if ok then
			loadedData = result
		else
			loadError = tostring(result)
			warnLine("DataStore load failed for " .. player.Name .. ": " .. loadError)
		end
	end]====],[====[local loadedData, loadError
	local token = HttpService:GenerateGUID(false)
	local enabledAtLoad = dataStoreEnabled()
	local noSave = not enabledAtLoad or studioVehicleSandboxConfig() ~= nil
	local transport = ProfileStore.new(enabledAtLoad and getStore() or nil)
	local loadDeadline = os.clock() + 25
	local leaseUntil = 0
	local function currentLoad()
		return not shuttingDown and player.Parent == Players and profileLoadsInFlight[userId] == loadTicket
			and profileLoadGenerations[userId] == generation and os.clock() < loadDeadline
	end
	if enabledAtLoad then
		local ok, result, info
		if noSave then
			ok, result = pcall(function() return getStore():GetAsync(profileKey(player)) end)
		else
			ok, result, info = transport:acquire(profileKey(player), token,
				schema.ToDataStore(schema.FromDataStore(nil, startingCash())), currentLoad)
		end
		if ok then
			loadedData = result
			local metadata = info and info:GetMetadata()
			leaseUntil = metadata and metadata.NTRSessionLeaseUntil or 0
		else loadError = tostring(result) end
	end
	if not noSave and (loadError or not currentLoad()) then
		-- Release a successful but late acquisition without replacing its data.
		if not loadError then transport:write(profileKey(player), token, nil, true) end
		if profileLoadsInFlight[userId] == loadTicket then profileLoadsInFlight[userId] = nil end
		player:SetAttribute("NTR_ProfileServiceLoaded", false)
		warnLine("Profile unavailable player=" .. player.Name .. " reason=" .. tostring(loadError or "Cancelled"))
		if player.Parent == Players then player:Kick("Your data is temporarily unavailable or still open in another server. Please rejoin shortly.") end
		return nil
	end]====]},{[====[SessionId = HttpService:GenerateGUID(false),]====],[====[SessionId = token,
		Key = profileKey(player),
		Transport = transport,
		LeaseUntil = leaseUntil,
		Revision = 0,]====]},{[====[DataStoreEnabledAtLoad = dataStoreEnabled(),]====],[====[DataStoreEnabledAtLoad = enabledAtLoad,]====]},{[====[NoSave = studioVehicleSandbox,]====],[====[NoSave = noSave,]====]},{[====[session.Dirty = true
	session.LastDirtyReason]====],[====[session.Dirty = true
	session.Revision += 1
	session.LastDirtyReason]====]},{[====[session.LastImportReason = tostring(reason or "unspecified")]====],[====[session.Revision += 1
	session.LastImportReason = tostring(reason or "unspecified")]====]},{[====[claims.Lookup[commandId] = true]====],[====[session.Revision += 1
		claims.Lookup[commandId] = true]====]},{[====[local function saveProfile(player, force)
	local session = sessionFor(player)
	if not session then
		return false, "Profile is not loaded."
	end
	if session.NoSave == true then
		session.Dirty = false
		session.LastSaveUnix = os.time()
		session.LastError = "Studio vehicle sandbox; save suppressed."
		updateRuntimeMarker(player, session)
		return true, "Studio vehicle sandbox; save suppressed."
	end
	if not force and not session.Dirty then
		return true, "No changes to save."
	end
	local now = os.time()
	if not force and session.LastSaveAttemptUnix and now - session.LastSaveAttemptUnix < saveDebounceSeconds() then
		return true, "Save debounce active."
	end
	session.LastSaveAttemptUnix = now

	local encodeStarted = os.clock()
	local converted, encodedOrError = pcall(schema.ToDataStore, session.Profile)
	local encoded = converted and encodedOrError or nil
	local safe, jsonOrError = false, encodedOrError
	if converted then safe, jsonOrError = pcall(function() return HttpService:JSONEncode(encoded) end) end
	local encodeMilliseconds = (os.clock() - encodeStarted) * 1000
	if encodeMilliseconds >= math.max(1, tonumber(getAttr("ProfileEncodeWarnMilliseconds", 16)) or 16) then warnLine("PROFILE ENCODE SLOW " .. string.format("%.1f", encodeMilliseconds) .. "ms player=" .. player.Name .. " reason=" .. tostring(session.LastDirtyReason or "unknown")) end
	if not safe then
		session.LastError = tostring(jsonOrError)
		updateRuntimeMarker(player, session)
		return false, "Profile is not DataStore-safe: " .. tostring(jsonOrError)
	end

	if not dataStoreEnabled() then
		session.Dirty = false
		session.LastSaveUnix = now
		session.LastError = "DataStore disabled; dry-run save only."
		updateRuntimeMarker(player, session)
		return true, "DataStore disabled; dry-run save only."
	end

	local ok, result = pcall(function()
		return getStore():UpdateAsync(profileKey(player), function()
			return encoded
		end)
	end)
	if ok then
		session.Dirty = false
		session.LastSaveUnix = now
		session.LastError = ""
		updateRuntimeMarker(player, session)
		return true, "Saved."
	end

	session.LastError = tostring(result)
	updateRuntimeMarker(player, session)
	warnLine("DataStore save failed for " .. player.Name .. ": " .. tostring(result))
	return false, tostring(result)
end

]====],[====[local function saveProfile(player, force, release, deadline)
	local session = sessions[player.UserId]
	if not session or session.Player ~= player then return false, "Profile is not loaded." end
	if session.Closing and not release then return false, "Profile is closing." end
	if not force and os.time() - (session.LastSaveAttemptUnix or 0) < saveDebounceSeconds() then return false, "Debounced" end
	session.LastSaveAttemptUnix = os.time()
	local ok, message = session.Transport:save(session, function(profile)
		local data = schema.ToDataStore(profile)
		HttpService:JSONEncode(data) -- Reject non-serialisable values before any write.
		return data
	end, release, deadline)
	if message == "SessionLost" then
		session.Loaded = false
		player:SetAttribute("NTR_ProfileServiceLoaded", false)
		if player.Parent == Players then player:Kick("Your data session changed. Please rejoin.") end
	end
	if sessions[player.UserId] == session then updateRuntimeMarker(player, session) end
	if not ok and message ~= "Busy" then warnLine("Save failed player=" .. player.Name .. " reason=" .. tostring(message)) end
	return ok, message
end

local function closeProfile(player)
	local session = sessions[player.UserId]
	if not session or session.Player ~= player or session.CloseStarted then return end
	session.CloseStarted = true
	session.Closing = true
	player:SetAttribute("NTR_ProfileServiceLoaded", false)
	local deadline = os.clock() + 25
	while session.Saving and os.clock() < deadline do task.wait(0.05) end
	if not session.Saving and os.clock() < deadline then saveProfile(player, true, true, deadline) end
	session.CloseFinished = true
end

]====]},{[====[		saveProfile(player, true)
		if sessions[userId]]====],[====[		closeProfile(player)
		-- A concurrent shutdown close owns final removal until its write finishes.
		while leavingSession.CloseStarted and not leavingSession.CloseFinished do task.wait(0.05) end
		if sessions[userId]]====]},{[====[task.spawn(function()
	while not shuttingDown do
		task.wait(autosaveSeconds())
		for _, player in ipairs(Players:GetPlayers()) do
			local session = sessionFor(player)
			if session and session.Dirty then
				saveProfile(player, false)
			end
		end
	end
end)

game:BindToClose(function()
	shuttingDown = true
	if RunService:IsStudio() then
		task.wait(0.2)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		saveProfile(player, true)
	end
end)

]====],[====[task.spawn(function()
	while not shuttingDown do
		task.wait(5)
		for _, session in pairs(sessions) do
			if not session.Closing and not session.Saving then
				if not session.NoSave and (session.LeaseUntil or 0) <= os.time() then
					session.Loaded = false
					session.Player:SetAttribute("NTR_ProfileServiceLoaded", false)
					session.Player:Kick("Your data connection expired. Please rejoin.")
				elseif session.Dirty and os.time() - (session.LastSaveUnix or 0) >= autosaveSeconds()
					or not session.NoSave and (session.LeaseUntil or 0) - os.time() <= 120 then
					task.spawn(saveProfile, session.Player, false)
				end
			end
		end
	end
end)

game:BindToClose(function()
	shuttingDown = true
	local pending = {}
	for _, session in pairs(sessions) do
		table.insert(pending, session)
		task.spawn(closeProfile, session.Player)
	end
	local deadline = os.clock() + 27
	while os.clock() < deadline do
		local finished = true
		for _, session in ipairs(pending) do if not session.CloseFinished then finished = false; break end end
		if finished then break end
		task.wait(0.05)
	end
end)

]====]}}},{path=[====[ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled]====],before=3308656182,after=2692948007,beforeBytes=133518,afterBytes=134387,edits={{[====[local deadline = os.clock() + 5]====],[====[local deadline = os.clock() + 30]====]},{[====[while os.clock() < deadline do]====],[====[while os.clock() < deadline and player.Parent == Players do]====]},{[====[local savedProfile, loadMessage = V87_getProfileServiceProfile(player)]====],[====[local savedProfile, loadMessage = V87_getProfileServiceProfile(player)
		if typeof(savedProfile) ~= "table" then error(loadMessage or "Profile is not ready.") end]====]},{[====[	V56_invoke.OnServerInvoke = function(player, action, args)]====],[====[	local requestGuard = require(script.Parent:WaitForChild("GarageRequestGuard")).new()
	Players.PlayerRemoving:Connect(function(player) requestGuard.forget(player); V56_profiles[player.UserId] = nil end)
	local function handleGarageRequest(player, action, args)
		if player:GetAttribute("NTR_ProfileServiceLoaded") ~= true then
			local loaded = V87_getProfileServiceProfile(player)
			if not loaded then return {Ok=false,Success=false,Message="Your profile is still loading. Please try again."} end
		end]====]},{[====[		local profile = V56_getProfile(player)
		return { Success = false, Message = "Garage server action failed: " .. tostring(result), Profile = V56_profileForClient(profile) }]====],[====[		return { Success = false, Message = "Garage server action failed. Please try again." }]====]},{[====[	Players.PlayerAdded:Connect(function(player)
		V56_setLeaderstats(player, V56_getProfile(player))
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		V56_setLeaderstats(player, V56_getProfile(player))
	end]====],[====[	V56_invoke.OnServerInvoke = function(player, action, args)
		return requestGuard.run(player, action, args, function() return handleGarageRequest(player, action, args) end)
	end
	local function initialiseGaragePlayer(player)
		local ok, message = pcall(function() V56_setLeaderstats(player, V56_getProfile(player)) end)
		if not ok and player.Parent == Players then warn("[Garage] Profile initialisation unavailable: " .. tostring(message)) end
	end
	Players.PlayerAdded:Connect(initialiseGaragePlayer)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(initialiseGaragePlayer, player) end]====]}}}}
local modules = {{path=[====[ServerScriptService.NeoTokyoRacers.Services.Player]====],name=[====[ProfileStore]====],source=[====[-- Pure transport helper: no profile ownership, global loops or DataStore lookup.
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
]====]},{path=[====[ServerScriptService.NeoTokyoRacers.Services.Garage]====],name=[====[GarageRequestGuard]====],source=[====[-- Bounded validation before expensive compatibility/profile work.
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
]====]}}
local function find(path)
	local item=game
	for part in path:gmatch("[^%.]+") do
		local found
		for _,child in ipairs(item:GetChildren()) do if child.Name==part then assert(not found,"Ambiguous path "..path); found=child end end
		assert(found,"Missing "..path); item=found
	end
	return item
end
local function hash(s) local h=0 for i=1,#s do h=(h*31+s:byte(i))%4294967296 end return h end
local function replace(s,a,b)
	local first,last=s:find(a,1,true)
	assert(first and not s:find(a,last+1,true),"Source anchor changed")
	return s:sub(1,first-1)..b..s:sub(last+1)
end
local proposed={}
local installedCount=0
for _,edit in ipairs(edits) do
	local item=find(edit.path)
	assert(item:IsA("Script") and not item.Disabled,"Unexpected script state")
	local old=item.Source
	local installed=hash(old)==edit.after and #old==edit.afterBytes
	assert(installed or hash(old)==edit.before and #old==edit.beforeBytes,"Baseline changed: "..edit.path)
	if installed then installedCount+=1 end
	local target=old
	if MODE=="INSTALL" and not installed then for _,pair in ipairs(edit.edits) do target=replace(target,pair[1],pair[2]) end end
	if MODE=="ROLLBACK" and installed then for i=#edit.edits,1,-1 do local pair=edit.edits[i]; target=replace(target,pair[2],pair[1]) end end
	local expected=MODE=="ROLLBACK" and edit.before or MODE=="INSTALL" and edit.after or hash(old)
	assert(hash(target)==expected,"Result fingerprint mismatch")
	local compiled,message=loadstring(target,"="..edit.path); assert(compiled,message)
	table.insert(proposed,{item=item,old=old,source=target})
end
assert(installedCount==0 or installedCount==#edits,"Mixed baseline; inspect before proceeding")
for _,entry in ipairs(modules) do
	entry.parent=find(entry.path)
	entry.item=entry.parent:FindFirstChild(entry.name)
	if entry.item then assert(entry.item:IsA("ModuleScript") and entry.item.Source==entry.source,"Module changed: "..entry.name) end
	assert((installedCount==#edits)==(entry.item~=nil),"Incomplete module installation")
	local compiled,message=loadstring(entry.source,"="..entry.name); assert(compiled,message)
end
if MODE=="AUDIT" then return "PASS Phase 2 "..(installedCount==#edits and "installed" or "baseline") end
local created={}
local ok,message=pcall(function()
	if MODE=="INSTALL" then
		for _,entry in ipairs(modules) do if not entry.item then
			local item=Instance.new("ModuleScript"); table.insert(created,item)
			item.Name=entry.name; item.Source=entry.source; item.Parent=entry.parent; entry.item=item
		end end
	end
	for _,change in ipairs(proposed) do if change.item.Source~=change.source then change.item.Source=change.source end end
	for _,change in ipairs(proposed) do assert(change.item.Source==change.source,"Source write mismatch") end
	if MODE=="ROLLBACK" then for _,entry in ipairs(modules) do if entry.item then entry.item:Destroy() end end end
end)
if not ok then
	for _,change in ipairs(proposed) do change.item.Source=change.old end
	for _,item in ipairs(created) do item:Destroy() end
	error("Phase 2 restored previous sources: "..tostring(message))
end
return "PASS Phase 2 "..MODE.."; gameplay confirmation pending"
