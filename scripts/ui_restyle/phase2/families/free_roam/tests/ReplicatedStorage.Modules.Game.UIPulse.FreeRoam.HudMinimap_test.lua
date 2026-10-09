-- Pure tests for FreeRoam.HudMinimap: the quantiser, the speed zoom and the cached layout. Mounting needs the kit
-- minimap and the shared map layers and is covered by the HudView mount test through the fixtures.
return function(M, env)
	local results = {}

	local function expect(condition, message)
		if not condition then error(message, 2) end
	end

	local function case(name, body)
		local ok, detail = pcall(body)
		table.insert(results, { name = name, ok = ok, detail = if ok then nil else tostring(detail) })
	end

	case("quantise: half degrees", function()
		expect(M._quantise(10.2) == 10, "down")
		expect(M._quantise(10.3) == 10.5, "up")
		expect(M._quantise(-0.2) == 0, "negative near zero")
		expect(M._quantise(359.76) == 360, "top")
	end)

	case("layout: Classic fallbacks and clamps (D143-148, D1152)", function()
		local layout = M._layout(nil)
		expect(layout.MapVisibleStuds == 2850 and layout.MapSmoothing == 10 and layout.MapRotationOffsetDegrees == 0, "map fallbacks")
		expect(layout.ZoomEnabled and layout.IconRotates, "booleans default true")
		expect(layout.ZoomStartMph == 40 and layout.ZoomFullMph == 200 and layout.ZoomMaxFactor == 1.8, "zoom fallbacks")
		expect(layout.ZoomOutResponse == 1.6 and layout.ZoomInResponse == 0.8, "zoom responses")
		local clamped = M._layout({ MapVisibleStuds = 5, ZoomMaxFactor = 9, ZoomEnabled = false, IconRotates = false })
		expect(clamped.MapVisibleStuds == 100 and clamped.ZoomMaxFactor == 4, "clamps")
		expect(clamped.ZoomEnabled == false and clamped.IconRotates == false, "false is kept")
	end)

	case("speed zoom: off, on foot, easing out and back (D133-151)", function()
		local layout = M._layout(nil)
		expect(M._zoomStep(1.5, nil, 0.016, layout) == 1, "no vehicle part resets to 1")
		expect(M._zoomStep(1.5, 300, 0.016, M._layout({ ZoomEnabled = false })) == 1, "disabled resets to 1")
		expect(M._zoomStep(1, 20, 0.016, layout) == 1, "below the start speed nothing moves")
		local out = M._zoomStep(1, 200, 0.1, layout)
		expect(out > 1 and out < 1.8, "eases towards the maximum")
		local expected = 1 + 0.8 * (1 - math.exp(-1.6 * 0.1))
		expect(math.abs(out - expected) < 1e-9, "the Classic formula")
		local back = M._zoomStep(1.8, 0, 0.1, layout)
		expect(math.abs(back - (1.8 - 0.8 * (1 - math.exp(-0.8 * 0.1)))) < 1e-9, "eases back with the slower response")
		expect(M._zoomStep(1, 200, 5, layout) == M._zoomStep(1, 200, 0.25, layout), "dt is clamped to 0.25 s")
	end)

	return results
end
