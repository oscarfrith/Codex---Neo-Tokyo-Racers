-- Owns game music: three stations read from Config.Audio.Radio (FreeRoam while driving, Race while the driven vehicle is a race participant, StartScreen while the start screen is up), their local Sounds, crossfades, and next / previous. No UI, remote, saved data or server state. Started by the Pulse free-roam HUD (UIPulse.FreeRoam.HudClient).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LOAD_TIMEOUT_SECONDS = 15
local WATCH_SECONDS = 0.25
local SKIP_FADE_SECONDS = 0.4

local Radio = {}
local changed = Instance.new("BindableEvent")
-- Fires with Radio.State() when the station or the track changes.
Radio.Changed = changed.Event

local started = false
local enabled = false
local showStrip = false
local crossfadeSeconds = 4
local fadeSeconds = 1.5
-- name -> { Name, Tracks, Order, Position, Sound, Row, Group, Volume, FadeOut, Restart }
-- Restart: leaving the station drops its track and the next entry starts the following one (Race, StartScreen).
-- Otherwise the track pauses and resumes where it was (FreeRoam).
local stations = {}
local active = nil
local tweens = setmetatable({}, { __mode = "k" })
local failures = 0

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
					First = object:GetAttribute("First") == true,
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

-- Pure: the play order as indices into rows. Shuffled: rows marked First keep their place at the front, the rest
-- are drawn at random for this session. random(n) returns an integer from 1 to n.
function Radio._order(rows, shuffle, random)
	local first, rest = {}, {}
	for index, row in ipairs(rows) do
		table.insert(shuffle and not row.First and rest or first, index)
	end
	for index = #rest, 2, -1 do
		local other = random(index)
		rest[index], rest[other] = rest[other], rest[index]
	end
	return table.move(rest, 1, #rest, #first + 1, first)
end

function Radio.State()
	local station = active and stations[active]
	return {
		Enabled = enabled,
		ShowStrip = enabled and showStrip,
		Station = active,
		Index = station and station.Position or 0,
		Count = station and #station.Order or 0,
		Title = station and station.Row and station.Row.Title or "",
	}
end

local function fadeTo(sound, target, seconds, after)
	local running = tweens[sound]
	if running then running:Cancel() end
	if seconds <= 0 then
		tweens[sound] = nil
		sound.Volume = target
		if after then after() end
		return
	end
	local tween = TweenService:Create(sound, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Volume = target })
	tweens[sound] = tween
	tween.Completed:Once(function(playbackState)
		if tweens[sound] == tween then tweens[sound] = nil end
		if after and playbackState == Enum.PlaybackState.Completed then after() end
	end)
	tween:Play()
end

local function fadeAway(sound, seconds)
	fadeTo(sound, 0, seconds, function()
		sound:Destroy()
	end)
end

local startTrack

-- The new track fades in over fadeIn while the one it replaces fades out over the same time.
function startTrack(station, position, fadeIn)
	local count = #station.Order
	if count == 0 then return end
	station.Position = ((position - 1) % count) + 1
	local row = station.Tracks[station.Order[station.Position]]
	if station.Sound then fadeAway(station.Sound, fadeIn) end
	local sound = Instance.new("Sound")
	sound.Name = "Radio_" .. station.Name
	sound.SoundId = row.Id
	sound.Volume = 0
	sound.Looped = count == 1
	sound.SoundGroup = station.Group
	sound.Parent = SoundService
	station.Sound = sound
	station.Row = row
	-- The watcher starts the next track early for the crossfade; this covers a track too short for one.
	sound.Ended:Connect(function()
		if station.Sound == sound and active == station.Name then
			failures = 0
			startTrack(station, station.Position + 1, 0)
		end
	end)
	-- A track that never loads (removed or moderated) would leave the station silent for good.
	task.delay(LOAD_TIMEOUT_SECONDS, function()
		if station.Sound ~= sound or active ~= station.Name or sound.IsLoaded then return end
		failures += 1
		if failures >= count then
			warn("[RadioClient] no " .. station.Name .. " track could be loaded")
			return
		end
		startTrack(station, station.Position + 1, 0)
	end)
	pcall(function() sound:Play() end)
	fadeTo(sound, math.clamp(station.Volume * row.Gain, 0, 3), fadeIn)
	changed:Fire(Radio.State())
end

local function setActive(name)
	if name == active then return end
	local previous = active and stations[active]
	if previous and previous.Sound then
		local sound = previous.Sound
		if previous.Restart then
			previous.Sound = nil
			previous.Row = nil
			fadeAway(sound, previous.FadeOut)
		else
			fadeTo(sound, 0, previous.FadeOut, function()
				sound:Pause()
			end)
		end
	end
	active = name
	failures = 0
	local station = name and stations[name]
	if station then
		local sound = station.Sound
		if sound then
			if sound.IsPaused then pcall(function() sound:Resume() end) end
			fadeTo(sound, math.clamp(station.Volume * station.Row.Gain, 0, 3), fadeSeconds)
		else
			startTrack(station, station.Restart and station.Position + 1 or station.Position, fadeSeconds)
		end
	end
	changed:Fire(Radio.State())
end

local function skip(step)
	local station = enabled and active and stations[active]
	if not station then return end
	failures = 0
	startTrack(station, station.Position + step, SKIP_FADE_SECONDS)
end

function Radio.Next() skip(1) end
function Radio.Previous() skip(-1) end

local function usable(name)
	return stations[name] ~= nil and #stations[name].Order > 0
end

-- Pure: which station should sound. Start screen first; nothing during the first-drive presentation; race music
-- while racing; free-roam music only while driving.
function Radio._resolve(flags, has)
	if flags.StartScreen and has("StartScreen") then return "StartScreen" end
	if flags.StartScreen or flags.FirstDrive then return nil end
	if flags.Racing and has("Race") then return "Race" end
	if flags.Driving and has("FreeRoam") then return "FreeRoam" end
	return nil
end

function Radio.Start()
	if started then return Radio end
	started = true
	local config = ReplicatedStorage:WaitForChild("Config"):WaitForChild("Audio"):FindFirstChild("Radio")
	if not config or config:GetAttribute("Enabled") ~= true then return Radio end

	local function number(name, fallback, maximum)
		return math.clamp(tonumber(config:GetAttribute(name)) or fallback, 0, maximum)
	end
	local volume = number("Volume", 0.5, 3)
	crossfadeSeconds = number("CrossfadeSeconds", 4, 20)
	fadeSeconds = number("FadeSeconds", 1.5, 20)
	showStrip = config:GetAttribute("ShowStrip") == true
	local group = SoundService:FindFirstChild("GameplayMusic")
	if not (group and group:IsA("SoundGroup")) then group = nil end
	local random = Random.new()
	local function draw(count) return random:NextInteger(1, count) end
	local function station(name, folderName, options)
		local folder = config:FindFirstChild(folderName)
		local rows = readTracks(folder)
		stations[name] = {
			Name = name,
			Tracks = rows,
			Order = Radio._order(rows, folder ~= nil and folder:GetAttribute("Shuffle") == true, draw),
			Position = options.Restart and 0 or 1,
			Group = options.Group,
			Volume = options.Volume,
			FadeOut = options.FadeOut,
			Restart = options.Restart == true,
		}
	end
	-- The loading mixer holds the GameplayMusic group at zero on the start screen, so that station has no group.
	station("FreeRoam", "Tracks", { Group = group, Volume = volume, FadeOut = fadeSeconds })
	station("Race", "RaceTracks", { Group = group, Volume = volume, FadeOut = fadeSeconds, Restart = true })
	station("StartScreen", "StartScreenTracks", { Volume = number("StartScreenVolume", 0.5, 3),
		FadeOut = number("StartScreenFadeOutSeconds", 2, 20), Restart = true })
	if not (usable("FreeRoam") or usable("Race") or usable("StartScreen")) then return Radio end
	enabled = true

	local player = Players.LocalPlayer
	local flags = { StartScreen = false, FirstDrive = false, Driving = false, Racing = false }
	local function update()
		setActive(Radio._resolve(flags, usable))
	end

	for flag, attribute in pairs({ StartScreen = "StartScreenActive", FirstDrive = "FirstDrivePresentationPending" }) do
		flags[flag] = player:GetAttribute(attribute) == true
		player:GetAttributeChangedSignal(attribute):Connect(function()
			flags[flag] = player:GetAttribute(attribute) == true
			update()
		end)
	end

	-- Driving: seated in the driver's seat of a vehicle under World.Runtime.PlayerVehicles, as the context audio
	-- owner tests it. Racing: that vehicle carries the server's RaceParticipant attribute.
	local vehicle, vehicleConnection, seatConnection, childConnection
	local function refreshDrive()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local world = Workspace:FindFirstChild("World")
		local runtime = world and world:FindFirstChild("Runtime")
		local vehicles = runtime and runtime:FindFirstChild("PlayerVehicles")
		local found = nil
		if seat and seat:IsA("VehicleSeat") and vehicles and seat:IsDescendantOf(vehicles) then
			found = seat
			while found.Parent ~= vehicles do found = found.Parent end
		end
		if found ~= vehicle then
			if vehicleConnection then vehicleConnection:Disconnect() end
			vehicle = found
			vehicleConnection = found and found:GetAttributeChangedSignal("RaceParticipant"):Connect(refreshDrive) or nil
		end
		flags.Driving = found ~= nil
		flags.Racing = found ~= nil and found:GetAttribute("RaceParticipant") == true
		update()
	end
	local function bindCharacter(character)
		if seatConnection then seatConnection:Disconnect() end
		if childConnection then childConnection:Disconnect() end
		seatConnection, childConnection = nil, nil
		if character then
			local function bindHumanoid(humanoid)
				if seatConnection then seatConnection:Disconnect() end
				seatConnection = humanoid:GetPropertyChangedSignal("SeatPart"):Connect(refreshDrive)
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then bindHumanoid(humanoid) end
			childConnection = character.ChildAdded:Connect(function(child)
				if child:IsA("Humanoid") then
					bindHumanoid(child)
					refreshDrive()
				end
			end)
		end
		refreshDrive()
	end
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function()
		bindCharacter(nil)
	end)
	bindCharacter(player.Character)

	-- Crossfade: the next track starts crossfadeSeconds before the current one ends.
	task.spawn(function()
		while true do
			task.wait(WATCH_SECONDS)
			local current = active and stations[active]
			local sound = current and current.Sound
			if sound and sound.IsPlaying and not sound.Looped and sound.TimeLength > crossfadeSeconds * 2
				and sound.TimePosition >= sound.TimeLength - crossfadeSeconds then
				failures = 0
				startTrack(current, current.Position + 1, crossfadeSeconds)
			end
		end
	end)

	return Radio
end

return Radio
