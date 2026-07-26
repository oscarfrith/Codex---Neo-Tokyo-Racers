-- Neo Tokyo Racers - Player Onboarding V1.13
-- Run in the Roblox Studio Edit-mode Command Bar.
-- INSTALL is transactional. Change MODE to "AUDIT" for the committed-state audit.

local MODE = "INSTALL"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local REVISION = "NTR_PLAYER_ONBOARDING_V1_13_STATE_IMPORT_RACE_CONTROLS_TWO_LINE_OBJECTIVES"
local PROFILE_MARKER = "NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1_3_STUDIO_VEHICLE_SANDBOX"
local PROFILE_IMPORT_PROTECTION_MARKER = "NTR_PROFILE_SERVICE_ONBOARDING_IMPORT_PROTECTION_V1"
local PROFILE_MARKER_V1_2 = "NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1_2"
local PROFILE_MARKER_V1_1 = "NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1_1"
local PROFILE_LEGACY_MARKER = "NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1"
local RACE_MARKER = "NTR_RACE_MATCHMAKING_ONBOARDING_START_V1"
local TRIAL_MARKER = "NTR_TIME_TRIAL_ONBOARDING_START_V1"
local GARAGE_MARKER = "NTR_OWNED_GARAGE_ONBOARDING_MANAGEMENT_V1"
local PURCHASE_MARKER = "NTR_GARAGE_ONBOARDING_PURCHASE_BOUNDARY_V1"
local DESKTOP_MARKER = "NTR_DESKTOP_ONBOARDING_CONTROLS_POPUP_V1"
local WORKSPACE_SEMANTIC_MARKER = "NTR_ONBOARDING_V1_5_SHARED_WORKSPACE_SEMANTICS"
local WORKSPACE_SEMANTIC_MARKER_V1_4 = "NTR_ONBOARDING_V1_4_SHARED_WORKSPACE_SEMANTICS"
local WORKSPACE_SEMANTIC_MARKER_V1_3 = "NTR_ONBOARDING_V1_3_SHARED_WORKSPACE_SEMANTICS"
local MODULE_SEMANTIC_MARKER = "NTR_ONBOARDING_V1_3_MODULE_PAGE_SEMANTICS"
local OWNED_SEMANTIC_MARKER = "NTR_ONBOARDING_V1_3_OWNED_GARAGE_PAGE_SEMANTICS"

local function child(parent, name, className)
	local object = parent:FindFirstChild(name)
	assert(object and object:IsA(className), ("Missing %s.%s (%s)"):format(parent:GetFullName(), name, className))
	return object
end

local function ensure(parent, name, className, created)
	local object = parent:FindFirstChild(name)
	if object then
		assert(object:IsA(className), object:GetFullName() .. " must be " .. className)
		return object
	end
	object = Instance.new(className)
	object.Name = name
	object.Parent = parent
	table.insert(created, object)
	return object
end

local function has(source, marker)
	return string.find(source, marker, 1, true) ~= nil
end

local function replaceOnce(source, old, new, label)
	local firstStart, firstEnd = string.find(source, old, 1, true)
	assert(firstStart, label .. " anchor missing; refresh/inspect the live mirror instead of guessing")
	assert(not string.find(source, old, firstEnd + 1, true), label .. " anchor is not unique")
	return string.sub(source, 1, firstStart - 1) .. new .. string.sub(source, firstEnd + 1)
end

local function compile(label, source)
	local fn, problem = loadstring(source, "=" .. label)
	assert(fn, label .. " compile failed: " .. tostring(problem))
end

local kit = child(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local runtimeConfig = child(child(kit, "Config", "Folder"), "Runtime", "Folder")
local shared = child(kit, "Shared", "Folder")
local sharedRemotes = child(shared, "Remotes", "Folder")
local serverRoot = child(ServerScriptService, "NeoTokyoRacers", "Folder")
local services = child(serverRoot, "Services", "Folder")
local playerServices = child(services, "Player", "Folder")
local racingServices = child(services, "Racing", "Folder")
local garageServices = child(services, "Garage", "Folder")
local profileService = child(playerServices, "ProfileService_Active", "Script")
local raceService = child(racingServices, "RaceMatchmakingService_Active", "Script")
local trialService = child(racingServices, "TimeTrialService_Active", "Script")
local garageAction = child(garageServices, "GarageActionController_Shadow_Disabled", "Script")
local garageRuntime = child(garageServices, "OwnedGarageManagementRuntime", "ModuleScript")
local starterScripts = child(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = child(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = child(clientRoot, "Controllers", "Folder")
local uiControllers = child(controllers, "UI", "Folder")
local desktopHud = child(uiControllers, "DesktopFreeRoamHudController_Active", "LocalScript")
local garageWorkspace = child(uiControllers, "GarageWorkspaceController", "ModuleScript")
local moduleShop = child(uiControllers, "ModuleShopUIController", "ModuleScript")
local ownedGarageWorkspace = child(uiControllers, "OwnedGarageWorkspaceController", "ModuleScript")

local PROFILE_BINDING_DECLARATION = [=[
local executeOwnedGarageCommandBinding = ensureBindableFunction(bindings, "ExecuteOwnedGarageCommand")
]=]

local PROFILE_BINDING_DECLARATION_NEW = [=[
local executeOwnedGarageCommandBinding = ensureBindableFunction(bindings, "ExecuteOwnedGarageCommand")
local executeOnboardingCommandBinding = ensureBindableFunction(bindings, "ExecuteOnboardingCommand") -- NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1
]=]

local PROFILE_HANDLER_ANCHOR = [=[
getProfileBinding.OnInvoke = function(player)
]=]

local PROFILE_HANDLER = [=[
-- NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1_2
executeOnboardingCommandBinding.OnInvoke = function(player, command)
	local session = sessionFor(player)
	if not session then return {Success=false, Message="Profile is not loaded."} end
	command = type(command) == "table" and command or {}
	local profile = session.Profile
	local firstOnboardingLoad = type(profile.Onboarding) ~= "table"
	profile.Onboarding = type(profile.Onboarding) == "table" and profile.Onboarding or {}
	local state = profile.Onboarding
	state.SeenPages = type(state.SeenPages) == "table" and state.SeenPages or {}
	state.Completed = type(state.Completed) == "table" and state.Completed or {}
	local action = tostring(command.Action or "Get")
	local changed = false
	local hasExistingVehicle = next(type(profile.Vehicles)=="table" and profile.Vehicles or {})~=nil
	if hasExistingVehicle and firstOnboardingLoad then
		state.Completed.FirstVehiclePurchased=true
		state.Completed.FirstVehicleDriven=true
		changed=true
	elseif hasExistingVehicle and state.Completed.FirstVehicleDriven==true and state.Completed.FirstVehiclePurchased~=true then
		state.Completed.FirstVehiclePurchased=true
		changed=true
	end
	if action == "MarkSeen" then
		local pageId = tostring(command.PageId or "")
		if pageId ~= "" and state.SeenPages[pageId] ~= true then state.SeenPages[pageId] = true; changed = true end
	elseif action == "RecordProgress" then
		local progressId = tostring(command.ProgressId or "")
		local allowed = {FirstVehiclePurchased=true, FirstVehicleDriven=true, FirstEventEntered=true, GarageManagementEntered=true}
		if allowed[progressId] and state.Completed[progressId] ~= true then state.Completed[progressId] = true; changed = true end
	elseif action ~= "Get" then
		return {Success=false, Message="Unknown onboarding command."}
	end
	if changed then markDirty(player, "Onboarding:" .. action) end
	local stage = (state.Completed.FirstVehiclePurchased ~= true or state.Completed.FirstVehicleDriven ~= true) and 1
		or state.Completed.GarageManagementEntered ~= true and 2
		or state.Completed.FirstEventEntered ~= true and 3
		or 4
	return {Success=true, Stage=stage, SeenPages=state.SeenPages, Completed=state.Completed, Changed=changed}
end

getProfileBinding.OnInvoke = function(player)
]=]

local PROFILE_SANDBOX_HELPERS = [=[
-- NTR Studio vehicle sandbox: authoritative in-memory profile mutation with a hard no-save guard.
local function studioVehicleSandboxConfig()
	if not RunService:IsStudio() then return nil end
	local runtime = ntr:FindFirstChild("Config") and ntr.Config:FindFirstChild("Runtime")
	local onboarding = runtime and runtime:FindFirstChild("Onboarding_EditAttributes")
	if not onboarding or onboarding:GetAttribute("StudioVehicleSandboxEveryPlay") ~= true then return nil end
	return onboarding
end

local function clearVehicleReferences(spaces)
	if type(spaces) ~= "table" then return end
	for key, space in pairs(spaces) do
		if type(space) == "table" then
			space.VehicleId = nil
		elseif space ~= nil then
			spaces[key] = false
		end
	end
end

local function applyStudioVehicleSandbox(player, profile)
	local onboarding = studioVehicleSandboxConfig()
	if not onboarding then
		player:SetAttribute("NTR_StudioVehicleSandboxActive", nil)
		return false
	end
	profile.Vehicles = {}
	profile.OwnedCockpitInstances = {}
	profile.OwnedModuleInstances = {}
	profile.CurrentVehicleId = nil
	profile.OwnedCockpits = {}
	profile.OwnedModules = {}
	profile.InstalledModules = {}
	profile.ModuleColors = {}
	profile.NeonOwned = {}
	profile.ModuleUpgradeLevels = {}
	clearVehicleReferences(profile.GarageDisplaySpaces)
	if type(profile.Garage) == "table" then clearVehicleReferences(profile.Garage.DisplaySpaces) end
	if type(profile.OwnedGarage) == "table" and type(profile.OwnedGarage.Properties) == "table" then
		for _, property in pairs(profile.OwnedGarage.Properties) do
			if type(property) == "table" then clearVehicleReferences(property.DisplaySpaces) end
		end
	end
	local testCash = math.max(0, tonumber(onboarding:GetAttribute("StudioVehicleSandboxCash")) or 1000000)
	profile.Cash = math.max(tonumber(profile.Cash) or 0, testCash)
	player:SetAttribute("NTR_StudioVehicleSandboxActive", true)
	log("STUDIO VEHICLE SANDBOX active player=" .. player.Name .. " saves suppressed")
	return true
end

local function loadProfile(player)
]=]

local PROFILE_LOAD_ANCHOR = [=[
local function loadProfile(player)
]=]

local PROFILE_SESSION_ANCHOR = [=[
	local profile = schema.FromDataStore(loadedData, startingCash())
	local session = {
		Player = player,
		SessionGeneration = generation,
		SessionId = HttpService:GenerateGUID(false),
		Profile = profile,
		Loaded = true,
		Dirty = false,
		LastDirtyReason = "",
		LastSaveUnix = 0,
		LastError = loadError,
		DataStoreEnabledAtLoad = dataStoreEnabled(),
	}
]=]

local PROFILE_SESSION_SANDBOX = [=[
	local profile = schema.FromDataStore(loadedData, startingCash())
	local studioVehicleSandbox = applyStudioVehicleSandbox(player, profile)
	local session = {
		Player = player,
		SessionGeneration = generation,
		SessionId = HttpService:GenerateGUID(false),
		Profile = profile,
		Loaded = true,
		Dirty = false,
		LastDirtyReason = "",
		LastSaveUnix = 0,
		LastError = loadError,
		DataStoreEnabledAtLoad = dataStoreEnabled(),
		StudioVehicleSandbox = studioVehicleSandbox,
		NoSave = studioVehicleSandbox,
	}
]=]

local PROFILE_SAVE_ANCHOR = [=[
	if not force and not session.Dirty then
]=]

local PROFILE_SAVE_SANDBOX = [=[
	if session.NoSave == true then
		session.Dirty = false
		session.LastSaveUnix = os.time()
		session.LastError = "Studio vehicle sandbox; save suppressed."
		updateRuntimeMarker(player, session)
		return true, "Studio vehicle sandbox; save suppressed."
	end
	if not force and not session.Dirty then
]=]

local PROFILE_IMPORT_ANCHOR = [=[
	local normalized = schema.Normalize(snapshot, startingCash())
	if normalized ~= session.Profile then
]=]

local PROFILE_IMPORT_PROTECTION = [=[
	local normalized = schema.Normalize(snapshot, startingCash())
	-- Generic garage/racing snapshots do not own authoritative onboarding state.
	normalized.Onboarding = session.Profile.Onboarding -- NTR_PROFILE_SERVICE_ONBOARDING_IMPORT_PROTECTION_V1
	if normalized ~= session.Profile then
]=]

local function projectProfile(source)
	if has(source, PROFILE_MARKER) then
		if not has(source,PROFILE_IMPORT_PROTECTION_MARKER) then
			source=replaceOnce(source,PROFILE_IMPORT_ANCHOR,PROFILE_IMPORT_PROTECTION,"ProfileService onboarding import protection")
		end
		return source
	end
	if has(source, PROFILE_MARKER_V1_2) then
		-- Current installed V1.6 baseline. Check this before the prefix-compatible legacy V1 marker.
	elseif has(source, PROFILE_MARKER_V1_1) then
		source=replaceOnce(source,PROFILE_MARKER_V1_1,PROFILE_MARKER_V1_2,"ProfileService onboarding V1.2 marker")
		source=replaceOnce(source,
			'or state.Completed.FirstEventEntered ~= true and 2\n\t\tor state.Completed.GarageManagementEntered ~= true and 3',
			'or state.Completed.GarageManagementEntered ~= true and 2\n\t\tor state.Completed.FirstEventEntered ~= true and 3',
			"ProfileService garage-before-race stage order")
	elseif has(source, PROFILE_LEGACY_MARKER) then
		local legacyStart = "executeOnboardingCommandBinding.OnInvoke = function(player, command)"
		local legacyEnd = "\n\ngetProfileBinding.OnInvoke = function(player)"
		local first = assert(string.find(source, legacyStart, 1, true), "Legacy onboarding handler start missing")
		local last = assert(string.find(source, legacyEnd, first, true), "Legacy onboarding handler end missing")
		local replacement = string.sub(PROFILE_HANDLER, 1, #PROFILE_HANDLER - #PROFILE_HANDLER_ANCHOR)
		source = string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last)
	elseif not has(source, PROFILE_MARKER_V1_2) then
		assert(has(source, "NTR_PROFILE_SERVICE_OWNED_GARAGE_COMMAND_OWNER_V1"), "Unknown ProfileService baseline")
		source = replaceOnce(source, PROFILE_BINDING_DECLARATION, PROFILE_BINDING_DECLARATION_NEW, "ProfileService onboarding binding declaration")
		source = replaceOnce(source, PROFILE_HANDLER_ANCHOR, PROFILE_HANDLER, "ProfileService onboarding command owner")
	end
	assert(has(source,PROFILE_MARKER_V1_2),"ProfileService V1.2 onboarding baseline missing")
	source=replaceOnce(source,PROFILE_MARKER_V1_2,PROFILE_MARKER,"ProfileService Studio vehicle sandbox marker")
	source=replaceOnce(source,PROFILE_LOAD_ANCHOR,PROFILE_SANDBOX_HELPERS,"ProfileService Studio vehicle sandbox helpers")
	source=replaceOnce(source,PROFILE_SESSION_ANCHOR,PROFILE_SESSION_SANDBOX,"ProfileService Studio vehicle sandbox session")
	source=replaceOnce(source,PROFILE_SAVE_ANCHOR,PROFILE_SAVE_SANDBOX,"ProfileService Studio vehicle sandbox no-save guard")
	source=replaceOnce(source,PROFILE_IMPORT_ANCHOR,PROFILE_IMPORT_PROTECTION,"ProfileService onboarding import protection")
	return source
end

local PURCHASE_ANCHOR = [=[
				V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)]=]
local PURCHASE_REPLACEMENT = [=[
				V80_mirrorLegacyProfileToPersistence(player, profile, action, V80_mutatingActions[action] == true)
				if action=="BuyCockpitInstance" then
					local onboarding=game:GetService("ServerScriptService").NeoTokyoRacers.Services.Player:FindFirstChild("OnboardingProgress")
					if onboarding and onboarding:IsA("BindableEvent") then onboarding:Fire(player,"FirstVehiclePurchased") end
				end -- NTR_GARAGE_ONBOARDING_PURCHASE_BOUNDARY_V1
]=]
local function projectGarageAction(source)
	if has(source, PURCHASE_MARKER) then return source end
	assert(has(source,"NTR_GARAGE_CANONICAL_CATEGORY_PURCHASE"),"Unknown GarageActionController purchase baseline")
	return replaceOnce(source,PURCHASE_ANCHOR,PURCHASE_REPLACEMENT,"trusted vehicle-purchase completion")
end

local RACE_ANCHOR = "prepareVehicleForDriving(entry.Player, entry.Vehicle)"
local RACE_REPLACEMENT = [=[
prepareVehicleForDriving(entry.Player, entry.Vehicle)
				local onboarding = game:GetService("ServerScriptService").NeoTokyoRacers.Services.Player:FindFirstChild("OnboardingProgress")
				if onboarding and onboarding:IsA("BindableEvent") then onboarding:Fire(entry.Player, "FirstEventEntered") end -- NTR_RACE_MATCHMAKING_ONBOARDING_START_V1
]=]
local function projectRace(source)
	if has(source, RACE_MARKER) then return source end
	assert(has(source, "NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP"), "Unknown RaceMatchmakingService baseline")
	return replaceOnce(source, RACE_ANCHOR, RACE_REPLACEMENT, "trusted multiplayer race start")
end

local TRIAL_ANCHOR = 'live.State = "Running"'
local TRIAL_REPLACEMENT = [=[
live.State = "Running"
		local onboarding = game:GetService("ServerScriptService").NeoTokyoRacers.Services.Player:FindFirstChild("OnboardingProgress")
		if onboarding and onboarding:IsA("BindableEvent") then onboarding:Fire(player, "FirstEventEntered") end -- NTR_TIME_TRIAL_ONBOARDING_START_V1
]=]
local function projectTrial(source)
	if has(source, TRIAL_MARKER) then return source end
	assert(has(source, "NTR_RACING_FLOW_COUNTDOWN_QUEUE_EXIT_OWNERSHIP"), "Unknown TimeTrialService baseline")
	return replaceOnce(source, TRIAL_ANCHOR, TRIAL_REPLACEMENT, "trusted time-trial start")
end

local GARAGE_ANCHOR = "session.ManagementOpen=args.Open==true; applyPromptPolicy(session);"
local GARAGE_REPLACEMENT = 'session.ManagementOpen=args.Open==true; applyPromptPolicy(session); if session.ManagementOpen then local progress=services.Player:FindFirstChild("OnboardingProgress"); if progress and progress:IsA("BindableEvent") then progress:Fire(player,"GarageManagementEntered") end end; --[[NTR_OWNED_GARAGE_ONBOARDING_MANAGEMENT_V1]]'
local function projectGarage(source)
	if has(source, GARAGE_MARKER) then return source end
	return replaceOnce(source, GARAGE_ANCHOR, GARAGE_REPLACEMENT, "trusted garage-management entry")
end

local DESKTOP_CONTROLS_ANCHOR = 'controlsButton.Activated:Connect(function() openModal("Controls") end)'
local DESKTOP_CONTROLS_REPLACEMENT = [=[
controlsButton.Activated:Connect(function() openModal("Controls") end)
	local onboardingControls=script.Parent:WaitForChild("OpenDrivingControlsFromOnboarding")
	onboardingControls.Event:Connect(function() openModal("Controls") end) -- NTR_DESKTOP_ONBOARDING_CONTROLS_POPUP_V1
]=]
local function projectDesktop(source)
	if has(source, DESKTOP_MARKER) then return source end
	assert(has(source,"NTR_PC_FREEROAM_UI_PHASE4A_DEALERSHIP_TELEPORT"),"Unknown DesktopFreeRoamHud baseline")
	return replaceOnce(source,DESKTOP_CONTROLS_ANCHOR,DESKTOP_CONTROLS_REPLACEMENT,"existing desktop controls popup bridge")
end

local function projectGarageWorkspace(source)
	if has(source, WORKSPACE_SEMANTIC_MARKER) then return source end
	assert(has(source,"NTR_GARAGE_WORKSPACE_CONTROLLER_V3"),"Unknown GarageWorkspaceController baseline")
	if has(source,WORKSPACE_SEMANTIC_MARKER_V1_4) then
		source=replaceOnce(source,WORKSPACE_SEMANTIC_MARKER_V1_4,WORKSPACE_SEMANTIC_MARKER,"V1.5 shared workspace marker")
		source=replaceOnce(source,
			'self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageWorkspace";',
			'self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageWorkspace"; self.Root:SetAttribute("TutorialWorkspace",true);',
			"semantic tutorial workspace root")
		source=replaceOnce(source,
			'self.Carousel=Instance.new("Frame"); self.Carousel.BackgroundTransparency=1;',
			'self.Carousel=Instance.new("Frame"); self.Carousel.Name="TutorialCardCarousel"; self.Carousel:SetAttribute("TutorialTargetId","CardCarousel"); self.Carousel.BackgroundTransparency=1;',
			"semantic tutorial card carousel")
		source=replaceOnce(source,
			'self.Scroller=Instance.new("ScrollingFrame"); self.Scroller.BackgroundTransparency=1;',
			'self.Scroller=Instance.new("ScrollingFrame"); self.Scroller.Name="TutorialCardScroller"; self.Scroller:SetAttribute("TutorialTargetId","CardScroller"); self.Scroller.BackgroundTransparency=1;',
			"semantic tutorial card scroller")
		return source
	end
	if has(source,WORKSPACE_SEMANTIC_MARKER_V1_3) then
		source=replaceOnce(source,
			" -- NTR_ONBOARDING_V1_3_SHARED_WORKSPACE_SEMANTICS; if selected then",
			" --[[NTR_ONBOARDING_V1_4_SHARED_WORKSPACE_SEMANTICS]]; if selected then",
			"V1.3 shared workspace line-comment repair")
		return projectGarageWorkspace(source)
	end
	source=replaceOnce(source,
		"card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end)",
		'card:SetAttribute("CanonicalGarageCardId",tostring(row.Id or "")); card.LayoutOrder=order; card.Activated:Connect(function() if row.OnSelect then row.OnSelect() end end) --[[NTR_ONBOARDING_V1_5_SHARED_WORKSPACE_SEMANTICS]]',
		"shared workspace semantic card id")
	source=replaceOnce(source,
		'self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageWorkspace";',
		'self.Root=Instance.new("Frame"); self.Root.Name="CanonicalGarageWorkspace"; self.Root:SetAttribute("TutorialWorkspace",true);',
		"semantic tutorial workspace root")
	source=replaceOnce(source,
		'self.Carousel=Instance.new("Frame"); self.Carousel.BackgroundTransparency=1;',
		'self.Carousel=Instance.new("Frame"); self.Carousel.Name="TutorialCardCarousel"; self.Carousel:SetAttribute("TutorialTargetId","CardCarousel"); self.Carousel.BackgroundTransparency=1;',
		"semantic tutorial card carousel")
	source=replaceOnce(source,
		'self.Scroller=Instance.new("ScrollingFrame"); self.Scroller.BackgroundTransparency=1;',
		'self.Scroller=Instance.new("ScrollingFrame"); self.Scroller.Name="TutorialCardScroller"; self.Scroller:SetAttribute("TutorialTargetId","CardScroller"); self.Scroller.BackgroundTransparency=1;',
		"semantic tutorial card scroller")
	source=replaceOnce(source,
		"self:CaptureScroll(); self:DisconnectDynamic(); self.Context=context; self.Title.Text=",
		'self:CaptureScroll(); self:DisconnectDynamic(); self.Context=context; self.Root:SetAttribute("TutorialPageId",tostring(context.TutorialPageId or "")); self.Title.Text=',
		"shared workspace refresh page id")
	source=replaceOnce(source,
		"self:CaptureScroll(); self:DisconnectDynamic(); self.Context=context\n\tself.Root.Visible=true;",
		'self:CaptureScroll(); self:DisconnectDynamic(); self.Context=context; self.Root:SetAttribute("TutorialPageId",tostring(context.TutorialPageId or ""))\n\tself.Root.Visible=true;',
		"shared workspace show page id")
	return source
end

local function projectModuleShop(source)
	if has(source, MODULE_SEMANTIC_MARKER) then return source end
	assert(has(source,"NTR_CUSTOMISATION_THREE_WORKSHOP_FLOW_V1"),"Unknown ModuleShopUIController baseline")
	source=replaceOnce(source,'local c=common("Garage")','local c=common("Garage"); c.TutorialPageId="CustomisationHome" -- NTR_ONBOARDING_V1_3_MODULE_PAGE_SEMANTICS',"customisation home semantic page")
	source=replaceOnce(source,'local c=common("Add Modules")','local c=common("Add Modules"); c.TutorialPageId="AddModules"',"Add Modules semantic page")
	source=replaceOnce(source,'local c=common("Upgrade Modules")','local c=common("Upgrade Modules"); c.TutorialPageId="UpgradeModules"',"Upgrade Modules semantic page")
	source=replaceOnce(source,'local c=common("Paint Shop")','local c=common("Paint Shop"); c.TutorialPageId="PaintShop"',"Paint Shop semantic page")
	return source
end

local function projectOwnedGarageWorkspace(source)
	if has(source, OWNED_SEMANTIC_MARKER) then return source end
	assert(has(source,"NTR_OWNED_GARAGE_STYLE_UX_V1_BATCH_STABLE_PREVIEW"),"Unknown OwnedGarageWorkspaceController baseline")
	return replaceOnce(source,
		'local item=property(); local home=page=="Home"; return {Title="GARAGE MANAGEMENT"',
		'local item=property(); local home=page=="Home"; local tutorialPage=page=="Home" and "GarageHome" or page=="DisplaySpaces" and "DisplayCars" or (page=="Build" or page=="Style") and "GarageAssetFamilies" or page=="BuildStructure" and "BuildStructure" or page=="BuildDecorations" and "BuildDecorations" or ""; return {TutorialPageId=tutorialPage,Title="GARAGE MANAGEMENT" --[[NTR_ONBOARDING_V1_3_OWNED_GARAGE_PAGE_SEMANTICS]]',
		"owned garage semantic page id")
end

local ONBOARDING_SERVICE_SOURCE = [=[
-- NTR_PLAYER_ONBOARDING_V1
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local ServerScriptService=game:GetService("ServerScriptService")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("Onboarding_EditAttributes")
local shared=kit:WaitForChild("Shared")
local remotes=shared:WaitForChild("Remotes"):WaitForChild("Onboarding")
local invoke=remotes:WaitForChild("OnboardingInvoke")
local changedEvent=remotes:WaitForChild("OnboardingStateChanged")
local services=ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
local playerServices=services:WaitForChild("Player")
local bindings=playerServices:WaitForChild("ProfileServiceBindings")
local execute=bindings:WaitForChild("ExecuteOnboardingCommand")
local progress=playerServices:WaitForChild("OnboardingProgress")
local replayStates={}
local allowedPages={Dealership=true,CustomisationHome=true,AddModules=true,UpgradeModules=true,PaintShop=true,PCDriving=true,MobileDriving=true,VehicleShortcut=true,RaceShortcut=true,RaceBrowser=true,EventMode=true,TimeTrialSetup=true,RaceSetup=true,GarageShortcut=true,GarageBrowser=true,GarageHome=true,DisplayCars=true,GarageAssetFamilies=true,BuildStructure=true,BuildDecorations=true}
local allowedProgress={FirstVehiclePurchased=true,FirstVehicleDriven=true,FirstEventEntered=true,GarageManagementEntered=true}

local function stageFor(state)
	return (state.Completed.FirstVehiclePurchased~=true or state.Completed.FirstVehicleDriven~=true) and 1 or state.Completed.GarageManagementEntered~=true and 2 or state.Completed.FirstEventEntered~=true and 3 or 4
end

local function replayRun(player,action,data)
	local state=replayStates[player]
	if not state then state={SeenPages={},Completed={}}; replayStates[player]=state end
	local changed=false
	if action=="MarkSeen" then local pageId=tostring(data and data.PageId or ""); if allowedPages[pageId] and state.SeenPages[pageId]~=true then state.SeenPages[pageId]=true; changed=true end
	elseif action=="RecordProgress" then local progressId=tostring(data and data.ProgressId or ""); if allowedProgress[progressId] and state.Completed[progressId]~=true then state.Completed[progressId]=true; changed=true end
	elseif action~="Get" then return {Success=false,Message="Unknown replay action."} end
	return {Success=true,Stage=stageFor(state),SeenPages=state.SeenPages,Completed=state.Completed,Changed=changed,ReplayMode=true}
end

local function run(player,action,data)
	local replay=RunService:IsStudio() and config:GetAttribute("StudioReplayEveryPlay")==true
	local ok,result
	if replay then ok,result=true,replayRun(player,action,data)
	else
		local command={Action=action}
		for key,value in pairs(type(data)=="table" and data or {}) do command[key]=value end
		ok,result=pcall(function() return execute:Invoke(player,command) end)
	end
	if not ok or type(result)~="table" then return {Success=false,Message=tostring(result),ReplayMode=replay} end
	if result.Success then
		player:SetAttribute("NTR_OnboardingStage",result.Stage)
		if RunService:IsStudio() and result.Changed then
			print("[NTR Onboarding Replay] "..player.Name.." action="..tostring(action).." stage="..tostring(result.Stage))
		end
		if result.Changed then changedEvent:FireClient(player,result) end
	end
	return result
end

invoke.OnServerInvoke=function(player,action,data)
	action=tostring(action or "")
	if action=="GetState" then return run(player,"Get") end
	if action=="MarkSeen" then
		local pageId=tostring(type(data)=="table" and data.PageId or "")
		if not allowedPages[pageId] then return {Success=false,Message="Invalid page id."} end
		return run(player,"MarkSeen",{PageId=pageId})
	end
	return {Success=false,Message="Unsupported onboarding request."}
end

progress.Event:Connect(function(player,progressId)
	if player and player.Parent==Players then run(player,"RecordProgress",{ProgressId=progressId}) end
end)

local function checkVehicle(player)
	if player:GetAttribute("NTR_OnboardingStage")==1 then
		local world=workspace:FindFirstChild("NeoTokyoRacersWorld")
		local runtime=world and world:FindFirstChild("Runtime")
		local vehicles=runtime and runtime:FindFirstChild("PlayerVehicles")
		for _,vehicle in ipairs(vehicles and vehicles:GetChildren() or {}) do
			if vehicle:IsA("Model") and tonumber(vehicle:GetAttribute("OwnerUserId"))==player.UserId and tonumber(vehicle:GetAttribute("DriverUserId"))==player.UserId then
				local seat=vehicle:FindFirstChild("DriverSeat",true); local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if seat and seat:IsA("VehicleSeat") and humanoid and seat.Occupant==humanoid then progress:Fire(player,"FirstVehicleDriven"); return end
			end
		end
	end
end

local function initialise(player)
	while player.Parent==Players and player:GetAttribute("NTR_ProfileServiceLoaded")~=true do task.wait(.1) end
	if player.Parent~=Players then return end
	run(player,"Get")
end
Players.PlayerAdded:Connect(function(player) task.spawn(initialise,player) end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(initialise,player) end
Players.PlayerRemoving:Connect(function(player) replayStates[player]=nil end)
task.spawn(function()
	while true do task.wait(.5); for _,player in ipairs(Players:GetPlayers()) do checkVehicle(player) end end
end)
print("[NTR Onboarding] authoritative service active | StudioReplayEveryPlay="..tostring(RunService:IsStudio() and config:GetAttribute("StudioReplayEveryPlay")==true))
]=]

local ONBOARDING_CLIENT_SOURCE = [=[
-- NTR_PLAYER_ONBOARDING_V1_13_STATE_IMPORT_RACE_CONTROLS_TWO_LINE_OBJECTIVES
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local TextService=game:GetService("TextService")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("Onboarding_EditAttributes")
local loadingConfig=kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("LoadingSystem")
local Racing=require(kit:WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild("UI"):WaitForChild("RacingUIComponents"))
local GuideTrail=require(script.Parent:WaitForChild("OnboardingGuideTrailRenderer"))
local remotes=kit.Shared.Remotes:WaitForChild("Onboarding")
local invoke=remotes:WaitForChild("OnboardingInvoke")
local stateChanged=remotes:WaitForChild("OnboardingStateChanged")
local state={Stage=1,SeenPages={},Completed={}}
local stateReady=false
local guideTrail=GuideTrail.new(config)
local activePage,activeIndex
local presentationOwners={}
local GOLD=config:GetAttribute("TutorialGold") or Color3.fromRGB(255,196,66)
local DEEP=Color3.fromRGB(10,14,23)
local TEXT=Color3.fromRGB(246,248,252)
local FONT=Enum.Font.Michroma
local function setting(name,fallback) local value=config:GetAttribute(name); return value==nil and fallback or value end

local copy={
 G1="Vehicle categories group cars into families. Cars in the same category can share compatible modules.",
 G4="Tier shows the vehicle's performance class. Overall rating gives a quick summary of its total performance.",
 A2="You have limited vehicle space. Buy more garages to increase your capacity.",
 G2="Select a vehicle to preview it. Buy it to add it to your collection.",
 J1="Buy and equip modules in each vehicle slot. Modules can be swapped between vehicles in the same category.",
 J2="Upgrade the modules fitted to your vehicle. Each module has several upgrade paths and a limited point budget.",
 J3="Change your vehicle's paint and lighting per module. You can also customise thrust, neon and underglow.",
 K1="Choose a module location. Buy and swap modules from your different owned vehicles.",
 L1="Choose an equipped module to see its upgrades. Different modules offer different upgrade paths.",
 L2="Each module has a limited upgrade-point budget. Spending points on one upgrade leaves fewer for the others.",
 M1="Choose which part of the vehicle you want to customise. You can edit the whole vehicle, cockpit, effects or individual modules.",
 D7="Use the drift arrows while turning to slide around corners. Drifting helps with tighter turns.",
 D8="Hold Boost for a burst of speed. The boost meter shows how much energy remains.",
 B2="Open My Vehicles to spawn, switch or despawn your cars. New vehicles appear here after you buy them.",
 B4="Open the Race Browser to find events around the city. Events can support races, time trials or both.",
 N1="Select an event to view its route and details.",
 N6="Teleport to the selected event's starting area.",
 O1="Choose Race to compete against other players. Choose Time Trial to race against target times.",
 Q1="Choose a vehicle class for the time trial. Each class has separate target times, records and eligible vehicles.",
 Q5="This shows your selected class and the best available reward. Higher tiers have greater rewards.",
 Q8="Beat these target times to earn medals and cash. Faster times award higher medals.",
 Q4="Choose how many timed laps you want to run. Your best completed lap is used for the result.",
 P1="This shows the route, lap count and player limit. Multiplayer races use an open vehicle category.",
 B3="Open My Garages to view your owned properties. Each garage can display vehicles and has its own customisation.",
 X1="Choose one of your owned garage properties. Each card shows how many display spaces it contains.",
 X3="Enter the selected garage. You can manage its vehicles, assets and appearance from inside.",
 Z1="Choose which owned vehicles are displayed in your garage. Each vehicle is assigned to a physical display space.",
 Z2="Buy and equip different walls, floors, ceilings, decorations and lighting.",
 Z3="Customise the assets already equipped in your garage. Change their colours, materials and lighting.",
 AA1="Choose a display space to manage. Empty spaces can receive a vehicle, while occupied spaces can be changed.",
 AB1="Choose Structure, Decorations or Lighting. Build adds new assets; Style changes the look of equipped assets.",
 AC1="Choose which section of the garage you want to rebuild. The selected style is previewed in that location.",
 AD1="Choose where you want to place a decoration. Each location has its own compatible asset options.",
}
local pages={
 Dealership={"G1","G4","A2","G2"}, CustomisationHome={"J1","J2","J3"}, AddModules={"K1"},
 UpgradeModules={"L1","L2"}, PaintShop={"M1"}, MobileDriving={"D7","D8"}, VehicleShortcut={"B2"},
 RaceShortcut={"B4"}, RaceBrowser={"N1","N6"}, EventMode={"O1"}, TimeTrialSetup={"Q1","Q5","Q8","Q4"},
 RaceSetup={"P1"}, GarageShortcut={"B3"}, GarageBrowser={"X1","X3"},
 GarageHome={"Z1","Z2","Z3"}, DisplayCars={"AA1"}, GarageAssetFamilies={"AB1"}, BuildStructure={"AC1"}, BuildDecorations={"AD1"},
}
local actionSteps={N6=true,X3=true}
local placement={B2="Below",B3="Below",B4="Below",G4="Left",O1="Below",L2="Above",Z1="Above",Z2="Above",Z3="Above",AA1="Above",AB1="Above"}

local gui=Instance.new("ScreenGui"); gui.Name="NTR_OnboardingV1"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.DisplayOrder=math.max(1,(tonumber(loadingConfig:GetAttribute("DisplayOrder")) or 1000)-10); gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
pcall(function() gui.ScreenInsets=Enum.ScreenInsets.None end); pcall(function() gui.ClipToDeviceSafeArea=false end); gui.Parent=playerGui
local overlay=Instance.new("Frame"); overlay.Name="Overlay"; overlay.BackgroundTransparency=1; overlay.BorderSizePixel=0; overlay.Size=UDim2.fromScale(1,1); overlay.Parent=gui
local objectiveLayer=Instance.new("Frame"); objectiveLayer.Name="Objectives"; objectiveLayer.BackgroundTransparency=1; objectiveLayer.BorderSizePixel=0; objectiveLayer.Size=UDim2.fromScale(1,1); objectiveLayer.ClipsDescendants=false; objectiveLayer.ZIndex=10; objectiveLayer.Parent=gui
local objectiveCards={}
local shade={}; for i=1,4 do local f=Instance.new("TextButton"); f.Name="Shade"..i; f.Text=""; f.AutoButtonColor=false; f.BackgroundColor3=Color3.new(0,0,0); f.BackgroundTransparency=setting("DimTransparency",.35); f.BorderSizePixel=0; f.Visible=false; f.Active=true; f.ZIndex=20; f.Parent=overlay; shade[i]=f end
local catch=Instance.new("TextButton"); catch.Name="Advance"; catch.Text=""; catch.AutoButtonColor=false; catch.BackgroundTransparency=1; catch.Size=UDim2.fromScale(1,1); catch.Visible=false; catch.Active=true; catch.ZIndex=21; catch.Parent=overlay; pcall(function() catch.Modal=true end)
local border=Racing.Panel(overlay,{Name="HighlightBorder",Color=DEEP,Transparency=1,StrokeColor=GOLD,StrokeWidth=3,GlowWidth=4,GlowTransparency=.72,Radius=8}); border.Visible=false; border.ZIndex=22
local connector=Instance.new("Frame"); connector.Name="Connector"; connector.BackgroundColor3=GOLD; connector.BorderSizePixel=0; connector.Visible=false; connector.ZIndex=22; connector.Parent=overlay; Racing.Corner(connector,2)
local bubble=Racing.Panel(overlay,{Name="Bubble",Color=DEEP,Transparency=.03,StrokeColor=GOLD,StrokeWidth=2,GlowWidth=4,GlowTransparency=.76,Radius=8}); bubble.Visible=false; bubble.ZIndex=23; bubble.Active=true
local bubbleText=Racing.Label(bubble,{Name="Copy",Text="",Color=TEXT,Wrapped=true,YAlignment=Enum.TextYAlignment.Center}); bubbleText.ZIndex=24
local nextButton=Racing.Button(bubble,{Name="Next",Text="NEXT",Color=GOLD,TextColor=DEEP,StrokeColor=GOLD,FocusColor=GOLD,FocusFill=GOLD,Radius=6,ZIndex=24}); nextButton.AnchorPoint=Vector2.zero
local nextGradient=nextButton:FindFirstChild("GradientOverlay"); if nextGradient and nextGradient:IsA("Frame") then nextGradient.BackgroundTransparency=setting("NextGradientTransparency",.62) end

local function visible(object)
	if not (object and object:IsA("GuiObject") and object.AbsoluteSize.X>2 and object.AbsoluteSize.Y>2) then return false end
	local at=object
	while at and at~=playerGui do
		if at:IsA("GuiObject") and not at.Visible then return false end
		if at:IsA("LayerCollector") and not at.Enabled then return false end
		at=at.Parent
	end
	return at==playerGui
end
local function scopeRoot(object)
	if not object then return nil end
	local at=object
	while at.Parent and at.Parent~=playerGui do
		if at.Parent:IsA("ScreenGui") or at.Parent.Name=="CanonicalCanvas" then return at end
		at=at.Parent
	end
	return at
end
local function namedIn(root,name)
	if root and root.Name==name and visible(root) then return root end
	for _,object in ipairs(root and root:GetDescendants() or {}) do if object.Name==name and visible(object) then return object end end
end
local function named(name,root)
	if root then return namedIn(root,name) end
	for _,object in ipairs(playerGui:GetDescendants()) do if object.Name==name and visible(object) then return object end end
end
local function buttonWithText(text,root)
	text=string.upper(text); local search=root and root:GetDescendants() or playerGui:GetDescendants()
	for _,object in ipairs(search) do
		if (object:IsA("TextLabel") or object:IsA("TextButton")) and visible(object) and string.upper(object.Text)==text then
			local at=object
			while at and at~=playerGui do if at:IsA("GuiButton") and visible(at) then return at end; at=at.Parent end
		end
	end
end
local function labelStarts(prefix,root)
	prefix=string.upper(prefix); local search=root and root:GetDescendants() or playerGui:GetDescendants()
	for _,object in ipairs(search) do if object:IsA("TextLabel") and visible(object) and string.sub(string.upper(object.Text),1,#prefix)==prefix then return object end end
end
local function screenRoot(name)
	local screen=playerGui:FindFirstChild(name)
	if not (screen and screen:IsA("ScreenGui") and screen.Enabled) then return nil end
	for _,object in ipairs(screen:GetChildren()) do if object:IsA("GuiObject") and visible(object) then return object end end
	for _,object in ipairs(screen:GetDescendants()) do if object:IsA("GuiObject") and visible(object) then return scopeRoot(object) end end
end
local function canonicalBrowser()
	local screen=playerGui:FindFirstChild("CanonicalGarageGui"); local canvas=screen and screen:FindFirstChild("CanonicalCanvas"); local browser=canvas and canvas:FindFirstChild("CanonicalGarageBrowser")
	if browser and visible(browser) and buttonWithText("DEALERSHIP",browser)==nil then
		for _,object in ipairs(browser:GetDescendants()) do if object:IsA("TextLabel") and visible(object) and string.upper(object.Text)=="DEALERSHIP" then return browser end end
	elseif browser and visible(browser) then return browser end
end
local function group(root,...)
	local result={}; for _,name in ipairs({...}) do local object=named(name,root); if object then table.insert(result,object) end end; return #result>0 and result or nil
end
local function textGroup(root,...)
	local result={}; for _,value in ipairs({...}) do local object=buttonWithText(value,root); if object then table.insert(result,object) end end; return #result>0 and result or nil
end
local function cardGroup(root,...)
	local wanted={}; for _,id in ipairs({...}) do wanted[tostring(id)]=true end; local filter=next(wanted)~=nil; local result={}
	for _,object in ipairs(root and root:GetDescendants() or {}) do
		if object:IsA("GuiButton") and object:GetAttribute("CanonicalGarageCard")==true and visible(object) then
			local id=tostring(object:GetAttribute("CanonicalGarageCardId") or "")
			if not filter or wanted[id] then table.insert(result,object) end
		end
	end
	return #result>0 and result or nil
end
local function visibleScrollerCards(root,scrollerName)
	local scroller=named(scrollerName,root)
	if not scroller then return nil end
	local scrollerPosition,scrollerSize=scroller.AbsolutePosition,scroller.AbsoluteSize
	local result,fallback={},{}
	for _,object in ipairs(scroller:GetDescendants()) do
		if object:IsA("GuiButton") and object:GetAttribute("CanonicalGarageCard")==true and visible(object) then
			local position,size=object.AbsolutePosition,object.AbsoluteSize
			local intersects=position.X+size.X>scrollerPosition.X and position.X<scrollerPosition.X+scrollerSize.X
				and position.Y+size.Y>scrollerPosition.Y and position.Y<scrollerPosition.Y+scrollerSize.Y
			if intersects then
				table.insert(fallback,object)
				local fullyVisible=position.X>=scrollerPosition.X-1 and position.X+size.X<=scrollerPosition.X+scrollerSize.X+1
					and position.Y>=scrollerPosition.Y-1 and position.Y+size.Y<=scrollerPosition.Y+scrollerSize.Y+1
				if fullyVisible then table.insert(result,object) end
			end
		end
	end
	return #result>0 and result or #fallback>0 and fallback or nil
end
local function workspacePage(pageId)
	for _,root in ipairs(playerGui:GetDescendants()) do
		if root:IsA("GuiObject") and root:GetAttribute("TutorialWorkspace")==true and visible(root) and root:GetAttribute("TutorialPageId")==pageId then return root end
	end
end
local resolvers={
 G1=function(root) return group(root,"Categories") end, G4=function(root) return group(root,"Stats") end, A2=function(root) return group(root,"Capacity") end, G2=function(root) return visibleScrollerCards(root,"VehicleScroller") end,
 J1=function(root) return cardGroup(root,"AddModules") end, J2=function(root) return cardGroup(root,"UpgradeModules") end, J3=function(root) return cardGroup(root,"PaintShop") end,
 K1=function(root) return visibleScrollerCards(root,"TutorialCardScroller") end, L1=function(root) return group(root,"Categories") end, L2=function(root) return group(root,"UpgradeBudget") end, M1=function(root) return group(root,"Categories") end,
 D7=function(root) return group(root,"DriftLeft","DriftRight","DriftLeftButton","DriftRightButton") end, D8=function(root) return group(root,"Boost","BoostButton") end,
 B2=function(root) return group(root,"Car") end, B3=function(root) return group(root,"Garage") end, B4=function(root) return group(root,"Race") end,
 N1=function(root) return group(root,"CardContent") end, N6=function(root) return group(root,"TeleportToStart") end,
 O1=function(root) return textGroup(root,"TIME TRIAL","RACE") end, Q1=function(root) return group(root,"TierE","TierD","TierC","TierB","TierA","TierS") end, Q5=function(root) return group(root,"PrizeSummary") end, Q8=function(root) return group(root,"MedalTargets") end, Q4=function(root) return group(root,"LapSelector") end,
 P1=function(root) return group(root,"RaceFormat") or group(root,"DetailColumn") end,
 X1=function(root) return group(root,"GarageList") end, X3=function(root) return group(root,"Enter") end,
 Z1=function(root) return cardGroup(root,"DisplayCars") end, Z2=function(root) return cardGroup(root,"BuildGarage") end, Z3=function(root) return cardGroup(root,"StyleGarage") end,
 AA1=function(root) return visibleScrollerCards(root,"TutorialCardScroller") end, AB1=function(root) return cardGroup(root,"Structure","Decorations","Lighting") end, AC1=function(root) return group(root,"Categories") end, AD1=function(root) return group(root,"Categories") end,
}
local pageSignals={
 Dealership=function() return canonicalBrowser() end,
 CustomisationHome=function() return workspacePage("CustomisationHome") end,
 AddModules=function() return workspacePage("AddModules") end,
 UpgradeModules=function() return workspacePage("UpgradeModules") end,
 PaintShop=function() return workspacePage("PaintShop") end,
 MobileDriving=function() local object=UserInputService.TouchEnabled and (named("DriftLeft") or named("DriftLeftButton")); return object and scopeRoot(object) end,
 VehicleShortcut=function() local object=state.Stage>=2 and named("Car"); return object and scopeRoot(object) end,
 RaceShortcut=function() local object=state.SeenPages.GarageShortcut==true and named("Race"); return object and scopeRoot(object) end,
 RaceBrowser=function() return screenRoot("NTR_RaceBrowser") end,
 EventMode=function() local root=screenRoot("NTR_RaceEntryPresentation"); return root and buttonWithText("TIME TRIAL",root) and buttonWithText("RACE",root) and root end,
 TimeTrialSetup=function() local object=named("TierE"); local root=scopeRoot(object); return root and named("LapSelector",root) and root end,
 RaceSetup=function() local object=named("RaceFormat"); return object and scopeRoot(object) end,
 GarageShortcut=function() local object=state.SeenPages.VehicleShortcut==true and named("Garage"); return object and scopeRoot(object) end,
 GarageBrowser=function() return screenRoot("NTR_OwnedGarageBrowser") end,
 GarageHome=function() return workspacePage("GarageHome") end,
 DisplayCars=function() return workspacePage("DisplayCars") end,
 GarageAssetFamilies=function() return workspacePage("GarageAssetFamilies") end,
 BuildStructure=function() return workspacePage("BuildStructure") end,
 BuildDecorations=function() return workspacePage("BuildDecorations") end,
}
local pageOrder={"Dealership","CustomisationHome","AddModules","UpgradeModules","PaintShop","MobileDriving","VehicleShortcut","GarageShortcut","GarageBrowser","GarageHome","DisplayCars","GarageAssetFamilies","BuildStructure","BuildDecorations","RaceShortcut","RaceBrowser","EventMode","TimeTrialSetup","RaceSetup"}

local function canvasSize()
	local size=overlay.AbsoluteSize
	if size.X>2 and size.Y>2 then return size end
	local camera=workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280,720)
end
local function isLandscapePhone(canvas)
	local short=math.min(canvas.X,canvas.Y); local long=math.max(canvas.X,canvas.Y)
	return long>short and short<=setting("LandscapePhoneShortSidePixels",650)
end
local function ownerScale(objects,canvas)
	for _,object in ipairs(objects or {}) do
		local at=object
		while at and at~=playerGui do
			local scaler=at:FindFirstChildOfClass("UIScale")
			if scaler then return math.clamp(scaler.Scale,setting("TutorialMinimumScale",.38),setting("TutorialMaximumScale",1.08)) end
			at=at.Parent
		end
	end
	if isLandscapePhone(canvas) then return setting("LandscapePhoneScale",.6) end
	return math.clamp(math.min(canvas.X/1600,canvas.Y/900),setting("TutorialDesktopMinimumScale",.68),setting("TutorialMaximumScale",1.08))
end
local function tutorialMetrics(objects,canvas)
	local scale=ownerScale(objects,canvas); local phone=isLandscapePhone(canvas)
	local minimum=phone and setting("TutorialPhoneMinimumTextSize",9) or setting("TutorialDesktopMinimumTextSize",11)
	return scale,math.max(minimum,math.floor(setting("TutorialTextSize",14)*scale+.5)),phone
end
local function rect(objects,canvas)
	local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
	local origin=overlay.AbsolutePosition
	for _,object in ipairs(objects or {}) do
		if visible(object) then local p,s=object.AbsolutePosition-origin,object.AbsoluteSize; minX=math.min(minX,p.X); minY=math.min(minY,p.Y); maxX=math.max(maxX,p.X+s.X); maxY=math.max(maxY,p.Y+s.Y) end
	end
	if minX==math.huge then return end
	local scale=ownerScale(objects,canvas); local pad=math.max(3,setting("HighlightPaddingPixels",8)*scale)
	return math.floor(minX-pad),math.floor(minY-pad),math.ceil(maxX+pad),math.ceil(maxY+pad)
end
local layoutKey
local function hideOverlay() layoutKey=nil; for _,f in ipairs(shade) do f.Visible=false end; catch.Visible=false; border.Visible=false; bubble.Visible=false; connector.Visible=false end
local function guiInsets()
	local origin=overlay.AbsolutePosition
	local ok,topLeft,bottomRight=pcall(function() return GuiService:GetGuiInset() end)
	if not ok then return Vector2.zero,Vector2.zero end
	return topLeft-origin,bottomRight
end
local function safeRect(canvas,scale,reserveTopbar)
	local margin=math.max(6,setting("CalloutMarginPixels",12)*(scale or 1)); local left,top,right,bottom=margin,margin,canvas.X-margin,canvas.Y-margin
	local topLeft,bottomRight=guiInsets()
	left=math.max(left,topLeft.X+margin); right=math.min(right,canvas.X-bottomRight.X-margin); bottom=math.min(bottom,canvas.Y-bottomRight.Y-margin)
	if reserveTopbar~=false then top=math.max(top,topLeft.Y+margin) end
	return left,top,right,bottom
end
local function setShade(frame,x,y,w,h)
	frame.Position=UDim2.fromOffset(math.floor(x),math.floor(y)); frame.Size=UDim2.fromOffset(math.max(0,math.ceil(w)),math.max(0,math.ceil(h))); frame.Visible=true
end
local function placeConnector(x,y,right,bottom,bx,by,bw,bh,scale)
	local br,bottomBubble=bx+bw,by+bh; local thickness=math.max(2,math.floor(3*scale+.5))
	if bx>=right then connector.Position=UDim2.fromOffset(right,math.clamp((y+bottom)*.5,by,bottomBubble)); connector.Size=UDim2.fromOffset(math.max(thickness,bx-right),thickness)
	elseif br<=x then connector.Position=UDim2.fromOffset(br,math.clamp((y+bottom)*.5,by,bottomBubble)); connector.Size=UDim2.fromOffset(math.max(thickness,x-br),thickness)
	elseif by>=bottom then connector.Position=UDim2.fromOffset(math.clamp((x+right)*.5,bx,br),bottom); connector.Size=UDim2.fromOffset(thickness,math.max(thickness,by-bottom))
	else connector.Position=UDim2.fromOffset(math.clamp((x+right)*.5,bx,br),bottomBubble); connector.Size=UDim2.fromOffset(thickness,math.max(thickness,y-bottomBubble)) end
	connector.Visible=true
end
local function placeBubble(id,objects,x,y,right,bottom,canvas)
	local scale,textSize,phone=tutorialMetrics(objects,canvas); local safeLeft,safeTop,safeRight,safeBottom=safeRect(canvas,scale,not phone); local safeWidth=math.max(180,safeRight-safeLeft)
	local shortcut=id=="B2" or id=="B3" or id=="B4"; local phoneShortcut=phone and shortcut
	local stacked=safeWidth<setting("TutorialStackedWidthPixels",560); local pad=math.max(7,math.floor(16*scale+.5)); local gap=math.max(7,math.floor(14*scale+.5)); local buttonW=math.max(80,math.floor(104*scale+.5)); local buttonH=math.max(44,math.floor(44*scale+.5)); local action=actionSteps[id]==true
	local widthRatio=phoneShortcut and setting("LandscapePhoneShortcutWidthRatio",.34) or phone and setting("LandscapePhoneTextWidthRatio",.42) or .34; local widthCap=math.max(phone and 210 or 280,setting("TutorialMaximumTextWidth",520)*scale); local maxTextWidth=math.clamp(safeWidth*widthRatio,phone and 180 or 240,math.min(safeWidth,widthCap)); local bounds=TextService:GetTextSize(copy[id],textSize,FONT,Vector2.new(maxTextWidth,1000))
	local bw,bh
	if stacked and not action then
		bw=math.min(safeWidth,math.max(phone and 210 or 280,bounds.X+pad*2)); bounds=TextService:GetTextSize(copy[id],textSize,FONT,Vector2.new(bw-pad*2,1000)); bh=bounds.Y+pad*2+gap+buttonH
	else
		local reserve=action and 0 or gap+buttonW; local minimum=phone and math.max(220,300*scale) or math.max(300,360*scale)
		bw=math.min(safeWidth,math.max(minimum,bounds.X+pad*2+reserve)); local available=math.max(phone and 160 or 220,bw-pad*2-reserve); bounds=TextService:GetTextSize(copy[id],textSize,FONT,Vector2.new(available,1000)); bh=math.max(bounds.Y+pad*2,action and bounds.Y+pad*2 or buttonH+pad*2)
	end
	if phoneShortcut then
		local reserve=action and 0 or gap+buttonW; local cap=math.max(260,math.floor(safeWidth*setting("LandscapePhoneShortcutWidthRatio",.34)+.5))
		bw=math.min(bw,cap); local available=math.max(150,bw-pad*2-reserve); bounds=TextService:GetTextSize(copy[id],textSize,FONT,Vector2.new(available,1000)); bh=math.max(bounds.Y+pad*2,action and bounds.Y+pad*2 or buttonH+pad*2)
	end
	local targetW,targetH=right-x,bottom-y; local offset=phoneShortcut and math.max(1,math.floor(setting("LandscapePhoneShortcutGapPixels",2)+.5)) or shortcut and math.max(3,math.floor(setting("ShortcutCalloutGapPixels",7)*scale+.5)) or math.max(8,math.floor(18*scale+.5)); local above={x+(targetW-bw)*.5,y-bh-offset}; local below={x+(targetW-bw)*.5,bottom+offset}; local left={x-bw-offset,y+(targetH-bh)*.5}; local rightSide={right+offset,y+(targetH-bh)*.5}; local mode=placement[id] or (((y+bottom)*.5)>safeTop+(safeBottom-safeTop)*.62 and "Above" or "Auto")
	local candidates=mode=="Above" and {above,below,left,rightSide} or mode=="Below" and {below,above,left,rightSide} or mode=="Left" and {left,below,above,rightSide} or {rightSide,left,above,below}
	local bx,by
	for _,candidate in ipairs(candidates) do if candidate[1]>=safeLeft and candidate[2]>=safeTop and candidate[1]+bw<=safeRight and candidate[2]+bh<=safeBottom then bx,by=candidate[1],candidate[2]; break end end
	bx=math.clamp(bx or candidates[1][1],safeLeft,math.max(safeLeft,safeRight-bw)); by=math.clamp(by or candidates[1][2],safeTop,math.max(safeTop,safeBottom-bh))
	bubble.Position=UDim2.fromOffset(math.floor(bx),math.floor(by)); bubble.Size=UDim2.fromOffset(math.ceil(bw),math.ceil(bh)); bubbleText.Text=copy[id]; bubbleText.TextSize=textSize
	if stacked and not action then
		bubbleText.Position=UDim2.fromOffset(pad,pad); bubbleText.Size=UDim2.fromOffset(bw-pad*2,bounds.Y)
		nextButton.Position=UDim2.fromOffset(bw-pad-buttonW,bh-pad-buttonH); nextButton.Size=UDim2.fromOffset(buttonW,buttonH)
	else
		local reserve=action and 0 or gap+buttonW; bubbleText.Position=UDim2.fromOffset(pad,pad); bubbleText.Size=UDim2.fromOffset(bw-pad*2-reserve,bh-pad*2)
		nextButton.Position=UDim2.fromOffset(bw-pad-buttonW,(bh-buttonH)*.5); nextButton.Size=UDim2.fromOffset(buttonW,buttonH)
	end
	nextButton.TextSize=textSize; nextButton.Visible=not action; bubble.Visible=true; placeConnector(x,y,right,bottom,bx,by,bw,bh,scale)
end
local loadingState=script.Parent:WaitForChild("LoadingPresentationState")
local loadingChanged=script.Parent:WaitForChild("LoadingPresentationChanged")
local activeRoot,activeObjects
local targetConnections={}
local layoutGeneration=0
local resolveGeneration=0
local gateGeneration=0
local rootMissingAt
local warnedMissingTarget=false

local function loadingActive()
	return player:GetAttribute("NTR_StartScreenActive")==true or loadingState:GetAttribute("Active")==true
end
local function disconnectTargets()
	for _,connection in ipairs(targetConnections) do connection:Disconnect() end
	table.clear(targetConnections)
end
local function geometryKey(id,objects,canvas)
	local x,y,right,bottom=rect(objects,canvas)
	if not x then return nil end
	x=math.clamp(x,0,canvas.X); y=math.clamp(y,0,canvas.Y); right=math.clamp(right,x,canvas.X); bottom=math.clamp(bottom,y,canvas.Y)
	local origin=overlay.AbsolutePosition
	return table.concat({id,x,y,right,bottom,math.floor(origin.X),math.floor(origin.Y),math.floor(canvas.X),math.floor(canvas.Y)},":"),x,y,right,bottom
end
local function renderPinned()
	if loadingActive() or not (activePage and activeObjects) then hideOverlay(); return end
	local id=pages[activePage][activeIndex]; local canvas=canvasSize()
	local nextLayoutKey,x,y,right,bottom=geometryKey(id,activeObjects,canvas); if not nextLayoutKey then hideOverlay(); return end
	local action=actionSteps[id]==true
	if layoutKey==nextLayoutKey and border.Visible and bubble.Visible then catch.Visible=not action; nextButton.Visible=not action; return end
	layoutKey=nextLayoutKey
	local overscan=setting("EdgeOverscanPixels",8)
	setShade(shade[1],-overscan,-overscan,canvas.X+overscan*2,y+overscan)
	setShade(shade[2],-overscan,y,x+overscan,bottom-y)
	setShade(shade[3],right,y,canvas.X-right+overscan,bottom-y)
	setShade(shade[4],-overscan,bottom,canvas.X+overscan*2,canvas.Y-bottom+overscan)
	local scale=ownerScale(activeObjects,canvas); local stroke=border:FindFirstChild("Stroke"); local glow=border:FindFirstChild("GlowStroke"); if stroke then stroke.Thickness=math.max(1.5,3*scale) end; if glow then glow.Thickness=math.max(2,4*scale) end
	local bubbleStroke=bubble:FindFirstChild("Stroke"); local bubbleGlow=bubble:FindFirstChild("GlowStroke"); if bubbleStroke then bubbleStroke.Thickness=math.max(1.5,2*scale) end; if bubbleGlow then bubbleGlow.Thickness=math.max(2,4*scale) end
	border.Position=UDim2.fromOffset(x,y); border.Size=UDim2.fromOffset(right-x,bottom-y); border.Visible=true
	placeBubble(id,activeObjects,x,y,right,bottom,canvas); catch.Visible=not action
end
local function scheduleLayout()
	layoutGeneration+=1; local generation=layoutGeneration
	task.spawn(function()
		local stableFrames=math.max(2,math.floor(setting("TargetStabilityFrames",2))); local previous
		for _=1,stableFrames do
			RunService.RenderStepped:Wait()
			if generation~=layoutGeneration or loadingActive() or not (activePage and activeObjects) then return end
			local canvas=canvasSize(); local id=pages[activePage][activeIndex]; local key=geometryKey(id,activeObjects,canvas)
			if not key then hideOverlay(); return end
			if previous and previous~=key then scheduleLayout(); return end
			previous=key
		end
		if generation==layoutGeneration then renderPinned() end
	end)
end
overlay:GetPropertyChangedSignal("AbsolutePosition"):Connect(function() if activePage then scheduleLayout() end end)
overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if activePage then scheduleLayout() end end)
local scheduleResolve
local advance
local function pinObjects(objects)
	disconnectTargets(); activeObjects=objects; rootMissingAt=nil; warnedMissingTarget=false
	local id=activePage and pages[activePage] and pages[activePage][activeIndex]
	for _,object in ipairs(objects) do
		table.insert(targetConnections,object:GetPropertyChangedSignal("AbsolutePosition"):Connect(scheduleLayout))
		table.insert(targetConnections,object:GetPropertyChangedSignal("AbsoluteSize"):Connect(scheduleLayout))
		table.insert(targetConnections,object:GetPropertyChangedSignal("Visible"):Connect(scheduleResolve))
		table.insert(targetConnections,object.AncestryChanged:Connect(scheduleResolve))
		if actionSteps[id] and object:IsA("GuiButton") then
			table.insert(targetConnections,object.Activated:Connect(function()
				local expectedPage,expectedIndex,expectedId=activePage,activeIndex,id
				task.defer(function()
					if activePage==expectedPage and activeIndex==expectedIndex and pages[activePage][activeIndex]==expectedId then advance() end
				end)
			end))
		end
	end
	scheduleLayout()
end
scheduleResolve=function()
	resolveGeneration+=1; local generation=resolveGeneration; hideOverlay(); disconnectTargets(); activeObjects=nil
	task.delay(.08,function()
		if generation~=resolveGeneration or loadingActive() or not activePage then return end
		if not (activeRoot and activeRoot.Parent and visible(activeRoot)) then
			local signal=pageSignals[activePage]; local ok,newRoot=signal and pcall(signal)
			if ok and newRoot then activeRoot=newRoot; rootMissingAt=nil
			else
				rootMissingAt=rootMissingAt or os.clock()
				if os.clock()-rootMissingAt>=setting("PageAbandonSeconds",3) then
					print("[NTR Tutorial] page closed before completion: "..tostring(activePage)); activePage=nil; activeIndex=nil; activeRoot=nil; resolveGeneration+=1
				else scheduleResolve() end
				return
			end
		end
		local id=pages[activePage][activeIndex]; local objects=resolvers[id] and resolvers[id](activeRoot)
		if objects then pinObjects(objects)
		else
			if not warnedMissingTarget and rootMissingAt and os.clock()-rootMissingAt>1 then warnedMissingTarget=true; warn("[NTR Tutorial] waiting for target "..tostring(activePage).." "..tostring(id)) end
			rootMissingAt=rootMissingAt or os.clock(); scheduleResolve()
		end
	end)
end
local function beginPage(pageId,root)
	activePage=pageId; activeIndex=1; activeRoot=root; rootMissingAt=nil
	print("[NTR Tutorial] begin "..pageId.." "..pages[pageId][1]); scheduleResolve()
end
local function markSeen(pageId)
	local ok,result=pcall(function() return invoke:InvokeServer("MarkSeen",{PageId=pageId}) end)
	if ok and type(result)=="table" and result.Success then state=result end
end
local lastAdvance=0
advance=function()
	if not activePage or os.clock()-lastAdvance<.18 then return end
	lastAdvance=os.clock()
	activeIndex+=1
	if activeIndex>#pages[activePage] then
		local done=activePage; state.SeenPages[done]=true; activePage=nil; activeIndex=nil; activeRoot=nil; activeObjects=nil; resolveGeneration+=1; disconnectTargets(); hideOverlay(); print("[NTR Tutorial] complete "..done); task.spawn(markSeen,done)
	else
		print("[NTR Tutorial] advance "..activePage.." "..pages[activePage][activeIndex]); scheduleResolve()
	end
end
catch.Activated:Connect(advance); nextButton.Activated:Connect(advance)

local function visibleRoot(name)
	local object=named(name)
	return object and scopeRoot(object) or nil
end
local function controlsOpen()
	local screen=playerGui:FindFirstChild("NTR_DesktopFreeRoamHud")
	local design=screen and screen:FindFirstChild("DesignRoot")
	local modal=design and design:FindFirstChild("ModalLayer")
	local controls=modal and modal:FindFirstChild("Controls")
	return modal and controls and visible(modal) and visible(controls)
end
local function majorMenuOpen()
	for _,active in pairs(presentationOwners) do if active then return true end end
	if canonicalBrowser() then return true end
	for _,root in ipairs(playerGui:GetDescendants()) do if root:IsA("GuiObject") and root:GetAttribute("TutorialWorkspace")==true and visible(root) then return true end end
	for _,name in ipairs({"NTR_RaceBrowser","NTR_RaceEntryPresentation","NTR_OwnedGarageBrowser"}) do if screenRoot(name) then return true end end
	return playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true
		or player:GetAttribute("NTR_RaceSessionActive")==true
		or player:GetAttribute("NTRMobileFreeRoamCarMenuOpen")==true
		or player:GetAttribute("NTRMobileMajorMenuOpen")==true
		or visibleRoot("CarPanel")~=nil
		or visibleRoot("ModalLayer")~=nil
		or controlsOpen()==true
end
local objectiveContent={
	[1]={Title="BUY AND CUSTOMISE A CAR"},
	[2]={Title="EXPLORE YOUR GARAGE",Hint="Enter your garage and open customisation."},
	[3]={Title="ENTER AN EVENT",Hint="Join a race or start a time trial."},
}
local objectiveCompletionSnapshot=nil
local objectiveLayout={Left=16,Top=66,Width=350,Height=98,Gap=8,Scale=1,Safe=6,Phone=false}
local function objectiveComplete(index)
	if index==1 then return state.Completed.FirstVehiclePurchased==true and state.Completed.FirstVehicleDriven==true and state.SeenPages.VehicleShortcut==true end
	if index==2 then return state.Completed.GarageManagementEntered==true end
	return state.Completed.FirstEventEntered==true
end
local function objectiveDesired(index)
	if index==1 then return not objectiveComplete(1) end
	return objectiveComplete(1) and not objectiveComplete(index)
end
local function objectiveHint(index)
	if index==1 then return state.Completed.FirstVehiclePurchased==true and "Start driving your new vehicle." or "Follow the trail to the dealership." end
	return objectiveContent[index].Hint
end
local function objectiveOrder()
	local result={}
	for _,index in ipairs({1,2,3}) do if objectiveDesired(index) then table.insert(result,index) end end
	return result
end
local function createObjectiveCard(index)
	local group=Instance.new("CanvasGroup"); group.Name="Objective"..index; group.BackgroundTransparency=1; group.BorderSizePixel=0; group.GroupTransparency=1; group.ZIndex=10; group.Parent=objectiveLayer
	local panel=Racing.Panel(group,{Name="Panel",Color=DEEP,Transparency=.08,StrokeColor=GOLD,StrokeWidth=2,GlowWidth=5,GlowTransparency=.78,Radius=8}); panel.Size=UDim2.fromScale(1,1); panel.ZIndex=10; panel.Active=true
	local label=Racing.Label(panel,{Text="OBJECTIVE "..index,Color=GOLD,Role="Heading"}); label.ZIndex=11
	local title=Racing.Label(panel,{Text=objectiveContent[index].Title,Color=TEXT,Role="Heading",Wrapped=true,YAlignment=Enum.TextYAlignment.Top}); title.ZIndex=11
	local hint=Racing.Label(panel,{Text=objectiveHint(index),Color=Color3.fromRGB(190,196,210),Wrapped=true,YAlignment=Enum.TextYAlignment.Top}); hint.ZIndex=11
	local progress=Racing.Label(panel,{Text=index.."/3",Color=GOLD,XAlignment=Enum.TextXAlignment.Right,Role="Heading",Truncate=Enum.TextTruncate.None}); progress.ZIndex=11
	local card={Index=index,Group=group,Panel=panel,Label=label,Title=title,Hint=hint,Progress=progress,Animating=false,Exiting=false}
	objectiveCards[index]=card
	return card
end
local function styleObjectiveCard(card)
	local layout=objectiveLayout; local scale=layout.Scale; local safe=layout.Safe; local phone=layout.Phone; local pad=math.max(phone and 7 or 9,math.floor(setting("ObjectiveCardPaddingPixels",16)*scale+.5)); local textMultiplier=phone and 1 or setting("ObjectiveDesktopTextMultiplier",1.5)
	local function textSize(name,fallback,minimum) return math.max(minimum,math.floor(setting(name,fallback)*scale*textMultiplier+.5)) end
	local numberSize=textSize("ObjectiveNumberTextSize",10,8); local titleSize=textSize("ObjectiveTitleTextSize",13,9); local hintSize=textSize("ObjectiveHintTextSize",10,8); local progressSize=textSize("ObjectiveProgressTextSize",9,8)
	card.Group.Size=UDim2.fromOffset(layout.Width+safe*2,layout.Height+safe*2)
	card.Group.ClipsDescendants=false
	card.Panel.Position=UDim2.fromOffset(safe,safe); card.Panel.Size=UDim2.fromOffset(layout.Width,layout.Height); card.Panel.ClipsDescendants=false
	if phone then
		local labelY=3; local labelH=math.max(9,math.ceil(numberSize*1.1)); local titleY=labelY+labelH; local titleH=math.max(12,math.ceil(titleSize*1.25)); local hintY=titleY+titleH+1
		local hintLineH=math.max(9,math.ceil(hintSize*1.15)); local descriptionBottom=math.min(layout.Height-3,hintY+hintLineH*2); local progressH=14
		card.Label.Position=UDim2.fromOffset(pad,labelY); card.Label.Size=UDim2.new(1,-pad*2,0,labelH)
		card.Title.Position=UDim2.fromOffset(pad,titleY); card.Title.Size=UDim2.new(1,-pad*2,0,titleH)
		card.Hint.Position=UDim2.fromOffset(pad,hintY); card.Hint.Size=UDim2.new(1,-66,0,math.max(hintLineH,descriptionBottom-hintY))
		card.Progress.Position=UDim2.fromOffset(layout.Width-57,descriptionBottom-progressH); card.Progress.Size=UDim2.fromOffset(48,progressH)
	else
		card.Label.Position=UDim2.fromOffset(pad,6); card.Label.Size=UDim2.new(1,-pad*2,0,18)
		card.Title.Position=UDim2.fromOffset(pad,22); card.Title.Size=UDim2.new(1,-pad*2,0,38)
		local hintY=57; local hintLineH=math.max(12,math.ceil(hintSize*1.15)); local descriptionBottom=layout.Height-7; local progressH=18
		card.Hint.Position=UDim2.fromOffset(pad,hintY); card.Hint.Size=UDim2.new(1,-82,0,math.max(hintLineH,descriptionBottom-hintY)) -- NTR_ONBOARDING_DESKTOP_TWO_LINE_OBJECTIVE_V1
		card.Progress.Position=UDim2.fromOffset(layout.Width-66,hintY+math.floor((descriptionBottom-hintY-progressH)*.5)); card.Progress.Size=UDim2.fromOffset(52,progressH)
	end
	card.Label.TextSize=numberSize
	card.Title.TextSize=titleSize
	card.Hint.Text=objectiveHint(card.Index); card.Hint.TextSize=hintSize
	card.Progress.TextSize=progressSize
	local stroke=card.Panel:FindFirstChild("Stroke"); local glow=card.Panel:FindFirstChild("GlowStroke"); if stroke then stroke.Thickness=math.max(1,2*scale) end; if glow then glow.Thickness=math.max(2,4*scale) end
end
local function targetObjectivePosition(orderIndex)
	local layout=objectiveLayout
	return UDim2.fromOffset(layout.Left-layout.Safe,layout.Top-layout.Safe+(orderIndex-1)*(layout.Height+layout.Gap))
end
local function cancelObjectiveTween(card)
	if card.Tween then card.Tween:Cancel(); card.Tween=nil end
end
local function layoutObjectives(animate)
	for orderIndex,index in ipairs(objectiveOrder()) do
		local card=objectiveCards[index]
		if card and not card.Exiting then
			styleObjectiveCard(card)
			local target=targetObjectivePosition(orderIndex)
			if not card.Animating then
				cancelObjectiveTween(card)
				if animate then
					card.Animating=true
					card.Tween=TweenService:Create(card.Group,TweenInfo.new(setting("ObjectiveReflowSeconds",.45),Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=target})
					card.Tween.Completed:Once(function() card.Animating=false; card.Tween=nil end)
					card.Tween:Play()
				else card.Group.Position=target end
			end
		end
	end
end
local function enterObjective(index,stagger)
	if not objectiveDesired(index) or objectiveCards[index] then return end
	task.delay(stagger or 0,function()
		if not objectiveDesired(index) or objectiveCards[index] then return end
		local card=createObjectiveCard(index); styleObjectiveCard(card)
		local orderIndex=table.find(objectiveOrder(),index) or 1; local target=targetObjectivePosition(orderIndex)
		card.Group.Position=UDim2.fromOffset(objectiveLayout.Left-objectiveLayout.Width-objectiveLayout.Safe*2-setting("ObjectiveOffscreenPaddingPixels",24),target.Y.Offset)
		card.Animating=true
		card.Tween=TweenService:Create(card.Group,TweenInfo.new(setting("ObjectiveEnterSeconds",.55),Enum.EasingStyle.Quint,Enum.EasingDirection.Out),{Position=target,GroupTransparency=0})
		card.Tween.Completed:Once(function() card.Animating=false; card.Tween=nil end)
		card.Tween:Play()
	end)
end
local function exitObjective(index)
	local card=objectiveCards[index]
	if not card or card.Exiting then return end
	card.Exiting=true; cancelObjectiveTween(card)
	task.delay(setting("ObjectiveExitHoldSeconds",.15),function()
		if objectiveCards[index]~=card then return end
		card.Animating=true
		local target=UDim2.fromOffset(objectiveLayout.Left-objectiveLayout.Width-objectiveLayout.Safe*2-setting("ObjectiveOffscreenPaddingPixels",24),card.Group.Position.Y.Offset)
		card.Tween=TweenService:Create(card.Group,TweenInfo.new(setting("ObjectiveExitSeconds",.4),Enum.EasingStyle.Quart,Enum.EasingDirection.In),{Position=target,GroupTransparency=1})
		card.Tween.Completed:Once(function()
			if objectiveCards[index]==card then objectiveCards[index]=nil end
			card.Group:Destroy()
		end)
		card.Tween:Play()
	end)
end
local function syncObjectives()
	if not stateReady then return end
	local objectiveOneWasComplete=objectiveCompletionSnapshot and objectiveCompletionSnapshot[1] or false
	local objectiveOneNowComplete=objectiveComplete(1)
	for _,index in ipairs({1,2,3}) do if objectiveCards[index] and not objectiveDesired(index) then exitObjective(index) end end
	local unlockDelay=objectiveCompletionSnapshot and not objectiveOneWasComplete and objectiveOneNowComplete
		and setting("ObjectiveExitHoldSeconds",.15)+setting("ObjectiveExitSeconds",.4) or 0
	for orderIndex,index in ipairs(objectiveOrder()) do
		if not objectiveCards[index] then enterObjective(index,unlockDelay+(orderIndex-1)*setting("ObjectiveStaggerSeconds",.1)) end
	end
	objectiveCompletionSnapshot={objectiveComplete(1),objectiveComplete(2),objectiveComplete(3)}
	if unlockDelay>0 then task.delay(unlockDelay*.45,function() layoutObjectives(true) end) else layoutObjectives(true) end
end
local function refreshObjective()
	local canvas=canvasSize(); local inside=player:GetAttribute("NTR_OwnedGarageInside")==true; local access=inside and named("AccessControls")
	local reference=access or named("Car") or named("Race") or named("Garage"); local objects=reference and {reference} or nil; local scale=ownerScale(objects,canvas); local phone=isLandscapePhone(canvas)
	local left,top,right,bottom=safeRect(canvas,scale,not phone); local width=math.min(math.floor(setting("ObjectiveCardWidthPixels",350)*scale+.5),math.max(math.floor(220*scale+.5),right-left)); local height=phone and math.floor(setting("ObjectivePhoneCardHeightPixels",48)+.5) or math.max(68,math.floor(setting("ObjectiveCardHeightPixels",98)*scale+.5)); local gap=phone and math.floor(setting("ObjectivePhoneCardGapPixels",4)+.5) or math.max(5,math.floor(setting("ObjectiveCardGapPixels",8)*scale+.5)); local safe=math.max(3,math.floor(setting("ObjectiveGlowSafePaddingPixels",6)*scale+.5)); local y=math.max(top,66)
	if phone then
		y=math.max(top,setting("ObjectivePhoneFallbackTopPixels",94))
		if reference and not access then
			local referencePosition=reference.AbsolutePosition-overlay.AbsolutePosition
			y=math.max(top,referencePosition.Y+reference.AbsoluteSize.Y+setting("ObjectivePhoneTopRowClearancePixels",14))
		end
	end
	if phone and not access then
		local boost=named("BoostButton") or named("Boost"); local count=math.max(1,#objectiveOrder())
		if boost then
			local position,size=boost.AbsolutePosition-overlay.AbsolutePosition,boost.AbsoluteSize
			local overlapsX=position.X+size.X>left and position.X<left+width
			if overlapsX then
				local available=position.Y-setting("ObjectivePhoneBoostGapPixels",4)-y-gap*(count-1)
				if available>0 then height=math.max(setting("ObjectivePhoneMinimumCardHeightPixels",46),math.min(height,math.floor(available/count))) end
			end
		end
	end
	if access then
		local localPosition=access.AbsolutePosition-overlay.AbsolutePosition
		left=math.clamp(localPosition.X,left,math.max(left,right-width))
		width=math.min(math.max(math.floor(200*scale+.5),access.AbsoluteSize.X),right-left)
		local count=math.max(1,#objectiveOrder()); local stackHeight=height*count+gap*(count-1)
		y=math.clamp(localPosition.Y+access.AbsoluteSize.Y+math.max(6,math.floor(8*scale+.5)),top,math.max(top,bottom-stackHeight))
	end
	objectiveLayout={Left=left,Top=y,Width=width,Height=height,Gap=gap,Scale=scale,Safe=safe,Phone=phone}
	layoutObjectives(false)
	local shortcutPrompt=activePage=="VehicleShortcut" or activePage=="RaceShortcut" or activePage=="GarageShortcut"
	objectiveLayer.Visible=stateReady and #objectiveOrder()>0 and not loadingActive() and not majorMenuOpen() and (not activePage or shortcutPrompt)
end
local function nearestGarageDesk()
	local character=player.Character; local root=character and character:FindFirstChild("HumanoidRootPart"); if not root then return nil end
	local best,bestDistance
	for _,object in ipairs(workspace:GetDescendants()) do
		if object.Name=="DeskPromptAnchor" and object:IsA("BasePart") and object:FindFirstAncestor("ManagementDesk") then
			local distance=(object.Position-root.Position).Magnitude
			if not bestDistance or distance<bestDistance then best,bestDistance=object,distance end
		end
	end
	return best
end
local function updateGuideTrail()
	if loadingActive() then guideTrail:Clear(); return end
	if state.Completed.FirstVehiclePurchased~=true then
		local world=workspace:FindFirstChild("NeoTokyoRacersWorld"); local intro=world and world:FindFirstChild("Dealership") and world.Dealership:FindFirstChild("Intro"); local desk=intro and intro:FindFirstChild("Desk") and intro.Desk:FindFirstChild("GarageDeskTrigger")
		guideTrail:SetTarget(desk)
	elseif player:GetAttribute("NTR_OwnedGarageInside")==true and state.Completed.GarageManagementEntered~=true and playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")~=true then
		guideTrail:SetTarget(nearestGarageDesk())
	else guideTrail:Clear() end
end
local function applyLocks()
	local unlocks={Car=state.SeenPages.VehicleShortcut==true,Race=state.SeenPages.RaceShortcut==true,Garage=state.SeenPages.GarageShortcut==true}
	for name,unlocked in pairs(unlocks) do
		for _,object in ipairs(playerGui:GetDescendants()) do if object.Name==name and object:IsA("GuiButton") then object.Active=unlocked; object.Selectable=unlocked; object.AutoButtonColor=unlocked end end
	end
end
local function activelyDriving()
	local world=workspace:FindFirstChild("NeoTokyoRacersWorld"); local runtime=world and world:FindFirstChild("Runtime"); local vehicles=runtime and runtime:FindFirstChild("PlayerVehicles")
	for _,vehicle in ipairs(vehicles and vehicles:GetChildren() or {}) do if vehicle:IsA("Model") and tonumber(vehicle:GetAttribute("OwnerUserId"))==player.UserId and tonumber(vehicle:GetAttribute("DriverUserId"))==player.UserId then local seat=vehicle:FindFirstChild("DriverSeat",true); local humanoid=player.Character and player.Character:FindFirstChildOfClass("Humanoid"); if seat and seat:IsA("VehicleSeat") and humanoid and seat.Occupant==humanoid then return vehicle end end end
	return nil
end
local pcControlsAwaitClose=false
local function pollPages()
	if loadingActive() or activePage then return end
	if pcControlsAwaitClose then
		if controlsOpen() then return end
		pcControlsAwaitClose=false
	end
	local drivenVehicle=activelyDriving()
	local raceDriving=drivenVehicle and (drivenVehicle:GetAttribute("NTR_RaceParticipant")==true or drivenVehicle:GetAttribute("NTR_RaceRunId")~=nil)
	if not UserInputService.TouchEnabled and state.Stage>=2 and state.SeenPages.PCDriving~=true and drivenVehicle and not raceDriving then -- NTR_ONBOARDING_FREE_ROAM_CONTROLS_ONLY_V1
		local event=script.Parent:FindFirstChild("OpenDrivingControlsFromOnboarding")
		if event and event:IsA("BindableEvent") then
			pcControlsAwaitClose=true; state.SeenPages.PCDriving=true; event:Fire(); task.spawn(markSeen,"PCDriving"); return
		end
	end
	for _,pageId in ipairs(pageOrder) do local signal=pageSignals[pageId]
		if state.SeenPages[pageId]~=true then local ok,result=pcall(signal); if ok and result then beginPage(pageId,result); return end end
	end
end
local function accept(newState)
	if type(newState)=="table" and newState.Success then state=newState; stateReady=true end
	applyLocks(); syncObjectives(); refreshObjective()
end
stateChanged.OnClientEvent:Connect(accept)
local presentation=script.Parent:FindFirstChild("FreeRoamHudPresentationMode")
if presentation and presentation:IsA("BindableEvent") then presentation.Event:Connect(function(payload) if type(payload)=="table" then presentationOwners[tostring(payload.Owner or "Unknown")]=payload.Active==true end end) end
local function refreshLoadingGate()
	gateGeneration+=1; local generation=gateGeneration
	if loadingActive() then gui.Enabled=false; hideOverlay(); return end
	task.spawn(function()
		RunService.RenderStepped:Wait(); RunService.RenderStepped:Wait()
		if generation~=gateGeneration or loadingActive() then return end
		gui.Enabled=true
		if activePage then scheduleResolve() else refreshObjective(); pollPages() end
	end)
end
player:GetAttributeChangedSignal("NTR_StartScreenActive"):Connect(refreshLoadingGate)
loadingState:GetAttributeChangedSignal("Active"):Connect(refreshLoadingGate)
loadingChanged.Event:Connect(refreshLoadingGate)
task.spawn(function() local ok,result=pcall(function() return invoke:InvokeServer("GetState",{}) end); if ok then accept(result) end end)
local elapsed=0
RunService.RenderStepped:Connect(function(dt) elapsed+=dt; if elapsed<.2 then return end; elapsed=0; applyLocks(); refreshObjective(); updateGuideTrail(); pollPages() end)
refreshLoadingGate()
print("[NTR Onboarding] client active V1.13 | protected state imports | free-roam controls gate | two-line desktop objectives")
]=]

local GUIDE_TRAIL_RENDERER_SOURCE = [=[
-- NTR_ONBOARDING_GUIDE_TRAIL_RENDERER_V4_TEXTURED_CHEVRON_BEAM
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Renderer={}
Renderer.__index=Renderer

local function number(config,name,fallback)
	local value=config:GetAttribute(name)
	return tonumber(value) or fallback
end
local function boolean(config,name,fallback)
	local value=config:GetAttribute(name)
	return type(value)=="boolean" and value or fallback
end
local function texture(config,name)
	local value=tostring(config:GetAttribute(name) or "")
	value=string.gsub(value,"^%s+",""); value=string.gsub(value,"%s+$","")
	if value=="" then return "" end
	if string.match(value,"^%d+$") then return "rbxassetid://"..value end
	if string.match(value,"^rbxassetid://%d+$") then return value end
	warn("[NTR Onboarding] GuideTrailChevronTexture must be a numeric asset ID or rbxassetid:// URI; using Part-arrow fallback")
	return ""
end
local function makeArrowPart(parent,name,size,color,transparency)
	local object=Instance.new("Part")
	object.Name=name; object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false
	object.CastShadow=false; object.Material=Enum.Material.Neon; object.Color=color; object.Transparency=transparency; object.Size=size
	object.TopSurface=Enum.SurfaceType.Smooth; object.BottomSurface=Enum.SurfaceType.Smooth; object.Parent=parent
	return object
end
local function makeBeamAnchor(parent,name)
	local object=Instance.new("Part"); object.Name=name; object.Anchored=true; object.CanCollide=false; object.CanTouch=false; object.CanQuery=false; object.CastShadow=false; object.Transparency=1; object.Size=Vector3.new(.2,.2,.2); object.Parent=parent
	local attachment=Instance.new("Attachment"); attachment.Name="Attachment"; attachment.Parent=object
	return object,attachment
end
local function createBeam(parent,config,color)
	if not boolean(config,"GuideTrailBeamEnabled",true) then return nil end
	local folder=Instance.new("Folder"); folder.Name="DynamicBeam"; folder.Parent=parent
	local startPart,startAttachment=makeBeamAnchor(folder,"BeamStart")
	local endPart,endAttachment=makeBeamAnchor(folder,"BeamEnd")
	local aura=Instance.new("Beam"); aura.Name="AuraBeam"; aura.Attachment0=startAttachment; aura.Attachment1=endAttachment; aura.Color=ColorSequence.new(color); aura.Transparency=NumberSequence.new(number(config,"GuideTrailBeamTransparency",.58)); aura.Width0=number(config,"GuideTrailBeamWidth",3.5); aura.Width1=aura.Width0; aura.LightEmission=1; aura.Brightness=1.8; aura.FaceCamera=true; aura.Segments=16; aura.Enabled=false; aura.Parent=folder
	local core=Instance.new("Beam"); core.Name="CoreBeam"; core.Attachment0=startAttachment; core.Attachment1=endAttachment; core.Color=ColorSequence.new(color); core.Transparency=NumberSequence.new(number(config,"GuideTrailBeamCoreTransparency",.25)); core.Width0=number(config,"GuideTrailBeamCoreWidth",.8); core.Width1=core.Width0; core.LightEmission=1; core.Brightness=2.2; core.FaceCamera=true; core.Segments=16; core.Enabled=false; core.Parent=folder
	local chevronTexture=texture(config,"GuideTrailChevronTexture"); local chevron=nil
	if boolean(config,"GuideTrailChevronBeamEnabled",true) and chevronTexture~="" then
		chevron=Instance.new("Beam"); chevron.Name="ChevronBeam"; chevron.Attachment0=startAttachment; chevron.Attachment1=endAttachment; chevron.Color=ColorSequence.new(color); chevron.Transparency=NumberSequence.new(math.clamp(number(config,"GuideTrailChevronTransparency",.08),0,1)); chevron.Width0=math.max(.1,number(config,"GuideTrailChevronWidth",2.2)); chevron.Width1=chevron.Width0; chevron.LightEmission=1; chevron.Brightness=math.max(0,number(config,"GuideTrailChevronBrightness",2)); chevron.FaceCamera=true; chevron.Segments=16; chevron.Texture=chevronTexture; chevron.TextureMode=Enum.TextureMode.Wrap; chevron.TextureLength=math.max(.1,number(config,"GuideTrailChevronTextureLength",6)); chevron.TextureSpeed=number(config,"GuideTrailChevronTextureSpeed",1.5); chevron.ZOffset=number(config,"GuideTrailChevronZOffset",.05); chevron.Enabled=false; chevron.Parent=folder
	end
	return {StartPart=startPart,EndPart=endPart,Aura=aura,Core=core,Chevron=chevron}
end
local function createArrow(parent,index,config,color)
	local scale=number(config,"GuideTrailArrowScale",1); local transparency=math.clamp(number(config,"GuideTrailTransparency",.12),0,.9)
	local model=Instance.new("Model"); model.Name=string.format("DynamicArrow_%02d",index); model.Parent=parent
	local shaft=makeArrowPart(model,"Shaft",Vector3.new(number(config,"GuideTrailArrowWidth",.42),.16,number(config,"GuideTrailShaftLength",2.6))*scale,color,transparency)
	local left=makeArrowPart(model,"HeadLeft",Vector3.new(number(config,"GuideTrailHeadWidth",.36),.16,number(config,"GuideTrailHeadLength",1.05))*scale,color,transparency)
	local right=makeArrowPart(model,"HeadRight",left.Size,color,transparency)
	return {Model=model,Shaft=shaft,Left=left,Right=right,Transparency=transparency,ShaftEnabled=boolean(config,"GuideTrailShaftEnabled",true)}
end
local function setArrowVisible(arrow,shown)
	local transparency=shown and arrow.Transparency or 1
	arrow.Shaft.Transparency=arrow.ShaftEnabled and transparency or 1; arrow.Left.Transparency=transparency; arrow.Right.Transparency=transparency
end
local function setBeamVisible(beam,shown)
	if beam then beam.Aura.Enabled=shown; beam.Core.Enabled=shown; if beam.Chevron then beam.Chevron.Enabled=shown end end
end
function Renderer.new(config)
	local self=setmetatable({},Renderer)
	self.Config=config; self.Target=nil; self.Folder=nil; self.Arrows={}; self.Beam=nil; self.Elapsed=0
	self.Connection=RunService.RenderStepped:Connect(function(dt) self:Update(dt) end)
	return self
end
function Renderer:EnsureFolder()
	if self.Folder and self.Folder.Parent then return self.Folder end
	local client=workspace:FindFirstChild("_NTR_ClientOnly")
	if not client then client=Instance.new("Folder"); client.Name="_NTR_ClientOnly"; client.Parent=workspace end
	local old=client:FindFirstChild("OnboardingGuideTrail"); if old then old:Destroy() end
	self.Folder=Instance.new("Folder"); self.Folder.Name="OnboardingGuideTrail"; self.Folder.Parent=client
	local color=self.Config:GetAttribute("TutorialGold") or Color3.fromRGB(255,196,66)
	self.Beam=createBeam(self.Folder,self.Config,color)
	local hasChevron=self.Beam and self.Beam.Chevron~=nil
	local usePartArrows=boolean(self.Config,"GuideTrailPartArrowsEnabled",false) or not hasChevron
	if usePartArrows then
		for index=1,math.max(1,math.floor(number(self.Config,"GuideTrailMaximumArrows",18))) do
			self.Arrows[index]=createArrow(self.Folder,index,self.Config,color); setArrowVisible(self.Arrows[index],false)
		end
	end
	return self.Folder
end
function Renderer:SetTarget(target)
	if not (target and target:IsA("BasePart") and target.Parent) then self:Clear(); return end
	if self.Target==target then return end
	self.Target=target; self:EnsureFolder()
end
function Renderer:Clear()
	if not self.Target and not self.Folder then return end
	self.Target=nil
	if self.Folder then self.Folder:Destroy(); self.Folder=nil end
	table.clear(self.Arrows); self.Beam=nil
end
function Renderer:Update(dt)
	local target=self.Target
	if not (target and target.Parent) then if self.Target then self:Clear() end; return end
	local player=Players.LocalPlayer; local character=player and player.Character; local root=character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local start=root.Position; local finish=target.Position; local delta=finish-start; local flatDelta=Vector3.new(delta.X,0,delta.Z); local distance=flatDelta.Magnitude
	local minimum=number(self.Config,"GuideTrailMinimumDistance",7)
	if distance<=minimum then
		setBeamVisible(self.Beam,false); for _,item in ipairs(self.Arrows) do setArrowVisible(item,false) end
		return
	end
	self:EnsureFolder()
	local direction=flatDelta.Unit; local startOffset=number(self.Config,"GuideTrailStartOffset",4); local endOffset=number(self.Config,"GuideTrailEndOffset",3)
	local usableDistance=math.max(0,distance-startOffset-endOffset); local spacing=math.max(3,number(self.Config,"GuideTrailSpacing",9))
	local count=0
	if #self.Arrows>0 then count=math.clamp(math.floor(usableDistance/spacing),1,#self.Arrows) end
	local trailHeight=number(self.Config,"GuideTrailHeightOffset",1.8); local height=Vector3.new(0,trailHeight,0)
	local beamStartHeight=number(self.Config,"GuideTrailBeamStartHeightOffset",-1); local beamStart=start+direction*startOffset+Vector3.new(0,beamStartHeight,0); local beamEnd=finish-direction*endOffset+height
	if self.Beam then self.Beam.StartPart.CFrame=CFrame.new(beamStart); self.Beam.EndPart.CFrame=CFrame.new(beamEnd); setBeamVisible(self.Beam,true) end
	self.Elapsed+=dt; local pulseSpeed=number(self.Config,"GuideTrailPulseSpeed",2); local pulseAmplitude=math.max(0,number(self.Config,"GuideTrailPulseAmplitude",.4)); local scale=number(self.Config,"GuideTrailArrowScale",1)
	local shaftForward=number(self.Config,"GuideTrailShaftLength",2.6)*.48*scale
	local headForward=(number(self.Config,"GuideTrailShaftLength",2.6)*.78+number(self.Config,"GuideTrailHeadLength",1.05)*.45)*scale
	local headSide=number(self.Config,"GuideTrailHeadWidth",.36)*.95*scale
	local color=self.Config:GetAttribute("TutorialGold") or Color3.fromRGB(255,196,66)
	if self.Beam then self.Beam.Aura.Color=ColorSequence.new(color); self.Beam.Core.Color=ColorSequence.new(color); if self.Beam.Chevron then self.Beam.Chevron.Color=ColorSequence.new(color) end end
	for index,item in ipairs(self.Arrows) do
		for _,object in ipairs({item.Shaft,item.Left,item.Right}) do object.Color=color end
		if index<=count then
			local travel=startOffset+usableDistance*(index/(count+1)); local center=start+direction*travel+height
			local frame=CFrame.lookAt(center,center+direction); local rightVector=frame.RightVector; local lift=Vector3.new(0,pulseSpeed>0 and pulseAmplitude*math.sin(self.Elapsed*pulseSpeed+index*.55) or 0,0)
			item.Shaft.CFrame=frame+lift
			item.Left.CFrame=CFrame.lookAt(center+lift+direction*shaftForward-rightVector*headSide,center+lift+direction*headForward)
			item.Right.CFrame=CFrame.lookAt(center+lift+direction*shaftForward+rightVector*headSide,center+lift+direction*headForward)
			setArrowVisible(item,true)
		else setArrowVisible(item,false) end
	end
end
function Renderer:Destroy()
	self:Clear(); if self.Connection then self.Connection:Disconnect(); self.Connection=nil end
end
return Renderer
]=]

local projected = {
	{Object=profileService, Source=projectProfile(profileService.Source), Marker=PROFILE_MARKER},
	{Object=raceService, Source=projectRace(raceService.Source), Marker=RACE_MARKER},
	{Object=trialService, Source=projectTrial(trialService.Source), Marker=TRIAL_MARKER},
	{Object=garageAction, Source=projectGarageAction(garageAction.Source), Marker=PURCHASE_MARKER},
	{Object=garageRuntime, Source=projectGarage(garageRuntime.Source), Marker=GARAGE_MARKER},
	{Object=desktopHud, Source=projectDesktop(desktopHud.Source), Marker=DESKTOP_MARKER},
	{Object=garageWorkspace, Source=projectGarageWorkspace(garageWorkspace.Source), Marker=WORKSPACE_SEMANTIC_MARKER},
	{Object=moduleShop, Source=projectModuleShop(moduleShop.Source), Marker=MODULE_SEMANTIC_MARKER},
	{Object=ownedGarageWorkspace, Source=projectOwnedGarageWorkspace(ownedGarageWorkspace.Source), Marker=OWNED_SEMANTIC_MARKER},
}
for _,item in ipairs(projected) do
	assert(has(item.Source,item.Marker),item.Marker.." projection failed")
	compile(item.Object:GetFullName(),item.Source)
end
compile("OnboardingService_Active",ONBOARDING_SERVICE_SOURCE)
compile("OnboardingClient_Active",ONBOARDING_CLIENT_SOURCE)
compile("OnboardingGuideTrailRenderer",GUIDE_TRAIL_RENDERER_SOURCE)

local created, sourceSnapshots, attributeSnapshots = {}, {}, {}
local onboardingConfig = ensure(runtimeConfig,"Onboarding_EditAttributes","Folder",created)
local onboardingRemotes = ensure(sharedRemotes,"Onboarding","Folder",created)
ensure(onboardingRemotes,"OnboardingInvoke","RemoteFunction",created)
ensure(onboardingRemotes,"OnboardingStateChanged","RemoteEvent",created)
local progress = ensure(playerServices,"OnboardingProgress","BindableEvent",created)
ensure(uiControllers,"OpenDrivingControlsFromOnboarding","BindableEvent",created)
local onboardingService = ensure(playerServices,"OnboardingService_Active","Script",created)
local onboardingClient = ensure(uiControllers,"OnboardingClient_Active","LocalScript",created)
local guideTrailRenderer = ensure(uiControllers,"OnboardingGuideTrailRenderer","ModuleScript",created)

local world = workspace:FindFirstChild("NeoTokyoRacersWorld")
local intro = world and world:FindFirstChild("Dealership") and world.Dealership:FindFirstChild("Intro")

local function snapshotAttribute(object,name)
	table.insert(attributeSnapshots,{Object=object,Name=name,Had=object:GetAttribute(name)~=nil,Value=object:GetAttribute(name)})
end
local function audit()
	assert(kit:GetAttribute("PlayerOnboardingRevision")==REVISION,"Onboarding revision missing")
	assert(onboardingService.Source==ONBOARDING_SERVICE_SOURCE,"Onboarding service source mismatch")
	assert(onboardingClient.Source==ONBOARDING_CLIENT_SOURCE,"Onboarding client source mismatch")
	assert(guideTrailRenderer.Source==GUIDE_TRAIL_RENDERER_SOURCE,"Onboarding guide trail renderer source mismatch")
	assert(progress:IsA("BindableEvent"),"Onboarding progress bridge missing")
	assert(type(onboardingConfig:GetAttribute("StudioReplayEveryPlay"))=="boolean","StudioReplayEveryPlay config missing")
	assert(type(onboardingConfig:GetAttribute("StudioVehicleSandboxEveryPlay"))=="boolean","StudioVehicleSandboxEveryPlay config missing")
	assert(typeof(onboardingConfig:GetAttribute("TutorialGold"))=="Color3","TutorialGold config missing")
	for _,name in ipairs({"HighlightPaddingPixels","DimTransparency","ShadeOverlapPixels","EdgeOverscanPixels","PageLossGraceSeconds","CalloutMarginPixels","ShortcutCalloutGapPixels","LandscapePhoneShortcutWidthRatio","LandscapePhoneShortcutGapPixels","MinimumTextSize","MaximumTextSize","TutorialTextSize","TargetStabilityFrames","PageAbandonSeconds","NextGradientTransparency","LandscapePhoneShortSidePixels","LandscapePhoneScale","TutorialMinimumScale","TutorialMaximumScale","TutorialDesktopMinimumScale","TutorialPhoneMinimumTextSize","TutorialDesktopMinimumTextSize","TutorialStackedWidthPixels","LandscapePhoneTextWidthRatio","TutorialMaximumTextWidth","ObjectiveEnterSeconds","ObjectiveExitHoldSeconds","ObjectiveExitSeconds","ObjectiveReflowSeconds","ObjectiveStaggerSeconds","ObjectiveCardGapPixels","ObjectiveOffscreenPaddingPixels","ObjectiveCardWidthPixels","ObjectiveCardHeightPixels","ObjectiveCardPaddingPixels","ObjectiveGlowSafePaddingPixels","ObjectiveNumberTextSize","ObjectiveTitleTextSize","ObjectiveHintTextSize","ObjectiveProgressTextSize","ObjectiveDesktopTextMultiplier","ObjectivePhoneCardHeightPixels","ObjectivePhoneCardGapPixels","ObjectivePhoneTopGapPixels","ObjectivePhoneTopRowClearancePixels","ObjectivePhoneFallbackTopPixels","ObjectivePhoneBoostGapPixels","ObjectivePhoneMinimumCardHeightPixels","StudioVehicleSandboxCash","GuideTrailMinimumDistance","GuideTrailSpacing","GuideTrailMaximumArrows","GuideTrailArrowWidth","GuideTrailArrowScale","GuideTrailShaftLength","GuideTrailHeadLength","GuideTrailHeadWidth","GuideTrailStartOffset","GuideTrailEndOffset","GuideTrailHeightOffset","GuideTrailPulseSpeed","GuideTrailPulseAmplitude","GuideTrailTransparency","GuideTrailBeamWidth","GuideTrailBeamTransparency","GuideTrailBeamCoreWidth","GuideTrailBeamCoreTransparency","GuideTrailBeamStartHeightOffset","GuideTrailChevronTextureSpeed","GuideTrailChevronTextureLength","GuideTrailChevronWidth","GuideTrailChevronTransparency","GuideTrailChevronBrightness","GuideTrailChevronZOffset"}) do assert(type(onboardingConfig:GetAttribute(name))=="number",name.." config missing") end
	for _,name in ipairs({"GuideTrailShaftEnabled","GuideTrailBeamEnabled","GuideTrailChevronBeamEnabled","GuideTrailPartArrowsEnabled"}) do assert(type(onboardingConfig:GetAttribute(name))=="boolean",name.." config missing") end
	assert(type(onboardingConfig:GetAttribute("GuideTrailChevronTexture"))=="string","GuideTrailChevronTexture config missing")
	assert(onboardingConfig:GetAttribute("ShadeOverlapPixels")==0,"ShadeOverlapPixels must be zero for exact dim tiles")
	for _,item in ipairs(projected) do assert(has(item.Object.Source,item.Marker),item.Marker.." missing") end
	assert(has(profileService.Source,PROFILE_IMPORT_PROTECTION_MARKER),"ProfileService onboarding import protection missing")
	assert(has(profileService.Source,"RunService:IsStudio()"),"Studio vehicle sandbox hard Studio guard missing")
	assert(has(profileService.Source,"Studio vehicle sandbox; save suppressed."),"Studio vehicle sandbox no-save guard missing")
	assert(has(garageWorkspace.Source,'SetAttribute("TutorialWorkspace",true)'),"Shared tutorial workspace semantic missing")
	assert(has(garageWorkspace.Source,'Name="TutorialCardScroller"'),"Shared tutorial card scroller semantic missing")
	if intro then
		assert(intro:GetAttribute("ShowObjectiveText")==false,"Legacy objective text is not disabled")
		assert(intro:GetAttribute("DynamicArrowTetherEnabled")==false,"Legacy guide trail owner is not disabled")
		local desk=intro:FindFirstChild("Desk") and intro.Desk:FindFirstChild("GarageDeskTrigger")
		assert(desk and desk:IsA("BasePart"),"Dealership guide endpoint missing")
	end
	assert(has(onboardingClient.Source,"NTR_ONBOARDING_FREE_ROAM_CONTROLS_ONLY_V1"),"Free-roam-only controls gate missing")
	assert(has(onboardingClient.Source,"NTR_ONBOARDING_DESKTOP_TWO_LINE_OBJECTIVE_V1"),"Desktop two-line objective layout missing")
	print("[NTR Player Onboarding V1.13] AUDIT PASS | protected state imports | free-roam controls gate | two-line desktop objectives | StudioReplayEveryPlay="..tostring(onboardingConfig:GetAttribute("StudioReplayEveryPlay")).." | StudioVehicleSandboxEveryPlay="..tostring(onboardingConfig:GetAttribute("StudioVehicleSandboxEveryPlay")))
end

if MODE=="AUDIT" then audit(); return end
assert(not RunService:IsRunning(),"Run INSTALL in Edit mode, not during Play")
assert(MODE=="INSTALL","MODE must be INSTALL or AUDIT")
local ok,problem=pcall(function()
	local previousRevision=kit:GetAttribute("PlayerOnboardingRevision")
	for _,item in ipairs(projected) do if item.Object.Source~=item.Source then table.insert(sourceSnapshots,{Object=item.Object,Source=item.Object.Source}); item.Object.Source=item.Source end end
	if onboardingService.Source~=ONBOARDING_SERVICE_SOURCE then table.insert(sourceSnapshots,{Object=onboardingService,Source=onboardingService.Source}); onboardingService.Source=ONBOARDING_SERVICE_SOURCE end
	if onboardingClient.Source~=ONBOARDING_CLIENT_SOURCE then table.insert(sourceSnapshots,{Object=onboardingClient,Source=onboardingClient.Source}); onboardingClient.Source=ONBOARDING_CLIENT_SOURCE end
	if guideTrailRenderer.Source~=GUIDE_TRAIL_RENDERER_SOURCE then table.insert(sourceSnapshots,{Object=guideTrailRenderer,Source=guideTrailRenderer.Source}); guideTrailRenderer.Source=GUIDE_TRAIL_RENDERER_SOURCE end
	snapshotAttribute(kit,"PlayerOnboardingRevision"); kit:SetAttribute("PlayerOnboardingRevision",REVISION)
	if onboardingConfig:GetAttribute("StudioReplayEveryPlay")==nil then snapshotAttribute(onboardingConfig,"StudioReplayEveryPlay"); onboardingConfig:SetAttribute("StudioReplayEveryPlay",true) end
	if onboardingConfig:GetAttribute("StudioVehicleSandboxEveryPlay")==nil then snapshotAttribute(onboardingConfig,"StudioVehicleSandboxEveryPlay"); onboardingConfig:SetAttribute("StudioVehicleSandboxEveryPlay",true) end
	local tuning={TutorialGold=Color3.fromRGB(255,196,66),HighlightPaddingPixels=8,DimTransparency=.35,EdgeOverscanPixels=8,PageLossGraceSeconds=.8,CalloutMarginPixels=12,ShortcutCalloutGapPixels=7,LandscapePhoneShortcutWidthRatio=.34,LandscapePhoneShortcutGapPixels=2,MinimumTextSize=14,MaximumTextSize=22,TutorialTextSize=14,TargetStabilityFrames=2,PageAbandonSeconds=3,NextGradientTransparency=.62,LandscapePhoneShortSidePixels=650,LandscapePhoneScale=.6,TutorialMinimumScale=.38,TutorialMaximumScale=1.08,TutorialDesktopMinimumScale=.68,TutorialPhoneMinimumTextSize=9,TutorialDesktopMinimumTextSize=11,TutorialStackedWidthPixels=560,LandscapePhoneTextWidthRatio=.42,TutorialMaximumTextWidth=520,ObjectiveEnterSeconds=.55,ObjectiveExitHoldSeconds=.15,ObjectiveExitSeconds=.4,ObjectiveReflowSeconds=.45,ObjectiveStaggerSeconds=.1,ObjectiveCardGapPixels=8,ObjectiveOffscreenPaddingPixels=24,ObjectiveCardWidthPixels=350,ObjectiveCardHeightPixels=98,ObjectiveCardPaddingPixels=16,ObjectiveGlowSafePaddingPixels=6,ObjectiveNumberTextSize=10,ObjectiveTitleTextSize=13,ObjectiveHintTextSize=10,ObjectiveProgressTextSize=9,ObjectiveDesktopTextMultiplier=1.5,ObjectivePhoneCardHeightPixels=48,ObjectivePhoneCardGapPixels=4,ObjectivePhoneTopGapPixels=2,ObjectivePhoneTopRowClearancePixels=14,ObjectivePhoneFallbackTopPixels=94,ObjectivePhoneBoostGapPixels=4,ObjectivePhoneMinimumCardHeightPixels=46,StudioVehicleSandboxCash=1000000,GuideTrailMinimumDistance=4,GuideTrailSpacing=9,GuideTrailMaximumArrows=18,GuideTrailArrowWidth=.42,GuideTrailArrowScale=1,GuideTrailShaftLength=2.6,GuideTrailHeadLength=1.05,GuideTrailHeadWidth=.36,GuideTrailStartOffset=4,GuideTrailEndOffset=3,GuideTrailHeightOffset=1.8,GuideTrailPulseSpeed=2,GuideTrailPulseAmplitude=.4,GuideTrailTransparency=.12,GuideTrailBeamWidth=3.5,GuideTrailBeamTransparency=.58,GuideTrailBeamCoreWidth=.8,GuideTrailBeamCoreTransparency=.25,GuideTrailBeamStartHeightOffset=-1,GuideTrailChevronTexture="",GuideTrailChevronTextureSpeed=1.5,GuideTrailChevronTextureLength=6,GuideTrailChevronWidth=2.2,GuideTrailChevronTransparency=.08,GuideTrailChevronBrightness=2,GuideTrailChevronZOffset=.05,GuideTrailShaftEnabled=true,GuideTrailBeamEnabled=true,GuideTrailChevronBeamEnabled=true,GuideTrailPartArrowsEnabled=false}
	for name,value in pairs(tuning) do if onboardingConfig:GetAttribute(name)==nil then snapshotAttribute(onboardingConfig,name); onboardingConfig:SetAttribute(name,value) end end
	if previousRevision=="NTR_PLAYER_ONBOARDING_V1_9_LIVE_TOP_ROW_OBJECTIVES" or previousRevision=="NTR_PLAYER_ONBOARDING_V1_8_RESPONSIVE_TOPBAR_CALLOUTS_OBJECTIVES" then
		for name,value in pairs({ObjectivePhoneCardHeightPixels=48,ObjectivePhoneMinimumCardHeightPixels=46}) do snapshotAttribute(onboardingConfig,name); onboardingConfig:SetAttribute(name,value) end
	end
	if previousRevision=="NTR_PLAYER_ONBOARDING_V1_5_SEMANTIC_TARGETS_OBJECTIVES_GUIDE_TRAIL" then
		for name,value in pairs({GuideTrailMinimumDistance=4,GuideTrailSpacing=9,GuideTrailHeightOffset=1.8,GuideTrailPulseSpeed=2,GuideTrailTransparency=.12}) do snapshotAttribute(onboardingConfig,name); onboardingConfig:SetAttribute(name,value) end
	end
	snapshotAttribute(onboardingConfig,"ShadeOverlapPixels"); onboardingConfig:SetAttribute("ShadeOverlapPixels",0)
	if intro then snapshotAttribute(intro,"ShowObjectiveText"); intro:SetAttribute("ShowObjectiveText",false); snapshotAttribute(intro,"DynamicArrowTetherEnabled"); intro:SetAttribute("DynamicArrowTetherEnabled",false) end
	audit()
end)
if not ok then
	for index=#sourceSnapshots,1,-1 do local s=sourceSnapshots[index]; pcall(function() s.Object.Source=s.Source end) end
	for index=#attributeSnapshots,1,-1 do local s=attributeSnapshots[index]; pcall(function() s.Object:SetAttribute(s.Name,s.Had and s.Value or nil) end) end
	for index=#created,1,-1 do local object=created[index]; pcall(function() if object.Parent then object:Destroy() end end) end
	error("[NTR Player Onboarding V1.13] INSTALL ROLLBACK: "..tostring(problem))
end
print("[NTR Player Onboarding V1.13] INSTALL PASS | restart Studio, test race exit and customisation re-entry, then run AUDIT")
