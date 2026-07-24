-- NTR_AUDIO_SYSTEM_PHASE1_BUS_V1
local SoundService = game:GetService("SoundService")

local Bus = {}
local started = false
local registrations = setmetatable({}, { __mode = "k" })
local groupConnections = {}

local groupNames = {
	LoadingMusic = "NTR_LoadingMusic",
	GameplayMusic = "NTR_GameplayMusic",
	Vehicle = "NTR_Vehicle",
	Ambience = "NTR_Ambience",
	GameplaySFX = "NTR_GameplaySFX",
	UI = "NTR_UI",
}

local function groupVolume(category)
	local name = groupNames[category]
	local group = name and SoundService:FindFirstChild(name)
	if group and group:IsA("SoundGroup") then
		return math.clamp(tonumber(group.Volume) or 1, 0, 3)
	end
	return 1
end

local function apply(fader, record)
	if not (fader and fader.Parent and fader:IsA("AudioFader")) then
		registrations[fader] = nil
		return
	end
	fader.Volume = math.clamp((tonumber(record.Gain) or 0) * groupVolume(record.Category), 0, 3)
end

local function refreshCategory(category)
	for fader, record in pairs(registrations) do
		if record.Category == category then apply(fader, record) end
	end
end

function Bus.Start()
	if started then return Bus end
	started = true
	for category, name in pairs(groupNames) do
		local group = SoundService:FindFirstChild(name)
		if group and group:IsA("SoundGroup") then
			groupConnections[category] = group:GetPropertyChangedSignal("Volume"):Connect(function()
				refreshCategory(category)
			end)
		end
	end
	return Bus
end

function Bus.Register(category, fader, initialGain)
	assert(groupNames[category], "Unknown audio category: " .. tostring(category))
	assert(fader and fader:IsA("AudioFader"), "AudioBusController.Register requires AudioFader")
	registrations[fader] = { Category = category, Gain = math.max(0, tonumber(initialGain) or 0) }
	apply(fader, registrations[fader])
	return fader
end

function Bus.SetGain(fader, gain)
	local record = registrations[fader]
	if not record then return false end
	record.Gain = math.max(0, tonumber(gain) or 0)
	apply(fader, record)
	return true
end

function Bus.Unregister(fader)
	registrations[fader] = nil
end

function Bus.Count(category)
	local count = 0
	for _, record in pairs(registrations) do
		if category == nil or record.Category == category then count += 1 end
	end
	return count
end

return Bus
