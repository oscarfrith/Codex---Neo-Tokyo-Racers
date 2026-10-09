-- Owns race-entry state: mode, page, tier, lap, vehicle choice, the fetched profile and records, and the three calls out (close, start, presentation mode); it creates no instance and owns no layout.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceEntry.RaceEntryModel. Requires: none (everything arrives through deps).
--
-- Classic source: ReplicatedStorage.Modules.Game.Racing.RaceEntryPresentationClient ("C" + line numbers below).
-- Rules that differ from Classic on purpose (API2 5.6 "Required fixes"): replies are fetched here and drawn by the
-- views afterwards; every reply carries the open token it was asked under and is dropped when that open has ended;
-- the personal best and the leaderboard are asked once per event and tier per open.

local Model = {}

-- C40.
local TIERS = { "E", "D", "C", "B", "A", "S" }
local TIER_SET = { E = true, D = true, C = true, B = true, A = true, S = true }
-- C536 and C784 (row order); C46-49 (the medals that have a marker).
local MEDALS = { "Platinum", "Gold", "Silver", "Bronze" }
local KNOWN_MEDAL = { Platinum = true, Gold = true, Silver = true, Bronze = true }
-- C450.
local PLACEMENTS = { { "Gold", "1ST" }, { "Silver", "2ND" }, { "Bronze", "3RD" } }

local BULLET = "  \u{2022}  " -- the Classic separator, C415 and C780
local DOT = " \u{00B7} " -- the Pulse separator (style sheet)
local DASH = "\u{2013}" -- C417
local NO_TIME = "--:--.---"
local LOADING = "LOADING"
local LEADERBOARD_LIMIT = 20 -- C521
local MAX_LAPS = 10 -- C326-327

Model.Tiers = table.freeze(table.clone(TIERS))

-- Small Luau signal: Connect, Once, Fire. A failing listener never stops a reducer (the close and start fires
-- come after the notification).
local function newSignal()
	local connections = {}
	local signal = {}
	local warned = false

	function signal:Connect(callback)
		assert(type(callback) == "function", "[Pulse.RaceEntryModel] Changed:Connect needs a function")
		local connection = { Connected = true }
		function connection:Disconnect()
			if not connection.Connected then
				return
			end
			connection.Connected = false
			local index = table.find(connections, connection)
			if index then
				table.remove(connections, index)
			end
		end
		connection.Callback = callback
		table.insert(connections, connection)
		return connection
	end

	function signal:Once(callback)
		local connection
		connection = signal:Connect(function(...)
			connection:Disconnect()
			callback(...)
		end)
		return connection
	end

	function signal:Fire(...)
		for _, connection in ipairs(table.clone(connections)) do
			if connection.Connected then
				local ok, problem = pcall(connection.Callback, ...)
				if not ok and not warned then
					warned = true
					warn("[Pulse.RaceEntryModel] a Changed listener failed: " .. tostring(problem))
				end
			end
		end
	end

	return signal
end

-- Pure helpers (exported with a leading underscore for the tests) ---------------------------------------------

-- C91-96.
function Model._timeText(seconds)
	seconds = tonumber(seconds) or 0
	if seconds <= 0 then
		return NO_TIME
	end
	local minutes = math.floor(seconds / 60)
	return string.format("%d:%06.3f", minutes, seconds - minutes * 60)
end

-- C98-101. `parent` is Config.Racing.Rewards.Race or nil.
local function numberAttribute(parent, name, fallback)
	local value = parent and tonumber(parent:GetAttribute(name))
	return value == nil and fallback or value
end

-- C103-108, unchanged: the prize preview is a projection of what the server pays.
function Model._roundedRacePrize(raceRewards, baseReward, medal)
	local multiplier = numberAttribute(raceRewards, medal .. "RewardMultiplier", medal == "Gold" and 1 or medal == "Silver" and 0.85 or 0.65)
	local nearest = math.max(1, numberAttribute(raceRewards, "RewardRoundToNearest", 250))
	local amount = math.floor(((tonumber(baseReward) or 0) * multiplier) / nearest + 0.5) * nearest
	return math.clamp(amount, numberAttribute(raceRewards, "MinReward", 0), numberAttribute(raceRewards, "MaxReward", 10000))
end

-- C298-309.
function Model._pairedEventId(payload, summary, mode)
	summary = summary or {}
	if mode == "Race" then
		local paired = tostring(payload and payload.RaceEventId or "")
		if paired ~= "" then
			return paired
		end
		local id = tostring(payload and payload.EventId or summary.EventId or "")
		return id:sub(-3) == "_tt" and (id:sub(1, -4) .. "_race") or id
	end
	local paired = tostring(payload and payload.TimeTrialEventId or "")
	if paired ~= "" then
		return paired
	end
	local id = tostring(payload and payload.EventId or summary.EventId or "")
	return id:sub(-5) == "_race" and (id:sub(1, -6) .. "_tt") or id
end

-- C325-329.
function Model._lapBounds(summary)
	summary = summary or {}
	local minLap = math.clamp(math.floor(tonumber(summary.MinLapCount) or 1), 1, MAX_LAPS)
	local maxLap = math.clamp(math.floor(tonumber(summary.MaxLapCount) or MAX_LAPS), minLap, MAX_LAPS)
	return minLap, maxLap
end

-- C733, C443, C630.
function Model._lapText(laps)
	return tostring(laps) .. (laps == 1 and " LAP" or " LAPS")
end

-- C211-225: which tiers the profile owns, and the highest of them (E when none).
function Model._ownedTiers(profile)
	local owned = {}
	local summaries = type(profile) == "table" and profile.VehicleSummaries or nil
	for _, vehicleSummary in pairs(type(summaries) == "table" and summaries or {}) do
		local overall = type(vehicleSummary) == "table" and type(vehicleSummary.Overall) == "table" and vehicleSummary.Overall or {}
		local tier = string.upper(tostring(overall.Tier or ""))
		if tier ~= "" then
			owned[tier] = true
		end
	end
	local selected = "E"
	for index = #TIERS, 1, -1 do
		if owned[TIERS[index]] then
			selected = TIERS[index]
			break
		end
	end
	return owned, selected
end

-- RacingUIComponents.Asset (36-42), which C79 and C664 pass every image through.
function Model._image(value)
	local text = tostring(value or "")
	if text == "" then
		return ""
	end
	if string.find(text, "rbxassetid://", 1, true) or string.find(text, "rbxthumb://", 1, true) then
		return text
	end
	if tonumber(text) then
		return "rbxassetid://" .. text
	end
	return text
end

-- One walk of the catalogue instead of two per vehicle (C237-246 and C276-280). Image and Name come from the
-- FIRST cockpit with that id (C239 returns there); Category comes from the LAST category that holds it (C278
-- breaks only the inner loop).
function Model._indexCatalog(catalog)
	local index = {}
	local categories = type(catalog) == "table" and catalog.Categories or nil
	for _, category in ipairs(type(categories) == "table" and categories or {}) do
		local cockpitList = type(category) == "table" and category.Cockpits or nil
		local seenHere = {}
		for _, cockpit in ipairs(type(cockpitList) == "table" and cockpitList or {}) do
			if type(cockpit) == "table" then
				local id = tostring(cockpit.CockpitId or cockpit.Id or "")
				local entry = index[id]
				if not entry then
					local image = cockpit.MenuImage or cockpit.Image or cockpit.Icon or cockpit.Thumbnail
					entry = {
						Image = (type(image) == "string" and image ~= "") and image or "",
						Name = tostring(cockpit.DisplayName or cockpit.Name or id or "VEHICLE"),
						Category = "OTHER",
					}
					index[id] = entry
				end
				if not seenHere[id] then
					seenHere[id] = true
					entry.Category = string.upper(tostring(category.DisplayName or category.Name or category.Id or "OTHER"))
				end
			end
		end
	end
	return index
end

-- C232-236 and C270-274.
function Model._cockpitId(profile, vehicle)
	local cockpitId = tostring(vehicle.CockpitId or "")
	if cockpitId == "" and vehicle.CockpitInstanceId then
		local instances = type(profile) == "table" and profile.OwnedCockpitInstances or nil
		local instance = type(instances) == "table" and instances[vehicle.CockpitInstanceId] or nil
		cockpitId = tostring(type(instance) == "table" and instance.TemplateId or "")
	end
	return cockpitId
end

-- Pulse order (style sheet review 2): rating, highest first. Then name (C288), then id so the order is total.
function Model._sortRows(rows)
	table.sort(rows, function(a, b)
		if a.Rating ~= b.Rating then
			return a.Rating > b.Rating
		end
		if a.Name ~= b.Name then
			return a.Name < b.Name
		end
		return a.VehicleId < b.VehicleId
	end)
	return rows
end

-- C268: a race takes every owned vehicle; a time trial takes the selected tier only.
function Model._eligible(mode, rowTier, selectedTier)
	return mode == "Race" or rowTier == selectedTier
end

-- Constructor -------------------------------------------------------------------------------------------------

-- deps = {
--   Remotes   = { RaceRequest = RemoteFunction, GarageInvoke = RemoteFunction },
--   Bindables = { LegacyAction = BindableEvent,                       -- Runtime.Racing.RaceEntryLegacyAction
--                 PresentationMode = () -> BindableEvent? },          -- Runtime.UI.FreeRoamHudPresentationMode, looked up per fire (C344-346)
--   Catalog   = GarageCatalogClient ({Fetch}), RaceConfig = RaceConfigReader ({GetEventSummary, GetTimeTrialMedals}),
--   Money     = (amount) -> string,                                   -- Kit.Data.Money(amount, false)
--   UserId    = number,
--   RaceRewards = Instance?,                                          -- Config.Racing.Rewards.Race (attributes)
--   RaceCatalogEvent = ((eventId) -> Instance?)?,                     -- Config.Racing.RaceCatalog.<eventId>
--   Copy = ((name) -> string?)?,                                      -- Config.UI.Racing.Copy.<name>.Value
--   PreviewCategories = (() -> Instance?)?,                           -- ReplicatedStorage.Assets.VehiclePreviews.Categories
--   Presence = Kit.Presence?, Spawn = task.spawn }
function Model.new(deps)
	assert(type(deps) == "table", "[Pulse.RaceEntryModel] deps is required")
	local remotes = deps.Remotes
	local bindables = deps.Bindables
	assert(type(remotes) == "table" and remotes.RaceRequest ~= nil and remotes.GarageInvoke ~= nil, "[Pulse.RaceEntryModel] deps.Remotes needs RaceRequest and GarageInvoke")
	assert(type(bindables) == "table" and bindables.LegacyAction ~= nil, "[Pulse.RaceEntryModel] deps.Bindables needs LegacyAction")
	assert(type(deps.Catalog) == "table" and type(deps.RaceConfig) == "table", "[Pulse.RaceEntryModel] deps needs Catalog and RaceConfig")
	assert(type(deps.Money) == "function", "[Pulse.RaceEntryModel] deps.Money is required")
	local spawn = deps.Spawn or task.spawn
	local money = deps.Money
	local raceRewards = deps.RaceRewards

	local self = {}
	local changed = newSignal()
	self.Changed = changed

	-- C55-65.
	local payload = {}
	local summary = nil
	local selectedMode = "TimeTrial"
	local selectedTier = "E"
	local selectedLap = 1
	local currentPage = "Setup"
	local selectedVehicleId = ""
	local ownedTiers = {}
	local garageProfile, garageCatalog = nil, nil

	local open = false
	local ready = false -- the profile reply of this open has been applied
	local token = 0 -- one per open and per close; replies compare it
	local revision = 0 -- one per notification; the views' render token
	local snapshot = nil
	local cockpits = {}
	local best, boards, medalCache, summaryCache = {}, {}, {}, {}
	local rowCache, rowCacheKey = nil, nil
	local releasePresence = nil

	local function notify(reason)
		revision += 1
		snapshot = nil
		changed:Fire(reason)
	end

	-- C72-76. The one remote function of this owner; every call site below matches contract.json.
	local function call(remote, action, data)
		local ok, result = pcall(function()
			if remote == remotes.GarageInvoke and action == "GetInitial" then
				return deps.Catalog.Fetch(remote, data)
			end
			return remote:InvokeServer(action, data or {})
		end)
		if ok and type(result) == "table" then
			return result
		end
		return { Ok = false, Success = false, Message = tostring(result) }
	end

	local function pairedEventId(mode)
		return Model._pairedEventId(payload, summary, mode)
	end

	local function lapBounds()
		return Model._lapBounds(summary)
	end

	-- RaceConfigReader.GetEventSummary for the paired event of `mode`, or nil (C316-318, C333).
	local function eventSummary(mode)
		local cached = summaryCache[mode]
		if cached == nil then
			local eventId = pairedEventId(mode)
			local ok, result = pcall(function()
				return deps.RaceConfig.GetEventSummary(eventId, mode)
			end)
			cached = (ok and type(result) == "table") and result or false
			summaryCache[mode] = cached
		end
		return cached or nil
	end

	-- C331-335.
	local function modeSummary(mode)
		return eventSummary(mode) or summary
	end

	-- C311-323: Race catalogue first, then Time Trial catalogue, then the payload summary.
	local function browserMedia(field)
		for _, mode in ipairs({ "Race", "TimeTrial" }) do
			local found = eventSummary(mode)
			local value = found and tostring(found[field] or "") or ""
			if value ~= "" then
				return value
			end
		end
		return tostring(summary[field] or "")
	end

	-- C337-341.
	local function raceCatalogAttribute(name)
		local event = deps.RaceCatalogEvent and deps.RaceCatalogEvent(pairedEventId("Race")) or nil
		return event and event:GetAttribute(name)
	end

	-- C293-296.
	local function copyValue(name, fallback)
		local value = deps.Copy and deps.Copy(name) or nil
		return type(value) == "string" and value or fallback
	end

	-- C343-347, on every device (API2 5.6; the Classic touch branch C348-359 is not carried).
	local function publishPresentation(active)
		local event = bindables.PresentationMode and bindables.PresentationMode() or nil
		if event then
			event:Fire({ Owner = "RaceEntry", Active = active == true, KeepTelemetry = false })
		end
	end

	-- C360-363. The views read Open from the snapshot and show or hide the layer root.
	local function setOpen(value)
		publishPresentation(value)
		open = value
		local presence = deps.Presence
		if presence then
			if value and not releasePresence then
				releasePresence = presence.Open("RaceEntry", "FullMenu")
			elseif not value and releasePresence then
				local release = releasePresence
				releasePresence = nil
				release()
			end
		end
	end

	-- C247-258: art taken from the preview models when the catalogue has no entry for the cockpit.
	local function previewPresentation(cockpitId)
		local categories = deps.PreviewCategories and deps.PreviewCategories() or nil
		for _, category in ipairs(categories and categories:GetChildren() or {}) do
			local cockpitRoot = category:FindFirstChild("COCKPITS_ReplaceAssetsHere")
			for _, model in ipairs(cockpitRoot and cockpitRoot:GetChildren() or {}) do
				if model:IsA("Model") and (model.Name == cockpitId or tostring(model:GetAttribute("CockpitId") or "") == cockpitId) then
					local image = model:GetAttribute("MenuImage")
					if type(image) == "string" and image ~= "" then
						return image, tostring(model:GetAttribute("DisplayName") or model.Name)
					end
				end
			end
		end
		return nil, nil
	end

	-- C227-260.
	local function vehiclePresentationForId(vehicleId)
		vehicleId = tostring(vehicleId or "")
		if vehicleId == "" or not garageProfile then
			return "", "VEHICLE"
		end
		local vehicles = garageProfile.Vehicles
		local vehicle = type(vehicles) == "table" and (vehicles[vehicleId] or vehicles[tonumber(vehicleId)]) or nil
		if type(vehicle) ~= "table" then
			return "", "VEHICLE"
		end
		local cockpitId = Model._cockpitId(garageProfile, vehicle)
		local entry = cockpits[cockpitId]
		if entry then
			return entry.Image, entry.Name
		end
		local image, name = previewPresentation(cockpitId)
		if image then
			return image, name
		end
		return "", cockpitId ~= "" and cockpitId or "VEHICLE"
	end

	-- C262-291 with the Pulse sort. Every owned vehicle is listed; Eligible is the Classic filter (C268), and
	-- only eligible rows can be selected or started.
	local function vehicleRows()
		local key = selectedMode .. "|" .. selectedTier
		if rowCache and rowCacheKey == key then
			return rowCache
		end
		local rows = {}
		local profile = garageProfile
		local vehicles = profile and profile.Vehicles or nil
		for vehicleId, vehicle in pairs(type(vehicles) == "table" and vehicles or {}) do
			if type(vehicle) == "table" then
				local summaries = profile.VehicleSummaries
				local summaryData = type(summaries) == "table" and (summaries[vehicleId] or summaries[tostring(vehicleId)]) or nil
				local overall = type(summaryData) == "table" and type(summaryData.Overall) == "table" and summaryData.Overall or {}
				local tier = string.upper(tostring(overall.Tier or "--"))
				local image, name = vehiclePresentationForId(vehicleId)
				local cockpitId = Model._cockpitId(profile, vehicle)
				local entry = cockpits[cockpitId]
				table.insert(rows, {
					VehicleId = tostring(vehicleId),
					CockpitId = cockpitId,
					Name = name,
					Image = Model._image(image),
					Tier = tier,
					Rating = tonumber(overall.PerformanceIndex) or 0,
					Category = entry and entry.Category or "OTHER",
					Eligible = Model._eligible(selectedMode, tier, selectedTier),
				})
			end
		end
		Model._sortRows(rows)
		rowCache, rowCacheKey = rows, key
		return rows
	end

	-- The Classic list (C262-283): what may be chosen and what Start looks the cockpit up in.
	local function eligibleRows()
		local rows = {}
		for _, row in ipairs(vehicleRows()) do
			if row.Eligible then
				table.insert(rows, row)
			end
		end
		return rows
	end

	-- C623-625.
	local function ensureVehicle()
		local rows = eligibleRows()
		for _, row in ipairs(rows) do
			if row.VehicleId == selectedVehicleId then
				return
			end
		end
		selectedVehicleId = rows[1] and rows[1].VehicleId or ""
	end

	-- C213-224.
	local function applyProfile(result)
		local profile = result.Profile or result
		garageProfile = type(profile) == "table" and profile or nil
		if type(result.Catalog) == "table" then
			garageCatalog = result.Catalog
		end
		cockpits = Model._indexCatalog(garageCatalog)
		rowCache, rowCacheKey = nil, nil
		ownedTiers, selectedTier = Model._ownedTiers(garageProfile)
	end

	-- C763 and C516, once per event and tier per open. Classic asks while it draws the time-trial Setup and
	-- Records pages; the same two pages ask here.
	local function requestBest()
		if not (open and ready and selectedMode == "TimeTrial" and currentPage ~= "Vehicles") then
			return
		end
		local eventId = pairedEventId("TimeTrial")
		local tier = selectedTier
		local key = eventId .. "|" .. tier
		if best[key] then
			return
		end
		local entry = { State = "Loading" }
		best[key] = entry
		local mine = token
		spawn(function()
			local reply = call(remotes.RaceRequest, "GetTimeTrialPersonalBest", { EventId = eventId, VehicleTier = tier })
			if mine ~= token then
				return
			end
			entry.State = "Ready"
			entry.Reply = reply
			notify("Best")
		end)
	end

	-- C521, once per event and tier per open, asked when the Records page is entered.
	local function requestBoard()
		if not (open and ready and selectedMode == "TimeTrial" and currentPage == "Records") then
			return
		end
		local eventId = pairedEventId("TimeTrial")
		local tier = selectedTier
		local key = eventId .. "|" .. tier
		if boards[key] then
			return
		end
		local entry = { State = "Loading" }
		boards[key] = entry
		local mine = token
		spawn(function()
			local reply = call(remotes.RaceRequest, "GetTimeTrialLeaderboard", { EventId = eventId, VehicleTier = tier, Limit = LEADERBOARD_LIMIT })
			if mine ~= token then
				return
			end
			entry.State = "Ready"
			entry.Reply = reply
			notify("Board")
		end)
	end

	-- Reducers ------------------------------------------------------------------------------------------------

	-- C880-892. The page is drawn at once from this state (footer included); the profile follows.
	function self.Open(entryPayload)
		token += 1
		local mine = token
		payload = type(entryPayload) == "table" and entryPayload or {}
		summary = type(payload.Summary) == "table" and payload.Summary or {}
		selectedMode = "TimeTrial"
		currentPage = "Setup"
		local minLap, maxLap = lapBounds()
		selectedLap = math.clamp(math.floor(tonumber(summary.DefaultLapCount or summary.Laps) or 1), minLap, maxLap)
		selectedVehicleId = ""
		selectedTier = "E"
		ownedTiers = {}
		ready = false
		best, boards, medalCache, summaryCache = {}, {}, {}, {}
		rowCache, rowCacheKey = nil, nil
		setOpen(true)
		notify("Open")
		spawn(function()
			local result = call(remotes.GarageInvoke, "GetInitial", {})
			if mine ~= token then
				return
			end
			applyProfile(result)
			ready = true
			notify("Profile")
			requestBest()
		end)
	end

	-- C481 and C807.
	function self.Exit()
		if not open then
			return false
		end
		token += 1
		setOpen(false)
		notify("Close")
		bindables.LegacyAction:Fire("Close")
		return true
	end

	-- C869-870. Works from every page, as Classic's tabs do, and always lands on Setup.
	function self.SelectMode(mode)
		if not open or (mode ~= "TimeTrial" and mode ~= "Race") then
			return false
		end
		if selectedMode == mode and currentPage == "Setup" then
			return false
		end
		selectedMode = mode
		currentPage = "Setup"
		rowCache, rowCacheKey = nil, nil
		notify("Mode")
		requestBest()
		return true
	end

	-- C396. Unowned tiers can be selected (their targets show; the gate is on NEXT and CHOOSE).
	function self.SelectTier(tier)
		if not (open and ready and selectedMode == "TimeTrial" and currentPage == "Setup") then
			return false
		end
		if TIER_SET[tier] ~= true or tier == selectedTier then
			return false
		end
		selectedTier = tier
		rowCache, rowCacheKey = nil, nil
		notify("Tier")
		requestBest()
		return true
	end

	-- C737-738 (minus and plus), as one clamped setter for Kit.Controls.Stepper.
	function self.SetLap(value)
		if not (open and selectedMode == "TimeTrial" and currentPage == "Setup") then
			return false
		end
		local minLap, maxLap = lapBounds()
		local lap = math.clamp(math.floor(tonumber(value) or selectedLap), minLap, maxLap)
		if lap == selectedLap then
			return false
		end
		selectedLap = lap
		notify("Lap")
		return true
	end

	function self.StepLap(delta)
		return self.SetLap(selectedLap + (tonumber(delta) or 0))
	end

	-- C808-812: time-trial Setup to Records.
	function self.Next()
		if not (open and ready and selectedMode == "TimeTrial" and currentPage == "Setup") then
			return false
		end
		if not ownedTiers[selectedTier] then
			return false
		end
		currentPage = "Records"
		notify("Page")
		requestBest()
		requestBoard()
		return true
	end

	-- To the Vehicles page: C482-488 (race Setup, no ownership gate, the lap count becomes the race's),
	-- C605-611 (Records), and the Setup shortcut of the programme contract section 8 with the Records gate.
	function self.ChooseVehicle()
		if not (open and ready) or currentPage == "Vehicles" then
			return false
		end
		if selectedMode == "Race" then
			local race = modeSummary("Race")
			selectedLap = math.max(1, math.floor(tonumber(race.Laps or race.DefaultLapCount) or 1))
		elseif not ownedTiers[selectedTier] then
			return false
		end
		selectedVehicleId = ""
		currentPage = "Vehicles"
		rowCache, rowCacheKey = nil, nil
		ensureVehicle()
		notify("Page")
		return true
	end

	-- C604 (Records to Setup) and C673 (Vehicles to Setup in a race, to Records in a time trial).
	function self.Back()
		if not open then
			return false
		end
		if currentPage == "Records" then
			currentPage = "Setup"
		elseif currentPage == "Vehicles" then
			currentPage = selectedMode == "Race" and "Setup" or "Records"
		else
			return false
		end
		notify("Page")
		requestBest()
		requestBoard()
		return true
	end

	-- C665.
	function self.SelectVehicle(vehicleId)
		if not (open and currentPage == "Vehicles") then
			return false
		end
		vehicleId = tostring(vehicleId or "")
		if vehicleId == selectedVehicleId then
			return false
		end
		for _, row in ipairs(eligibleRows()) do
			if row.VehicleId == vehicleId then
				selectedVehicleId = vehicleId
				notify("Vehicle")
				return true
			end
		end
		return false
	end

	-- C674-680. Closing first is the only guard Classic has against a second press; it is kept.
	function self.Start()
		if not (open and currentPage == "Vehicles") then
			return false
		end
		if selectedVehicleId == "" then
			return false
		end
		local selectedRow = nil
		for _, row in ipairs(eligibleRows()) do
			if row.VehicleId == selectedVehicleId then
				selectedRow = row
				break
			end
		end
		token += 1
		setOpen(false)
		notify("Close")
		bindables.LegacyAction:Fire("StartSelectedVehicle", { Mode = selectedMode, EventId = pairedEventId(selectedMode), VehicleId = selectedVehicleId, CockpitId = selectedRow and selectedRow.CockpitId, Tier = selectedTier, LapCount = selectedLap })
		return true
	end

	-- Getters -------------------------------------------------------------------------------------------------

	function self.IsOpen()
		return open
	end

	function self.Revision()
		return revision
	end

	function self.Token()
		return token
	end

	function self.Mode()
		return selectedMode
	end

	function self.Page()
		return currentPage
	end

	function self.Tier()
		return selectedTier
	end

	function self.Lap()
		return selectedLap
	end

	function self.SelectedVehicle()
		return selectedVehicleId
	end

	function self.LapText(laps)
		return Model._lapText(laps)
	end

	-- Snapshot ------------------------------------------------------------------------------------------------

	local function checkpointCount(source)
		return math.max(0, math.floor(tonumber(source.CheckpointCount or summary.CheckpointCount) or 0))
	end

	local function tierList()
		local list = {}
		for index, tier in ipairs(TIERS) do
			list[index] = { Tier = tier, Owned = ownedTiers[tier] == true }
		end
		return list
	end

	-- C764-767 and C517-520, from the cached reply.
	local function bestView()
		local entry = best[pairedEventId("TimeTrial") .. "|" .. selectedTier]
		local pb = entry and entry.State == "Ready" and entry.Reply or nil
		local record = pb and type(pb.Record) == "table" and pb.Record or nil
		local pbSeconds = pb and tonumber(pb.BestSeconds or (record and record.BestSeconds)) or nil
		local pbMedal = pb and tostring(pb.BestMedal or (record and record.BestMedal) or "--") or "--"
		local pbVehicleId = pb and tostring(pb.BestVehicleId or (record and record.BestVehicleId) or "") or ""
		local _, pbVehicleName = vehiclePresentationForId(pbVehicleId)
		return {
			Loading = pb == nil,
			Has = pbSeconds ~= nil,
			TimeText = pbSeconds and Model._timeText(pbSeconds) or NO_TIME,
			Medal = (pbSeconds and KNOWN_MEDAL[pbMedal]) and pbMedal or "",
			MedalText = string.upper(pbSeconds and pbMedal or "--"),
			VehicleText = string.upper(tostring(pbSeconds and pbVehicleName or "NO VEHICLE RECORD")),
		}
	end

	-- C762 and C515, protected (API2 5.6), read once per tier per open.
	local function medalRows(bestMedal)
		local eventId = pairedEventId("TimeTrial")
		local key = eventId .. "|" .. selectedTier
		local medals = medalCache[key]
		if not medals then
			local ok, result = pcall(function()
				return deps.RaceConfig.GetTimeTrialMedals(eventId, selectedTier)
			end)
			medals = (ok and type(result) == "table") and result or {}
			medalCache[key] = medals
		end
		local rows = {}
		for index, name in ipairs(MEDALS) do
			local yours = bestMedal == name
			rows[index] = { Id = name, Label = string.upper(name) .. (yours and (DOT .. "YOURS") or ""), Time = Model._timeText(medals[name]), Yours = yours }
		end
		return rows
	end

	local function gateText()
		return "OWN A " .. selectedTier .. " CLASS VEHICLE TO ENTER" -- C601 and C804
	end

	-- C683-813 as data.
	local function buildSetup()
		local owned = ownedTiers[selectedTier] == true
		local minLap, maxLap = lapBounds()
		local bestNow = bestView()
		local lapText = Model._lapText(selectedLap)
		local checkpoints = checkpointCount(summary)
		return {
			Tiers = tierList(),
			Info = lapText .. DOT .. tostring(checkpoints) .. " CHECKPOINTS",
			InfoShort = lapText .. DOT .. tostring(checkpoints) .. " CP",
			MapImage = Model._image(browserMedia("MapImage")),
			Lap = selectedLap,
			MinLap = minLap,
			MaxLap = maxLap,
			LapText = lapText,
			PrizeLabel = "TIER " .. selectedTier .. DOT .. "PLATINUM PRIZE", -- C755 with the tier in words
			PrizeText = money(summary.BaseReward or 0), -- C756
			BonusText = "DAILY BONUS " .. copyValue("DailyBonusDisplay", "2X"), -- C758-759
			Best = bestNow,
			BestCaption = "YOUR BEST" .. BULLET .. bestNow.VehicleText, -- C780
			Medals = medalRows(bestNow.Medal),
			RecordsText = "VIEW RECORDS", -- Classic NEXT (C804)
			RecordsShort = "RECORDS",
			ChooseText = (not ready) and LOADING or (owned and "CHOOSE VEHICLE" or gateText()),
			Enabled = ready and owned,
		}
	end

	-- C400-476 as data.
	local function buildRace()
		local race = modeSummary("Race")
		local laps = math.max(1, math.floor(tonumber(race.Laps or race.DefaultLapCount) or 1))
		local minPlayers = math.max(1, math.floor(tonumber(race.MinPlayers) or 2))
		local maxPlayers = math.max(minPlayers, math.floor(tonumber(race.MaxPlayers) or 6))
		local checkpoints = checkpointCount(race)
		local lengthMiles = tonumber(raceCatalogAttribute("TrackLengthMiles") or race.TrackLengthMiles or summary.TrackLengthMiles)
		if lengthMiles and lengthMiles <= 0 then
			lengthMiles = nil
		end
		local baseReward = tonumber(race.BaseReward or summary.BaseReward) or 0
		local prizes = {}
		for index, placement in ipairs(PLACEMENTS) do
			local amount = Model._roundedRacePrize(raceRewards, baseReward, placement[1])
			prizes[index] = { Id = placement[2], Label = placement[2], Medal = placement[1], Amount = amount, Text = money(amount) }
		end
		return {
			Facts = {
				"OPEN CATEGORY",
				"CIRCUIT" .. BULLET .. tostring(laps) .. " LAPS",
				lengthMiles and string.format("TRACK LENGTH" .. BULLET .. "%.2f MI", lengthMiles) or ("TRACK LENGTH" .. BULLET .. "-- MI"),
				tostring(minPlayers) .. DASH .. tostring(maxPlayers) .. " PLAYERS",
			},
			MapImage = Model._image(browserMedia("MapImage")),
			MapLabel = "MULTIPLAYER RACE",
			Name = string.upper(tostring(race.DisplayName or summary.DisplayName or "RACE")),
			FormatLabel = "RACE FORMAT",
			FormatText = Model._lapText(laps),
			PrizesLabel = "PLACEMENT PRIZES",
			Prizes = prizes,
			Stats = {
				{ Id = "Checkpoints", Label = "CHECKPOINTS", Text = tostring(checkpoints) },
				{ Id = "Players", Label = "MAX PLAYERS", Text = tostring(maxPlayers) },
			},
			ChooseText = ready and "CHOOSE VEHICLE" or LOADING,
			Enabled = ready,
		}
	end

	-- C491-611 as data.
	local function buildRecords()
		local owned = ownedTiers[selectedTier] == true
		local bestNow = bestView()
		local entry = boards[pairedEventId("TimeTrial") .. "|" .. selectedTier]
		local reply = entry and entry.State == "Ready" and entry.Reply or nil
		local entries = reply and type(reply.Entries) == "table" and reply.Entries or {}
		local leader = type(entries[1]) == "table" and entries[1] or nil
		local board = { State = "Loading", Message = LOADING, Rows = {} }
		if reply then
			if reply.Ok == true and #entries > 0 then
				board.State = "Rows"
				board.Message = ""
				for index, item in ipairs(entries) do
					if type(item) == "table" then
						local you = tonumber(item.UserId) == deps.UserId
						table.insert(board.Rows, {
							Key = "Row" .. tostring(index),
							You = you,
							Columns = {
								tostring(item.Rank or index),
								string.upper(tostring(item.DisplayName or item.Username or ("PLAYER " .. tostring(item.UserId or "")))),
								string.upper(tostring(item.VehicleName or item.VehicleId or "--")),
								Model._timeText(item.BestSeconds),
							},
						})
					end
				end
			elseif reply.Ok == true then
				board.State = "Empty"
				board.Message = "NO GLOBAL RECORDS YET"
			else
				board.State = "Unavailable"
				board.Message = "GLOBAL RANKINGS UNAVAILABLE\n\nYour personal record is still shown on the left."
			end
		end
		return {
			PageLabel = "RECORDS",
			Tiers = tierList(),
			WorldLabel = "WORLD RECORD" .. DOT .. "TIER " .. selectedTier,
			WorldName = leader and string.upper(tostring(leader.DisplayName or leader.Username or "WORLD RECORD")) or "NO RECORD SET",
			WorldTime = leader and Model._timeText(leader.BestSeconds) or NO_TIME,
			TargetsLabel = "MEDAL TARGETS",
			Medals = medalRows(bestNow.Medal),
			YourLabel = "YOUR RECORD",
			Best = bestNow,
			BoardLabel = "GLOBAL TOP 20",
			Columns = { "POS", "PLAYER", "VEHICLE", "TIME" },
			Board = board,
			ChooseText = owned and "CHOOSE VEHICLE" or gateText(),
			Enabled = owned,
		}
	end

	-- C614-680 as data.
	local function buildVehicles()
		local rows = vehicleRows()
		local race = selectedMode == "Race"
		local selected, position, eligibleCount = nil, 0, 0
		for index, row in ipairs(rows) do
			if row.Eligible then
				eligibleCount += 1
			end
			if row.VehicleId == selectedVehicleId and selectedVehicleId ~= "" then
				selected = row
				position = index
			end
		end
		local facts
		local source = race and modeSummary("Race") or summary
		local lapFact = tostring(selectedLap) .. DOT .. tostring(checkpointCount(source)) .. " CHECKPOINTS"
		if race then
			local minPlayers = math.max(1, math.floor(tonumber(source.MinPlayers) or 2))
			local maxPlayers = math.max(minPlayers, math.floor(tonumber(source.MaxPlayers) or 6))
			local baseReward = tonumber(source.BaseReward or summary.BaseReward) or 0
			facts = {
				{ Id = "Mode", Icon = "race_flag", Label = "MODE", Value = "RACE", Kind = "Text" },
				{ Id = "Laps", Icon = "laps", Label = "LAPS", Value = lapFact, Kind = "Text" },
				{ Id = "Players", Icon = "players", Label = "PLAYERS", Value = tostring(minPlayers) .. DASH .. tostring(maxPlayers), Kind = "Text" },
				{ Id = "Prize", Icon = "trophy", Label = "1ST PRIZE", Value = money(Model._roundedRacePrize(raceRewards, baseReward, "Gold")), Kind = "Prize" },
			}
		else
			facts = {
				{ Id = "Mode", Icon = "race_flag", Label = "MODE", Value = "TIME TRIAL", Kind = "Text" },
				{ Id = "Laps", Icon = "laps", Label = "LAPS", Value = lapFact, Kind = "Text" },
				{ Id = "Best", Icon = "timer", Label = "YOUR BEST", Value = bestView().TimeText, Kind = "Text" },
				{ Id = "Prize", Icon = "trophy", Label = "PLATINUM PRIZE", Value = money(summary.BaseReward or 0), Kind = "Prize" },
			}
		end
		local actionText = race and "JOIN RACE" or "START TIME TRIAL" -- C670
		return {
			Sub = race and "CHOOSE RACE VEHICLE" or "CHOOSE TIME TRIAL VEHICLE", -- C818
			Heading = race and "OPEN CATEGORY" or ("TIER " .. selectedTier), -- C629
			Count = tostring(position) .. "/" .. tostring(#rows),
			Context = string.upper(tostring(summary.DisplayName or "RACE EVENT")) .. BULLET .. Model._lapText(selectedLap), -- C630
			LockedSub = "TIER " .. selectedTier .. " ONLY",
			Rows = rows,
			SelectedId = selectedVehicleId,
			Selected = selected,
			EmptyText = eligibleCount == 0 and (race and "NO OWNED VEHICLES" or ("NO OWNED " .. selectedTier .. " CLASS VEHICLES")) or "", -- C659
			Facts = facts,
			StartText = selectedVehicleId ~= "" and actionText or "SELECT A VEHICLE", -- C671
			Enabled = selectedVehicleId ~= "",
		}
	end

	local function build()
		local snap = {
			Revision = revision,
			Open = open,
			Ready = ready,
			Mode = selectedMode,
			Page = currentPage,
			Tier = selectedTier,
			Lap = selectedLap,
			Title = "RACE ENTRY", -- C852
		}
		if not summary then
			return snap
		end
		snap.Title = string.upper(tostring(summary.DisplayName or "RACE ENTRY")) -- C818
		if not open then
			return snap
		end
		if currentPage == "Records" then
			snap.Records = buildRecords()
		elseif currentPage == "Vehicles" then
			snap.Vehicles = buildVehicles()
		elseif selectedMode == "Race" then
			snap.Race = buildRace()
		else
			snap.Setup = buildSetup()
		end
		return snap
	end

	-- Everything a view draws, for the current revision. deps.Money may yield on its first call (API2 3.5); a
	-- snapshot that was overtaken while it was built is returned with its old Revision and is not cached, so
	-- a view comparing Revision with model.Revision() never draws it.
	function self.Snapshot()
		local cached = snapshot
		if cached and cached.Revision == revision then
			return cached
		end
		local built = build()
		if built.Revision == revision then
			snapshot = built
		end
		return built
	end

	return self
end

return Model
