-- Pure tests for Kit.Tokens (API.md 3 and 13; API2 1.1 and 2.2). No instance, no yield.
return function(M: any, env: any): { { name: string, ok: boolean, detail: string? } }
	local results = {}
	local function case(name, body)
		local ok, detail = pcall(body)
		if ok then
			table.insert(results, { name = "Tokens: " .. name, ok = true })
		else
			table.insert(results, { name = "Tokens: " .. name, ok = false, detail = tostring(detail) })
		end
	end

	local Sprites = env.Load("ReplicatedStorage.Modules.Game.UIPulse.Kit.Sprites")

	-- Section 3.1 to 3.5, typed out from API.md, then the API2 2.2 additions. Colours are {r, g, b}.
	local expected = {
		ColourSlate = { 14, 13, 26 }, ColourWhite = { 243, 240, 255 }, ColourInk = { 7, 6, 13 },
		ColourPink = { 255, 45, 149 }, ColourViolet = { 154, 61, 255 }, ColourCyan = { 34, 228, 255 },
		ColourYellow = { 255, 228, 51 }, ColourTextSecondary = { 217, 211, 245 },
		ColourTextMuted = { 185, 179, 214 }, ColourDanger = { 196, 57, 75 }, ColourScrimTop = { 8, 6, 24 },
		ColourScrimBottom = { 34, 14, 72 }, ColourBlack = { 0, 0, 0 },
		TierE = { 132, 142, 145 }, TierD = { 105, 190, 129 }, TierC = { 74, 204, 211 },
		TierB = { 82, 137, 235 }, TierA = { 244, 188, 65 }, TierS = { 236, 92, 168 },

		OpacityPanel = 0.86, OpacityHairTop = 0.85, OpacityHairBottom = 0.22, OpacityDisabled = 0.40,
		OpacityLocked = 0.60, OpacityTabLocked = 0.45, OpacityChipNeutral = 0.16, OpacitySegmentEmpty = 0.20,
		OpacityRankTrack = 0.30, OpacityGlowTile = 0.55, OpacityGlowButton = 0.60, OpacityGlowRing = 0.45,
		OpacityScrimTop = 0.94, OpacityScrimBottom = 0.85, OpacityConfirmScrim = 0.66,

		SpaceHairline = 2, SpacePad = 22, SpaceGap = 10, SpaceTabGap = 34, SpaceTabUnderline = 4,
		SpaceMenuMargin = 68, SpaceMenuBottom = 30, SpaceHudMargin = 40, SpaceHudBottom = 28,
		SpaceTopRightTop = 40, SpaceTopBarGap = 12, SpaceToastTopGap = 10,
		SpaceButtonHeight = 64, SpaceButtonHeightLarge = 88, SpaceButtonMainMinWidth = 250,
		SpaceButtonPadX = 22, SpaceIconButton = 64,
		SpaceTileWidth = 315, SpaceTileHeight = 242, SpaceTileBaseLine = 6, SpaceTileSelectedGrow = 1.10,
		SpaceListWidth = 480, SpaceStatPanelWidth = 480, SpaceListRowHeight = 96,
		SpaceBadgeLarge = 46, SpaceBadgeMedium = 38, SpaceBadgeSmall = 34,
		SpaceGlowTileRadius = 46, SpaceGlowButtonRadius = 42, SpaceGlowRingRadius = 10,
		SpaceConfirmWidth = 650, SpaceToastMaxWidth = 820, SpaceToastMaxCards = 3, SpaceToastGap = 6,
		SpaceTouchMin = 48, SpaceTouchGap = 8, SpaceCompactButtonDrawn = 36, SpaceCompactTileMinWidth = 88,
		SpaceCompactMargin = 12, SpaceCompactToastMaxWidth = 280,

		TypeFamily = "rbxassetid://12187372847",
		TypeFallbackFamily = "rbxasset://fonts/families/RobotoCondensed.json",
		TypeCapRatio = 0.583, TypeFallbackCapRatio = 0.607, TypeBaselineShift = 0.04, TypeItalicPad = 0.2,
		TypeMinTextSize = 14, TypeMaxTextSize = 100, TypeReadyTimeout = 2,

		CapScreenTitle = 56, CapSectionHead = 38, CapButtonMain = 31, CapButton = 27, CapMenuButtonMain = 24,
		CapMenuButton = 20, CapTileName = 27, CapTileNameSmall = 21, CapStatus = 24, CapTab = 20,
		CapValue = 18, CapLabel = 15, CapBody = 15,
		CompactCapScreenTitle = 15.4, CompactCapSectionHead = 12.6, CompactCapButtonMain = 11.6,
		CompactCapButton = 10.5, CompactCapMenuButtonMain = 11.6, CompactCapMenuButton = 10.5,
		CompactCapTileName = 10.5, CompactCapTileNameSmall = 9.7, CompactCapStatus = 10.5,
		CompactCapTab = 10.5, CompactCapValue = 10.5, CompactCapLabel = 9.7, CompactCapBody = 9.7,

		ScaleRegularRefHeight = 1080, ScaleRegularRefWidth = 1600, ScaleRegularMin = 16 / 24,
		ScaleRegularMax = 2.0, ScaleRegularSteps = 24,
		ScaleCompactRefHeight = 390, ScaleCompactMin = 0.85, ScaleCompactMax = 1.10, ScaleCompactSteps = 20,
		ScaleCompactEnterHeight = 600, ScaleCompactEnterWidth = 1000, ScaleCompactLeaveHeight = 640,
		ScaleNarrowBelow = 1600, ScaleWideAbove = 2300, ScaleHudMaxAspect = 21 / 9, ScaleMenuMaxAspect = 2.0,
		ScaleResizeSettle = 0.25,

		-- API2 2.2.
		NumberCapSpeed = 95, NumberCapHero = 140, NumberCapPosition = 150, NumberCapTimer = 62,
		NumberCapCountdown = 260, NumberCapRank = 22, NumberCapSmall = 31,
		CompactNumberCapSpeed = 24, CompactNumberCapHero = 31, CompactNumberCapPosition = 28,
		CompactNumberCapTimer = 17, CompactNumberCapCountdown = 67, CompactNumberCapRank = 10,
		CompactNumberCapSmall = 12,

		SpaceMenuTopRightTop = 67, SpaceRightColumnTop = 152, SpaceHudRightColumnTop = 186, SpaceRailButtonsLift = 30,
		SpaceStatusHeight = 54, SpaceStatusPad = 6, SpaceActionTileWidth = 77, SpaceActionTileHeight = 60,
		SpaceActionGap = 8, SpaceHudButtonHeight = 56, SpaceGaugeSize = 403, SpaceGaugeTouchSize = 240,
		SpaceMinimapSize = 307, SpaceMinimapInset = 18, SpaceMinimapLabelBand = 52, SpaceRankArcWidth = 10,
		SpaceRankArcGap = 8, SpaceSidePanelWidth = 600, SpaceStatRowHeight = 48, SpaceStatPanelHeight = 448,
		SpaceSegmentWidth = 10, SpaceSegmentGap = 3, SpaceSegmentHeight = 10, SpaceFactRowHeight = 58,
		SpacePromptWidth = 590, SpacePromptHeight = 84, SpacePromptLift = 330, SpaceKeyCapSize = 40,
		SpaceTitleMarkWidth = 34, SpaceTitleMarkHeight = 60, SpaceHeaderTabsGap = 14, SpaceModalMaxWidth = 900,
		SpaceSwitchGap = 30, SpaceStepperWidth = 220, SpaceSliderHeight = 40, SpaceDropdownRowHeight = 56,
		SpaceTextShadowOffset = 2,
		SpaceCompactBottom = 8, SpaceCompactTop = 8, SpaceCompactRightColumnTop = 45,
		SpaceCompactRailButtonsLift = 14, SpaceCompactTileHeight = 60, SpaceCompactStatPanelWidth = 176,
		SpaceCompactGauge = 92, SpaceCompactMinimap = 92, SpaceCompactActionTile = 32,
		SpaceCompactSidePanelWidth = 232, SpaceCompactHudButton = 36, SpaceCompactPromptLift = 112,
		SpaceCompactPromptWidth = 300, SpaceCompactStatusHeight = 26, SpaceCompactKeepOutGap = 8,

		OpacityTextShadow = 0.60, OpacityTouchDisabled = 0.40, OpacityButtonPlate = 0.86,
		OpacityHairButtonTop = 0.85, OpacityHairButtonBottom = 0.22, OpacityVignette = 0.90,
		OpacityRankTrackImage = 0.25,

		ScaleRegularDp = 1.25,
	}

	-- API2 1.1: exactly these 31 keys, each defaulting to its uploaded id.
	local assetKeys = {
		"IconSheet", "MapIconSheet", "GlowSoft", "GlowTight", "GlowLine", "Digits256", "Digits128", "DigitsPunct",
		"GaugeTrack", "GaugeTicks", "GaugeGlow", "GaugeArc", "BoostArc", "MinimapRing", "MinimapVignette",
		"MapPlayerArrow", "RankArc", "SegmentStrip", "TitleSlash", "ChequerCorner", "KeyCap",
		"TouchAccelerate", "TouchAcceleratePressed", "TouchBrake", "TouchBrakePressed", "TouchTurn",
		"TouchTurnPressed", "TouchDrift", "TouchDriftPressed", "TouchBoost", "TouchBoostPressed",
	}
	local retiredAssetKeys = { "GaugeRing", "MinimapRankRing", "TouchControls", "TouchControls2", "TitleMark" }

	local function count(t)
		local n = 0
		for _ in t do
			n += 1
		end
		return n
	end

	local function same(want, got)
		if type(want) == "table" then
			if typeof(got) ~= "Color3" then
				return false
			end
			return math.round(got.R * 255) == want[1] and math.round(got.G * 255) == want[2]
				and math.round(got.B * 255) == want[3]
		elseif type(want) == "number" then
			return type(got) == "number" and math.abs(got - want) < 1e-9
		end
		return got == want
	end

	-- Longest prefix first is not needed: no prefix is the start of another.
	local prefixes = {
		{ "CompactNumberCap", function(t) return t.NumberCap.Compact end },
		{ "NumberCap", function(t) return t.NumberCap.Regular end },
		{ "CompactCap", function(t) return t.Cap.Compact end },
		{ "Colour", function(t) return t.Colour end },
		{ "Opacity", function(t) return t.Opacity end },
		{ "Space", function(t) return t.Space end },
		{ "Scale", function(t) return t.Scale end },
		{ "Type", function(t) return t.Type end },
		{ "Tier", function(t) return t.Tier end },
		{ "Cap", function(t) return t.Cap.Regular end },
	}
	local function resolve(t, flatName)
		for _, entry in prefixes do
			local prefix = entry[1]
			if string.sub(flatName, 1, #prefix) == prefix then
				return entry[2](t)[string.sub(flatName, #prefix + 1)]
			end
		end
		return nil
	end

	case("every value of section 3 and of API2 2.2 equals Defaults", function()
		local flat = M.Flatten(M.Defaults)
		for name, want in expected do
			assert(flat[name] ~= nil, "missing flat token " .. name)
			assert(same(want, flat[name]), name .. " is " .. tostring(flat[name]))
		end
		for name in flat do
			assert(expected[name] ~= nil, "flat token not in API.md 3 or API2 2.2: " .. name)
		end
	end)

	case("Flatten round trip", function()
		local flat = M.Flatten(M.Defaults)
		for name, value in flat do
			assert(resolve(M.Defaults, name) == value, "Defaults does not resolve " .. name)
			local live = resolve(M, name)
			assert(typeof(live) == typeof(value), "live type differs for " .. name)
		end
		local again = M.Flatten(M.Defaults)
		assert(count(again) == count(flat), "second Flatten differs in size")
		for name, value in flat do
			assert(again[name] == value, "second Flatten differs at " .. name)
		end
	end)

	case("no flat-name collision", function()
		local d = M.Defaults
		local total = count(d.Colour) + count(d.Tier) + count(d.Opacity) + count(d.Space) + count(d.Type)
			+ count(d.Scale) + count(d.Cap.Regular) + count(d.Cap.Compact)
			+ count(d.NumberCap.Regular) + count(d.NumberCap.Compact)
		local flat = M.Flatten(d)
		assert(count(flat) == total, "flat " .. count(flat) .. " against grouped " .. total)
		assert(count(flat) == count(expected), "flat " .. count(flat) .. " against API " .. count(expected))
		for _, key in assetKeys do
			assert(flat[key] == nil, "asset key shadows a flat token: " .. key)
		end
	end)

	case("Flatten accepts the live table and junk", function()
		assert(count(M.Flatten(M)) == count(expected), "live Flatten size")
		assert(count(M.Flatten(nil)) == 0, "nil")
		assert(count(M.Flatten({})) == 0, "empty")
		assert(count(M.Flatten({ Colour = 1, Cap = {} })) == 0, "malformed groups")
	end)

	case("Defaults is frozen, deep", function()
		assert(table.isfrozen(M.Defaults), "Defaults")
		assert(table.isfrozen(M.Defaults.Colour), "Colour")
		assert(table.isfrozen(M.Defaults.Cap.Compact), "Cap.Compact")
		assert(table.isfrozen(M.Defaults.NumberCap.Regular), "NumberCap.Regular")
		assert(table.isfrozen(M.Defaults.Icons.Glyphs.garage), "glyph")
		assert(M.Defaults.Colour ~= M.Colour, "Defaults.Colour must be a copy")
	end)

	case("assets: the 31 uploaded keys default to their ids, retired keys are gone, Asset is nil for empty", function()
		assert(count(M.Defaults.Assets) == #assetKeys, "asset key count " .. count(M.Defaults.Assets))
		assert(#assetKeys == 31, "the test lists " .. #assetKeys .. " keys")
		local seen = {}
		for _, key in assetKeys do
			local id = M.Defaults.Assets[key]
			assert(type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil, key .. " default is not an uploaded id")
			assert(seen[id] == nil, key .. " shares an id with " .. tostring(seen[id]))
			seen[id] = key
			assert(type(M.Assets[key]) == "string", key .. " live is not a string")
		end
		for _, key in retiredAssetKeys do
			assert(M.Defaults.Assets[key] == nil and M.Assets[key] == nil, key .. " is still an asset key")
		end
		assert(M.Defaults.Assets.IconSheet == "rbxassetid://75923195736638", "IconSheet id")
		assert(M.Defaults.Assets.TitleSlash == "rbxassetid://72834960725330", "TitleSlash id")
		assert(M.Defaults.Assets.TouchBoostPressed == "rbxassetid://113577162843584", "TouchBoostPressed id")
		local before = M.Assets.GlowSoft
		M.Assets.GlowSoft = ""
		local empty = M.Asset("GlowSoft")
		M.Assets.GlowSoft = "rbxassetid://1"
		local set = M.Asset("GlowSoft")
		M.Assets.GlowSoft = before
		assert(empty == nil, 'Asset("") must be nil')
		assert(set == "rbxassetid://1", "Asset must return a set id")
	end)

	case("every asset key Sprites names is a Tokens asset key", function()
		local named = { Sprites.Icons.Asset, Sprites.MapIcons.Asset, Sprites.Digits[256].Asset, Sprites.Digits[128].Asset,
			Sprites.Punct[256].Asset, Sprites.Punct[128].Asset }
		for _, control in Sprites.Touch do
			table.insert(named, control.Idle)
			table.insert(named, control.Pressed)
		end
		assert(#named == 16, "expected 16 named keys, got " .. #named)
		for _, key in named do
			assert(M.Defaults.Assets[key] ~= nil, tostring(key) .. " is not an asset key")
		end
	end)

	case("number caps and the wave-2 groups are live tables", function()
		assert(M.NumberCap.Regular.Countdown == 260 and M.NumberCap.Compact.Countdown == 67, "Countdown")
		assert(count(M.NumberCap.Regular) == 7 and count(M.NumberCap.Compact) == 7, "seven roles each")
		for role in M.NumberCap.Regular do
			assert(M.NumberCap.Compact[role] ~= nil, role .. " has no Compact cap")
		end
		assert(M.Space.CompactTop == 8 and M.Space.GaugeSize == 403, "Space")
		assert(M.Opacity.RankTrackImage == 0.25 and M.Scale.RegularDp == 1.25, "Opacity and Scale")
		assert(M.Tier.S ~= nil and count(M.Tier) == 6, "Tier unchanged")
	end)

	case("slices", function()
		local want = {
			GlowSoft = { Rect.new(62, 62, 66, 66), 44 },
			GlowTight = { Rect.new(30, 30, 34, 34), 20 },
			GlowLine = { Rect.new(30, 0, 34, 64), 20 },
			KeyCap = { Rect.new(20, 20, 44, 44), 0 },
		}
		assert(count(M.Slices) == 4, "slice count")
		for key, item in want do
			local slice = M.Slices[key]
			assert(slice ~= nil, "missing slice " .. key)
			assert(slice.Center == item[1], key .. " centre")
			assert(slice.Inset == item[2], key .. " inset")
			assert(M.Defaults.Assets[key] ~= nil, key .. " has no asset key")
		end
	end)

	case("icons: 58 glyphs, one cell each, inside the 8 x 8 sheet, built from Sprites", function()
		assert(M.Icons.Cell == 128, "cell")
		assert(M.Icons.Cell == Sprites.Icons.Cell and M.Icons.Glyphs == Sprites.Icons.Glyphs, "Icons is not Sprites.Icons")
		local seen = {}
		local n = 0
		for name, cell in M.Icons.Glyphs do
			n += 1
			assert(type(name) == "string" and #cell == 2, "glyph shape " .. tostring(name))
			local column, row = cell[1], cell[2]
			assert(column >= 0 and column <= 7 and row >= 0 and row <= 7, name .. " outside the sheet")
			local id = row * 8 + column
			assert(not seen[id], name .. " shares a cell with " .. tostring(seen[id]))
			seen[id] = name
		end
		assert(n == 58, "glyph count " .. n)
		assert(M.Icons.Glyphs.garage[1] == 0 and M.Icons.Glyphs.garage[2] == 0, "garage")
		assert(M.Icons.Glyphs.lock[1] == 6 and M.Icons.Glyphs.lock[2] == 3, "lock")
		assert(M.Icons.Glyphs.gauge[1] == 1 and M.Icons.Glyphs.gauge[2] == 7, "gauge")
	end)

	return results
end
