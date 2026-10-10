-- Owns the free-roam HUD composition for Regular, Compact and TouchDrive (status, action bar, bottom buttons, gauge, minimap host, car panel and modal hosts) and the HUD's frame step; no remote, attribute or bindable.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.HudView. Requires: Kit.Tokens, Kit.Controls, Kit.Data, Kit.Gauge, FreeRoam.HudMinimap, FreeRoam.CarPanelView, FreeRoam.HudModals (resolved on the first mount).
--
-- Static layer (DesktopFreeRoamHud): action bar, bottom buttons, car panel, ModalLayer, the Minimap marker frame.
-- Live layer (DesktopFreeRoamHudLive): status cluster (its cash chip counts), gauge, minimap.
-- Every position comes from a slot; Standard against TouchDrive is decided by the slots (API2 2.4).
-- Classic line references: D = DesktopFreeRoamHudUI, M = MobileFreeRoamHudUI.

local TIERS = { E = true, D = true, C = true, B = true, A = true, S = true }

local HudView = {}

local modulesCache
local function modules()
	if not modulesCache then
		local family = script.Parent
		local folder = family.Parent.Kit
		modulesCache = {
			Tokens = require(folder.Tokens),
			Controls = require(folder.Controls),
			Data = require(folder.Data),
			Gauge = require(folder.Gauge),
			HudMinimap = require(family.HudMinimap),
			CarPanelView = require(family.CarPanelView),
			HudModals = require(family.HudModals),
		}
	end
	return modulesCache
end
function HudView._setModules(replacement) modulesCache = replacement end

-- Pure: the width of a row of boxes with a gap between them, and the whole-pixel offset that puts the row on a
-- slot anchor (1: the row ends at the slot; 0.5: centred on it; 0: starts at it).
function HudView._rowPlace(widths, height, gap, anchorX, anchorY)
	local width = 0
	for index, value in ipairs(widths) do
		width += value + (index > 1 and gap or 0)
	end
	return width, -math.floor(width * anchorX), -math.floor(height * anchorY)
end

-- A row of buttons on a slot. The row is sized and placed in code from its showing children, as Controls.ButtonRow
-- does: an AutomaticSize row with the slot's AnchorPoint sat centred on the slot instead of ending at it.
local function holder(name, slot, gap, scope)
	local item = Instance.new("Frame")
	item.Name = name
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, gap)
	layout.Parent = item
	item.Parent = slot

	local widths = {}
	local function fit()
		table.clear(widths)
		local height = 0
		for _, child in ipairs(item:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				local size = child.Size
				table.insert(widths, size.X.Offset)
				height = math.max(height, size.Y.Offset)
			end
		end
		local anchor = slot.AnchorPoint
		local width, x, y = HudView._rowPlace(widths, height, gap, anchor.X, anchor.Y)
		local size, position = UDim2.fromOffset(width, height), UDim2.fromOffset(x, y)
		if item.Size ~= size then item.Size = size end
		if item.Position ~= position then item.Position = position end
	end
	scope:connect(item.ChildAdded, function(child)
		if child:IsA("GuiObject") then
			scope:connect(child:GetPropertyChangedSignal("Size"), fit)
			scope:connect(child:GetPropertyChangedSignal("Visible"), fit)
		end
		fit()
	end)
	scope:connect(item.ChildRemoved, fit)
	scope:connect(slot:GetPropertyChangedSignal("AnchorPoint"), fit)
	return item, fit
end

local function place(component, slot)
	component.Instance.AnchorPoint = slot.AnchorPoint
	component.Instance.Position = UDim2.new()
end

-- Pure: the design size of the gauge for a context (API2 2.4: a screen may test the arrangement to choose a size).
function HudView._gaugeSize(space, class, arrangement)
	if class == "Compact" then return space.CompactGauge end
	return arrangement == "TouchDrive" and space.GaugeTouchSize or space.GaugeSize
end

-- Pure: the status cluster patch for the known vehicle (Regular only). The rank is not passed: the cluster's rank
-- ring drew pale on pale (capture free_roam_driving), and the rank already shows on the minimap (number and arc).
function HudView._statusPatch(vehicle, _rank)
	if type(vehicle) == "table" and TIERS[vehicle.Tier] then
		return { Mode = "Vehicle", Tier = vehicle.Tier, Rating = math.floor(tonumber(vehicle.Rating) or 0) },
			string.format("%s|%d", vehicle.Tier, math.floor(tonumber(vehicle.Rating) or 0))
	end
	return { Mode = "CashOnly" }, ""
end

-- Pure: is the gauge or the minimap covered by something drawn on the static layer? The live layer draws above
-- the static one, so its gauge and minimap would show through an open modal or, on Compact, through the vehicles
-- side panel (which stands on their side of the screen). Classic keeps one gui, where the modal is simply on top.
function HudView._liveCovered(state, compact)
	if state.ActiveModal ~= nil then return true end
	return compact == true and state.CarPanelOpen == true
end

-- layer: the static Layer. extra = {
--   Live: Layer?            the live Layer (the gallery passes none: one stage holds both)
--   Player: Player?         binds the cash chip; nil in the gallery
--   SampleCash: number?     gallery
--   MinimapDeps: table?     HudMinimap deps; nil in the gallery
--   DriveState: table?      the shared MobileDriveInputState table (SpeedMph, BoostPercent, IsDriving)
--   Subject: table?         { Part, VehiclePart }, kept current by the client's listeners
--   SpeedGaugeMaxMph, BoostBarSmoothing: number?    cached config (D1288, D1279)
--   Sample: { Speed, Boost }?    gallery: a fixed gauge reading }
function HudView.Mount(layer, model, scope, extra)
	extra = extra or {}
	local m = modules()
	local live = extra.Live or layer
	local ctx = layer.Metrics
	local compact = ctx.Class == "Compact"
	local touchDrive = ctx.Arrangement == "TouchDrive"
	local space = m.Tokens.Space
	local px = ctx.Px

	local self = { Class = ctx.Class, Arrangement = ctx.Arrangement }

	-- Action bar (D855-890). Car, Garage and Race carry the onboarding marks; Classic onboarding writes Active,
	-- Selectable and AutoButtonColor on them (OnboardingClient 666-671): the write is mirrored as the locked look,
	-- never overridden.
	local barSlot = layer.Slot("ActionBar")
	local bar, fitBar = holder("ActionBar", barSlot, px(compact and space.TouchGap or space.ActionGap), scope)
	local function action(name, icon, markKey, order, onActivated)
		return m.Controls.IconButton(bar, { Name = name, Icon = icon, Size = "Action", MarkKey = markKey, LayoutOrder = order,
			OnActivated = onActivated }, scope)
	end
	local function mirrorLock(component)
		local button = component.Instance
		scope:connect(button:GetPropertyChangedSignal("Active"), function()
			component.Set({ Disabled = not button.Active })
		end)
	end
	local car = action(nil, "car", "Car", 1, function() model.ToggleCarPanel() end)
	local garage = action(nil, "garage", "Garage", 2, function() model.OpenGarages() end)
	local race = action(nil, "race_flag", "Race", 3, function() model.OpenRaces() end)
	local dealership = action("TeleportDealership", "dealership", nil, 4, function() model.RequestTeleport() end)
	local settings = action("OpenSettings", "settings_cog", nil, 5, function() model.OpenModal("Settings") end)
	mirrorLock(car)
	mirrorLock(garage)
	mirrorLock(race)
	fitBar()

	-- Bottom buttons (D978-1008, M147). Touch has no Controls button, as the Classic touch HUD has none.
	local buttonsSlot = layer.Slot("HudButtons")
	local buttons, fitButtons = holder("BottomActions", buttonsSlot, px(space.Gap), scope)
	buttons.Visible = false
	if not touchDrive then
		m.Controls.Button(buttons, { Name = "OpenControls", Variant = "Default", Size = "Hud", Text = "CONTROLS", Icon = "gamepad",
			LayoutOrder = 1, OnActivated = function() model.OpenModal("Controls") end }, scope)
	end
	m.Controls.Button(buttons, { Name = "ExitVehicle", Variant = "Default", Size = "Hud", Text = touchDrive and "EXIT" or "EXIT VEHICLE",
		Icon = "exit", LayoutOrder = 2, OnActivated = function() model.ExitVehicle() end }, scope)
	fitButtons()

	-- Status (D895-911): cash from leaderstats through the kit chip; the plus opens Get Cash.
	local statusSlot = live.Slot("HudStatus")
	local status = m.Data.StatusCluster(statusSlot, { Name = "Status", Mode = "CashOnly", ShowPlus = true,
		OnCashPlus = function() model.OpenModal("Cash") end }, scope)
	place(status, statusSlot)
	if extra.Player then
		-- Bind may yield once on its first use (API2 3.5); it never blocks the mount.
		scope:task(function()
			local ok, message = pcall(status.Cash.Bind, extra.Player)
			if not ok then warn("[Pulse.HudView] cash chip bind failed: " .. tostring(message)) end
		end)
	elseif extra.SampleCash then
		status.Cash.SetAmount(extra.SampleCash)
	end

	-- Gauge (D1010-1033).
	local gaugeSlot = live.Slot("Gauge")
	local gauge = m.Gauge.New(gaugeSlot, { Name = "Gauge", Size = HudView._gaugeSize(space, ctx.Class, ctx.Arrangement), Unit = "MPH",
		ShowBoostText = not compact, Visible = false }, scope)
	place(gauge, gaugeSlot)

	-- Minimap (D929-975): the frame and its map layers are live; the driver rank is its arc.
	local minimap = m.HudMinimap.Mount(live.Slot("Minimap"), {
		Size = compact and space.CompactMinimap or space.MinimapSize,
		OnActivated = function() model.OpenFullMap() end,
	}, extra.MinimapDeps, scope)

	-- Classic FullMapUI 464-478 looks for a showing descendant named Minimap under the ScreenGui DesktopFreeRoamHud.
	-- The kit minimap is on the live gui, so the static gui carries this empty marker with the same visibility.
	local marker
	if live ~= layer then
		marker = Instance.new("Frame")
		marker.Name = "Minimap"
		marker.BackgroundTransparency = 1
		marker.BorderSizePixel = 0
		marker.Parent = layer.Slot("Minimap")
	end

	local carPanel = m.CarPanelView.Mount(layer.Slot("SidePanel"), model, scope)
	local modals = m.HudModals.Mount(layer.Root, model, scope, { Player = extra.Player, SampleCash = extra.SampleCash })

	if extra.Sample then
		gauge.SetSpeed(extra.Sample.Speed, extra.Sample.Speed / (extra.SpeedGaugeMaxMph or extra.Sample.Speed))
		gauge.SetBoost(extra.Sample.Boost)
	end

	local shown = {}
	local function show(key, component, visible)
		if shown[key] == visible then return end
		shown[key] = visible
		component.Set({ Visible = visible })
	end

	function self.Render(reason)
		local state = model.GetState()

		local visible = not state.Hidden
		if shown.Layers ~= visible then
			shown.Layers = visible
			layer.SetVisible(visible)
			if live ~= layer then live.SetVisible(visible) end
		end

		if bar.Visible ~= state.ShowActionBar then bar.Visible = state.ShowActionBar end
		show("Car", car, state.ShowMainActions)
		show("Garage", garage, state.ShowMainActions)
		show("Race", race, state.ShowMainActions)
		show("Dealership", dealership, state.ShowMainActions)
		if shown.CarSelected ~= state.CarPanelOpen then
			shown.CarSelected = state.CarPanelOpen
			car.Set({ Selected = state.CarPanelOpen })
		end
		local settingsOpen = state.ActiveModal == "Settings"
		if shown.SettingsSelected ~= settingsOpen then
			shown.SettingsSelected = settingsOpen
			settings.Set({ Selected = settingsOpen })
		end

		if buttons.Visible ~= state.ShowBottomButtons then buttons.Visible = state.ShowBottomButtons end
		show("Status", status, state.ShowStatus)
		local covered = HudView._liveCovered(state, compact)
		show("Gauge", gauge, state.ShowGauge and not covered)

		local rank = model.GetRank()
		if not compact then
			local patch, key = HudView._statusPatch(state.Vehicle, rank)
			if shown.StatusKey ~= key then
				shown.StatusKey = key
				status.Set(patch)
			end
		end
		-- D919-927: the arc is the XP fraction; with no Rank attribute yet it shows rank 1 with an empty arc.
		minimap.SetRank(rank.Rank, rank.Visible and rank.Fraction or 0)
		-- The marker keeps the model's answer (the full map owner reads it); only the drawn minimap is covered.
		local minimapShown = state.ShowMinimap and not covered
		if shown.Minimap ~= minimapShown then
			shown.Minimap = minimapShown
			minimap.SetVisible(minimapShown)
		end
		if marker and marker.Visible ~= state.ShowMinimap then marker.Visible = state.ShowMinimap end

		carPanel.Render(reason)
		modals.Render(reason)
	end

	-- The frame step, bound once by the client through Kit.Perf on the live root. No lookup and no creation; every
	-- write is behind a comparison (here or in the kit setter). The model's state table is the same table for the
	-- model's life, so its fields are read directly.
	local drive = extra.DriveState
	local subject = extra.Subject
	local state = model.GetState()
	local maxMph = math.max(1, tonumber(extra.SpeedGaugeMaxMph) or 260)
	local smoothing = math.max(0, tonumber(extra.BoostBarSmoothing) or 14)
	local lastDriving = state.Driving == true -- a remount keeps the model, so start from what it holds
	local boostAlpha = 1 -- D85
	local defer = task.defer
	local setDriving = model.SetDriving

	if drive and subject then
		function self.Step(dt)
			local driving = drive.IsDriving == true
			if driving ~= lastDriving then
				lastDriving = driving
				defer(setDriving, driving) -- the model fires Changed; the render runs outside the frame step
			end

			-- D1142-1274: exactly one RouteGuide.Update per frame, inside minimap.Step, and none while the layer is
			-- hidden (the full map owner calls it then).
			if state.MapLive then
				local part = subject.Part
				if part then
					minimap.Step(dt, part, subject.VehiclePart, shown.Minimap == true)
				else
					minimap.Idle()
				end
			else
				minimap.Idle()
			end

			-- D1275-1293 and M493.
			if driving then
				local speed = math.max(0, tonumber(drive.SpeedMph) or 0)
				gauge.SetSpeed(math.floor(speed + 0.5), math.clamp(speed / maxMph, 0, 1))
				local target = math.clamp((tonumber(drive.BoostPercent) or 100) / 100, 0, 1)
				local amount = smoothing <= 0 and 1 or math.clamp(dt * smoothing, 0, 1)
				boostAlpha += (target - boostAlpha) * amount
				gauge.SetBoost(math.clamp(boostAlpha, 0, 1))
			else
				boostAlpha = 1
			end
		end
	else
		function self.Step() end
	end

	function self.Destroy()
		carPanel.Destroy()
		modals.Destroy()
		minimap.Destroy()
		gauge.Destroy()
		status.Destroy()
		car.Destroy()
		garage.Destroy()
		race.Destroy()
		dealership.Destroy()
		settings.Destroy()
		bar:Destroy()
		buttons:Destroy()
		if marker then marker:Destroy() end
	end

	return self
end

return HudView
