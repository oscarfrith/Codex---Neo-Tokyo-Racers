-- Owns the gallery items for the free-roam HUD views (HUD, car panel, three modals) over a fake model; no game state, remote, profile or player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.FreeRoam. Requires: Kit.Layers, FreeRoam.HudView (resolved on the first mount).
--
-- Agent F2a's half of the family fixtures (HUD). The touch controls and activity items of agent F2b are appended by
-- the integrator (NOTES_a: one Dev.Fixtures.FreeRoam module, two authors).

local FADE_SECONDS = 0.55
local SAMPLE_CASH = 3613709
local SAMPLE_SPEED = 142
local SAMPLE_BOOST = 0.64
local SAMPLE_MAX_MPH = 260

local STATE_KEYS = { Driving = true, CarPanel = true, Modal = true, Racing = true, Inside = true, Rows = true, Touch = true,
	Reveal = true, NoGyro = true, NoRank = true, Vehicle = true, Hidden = true }

local ROWS = {
	Six = {
		{ VehicleId = "v1", CockpitId = "seraph", Category = "EXOTIC", Name = "SERAPH", Image = "", Tier = "S", Rating = 939, Price = 0, Selected = true },
		{ VehicleId = "v2", CockpitId = "endura", Category = "EXOTIC", Name = "ENDURA", Image = "", Tier = "B", Rating = 675, Price = 0, Selected = false },
		{ VehicleId = "v3", CockpitId = "aurora", Category = "EXOTIC", Name = "AURORA", Image = "", Tier = "C", Rating = 540, Price = 0, Selected = false },
		{ VehicleId = "v4", CockpitId = "kestrel", Category = "PIERCER", Name = "KESTREL", Image = "", Tier = "C", Rating = 512, Price = 0, Selected = false },
		{ VehicleId = "v5", CockpitId = "zephyr", Category = "EXOTIC", Name = "ZEPHYR", Image = "", Tier = "D", Rating = 390, Price = 0, Selected = false },
		{ VehicleId = "v6", CockpitId = "rosso", Category = "EXOTIC", Name = "ROSSO", Image = "", Tier = "A", Rating = 801, Price = 0, Selected = false },
	},
	Empty = {},
	Long = {
		{ VehicleId = "l1", CockpitId = "long", Category = "INTERCEPTOR HEAVY", Name = "THUNDERCLAP GRAND TOURER MK II", Image = "", Tier = "S", Rating = 1000, Price = 0, Selected = true },
		{ VehicleId = "l2", CockpitId = "odd", Category = "OTHER", Name = "COCKPIT WITH AN UNKNOWN TIER", Image = "", Tier = "?", Rating = 0, Price = 0, Selected = false },
	},
}

local modulesCache
local function modules()
	if not modulesCache then
		local pulse = script.Parent.Parent.Parent
		modulesCache = {
			Layers = require(pulse.Kit.Layers),
			HudView = require(pulse.FreeRoam.HudView),
		}
	end
	return modulesCache
end

local function newSignal()
	local handlers = {}
	local signal = {}
	function signal:Connect(handler)
		local connection = {}
		function connection:Disconnect()
			local index = table.find(handlers, handler)
			if index then table.remove(handlers, index) end
		end
		table.insert(handlers, handler)
		return connection
	end
	function signal:Fire(...)
		for _, handler in ipairs(table.clone(handlers)) do handler(...) end
	end
	return signal
end

local function categoryOptions(rows)
	local seen, options = {}, { "ALL" }
	for _, row in ipairs(rows) do
		if not seen[row.Category] then
			seen[row.Category] = true
			table.insert(options, row.Category)
		end
	end
	return options
end

-- The same getters and actions as HudModel, with canned state. Actions only move the canned state.
local function fakeModel(props)
	local model = { Changed = newSignal(), ControlsFadeSeconds = FADE_SECONDS, BuyMoreKey = "BuyMore" }
	local state = { Rows = {}, CategoryOptions = { "ALL" }, Category = "ALL", Sort = "RATING" }
	local access, minimapMode, controlMode = "FRIENDS", "ROTATE", "Arrows"
	local settings = {}

	local function apply(patch)
		for key, value in pairs(patch) do
			if not STATE_KEYS[key] then error("FreeRoam fixture: unknown key '" .. tostring(key) .. "'", 3) end
			settings[key] = value
		end
		local racing = settings.Racing == true
		local inside = settings.Inside == true
		local rowsKey = settings.Rows or "Six"
		state.Touch = settings.Touch == true
		state.Racing = racing
		state.TelemetryOnly = racing
		state.OwnedGarageInside = inside
		state.Driving = settings.Driving == true
		state.Hidden = settings.Hidden == true
		state.CarPanelOpen = settings.CarPanel == true and not racing
		state.ShowActionBar = not racing
		state.ShowMainActions = not inside
		state.ShowStatus = not racing
		state.ShowMinimap = not racing and not state.CarPanelOpen and not inside
		state.ShowBottomButtons = state.Driving and not racing
		state.ShowGauge = state.Driving
		state.MapLive = false
		state.RowsLoading = rowsKey == "Loading"
		local rows = ROWS[rowsKey] or ROWS.Empty
		if state.RowsSource ~= rows then
			state.RowsSource = rows
			state.Rows = table.clone(rows)
			state.CategoryOptions = categoryOptions(rows)
		end
		state.Vehicle = settings.Vehicle ~= false and { Tier = "S", Rating = 939, Name = "SERAPH" } or nil
		state.ActiveModal = settings.Modal
		state.ControlsReveal = settings.Reveal == true and settings.Modal == "Controls"
		state.ControlsFading = false
		state.Busy = false
	end
	apply(props or {})

	local function change(patch, reason)
		apply(patch)
		model.Changed:Fire(reason)
	end

	function model.Apply(patch) change(patch, "Fixture") end
	function model.GetState() return state end
	function model.IsMinimapShowing() return not state.Hidden and state.ShowMinimap end
	function model.GetRank()
		if settings.NoRank then return { Visible = false, Rank = 1, Fraction = 1, Text = "MAX" } end
		return { Visible = true, Rank = 6, Fraction = 0.4, Text = "400 / 1000 XP" }
	end
	function model.GetPassengerAccess() return access end
	function model.GetMinimapMode() return minimapMode end
	function model.GetControlMode() return controlMode end
	function model.IsControlModeLocked(mode) return mode == "Tilt" and settings.NoGyro == true end
	function model.SetPassengerAccess(value) access = value; model.Changed:Fire("PassengerAccess") end
	function model.SetMinimapMode(value) minimapMode = value; model.Changed:Fire("MinimapMode") end
	function model.SetControlMode(value) controlMode = value; model.Changed:Fire("MobileControlMode") end
	function model.SetDriving(driving) change({ Driving = driving }, "Driving") end
	function model.OpenModal(name) change({ Modal = name }, "Modal") end
	function model.CloseModal()
		if state.ControlsReveal then return end
		settings.Modal = nil
		change({}, "Modal")
	end
	function model.CompleteControls()
		settings.Modal = nil
		settings.Reveal = false
		change({}, "Modal")
	end
	function model.ToggleCarPanel() change({ CarPanel = not state.CarPanelOpen }, "CarPanel") end
	function model.SetCarPanelOpen(open) change({ CarPanel = open == true }, "CarPanel") end
	function model.SelectCategory(option)
		state.Category = option
		local rows = {}
		for _, row in ipairs(state.RowsSource) do
			if option == "ALL" or row.Category == option then table.insert(rows, row) end
		end
		state.Rows = rows
		model.Changed:Fire("Rows")
	end
	function model.SelectSort(option)
		state.Sort = option
		model.Changed:Fire("Rows")
	end
	function model.SpawnVehicle() change({ CarPanel = false }, "Spawn") end
	function model.BuyMore() end
	function model.Despawn() change({ Vehicle = false }, "Despawn") end
	function model.ExitVehicle() change({ Driving = false }, "Exit") end
	function model.RequestTeleport() end
	function model.OpenGarages() end
	function model.OpenRaces() end
	function model.OpenFullMap() end
	function model.CashPackPressed() end
	return model
end

local function stageOf(parent)
	return parent:FindFirstAncestor("Stage") or parent
end

-- Builds the whole HUD view on its own Hud stage over the gallery stage, so every real slot is exercised.
local function mount(parent, props, scope, ctx)
	local m = modules()
	local layer = m.Layers.Stage(stageOf(parent), ctx, "Hud")
	local model = fakeModel(props)
	local view = m.HudView.Mount(layer, model, scope, {
		SampleCash = SAMPLE_CASH,
		SpeedGaugeMaxMph = SAMPLE_MAX_MPH,
		Sample = { Speed = SAMPLE_SPEED, Boost = SAMPLE_BOOST },
	})
	view.Render("Mount")
	scope:connect(model.Changed, function(reason)
		view.Render(reason)
	end)
	local destroyed = false
	local component = { Instance = layer.Root, Model = model, View = view }
	function component.Set(patch)
		model.Apply(patch)
	end
	function component.Destroy()
		if destroyed then return end
		destroyed = true
		view.Destroy()
		layer.Destroy()
	end
	return component
end

local function item(id, states)
	return { Id = id, Frame = "Hud", States = states, Mount = mount }
end

return {
	item("FreeRoam.Hud", {
		{ Id = "Driving", Props = { Driving = true } },
		{ Id = "OnFoot", Props = { Driving = false, Vehicle = false } },
		{ Id = "NoRank", Props = { Driving = true, NoRank = true } },
		{ Id = "RaceTelemetryOnly", Props = { Driving = true, Racing = true } },
		{ Id = "OwnedGarageInside", Props = { Inside = true, Vehicle = false } },
		{ Id = "Hidden", Props = { Hidden = true } },
	}),
	item("FreeRoam.CarPanel", {
		{ Id = "Six", Props = { CarPanel = true, Rows = "Six" } },
		{ Id = "Driving", Props = { CarPanel = true, Rows = "Six", Driving = true } },
		{ Id = "Loading", Props = { CarPanel = true, Rows = "Loading" } },
		{ Id = "Empty", Props = { CarPanel = true, Rows = "Empty", Vehicle = false } },
		{ Id = "LongStrings", Props = { CarPanel = true, Rows = "Long" } },
	}),
	item("FreeRoam.Modal.Controls", {
		{ Id = "Open", Props = { Modal = "Controls", Driving = true } },
		{ Id = "FirstDriveReveal", Props = { Modal = "Controls", Driving = true, Reveal = true } },
	}),
	item("FreeRoam.Modal.Settings", {
		{ Id = "Open", Props = { Modal = "Settings" } },
		{ Id = "Touch", Props = { Modal = "Settings", Touch = true } },
		{ Id = "TouchNoGyroscope", Props = { Modal = "Settings", Touch = true, NoGyro = true } },
	}),
	item("FreeRoam.Modal.Cash", {
		{ Id = "Open", Props = { Modal = "Cash" } },
	}),
}
