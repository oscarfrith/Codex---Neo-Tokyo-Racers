-- Pure tests for Kit.Sprites (API2 1.2). Reads the generated tables only. No instance, no yield.
return function(M: any, env: any): { { name: string, ok: boolean, detail: string? } }
	local Tokens = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens")

	local results = {}
	local function case(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		table.insert(results, { name = "Sprites: " .. name, ok = ok, detail = (not ok) and tostring(err) or nil })
	end

	local function count(t: any): number
		local n = 0
		for _ in pairs(t) do
			n += 1
		end
		return n
	end

	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 1e-9
	end

	local function isAsset(key: any): boolean
		return type(key) == "string" and Tokens.Defaults.Assets[key] ~= nil
	end

	-- API2 1.2, typed out: the only valid IconName values and the map glyph names.
	local ICONS = {
		"garage", "dealership", "customise", "race_flag", "map", "settings_cog", "controls", "gamepad", "car", "passenger",
		"players", "taxi", "parcel", "exit", "back", "steering_wheel", "trophy", "medal", "star", "coin", "timer", "loop",
		"laps", "checkpoints", "pin", "set_route", "route", "north", "boost", "upgrade", "lock", "tick", "chevron_left",
		"chevron_right", "chevron_up", "chevron_down", "plus", "minus", "close", "title_mark", "warning", "info", "duel",
		"paint", "keycap_blank", "dpad", "pad_select", "pad_start", "pad_a", "pad_b", "pad_x", "pad_y", "pad_lb", "pad_rb",
		"pad_lt", "pad_rt", "drift", "gauge",
	}
	local MAP_ICONS = { "Race", "TimeTrial", "Duel", "Job", "TaxiFare", "CourierPickup", "TaxiDrop", "CourierDrop",
		"Customisation", "Dealership", "Garage", "Waypoint", "Player", "OtherPlayer" }
	local PUNCT = { ":", ".", ",", "$", "%", "+", "-", "/", "x", "K", "M", "MPH", "KM/H", "XP" }

	-- Every glyph is one {column, row} cell inside a sheet of `across` cells, and no two share a cell.
	local function expectSheet(sheet: any, names: { string }, across: number)
		assert(count(sheet.Glyphs) == #names, "glyph count " .. count(sheet.Glyphs))
		local seen = {}
		for _, name in ipairs(names) do
			local cell = sheet.Glyphs[name]
			assert(type(cell) == "table" and #cell == 2, name .. " is missing or not {column, row}")
			local column, row = cell[1], cell[2]
			assert(column % 1 == 0 and row % 1 == 0, name .. " is not on a whole cell")
			assert(column >= 0 and column < across and row >= 0 and row < across, name .. " is outside the sheet")
			local id = row * across + column
			assert(seen[id] == nil, name .. " shares a cell with " .. tostring(seen[id]))
			seen[id] = name
		end
	end

	case("icons: 58 names of API2 1.2 on the 8 x 8 sheet", function()
		assert(#ICONS == 58, "the test lists " .. #ICONS .. " names")
		assert(M.Icons.Asset == "IconSheet" and isAsset(M.Icons.Asset), "asset key")
		assert(M.Icons.Cell == 128, "cell")
		expectSheet(M.Icons, ICONS, 8)
		assert(M.Icons.Glyphs.garage[1] == 0 and M.Icons.Glyphs.garage[2] == 0, "garage")
		assert(M.Icons.Glyphs.lock[1] == 6 and M.Icons.Glyphs.lock[2] == 3, "lock")
		assert(M.Icons.Glyphs.gauge[1] == 1 and M.Icons.Glyphs.gauge[2] == 7, "gauge")
	end)

	case("map icons: 14 names on the 4 x 4 sheet, three pins", function()
		assert(M.MapIcons.Asset == "MapIconSheet" and isAsset(M.MapIcons.Asset), "asset key")
		assert(M.MapIcons.Cell == 128, "cell")
		assert(M.MapIcons.PinTipY == 0.921875, "PinTipY " .. tostring(M.MapIcons.PinTipY))
		expectSheet(M.MapIcons, MAP_ICONS, 4)
		assert(count(M.MapIcons.Pins) == 3, "pin count")
		for _, name in ipairs({ "Waypoint", "TaxiDrop", "CourierDrop" }) do
			assert(M.MapIcons.Pins[name] == true, name .. " is not a pin")
			assert(M.MapIcons.Glyphs[name] ~= nil, name .. " pin has no glyph")
		end
		assert(M.MapIcons.Glyphs.Player[1] == 0 and M.MapIcons.Glyphs.Player[2] == 3, "Player")
	end)

	case("digit sheets: metrics of API2 1.2 and ten cells each", function()
		local want = {
			[256] = { Asset = "Digits256", Cell = { 148, 256 }, Cap = 185, Baseline = 218, Pitch = 130, PitchTight = 117 },
			[128] = { Asset = "Digits128", Cell = { 80, 128 }, Cap = 92, Baseline = 108, Pitch = 65, PitchTight = 58 },
		}
		assert(count(M.Digits) == 2, "sheet count")
		for size, expected in pairs(want) do
			local sheet = M.Digits[size]
			assert(type(sheet) == "table", "sheet " .. size .. " is missing")
			assert(sheet.Asset == expected.Asset and isAsset(sheet.Asset), size .. " asset key")
			assert(sheet.Cell[1] == expected.Cell[1] and sheet.Cell[2] == expected.Cell[2] and sheet.Cell[2] == size, size .. " cell")
			assert(sheet.Cap == expected.Cap and sheet.Baseline == expected.Baseline, size .. " cap or baseline")
			assert(sheet.Pitch == expected.Pitch and sheet.PitchTight == expected.PitchTight, size .. " pitch")
			assert(count(sheet.Glyphs) == 10, size .. " glyph count")
			local widest = 0
			for digit = 0, 9 do
				local glyph = sheet.Glyphs[tostring(digit)]
				assert(type(glyph) == "table" and #glyph == 4, size .. " digit " .. digit .. " is not {x, y, advance, originX}")
				local x, y, advance, originX = glyph[1], glyph[2], glyph[3], glyph[4]
				assert(x % sheet.Cell[1] == 0 and y % sheet.Cell[2] == 0 and x >= 0 and y >= 0, size .. " digit " .. digit .. " is off the cell grid")
				assert(x + sheet.Cell[1] <= 1024, size .. " digit " .. digit .. " leaves the sheet")
				assert(advance > 0 and advance <= sheet.Pitch, size .. " digit " .. digit .. " advance " .. advance)
				assert(originX >= 0 and originX < sheet.Cell[1], size .. " digit " .. digit .. " origin")
				widest = math.max(widest, advance)
			end
			-- Pitch is the widest advance, so fixed cells never clip a digit.
			assert(widest == sheet.Pitch, size .. " widest advance " .. widest)
		end
		assert(M.Digits[256].Glyphs["4"][3] == 130 and M.Digits[256].Glyphs["1"][3] == 75, "256 advances")
		assert(M.Digits[128].Glyphs["9"][1] == 720, "128 nine")
	end)

	case("punctuation: the 14 tokens for each size, inside the sheet", function()
		assert(#PUNCT == 14, "the test lists " .. #PUNCT .. " tokens")
		assert(count(M.Punct) == 2, "size count")
		for _, size in ipairs({ 256, 128 }) do
			local set = M.Punct[size]
			assert(type(set) == "table" and set.Asset == "DigitsPunct" and isAsset(set.Asset), size .. " asset key")
			assert(count(set.Glyphs) == #PUNCT, size .. " token count " .. count(set.Glyphs))
			for _, token in ipairs(PUNCT) do
				local glyph = set.Glyphs[token]
				assert(type(glyph) == "table" and #glyph == 6, size .. " '" .. token .. "' is not {x, y, w, h, advance, originX}")
				local x, y, w, h, advance, originX = glyph[1], glyph[2], glyph[3], glyph[4], glyph[5], glyph[6]
				assert(h == size, size .. " '" .. token .. "' height " .. h)
				assert(x >= 0 and y >= 0 and x + w <= 1024 and y + h <= 1024, size .. " '" .. token .. "' leaves the sheet")
				assert(w > 0 and advance > 0 and advance <= w, size .. " '" .. token .. "' advance")
				assert(originX >= 0 and originX < w, size .. " '" .. token .. "' origin")
			end
		end
		local mph = M.Punct[128].Glyphs["MPH"]
		assert(mph[1] == 758 and mph[2] == 768 and mph[3] == 212 and mph[5] == 194, "128 MPH")
		assert(M.Punct[256].Glyphs["KM/H"][5] == 510 and M.Punct[256].Glyphs[":"][5] == 76, "256 advances")
	end)

	case("rings: sizes, angles and frame scales of API2 1.2", function()
		local rings = M.Rings
		assert(rings.Size == 512, "size")
		assert(rings.Gauge.StartDeg == 135 and rings.Gauge.SweepDeg == 270, "gauge sweep")
		assert(rings.Gauge.ArcRadius == 210 and rings.Gauge.BoostRadius == 184, "gauge radii")
		assert(near(rings.Gauge.TipFraction, 0.09), "tip fraction")
		assert(rings.Gauge.ArcRadius * 2 < rings.Size and rings.Gauge.BoostRadius < rings.Gauge.ArcRadius, "radii inside the image")
		assert(near(rings.Minimap.FrameScale, 512 / 480), "minimap frame scale")
		assert(near(rings.Rank.FrameScale, 1.099 * 512 / 480), "rank frame scale")
		assert(rings.Rank.StartDeg == 180 and rings.Rank.SweepRegular == 90, "rank regular sweep")
		assert(rings.Rank.CompactFromDeg == 165 and rings.Rank.CompactToDeg == 285, "rank compact sweep")
		assert(rings.TitleSlash.Size[1] == 160 and rings.TitleSlash.Size[2] == 192, "title slash size")
		assert(near(rings.TitleSlash.Design[1], 53.3) and rings.TitleSlash.Design[2] == 64, "title slash design box")
	end)

	case("touch: five controls, asset keys and dp sizes", function()
		local controls = { "Accelerate", "Brake", "Turn", "Drift", "Boost" }
		assert(count(M.Touch) == #controls, "control count")
		local seen = {}
		for _, name in ipairs(controls) do
			local control = M.Touch[name]
			assert(type(control) == "table", name .. " is missing")
			assert(control.Idle == "Touch" .. name and control.Pressed == "Touch" .. name .. "Pressed", name .. " asset keys")
			assert(isAsset(control.Idle) and isAsset(control.Pressed), name .. " keys are not Tokens asset keys")
			assert(seen[control.Idle] == nil and seen[control.Pressed] == nil, name .. " shares a key")
			seen[control.Idle] = true
			seen[control.Pressed] = true
			for _, field in ipairs({ "PlateDp", "FrameDp", "HitDp" }) do
				local size = control[field]
				assert(type(size) == "table" and #size == 2 and size[1] > 0 and size[2] > 0, name .. "." .. field)
			end
			-- The image frame carries glow room, so it is never smaller than the plate.
			assert(control.FrameDp[1] >= control.PlateDp[1] and control.FrameDp[2] >= control.PlateDp[2], name .. " frame is smaller than its plate")
		end
		local accelerate = M.Touch.Accelerate
		assert(accelerate.PlateDp[1] == 72 and accelerate.PlateDp[2] == 100, "Accelerate plate")
		assert(accelerate.FrameDp[1] == 110 and accelerate.FrameDp[2] == 110, "Accelerate frame")
		assert(accelerate.HitDp[1] == 96 and accelerate.HitDp[2] == 112, "Accelerate hit box")
		assert(M.Touch.Boost.PlateDp[1] == 48 and M.Touch.Boost.FrameDp[1] == 58 and M.Touch.Boost.HitDp[1] == 52, "Boost")
	end)

	case("source names the generator and fingerprints every input", function()
		assert(type(M.Source.Generator) == "string" and string.find(M.Source.Generator, "gen_sprites%.py$") ~= nil, "Generator")
		for _, file in ipairs({ "icons.json", "map_icons.json", "digits.json", "rings.json", "touch.json", "static_geometry.json",
			"uploaded_assets.json" }) do
			local fingerprint = M.Source.Inputs[file]
			assert(type(fingerprint) == "string" and string.match(fingerprint, "^sha256:%x+$") ~= nil, file .. " fingerprint")
		end
	end)

	case("data only: frozen, and no asset id or datatype inside", function()
		assert(table.isfrozen(M) and table.isfrozen(M.Icons) and table.isfrozen(M.Icons.Glyphs.garage), "not frozen")
		assert(table.isfrozen(M.Digits[256].Glyphs["0"]) and table.isfrozen(M.Touch.Boost.HitDp), "nested tables not frozen")
		local function walk(value: any, path: string)
			local kind = typeof(value)
			if kind == "table" then
				for key, item in pairs(value) do
					walk(item, path .. "." .. tostring(key))
				end
			elseif kind == "string" then
				assert(string.find(value, "rbxassetid", 1, true) == nil, path .. " holds an asset id")
			else
				assert(kind == "number" or kind == "boolean", path .. " is a " .. kind)
			end
		end
		walk(M, "Sprites")
	end)

	return results
end
