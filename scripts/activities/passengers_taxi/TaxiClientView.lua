-- Canonical feature implementation; mounted by ActivityClient (no startup of its own).
-- Sky Taxi client view (Street Life design 4.7). JOBS entries (SKY TAXI duty toggle, CALL A TAXI),
-- fare beacon + activity route (fare, then destination), the job strip, request offer cards for
-- on-duty drivers and toasts. Read-only mirror of server events; sends intents only.
local Players = game:GetService("Players")

local ROUTE_SOURCE = "SkyTaxi"
local STRIP_KIND = "Taxi"
local STUDS_PER_MILE = 5760 -- 1 stud/s = 0.625 mph
local ROUTE_PRIORITY = 50

local View = {}

local ctx
local localPlayer = Players.LocalPlayer
local onDuty = false
local fare -- { Id, Phase = "Pickup"|"Dropoff", Position, Destination, Estimate, StartedAt, Stars }
local ride -- driver side: { Name, Position, Phase = "Pickup"|"Riding", RequesterUserId }
local request -- rider side: { Phase = "Open"|"Accepted"|"Riding", DriverName }
-- Request offers are shown one at a time from a queue. The shared Offer card can be replaced by
-- another offer (ours or another view's), so each shown offer frees its slot after its timeout
-- even if no button was pressed; requests still open are never lost behind a stale handle.
local OFFER_SECONDS = 20
local pendingOffers = {} -- ordered payloads waiting to be shown
local currentOffer -- { Id, Close, Token }
local offerToken = 0
local beaconRemove
local invoking = false

local function upper(text)
	return string.upper(tostring(text or ""))
end

local function miles(studs)
	local value = math.max(0, tonumber(studs) or 0) / STUDS_PER_MILE
	return value < 0.1 and "<0.1 MI" or string.format("%.1f MI", value)
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function stars(count)
	local n = math.clamp(math.floor(tonumber(count) or 5), 0, 5)
	return n .. "/5 STARS"
end

local function myPosition()
	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function setBeacon(position, colour)
	if beaconRemove then beaconRemove(); beaconRemove = nil end
	if position then beaconRemove = ctx.UI.Beacon("SkyTaxi", position, colour) end
end

local function setRoute(position, label)
	if position then
		ctx.RouteGuide.SetDestination(ROUTE_SOURCE, position, { Label = label, Priority = ROUTE_PRIORITY, Kind = "Activity" })
	else
		ctx.RouteGuide.Clear(ROUTE_SOURCE)
	end
end

local function clearGuide()
	setBeacon(nil)
	setRoute(nil)
end

local function closeOffers()
	table.clear(pendingOffers)
	local offer = currentOffer
	currentOffer = nil
	if offer then pcall(offer.Close) end
end

-- Strip text is derived from state so every change goes through one place.
local function updateStrip()
	if fare and fare.Phase == "Dropoff" then
		local left = fare.Estimate - (os.clock() - fare.StartedAt)
		local eta = left >= 0 and ("ETA " .. clock(left)) or ("LATE " .. clock(-left))
		ctx.UI.Strip.Set(STRIP_KIND, "SKY TAXI · DROP OFF · " .. eta .. " · " .. stars(fare.Stars), ctx.Theme.Telemetry)
	elseif fare and fare.Phase == "Pickup" then
		ctx.UI.Strip.Set(STRIP_KIND, "SKY TAXI · PICK UP YOUR FARE · STOP AT THE BEACON", ctx.Theme.Telemetry)
	elseif ride and ride.Phase == "Riding" then
		ctx.UI.Strip.Set(STRIP_KIND, "SKY TAXI · DRIVING " .. upper(ride.Name) .. " · STOP WHERE THEY ASK", ctx.Theme.ElectricBlue)
	elseif ride then
		ctx.UI.Strip.Set(STRIP_KIND, "SKY TAXI · PICK UP " .. upper(ride.Name), ctx.Theme.ElectricBlue)
	elseif onDuty then
		ctx.UI.Strip.Set(STRIP_KIND, "SKY TAXI · ON DUTY · WAITING FOR A FARE", ctx.Theme.Muted)
	elseif request and request.Phase == "Open" then
		ctx.UI.Strip.Set(STRIP_KIND, "TAXI REQUESTED · WAITING FOR A DRIVER", ctx.Theme.Telemetry)
	elseif request and request.Phase == "Accepted" then
		ctx.UI.Strip.Set(STRIP_KIND, upper(request.DriverName) .. " IS ON THE WAY · PRESS RIDE AT THEIR CAR", ctx.Theme.Telemetry)
	else
		-- Riders see the passenger strip from PassengerClientView instead.
		ctx.UI.Strip.Clear(STRIP_KIND)
	end
end

local function invoke(action, args)
	if invoking then return nil end
	invoking = true
	local reply = ctx.Invoke(action, args)
	invoking = false
	if reply and reply.Message and reply.Message ~= "" then ctx.Toast(reply.Message, 3) end
	return reply
end

local refreshJobs
local function act(action, args)
	task.spawn(function()
		invoke(action, args)
		refreshJobs()
	end)
end

refreshJobs = function()
	ctx.Jobs.AddEntry({
		Id = "SkyTaxi",
		Title = "SKY TAXI",
		Subtitle = onDuty and "On duty. Fares appear on your map." or "Drive fares across the city. Pay by distance and stars.",
		Order = 20,
		Buttons = {
			{
				Text = onDuty and "GO OFF DUTY" or "GO ON DUTY",
				Enabled = not invoking,
				OnClick = function() act("TaxiSetDuty", { OnDuty = not onDuty }) end,
			},
		},
	})
	local requesting = request ~= nil
	ctx.Jobs.AddEntry({
		Id = "CallTaxi",
		Title = "CALL A TAXI",
		Subtitle = requesting and "Your request is live." or "Ping on-duty drivers for a ride. Always free for you.",
		Order = 21,
		Buttons = {
			{
				Text = requesting and "CANCEL" or "REQUEST",
				Enabled = not invoking and not onDuty and not (request and request.Phase == "Riding"),
				OnClick = function() act(requesting and "TaxiCancelRequest" or "TaxiRequest", nil) end,
			},
		},
	})
	ctx.Jobs.Refresh()
end

local showNextOffer

-- requeue: the slot timed out without a button press (possibly replaced by another offer card);
-- the still-open request goes back in the queue once so it can be shown again.
local function finishOffer(token, requeue)
	if currentOffer and currentOffer.Token == token then
		local payload = currentOffer.Payload
		currentOffer = nil
		if requeue and payload.Shown < 2 then table.insert(pendingOffers, payload) end
		showNextOffer()
	end
end

showNextOffer = function()
	if currentOffer or not onDuty then return end
	local payload = table.remove(pendingOffers, 1)
	if not payload then return end
	local requesterUserId = payload.RequesterUserId
	local here = myPosition()
	local distance = (here and typeof(payload.Position) == "Vector3") and miles((payload.Position - here).Magnitude) or "NEARBY"
	offerToken += 1
	local token = offerToken
	payload.Shown = (payload.Shown or 0) + 1
	currentOffer = { Id = requesterUserId, Token = token, Payload = payload, Close = function() end }
	currentOffer.Close = ctx.UI.Offer({
		Title = "TAXI REQUEST",
		Body = upper(payload.Name) .. " · " .. distance .. " AWAY",
		Timeout = OFFER_SECONDS,
		Buttons = {
			{
				Text = "ACCEPT",
				Accent = ctx.Theme.Telemetry, -- a Color3 token (ActivityClient uses it as the stroke colour)
				OnClick = function()
					finishOffer(token)
					act("TaxiAcceptRequest", { RequesterUserId = requesterUserId })
				end,
			},
			{ Text = "IGNORE", OnClick = function() finishOffer(token) end },
		},
	}) or function() end
	task.delay(OFFER_SECONDS + 0.25, finishOffer, token, true)
end

local function queueOffer(payload)
	local requesterUserId = tonumber(payload.RequesterUserId)
	if not requesterUserId or not onDuty then return end
	if currentOffer and currentOffer.Id == requesterUserId then return end
	for _, queued in ipairs(pendingOffers) do
		if queued.RequesterUserId == requesterUserId then return end
	end
	table.insert(pendingOffers, { RequesterUserId = requesterUserId, Name = payload.Name, Position = payload.Position })
	showNextOffer()
end

local function dropOffer(requesterUserId)
	for index = #pendingOffers, 1, -1 do
		if pendingOffers[index].RequesterUserId == requesterUserId then table.remove(pendingOffers, index) end
	end
	if currentOffer and currentOffer.Id == requesterUserId then
		local offer = currentOffer
		currentOffer = nil
		pcall(offer.Close)
		showNextOffer()
	end
end

local function setOnDuty(value)
	onDuty = value
	if not value then
		fare = nil
		ride = nil
		clearGuide()
		closeOffers()
	end
end

local handlers = {}

handlers["Taxi:Duty"] = function(payload)
	setOnDuty(payload.OnDuty == true)
	if payload.OnDuty ~= true and payload.Message then ctx.Toast(payload.Message, 3) end
end

handlers["Taxi:Fare"] = function(payload)
	if typeof(payload.Position) ~= "Vector3" then return end
	fare = { Id = payload.FareId, Phase = "Pickup", Position = payload.Position }
	setBeacon(payload.Position, ctx.Theme.Telemetry)
	setRoute(payload.Position, "FARE")
	ctx.Toast("NEW FARE · FOLLOW THE ROUTE", 3)
end

handlers["Taxi:PickedUp"] = function(payload)
	if typeof(payload.Destination) ~= "Vector3" then return end
	fare = {
		Id = payload.FareId, Phase = "Dropoff", Destination = payload.Destination,
		Estimate = tonumber(payload.EstimateSeconds) or 60, StartedAt = os.clock(), Stars = 5,
	}
	setBeacon(payload.Destination, ctx.Theme.HighSpeed)
	setRoute(payload.Destination, "DROP OFF")
	ctx.Toast("FARE ON BOARD · " .. miles(payload.Distance) .. " TRIP", 3)
end

handlers["Taxi:Impact"] = function(payload)
	if fare and fare.Phase == "Dropoff" then
		fare.Stars = tonumber(payload.Stars) or fare.Stars
		ctx.Toast("OUCH! " .. stars(fare.Stars), 2)
	end
end

handlers["Taxi:Delivered"] = function(payload)
	fare = nil
	clearGuide()
	local text = "FARE COMPLETE · " .. stars(payload.Stars)
	if (tonumber(payload.Cash) or 0) > 0 then text ..= " · +$" .. math.floor(payload.Cash) end
	if (tonumber(payload.Xp) or 0) > 0 then text ..= " · +" .. math.floor(payload.Xp) .. " XP" end
	if payload.Capped then text ..= " · HOURLY JOB CAP REACHED" end
	ctx.Toast(text, 4)
end

handlers["Taxi:FareLost"] = function(payload)
	fare = nil
	clearGuide()
	if payload.Message then ctx.Toast(payload.Message, 3) end
end

handlers["Taxi:Notice"] = function(payload)
	if payload.Message then ctx.Toast(payload.Message, 3) end
end

handlers["Taxi:Request"] = queueOffer

handlers["Taxi:RequestClosed"] = function(payload)
	local requesterUserId = tonumber(payload.RequesterUserId)
	if requesterUserId then dropOffer(requesterUserId) end
end

handlers["Taxi:RequestOpen"] = function()
	request = { Phase = "Open" }
end

handlers["Taxi:RequestAccepted"] = function(payload)
	if payload.Role == "Driver" then
		closeOffers()
		fare = nil
		ride = { Name = payload.Name, Position = payload.Position, Phase = "Pickup", RequesterUserId = payload.RequesterUserId }
		if typeof(payload.Position) == "Vector3" then
			setBeacon(payload.Position, ctx.Theme.ElectricBlue)
			setRoute(payload.Position, "PICK UP")
		end
		if payload.Bonus == false then ctx.Toast("SAME PASSENGER RECENTLY · NO FARE BONUS THIS TIME", 3) end
	else
		request = { Phase = "Accepted", DriverName = payload.DriverName }
		ctx.Toast(upper(payload.DriverName) .. " ACCEPTED · PRESS RIDE (F) AT THEIR CAR", 4)
	end
end

handlers["Taxi:RideStarted"] = function(payload)
	if payload.Role == "Driver" and ride then
		ride.Phase = "Riding"
		clearGuide()
	elseif payload.Role == "Rider" and request then
		request.Phase = "Riding"
	end
end

handlers["Taxi:RideComplete"] = function(payload)
	local text = "RIDE COMPLETE · " .. upper(payload.Name) .. " · " .. miles(payload.Distance)
	if (tonumber(payload.Cash) or 0) > 0 then text ..= " · +$" .. math.floor(payload.Cash) end
	if (tonumber(payload.Xp) or 0) > 0 then text ..= " · +" .. math.floor(payload.Xp) .. " XP" end
	if payload.Capped then text ..= " · HOURLY JOB CAP REACHED" end
	ctx.Toast(text, 4)
end

handlers["Taxi:RequestEnded"] = function(payload)
	if payload.Role == "Driver" then
		ride = nil
		clearGuide()
	else
		request = nil
	end
	if payload.Message then ctx.Toast(payload.Message, 3) end
end

function View.Mount(context)
	ctx = context
	onDuty = localPlayer:GetAttribute("ActivityKind") == "Taxi"
	refreshJobs()
	-- Keep the ETA ticking and the strip in sync; cheap (2 Hz, only text).
	task.spawn(function()
		while true do
			local ok, err = pcall(updateStrip)
			if not ok then warn("[TaxiClientView]", err) end
			task.wait(0.5)
		end
	end)
	localPlayer:GetAttributeChangedSignal("ActivityKind"):Connect(function()
		local taxi = localPlayer:GetAttribute("ActivityKind") == "Taxi"
		if onDuty and not taxi then setOnDuty(false) end
		refreshJobs()
	end)
end

function View.OnEvent(payload)
	if type(payload) ~= "table" or type(payload.Type) ~= "string" then return end
	local handler = handlers[payload.Type]
	if not handler then return end
	handler(payload)
	updateStrip()
	refreshJobs()
end

return View
