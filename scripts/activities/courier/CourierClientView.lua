-- Courier client view (Street Life design 4.6). Mounted by ActivityClient; presentation only.
-- Owns: the COURIER Jobs entry, the hub offer card, the job strip text, hub/drop beacons and the
-- "Courier" RouteGuide source. The server decides hubs, drops, timers, delivery and pay; this view
-- only sends intents (CourierGoToHub, CourierStart, Cancel) and renders pushed Courier:* events.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RoadRouting = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("World"):WaitForChild("RoadRouting"))

local KIND = "Courier"
local ROUTE_SOURCE = "Courier"
local HUB_TAG = "CourierHub"
local STUDS_PER_MILE = 5760
local POLL_SECONDS = 0.25
local ROUTE_PRIORITY = 50

local ctx = nil
local run = nil -- { RunId, Drop, TimeLimit, StartServerTime, Variant, Chain, Impacts }
local hubRoute = nil -- { HubId, Position }
local removeDropBeacon, removeHubBeacon, closeOffer = nil, nil, nil
local offeredHubId = nil -- hub whose offer was shown; re-armed after leaving the pad
local pollConnection = nil
local elapsedSincePoll = 0
local refreshJobs -- forward declaration

local function config()
	local root = ReplicatedStorage:FindFirstChild("Config")
	local folder = root and root:FindFirstChild("Activities")
	return folder and folder:FindFirstChild(KIND)
end

local function number(key, fallback)
	local folder = config()
	local value = folder and tonumber(folder:GetAttribute(key))
	if value == nil or value ~= value then return fallback end
	return value
end

local function isEnabled()
	local folder = config()
	return folder ~= nil and folder:GetAttribute("Enabled") ~= false
end

-- The local player's own car root when they are in its DriverSeat (UX only; the server re-checks).
local function drivenRoot()
	local character = ctx.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then return nil end
	local model = seat:FindFirstAncestorOfClass("Model")
	while model and model:GetAttribute("OwnerUserId") == nil do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if not model or model:GetAttribute("OwnerUserId") ~= ctx.Player.UserId then return nil end
	return model.PrimaryPart
end

local function playerPosition()
	local root = drivenRoot()
	if root then return root.Position end
	local character = ctx.Player.Character
	local humanoidRoot = character and character:FindFirstChild("HumanoidRootPart")
	return humanoidRoot and humanoidRoot.Position or nil
end

local function flatDistance(a, b)
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Streamed-in hub pads only (streaming may hide distant pads; that is fine for the on-pad check).
local function hubAt(position)
	local radius = number("HubRadius", 30)
	for _, part in ipairs(CollectionService:GetTagged(HUB_TAG)) do
		if part:IsA("BasePart") and flatDistance(part.Position, position) <= radius then
			return part
		end
	end
	return nil
end

local function formatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function stars(count)
	return string.format("%d/3 STARS", math.clamp(tonumber(count) or 0, 0, 3))
end

local function remaining()
	if not run then return 0 end
	return run.TimeLimit - (workspace:GetServerTimeNow() - run.StartServerTime)
end

local function dismissOffer()
	if closeOffer then
		local close = closeOffer
		closeOffer = nil
		close()
	end
end

local function clearHubRoute()
	if removeHubBeacon then removeHubBeacon(); removeHubBeacon = nil end
	if hubRoute then ctx.RouteGuide.Clear(ROUTE_SOURCE .. "Hub") end
	hubRoute = nil
end

local function clearRun()
	run = nil
	if removeDropBeacon then removeDropBeacon(); removeDropBeacon = nil end
	ctx.RouteGuide.Clear(ROUTE_SOURCE)
	ctx.UI.Strip.Clear(KIND)
end

local function goToHub(label)
	local reply = ctx.Invoke("CourierGoToHub", {})
	if not (reply and reply.Ok and typeof(reply.Position) == "Vector3") then
		ctx.Toast((reply and reply.Message) or "Courier hubs are unavailable.", 3)
		return
	end
	clearHubRoute()
	hubRoute = { HubId = reply.HubId, Position = reply.Position }
	ctx.RouteGuide.SetDestination(ROUTE_SOURCE .. "Hub", reply.Position, {
		Label = label or string.upper(tostring(reply.DisplayName or "COURIER HUB")),
		Priority = ROUTE_PRIORITY - 10,
		Kind = "Activity",
	})
	removeHubBeacon = ctx.UI.Beacon("CourierHub", reply.Position, ctx.Theme.ElectricBlue)
end

local function startRun(hubId, variant)
	dismissOffer()
	local reply = ctx.Invoke("CourierStart", { HubId = hubId, Variant = variant })
	if not (reply and reply.Ok) then
		ctx.Toast((reply and reply.Message) or "Could not start the delivery.", 3)
	end
end

local function showOffer(hubPart)
	if closeOffer or run then return end
	local hubId = hubPart:GetAttribute("HubId")
	if type(hubId) ~= "string" then return end
	offeredHubId = hubId
	local basePay = number("BasePay", 1500)
	local hot = number("HotPayMultiplier", 1.4)
	local fragile = number("FragilePayMultiplier", 1.25)
	local penalty = math.floor(math.clamp(number("FragileImpactPenalty", 0.15), 0, 1) * 100 + 0.5)
	closeOffer = ctx.UI.Offer({
		Title = "COURIER RUN · " .. string.upper(tostring(hubPart:GetAttribute("DisplayName") or hubId)),
		Body = string.format(
			"Deliver a package across the city. From $%d plus distance and time bonus.\nHOT: tighter timer, x%.1f pay. FRAGILE: x%.2f pay, hard hits cost %d%%.",
			basePay, hot, fragile, penalty
		),
		Buttons = {
			{ Text = "STANDARD", Accent = ctx.Theme.Telemetry, OnClick = function() startRun(hubId, "Standard") end },
			{ Text = "HOT", Accent = ctx.Theme.HighSpeed, OnClick = function() startRun(hubId, "Hot") end },
			{ Text = "FRAGILE", Accent = ctx.Theme.ElectricBlue, OnClick = function() startRun(hubId, "Fragile") end },
		},
		Timeout = 15,
	})
end

local function updateStrip()
	if not run then return end
	local left = remaining()
	local position = playerPosition()
	local distance = position and RoadRouting.FormatDistance(flatDistance(position, run.Drop), STUDS_PER_MILE) or "--"
	local variant = run.Variant ~= "Standard" and (" · " .. string.upper(run.Variant)) or ""
	local damage = (run.Variant == "Fragile" and run.Impacts > 0) and string.format(" · HITS %d", run.Impacts) or ""
	local chain = run.Chain > 1 and string.format(" · x%.1f", run.Chain) or ""
	local colour = left <= 10 and ctx.Theme.Danger or ctx.Theme.Telemetry
	ctx.UI.Strip.Set(KIND, string.format("COURIER%s  %s  ·  %s%s%s", variant, formatTime(left), distance, damage, chain), colour)
end

local function poll()
	if run then
		updateStrip()
		return
	end
	if not isEnabled() then return end
	local root = drivenRoot()
	local hubPart = root and hubAt(root.Position)
	if hubPart then
		if hubRoute and hubRoute.HubId == hubPart:GetAttribute("HubId") then clearHubRoute() end
		if offeredHubId ~= hubPart:GetAttribute("HubId") then showOffer(hubPart) end
	else
		-- Leaving the pad closes any open offer (close() must be idempotent) and re-arms the offer.
		dismissOffer()
		offeredHubId = nil
	end
end

local function onHeartbeat(dt)
	elapsedSincePoll += dt
	if elapsedSincePoll < POLL_SECONDS then return end
	elapsedSincePoll = 0
	local ok, message = pcall(poll)
	if not ok then warn("[CourierClientView] poll failed", message) end
end

local function jobEntry()
	local enabled = isEnabled()
	local buttons
	local subtitle
	if run then
		subtitle = string.format("%s delivery in progress · %s left", string.upper(run.Variant), formatTime(remaining()))
		buttons = {
			{ Text = "CANCEL RUN", OnClick = function()
				local reply = ctx.Invoke("Cancel", {})
				if reply and reply.Ok == false and reply.Message then ctx.Toast(reply.Message, 3) end
			end },
		}
	else
		subtitle = "Drive packages across the city. Hot pays more, fragile hates bumps. Chain runs up to x1.5."
		buttons = {
			{ Text = "GO TO HUB", Enabled = enabled, OnClick = function() goToHub() end },
			{ Text = "START", Enabled = enabled, OnClick = function()
				local root = drivenRoot()
				local hubPart = root and hubAt(root.Position)
				if hubPart then
					dismissOffer()
					offeredHubId = nil
					showOffer(hubPart)
				else
					goToHub()
					ctx.Toast("Drive onto a courier hub pad to start.", 3)
				end
			end },
		}
	end
	ctx.Jobs.AddEntry({ Id = KIND, Title = "COURIER", Subtitle = subtitle, Order = 10, Buttons = buttons })
end

refreshJobs = function()
	jobEntry()
	ctx.Jobs.Refresh()
end

local function onStarted(payload)
	if typeof(payload.DropPosition) ~= "Vector3" then return end
	dismissOffer()
	clearHubRoute()
	clearRun()
	run = {
		RunId = payload.RunId,
		Drop = payload.DropPosition,
		TimeLimit = tonumber(payload.TimeLimit) or 0,
		StartServerTime = tonumber(payload.ServerStartTime) or workspace:GetServerTimeNow(),
		Variant = tostring(payload.Variant or "Standard"),
		Chain = tonumber(payload.Chain) or 1,
		Impacts = 0,
	}
	ctx.RouteGuide.SetDestination(ROUTE_SOURCE, run.Drop, { Label = "DROP-OFF", Priority = ROUTE_PRIORITY, Kind = "Activity" })
	removeDropBeacon = ctx.UI.Beacon("CourierDrop", run.Drop, ctx.Theme.HighSpeed)
	updateStrip()
	ctx.Toast(string.format("DELIVER IN %s", formatTime(run.TimeLimit)), 2.5)
	refreshJobs()
end

local function onCompleted(payload)
	clearRun()
	local text = string.format("DELIVERED  $%s  +%d XP  %s", tostring(payload.Cash or 0), tonumber(payload.Xp) or 0, stars(payload.Stars))
	if (tonumber(payload.Chain) or 1) > 1 then text ..= string.format("  CHAIN x%.1f", payload.Chain) end
	if payload.Capped then text ..= "  (hourly job cap reached)" end
	ctx.Toast(text, 5)
	refreshJobs()
	-- Keep the chain going: point at the nearest hub.
	task.delay(1, function()
		if not run then goToHub("NEXT RUN · COURIER HUB") end
	end)
end

local function onEnded(payload, prefix)
	clearRun()
	ctx.Toast(prefix .. tostring(payload.Reason or ""), 4)
	refreshJobs()
end

return {
	Mount = function(context)
		ctx = context
		refreshJobs()
		if pollConnection then pollConnection:Disconnect() end
		pollConnection = RunService.Heartbeat:Connect(onHeartbeat)
		local folder = config()
		if folder then
			folder:GetAttributeChangedSignal("Enabled"):Connect(function()
				if not isEnabled() then dismissOffer(); clearHubRoute() end
				refreshJobs()
			end)
		end
	end,
	OnEvent = function(payload)
		if not ctx or type(payload) ~= "table" then return end
		local kind = payload.Type
		if kind == "Courier:Started" then
			onStarted(payload)
		elseif kind == "Courier:Completed" then
			onCompleted(payload)
		elseif kind == "Courier:Failed" then
			onEnded(payload, "DELIVERY FAILED: ")
		elseif kind == "Courier:Cancelled" then
			onEnded(payload, "DELIVERY CANCELLED: ")
		elseif kind == "Courier:Impact" and run and payload.RunId == run.RunId then
			run.Impacts = tonumber(payload.Impacts) or run.Impacts
			ctx.Toast(string.format("FRAGILE CARGO HIT (%d)", run.Impacts), 1.5)
			updateStrip()
		end
	end,
}
