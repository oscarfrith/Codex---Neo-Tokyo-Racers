-- NTR Persistence Phase 23 Same-Server Garage Visits
-- Dual-mode Studio Command Bar script.
--
-- Edit mode:
--   Adds same-server access mode and visit actions to GarageInteriorService_Active.
--
-- Play mode, CLIENT Command Bar:
--   Smoke-checks SetAccessMode, VisitGarage, GetState, and ReturnToCity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local TAG = "[NTR Persistence Phase 23 Same-Server Garage Visits]"

local function info(message)
	print(TAG .. " " .. tostring(message))
end

local function waitForPath(root, names)
	local current = root
	for _, name in ipairs(names) do
		current = current:WaitForChild(name)
	end
	return current
end

local function replaceOnce(source, oldText, newText, label)
	if newText ~= "" and string.find(source, newText, 1, true) then
		return source
	end
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	assert(startIndex, "Could not find source anchor for " .. label)
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1)
end

local function tryReplaceOnce(source, oldText, newText)
	if newText ~= "" and string.find(source, newText, 1, true) then
		return source, true
	end
	local startIndex, endIndex = string.find(source, oldText, 1, true)
	if not startIndex then
		return source, false
	end
	return string.sub(source, 1, startIndex - 1) .. newText .. string.sub(source, endIndex + 1), true
end

local function insertAfterOnce(source, anchorText, insertText, label, searchStart)
	searchStart = searchStart or 1
	local startIndex, endIndex = string.find(source, anchorText, searchStart, true)
	assert(startIndex, "Could not find source anchor for " .. label)
	if string.find(source, insertText, 1, true) then
		return source
	end
	return string.sub(source, 1, endIndex) .. insertText .. string.sub(source, endIndex + 1)
end

local function insertBeforeOnce(source, anchorText, insertText, label, searchStart)
	searchStart = searchStart or 1
	local startIndex = string.find(source, anchorText, searchStart, true)
	assert(startIndex, "Could not find source anchor for " .. label)
	if string.find(source, insertText, 1, true) then
		return source
	end
	return string.sub(source, 1, startIndex - 1) .. insertText .. string.sub(source, startIndex)
end

local function replaceBetween(source, startText, endText, replacementText, label)
	local startIndex = string.find(source, startText, 1, true)
	assert(startIndex, "Could not find source start anchor for " .. label)
	local endIndex = string.find(source, endText, startIndex, true)
	assert(endIndex, "Could not find source end anchor for " .. label)
	return string.sub(source, 1, startIndex - 1) .. replacementText .. string.sub(source, endIndex)
end

if RunService:IsRunning() then
	local player = Players.LocalPlayer
	assert(player, "Run this smoke from the CLIENT Command Bar during Play.")

	local remotes = waitForPath(ReplicatedStorage, { "NeoTokyoRacers", "Shared", "Remotes", "Garage" })
	local garageInvoke = remotes:WaitForChild("GarageInvoke")
	local interiorInvoke = remotes:WaitForChild("GarageInteriorInvoke")

	local initial = garageInvoke:InvokeServer("GetInitial", {})
	assert(type(initial) == "table" and initial.Profile ~= nil, "Garage GetInitial failed before visit smoke.")
	info("Garage GetInitial OK before visit smoke.")

	local setPublic = interiorInvoke:InvokeServer("SetAccessMode", { AccessMode = "Public" })
	assert(type(setPublic) == "table" and setPublic.Ok == true, "SetAccessMode Public failed: " .. tostring(setPublic and setPublic.Error))
	info("SetAccessMode OK. mode=" .. tostring(setPublic.AccessMode))

	local visit = interiorInvoke:InvokeServer("VisitGarage", { OwnerUserId = player.UserId })
	assert(type(visit) == "table" and visit.Ok == true, "VisitGarage failed: " .. tostring(visit and visit.Error))
	info("VisitGarage OK. owner=" .. tostring(visit.OwnerUserId) .. " mode=" .. tostring(visit.AccessMode) .. " displayOk=" .. tostring(visit.DisplayOk))

	task.wait(1.25)

	local state = interiorInvoke:InvokeServer("GetState", {})
	assert(type(state) == "table" and state.Ok == true, "GetState failed: " .. tostring(state and state.Error))
	assert(state.VisitingOwnerUserId == player.UserId, "Expected VisitingOwnerUserId to match local player in self-visit smoke.")
	info("State InGarage=" .. tostring(state.InGarage) .. " visitingOwner=" .. tostring(state.VisitingOwnerUserId) .. " accessMode=" .. tostring(state.AccessMode) .. " displayExists=" .. tostring(state.DisplayExists))

	local returned = interiorInvoke:InvokeServer("ReturnToCity", { Smoke = true, Phase23 = true })
	assert(type(returned) == "table" and returned.Ok == true, "ReturnToCity failed: " .. tostring(returned and returned.Error))
	info("ReturnToCity OK. returnSource=" .. tostring(returned.ReturnSource))

	local setPrivate = interiorInvoke:InvokeServer("SetAccessMode", { AccessMode = "Private" })
	assert(type(setPrivate) == "table" and setPrivate.Ok == true, "SetAccessMode Private cleanup failed: " .. tostring(setPrivate and setPrivate.Error))
	info("Cleanup SetAccessMode OK. mode=" .. tostring(setPrivate.AccessMode))
	info("Expected: same-server garage access actions are live. Multi-player manual check can set Public/FriendsOnly/InviteOnly and have another player visit by owner UserId.")
	return
end

local services = ServerScriptService:WaitForChild("NeoTokyoRacers"):WaitForChild("Services")
local garageServices = services:WaitForChild("Garage")
local interiorService = garageServices:WaitForChild("GarageInteriorService_Active")
assert(interiorService:IsA("Script"), "Expected GarageInteriorService_Active before Phase 23.")
assert(string.find(interiorService.Source, "NTR_PERSISTENCE_PHASE22_REFRESH_DISPLAY", 1, true), "Expected Phase 22 display refresh before Phase 23.")

local source = interiorService.Source

source = replaceOnce(
	source,
	[=[local activeSlotsByUserId = {}
local returnCFramesByUserId = {}
local promptConnections = {}]=],
	[=[local activeSlotsByUserId = {}
local returnCFramesByUserId = {}
local promptConnections = {}
-- NTR_PERSISTENCE_PHASE23_GARAGE_VISITS_STATE
local garageInvitesByOwnerUserId = {}]=],
	"Phase 23 visit state"
)

local promptPatched
source, promptPatched = tryReplaceOnce(
	source,
	[=[			if triggeringPlayer == player then
				local ok, err = pcall(function()
					invoke.OnServerInvoke(triggeringPlayer, "ReturnToCity", { Source = "Prompt" })
				end)
				if not ok then
					warn(TAG .. " Return prompt failed: " .. tostring(err))
				end
			end]=],
	[=[			if triggeringPlayer then
				local ok, err = pcall(function()
					invoke.OnServerInvoke(triggeringPlayer, "ReturnToCity", { Source = "Prompt" })
				end)
				if not ok then
					warn(TAG .. " Return prompt failed: " .. tostring(err))
				end
			end]=]
)
if not promptPatched then
	info("Return prompt widening anchor not found; continuing with remote ReturnToCity support. Manual visitor prompt return can be repaired later if needed.")
end

if not string.find(source, 'player:SetAttribute("NTR_Phase23VisitingGarageOwnerUserId", nil)', 1, true) then
	source = insertAfterOnce(
		source,
		[=[	player:SetAttribute("NTR_Phase21InPrivateGarage", false)]=],
		[=[
	player:SetAttribute("NTR_Phase23VisitingGarageOwnerUserId", nil)
	player:SetAttribute("NTR_Phase23VisitAccessMode", nil)]=],
		"Phase 23 return clears visit attributes"
	)
end

-- Backward-compatible exact replacement retained for older unpatched service text.
source, _ = tryReplaceOnce(
	source,
	[=[	player:SetAttribute("NTR_Phase21InPrivateGarage", false)
	transition:FireClient(player, { Step = "Stream", Label = "Loading city", Position = cframe.Position })]=],
	[=[	player:SetAttribute("NTR_Phase21InPrivateGarage", false)
	player:SetAttribute("NTR_Phase23VisitingGarageOwnerUserId", nil)
	player:SetAttribute("NTR_Phase23VisitAccessMode", nil)
	transition:FireClient(player, { Step = "Stream", Label = "Loading city", Position = cframe.Position })]=]
)

local visitFunctions = [=[

-- NTR_PERSISTENCE_PHASE23_GARAGE_VISITS
local VALID_ACCESS_MODES = {
	Private = true,
	FriendsOnly = true,
	InviteOnly = true,
	Public = true,
}

local function validAccessMode(value)
	value = tostring(value or "Private")
	if VALID_ACCESS_MODES[value] then
		return value
	end
	return nil
end

local function setAccessMode(player, payload)
	local mode = validAccessMode(payload and payload.AccessMode)
	if not mode then
		return { Ok = false, Error = "InvalidAccessMode" }
	end
	local model = ensureInterior(player)
	model:SetAttribute("AccessMode", mode)
	player:SetAttribute("NTR_Phase23GarageAccessMode", mode)
	return {
		Ok = true,
		AccessMode = mode,
		InteriorId = model.Name,
	}
end

local function inviteVisitor(player, payload)
	local targetUserId = tonumber(payload and payload.UserId)
	if not targetUserId then
		return { Ok = false, Error = "MissingUserId" }
	end
	local ownerUserId = player.UserId
	garageInvitesByOwnerUserId[ownerUserId] = garageInvitesByOwnerUserId[ownerUserId] or {}
	garageInvitesByOwnerUserId[ownerUserId][targetUserId] = true
	return {
		Ok = true,
		OwnerUserId = ownerUserId,
		UserId = targetUserId,
	}
end

local function isInvited(ownerUserId, visitorUserId)
	local inviteSet = garageInvitesByOwnerUserId[ownerUserId]
	return inviteSet and inviteSet[visitorUserId] == true
end

local function canVisitGarage(visitor, owner, model)
	if visitor == owner then
		return true, "Owner"
	end
	local mode = tostring(model:GetAttribute("AccessMode") or "Private")
	if mode == "Public" then
		return true, "Public"
	elseif mode == "FriendsOnly" then
		local ok, result = pcall(function()
			return visitor:IsFriendsWith(owner.UserId)
		end)
		return ok and result == true, "FriendsOnly"
	elseif mode == "InviteOnly" then
		return isInvited(owner.UserId, visitor.UserId), "InviteOnly"
	end
	return false, "Private"
end

local function visitGarage(player, payload)
	local ownerUserId = tonumber(payload and payload.OwnerUserId)
	if not ownerUserId then
		return { Ok = false, Error = "MissingOwnerUserId" }
	end
	-- NTR_PERSISTENCE_PHASE23_OWNER_LOOKUP_INLINE
	local owner = nil
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.UserId == ownerUserId then
			owner = candidate
			break
		end
	end
	if not owner then
		return { Ok = false, Error = "OwnerNotInServer" }
	end

	local model = ensureInterior(owner)
	local allowed, accessReason = canVisitGarage(player, owner, model)
	if not allowed then
		return {
			Ok = false,
			Error = "AccessDenied",
			AccessMode = tostring(model:GetAttribute("AccessMode") or "Private"),
			AccessReason = accessReason,
		}
	end

	local root = getCharacterRoot(player)
	if root then
		returnCFramesByUserId[player.UserId] = root.CFrame
	else
		returnCFramesByUserId[player.UserId] = fallbackCityCFrame(player)
	end

	local displayResult = GarageDisplayRuntime.RefreshDisplayVehicle(owner, model)
	local spawn = model:FindFirstChild("GarageSpawnPoint", true)
	if not spawn or not spawn:IsA("BasePart") then
		return { Ok = false, Error = "MissingGarageSpawnPoint" }
	end

	transition:FireClient(player, { Step = "FadeOut", Label = player == owner and "Entering garage" or "Visiting garage" })
	task.wait(0.15)
	local ok, err = teleportCharacter(player, spawn.CFrame * CFrame.new(0, 4, 0))
	if not ok then
		return { Ok = false, Error = err }
	end

	local mode = tostring(model:GetAttribute("AccessMode") or "Private")
	player:SetAttribute("NTR_Phase21InPrivateGarage", true)
	player:SetAttribute("NTR_Phase21GarageInteriorId", model.Name)
	player:SetAttribute("NTR_Phase21GarageAccessMode", mode)
	player:SetAttribute("NTR_Phase23VisitingGarageOwnerUserId", owner.UserId)
	player:SetAttribute("NTR_Phase23VisitAccessMode", mode)
	transition:FireClient(player, { Step = "Stream", Label = "Loading garage", Position = spawn.Position })

	return {
		Ok = true,
		InteriorId = model.Name,
		OwnerUserId = owner.UserId,
		AccessMode = mode,
		AccessReason = accessReason,
		DisplayOk = typeof(displayResult) == "table" and displayResult.Ok == true,
		DisplayName = typeof(displayResult) == "table" and displayResult.DisplayName or nil,
		DisplayError = typeof(displayResult) == "table" and displayResult.Error or nil,
	}
end
]=]

if not string.find(source, "NTR_PERSISTENCE_PHASE23_GARAGE_VISITS", 1, true) then
	source = insertAfterOnce(
		source,
		[=[end

local function connectEntryPrompt()]=],
		visitFunctions,
		"Phase 23 visit functions"
	)
end

if not string.find(source, "NTR_PERSISTENCE_PHASE23_OWNER_LOOKUP_INLINE", 1, true) then
	local robustVisitGarage = [=[local function visitGarage(player, payload)
	local ownerUserId = tonumber(payload and payload.OwnerUserId)
	if not ownerUserId then
		return { Ok = false, Error = "MissingOwnerUserId" }
	end
	-- NTR_PERSISTENCE_PHASE23_OWNER_LOOKUP_INLINE
	local owner = nil
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.UserId == ownerUserId then
			owner = candidate
			break
		end
	end
	if not owner then
		return { Ok = false, Error = "OwnerNotInServer" }
	end

	local model = ensureInterior(owner)
	local allowed, accessReason = canVisitGarage(player, owner, model)
	if not allowed then
		return {
			Ok = false,
			Error = "AccessDenied",
			AccessMode = tostring(model:GetAttribute("AccessMode") or "Private"),
			AccessReason = accessReason,
		}
	end

	local root = getCharacterRoot(player)
	if root then
		returnCFramesByUserId[player.UserId] = root.CFrame
	else
		returnCFramesByUserId[player.UserId] = fallbackCityCFrame(player)
	end

	local displayResult = GarageDisplayRuntime.RefreshDisplayVehicle(owner, model)
	local spawn = model:FindFirstChild("GarageSpawnPoint", true)
	if not spawn or not spawn:IsA("BasePart") then
		return { Ok = false, Error = "MissingGarageSpawnPoint" }
	end

	transition:FireClient(player, { Step = "FadeOut", Label = player == owner and "Entering garage" or "Visiting garage" })
	task.wait(0.15)
	local ok, err = teleportCharacter(player, spawn.CFrame * CFrame.new(0, 4, 0))
	if not ok then
		return { Ok = false, Error = err }
	end

	local mode = tostring(model:GetAttribute("AccessMode") or "Private")
	player:SetAttribute("NTR_Phase21InPrivateGarage", true)
	player:SetAttribute("NTR_Phase21GarageInteriorId", model.Name)
	player:SetAttribute("NTR_Phase21GarageAccessMode", mode)
	player:SetAttribute("NTR_Phase23VisitingGarageOwnerUserId", owner.UserId)
	player:SetAttribute("NTR_Phase23VisitAccessMode", mode)
	transition:FireClient(player, { Step = "Stream", Label = "Loading garage", Position = spawn.Position })

	return {
		Ok = true,
		InteriorId = model.Name,
		OwnerUserId = owner.UserId,
		AccessMode = mode,
		AccessReason = accessReason,
		DisplayOk = typeof(displayResult) == "table" and displayResult.Ok == true,
		DisplayName = typeof(displayResult) == "table" and displayResult.DisplayName or nil,
		DisplayError = typeof(displayResult) == "table" and displayResult.Error or nil,
	}
end

]=]
	local replacementCount = 0
	source, replacementCount = string.gsub(source, "local%s+owner%s*=%s*Players:GetPlayerByUserId%(%s*ownerUserId%s*%)", [=[	-- NTR_PERSISTENCE_PHASE23_OWNER_LOOKUP_INLINE
	local owner = nil
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.UserId == ownerUserId then
			owner = candidate
			break
		end
	end]=], 1)
	if replacementCount == 0 then
		source, replacementCount = string.gsub(source, "local%s+owner%s*=%s*findPlayerByUserId%(%s*ownerUserId%s*%)", [=[	-- NTR_PERSISTENCE_PHASE23_OWNER_LOOKUP_INLINE
	local owner = nil
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate.UserId == ownerUserId then
			owner = candidate
			break
		end
	end]=], 1)
	end
	if replacementCount == 0 then
		source = replaceBetween(
			source,
			[=[local function visitGarage(player, payload)]=],
			[=[local function connectEntryPrompt()]=],
			robustVisitGarage,
			"Phase 23 robust VisitGarage replacement"
		)
	end
end

local stateStart = string.find(source, "local function getState", 1, true) or 1
source = insertAfterOnce(
	source,
	[=[		AccessMode = player:GetAttribute("NTR_Phase21GarageAccessMode"),]=],
	[=[
		VisitingOwnerUserId = player:GetAttribute("NTR_Phase23VisitingGarageOwnerUserId"),
		VisitAccessMode = player:GetAttribute("NTR_Phase23VisitAccessMode"),]=],
	"Phase 23 get state visit fields",
	stateStart
)

if not string.find(source, 'action == "VisitGarage"', 1, true) then
	source = insertAfterOnce(
		source,
		[=[	if action == "EnterOwnGarage" then
		return enterOwnGarage(player)]=],
		[=[
	elseif action == "VisitGarage" then
		return visitGarage(player, payload)
	elseif action == "SetAccessMode" then
		return setAccessMode(player, payload)
	elseif action == "InviteVisitor" then
		return inviteVisitor(player, payload)]=],
		"Phase 23 remote actions"
	)
end

if not string.find(source, "garageInvitesByOwnerUserId[player.UserId] = nil", 1, true) then
	source = replaceOnce(
		source,
		[=[	returnCFramesByUserId[player.UserId] = nil
	activeSlotsByUserId[player.UserId] = nil]=],
		[=[	returnCFramesByUserId[player.UserId] = nil
	activeSlotsByUserId[player.UserId] = nil
	garageInvitesByOwnerUserId[player.UserId] = nil]=],
		"Phase 23 player removing invite cleanup"
	)
end

interiorService.Source = source
interiorService:SetAttribute("PersistencePhase23SameServerGarageVisits", true)

local finalSource = interiorService.Source
assert(string.find(finalSource, "NTR_PERSISTENCE_PHASE23_GARAGE_VISITS", 1, true), "Phase 23 visit functions missing.")
assert(string.find(finalSource, "VisitGarage", 1, true), "Phase 23 VisitGarage action missing.")
assert(string.find(finalSource, "SetAccessMode", 1, true), "Phase 23 SetAccessMode action missing.")
assert(string.find(finalSource, "VisitingOwnerUserId", 1, true), "Phase 23 visit state fields missing.")
assert(string.find(finalSource, "NTR_PERSISTENCE_PHASE23_OWNER_LOOKUP_INLINE", 1, true), "Phase 23 inline owner lookup missing.")
assert(not string.find(finalSource, "Players:GetPlayerByUserId", 1, true), "Phase 23 unsafe Players:GetPlayerByUserId lookup is still present.")

info("PASS: installed same-server garage visit/access actions into GarageInteriorService_Active.")
info("Next: restart Play and run this same script from the CLIENT Command Bar. Expected VisitGarage OK, visitingOwner=<your user id>, and ReturnToCity OK.")
