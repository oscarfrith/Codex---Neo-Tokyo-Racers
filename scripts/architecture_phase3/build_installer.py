"""Package one reversible migration. Sources/edits are fingerprinted; mirror is output only."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
def read(p): return p.read_text(encoding='utf-8')
def hash(s):
    h=0
    for b in s.encode(): h=(h*31+b)%4294967296
    return h
def q(s):
    eq='===='
    while ']'+eq+']' in s: eq+='='
    return '['+eq+'[\n'+s+']'+eq+']'
def expression(path): return 'game:GetService('+json.dumps(path.split('.')[0])+')'+''.join(':WaitForChild('+json.dumps(p)+')' for p in path.split('.')[1:])
manifest=json.loads(read(ROOT/'roblox/exported_scripts/manifest.json'))
old_package=json.loads(read(HERE/'migration.json')) if (HERE/'migration.json').exists() else None
old_index={r['old']:r for r in old_package or []}
names={
 'ProfileService_Active':'Player.ProfileServer', 'LegacyGarageProfileBridge_Active':'Player.ProfileCompatibilityServer',
 'OnboardingService_Active':'Player.OnboardingServer', 'ProfileStore':'Player.ProfileStore',
 'GarageActionController_Shadow_Disabled':'Garage.GarageServer', 'GarageSessionService_Active':'Garage.GarageSessionServer',
 'OwnedGarageService_Active':'Garage.OwnedGarageServer', 'IntroProgressService_Active':'Dealership.IntroProgressServer',
 'StudioCashGrantService_Active':'Development.StudioCashGrantServer',
 'VehicleAudioStateService_Active':'Audio.VehicleAudioServer',
 'FreeRoamHudTeleportService_Active':'World.FreeRoamTeleportServer',
 'TrafficLightService':'World.TrafficLightServer', 'LightingService_Active':'World.LightingServer',
 'VehicleCollisionLifecycleService_Active':'Vehicles.VehicleCollisionServer',
 'DriverSeatPositionService_Active':'Vehicles.DriverSeatServer',
 'VehicleAccessPromptService_Active':'Vehicles.VehicleAccessServer',
 'VehiclePerformanceRuntimeService_Active':'Vehicles.VehiclePerformanceServer',
 'VehiclePerformanceV2ShadowService_Active':'Development.VehiclePerformanceComparisonServer',
 'DriveToEarnCashService_Active':'Vehicles.DriveRewardsServer',
 'RaceMatchmakingService_Active':'Racing.MatchmakingServer', 'TimeTrialService_Active':'Racing.TimeTrialServer',
 'RaceRewardService_Active':'Racing.RaceRewardsServer', 'RacePersonalBestService_Active':'Racing.PersonalBestServer',
 'GlobalTimeTrialLeaderboardService_Active':'Racing.GlobalLeaderboardServer',
 'RaceBrowserTeleportService_Active':'Racing.RaceTeleportServer',
 'RaceDisplayNameService_Active':'Racing.RaceDisplayNameServer',
 'RaceSessionAssetService_Active':'Racing.RaceAssetsServer',
}
records=[]
rows=[r for r in manifest if r['roblox_path'].startswith('ServerScriptService.NeoTokyoRacers.Services.') and not r['disabled']]
for row in rows:
    path=row['roblox_path']; name=path.split('.')[-1]
    target='ServerStorage.Modules.Game.'+names.get(name,'Garage.'+name.removesuffix('Runtime'))
    if name=='GarageRequestGuard': target='ServerStorage.Modules.Game.Garage.GarageRequestGuard'
    src=read(ROOT/row['file'])
    if src.startswith('-- Phase 3 stateless compatibility adapter'):
        previous=old_index[path]
        mirror=next(r for r in manifest if r['roblox_path']==previous['new'])
        src=read(ROOT/mirror['file'])
        assert src.startswith(previous['prefix']) and src.endswith(previous['suffix'])
        src=src[len(previous['prefix']):len(src)-len(previous['suffix'])] if previous['suffix'] else src[len(previous['prefix']):]
        for before,after in reversed(previous['edits']):
            assert src.count(after)==1
            src=src.replace(after,before)
        assert hash(src)==previous['before']
        cls=previous['class']
    else: cls=row['class_name']
    records.append({'old':path,'new':target,'class':cls,'original':src,'body':src,'edits':[]})
def rec(name): return next(r for r in records if r['old'].endswith('.'+name))
def replace(r,a,b):
    assert r['body'].count(a)==1,(r['old'],a[:100],r['body'].count(a))
    r['body']=r['body'].replace(a,b); r['edits'].append([a,b])
def block(r,a,b,new):
    start=r['body'].index(a); stop=r['body'].index(b,start)
    replace(r,r['body'][start:stop],new+'\n\n')

p=rec('ProfileService_Active')
replace(p,'local sessions = {}','local Compatibility = require(game.ServerStorage.Modules.Game.Player.ProfileCompatibility)\nlocal sessions = {}')
block(p,'local function reconcileTableIdentity','local function saveProfile', '''local function importProfileSnapshot()
	return false, "Whole-profile import retired; use the authoritative feature command."
end

Service.get_profile = function(player)
	local session=sessionFor(player)
	return session and session.Profile or nil
end
Service.get_garage_profile = function(player, hydrate)
	local session=sessionFor(player)
	if not session then return nil end
	if not session.GarageViewReady then
		Compatibility.attach(session.Profile, hydrate(session.Profile))
		session.GarageViewReady=true
	end
	return session.Profile
end
Service.commit_garage = function(player, profile, reason, dirty)
	local session=sessionFor(player)
	if not session or session.Profile~=profile then return false, "Profile session changed." end
	Compatibility.commit(profile)
	if dirty then return markDirty(player, reason) end
	return true
end
Service.mark_dirty = function(player, profile, reason)
	local session=sessionFor(player)
	if not session or session.Profile~=profile then return false, "Profile session changed." end
	return markDirty(player, reason)
end''')
replace(p,'local data = schema.ToDataStore(profile)','local data = schema.ToDataStore(Compatibility.persistent(profile))')
replace(p,'return session and session.Profile or nil\nend\n\ngetSummaryBinding','return session and Compatibility.persistent(session.Profile) or nil\nend\n\ngetSummaryBinding')

# Extract the existing economy command implementation, retaining exact eligibility and rewards.
start=p['body'].index('-- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1\n-- Canonical')
end=p['body'].index('executeOwnedGarageCommandBinding.OnInvoke',start)
economy=p['body'][start:end]
dependencies=['ntr','sessionFor','economyCommandLocks','updateRuntimeMarker','executeEconomyCommandBinding','economyCashCommittedEvent','warnLine','Players']
economy_source='-- Cash command owner; ProfileServer provides the current authoritative session.\nlocal EconomyServer = {}\nfunction EconomyServer.init(context)\n'+''.join('local '+k+' = context.'+k+'\n' for k in dependencies)+economy+'\nend\nreturn EconomyServer\n'
replace(p,economy,'local EconomyServer = require(game.ServerStorage.Modules.Game.Player.EconomyServer)\nEconomyServer.init({'+','.join(k+'='+k for k in dependencies)+'})\n\n')

g=rec('GarageActionController_Shadow_Disabled')
replace(g,'local V56_profiles = {}','local ProfileServer = require(game.ServerStorage.Modules.Game.Player.ProfileServer)')
block(g,'\tlocal function V56_getProfile(player)','\t-- NTR_GARAGE_MODULE_INVENTORY_DUAL_OWNER_BRIDGE_V1', '''	local function V56_getProfile(player)
		local profile=ProfileServer.get_garage_profile(player, function(saved)
			return V87_profileHasSavedInstanceData(saved) and V87_savedProfileToLegacySession(saved) or V56_defaultProfile()
		end)
		if not profile then error("Profile is not ready.") end
		return V56_normalizeProfile(profile)
	end''')
block(g,'\tlocal function V80_getPersistenceBindings()','\t-- NTR_VEHICLE_PHASE_AK_PER_COCKPIT_COLOURS', '''	local function V80_mirrorLegacyProfileToPersistence(player, profile, action, dirty)
		local ok, message=ProfileServer.commit_garage(player,profile,"GarageAction:"..tostring(action),dirty==true)
		if not ok then error(message) end
	end''')
replace(g,'local legacy = V56_profiles[player.UserId]\n\t\t\tif legacy then legacy.Cash = math.max(0, math.floor(tonumber(committedCash) or 0)) end','local current = ProfileServer.get_profile(player)\n\t\t\tif current then committedCash=current.Cash end')
replace(g,'requestGuard.forget(player); V56_profiles[player.UserId] = nil','requestGuard.forget(player)')
replace(g,'local V80_persistenceBindings = nil','-- ProfileServer owns the only persistent profile table.')
replace(g,'local ok, message = pcall(function() V56_setLeaderstats(player, V56_getProfile(player)) end)',
        'local ok, message = pcall(function() if V87_getProfileServiceProfile(player) then V56_setLeaderstats(player, V56_getProfile(player)) end end)')
# Remove inactive legacy hydration/default-load helpers; main getter is now direct.
block(g,'\tlocal function V87_getProfileServiceProfile(player)','\tlocal function V87_profileHasSavedInstanceData', '''	local function V87_getProfileServiceProfile(player)
		local deadline=os.clock()+30
		repeat
			local profile=ProfileServer.get_profile(player)
			if profile then return profile end
			task.wait(0.1)
		until player.Parent~=Players or os.clock()>=deadline
		return nil,"Profile is not ready."
	end''')
block(g,'\tlocal function V87_tryHydrateProfileFromPersistence(player)','\tlocal function V56_getProfile(player)', '\t-- Garage hydration is owned by ProfileServer.get_garage_profile.')
# Duplicate legacy declarations carry no behaviour and obscure the resulting feature source.
for duplicate in ['\t\t\tModuleUpgradeLevels = {},\n\t\t\tModuleUpgradeLevels = {},\n\t\t\tModuleUpgradeLevels = {},','\t\tprofile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}\n\t\tprofile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}\n\t\tprofile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}']:
    replace(g,duplicate,duplicate.split('\n')[0])

r=rec('RaceRewardService_Active')
block(r,'local function profileBindings()','local function garageCashGrantBinding()', '''local ProfileServer = require(game.ServerStorage.Modules.Game.Player.ProfileServer)
local function profileFor(player)
	return ProfileServer.get_profile(player)
end
local function persistProfile(player, profile, reason)
	return ProfileServer.mark_dirty(player,profile,tostring(reason or "RaceReward"))
end''')
t=rec('TrafficLightService')
replace(t,'while true do','task.spawn(function()\nwhile true do')
replace(t,'\ttask.wait(UPDATE_RATE)\nend','\ttask.wait(UPDATE_RATE)\nend\nend)')
lighting=rec('LightingService_Active')
replace(lighting,'while true do','task.spawn(function()\nwhile true do')
replace(lighting,'\ttask.wait(1)\nend','\ttask.wait(1)\nend\nend)')

entries=[]
def dependencies(name):
    if name in ['ProfileServer','LightingServer','TrafficLightServer','VehicleAudioServer','VehiclePerformanceServer','VehiclePerformanceComparisonServer','DriverSeatServer','VehicleCollisionServer','RaceDisplayNameServer']: return []
    if name in ['GarageServer','ProfileCompatibilityServer','OnboardingServer','IntroProgressServer','DriveRewardsServer','PersonalBestServer']: return ['ProfileServer']
    if name in ['MatchmakingServer','TimeTrialServer']: return ['GarageServer','RaceRewardsServer','PersonalBestServer','RaceAssetsServer']
    return ['GarageServer']
for r in records:
    alias='-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.\nreturn require('+expression(r['new'])+')\n'
    context='local script = '+expression(r['old'])+'\n'
    if r['class']=='Script':
        r['prefix']='-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.\nlocal Service = {}\nlocal state\nfunction Service.start()\nif state then assert(state=="ready", "Service already starting or failed"); return end\nstate="starting"\nlocal ok,message=xpcall(function()\n'+context
        r['suffix']='\nend,debug.traceback)\nstate=ok and "ready" or "failed"\nassert(ok,message)\nend\nreturn Service\n'
        entries.append({'name':r['new'].split('.')[-1],'path':r['new'],'dependencies':dependencies(r['new'].split('.')[-1])})
    else: r['prefix']='-- Phase 3 canonical helper. Old paths only forward to this instance.\n'+context; r['suffix']=''
    r['before']=hash(r['original']); r['beforeBytes']=len(r['original'].encode())
    r['source']=r['prefix']+r['body']+r['suffix']; r['after']=hash(r['source']); r['afterBytes']=len(r['source'].encode()); r['adapter']=alias

entry_source='local entries = {\n'+''.join('{name='+q(e['name'])+',path='+q(e['path'])+',dependencies={'+','.join(q(d) for d in e['dependencies'])+'}},\n' for e in entries)+'}\n'
base='''-- Server composition root: explicit registrations; old paths contain adapters only.
local modules=game:GetService("ServerStorage"):WaitForChild("Modules")
local lifecycle=require(modules.Core.ServerLifecycle)
'''+entry_source+'''local state=Instance.new("Folder")
state.Name="StartupState"
state.Parent=script
lifecycle.start(entries,function(entry)
	local item=game
	for part in entry.path:gmatch("[^%.]+") do item=item:WaitForChild(part) end
	return require(item)
end,function(name,status,message)
	state:SetAttribute(name,status)
	if message then warn("[ServerBase] "..name.." "..status..": "..message) end
end)
'''
extras=[{'path':'ServerScriptService.ServerBase','class':'Script','source':base},
 {'path':'ServerStorage.Modules.Core.ServerLifecycle','class':'ModuleScript','source':read(HERE/'ServerLifecycle.lua')},
 {'path':'ServerStorage.Modules.Game.Player.ProfileCompatibility','class':'ModuleScript','source':read(HERE/'ProfileCompatibility.lua')},
 {'path':'ServerStorage.Modules.Game.Player.EconomyServer','class':'ModuleScript','source':economy_source}]
compact=[{k:v for k,v in r.items() if k not in ['original','body','source']} for r in records]
(HERE/'migration.json').write_text(json.dumps(compact,indent=2),encoding='utf-8')
def lua(v):
    if isinstance(v,str): return q(v)
    if isinstance(v,int): return str(v)
    if isinstance(v,list): return '{'+','.join(lua(x) for x in v)+'}'
    return '{'+','.join(k+'='+lua(x) for k,x in v.items())+'}'
installer=read(HERE/'installer_template.lua').replace('--[[RECORDS]]',','.join(lua(r) for r in compact)).replace('--[[EXTRAS]]',','.join(lua(r) for r in extras))
(ROOT/'scripts/roblox_architecture_phase3_server_organisation.lua').write_text(installer,encoding='utf-8',newline='\n')
print('Packaged',len(records),'implementations;',len(entries),'startup entries;',len(installer.encode()),'installer bytes')
# Readable projected outputs are local build evidence; authoritative installed sources are exported after install.
out=HERE/'projected'; out.mkdir(exist_ok=True)
for r in records: (out/(r['new'].removeprefix('ServerStorage.Modules.Game.')+'.lua')).write_text(r['source'],encoding='utf-8')
for e in extras: (out/(e['path'].split('.')[-1]+'.lua')).write_text(e['source'],encoding='utf-8')
tests='local Lifecycle=(function()\n'+read(HERE/'ServerLifecycle.lua')+'\nend)()\nlocal Compatibility=(function()\n'+read(HERE/'ProfileCompatibility.lua')+'\nend)()\n'+read(HERE/'test_helpers.lua')
(ROOT/'scripts/roblox_architecture_phase3_safety_tests.lua').write_text(tests,encoding='utf-8',newline='\n')
mapping='# Phase 3 installed server path map\n\nOld paths are stateless adapters; implementation and startup ownership are at the new paths. Two previously disabled server scripts remain disabled and unmoved.\n\n| Compatibility path | Canonical implementation | Startup |\n|---|---|---|\n'
for r in records:
    mapping+='| `'+r['old']+'` | `'+r['new']+'` | '+('ServerBase' if r['class']=='Script' else 'Required helper')+' |\n'
(ROOT/'docs/architecture/phase3-path-map.md').write_text(mapping,encoding='utf-8',newline='\n')
