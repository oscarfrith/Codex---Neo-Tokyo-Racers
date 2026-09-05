-- Cash command owner; ProfileServer provides the current authoritative session.
local EconomyServer = {}
function EconomyServer.init(context)
local ntr = context.ntr
local sessionFor = context.sessionFor
local economyCommandLocks = context.economyCommandLocks
local updateRuntimeMarker = context.updateRuntimeMarker
local executeEconomyCommandBinding = context.executeEconomyCommandBinding
local economyCashCommittedEvent = context.economyCashCommittedEvent
local warnLine = context.warnLine
local Players = context.Players
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
		session.Revision += 1
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


end
return EconomyServer
