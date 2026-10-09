-- Owns the gallery item for Kit.Gauge, still and animated from fixture data; no vehicle, game state, remote, profile or player attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Gauge. Requires: Tokens, Metrics, Perf, Gauge (resolved on the first mount).

local PUBLISH_SECONDS = 1 -- how often an animated state publishes its counters for a probe
local DEFAULT_PERIOD = 4 -- seconds from empty to full in an animated state
local DEFAULT_TOP_SPEED = 240

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
	ShowBoost = true, ShowBoostText = true, Animate = true, TopSpeed = true, Period = true }

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
	end

	-- The animation exists only while a state asks for it. Its one frame step reads fixture data and calls the two
	-- setters an owner would call; it publishes its counters once a second so a probe can read writes per frame.
	local binding = nil
	local elapsed, frames, published = 0, 0, 0
	local period, topSpeed = DEFAULT_PERIOD, DEFAULT_TOP_SPEED

	local function step(dt)
		elapsed += dt
		frames += 1
		local eased = sweepAt(elapsed, period)
		gauge.SetSpeed(topSpeed * eased, eased)
		gauge.SetBoost(1 - eased)
		if elapsed - published >= PUBLISH_SECONDS then
			published = elapsed
			root:SetAttribute("GaugeFrames", frames)
			root:SetAttribute("GaugeWrites", gauge._writes())
		end
	end

	local function applyAnimate()
		period = current.Period or DEFAULT_PERIOD
		topSpeed = current.TopSpeed or DEFAULT_TOP_SPEED
		local want = current.Animate == true
		if want and not binding then
			elapsed, frames, published = 0, 0, 0
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
		if not binding then still() end
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
		},
		Mount = mountGauge,
		-- Pure, for the fixture test.
		_sweepAt = sweepAt,
	},
}
