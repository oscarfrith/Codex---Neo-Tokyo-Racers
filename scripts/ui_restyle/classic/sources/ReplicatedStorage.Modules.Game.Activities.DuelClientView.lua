-- DuelClientView (ReplicatedStorage.Modules.Game.Activities.DuelClientView). Mounted by ActivityClient.
-- Presentation and intents only: the server decides eligibility, stakes, results and Cash.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local SCAN_SECONDS = 0.25
local ROUTE_SOURCE = "Duel"

local ctx
local button
local target -- Player currently offered by the CHALLENGE button
local outgoing -- { DuelId, ExpiresAt, Name }
local incoming = {} -- [duelId] = close()
local stakeMenuClose
local active -- { DuelId, OpponentName, Pot, RemoveBeacon }
local busyInvoke = false

local function duelConfig()
	local config = ReplicatedStorage:FindFirstChild("Config")
	local activities = config and config:FindFirstChild("Activities")
	return activities and activities:FindFirstChild("Duels")
end

local function configNumber(key, default, minimum, maximum)
	local folder = duelConfig()
	local value = folder and tonumber(folder:GetAttribute(key))
	if value == nil or value ~= value then return default end
	return math.clamp(value, minimum, maximum)
end

local function money(amount)
	local text = tostring(math.floor(tonumber(amount) or 0))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then formatted = formatted:sub(2) end
	return "$" .. formatted
end

-- Vehicles -----------------------------------------------------------------------------------------------
local function vehiclesFolder()
	local world = Workspace:FindFirstChild("World")
	local runtime = world and world:FindFirstChild("Runtime")
	return runtime and runtime:FindFirstChild("PlayerVehicles")
end

-- The vehicle's owner is seated in its DriverSeat (streamed-out parts simply return nil).
local function drivenByOwner(vehicle)
	local ownerId = vehicle:GetAttribute("OwnerUserId")
	local owner = ownerId and Players:GetPlayerByUserId(ownerId)
	if not owner or not owner.Character then return nil end
	local seat = vehicle:FindFirstChild("DriverSeat", true)
	local occupant = seat and seat:IsA("VehicleSeat") and seat.Occupant
	if not occupant or occupant.Parent ~= owner.Character then return nil end
	if vehicle:GetAttribute("RaceParticipant") or vehicle:GetAttribute("RaceRunId") then return nil end
	return owner, vehicle.PrimaryPart
end

local function playerFree(player)
	local kind = player:GetAttribute("ActivityKind")
	if kind ~= nil and kind ~= "" then return false end
	return not (player:GetAttribute("RaceQueueActive") or player:GetAttribute("GarageSessionActive")
		or player:GetAttribute("OwnedGarageInside"))
end

-- Nearest other player who is driving their own car within range of my driven car.
local function findTarget()
	local folder = vehiclesFolder()
	if not folder or not playerFree(LocalPlayer) then return nil end
	local mine, others = nil, {}
	for _, vehicle in ipairs(folder:GetChildren()) do
		local owner, root = drivenByOwner(vehicle)
		if owner and root then
			if owner == LocalPlayer then mine = root else table.insert(others, { Owner = owner, Root = root }) end
		end
	end
	if not mine then return nil end
	local range = configNumber("ChallengeRange", 60, 10, 300)
	local best, bestDistance = nil, range
	for _, other in ipairs(others) do
		local offset = other.Root.Position - mine.Position
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if distance <= bestDistance and playerFree(other.Owner) then
			best, bestDistance = other.Owner, distance
		end
	end
	return best
end

-- UI -----------------------------------------------------------------------------------------------------
local function closeStakeMenu()
	if stakeMenuClose then
		local close = stakeMenuClose
		stakeMenuClose = nil
		close()
	end
end

local function clearActive()
	if not active then return end
	if active.RemoveBeacon then active.RemoveBeacon() end
	ctx.RouteGuide.Clear(ROUTE_SOURCE)
	ctx.UI.Strip.Clear("Duel")
	active = nil
end

local function sendChallenge(player, stake)
	closeStakeMenu()
	if busyInvoke then return end
	busyInvoke = true
	local reply = ctx.Invoke("DuelChallenge", { TargetUserId = player.UserId, Stake = stake })
	busyInvoke = false
	if reply and reply.Ok then
		outgoing = { DuelId = reply.DuelId, ExpiresAt = reply.ExpiresAt, Name = player.DisplayName }
		ctx.Toast("Challenge sent to " .. player.DisplayName .. (stake > 0 and (" for " .. money(stake)) or ""), 3)
	else
		ctx.Toast(reply and reply.Message or "Challenge failed.", 3)
	end
end

local function openStakeMenu()
	local player = target
	if not player or busyInvoke or stakeMenuClose then return end
	busyInvoke = true
	local reply = ctx.Invoke("DuelChallenge", { TargetUserId = player.UserId, Preview = true })
	busyInvoke = false
	if not (reply and reply.Ok) then
		ctx.Toast(reply and reply.Message or "Duel unavailable.", 3)
		return
	end
	local buttons = {}
	local stakes = type(reply.Stakes) == "table" and reply.Stakes or { 0 }
	for _, stake in ipairs(stakes) do
		local amount = tonumber(stake) or 0
		table.insert(buttons, {
			Text = amount == 0 and "FREE" or money(amount),
			Accent = amount > 0 and ctx.Theme.HighSpeed or nil,
			OnClick = function() sendChallenge(player, amount) end,
		})
	end
	table.insert(buttons, { Text = "CANCEL", OnClick = closeStakeMenu })
	local body = "Race " .. player.DisplayName .. " to a finish across the city."
	if #stakes <= 1 then
		body ..= " Cash stakes unlock at Driver Rank " .. tostring(reply.StakeMinRank or 3) .. "."
	else
		body ..= " Winner takes both stakes."
	end
	stakeMenuClose = ctx.UI.Offer({ Title = "STREET DUEL", Body = body, Buttons = buttons, Timeout = 15 })
end

local function respond(duelId, accept)
	local close = incoming[duelId]
	incoming[duelId] = nil
	if close then close() end
	local reply = ctx.Invoke("DuelRespond", { DuelId = duelId, Accept = accept })
	if accept and not (reply and reply.Ok) then
		ctx.Toast(reply and reply.Message or "Could not start the duel.", 3)
	end
end

local function refreshButton()
	local now = Workspace:GetServerTimeNow()
	if outgoing and outgoing.ExpiresAt and now > outgoing.ExpiresAt + 2 then outgoing = nil end
	local enabled = duelConfig() == nil or duelConfig():GetAttribute("Enabled") ~= false
	target = (enabled and not active and not outgoing and next(incoming) == nil) and findTarget() or nil
	button.Visible = target ~= nil
	if target then button.Text = "CHALLENGE " .. string.upper(target.DisplayName) end
end

-- Events -------------------------------------------------------------------------------------------------
local handlers = {}

handlers["Duel:Challenge"] = function(payload)
	local duelId = payload.DuelId
	if type(duelId) ~= "string" or incoming[duelId] then return end
	local stake = tonumber(payload.Stake) or 0
	local body = tostring(payload.FromName or "A driver") .. " challenges you to a street duel"
	body ..= stake > 0 and (" for " .. money(stake) .. ". Winner takes " .. money(stake * 2) .. ".") or " (XP only)."
	local timeout = math.max(1, (tonumber(payload.ExpiresAt) or 0) - Workspace:GetServerTimeNow())
	incoming[duelId] = ctx.UI.Offer({
		Title = "DUEL CHALLENGE",
		Body = body,
		Timeout = timeout,
		Buttons = {
			{ Text = "ACCEPT", Accent = ctx.Theme.Telemetry, OnClick = function() respond(duelId, true) end },
			{ Text = "DECLINE", OnClick = function() respond(duelId, false) end },
		},
	})
end

handlers["Duel:Closed"] = function(payload)
	local close = incoming[payload.DuelId]
	incoming[payload.DuelId] = nil
	if close then close() end
	local wasMine = outgoing and outgoing.DuelId == payload.DuelId
	if wasMine then outgoing = nil end
	if payload.Message then
		ctx.Toast(payload.Message, 3)
	elseif wasMine and payload.Outcome == "Declined" then
		ctx.Toast("Challenge declined.", 3)
	elseif wasMine and payload.Outcome == "Expired" then
		ctx.Toast("Challenge expired.", 3)
	end
end

handlers["Duel:Countdown"] = function(payload)
	for duelId, close in pairs(incoming) do
		close()
		incoming[duelId] = nil
	end
	closeStakeMenu()
	outgoing = nil
	clearActive()
	local finish = payload.Finish
	if typeof(finish) ~= "Vector3" then return end
	local pot = tonumber(payload.Pot) or 0
	local name = tostring(payload.OpponentName or "rival")
	active = { DuelId = payload.DuelId, OpponentName = name, Pot = pot }
	ctx.UI.Countdown(tonumber(payload.GoAtServerTime) or Workspace:GetServerTimeNow(), "DUEL")
	ctx.RouteGuide.SetDestination(ROUTE_SOURCE, finish, { Label = "DUEL FINISH", Kind = "Activity", Priority = 60 })
	active.RemoveBeacon = ctx.UI.Beacon("Duel", finish, ctx.Theme.HighSpeed)
	ctx.UI.Strip.Set("Duel", "DUEL vs " .. name .. " · " .. (pot > 0 and money(pot) or "XP"), ctx.Theme.HighSpeed)
	button.Visible = false
end

handlers["Duel:Go"] = function() end

handlers["Duel:Result"] = function(payload)
	clearActive()
	local cash, xp = tonumber(payload.Cash) or 0, tonumber(payload.Xp) or 0
	local gains = {}
	if cash > 0 then table.insert(gains, "+" .. money(cash)) end
	if xp > 0 then table.insert(gains, "+" .. xp .. " XP") end
	local suffix = #gains > 0 and (" " .. table.concat(gains, " ")) or ""
	local won = payload.WinnerUserId == LocalPlayer.UserId
	local text
	if payload.Outcome == "Draw" then
		text = ((tonumber(payload.Stake) or 0) > 0 and "Duel drawn: stake refunded." or "Duel drawn.") .. suffix
	elseif payload.Outcome == "Forfeit" then
		text = (won and "Your rival forfeited. You win!" or "You forfeited the duel.") .. suffix
	else
		text = (won and "You won the duel!" or "You lost the duel.") .. suffix
	end
	ctx.Toast(text, 5)
end

-- View ---------------------------------------------------------------------------------------------------
local function mount(context)
	ctx = context
	local mobile = ctx.IsMobile == true
	button = ctx.UI.Button(ctx.Root, {
		Name = "DuelChallengeButton",
		Text = "CHALLENGE",
		Size = mobile and UDim2.fromOffset(240, 52) or UDim2.fromOffset(240, 40),
		Color = ctx.Theme.PanelDeep,
		StrokeColor = ctx.Theme.HighSpeed,
		TextColor = ctx.Theme.Text,
	})
	button.AnchorPoint = Vector2.new(0.5, 1)
	-- Bottom centre, above the free-roam CONTROLS / EXIT VEHICLE row (38 px tall at the bottom edge).
	button.Position = UDim2.new(0.5, 0, 1, mobile and -120 or -84)
	button.Visible = false
	button.Activated:Connect(openStakeMenu)
	button.Destroying:Connect(function()
		clearActive()
	end)

	-- ActivityHud is ResetOnSpawn = false and views are mounted once, so a character reset keeps this scan;
	-- it is disconnected when the button goes away (HUD destroyed or remounted).
	local elapsed = 0
	local scan
	scan = RunService.Heartbeat:Connect(function(dt)
		if not button.Parent then
			scan:Disconnect()
			return
		end
		elapsed += dt
		if elapsed < SCAN_SECONDS then return end
		elapsed = 0
		local ok, message = pcall(refreshButton)
		if not ok then
			button.Visible = false
			warn("[DUEL] view refresh failed: " .. tostring(message))
		end
	end)
end

local function onEvent(payload)
	if type(payload) ~= "table" or not ctx then return end
	local handler = handlers[payload.Type]
	if handler then handler(payload) end
end

return { Mount = mount, OnEvent = onEvent }
