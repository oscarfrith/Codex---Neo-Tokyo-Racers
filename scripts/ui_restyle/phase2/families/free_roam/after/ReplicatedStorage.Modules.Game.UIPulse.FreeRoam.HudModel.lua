-- Owns the free-roam HUD state and every remote call, bindable fire and player-attribute write of the HUD; no GuiObject, layout or frame step.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.HudModel. Requires: none (every handle arrives in deps).
--
-- Classic line references: D = ReplicatedStorage.Modules.Game.UI.DesktopFreeRoamHudUI, M = ...MobileFreeRoamHudUI.
-- deps = {
--   Player, PlayerGui,                                  instances (or fakes with GetAttribute / SetAttribute)
--   Remotes = { GarageInvoke, TeleportInvoke },         RemoteFunctions
--   FindActivityInvoke = () -> RemoteFunction?,         D608-609: looked up at the press, may be absent
--   Bindables = { Folder, ShowTopNotification, LoadingTransitionInvoke },
--   Catalog (GarageCatalogClient), CategoriesRoot, InputGate (GameplayInputGate),
--   Confirm = (options) -> (),                          Kit.Overlay.Confirm bound to the HUD root by the client
--   OpenFullMap = () -> boolean,                        Routes.Resolve("FullMapUI").Open(), may yield
--   Config = { ProfileRefreshSeconds, PauseFreeRoamMapDuringRace, DefaultControlMode },   cached at start
--   OwnedVehicles = (() -> {Instance})?,                the children of World.Runtime.PlayerVehicles; absent = profile only
--   TouchEnabled, GyroscopeEnabled, Clock, Spawn, Delay }

local Model = {}

Model.CONTROLS_FADE_SECONDS = 0.55 -- D455
Model.TOAST_SECONDS = 2.2 -- D365
Model.SORTS = { "RATING", "PRICE", "A-Z" } -- D804
Model.ACCESS_OPTIONS = { "FRIENDS", "ANYONE", "NOBODY" } -- D599
Model.MINIMAP_OPTIONS = { "ROTATE", "NORTH UP" } -- D633
Model.CONTROL_MODES = { "Arrows", "Thumbstick", "Tilt" } -- M201
Model.BUY_MORE_KEY = "BuyMore" -- D775
-- The attributes whose change the client forwards to AttributeChanged.
Model.PlayerAttributes = { "GarageSessionActive", "FullMapOpen", "OwnedGarageInside", "Rank", "XpIntoRank", "XpForNext",
	"PassengerAccess", "MinimapMode", "MobileControlMode" }
Model.PlayerGuiAttributes = { "OwnedGarageManagementOpen" }

local ACCESS_LABELS = { Friends = "FRIENDS", Anyone = "ANYONE", Nobody = "NOBODY" } -- D595
local MODALS = { Controls = true, Settings = true, Cash = true }

-- A minimal Luau signal: Connect returns a connection with Disconnect, so Core.ConnectionScope can hold it.
local function newSignal()
	local connections = {}
	local signal = {}
	function signal:Connect(handler)
		local connection = { Connected = true }
		function connection:Disconnect()
			if not connection.Connected then return end
			connection.Connected = false
			local index = table.find(connections, connection)
			if index then table.remove(connections, index) end
		end
		connection.Handler = handler
		table.insert(connections, connection)
		return connection
	end
	function signal:Fire(...)
		for _, connection in ipairs(table.clone(connections)) do
			if connection.Connected then connection.Handler(...) end
		end
	end
	return signal
end
Model._newSignal = newSignal

-- D121-124, copied exactly (a false value yields the fallback, as it does in Classic).
function Model._readValue(folder, name, fallback)
	local item = folder and folder:FindFirstChild(name)
	return item and item.Value ~= nil and item.Value or fallback
end

-- D1341-1344: owners table -> racing, telemetryOnly.
function Model._presentation(owners)
	local racing = next(owners) ~= nil
	local telemetryOnly = racing
	for _, owner in pairs(owners) do
		if not owner.KeepTelemetry then
			telemetryOnly = false
			break
		end
	end
	return racing, telemetryOnly
end

-- D1339-1342: applies one FreeRoamHudPresentationMode message to the owners table.
function Model._applyPresentation(owners, message)
	if typeof(message) == "table" then
		local owner = tostring(message.Owner or "Racing")
		owners[owner] = message.Active == true and { KeepTelemetry = message.KeepTelemetry == true } or nil
	else
		owners.Racing = tostring(message) == "Racing" and { KeepTelemetry = true } or nil
	end
end

-- D919-924.
function Model._rankView(rank, into, need)
	into = tonumber(into) or 0
	need = tonumber(need) or 0
	return {
		Visible = rank ~= nil,
		Rank = tonumber(rank) or 1,
		Fraction = need > 0 and math.clamp(into / need, 0, 1) or 1,
		Text = need > 0 and (tostring(into) .. " / " .. tostring(need) .. " XP") or "MAX",
	}
end

-- D612: "FRIENDS" -> "Friends". nil for anything that is not one of the three labels.
function Model._accessFromLabel(label)
	for value, text in pairs(ACCESS_LABELS) do
		if text == label then return value end
	end
	return nil
end

-- D650-661 walks every descendant once per owned vehicle; this builds the same ordered list of models once per
-- row build, and _cockpitModel applies the same three tests in the same order, so the match is identical.
function Model._cockpitIndex(categoriesRoot)
	local index = {}
	if not categoriesRoot then return index end
	for _, item in ipairs(categoriesRoot:GetDescendants()) do
		if item:IsA("Model") then
			local id = string.lower(tostring(item:GetAttribute("CockpitId") or item:GetAttribute("TemplateId") or item.Name))
			local compact = string.gsub(id, "^cockpit_", "")
			table.insert(index, { Id = id, Compact = compact, Model = item })
		end
	end
	return index
end

function Model._cockpitModel(index, cockpitId)
	local target = string.lower(tostring(cockpitId or ""))
	if target == "" then return nil end
	for _, entry in ipairs(index) do
		if entry.Id == target or entry.Compact == target or string.find(entry.Id, target, 1, true) then return entry.Model end
	end
	return nil
end

-- VehicleDisplayNames is not on the shared-module list of API2 6.6, so the three functions the Classic HUD uses from
-- it (titleWords, FindCockpit, CategoryName; VehicleDisplayNames 4-10, 22-36, 45-58) are carried here unchanged in
-- result. _categoryIndex makes FindCockpit's walk once per row build instead of once per vehicle.
local function titleWords(value)
	local text = string.gsub(tostring(value or ""), "_", " ")
	text = string.gsub(text, "%s+", " ")
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	local titled = string.gsub(string.lower(text), "(%a)([%w']*)", function(first, rest) return string.upper(first) .. rest end)
	return titled
end
Model._titleWords = titleWords

function Model._categoryIndex(categoriesRoot)
	local index = { Categories = {}, Entries = {} }
	if not categoriesRoot then return index end
	index.Categories = categoriesRoot:GetChildren()
	for _, category in ipairs(index.Categories) do
		for _, item in ipairs(category:GetDescendants()) do
			if item:IsA("Model") then
				local id = string.lower(tostring(item:GetAttribute("CockpitId") or item:GetAttribute("TemplateId") or item.Name))
				local compact = string.gsub(id, "^cockpit_", "")
				table.insert(index.Entries, { Id = id, Compact = compact, Category = category })
			end
		end
	end
	return index
end

function Model._categoryName(categoriesRoot, categoryIndex, categoryId, cockpitId)
	local category
	local wantedCockpit = string.lower(tostring(cockpitId or ""))
	if categoriesRoot and wantedCockpit ~= "" then
		for _, entry in ipairs(categoryIndex.Entries) do
			if entry.Id == wantedCockpit or entry.Compact == wantedCockpit then
				category = entry.Category
				break
			end
		end
	end
	if not category and categoriesRoot then
		local wanted = string.lower(tostring(categoryId or ""))
		for _, candidate in ipairs(categoryIndex.Categories) do
			if string.lower(candidate.Name) == wanted then
				category = candidate
				break
			end
		end
		-- "bruiser" is a stable legacy data ID; PIERCER is its current player-facing asset family.
		if not category and wanted == "bruiser" then category = categoriesRoot:FindFirstChild("PIERCER") end
	end
	local display = category and category:GetAttribute("DisplayName")
	return titleWords(display ~= nil and tostring(display) ~= "" and display or (category and category.Name or categoryId or "Other"))
end

-- D663-690 (and D645-648 for the category).
function Model._rowsFromProfile(profile, index, categoriesRoot, categoryIndex)
	local rows = {}
	if type(profile) ~= "table" then return rows end
	for vehicleId, vehicle in pairs(type(profile.Vehicles) == "table" and profile.Vehicles or {}) do
		if type(vehicle) == "table" then
			local cockpitId = tostring(vehicle.CockpitId or "")
			if cockpitId == "" and vehicle.CockpitInstanceId and type(profile.OwnedCockpitInstances) == "table" then
				local instance = profile.OwnedCockpitInstances[vehicle.CockpitInstanceId]
				cockpitId = tostring(type(instance) == "table" and instance.TemplateId or "")
			end
			local model = Model._cockpitModel(index, cockpitId)
			local summary = type(profile.VehicleSummaries) == "table" and profile.VehicleSummaries[vehicleId]
			local overall = type(summary) == "table" and type(summary.Overall) == "table" and summary.Overall or {}
			local rating = tonumber(overall.PerformanceIndex) or 0
			local tier = tostring(overall.Tier or "E")
			local displayName = tostring(model and model:GetAttribute("DisplayName") or cockpitId ~= "" and cockpitId or "Vehicle")
			displayName = string.upper((string.gsub(displayName, "_", " ")))
			local image = tostring(model and (model:GetAttribute("MenuImage") or model:GetAttribute("CockpitImage")) or "")
			if tonumber(image) then image = "rbxassetid://" .. image end
			local explicit = tostring(vehicle.CategoryId or vehicle.Category or "")
			table.insert(rows, {
				VehicleId = tostring(vehicleId),
				CockpitId = cockpitId,
				Category = string.upper(Model._categoryName(categoriesRoot, categoryIndex, explicit, cockpitId)),
				Name = displayName,
				Image = image,
				Tier = tier,
				Rating = rating,
				Price = tonumber(model and model:GetAttribute("Price")) or 0,
				Selected = tostring(profile.CurrentVehicleId or "") == tostring(vehicleId),
			})
		end
	end
	return rows
end

-- Pure. Is a vehicle of this player out, and which owned vehicle is it (VehicleBuildService 268-269)?
function Model._vehicleOut(vehicles, userId)
	if userId == nil then return false, "" end
	for _, vehicle in ipairs(vehicles or {}) do
		if vehicle:IsA("Model") and tonumber(vehicle:GetAttribute("OwnerUserId")) == userId then
			return true, tostring(vehicle:GetAttribute("OwnedVehicleId") or "")
		end
	end
	return false, ""
end

-- Pure. profile.CurrentVehicleId outlives the vehicle (a teleport or a despawn removes the model, not the id), so a
-- row is CURRENT only while the player's vehicle exists. Returns true when any row changed.
function Model._markCurrent(rows, out, outId)
	local changed = false
	for _, row in ipairs(rows) do
		if row.ProfileCurrent == nil then row.ProfileCurrent = row.Selected == true end
		local current = false
		if out then
			if outId ~= "" then current = row.VehicleId == outId else current = row.ProfileCurrent end
		end
		if row.Selected ~= current then
			row.Selected = current
			changed = true
		end
	end
	return changed
end

-- D761-764.
function Model._filterRows(rows, category)
	local filtered = {}
	for _, row in ipairs(rows) do
		if category == "ALL" or row.Category == category then table.insert(filtered, row) end
	end
	return filtered
end

-- D765-774. Sorts in place and returns the list.
function Model._sortRows(rows, sort)
	table.sort(rows, function(a, b)
		if sort == "PRICE" then
			if a.Price ~= b.Price then return a.Price < b.Price end
		elseif sort == "A-Z" then
			if a.Name ~= b.Name then return a.Name < b.Name end
		else
			if a.Rating ~= b.Rating then return a.Rating > b.Rating end
		end
		return a.Name < b.Name
	end)
	return rows
end

-- D759-760 and D786-788 (with the a == b guard of M303, which changes no result).
function Model._categoryOptions(rows)
	local seen = { ALL = true }
	for _, row in ipairs(rows) do seen[row.Category] = true end
	local options = {}
	for name in pairs(seen) do table.insert(options, name) end
	table.sort(options, function(a, b)
		if a == b then return false elseif a == "ALL" then return true elseif b == "ALL" then return false end
		return a < b
	end)
	return options
end

function Model.new(deps)
	assert(type(deps) == "table", "HudModel.new requires deps")
	local player = deps.Player
	local playerGui = deps.PlayerGui
	local remotes = deps.Remotes
	local bindables = deps.Bindables
	local config = deps.Config or {}
	local clock = deps.Clock or os.clock
	local spawn = deps.Spawn or task.spawn
	local delay = deps.Delay or task.delay
	local touch = deps.TouchEnabled == true
	local pauseMap = config.PauseFreeRoamMapDuringRace ~= false

	local self = {}
	self.Changed = newSignal() -- (reason: string)
	self.ControlsFadeSeconds = Model.CONTROLS_FADE_SECONDS
	self.BuyMoreKey = Model.BUY_MORE_KEY

	local state = {
		Touch = touch,
		Racing = false, TelemetryOnly = false, FullMapOpen = false, GarageSession = false, ManagementOpen = false,
		OwnedGarageInside = false, Driving = false, Hidden = false,
		ShowActionBar = true, ShowMainActions = true, ShowStatus = true, ShowMinimap = true,
		ShowBottomButtons = false, ShowGauge = false, MapLive = true,
		CarPanelOpen = false, RowsLoading = false, Rows = {}, Category = "ALL", Sort = "RATING",
		CategoryOptions = { "ALL" }, Vehicle = nil,
		ActiveModal = nil, ControlsReveal = false, ControlsFading = false, Busy = false,
	}
	local owners = {} -- D103 presentationOwners
	local busy = false -- D118: one guard for spawn, despawn, exit and teleport
	local controlsFadeGeneration = 0 -- D107
	local controlsInputToken -- D108
	local cachedInitial, cachedProfile -- D111-112
	local lastProfileRead = 0 -- D114
	local allRows = {}
	local loadToken = 0

	-- The one remote entry point. Call sites below match contract_a.json.
	local function call(remote, action, payload)
		return pcall(function()
			if payload == nil then return remote:InvokeServer(action) end
			return remote:InvokeServer(action, payload)
		end)
	end

	-- D341-347.
	local function callGarage(action, payload)
		local ok, result = call(remotes.GarageInvoke, action, payload or {})
		if ok and typeof(result) == "table" then return result end
		return { Success = false, Ok = false, Message = tostring(result), Error = tostring(result) }
	end

	-- D364-366.
	local function toast(text)
		bindables.ShowTopNotification:Fire(text, Model.TOAST_SECONDS)
	end

	-- D410-414.
	local function fireUi(name)
		local event = bindables.Folder:FindFirstChild(name)
		if event and event:IsA("BindableEvent") then
			event:Fire()
			return true
		end
		return false
	end

	-- D416-421.
	local function loadingAction(action, payload)
		local ok, result = pcall(function() return bindables.LoadingTransitionInvoke:Invoke(action, payload or {}) end)
		if ok then return result end
		warn("[Pulse.HudModel] Loading transition " .. tostring(action) .. " failed: " .. tostring(result))
		return nil
	end

	-- D349-362.
	local function readInitial(force)
		local interval = tonumber(config.ProfileRefreshSeconds) or 2
		if not force and cachedInitial and clock() - lastProfileRead < interval then return cachedInitial end
		local ok, result = pcall(function() return deps.Catalog.Fetch(remotes.GarageInvoke, {}) end)
		lastProfileRead = clock()
		if ok and typeof(result) == "table" then
			cachedInitial = result
			cachedProfile = result.Profile or result
		end
		return cachedInitial
	end

	local function recompute()
		local racing, telemetryOnly = Model._presentation(owners)
		state.Racing = racing
		state.TelemetryOnly = telemetryOnly
		state.FullMapOpen = player:GetAttribute("FullMapOpen") == true -- D1116
		state.GarageSession = player:GetAttribute("GarageSessionActive") == true -- D380
		state.ManagementOpen = playerGui:GetAttribute("OwnedGarageManagementOpen") == true -- D1125
		state.OwnedGarageInside = player:GetAttribute("OwnedGarageInside") == true -- D1132
		state.Hidden = (racing and not telemetryOnly) or state.FullMapOpen or state.GarageSession or state.ManagementOpen -- D1114-1128
		state.ShowActionBar = not racing -- D1133
		state.ShowMainActions = not state.OwnedGarageInside -- D1133
		state.ShowStatus = not racing -- D1135 (cash); the car panel no longer hides it (API2 target r09)
		state.ShowMinimap = not racing and not state.CarPanelOpen and not state.OwnedGarageInside -- D1135-1136
		state.ShowBottomButtons = state.Driving and not racing -- D1138
		state.ShowGauge = state.Driving -- D1141
		state.MapLive = not state.OwnedGarageInside and not (racing and pauseMap) -- D1142
		state.Busy = busy
	end

	local closeModal
	local setCarPanelOpen

	local function update(reason)
		recompute()
		-- M397: on touch a hidden HUD drops the car menu (and its player attribute).
		if touch and state.Hidden and state.CarPanelOpen then
			setCarPanelOpen(false)
			recompute()
		end
		self.Changed:Fire(reason)
	end

	local function applyFilter()
		state.CategoryOptions = Model._categoryOptions(allRows)
		state.Rows = Model._sortRows(Model._filterRows(allRows, state.Category), state.Sort)
	end

	local function markRows()
		if not deps.OwnedVehicles then return false end
		local out, outId = Model._vehicleOut(deps.OwnedVehicles(), player.UserId)
		return Model._markCurrent(allRows, out, outId)
	end

	-- The player's vehicle appeared or went while the panel is open: the CURRENT chip follows it.
	function self.VehiclesChanged()
		if not state.CarPanelOpen or state.RowsLoading then return end
		if not markRows() then return end
		applyFilter()
		update("Rows")
	end

	-- D754-758 in fetch-first form: one token, so a late reply never draws into a newer request (PC 5.1 rule 8).
	local function loadRows(force)
		loadToken += 1
		local token = loadToken
		state.RowsLoading = true
		spawn(function()
			readInitial(force)
			if token ~= loadToken then return end
			allRows = Model._rowsFromProfile(cachedProfile or {}, Model._cockpitIndex(deps.CategoriesRoot),
				deps.CategoriesRoot, Model._categoryIndex(deps.CategoriesRoot))
			markRows()
			state.RowsLoading = false
			applyFilter()
			update("Rows")
		end)
	end

	-- D429-439 (and M188 for the touch attribute).
	local function finishModalClose()
		local closingControls = state.ActiveModal == "Controls"
		state.ActiveModal = nil
		state.ControlsFading = false
		if closingControls then player:SetAttribute("DrivingControlsOpen", false) end
		if touch then player:SetAttribute("MobileMajorMenuOpen", false) end
		if controlsInputToken then
			deps.InputGate.Release(controlsInputToken, true)
			controlsInputToken = nil
		end
		state.ControlsReveal = false
	end

	-- D441-445.
	closeModal = function()
		if state.ActiveModal == "Controls" and state.ControlsReveal then return end
		controlsFadeGeneration += 1
		finishModalClose()
	end

	-- D464-473 (and M190 for the touch attribute, which Classic writes for its Settings and Cash modals).
	local function openModal(name)
		controlsFadeGeneration += 1
		state.ActiveModal = name
		state.ControlsFading = false
		player:SetAttribute("DrivingControlsOpen", name == "Controls")
		if touch and name ~= "Controls" then player:SetAttribute("MobileMajorMenuOpen", true) end
	end

	-- D863-875 and M283-286.
	setCarPanelOpen = function(open)
		open = open == true
		if state.CarPanelOpen == open then return end
		state.CarPanelOpen = open
		if touch then player:SetAttribute("MobileFreeRoamCarMenuOpen", open) end
		if open then
			closeModal() -- M285
			loadRows(true) -- D869-870
		else
			loadToken += 1
			state.RowsLoading = false
			cachedInitial = nil -- D872-874
			cachedProfile = nil
			allRows = {} -- the cards go with the panel (D755-757 destroys them on the next open)
			state.Rows = {}
		end
	end

	-- D395-408.
	local function ownedVehicleSeat()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		if not (seat and seat:IsA("VehicleSeat")) then return nil, nil end
		local current = seat
		while current do
			if current:IsA("Model") and tonumber(current:GetAttribute("OwnerUserId")) == player.UserId then return seat, current end
			current = current.Parent
		end
		return nil, nil
	end
	self.OwnedVehicleSeat = ownedVehicleSeat

	-- D830-832, D1003-1005.
	local function standUp()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.Sit = false end
	end

	local function findRow(vehicleId)
		for _, row in ipairs(allRows) do
			if row.VehicleId == vehicleId then return row end
		end
		return nil
	end

	-- State ----------------------------------------------------------------------------------------------------
	function self.GetState() return state end
	function self.IsMinimapShowing() return not state.Hidden and state.ShowMinimap end
	function self.GetRank()
		return Model._rankView(player:GetAttribute("Rank"), player:GetAttribute("XpIntoRank"), player:GetAttribute("XpForNext"))
	end
	-- D598.
	function self.GetPassengerAccess() return ACCESS_LABELS[player:GetAttribute("PassengerAccess")] or "FRIENDS" end
	-- D632-633.
	function self.GetMinimapMode() return player:GetAttribute("MinimapMode") == "NORTH UP" and "NORTH UP" or "ROTATE" end
	-- M200.
	function self.GetControlMode() return tostring(player:GetAttribute("MobileControlMode") or config.DefaultControlMode or "Arrows") end
	-- M201: Tilt needs a gyroscope.
	function self.IsControlModeLocked(mode) return mode == "Tilt" and deps.GyroscopeEnabled ~= true end

	-- Inputs from the client's listeners ------------------------------------------------------------------------
	function self.AttributeChanged(name)
		-- D1351-1353 and M331.
		if name == "FullMapOpen" and player:GetAttribute("FullMapOpen") == true then
			if touch and state.CarPanelOpen then setCarPanelOpen(false) end
			if state.ActiveModal ~= "Controls" then closeModal() end
		end
		update(name)
	end

	-- D1339-1347.
	function self.PresentationMessage(message)
		Model._applyPresentation(owners, message)
		if next(owners) ~= nil then
			setCarPanelOpen(false)
			closeModal()
		end
		update("Presentation")
	end

	-- D987-994.
	function self.OpenControlsFromOnboarding(options)
		state.ControlsReveal = type(options) == "table" and options.FirstDrive == true
		if state.ControlsReveal then
			player:SetAttribute("FirstDrivePresentationPending", true)
			if not controlsInputToken then controlsInputToken = deps.InputGate.Acquire("FirstDriveControls", "V1") end
		end
		openModal("Controls")
		update("Modal")
	end

	-- D964.
	function self.Arrived(destination)
		toast("ARRIVED: " .. tostring(type(destination) == "table" and destination.Label or ""))
	end

	function self.SetDriving(driving)
		driving = driving == true
		if state.Driving == driving then return end
		state.Driving = driving
		if driving then
			-- The seated owned vehicle carries its tier and rating (VehiclePerformance.WriteToVehicle), so the status
			-- cluster can show them for a vehicle this HUD did not spawn.
			local _, vehicle = ownedVehicleSeat()
			local tier = vehicle and vehicle:GetAttribute("PerformanceTier")
			if tier ~= nil then
				state.Vehicle = { Tier = tostring(tier), Rating = tonumber(vehicle:GetAttribute("PerformanceIndex")) or 0,
					Name = state.Vehicle and state.Vehicle.Name or nil }
			end
		end
		update("Driving")
	end

	-- Modals ---------------------------------------------------------------------------------------------------
	function self.OpenModal(name)
		if not MODALS[name] then return end
		openModal(name)
		update("Modal")
	end

	function self.CloseModal()
		closeModal()
		update("Modal")
	end

	-- D447-462. The view fades the backdrop for CONTROLS_FADE_SECONDS while ControlsFading is true.
	function self.CompleteControls()
		if state.ActiveModal ~= "Controls" then return end
		if not state.ControlsReveal then
			closeModal()
			update("Modal")
			return
		end
		if state.ControlsFading then return end -- D454: the Done button is inactive during the fade
		controlsFadeGeneration += 1
		local generation = controlsFadeGeneration
		state.ControlsFading = true
		update("Modal")
		delay(Model.CONTROLS_FADE_SECONDS, function()
			if generation ~= controlsFadeGeneration then return end
			player:SetAttribute("FirstDrivePresentationPending", false)
			finishModalClose()
			update("Modal")
		end)
	end

	-- D577.
	function self.CashPackPressed() toast("CASH PRODUCTS ARE NOT ENABLED YET") end

	-- Settings -------------------------------------------------------------------------------------------------
	-- D607-616.
	function self.SetPassengerAccess(label)
		local access = Model._accessFromLabel(label)
		if not access then return end
		local remote = deps.FindActivityInvoke and deps.FindActivityInvoke()
		if not remote then return end
		spawn(function()
			local ok, reply = call(remote, "SetPassengerAccess", { Access = access })
			if not (ok and type(reply) == "table" and reply.Ok) then toast("PASSENGER SETTING NOT SAVED") end
			update("PassengerAccess")
		end)
	end

	-- D633-635.
	function self.SetMinimapMode(option)
		if option ~= "ROTATE" and option ~= "NORTH UP" then return end
		player:SetAttribute("MinimapMode", option)
		update("MinimapMode")
	end

	-- M201. Only where Classic's mobile HUD ran (TouchEnabled).
	function self.SetControlMode(option)
		if not touch or not table.find(Model.CONTROL_MODES, option) or self.IsControlModeLocked(option) then return end
		player:SetAttribute("MobileControlMode", option)
		update("MobileControlMode")
	end

	-- Action bar -----------------------------------------------------------------------------------------------
	function self.ToggleCarPanel()
		setCarPanelOpen(not state.CarPanelOpen)
		update("CarPanel")
	end

	function self.SetCarPanelOpen(open)
		setCarPanelOpen(open)
		update("CarPanel")
	end

	-- D878-880.
	function self.OpenGarages()
		if not fireUi("OpenOwnedGarageBrowser") then toast("MY GARAGES NOT READY") end
	end

	-- D882-884.
	function self.OpenRaces()
		if not fireUi("OpenRaceBrowser") then toast("RACE BROWSER NOT READY") end
	end

	-- D958-963.
	function self.OpenFullMap()
		spawn(function()
			local ok, opened = pcall(deps.OpenFullMap)
			if not (ok and opened) then toast("MAP NOT AVAILABLE") end
		end)
	end

	-- D508-534, behind the confirmation.
	function self.RequestTeleport()
		deps.Confirm({
			Title = "TELEPORT TO DEALERSHIP?",
			Body = "Your current vehicle will be despawned.",
			ConfirmText = "YES",
			CancelText = "NO",
			OnConfirm = function()
				if busy then return end
				busy = true
				spawn(function()
					local generation = loadingAction("Begin", { Destination = "DealershipExterior", Status = "TRAVELLING TO DEALERSHIP" })
					local ok, result = call(remotes.TeleportInvoke, "TeleportToDealership")
					if ok and typeof(result) == "table" and result.Success == true then
						fireUi("FreeRoamVehicleExited")
						lastProfileRead = 0
						state.Vehicle = nil
						loadingAction("Complete", { Generation = generation, Status = "READY" })
						toast(result.Message or "TELEPORTED TO DEALERSHIP")
					else
						local message = (typeof(result) == "table" and (result.Message or result.Error)) or "DEALERSHIP TELEPORT FAILED"
						loadingAction("Fail", { Generation = generation, Status = "RETURNING", Reason = message })
						toast(message)
					end
					busy = false
					update("Teleport")
				end)
			end,
		})
	end

	-- Car panel ------------------------------------------------------------------------------------------------
	-- D801.
	function self.SelectCategory(option)
		if type(option) ~= "string" or state.Category == option then return end
		state.Category = option
		loadRows(false)
	end

	-- D804.
	function self.SelectSort(option)
		if not table.find(Model.SORTS, option) or state.Sort == option then return end
		state.Sort = option
		loadRows(false)
	end

	-- D777 and M301.
	function self.BuyMore()
		if touch then
			setCarPanelOpen(false)
			update("CarPanel")
		end
		self.RequestTeleport()
	end

	-- D746-751.
	function self.SpawnVehicle(vehicleId)
		if busy then return end
		local row = findRow(vehicleId)
		if not row then return end
		busy = true
		spawn(function()
			toast("SPAWNING VEHICLE...")
			local result = callGarage("SpawnOwnedVehicleFromFreeRoam", { VehicleId = row.VehicleId, CockpitId = row.CockpitId })
			if result.Success == true then
				lastProfileRead = 0
				fireUi("FreeRoamVehicleSpawned")
				state.Vehicle = { Tier = row.Tier, Rating = row.Rating, Name = row.Name }
				setCarPanelOpen(false)
				toast("VEHICLE SPAWNED")
			else
				toast(result.Message or result.Error or "VEHICLE SPAWN FAILED")
			end
			busy = false
			update("Spawn")
		end)
	end

	-- D825-836 (and M310: the touch panel closes).
	function self.Despawn()
		if busy then return end
		busy = true
		spawn(function()
			fireUi("FreeRoamVehicleExited")
			local result = callGarage("DespawnVehicle", {})
			standUp()
			lastProfileRead = 0
			if result.Success ~= false then state.Vehicle = nil end
			if touch then setCarPanelOpen(false) end
			toast(result.Success == false and (result.Message or "DESPAWN FAILED") or "VEHICLE DESPAWNED")
			busy = false
			update("Despawn")
		end)
	end

	-- D996-1008.
	function self.ExitVehicle()
		if busy then return end
		local seat = ownedVehicleSeat()
		if not seat then return end
		busy = true
		spawn(function()
			fireUi("FreeRoamVehicleExited")
			callGarage("ExitVehicle", {})
			standUp()
			toast("VEHICLE PARKED")
			busy = false
			update("Exit")
		end)
	end

	-- M168, M187: the two touch attributes start false.
	if touch then
		player:SetAttribute("MobileFreeRoamCarMenuOpen", false)
		player:SetAttribute("MobileMajorMenuOpen", false)
	end
	recompute()
	return self
end

return Model
