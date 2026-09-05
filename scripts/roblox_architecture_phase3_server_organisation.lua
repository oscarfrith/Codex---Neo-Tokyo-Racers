-- One Phase 3 migration/recovery entry point. Edit mode only; never publish here.
local MODE="INSTALL" -- INSTALL | AUDIT | ROLLBACK
assert(game.PlaceId==121304917315753,"Wrong place")
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","Unknown mode")
local records={{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Audio.VehicleAudioStateService_Active]====],new=[====[
ServerStorage.Modules.Game.Audio.VehicleAudioServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Audio"):WaitForChild("VehicleAudioStateService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=2615554809,beforeBytes=6665,after=2529740418,afterBytes=7217,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Audio"):WaitForChild("VehicleAudioServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Dealership.IntroProgressService_Active]====],new=[====[
ServerStorage.Modules.Game.Dealership.IntroProgressServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Dealership"):WaitForChild("IntroProgressService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=1517072554,beforeBytes=6098,after=1162808844,afterBytes=6651,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Dealership"):WaitForChild("IntroProgressServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Debug.StudioCashGrantService_Active]====],new=[====[
ServerStorage.Modules.Game.Development.StudioCashGrantServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Debug"):WaitForChild("StudioCashGrantService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=1375134817,beforeBytes=2933,after=1572056881,afterBytes=3483,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Development"):WaitForChild("StudioCashGrantServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled]====],new=[====[
ServerStorage.Modules.Game.Garage.GarageServer]====],class=[====[
Script]====],edits={{[====[
local V56_profiles = {}]====],[====[
local ProfileServer = require(game.ServerStorage.Modules.Game.Player.ProfileServer)]====]},{[====[
	local function V56_getProfile(player)
		local profile = V56_profiles[player.UserId]
		if not profile then
			profile = V87_tryHydrateProfileFromPersistence(player) or V56_defaultProfile()
			V56_profiles[player.UserId] = profile
		end
		return V56_normalizeProfile(profile)
	end

]====],[====[
	local function V56_getProfile(player)
		local profile=ProfileServer.get_garage_profile(player, function(saved)
			return V87_profileHasSavedInstanceData(saved) and V87_savedProfileToLegacySession(saved) or V56_defaultProfile()
		end)
		if not profile then error("Profile is not ready.") end
		return V56_normalizeProfile(profile)
	end

]====]},{[====[
	local function V80_getPersistenceBindings()
		if V80_persistenceBindings then
			return V80_persistenceBindings
		end
		local servicesRoot = script.Parent and script.Parent.Parent
		local playerServices = servicesRoot and servicesRoot:FindFirstChild("Player")
		local profileBindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
		local bridgeBindings = playerServices and playerServices:FindFirstChild("LegacyGarageProfileBridgeBindings")
		local getProfile = profileBindings and profileBindings:FindFirstChild("GetProfile")
		local markDirty = profileBindings and profileBindings:FindFirstChild("MarkDirty")
		local importProfileSnapshot = profileBindings and profileBindings:FindFirstChild("ImportProfileSnapshot")
		local convert = bridgeBindings and bridgeBindings:FindFirstChild("ConvertLegacyProfile")
		if getProfile and markDirty and importProfileSnapshot and convert then
			V80_persistenceBindings = {
				GetProfile = getProfile,
				MarkDirty = markDirty,
				ImportProfileSnapshot = importProfileSnapshot,
				ConvertLegacyProfile = convert,
			}
		end
		return V80_persistenceBindings
	end

	local function V80_mirrorLegacyProfileToPersistence(player, profile, action, markDirty)
		local bindings = V80_getPersistenceBindings()
		if not bindings then
			return
		end
		local okConvert, converted = pcall(function()
			return bindings.ConvertLegacyProfile:Invoke(profile, { PreserveLegacyCapacity = true })
		end)
		if not okConvert or typeof(converted) ~= "table" then
			warn("[NTR Persistence Phase 4] Legacy profile conversion failed: " .. tostring(converted))
			return
		end
		-- NTR_OWNED_GARAGE_PHASE6_PERSISTENCE_PRESERVE_V1
		local currentSaved=bindings.GetProfile:Invoke(player); if typeof(currentSaved)=="table" and typeof(currentSaved.OwnedGarage)=="table" then converted.OwnedGarage=V87_cloneValue(currentSaved.OwnedGarage) end
		local okImport, importOk, importMessage = pcall(function()
			-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT
			return bindings.ImportProfileSnapshot:Invoke(player, converted, "GarageAction:" .. tostring(action or "Unknown"), markDirty == true)
		end)
		if not okImport or importOk ~= true then
			warn("[NTR Persistence Phase 5] ProfileService snapshot import failed: " .. tostring(importOk or importMessage))
			return
		end
		player:SetAttribute("NTR_PersistenceMirrorLastAction", tostring(action or "Unknown"))
		player:SetAttribute("NTR_PersistenceMirrorVehicleCount", V80_countDictionary(converted.Vehicles))
		player:SetAttribute("NTR_PersistenceMirrorModuleInstanceCount", V80_countDictionary(converted.OwnedModuleInstances))
		-- Dirty marking is owned by ImportProfileSnapshot after Phase 5.
	end

]====],[====[
	local function V80_mirrorLegacyProfileToPersistence(player, profile, action, dirty)
		local ok, message=ProfileServer.commit_garage(player,profile,"GarageAction:"..tostring(action),dirty==true)
		if not ok then error(message) end
	end

]====]},{[====[
local legacy = V56_profiles[player.UserId]
			if legacy then legacy.Cash = math.max(0, math.floor(tonumber(committedCash) or 0)) end]====],[====[
local current = ProfileServer.get_profile(player)
			if current then committedCash=current.Cash end]====]},{[====[
requestGuard.forget(player); V56_profiles[player.UserId] = nil]====],[====[
requestGuard.forget(player)]====]},{[====[
local V80_persistenceBindings = nil]====],[====[
-- ProfileServer owns the only persistent profile table.]====]},{[====[
local ok, message = pcall(function() V56_setLeaderstats(player, V56_getProfile(player)) end)]====],[====[
local ok, message = pcall(function() if V87_getProfileServiceProfile(player) then V56_setLeaderstats(player, V56_getProfile(player)) end end)]====]},{[====[
	local function V87_getProfileServiceProfile(player)
		local getProfile = nil
		local deadline = os.clock() + 30
		while os.clock() < deadline and player.Parent == Players do
			local servicesRoot = script.Parent and script.Parent.Parent
			local playerServices = servicesRoot and servicesRoot:FindFirstChild("Player")
			local profileBindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
			getProfile = profileBindings and profileBindings:FindFirstChild("GetProfile")
			if getProfile and getProfile:IsA("BindableFunction") then
				local ok, profileOrError = pcall(function()
					return getProfile:Invoke(player)
				end)
				if ok and typeof(profileOrError) == "table" then
					return profileOrError, nil
				end
				if not ok then
					return nil, tostring(profileOrError)
				end
			end
			task.wait(0.1)
		end
		return nil, "ProfileService profile not loaded"
	end

]====],[====[
	local function V87_getProfileServiceProfile(player)
		local deadline=os.clock()+30
		repeat
			local profile=ProfileServer.get_profile(player)
			if profile then return profile end
			task.wait(0.1)
		until player.Parent~=Players or os.clock()>=deadline
		return nil,"Profile is not ready."
	end

]====]},{[====[
	local function V87_tryHydrateProfileFromPersistence(player)
		local savedProfile, loadMessage = V87_getProfileServiceProfile(player)
		if typeof(savedProfile) ~= "table" then error(loadMessage or "Profile is not ready.") end
		if not V87_profileHasSavedInstanceData(savedProfile) then
			player:SetAttribute("NTR_PersistencePhase18Hydrated", false)
			player:SetAttribute("NTR_PersistencePhase18HydrationSource", tostring(loadMessage or "NoSavedInstanceData"))
			player:SetAttribute("NTR_PersistencePhase18SavedVehicleCount", 0)
			return nil
		end
		local legacy = V87_savedProfileToLegacySession(savedProfile)
		player:SetAttribute("NTR_PersistencePhase18Hydrated", true)
		player:SetAttribute("NTR_PersistencePhase18HydrationSource", "ProfileService")
		player:SetAttribute("NTR_PersistencePhase18SavedVehicleCount", V87_countDictionary(savedProfile.Vehicles))
		player:SetAttribute("NTR_PersistencePhase18SavedModuleInstanceCount", V87_countDictionary(savedProfile.OwnedModuleInstances))
		return legacy
	end

]====],[====[
	-- Garage hydration is owned by ProfileServer.get_garage_profile.

]====]},{[====[
			ModuleUpgradeLevels = {},
			ModuleUpgradeLevels = {},
			ModuleUpgradeLevels = {},]====],[====[
			ModuleUpgradeLevels = {},]====]},{[====[
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}]====],[====[
		profile.ModuleUpgradeLevels = profile.ModuleUpgradeLevels or {}]====]}},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageActionController_Shadow_Disabled")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=2692948007,beforeBytes=134387,after=1134469953,afterBytes=130853,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageDisplayRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.GarageDisplay]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageDisplayRuntime")
]====],suffix=[====[
]====],before=2399818308,beforeBytes=11330,after=2936772542,afterBytes=11570,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageDisplay"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageModuleInstanceCustomizationRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.GarageModuleInstanceCustomization]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageModuleInstanceCustomizationRuntime")
]====],suffix=[====[
]====],before=2988286642,beforeBytes=7776,after=2984709020,afterBytes=8036,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageModuleInstanceCustomization"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageModuleInventoryRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.GarageModuleInventory]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageModuleInventoryRuntime")
]====],suffix=[====[
]====],before=1672445457,beforeBytes=9962,after=301096217,afterBytes=10210,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageModuleInventory"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageModuleTransactionRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.GarageModuleTransaction]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageModuleTransactionRuntime")
]====],suffix=[====[
]====],before=2391429570,beforeBytes=7468,after=2351138444,afterBytes=7718,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageModuleTransaction"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageProfileRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.GarageProfile]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageProfileRuntime")
]====],suffix=[====[
]====],before=3507847032,beforeBytes=5418,after=3648589401,afterBytes=5658,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageProfile"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageRequestGuard]====],new=[====[
ServerStorage.Modules.Game.Garage.GarageRequestGuard]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageRequestGuard")
]====],suffix=[====[
]====],before=2630243863,beforeBytes=2993,after=4142602941,afterBytes=3231,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageRequestGuard"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.GarageSessionService_Active]====],new=[====[
ServerStorage.Modules.Game.Garage.GarageSessionServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("GarageSessionService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=2355667481,beforeBytes=7096,after=4157498565,afterBytes=7645,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("GarageSessionServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageAuthoritativeCommandRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.OwnedGarageAuthoritativeCommand]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("OwnedGarageAuthoritativeCommandRuntime")
]====],suffix=[====[
]====],before=186271225,beforeBytes=4544,after=419840032,afterBytes=4802,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageAuthoritativeCommand"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageDisplayAssignmentRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.OwnedGarageDisplayAssignment]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("OwnedGarageDisplayAssignmentRuntime")
]====],suffix=[====[
]====],before=1043716484,beforeBytes=5581,after=2734106602,afterBytes=5836,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageDisplayAssignment"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageDisplayRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.OwnedGarageDisplay]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("OwnedGarageDisplayRuntime")
]====],suffix=[====[
]====],before=1147453587,beforeBytes=8807,after=3382603846,afterBytes=9052,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageDisplay"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageFinishRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.OwnedGarageFinish]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("OwnedGarageFinishRuntime")
]====],suffix=[====[
]====],before=2581289191,beforeBytes=12936,after=534056485,afterBytes=13180,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageFinish"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageInteriorRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.OwnedGarageInterior]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("OwnedGarageInteriorRuntime")
]====],suffix=[====[
]====],before=1251343402,beforeBytes=4402,after=4252236677,afterBytes=4648,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageInterior"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageManagementRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.OwnedGarageManagement]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("OwnedGarageManagementRuntime")
]====],suffix=[====[
]====],before=3543335456,beforeBytes=70576,after=654250254,afterBytes=70824,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageManagement"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageProfileRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.OwnedGarageProfile]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("OwnedGarageProfileRuntime")
]====],suffix=[====[
]====],before=804084785,beforeBytes=24622,after=915531013,afterBytes=24867,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageProfile"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.OwnedGarageService_Active]====],new=[====[
ServerStorage.Modules.Game.Garage.OwnedGarageServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("OwnedGarageService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=1329855305,beforeBytes=342,after=3665273938,afterBytes=889,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("OwnedGarageServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Garage.VehicleCosmeticServerRuntime]====],new=[====[
ServerStorage.Modules.Game.Garage.VehicleCosmeticServer]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage"):WaitForChild("VehicleCosmeticServerRuntime")
]====],suffix=[====[
]====],before=1085600290,beforeBytes=4709,after=990022245,afterBytes=4957,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Garage"):WaitForChild("VehicleCosmeticServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Player.LegacyGarageProfileBridge_Active]====],new=[====[
ServerStorage.Modules.Game.Player.ProfileCompatibilityServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Player"):WaitForChild("LegacyGarageProfileBridge_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=3437380280,beforeBytes=2104,after=1754596778,afterBytes=2658,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("ProfileCompatibilityServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Player.OnboardingService_Active]====],new=[====[
ServerStorage.Modules.Game.Player.OnboardingServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Player"):WaitForChild("OnboardingService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=2568388989,beforeBytes=5635,after=1085628919,afterBytes=6181,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("OnboardingServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService_Active]====],new=[====[
ServerStorage.Modules.Game.Player.ProfileServer]====],class=[====[
Script]====],edits={{[====[
local sessions = {}]====],[====[
local Compatibility = require(game.ServerStorage.Modules.Game.Player.ProfileCompatibility)
local sessions = {}]====]},{[====[
local function reconcileTableIdentity(target, source, visited)
	-- Preserve all existing authoritative table identities while adopting normalized values.
	if target == source then return end
	visited = visited or {}
	if visited[target] == source then return end
	visited[target] = source
	for key in pairs(target) do
		if source[key] == nil then target[key] = nil end
	end
	for key, sourceValue in pairs(source) do
		local targetValue = target[key]
		if typeof(targetValue) == "table" and typeof(sourceValue) == "table" then
			reconcileTableIdentity(targetValue, sourceValue, visited)
		else
			target[key] = sourceValue
		end
	end
end

local function importProfileSnapshot(player, snapshot, reason, dirty)
	-- NTR_PERSISTENCE_PHASE5_IMPORT_PROFILE_SNAPSHOT
	local cleanupTransaction = player and garageCleanupTransactions[player.UserId]
	if cleanupTransaction then
		cleanupTransaction.BlockedCount += 1
		cleanupTransaction.LastBlockedReason = tostring(reason or "unspecified")
		warnLine("PROFILE IMPORT BLOCKED during garage inventory cleanup player=" .. player.Name
			.. " reason=" .. cleanupTransaction.LastBlockedReason)
		return false, "Profile import blocked during garage inventory cleanup transaction."
	end
	local session = sessionFor(player)
	if not session then
		return false, "Profile is not loaded."
	end
	if typeof(snapshot) ~= "table" then
		return false, "Snapshot must be a table."
	end
	local normalized = schema.Normalize(snapshot, startingCash())
	-- Generic garage/racing snapshots do not own authoritative onboarding state.
	normalized.Onboarding = session.Profile.Onboarding -- NTR_PROFILE_SERVICE_ONBOARDING_IMPORT_PROTECTION_V1
	if normalized ~= session.Profile then
		reconcileTableIdentity(session.Profile, normalized)
	end
	session.Revision += 1
	session.LastImportReason = tostring(reason or "unspecified")
	if dirty then
		session.Dirty = true
		session.LastDirtyReason = tostring(reason or "ImportProfileSnapshot")
	end
	updateRuntimeMarker(player, session)
	return true, "Imported profile snapshot."
end

]====],[====[
local function importProfileSnapshot()
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
end

]====]},{[====[
local data = schema.ToDataStore(profile)]====],[====[
local data = schema.ToDataStore(Compatibility.persistent(profile))]====]},{[====[
return session and session.Profile or nil
end

getSummaryBinding]====],[====[
return session and Compatibility.persistent(session.Profile) or nil
end

getSummaryBinding]====]},{[====[
-- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1
-- Canonical positive-Cash command boundary. Callers provide server-authored intent;
-- this owner validates the current ProfileService session and mutates session.Profile.
local ECONOMY_COMMAND_VERSION = 1
local GENERIC_GRANT_REASONS = {
	RaceReward = true,
	TimeTrialReward = true,
	StudioCashGrantHotkey = true,
}

local function economyConfig()
	local runtime = ntr:FindFirstChild("Config") and ntr.Config:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("DriveToEarnCash_EditAttributes")
end

local function economyNumber(name, fallback, minimum, maximum)
	local folder = economyConfig()
	local value = tonumber(folder and folder:GetAttribute(name)) or fallback
	if minimum ~= nil then value = math.max(minimum, value) end
	if maximum ~= nil then value = math.min(maximum, value) end
	return value
end

local function setCommittedCashProjection(player, cash)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local value = leaderstats:FindFirstChild("Cash")
	if value and not value:IsA("IntValue") then
		return false, "leaderstats.Cash must be an IntValue."
	end
	if not value then
		value = Instance.new("IntValue")
		value.Name = "Cash"
		value.Parent = leaderstats
	end
	value.Value = math.max(0, math.floor(tonumber(cash) or 0))
	return true
end

local function validateDriveVehicle(player, session, command)
	local vehicle = command.Vehicle
	local vehicleId = tostring(command.VehicleId or "")
	if not (vehicle and vehicle:IsA("Model") and vehicle.Parent) then
		return false, "VehicleMissing"
	end
	local world = workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
	if not (vehicles and vehicle.Parent == vehicles) then
		return false, "NotRuntimeVehicle"
	end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId
		or tonumber(vehicle:GetAttribute("DriverUserId")) ~= player.UserId then
		return false, "OwnershipMismatch"
	end
	if vehicleId == "" or tostring(vehicle:GetAttribute("OwnedVehicleId") or "") ~= vehicleId then
		return false, "VehicleIdentityMismatch"
	end
	if typeof(session.Profile.Vehicles) ~= "table" or typeof(session.Profile.Vehicles[vehicleId]) ~= "table" then
		return false, "VehicleNotOwned"
	end
	if tostring(session.Profile.CurrentVehicleId or "") ~= vehicleId then
		return false, "VehicleNotCurrent"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle) and seat.Occupant == humanoid) then
		return false, "Unseated"
	end
	if vehicle:GetAttribute("DriveReady") ~= true then return false, "NotDriveReady" end
	if vehicle:GetAttribute("NTR_RaceFrozen") == true or vehicle.PrimaryPart and vehicle.PrimaryPart.Anchored then
		return false, "FrozenOrStaging"
	end
	if vehicle:GetAttribute("ParkedShowcase") == true or vehicle:GetAttribute("NTR_ParkedFixed") == true then
		return false, "Parked"
	end
	if vehicle:GetAttribute("NTR_ExitCoasting") == true then return false, "ExitCoasting" end
	if vehicle:GetAttribute("NTR_RaceBrowserTeleportDespawn") == true
		or vehicle:GetAttribute("NTR_FreeRoamHudTeleportDespawn") == true then
		return false, "TeleportOrTransition"
	end
	return true
end

executeEconomyCommandBinding.OnInvoke = function(player, command)
	if not (player and player:IsA("Player") and player.Parent == Players) then
		return {Ok=false, Success=false, Message="Player lifecycle is not active.", RejectionReason="PlayerLifecycle"}
	end
	command = typeof(command) == "table" and command or {}
	if math.floor(tonumber(command.Version) or 0) ~= ECONOMY_COMMAND_VERSION then
		return {Ok=false, Success=false, Message="Unsupported economy command version.", RejectionReason="CommandVersion"}
	end
	local session = sessionFor(player)
	if not session then
		return {Ok=false, Success=false, Message="Profile is not loaded.", RejectionReason="ProfileNotLoaded"}
	end
	if command.ExpectedSessionGeneration ~= nil
		and tonumber(command.ExpectedSessionGeneration) ~= session.SessionGeneration then
		return {Ok=false, Success=false, Message="Profile session generation changed.", RejectionReason="SessionChanged"}
	end
	if command.ExpectedSessionId ~= nil and tostring(command.ExpectedSessionId) ~= session.SessionId then
		return {Ok=false, Success=false, Message="Profile session identity changed.", RejectionReason="SessionChanged"}
	end
	local userId = player.UserId
	if economyCommandLocks[userId] then
		return {Ok=false, Success=false, Message="Economy command already in progress.", RejectionReason="Busy", Busy=true}
	end
	economyCommandLocks[userId] = session
	local expectedGeneration = session.SessionGeneration
	local expectedId = session.SessionId
	local action = tostring(command.Action or "")

	local ok, result = pcall(function()
		if action == "ValidateDriveSample" or action == "GrantDriveCash" then
			local valid, reason = validateDriveVehicle(player, session, command)
			if not valid then
				return {Ok=false, Success=false, Message="Drive sample rejected: "..reason, RejectionReason=reason}
			end
			if action == "ValidateDriveSample" then
				return {
					Ok=true, Success=true, Valid=true,
					SessionGeneration=expectedGeneration, SessionId=expectedId,
					VehicleId=tostring(command.VehicleId or ""),
				}
			end
		elseif action == "GrantCash" then
			if not GENERIC_GRANT_REASONS[tostring(command.Reason or "")] then
				return {Ok=false, Success=false, Message="Generic Cash grant reason is not allowed.", RejectionReason="ReasonNotAllowed"}
			end
		else
			return {Ok=false, Success=false, Message="Unknown economy command.", RejectionReason="UnknownAction"}
		end

		local amount = math.floor(tonumber(command.Amount) or 0)
		if amount <= 0 then
			return {Ok=false, Success=false, Message="Cash amount must be a positive whole number.", RejectionReason="InvalidAmount"}
		end
		local commandId = tostring(command.CommandId or "")
		if commandId == "" or #commandId > 240 then
			return {Ok=false, Success=false, Message="A bounded economy command ID is required.", RejectionReason="CommandId"}
		end
		session.EconomyClaims = session.EconomyClaims or {Lookup={}, Order={}}
		local claims = session.EconomyClaims
		if claims.Lookup[commandId] then
			return {
				Ok=true, Success=true, Amount=0, Cash=math.max(0,math.floor(tonumber(session.Profile.Cash) or 0)),
				AlreadyCommitted=true, SessionGeneration=expectedGeneration, SessionId=expectedId,
			}
		end
		local maximum = action == "GrantDriveCash"
			and economyNumber("MaximumDriveGrantPerCommand", 1000, 1, 100000)
			or 1000000
		if amount > maximum then
			return {Ok=false, Success=false, Message="Cash amount exceeds the command limit.", RejectionReason="AmountLimit"}
		end
		local current = sessionFor(player)
		if current ~= session or current.SessionGeneration ~= expectedGeneration or current.SessionId ~= expectedId then
			return {Ok=false, Success=false, Message="Profile session changed before Cash commit.", RejectionReason="SessionChanged"}
		end
		local oldCash = math.max(0, math.floor(tonumber(session.Profile.Cash) or 0))
		local oldDirty = session.Dirty
		local oldDirtyReason = session.LastDirtyReason
		local newCash = oldCash + amount
		if newCash > 2000000000 then
			return {Ok=false, Success=false, Message="Cash balance safety limit reached.", RejectionReason="BalanceLimit"}
		end
		session.Profile.Cash = newCash
		session.Dirty = true
		session.LastDirtyReason = "EconomyCommand:" .. tostring(command.Reason or action)
		updateRuntimeMarker(player, session)
		local projected, projectionMessage = setCommittedCashProjection(player, newCash)
		if not projected then
			session.Profile.Cash = oldCash
			session.Dirty = oldDirty
			session.LastDirtyReason = oldDirtyReason
			updateRuntimeMarker(player, session)
			return {Ok=false, Success=false, Message=projectionMessage, RejectionReason="ProjectionFailed"}
		end
		session.Revision += 1
		claims.Lookup[commandId] = true
		table.insert(claims.Order, commandId)
		while #claims.Order > 256 do
			local expired = table.remove(claims.Order, 1)
			claims.Lookup[expired] = nil
		end
		player:SetAttribute("NTR_LastEconomyCommand", action)
		player:SetAttribute("NTR_LastEconomyGrantAmount", amount)
		player:SetAttribute("NTR_LastEconomyGrantReason", tostring(command.Reason or action))
		economyCashCommittedEvent:Fire(player, newCash, {
			Version=ECONOMY_COMMAND_VERSION,
			Action=action,
			Amount=amount,
			Reason=tostring(command.Reason or action),
			CommandId=commandId,
			SessionGeneration=expectedGeneration,
			SessionId=expectedId,
		})
		return {
			Ok=true, Success=true, Amount=amount, Cash=newCash,
			SessionGeneration=expectedGeneration, SessionId=expectedId,
		}
	end)
	if economyCommandLocks[userId] == session then economyCommandLocks[userId] = nil end
	if not ok then
		warnLine("ECONOMY COMMAND FAILED player="..player.Name.." action="..action.." error="..tostring(result))
		return {Ok=false, Success=false, Message="Economy command failed.", RejectionReason="CommandError"}
	end
	return result
end

]====],[====[
local EconomyServer = require(game.ServerStorage.Modules.Game.Player.EconomyServer)
EconomyServer.init({ntr=ntr,sessionFor=sessionFor,economyCommandLocks=economyCommandLocks,updateRuntimeMarker=updateRuntimeMarker,executeEconomyCommandBinding=executeEconomyCommandBinding,economyCashCommittedEvent=economyCashCommittedEvent,warnLine=warnLine,Players=Players})

]====]}},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Player"):WaitForChild("ProfileService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=63692043,beforeBytes=34513,after=1739506812,afterBytes=25190,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("ProfileServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Player.ProfileStore]====],new=[====[
ServerStorage.Modules.Game.Player.ProfileStore]====],class=[====[
ModuleScript]====],edits={},prefix=[====[
-- Phase 3 canonical helper. Old paths only forward to this instance.
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Player"):WaitForChild("ProfileStore")
]====],suffix=[====[
]====],before=3603268762,beforeBytes=3574,after=197142707,afterBytes=3806,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Player"):WaitForChild("ProfileStore"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Racing.GlobalTimeTrialLeaderboardService_Active]====],new=[====[
ServerStorage.Modules.Game.Racing.GlobalLeaderboardServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):WaitForChild("GlobalTimeTrialLeaderboardService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=1247387726,beforeBytes=5447,after=2848731287,afterBytes=6009,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("GlobalLeaderboardServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Racing.RaceBrowserTeleportService_Active]====],new=[====[
ServerStorage.Modules.Game.Racing.RaceTeleportServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):WaitForChild("RaceBrowserTeleportService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=2772966439,beforeBytes=7740,after=3850832337,afterBytes=8295,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceTeleportServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Racing.RaceDisplayNameService_Active]====],new=[====[
ServerStorage.Modules.Game.Racing.RaceDisplayNameServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):WaitForChild("RaceDisplayNameService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=3527690850,beforeBytes=2585,after=153412042,afterBytes=3136,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceDisplayNameServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active]====],new=[====[
ServerStorage.Modules.Game.Racing.MatchmakingServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):WaitForChild("RaceMatchmakingService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=1920684373,beforeBytes=46825,after=1963826068,afterBytes=47376,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("MatchmakingServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Racing.RacePersonalBestService_Active]====],new=[====[
ServerStorage.Modules.Game.Racing.PersonalBestServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):WaitForChild("RacePersonalBestService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=2397281796,beforeBytes=11700,after=3778384563,afterBytes=12252,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("PersonalBestServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Racing.RaceRewardService_Active]====],new=[====[
ServerStorage.Modules.Game.Racing.RaceRewardsServer]====],class=[====[
Script]====],edits={{[====[
local function profileBindings()
	local playerServices = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Player")
	local bindingsFolder = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
	local getProfile = bindingsFolder and bindingsFolder:FindFirstChild("GetProfile")
	local importProfileSnapshot = bindingsFolder and bindingsFolder:FindFirstChild("ImportProfileSnapshot")
	if getProfile and getProfile:IsA("BindableFunction") and importProfileSnapshot and importProfileSnapshot:IsA("BindableFunction") then
		return {
			GetProfile = getProfile,
			ImportProfileSnapshot = importProfileSnapshot,
		}
	end
	return nil
end

local function profileFor(player)
	local bindingsData = profileBindings()
	if not bindingsData then return nil end
	local ok, profile = pcall(function()
		return bindingsData.GetProfile:Invoke(player)
	end)
	if ok and typeof(profile) == "table" then return profile end
	return nil
end

local function persistProfile(player, profile, reason)
	local bindingsData = profileBindings()
	if not bindingsData or typeof(profile) ~= "table" then return false end
	local ok, importOk = pcall(function()
		return bindingsData.ImportProfileSnapshot:Invoke(player, profile, tostring(reason or "RaceReward"), true)
	end)
	return ok and importOk == true
end

]====],[====[
local ProfileServer = require(game.ServerStorage.Modules.Game.Player.ProfileServer)
local function profileFor(player)
	return ProfileServer.get_profile(player)
end
local function persistProfile(player, profile, reason)
	return ProfileServer.mark_dirty(player,profile,tostring(reason or "RaceReward"))
end

]====]}},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):WaitForChild("RaceRewardService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=411305978,beforeBytes=15647,after=3340955666,afterBytes=15065,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceRewardsServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Racing.RaceSessionAssetService_Active]====],new=[====[
ServerStorage.Modules.Game.Racing.RaceAssetsServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):WaitForChild("RaceSessionAssetService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=1652330907,beforeBytes=12656,after=3140602290,afterBytes=13208,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("RaceAssetsServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Racing.TimeTrialService_Active]====],new=[====[
ServerStorage.Modules.Game.Racing.TimeTrialServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Racing"):WaitForChild("TimeTrialService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=1084725399,beforeBytes=51026,after=2315910152,afterBytes=51571,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Racing"):WaitForChild("TimeTrialServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.UI.FreeRoamHudTeleportService_Active]====],new=[====[
ServerStorage.Modules.Game.World.FreeRoamTeleportServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("UI"):WaitForChild("FreeRoamHudTeleportService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=428843673,beforeBytes=5433,after=4116624892,afterBytes=5984,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("FreeRoamTeleportServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriveToEarnCashService_Active]====],new=[====[
ServerStorage.Modules.Game.Vehicles.DriveRewardsServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Vehicle"):WaitForChild("DriveToEarnCashService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=3583911946,beforeBytes=19098,after=696697688,afterBytes=19650,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("DriveRewardsServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Vehicle.DriverSeatPositionService_Active]====],new=[====[
ServerStorage.Modules.Game.Vehicles.DriverSeatServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Vehicle"):WaitForChild("DriverSeatPositionService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=3223360520,beforeBytes=6224,after=724693396,afterBytes=6779,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("DriverSeatServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehicleAccessPromptService_Active]====],new=[====[
ServerStorage.Modules.Game.Vehicles.VehicleAccessServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Vehicle"):WaitForChild("VehicleAccessPromptService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=814230008,beforeBytes=4163,after=4183683104,afterBytes=4719,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehicleAccessServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehicleCollisionLifecycleService_Active]====],new=[====[
ServerStorage.Modules.Game.Vehicles.VehicleCollisionServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Vehicle"):WaitForChild("VehicleCollisionLifecycleService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=2621017697,beforeBytes=7347,after=2999828839,afterBytes=7909,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehicleCollisionServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehiclePerformanceRuntimeService_Active]====],new=[====[
ServerStorage.Modules.Game.Vehicles.VehiclePerformanceServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Vehicle"):WaitForChild("VehiclePerformanceRuntimeService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=2762972647,beforeBytes=1815,after=773786609,afterBytes=2377,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("VehiclePerformanceServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.Vehicle.VehiclePerformanceV2ShadowService_Active]====],new=[====[
ServerStorage.Modules.Game.Development.VehiclePerformanceComparisonServer]====],class=[====[
Script]====],edits={},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Vehicle"):WaitForChild("VehiclePerformanceV2ShadowService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=3051686520,beforeBytes=1714,after=1060231566,afterBytes=2277,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Development"):WaitForChild("VehiclePerformanceComparisonServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.World.Lighting.LightingService_Active]====],new=[====[
ServerStorage.Modules.Game.World.LightingServer]====],class=[====[
Script]====],edits={{[====[
while true do]====],[====[
task.spawn(function()
while true do]====]},{[====[
	task.wait(1)
end]====],[====[
	task.wait(1)
end
end)]====]}},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("World"):WaitForChild("Lighting"):WaitForChild("LightingService_Active")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=2705542937,beforeBytes=4204,after=852702835,afterBytes=4799,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("LightingServer"))
]====]},{old=[====[
ServerScriptService.NeoTokyoRacers.Services.World.Traffic.TrafficLightService]====],new=[====[
ServerStorage.Modules.Game.World.TrafficLightServer]====],class=[====[
Script]====],edits={{[====[
while true do]====],[====[
task.spawn(function()
while true do]====]},{[====[
	task.wait(UPDATE_RATE)
end]====],[====[
	task.wait(UPDATE_RATE)
end
end)]====]}},prefix=[====[
-- Phase 3 server feature; starts only through ServerBase. Server-session lifetime.
local Service = {}
local state
function Service.start()
if state then assert(state=="ready", "Service already starting or failed"); return end
state="starting"
local ok,message=xpcall(function()
local script = game:GetService("ServerScriptService"):WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("World"):WaitForChild("Traffic"):WaitForChild("TrafficLightService")
]====],suffix=[====[

end,debug.traceback)
state=ok and "ready" or "failed"
assert(ok,message)
end
return Service
]====],before=4225431948,beforeBytes=1076,after=3202853661,afterBytes=1667,adapter=[====[
-- Phase 3 stateless compatibility adapter; implementation has one canonical owner.
return require(game:GetService("ServerStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("TrafficLightServer"))
]====]}}
local extras={{path=[====[
ServerScriptService.ServerBase]====],class=[====[
Script]====],source=[=====[
-- Server composition root: explicit registrations; old paths contain adapters only.
local modules=game:GetService("ServerStorage"):WaitForChild("Modules")
local lifecycle=require(modules.Core.ServerLifecycle)
local entries = {
{name=[====[
VehicleAudioServer]====],path=[====[
ServerStorage.Modules.Game.Audio.VehicleAudioServer]====],dependencies={}},
{name=[====[
IntroProgressServer]====],path=[====[
ServerStorage.Modules.Game.Dealership.IntroProgressServer]====],dependencies={[====[
ProfileServer]====]}},
{name=[====[
StudioCashGrantServer]====],path=[====[
ServerStorage.Modules.Game.Development.StudioCashGrantServer]====],dependencies={[====[
GarageServer]====]}},
{name=[====[
GarageServer]====],path=[====[
ServerStorage.Modules.Game.Garage.GarageServer]====],dependencies={[====[
ProfileServer]====]}},
{name=[====[
GarageSessionServer]====],path=[====[
ServerStorage.Modules.Game.Garage.GarageSessionServer]====],dependencies={[====[
GarageServer]====]}},
{name=[====[
OwnedGarageServer]====],path=[====[
ServerStorage.Modules.Game.Garage.OwnedGarageServer]====],dependencies={[====[
GarageServer]====]}},
{name=[====[
ProfileCompatibilityServer]====],path=[====[
ServerStorage.Modules.Game.Player.ProfileCompatibilityServer]====],dependencies={[====[
ProfileServer]====]}},
{name=[====[
OnboardingServer]====],path=[====[
ServerStorage.Modules.Game.Player.OnboardingServer]====],dependencies={[====[
ProfileServer]====]}},
{name=[====[
ProfileServer]====],path=[====[
ServerStorage.Modules.Game.Player.ProfileServer]====],dependencies={}},
{name=[====[
GlobalLeaderboardServer]====],path=[====[
ServerStorage.Modules.Game.Racing.GlobalLeaderboardServer]====],dependencies={[====[
GarageServer]====]}},
{name=[====[
RaceTeleportServer]====],path=[====[
ServerStorage.Modules.Game.Racing.RaceTeleportServer]====],dependencies={[====[
GarageServer]====]}},
{name=[====[
RaceDisplayNameServer]====],path=[====[
ServerStorage.Modules.Game.Racing.RaceDisplayNameServer]====],dependencies={}},
{name=[====[
MatchmakingServer]====],path=[====[
ServerStorage.Modules.Game.Racing.MatchmakingServer]====],dependencies={[====[
GarageServer]====],[====[
RaceRewardsServer]====],[====[
PersonalBestServer]====],[====[
RaceAssetsServer]====]}},
{name=[====[
PersonalBestServer]====],path=[====[
ServerStorage.Modules.Game.Racing.PersonalBestServer]====],dependencies={[====[
ProfileServer]====]}},
{name=[====[
RaceRewardsServer]====],path=[====[
ServerStorage.Modules.Game.Racing.RaceRewardsServer]====],dependencies={[====[
GarageServer]====]}},
{name=[====[
RaceAssetsServer]====],path=[====[
ServerStorage.Modules.Game.Racing.RaceAssetsServer]====],dependencies={[====[
GarageServer]====]}},
{name=[====[
TimeTrialServer]====],path=[====[
ServerStorage.Modules.Game.Racing.TimeTrialServer]====],dependencies={[====[
GarageServer]====],[====[
RaceRewardsServer]====],[====[
PersonalBestServer]====],[====[
RaceAssetsServer]====]}},
{name=[====[
FreeRoamTeleportServer]====],path=[====[
ServerStorage.Modules.Game.World.FreeRoamTeleportServer]====],dependencies={[====[
GarageServer]====]}},
{name=[====[
DriveRewardsServer]====],path=[====[
ServerStorage.Modules.Game.Vehicles.DriveRewardsServer]====],dependencies={[====[
ProfileServer]====]}},
{name=[====[
DriverSeatServer]====],path=[====[
ServerStorage.Modules.Game.Vehicles.DriverSeatServer]====],dependencies={}},
{name=[====[
VehicleAccessServer]====],path=[====[
ServerStorage.Modules.Game.Vehicles.VehicleAccessServer]====],dependencies={[====[
GarageServer]====]}},
{name=[====[
VehicleCollisionServer]====],path=[====[
ServerStorage.Modules.Game.Vehicles.VehicleCollisionServer]====],dependencies={}},
{name=[====[
VehiclePerformanceServer]====],path=[====[
ServerStorage.Modules.Game.Vehicles.VehiclePerformanceServer]====],dependencies={}},
{name=[====[
VehiclePerformanceComparisonServer]====],path=[====[
ServerStorage.Modules.Game.Development.VehiclePerformanceComparisonServer]====],dependencies={}},
{name=[====[
LightingServer]====],path=[====[
ServerStorage.Modules.Game.World.LightingServer]====],dependencies={}},
{name=[====[
TrafficLightServer]====],path=[====[
ServerStorage.Modules.Game.World.TrafficLightServer]====],dependencies={}},
}
local state=Instance.new("Folder")
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
]=====]},{path=[====[
ServerStorage.Modules.Core.ServerLifecycle]====],class=[====[
ModuleScript]====],source=[====[
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
]====]},{path=[====[
ServerStorage.Modules.Game.Player.ProfileCompatibility]====],class=[====[
ModuleScript]====],source=[====[
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
]====]},{path=[====[
ServerStorage.Modules.Game.Player.EconomyServer]====],class=[====[
ModuleScript]====],source=[====[
-- Cash command owner; ProfileServer provides the current authoritative session.
local EconomyServer = {}
function EconomyServer.init(context)
local ntr = context.ntr
local sessionFor = context.sessionFor
local economyCommandLocks = context.economyCommandLocks
local updateRuntimeMarker = context.updateRuntimeMarker
local executeEconomyCommandBinding = context.executeEconomyCommandBinding
local economyCashCommittedEvent = context.economyCashCommittedEvent
local warnLine = context.warnLine
local Players = context.Players
-- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1
-- Canonical positive-Cash command boundary. Callers provide server-authored intent;
-- this owner validates the current ProfileService session and mutates session.Profile.
local ECONOMY_COMMAND_VERSION = 1
local GENERIC_GRANT_REASONS = {
	RaceReward = true,
	TimeTrialReward = true,
	StudioCashGrantHotkey = true,
}

local function economyConfig()
	local runtime = ntr:FindFirstChild("Config") and ntr.Config:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("DriveToEarnCash_EditAttributes")
end

local function economyNumber(name, fallback, minimum, maximum)
	local folder = economyConfig()
	local value = tonumber(folder and folder:GetAttribute(name)) or fallback
	if minimum ~= nil then value = math.max(minimum, value) end
	if maximum ~= nil then value = math.min(maximum, value) end
	return value
end

local function setCommittedCashProjection(player, cash)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local value = leaderstats:FindFirstChild("Cash")
	if value and not value:IsA("IntValue") then
		return false, "leaderstats.Cash must be an IntValue."
	end
	if not value then
		value = Instance.new("IntValue")
		value.Name = "Cash"
		value.Parent = leaderstats
	end
	value.Value = math.max(0, math.floor(tonumber(cash) or 0))
	return true
end

local function validateDriveVehicle(player, session, command)
	local vehicle = command.Vehicle
	local vehicleId = tostring(command.VehicleId or "")
	if not (vehicle and vehicle:IsA("Model") and vehicle.Parent) then
		return false, "VehicleMissing"
	end
	local world = workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
	if not (vehicles and vehicle.Parent == vehicles) then
		return false, "NotRuntimeVehicle"
	end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId
		or tonumber(vehicle:GetAttribute("DriverUserId")) ~= player.UserId then
		return false, "OwnershipMismatch"
	end
	if vehicleId == "" or tostring(vehicle:GetAttribute("OwnedVehicleId") or "") ~= vehicleId then
		return false, "VehicleIdentityMismatch"
	end
	if typeof(session.Profile.Vehicles) ~= "table" or typeof(session.Profile.Vehicles[vehicleId]) ~= "table" then
		return false, "VehicleNotOwned"
	end
	if tostring(session.Profile.CurrentVehicleId or "") ~= vehicleId then
		return false, "VehicleNotCurrent"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle) and seat.Occupant == humanoid) then
		return false, "Unseated"
	end
	if vehicle:GetAttribute("DriveReady") ~= true then return false, "NotDriveReady" end
	if vehicle:GetAttribute("NTR_RaceFrozen") == true or vehicle.PrimaryPart and vehicle.PrimaryPart.Anchored then
		return false, "FrozenOrStaging"
	end
	if vehicle:GetAttribute("ParkedShowcase") == true or vehicle:GetAttribute("NTR_ParkedFixed") == true then
		return false, "Parked"
	end
	if vehicle:GetAttribute("NTR_ExitCoasting") == true then return false, "ExitCoasting" end
	if vehicle:GetAttribute("NTR_RaceBrowserTeleportDespawn") == true
		or vehicle:GetAttribute("NTR_FreeRoamHudTeleportDespawn") == true then
		return false, "TeleportOrTransition"
	end
	return true
end

executeEconomyCommandBinding.OnInvoke = function(player, command)
	if not (player and player:IsA("Player") and player.Parent == Players) then
		return {Ok=false, Success=false, Message="Player lifecycle is not active.", RejectionReason="PlayerLifecycle"}
	end
	command = typeof(command) == "table" and command or {}
	if math.floor(tonumber(command.Version) or 0) ~= ECONOMY_COMMAND_VERSION then
		return {Ok=false, Success=false, Message="Unsupported economy command version.", RejectionReason="CommandVersion"}
	end
	local session = sessionFor(player)
	if not session then
		return {Ok=false, Success=false, Message="Profile is not loaded.", RejectionReason="ProfileNotLoaded"}
	end
	if command.ExpectedSessionGeneration ~= nil
		and tonumber(command.ExpectedSessionGeneration) ~= session.SessionGeneration then
		return {Ok=false, Success=false, Message="Profile session generation changed.", RejectionReason="SessionChanged"}
	end
	if command.ExpectedSessionId ~= nil and tostring(command.ExpectedSessionId) ~= session.SessionId then
		return {Ok=false, Success=false, Message="Profile session identity changed.", RejectionReason="SessionChanged"}
	end
	local userId = player.UserId
	if economyCommandLocks[userId] then
		return {Ok=false, Success=false, Message="Economy command already in progress.", RejectionReason="Busy", Busy=true}
	end
	economyCommandLocks[userId] = session
	local expectedGeneration = session.SessionGeneration
	local expectedId = session.SessionId
	local action = tostring(command.Action or "")

	local ok, result = pcall(function()
		if action == "ValidateDriveSample" or action == "GrantDriveCash" then
			local valid, reason = validateDriveVehicle(player, session, command)
			if not valid then
				return {Ok=false, Success=false, Message="Drive sample rejected: "..reason, RejectionReason=reason}
			end
			if action == "ValidateDriveSample" then
				return {
					Ok=true, Success=true, Valid=true,
					SessionGeneration=expectedGeneration, SessionId=expectedId,
					VehicleId=tostring(command.VehicleId or ""),
				}
			end
		elseif action == "GrantCash" then
			if not GENERIC_GRANT_REASONS[tostring(command.Reason or "")] then
				return {Ok=false, Success=false, Message="Generic Cash grant reason is not allowed.", RejectionReason="ReasonNotAllowed"}
			end
		else
			return {Ok=false, Success=false, Message="Unknown economy command.", RejectionReason="UnknownAction"}
		end

		local amount = math.floor(tonumber(command.Amount) or 0)
		if amount <= 0 then
			return {Ok=false, Success=false, Message="Cash amount must be a positive whole number.", RejectionReason="InvalidAmount"}
		end
		local commandId = tostring(command.CommandId or "")
		if commandId == "" or #commandId > 240 then
			return {Ok=false, Success=false, Message="A bounded economy command ID is required.", RejectionReason="CommandId"}
		end
		session.EconomyClaims = session.EconomyClaims or {Lookup={}, Order={}}
		local claims = session.EconomyClaims
		if claims.Lookup[commandId] then
			return {
				Ok=true, Success=true, Amount=0, Cash=math.max(0,math.floor(tonumber(session.Profile.Cash) or 0)),
				AlreadyCommitted=true, SessionGeneration=expectedGeneration, SessionId=expectedId,
			}
		end
		local maximum = action == "GrantDriveCash"
			and economyNumber("MaximumDriveGrantPerCommand", 1000, 1, 100000)
			or 1000000
		if amount > maximum then
			return {Ok=false, Success=false, Message="Cash amount exceeds the command limit.", RejectionReason="AmountLimit"}
		end
		local current = sessionFor(player)
		if current ~= session or current.SessionGeneration ~= expectedGeneration or current.SessionId ~= expectedId then
			return {Ok=false, Success=false, Message="Profile session changed before Cash commit.", RejectionReason="SessionChanged"}
		end
		local oldCash = math.max(0, math.floor(tonumber(session.Profile.Cash) or 0))
		local oldDirty = session.Dirty
		local oldDirtyReason = session.LastDirtyReason
		local newCash = oldCash + amount
		if newCash > 2000000000 then
			return {Ok=false, Success=false, Message="Cash balance safety limit reached.", RejectionReason="BalanceLimit"}
		end
		session.Profile.Cash = newCash
		session.Dirty = true
		session.LastDirtyReason = "EconomyCommand:" .. tostring(command.Reason or action)
		updateRuntimeMarker(player, session)
		local projected, projectionMessage = setCommittedCashProjection(player, newCash)
		if not projected then
			session.Profile.Cash = oldCash
			session.Dirty = oldDirty
			session.LastDirtyReason = oldDirtyReason
			updateRuntimeMarker(player, session)
			return {Ok=false, Success=false, Message=projectionMessage, RejectionReason="ProjectionFailed"}
		end
		session.Revision += 1
		claims.Lookup[commandId] = true
		table.insert(claims.Order, commandId)
		while #claims.Order > 256 do
			local expired = table.remove(claims.Order, 1)
			claims.Lookup[expired] = nil
		end
		player:SetAttribute("NTR_LastEconomyCommand", action)
		player:SetAttribute("NTR_LastEconomyGrantAmount", amount)
		player:SetAttribute("NTR_LastEconomyGrantReason", tostring(command.Reason or action))
		economyCashCommittedEvent:Fire(player, newCash, {
			Version=ECONOMY_COMMAND_VERSION,
			Action=action,
			Amount=amount,
			Reason=tostring(command.Reason or action),
			CommandId=commandId,
			SessionGeneration=expectedGeneration,
			SessionId=expectedId,
		})
		return {
			Ok=true, Success=true, Amount=amount, Cash=newCash,
			SessionGeneration=expectedGeneration, SessionId=expectedId,
		}
	end)
	if economyCommandLocks[userId] == session then economyCommandLocks[userId] = nil end
	if not ok then
		warnLine("ECONOMY COMMAND FAILED player="..player.Name.." action="..action.." error="..tostring(result))
		return {Ok=false, Success=false, Message="Economy command failed.", RejectionReason="CommandError"}
	end
	return result
end


end
return EconomyServer
]====]}}
local function find(path)
	local item=game
	for part in path:gmatch("[^%.]+") do
		local found
		for _,child in ipairs(item:GetChildren()) do if child.Name==part then assert(not found,"Ambiguous path "..path); found=child end end
		if not found then return nil end
		item=found
	end
	return item
end
local function hash(source) local n=0 for i=1,#source do n=(n*31+source:byte(i))%4294967296 end return n end
local function replace(source,a,b)
	local i,j=source:find(a,1,true)
	assert(i and not source:find(a,j+1,true),"Source anchor mismatch")
	return source:sub(1,i-1)..b..source:sub(j+1)
end
local function compile(source,path) local f,e=loadstring(source,"="..path); assert(f,e) end
local installed=find("ServerScriptService.ServerBase")~=nil
-- Stage and compile every projected source before changing any instance.
for _,r in ipairs(records) do
	r.item=assert(find(r.old),"Missing "..r.old)
	assert(#r.item:GetChildren()==0,"Unexpected children; inspect "..r.old)
	if installed then
		assert(r.item:IsA("ModuleScript") and r.item.Source==r.adapter,"Adapter changed "..r.old)
		r.canonical=assert(find(r.new),"Missing "..r.new)
		assert(r.canonical:IsA("ModuleScript") and #r.canonical:GetChildren()==0,"Unexpected canonical shape")
		r.target=r.canonical.Source
		assert(#r.target==r.afterBytes and hash(r.target)==r.after,"Canonical source changed "..r.new)
		assert(r.target:sub(1,#r.prefix)==r.prefix,"Prefix changed")
		r.original=r.target:sub(#r.prefix+1,#r.target-#r.suffix)
		for i=#r.edits,1,-1 do local pair=r.edits[i]; r.original=replace(r.original,pair[2],pair[1]) end
	else
		assert(r.item.ClassName==r.class,"Class mismatch "..r.old)
		if r.item:IsA("Script") then assert(not r.item.Disabled,"Disabled baseline "..r.old) end
		assert(not find(r.new),"Destination occupied "..r.new)
		r.original=r.item.Source
		r.target=r.original
		for _,pair in ipairs(r.edits) do r.target=replace(r.target,pair[1],pair[2]) end
		r.target=r.prefix..r.target..r.suffix
	end
	assert(hash(r.original)==r.before and #r.original==r.beforeBytes,"Baseline changed "..r.old)
	assert(hash(r.target)==r.after and #r.target==r.afterBytes,"Projected source mismatch "..r.new)
	compile(r.original,r.old); compile(r.target,r.new); compile(r.adapter,r.old)
end
for _,e in ipairs(extras) do
	e.item=find(e.path)
	assert((e.item~=nil)==installed,"Mixed extra installation "..e.path)
	if installed then assert(e.item.ClassName==e.class and e.item.Source==e.source and #e.item:GetChildren()==0,"Extra changed "..e.path) end
	compile(e.source,e.path)
end
if MODE=="AUDIT" then return "PASS Phase 3 "..(installed and "installed" or "baseline") end
if MODE=="INSTALL" and installed or MODE=="ROLLBACK" and not installed then return "PASS Phase 3 already in requested state" end
local created,changed,detached={}, {}, {}
local function parentFor(path)
	local parentPath,name=path:match("^(.*)%.([^%.]+)$")
	local parent=game
	for part in parentPath:gmatch("[^%.]+") do
		local nextItem=parent:FindFirstChild(part)
		if not nextItem then
			nextItem=Instance.new("Folder"); nextItem.Name=part
			nextItem:SetAttribute("NTRArchitecturePhase3Folder",true)
			table.insert(created,nextItem); nextItem.Parent=parent
		end
		parent=nextItem
	end
	return parent,name
end
local function make(path,class,source,attrs)
	local parent,name=parentFor(path)
	assert(not parent:FindFirstChild(name),"Occupied "..path)
	local item=Instance.new(class); table.insert(created,item)
	item.Name=name; item.Source=source
	for k,v in pairs(attrs or {}) do item:SetAttribute(k,v) end
	item.Parent=parent
	return item
end
local function detach(item)
	table.insert(detached,{item=item,parent=item.Parent})
	item.Parent=nil
end
local function assign(item,source)
	table.insert(changed,{item=item,source=item.Source}); item.Source=source
end
local ok,message=xpcall(function()
	if MODE=="INSTALL" then
		for _,r in ipairs(records) do make(r.new,"ModuleScript",r.target) end
		for _,e in ipairs(extras) do make(e.path,e.class,e.source) end
		for _,r in ipairs(records) do
			if r.class=="Script" then
				local attrs=r.item:GetAttributes(); detach(r.item); make(r.old,"ModuleScript",r.adapter,attrs)
			else assign(r.item,r.adapter) end
		end
		for _,r in ipairs(records) do assert(find(r.old).Source==r.adapter and find(r.new).Source==r.target,"Post-install mismatch") end
	else
		for _,r in ipairs(records) do
			if r.class=="Script" then
				local attrs=r.item:GetAttributes(); detach(r.item); make(r.old,"Script",r.original,attrs)
			else assign(r.item,r.original) end
			detach(r.canonical)
		end
		for _,e in ipairs(extras) do detach(e.item) end
		for _,r in ipairs(records) do assert(find(r.old).Source==r.original,"Post-rollback mismatch") end
	end
end,debug.traceback)
if not ok then
	for _,c in ipairs(changed) do c.item.Source=c.source end
	for i=#created,1,-1 do created[i]:Destroy() end
	for _,d in ipairs(detached) do d.item.Parent=d.parent end
	error("Phase 3 restored previous state: "..tostring(message))
end
for _,d in ipairs(detached) do d.item:Destroy() end
if MODE=="ROLLBACK" then
	local folders={}
	for _,item in ipairs(game.ServerStorage:GetDescendants()) do if item:IsA("Folder") and item:GetAttribute("NTRArchitecturePhase3Folder")==true then table.insert(folders,item) end end
	for i=#folders,1,-1 do if #folders[i]:GetChildren()==0 then folders[i]:Destroy() end end
end
return "PASS Phase 3 "..MODE.."; verify a fresh Play session"
