-- Canonical feature implementation; startup is owned by the composition root.
-- GarageServer free-roam road spawn and race vehicle spawn, including the RaceVehicleSpawner bridge. Extracted verbatim from the GarageServer controller closure
-- (architecture P6); dependencies arrive through ctx and the same locals are returned in order.
return function(ctx)
	local CollectionService = ctx.CollectionService
	local FALLBACK_SPAWN_POS = ctx.FALLBACK_SPAWN_POS
	local Players = ctx.Players
	local Workspace = ctx.Workspace
	local buildVehicle = ctx.buildVehicle
	local coreModulesEquipped = ctx.coreModulesEquipped
	local getProfile = ctx.getProfile
	local mirrorLegacyProfileToPersistence = ctx.mirrorLegacyProfileToPersistence
	local selectVehicleInstance = ctx.selectVehicleInstance
	local vehiclesRoot = ctx.vehiclesRoot
	local lastFreeRoamSpawnByUserId = {}
	local ROAD_SPAWN_TAG = "RoadSpawnPoint"
	local ROAD_GREY = Vector3.new(95, 95, 95)

	local function spawnConfigRoot()
		local config = game:GetService("ReplicatedStorage"):FindFirstChild("Config")
		local runtime = config and game:GetService("ReplicatedStorage"):FindFirstChild("Config")
		return runtime and runtime:FindFirstChild("FreeRoamVehicleSpawn")
	end

	local function configNumber(name, fallback)
		local root = spawnConfigRoot()
		local item = root and root:FindFirstChild(name)
		if item and item:IsA("NumberValue") then
			return item.Value
		end
		return fallback
	end

	local function configBool(name, fallback)
		local root = spawnConfigRoot()
		local item = root and root:FindFirstChild(name)
		if item and item:IsA("BoolValue") then
			return item.Value
		end
		return fallback
	end

	local function playerVehicle(player)
		for _, candidate in ipairs(vehiclesRoot:GetChildren()) do
			if candidate:GetAttribute("OwnerUserId") == player.UserId then
				return candidate
			end
		end
		return nil
	end

	local function rootPart(model)
		if not model then
			return nil
		end
		return model.PrimaryPart or model:FindFirstChild("CockpitRoot_DoNotRename", true)
	end

	local function playerSpeedMph(player)
		local studsToMph = configNumber("StudsPerSecondToMph", 0.625)
		local vehicleRoot = rootPart(playerVehicle(player))
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
	local function playerIsDrivingOwnedVehicle(player)
		local vehicle = playerVehicle(player)
		if not vehicle then return false end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		return seat ~= nil and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle)
	end
	local function requestPosition(player)
		if playerIsDrivingOwnedVehicle(player) then
			local vehicleRoot = rootPart(playerVehicle(player))
			if vehicleRoot and vehicleRoot:IsA("BasePart") then
				return vehicleRoot.Position
			end
		end
		local character = player.Character
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRoot and humanoidRoot:IsA("BasePart") then
			return humanoidRoot.Position
		end
		return FALLBACK_SPAWN_POS
	end

	local function colorRgb(color)
		return Vector3.new(math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	end

	local function isAllowedRoadPart(part)
		local lower = string.lower(part.Name)
		if lower == "road" then
			local rgb = colorRgb(part.Color)
			return math.abs(rgb.X - ROAD_GREY.X) <= 3
				and math.abs(rgb.Y - ROAD_GREY.Y) <= 3
				and math.abs(rgb.Z - ROAD_GREY.Z) <= 3
		end
		return string.find(lower, "road marking", 1, true) ~= nil
	end

	local function markerEnabled(marker)
		if marker:GetAttribute("SpawnEnabled") == false then
			return false
		end
		if marker:GetAttribute("Disabled") == true then
			return false
		end
		return true
	end

	local function markerSpawnCFrame(marker)
		local heightOffset = configNumber("SpawnHeightOffset", 4)
		local position = marker.Position + Vector3.new(0, heightOffset, 0)
		return CFrame.lookAt(position, position + marker.CFrame.LookVector)
	end

	local function spawnIsClear(player, spawnCFrame)
		local clearanceRadius = configNumber("SpawnClearanceRadius", 16)
		local querySize = Vector3.new(clearanceRadius * 2, 10, clearanceRadius * 2)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local excludes = { vehiclesRoot }
		if player.Character then
			table.insert(excludes, player.Character)
		end
		local spawnPoints = game:GetService("Workspace"):WaitForChild("World"):FindFirstChild("SpawnPoints")
		local roadMarkers = spawnPoints and game:GetService("Workspace"):WaitForChild("World"):WaitForChild("SpawnPoints"):FindFirstChild("RoadSpawnMarkers")
		if roadMarkers then
			table.insert(excludes, roadMarkers)
		end
		params.FilterDescendantsInstances = excludes

		local parts = Workspace:GetPartBoundsInBox(spawnCFrame, querySize, params)
		for _, part in ipairs(parts) do
			if part:IsA("BasePart") and part.CanCollide and not isAllowedRoadPart(part) then
				return false, part:GetFullName()
			end
		end
		return true, nil
	end

	local function nearestRoadSpawnCFrame(player)
		local origin = requestPosition(player)
		local radius = configNumber("RoadSearchRadius", 350)
		local markers = {}
		for _, marker in ipairs(CollectionService:GetTagged(ROAD_SPAWN_TAG)) do
			if marker:IsA("BasePart") and marker:IsDescendantOf(Workspace) and markerEnabled(marker) then
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
			local cf = markerSpawnCFrame(entry.Marker)
			local clear = spawnIsClear(player, cf)
			if clear then
				return cf, entry.Marker
			end
		end
		if configBool("AllowFallbackToPlayerOffset", false) then
			local position = origin + Vector3.new(0, configNumber("SpawnHeightOffset", 4), 0)
			return CFrame.lookAt(position, position + Vector3.new(0, 0, -1)), nil
		end
		return nil, nil
	end

	local function spawnOwnedVehicleFromFreeRoam(player, profile, args)
		args = typeof(args) == "table" and args or {}
		local now = os.clock()
		local cooldown = configNumber("SpawnCooldownSeconds", 1)
		local last = lastFreeRoamSpawnByUserId[player.UserId] or 0
		if now - last < cooldown then
			return false, "Spawn is cooling down."
		end

		local maxSpeed = configNumber("MaxSpawnSpeedMph", 10)
		if playerIsDrivingOwnedVehicle(player) then
			local speedMph = playerSpeedMph(player)
			if speedMph > maxSpeed then
				return false, "Slow below " .. tostring(math.floor(maxSpeed + 0.5)) .. " MPH to spawn."
			end
		end

		local okSelect, selectMessage = selectVehicleInstance(profile, args)
		if not okSelect then
			return false, selectMessage
		end
		if not coreModulesEquipped(profile) then
			return false, "Equip at least one engine, stabilisers, and boost before driving."
		end

		local spawnCFrame, marker = nearestRoadSpawnCFrame(player)
		if not spawnCFrame then
			return false, "No clear road spawn nearby."
		end

		lastFreeRoamSpawnByUserId[player.UserId] = now
		local vehicle, err = buildVehicle(player, profile, spawnCFrame)
		if not vehicle then
			return false, err or "Vehicle spawn failed."
		end
		if marker then
			vehicle:SetAttribute("FreeRoamSpawnMarker", marker:GetFullName())
		end
		return true, "Vehicle spawned."
	end
	local function selectedRaceVehicleReady(profile, args)
		args = typeof(args) == "table" and args or {}
		local okSelect, selectMessage = selectVehicleInstance(profile, {
			VehicleId = args.VehicleId,
			CockpitId = args.CockpitId,
		})
		if not okSelect then
			return false, selectMessage
		end
		if not coreModulesEquipped(profile) then
			return false, "Equip at least one engine, stabilisers, and boost before racing."
		end
		return true, "Vehicle ready."
	end

	local function spawnOwnedVehicleForRace(player, profile, args)
		args = typeof(args) == "table" and args or {}
		local spawnCFrame = args.SpawnCFrame
		if typeof(spawnCFrame) ~= "CFrame" then
			return { Ok = false, Success = false, Message = "Race spawn CFrame missing." }
		end
		local okReady, readyMessage = selectedRaceVehicleReady(profile, args)
		if not okReady then
			return { Ok = false, Success = false, Message = readyMessage }
		end
		local vehicle, err = buildVehicle(player, profile, spawnCFrame)
		if not vehicle then
			return { Ok = false, Success = false, Message = err or "Race vehicle spawn failed." }
		end
		vehicle:SetAttribute("RaceGridSpawned", true)
		vehicle:SetAttribute("DriveReady", false)
		return {
			Ok = true,
			Success = true,
			Message = "Race vehicle spawned.",
			Vehicle = vehicle,
			VehicleId = tostring(profile.CurrentVehicleId or ""),
		}
	end

	local function ensureRaceVehicleSpawnBinding()
		local binding = game:GetService("ServerStorage"):WaitForChild("Runtime"):WaitForChild("Garage"):FindFirstChild("RaceVehicleSpawner")
		if binding and not binding:IsA("BindableFunction") then
			binding:Destroy()
			binding = nil
		end
		if not binding then
			binding = Instance.new("BindableFunction")
			binding.Name = "RaceVehicleSpawner"
			binding.Parent = game:GetService("ServerStorage").Runtime.Garage
		end
		binding.OnInvoke = function(action, payload)
			payload = typeof(payload) == "table" and payload or {}
			local player = payload.Player
			if not (player and player:IsA("Player")) then
				return { Ok = false, Success = false, Message = "Player missing." }
			end
			local profile = getProfile(player)
			if action == "ValidateForRace" then
				local okReady, readyMessage = selectedRaceVehicleReady(profile, payload)
				if okReady then
					mirrorLegacyProfileToPersistence(player, profile, "SelectVehicleInstance", false)
				end
				return {
					Ok = okReady == true,
					Success = okReady == true,
					Message = readyMessage,
					VehicleId = tostring(profile.CurrentVehicleId or ""),
				}
			elseif action == "SpawnForRace" then
				local result = spawnOwnedVehicleForRace(player, profile, payload)
				if result.Ok == true then
					mirrorLegacyProfileToPersistence(player, profile, "SpawnRaceVehicle", false)
				end
				return result
			end
			return { Ok = false, Success = false, Message = "Unknown race vehicle action." }
		end
	end
	ensureRaceVehicleSpawnBinding()
	-- Release the per-player free-roam spawn cooldown when the player leaves (architecture P6).
	Players.PlayerRemoving:Connect(function(player) lastFreeRoamSpawnByUserId[player.UserId] = nil end)
	return rootPart, playerSpeedMph, spawnOwnedVehicleFromFreeRoam
end
