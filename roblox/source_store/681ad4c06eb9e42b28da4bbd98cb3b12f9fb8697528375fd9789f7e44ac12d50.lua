-- Canonical feature implementation; mounted by ActivityClient (no startup of its own).
-- Passenger seats, client view (Street Life design 4.7). Shows a local "RIDE" ProximityPrompt (F)
-- on other players' PassengerSeat when their PassengerAccess allows it (or a taxi ride was
-- accepted), sends the Ride intent, and shows the riding strip. The server re-checks everything;
-- this view only decides what to offer. E stays the owner's own-car entry key.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PROMPT_NAME = "PassengerRidePrompt"
local SEAT_NAME = "PassengerSeat"
local STRIP_KIND = "Passenger"
local REFRESH_SECONDS = 0.4
local FRIEND_CACHE_SECONDS = 120

local View = {}

local ctx
local localPlayer = Players.LocalPlayer
local allowances = {} -- [ownerUserId] = os.clock expiry (taxi rides)
local friendCache = {} -- [userId] = { Value, At, Pending }
local prompts = {} -- [seat] = { Prompt, Connection }
local riding = false
local busy = false

local function vehiclesRoot()
	local world = Workspace:FindFirstChild("World")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

local function isFriend(userId)
	local cached = friendCache[userId]
	if cached and (cached.Pending or os.clock() - cached.At < FRIEND_CACHE_SECONDS) then return cached.Value == true end
	friendCache[userId] = { Value = cached and cached.Value or false, At = os.clock(), Pending = true }
	task.spawn(function()
		local ok, result = pcall(function() return localPlayer:IsFriendsWith(userId) end)
		friendCache[userId] = { Value = ok and result == true, At = os.clock(), Pending = false }
	end)
	return cached and cached.Value == true or false
end

local function accessAllows(owner)
	local expiry = allowances[owner.UserId]
	if expiry and os.clock() < expiry then return true end
	local access = owner:GetAttribute("PassengerAccess")
	if access == "Anyone" then return true end
	if access == "Nobody" then return false end
	return isFriend(owner.UserId) -- "Friends" and unknown values fall back to the default
end

local function onFoot()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and humanoid.SeatPart == nil
end

local function removePrompt(seat)
	local entry = prompts[seat]
	if not entry then return end
	prompts[seat] = nil
	entry.Connection:Disconnect()
	if entry.Prompt then entry.Prompt:Destroy() end
end

local function ensurePrompt(seat, owner)
	local entry = prompts[seat]
	if entry and entry.Prompt.Parent == seat then return entry.Prompt end
	if entry then removePrompt(seat) end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt.ActionText = "RIDE"
	prompt.ObjectText = owner.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.UIOffset = Vector2.new(0, 40) -- sits under the server's Enter prompt when both show
	prompt.Parent = seat
	local connection = prompt.Triggered:Connect(function()
		if busy then return end
		busy = true
		prompt.Enabled = false
		task.spawn(function()
			local reply = ctx.Invoke("Ride", { OwnerUserId = owner.UserId })
			busy = false
			if not (reply and reply.Ok) then
				ctx.Toast((reply and reply.Message) or "Couldn't get in.", 3)
			end
		end)
	end)
	prompts[seat] = { Prompt = prompt, Connection = connection }
	return prompt
end

local function riderStrip()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat.Name == SEAT_NAME and not seat:IsA("VehicleSeat")) then return nil end
	local vehicle = seat:FindFirstAncestorOfClass("Model")
	while vehicle and vehicle:GetAttribute("OwnerUserId") == nil do vehicle = vehicle:FindFirstAncestorOfClass("Model") end
	local owner = vehicle and Players:GetPlayerByUserId(tonumber(vehicle:GetAttribute("OwnerUserId")) or 0)
	return owner and owner.DisplayName or "DRIVER"
end

local function refresh()
	-- Riding strip.
	local ownerName = riderStrip()
	if ownerName then
		ctx.UI.Strip.Set(STRIP_KIND, "RIDING WITH " .. string.upper(ownerName) .. " · JUMP TO EXIT", ctx.Theme.Telemetry)
		riding = true
	elseif riding then
		ctx.UI.Strip.Clear(STRIP_KIND)
		riding = false
	end

	-- Prompts on other players' cars (streamed-out seats simply have none).
	local root = vehiclesRoot()
	local seen = {}
	local walking = onFoot()
	if root then
		for _, vehicle in ipairs(root:GetChildren()) do
			local ownerUserId = tonumber(vehicle:GetAttribute("OwnerUserId"))
			local owner = ownerUserId and ownerUserId ~= localPlayer.UserId and Players:GetPlayerByUserId(ownerUserId)
			local seat = owner and vehicle:FindFirstChild(SEAT_NAME, true)
			if seat and seat:IsA("Seat") then
				seen[seat] = true
				local show = walking
					and seat.Occupant == nil
					and vehicle:GetAttribute("RaceParticipant") ~= true
					and owner:GetAttribute("RaceQueueActive") ~= true
					and owner:GetAttribute("GarageSessionActive") ~= true
					and owner:GetAttribute("OwnedGarageInside") ~= true
					and vehicle:GetAttribute("RaceRunId") == nil
					and accessAllows(owner)
				if show then
					ensurePrompt(seat, owner).Enabled = not busy
				elseif prompts[seat] then
					prompts[seat].Prompt.Enabled = false
				end
			end
		end
	end
	for seat in pairs(prompts) do
		if not seen[seat] then removePrompt(seat) end
	end
end

function View.Mount(context)
	ctx = context
	task.spawn(function()
		while true do
			local ok, err = pcall(refresh)
			if not ok then warn("[PassengerClientView]", err) end
			task.wait(REFRESH_SECONDS)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		allowances[player.UserId] = nil
		friendCache[player.UserId] = nil
	end)
end

function View.OnEvent(payload)
	if type(payload) ~= "table" or type(payload.Type) ~= "string" then return end
	local kind = payload.Type
	if kind == "Passenger:Allowed" or (kind == "Taxi:RequestAccepted" and payload.Role == "Rider") then
		local ownerUserId = tonumber(payload.OwnerUserId or payload.DriverUserId)
		if ownerUserId then allowances[ownerUserId] = os.clock() + (tonumber(payload.Seconds) or 120) end
	elseif kind == "Passenger:Revoked" then
		local ownerUserId = tonumber(payload.OwnerUserId)
		if ownerUserId then allowances[ownerUserId] = nil end
	elseif kind == "Passenger:Joined" then
		ctx.Toast(string.upper(tostring(payload.Name or "A passenger")) .. " JUMPED IN", 3)
	elseif kind == "Passenger:Left" then
		local reason = tostring(payload.Reason or "")
		if payload.RiderUserId then
			ctx.Toast(string.upper(tostring(payload.Name or "Your passenger")) .. " GOT OUT", 3)
		elseif reason ~= "" and reason ~= "Left the seat." and reason ~= "Left the ride." and reason ~= "CoreCancel"
			and reason ~= "Died." and reason ~= "Respawned." and reason ~= "Left the game." then
			ctx.Toast(reason, 3)
		end
	end
end

return View
