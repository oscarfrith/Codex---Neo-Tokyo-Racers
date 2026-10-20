-- Pure tests for Dev.Fixtures.Gauge: the registration shape of API.md section 10 and the animation's fixture data.
-- Nothing is mounted here; the gallery mounts every state at every preset. drivetrain_feel (API2 amendment A20) adds the
-- gear, shift light, punch and gear-run states.
return function(M, _env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	case("one item, in the Hud frame and the Gauge slot", function()
		expect(type(M) == "table" and #M == 1, "one item")
		local item = M[1]
		expect(item.Id == "Gauge.Gauge" and item.Frame == "Hud" and item.Slot == "Gauge", "id, frame, slot")
		expect(type(item.Mount) == "function", "Mount")
	end)

	case("state shape", function()
		local ids = {}
		for _, state in ipairs(M[1].States) do
			expect(type(state.Id) == "string" and state.Id ~= "", "state Id")
			expect(not string.find(state.Id, "[|,%s]"), "state Id has no separator or space")
			expect(not ids[state.Id], "duplicate state " .. state.Id)
			ids[state.Id] = true
			expect(type(state.Props) == "table", state.Id .. ": Props")
		end
	end)

	case("states cover parked, both sides of the seam, full, both units, the touch size and no boost", function()
		local byId = {}
		for _, state in ipairs(M[1].States) do byId[state.Id] = state.Props end
		expect(byId.Parked.Speed == 0 and byId.Parked.Fraction == 0, "parked")
		expect(byId.BeforeSeam.Fraction < 0.5 and byId.AtSeam.Fraction == 0.5 and byId.PastSeam.Fraction > 0.5, "the seam")
		expect(byId.Full.Fraction == 1 and byId.Full.Boost == 1, "full")
		expect(byId.Kmh.Unit == "KM/H", "the other unit")
		expect(byId.TouchSize.SizeKey == "GaugeTouchSize", "the touch size by token name")
		expect(byId.NoBoost.ShowBoost == false and byId.NoBoostText.ShowBoostText == false, "boost off")
	end)

	case("only the states that ask are animated", function()
		local animated = 0
		for _, state in ipairs(M[1].States) do
			if state.Props.Animate then
				animated += 1
				expect(state.Props.Animate == true and state.Props.Period > 0 and state.Props.TopSpeed > 0, "fixture data")
			end
		end
		expect(animated >= 1 and animated < #M[1].States, "some animated, most still")
		expect(M[1].States[1].Props.Animate == nil, "the default state is still")
	end)

	case("sweep position: eased, up over one period and down over the next", function()
		local sweepAt = M[1]._sweepAt
		expect(sweepAt(0, 4) == 0 and sweepAt(4, 4) == 1 and sweepAt(8, 4) == 0, "ends")
		expect(sweepAt(2, 4) == 0.5 and sweepAt(6, 4) == 0.5, "half way up and half way down")
		local last = 0
		for step = 1, 40 do
			local value = sweepAt(step / 10, 4)
			expect(value >= last and value <= 1, "rises without leaving 0..1")
			last = value
		end
		expect(sweepAt(1, 0) >= 0, "a zero period does not divide by zero")
	end)

	case("drivetrain states: gears N, 1, 7 and R, the shift light, the limiter, the spin warning and Overdrive", function()
		local byId = {}
		for _, state in ipairs(M[1].States) do byId[state.Id] = state.Props end
		expect(byId.GearN.Gear == "N" and byId.Gear1.Gear == "1" and byId.Gear7.Gear == "7" and byId.Reverse.Gear == "R",
			"the gears")
		expect(byId.ShiftWarm.Light == 1 and byId.ShiftLight.Light == 2, "warm and shift")
		expect(byId.Limiter.Light == 3 and byId.SpinWarning.Light == 4 and byId.Overdrive.Light == 5,
			"limiter, spin warning, Overdrive")
		expect(byId.Limiter.Gear ~= "N" and byId.Limiter.Gear ~= nil, "the flashing limiter is in a gear")
		expect(byId.NeutralLimiter.Gear == "N" and byId.NeutralLimiter.Light == 2,
			"the limiter in N is the steady shift light HudView maps it to")
		expect(byId.GearPunch.Punch == true and byId.GearPunch.Gear ~= nil, "a repeating punch on a shown gear")
		expect(byId.GearRun.Animate == true and byId.GearRun.Rpm == true, "the animated gear run")
		expect(byId.GearTouchSize.SizeKey == "GaugeTouchSize" and byId.GearTouchSize.Gear ~= nil, "the gear at the touch size")
		for id, props in pairs(byId) do
			if props.Light ~= nil then
				expect(props.Light % 1 == 0 and props.Light >= 0 and props.Light <= 5, id .. ": a Kit.Gauge.Light level")
			end
			if props.Gear ~= nil then
				expect(type(props.Gear) == "string" and #props.Gear <= 2, id .. ": a short gear string")
			end
			if props.Fraction ~= nil then
				expect(props.Fraction >= 0 and props.Fraction <= 1, id .. ": a fraction")
			end
		end
	end)

	case("gear run: each gear climbs from the land point to the redline; the light only before an upshift", function()
		local runAt = M[1]._runAt
		local index, fraction, light, speed = runAt(0, 1)
		expect(index == 1 and math.abs(fraction - 0.45) < 1e-9 and light == 0 and speed == 0, "starts in first, landed")
		index, fraction, light = runAt(0.9, 1)
		expect(index == 1 and fraction > 0.8 and light == 2, "lit near the redline")
		index, fraction, light = runAt(0.7, 1)
		expect(index == 1 and light == 1, "warm before that")
		index = runAt(1.01, 1)
		expect(index == 2, "then second")
		index, fraction, light = runAt(6.95, 1)
		expect(index == 7 and light == 0, "top gear never lights")
		expect(runAt(7.2, 1) == 1, "and round again")
		local last = 0
		for step = 1, 99 do
			local _, _, _, value = runAt(step / 100 * 7, 1)
			expect(value >= last and value <= 1, "speed rises through the run")
			last = value
		end
		expect(runAt(1, 0) >= 1, "a zero period does not divide by zero")
	end)

	return results
end
