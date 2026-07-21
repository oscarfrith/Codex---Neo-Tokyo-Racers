-- NTR_LOADING_SYSTEM_PHASE1_AUDIO_MIXER_V1_1
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Mixer = {}
local started = false
local config = nil
local activeGeneration = 0
local active = false
local operationPending = false
local tweens = {}
local loadingSound = nil

local gameplayGroups = {
	"NTR_GameplayMusic",
	"NTR_Vehicle",
	"NTR_Ambience",
	"NTR_GameplaySFX",
}

local function number(name, fallback)
	local value = config and config:GetAttribute(name)
	return tonumber(value) or fallback
end

local function text(name, fallback)
	local value = config and config:GetAttribute(name)
	return type(value) == "string" and value or fallback
end

local function group(name)
	local item = SoundService:FindFirstChild(name)
	return item and item:IsA("SoundGroup") and item or nil
end

local function tweenVolume(item, target, duration)
	if not item then return end
	if tweens[item] then tweens[item]:Cancel() end
	local tween = TweenService:Create(item, TweenInfo.new(math.max(0, duration), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = target })
	tweens[item] = tween
	tween:Play()
	tween.Completed:Once(function() if tweens[item] == tween then tweens[item] = nil end end)
end

local function assetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

function Mixer.Start(configuration)
	config = configuration or config
	if started then return Mixer end
	started = true
	local loadingGroup = group("NTR_LoadingMusic")
	if loadingGroup then loadingGroup.Volume = 0 end
	loadingSound = Instance.new("Sound")
	loadingSound.Name = "NTR_LoadingMusic_Runtime"
	loadingSound.Looped = true
	loadingSound.Volume = 1
	loadingSound.SoundGroup = loadingGroup
	loadingSound.Parent = SoundService
	return Mixer
end

function Mixer.Begin(generation)
	activeGeneration = tonumber(generation) or (activeGeneration + 1)
	local thisGeneration = activeGeneration
	active = true
	operationPending = true
	for _, name in ipairs(gameplayGroups) do
		tweenVolume(group(name), number("GameplayDuckVolume", 0), number("GameplayAudioDuckSeconds", 0.25))
	end
	task.delay(math.max(0, number("LoadingMusicStartDelaySeconds", 0.9)), function()
		if not active or not operationPending or thisGeneration ~= activeGeneration or not loadingSound then return end
		local id = assetId(text("LoadingMusicAssetId", ""))
		if id == "" then return end
		loadingSound.SoundId = id
		if not loadingSound.IsPlaying then pcall(function() loadingSound:Play() end) end
		tweenVolume(group("NTR_LoadingMusic"), number("LoadingMusicVolume", 0.55), number("LoadingMusicFadeInSeconds", 0.5))
	end)
	return thisGeneration
end

function Mixer.MarkReady(generation)
	if tonumber(generation) ~= activeGeneration then return false end
	operationPending = false
	return true
end

function Mixer.Finish(generation, duration)
	if tonumber(generation) ~= activeGeneration then return false end
	active = false
	operationPending = false
	local fade = math.max(0, tonumber(duration) or number("FadeOutSeconds", 0.3))
	tweenVolume(group("NTR_LoadingMusic"), 0, fade)
	for _, name in ipairs(gameplayGroups) do
		tweenVolume(group(name), number(name .. "BaseVolume", 1), fade)
	end
	local thisGeneration = activeGeneration
	task.delay(fade + 0.05, function()
		if thisGeneration == activeGeneration and not active and loadingSound then pcall(function() loadingSound:Stop() end) end
	end)
	return true
end

function Mixer.IsActive()
	return active
end

return Mixer
