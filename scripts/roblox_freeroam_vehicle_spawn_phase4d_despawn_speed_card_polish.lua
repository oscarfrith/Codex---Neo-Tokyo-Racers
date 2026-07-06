-- Neo Tokyo Racers - Free Roam Vehicle Spawn Phase 4D
-- Repairs parked despawn teleporting, limits the 10 MPH spawn gate to active
-- driving only, and tightens/restyles free-roam car cards.
--
-- Run in Roblox Studio Command Bar while the place is open.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local SERVER_DESPAWN_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4D_DESPAWN_ONLY_MOVE_IF_SEATED"
local SERVER_SPEED_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4D_SPEED_GATE_DRIVING_ONLY"
local CLIENT_UI_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4D_COMPACT_BORDERLESS_CARDS"

local function info(message)
	print("[NTR Free Roam Vehicle Spawn Phase 4D] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function replaceOnce(source, oldText, newText, label)
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	assert(startIndex, "Could not find source anchor for " .. label .. ". Refresh the Studio mirror before creating another patch.")
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
end

local function activeGarageServer()
	return ServerScriptService
		:WaitForChild("NeoTokyoRacers")
		:WaitForChild("Services")
		:WaitForChild("Garage")
		:WaitForChild("GarageActionController_Shadow_Disabled")
end

local function activeFreeRoamNav()
	return StarterPlayer
		:WaitForChild("StarterPlayerScripts")
		:WaitForChild("NeoTokyoRacersClient")
		:WaitForChild("Controllers")
		:WaitForChild("UI")
		:WaitForChild("FreeRoamNavController_Active")
end

local function ensureNumberValue(parent, name, value)
	local item = parent:FindFirstChild(name)
	if not item then
		item = Instance.new("NumberValue")
		item.Name = name
		item.Parent = parent
	end
	if item:IsA("NumberValue") then
		item.Value = value
	end
end

local function freeRoamConfig()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	return kit:WaitForChild("Config"):WaitForChild("UI"):WaitForChild("FreeRoamNav")
end

local function patchServerDespawn()
	local scriptObject = activeGarageServer()
	local source = scriptObject.Source
	if findPlain(source, SERVER_DESPAWN_MARKER) then
		info("Server parked despawn repair already present.")
		return
	end
	assert(findPlain(source, "NTR_FREEROAM_VEHICLE_SPAWN_PHASE4_SERVER"), "Phase 4 server block missing. Run Phase 4 before Phase 4D.")

	local helper = [=[

	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4D_DESPAWN_ONLY_MOVE_IF_SEATED
	local function V94_playerIsSeatedInVehicle(player, vehicle)
		if not vehicle then return false end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		return seat ~= nil and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)
	end
]=]

	source = replaceOnce(
		source,
		[=[
	local function V92_despawnVehicle(player)
]=],
		helper .. [=[
	local function V92_despawnVehicle(player)
]=],
		"despawn seated-state helper"
	)

	source = replaceOnce(
		source,
		[=[		V92_unseatAndMovePlayer(player, vehicle)
		vehicle:Destroy()
]=],
		[=[		if V94_playerIsSeatedInVehicle(player, vehicle) then
			V92_unseatAndMovePlayer(player, vehicle)
		else
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.SeatPart and humanoid.SeatPart:IsDescendantOf(vehicle) then
				humanoid.Sit = false
			end
		end
		vehicle:Destroy()
]=],
		"despawn without teleport when already exited"
	)

	scriptObject.Source = source
	info("Patched despawn to leave already-exited players in place.")
end

local function patchServerSpeedGate()
	local scriptObject = activeGarageServer()
	local source = scriptObject.Source
	if findPlain(source, SERVER_SPEED_MARKER) then
		info("Server driving-only speed gate already present.")
		return
	end
	assert(findPlain(source, "NTR_FREEROAM_VEHICLE_SPAWN_PHASE3_SERVER"), "Phase 3 server spawn block missing. Run Phase 3 before Phase 4D.")

	local helper = [=[

	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4D_SPEED_GATE_DRIVING_ONLY
	local function V94_playerIsDrivingOwnedVehicle(player)
		local vehicle = V91_playerVehicle(player)
		if not vehicle then return false end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		return seat ~= nil and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)
	end
]=]

	source = replaceOnce(
		source,
		[=[
	local function V91_requestPosition(player)
]=],
		helper .. [=[
	local function V91_requestPosition(player)
]=],
		"driving-only speed helper"
	)

	source = replaceOnce(
		source,
		[=[		local speedMph = V91_playerSpeedMph(player)
		local maxSpeed = V91_configNumber("MaxSpawnSpeedMph", 10)
		if speedMph > maxSpeed then
			return false, "Slow below " .. tostring(math.floor(maxSpeed + 0.5)) .. " MPH to spawn."
		end
]=],
		[=[		local maxSpeed = V91_configNumber("MaxSpawnSpeedMph", 10)
		if V94_playerIsDrivingOwnedVehicle(player) then
			local speedMph = V91_playerSpeedMph(player)
			if speedMph > maxSpeed then
				return false, "Slow below " .. tostring(math.floor(maxSpeed + 0.5)) .. " MPH to spawn."
			end
		end
]=],
		"10 MPH gate only while driving"
	)

	source = replaceOnce(
		source,
		[=[	local function V91_requestPosition(player)
		local vehicleRoot = V91_rootPart(V91_playerVehicle(player))
		if vehicleRoot and vehicleRoot:IsA("BasePart") then
			return vehicleRoot.Position
		end
		local character = player.Character
]=],
		[=[	local function V91_requestPosition(player)
		if V94_playerIsDrivingOwnedVehicle(player) then
			local vehicleRoot = V91_rootPart(V91_playerVehicle(player))
			if vehicleRoot and vehicleRoot:IsA("BasePart") then
				return vehicleRoot.Position
			end
		end
		local character = player.Character
]=],
		"spawn request position uses player when not driving"
	)

	scriptObject.Source = source
	info("Patched spawn speed gate to apply only while driving.")
end

local function patchFreeRoamCards()
	local scriptObject = activeFreeRoamNav()
	local source = scriptObject.Source
	if findPlain(source, CLIENT_UI_MARKER) then
		info("Free-roam compact borderless card polish already present.")
		return
	end
	assert(findPlain(source, "NTR_FREEROAM_CAR_MENU_PHASE7_BORDERLESS_CARD_FRAMES_COMPACT_WIDTH"), "Free-roam car menu Phase 7 marker missing.")

	source = replaceOnce(
		source,
		[=[	local border = math.max(1, math.floor(carPanelNumber("CarPanelBorderThickness", 2) + 0.5))
	local outlineColor = readColor(config, "ButtonOutline", Color3.fromRGB(230, 88, 205))
]=],
		[=[	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE4D_COMPACT_BORDERLESS_CARDS
	local border = 0
	local outlineColor = row.Selected and theme.Selected or theme.Card
]=],
		"card borderless style marker"
	)

	source = replaceOnce(
		source,
		[=[	surfaceBorder.BackgroundColor3 = outlineColor
	surfaceBorder.BackgroundTransparency = row.Selected and 0.08 or 0.18
]=],
		[=[	surfaceBorder.BackgroundColor3 = outlineColor
	surfaceBorder.BackgroundTransparency = row.Selected and 0.02 or theme.ButtonTransparency
]=],
		"card surface border fill"
	)

	source = replaceOnce(
		source,
		[=[	surface.Position = UDim2.fromOffset(border, border)
	surface.Size = UDim2.new(1, -border * 2, 1, -border * 2)
]=],
		[=[	surface.Position = UDim2.fromOffset(0, 0)
	surface.Size = UDim2.fromScale(1, 1)
]=],
		"card fill flush"
	)

	source = replaceOnce(
		source,
		[=[	imageBorder.BackgroundColor3 = outlineColor
	imageBorder.BackgroundTransparency = 0.18
]=],
		[=[	imageBorder.BackgroundColor3 = Color3.fromRGB(18, 27, 31)
	imageBorder.BackgroundTransparency = 0
]=],
		"image box borderless fill"
	)

	source = replaceOnce(
		source,
		[=[	imageBox.Position = UDim2.fromOffset(border, border)
	imageBox.Size = UDim2.new(1, -border * 2, 1, -border * 2)
]=],
		[=[	imageBox.Position = UDim2.fromOffset(0, 0)
	imageBox.Size = UDim2.fromScale(1, 1)
]=],
		"image fill flush"
	)

	source = replaceOnce(
		source,
		[=[		local desiredW = touch and carPanelNumber("CarPanelWidthTouch", 260) or carPanelNumber("CarPanelWidthDesktop", 512)
		local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", 240) or carPanelNumber("CarPanelMinWidthDesktop", 430)
		local maxAvailableW = math.max(minPanelW, viewport.X - rightMargin - stackW - 18)
		panelW = math.floor(math.clamp(desiredW, minPanelW, maxAvailableW))
]=],
		[=[		local columns = touch and carPanelNumber("CarPanelMobileColumns", 2) or carPanelNumber("CarPanelDesktopColumns", 3)
		columns = math.max(1, math.floor(columns + 0.5))
		local pad = carPanelNumber("CarPanelPadding", 8)
		local gap = carPanelNumber("CarPanelCardGap", 8)
		local maxCard = touch and carPanelNumber("CarPanelMaxCardWidthTouch", 118) or carPanelNumber("CarPanelMaxCardWidthDesktop", 146)
		local fittedW = pad * 2 + columns * maxCard + gap * math.max(columns - 1, 0)
		local desiredW = touch and carPanelNumber("CarPanelWidthTouch", fittedW) or fittedW
		local minPanelW = touch and carPanelNumber("CarPanelMinWidthTouch", math.min(240, fittedW)) or fittedW
		local maxAvailableW = math.max(minPanelW, viewport.X - rightMargin - stackW - 18)
		panelW = math.floor(math.clamp(desiredW, minPanelW, maxAvailableW))
]=],
		"compact car panel fitted width"
	)

	scriptObject.Source = source

	local config = freeRoamConfig()
	ensureNumberValue(config, "CarPanelDesktopColumns", 3)
	ensureNumberValue(config, "CarPanelMaxCardWidthDesktop", 146)
	ensureNumberValue(config, "CarPanelWidthDesktop", 470)
	ensureNumberValue(config, "CarPanelMinWidthDesktop", 470)
	info("Patched free-roam car panel width and card/image outline style.")
end

patchServerDespawn()
patchServerSpeedGate()
patchFreeRoamCards()

info("Phase 4D install complete. Restart Play before testing parked despawn, parked respawn, and car-menu sizing.")
