--[[
	Neo Tokyo Racers - Slope Hover Height Compensation
	Paste this whole file into the Roblox Studio Command Bar while NOT play-testing.

	This fixes slope hover height drift in DrivingControllerV47:
	- uphill speed no longer makes the vehicle sink close to the ground
	- downhill speed no longer makes the vehicle float far above the ground
	- terrain slope alignment, turn banking, brake/accel pitch, and wobble can still layer on top

	Root cause:
	The old hover spring damped raw world-Y velocity. When driving uphill, the
	vehicle needs positive Y velocity to follow the slope, but the spring treated
	that as unwanted upward bounce and reduced lift. Downhill did the reverse and
	over-added lift. This patch subtracts the expected vertical velocity from
	moving along the ground plane before damping the hover spring.

	Editable values are created under:
	ReplicatedStorage.NeoTokyoRacers.Config.Runtime.DRIVING_MECHANICS_EditAttributes

	This is a guarded source-text patch against the current corner hover block in
	DrivingControllerV47. If the live source shape has changed, it aborts and
	prints nearby source markers instead of guessing.

	Modes:
	- INSTALL: create/update config attributes and patch the controller
	- AUDIT: print config/source state without changing anything
	- ROLLBACK: remove this patch and restore the previous hover block
]]

local MODE = "INSTALL" -- "INSTALL", "AUDIT", or "ROLLBACK"

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PATCH_ID = "NTR_SLOPE_HOVER_HEIGHT_COMPENSATION_V1"
local LOG_PREFIX = "[NTR Slope Hover]"

local function log(message)
	print(LOG_PREFIX .. " " .. tostring(message))
end

local function fail(message)
	error(LOG_PREFIX .. " " .. tostring(message), 2)
end

local function child(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and not existing:IsA(className) then
		fail(("Expected %s.%s to be %s, found %s"):format(parent:GetFullName(), name, className, existing.ClassName))
	end
	if not existing then
		existing = Instance.new(className)
		existing.Name = name
		existing.Parent = parent
	end
	return existing
end

local function findNeoTokyoRoot()
	local root = ReplicatedStorage:FindFirstChild("NeoTokyoRacers")
	if root then
		return root
	end
	fail("Missing ReplicatedStorage.NeoTokyoRacers")
end

local function findDrivingController(root)
	local path = {
		"Shared",
		"Modules",
		"Client",
		"Controllers",
		"DrivingControllerV47",
	}

	local current = root
	for _, name in ipairs(path) do
		current = current and current:FindFirstChild(name)
	end

	if current and current:IsA("ModuleScript") then
		return current
	end

	fail("Missing ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Controllers.DrivingControllerV47")
end

local function ensureMechanicsConfig(root)
	local config = child(root, "Folder", "Config")
	local runtime = child(config, "Folder", "Runtime")
	local mechanics = child(runtime, "Folder", "DRIVING_MECHANICS_EditAttributes")

	local defaults = {
		SlopeHoverCompensationEnabled = true,
		SlopeHoverVelocityCompensation = 1.0,
		SlopeHoverHeightStiffness = 54,
		SlopeHoverNormalVelocityDamping = 7,
		SlopeHoverMaxLiftMultiplier = 4.5,
		SlopeHoverMissLiftMultiplier = 0.05,
		SlopeHoverForceAlongGroundNormal = false,
		SlopeHoverDebugAttributes = true,
	}

	for name, value in pairs(defaults) do
		if mechanics:GetAttribute(name) == nil then
			mechanics:SetAttribute(name, value)
		end
	end

	mechanics:SetAttribute("SlopeHoverNotes", "Fixes uphill/downhill hover-height drift by damping vertical velocity relative to expected slope-following vertical motion instead of raw world-Y velocity. ForceAlongGroundNormal is optional and off by default.")
	return mechanics
end

local ORIGINAL_HOVER_BLOCK = [[
		local hitPositions = {}
		local normalSum = Vector3.zero
		local hits = 0
		local liftPerCorner = mass * Workspace.Gravity / 4

		for index, corner in ipairs(state.Controls.Corners) do
			local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), state.RayParams)
			if result then
				local targetDistance = HOVER_HEIGHT + SENSOR_START_HEIGHT
				local heightError = targetDistance - result.Distance
				local pointVelocityY = root:GetVelocityAtPosition(origin).Y
				local forceAmount = liftPerCorner + mass * (heightError * 48 - pointVelocityY * 6)
				corner.Force.Force = Vector3.new(0, math.clamp(forceAmount, 0, liftPerCorner * 4.25), 0)
				hitPositions[index] = result.Position
				normalSum += result.Normal
				hits += 1
			else
				corner.Force.Force = Vector3.new(0, liftPerCorner * 0.05, 0)
			end
		end

		local terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		local grounded = hits >= 2]]

local PATCHED_HOVER_BLOCK = [[
		-- NTR_SLOPE_HOVER_HEIGHT_COMPENSATION_V1_BEGIN
		local hitPositions = {}
		local normalSum = Vector3.zero
		local hits = 0
		local liftPerCorner = mass * Workspace.Gravity / 4
		local hoverResults = {}

		for index, corner in ipairs(state.Controls.Corners) do
			local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
			local result = Workspace:Raycast(origin, Vector3.new(0, -SENSOR_LENGTH, 0), state.RayParams)
			hoverResults[index] = result
			if result then
				hitPositions[index] = result.Position
				normalSum += result.Normal
				hits += 1
			end
		end

		local terrainForward, groundNormal = getTerrainFrame(root, hitPositions, normalSum, hits)
		local grounded = hits >= 2
		local slopeHoverEnabled = configBool("DRIVING_MECHANICS_EditAttributes", "SlopeHoverCompensationEnabled", true)
		local tangentVelocity = velocity - groundNormal * velocity:Dot(groundNormal)
		local expectedSlopeYVelocity = slopeHoverEnabled and tangentVelocity.Y or 0
		local velocityCompensation = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverVelocityCompensation", 1.0, 0, 1.5)
		local heightStiffness = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverHeightStiffness", 54, 8, 140)
		local normalVelocityDamping = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverNormalVelocityDamping", 7, 0, 30)
		local maxLiftMultiplier = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverMaxLiftMultiplier", 4.5, 1, 10)
		local missLiftMultiplier = configNumber("DRIVING_MECHANICS_EditAttributes", "SlopeHoverMissLiftMultiplier", 0.05, 0, 1)
		local forceAlongGroundNormal = configBool("DRIVING_MECHANICS_EditAttributes", "SlopeHoverForceAlongGroundNormal", false)
		local lastRelativeYVelocity = 0

		for index, corner in ipairs(state.Controls.Corners) do
			local result = hoverResults[index]
			if result then
				local targetDistance = HOVER_HEIGHT + SENSOR_START_HEIGHT
				local heightError = targetDistance - result.Distance
				local origin = root.CFrame:PointToWorldSpace(corner.Offset) + Vector3.new(0, SENSOR_START_HEIGHT, 0)
				local pointVelocityY = root:GetVelocityAtPosition(origin).Y
				local relativeYVelocity = pointVelocityY - expectedSlopeYVelocity * velocityCompensation
				lastRelativeYVelocity = relativeYVelocity
				local forceAmount = liftPerCorner + mass * (heightError * heightStiffness - relativeYVelocity * normalVelocityDamping)
				forceAmount = math.clamp(forceAmount, 0, liftPerCorner * maxLiftMultiplier)
				if forceAlongGroundNormal and groundNormal.Y > 0.15 then
					corner.Force.Force = groundNormal * (forceAmount / math.max(groundNormal.Y, 0.25))
				else
					corner.Force.Force = Vector3.new(0, forceAmount, 0)
				end
			else
				corner.Force.Force = Vector3.new(0, liftPerCorner * missLiftMultiplier, 0)
			end
		end

		if configBool("DRIVING_MECHANICS_EditAttributes", "SlopeHoverDebugAttributes", true) then
			state.Vehicle:SetAttribute("SlopeHoverExpectedYVelocity", expectedSlopeYVelocity)
			state.Vehicle:SetAttribute("SlopeHoverRelativeYVelocity", lastRelativeYVelocity)
			state.Vehicle:SetAttribute("SlopeHoverGroundNormalY", groundNormal.Y)
			state.Vehicle:SetAttribute("SlopeHoverTerrainForwardY", terrainForward.Y)
			state.Vehicle:SetAttribute("SlopeHoverHits", hits)
		end
		-- NTR_SLOPE_HOVER_HEIGHT_COMPENSATION_V1_END]]

local function replacePlainOnce(source, needle, replacement)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		return source, 0
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex + 1), 1
end

local function printSourceDiagnostics(source)
	local markers = {
		"local hitPositions = {}",
		"local pointVelocityY = root:GetVelocityAtPosition(origin).Y",
		"local terrainForward, groundNormal = getTerrainFrame",
		"NTR_SLOPE_HOVER_HEIGHT_COMPENSATION_V1",
	}

	for _, marker in ipairs(markers) do
		local index = string.find(source, marker, 1, true)
		if index then
			local startIndex = math.max(1, index - 450)
			local endIndex = math.min(#source, index + 1200)
			log(("Found marker '%s'. Nearby source:\n%s"):format(marker, string.sub(source, startIndex, endIndex)))
		else
			log(("Marker not found: %s"):format(marker))
		end
	end
end

local function sourceHasPatch(source)
	return string.find(source, "NTR_SLOPE_HOVER_HEIGHT_COMPENSATION_V1_BEGIN", 1, true) ~= nil
		and string.find(source, "NTR_SLOPE_HOVER_HEIGHT_COMPENSATION_V1_END", 1, true) ~= nil
end

local function install(controller)
	local source = controller.Source
	if sourceHasPatch(source) then
		log("Controller already has slope hover height compensation; config attributes refreshed.")
		controller:SetAttribute("SlopeHoverHeightCompensationPatch", PATCH_ID)
		return
	end

	local patched, replacements = replacePlainOnce(source, ORIGINAL_HOVER_BLOCK, PATCHED_HOVER_BLOCK)
	if replacements ~= 1 then
		printSourceDiagnostics(source)
		fail("Could not find the expected V75 corner hover source block. Refresh the Studio mirror or inspect the live DrivingControllerV47 source before another patch.")
	end

	controller.Source = patched
	controller:SetAttribute("SlopeHoverHeightCompensationPatch", PATCH_ID)
	controller:SetAttribute("SlopeHoverHeightCompensationInstalledAt", os.date("!%Y-%m-%dT%H:%M:%SZ"))
	log("Installed slope hover height compensation into DrivingControllerV47.")
end

local function rollback(controller)
	local source = controller.Source
	if not sourceHasPatch(source) then
		log("Controller does not have slope hover height compensation; nothing to roll back.")
		return
	end

	local restored, replacements = replacePlainOnce(source, PATCHED_HOVER_BLOCK, ORIGINAL_HOVER_BLOCK)
	if replacements ~= 1 then
		printSourceDiagnostics(source)
		fail("Could not cleanly remove slope hover height compensation.")
	end

	controller.Source = restored
	controller:SetAttribute("SlopeHoverHeightCompensationPatch", nil)
	controller:SetAttribute("SlopeHoverHeightCompensationInstalledAt", nil)
	log("Rolled back slope hover height compensation from DrivingControllerV47.")
end

local function audit(controller, mechanics)
	local source = controller.Source
	log("DrivingControllerV47 path: " .. controller:GetFullName())
	log("Slope hover compensation installed: " .. tostring(sourceHasPatch(source)))
	log("Config path: " .. mechanics:GetFullName())

	local names = {
		"SlopeHoverCompensationEnabled",
		"SlopeHoverVelocityCompensation",
		"SlopeHoverHeightStiffness",
		"SlopeHoverNormalVelocityDamping",
		"SlopeHoverMaxLiftMultiplier",
		"SlopeHoverMissLiftMultiplier",
		"SlopeHoverForceAlongGroundNormal",
		"SlopeHoverDebugAttributes",
	}

	for _, name in ipairs(names) do
		log(("%s = %s"):format(name, tostring(mechanics:GetAttribute(name))))
	end
end

local root = findNeoTokyoRoot()
local controller = findDrivingController(root)
local mechanics = ensureMechanicsConfig(root)

if MODE == "INSTALL" then
	install(controller)
	audit(controller, mechanics)
elseif MODE == "ROLLBACK" then
	rollback(controller)
	audit(controller, mechanics)
elseif MODE == "AUDIT" then
	audit(controller, mechanics)
else
	fail("Unknown MODE: " .. tostring(MODE))
end

log("Done. Restart Play mode after INSTALL or ROLLBACK so clients require the updated controller.")
