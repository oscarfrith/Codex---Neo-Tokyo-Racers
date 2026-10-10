-- Owns the radio: one local music Sound in the GameplayMusic group, the playlist read from Config.Audio.Radio, and next / previous. No UI, remote, saved data or server state. Started by the Pulse free-roam HUD (UIPulse.FreeRoam.HudClient), which draws its strip.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local LOAD_TIMEOUT_SECONDS = 15
local AUDIBLE_GROUP_VOLUME = 0.01
local STARTUP_SETTLE_SECONDS = 2

local Radio = {}
local changed = Instance.new("BindableEvent")
-- Fires with Radio.State() when the track changes.
Radio.Changed = changed.Event

local started = false
local enabled = false
local volume = 0.5
local tracks = {}
local index = 0
local sound = nil
local generation = 0
local failures = 0
-- Reasons the music is paused: Startup (the first seconds of the session), StartScreen, FirstDrive (the first-drive
-- presentation) and Ducked (the loading mixer has the group at zero).
local holds = {}

local function assetId(raw)
	local value = tostring(raw or "")
	if value == "" then return "" end
	if tonumber(value) then return "rbxassetid://" .. value end
	return value
end

-- Ordered StringValue children with a value; the same shape as the context audio track folders.
local function readTracks(folder)
	local rows = {}
	for _, object in ipairs(folder and folder:GetChildren() or {}) do
		if object:IsA("StringValue") then
			local id = assetId(object.Value)
			if id ~= "" then
				local title = object:GetAttribute("Title")
				table.insert(rows, {
					Id = id,
					Name = object.Name,
					Title = type(title) == "string" and title ~= "" and title or object.Name,
					Order = tonumber(object:GetAttribute("Order")) or 0,
					Gain = math.clamp(tonumber(object:GetAttribute("Gain")) or 1, 0, 3),
				})
			end
		end
	end
	table.sort(rows, function(a, b)
		if a.Order ~= b.Order then return a.Order < b.Order end
		return a.Name < b.Name
	end)
	return rows
end

function Radio.State()
	local row = tracks[index]
	return {
		Enabled = enabled,
		Index = index,
		Count = #tracks,
		Title = row and row.Title or "",
		Playing = sound ~= nil and sound.IsPlaying,
	}
end

local play

local function advanceAfterFailure(mine)
	if mine ~= generation then return end
	failures += 1
	if failures >= #tracks then
		warn("[RadioClient] no track could be loaded; the radio has stopped")
		return
	end
	play(index + 1)
end

function play(position)
	if #tracks == 0 then return end
	index = ((position - 1) % #tracks) + 1
	generation += 1
	local mine = generation
	local row = tracks[index]
	if sound then
		sound:Stop()
		sound:Destroy()
	end
	local item = Instance.new("Sound")
	item.Name = "Radio_Local"
	item.SoundId = row.Id
	item.Volume = math.clamp(volume * row.Gain, 0, 3)
	item.Looped = false
	item.SoundGroup = SoundService:FindFirstChild("GameplayMusic")
	item.Parent = SoundService
	sound = item
	item.Ended:Connect(function()
		if mine ~= generation then return end
		failures = 0
		play(index + 1)
	end)
	-- A track that never loads (removed or moderated) would leave the radio silent for good.
	task.delay(LOAD_TIMEOUT_SECONDS, function()
		if mine == generation and not item.IsLoaded then advanceAfterFailure(mine) end
	end)
	if next(holds) == nil then pcall(function() item:Play() end) end
	changed:Fire(Radio.State())
end

function Radio.Next()
	if not enabled then return end
	failures = 0
	play(index + 1)
end

function Radio.Previous()
	if not enabled then return end
	failures = 0
	play(index - 1)
end

local function setHold(reason, value)
	local wasHeld = next(holds) ~= nil
	holds[reason] = value and true or nil
	local held = next(holds) ~= nil
	if held == wasHeld or not sound then return end
	if held then
		sound:Pause()
	elseif sound.IsPaused then
		pcall(function() sound:Resume() end)
	else
		pcall(function() sound:Play() end)
	end
end

function Radio.Start()
	if started then return Radio end
	started = true
	local audio = ReplicatedStorage:WaitForChild("Config"):WaitForChild("Audio")
	local config = audio:FindFirstChild("Radio")
	if not config then return Radio end
	enabled = config:GetAttribute("Enabled") == true
	volume = math.clamp(tonumber(config:GetAttribute("Volume")) or 0.5, 0, 3)
	tracks = readTracks(config:FindFirstChild("Tracks"))
	if not enabled or #tracks == 0 then
		enabled = false
		return Radio
	end
	index = 1

	-- The first-drive presentation keeps music silent, as the context audio owner does.
	local player = Players.LocalPlayer
	setHold("FirstDrive", player:GetAttribute("FirstDrivePresentationPending") == true)
	player:GetAttributeChangedSignal("FirstDrivePresentationPending"):Connect(function()
		setHold("FirstDrive", player:GetAttribute("FirstDrivePresentationPending") == true)
	end)

	-- The loading mixer takes the GameplayMusic group to zero for the start screen and every loading transition. The
	-- track pauses while the group is silent, so nothing plays unheard and the first track is heard from its start.
	local group = SoundService:FindFirstChild("GameplayMusic")
	if group and group:IsA("SoundGroup") then
		setHold("Ducked", group.Volume < AUDIBLE_GROUP_VOLUME)
		group:GetPropertyChangedSignal("Volume"):Connect(function()
			setHold("Ducked", group.Volume < AUDIBLE_GROUP_VOLUME)
		end)
	end

	setHold("StartScreen", player:GetAttribute("StartScreenActive") == true)
	player:GetAttributeChangedSignal("StartScreenActive"):Connect(function()
		setHold("StartScreen", player:GetAttribute("StartScreenActive") == true)
	end)

	-- The HUD can start before the loading flow has ducked the group or raised the start screen. Holding for a
	-- moment keeps a second of music from sounding before either hold is in place.
	setHold("Startup", true)
	task.delay(STARTUP_SETTLE_SECONDS, setHold, "Startup", false)

	play(1)
	return Radio
end

return Radio
