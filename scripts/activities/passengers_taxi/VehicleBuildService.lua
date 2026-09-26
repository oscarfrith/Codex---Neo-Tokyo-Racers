-- Canonical feature implementation; startup is owned by the composition root.
-- GarageServer vehicle paint, welding, driver seat and vehicle build/seat. Extracted verbatim from the GarageServer controller closure
-- (architecture P6); dependencies arrive through ctx and the same locals are returned in order.
return function(ctx)
	local cosmeticCatalog = ctx.cosmeticCatalog
	local findCockpit = ctx.findCockpit
	local findModule = ctx.findModule
	local garageServer_spawnCFrame = ctx.garageServer_spawnCFrame
	local moduleTypeForModel = ctx.moduleTypeForModel
	local moduleUpgrades = ctx.moduleUpgrades
	local normalizeProfile = ctx.normalizeProfile
	local totalStats = ctx.totalStats
	local vehiclesRoot = ctx.vehiclesRoot
	local function resolvePaintChannel(object)
		local current = object
		while current do
			if current.Name == "PRIMARY_ReplaceWithPrimaryMeshes" then return "Primary" end
			if current.Name == "SECONDARY_ReplaceWithSecondaryMeshes" then return "Secondary" end
			if current.Name == "DETAIL_ReplaceWithDetailMeshes" then return "Detail" end
			if current.Name == "NEON_OptionalLights" then return "Neon" end
			if current.Name == "THRUST_COLOR_WhiteByDefault" then return "ThrustColor" end
			current = current.Parent
		end
		current = object
		while current do
			local attr = current:GetAttribute("PaintChannel")
			if typeof(attr) == "string" and attr ~= "" then return attr end
			current = current.Parent
		end
	end

	local function pathHas(object, text)
		text = string.lower(text)
		local current = object
		while current do
			if string.find(string.lower(current.Name), text, 1, true) then return true end
			current = current.Parent
		end
		return false
	end

	local function applyColors(model, colors, neonVisible)
		colors = colors or {}
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
				local lower = string.lower(object.Name)
				if string.find(lower, "fire", 1, true) then
					object.Color = ColorSequence.new(colors.ThrustColor or Color3.fromRGB(255, 255, 255))
				end
			elseif object:IsA("SpotLight") then
				local channel = object:GetAttribute("LightChannel")
				if object:GetAttribute("CockpitLightSystem") == "PhaseAE_RootOnly" then
					if channel == "FrontLights" then
						object.Color = colors.FrontLights or Color3.fromRGB(252, 250, 255)
					elseif channel == "RearLights" then
						object.Color = colors.RearLights or Color3.fromRGB(255, 116, 116)
					end
					object.Enabled = true
					object.Shadows = false
				end
			elseif object:IsA("SpotLight") then
				local channel = object:GetAttribute("LightChannel")
				if object:GetAttribute("RootCockpitSpotLight") == true or channel == "FrontLights" or channel == "RearLights" then
					if channel == "FrontLights" then
						object.Color = colors.FrontLights or Color3.fromRGB(252, 250, 255)
					elseif channel == "RearLights" then
						object.Color = colors.RearLights or Color3.fromRGB(255, 116, 116)
					end
					object.Shadows = false
				end
			end
		end
	end

	local function clearPlayerVehicle(player)
		for _, vehicle in ipairs(vehiclesRoot:GetChildren()) do
			if vehicle:GetAttribute("OwnerUserId") == player.UserId then vehicle:Destroy() end
		end
	end

	local function getSlotMount(vehicle, slotId)
		local slotRoot = vehicle and vehicle:FindFirstChild("ModuleSlots", true)
		local slot = slotRoot and slotRoot:FindFirstChild("SLOT_" .. tostring(slotId), true)
		return slot and slot:FindFirstChild("Mount_DoNotRename")
	end

	local function pivotModuleToSlot(moduleClone, mount)
		local root = moduleClone.PrimaryPart or moduleClone:FindFirstChild("ModuleRoot_DoNotRename", true)
		if root then moduleClone.PrimaryPart = root end
		local moduleAttachment = moduleClone:FindFirstChild("MountAttachment", true)
		local mountAttachment = mount and mount:FindFirstChild("MountAttachment")
		if moduleAttachment and mountAttachment then
			moduleClone:PivotTo(mountAttachment.WorldCFrame * moduleAttachment.CFrame:Inverse())
		elseif mount then
			moduleClone:PivotTo(mount.CFrame)
		end
	end

	local function partAlreadyRootWelded(part, root)
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("WeldConstraint") then
				local part0 = child.Part0
				local part1 = child.Part1
				if (part0 == root and part1 == part) or (part0 == part and part1 == root) then
					return true
				end
			end
		end
		return false
	end

	local function weldVehicle(model, root)
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				-- Skip cockpit spotlight lens parts: they already have PhaseAB_CockpitLightLensRootWeld
				-- and a second V56_FixedVehicleWeld would cause duplicate-constraint jitter.
				if descendant:GetAttribute("TemplateRole") == "CockpitSpotLightLens" then
					descendant.Anchored = false
					descendant.CanCollide = false
					descendant.CanQuery = false
					descendant.Massless = true
					continue
				end
				descendant.Anchored = false
				descendant.CanCollide = descendant == root
				descendant.CanQuery = false
				if descendant ~= root then
					descendant.Massless = true
					if not partAlreadyRootWelded(descendant, root) then
						local weld = Instance.new("WeldConstraint")
						weld.Name = "V56_FixedVehicleWeld"
						weld.Part0 = root
						weld.Part1 = descendant
						weld.Parent = descendant
					end
				end
			end
		end
	end

	local function makeDriverSeat(vehicle, root)
		local seat = vehicle:FindFirstChild("DriverSeat", true)
		if seat and seat:IsA("VehicleSeat") then
			seat.Transparency = 1
			seat.CanCollide = false
			seat.CanQuery = false
			seat.CanTouch = false
			seat.Massless = true
			return seat
		end
		seat = Instance.new("VehicleSeat")
		seat.Name = "DriverSeat"
		seat.Size = Vector3.new(2.2, 0.45, 2.2)
		seat.Transparency = 1
		seat.CanCollide = false
		seat.CanQuery = false
		seat.CanTouch = false
		seat.Massless = true
		seat.Anchored = false
		seat.CFrame = root.CFrame * CFrame.new(0, 2.2, 8)
		seat.Parent = vehicle
		local weld = Instance.new("WeldConstraint")
		weld.Name = "DriverSeatWeld"
		weld.Part0 = root
		weld.Part1 = seat
		weld.Parent = seat
		return seat
	end

	-- Street Life (Passengers): one plain Seat named "PassengerSeat" per vehicle. It must stay a Seat,
	-- never a VehicleSeat, because driving clients key on SeatPart:IsA("VehicleSeat") + ownership.
	-- Offset comes from ReplicatedStorage.Config.Activities.Passengers SeatOffsetX/Y/Z (default 0, 1.45, 11).
	-- PassengerService owns who may sit in it; CanTouch=false so nobody sits by walking into it.
	local function addPassengerSeat(vehicle, root)
		local config = game:GetService("ReplicatedStorage"):FindFirstChild("Config")
		config = config and config:FindFirstChild("Activities")
		config = config and config:FindFirstChild("Passengers")
		local function offset(key, fallback)
			local value = tonumber(config and config:GetAttribute(key))
			if value == nil or value ~= value then return fallback end
			return math.clamp(value, -40, 40)
		end
		local seat = vehicle:FindFirstChild("PassengerSeat", true)
		if seat and not (seat:IsA("Seat") and not seat:IsA("VehicleSeat")) then
			seat:Destroy()
			seat = nil
		end
		if not seat then
			seat = Instance.new("Seat")
			seat.Name = "PassengerSeat"
			seat.Size = Vector3.new(2.2, 0.45, 2.2)
		end
		seat.Transparency = 1
		seat.CanCollide = false
		seat.CanQuery = false
		seat.CanTouch = false
		seat.Massless = true
		seat.Anchored = false
		seat.CFrame = root.CFrame * CFrame.new(offset("SeatOffsetX", 0), offset("SeatOffsetY", 1.45), offset("SeatOffsetZ", 11))
		seat.Parent = vehicle
		if not seat:FindFirstChild("PassengerSeatWeld") then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "PassengerSeatWeld"
			weld.Part0 = root
			weld.Part1 = seat
			weld.Parent = seat
		end
		return seat
	end

	local function seatPlayer(player, vehicle, seat)
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		if root then pcall(function() root:SetNetworkOwner(player) end) end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
		if humanoidRoot and seat then humanoidRoot.CFrame = seat.CFrame + Vector3.new(0, 2, 0) end
		if humanoid and seat then
			task.wait(0.08)
			seat:Sit(humanoid)
		end
	end

	local function folderHasBuyableNeon(folder)
		if not folder then return false end
		for _, descendant in ipairs(folder:GetDescendants()) do
			if descendant:IsA("BasePart") or descendant:IsA("ParticleEmitter") or descendant:IsA("Beam") or descendant:IsA("Trail") or descendant:IsA("PointLight") or descendant:IsA("SpotLight") or descendant:IsA("SurfaceLight") then return true end
		end
		return false
	end

	local function buildVehicle(player, profile, spawnCFrameOverride)
		normalizeProfile(profile)
		local cockpit = findCockpit(profile.CurrentCategory, profile.CurrentCockpit)
		if not cockpit then return nil, "Cockpit template not found." end
		clearPlayerVehicle(player)
		local vehicle = cockpit:Clone()
		vehicle.Name = player.Name .. "_FixedSlotHovercar"
		vehicle:SetAttribute("OwnerUserId", player.UserId)
		vehicle:SetAttribute("OwnedVehicleId", tostring(profile.CurrentVehicleId or "")) 
		vehicle:SetAttribute("CategoryId", profile.CurrentCategory)
		vehicle:SetAttribute("CockpitId", profile.CurrentCockpit)
		vehicle:SetAttribute("ThrustColor", profile.ThrustColor)
		vehicle:SetAttribute("HoverHeight", math.clamp(require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Vehicles"):WaitForChild("DriveTuning")).Read().HoverHeightStuds, 0.5, 8)) 
		vehicle:SetAttribute("DriveReady", true)
		vehicle:SetAttribute("DriverUserId", player.UserId)
		vehicle.Parent = vehiclesRoot
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		if not root then vehicle:Destroy(); return nil, "CockpitRoot_DoNotRename missing." end
		vehicle.PrimaryPart = root
		applyColors(vehicle, profile.CockpitColors, true)
		local cosmeticVehicle=profile.CurrentVehicleId and profile.Vehicles and profile.Vehicles[profile.CurrentVehicleId]
		cosmeticCatalog.ApplyPresentation(vehicle,cosmeticVehicle)

		local installedRoot = vehicle:FindFirstChild("INSTALLED_MODULES_Runtime") or Instance.new("Folder")
		installedRoot.Name = "INSTALLED_MODULES_Runtime"
		installedRoot.Parent = vehicle
		installedRoot:ClearAllChildren()

		for slotId, moduleId in pairs(profile.InstalledModules or {}) do
			local moduleTemplate = findModule(profile.CurrentCategory, moduleId)
			local mount = getSlotMount(vehicle, slotId)
			if moduleTemplate and mount then
				local moduleClone = moduleTemplate:Clone()
				moduleClone.Name = "INSTALLED_" .. tostring(slotId) .. "_" .. moduleTemplate.Name
				moduleClone:SetAttribute("InstalledSlotId", slotId)
				moduleUpgrades.ApplyToClone(player, moduleTemplate, moduleClone, moduleTypeForModel)
				moduleClone.Parent = installedRoot
				pivotModuleToSlot(moduleClone, mount)
				local moduleColors = profile.ModuleColors[slotId] or {
					Primary = profile.CockpitColors.Primary,
					Secondary = profile.CockpitColors.Secondary,
					Detail = profile.CockpitColors.Detail,
					Neon = Color3.fromRGB(255, 255, 255),
					ThrustColor = profile.ThrustColor,
				}
				moduleColors.ThrustColor = profile.ThrustColor
				applyColors(moduleClone, moduleColors, profile.NeonOwned[slotId] == true)
			end
		end

		local totals = totalStats(profile)
		for stat, value in pairs(totals) do vehicle:SetAttribute(stat, value) end
		local runtime = vehicle:FindFirstChild("TOTAL_STATS_Runtime") or Instance.new("Folder")
		runtime.Name = "TOTAL_STATS_Runtime"
		runtime.Parent = vehicle
		runtime:ClearAllChildren()
		for stat, value in pairs(totals) do
			local v = Instance.new("NumberValue")
			v.Name = stat
			v.Value = value
			v.Parent = runtime
		end

		local seat = makeDriverSeat(vehicle, root)
		addPassengerSeat(vehicle, root) -- Street Life (Passengers)
		weldVehicle(vehicle, root)
		vehicle:PivotTo(spawnCFrameOverride or garageServer_spawnCFrame())
		seatPlayer(player, vehicle, seat)
		return vehicle
	end
	return seatPlayer, folderHasBuyableNeon, buildVehicle
end
