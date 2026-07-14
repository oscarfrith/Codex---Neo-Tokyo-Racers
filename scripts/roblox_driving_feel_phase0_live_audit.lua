-- Neo Tokyo Racers - Driving Feel Phase 0 live audit
-- Read-only: this script creates, changes, and deletes nothing.
--
-- Run once in the Studio Command Bar while NOT play-testing to audit source and
-- config. Run it again during Play after spawning a vehicle to include runtime
-- legacy/detailed stats, velocity, collision, and network-owner observations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local PREFIX = "[NTR Driving Feel Phase 0] "
local passCount = 0
local warnCount = 0
local failCount = 0

local function pass(message)
	passCount += 1
	print(PREFIX .. "PASS: " .. message)
end

local function warnAudit(message)
	warnCount += 1
	warn(PREFIX .. "WARN: " .. message)
end

local function fail(message)
	failCount += 1
	warn(PREFIX .. "FAIL: " .. message)
end

local function child(parent, name)
	return parent and parent:FindFirstChild(name) or nil
end

local function sourceOf(instance)
	if not instance or not instance:IsA("LuaSourceContainer") then
		return nil
	end
	local ok, source = pcall(function()
		return instance.Source
	end)
	return ok and source or nil
end

local function hasPlain(source, needle)
	return typeof(source) == "string" and string.find(source, needle, 1, true) ~= nil
end

local kit = child(ReplicatedStorage, "NeoTokyoRacers")
if kit then pass("ReplicatedStorage.NeoTokyoRacers exists") else fail("ReplicatedStorage.NeoTokyoRacers is missing") end

local shared = child(kit, "Shared")
local modules = child(shared, "Modules")
local clientModules = child(modules, "Client")
local clientControllers = child(clientModules, "Controllers")
local driving = child(clientControllers, "DrivingControllerV47")
local drivingSource = sourceOf(driving)

if driving and driving:IsA("ModuleScript") then
	pass("DrivingControllerV47 exists at the active shared-module path")
else
	fail("DrivingControllerV47 is missing from the active shared-module path")
end

if drivingSource then
	pass("DrivingControllerV47 source is readable")
	if hasPlain(drivingSource, "NTR_SPEED_SENSITIVE_STEERING_V1_BEGIN") then
		pass("confirmed speed-sensitive steering patch is present")
	else
		warnAudit("confirmed speed-sensitive steering marker is absent")
	end
	if hasPlain(drivingSource, "NTR_SLOPE_HOVER_HEIGHT_COMPENSATION_V1_BEGIN") then
		pass("confirmed slope-hover compensation patch is present")
	else
		warnAudit("confirmed slope-hover compensation marker is absent")
	end
	if hasPlain(drivingSource, "NTR_ACCEL_BRAKE_PITCH_TILT_V1_BEGIN") then
		pass("confirmed acceleration/braking pitch patch is present")
	else
		warnAudit("confirmed acceleration/braking pitch marker is absent")
	end
	if hasPlain(drivingSource, "NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE") then
		pass("Phase AM detailed-stat physics bridge is present")
	else
		warnAudit("Phase AM detailed-stat physics bridge is ABSENT; live driving appears to read legacy totals")
	end
	if hasPlain(drivingSource, "acceleration * 3.1 * speedLimiter") then
		warnAudit("current initial acceleration multiplier 3.1 is present")
	else
		pass("current source no longer contains the known 3.1 acceleration expression")
	end
	if hasPlain(drivingSource, "math.clamp(1 - (math.max(forwardSpeed, 0) / maxForwardStuds), 0.08, 1)") then
		warnAudit("current linear top-speed limiter with 0.08 force floor is present")
	else
		pass("current source no longer contains the known linear limiter expression")
	end
	if hasPlain(drivingSource, "driveForce += -velocity * mass * (0.16 + 0.10 * state.DriftBlend)") then
		warnAudit("current low neutral drag expression is present")
	else
		pass("current source no longer contains the known neutral-drag expression")
	end
	if hasPlain(drivingSource, "elseif throttle < 0 and forwardSpeed > -maxReverseStuds then") then
		warnAudit("braking and reverse still share one continuous input branch")
	else
		pass("current source no longer contains the known combined brake/reverse branch")
	end
else
	fail("DrivingControllerV47 source could not be read; do not install a source patch from this audit")
end

local sharedConfig = child(shared, "Config")
local performanceConfig = child(sharedConfig, "VehiclePerformance_EditAttributes")
local integrationConfig = child(performanceConfig, "RuntimeIntegration")
local physicsEnabled = integrationConfig and integrationConfig:GetAttribute("PhysicsEnabled") == true
if integrationConfig then
	pass("VehiclePerformance RuntimeIntegration config exists")
	print(PREFIX .. "INFO: RuntimeIntegration.PhysicsEnabled=" .. tostring(physicsEnabled))
else
	fail("VehiclePerformance RuntimeIntegration config is missing")
end
if physicsEnabled and not hasPlain(drivingSource, "NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE") then
	warnAudit("configuration says detailed physics is enabled, but the active driving source has no Phase AM bridge")
end

local performanceServiceRoot = child(child(ServerScriptService, "NeoTokyoRacers"), "Services")
performanceServiceRoot = child(performanceServiceRoot, "Vehicle")
local performanceService = child(performanceServiceRoot, "VehiclePerformanceRuntimeService_Active")
local clientPlayContext = RunService:IsRunning() and RunService:IsClient()
if clientPlayContext then
	pass("client Play context: skipped server-only performance-service visibility check")
elseif performanceService and performanceService:IsA("Script") and not performanceService.Disabled then
	pass("VehiclePerformanceRuntimeService_Active exists and is enabled")
else
	fail("VehiclePerformanceRuntimeService_Active is missing or disabled")
end

local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
local clientRoot = child(starterScripts, "NeoTokyoRacersClient")
local controllerRoot = child(clientRoot, "Controllers")
local runtimeControllers = child(controllerRoot, "Runtime")
local parkedHover = child(runtimeControllers, "FreeRoamParkedHoverController_Active")
local parkedSource = sourceOf(parkedHover)
if parkedSource then
	pass("FreeRoamParkedHoverController_Active source is readable")
	if hasPlain(parkedSource, "AssemblyLinearVelocity") or hasPlain(parkedSource, "AssemblyAngularVelocity") then
		pass("parked-hover source contains explicit velocity settling")
	else
		warnAudit("parked-hover source has no explicit horizontal/angular velocity settling")
	end
else
	warnAudit("FreeRoamParkedHoverController_Active source is missing or unreadable")
end

local garageServices = child(child(child(ServerScriptService, "NeoTokyoRacers"), "Services"), "Garage")
local garageController = child(garageServices, "GarageActionController_Shadow_Disabled")
local garageSource = sourceOf(garageController)
if clientPlayContext then
	pass("client Play context: skipped server-only garage-source visibility check")
elseif garageSource then
	pass("garage action controller source is readable")
	if hasPlain(garageSource, "CFrame.new(-10, 3, 0)") then
		warnAudit("vehicle exit still uses the fixed -10, +3 stud offset")
	else
		pass("garage source no longer contains the known fixed exit offset")
	end
	if hasPlain(garageSource, "descendant.CanCollide = descendant == root") then
		warnAudit("spawned vehicle root remains collidable")
	end
	if hasPlain(garageSource, "RegisterCollisionGroup") or hasPlain(garageSource, "CollisionGroup =") then
		pass("garage source contains collision-group handling")
	else
		warnAudit("garage source contains no vehicle/player collision-group assignment")
	end
else
	fail("garage action controller source is missing or unreadable")
end

local function numberFromFolder(folder, name)
	local value = folder and folder:FindFirstChild(name)
	return value and value:IsA("NumberValue") and value.Value or nil
end

local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
local runtime = child(world, "Runtime")
local vehiclesRoot = child(runtime, "PlayerVehicles")
local vehicles = vehiclesRoot and vehiclesRoot:GetChildren() or {}

if RunService:IsRunning() then
	if #vehicles == 0 then
		warnAudit("Play runtime has no spawned vehicle; spawn one and rerun for runtime stat evidence")
	else
		pass("Play runtime has " .. tostring(#vehicles) .. " spawned player vehicle(s)")
	end
	for index, vehicle in ipairs(vehicles) do
		if index > 3 then break end
		local legacy = vehicle:FindFirstChild("TOTAL_STATS_Runtime")
		local raw = vehicle:FindFirstChild("RAW_PERFORMANCE_Runtime")
		local root = vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename", true)
		print(PREFIX .. "RUNTIME VEHICLE " .. tostring(index) .. ": " .. vehicle:GetFullName())
		print(string.format(
			"%s  OwnerUserId=%s DriverUserId=%s Tier=%s PI=%s",
			PREFIX,
			tostring(vehicle:GetAttribute("OwnerUserId")),
			tostring(vehicle:GetAttribute("DriverUserId")),
			tostring(vehicle:GetAttribute("PerformanceTier")),
			tostring(vehicle:GetAttribute("PerformanceIndex"))
		))
		for _, pair in ipairs({
			{ "Acceleration", "EngineOutput" },
			{ "Handling", "SteeringResponse" },
			{ "Drift", "DriftControl" },
			{ "Braking", "BrakingForce" },
			{ "Boost", "BoostForce" },
		}) do
			print(string.format(
				"%s  legacy %s=%s | detailed %s=%s",
				PREFIX,
				pair[1],
				tostring(numberFromFolder(legacy, pair[1])),
				pair[2],
				tostring(numberFromFolder(raw, pair[2]))
			))
		end
		print(string.format(
			"%s  TopSpeed=%s Weight=%s Drag=%s LateralGrip=%s Downforce=%s",
			PREFIX,
			tostring(numberFromFolder(legacy, "TopSpeed")),
			tostring(numberFromFolder(legacy, "Weight")),
			tostring(numberFromFolder(raw, "Drag")),
			tostring(numberFromFolder(raw, "LateralGrip")),
			tostring(numberFromFolder(raw, "Downforce"))
		))
		if root and root:IsA("BasePart") then
			print(string.format(
				"%s  SpeedMph=%.2f RootCanCollide=%s RootCollisionGroup=%s AssemblyMass=%.2f",
				PREFIX,
				root.AssemblyLinearVelocity.Magnitude * 0.625,
				tostring(root.CanCollide),
				tostring(root.CollisionGroup),
				root.AssemblyMass
			))
			local ok, owner = pcall(function() return root:GetNetworkOwner() end)
			if ok then
				print(PREFIX .. "  NetworkOwner=" .. tostring(owner and owner.Name or "server/automatic"))
			end
		else
			warnAudit(vehicle:GetFullName() .. " has no usable root part")
		end
	end
else
	pass("Edit-mode source/config audit completed; rerun during Play after spawning a vehicle")
end

print(string.format("%sSUMMARY: pass=%d warn=%d fail=%d", PREFIX, passCount, warnCount, failCount))
if failCount > 0 then
	warn(PREFIX .. "RESULT: BLOCKED. Resolve failures or refresh the Studio mirror before Phase 1.")
elseif not hasPlain(drivingSource, "NTR_VEHICLE_PHASE_AM_PHYSICS_BRIDGE") then
	print(PREFIX .. "RESULT: EXPECTED AUDIT GATE. Detailed-stat bridge absence confirmed; use the fresh live source for the condensed dynamics installer.")
else
	print(PREFIX .. "RESULT: SOURCE SHAPE DIFFERS FROM THE MIRROR FINDING. Refresh the mirror before generating Phase 1.")
end
