"""Build exact reversible edits from the frozen pre-phase mirror. Never edits the mirror."""
from pathlib import Path
import json
import subprocess
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
def read(path): return path.read_bytes().decode('utf-8')
def checksum(s):
    h=0
    for b in s.encode(): h=(h*31+b)%4294967296
    return h
def quote(s):
    eq='===='
    assert ']'+eq+']' not in s
    return '['+eq+'['+s+']'+eq+']'

records=[]
def source(path):
    # Immutable pre-phase Git blobs keep rebuilding possible after mirror refresh/commit.
    blobs={'ProfileService_Active.server.lua':'def63f8532458981193e2769eff6b416569c5308',
           'GarageActionController_Shadow_Disabled.server.lua':'deb07d6a0eb08a22a6da8a85f67b1b556b1b7756'}
    text=subprocess.check_output(['git','cat-file','blob',blobs[Path(path).name]],cwd=ROOT).decode('utf-8').replace('\r\n','\n')
    record={'path':path.replace('/', '.').replace('.server.lua',''),'before':text,'after':text,'edits':[]}
    records.append(record)
    return record
def replace(r,old,new):
    assert r['after'].count(old)==1, (r['path'],old[:100],r['after'].count(old))
    r['after']=r['after'].replace(old,new)
    r['edits'].append([old,new])
def block(r,start,end,new):
    text=r['after']; a=text.index(start); b=text.index(end,a)
    replace(r,text[a:b],new+'\n\n')

p=source('ServerScriptService/NeoTokyoRacers/Services/Player/ProfileService_Active.server.lua')
replace(p,'local sessions = {}','local ProfileStore = require(playerServices:WaitForChild("ProfileStore"))\nlocal sessions = {}')
replace(p,'local userId = player.UserId\n\tlocal cleanupTransaction', '''local userId = player.UserId
	local active = sessions[userId]
	if active and (active.Closing or active.Released or not active.Loaded
		or not active.NoSave and (active.LeaseUntil or 0) <= os.time()) then return nil end
	local cleanupTransaction''')
replace(p,'local loadedData = nil\n\tlocal loadError = nil\n\tif dataStoreEnabled() then\n\t\tlocal ok, result = pcall(function()\n\t\t\treturn getStore():GetAsync(profileKey(player))\n\t\tend)\n\t\tif ok then\n\t\t\tloadedData = result\n\t\telse\n\t\t\tloadError = tostring(result)\n\t\t\twarnLine("DataStore load failed for " .. player.Name .. ": " .. loadError)\n\t\tend\n\tend', '''local loadedData, loadError
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
	end''')
replace(p,'SessionId = HttpService:GenerateGUID(false),','SessionId = token,\n\t\tKey = profileKey(player),\n\t\tTransport = transport,\n\t\tLeaseUntil = leaseUntil,\n\t\tRevision = 0,')
replace(p,'DataStoreEnabledAtLoad = dataStoreEnabled(),','DataStoreEnabledAtLoad = enabledAtLoad,')
replace(p,'NoSave = studioVehicleSandbox,','NoSave = noSave,')
replace(p,'session.Dirty = true\n\tsession.LastDirtyReason', 'session.Dirty = true\n\tsession.Revision += 1\n\tsession.LastDirtyReason')
replace(p,'session.LastImportReason = tostring(reason or "unspecified")','session.Revision += 1\n\tsession.LastImportReason = tostring(reason or "unspecified")')
replace(p,'claims.Lookup[commandId] = true','session.Revision += 1\n\t\tclaims.Lookup[commandId] = true')
block(p,'local function saveProfile(player, force)','-- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1\n-- Canonical', '''local function saveProfile(player, force, release, deadline)
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
end''')
replace(p,'\t\tsaveProfile(player, true)\n\t\tif sessions[userId]', '\t\tcloseProfile(player)\n\t\t-- A concurrent shutdown close owns final removal until its write finishes.\n\t\twhile leavingSession.CloseStarted and not leavingSession.CloseFinished do task.wait(0.05) end\n\t\tif sessions[userId]')
block(p,'task.spawn(function()\n\twhile not shuttingDown do','log("ProfileService foundation active.', '''task.spawn(function()
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
end)''')

g=source('ServerScriptService/NeoTokyoRacers/Services/Garage/GarageActionController_Shadow_Disabled.server.lua')
replace(g,'local deadline = os.clock() + 5','local deadline = os.clock() + 30')
replace(g,'while os.clock() < deadline do','while os.clock() < deadline and player.Parent == Players do')
replace(g,'local savedProfile, loadMessage = V87_getProfileServiceProfile(player)','local savedProfile, loadMessage = V87_getProfileServiceProfile(player)\n\t\tif typeof(savedProfile) ~= "table" then error(loadMessage or "Profile is not ready.") end')
replace(g,'\tV56_invoke.OnServerInvoke = function(player, action, args)','''	local requestGuard = require(script.Parent:WaitForChild("GarageRequestGuard")).new()
	Players.PlayerRemoving:Connect(function(player) requestGuard.forget(player); V56_profiles[player.UserId] = nil end)
	local function handleGarageRequest(player, action, args)
		if player:GetAttribute("NTR_ProfileServiceLoaded") ~= true then
			local loaded = V87_getProfileServiceProfile(player)
			if not loaded then return {Ok=false,Success=false,Message="Your profile is still loading. Please try again."} end
		end''')
replace(g,'\t\tlocal profile = V56_getProfile(player)\n\t\treturn { Success = false, Message = "Garage server action failed: " .. tostring(result), Profile = V56_profileForClient(profile) }','\t\treturn { Success = false, Message = "Garage server action failed. Please try again." }')
replace(g,'''\tPlayers.PlayerAdded:Connect(function(player)
		V56_setLeaderstats(player, V56_getProfile(player))
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		V56_setLeaderstats(player, V56_getProfile(player))
	end''','''	V56_invoke.OnServerInvoke = function(player, action, args)
		return requestGuard.run(player, action, args, function() return handleGarageRequest(player, action, args) end)
	end
	local function initialiseGaragePlayer(player)
		local ok, message = pcall(function() V56_setLeaderstats(player, V56_getProfile(player)) end)
		if not ok and player.Parent == Players then warn("[Garage] Profile initialisation unavailable: " .. tostring(message)) end
	end
	Players.PlayerAdded:Connect(initialiseGaragePlayer)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(initialiseGaragePlayer, player) end''')

payload=[]
for r in records:
    payload.append('{path='+quote(r['path'])+',before='+str(checksum(r['before']))+',after='+str(checksum(r['after']))+',beforeBytes='+str(len(r['before'].encode()))+',afterBytes='+str(len(r['after'].encode()))+',edits={'+','.join('{'+quote(a)+','+quote(b)+'}' for a,b in r['edits'])+'}}')
modules=[]
for name,folder in [('ProfileStore','Player'),('GarageRequestGuard','Garage')]:
    modules.append('{path='+quote('ServerScriptService.NeoTokyoRacers.Services.'+folder)+',name='+quote(name)+',source='+quote(read(HERE/(name+'.lua')))+'}')
template=read(HERE/'installer_template.lua')
output=template.replace('--[[EDITS]]',','.join(payload)).replace('--[[MODULES]]',','.join(modules))
(ROOT/'scripts/roblox_architecture_phase2_persistence_safety.lua').write_text(output,encoding='utf-8',newline='\n')
(HERE/'expected.json').write_text(json.dumps([{k:v for k,v in r.items() if k not in ('before','after','edits')}|{'before':checksum(r['before']),'after':checksum(r['after'])} for r in records],indent=2))
print('Built installer',len(output.encode()),'bytes')
tests='local ProfileStore=(function()\n'+read(HERE/'ProfileStore.lua')+'\nend)()\nlocal GarageRequestGuard=(function()\n'+read(HERE/'GarageRequestGuard.lua')+'\nend)()\n'+read(HERE/'test_helpers.lua')
(ROOT/'scripts/roblox_architecture_phase2_safety_tests.lua').write_text(tests,encoding='utf-8',newline='\n')
