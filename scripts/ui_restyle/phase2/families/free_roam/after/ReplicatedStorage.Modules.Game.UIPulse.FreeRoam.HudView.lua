-- Owns the free-roam HUD composition for Regular, Compact and TouchDrive (status, action bar, bottom buttons, gauge, minimap host, car panel and modal hosts) and the HUD's frame step; no remote, attribute or bindable.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.HudView. Requires: Kit.Tokens, Kit.Controls, Kit.Data, Kit.Gauge, FreeRoam.HudMinimap, FreeRoam.CarPanelView, FreeRoam.HudModals, FreeRoam.RadioStripView (resolved on the first mount).
--
-- Static layer (DesktopFreeRoamHud): action bar, bottom buttons, car panel, ModalLayer, the Minimap marker frame.
-- Live layer (DesktopFreeRoamHudLive): status cluster (its cash chip counts), gauge, minimap.
-- Every position comes from a slot; Standard against TouchDrive is decided by the slots (API2 2.4).
-- Classic line references: D = DesktopFreeRoamHudUI, M = MobileFreeRoamHudUI.

local TIERS = { E = true, D = true, C = true, B = true, A = true, S = true }

-- Drivetrain telemetry (drivetrain_feel contract 3.2 and 7): the rpm needle's spring and the start-up sweep.
local NEEDLE_OMEGA = 25 -- rad/s
local NEEDLE_ZETA = 0.5 -- under 1: a slight overshoot, so the needle slams and settles
local SWEEP_UP, SWEEP_HOLD, SWEEP_DOWN = 0.2, 0.06, 0.24 -- seconds: the cluster self-test on the first telemetry
local SHIFT_LIGHT, LIMITER_LIGHT = 2, 3 -- Kit.Gauge.Light.Shift and .Limiter
local SPIN_LIGHT, OVERDRIVE_LIGHT = 4, 5 -- Kit.Gauge.Light.Spin and .Overdrive

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
			RadioStripView = require(family.RadioStripView),
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

-- Pure: is the cash chip covered? Compact only: the vehicles side panel stands on the chip's side of the screen and
-- a modal dims the screen, and the live layer would draw the chip above either. Regular keeps the chip (the panel
-- is on the other side and the chip sits clear of the centred modal).
function HudView._statusCovered(state, compact)
	return compact == true and HudView._liveCovered(state, true)
end

-- Pure: are the bottom buttons (EXIT, CONTROLS) under an open modal? Compact only: a phone modal reaches the bottom
-- row and the buttons showed through its panel.
function HudView._buttonsCovered(state, compact)
	return compact == true and state.ActiveModal ~= nil
end

-- Pure: how far the status column moves up (Compact TouchDrive only): the minimap's box and gap while the model
-- shows no minimap and the column is not itself covered by the vehicles panel (which also hides the minimap).
function HudView._columnRaise(state, phone, room)
	if phone and state.ShowMinimap ~= true and state.CarPanelOpen ~= true then return room end
	return 0
end

-- Pure: where the radio strip's seat goes under a right-anchored slot point (Compact TouchDrive). The strip hangs
-- from its seat by its bottom centre; `width` and `height` are its root box, `right` how far its buttons reach
-- from the root's left edge (a touch hit box is wider than the drawn tile), `top` the room the cash chip takes
-- above it. Returns the seat offset that ends the strip at the slot's x and starts it `top` below it.
function HudView._radioSeat(width, height, right, top)
	return -(math.max(width, right) - math.floor(width * 0.5)), top + height
end

-- Pure: one exact step of a damped spring whose target holds still over dt, so the needle moves the same at any frame
-- rate. zeta is kept under 1 (the closed form is the underdamped one). Returns the new position and velocity.
function HudView._needleStep(position, velocity, target, dt, omega, zeta)
	if dt <= 0 then return position, velocity end
	zeta = math.clamp(zeta, 0.05, 0.95)
	local offset = position - target
	local decay = math.exp(-zeta * omega * dt)
	local damped = omega * math.sqrt(1 - zeta * zeta)
	local cosine, sine = math.cos(damped * dt), math.sin(damped * dt)
	local nextOffset = decay * (offset * cosine + (velocity + zeta * omega * offset) / damped * sine)
	local nextVelocity = decay * (velocity * cosine - (zeta * omega * velocity + omega * omega * offset) / damped * sine)
	return target + nextOffset, nextVelocity
end

local function ease(x)
	return x * x * (3 - 2 * x)
end

-- Pure: the needle during the start-up sweep, `elapsed` seconds in: up to full, a short hold, down to `live`.
-- Returns the fraction and whether the sweep is still running.
function HudView._startSweep(elapsed, live)
	if elapsed < SWEEP_UP then return ease(math.max(elapsed, 0) / SWEEP_UP), true end
	elapsed -= SWEEP_UP
	if elapsed < SWEEP_HOLD then return 1, true end
	elapsed -= SWEEP_HOLD
	if elapsed < SWEEP_DOWN then return 1 + (live - 1) * ease(elapsed / SWEEP_DOWN), true end
	return live, false
end

-- Pure: the Kit.Gauge light level for the drive state's ShiftLight (0 off, 1 warm, 2 shift, 3 limiter, 4 spin
-- warning), Overdrive and Gear. Overdrive shows unless the spin warning does. In N the limiter is a steady shift light:
-- neutral revs on the countdown hold it for as long as W is held, and neutral gets no bounce effect (critique 17).
function HudView._lightLevel(shiftLight, overdrive, gear)
	local level = if type(shiftLight) == "number" and shiftLight == shiftLight then math.floor(shiftLight) else 0
	if level < 0 or level > SPIN_LIGHT then level = 0 end
	if overdrive == true and level ~= SPIN_LIGHT then return OVERDRIVE_LIGHT end
	if level == LIMITER_LIGHT and gear == "N" then return SHIFT_LIGHT end
	return level
end

-- The drivetrain part of the gauge (contract 3.2 and 7) for a car whose drive state carries RpmFraction: the rpm
-- needle, the gear readout and the shift light. Step returns this frame's arc fraction, or nil when the drive state has
-- no telemetry (the caller then draws the speed arc exactly as before). Clear hides the gear and the light, once.
-- No lookup and no creation; the gauge setters write on change only.
function HudView._telemetry(gauge)
	local on = false
	local needle, velocity, elapsed, sweeping = 0, 0, 0, false
	local gear, revision, light = nil, nil, 0
	local telemetry = {}

	function telemetry.Clear()
		if not on then return end
		on = false
		gear, revision, light = nil, nil, 0
		gauge.SetShiftLight(0)
		gauge.SetGear(nil)
	end

	function telemetry.Step(dt, drive)
		local target = drive.RpmFraction
		if type(target) ~= "number" or target ~= target then
			telemetry.Clear()
			return nil
		end
		target = math.clamp(target, 0, 1)
		if type(dt) ~= "number" or dt ~= dt or dt < 0 then dt = 0 end
		local first = not on
		if first then
			on = true
			needle, velocity, elapsed, sweeping = 0, 0, 0, true
		end

		if drive.Gear ~= gear then
			gear = drive.Gear
			gauge.SetGear(gear)
		end
		-- The first revision seen is a baseline, not a shift.
		local seen = drive.GearRevision
		if first then
			revision = seen
		elseif seen ~= revision then
			revision = seen
			gauge.PunchGear()
		end
		local level = HudView._lightLevel(drive.ShiftLight, drive.Overdrive, drive.Gear)
		if level ~= light then
			light = level
			gauge.SetShiftLight(level)
		end

		if sweeping then
			elapsed += dt
			needle, sweeping = HudView._startSweep(elapsed, target)
			velocity = 0
		else
			needle, velocity = HudView._needleStep(needle, velocity, target, dt, NEEDLE_OMEGA, NEEDLE_ZETA)
			if needle ~= needle or velocity ~= velocity then needle, velocity = target, 0 end
		end
		return needle
	end

	return telemetry
end

-- layer: the static Layer. extra = {
--   Live: Layer?            the live Layer (the gallery passes none: one stage holds both)
--   Player: Player?         binds the cash chip; nil in the gallery
--   SampleCash: number?     gallery
--   MinimapDeps: table?     HudMinimap deps; nil in the gallery
--   DriveState: table?      the shared MobileDriveInputState table (SpeedMph, BoostPercent, IsDriving; from a car with
--                           a drivetrain also RpmFraction, Gear, GearRevision, ShiftLight, Overdrive)
--   Subject: table?         { Part, VehiclePart }, kept current by the client's listeners
--   Radio: table?           Audio.RadioClient when the radio is on; nil (and no strip) in the gallery
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

	-- Radio strip: bottom centre, lifted clear of the HUD buttons (or of the gauge, which TouchDrive centres there).
	-- Compact TouchDrive (a phone) has no room there: above the centred gauge the strip stood in the middle of the
	-- driving view, on the world prompts (PromptStack) and the Duel challenge button. It joins the status column
	-- instead: top right, under the minimap and the cash chip, above the accelerate button.
	-- Compact TouchDrive: the status column (cash chip, radio strip) hangs under the minimap. While the minimap is
	-- not part of the HUD (inside an owned garage) the column moves up into its place instead of floating under a gap.
	local columnRaise = 0
	local seatRadio
	local radio
	if extra.Radio and compact and touchDrive then
		local seat = Instance.new("Frame")
		seat.Name = "RadioSeat"
		seat.BackgroundTransparency = 1
		seat.BorderSizePixel = 0
		seat.Size = UDim2.new()
		seat.Parent = layer.Slot("HudStatus")
		radio = m.RadioStripView.Mount(seat, extra.Radio, scope, { Px = px, Gap = px(space.Gap), Lift = 0, Compact = true,
			Touch = true })
		local strip = radio.Instance
		seatRadio = function()
			local size = strip.Size
			local right = size.X.Offset
			for _, child in ipairs(strip:GetChildren()) do
				if child:IsA("GuiButton") then
					right = math.max(right, child.Position.X.Offset + child.Size.X.Offset)
				end
			end
			local top = px(space.CompactStatusHeight) + px(space.TouchGap)
			local x, y = HudView._radioSeat(size.X.Offset, size.Y.Offset, right, top)
			local position = UDim2.fromOffset(x, y - columnRaise)
			if seat.Position ~= position then seat.Position = position end
		end
		seatRadio()
		scope:connect(strip:GetPropertyChangedSignal("Size"), seatRadio)
		if ctx.Changed then
			scope:connect(ctx.Changed, function(change)
				if type(change) == "table" and change.Layout == false then return end
				seatRadio()
			end)
		end
		scope:add(function() seat:Destroy() end)
	elseif extra.Radio then
		local below = touchDrive and HudView._gaugeSize(space, ctx.Class, ctx.Arrangement)
			or (compact and space.CompactHudButton or space.HudButtonHeight)
		radio = m.RadioStripView.Mount(layer.Slot("BottomCentre"), extra.Radio, scope, { Px = px, Gap = px(space.Gap),
			Lift = px(below) + px(space.Gap), Compact = compact, Touch = touchDrive })
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

		local buttonsShown = state.ShowBottomButtons and not HudView._buttonsCovered(state, compact)
		if buttons.Visible ~= buttonsShown then buttons.Visible = buttonsShown end
		show("Status", status, state.ShowStatus and not HudView._statusCovered(state, compact))
		local raise = HudView._columnRaise(state, compact and touchDrive, px(space.CompactMinimap) + px(space.TouchGap))
		if raise ~= columnRaise then
			columnRaise = raise
			status.Instance.Position = UDim2.fromOffset(0, -raise)
			if seatRadio then seatRadio() end
		end
		local covered = HudView._liveCovered(state, compact)
		show("Gauge", gauge, state.ShowGauge and not covered)
		if radio then show("Radio", radio, state.ShowActionBar and not covered) end

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
	local telemetry = HudView._telemetry(gauge)

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

			-- D1275-1293 and M493. A car that sends drivetrain telemetry shows rpm on the arc with its gear and shift
			-- light (drivetrain_feel contract 7); every other car shows speed exactly as before.
			if driving then
				local speed = math.max(0, tonumber(drive.SpeedMph) or 0)
				gauge.Step(dt) -- first, so a punch or light change below is drawn at its full value this frame
				local rpm = telemetry.Step(dt, drive)
				gauge.SetSpeed(math.floor(speed + 0.5), rpm or math.clamp(speed / maxMph, 0, 1))
				local target = math.clamp((tonumber(drive.BoostPercent) or 100) / 100, 0, 1)
				local amount = smoothing <= 0 and 1 or math.clamp(dt * smoothing, 0, 1)
				boostAlpha += (target - boostAlpha) * amount
				gauge.SetBoost(math.clamp(boostAlpha, 0, 1))
			else
				boostAlpha = 1
				telemetry.Clear() -- no stale gear or light on the next car
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
		if radio then radio.Destroy() end
		if marker then marker:Destroy() end
	end

	return self
end

return HudView
