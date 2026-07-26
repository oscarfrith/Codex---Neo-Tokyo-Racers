-- Neo Tokyo Racers - Customisation Access, Onboarding, and Physical Colours V1.1
-- Run in Roblox Studio Edit mode from the Command Bar.
--
-- Modes:
--   INSTALL  - preflight, compile projected sources, mutate transactionally, then audit.
--   AUDIT    - read-only source/hierarchy/catalogue audit.
--   ROLLBACK - restore only sources still carrying this installer's exact marker.
--
-- This is the single canonical installer for the approved refinement scope.
-- It does not create in-game backup folders or scripts.

local MODE = "INSTALL" -- "INSTALL", "AUDIT", or "ROLLBACK"

local RunService = game:GetService("RunService")
assert(not RunService:IsRunning(), "Run this installer in Roblox Studio Edit mode.")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local TAG = "[NTR Customisation Refinement V1.1]"
local PRIOR_REVISION = "NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1"
local REVISION = "NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1"
local RUN_ID = HttpService:GenerateGUID(false)
local BLOCK_MESSAGE = "OWN A VEHICLE TO CUSTOMISE"

local function countPlain(source, needle)
	local count, cursor = 0, 1
	while true do
		local first, last = source:find(needle, cursor, true)
		if not first then return count end
		count += 1
		cursor = last + 1
	end
end

local function replaceOnce(source, needle, replacement, label)
	assert(type(source) == "string", label .. " source missing")
	assert(countPlain(source, needle) == 1, label .. " anchor count changed")
	local first = assert(source:find(needle, 1, true), label .. " anchor missing")
	return source:sub(1, first - 1) .. replacement .. source:sub(first + #needle)
end

local function compile(source, label)
	local fn, problem = loadstring(source, "=" .. label)
	assert(fn, label .. " compile failed: " .. tostring(problem))
end

local kit = assert(ReplicatedStorage:FindFirstChild("NeoTokyoRacers"), "ReplicatedStorage.NeoTokyoRacers missing")
local categories = assert(
		kit:FindFirstChild("Assets")
			and kit.Assets:FindFirstChild("Vehicles")
			and kit.Assets.Vehicles:FindFirstChild("Categories"),
	"Authoritative vehicle Categories folder missing"
)
local services = assert(
	ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Garage"),
	"ServerScriptService.NeoTokyoRacers.Services.Garage missing"
)
local clientRoot = assert(
	StarterPlayer:FindFirstChild("StarterPlayerScripts")
		and StarterPlayer.StarterPlayerScripts:FindFirstChild("NeoTokyoRacersClient")
		and StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient:FindFirstChild("Controllers"),
	"NeoTokyoRacersClient.Controllers missing"
)
local ui = assert(clientRoot:FindFirstChild("UI"), "Client UI controllers missing")
local intro = assert(clientRoot:FindFirstChild("Intro"), "Client Intro controllers missing")

local runtime = assert(services:FindFirstChild("GarageModuleInstanceCustomizationRuntime"), "Module-instance runtime missing")
local action = assert(services:FindFirstChild("GarageActionController_Shadow_Disabled"), "Garage action controller missing")
local session = assert(services:FindFirstChild("GarageSessionService_Active"), "Garage session service missing")
local shop = assert(ui:FindFirstChild("ModuleShopUIController"), "Module shop controller missing")
local onboarding = assert(ui:FindFirstChild("OnboardingClient_Active"), "Onboarding controller missing")
local entrance = assert(intro:FindFirstChild("GarageEntranceController_Active"), "Garage entrance controller missing")

assert(runtime:IsA("ModuleScript"), runtime:GetFullName() .. " must be a ModuleScript")
assert(action:IsA("Script"), action:GetFullName() .. " must be a Script")
assert(action.Disabled == false, action:GetFullName() .. " is the active owner and must remain enabled")
assert(session:IsA("Script") and session.Disabled == false, "Garage session owner must be an enabled Script")
assert(shop:IsA("ModuleScript"), shop:GetFullName() .. " must be a ModuleScript")
assert(onboarding:IsA("LocalScript") and onboarding.Disabled == false, "Onboarding owner must be enabled")
assert(entrance:IsA("LocalScript") and entrance.Disabled == false, "Garage entrance owner must be enabled")

local RUNTIME_OLD = [==[function Runtime.HydrateSlot(profile,slotId)
	local _,_,_,instance=Runtime.ResolveSlot(profile,slotId); if typeof(instance)~="table" then return false,"Installed module instance not found for "..tostring(slotId) end
	profile.ModuleColors=typeof(profile.ModuleColors)=="table" and profile.ModuleColors or {}; profile.NeonOwned=typeof(profile.NeonOwned)=="table" and profile.NeonOwned or {}; profile.ModuleUpgradeLevels=typeof(profile.ModuleUpgradeLevels)=="table" and profile.ModuleUpgradeLevels or {}
	instance.Colors=typeof(instance.Colors)=="table" and instance.Colors or {}; instance.UpgradeLevels=typeof(instance.UpgradeLevels)=="table" and instance.UpgradeLevels or {}
	profile.ModuleColors[slotId]=clone(instance.Colors); profile.NeonOwned[slotId]=instance.NeonOwned==true; profile.ModuleUpgradeLevels[tostring(instance.TemplateId or "")]=clone(instance.UpgradeLevels)
	return true
end

function Runtime.HydrateAll(profile)
	local vehicle=currentVehicle(profile); if not vehicle then return false,"Current vehicle not found" end
	profile.ModuleColors={}; profile.NeonOwned={}; profile.ModuleUpgradeLevels=typeof(profile.ModuleUpgradeLevels)=="table" and profile.ModuleUpgradeLevels or {}
	for slotId in pairs(vehicle.InstalledModules or {}) do local ok,message=Runtime.HydrateSlot(profile,slotId); if not ok then return false,message end end
	return true
end]==]

local RUNTIME_NEW = [==[-- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
local function completePhysicalColours(profile,vehicle,instance)
	instance.Colors=typeof(instance.Colors)=="table" and instance.Colors or {}
	local cockpitColors=(typeof(vehicle)=="table" and typeof(vehicle.CockpitColors)=="table" and vehicle.CockpitColors)
		or (typeof(profile.CockpitColors)=="table" and profile.CockpitColors)
		or {}
	local repaired=0
	for _,channel in ipairs({"Primary","Secondary","Detail"}) do
		if typeof(instance.Colors[channel])~="Color3" and typeof(cockpitColors[channel])=="Color3" then
			instance.Colors[channel]=cockpitColors[channel]
			repaired+=1
		end
	end
	if typeof(instance.Colors.Neon)~="Color3" then
		instance.Colors.Neon=typeof(cockpitColors.Neon)=="Color3" and cockpitColors.Neon or Color3.new(1,1,1)
		repaired+=1
	end
	if typeof(instance.Colors.ThrustColor)~="Color3" then
		local thrust=(typeof(vehicle)=="table" and typeof(vehicle.ThrustColor)=="Color3" and vehicle.ThrustColor)
			or (typeof(profile.ThrustColor)=="Color3" and profile.ThrustColor)
			or (typeof(cockpitColors.ThrustColor)=="Color3" and cockpitColors.ThrustColor)
		if typeof(thrust)=="Color3" then instance.Colors.ThrustColor=thrust; repaired+=1 end
	end
	return repaired
end

function Runtime.HydrateSlot(profile,slotId)
	local vehicle,_,_,instance=Runtime.ResolveSlot(profile,slotId); if typeof(instance)~="table" then return false,"Installed module instance not found for "..tostring(slotId) end
	profile.ModuleColors=typeof(profile.ModuleColors)=="table" and profile.ModuleColors or {}; profile.NeonOwned=typeof(profile.NeonOwned)=="table" and profile.NeonOwned or {}; profile.ModuleUpgradeLevels=typeof(profile.ModuleUpgradeLevels)=="table" and profile.ModuleUpgradeLevels or {}
	local repaired=completePhysicalColours(profile,vehicle,instance); instance.UpgradeLevels=typeof(instance.UpgradeLevels)=="table" and instance.UpgradeLevels or {}
	profile.ModuleColors[slotId]=clone(instance.Colors); profile.NeonOwned[slotId]=instance.NeonOwned==true; profile.ModuleUpgradeLevels[tostring(instance.TemplateId or "")]=clone(instance.UpgradeLevels)
	return true,instance,repaired
end

function Runtime.HydrateAll(profile)
	local vehicle=currentVehicle(profile); if not vehicle then return false,"Current vehicle not found" end
	profile.ModuleColors={}; profile.NeonOwned={}; profile.ModuleUpgradeLevels=typeof(profile.ModuleUpgradeLevels)=="table" and profile.ModuleUpgradeLevels or {}
	local repaired=0
	for slotId in pairs(vehicle.InstalledModules or {}) do local ok,message,count=Runtime.HydrateSlot(profile,slotId); if not ok then return false,message end; repaired+=tonumber(count) or 0 end
	return true,"Module instance state hydrated.",repaired
end]==]

local ACTION_SYNC_OLD = [==[		local hydrated,hydrateMessage=V97_ModuleInstances.HydrateAll(profile); if not hydrated then return false,hydrateMessage end
		return true, "Vehicle selected."
	end

	local function V89_selectVehicleInstance(profile, args)]==]

local ACTION_SYNC_NEW = [==[		local hydrated,hydrateMessage,repairedColours=V97_ModuleInstances.HydrateAll(profile); if not hydrated then return false,hydrateMessage end
		return true, "Vehicle selected.", tonumber(repairedColours) or 0
	end

	local function V89_selectVehicleInstance(profile, args)]==]

local ACTION_SELECT_OLD = [==[		profile.CurrentVehicleId = selectedVehicleId
		local ok, message = V89_syncLegacyFromCurrentVehicle(profile)
		if ok then
			V85_attachDefaultModuleInstancesToCurrentVehicle(profile)
			V89_syncLegacyFromCurrentVehicle(profile)
		end
		return ok, message
	end

	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_INSTANCE_CARDS]==]

local ACTION_SELECT_NEW = [==[		profile.CurrentVehicleId = selectedVehicleId
		local ok, message, repairedColours = V89_syncLegacyFromCurrentVehicle(profile)
		if ok then
			V85_attachDefaultModuleInstancesToCurrentVehicle(profile)
			local resynced,resyncMessage,resyncRepairs=V89_syncLegacyFromCurrentVehicle(profile)
			if not resynced then return false,resyncMessage,tonumber(repairedColours) or 0 end
			repairedColours=(tonumber(repairedColours) or 0)+(tonumber(resyncRepairs) or 0)
		end
		return ok, message, repairedColours
	end

	-- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
	local function V102_ensureCustomisationAccess(player,profile)
		V84_ensureInstanceInventory(profile)
		local owned,ownedLookup={},{}
		for vehicleId,vehicle in pairs(profile.Vehicles or {}) do
			local cockpitInstance=typeof(vehicle)=="table" and vehicle.CockpitInstanceId and profile.OwnedCockpitInstances and profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
			if typeof(cockpitInstance)=="table" and tostring(cockpitInstance.TemplateId or "")~="" then
				local id=tostring(vehicleId); table.insert(owned,id); ownedLookup[id]=true
			end
		end
		table.sort(owned)
		if #owned==0 then return {Success=false,Message="OWN A VEHICLE TO CUSTOMISE",OwnedVehicleCount=0} end
		local current=tostring(profile.CurrentVehicleId or "")
		local stale=current=="" or ownedLookup[current]~=true
		local ok,message,repairedColours
		if stale then
			ok,message,repairedColours=V89_selectVehicleInstance(profile,{VehicleId=owned[1]})
		else
			ok,message,repairedColours=V89_syncLegacyFromCurrentVehicle(profile)
		end
		if not ok then return {Success=false,Message=message or "Owned vehicle selection could not be repaired.",OwnedVehicleCount=#owned} end
		local valid,validationMessage=V97_ModuleInstances.Validate(profile)
		if not valid then return {Success=false,Message="Owned vehicle state is invalid: "..tostring(validationMessage),OwnedVehicleCount=#owned} end
		if stale or (tonumber(repairedColours) or 0)>0 then
			V80_mirrorLegacyProfileToPersistence(player,profile,"EnsureCustomisationAccess",true)
		end
		return {
			Success=true,
			Message=stale and "Owned vehicle selection repaired." or "Customisation access ready.",
			OwnedVehicleCount=#owned,
			VehicleId=profile.CurrentVehicleId,
			SelectionRepaired=stale,
			PhysicalColourChannelsRepaired=tonumber(repairedColours) or 0,
		}
	end

	local V102_accessBinding=script.Parent:FindFirstChild("GarageCustomisationAccessBinding") or Instance.new("BindableFunction")
	V102_accessBinding.Name="GarageCustomisationAccessBinding"
	V102_accessBinding.Parent=script.Parent
	V102_accessBinding.OnInvoke=function(player)
		local ok,result=pcall(function()
			local profile=V56_getProfile(player); profile._Player=player
			return V102_ensureCustomisationAccess(player,profile)
		end)
		if ok and typeof(result)=="table" then return result end
		warn("[NTR Customisation Access] binding failed: "..tostring(result))
		return {Success=false,Message="Customisation access is unavailable."}
	end

	-- NTR_DEALERSHIP_CUSTOMISATION_SPLIT_PHASE3_INSTANCE_CARDS]==]

local ACTION_REMOTE_OLD = [==[			if action == "GetInitial" then
				-- NTR_PROFILE_SERVICE_READ_ONLY_IMPORT_GUARD_V1]==]

local ACTION_REMOTE_NEW = [==[			if action == "EnsureCustomisationAccess" then
				return V102_ensureCustomisationAccess(player,profile)
			elseif action == "GetInitial" then
				-- NTR_PROFILE_SERVICE_READ_ONLY_IMPORT_GUARD_V1]==]

local SESSION_INSERT_OLD = [==[local sessions = {}
local function worldParts()]==]

local SESSION_INSERT_NEW = [==[local sessions = {}
local function customisationAccess(player)
	local binding = script.Parent:FindFirstChild("GarageCustomisationAccessBinding") or script.Parent:WaitForChild("GarageCustomisationAccessBinding", 10)
	if not binding or not binding:IsA("BindableFunction") then return { Success=false, Message="Customisation access is unavailable." } end
	local ok, result = pcall(function() return binding:Invoke(player) end)
	if not ok or typeof(result)~="table" then return { Success=false, Message="Customisation access is unavailable." } end
	return result
end
local function worldParts()]==]

local SESSION_BEGIN_OLD = [==[local function begin(player, mode)
	if sessions[player] then return { Success=false, Message="A garage session is already active." } end
	if player:GetAttribute("NTR_RaceQueueActive") == true or player:GetAttribute("NTR_RaceSessionActive") == true then return { Success=false, Message="Leave the race session first." } end
	local model, humanoid, root = character(player)]==]

local SESSION_BEGIN_NEW = [==[local function begin(player, mode)
	if mode~="Dealership" and mode~="Customisation" and mode~="DriveIn" then return { Success=false, Message="Unknown garage session mode." } end
	if sessions[player] then return { Success=false, Message="A garage session is already active." } end
	if player:GetAttribute("NTR_RaceQueueActive") == true or player:GetAttribute("NTR_RaceSessionActive") == true then return { Success=false, Message="Leave the race session first." } end
	if mode=="Customisation" or mode=="DriveIn" then
		local access=customisationAccess(player)
		if access.Success~=true then return { Success=false, Message=tostring(access.Message or "Customisation access is unavailable.") } end
	end
	local model, humanoid, root = character(player)]==]

local SHOP_OPEN_OLD = [==[	local generation=entryLoading(mode,payload)
	local result=action:Refresh(); if not result.Success then local reason=tostring(result.Message or "Garage data unavailable"); warn("[NTR Canonical Garage] "..reason); action:Session("End",{ReturnToEntry=true}); player:SetAttribute("NTR_GarageEntryMode",nil); loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); return end
	active=true;]==]

local SHOP_OPEN_V1 = [==[	local generation=entryLoading(mode,payload)
	if mode~="Dealership" then
		local access=action:Call("EnsureCustomisationAccess",{})
		if not access.Success then
			local reason=tostring(access.Message or "Customisation access is unavailable.")
			local notification=uiFolder:FindFirstChild("ShowTopNotification")
			if notification and notification:IsA("BindableEvent") then notification:Fire(reason) end
			action:Session("End",{ReturnToEntry=true}); player:SetAttribute("NTR_GarageEntryMode",nil)
			loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason})
			return
		end
	end
	local result=action:Refresh(); if not result.Success then local reason=tostring(result.Message or "Garage data unavailable"); warn("[NTR Canonical Garage] "..reason); action:Session("End",{ReturnToEntry=true}); player:SetAttribute("NTR_GarageEntryMode",nil); loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); return end
	active=true;]==]

local SHOP_OPEN_NEW = [==[	local generation
	if mode~="Dealership" then
		local access=action:Call("EnsureCustomisationAccess",{})
		if not access.Success then
			local reason=tostring(access.Message or "Customisation access is unavailable.")
			local notification=uiFolder:FindFirstChild("ShowTopNotification")
			if notification and notification:IsA("BindableEvent") then notification:Fire(reason) end
			if reason=="OWN A VEHICLE TO CUSTOMISE" then AudioBridge.Emit("UI.PurchaseRejected",{Reason="VehicleRequired",Route="CustomisationShortcut"}) end
			action:Session("End",{ReturnToEntry=true}); player:SetAttribute("NTR_GarageEntryMode",nil)
			return
		end
	end
	generation=entryLoading(mode,payload)
	local result=action:Refresh(); if not result.Success then local reason=tostring(result.Message or "Garage data unavailable"); warn("[NTR Canonical Garage] "..reason); action:Session("End",{ReturnToEntry=true}); player:SetAttribute("NTR_GarageEntryMode",nil); loadingAction("Fail",{Generation=generation,Status="RETURNING",Reason=reason}); return end
	active=true;]==]

local ENTRANCE_AUDIO_OLD = [==[local loadingInvoke = script.Parent.Parent:WaitForChild("UI"):WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE2_GARAGE_ENTRY_V1]==]

local ENTRANCE_AUDIO_NEW = [==[local loadingInvoke = script.Parent.Parent:WaitForChild("UI"):WaitForChild("LoadingTransitionInvoke") -- NTR_LOADING_SYSTEM_PHASE2_GARAGE_ENTRY_V1
local AudioBridge = require(kit.Shared.Modules.Client.Audio:WaitForChild("PresentationAudioBridge"))]==]

local ENTRANCE_FLOW_V1 = [==[		busy = true
		local destination, status = loadingDetails(definition.Mode)
		local generation = loadingAction("Begin", { Destination = destination, Status = status })
		local ok, result = pcall(function()
			return request:InvokeServer("Begin", { Mode = definition.Mode })
		end)
		if not ok or not result or result.Success ~= true then
			local message = (result and result.Message) or "Could not enter garage."
			loadingAction("Fail", { Generation = generation, Status = "RETURNING", Reason = message })
			busy = false
			flash(message)
			refreshPromptAvailability()
			return
		end

		player:SetAttribute("NTR_GarageEntryMode", definition.Mode)]==]

local ENTRANCE_FLOW_NEW = [==[		busy = true
		local destination, status = loadingDetails(definition.Mode)
		local ok, result = pcall(function()
			return request:InvokeServer("Begin", { Mode = definition.Mode })
		end)
		if not ok or not result or result.Success ~= true then
			local message = (result and result.Message) or "Could not enter garage."
			if message=="OWN A VEHICLE TO CUSTOMISE" then AudioBridge.Emit("UI.PurchaseRejected",{Reason="VehicleRequired",Route=definition.Mode}) end
			busy = false
			flash(message)
			refreshPromptAvailability()
			return
		end

		local generation = loadingAction("Begin", { Destination = destination, Status = status })
		player:SetAttribute("NTR_GarageEntryMode", definition.Mode)]==]

local ENTRANCE_FLASH_OLD = [==[local function flash(text)
	statusSerial += 1]==]

local ENTRANCE_FLASH_NEW = [==[local function flash(text)
	if text=="OWN A VEHICLE TO CUSTOMISE" then
		local notification=script.Parent.Parent.UI:FindFirstChild("ShowTopNotification")
		if notification and notification:IsA("BindableEvent") then notification:Fire(text); return end
	end
	statusSerial += 1]==]

local ONBOARDING_OLD = [==[	return playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true
		or player:GetAttribute("NTR_RaceSessionActive")==true]==]

local ONBOARDING_NEW = [==[	return playerGui:GetAttribute("NTR_OwnedGarageManagementOpen")==true
		or (player:GetAttribute("NTR_GarageSessionActive")==true and player:GetAttribute("NTR_GarageSessionMode")~="Dealership") -- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
		or player:GetAttribute("NTR_RaceSessionActive")==true]==]

local NOTIFICATION_SOURCE = [==[-- NTR_CUSTOMISATION_ACCESS_ONBOARDING_PHYSICAL_COLOURS_V1_1
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local event=script.Parent:FindFirstChild("ShowTopNotification") or Instance.new("BindableEvent")
event.Name="ShowTopNotification"; event.Parent=script.Parent
local old=playerGui:FindFirstChild("NTR_SharedTopNotification")
if old then old:Destroy() end
local gui=Instance.new("ScreenGui"); gui.Name="NTR_SharedTopNotification"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=1100; gui.Parent=playerGui
local label=Instance.new("TextLabel"); label.Name="Message"; label.AnchorPoint=Vector2.new(.5,0); label.Position=UDim2.new(.5,0,0,18); label.Size=UDim2.new(1,-32,0,48); label.BackgroundColor3=Color3.fromRGB(9,12,16); label.BackgroundTransparency=.06; label.TextColor3=Color3.fromRGB(255,255,255); label.FontFace=Font.new("rbxasset://fonts/families/Michroma.json"); label.TextSize=14; label.TextWrapped=true; label.Visible=false; label.Parent=gui
local size=Instance.new("UISizeConstraint"); size.MaxSize=Vector2.new(620,48); size.MinSize=Vector2.new(260,48); size.Parent=label
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,5); corner.Parent=label
local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(236,92,168); stroke.Thickness=1; stroke.Parent=label
local serial=0
event.Event:Connect(function(message)
	serial+=1; local mine=serial
	label.Text=string.upper(tostring(message or "")); label.Visible=label.Text~=""
	task.delay(2.5,function() if mine==serial and label.Parent then label.Visible=false end end)
end)
]==]

local function projectedSources()
	local projected = {}
	local runtimeSource = runtime.Source
	if runtimeSource:find(REVISION,1,true) then
	elseif runtimeSource:find(PRIOR_REVISION,1,true) then
		runtimeSource=runtimeSource:gsub(PRIOR_REVISION,REVISION)
	else
		runtimeSource = replaceOnce(runtimeSource, RUNTIME_OLD, RUNTIME_NEW, "Module-instance runtime")
	end
	projected[runtime] = runtimeSource

	local actionSource = action.Source
	if actionSource:find(REVISION,1,true) then
	elseif actionSource:find(PRIOR_REVISION,1,true) then
		actionSource=replaceOnce(actionSource,'\t\t\tProfile=V56_profileForClient(profile),\n',"","Garage action V1 forward-reference repair")
		actionSource=actionSource:gsub(PRIOR_REVISION,REVISION)
	else
		actionSource = replaceOnce(actionSource, ACTION_SYNC_OLD, ACTION_SYNC_NEW, "Garage action hydration result")
		actionSource = replaceOnce(actionSource, ACTION_SELECT_OLD, ACTION_SELECT_NEW, "Garage action access authority")
		actionSource = replaceOnce(actionSource, ACTION_REMOTE_OLD, ACTION_REMOTE_NEW, "Garage action remote route")
	end
	projected[action] = actionSource

	local sessionSource = session.Source
	if sessionSource:find(REVISION,1,true) then
	elseif sessionSource:find(PRIOR_REVISION,1,true) then
		sessionSource=sessionSource:gsub(PRIOR_REVISION,REVISION)
	else
		sessionSource = "-- " .. REVISION .. "\n" .. sessionSource
		sessionSource = replaceOnce(sessionSource, SESSION_INSERT_OLD, SESSION_INSERT_NEW, "Garage session binding")
		sessionSource = replaceOnce(sessionSource, SESSION_BEGIN_OLD, SESSION_BEGIN_NEW, "Garage session access gate")
	end
	projected[session] = sessionSource

	local shopSource = shop.Source
	if shopSource:find(REVISION,1,true) then
	elseif shopSource:find(PRIOR_REVISION,1,true) then
		shopSource=replaceOnce(shopSource,SHOP_OPEN_V1,SHOP_OPEN_NEW,"Module shop V1 loading-order repair")
		shopSource=shopSource:gsub(PRIOR_REVISION,REVISION)
	else
		shopSource = "-- " .. REVISION .. "\n" .. replaceOnce(shopSource, SHOP_OPEN_OLD, SHOP_OPEN_NEW, "Module shop entry funnel")
	end
	projected[shop] = shopSource

	local entranceSource = entrance.Source
	if entranceSource:find(REVISION,1,true) then
	elseif entranceSource:find(PRIOR_REVISION,1,true) then
		entranceSource=replaceOnce(entranceSource,ENTRANCE_AUDIO_OLD,ENTRANCE_AUDIO_NEW,"Garage entrance audio bridge")
		entranceSource=replaceOnce(entranceSource,ENTRANCE_FLOW_V1,ENTRANCE_FLOW_NEW,"Garage entrance V1 loading-order repair")
		entranceSource=entranceSource:gsub(PRIOR_REVISION,REVISION)
	else
		entranceSource = "-- " .. REVISION .. "\n" .. entranceSource
		entranceSource = replaceOnce(entranceSource, ENTRANCE_FLASH_OLD, ENTRANCE_FLASH_NEW, "Garage entrance notification")
		entranceSource = replaceOnce(entranceSource,ENTRANCE_AUDIO_OLD,ENTRANCE_AUDIO_NEW,"Garage entrance audio bridge")
		entranceSource = replaceOnce(entranceSource,ENTRANCE_FLOW_V1,ENTRANCE_FLOW_NEW,"Garage entrance loading-order gate")
	end
	projected[entrance] = entranceSource

	local onboardingSource = onboarding.Source
	if onboardingSource:find(REVISION,1,true) then
	elseif onboardingSource:find(PRIOR_REVISION,1,true) then
		onboardingSource=onboardingSource:gsub(PRIOR_REVISION,REVISION)
	else
		onboardingSource = replaceOnce(onboardingSource, ONBOARDING_OLD, ONBOARDING_NEW, "Onboarding visibility")
	end
	projected[onboarding] = onboardingSource
	return projected
end

local REQUIRED_SLOTS = {"Boost","Engine1","Engine2","FrontBumper","RearBumper","RearSpoiler","SidePods","Stabilisers"}
local function auditCatalogue()
	local cockpits, modules = {}, {}
	for _, object in ipairs(categories:GetDescendants()) do
		if object:IsA("Model") then
			if tostring(object:GetAttribute("CockpitId") or "")~="" or object.Name:match("^COCKPIT_") then table.insert(cockpits,object) end
			if tostring(object:GetAttribute("ModuleId") or "")~="" or object.Name:match("^MODULE_") then table.insert(modules,object) end
		end
	end
	assert(#cockpits==6, "Current cockpit catalogue changed: expected 6, found "..#cockpits)
	assert(#modules==116, "Current module catalogue changed: expected 116, found "..#modules)
	local slotCoverage={}
	for _,slotId in ipairs(REQUIRED_SLOTS) do slotCoverage[slotId]=0 end
	for _,cockpit in ipairs(cockpits) do
		for _,slotId in ipairs(REQUIRED_SLOTS) do
			assert(cockpit:FindFirstChild("SLOT_"..slotId,true),cockpit:GetFullName().." missing SLOT_"..slotId)
		end
	end
	for _,module in ipairs(modules) do
		local text=string.lower(module.Name.." "..tostring(module:GetAttribute("ModuleType") or "").." "..tostring(module:GetAttribute("ModuleFolder") or ""))
		if text:find("boost",1,true) then slotCoverage.Boost+=1 end
		if text:find("engine",1,true) then slotCoverage.Engine1+=1; slotCoverage.Engine2+=1 end
		if text:find("frontbumper",1,true) or text:find("front_bumper",1,true) then slotCoverage.FrontBumper+=1 end
		if text:find("rearbumper",1,true) or text:find("rear_bumper",1,true) then slotCoverage.RearBumper+=1 end
		if text:find("rearspoiler",1,true) or text:find("spoiler",1,true) then slotCoverage.RearSpoiler+=1 end
		if text:find("sidepod",1,true) then slotCoverage.SidePods+=1 end
		if text:find("stabil",1,true) then slotCoverage.Stabilisers+=1 end
	end
	for slotId,count in pairs(slotCoverage) do assert(count>0,"No module template coverage found for "..slotId) end
	assert(slotCoverage.Boost==22,"Boost catalogue changed: expected 22")
	assert(slotCoverage.Engine1==44 and slotCoverage.Engine2==44,"Engine catalogue changed: expected 44")
	assert(slotCoverage.FrontBumper==7 and slotCoverage.RearBumper==7 and slotCoverage.RearSpoiler==7 and slotCoverage.SidePods==7,"Body-module catalogue changed: expected 7 per location")
	assert(slotCoverage.Stabilisers==22,"Stabiliser catalogue changed: expected 22")
	return #cockpits,#modules,slotCoverage
end

local function audit()
	local cockpits,modules,coverage=auditCatalogue()
	local notification=ui:FindFirstChild("SharedTopNotificationController_Active")
	local event=ui:FindFirstChild("ShowTopNotification")
	assert(runtime.Source:find(REVISION,1,true),"Module-instance colour completion missing")
	assert(action.Source:find(REVISION,1,true),"Garage access authority missing")
	assert(session.Source:find(REVISION,1,true),"Garage session gate missing")
	assert(shop.Source:find(REVISION,1,true),"Module shop funnel gate missing")
	assert(entrance.Source:find(REVISION,1,true),"Entrance shared-notification route missing")
	assert(onboarding.Source:find(REVISION,1,true),"Onboarding session visibility guard missing")
	assert(notification and notification:IsA("LocalScript") and notification.Disabled==false,"Shared notification owner missing or disabled")
	assert(event and event:IsA("BindableEvent"),"Shared top notification event missing")
	assert(countPlain(notification.Source,REVISION)==1,"Shared notification owner revision mismatch")
	assert(intro:FindFirstChild("CockpitCustomisationZoneClient_Active")==nil or intro.CockpitCustomisationZoneClient_Active.Disabled==true,"Legacy cockpit customisation owner unexpectedly enabled")
	assert(intro:FindFirstChild("DriveInCustomisationZoneClient_Active")==nil or intro.DriveInCustomisationZoneClient_Active.Disabled==true,"Legacy drive-in customisation owner unexpectedly enabled")
	assert(countPlain(action.Source,"GarageCustomisationAccessBinding")==2,"Garage access binding owner count changed")
	assert(countPlain(action.Source,'Profile=V56_profileForClient(profile),')==0,"Access response still calls the later client-profile serializer")
	assert(countPlain(shop.Source,'action:Call("EnsureCustomisationAccess",{})')==1,"Module shop access funnel count changed")
	assert(countPlain(shop.Source,'AudioBridge.Emit("UI.PurchaseRejected"')==1,"Module shop purchase-rejected cue count changed")
	local shopAccess=assert(shop.Source:find('action:Call("EnsureCustomisationAccess",{})',1,true),"Module shop access gate missing")
	local shopLoading=assert(shop.Source:find("generation=entryLoading(mode,payload)",1,true),"Module shop loading start missing")
	assert(shopAccess<shopLoading,"Module shop starts loading before access is accepted")
	assert(countPlain(entrance.Source,'AudioBridge.Emit("UI.PurchaseRejected"')==1,"Garage entrance purchase-rejected cue count changed")
	local entranceRequest=assert(entrance.Source:find('request:InvokeServer("Begin", { Mode = definition.Mode })',1,true),"Garage entrance begin request missing")
	local entranceLoading=assert(entrance.Source:find('local generation = loadingAction("Begin"',1,true),"Garage entrance loading start missing")
	assert(entranceRequest<entranceLoading,"Garage entrance starts loading before server access is accepted")
	assert(countPlain(onboarding.Source,'player:GetAttribute("NTR_GarageSessionActive")==true')==1,"Onboarding garage-session guard count changed")
	for object,source in pairs(projectedSources()) do assert(object.Source==source,object:GetFullName().." differs from projected idempotent source"); compile(object.Source,object.Name.."_Audit") end
	compile(notification.Source,"SharedTopNotificationController_Audit")
	print(TAG.." AUDIT PASS revision="..REVISION.." cockpits="..cockpits.." modules="..modules.." slots="..table.concat(REQUIRED_SLOTS,","))
	for _,slotId in ipairs(REQUIRED_SLOTS) do print(TAG.." CATALOG "..slotId.." moduleCandidates="..coverage[slotId]) end
	print(TAG.." OWNER PASS notification=1 sessionGate=1 uiFunnel=1 onboardingVisibility=1 legacyEntryOwners=disabled bootstrap=untouched")
end

MODE=string.upper(tostring(MODE))
assert(MODE=="INSTALL" or MODE=="AUDIT" or MODE=="ROLLBACK","MODE must be INSTALL, AUDIT, or ROLLBACK")

if MODE=="AUDIT" then audit(); return end

local originals={
	[runtime]=runtime.Source,[action]=action.Source,[session]=session.Source,
	[shop]=shop.Source,[entrance]=entrance.Source,[onboarding]=onboarding.Source,
}
local originalAttributes={}
for object in pairs(originals) do
	originalAttributes[object]={
		Revision=object:GetAttribute("CustomisationRefinementRevision"),
		RunId=object:GetAttribute("CustomisationRefinementRunId"),
	}
end

if MODE=="ROLLBACK" then
	local notification=ui:FindFirstChild("SharedTopNotificationController_Active")
	local event=ui:FindFirstChild("ShowTopNotification")
	for object,source in pairs(originals) do
		assert(source:find(REVISION,1,true),"ROLLBACK refused: "..object:GetFullName().." does not carry the exact revision")
	end
	local function reverse(source,new,old,label)
		source=source:gsub("^%-%- "..REVISION.."\n","",1)
		return replaceOnce(source,new,old,label)
	end
	local restored={}
	restored[runtime]=replaceOnce(originals[runtime],RUNTIME_NEW,RUNTIME_OLD,"Runtime rollback")
	local actionSource=replaceOnce(originals[action],ACTION_REMOTE_NEW,ACTION_REMOTE_OLD,"Action remote rollback")
	actionSource=replaceOnce(actionSource,ACTION_SELECT_NEW,ACTION_SELECT_OLD,"Action authority rollback")
	actionSource=replaceOnce(actionSource,ACTION_SYNC_NEW,ACTION_SYNC_OLD,"Action hydration rollback")
	restored[action]=actionSource
	local sessionSource=reverse(originals[session],SESSION_BEGIN_NEW,SESSION_BEGIN_OLD,"Session gate rollback")
	sessionSource=replaceOnce(sessionSource,SESSION_INSERT_NEW,SESSION_INSERT_OLD,"Session binding rollback")
	restored[session]=sessionSource
	restored[shop]=reverse(originals[shop],SHOP_OPEN_NEW,SHOP_OPEN_OLD,"Shop funnel rollback")
	local entranceSource=reverse(originals[entrance],ENTRANCE_FLASH_NEW,ENTRANCE_FLASH_OLD,"Entrance notification rollback")
	entranceSource=replaceOnce(entranceSource,ENTRANCE_FLOW_NEW,ENTRANCE_FLOW_V1,"Entrance loading-order rollback")
	entranceSource=replaceOnce(entranceSource,ENTRANCE_AUDIO_NEW,ENTRANCE_AUDIO_OLD,"Entrance audio bridge rollback")
	restored[entrance]=entranceSource
	restored[onboarding]=replaceOnce(originals[onboarding],ONBOARDING_NEW,ONBOARDING_OLD,"Onboarding rollback")
	for object,source in pairs(restored) do compile(source,object.Name.."_Rollback"); object.Source=source; object:SetAttribute("CustomisationRefinementRevision",nil); object:SetAttribute("CustomisationRefinementRunId",nil) end
	if notification and notification:GetAttribute("CustomisationRefinementRevision")==REVISION then notification:Destroy() end
	if event and event:GetAttribute("CustomisationRefinementRevision")==REVISION then event:Destroy() end
	print(TAG.." ROLLBACK PASS. Restart Play mode and verify the prior confirmed baseline.")
	return
end

local projected=projectedSources()
for object,source in pairs(projected) do compile(source,object.Name.."_Projected") end
compile(NOTIFICATION_SOURCE,"SharedTopNotificationController_Projected")
local cockpitCount,moduleCount=auditCatalogue()
assert(BLOCK_MESSAGE=="OWN A VEHICLE TO CUSTOMISE","Block copy changed")

local oldNotification=ui:FindFirstChild("SharedTopNotificationController_Active")
local oldEvent=ui:FindFirstChild("ShowTopNotification")
assert(not oldNotification or (oldNotification:IsA("LocalScript") and (oldNotification.Source:find(REVISION,1,true) or oldNotification.Source:find(PRIOR_REVISION,1,true))),"A different shared top-notification owner already exists; inspect ownership before installing")
assert(not oldEvent or (oldEvent:IsA("BindableEvent") and (oldEvent:GetAttribute("CustomisationRefinementRevision")==REVISION or oldEvent:GetAttribute("CustomisationRefinementRevision")==PRIOR_REVISION)),"A different ShowTopNotification event already exists; inspect ownership before installing")
local oldNotificationSource=oldNotification and oldNotification.Source
local oldNotificationDisabled=oldNotification and oldNotification.Disabled
local oldNotificationRevision=oldNotification and oldNotification:GetAttribute("CustomisationRefinementRevision")
local oldNotificationRunId=oldNotification and oldNotification:GetAttribute("CustomisationRefinementRunId")
local oldEventRevision=oldEvent and oldEvent:GetAttribute("CustomisationRefinementRevision")
local createdNotification=false
local createdEvent=false

local ok,problem=pcall(function()
	for object,source in pairs(projected) do
		object.Source=source
		object:SetAttribute("CustomisationRefinementRevision",REVISION)
		object:SetAttribute("CustomisationRefinementRunId",RUN_ID)
	end
	local event=oldEvent
	if not event then event=Instance.new("BindableEvent"); event.Name="ShowTopNotification"; event.Parent=ui; createdEvent=true end
	assert(event:IsA("BindableEvent"),event:GetFullName().." must be a BindableEvent")
	event:SetAttribute("CustomisationRefinementRevision",REVISION)
	local notification=oldNotification
	if not notification then notification=Instance.new("LocalScript"); notification.Name="SharedTopNotificationController_Active"; notification.Parent=ui; createdNotification=true end
	assert(notification:IsA("LocalScript"),notification:GetFullName().." must be a LocalScript")
	notification.Source=NOTIFICATION_SOURCE; notification.Disabled=false
	notification:SetAttribute("CustomisationRefinementRevision",REVISION)
	notification:SetAttribute("CustomisationRefinementRunId",RUN_ID)
	for object,source in pairs(projected) do assert(object.Source==source,object:GetFullName().." source did not persist"); compile(object.Source,object.Name.."_Committed") end
	compile(notification.Source,"SharedTopNotificationController_Committed")
	audit()
end)

if not ok then
	pcall(function()
		for object,source in pairs(originals) do
			object.Source=source
			object:SetAttribute("CustomisationRefinementRevision",originalAttributes[object].Revision)
			object:SetAttribute("CustomisationRefinementRunId",originalAttributes[object].RunId)
		end
		if createdNotification then local object=ui:FindFirstChild("SharedTopNotificationController_Active"); if object then object:Destroy() end
		elseif oldNotification then oldNotification.Source=oldNotificationSource; oldNotification.Disabled=oldNotificationDisabled; oldNotification:SetAttribute("CustomisationRefinementRevision",oldNotificationRevision); oldNotification:SetAttribute("CustomisationRefinementRunId",oldNotificationRunId) end
		if createdEvent then local object=ui:FindFirstChild("ShowTopNotification"); if object then object:Destroy() end
		elseif oldEvent then oldEvent:SetAttribute("CustomisationRefinementRevision",oldEventRevision) end
	end)
	error(TAG.." INSTALL ROLLED BACK: "..tostring(problem))
end

print(TAG.." INSTALL PASS runId="..RUN_ID.." cockpits="..cockpitCount.." modules="..moduleCount)
print(TAG.." EXPECTED: zero-vehicle access returns '"..BLOCK_MESSAGE.."' with UI.PurchaseRejected and no loading transition; same-session purchased vehicles enter; stale selection repairs; objectives stay hidden; physical colours persist.")
print(TAG.." NEXT: restart Play mode, run the complete profile/device/module-location verification matrix, then rerun this same script with MODE='AUDIT'.")
