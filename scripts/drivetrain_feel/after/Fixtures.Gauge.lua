-- Owns the gallery item for Kit.Gauge, still and animated from fixture data (speed, boost, gear, shift light and punch); no vehicle, game state, remote, profile or player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Gauge. Requires: Tokens, Metrics, Perf, Gauge (resolved on the first mount).

local PUBLISH_SECONDS = 1 -- how often an animated state publishes its counters for a probe
local DEFAULT_PERIOD = 4 -- seconds from empty to full in an animated state
local DEFAULT_TOP_SPEED = 240
local PUNCH_REPEAT = 1 -- seconds between punches in a Punch state
-- The gear run (Rpm = true): each gear's needle climbs from the land point to the redline at HudRedlineSweep
-- (drivetrain_feel contract 4.6), warms, lights, then shifts with a punch.
local RUN_GEARS = { "1", "2", "3", "4", "5", "6", "7" }
local RUN_LAND, RUN_REDLINE = 0.45, 0.87
local RUN_WARM, RUN_SHIFT = 0.6, 0.85 -- fractions of a gear's climb where the light warms and then shows

local kitCache
local function kit()
	if not kitCache then
		local folder = script.Parent.Parent.Parent.Kit
		kitCache = {
			Tokens = require(folder.Tokens),
			Metrics = require(folder.Metrics),
			Perf = require(folder.Perf),
			Gauge = require(folder.Gauge),
		}
	end
	return kitCache
end

local GAUGE_FIXTURE_KEYS = { Speed = true, Fraction = true, Boost = true, Unit = true, SizeKey = true,
	ShowBoost = true, ShowBoostText = true, Animate = true, TopSpeed = true, Period = true,
	Gear = true, Light = true, Punch = true, Rpm = true }

local function checkKeys(patch)
	assert(type(patch) == "table", "Gauge fixture expects a table")
	for key in pairs(patch) do
		if not GAUGE_FIXTURE_KEYS[key] then error(string.format("Gauge fixture: unknown key '%s'", tostring(key)), 3) end
	end
end

-- Pure. The eased 0..1 position of the sweep after `elapsed` seconds: up over one period, down over the next.
local function sweepAt(elapsed, period)
	local phase = (elapsed / math.max(period, 0.1)) % 2
	if phase > 1 then phase = 2 - phase end
	return phase * phase * (3 - 2 * phase)
end

-- Pure. The gear run after `elapsed` seconds with `period` seconds per gear: the gear's index, the needle fraction,
-- the light level (0 off, 1 warm, 2 shift) and the speed as a fraction of the top speed.
local function runAt(elapsed, period)
	period = math.max(period, 0.1)
	local count = #RUN_GEARS
	local index = math.floor(elapsed / period) % count + 1
	local climb = (elapsed % period) / period
	local light = if climb >= RUN_SHIFT and index < count then 2 elseif climb >= RUN_WARM and index < count then 1 else 0
	return index, RUN_LAND + (RUN_REDLINE - RUN_LAND) * climb, light, (index - 1 + climb) / count
end

local function mountGauge(parent, props, scope, ctx)
	local k = kit()
	checkKeys(props)
	ctx = ctx or k.Metrics.Of(parent)
	local space = k.Tokens.Space
	local current = {}
	for key, value in pairs(props) do current[key] = value end

	-- Sizes are tokens: the named one, else the class default (Compact has its own).
	local size = nil
	if current.SizeKey then
		size = space[current.SizeKey]
		assert(type(size) == "number", "Gauge fixture: unknown SizeKey " .. tostring(current.SizeKey))
	elseif ctx.Class == "Compact" then
		size = space.CompactGauge
	end
	local gauge = k.Gauge.New(parent, { Size = size, Unit = current.Unit, ShowBoostText = current.ShowBoostText }, scope)
	local root = gauge.Instance

	local function still()
		gauge.SetSpeed(current.Speed or 0, current.Fraction or 0)
		gauge.SetBoost(current.Boost or 0)
		gauge.SetVisibleBoost(current.ShowBoost ~= false)
		gauge.SetGear(current.Gear)
		gauge.SetShiftLight(current.Light or 0)
	end

	-- A clock runs only while a state asks for one: an animation, a repeating punch, or a light that moves on its own
	-- (the limiter flash, the Overdrive pulse). Its one frame step reads fixture data and calls the setters an owner
	-- would call, then the gauge's Step; it publishes its counters once a second so a probe can read writes per frame.
	local binding = nil
	local elapsed, frames, published, punched = 0, 0, 0, 0
	local period, topSpeed = DEFAULT_PERIOD, DEFAULT_TOP_SPEED
	local runGear = 0

	local function wantsClock()
		local light = k.Gauge.Light
		return current.Animate == true or current.Punch == true or current.Light == light.Limiter
			or current.Light == light.Overdrive
	end

	local function step(dt)
		gauge.Step(dt) -- first, as HudView does: a punch or light change below is drawn at its full value this frame
		elapsed += dt
		frames += 1
		if current.Animate == true and current.Rpm == true then
			local index, fraction, light, speed = runAt(elapsed, period)
			gauge.SetGear(RUN_GEARS[index])
			if index ~= runGear then
				if runGear ~= 0 then gauge.PunchGear() end
				runGear = index
			end
			gauge.SetShiftLight(light)
			gauge.SetSpeed(topSpeed * speed, fraction)
		elseif current.Animate == true then
			local eased = sweepAt(elapsed, period)
			gauge.SetSpeed(topSpeed * eased, eased)
			gauge.SetBoost(1 - eased)
		elseif current.Punch == true and elapsed - punched >= PUNCH_REPEAT then
			punched = elapsed
			gauge.PunchGear()
		end
		if elapsed - published >= PUBLISH_SECONDS then
			published = elapsed
			root:SetAttribute("GaugeFrames", frames)
			root:SetAttribute("GaugeWrites", gauge._writes())
		end
	end

	local function applyAnimate()
		period = current.Period or DEFAULT_PERIOD
		topSpeed = current.TopSpeed or DEFAULT_TOP_SPEED
		local want = wantsClock()
		if want and not binding then
			elapsed, frames, published, punched, runGear = 0, 0, 0, 0, 0
			binding = k.Perf.Bind("GalleryGauge", root, step)
		elseif not want and binding then
			binding.Disconnect()
			binding = nil
			still()
		end
		root:SetAttribute("GaugeAnimated", want)
	end

	still()
	applyAnimate()

	local destroyed = false
	local component = { Instance = root }
	function component.Set(patch)
		checkKeys(patch)
		for key, value in pairs(patch) do current[key] = value end
		if patch.Unit ~= nil then gauge.SetUnit(patch.Unit) end
		if patch.ShowBoostText ~= nil then gauge.Set({ ShowBoostText = patch.ShowBoostText }) end
		if not binding or current.Animate ~= true then still() end
		applyAnimate()
	end
	function component.Destroy()
		if destroyed then return end
		destroyed = true
		if binding then
			binding.Disconnect()
			binding = nil
		end
		gauge.Destroy()
	end
	scope:add(component.Destroy)
	return component
end

return {
	{
		Id = "Gauge.Gauge",
		Frame = "Hud",
		Slot = "Gauge",
		States = {
			{ Id = "Cruise", Props = { Speed = 142, Fraction = 0.59, Boost = 0.64 } },
			{ Id = "Parked", Props = { Speed = 0, Fraction = 0, Boost = 1 } },
			{ Id = "Race", Props = { Speed = 187, Fraction = 0.78, Boost = 0.3 } },
			{ Id = "BeforeSeam", Props = { Speed = 119, Fraction = 0.49, Boost = 0.49 } },
			{ Id = "AtSeam", Props = { Speed = 120, Fraction = 0.5, Boost = 0.5 } },
			{ Id = "PastSeam", Props = { Speed = 122, Fraction = 0.51, Boost = 0.51 } },
			{ Id = "Full", Props = { Speed = 240, Fraction = 1, Boost = 1 } },
			{ Id = "Kmh", Props = { Speed = 228, Fraction = 0.59, Boost = 0.64, Unit = "KM/H" } },
			{ Id = "TouchSize", Props = { Speed = 142, Fraction = 0.59, Boost = 0.64, SizeKey = "GaugeTouchSize" } },
			{ Id = "NoBoost", Props = { Speed = 142, Fraction = 0.59, Boost = 0.64, ShowBoost = false } },
			{ Id = "NoBoostText", Props = { Speed = 142, Fraction = 0.59, Boost = 0.64, ShowBoostText = false } },
			{ Id = "Sweep", Props = { Animate = true, TopSpeed = 240, Period = 4 } },
			{ Id = "SlowSweep", Props = { Animate = true, TopSpeed = 240, Period = 20 } },
			-- Drivetrain telemetry (drivetrain_feel contract 7): the arc is rpm, redline at 0.87 of the sweep. Light is a
			-- Kit.Gauge.Light level: 0 off, 1 warm, 2 shift, 3 limiter, 4 spin warning, 5 Overdrive. The limiter flashes in a
			-- gear only; HudView shows it in N as a steady shift light (NeutralLimiter).
			{ Id = "GearN", Props = { Speed = 0, Fraction = 0.11, Boost = 1, Gear = "N" } },
			{ Id = "Gear1", Props = { Speed = 21, Fraction = 0.52, Boost = 1, Gear = "1" } },
			{ Id = "Gear7", Props = { Speed = 176, Fraction = 0.71, Boost = 0.64, Gear = "7" } },
			{ Id = "Reverse", Props = { Speed = 7, Fraction = 0.24, Boost = 1, Gear = "R" } },
			{ Id = "ShiftWarm", Props = { Speed = 74, Fraction = 0.79, Boost = 0.8, Gear = "3", Light = 1 } },
			{ Id = "ShiftLight", Props = { Speed = 81, Fraction = 0.86, Boost = 0.8, Gear = "3", Light = 2 } },
			{ Id = "Limiter", Props = { Speed = 83, Fraction = 0.88, Boost = 0.8, Gear = "3", Light = 3 } },
			{ Id = "NeutralLimiter", Props = { Speed = 0, Fraction = 0.88, Boost = 1, Gear = "N", Light = 2 } },
			{ Id = "SpinWarning", Props = { Speed = 14, Fraction = 0.63, Boost = 0.9, Gear = "1", Light = 4 } },
			{ Id = "Overdrive", Props = { Speed = 214, Fraction = 0.87, Boost = 0.3, Gear = "7", Light = 5 } },
			{ Id = "GearPunch", Props = { Speed = 96, Fraction = 0.52, Boost = 0.7, Gear = "4", Punch = true } },
			{ Id = "GearRun", Props = { Animate = true, Rpm = true, TopSpeed = 184, Period = 1.4, Boost = 1 } },
			{ Id = "GearTouchSize", Props = { Speed = 81, Fraction = 0.86, Boost = 0.8, Gear = "3", Light = 2,
				SizeKey = "GaugeTouchSize" } },
		},
		Mount = mountGauge,
		-- Pure, for the fixture test.
		_sweepAt = sweepAt,
		_runAt = runAt,
	},
}
