-- Neo Tokyo Racers - PC Free-Roam UI Phase 0 Audit
-- Read-only Studio Command Bar audit. Run in Edit mode before generating the
-- first PC free-roam HUD installer.

local PHASE = "NTR PC Free-Roam UI Phase 0 Audit"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local passCount = 0
local warnCount = 0
local failCount = 0

local function line(kind, message)
	print(string.format("[%s] %-4s %s", PHASE, kind, tostring(message)))
end

local function pass(message)
	passCount += 1
	line("PASS", message)
end

local function warnLine(message)
	warnCount += 1
	line("WARN", message)
end

local function fail(message)
	failCount += 1
	line("FAIL", message)
end

local function child(parent, name)
	return parent and parent:FindFirstChild(name) or nil
end

local function path(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = child(current, name)
		if not current then return nil end
	end
	return current
end

local function checkObject(label, object, className, required)
	if not object then
		if required then
			fail(label .. " is missing.")
		else
			warnLine(label .. " is missing.")
		end
		return false
	end
	if className and not object:IsA(className) then
		fail(label .. " is " .. object.ClassName .. ", expected " .. className .. ".")
		return false
	end
	pass(label .. " -> " .. object:GetFullName())
	return true
end

local function readSource(object, label)
	if not object or not object:IsA("LuaSourceContainer") then return nil end
	local ok, source = pcall(function()
		return object.Source
	end)
	if not ok then
		warnLine("Could not read " .. label .. " source in this Studio context.")
		return nil
	end
	return source
end

local function checkMarkers(object, label, markers)
	local source = readSource(object, label)
	if not source then return end
	for _, marker in ipairs(markers) do
		if string.find(source, marker, 1, true) then
			pass(label .. " source contains " .. marker)
		else
			fail(label .. " source is missing " .. marker)
		end
	end
end

line("INFO", "Context: " .. (RunService:IsRunning() and "Play/runtime" or "Edit mode"))
line("INFO", "This audit does not create, modify, disable, or delete any Instance or source text.")

local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
checkObject("NeoTokyoRacers root", kit, "Folder", true)

local config = child(kit, "Config")
local uiConfig = child(config, "UI")
local theme = child(uiConfig, "Theme")
local freeRoamConfig = child(uiConfig, "FreeRoamNav")
local cockpitCardConfig = child(uiConfig, "CockpitMenuCards")

checkObject("Config.UI", uiConfig, "Folder", true)
checkObject("Shared UI theme", theme, "Folder", true)
checkObject("FreeRoamNav config", freeRoamConfig, "Folder", true)
checkObject("CockpitMenuCards config", cockpitCardConfig, "Folder", true)

local playerScripts = path(StarterPlayer, { "StarterPlayerScripts" })
local clientRoot = path(playerScripts, { "NeoTokyoRacersClient" })
local controllers = child(clientRoot, "Controllers")
local uiControllers = child(controllers, "UI")
local runtimeControllers = child(controllers, "Runtime")
local racingControllers = child(controllers, "Racing")

local bootstrap = child(clientRoot, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
local freeRoamNav = child(uiControllers, "FreeRoamNavController_Active")
local exitButton = child(uiControllers, "FreeRoamVehicleExitButton_Active")
local driveHudController = child(runtimeControllers, "DriveHudController_Active")
local raceBrowser = child(racingControllers, "RaceBrowserClient_Active")

checkObject("Active client bootstrap", bootstrap, "LocalScript", true)
checkObject("Free-roam navigation controller", freeRoamNav, "LocalScript", true)
checkObject("Free-roam exit controller", exitButton, "LocalScript", true)
checkObject("Drive HUD/mobile suppressor controller", driveHudController, "LocalScript", true)
checkObject("Race browser controller", raceBrowser, "LocalScript", true)

checkMarkers(bootstrap, "bootstrap", {
	"V75Driving.Start",
	"UpdateDriveUi = function",
	"FreeRoamVehicleSpawned",
	"FreeRoamVehicleExited",
})

checkMarkers(freeRoamNav, "free-roam navigation", {
	"NTR_FREEROAM_CAR_MENU_PHASE7_BORDERLESS_CARD_FRAMES_COMPACT_WIDTH",
	"SpawnOwnedVehicleFromFreeRoam",
	"DespawnVehicle",
	"OpenRaceBrowser",
	"GarageInteriorInvoke",
})

checkMarkers(exitButton, "free-roam exit controller", {
	"NTR_FREEROAM_VEHICLE_SPAWN_PHASE4C_EXIT_EVENT",
	"FreeRoamVehicleExited",
	"ExitVehicle",
})

local serverRoot = path(ServerScriptService, { "NeoTokyoRacers" })
local services = child(serverRoot, "Services")
local playerServices = child(services, "Player")
local profileService = child(playerServices, "ProfileService_Active")

checkObject("Profile service", profileService, "Script", true)
checkMarkers(profileService, "profile service", {
	"ProfileServiceBindings",
	"GetProfile",
	"ImportProfileSnapshot",
	"updateRuntimeMarker",
})

local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
local dealership = child(world, "Dealership")
local intro = child(dealership, "Intro")
local introSpawn = path(intro, { "Spawn", "IntroSpawnPoint" })
local deskTrigger = path(intro, { "Desk", "GarageDeskTrigger" })
local vehicleExitSpawn = path(dealership, { "Spawn", "VehicleExitSpawnPoint" })

checkObject("World root", world, "Folder", true)
checkObject("Dealership root", dealership, "Folder", true)
checkObject("Dealership intro spawn", introSpawn, "BasePart", true)
checkObject("Dealership desk trigger", deskTrigger, "BasePart", true)
checkObject("Dealership vehicle exit spawn", vehicleExitSpawn, "BasePart", true)

local teleportPoint = path(dealership, { "TeleportPoints", "FreeRoamHudTeleportPoint" })
if teleportPoint and teleportPoint:IsA("BasePart") then
	pass("Dedicated free-roam dealership teleport point already exists.")
else
	warnLine("Dedicated Dealership.TeleportPoints.FreeRoamHudTeleportPoint is not installed yet; Phase 1 should create an editable marker rather than reusing the vehicle exit spawn.")
end

local mapBounds = path(world, { "MapCalibration", "MinimapBounds" })
if mapBounds and mapBounds:IsA("BasePart") then
	pass("Minimap calibration bounds already exist.")
else
	warnLine("MapCalibration.MinimapBounds is not installed yet; the minimap phase should create one editable anchored calibration part.")
end

local desktopHud = child(uiControllers, "DesktopFreeRoamHudController_Active")
if desktopHud then
	warnLine("DesktopFreeRoamHudController_Active already exists. Inspect it before running a future installer.")
else
	pass("No existing DesktopFreeRoamHudController_Active conflicts with the planned isolated controller.")
end

local desktopHudConfig = child(uiConfig, "DesktopFreeRoamHud")
if desktopHudConfig then
	warnLine("Config.UI.DesktopFreeRoamHud already exists. Preserve its edited values in any future installer.")
else
	pass("No existing DesktopFreeRoamHud config conflicts with the planned config folder.")
end

local monetizationService = child(playerServices, "CashPurchaseService_Active")
if monetizationService then
	warnLine("CashPurchaseService_Active already exists. Audit receipt ownership before adding Developer Products.")
else
	pass("No existing cash purchase service was found; Robux cash purchases remain a separate future phase.")
end

line("INFO", string.format("Summary: pass=%d warn=%d fail=%d", passCount, warnCount, failCount))
if failCount == 0 then
	line("READY", "Phase 0 passed. Review warnings, paste this Output into Codex, and then generate the isolated visual-shell installer.")
else
	line("STOP", "Do not generate or run the installer until the failed live paths/source markers are inspected against a fresh Studio mirror.")
end
