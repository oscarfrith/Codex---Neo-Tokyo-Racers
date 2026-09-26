-- Canonical feature implementation; used by TaxiClientView and CourierClientView (mounted by ActivityClient).
-- World jobs client (map-markers-contract "World jobs"). Presentation and intents only:
--   * mirrors ReplicatedStorage.ActivityState.JobOffers into MapMarkers (TaxiFare / CourierPickup icons,
--     Kind "Job", Pulse); streamed-in offers get a local anchor with a ProximityPrompt ("Give ride" /
--     "Pick up parcel", E) enabled only while the player drives their own car slowly, a beacon and the
--     kind's prop (parcel crate). Taxi fares' NPCs are server rigs;
--   * JobAccept intent; during a job: strip (time, distance, live pay estimate, crashes), the Activity
--     route and the TaxiDrop / CourierDrop marker; completion toast with the pay breakdown;
--   * JOBS panel entries "NEAREST TAXI FARE" / "NEAREST PARCEL" with SET ROUTE.
-- The server (JobBoard) decides offers, acceptance, crashes, arrival and pay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local JobRules = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Game"):WaitForChild("Activities"):WaitForChild("JobRules"))

local JobClient = {}

local ROUTE_TRIP = "Job"
local ROUTE_OFFER = "JobOffer"
local DESTINATION_MARKER = "JobDestination"
local POLL_SECONDS = 0.2

local ctx
local mounted = false
local localPlayer = Players.LocalPlayer
local kinds = {} -- [kind] = spec (RegisterKind)
local offers = {} -- [offerId] = entry
local trip = nil
local markersModule = nil -- nil = not resolved yet, false = unavailable
local markerIds = {} -- [markerId] = true while set
local propsFolder
local routedOffer = nil -- { Id, Kind }
local accepting = false
local lastAcceptId = nil
local entryText = {} -- [kind] = last subtitle
local board = JobRules.ReadBoardConfig(nil)
local boardReadAt = -math.huge
local slowAt = { markers = -math.huge, jobs = -math.huge }

local function configFolder(name)
	local root = ReplicatedStorage:FindFirstChild("Config")
	local activities = root and root:FindFirstChild("Activities")
	return activities and activities:FindFirstChild(name)
end

local function refreshBoard()
	if os.clock() - boardReadAt < 2 then return end
	boardReadAt = os.clock()
	local folder = configFolder("Jobs")
	board = JobRules.ReadBoardConfig(function(key) return folder and folder:GetAttribute(key) end)
end

local function kindEnabled(kind)
	local folder = configFolder(kind)
	local jobs = configFolder("Jobs")
	return folder ~= nil and folder:GetAttribute("Enabled") ~= false and not (jobs and jobs:GetAttribute("Enabled") == false)
end

-- The local player's own car root when they are in its DriverSeat (UX only; the server re-checks).
local function drivenRoot()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not (seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat") then return nil end
	local model = seat:FindFirstAncestorOfClass("Model")
	while model and model:GetAttribute("OwnerUserId") == nil do model = model:FindFirstAncestorOfClass("Model") end
	if not model or tonumber(model:GetAttribute("OwnerUserId")) ~= localPlayer.UserId then return nil end
	return model.PrimaryPart or model:FindFirstChild("CockpitRoot_DoNotRename", true)
end

local function myPosition()
	local root = drivenRoot()
	if root then return root.Position end
	local character = localPlayer.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or nil
end

-- MapMarkers (owned by the map UI; optional until installed) ------------------------------------------

local function markers()
	if markersModule ~= nil then return markersModule or nil end
	local game_ = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Game")
	local ui = game_ and game_:FindFirstChild("UI")
	local module = ui and ui:FindFirstChild("MapMarkers")
	if not module then return nil end -- not installed yet; retried on the next sync
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" and type(result.Set) == "function" and type(result.Remove) == "function" then
		markersModule = result
	else
		markersModule = false
		warn("[JobClient] MapMarkers unavailable: " .. tostring(result))
	end
	return markersModule or nil
end

local function setMarker(id, marker)
	local api = markers()
	if not api then return false end
	local ok, err = pcall(api.Set, id, marker)
	if ok then markerIds[id] = true else warn("[JobClient] marker failed: " .. tostring(err)) end
	return ok
end

local function removeMarker(id)
	if not markerIds[id] then return end
	markerIds[id] = nil
	local api = markers()
	if api then pcall(api.Remove, id) end
end

-- Offers -----------------------------------------------------------------------------------------------

local function offerLabel(entry)
	local spec = kinds[entry.Kind]
	local title = spec and spec.Title or string.upper(entry.Kind)
	local label = type(entry.Label) == "string" and entry.Label ~= "" and (" · " .. string.upper(entry.Label)) or ""
	return string.format("%s%s · %s TRIP · ~%s", title, label, JobRules.Miles(entry.Distance), JobRules.Money(entry.Estimate))
end

local function offerVisible(entry)
	return trip == nil and kinds[entry.Kind] ~= nil and kindEnabled(entry.Kind)
end

local function readEntry(entry)
	local item = entry.Instance
	entry.Kind = tostring(item:GetAttribute("Kind") or "")
	local position = item:GetAttribute("Position")
	entry.Position = typeof(position) == "Vector3" and position or nil
	entry.Distance = tonumber(item:GetAttribute("Distance")) or 0
	entry.Estimate = tonumber(item:GetAttribute("Estimate")) or 0
	entry.Label = item:GetAttribute("Label")
	entry.MarkerDirty = true
end

local function dropProp(entry)
	if entry.RemoveBeacon then entry.RemoveBeacon() entry.RemoveBeacon = nil end
	if entry.Prop then entry.Prop:Destroy() end
	entry.Prop, entry.Prompt = nil, nil
end

local function acceptOffer(offerId)
	if accepting or trip then return end
	accepting = true
	lastAcceptId = offerId
	for _, entry in pairs(offers) do
		if entry.Prompt then entry.Prompt.Enabled = false end
	end
	task.spawn(function()
		local reply = ctx.Invoke("JobAccept", { OfferId = offerId })
		accepting = false
		if not (reply and reply.Ok) then
			ctx.Toast((reply and reply.Message) or "Couldn't take that job.", 3)
		end
	end)
end

local function ensureProp(entry)
	if entry.Prop or not entry.Position then return end
	local spec = kinds[entry.Kind]
	local anchor = Instance.new("Part")
	anchor.Name = "JobOffer_" .. entry.Id
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2, 2, 2)
	anchor.CFrame = CFrame.new(entry.Position + Vector3.new(0, 3, 0))
	local id = entry.Id
	if spec.BuildProp then
		local ok, err = pcall(spec.BuildProp, entry, anchor, ctx)
		if not ok then warn("[JobClient] prop failed: " .. tostring(err)) end
	end
	anchor.Parent = propsFolder
	entry.Prop = anchor
	-- The pillar starts above head height so it never hides the fare or the parcel stack.
	entry.RemoveBeacon = ctx.UI.Beacon("JobOffer_" .. id, entry.Position + Vector3.new(0, 9, 0), spec.Colour)
end

-- One prompt rides on the player's own car (a local Attachment on its root) and targets the nearest
-- eligible offer. A prompt on the kerb anchor goes off-screen as the driver pulls alongside, and
-- ProximityPrompts only show while on screen.
local driverPrompt = { Attachment = nil, Prompt = nil, TargetId = nil }
local function clearDriverPrompt()
	if driverPrompt.Attachment then driverPrompt.Attachment:Destroy() end
	driverPrompt.Attachment, driverPrompt.Prompt, driverPrompt.TargetId = nil, nil, nil
end
local function updateDriverPrompt(root, target)
	if not (root and target) then
		if driverPrompt.Prompt then driverPrompt.Prompt.Enabled = false end
		driverPrompt.TargetId = nil
		return
	end
	if not (driverPrompt.Attachment and driverPrompt.Attachment.Parent == root) then
		clearDriverPrompt()
		local attachment = Instance.new("Attachment")
		attachment.Name = "JobDriverPrompt" -- client-local; never replicated
		attachment.Position = Vector3.new(0, 4, 0)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "JobPrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		prompt.MaxActivationDistance = 30 -- the prompt sits on the car, so the driver is always in range
		prompt.Enabled = false
		prompt.Parent = attachment
		prompt.Triggered:Connect(function()
			if driverPrompt.TargetId then acceptOffer(driverPrompt.TargetId) end
		end)
		attachment.Parent = root
		driverPrompt.Attachment, driverPrompt.Prompt = attachment, prompt
	end
	local spec = kinds[target.Kind]
	driverPrompt.TargetId = target.Id
	driverPrompt.Prompt.ActionText = spec and spec.ActionText or "Take job"
	driverPrompt.Prompt.ObjectText = offerLabel(target)
	driverPrompt.Prompt.Enabled = true
end

local function syncMarkers()
	for id, entry in pairs(offers) do
		local markerId = "JobOffer_" .. id
		local spec = kinds[entry.Kind]
		if entry.Position and spec and offerVisible(entry) then
			if entry.MarkerDirty or not markerIds[markerId] then
				if setMarker(markerId, {
					Position = entry.Position, Icon = spec.Icon, Label = offerLabel(entry), Kind = "Job",
					Priority = 20, Pulse = true, Color = spec.Colour,
				}) then entry.MarkerDirty = false end
			end
		else
			removeMarker(markerId)
		end
	end
end

local function clearOfferRoute()
	if routedOffer then
		routedOffer = nil
		ctx.RouteGuide.Clear(ROUTE_OFFER)
	end
end

local function addOffer(item)
	if not item:IsA("Configuration") or offers[item.Name] then return end
	local entry = { Id = item.Name, Instance = item }
	readEntry(entry)
	offers[entry.Id] = entry
	item.AttributeChanged:Connect(function()
		if offers[entry.Id] ~= entry then return end
		readEntry(entry)
	end)
	syncMarkers()
end

local function removeOffer(item)
	local entry = offers[item.Name]
	if not entry then return end
	offers[item.Name] = nil
	dropProp(entry)
	removeMarker("JobOffer_" .. entry.Id)
	if routedOffer and routedOffer.Id == entry.Id then
		clearOfferRoute()
		if not trip and not accepting and lastAcceptId ~= entry.Id then
			local spec = kinds[entry.Kind]
			ctx.Toast(string.format("THAT %s IS GONE · PICK ANOTHER ON THE MAP", spec and spec.Title or "JOB"), 3)
		end
	end
end

local function nearestOffer(kind, here)
	local best, bestDistance
	for _, entry in pairs(offers) do
		if entry.Kind == kind and entry.Position then
			local distance = here and JobRules.Flat(here, entry.Position) or 0
			if not best or distance < bestDistance then best, bestDistance = entry, distance end
		end
	end
	return best, bestDistance
end

local function routeTo(entry)
	if trip or not (entry and offers[entry.Id] == entry) then return end
	local spec = kinds[entry.Kind]
	routedOffer = { Id = entry.Id, Kind = entry.Kind }
	ctx.RouteGuide.SetDestination(ROUTE_OFFER, entry.Position, { Label = spec.Title, Priority = 45, Kind = "Activity" })
	local here = myPosition()
	ctx.Toast(string.format("ROUTE SET · %s · %s AWAY", spec.Title, here and JobRules.Miles(JobRules.Flat(here, entry.Position)) or "NEARBY"), 3)
end

-- Jobs panel ---------------------------------------------------------------------------------------------

local function jobSubtitle(kind, here)
	local spec = kinds[kind]
	if trip and trip.Kind == kind then
		local left = here and JobRules.Miles(JobRules.Flat(here, trip.Destination)) or "--"
		return "On the job · " .. left .. " to go. Faster pays more; crashes cost."
	elseif trip then
		return "Finish your current job first."
	elseif not kindEnabled(kind) then
		return "Closed right now."
	end
	local entry, distance = nearestOffer(kind, here)
	if not entry then return "None right now. New " .. string.lower(spec.Title) .. "s appear on the map." end
	return string.format("%s away · %s trip · ~%s", JobRules.Miles(distance), JobRules.Miles(entry.Distance), JobRules.Money(entry.Estimate))
end

local function addJobEntry(kind, subtitle)
	local spec = kinds[kind]
	ctx.Jobs.AddEntry({
		Id = "Jobs" .. kind,
		Title = spec.Nearest,
		Subtitle = subtitle,
		Order = spec.Order,
		Buttons = function()
			if trip and trip.Kind == kind then
				return { {
					Text = "CANCEL JOB", Accent = ctx.Theme.Danger,
					OnClick = function()
						local reply = ctx.Invoke("Cancel", {})
						if reply and reply.Ok == false and reply.Message then ctx.Toast(reply.Message, 3) end
					end,
				} }
			end
			local entry = nearestOffer(kind, myPosition())
			return { {
				Text = "SET ROUTE", Enabled = trip == nil and entry ~= nil and kindEnabled(kind),
				OnClick = function() routeTo(entry) end,
			} }
		end,
	})
end

local function refreshJobs(force)
	local here = myPosition()
	for kind in pairs(kinds) do
		local subtitle = jobSubtitle(kind, here)
		if force or entryText[kind] ~= subtitle then
			entryText[kind] = subtitle
			addJobEntry(kind, subtitle)
		end
	end
end

-- Trip -----------------------------------------------------------------------------------------------------

local function endTrip()
	if not trip then return end
	local ended = trip
	trip = nil
	ctx.UI.Strip.Clear(ended.Kind)
	ctx.RouteGuide.Clear(ROUTE_TRIP)
	removeMarker(DESTINATION_MARKER)
	if ended.RemoveBeacon then ended.RemoveBeacon() end
	syncMarkers()
	refreshJobs(true)
end

local function updateTrip(here)
	local spec = kinds[trip.Kind]
	local toGo = here and JobRules.Flat(here, trip.Destination) or 0
	if trip.Boarding or not trip.StartServerTime then
		ctx.UI.Strip.Set(trip.Kind, spec.BoardingText, ctx.Theme.Telemetry)
		return
	end
	local elapsed = Workspace:GetServerTimeNow() - trip.StartServerTime
	local estimate = JobRules.ProjectedPay(trip.Pay, trip.Distance, elapsed, toGo * board.RoadFactor, trip.Crashes)
	local text = string.format("%s  %s  ·  %s  ·  %s", spec.StripTitle, JobRules.Clock(elapsed), JobRules.Miles(toGo), JobRules.Money(estimate))
	if trip.Crashes > 0 then text ..= string.format("  ·  %d %s", trip.Crashes, trip.Crashes == 1 and "CRASH" or "CRASHES") end
	ctx.UI.Strip.Set(trip.Kind, text, trip.Crashes > 0 and ctx.Theme.HighSpeed or ctx.Theme.Telemetry)
	-- RouteGuide clears a source on arrival; bring the route back if the driver overshoots.
	if toGo > 150 and ctx.RouteGuide.GetActive() == nil then
		ctx.RouteGuide.SetDestination(ROUTE_TRIP, trip.Destination, { Label = spec.DropLabel, Priority = 50, Kind = "Activity" })
	end
end

local handlers = {}

handlers.Started = function(kind, payload)
	if typeof(payload.Destination) ~= "Vector3" then return end
	local spec = kinds[kind]
	endTrip()
	clearOfferRoute()
	trip = {
		Kind = kind, TripId = payload.TripId, Destination = payload.Destination,
		Distance = tonumber(payload.Distance) or 0, Pay = JobRules.SafeSnapshot(payload.Pay),
		Crashes = 0, Boarding = payload.Boarding == true, StartServerTime = nil,
	}
	for _, entry in pairs(offers) do dropProp(entry) end
	syncMarkers()
	ctx.RouteGuide.SetDestination(ROUTE_TRIP, trip.Destination, { Label = spec.DropLabel, Priority = 50, Kind = "Activity" })
	setMarker(DESTINATION_MARKER, {
		Position = trip.Destination, Icon = spec.DropIcon, Label = spec.DropLabel, Kind = "Activity",
		Priority = 60, EdgeClamp = true, Color = ctx.Theme.HighSpeed,
	})
	trip.RemoveBeacon = ctx.UI.Beacon(DESTINATION_MARKER, trip.Destination, ctx.Theme.HighSpeed)
	ctx.Toast(spec.StartedText(payload), 3.5)
	refreshJobs(true)
end

handlers.Driving = function(_, payload)
	if not trip or payload.TripId ~= trip.TripId then return end
	trip.Boarding = false
	trip.StartServerTime = tonumber(payload.ServerStartTime) or Workspace:GetServerTimeNow()
end

handlers.Crash = function(_, payload)
	if not trip or payload.TripId ~= trip.TripId then return end
	trip.Crashes = math.max(trip.Crashes, tonumber(payload.Crashes) or trip.Crashes + 1)
	local factor = tonumber(payload.DamageFactor) or 1
	ctx.Toast(string.format("CRASH! PAY NOW x%.2f", factor), 1.8)
end

handlers.Completed = function(kind, payload)
	local spec = kinds[kind]
	endTrip()
	local speedBonus = tonumber(payload.SpeedBonus) or 0
	local parts = {
		spec.DoneTitle .. " +" .. JobRules.Money(payload.Cash),
		"BASE " .. JobRules.Money(payload.Base),
		"SPEED " .. (speedBonus >= 0 and "+" or "") .. JobRules.Money(speedBonus),
	}
	if (tonumber(payload.CrashPenalty) or 0) > 0 then
		table.insert(parts, string.format("%d CRASH%s -%s", tonumber(payload.Crashes) or 0, (tonumber(payload.Crashes) or 0) == 1 and "" or "ES", JobRules.Money(payload.CrashPenalty)))
	end
	if (tonumber(payload.Xp) or 0) > 0 then table.insert(parts, "+" .. math.floor(payload.Xp) .. " XP") end
	if payload.Capped then table.insert(parts, "HOURLY JOB CAP REACHED") end
	ctx.Toast(table.concat(parts, " · "), 6)
end

handlers.Failed = function(kind, payload)
	endTrip()
	ctx.Toast(kinds[kind].FailTitle .. string.upper(tostring(payload.Reason or "")), 4)
end

handlers.Cancelled = function(kind, payload)
	endTrip()
	ctx.Toast(kinds[kind].CancelTitle .. string.upper(tostring(payload.Reason or "")), 4)
end

-- Loop ----------------------------------------------------------------------------------------------------------

local function poll()
	refreshBoard()
	local here = myPosition()
	local root = drivenRoot()
	local mph = 0
	if root then
		local v = root.AssemblyLinearVelocity
		mph = JobRules.Mph(Vector3.new(v.X, 0, v.Z).Magnitude)
	end
	local canPrompt = root ~= nil and mph < board.AcceptMaxMph * 0.8 and not trip and not accepting
	local nearest, nearestDistance = nil, math.huge
	for _, entry in pairs(offers) do
		local distance = (here and entry.Position) and JobRules.Flat(here, entry.Position) or math.huge
		local limit = entry.Prop and (board.StreamRadius + board.StreamHysteresis) or board.StreamRadius
		if offerVisible(entry) and distance <= limit then
			ensureProp(entry)
			if canPrompt and entry.Prop and distance <= board.PromptDistance and (not nearest or distance < nearestDistance) then
				nearest, nearestDistance = entry, distance
			end
		elseif entry.Prop then
			dropProp(entry)
		end
	end
	updateDriverPrompt(canPrompt and root or nil, nearest)
	if trip then updateTrip(here) end
	local now = os.clock()
	if now - slowAt.markers >= 1 then
		slowAt.markers = now
		syncMarkers()
	end
	if now - slowAt.jobs >= 1 then
		slowAt.jobs = now
		refreshJobs(false)
	end
end

local function mirror()
	local stateFolder
	repeat stateFolder = ReplicatedStorage:WaitForChild("ActivityState", 30) until stateFolder
	local folder
	repeat folder = stateFolder:WaitForChild("JobOffers", 30) until folder
	folder.ChildAdded:Connect(addOffer)
	folder.ChildRemoved:Connect(removeOffer)
	for _, child in ipairs(folder:GetChildren()) do addOffer(child) end
end

-- spec = { Kind, Title, Nearest, Icon, DropIcon, ActionText, DropLabel, StripTitle, BoardingText, Colour, Order,
--          StartedText = (payload) -> string, DoneTitle, FailTitle, CancelTitle, BuildProp = (entry, anchor, ctx)? }
function JobClient.RegisterKind(spec)
	assert(type(spec) == "table" and type(spec.Kind) == "string", "JobClient kind spec required")
	kinds[spec.Kind] = spec
	for _, entry in pairs(offers) do entry.MarkerDirty = true end
	if ctx then refreshJobs(true) end
end

function JobClient.Mount(context)
	if mounted then return end
	mounted = true
	ctx = context
	-- Client-local props live inside World scope (World.Runtime), never at the Workspace root.
	local world = Workspace:WaitForChild("World")
	local runtime = world:FindFirstChild("Runtime") or world:WaitForChild("Runtime", 10) or world
	propsFolder = runtime:FindFirstChild("ClientJobProps")
	if propsFolder then propsFolder:ClearAllChildren() else
		propsFolder = Instance.new("Folder")
		propsFolder.Name = "ClientJobProps" -- client-local; never replicated
		propsFolder.Parent = runtime
	end
	task.spawn(mirror)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < POLL_SECONDS then return end
		elapsed = 0
		local ok, err = pcall(poll)
		if not ok then warn("[JobClient] poll failed: " .. tostring(err)) end
	end)
	localPlayer:GetAttributeChangedSignal("ActivityKind"):Connect(function()
		-- The server ended the record (the result event follows); drop the job visuals.
		if trip and localPlayer:GetAttribute("ActivityKind") ~= trip.Kind then endTrip() end
	end)
end

function JobClient.OnEvent(kind, payload)
	if not ctx or not kinds[kind] or type(payload) ~= "table" or type(payload.Type) ~= "string" then return end
	local event = string.sub(payload.Type, #kind + 2)
	local handler = handlers[event]
	if handler then handler(kind, payload) end
end

return JobClient
