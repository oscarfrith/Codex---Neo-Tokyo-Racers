-- Tests for FreeRoam.HudView: the pure helpers, then every gallery state of the family mounted on a detached stage at
-- R1080 and C844 over the fake model (API2 6.4): no error, inside the budget, a second Render and a sort change
-- create and destroy nothing. Needs kit v2 and the fixtures module; nothing is parented into the game tree.
-- drivetrain_feel: the rpm needle, the start-up sweep, the light mapping and the telemetry driver over a fake gauge.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	local UIP = "ReplicatedStorage.Modules.Game.UIPulse."
	local HUD_BUDGET = { Regular = 260, Compact = 220 } -- PC 5.2
	local MODAL_BUDGET = 120 -- PC 5.2, per modal or panel

	case("gauge size per class and arrangement", function()
		local space = { GaugeSize = 403, GaugeTouchSize = 240, CompactGauge = 92 }
		expect(M._gaugeSize(space, "Regular", "Standard") == 403, "Regular")
		expect(M._gaugeSize(space, "Regular", "TouchDrive") == 240, "Regular touch")
		expect(M._gaugeSize(space, "Compact", "TouchDrive") == 92, "Compact")
	end)

	case("status patch: vehicle known, unknown tier, no vehicle", function()
		local patch, key = M._statusPatch({ Tier = "S", Rating = 939.6 }, { Visible = true, Rank = 6 })
		expect(patch.Mode == "Vehicle" and patch.Tier == "S" and patch.Rating == 939 and patch.Rank == nil and key == "S|939", "vehicle; the rank stays on the minimap")
		patch, key = M._statusPatch(nil, { Visible = true, Rank = 6 })
		expect(patch.Mode == "CashOnly" and key == "", "no vehicle")
		patch = M._statusPatch({ Tier = "?", Rating = 1 }, { Visible = false, Rank = 1 })
		expect(patch.Mode == "CashOnly", "unknown tier")
	end)

	case("live cover: any modal hides the gauge and minimap; the vehicles panel does on Compact only", function()
		expect(M._liveCovered({ ActiveModal = nil, CarPanelOpen = false }, true) == false, "nothing open, Compact")
		expect(M._liveCovered({ ActiveModal = nil, CarPanelOpen = false }, false) == false, "nothing open, Regular")
		expect(M._liveCovered({ ActiveModal = "Settings", CarPanelOpen = false }, true) == true, "modal, Compact")
		expect(M._liveCovered({ ActiveModal = "Cash", CarPanelOpen = false }, false) == true, "modal, Regular")
		expect(M._liveCovered({ ActiveModal = nil, CarPanelOpen = true }, true) == true, "vehicles panel, Compact")
		expect(M._liveCovered({ ActiveModal = nil, CarPanelOpen = true }, false) == false, "vehicles panel, Regular: the gauge stays")
	end)

	case("row placement: a right-anchored row ends at its slot, a centred row straddles it", function()
		local width, x, y = M._rowPlace({ 80, 80, 80, 80, 80 }, 64, 8, 1, 0)
		expect(width == 432 and x == -432 and y == 0, "action bar: five tiles end at the slot")
		width, x, y = M._rowPlace({ 201, 240 }, 56, 10, 0.5, 1)
		expect(width == 451 and x == -226 and y == -56, "bottom buttons: centred, on the slot's bottom edge")
		width, x, y = M._rowPlace({}, 0, 8, 1, 1)
		expect(width == 0 and x == 0 and y == 0, "an empty row")
	end)

	case("needle: an exact spring step, the same at any frame rate", function()
		local function run(rate, seconds)
			local position, velocity = 0.2, 0
			for _ = 1, math.floor(rate * seconds + 0.5) do
				position, velocity = M._needleStep(position, velocity, 0.7, 1 / rate, 25, 0.5)
			end
			return position, velocity
		end
		local a, va = run(60, 0.5)
		local b, vb = run(20, 0.5)
		local c, vc = M._needleStep(0.2, 0, 0.7, 0.5, 25, 0.5)
		expect(math.abs(a - b) < 1e-9 and math.abs(a - c) < 1e-9, "60 fps, 20 fps and one step agree")
		expect(math.abs(va - vb) < 1e-6 and math.abs(va - vc) < 1e-6, "and so do their velocities")
		local settled = M._needleStep(0.2, 0, 0.7, 2, 25, 0.5)
		expect(math.abs(settled - 0.7) < 1e-6, "settled on the target")
		local peak, position, velocity = 0, 0.2, 0
		for _ = 1, 60 do
			position, velocity = M._needleStep(position, velocity, 0.7, 1 / 60, 25, 0.5)
			peak = math.max(peak, position)
		end
		expect(peak > 0.7 and peak < 0.7 + 0.5 * 0.25, "a slight overshoot, under a quarter of the step")
		local same, still = M._needleStep(0.4, 0.3, 0.9, 0, 25, 0.5)
		expect(same == 0.4 and still == 0.3, "no time, no move")
		local x = M._needleStep(0.2, 0, 0.7, 1 / 60, 25, 3)
		expect(x == x, "a zeta over 1 is clamped, never not-a-number")
	end)

	case("start-up sweep: up to full, hold, down to the live reading, about half a second", function()
		local value, running = M._startSweep(0, 0.12)
		expect(value == 0 and running, "starts empty")
		local peak = 0
		local elapsed = 0
		while running and elapsed < 2 do
			elapsed += 1 / 60
			value, running = M._startSweep(elapsed, 0.12)
			peak = math.max(peak, value)
			expect(value >= 0 and value <= 1, "inside the arc")
		end
		expect(peak == 1, "reaches full")
		expect(not running and value == 0.12, "ends on the live reading")
		expect(elapsed > 0.4 and elapsed < 0.6, "about half a second, took " .. elapsed)
	end)

	case("light level: ShiftLight 0..4 and Overdrive onto Kit.Gauge.Light", function()
		expect(M._lightLevel(nil, nil) == 0 and M._lightLevel(0, false) == 0, "off")
		expect(M._lightLevel(1, false) == 1 and M._lightLevel(2, nil) == 2 and M._lightLevel(3, false) == 3, "pass through")
		expect(M._lightLevel(4, true) == 4, "the spin warning beats Overdrive")
		expect(M._lightLevel(0, true) == 5 and M._lightLevel(3, true) == 5, "Overdrive otherwise")
		expect(M._lightLevel(9, false) == 0 and M._lightLevel(0 / 0, false) == 0 and M._lightLevel("2", false) == 0, "junk is off")
		expect(M._lightLevel(3, false, "N") == 2, "the limiter in N is a steady shift light: no bounce effect in neutral")
		expect(M._lightLevel(3, false, "3") == 3 and M._lightLevel(3, false, "R") == 3, "in a gear the limiter flashes")
		expect(M._lightLevel(2, false, "N") == 2 and M._lightLevel(4, false, "N") == 4, "N changes nothing else")
	end)

	-- A gauge stand-in that records the calls the telemetry driver makes.
	local function fakeGauge()
		local calls = { Gear = {}, Light = {}, Punch = 0 }
		return {
			SetGear = function(text) table.insert(calls.Gear, text == nil and "nil" or text) end,
			SetShiftLight = function(level) table.insert(calls.Light, level) end,
			PunchGear = function() calls.Punch += 1 end,
		}, calls
	end

	case("telemetry: no RpmFraction means the speed arc and no gauge call", function()
		local gauge, calls = fakeGauge()
		local driver = M._telemetry(gauge)
		local drive = { SpeedMph = 80, IsDriving = true }
		for _ = 1, 10 do
			expect(driver.Step(1 / 60, drive) == nil, "nil: the caller draws speed as before")
		end
		driver.Clear()
		expect(#calls.Gear == 0 and #calls.Light == 0 and calls.Punch == 0, "a car without telemetry never touches the gear")
	end)

	case("telemetry: sweep, gear on change, punch on a new revision (first one a baseline), lights, clear", function()
		local gauge, calls = fakeGauge()
		local driver = M._telemetry(gauge)
		local drive = { RpmFraction = 0.11, Gear = "N", GearRevision = 7, ShiftLight = 0, Overdrive = false }
		local first = driver.Step(1 / 60, drive)
		expect(first ~= nil and first < 0.2, "the sweep starts near empty")
		expect(calls.Gear[1] == "N" and calls.Punch == 0, "gear shown, the first revision is no shift")
		local peak, value = 0, first
		for _ = 1, 40 do
			value = driver.Step(1 / 60, drive)
			peak = math.max(peak, value)
		end
		expect(peak >= 0.99, "the sweep reaches full")
		expect(math.abs(value - 0.11) < 0.02, "and comes back to the live reading")
		for _ = 1, 10 do driver.Step(1 / 60, drive) end
		expect(#calls.Gear == 1, "the same gear is not sent again")

		drive.Gear, drive.GearRevision, drive.RpmFraction = "1", 8, 0.5
		driver.Step(1 / 60, drive)
		expect(calls.Gear[2] == "1" and calls.Punch == 1, "a shift: new gear and one punch")
		driver.Step(1 / 60, drive)
		expect(calls.Punch == 1, "one punch per revision")

		drive.ShiftLight = 2
		driver.Step(1 / 60, drive)
		drive.Overdrive = true
		driver.Step(1 / 60, drive)
		drive.ShiftLight = 4
		driver.Step(1 / 60, drive)
		expect(calls.Light[1] == 2 and calls.Light[2] == 5 and calls.Light[3] == 4, "shift, then Overdrive, then the spin warning")

		drive.RpmFraction = nil
		expect(driver.Step(1 / 60, drive) == nil, "telemetry gone: the speed arc again")
		expect(calls.Gear[#calls.Gear] == "nil" and calls.Light[#calls.Light] == 0, "gear hidden and light off")
		local count = #calls.Gear
		driver.Step(1 / 60, drive)
		driver.Clear()
		expect(#calls.Gear == count, "cleared once only")

		drive.RpmFraction, drive.GearRevision = 0.3, 12
		driver.Step(1 / 60, drive)
		expect(calls.Punch == 1, "telemetry back: its revision is a new baseline, not a shift")
		local again = driver.Step(1 / 60, drive)
		expect(again < 0.2, "and the start-up sweep runs again from near empty")
	end)

	case("telemetry: the limiter in N (countdown neutral revs) is steady; in a gear it flashes", function()
		local gauge, calls = fakeGauge()
		local driver = M._telemetry(gauge)
		local drive = { RpmFraction = 0.88, Gear = "N", GearRevision = 1, ShiftLight = 3, Overdrive = false }
		for _ = 1, 30 do driver.Step(1 / 60, drive) end
		expect(#calls.Light == 1 and calls.Light[1] == 2, "N on the limiter: one steady shift light")
		drive.Gear, drive.GearRevision = "3", 2
		driver.Step(1 / 60, drive)
		expect(calls.Light[2] == 3, "in a gear: the limiter level, which the gauge flashes")
	end)

	case("telemetry: the needle is frame-rate independent after the sweep", function()
		local function run(rate)
			local gauge = fakeGauge()
			local driver = M._telemetry(gauge)
			local drive = { RpmFraction = 0.4, Gear = "2", GearRevision = 1, ShiftLight = 0 }
			for _ = 1, rate do driver.Step(1 / rate, drive) end -- one second: the sweep is over
			drive.RpmFraction = 0.8
			local value
			for _ = 1, math.floor(rate * 0.1 + 0.5) do value = driver.Step(1 / rate, drive) end
			return value
		end
		local fast, slow = run(60), run(20)
		expect(math.abs(fast - slow) < 1e-6, string.format("60 fps %.6f against 20 fps %.6f", fast, slow))
	end)

	local function mountAll(presetName, size, touch)
		local loaded, Metrics, items = pcall(function()
			return env.Load(UIP .. "Kit.Metrics"), env.Load(UIP .. "Dev.Fixtures.FreeRoam")
		end)
		if not loaded then
			case(presetName .. " / fixtures load", function() error(tostring(Metrics)) end)
			return
		end
		for _, item in ipairs(items) do
			for _, stateSpec in ipairs(item.States) do
				case(string.format("%s / %s / %s", presetName, item.Id, stateSpec.Id), function()
					local stage = env.Detached("Frame")
					stage.Name = "Stage"
					stage.Size = UDim2.fromOffset(size.X, size.Y)
					local ctx = Metrics.Fixed({ Size = size, TouchEnabled = touch, Input = touch and "Touch" or "KeyboardAndMouse" })
					Metrics.Bind(stage, ctx)
					local scope = env.Scope()
					local component = item.Mount(stage, stateSpec.Props, scope, ctx)
					local count = #stage:GetDescendants()
					local budget = HUD_BUDGET[ctx.Class]
					if stateSpec.Props.Modal or stateSpec.Props.CarPanel then budget += MODAL_BUDGET end
					expect(count <= budget, string.format("%d instances, budget %d", count, budget))

					local added, removed = 0, 0
					local addedConnection = stage.DescendantAdded:Connect(function() added += 1 end)
					local removedConnection = stage.DescendantRemoving:Connect(function() removed += 1 end)
					component.View.Render("Again")
					component.View.Render("Again")
					if stateSpec.Props.CarPanel then
						component.Model.SelectSort("A-Z")
						component.Model.SelectSort("RATING")
					end
					addedConnection:Disconnect()
					removedConnection:Disconnect()
					expect(added == 0 and removed == 0, string.format("churn: %d added, %d removed", added, removed))

					local state = component.Model.GetState()
					expect(component.Model.IsMinimapShowing() == (state.ShowMinimap and not state.Hidden), "minimap flag")
					component.Destroy()
					component.Destroy()
					scope:destroy()
				end)
			end
		end
	end

	mountAll("R1080", Vector2.new(1920, 1080), false)
	mountAll("C844", Vector2.new(844, 390), true)

	return results
end
