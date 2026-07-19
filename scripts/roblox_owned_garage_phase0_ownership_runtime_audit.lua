-- Neo Tokyo Racers - Owned Garage replacement Phase 0 ownership/runtime audit
-- NTR_OWNED_GARAGE_PHASE0_OWNERSHIP_RUNTIME_AUDIT_V1
--
-- READ ONLY. This script does not create, destroy, reparent, enable, disable,
-- edit, invoke remotes, mark profiles dirty, save profiles, or change Attributes.
--
-- Run the same complete script in three contexts:
--   1. Studio Edit Command Bar: static source, hierarchy, owner, and dependency audit.
--   2. Play Server Command Bar: profile/display-reference and runtime-instance audit.
--   3. Play Client Command Bar: current HUD, map, menu, and interior presentation audit.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local PREFIX = "[NTR Owned Garage Phase 0]"
local counts = { PASS = 0, WARN = 0, BLOCKER = 0, INFO = 0 }

local function report(level, message)
	counts[level] += 1
	local text = string.format("%s %-7s %s", PREFIX, level, tostring(message))
	if level == "BLOCKER" then warn(text) else print(text) end
end

local function pass(message) report("PASS", message) end
local function warnLine(message) report("WARN", message) end
local function blocker(message) report("BLOCKER", message) end
local function info(message) report("INFO", message) end

local function finish(mode)
	print(string.format(
		"%s RESULT mode=%s pass=%d warn=%d blocker=%d info=%d",
		PREFIX,
		mode,
		counts.PASS,
		counts.WARN,
		counts.BLOCKER,
		counts.INFO
	))
	if counts.BLOCKER == 0 then
		print(PREFIX .. " GATE PASS: copy the complete output back to Codex.")
	else
		warn(PREFIX .. " GATE BLOCKED: do not install the replacement; copy the complete output back to Codex.")
	end
end

local function findPath(root, path)
	local current = root
	for segment in string.gmatch(path, "[^.]+") do
		current = current and current:FindFirstChild(segment)
	end
	return current
end

local function fullName(object)
	local ok, result = pcall(function() return object:GetFullName() end)
	return ok and result or tostring(object)
end

local function sourceOf(object)
	if not object or not object:IsA("LuaSourceContainer") then return nil end
	local ok, source = pcall(function() return object.Source end)
	return ok and type(source) == "string" and source or nil
end

local function has(source, marker)
	return type(source) == "string" and string.find(source, marker, 1, true) ~= nil
end

local function countDictionary(value)
	local count = 0
	if type(value) == "table" then for _ in pairs(value) do count += 1 end end
	return count
end

local function enabledState(object)
	if object and object:IsA("BaseScript") then return object.Enabled and "enabled" or "disabled" end
	return object and "module" or "missing"
end

local function inspectSource(path, requiredMarkers, missingLevel)
	local object = findPath(game, path)
	if not object then
		blocker("Missing source owner: " .. path)
		return nil, nil
	end
	local source = sourceOf(object)
	if not source then
		blocker("Studio did not expose Source for " .. path .. ". Run the static audit in Edit mode.")
		return object, nil
	end
	info(string.format("SOURCE %s [%s, %d chars]", fullName(object), enabledState(object), #source))
	for _, marker in ipairs(requiredMarkers or {}) do
		if has(source, marker) then
			pass(path .. " contains " .. marker)
		elseif missingLevel == "WARN" then
			warnLine(path .. " is missing expected marker " .. marker)
		else
			blocker(path .. " is missing required marker " .. marker)
		end
	end
	return object, source
end

local function staticAudit()
	print(PREFIX .. " MODE Edit/static (read only)")

	local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	if not kit then blocker("ReplicatedStorage.NeoTokyoRacers is missing."); finish("STATIC"); return end

	local clientRoot = findPath(StarterPlayer, "StarterPlayerScripts.NeoTokyoRacersClient")
	local uiRoot = clientRoot and findPath(clientRoot, "Controllers.UI")
	local worldRoot = clientRoot and findPath(clientRoot, "Controllers.World")
	local racingRoot = clientRoot and findPath(clientRoot, "Controllers.Racing")
	local garageServices = findPath(ServerScriptService, "NeoTokyoRacers.Services.Garage")
	local playerServices = findPath(ServerScriptService, "NeoTokyoRacers.Services.Player")
	local garageRemotes = findPath(kit, "Shared.Remotes.Garage")

	for _, requirement in ipairs({
		{ "UI controller root", uiRoot },
		{ "World controller root", worldRoot },
		{ "Racing controller root", racingRoot },
		{ "Garage services root", garageServices },
		{ "Player services root", playerServices },
		{ "Garage remotes root", garageRemotes },
	}) do
		if requirement[2] then pass(requirement[1] .. " exists at " .. fullName(requirement[2]))
		else blocker(requirement[1] .. " is missing.") end
	end

	local _, profileSource = inspectSource(
		"ServerScriptService.NeoTokyoRacers.Services.Player.ProfileService_Active",
		{
			'ensureFolder(playerServices, "ProfileServiceBindings")',
			'ensureBindableFunction(bindings, "GetProfile")',
			'ensureBindableFunction(bindings, "MarkDirty")',
			'ensureBindableFunction(bindings, "SaveNow")',
			'ensureBindableFunction(bindings, "ImportProfileSnapshot")',
		}
	)
	if profileSource and has(profileSource, "PlayerAdded") then pass("ProfileService retains player-session ownership.") end

	local _, actionSource = inspectSource(
		"ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled",
		{
			"local function V56_buildVehicle",
			"local function V91_spawnOwnedVehicleFromFreeRoam",
			"local function V92_despawnVehicle",
			'elseif action == "SpawnOwnedVehicleFromFreeRoam"',
			'elseif action == "DespawnVehicle"',
			"NTR_RaceQueueActive",
		}
	)
	if actionSource then
		if has(actionSource, "GarageVehicleLifecycleBinding") then
			warnLine("A GarageVehicleLifecycleBinding already exists; inspect it before adding the planned narrow bridge.")
		else
			pass("No pre-existing owned-garage vehicle lifecycle binding competes with the planned bridge.")
		end
	end

	local _, desktopSource = inspectSource(
		"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.DesktopFreeRoamHudController_Active",
		{
			'actionIcon("Garage", "GarageIcon", "HOME"',
			'interiorInvoke:InvokeServer("VisitGarage"',
			'minimap = new("Frame"',
		},
		"WARN"
	)
	local _, mobileSource = inspectSource(
		"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.MobileFreeRoamHudController_Active",
		{
			"garageButton.Activated:Connect",
			'interiorInvoke:InvokeServer("VisitGarage"',
			"NTRMobileMajorMenuOpen",
		},
		"WARN"
	)
	if desktopSource and has(desktopSource, 'interiorInvoke:InvokeServer("VisitGarage"') then
		pass("Desktop HOME currently has one identifiable direct-entry handler for canonical replacement.")
	end
	if mobileSource and has(mobileSource, 'interiorInvoke:InvokeServer("VisitGarage"') then
		pass("Mobile HOME currently has one identifiable direct-entry handler for canonical replacement.")
	end
	for label, source in pairs({ Desktop = desktopSource, Mobile = mobileSource }) do
		if source then
			local hasInteriorMapPolicy = has(source, "NTR_GarageInteriorActive") or has(source, "NTR_Phase21InPrivateGarage")
			if hasInteriorMapPolicy then pass(label .. " HUD already contains an interior-state visibility hook.")
			else warnLine(label .. " HUD has no explicit interior-state minimap policy; replacement must add one shared state contract.") end
		end
	end

	local _, raceBrowserSource = inspectSource(
		"StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.Racing.RaceBrowserClient_Active",
		{
			'require(uiModules:WaitForChild("RacingUIComponents"))',
			'require(uiModules:WaitForChild("RacingMobileScaledDesktopLayout"))',
			'L("ShellWidth", 1200)',
			'L("ShellHeight", 720)',
			"MobileScaledDesktop.Attach(shell)",
		}
	)
	if raceBrowserSource and has(raceBrowserSource, 'Name = "RacingShell"') then
		pass("Race Browser exposes the approved shell composition for My Garages reuse.")
	end

	for _, moduleName in ipairs({ "GarageReplacementComponents", "RacingUIComponents", "RacingMobileScaledDesktopLayout" }) do
		local object = (uiRoot and uiRoot:FindFirstChild(moduleName)) or findPath(kit, "Shared.Modules.UI." .. moduleName)
		if object and object:IsA("ModuleScript") then pass("Shared UI dependency exists: " .. fullName(object))
		else blocker("Shared UI dependency missing: " .. moduleName) end
	end

	local retirementCandidates = {
		{ worldRoot, "GarageAccessClient_Active" },
		{ worldRoot, "GarageInteriorClient_Active" },
		{ worldRoot, "GarageInteriorCustomizationClient_Active" },
		{ uiRoot, "GaragePropertyMenuController" },
		{ garageServices, "GarageDisplayRuntime" },
		{ garageServices, "GarageInteriorService_Active" },
		{ garageServices, "GarageInteriorCustomizationService_Active" },
		{ garageRemotes, "GarageInteriorInvoke" },
		{ garageRemotes, "GarageInteriorTransition" },
		{ garageRemotes, "GarageInteriorCustomizationInvoke" },
	}
	for _, candidate in ipairs(retirementCandidates) do
		local object = candidate[1] and candidate[1]:FindFirstChild(candidate[2])
		if object then info("RETIREMENT CANDIDATE " .. fullName(object) .. " [" .. enabledState(object) .. "]")
		else warnLine("Retirement candidate is already absent: " .. candidate[2]) end
	end

	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local interiorPool = world and findPath(world, "Interiors.GarageInstances")
	local exterior = world and findPath(world, "Interactives.GarageInteriorElevatorMVP")
	if interiorPool then
		pass("Existing runtime interior pool exists: " .. fullName(interiorPool))
		info("Interior pool base=" .. tostring(interiorPool:GetAttribute("InteriorBasePosition")) .. " spacing=" .. tostring(interiorPool:GetAttribute("InteriorSlotSpacing")))
	else blocker("Workspace.NeoTokyoRacersWorld.Interiors.GarageInstances is missing.") end
	if exterior then
		pass("Existing exterior entrance marker can provide the editable replacement placement reference: " .. fullName(exterior))
		if exterior:IsA("BasePart") then info("Exterior marker CFrame=" .. tostring(exterior.CFrame) .. " size=" .. tostring(exterior.Size)) end
	else warnLine("GarageInteriorElevatorMVP is absent; the replacement installer needs an explicit exterior placement configuration.") end

	local templateRoot = findPath(game:GetService("ServerStorage"), "NeoTokyoRacers.Interiors.GarageTemplates")
	if templateRoot then warnLine("GarageTemplates already exists; inspect it before installing StarterTwoBay.")
	else pass("No existing ServerStorage garage-template owner competes with the planned StarterTwoBay template.") end

	local schema = findPath(kit, "Shared.Modules.Data.PlayerProfileSchema")
	local schemaSource = sourceOf(schema)
	if not schemaSource then blocker("PlayerProfileSchema source is unavailable.")
	else
		if has(schemaSource, "DisplaySpaces") and has(schemaSource, "ActiveGarageId") then pass("Current profile schema exposes the legacy garage fields targeted by the clean reset.")
		else warnLine("Current profile schema does not contain both DisplaySpaces and ActiveGarageId; inspect before schema replacement.") end
	end

	pass("Static audit made no changes.")
	finish("STATIC")
end

local function collectDisplayReferences(profile)
	local references = {}
	local function add(source, garageId, slotId, vehicleId)
		vehicleId = vehicleId ~= nil and tostring(vehicleId) or ""
		if vehicleId ~= "" then
			table.insert(references, { Source = source, GarageId = tostring(garageId or ""), SlotId = tostring(slotId or ""), VehicleId = vehicleId })
		end
	end
	local garage = type(profile.Garage) == "table" and profile.Garage or {}
	for slotId, item in pairs(type(garage.DisplaySpaces) == "table" and garage.DisplaySpaces or {}) do
		add("Garage.DisplaySpaces", garage.ActiveGarageId, slotId, type(item) == "table" and item.VehicleId or item)
	end
	for slotId, item in pairs(type(profile.GarageDisplaySpaces) == "table" and profile.GarageDisplaySpaces or {}) do
		add("GarageDisplaySpaces", garage.ActiveGarageId, slotId, type(item) == "table" and item.VehicleId or item)
	end
	for garageId, property in pairs(type(garage.Properties) == "table" and garage.Properties or {}) do
		for slotId, item in pairs(type(property) == "table" and type(property.DisplaySpaces) == "table" and property.DisplaySpaces or {}) do
			add("Garage.Properties", garageId, slotId, type(item) == "table" and item.VehicleId or item)
		end
	end
	return references
end

local function serverRuntimeAudit()
	print(PREFIX .. " MODE Play/server (read only)")
	local players = Players:GetPlayers()
	if #players == 0 then blocker("No test player is connected. Start Play with a player before running the server audit."); finish("SERVER"); return end

	local bindings = findPath(ServerScriptService, "NeoTokyoRacers.Services.Player.ProfileServiceBindings")
	local getProfile = bindings and bindings:FindFirstChild("GetProfile")
	if not (getProfile and getProfile:IsA("BindableFunction")) then
		blocker("ProfileServiceBindings.GetProfile is unavailable in Play server context.")
		finish("SERVER")
		return
	end

	for _, player in ipairs(players) do
		local ok, profile = pcall(function() return getProfile:Invoke(player) end)
		if not ok or type(profile) ~= "table" then
			blocker("Could not read the active profile for " .. player.Name .. ": " .. tostring(profile))
			continue
		end
		local vehicles = type(profile.Vehicles) == "table" and profile.Vehicles or {}
		local references = collectDisplayReferences(profile)
		local byVehicle = {}
		local missing = 0
		for _, reference in ipairs(references) do
			byVehicle[reference.VehicleId] = byVehicle[reference.VehicleId] or {}
			table.insert(byVehicle[reference.VehicleId], reference)
			if vehicles[reference.VehicleId] == nil then
				missing += 1
				warnLine(string.format("%s display reference points to missing vehicle: %s/%s -> %s", player.Name, reference.GarageId, reference.SlotId, reference.VehicleId))
			end
		end
		local duplicates = 0
		for vehicleId, items in pairs(byVehicle) do
			if #items > 1 then
				duplicates += 1
				local paths = {}
				for _, item in ipairs(items) do table.insert(paths, item.Source .. ":" .. item.GarageId .. "/" .. item.SlotId) end
				warnLine(player.Name .. " duplicate display reference for " .. vehicleId .. " at " .. table.concat(paths, ", "))
			end
		end
		info(string.format(
			"PROFILE player=%s userId=%d vehicles=%d cockpitInstances=%d moduleInstances=%d displayRefs=%d duplicateVehicleRefs=%d missingVehicleRefs=%d garageSchema=%s activeGarage=%s",
			player.Name,
			player.UserId,
			countDictionary(vehicles),
			countDictionary(profile.OwnedCockpitInstances),
			countDictionary(profile.OwnedModuleInstances),
			#references,
			duplicates,
			missing,
			tostring(type(profile.Garage) == "table" and profile.Garage.SchemaVersion or nil),
			tostring(type(profile.Garage) == "table" and profile.Garage.ActiveGarageId or nil)
		))
		pass("Read active profile for " .. player.Name .. " without mutation.")
	end

	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtimeVehicles = world and findPath(world, "Runtime.PlayerVehicles")
	local interiorPool = world and findPath(world, "Interiors.GarageInstances")
	local runtimeVehicleCount = runtimeVehicles and #runtimeVehicles:GetChildren() or 0
	local interiorCount = interiorPool and #interiorPool:GetChildren() or 0
	local displayCount = 0
	if interiorPool then
		for _, object in ipairs(interiorPool:GetDescendants()) do
			if object:IsA("Model") and (object.Name == "DisplayVehicle_Runtime" or object.Parent and object.Parent.Name == "DisplayVehicles_Runtime") then displayCount += 1 end
		end
	end
	info(string.format("RUNTIME playerVehicles=%d interiors=%d displayModels=%d", runtimeVehicleCount, interiorCount, displayCount))
	if interiorPool then pass("Runtime interior pool is visible to the server audit.")
	else blocker("Runtime interior pool is missing in Play.") end

	for _, player in ipairs(players) do
		info(string.format(
			"STATE player=%s inInterior=%s interiorId=%s visitingOwner=%s raceQueue=%s raceSession=%s",
			player.Name,
			tostring(player:GetAttribute("NTR_Phase21InPrivateGarage")),
			tostring(player:GetAttribute("NTR_Phase21GarageInteriorId")),
			tostring(player:GetAttribute("NTR_Phase23VisitingGarageOwnerUserId")),
			tostring(player:GetAttribute("NTR_RaceQueueActive")),
			tostring(player:GetAttribute("NTR_RaceSessionActive"))
		))
	end

	pass("Server runtime audit made no profile, instance, or Attribute changes.")
	finish("SERVER")
end

local function effectivelyVisible(object)
	local current = object
	while current do
		if current:IsA("ScreenGui") and not current.Enabled then return false end
		if current:IsA("GuiObject") and not current.Visible then return false end
		current = current.Parent
	end
	return object ~= nil and object.Parent ~= nil
end

local function clientRuntimeAudit(player)
	print(PREFIX .. " MODE Play/client (read only)")
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then blocker("Local PlayerGui is unavailable."); finish("CLIENT"); return end

	local desktopGui = playerGui:FindFirstChild("NTR_DesktopFreeRoamHud")
	local mobileGui = playerGui:FindFirstChild("NTR_MobileFreeRoamHud_Phase1")
	local hudGui = desktopGui or mobileGui
	if hudGui then pass("Active free-roam HUD found: " .. fullName(hudGui))
	else warnLine("No known free-roam HUD ScreenGui is present; run after HUD startup.") end

	local home = hudGui and (hudGui:FindFirstChild("Garage", true) or hudGui:FindFirstChild("GarageButton", true))
	if home and home:IsA("GuiButton") then
		pass("HOME/Garage action is present and uses a GuiButton.")
		info("HOME visible=" .. tostring(effectivelyVisible(home)) .. " size=" .. tostring(home.AbsoluteSize))
	else warnLine("Could not resolve the active HOME/Garage GuiButton by name.") end

	local inInterior = player:GetAttribute("NTR_Phase21InPrivateGarage") == true
		or tostring(player:GetAttribute("NTR_Phase21GarageInteriorId") or "") ~= ""
	local minimap = hudGui and hudGui:FindFirstChild("Minimap", true)
	info("INTERIOR active=" .. tostring(inInterior) .. " minimap=" .. tostring(minimap and effectivelyVisible(minimap)))
	if inInterior and minimap and effectivelyVisible(minimap) then
		warnLine("Minimap is effectively visible inside the current garage interior; this confirms the replacement needs one explicit map suppression owner.")
	elseif inInterior then
		pass("Minimap is not effectively visible inside the current garage interior.")
	else
		warnLine("Player is not inside the current interior. Enter it and rerun this client audit for map/HUD evidence.")
	end

	for _, guiName in ipairs({ "NTR_GarageAccessUI", "NTR_GarageInteriorCustomizationUI", "NTR_GarageInteriorTransition" }) do
		local gui = playerGui:FindFirstChild(guiName)
		if gui then info("LEGACY GUI " .. guiName .. " enabled=" .. tostring(gui:IsA("ScreenGui") and gui.Enabled))
		else warnLine("Legacy runtime GUI is absent: " .. guiName) end
	end

	local raceBrowser = playerGui:FindFirstChild("NTR_RaceBrowser")
	local raceShell = raceBrowser and raceBrowser:FindFirstChild("RacingShell", true)
	if raceShell and raceShell:IsA("GuiObject") then
		info("RACE SHELL visible=" .. tostring(effectivelyVisible(raceShell)) .. " absoluteSize=" .. tostring(raceShell.AbsoluteSize))
		pass("Runtime Race Browser shell exists for garage-browser size comparison.")
	else warnLine("Race Browser shell is not constructed/available; static source contract remains the size authority.") end

	local visibleGarageGuis = {}
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Enabled and string.find(string.lower(child.Name), "garage", 1, true) then
			table.insert(visibleGarageGuis, child.Name)
		end
	end
	table.sort(visibleGarageGuis)
	info("ENABLED GARAGE GUIS count=" .. tostring(#visibleGarageGuis) .. " names=" .. table.concat(visibleGarageGuis, ","))

	pass("Client runtime audit made no UI, state, remote, or Attribute changes.")
	finish("CLIENT")
end

if not RunService:IsRunning() then
	staticAudit()
elseif Players.LocalPlayer then
	clientRuntimeAudit(Players.LocalPlayer)
else
	serverRuntimeAudit()
end
