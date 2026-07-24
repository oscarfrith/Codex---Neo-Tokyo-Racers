-- NTR_AUDIO_SYSTEM_PHASE2_CONTEXT_CONTROLLER_V1
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Controller = {}
local player = Players.LocalPlayer
local kit = ReplicatedStorage:WaitForChild("NeoTokyoRacers")
local audioModules = kit.Shared.Modules.Client:WaitForChild("Audio")
local Catalog = require(audioModules:WaitForChild("ContextAudioCatalog"))
local contextConfig = kit.Config.Audio:WaitForChild("Context")
local global = contextConfig:WaitForChild("Global")

local TAG = "NTR_AudioContextZone"
local channels = { Music = {}, Ambience = {} }
local zones = setmetatable({}, { __mode = "k" })
local connections = {}
local heartbeatConnection = nil
local runtimeRoot = nil
local currentContextId = nil
local currentContext = nil
local elapsed = 0
local transitionGeneration = 0
local started = false

local function debugLog(message)
	if global:GetAttribute("DebugContextAudio") == true then
		print("[NTR Audio Phase 2] " .. tostring(message))
	end
end

local function enabled()
	local phase1Global = kit.Config.Audio:FindFirstChild("Global")
	return phase1Global and phase1Global:GetAttribute("AudioSystemEnabled") == true
		and global:GetAttribute("ContextAudioEnabled") == true
end

local function humanoidAndRoot()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

local function driving()
	local humanoid = humanoidAndRoot()
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then return false end
	local world = Workspace:FindFirstChild("NeoTokyoRacersWorld")
	local runtime = world and world:FindFirstChild("Runtime")
	local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
	return vehicles ~= nil and seat:IsDescendantOf(vehicles)
end

local function pointInside(object, position)
	if object:IsA("BasePart") then
		local localPoint = object.CFrame:PointToObjectSpace(position)
		local half = object.Size * 0.5
		return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
	end
	if object:IsA("Model") then
		local ok, cf, size = pcall(object.GetBoundingBox, object)
		if not ok then return false end
		local localPoint = cf:PointToObjectSpace(position)
		local half = size * 0.5
		return math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z
	end
	return false
end

local function registerZone(object)
	if zones[object] then return end
	if not (object:IsA("BasePart") or object:IsA("Model")) then
		if global:GetAttribute("DebugContextAudio") == true then warn("[NTR Audio Phase 2] Ignored non-spatial tagged zone " .. object:GetFullName()) end
		return
	end
	local cap = math.max(1, math.floor(Catalog.GlobalNumber("MaxRegisteredZones", 32)))
	local count = 0
	for _ in pairs(zones) do count += 1 end
	if count >= cap then
		if global:GetAttribute("DebugContextAudio") == true then warn("[NTR Audio Phase 2] Zone cap reached; ignored " .. object:GetFullName()) end
		return
	end
	zones[object] = true
end

local function unregisterZone(object)
	zones[object] = nil
end

local function zoneContext(position)
	local winnerId = nil
	local winnerPriority = -math.huge
	local winnerName = ""
	for object in pairs(zones) do
		if not object.Parent then
			zones[object] = nil
		else
			local contextId = tostring(object:GetAttribute("AudioContextId") or "")
			if contextId ~= "" and Catalog.HasContext(contextId) and pointInside(object, position) then
				local definition = Catalog.Get(contextId)
				local priority = tonumber(object:GetAttribute("AudioContextPriority")) or (definition and definition.Priority) or 0
				local stableName = object:GetFullName()
				if priority > winnerPriority or (priority == winnerPriority and stableName < winnerName) then
					winnerId = contextId
					winnerPriority = priority
					winnerName = stableName
				end
			end
		end
	end
	return winnerId
end

local function resolveContextId()
	if player:GetAttribute("NTR_OwnedGarageInside") == true and Catalog.HasContext("OWNED_GARAGE_INTERIOR") then
		return "OWNED_GARAGE_INTERIOR", "OwnedGarage"
	end
	if player:GetAttribute("NTR_GarageSessionActive") == true and Catalog.HasContext("DEALERSHIP_INTERIOR") then
		return "DEALERSHIP_INTERIOR", tostring(player:GetAttribute("NTR_GarageSessionMode") or "GarageSession")
	end
	local _, root = humanoidAndRoot()
	local zoned = root and zoneContext(root.Position)
	if zoned then return zoned, "TaggedZone" end
	if driving() and Catalog.HasContext("FREE_ROAM_DRIVING") then return "FREE_ROAM_DRIVING", "Driving" end
	return Catalog.GlobalString("DefaultContextId", "FREE_ROAM_ON_FOOT"), "Default"
end

local function newSound(channelName, context, row)
	local sound = Instance.new("Sound")
	sound.Name = channelName .. "_" .. context.Id .. "_" .. row.Name
	sound.SoundId = row.Id
	sound.Volume = 0
	sound.Looped = row.Loop == true
	sound.SoundGroup = SoundService:FindFirstChild(channelName == "Music" and "NTR_GameplayMusic" or "NTR_Ambience")
	sound.Parent = runtimeRoot
	return sound
end

local function chooseTrack(context, channelName, previousIndex)
	local rows = channelName == "Music" and context.Music or context.Ambience
	if #rows == 0 then return nil, 0 end
	local mode = string.lower(context.PlaylistMode)
	local index
	if mode == "random" and #rows > 1 then
		repeat index = math.random(1, #rows) until index ~= previousIndex
	else
		index = (previousIndex % #rows) + 1
	end
	return rows[index], index
end

local function fadeSound(sound, from, to, seconds, generation, destroyAtEnd)
	task.spawn(function()
		local duration = math.max(0, seconds)
		local startedAt = os.clock()
		repeat
			if generation ~= transitionGeneration or not sound.Parent then
				if destroyAtEnd and sound.Parent then sound:Destroy() end
				return
			end
			local alpha = duration == 0 and 1 or math.clamp((os.clock() - startedAt) / duration, 0, 1)
			sound.Volume = from + (to - from) * alpha
			if alpha >= 1 then break end
			RunService.Heartbeat:Wait()
		until false
		if destroyAtEnd and sound.Parent then sound:Destroy() end
	end)
end

local function startChannel(channelName, context, fadeSeconds)
	local channel = channels[channelName]
	local previous = channel.Sound
	local previousVolume = previous and previous.Volume or 0
	local row, index = chooseTrack(context, channelName, channel.Index or 0)
	channel.Index = index
	channel.ContextId = context.Id
	channel.Sound = nil
	if previous then fadeSound(previous, previousVolume, 0, fadeSeconds, transitionGeneration, true) end
	if not row then return end
	local sound = newSound(channelName, context, row)
	channel.Sound = sound
	local baseGain = channelName == "Music" and context.MusicGain or context.AmbienceGain
	local target = math.clamp(baseGain * row.Gain, 0, 3)
	sound.Ended:Connect(function()
		if channel.Sound ~= sound or transitionGeneration <= 0 or sound.Looped then return end
		local nextRow, nextIndex = chooseTrack(context, channelName, channel.Index or 0)
		if not nextRow then return end
		channel.Index = nextIndex
		local nextSound = newSound(channelName, context, nextRow)
		channel.Sound = nextSound
		nextSound.Volume = math.clamp(baseGain * nextRow.Gain, 0, 3)
		pcall(function() nextSound:Play() end)
		sound:Destroy()
	end)
	pcall(function() sound:Play() end)
	fadeSound(sound, 0, target, fadeSeconds, transitionGeneration, false)
end

local function transition(contextId, reason)
	local context = Catalog.Get(contextId)
	if not context then
		if global:GetAttribute("DebugContextAudio") == true then warn("[NTR Audio Phase 2] Missing context " .. tostring(contextId)) end
		return
	end
	if currentContextId == contextId then return end
	transitionGeneration += 1
	currentContextId = contextId
	currentContext = context
	local fade = enabled() and context.FadeSeconds or 0
	startChannel("Music", context, fade)
	startChannel("Ambience", context, fade)
	debugLog(("context=%s reason=%s music=%d ambience=%d"):format(context.Id, reason, #context.Music, #context.Ambience))
end

local function stopAll(seconds)
	transitionGeneration += 1
	for _, channel in pairs(channels) do
		local sound = channel.Sound
		channel.Sound = nil
		channel.ContextId = nil
		if sound then fadeSound(sound, sound.Volume, 0, seconds or 0, transitionGeneration, true) end
	end
	currentContextId = nil
	currentContext = nil
end

local function refresh()
	if not enabled() then
		if currentContextId ~= nil then stopAll(Catalog.GlobalNumber("DisableFadeSeconds", 0.4)) end
		return
	end
	local contextId, reason = resolveContextId()
	transition(contextId, reason)
end

function Controller.Start()
	if started then return Controller end
	started = true
	runtimeRoot = SoundService:FindFirstChild("NTR_ContextAudioRuntime_Local")
	if runtimeRoot then runtimeRoot:Destroy() end
	runtimeRoot = Instance.new("Folder")
	runtimeRoot.Name = "NTR_ContextAudioRuntime_Local"
	runtimeRoot.Parent = SoundService
	for _, object in ipairs(CollectionService:GetTagged(TAG)) do registerZone(object) end
	table.insert(connections, CollectionService:GetInstanceAddedSignal(TAG):Connect(registerZone))
	table.insert(connections, CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregisterZone))
	for _, attributeName in ipairs({ "NTR_OwnedGarageInside", "NTR_GarageSessionActive", "NTR_GarageSessionMode" }) do
		table.insert(connections, player:GetAttributeChangedSignal(attributeName):Connect(refresh))
	end
	local phase1Global = kit.Config.Audio:WaitForChild("Global")
	table.insert(connections, phase1Global:GetAttributeChangedSignal("AudioSystemEnabled"):Connect(refresh))
	table.insert(connections, global:GetAttributeChangedSignal("ContextAudioEnabled"):Connect(refresh))
	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		local interval = 1 / math.max(1, Catalog.GlobalNumber("ContextUpdateHz", 5))
		if elapsed >= interval then elapsed = 0; refresh() end
	end)
	refresh()
	debugLog("ContextAudioController started")
	return Controller
end

function Controller.Stop()
	if not started then return end
	started = false
	if heartbeatConnection then heartbeatConnection:Disconnect(); heartbeatConnection = nil end
	for _, connection in ipairs(connections) do connection:Disconnect() end
	table.clear(connections)
	stopAll(0)
	if runtimeRoot and runtimeRoot.Parent then runtimeRoot:Destroy() end
	runtimeRoot = nil
	table.clear(channels.Music)
	table.clear(channels.Ambience)
end

function Controller.State()
	local zoneCount = 0
	for _ in pairs(zones) do zoneCount += 1 end
	return {
		ContextId = currentContextId,
		DisplayName = currentContext and currentContext.DisplayName or nil,
		RegisteredZones = zoneCount,
		MusicActive = channels.Music.Sound ~= nil,
		AmbienceActive = channels.Ambience.Sound ~= nil,
	}
end

return Controller
