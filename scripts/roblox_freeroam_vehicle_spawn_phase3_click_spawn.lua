-- Neo Tokyo Racers - Free Roam Vehicle Spawn Phase 3
-- Click an owned cockpit card in the free-roam car menu to spawn/swap into it.
--
-- This is a guarded source patch against:
-- - ServerScriptService.NeoTokyoRacers.Services.Garage.GarageActionController_Shadow_Disabled
-- - StarterPlayer.StarterPlayerScripts.NeoTokyoRacersClient.Controllers.UI.FreeRoamNavController_Active
--
-- It expects Free Roam Car Menu Phase 7 and road markers tagged NTR_RoadSpawnPoint.

local PHASE = "NTR Free Roam Vehicle Spawn Phase 3 Click Spawn"
local SERVER_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE3_SERVER"
local CLIENT_MARKER = "NTR_FREEROAM_VEHICLE_SPAWN_PHASE3_CLIENT"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function findPlain(source, needle)
	return string.find(source, needle, 1, true) ~= nil
end

local function escapePattern(text)
	return text:gsub("([^%w])", "%%%1")
end

local function replaceOnce(source, old, new, label)
	local nextSource, count = string.gsub(source, escapePattern(old), new, 1)
	assert(count == 1, "Could not replace " .. label)
	return nextSource
end

local function activeGarageServer()
	local garage = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services"):WaitForChild("Garage")
	local scriptObject = garage:WaitForChild("GarageActionController_Shadow_Disabled")
	assert(scriptObject:IsA("Script"), "GarageActionController_Shadow_Disabled must be a Script.")
	return scriptObject
end

local function activeFreeRoamNav()
	local ui = StarterPlayer:WaitForChild("StarterPlayerScripts")
		:WaitForChild("NeoTokyoRacersClient")
		:WaitForChild("Controllers")
		:WaitForChild("UI")
	local scriptObject = ui:WaitForChild("FreeRoamNavController_Active")
	assert(scriptObject:IsA("LocalScript"), "FreeRoamNavController_Active must be a LocalScript.")
	return scriptObject
end

local function ensureChild(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		assert(existing.ClassName == className, existing:GetFullName() .. " must be a " .. className)
		return existing
	end
	local child = Instance.new(className)
	child.Name = name
	child.Parent = parent
	return child
end

local function setFreeRoamClickAction()
	local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	local configRoot = ensureChild(kit, "Folder", "Config")
	local ui = ensureChild(configRoot, "Folder", "UI")
	local nav = ensureChild(ui, "Folder", "FreeRoamNav")
	local action = ensureChild(nav, "StringValue", "CarPanelClickAction")
	action.Value = "SpawnOwnedVehicle"
	info("Set FreeRoamNav.CarPanelClickAction=SpawnOwnedVehicle.")
end

local function patchServer()
	local scriptObject = activeGarageServer()
	local source = scriptObject.Source
	if findPlain(source, SERVER_MARKER) then
		info("Server Phase 3 marker already present.")
		return
	end

	assert(findPlain(source, 'local Workspace = game:GetService("Workspace")'), "Server source missing Workspace service anchor.")
	assert(findPlain(source, 'local V56_vehiclesRoot = V56_runtime:WaitForChild("PlayerVehicles")'), "Server source missing vehicles root anchor.")
	assert(findPlain(source, 'SpawnVehicle = false,'), "Server source missing mutating action anchor.")
	assert(findPlain(source, 'local function V56_buildVehicle(player, profile)'), "Server source missing V56_buildVehicle signature anchor.")
	assert(findPlain(source, 'vehicle:PivotTo(V56_spawnCFrame())'), "Server source missing build spawn pivot anchor.")
	assert(findPlain(source, 'elseif action == "SpawnVehicle" then'), "Server source missing SpawnVehicle action branch anchor.")

	source = replaceOnce(
		source,
		'local Workspace = game:GetService("Workspace")',
		'local Workspace = game:GetService("Workspace")\n\tlocal CollectionService = game:GetService("CollectionService")',
		"CollectionService service"
	)

	source = replaceOnce(
		source,
		'SpawnVehicle = false,',
		'SpawnVehicle = false,\n\t\tSpawnOwnedVehicleFromFreeRoam = true,',
		"free-roam spawn mutating action"
	)

	source = replaceOnce(
		source,
		'local function V56_buildVehicle(player, profile)',
		'local function V56_buildVehicle(player, profile, spawnCFrameOverride)',
		"V56_buildVehicle optional spawn CFrame signature"
	)

	source = replaceOnce(
		source,
		'vehicle:PivotTo(V56_spawnCFrame())',
		'vehicle:PivotTo(spawnCFrameOverride or V56_spawnCFrame())',
		"V56_buildVehicle optional spawn CFrame pivot"
	)

	local helperBlock = [=[

	-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE3_SERVER
	local V91_lastFreeRoamSpawnByUserId = {}
	local V91_ROAD_SPAWN_TAG = "NTR_RoadSpawnPoint"
	local V91_ROAD_GREY = Vector3.new(95, 95, 95)

	local function V91_spawnConfigRoot()
		local config = V56_kit:FindFirstChild("Config")
		local runtime = config and config:FindFirstChild("Runtime")
		return runtime and runtime:FindFirstChild("FreeRoamVehicleSpawn")
	end

	local function V91_configNumber(name, fallback)
		local root = V91_spawnConfigRoot()
		local item = root and root:FindFirstChild(name)
		if item and item:IsA("NumberValue") then
			return item.Value
		end
		return fallback
	end

	local function V91_configBool(name, fallback)
		local root = V91_spawnConfigRoot()
		local item = root and root:FindFirstChild(name)
		if item and item:IsA("BoolValue") then
			return item.Value
		end
		return fallback
	end

	local function V91_playerVehicle(player)
		for _, candidate in ipairs(V56_vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then
				return candidate
			end
		end
		return nil
	end

	local function V91_rootPart(model)
		if not model then
			return nil
		end
		return model.PrimaryPart or model:FindFirstChild("CockpitRoot_DoNotRename", true)
	end

	local function V91_playerSpeedMph(player)
		local studsToMph = V91_configNumber("StudsPerSecondToMph", 0.625)
		local vehicleRoot = V91_rootPart(V91_playerVehicle(player))
		if vehicleRoot and vehicleRoot:IsA("BasePart") then
			return vehicleRoot.AssemblyLinearVelocity.Magnitude * studsToMph
		end
		local character = player.Character
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRoot and humanoidRoot:IsA("BasePart") then
			return humanoidRoot.AssemblyLinearVelocity.Magnitude * studsToMph
		end
		return 0
	end

	local function V91_requestPosition(player)
		local vehicleRoot = V91_rootPart(V91_playerVehicle(player))
		if vehicleRoot and vehicleRoot:IsA("BasePart") then
			return vehicleRoot.Position
		end
		local character = player.Character
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRoot and humanoidRoot:IsA("BasePart") then
			return humanoidRoot.Position
		end
		return V56_FALLBACK_SPAWN_POS
	end

	local function V91_colorRgb(color)
		return Vector3.new(math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	end

	local function V91_isAllowedRoadPart(part)
		local lower = string.lower(part.Name)
		if lower == "road" then
			local rgb = V91_colorRgb(part.Color)
			return math.abs(rgb.X - V91_ROAD_GREY.X) <= 3
				and math.abs(rgb.Y - V91_ROAD_GREY.Y) <= 3
				and math.abs(rgb.Z - V91_ROAD_GREY.Z) <= 3
		end
		return string.find(lower, "road marking", 1, true) ~= nil
	end

	local function V91_markerEnabled(marker)
		if marker:GetAttribute("SpawnEnabled") == false then
			return false
		end
		if marker:GetAttribute("Disabled") == true then
			return false
		end
		return true
	end

	local function V91_markerSpawnCFrame(marker)
		local heightOffset = V91_configNumber("SpawnHeightOffset", 4)
		local position = marker.Position + Vector3.new(0, heightOffset, 0)
		return CFrame.lookAt(position, position + marker.CFrame.LookVector)
	end

	local function V91_spawnIsClear(player, spawnCFrame)
		local clearanceRadius = V91_configNumber("SpawnClearanceRadius", 16)
		local querySize = Vector3.new(clearanceRadius * 2, 10, clearanceRadius * 2)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excludes = { V56_vehiclesRoot }
		if player.Character then
			table.insert(excludes, player.Character)
		end
		local spawnPoints = V56_world:FindFirstChild("SpawnPoints")
		local roadMarkers = spawnPoints and spawnPoints:FindFirstChild("RoadSpawnMarkers")
		if roadMarkers then
			table.insert(excludes, roadMarkers)
		end
		params.FilterDescendantsInstances = excludes

		local parts = Workspace:GetPartBoundsInBox(spawnCFrame, querySize, params)
		for _, part in ipairs(parts) do
			if part:IsA("BasePart") and part.CanCollide and not V91_isAllowedRoadPart(part) then
				return false, part:GetFullName()
			end
		end
		return true, nil
	end

	local function V91_nearestRoadSpawnCFrame(player)
		local origin = V91_requestPosition(player)
		local radius = V91_configNumber("RoadSearchRadius", 350)
		local markers = {}
		for _, marker in ipairs(CollectionService:GetTagged(V91_ROAD_SPAWN_TAG)) do
			if marker:IsA("BasePart") and marker:IsDescendantOf(Workspace) and V91_markerEnabled(marker) then
				local offset = marker.Position - origin
				local flatDistance = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if flatDistance <= radius then
					table.insert(markers, { Marker = marker, Distance = flatDistance })
				end
			end
		end
		table.sort(markers, function(a, b)
			return a.Distance < b.Distance
		end)
		for _, entry in ipairs(markers) do
			local cf = V91_markerSpawnCFrame(entry.Marker)
			local clear = V91_spawnIsClear(player, cf)
			if clear then
				return cf, entry.Marker
			end
		end
		if V91_configBool("AllowFallbackToPlayerOffset", false) then
			local position = origin + Vector3.new(0, V91_configNumber("SpawnHeightOffset", 4), 0)
			return CFrame.lookAt(position, position + Vector3.new(0, 0, -1)), nil
		end
		return nil, nil
	end

	local function V91_spawnOwnedVehicleFromFreeRoam(player, profile, args)
		args = typeof(args) == "table" and args or {}
		local now = os.clock()
		local cooldown = V91_configNumber("SpawnCooldownSeconds", 1)
		local last = V91_lastFreeRoamSpawnByUserId[player.UserId] or 0
		if now - last < cooldown then
			return false, "Spawn is cooling down."
		end

		local speedMph = V91_playerSpeedMph(player)
		local maxSpeed = V91_configNumber("MaxSpawnSpeedMph", 10)
		if speedMph > maxSpeed then
			return false, "Slow below " .. tostring(math.floor(maxSpeed + 0.5)) .. " MPH to spawn."
		end

		local okSelect, selectMessage = V89_selectVehicleInstance(profile, args)
		if not okSelect then
			return false, selectMessage
		end
		if not V76_coreModulesEquipped(profile) then
			return false, "Equip at least one engine, stabilisers, and boost before driving."
		end

		local spawnCFrame, marker = V91_nearestRoadSpawnCFrame(player)
		if not spawnCFrame then
			return false, "No clear road spawn nearby."
		end

		V91_lastFreeRoamSpawnByUserId[player.UserId] = now
		local vehicle, err = V56_buildVehicle(player, profile, spawnCFrame)
		if not vehicle then
			return false, err or "Vehicle spawn failed."
		end
		if marker then
			vehicle:SetAttribute("FreeRoamSpawnMarker", marker:GetFullName())
		end
		return true, "Vehicle spawned."
	end
]=]

	source = replaceOnce(
		source,
		[=[		local seat = V56_makeDriverSeat(vehicle, root)
		V56_weldVehicle(vehicle, root)
		vehicle:PivotTo(spawnCFrameOverride or V56_spawnCFrame())
		V56_seatPlayer(player, vehicle, seat)
		return vehicle
	end

	local function V56_exitVehicle(player)
]=],
		[=[		local seat = V56_makeDriverSeat(vehicle, root)
		V56_weldVehicle(vehicle, root)
		vehicle:PivotTo(spawnCFrameOverride or V56_spawnCFrame())
		V56_seatPlayer(player, vehicle, seat)
		return vehicle
	end
]=] .. helperBlock .. [=[

	local function V56_exitVehicle(player)
]=],
		"free-roam spawn helper block"
	)

	local oldBranch = [=[			elseif action == "SpawnVehicle" then
				if not V76_coreModulesEquipped(profile) then
					ok, message = false, "Equip at least one engine, stabilisers, and boost before customising or driving."
				else
					local vehicle, err = V56_buildVehicle(player, profile)
					ok, message = vehicle ~= nil, err or "Vehicle spawned."
				end
]=]
	local newBranch = [=[			elseif action == "SpawnOwnedVehicleFromFreeRoam" then
				ok, message = V91_spawnOwnedVehicleFromFreeRoam(player, profile, args)
			elseif action == "SpawnVehicle" then
				if not V76_coreModulesEquipped(profile) then
					ok, message = false, "Equip at least one engine, stabilisers, and boost before customising or driving."
				else
					local vehicle, err = V56_buildVehicle(player, profile)
					ok, message = vehicle ~= nil, err or "Vehicle spawned."
				end
]=]
	source = replaceOnce(source, oldBranch, newBranch, "free-roam spawn action branch")

	scriptObject.Source = source
	assert(findPlain(scriptObject.Source, SERVER_MARKER), "Server Phase 3 marker missing after patch.")
	info("Patched garage server with SpawnOwnedVehicleFromFreeRoam.")
end

local function patchClient()
	local scriptObject = activeFreeRoamNav()
	local source = scriptObject.Source
	if findPlain(source, CLIENT_MARKER) then
		info("Client Phase 3 marker already present.")
		return
	end

	assert(findPlain(source, "NTR_FREEROAM_CAR_MENU_PHASE7_BORDERLESS_CARD_FRAMES_COMPACT_WIDTH"), "FreeRoamNav Phase 7 marker is missing.")
	assert(findPlain(source, 'setStatus(row.Selected and "CURRENT VEHICLE" or "SPAWN / SELECT COMING NEXT", row.Selected)'), "Client source missing preview-only click status anchor.")

	local helper = [=[

-- NTR_FREEROAM_VEHICLE_SPAWN_PHASE3_CLIENT
local function spawnOwnedVehicleFromCard(row)
	if not row or not row.VehicleId then
		setStatus("VEHICLE CARD MISSING ID", false)
		return
	end
	setStatus("SPAWNING VEHICLE...", true)
	local result = callGarage("SpawnOwnedVehicleFromFreeRoam", {
		VehicleId = tostring(row.VehicleId or ""),
		CockpitId = tostring(row.CockpitId or ""),
	})
	if result.Success == true then
		cachedProfile = result.Profile or cachedProfile
		lastProfileRead = os.clock()
		setStatus("VEHICLE SPAWNED", true)
	else
		setStatus(tostring(result.Message or "SPAWN FAILED"), false)
	end
end
]=]

	source = replaceOnce(
		source,
		'\nlocal function carPanelRenderCockpitCard(parent, row, width)',
		helper .. '\nlocal function carPanelRenderCockpitCard(parent, row, width)',
		"client spawn helper"
	)

	local oldClick = [=[	card.MouseButton1Click:Connect(function()
		local action = readString(config, "CarPanelClickAction", "PreviewOnly")
		if action == "PreviewOnly" then
			setStatus(row.Selected and "CURRENT VEHICLE" or "SPAWN / SELECT COMING NEXT", row.Selected)
		else
			setStatus("READY FOR " .. string.upper(action), true)
		end
	end)
]=]
	local newClick = [=[	card.MouseButton1Click:Connect(function()
		local action = readString(config, "CarPanelClickAction", "SpawnOwnedVehicle")
		if action == "PreviewOnly" then
			setStatus(row.Selected and "CURRENT VEHICLE" or "SPAWN / SELECT COMING NEXT", row.Selected)
		else
			spawnOwnedVehicleFromCard(row)
		end
	end)
]=]
	source = replaceOnce(source, oldClick, newClick, "client card click handler")
	scriptObject.Source = source
	assert(findPlain(scriptObject.Source, CLIENT_MARKER), "Client Phase 3 marker missing after patch.")
	info("Patched free-roam client cockpit cards to spawn owned vehicles.")
end

patchServer()
patchClient()
setFreeRoamClickAction()
info("Phase 3 install complete. Test in Play mode from the free-roam Car menu.")
