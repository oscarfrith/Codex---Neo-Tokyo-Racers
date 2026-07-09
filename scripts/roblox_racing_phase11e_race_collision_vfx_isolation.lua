-- Neo Tokyo Racers - Racing Phase 11E Race Collision + VFX Isolation
-- Run in Roblox Studio Command Bar in Edit mode, then restart Play.
--
-- Fixes the post-11D multiplayer race issues:
-- 1) race arrow/barrier collision window not staying active after later checkpoints,
-- 2) race/time-trial VFX leaking between free roam and sessions,
-- 3) race vehicles colliding with each other.

local PHASE = "NTR Racing Phase 11E"

local function info(message)
	print("[" .. PHASE .. "] " .. tostring(message))
end

local function fail(message)
	error("[" .. PHASE .. "] " .. tostring(message), 2)
end

local function child(parent, name, className)
	local item = parent and parent:FindFirstChild(name)
	if not item then
		fail("Missing " .. tostring(name) .. " under " .. (parent and parent:GetFullName() or "nil"))
	end
	if className and not item:IsA(className) then
		fail(item:GetFullName() .. " is " .. item.ClassName .. ", expected " .. className)
	end
	return item
end

local function findScript(path)
	local current = game
	for token in string.gmatch(path, "[^%.]+") do
		current = child(current, token)
	end
	if not (current:IsA("Script") or current:IsA("LocalScript") or current:IsA("ModuleScript")) then
		fail(path .. " is not a script")
	end
	return current
end

local function replaceOnce(source, needle, replacement, label)
	local startIndex, endIndex = string.find(source, needle, 1, true)
	if not startIndex then
		fail("Could not find source anchor: " .. label)
	end
	local second = string.find(source, needle, endIndex + 1, true)
	if second then
		fail("Source anchor is not unique: " .. label)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, endIndex + 1)
end

local function replaceFunctionBefore(source, functionName, nextFunctionName, replacement, label)
	local startIndex = string.find(source, "local function " .. functionName .. "(", 1, true)
	if not startIndex then
		fail("Could not find function start: " .. label)
	end
	local nextIndex = string.find(source, "\n\nlocal function " .. nextFunctionName .. "(", startIndex, true)
	if not nextIndex then
		nextIndex = string.find(source, "\nlocal function " .. nextFunctionName .. "(", startIndex, true)
	end
	if not nextIndex then
		fail("Could not find next function boundary: " .. label)
	end
	return string.sub(source, 1, startIndex - 1) .. replacement .. string.sub(source, nextIndex)
end

local function patchSessionAssetService()
	local scriptObj = findScript("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceSessionAssetService_Active")
	local source = scriptObj.Source
	if string.find(source, "NTR_RACING_PHASE11E_COLLISION_POLICY", 1, true) then
		info("RaceSessionAssetService already has Phase 11E collision policy.")
		return
	end

	source = replaceOnce(source, [==[	pcall(function() PhysicsService:CollisionGroupSetCollidable(ASSET_GROUP, PARTICIPANT_GROUP, true) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(PARTICIPANT_GROUP, "Default", true) end)
]==], [==[	pcall(function() PhysicsService:CollisionGroupSetCollidable(ASSET_GROUP, PARTICIPANT_GROUP, true) end)
	pcall(function() PhysicsService:CollisionGroupSetCollidable(PARTICIPANT_GROUP, PARTICIPANT_GROUP, false) end) -- NTR_RACING_PHASE11E_COLLISION_POLICY
	pcall(function() PhysicsService:CollisionGroupSetCollidable(PARTICIPANT_GROUP, "Default", true) end)
]==], "participant self collision off")

	source = replaceOnce(source, [==[	state.ProxyFolder:SetAttribute("ActiveProxyCount", created)
	state.ProxyFolder:SetAttribute("LastRebuiltClock", os.clock())
end
]==], [==[	state.ProxyFolder:SetAttribute("ActiveProxyCount", created)
	state.ProxyFolder:SetAttribute("LastRebuiltClock", os.clock())
	state.ProxyFolder:SetAttribute("ActiveSegmentCount", tableCount and tableCount(union) or 0)
	local segmentText = {}
	for userId, segment in pairs(state.ParticipantSegments) do
		table.insert(segmentText, tostring(userId) .. ":" .. tostring(segment))
	end
	table.sort(segmentText)
	state.ProxyFolder:SetAttribute("ParticipantSegments", table.concat(segmentText, ","))
end
]==], "proxy rebuild debug attributes")

	-- The tableCount helper is added only for the debug attribute above.
	source = replaceOnce(source, [==[local function configureCollisionGroups()
]==], [==[local function tableCount(t)
	local count = 0
	for _ in pairs(t or {}) do
		count += 1
	end
	return count
end

local function configureCollisionGroups()
]==], "session asset tableCount helper")

	scriptObj.Source = source
	info("Patched RaceSessionAssetService collision policy and proxy diagnostics.")
end

local function patchRaceMatchmakingService()
	local scriptObj = findScript("ServerScriptService.NeoTokyoRacers.Services.Racing.RaceMatchmakingService_Active")
	local source = scriptObj.Source
	if string.find(source, "NTR_RACING_PHASE11E_CHECKPOINT_COLLISION_REAPPLY", 1, true) then
		info("RaceMatchmakingService already reapplies checkpoint collision groups.")
		return
	end

	source = replaceOnce(source, [==[	-- NTR_RACING_PHASE10B_CHECKPOINT_SEGMENT_UPDATE
	callSessionAssetService("UpdateParticipantSegment", {
		RunId = race.RunId,
		UserId = entry.Player.UserId,
		CurrentSegment = math.max(0, (tonumber(entry.NextGateIndex) or 1) - 1),
	})	fire(entry.Player, {
]==], [==[	-- NTR_RACING_PHASE10B_CHECKPOINT_SEGMENT_UPDATE
	callSessionAssetService("ApplyParticipants", {
		RunId = race.RunId,
		Participants = {
			{ Player = entry.Player, Vehicle = entry.Vehicle },
		},
	}) -- NTR_RACING_PHASE11E_CHECKPOINT_COLLISION_REAPPLY
	callSessionAssetService("UpdateParticipantSegment", {
		RunId = race.RunId,
		UserId = entry.Player.UserId,
		CurrentSegment = math.max(0, (tonumber(entry.NextGateIndex) or 1) - 1),
	})
	fire(entry.Player, {
]==], "race checkpoint segment collision reapply")

	scriptObj.Source = source
	info("Patched RaceMatchmakingService checkpoint collision reapply.")
end

local function patchCachedVfxRuntime()
	local scriptObj = findScript("ReplicatedStorage.NeoTokyoRacers.Shared.Modules.Client.Visuals.CachedThrustVisualRuntime")
	local source = scriptObj.Source
	if string.find(source, "NTR_RACING_PHASE11E_VFX_GATE", 1, true) then
		info("CachedThrustVisualRuntime already has Phase 11E VFX gate.")
		return
	end

	source = replaceOnce(source, [==[local StarterGui = game:GetService("StarterGui")
]==], [==[local StarterGui = game:GetService("StarterGui")
]==], "vfx header sanity")

	source = replaceOnce(source, [==[local tracked = setmetatable({}, { __mode = "k" })
]==], [==[local tracked = setmetatable({}, { __mode = "k" })
local raceVisibilityActive = false -- NTR_RACING_PHASE11E_VFX_GATE
local raceParticipants = {}
local raceEvent = nil
]==], "vfx race visibility state")

	source = replaceOnce(source, [==[local function isToggleable(object)
]==], [==[local function clearRaceParticipants()
	table.clear(raceParticipants)
end

local function setRaceParticipants(list)
	clearRaceParticipants()
	for _, userId in ipairs(list or {}) do
		raceParticipants[tonumber(userId)] = true
	end
end

local function localIsRaceParticipant()
	return raceParticipants[LOCAL_PLAYER.UserId] == true
end

local function modelOwnerUserId(model)
	return tonumber(model and model:GetAttribute("OwnerUserId"))
end

local function shouldRenderVehicleVFX(model)
	local ownerId = modelOwnerUserId(model)
	local vehicleIsParticipant = ownerId and raceParticipants[ownerId] == true
	local modelClaimsRace = model and model:GetAttribute("NTR_RaceParticipant") == true
	if raceVisibilityActive == true then
		if localIsRaceParticipant() then
			return vehicleIsParticipant == true
		end
		return vehicleIsParticipant ~= true and modelClaimsRace ~= true
	end
	return modelClaimsRace ~= true
end

local function isToggleable(object)
]==], "vfx race visibility helpers")

	source = replaceOnce(source, [==[local function updateTemplateController(cache, state, dt)
	if not cache.Controller or typeof(cache.Controller.Update) ~= "function" then return end
	local throttle = state.Accelerating and 1 or 0
	local boost = state.Boosting and 1 or 0
	local drift = state.AnyDrift and 1 or 0
	if state.ForcePreview then
		throttle = 1
		boost = 1
		drift = 1
	end
	pcall(function()
		cache.Controller:Update(dt, {
			Throttle = throttle,
			Boost = boost,
			Drift = drift,
			DriftLeft = state.DriftLeft and 1 or 0,
			DriftRight = state.DriftRight and 1 or 0,
			HoverDust = state.Driving and 0.45 or 0,
			Brake = 0,
		})
	end)
end
]==], [==[local function updateTemplateController(cache, state, dt)
	if not cache.Controller or typeof(cache.Controller.Update) ~= "function" then return end
	local hiddenByRace = shouldRenderVehicleVFX(cache.Model) ~= true -- NTR_RACING_PHASE11E_VFX_GATE
	local throttle = (not hiddenByRace and state.Accelerating) and 1 or 0
	local boost = (not hiddenByRace and state.Boosting) and 1 or 0
	local drift = (not hiddenByRace and state.AnyDrift) and 1 or 0
	if state.ForcePreview and not hiddenByRace then
		throttle = 1
		boost = 1
		drift = 1
	end
	pcall(function()
		cache.Controller:Update(dt, {
			Throttle = throttle,
			Boost = boost,
			Drift = drift,
			DriftLeft = (not hiddenByRace and state.DriftLeft) and 1 or 0,
			DriftRight = (not hiddenByRace and state.DriftRight) and 1 or 0,
			HoverDust = (not hiddenByRace and state.Driving) and 0.45 or 0,
			Brake = 0,
		})
	end)
end
]==], "vfx template controller gate")

	source = replaceOnce(source, [==[local function applyVFXState(cache, state)
	local key = stateKey(state)
	if cache.LastStateKey == key then return end
	cache.LastStateKey = key
	for object, meta in pairs(cache.VFXObjects) do
		if object.Parent then
			local enabled = enabledFor(meta.Kind, meta.Side, state)
			if enabled ~= nil then
				setEnabled(object, enabled)
			end
		end
	end
end
]==], [==[local function applyVFXState(cache, state)
	local visibleByRace = shouldRenderVehicleVFX(cache.Model) == true -- NTR_RACING_PHASE11E_VFX_GATE
	local key = stateKey(state) .. "|RaceVisible=" .. tostring(visibleByRace)
	if cache.LastStateKey == key then return end
	cache.LastStateKey = key
	for object, meta in pairs(cache.VFXObjects) do
		if object.Parent then
			local enabled = visibleByRace and enabledFor(meta.Kind, meta.Side, state) or false
			if enabled ~= nil then
				setEnabled(object, enabled)
			end
		end
	end
end
]==], "vfx object gate")

	source = replaceOnce(source, [==[	table.insert(cache.Connections, model:GetAttributeChangedSignal("ThrustColor"):Connect(function()
		cache.NeedsColour = true
	end))
	for _, attr in ipairs({ "DriveReady", "Accelerating", "Boosting", "DriftingLeft", "DriftingRight" }) do
		table.insert(cache.Connections, model:GetAttributeChangedSignal(attr):Connect(function()
			cache.LastStateKey = nil
		end))
	end
]==], [==[	table.insert(cache.Connections, model:GetAttributeChangedSignal("ThrustColor"):Connect(function()
		cache.NeedsColour = true
	end))
	for _, attr in ipairs({ "DriveReady", "Accelerating", "Boosting", "DriftingLeft", "DriftingRight", "NTR_RaceParticipant", "NTR_RaceRunId" }) do
		table.insert(cache.Connections, model:GetAttributeChangedSignal(attr):Connect(function()
			cache.LastStateKey = nil
		end))
	end
]==], "vfx race attribute invalidation")

	source = replaceOnce(source, [==[function Runtime.Start()
	if connection then return end
	initControls()
	scanCandidates()
	requestLandscape()
	connection = RunService.RenderStepped:Connect(function(dt)
]==], [==[local function connectRaceVisibility()
	if raceEvent then return end
	local remotes = kit:FindFirstChild("Shared")
		and kit.Shared:FindFirstChild("Remotes")
		and kit.Shared.Remotes:FindFirstChild("Racing")
	local event = remotes and remotes:FindFirstChild("RaceEvent")
	if not (event and event:IsA("RemoteEvent")) then return end
	raceEvent = event
	event.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then return end
		local kind = tostring(payload.Type or "")
		if kind == "RaceVisibilityUpdate" then
			raceVisibilityActive = payload.Active == true
			setRaceParticipants(payload.Participants or {})
			for _, cache in pairs(tracked) do
				cache.LastStateKey = nil
			end
		elseif kind == "RaceExitedToStart" or kind == "RaceEnded" or kind == "RaceDNF" or kind == "TimeTrialEnded" or kind == "TimeTrialFinished" then
			raceParticipants[LOCAL_PLAYER.UserId] = nil
			if next(raceParticipants) == nil then
				raceVisibilityActive = false
			end
			for _, cache in pairs(tracked) do
				cache.LastStateKey = nil
			end
		end
	end)
end

function Runtime.Start()
	if connection then return end
	initControls()
	connectRaceVisibility()
	scanCandidates()
	requestLandscape()
	connection = RunService.RenderStepped:Connect(function(dt)
]==], "vfx connect race visibility")

	scriptObj.Source = source
	info("Patched CachedThrustVisualRuntime race/session VFX gate.")
end

patchSessionAssetService()
patchRaceMatchmakingService()
patchCachedVfxRuntime()

info("Install complete. Restart Play and test multiplayer race checkpoint collisions, VFX isolation, and racer vehicle non-collision.")
