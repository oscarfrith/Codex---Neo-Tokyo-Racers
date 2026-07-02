-- NTR Persistence Phase 22 Garage Display Vehicle MVP
-- Dual-mode Studio Command Bar script.
--
-- Edit mode:
--   Installs GarageDisplayRuntime and patches the Phase 21 garage interior service
--   so entering a private garage creates a lightweight anchored display vehicle.
--
-- Play mode, CLIENT Command Bar:
--   Enters the private garage, confirms the display clone exists, then returns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local TAG = "[NTR Persistence Phase 22 Garage Display Vehicle MVP]"

local function info(message)
	print(TAG .. " " .. tostring(message))
end

local function waitForPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current:WaitForChild(name)
	end
	return current
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, existing:GetFullName() .. " is " .. existing.ClassName .. ", expected " .. className)
		return existing
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function replaceOnce(source, oldText, newText, label)
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	assert(startIndex, "Could not find source anchor for " .. label)
	assert(not string.find(source, newText, 1, true), label .. " already appears to be installed.")
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
end

local function insertAfterOnce(source, anchorText, insertText, label, searchStart)
	searchStart = searchStart or 1
	local startIndex, endIndex = string.find(source, anchorText, searchStart, true)
	assert(startIndex, "Could not find source anchor for " .. label)
	if string.find(source, insertText, 1, true) then
		return source
	end
	return string.sub(source, 1, endIndex) .. insertText .. string.sub(source, endIndex + 1)
end

if RunService:IsRunning() then
	local player = Players.LocalPlayer
	assert(player, "Run this smoke from the CLIENT Command Bar during Play.")

	local remotes = waitForPath(ReplicatedStorage, { "NeoTokyoRacers", "Shared", "Remotes", "Garage" })
	local invoke = remotes:WaitForChild("GarageInteriorInvoke")
	local garageInvoke = remotes:WaitForChild("GarageInvoke")
	local initial = garageInvoke:InvokeServer("GetInitial", {})
	assert(type(initial) == "table" and initial.Profile ~= nil, "Garage GetInitial failed before display smoke.")
	info("Garage GetInitial OK before display smoke.")

	local enter = invoke:InvokeServer("EnterOwnGarage", { Smoke = true, Phase22 = true })
	assert(type(enter) == "table" and enter.Ok == true, "EnterOwnGarage failed: " .. tostring(enter and enter.Error))
	info("EnterOwnGarage OK. interior=" .. tostring(enter.InteriorId) .. " displayOk=" .. tostring(enter.DisplayOk) .. " display=" .. tostring(enter.DisplayName) .. " streamOk=" .. tostring(player:GetAttribute("NTR_Phase21LastStreamOk")) .. " streamError=" .. tostring(player:GetAttribute("NTR_Phase21LastStreamError")))

	task.wait(1.25)

	local state = invoke:InvokeServer("GetState", {})
	assert(type(state) == "table" and state.Ok == true, "GetState failed: " .. tostring(state and state.Error))
	assert(state.DisplayExists == true, "Garage display vehicle was not found in the active interior.")
	info("State InGarage=" .. tostring(state.InGarage) .. " displayExists=" .. tostring(state.DisplayExists) .. " displayName=" .. tostring(state.DisplayName) .. " displaySource=" .. tostring(state.DisplaySource))

	local returned = invoke:InvokeServer("ReturnToCity", { Smoke = true, Phase22 = true })
	assert(type(returned) == "table" and returned.Ok == true, "ReturnToCity failed: " .. tostring(returned and returned.Error))
	info("ReturnToCity OK. returnSource=" .. tostring(returned.ReturnSource))
	info("Expected: private garage now contains a non-drivable anchored display clone of the current saved vehicle.")
	return
end

local services = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
local garageServices = services:WaitForChild("Garage")
local interiorService = garageServices:WaitForChild("GarageInteriorService_Active")
assert(interiorService:IsA("Script"), "Expected Phase 21 GarageInteriorService_Active before Phase 22.")
assert(string.find(interiorService.Source, "NTR Persistence Phase 21 Private Garage Interior MVP", 1, true), "Expected Phase 21 interior service source before Phase 22.")

local displayRuntimeSource = [=[-- NTR Persistence Phase 22 Garage Display Vehicle MVP

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GarageDisplayRuntime = {}

local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local categoriesRoot = kit:WaitForChild("Assets"):WaitForChild("Vehicles"):WaitForChild("Categories")

local function findByAttribute(root, attributeName, expectedValue)
	if not root then
		return nil
	end
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("Model") and tostring(item:GetAttribute(attributeName) or "") == tostring(expectedValue or "") then
			return item
		end
	end
	return nil
end

local function categoryFolder(categoryId)
	local wanted = string.upper(tostring(categoryId or "BRUISER"))
	for _, child in ipairs(categoriesRoot:GetChildren()) do
		if string.upper(child.Name) == wanted or string.lower(child.Name) == string.lower(tostring(categoryId or "")) then
			return child
		end
	end
	return categoriesRoot:FindFirstChild("BRUISER") or categoriesRoot:GetChildren()[1]
end

local function findCockpit(categoryId, cockpitId)
	local category = categoryFolder(categoryId)
	local root = category and (category:FindFirstChild("COCKPITS_ReplaceAssetsHere") or category:FindFirstChild("Cockpits") or category:FindFirstChild("COCKPITS"))
	return findByAttribute(root or category, "CockpitId", cockpitId)
end

local function findModule(categoryId, moduleId)
	local category = categoryFolder(categoryId)
	local root = category and (category:FindFirstChild("MODULES_InterchangeableWithinCategory") or category)
	return findByAttribute(root, "ModuleId", moduleId)
end

local function profileBindings()
	local playerServices = ServerScriptService:FindFirstChild("NeoTokyoRacers")
		and ServerScriptService.NeoTokyoRacers:FindFirstChild("Services")
		and ServerScriptService.NeoTokyoRacers.Services:FindFirstChild("Player")
	local bindings = playerServices and playerServices:FindFirstChild("ProfileServiceBindings")
	local getProfile = bindings and bindings:FindFirstChild("GetProfile")
	return getProfile and getProfile:IsA("BindableFunction") and getProfile or nil
end

local function getProfile(player)
	local binding = profileBindings()
	if binding then
		local ok, profile = pcall(function()
			return binding:Invoke(player)
		end)
		if ok and typeof(profile) == "table" then
			return profile
		end
	end
	return nil
end

local function resolvePaintChannel(object)
	local current = object
	while current do
		local attr = current:GetAttribute("PaintChannel")
		if typeof(attr) == "string" and attr ~= "" then
			return attr
		end
		if current.Name == "PRIMARY_ReplaceWithPrimaryMeshes" then return "Primary" end
		if current.Name == "SECONDARY_ReplaceWithSecondaryMeshes" then return "Secondary" end
		if current.Name == "DETAIL_ReplaceWithDetailMeshes" then return "Detail" end
		if current.Name == "NEON_OptionalLights" then return "Neon" end
		if current.Name == "THRUST_COLOR_WhiteByDefault" then return "ThrustColor" end
		current = current.Parent
	end
	return nil
end

local function pathHas(object, text)
	text = string.lower(tostring(text or ""))
	local current = object
	while current do
		if string.find(string.lower(current.Name), text, 1, true) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function applyColors(model, colors, neonVisible)
	colors = typeof(colors) == "table" and colors or {}
	for _, object in ipairs(model:GetDescendants()) do
		if object:IsA("BasePart") then
			local channel = resolvePaintChannel(object)
			if object:GetAttribute("TemplateRole") == "FixedSlotMount" then
				object.Transparency = 1
				object.CanCollide = false
				object.CanQuery = false
				object.CanTouch = false
			elseif channel == "ThrustColor" then
				object.Color = colors.ThrustColor or Color3.fromRGB(255, 255, 255)
				object.Material = Enum.Material.Neon
				object.Transparency = 0
			elseif channel == "Neon" then
				local colour = colors.Neon or Color3.fromRGB(255, 255, 255)
				if pathHas(object, "cockpit") then
					if pathHas(object, "front") then colour = colors.FrontLights or Color3.fromRGB(252, 250, 255) end
					if pathHas(object, "rear") or pathHas(object, "back") then colour = colors.RearLights or Color3.fromRGB(255, 116, 116) end
				end
				object.Color = colour
				object.Material = Enum.Material.Neon
				object.Transparency = neonVisible and 0 or 1
			elseif channel == "Primary" then
				object.Color = colors.Primary or object.Color
			elseif channel == "Secondary" then
				object.Color = colors.Secondary or object.Color
			elseif channel == "Detail" then
				object.Color = colors.Detail or object.Color
			end
		elseif object:IsA("ParticleEmitter") then
			object.Enabled = false
		elseif object:IsA("Beam") or object:IsA("Trail") then
			object.Enabled = false
		elseif object:IsA("SpotLight") or object:IsA("PointLight") or object:IsA("SurfaceLight") then
			object.Enabled = false
		end
	end
end

local function getSlotMount(vehicle, slotId)
	local slotRoot = vehicle and vehicle:FindFirstChild("FIXED_MODULE_SLOTS_DoNotRename", true)
	local slot = slotRoot and slotRoot:FindFirstChild("SLOT_" .. tostring(slotId), true)
	return slot and slot:FindFirstChild("Mount_DoNotRename")
end

local function pivotModuleToSlot(moduleClone, mount)
	local root = moduleClone.PrimaryPart or moduleClone:FindFirstChild("ModuleRoot_DoNotRename", true)
	if root then
		moduleClone.PrimaryPart = root
	end
	local moduleAttachment = moduleClone:FindFirstChild("MountAttachment", true)
	local mountAttachment = mount and mount:FindFirstChild("MountAttachment")
	if moduleAttachment and mountAttachment then
		moduleClone:PivotTo(mountAttachment.WorldCFrame * moduleAttachment.CFrame:Inverse())
	elseif mount then
		moduleClone:PivotTo(mount.CFrame)
	end
end

local function sanitizeDisplay(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		elseif descendant:IsA("VehicleSeat") or descendant:IsA("Seat") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
end

local function profileVehicle(profile)
	local vehicleId = profile and profile.CurrentVehicleId
	local vehicle = vehicleId and profile.Vehicles and profile.Vehicles[tostring(vehicleId)] or nil
	return typeof(vehicle) == "table" and vehicle or nil
end

local function legacyOrVehicleValue(profile, vehicle, key, fallback)
	if vehicle and vehicle[key] ~= nil then
		return vehicle[key]
	end
	if profile and profile[key] ~= nil then
		return profile[key]
	end
	return fallback
end

local function moduleIdForSlot(profile, vehicle, slotId)
	local installed = vehicle and vehicle.InstalledModules
	local instanceId = typeof(installed) == "table" and installed[slotId] or nil
	local instance = instanceId and profile.OwnedModuleInstances and profile.OwnedModuleInstances[tostring(instanceId)] or nil
	if typeof(instance) == "table" and instance.TemplateId then
		return tostring(instance.TemplateId)
	end
	local legacy = profile.InstalledModules
	return typeof(legacy) == "table" and legacy[slotId] or nil
end

function GarageDisplayRuntime.RefreshDisplayVehicle(player, interiorModel)
	if not player or not interiorModel then
		return { Ok = false, Error = "MissingPlayerOrInterior" }
	end

	local profile = getProfile(player)
	if typeof(profile) ~= "table" then
		return { Ok = false, Error = "MissingProfile" }
	end

	local vehicle = profileVehicle(profile)
	local categoryId = legacyOrVehicleValue(profile, vehicle, "CategoryId", profile.CurrentCategory or "bruiser")
	local cockpitId = legacyOrVehicleValue(profile, vehicle, "CockpitId", profile.CurrentCockpit)
	local cockpit = findCockpit(categoryId, cockpitId)
	if not cockpit then
		return { Ok = false, Error = "CockpitTemplateNotFound", CockpitId = cockpitId }
	end

	local existing = interiorModel:FindFirstChild("DisplayVehicle_Runtime")
	if existing then
		existing:Destroy()
	end

	local display = cockpit:Clone()
	display.Name = "DisplayVehicle_Runtime"
	display:SetAttribute("PersistencePhase22GarageDisplayVehicleMVP", true)
	display:SetAttribute("OwnerUserId", player.UserId)
	display:SetAttribute("CategoryId", categoryId)
	display:SetAttribute("CockpitId", cockpitId)
	display:SetAttribute("DisplaySource", "ProfileServiceCurrentVehicle")
	display.Parent = interiorModel

	local root = display.PrimaryPart or display:FindFirstChild("CockpitRoot_DoNotRename", true)
	if not root then
		display:Destroy()
		return { Ok = false, Error = "CockpitRootMissing" }
	end
	display.PrimaryPart = root

	local cockpitColors = legacyOrVehicleValue(profile, vehicle, "CockpitColors", profile.CockpitColors or {})
	local thrustColor = legacyOrVehicleValue(profile, vehicle, "ThrustColor", profile.ThrustColor)
	if typeof(cockpitColors) ~= "table" then
		cockpitColors = {}
	end
	cockpitColors.ThrustColor = thrustColor or cockpitColors.ThrustColor
	applyColors(display, cockpitColors, true)

	local installedRoot = display:FindFirstChild("INSTALLED_MODULES_Runtime") or Instance.new("Folder")
	installedRoot.Name = "INSTALLED_MODULES_Runtime"
	installedRoot.Parent = display
	installedRoot:ClearAllChildren()

	local moduleCount = 0
	local installed = profile.InstalledModules
	for slotId in pairs(typeof(installed) == "table" and installed or {}) do
		local moduleId = moduleIdForSlot(profile, vehicle, slotId)
		local moduleTemplate = moduleId and findModule(categoryId, moduleId) or nil
		local mount = getSlotMount(display, slotId)
		if moduleTemplate and mount then
			local moduleClone = moduleTemplate:Clone()
			moduleClone.Name = "DISPLAY_" .. tostring(slotId) .. "_" .. moduleTemplate.Name
			moduleClone:SetAttribute("InstalledSlotId", slotId)
			moduleClone:SetAttribute("PersistencePhase22GarageDisplayVehicleMVP", true)
			moduleClone.Parent = installedRoot
			pivotModuleToSlot(moduleClone, mount)
			local moduleColors = profile.ModuleColors and profile.ModuleColors[slotId] or {
				Primary = cockpitColors.Primary,
				Secondary = cockpitColors.Secondary,
				Detail = cockpitColors.Detail,
				Neon = Color3.fromRGB(255, 255, 255),
				ThrustColor = thrustColor,
			}
			if typeof(moduleColors) ~= "table" then
				moduleColors = {}
			end
			moduleColors.ThrustColor = thrustColor or moduleColors.ThrustColor
			applyColors(moduleClone, moduleColors, profile.NeonOwned and profile.NeonOwned[slotId] == true)
			moduleCount += 1
		end
	end

	sanitizeDisplay(display)

	local pad = interiorModel:FindFirstChild("VehicleDisplayPad", true)
	if pad and pad:IsA("BasePart") then
		display:PivotTo(pad.CFrame * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, math.rad(180), 0))
	else
		display:PivotTo(interiorModel:GetPivot() * CFrame.new(0, 3.2, 2))
	end

	return {
		Ok = true,
		DisplayName = display.Name,
		DisplaySource = display:GetAttribute("DisplaySource"),
		CockpitId = cockpitId,
		ModuleCount = moduleCount,
	}
end

return GarageDisplayRuntime
]=]

local displayRuntime = ensureChild(garageServices, "ModuleScript", "GarageDisplayRuntime")
displayRuntime.Source = displayRuntimeSource
displayRuntime:SetAttribute("PersistencePhase22GarageDisplayVehicleMVP", true)

local source = interiorService.Source
if not string.find(source, "NTR_PERSISTENCE_PHASE22_GARAGE_DISPLAY_REQUIRE", 1, true) then
	source = replaceOnce(
		source,
		[=[local garageRoot = interiors:WaitForChild("GarageInstances")
local interactives = world:WaitForChild("Interactives")]=],
		[=[local garageRoot = interiors:WaitForChild("GarageInstances")
local interactives = world:WaitForChild("Interactives")
-- NTR_PERSISTENCE_PHASE22_GARAGE_DISPLAY_REQUIRE
local GarageDisplayRuntime = require(script.Parent:WaitForChild("GarageDisplayRuntime"))]=],
		"Phase 22 display runtime require"
	)
end

if not string.find(source, "NTR_PERSISTENCE_PHASE22_REFRESH_DISPLAY", 1, true) then
	source = replaceOnce(
		source,
		[=[	local model = ensureInterior(player)
	local spawn = model:FindFirstChild("GarageSpawnPoint", true)]=],
		[=[	local model = ensureInterior(player)
	-- NTR_PERSISTENCE_PHASE22_REFRESH_DISPLAY
	local displayResult = GarageDisplayRuntime.RefreshDisplayVehicle(player, model)
	local spawn = model:FindFirstChild("GarageSpawnPoint", true)]=],
		"Phase 22 enter display refresh"
	)
	local enterPayloadStart = string.find(source, "NTR_PERSISTENCE_PHASE22_REFRESH_DISPLAY", 1, true) or 1
	source = insertAfterOnce(
		source,
		[=[		AccessMode = "Private",]=],
		[=[
		DisplayOk = typeof(displayResult) == "table" and displayResult.Ok == true,
		DisplayName = typeof(displayResult) == "table" and displayResult.DisplayName or nil,
		DisplaySource = typeof(displayResult) == "table" and displayResult.DisplaySource or nil,
		DisplayError = typeof(displayResult) == "table" and displayResult.Error or nil,]=],
		"Phase 22 enter return payload fields",
		enterPayloadStart
	)
	source = replaceOnce(
		source,
		[=[	local interiorId = player:GetAttribute("NTR_Phase21GarageInteriorId")
	local model = interiorId and garageRoot:FindFirstChild(tostring(interiorId)) or nil
]=],
		[=[	local interiorId = player:GetAttribute("NTR_Phase21GarageInteriorId")
	local model = interiorId and garageRoot:FindFirstChild(tostring(interiorId)) or nil
	local display = model and model:FindFirstChild("DisplayVehicle_Runtime") or nil
]=],
		"Phase 22 get state display lookup"
	)
	local stateStart = string.find(source, "local function getState", 1, true) or 1
	source = insertAfterOnce(
		source,
		[=[		AccessMode = player:GetAttribute("NTR_Phase21GarageAccessMode"),]=],
		[=[
		DisplayExists = display ~= nil,
		DisplayName = display and display.Name or nil,
		DisplaySource = display and display:GetAttribute("DisplaySource") or nil,]=],
		"Phase 22 get state display fields",
		stateStart
	)
	interiorService.Source = source
else
	if not string.find(source, "DisplayOk =", 1, true) then
		local enterPayloadStart = string.find(source, "NTR_PERSISTENCE_PHASE22_REFRESH_DISPLAY", 1, true) or 1
		source = insertAfterOnce(
			source,
			[=[		AccessMode = "Private",]=],
			[=[
		DisplayOk = typeof(displayResult) == "table" and displayResult.Ok == true,
		DisplayName = typeof(displayResult) == "table" and displayResult.DisplayName or nil,
		DisplaySource = typeof(displayResult) == "table" and displayResult.DisplaySource or nil,
		DisplayError = typeof(displayResult) == "table" and displayResult.Error or nil,]=],
			"Phase 22 enter return payload fields after partial install",
			enterPayloadStart
		)
	end
	if not string.find(source, "DisplayExists =", 1, true) then
		source = replaceOnce(
			source,
			[=[	local interiorId = player:GetAttribute("NTR_Phase21GarageInteriorId")
	local model = interiorId and garageRoot:FindFirstChild(tostring(interiorId)) or nil
]=],
			[=[	local interiorId = player:GetAttribute("NTR_Phase21GarageInteriorId")
	local model = interiorId and garageRoot:FindFirstChild(tostring(interiorId)) or nil
	local display = model and model:FindFirstChild("DisplayVehicle_Runtime") or nil
]=],
			"Phase 22 get state display lookup after partial install"
		)
		local stateStart = string.find(source, "local function getState", 1, true) or 1
		source = insertAfterOnce(
			source,
			[=[		AccessMode = player:GetAttribute("NTR_Phase21GarageAccessMode"),]=],
			[=[
		DisplayExists = display ~= nil,
		DisplayName = display and display.Name or nil,
		DisplaySource = display and display:GetAttribute("DisplaySource") or nil,]=],
			"Phase 22 get state display fields after partial install",
			stateStart
		)
	end
	interiorService.Source = source
	info("Phase 22 display hooks already installed or repaired after partial install; refreshing runtime module.")
end

local starterScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local clientScript = starterScripts:WaitForChild("NeoTokyoRacersClient"):WaitForChild("Controllers"):WaitForChild("World"):WaitForChild("GarageInteriorClient_Active")
assert(clientScript:IsA("LocalScript"), "Expected Phase 21 GarageInteriorClient_Active before Phase 22.")

if not string.find(clientScript.Source, "NTR_PERSISTENCE_PHASE22_STREAM_DIAGNOSTIC", 1, true) then
	clientScript.Source = replaceOnce(
		clientScript.Source,
		[=[		if typeof(payload.Position) == "Vector3" then
			ok = pcall(function()
				Workspace:RequestStreamAroundAsync(payload.Position)
			end)
		end
		player:SetAttribute("NTR_Phase21LastStreamOk", ok == true)]=],
		[=[		local streamError = ""
		if typeof(payload.Position) == "Vector3" then
			-- NTR_PERSISTENCE_PHASE22_STREAM_DIAGNOSTIC
			local success, err = pcall(function()
				Workspace:RequestStreamAroundAsync(payload.Position)
			end)
			ok = success == true
			if not success then
				streamError = tostring(err or "")
			end
		end
		player:SetAttribute("NTR_Phase21LastStreamOk", ok == true)
		player:SetAttribute("NTR_Phase21LastStreamError", streamError)]=],
		"Phase 22 stream diagnostic"
	)
end
clientScript:SetAttribute("PersistencePhase22GarageDisplayVehicleMVP", true)
interiorService:SetAttribute("PersistencePhase22GarageDisplayVehicleMVP", true)

local finalSource = interiorService.Source
assert(string.find(finalSource, "NTR_PERSISTENCE_PHASE22_GARAGE_DISPLAY_REQUIRE", 1, true), "Phase 22 display require missing.")
assert(string.find(finalSource, "NTR_PERSISTENCE_PHASE22_REFRESH_DISPLAY", 1, true), "Phase 22 display refresh hook missing.")
assert(string.find(finalSource, "DisplayExists", 1, true), "Phase 22 display state fields missing.")
assert(string.find(clientScript.Source, "NTR_PERSISTENCE_PHASE22_STREAM_DIAGNOSTIC", 1, true), "Phase 22 stream diagnostic missing.")

info("PASS: installed GarageDisplayRuntime, hooked private-garage entry display refresh, and added stream error diagnostics.")
info("Next: restart Play and run this same script from the CLIENT Command Bar. Expected displayExists=true and ReturnToCity OK.")
