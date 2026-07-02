-- Persistence Phase 17 close-garage drive handoff repair.
--
-- Run from Roblox Studio Command Bar in Edit mode if pressing Start Driving
-- spawns a car but the car is not hover/drivable, with Output similar to:
--
--   NeoTokyoRacersClient_Bootstrap_Shadow_Disabled:<line>: attempt to call a nil value
--   Line ... - function closeGarage
--
-- Root cause: after the Phase 17 colour-picker recovery, the optional
-- disconnectPickerInputs helper can be absent while closeGarage still calls it
-- directly. That stops the "SpawnVehicle -> close UI -> startDriving" handoff.
--
-- This patch keeps the change narrow:
-- - closeGarage tolerates missing cleanup helpers and missing camera targets.
-- - the final Start Driving button starts driving even if future UI cleanup
--   throws, while still warning in Output.

local StarterPlayer = game:GetService("StarterPlayer")

local PHASE = "Persistence Phase 17 Close Garage Drive Handoff Repair"

local function info(message)
	print("[NTR " .. PHASE .. "] " .. message)
end

local function findPlain(source, needle, startAt)
	return string.find(source, needle, startAt or 1, true)
end

local function replaceRange(source, startMarker, endMarker, replacement, label)
	local startAt = findPlain(source, startMarker)
	assert(startAt, "Could not find start marker for " .. label .. ". Refresh the Studio mirror before another close-garage patch.")
	local endAt = findPlain(source, endMarker, startAt + #startMarker)
	assert(endAt, "Could not find end marker for " .. label .. ". Refresh the Studio mirror before another close-garage patch.")
	local second = findPlain(source, startMarker, startAt + #startMarker)
	assert(not second or second > endAt, "Start marker for " .. label .. " appears more than once before the end marker. Refresh the Studio mirror before another close-garage patch.")
	return string.sub(source, 1, startAt - 1) .. replacement .. string.sub(source, endAt)
end

local function replaceOnce(source, before, after, label)
	local first = findPlain(source, before)
	assert(first, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before another close-garage patch.")
	local second = findPlain(source, before, first + #before)
	assert(not second, "Source anchor for " .. label .. " appears more than once. Refresh the Studio mirror before another close-garage patch.")
	return string.sub(source, 1, first - 1) .. after .. string.sub(source, first + #before)
end

local bootstrap = StarterPlayer
	:WaitForChild("StarterPlayerScripts")
	:WaitForChild("NeoTokyoRacersClient")
	:WaitForChild("NeoTokyoRacersClient_Bootstrap_Shadow_Disabled")

assert(bootstrap:IsA("LocalScript"), "Expected active client bootstrap to be a LocalScript.")

local source = bootstrap.Source
assert(findPlain(source, 'callServer("SpawnVehicle"'), "Expected Start Driving SpawnVehicle call in active client bootstrap.")
assert(findPlain(source, "local function closeGarage()"), "Expected closeGarage function in active client bootstrap.")

local changedCloseGarage = false
if not findPlain(source, "NTR_PERSISTENCE_PHASE17_CLOSE_GARAGE_DRIVE_HANDOFF_REPAIR") then
	local safeCloseGarage = [=[
-- NTR_PERSISTENCE_PHASE17_CLOSE_GARAGE_DRIVE_HANDOFF_REPAIR
local function closeGarage()
	State.GarageCameraActive = false
	if Preview and Preview.Root then
		Preview.Root:Destroy()
		Preview.Root = nil
		Preview.Vehicle = nil
	end
	if UI and UI.Gui then
		UI.Gui.Enabled = false
	end
	if typeof(disconnectPickerInputs) == "function" then
		local ok, err = pcall(disconnectPickerInputs)
		if not ok then
			warn("[NTR Phase 17] closeGarage picker cleanup warning: " .. tostring(err))
		end
	end
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		local vehicle = typeof(getPlayerVehicle) == "function" and getPlayerVehicle() or nil
		local seat = vehicle and vehicle:FindFirstChild("DriverSeat", true)
		local humanoid = typeof(getHumanoid) == "function" and getHumanoid() or nil
		if seat and seat:IsA("VehicleSeat") then
			camera.CameraSubject = seat
		elseif humanoid then
			camera.CameraSubject = humanoid
		end
	end
end


]=]
	source = replaceRange(source, "local function closeGarage()", "local function handleDriftAction", safeCloseGarage, "safe closeGarage replacement")
	changedCloseGarage = true
end

local changedDriveHandoff = false
local oldHandoff = [=[
			if result.Success then
				closeGarage()
				task.defer(startDriving)
			else
]=]

local newHandoff = [=[
			if result.Success then
				local closeOk, closeErr = pcall(closeGarage)
				if not closeOk then
					warn("[NTR Phase 17] closeGarage failed after SpawnVehicle, starting driving anyway: " .. tostring(closeErr))
				end
				task.defer(startDriving)
			else
]=]

if findPlain(source, oldHandoff) then
	source = replaceOnce(source, oldHandoff, newHandoff, "Start Driving closeGarage handoff")
	changedDriveHandoff = true
elseif findPlain(source, "closeGarage failed after SpawnVehicle, starting driving anyway") then
	info("Start Driving handoff is already guarded.")
else
	error("Could not find the Start Driving handoff block. Refresh the Studio mirror before another close-garage patch.")
end

bootstrap.Source = source
bootstrap:SetAttribute("PersistencePhase17CloseGarageDriveHandoffRepair", true)

assert(findPlain(bootstrap.Source, "NTR_PERSISTENCE_PHASE17_CLOSE_GARAGE_DRIVE_HANDOFF_REPAIR"), "Safe closeGarage marker missing after patch.")
assert(findPlain(bootstrap.Source, "closeGarage failed after SpawnVehicle, starting driving anyway"), "Guarded Start Driving handoff missing after patch.")

if changedCloseGarage then
	info("PASS: closeGarage now tolerates missing optional cleanup helpers.")
else
	info("PASS: closeGarage was already repaired.")
end
if changedDriveHandoff then
	info("PASS: Start Driving handoff now continues to startDriving even if UI cleanup warns.")
else
	info("PASS: Start Driving handoff was already guarded.")
end
info("Next: restart Play, complete customisation, press Start Driving, and confirm the vehicle hovers/drives.")
