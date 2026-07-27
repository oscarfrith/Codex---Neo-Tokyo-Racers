-- Neo Tokyo Racers - Drive-To-Earn Cash System V1.1
-- Paste this whole file into the Roblox Studio Command Bar in Edit mode.
--
-- INSTALL:
--   1. Leave MODE = "INSTALL".
--   2. Run once in Edit mode.
--   3. Require both AUDIT PASS and INSTALL PASS.
--   4. Restart Play and complete the verification matrix in the handoff doc.
--
-- AUDIT:
--   Change MODE to "AUDIT" and run in Edit mode. This is read-only.
--
-- ROLLBACK:
--   Change MODE to "ROLLBACK" and run in Edit mode. This removes this exact
--   system and restores the guarded V1 source anchors. It does not roll back
--   Cash already earned and saved while the system was active.
--
-- This installer creates no in-game backup folders or scripts. Source patches
-- are intentionally exact and fragile: any unknown live source shape aborts
-- before mutation. A failed INSTALL restores everything changed by that run.

local MODE = "INSTALL" -- INSTALL, AUDIT, or ROLLBACK
local PHASE = "NTR Drive-To-Earn Cash V1.1"
local REVISION = "NTR_DRIVE_TO_EARN_CASH_V1_1"
local PREVIOUS_REVISION = "NTR_DRIVE_TO_EARN_CASH_V1"
local PROFILE_MARKER = "NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1"
local GARAGE_MARKER = "NTR_GARAGE_ECONOMY_COMMITTED_PROJECTION_V1"
local VEHICLE_ID_MARKER = "NTR_RUNTIME_OWNED_VEHICLE_ID_V1"
local SERVICE_MARKER = "NTR_DRIVE_TO_EARN_CASH_SERVICE_V1_1"
local TELEMETRY_MARKER = "NTR_DRIVE_TO_EARN_STUDIO_TELEMETRY_V1_1"
local PREVIOUS_SERVICE_MARKER = "NTR_DRIVE_TO_EARN_CASH_SERVICE_V1"
local PREVIOUS_TELEMETRY_MARKER = "NTR_DRIVE_TO_EARN_STUDIO_TELEMETRY_V1"

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function log(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function must(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item or (className and not item:IsA(className)) then
		fail("Missing " .. tostring(parent and parent:GetFullName() or "<nil>") .. "." .. tostring(name))
	end
	return item
end

local function countPlain(source, needle)
	local count = 0
	local cursor = 1
	while true do
		local first = string.find(source, needle, cursor, true)
		if not first then return count end
		count += 1
		cursor = first + #needle
	end
end

local function replaceOnce(source, anchor, replacement, label)
	local count = countPlain(source, anchor)
	if count ~= 1 then
		fail(label .. " anchor count expected 1, got " .. tostring(count)
			.. ". Refresh and inspect the live mirror; do not loosen this anchor.")
	end
	local first, last = string.find(source, anchor, 1, true)
	return string.sub(source, 1, first - 1) .. replacement .. string.sub(source, last + 1)
end

local function insertAfterOnce(source, anchor, insertion, label)
	return replaceOnce(source, anchor, anchor .. insertion, label)
end

local function insertBeforeOnce(source, anchor, insertion, label)
	return replaceOnce(source, anchor, insertion .. anchor, label)
end

local function compile(source, label)
	if #source > 180000 then
		fail(label .. " projected source is too large (" .. tostring(#source) .. " bytes).")
	end
	local chunk, problem = loadstring(source, "=" .. tostring(label))
	if not chunk then fail(label .. " compile failed: " .. tostring(problem)) end
end

local function supportedRevision(value)
	return value == REVISION or value == PREVIOUS_REVISION
end

local function setDescription(folder, name, text)
	local descriptions = folder:FindFirstChild("Descriptions")
	if not descriptions then
		descriptions = Instance.new("Folder")
		descriptions.Name = "Descriptions"
		descriptions.Parent = folder
	end
	local item = descriptions:FindFirstChild(name)
	if item and not item:IsA("StringValue") then
		fail(item:GetFullName() .. " must be a StringValue.")
	end
	if not item then
		item = Instance.new("StringValue")
		item.Name = name
		item.Parent = descriptions
	end
	item.Value = text
end

local kit = must(ReplicatedStorage, "NeoTokyoRacers", "Folder")
local configRoot = must(kit, "Config", "Folder")
local runtimeConfig = must(configRoot, "Runtime", "Folder")
local serverRoot = must(ServerScriptService, "NeoTokyoRacers", "Folder")
local services = must(serverRoot, "Services", "Folder")
local playerServices = must(services, "Player", "Folder")
local garageServices = must(services, "Garage", "Folder")
local vehicleServices = must(services, "Vehicle", "Folder")
local profileService = must(playerServices, "ProfileService_Active", "Script")
local garageAction = must(garageServices, "GarageActionController_Shadow_Disabled", "Script")
if garageAction.Disabled then fail("The canonical garage action owner is unexpectedly disabled.") end
local starterScripts = must(StarterPlayer, "StarterPlayerScripts", "StarterPlayerScripts")
local clientRoot = must(starterScripts, "NeoTokyoRacersClient", "Folder")
local controllers = must(clientRoot, "Controllers", "Folder")

local CONFIG_NAME = "DriveToEarnCash_EditAttributes"
local SERVICE_NAME = "DriveToEarnCashService_Active"
local TELEMETRY_NAME = "DriveToEarnCashTelemetry_StudioOnly"

local CONFIG_DEFAULTS = {
	Enabled = true,
	CashPerAcceptedStud = 0.10,
	VisibleGrantBatchCash = 1,
	SampleIntervalSeconds = 0.5,
	MinimumGrantIntervalSeconds = 0.5,
	MinimumAcceptedSegmentStuds = 1,
	MaximumAcceptedSpeedStudsPerSecond = 540,
	SegmentToleranceStuds = 12,
	MaximumVerticalDeltaStuds = 30,
	MaximumVerticalToHorizontalRatio = 1,
	MaximumSampleGapSeconds = 2,
	HourlyCashCeiling = 35000,
	CeilingWindowSeconds = 3600,
	CeilingBucketSeconds = 60,
	MaximumDriveGrantPerCommand = 1000,
	ProjectionWindowSeconds = 600,
	ProjectionBucketSeconds = 10,
	StudioTelemetryEnabled = true,
	TelemetryRefreshSeconds = 2,
	RuntimeAuditIntervalSeconds = 30,
}

local CONFIG_DESCRIPTIONS = {
	Enabled = "Master server switch. False stops sampling and grants without removing saved Cash.",
	CashPerAcceptedStud = "Base passive earning rate. V1.1 balance is $1 per 10 accepted studs (0.10 Cash/stud).",
	VisibleGrantBatchCash = "Minimum whole-Cash reconciliation batch. V1.1 uses $1, coalesced into one command rather than one command per dollar.",
	SampleIntervalSeconds = "Server sampling interval per player. V1.1 uses 0.5 seconds (2 Hz).",
	MinimumGrantIntervalSeconds = "Minimum between ProfileService drive-Cash commands per player. Values below 0.5 are safety-clamped to 0.5 seconds (at most 2 Hz), even if sampling is tuned faster.",
	MinimumAcceptedSegmentStuds = "Movement below this per-sample distance is stationary/jitter and is not payable.",
	MaximumAcceptedSpeedStudsPerSecond = "Hard server plausibility speed, independent of vehicle tier, price, or advertised max speed.",
	SegmentToleranceStuds = "Extra segment allowance for scheduler jitter before a sample is rejected as implausible.",
	MaximumVerticalDeltaStuds = "Reject a single sample with more vertical movement than this.",
	MaximumVerticalToHorizontalRatio = "Reject mostly vertical movement above this vertical/horizontal ratio.",
	MaximumSampleGapSeconds = "Long scheduler or lifecycle gaps reset the baseline and never become payable.",
	HourlyCashCeiling = "Hard drive-to-earn Cash ceiling inside the rolling window. V1 starts at $35,000.",
	CeilingWindowSeconds = "Rolling ceiling window length. V1 is 3,600 seconds.",
	CeilingBucketSeconds = "Bounded rolling-cap bucket size. V1 keeps at most 60 one-minute buckets per player.",
	MaximumDriveGrantPerCommand = "Defence-in-depth maximum for one ProfileService drive grant.",
	ProjectionWindowSeconds = "Rolling accepted-distance window used by Studio tuning telemetry.",
	ProjectionBucketSeconds = "Bounded telemetry bucket size; does not affect rewards.",
	StudioTelemetryEnabled = "Studio-only read-only overlay/attributes. Ignored in published servers.",
	TelemetryRefreshSeconds = "Studio telemetry publication interval; no client request or remote is used.",
	RuntimeAuditIntervalSeconds = "Studio-only bounded server audit print interval.",
}

local PROFILE_DECLARATION_ANCHOR =
	'local executeOnboardingCommandBinding = ensureBindableFunction(bindings, "ExecuteOnboardingCommand") -- NTR_PROFILE_SERVICE_ONBOARDING_COMMAND_OWNER_V1\n'

local PROFILE_DECLARATION_INSERT = [==[
local executeEconomyCommandBinding = ensureBindableFunction(bindings, "ExecuteEconomyCommand") -- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1
local economyCashCommittedEvent = bindings:FindFirstChild("EconomyCashCommitted")
if economyCashCommittedEvent and not economyCashCommittedEvent:IsA("BindableEvent") then
	error(economyCashCommittedEvent:GetFullName() .. " must be a BindableEvent")
end
if not economyCashCommittedEvent then
	economyCashCommittedEvent = Instance.new("BindableEvent")
	economyCashCommittedEvent.Name = "EconomyCashCommitted"
	economyCashCommittedEvent.Parent = bindings
end
]==]

local PROFILE_LOCK_ANCHOR = "local shuttingDown = false\n"
local PROFILE_LOCK_INSERT = "local economyCommandLocks = {} -- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1\n"

local PROFILE_COMMAND_ANCHOR = "executeOwnedGarageCommandBinding.OnInvoke = function(player, command)\n"
local PROFILE_COMMAND_BLOCK = [==[
-- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1
-- Canonical positive-Cash command boundary. Callers provide server-authored intent;
-- this owner validates the current ProfileService session and mutates session.Profile.
local ECONOMY_COMMAND_VERSION = 1
local GENERIC_GRANT_REASONS = {
	RaceReward = true,
	TimeTrialReward = true,
	StudioCashGrantHotkey = true,
}

local function economyConfig()
	local runtime = ntr:FindFirstChild("Config") and ntr.Config:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("DriveToEarnCash_EditAttributes")
end

local function economyNumber(name, fallback, minimum, maximum)
	local folder = economyConfig()
	local value = tonumber(folder and folder:GetAttribute(name)) or fallback
	if minimum ~= nil then value = math.max(minimum, value) end
	if maximum ~= nil then value = math.min(maximum, value) end
	return value
end

local function setCommittedCashProjection(player, cash)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end
	local value = leaderstats:FindFirstChild("Cash")
	if value and not value:IsA("IntValue") then
		return false, "leaderstats.Cash must be an IntValue."
	end
	if not value then
		value = Instance.new("IntValue")
		value.Name = "Cash"
		value.Parent = leaderstats
	end
	value.Value = math.max(0, math.floor(tonumber(cash) or 0))
	return true
end

local function validateDriveVehicle(player, session, command)
	local vehicle = command.Vehicle
	local vehicleId = tostring(command.VehicleId or "")
	if not (vehicle and vehicle:IsA("Model") and vehicle.Parent) then
		return false, "VehicleMissing"
	end
	local world = workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
	if not (vehicles and vehicle.Parent == vehicles) then
		return false, "NotRuntimeVehicle"
	end
	if tonumber(vehicle:GetAttribute("OwnerUserId")) ~= player.UserId
		or tonumber(vehicle:GetAttribute("DriverUserId")) ~= player.UserId then
		return false, "OwnershipMismatch"
	end
	if vehicleId == "" or tostring(vehicle:GetAttribute("OwnedVehicleId") or "") ~= vehicleId then
		return false, "VehicleIdentityMismatch"
	end
	if typeof(session.Profile.Vehicles) ~= "table" or typeof(session.Profile.Vehicles[vehicleId]) ~= "table" then
		return false, "VehicleNotOwned"
	end
	if tostring(session.Profile.CurrentVehicleId or "") ~= vehicleId then
		return false, "VehicleNotCurrent"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat:IsDescendantOf(vehicle) and seat.Occupant == humanoid) then
		return false, "Unseated"
	end
	if vehicle:GetAttribute("DriveReady") ~= true then return false, "NotDriveReady" end
	if vehicle:GetAttribute("NTR_RaceFrozen") == true or vehicle.PrimaryPart and vehicle.PrimaryPart.Anchored then
		return false, "FrozenOrStaging"
	end
	if vehicle:GetAttribute("ParkedShowcase") == true or vehicle:GetAttribute("NTR_ParkedFixed") == true then
		return false, "Parked"
	end
	if vehicle:GetAttribute("NTR_ExitCoasting") == true then return false, "ExitCoasting" end
	if vehicle:GetAttribute("NTR_RaceBrowserTeleportDespawn") == true
		or vehicle:GetAttribute("NTR_FreeRoamHudTeleportDespawn") == true then
		return false, "TeleportOrTransition"
	end
	return true
end

executeEconomyCommandBinding.OnInvoke = function(player, command)
	if not (player and player:IsA("Player") and player.Parent == Players) then
		return {Ok=false, Success=false, Message="Player lifecycle is not active.", RejectionReason="PlayerLifecycle"}
	end
	command = typeof(command) == "table" and command or {}
	if math.floor(tonumber(command.Version) or 0) ~= ECONOMY_COMMAND_VERSION then
		return {Ok=false, Success=false, Message="Unsupported economy command version.", RejectionReason="CommandVersion"}
	end
	local session = sessionFor(player)
	if not session then
		return {Ok=false, Success=false, Message="Profile is not loaded.", RejectionReason="ProfileNotLoaded"}
	end
	if command.ExpectedSessionGeneration ~= nil
		and tonumber(command.ExpectedSessionGeneration) ~= session.SessionGeneration then
		return {Ok=false, Success=false, Message="Profile session generation changed.", RejectionReason="SessionChanged"}
	end
	if command.ExpectedSessionId ~= nil and tostring(command.ExpectedSessionId) ~= session.SessionId then
		return {Ok=false, Success=false, Message="Profile session identity changed.", RejectionReason="SessionChanged"}
	end
	local userId = player.UserId
	if economyCommandLocks[userId] then
		return {Ok=false, Success=false, Message="Economy command already in progress.", RejectionReason="Busy", Busy=true}
	end
	economyCommandLocks[userId] = session
	local expectedGeneration = session.SessionGeneration
	local expectedId = session.SessionId
	local action = tostring(command.Action or "")

	local ok, result = pcall(function()
		if action == "ValidateDriveSample" or action == "GrantDriveCash" then
			local valid, reason = validateDriveVehicle(player, session, command)
			if not valid then
				return {Ok=false, Success=false, Message="Drive sample rejected: "..reason, RejectionReason=reason}
			end
			if action == "ValidateDriveSample" then
				return {
					Ok=true, Success=true, Valid=true,
					SessionGeneration=expectedGeneration, SessionId=expectedId,
					VehicleId=tostring(command.VehicleId or ""),
				}
			end
		elseif action == "GrantCash" then
			if not GENERIC_GRANT_REASONS[tostring(command.Reason or "")] then
				return {Ok=false, Success=false, Message="Generic Cash grant reason is not allowed.", RejectionReason="ReasonNotAllowed"}
			end
		else
			return {Ok=false, Success=false, Message="Unknown economy command.", RejectionReason="UnknownAction"}
		end

		local amount = math.floor(tonumber(command.Amount) or 0)
		if amount <= 0 then
			return {Ok=false, Success=false, Message="Cash amount must be a positive whole number.", RejectionReason="InvalidAmount"}
		end
		local commandId = tostring(command.CommandId or "")
		if commandId == "" or #commandId > 240 then
			return {Ok=false, Success=false, Message="A bounded economy command ID is required.", RejectionReason="CommandId"}
		end
		session.EconomyClaims = session.EconomyClaims or {Lookup={}, Order={}}
		local claims = session.EconomyClaims
		if claims.Lookup[commandId] then
			return {
				Ok=true, Success=true, Amount=0, Cash=math.max(0,math.floor(tonumber(session.Profile.Cash) or 0)),
				AlreadyCommitted=true, SessionGeneration=expectedGeneration, SessionId=expectedId,
			}
		end
		local maximum = action == "GrantDriveCash"
			and economyNumber("MaximumDriveGrantPerCommand", 1000, 1, 100000)
			or 1000000
		if amount > maximum then
			return {Ok=false, Success=false, Message="Cash amount exceeds the command limit.", RejectionReason="AmountLimit"}
		end
		local current = sessionFor(player)
		if current ~= session or current.SessionGeneration ~= expectedGeneration or current.SessionId ~= expectedId then
			return {Ok=false, Success=false, Message="Profile session changed before Cash commit.", RejectionReason="SessionChanged"}
		end
		local oldCash = math.max(0, math.floor(tonumber(session.Profile.Cash) or 0))
		local oldDirty = session.Dirty
		local oldDirtyReason = session.LastDirtyReason
		local newCash = oldCash + amount
		if newCash > 2000000000 then
			return {Ok=false, Success=false, Message="Cash balance safety limit reached.", RejectionReason="BalanceLimit"}
		end
		session.Profile.Cash = newCash
		session.Dirty = true
		session.LastDirtyReason = "EconomyCommand:" .. tostring(command.Reason or action)
		updateRuntimeMarker(player, session)
		local projected, projectionMessage = setCommittedCashProjection(player, newCash)
		if not projected then
			session.Profile.Cash = oldCash
			session.Dirty = oldDirty
			session.LastDirtyReason = oldDirtyReason
			updateRuntimeMarker(player, session)
			return {Ok=false, Success=false, Message=projectionMessage, RejectionReason="ProjectionFailed"}
		end
		claims.Lookup[commandId] = true
		table.insert(claims.Order, commandId)
		while #claims.Order > 256 do
			local expired = table.remove(claims.Order, 1)
			claims.Lookup[expired] = nil
		end
		player:SetAttribute("NTR_LastEconomyCommand", action)
		player:SetAttribute("NTR_LastEconomyGrantAmount", amount)
		player:SetAttribute("NTR_LastEconomyGrantReason", tostring(command.Reason or action))
		economyCashCommittedEvent:Fire(player, newCash, {
			Version=ECONOMY_COMMAND_VERSION,
			Action=action,
			Amount=amount,
			Reason=tostring(command.Reason or action),
			CommandId=commandId,
			SessionGeneration=expectedGeneration,
			SessionId=expectedId,
		})
		return {
			Ok=true, Success=true, Amount=amount, Cash=newCash,
			SessionGeneration=expectedGeneration, SessionId=expectedId,
		}
	end)
	if economyCommandLocks[userId] == session then economyCommandLocks[userId] = nil end
	if not ok then
		warnLine("ECONOMY COMMAND FAILED player="..player.Name.." action="..action.." error="..tostring(result))
		return {Ok=false, Success=false, Message="Economy command failed.", RejectionReason="CommandError"}
	end
	return result
end

]==]

local PROFILE_REMOVE_ANCHOR = "\townedGarageCommandLocks[userId] = nil\n"
local PROFILE_REMOVE_INSERT = "\teconomyCommandLocks[userId] = nil -- NTR_PROFILE_SERVICE_ECONOMY_COMMAND_OWNER_V1\n"

local ORIGINAL_GARAGE_BRIDGE = [==[
	-- NTR_RACING_PHASE6_GARAGE_CASH_BRIDGE
	local V91_RaceRewardBridgeReady = false
	local function V91_ensureRaceRewardCashBridge()
		if V91_RaceRewardBridgeReady then
			return
		end
		local bindings = script.Parent:FindFirstChild("GarageProfileMutationBindings")
		if not bindings then
			bindings = Instance.new("Folder")
			bindings.Name = "GarageProfileMutationBindings"
			bindings.Parent = script.Parent
		end
		local grantCash = bindings:FindFirstChild("GrantCash")
		if not grantCash then
			grantCash = Instance.new("BindableFunction")
			grantCash.Name = "GrantCash"
			grantCash.Parent = bindings
		end
		grantCash.OnInvoke = function(action, payload)
			if action ~= "GrantCash" then
				return { Ok = false, Success = false, Message = "Unknown garage mutation action." }
			end
			payload = typeof(payload) == "table" and payload or {}
			local player = payload.Player
			local amount = math.floor((tonumber(payload.Amount) or 0) + 0.5)
			if not player or amount <= 0 then
				return { Ok = false, Success = false, Message = "Missing player or positive amount." }
			end
			local profile = V56_getProfile(player)
			profile.Cash = math.max(0, math.floor((tonumber(profile.Cash) or 0) + amount))
			V56_setLeaderstats(player, profile)
			V80_mirrorLegacyProfileToPersistence(player, profile, tostring(payload.Reason or "RaceRewardGrant"), true)
			player:SetAttribute("NTR_LastRaceRewardAmount", amount)
			player:SetAttribute("NTR_LastRaceRewardRunId", tostring(payload.RunId or ""))
			player:SetAttribute("NTR_LastRaceRewardEventId", tostring(payload.EventId or ""))
			return { Ok = true, Success = true, Amount = amount, Cash = profile.Cash }
		end
		V91_RaceRewardBridgeReady = true
	end
	V91_ensureRaceRewardCashBridge()
]==]

local NEW_GARAGE_BRIDGE = [==[
	-- NTR_RACING_PHASE6_GARAGE_CASH_BRIDGE
	-- NTR_GARAGE_ECONOMY_COMMITTED_PROJECTION_V1
	-- Existing reward callers retain their binding, but ProfileService is the only
	-- positive-Cash grant owner. This legacy profile is a committed projection only.
	local V91_RaceRewardBridgeReady = false
	local V91_EconomyProjectionConnected = false
	local function V91_profileEconomyBindings()
		local servicesRoot = script.Parent and script.Parent.Parent
		local playerRoot = servicesRoot and servicesRoot:FindFirstChild("Player")
		local bindings = playerRoot and playerRoot:FindFirstChild("ProfileServiceBindings")
		local execute = bindings and bindings:FindFirstChild("ExecuteEconomyCommand")
		local committed = bindings and bindings:FindFirstChild("EconomyCashCommitted")
		return execute, committed
	end
	local function V91_connectEconomyProjection()
		if V91_EconomyProjectionConnected then return end
		local _, committed = V91_profileEconomyBindings()
		if not (committed and committed:IsA("BindableEvent")) then return end
		committed.Event:Connect(function(player, committedCash)
			if not (player and player:IsA("Player")) then return end
			local legacy = V56_profiles[player.UserId]
			if legacy then legacy.Cash = math.max(0, math.floor(tonumber(committedCash) or 0)) end
			V56_setLeaderstats(player, {Cash=committedCash})
		end)
		V91_EconomyProjectionConnected = true
	end
	local function V91_ensureRaceRewardCashBridge()
		if V91_RaceRewardBridgeReady then return end
		local bindings = script.Parent:FindFirstChild("GarageProfileMutationBindings")
		if not bindings then
			bindings = Instance.new("Folder")
			bindings.Name = "GarageProfileMutationBindings"
			bindings.Parent = script.Parent
		end
		local grantCash = bindings:FindFirstChild("GrantCash")
		if not grantCash then
			grantCash = Instance.new("BindableFunction")
			grantCash.Name = "GrantCash"
			grantCash.Parent = bindings
		end
		grantCash.OnInvoke = function(action, payload)
			if action ~= "GrantCash" then
				return {Ok=false, Success=false, Message="Unknown garage mutation action."}
			end
			payload = typeof(payload) == "table" and payload or {}
			local player = payload.Player
			local execute = V91_profileEconomyBindings()
			if not (player and execute and execute:IsA("BindableFunction")) then
				return {Ok=false, Success=false, Message="ProfileService economy command is unavailable."}
			end
			V91_connectEconomyProjection()
			local result = execute:Invoke(player, {
				Version=1,
				Action="GrantCash",
				Amount=math.floor((tonumber(payload.Amount) or 0)+0.5),
				Reason=tostring(payload.Reason or ""),
				CommandId=(tostring(payload.Reason or "")=="StudioCashGrantHotkey")
					and game:GetService("HttpService"):GenerateGUID(false)
					or (tostring(payload.Reason or "")..":"..tostring(payload.RunId or "")..":"..tostring(player.UserId)),
				RunId=tostring(payload.RunId or ""),
				EventId=tostring(payload.EventId or ""),
			})
			if typeof(result) == "table" and result.Success == true then
				player:SetAttribute("NTR_LastRaceRewardAmount", result.Amount)
				player:SetAttribute("NTR_LastRaceRewardRunId", tostring(payload.RunId or ""))
				player:SetAttribute("NTR_LastRaceRewardEventId", tostring(payload.EventId or ""))
			end
			return result
		end
		V91_connectEconomyProjection()
		task.spawn(function()
			for _ = 1, 100 do
				if V91_EconomyProjectionConnected then return end
				task.wait(0.1)
				V91_connectEconomyProjection()
			end
			warn("[NTR Economy] Legacy Cash projection did not connect within 10 seconds.")
		end)
		V91_RaceRewardBridgeReady = true
	end
	V91_ensureRaceRewardCashBridge()
]==]

local VEHICLE_ID_ANCHOR = '\t\tvehicle:SetAttribute("OwnerUserId", player.UserId)\n'
local VEHICLE_ID_INSERT =
	'\t\tvehicle:SetAttribute("OwnedVehicleId", tostring(profile.CurrentVehicleId or "")) -- NTR_RUNTIME_OWNED_VEHICLE_ID_V1\n'

local SERVICE_SOURCE = [==[
-- NTR_DRIVE_TO_EARN_CASH_SERVICE_V1_1
-- Canonical server distance/reward owner. No client-authored distance, speed,
-- multiplier, reward, tier, price or maximum-speed value is accepted.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local ServerScriptService=game:GetService("ServerScriptService")
local Workspace=game:GetService("Workspace")

local REVISION="NTR_DRIVE_TO_EARN_CASH_V1_1"
local kit=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local config=kit:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("DriveToEarnCash_EditAttributes")
local serverRoot=ServerScriptService:WaitForChild("NeoTokyoRacers")
local services=serverRoot:WaitForChild("Services")
local profileBindings=services:WaitForChild("Player"):WaitForChild("ProfileServiceBindings")
local executeEconomy=profileBindings:WaitForChild("ExecuteEconomyCommand")
local world=Workspace:WaitForChild("NeoTokyoRacersWorld")
local vehiclesRoot=world:WaitForChild("Runtime"):WaitForChild("PlayerVehicles")

local states={}
local shuttingDown=false
local totalSamples=0
local totalCommands=0
local totalGrantCommands=0
local activeLoopGeneration=0
local REASONS={
	"BaselineReset","PlayerLifecycle","ProfileNotLoaded","NoCharacter","Unseated",
	"NotRuntimeVehicle","VehicleMissing","OwnershipMismatch","VehicleIdentityMismatch",
	"VehicleNotOwned","VehicleNotCurrent","NotDriveReady","FrozenOrStaging","Parked","ExitCoasting",
	"TeleportOrTransition","GarageTransition","LoadingTransition","SessionChanged",
	"VehicleLifecycleChanged","SampleGap","Stationary","VerticalJump",
	"ImplausibleSegment","HourlyCap","CashCommandRejected","Busy",
}

local function number(name,fallback,minimum,maximum)
	local value=tonumber(config:GetAttribute(name)) or fallback
	if minimum~=nil then value=math.max(minimum,value) end
	if maximum~=nil then value=math.min(maximum,value) end
	return value
end

local function enabled()
	return config:GetAttribute("Enabled")~=false
end

local function newBuckets()
	return {}
end

local function bucketAdd(buckets,now,bucketSeconds,windowSeconds,amount)
	local slot=math.floor(now/bucketSeconds)
	buckets[slot]=(buckets[slot] or 0)+amount
	local minimumSlot=math.floor((now-windowSeconds)/bucketSeconds)-1
	for key in pairs(buckets) do if key<minimumSlot then buckets[key]=nil end end
end

local function bucketSum(buckets,now,bucketSeconds,windowSeconds)
	local minimumSlot=math.floor((now-windowSeconds)/bucketSeconds)
	local total=0
	for slot,value in pairs(buckets) do
		if slot>=minimumSlot then total+=value else buckets[slot]=nil end
	end
	return total
end

local function newState(player)
	local rejected={}
	for _,reason in ipairs(REASONS) do rejected[reason]=0 end
	return {
		Player=player,
		Generation=0,
		CreatedClock=os.clock(),
		BaselinePosition=nil,
		BaselineClock=nil,
		Vehicle=nil,
		VehicleId="",
		SessionGeneration=nil,
		SessionId="",
		RunId="",
		AccumulatedCash=0,
		AcceptedStuds=0,
		GrantedCash=0,
		Rejected=rejected,
		CapBuckets=newBuckets(),
		ProjectionBuckets=newBuckets(),
		LastTelemetryClock=0,
		LastGrantClock=0,
		LastReason="BaselineReset",
		LastVehicleIdentity="",
		LastSessionIdentity="",
		GrantSequence=0,
	}
end

local function stateFor(player)
	local state=states[player]
	if not state then state=newState(player) states[player]=state end
	return state
end

local function rootPart(vehicle)
	if not vehicle then return nil end
	local root=vehicle.PrimaryPart or vehicle:FindFirstChild("CockpitRoot_DoNotRename",true)
	return root and root:IsA("BasePart") and root or nil
end

local function vehicleFromSeat(seat)
	local current=seat
	while current and current~=vehiclesRoot do
		if current:IsA("Model") and current.Parent==vehiclesRoot then return current end
		current=current.Parent
	end
	return nil
end

local function transitionReason(player)
	if player:GetAttribute("NTR_RaceBrowserTeleporting")==true
		or player:GetAttribute("NTR_FreeRoamHudTeleporting")==true then
		return "TeleportOrTransition"
	end
	if player:GetAttribute("NTR_GarageSessionActive")==true
		or player:GetAttribute("NTR_DriveInCustomisationActive")==true
		or player:GetAttribute("NTR_OwnedGarageInside")==true
		or player:GetAttribute("NTR_Phase21InPrivateGarage")==true then
		return "GarageTransition"
	end
	-- These are denial-only presentation/lifecycle guards. They never establish
	-- positive eligibility and therefore cannot author a payable sample.
	if player:GetAttribute("NTR_StartScreenActive")==true then return "LoadingTransition" end
	return nil
end

local function resolve(player)
	if player.Parent~=Players then return nil,"PlayerLifecycle" end
	if player:GetAttribute("NTR_ProfileServiceLoaded")~=true then return nil,"ProfileNotLoaded" end
	local transition=transitionReason(player)
	if transition then return nil,transition end
	local character=player.Character
	local humanoid=character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil,"NoCharacter" end
	local seat=humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat.Occupant==humanoid) then return nil,"Unseated" end
	local vehicle=vehicleFromSeat(seat)
	if not vehicle then return nil,"NotRuntimeVehicle" end
	local root=rootPart(vehicle)
	if not root or not root.Parent then return nil,"VehicleMissing" end
	if tonumber(vehicle:GetAttribute("OwnerUserId"))~=player.UserId
		or tonumber(vehicle:GetAttribute("DriverUserId"))~=player.UserId then
		return nil,"OwnershipMismatch"
	end
	local vehicleId=tostring(vehicle:GetAttribute("OwnedVehicleId") or "")
	if vehicleId=="" then return nil,"VehicleIdentityMismatch" end
	if vehicle:GetAttribute("DriveReady")~=true then return nil,"NotDriveReady" end
	if vehicle:GetAttribute("NTR_RaceFrozen")==true or root.Anchored then return nil,"FrozenOrStaging" end
	if vehicle:GetAttribute("ParkedShowcase")==true or vehicle:GetAttribute("NTR_ParkedFixed")==true then return nil,"Parked" end
	if vehicle:GetAttribute("NTR_ExitCoasting")==true then return nil,"ExitCoasting" end
	if vehicle:GetAttribute("NTR_RaceBrowserTeleportDespawn")==true
		or vehicle:GetAttribute("NTR_FreeRoamHudTeleportDespawn")==true then
		return nil,"TeleportOrTransition"
	end
	return {
		Player=player, Character=character, Humanoid=humanoid, Seat=seat,
		Vehicle=vehicle, Root=root, VehicleId=vehicleId,
		SessionGeneration=player:GetAttribute("NTR_ProfileSessionGeneration"),
		SessionId=tostring(player:GetAttribute("NTR_ProfileSessionId") or ""),
		RunId=tostring(vehicle:GetAttribute("NTR_RaceRunId") or ""),
	}
end

local function sameContext(a,b)
	return a and b
		and a.Player==b.Player and a.Character==b.Character and a.Humanoid==b.Humanoid
		and a.Seat==b.Seat and a.Vehicle==b.Vehicle and a.Root==b.Root
		and a.VehicleId==b.VehicleId and a.SessionGeneration==b.SessionGeneration
		and a.SessionId==b.SessionId and a.RunId==b.RunId
end

local function distanceFromBaseline(state,context)
	if not (state.BaselinePosition and context and context.Root and context.Root.Parent) then return 0 end
	local delta=context.Root.Position-state.BaselinePosition
	return Vector3.new(delta.X,0,delta.Z).Magnitude
end

local function reject(state,reason,studs,resetBaseline)
	reason=tostring(reason or "CashCommandRejected")
	state.Rejected[reason]=(state.Rejected[reason] or 0)+math.max(0,tonumber(studs) or 0)
	state.LastReason=reason
	if resetBaseline then
		state.Generation+=1
		state.BaselinePosition=nil
		state.BaselineClock=nil
		state.Vehicle=nil
		state.VehicleId=""
		state.RunId=""
	end
end

local function resetToContext(state,context,now,reason)
	reject(state,reason or "BaselineReset",0,true)
	state.BaselinePosition=context.Root.Position
	state.BaselineClock=now
	state.Vehicle=context.Vehicle
	state.VehicleId=context.VehicleId
	state.SessionGeneration=context.SessionGeneration
	state.SessionId=context.SessionId
	state.RunId=context.RunId
	state.LastVehicleIdentity=context.VehicleId.."|"..context.Vehicle:GetFullName().."|"..context.RunId
	state.LastSessionIdentity=tostring(context.SessionGeneration).."|"..context.SessionId
end

local function invokeEconomy(player,command)
	totalCommands+=1
	local ok,result=pcall(function() return executeEconomy:Invoke(player,command) end)
	if not ok then
		warn("[NTR Drive-To-Earn] ProfileService command error player="..player.Name.." error="..tostring(result))
		return {Ok=false,Success=false,RejectionReason="CashCommandRejected",Message=tostring(result)}
	end
	return typeof(result)=="table" and result
		or {Ok=false,Success=false,RejectionReason="CashCommandRejected",Message="Invalid command result."}
end

local function commandFor(context,action,amount,commandId)
	return {
		Version=1,
		Action=action,
		Amount=amount,
		Reason="DriveToEarnCash",
		ExpectedSessionGeneration=context.SessionGeneration,
		ExpectedSessionId=context.SessionId,
		Vehicle=context.Vehicle,
		VehicleId=context.VehicleId,
		RunId=context.RunId,
		CommandId=commandId,
	}
end

local function rejectionSummary(state)
	local rows={}
	for _,reason in ipairs(REASONS) do
		local value=state.Rejected[reason] or 0
		if value>0 then table.insert(rows,reason.."="..string.format("%.1f",value)) end
	end
	return #rows>0 and table.concat(rows,", ") or "none"
end

local function publishTelemetry(state,now,force)
	if not RunService:IsStudio() or config:GetAttribute("StudioTelemetryEnabled")~=true then return end
	local interval=number("TelemetryRefreshSeconds",2,0.5,30)
	if not force and now-state.LastTelemetryClock<interval then return end
	state.LastTelemetryClock=now
	local player=state.Player
	if player.Parent~=Players then return end
	local capWindow=number("CeilingWindowSeconds",3600,60,86400)
	local capBucket=number("CeilingBucketSeconds",60,1,capWindow)
	local cap=number("HourlyCashCeiling",35000,0,10000000)
	local capUsed=bucketSum(state.CapBuckets,now,capBucket,capWindow)
	local projectionWindow=number("ProjectionWindowSeconds",600,30,3600)
	local projectionBucket=number("ProjectionBucketSeconds",10,1,projectionWindow)
	local projectedStuds=bucketSum(state.ProjectionBuckets,now,projectionBucket,projectionWindow)
	local projectionElapsed=math.max(1,math.min(projectionWindow,now-state.CreatedClock))
	local projectedHourly=projectedStuds*number("CashPerAcceptedStud",0.10,0,10)*3600/projectionElapsed
	local currentElapsed=math.max(1,math.min(capWindow,now-state.CreatedClock))
	local currentHourly=capUsed*3600/currentElapsed
	player:SetAttribute("NTR_DriveCashTelemetryRevision",REVISION)
	player:SetAttribute("NTR_DriveCashAcceptedStuds",math.floor(state.AcceptedStuds*10+0.5)/10)
	player:SetAttribute("NTR_DriveCashRejectedStudsByReason",string.sub(rejectionSummary(state),1,900))
	player:SetAttribute("NTR_DriveCashAccumulatedUngranted",math.floor(state.AccumulatedCash*1000+0.5)/1000)
	player:SetAttribute("NTR_DriveCashGranted",state.GrantedCash)
	player:SetAttribute("NTR_DriveCashCurrentHourly",math.floor(currentHourly+0.5))
	player:SetAttribute("NTR_DriveCashProjectedHourly",math.floor(projectedHourly+0.5))
	player:SetAttribute("NTR_DriveCashCapUsage",cap>0 and math.floor((capUsed/cap)*1000+0.5)/10 or 0)
	player:SetAttribute("NTR_DriveCashCapUsed",capUsed)
	player:SetAttribute("NTR_DriveCashVehicleIdentity",string.sub(state.LastVehicleIdentity,1,240))
	player:SetAttribute("NTR_DriveCashSessionIdentity",string.sub(state.LastSessionIdentity,1,240))
	player:SetAttribute("NTR_DriveCashLastReason",state.LastReason)
end

local function processPlayer(player,now)
	totalSamples+=1
	local state=stateFor(player)
	local context,reason=resolve(player)
	if not context then
		reject(state,reason,0,true)
		publishTelemetry(state,now,false)
		return
	end

	local validation=invokeEconomy(player,commandFor(context,"ValidateDriveSample"))
	-- BindableFunction:Invoke is a yield boundary. Revalidate every lifecycle owner.
	local current,currentReason=resolve(player)
	if not sameContext(context,current) then
		reject(state,currentReason or "VehicleLifecycleChanged",distanceFromBaseline(state,current),true)
		publishTelemetry(state,now,false)
		return
	end
	if validation.Success~=true then
		reject(state,validation.RejectionReason or "CashCommandRejected",distanceFromBaseline(state,current),true)
		publishTelemetry(state,now,false)
		return
	end

	if state.Vehicle~=current.Vehicle or state.VehicleId~=current.VehicleId
		or state.SessionGeneration~=current.SessionGeneration or state.SessionId~=current.SessionId
		or state.RunId~=current.RunId or not state.BaselinePosition then
		resetToContext(state,current,now,"BaselineReset")
		publishTelemetry(state,now,false)
		return
	end

	local previousPosition=state.BaselinePosition
	local previousClock=state.BaselineClock or now
	local position=current.Root.Position
	local elapsed=now-previousClock
	state.BaselinePosition=position
	state.BaselineClock=now
	local delta=position-previousPosition
	local horizontal=Vector3.new(delta.X,0,delta.Z).Magnitude
	local vertical=math.abs(delta.Y)
	if elapsed<=0 or elapsed>number("MaximumSampleGapSeconds",2,0.25,10) then
		reject(state,"SampleGap",horizontal,true)
		publishTelemetry(state,now,false)
		return
	end
	if horizontal<number("MinimumAcceptedSegmentStuds",1,0,20) then
		reject(state,"Stationary",horizontal,false)
		publishTelemetry(state,now,false)
		return
	end
	local maxVertical=number("MaximumVerticalDeltaStuds",30,1,500)
	local maxRatio=number("MaximumVerticalToHorizontalRatio",1,0.1,10)
	if vertical>maxVertical or vertical/math.max(horizontal,0.001)>maxRatio then
		reject(state,"VerticalJump",horizontal,true)
		publishTelemetry(state,now,false)
		return
	end
	local maximumSegment=number("MaximumAcceptedSpeedStudsPerSecond",540,10,2000)*elapsed
		+ number("SegmentToleranceStuds",12,0,200)
	if horizontal>maximumSegment then
		reject(state,"ImplausibleSegment",horizontal,true)
		publishTelemetry(state,now,false)
		return
	end

	state.AcceptedStuds+=horizontal
	state.LastReason="Accepted"
	local projectionWindow=number("ProjectionWindowSeconds",600,30,3600)
	local projectionBucket=number("ProjectionBucketSeconds",10,1,projectionWindow)
	bucketAdd(state.ProjectionBuckets,now,projectionBucket,projectionWindow,horizontal)
	state.AccumulatedCash+=horizontal*number("CashPerAcceptedStud",0.10,0,10)

	local batch=math.max(1,math.floor(number("VisibleGrantBatchCash",1,1,10000)))
	local desired=math.floor(state.AccumulatedCash/batch)*batch
	local grantInterval=number("MinimumGrantIntervalSeconds",0.5,0.5,5)
	if desired>0 and now-state.LastGrantClock>=grantInterval then
		-- A $1 batch changes the visibility threshold, not the command count:
		-- all payable whole Cash is coalesced into at most one command per interval.
		state.LastGrantClock=now
		local capWindow=number("CeilingWindowSeconds",3600,60,86400)
		local capBucket=number("CeilingBucketSeconds",60,1,capWindow)
		local cap=math.max(0,math.floor(number("HourlyCashCeiling",35000,0,10000000)))
		local capUsed=bucketSum(state.CapBuckets,now,capBucket,capWindow)
		local maximumCommand=math.max(1,math.floor(number("MaximumDriveGrantPerCommand",1000,1,100000)))
		local available=math.max(0,cap-capUsed)
		local grant=math.min(desired,available,maximumCommand)
		grant=math.floor(grant/batch)*batch
		if grant<=0 then
			reject(state,"HourlyCap",0,false)
			state.AccumulatedCash=math.min(state.AccumulatedCash,batch-0.001)
		else
			state.AccumulatedCash-=grant
			state.GrantSequence+=1
			local commandId=table.concat({
				"Drive",tostring(current.SessionGeneration),current.SessionId,current.VehicleId,
				tostring(state.Generation),tostring(state.GrantSequence),
			},":")
			totalGrantCommands+=1
			local result=invokeEconomy(player,commandFor(current,"GrantDriveCash",grant,commandId))
			-- The commit call is another yield boundary. Revalidate before retaining
			-- a movement baseline, regardless of whether the commit succeeded.
			local after,afterReason=resolve(player)
			if result.Success==true then
				local committed=math.max(0,math.floor(tonumber(result.Amount) or 0))
				state.GrantedCash+=committed
				bucketAdd(state.CapBuckets,now,capBucket,capWindow,committed)
			else
				state.AccumulatedCash=math.min(state.AccumulatedCash+grant,batch-0.001)
				reject(state,result.RejectionReason or "CashCommandRejected",0,false)
			end
			if not sameContext(current,after) then
				reject(state,afterReason or "VehicleLifecycleChanged",0,true)
			end
		end
	end
	publishTelemetry(state,now,false)
end

local function clearTelemetry(player)
	for _,name in ipairs({
		"NTR_DriveCashTelemetryRevision","NTR_DriveCashAcceptedStuds",
		"NTR_DriveCashRejectedStudsByReason","NTR_DriveCashAccumulatedUngranted",
		"NTR_DriveCashGranted","NTR_DriveCashCurrentHourly",
		"NTR_DriveCashProjectedHourly","NTR_DriveCashCapUsage","NTR_DriveCashCapUsed",
		"NTR_DriveCashVehicleIdentity","NTR_DriveCashSessionIdentity","NTR_DriveCashLastReason",
	}) do player:SetAttribute(name,nil) end
end

Players.PlayerRemoving:Connect(function(player)
	states[player]=nil
end)

script:SetAttribute("Revision",REVISION)
script:SetAttribute("Authority","ServerDistance/ProfileServiceCash")
script:SetAttribute("NoClientPayableInputs",true)
script:SetAttribute("RuntimeAuditStatus","Starting")
activeLoopGeneration+=1
local loopGeneration=activeLoopGeneration
task.spawn(function()
	local nextAudit=os.clock()+number("RuntimeAuditIntervalSeconds",30,5,600)
	while not shuttingDown and loopGeneration==activeLoopGeneration do
		task.wait(number("SampleIntervalSeconds",0.5,0.1,5))
		local now=os.clock()
		if enabled() then
			for _,player in ipairs(Players:GetPlayers()) do processPlayer(player,now) end
		else
			for player,state in pairs(states) do
				reject(state,"LoadingTransition",0,true)
				publishTelemetry(state,now,false)
			end
		end
		if RunService:IsStudio() and now>=nextAudit then
			local count=0
			for _ in pairs(states) do count+=1 end
			script:SetAttribute("RuntimeAuditStatus","PASS")
			script:SetAttribute("ActivePlayerStates",count)
			script:SetAttribute("TotalSamples",totalSamples)
			script:SetAttribute("TotalProfileCommands",totalCommands)
			script:SetAttribute("TotalGrantCommands",totalGrantCommands)
			print(string.format(
				"[NTR Drive-To-Earn Runtime Audit] PASS players=%d samples=%d commands=%d grants=%d rate=%.4f batch=%d grantMaxHz=%.2f cap=%d/%ds noRemotes=true",
				count,totalSamples,totalCommands,totalGrantCommands,number("CashPerAcceptedStud",0.10,0,10),
				math.floor(number("VisibleGrantBatchCash",1,1,10000)),
				1/number("MinimumGrantIntervalSeconds",0.5,0.5,5),
				math.floor(number("HourlyCashCeiling",35000,0,10000000)),
				math.floor(number("CeilingWindowSeconds",3600,60,86400))))
			nextAudit=now+number("RuntimeAuditIntervalSeconds",30,5,600)
		end
	end
end)

game:BindToClose(function()
	shuttingDown=true
	activeLoopGeneration+=1
end)

if not RunService:IsStudio() then
	for _,player in ipairs(Players:GetPlayers()) do clearTelemetry(player) end
end
print("[NTR Drive-To-Earn] Service active; server-owned distance, ProfileService Cash command, rolling cap, and Studio-only telemetry ready.")
]==]

local TELEMETRY_SOURCE = [==[
-- NTR_DRIVE_TO_EARN_STUDIO_TELEMETRY_V1_1
-- Read-only Studio presentation. No GUI is created in a published server and no
-- remote or mutation control exists.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
if not RunService:IsStudio() then return end

local player=Players.LocalPlayer
local config=ReplicatedStorage:WaitForChild("NeoTokyoRacers")
	:WaitForChild("Config"):WaitForChild("Runtime"):WaitForChild("DriveToEarnCash_EditAttributes")
if config:GetAttribute("StudioTelemetryEnabled")~=true then return end
local playerGui=player:WaitForChild("PlayerGui")
local old=playerGui:FindFirstChild("NTR_DriveToEarnCashTelemetry")
if old then old:Destroy() end

local gui=Instance.new("ScreenGui")
gui.Name="NTR_DriveToEarnCashTelemetry"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.DisplayOrder=2000
gui.Parent=playerGui
local panel=Instance.new("Frame")
panel.Name="ReadOnlyPanel"
panel.AnchorPoint=Vector2.new(1,0)
panel.Position=UDim2.new(1,-12,0,12)
panel.Size=UDim2.fromOffset(470,286)
panel.BackgroundColor3=Color3.fromRGB(12,17,25)
panel.BackgroundTransparency=0.08
panel.BorderSizePixel=0
panel.Parent=gui
local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,8); corner.Parent=panel
local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(0,220,255); stroke.Thickness=1; stroke.Transparency=0.15; stroke.Parent=panel
local label=Instance.new("TextLabel")
label.Name="TelemetryText"
label.Position=UDim2.fromOffset(12,10)
label.Size=UDim2.new(1,-24,1,-20)
label.BackgroundTransparency=1
label.Font=Enum.Font.Code
label.TextSize=14
label.TextColor3=Color3.fromRGB(225,245,255)
label.TextXAlignment=Enum.TextXAlignment.Left
label.TextYAlignment=Enum.TextYAlignment.Top
label.TextWrapped=true
label.Parent=panel

local function value(name,fallback)
	local result=player:GetAttribute(name)
	return result==nil and fallback or result
end
local function update()
	if config:GetAttribute("StudioTelemetryEnabled")~=true then
		gui.Enabled=false
		return
	end
	gui.Enabled=true
	local camera=Workspace.CurrentCamera
	local viewport=camera and camera.ViewportSize or Vector2.new(1920,1080)
	panel.Size=UDim2.fromOffset(math.max(280,math.min(470,viewport.X-24)),math.max(240,math.min(286,viewport.Y-24)))
	label.TextSize=viewport.X<600 and 11 or 14
	label.Text=table.concat({
		"DRIVE-TO-EARN ECONOMY TELEMETRY  [STUDIO / READ ONLY]",
		"accepted studs:       "..tostring(value("NTR_DriveCashAcceptedStuds",0)),
		"rejected studs:       "..tostring(value("NTR_DriveCashRejectedStudsByReason","none")),
		"ungranted Cash:       $"..tostring(value("NTR_DriveCashAccumulatedUngranted",0)),
		"granted Cash:         $"..tostring(value("NTR_DriveCashGranted",0)),
		"current hourly:       $"..tostring(value("NTR_DriveCashCurrentHourly",0)),
		"projected hourly:     $"..tostring(value("NTR_DriveCashProjectedHourly",0)),
		"cap usage:            "..tostring(value("NTR_DriveCashCapUsage",0)).."%  ($"..tostring(value("NTR_DriveCashCapUsed",0))..")",
		"last sample:          "..tostring(value("NTR_DriveCashLastReason","waiting")),
		"vehicle/session:",
		"  "..tostring(value("NTR_DriveCashVehicleIdentity","none")),
		"  "..tostring(value("NTR_DriveCashSessionIdentity","none")),
	},"\n")
end
while gui.Parent do
	update()
	task.wait(0.25)
end
]==]

local function projectSources()
	local profileSource = profileService.Source
	local garageSource = garageAction.Source
	if countPlain(profileSource, PROFILE_MARKER) == 0 then
		profileSource = insertAfterOnce(profileSource, PROFILE_DECLARATION_ANCHOR, PROFILE_DECLARATION_INSERT,
			"ProfileService economy declaration")
		profileSource = insertAfterOnce(profileSource, PROFILE_LOCK_ANCHOR, PROFILE_LOCK_INSERT,
			"ProfileService economy lock")
		profileSource = insertBeforeOnce(profileSource, PROFILE_COMMAND_ANCHOR, PROFILE_COMMAND_BLOCK,
			"ProfileService economy command")
		profileSource = insertAfterOnce(profileSource, PROFILE_REMOVE_ANCHOR, PROFILE_REMOVE_INSERT,
			"ProfileService economy cleanup")
	elseif countPlain(profileSource, PROFILE_MARKER) < 4 then
		fail("ProfileService contains a partial economy-command install.")
	end

	if countPlain(garageSource, GARAGE_MARKER) == 0 then
		garageSource = replaceOnce(garageSource, ORIGINAL_GARAGE_BRIDGE, NEW_GARAGE_BRIDGE,
			"Garage positive-Cash bridge")
	elseif countPlain(garageSource, GARAGE_MARKER) ~= 1 then
		fail("Garage action controller contains an unexpected economy projection marker count.")
	end

	if countPlain(garageSource, VEHICLE_ID_MARKER) == 0 then
		garageSource = insertAfterOnce(garageSource, VEHICLE_ID_ANCHOR, VEHICLE_ID_INSERT,
			"Runtime owned vehicle identity")
	elseif countPlain(garageSource, VEHICLE_ID_MARKER) ~= 1 then
		fail("Garage action controller contains an unexpected runtime vehicle identity marker count.")
	end
	return profileSource, garageSource
end

local function audit()
	local blockers = {}
	local warnings = {}
	local function requireCheck(condition, message)
		if not condition then table.insert(blockers, message) end
	end
	local function warnCheck(condition, message)
		if not condition then table.insert(warnings, message) end
	end
	local config = runtimeConfig:FindFirstChild(CONFIG_NAME)
	local service = vehicleServices:FindFirstChild(SERVICE_NAME)
	local debugFolder = controllers:FindFirstChild("Debug")
	local telemetry = debugFolder and debugFolder:FindFirstChild(TELEMETRY_NAME)
	requireCheck(config and config:IsA("Folder"), "Config.Runtime." .. CONFIG_NAME .. " is missing.")
	requireCheck(service and service:IsA("Script") and not service.Disabled, SERVICE_NAME .. " is missing or disabled.")
	requireCheck(telemetry and telemetry:IsA("LocalScript") and not telemetry.Disabled,
		TELEMETRY_NAME .. " is missing or disabled.")
	requireCheck(countPlain(profileService.Source, PROFILE_MARKER) >= 4,
		"ProfileService economy command markers are incomplete.")
	requireCheck(countPlain(garageAction.Source, GARAGE_MARKER) == 1,
		"Garage committed-Cash projection marker is missing.")
	requireCheck(countPlain(garageAction.Source, VEHICLE_ID_MARKER) == 1,
		"Runtime owned vehicle ID marker is missing.")
	requireCheck(service and countPlain(service.Source, SERVICE_MARKER) == 1,
		"Drive-to-earn service source marker is missing.")
	requireCheck(telemetry and countPlain(telemetry.Source, TELEMETRY_MARKER) == 1,
		"Studio telemetry source marker is missing.")
	if config then
		for name, expected in pairs(CONFIG_DEFAULTS) do
			requireCheck(config:GetAttribute(name) ~= nil, "Config attribute " .. name .. " is missing.")
			if name == "CashPerAcceptedStud" then
				warnCheck(math.abs((tonumber(config:GetAttribute(name)) or 0) - expected) < 0.000001,
					name .. " is tuned away from the approved V1.1 $1/10-stud baseline.")
			end
		end
		requireCheck(config:GetAttribute("Revision") == REVISION, "Config revision is not " .. REVISION .. ".")
	end
	requireCheck(profileService:GetAttribute("DriveToEarnEconomyRevision") == REVISION,
		"ProfileService revision attribute is missing.")
	requireCheck(garageAction:GetAttribute("DriveToEarnEconomyRevision") == REVISION,
		"Garage action revision attribute is missing.")
	requireCheck(service and service:GetAttribute("Revision") == REVISION,
		"Service revision attribute is missing.")
	requireCheck(telemetry and telemetry:GetAttribute("Revision") == REVISION,
		"Telemetry revision attribute is missing.")
	requireCheck(service and not string.find(service.Source, "OnServerEvent", 1, true),
		"Drive-to-earn service must not accept a client remote.")
	if #blockers > 0 then
		for _,message in ipairs(blockers) do warn("[" .. PHASE .. "] BLOCKER " .. message) end
		fail("AUDIT FAIL blockers=" .. tostring(#blockers) .. " warnings=" .. tostring(#warnings))
	end
	for _,message in ipairs(warnings) do warn("[" .. PHASE .. "] WARN " .. message) end
	log(string.format(
		"AUDIT PASS owner=DriveToEarnCashService_Active cashOwner=ProfileService.ExecuteEconomyCommand rate=%.4f batch=%d cap=%d/%ds sample=%.2fs grantMaxHz=%.2f telemetry=StudioOnly warnings=%d",
		tonumber(config:GetAttribute("CashPerAcceptedStud")) or 0,
		math.floor(tonumber(config:GetAttribute("VisibleGrantBatchCash")) or 0),
		math.floor(tonumber(config:GetAttribute("HourlyCashCeiling")) or 0),
		math.floor(tonumber(config:GetAttribute("CeilingWindowSeconds")) or 0),
		tonumber(config:GetAttribute("SampleIntervalSeconds")) or 0,
		1 / math.max(0.5, tonumber(config:GetAttribute("MinimumGrantIntervalSeconds")) or 0.5),
		#warnings))
end

local function rollback()
	local profileSource = profileService.Source
	local garageSource = garageAction.Source
	if countPlain(profileSource, PROFILE_MARKER) > 0 then
		profileSource = replaceOnce(profileSource, PROFILE_DECLARATION_INSERT, "", "Rollback ProfileService declaration")
		profileSource = replaceOnce(profileSource, PROFILE_LOCK_INSERT, "", "Rollback ProfileService lock")
		profileSource = replaceOnce(profileSource, PROFILE_COMMAND_BLOCK, "", "Rollback ProfileService command")
		profileSource = replaceOnce(profileSource, PROFILE_REMOVE_INSERT, "", "Rollback ProfileService cleanup")
	end
	if countPlain(garageSource, GARAGE_MARKER) > 0 then
		garageSource = replaceOnce(garageSource, NEW_GARAGE_BRIDGE, ORIGINAL_GARAGE_BRIDGE,
			"Rollback garage Cash bridge")
	end
	if countPlain(garageSource, VEHICLE_ID_MARKER) > 0 then
		garageSource = replaceOnce(garageSource, VEHICLE_ID_INSERT, "", "Rollback runtime vehicle identity")
	end
	compile(profileSource, "ProfileService rollback")
	compile(garageSource, "Garage action rollback")
	profileService.Source = profileSource
	garageAction.Source = garageSource
	profileService:SetAttribute("DriveToEarnEconomyRevision", nil)
	garageAction:SetAttribute("DriveToEarnEconomyRevision", nil)
	local service = vehicleServices:FindFirstChild(SERVICE_NAME)
	if service and supportedRevision(service:GetAttribute("Revision")) then service:Destroy() end
	local debugFolder = controllers:FindFirstChild("Debug")
	local telemetry = debugFolder and debugFolder:FindFirstChild(TELEMETRY_NAME)
	if telemetry and supportedRevision(telemetry:GetAttribute("Revision")) then telemetry:Destroy() end
	local config = runtimeConfig:FindFirstChild(CONFIG_NAME)
	if config and supportedRevision(config:GetAttribute("Revision")) then config:Destroy() end
	ChangeHistoryService:SetWaypoint(PHASE .. " rollback")
	log("ROLLBACK PASS. Restart Studio/Play. Previously committed Cash is intentionally unchanged.")
end

if MODE == "AUDIT" then
	audit()
	return
elseif MODE == "ROLLBACK" then
	rollback()
	return
elseif MODE ~= "INSTALL" then
	fail("Unknown MODE " .. tostring(MODE))
end

compile(SERVICE_SOURCE, SERVICE_NAME)
compile(TELEMETRY_SOURCE, TELEMETRY_NAME)
local projectedProfile, projectedGarage = projectSources()
compile(projectedProfile, "ProfileService projected")
compile(projectedGarage, "Garage action projected")

local existingConfig = runtimeConfig:FindFirstChild(CONFIG_NAME)
if existingConfig and (not existingConfig:IsA("Folder") or not supportedRevision(existingConfig:GetAttribute("Revision"))) then
	fail(existingConfig:GetFullName() .. " already exists outside this installer revision.")
end
local existingService = vehicleServices:FindFirstChild(SERVICE_NAME)
if existingService and (not existingService:IsA("Script") or not supportedRevision(existingService:GetAttribute("Revision"))) then
	fail(existingService:GetFullName() .. " already exists outside this installer revision.")
end
local debugFolder = controllers:FindFirstChild("Debug")
if debugFolder and not debugFolder:IsA("Folder") then fail(debugFolder:GetFullName() .. " must be a Folder.") end
local existingTelemetry = debugFolder and debugFolder:FindFirstChild(TELEMETRY_NAME)
if existingTelemetry and (not existingTelemetry:IsA("LocalScript")
	or not supportedRevision(existingTelemetry:GetAttribute("Revision"))) then
	fail(existingTelemetry:GetFullName() .. " already exists outside this installer revision.")
end
if existingConfig then
	local baselineRevision = existingConfig:GetAttribute("Revision")
	if not existingService or not existingTelemetry then
		fail("Detected a partial existing drive-to-earn install. Refresh/inspect the live mirror; do not repair around it.")
	end
	if profileService:GetAttribute("DriveToEarnEconomyRevision") ~= baselineRevision
		or garageAction:GetAttribute("DriveToEarnEconomyRevision") ~= baselineRevision
		or existingService:GetAttribute("Revision") ~= baselineRevision
		or existingTelemetry:GetAttribute("Revision") ~= baselineRevision then
		fail("Existing drive-to-earn revision attributes disagree. Refresh/inspect the live mirror.")
	end
	local expectedServiceMarker = baselineRevision == REVISION and SERVICE_MARKER or PREVIOUS_SERVICE_MARKER
	local expectedTelemetryMarker = baselineRevision == REVISION and TELEMETRY_MARKER or PREVIOUS_TELEMETRY_MARKER
	if countPlain(existingService.Source, expectedServiceMarker) ~= 1
		or countPlain(existingTelemetry.Source, expectedTelemetryMarker) ~= 1 then
		fail("Existing drive-to-earn source markers do not match the installed revision.")
	end
elseif existingService or existingTelemetry then
	fail("Drive-to-earn service/telemetry exists without its canonical config. Refresh/inspect the live mirror.")
end

local existingDescriptions = existingConfig and existingConfig:FindFirstChild("Descriptions")
local descriptionSnapshot = {}
if existingDescriptions then
	if not existingDescriptions:IsA("Folder") then fail(existingDescriptions:GetFullName() .. " must be a Folder.") end
	for _,item in ipairs(existingDescriptions:GetChildren()) do
		if item:IsA("StringValue") then descriptionSnapshot[item.Name] = item.Value end
	end
end

local snapshot = {
	ProfileSource = profileService.Source,
	GarageSource = garageAction.Source,
	ProfileRevision = profileService:GetAttribute("DriveToEarnEconomyRevision"),
	GarageRevision = garageAction:GetAttribute("DriveToEarnEconomyRevision"),
	ConfigExisted = existingConfig ~= nil,
	ServiceExisted = existingService ~= nil,
	DebugExisted = debugFolder ~= nil,
	TelemetryExisted = existingTelemetry ~= nil,
	ConfigRevision = existingConfig and existingConfig:GetAttribute("Revision") or nil,
	ServiceSource = existingService and existingService.Source or nil,
	ServiceDisabled = existingService and existingService.Disabled or nil,
	ServiceRevision = existingService and existingService:GetAttribute("Revision") or nil,
	TelemetrySource = existingTelemetry and existingTelemetry.Source or nil,
	TelemetryDisabled = existingTelemetry and existingTelemetry.Disabled or nil,
	TelemetryRevision = existingTelemetry and existingTelemetry:GetAttribute("Revision") or nil,
	ConfigCashPerAcceptedStud = existingConfig and existingConfig:GetAttribute("CashPerAcceptedStud") or nil,
	ConfigVisibleGrantBatchCash = existingConfig and existingConfig:GetAttribute("VisibleGrantBatchCash") or nil,
	ConfigMinimumGrantIntervalSeconds = existingConfig and existingConfig:GetAttribute("MinimumGrantIntervalSeconds") or nil,
	ConfigBalanceReferenceAverageStudsPerSecond = existingConfig and existingConfig:GetAttribute("BalanceReferenceAverageStudsPerSecond") or nil,
	ConfigBalanceReferenceAverageMph = existingConfig and existingConfig:GetAttribute("BalanceReferenceAverageMph") or nil,
	DescriptionsExisted = existingDescriptions ~= nil,
	DescriptionValues = descriptionSnapshot,
}
local ok, problem = pcall(function()
	-- V1.1 does not rewrite the large established owners when their V1 authority
	-- blocks are already installed; only a fresh V1 install assigns them.
	if profileService.Source ~= projectedProfile then profileService.Source = projectedProfile end
	if garageAction.Source ~= projectedGarage then garageAction.Source = projectedGarage end
	profileService:SetAttribute("DriveToEarnEconomyRevision", REVISION)
	garageAction:SetAttribute("DriveToEarnEconomyRevision", REVISION)

	local config = existingConfig
	if not config then
		config = Instance.new("Folder")
		config.Name = CONFIG_NAME
		config.Parent = runtimeConfig
	end
	local upgradingFromV1 = config:GetAttribute("Revision") == PREVIOUS_REVISION
	for name, value in pairs(CONFIG_DEFAULTS) do
		if config:GetAttribute(name) == nil then config:SetAttribute(name, value) end
		setDescription(config, name, CONFIG_DESCRIPTIONS[name])
	end
	if upgradingFromV1 then
		-- These are the two explicitly approved V1 -> V1.1 balance changes.
		-- Other designer tuning survives the upgrade.
		config:SetAttribute("CashPerAcceptedStud", CONFIG_DEFAULTS.CashPerAcceptedStud)
		config:SetAttribute("VisibleGrantBatchCash", CONFIG_DEFAULTS.VisibleGrantBatchCash)
		config:SetAttribute("MinimumGrantIntervalSeconds", CONFIG_DEFAULTS.MinimumGrantIntervalSeconds)
	end
	config:SetAttribute("Revision", REVISION)
	config:SetAttribute("Owner", "DriveToEarnCashService_Active")
	config:SetAttribute("BalanceTargetCashPerHour", 25000)
	config:SetAttribute("BalanceReferenceAverageStudsPerSecond", 69.444444)
	config:SetAttribute("BalanceReferenceAverageMph", 43.402778)

	local service = existingService
	if not service then
		service = Instance.new("Script")
		service.Name = SERVICE_NAME
		service.Parent = vehicleServices
	end
	service.Source = SERVICE_SOURCE
	service.Disabled = false
	service:SetAttribute("Revision", REVISION)
	service:SetAttribute("CanonicalDistanceOwner", true)
	service:SetAttribute("CanonicalCashCommand", "ProfileServiceBindings.ExecuteEconomyCommand")

	if not debugFolder then
		debugFolder = Instance.new("Folder")
		debugFolder.Name = "Debug"
		debugFolder.Parent = controllers
	end
	local telemetry = existingTelemetry
	if not telemetry then
		telemetry = Instance.new("LocalScript")
		telemetry.Name = TELEMETRY_NAME
		telemetry.Parent = debugFolder
	end
	telemetry.Source = TELEMETRY_SOURCE
	telemetry.Disabled = false
	telemetry:SetAttribute("Revision", REVISION)
	telemetry:SetAttribute("StudioOnly", true)

	audit()
end)

if not ok then
	profileService.Source = snapshot.ProfileSource
	garageAction.Source = snapshot.GarageSource
	profileService:SetAttribute("DriveToEarnEconomyRevision", snapshot.ProfileRevision)
	garageAction:SetAttribute("DriveToEarnEconomyRevision", snapshot.GarageRevision)
	if not snapshot.ServiceExisted then
		local item = vehicleServices:FindFirstChild(SERVICE_NAME)
		if item then item:Destroy() end
	elseif existingService then
		existingService.Source = snapshot.ServiceSource
		existingService.Disabled = snapshot.ServiceDisabled
		existingService:SetAttribute("Revision", snapshot.ServiceRevision)
	end
	if not snapshot.TelemetryExisted and debugFolder then
		local item = debugFolder:FindFirstChild(TELEMETRY_NAME)
		if item then item:Destroy() end
	elseif existingTelemetry then
		existingTelemetry.Source = snapshot.TelemetrySource
		existingTelemetry.Disabled = snapshot.TelemetryDisabled
		existingTelemetry:SetAttribute("Revision", snapshot.TelemetryRevision)
	end
	if not snapshot.DebugExisted and debugFolder and #debugFolder:GetChildren() == 0 then debugFolder:Destroy() end
	if not snapshot.ConfigExisted then
		local item = runtimeConfig:FindFirstChild(CONFIG_NAME)
		if item then item:Destroy() end
	elseif existingConfig then
		existingConfig:SetAttribute("Revision", snapshot.ConfigRevision)
		-- V1.1 mutates only these approved tuning attributes during an upgrade.
		existingConfig:SetAttribute("CashPerAcceptedStud", snapshot.ConfigCashPerAcceptedStud)
		existingConfig:SetAttribute("VisibleGrantBatchCash", snapshot.ConfigVisibleGrantBatchCash)
		existingConfig:SetAttribute("MinimumGrantIntervalSeconds", snapshot.ConfigMinimumGrantIntervalSeconds)
		existingConfig:SetAttribute("BalanceReferenceAverageStudsPerSecond", snapshot.ConfigBalanceReferenceAverageStudsPerSecond)
		existingConfig:SetAttribute("BalanceReferenceAverageMph", snapshot.ConfigBalanceReferenceAverageMph)
		local descriptions = existingConfig:FindFirstChild("Descriptions")
		if descriptions then
			for name in pairs(CONFIG_DESCRIPTIONS) do
				local item = descriptions:FindFirstChild(name)
				local oldValue = snapshot.DescriptionValues[name]
				if item and oldValue ~= nil then
					item.Value = oldValue
				elseif item and oldValue == nil then
					item:Destroy()
				end
			end
			if not snapshot.DescriptionsExisted and #descriptions:GetChildren() == 0 then descriptions:Destroy() end
		end
	end
	fail("INSTALL ROLLED BACK: " .. tostring(problem))
end

ChangeHistoryService:SetWaypoint(PHASE .. " install")
log("INSTALL PASS. Restart Play. Require the runtime audit PASS and complete the High-Risk verification matrix before confirmation.")
