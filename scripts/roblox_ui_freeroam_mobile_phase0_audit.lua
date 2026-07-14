-- Neo Tokyo Racers - Mobile Free-Roam UI Phase 0 Audit
-- Run in Roblox Studio Command Bar in Edit mode. Read-only.

local PHASE = "NTR Mobile Free-Roam UI Phase 0 Audit"
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local pass, warn, fail = 0, 0, 0
local function result(kind, message)
	if kind == "PASS" then pass += 1 elseif kind == "WARN" then warn += 1 else fail += 1 end
	print(("[%s] %s: %s"):format(PHASE, kind, message))
end
local function check(condition, message, warning)
	result(condition and "PASS" or (warning and "WARN" or "FAIL"), message)
	return condition
end
local function at(root, ...)
	local current = root
	for _, name in ipairs({ ... }) do current = current and current:FindFirstChild(name) end
	return current
end

local kit = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
check(kit and kit:IsA("Folder"), "ReplicatedStorage.NeoTokyoRacers exists")
if not kit then return end

local shared = at(kit, "Shared")
local inputState = at(shared, "Modules", "Client", "Controllers", "MobileDriveInputState")
check(inputState and inputState:IsA("ModuleScript"), "shared MobileDriveInputState module exists")
if inputState then
	for _, marker in ipairs({ "Throttle", "Steer", "Drift", "Boost", "IsDriving", "SetSteering", "Reset" }) do
		check(string.find(inputState.Source, marker, 1, true) ~= nil, "MobileDriveInputState exposes " .. marker)
	end
end

local remotes = at(shared, "Remotes")
check(at(remotes, "Garage", "GarageInvoke") ~= nil, "GarageInvoke exists")
check(at(remotes, "Garage", "GarageInteriorInvoke") ~= nil, "GarageInteriorInvoke exists", true)
check(at(remotes, "UI", "FreeRoamHudTeleportInvoke") ~= nil, "FreeRoamHudTeleportInvoke exists")

local playerScripts = at(StarterPlayer, "StarterPlayerScripts")
local client = at(playerScripts, "NeoTokyoRacersClient")
local controllers = at(client, "Controllers")
local runtime = at(controllers, "Runtime")
local ui = at(controllers, "UI")
check(runtime and runtime:IsA("Folder"), "Runtime controller folder exists")
check(ui and ui:IsA("Folder"), "UI controller folder exists")

local mobile = at(runtime, "MobileDriveControlsController_Active")
check(mobile and mobile:IsA("LocalScript"), "mobile drive control owner exists")
if mobile then
	check(string.find(mobile.Source, "TouchEnabled", 1, true) ~= nil, "mobile owner remains touch-gated")
	check(string.find(mobile.Source, "NTR_RACING_UI_PHASE16E_RUNTIME_OWNERSHIP", 1, true) ~= nil
		or string.find(mobile.Source, "NTR_MOBILE_FREEROAM_UI_PHASE1", 1, true) ~= nil,
		"mobile owner is Phase 16E loader or already Phase 1")
end

for _, name in ipairs({ "DriveHudController_Active", "MobileDriveControlsController_Active" }) do
	local item = at(runtime, name)
	check(item and item:IsA("LocalScript"), name .. " exists")
end
for _, name in ipairs({ "DesktopFreeRoamHudController_Active", "FreeRoamNavController_Active", "FreeRoamVehicleExitButton_Active" }) do
	local item = at(ui, name)
	check(item and item:IsA("LocalScript"), name .. " exists")
end

local desktop = at(ui, "DesktopFreeRoamHudController_Active")
if desktop then
	for _, marker in ipairs({ "NTR_PC_FREEROAM_UI_PHASE4A_DEALERSHIP_TELEPORT", "MapTileTopLeft", "OpenRaceBrowser", "ExitVehicle" }) do
		check(string.find(desktop.Source, marker, 1, true) ~= nil, "desktop Phase 4A contract contains " .. marker)
	end
end

local bootstrap = at(client, "NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")
check(bootstrap and bootstrap:IsA("LocalScript"), "register-limited bootstrap exists")
if bootstrap then
	for _, marker in ipairs({ "FreeRoamVehicleSpawned", "FreeRoamVehicleExited", "MobileDriveInputState" }) do
		check(string.find(bootstrap.Source, marker, 1, true) ~= nil, "bootstrap bridge contains " .. marker)
	end
end

local desktopConfig = at(kit, "Config", "UI", "DesktopFreeRoamHud")
check(desktopConfig and desktopConfig:IsA("Folder"), "Phase 4A desktop HUD config exists")
if desktopConfig then
	for _, name in ipairs({ "Colours", "Layout", "Assets", "Defaults" }) do
		check(desktopConfig:FindFirstChild(name) ~= nil, "desktop config contains " .. name)
	end
end

print(("[%s] COMPLETE pass=%d warn=%d fail=%d"):format(PHASE, pass, warn, fail))
if fail == 0 then
	print("[" .. PHASE .. "] Gate passed. Run scripts/roblox_ui_freeroam_mobile_phase1_canonical_hud_controls.lua in Edit mode.")
else
	warn("[" .. PHASE .. "] Gate failed. Refresh the Studio mirror and inspect live owners before installing Phase 1.")
end
