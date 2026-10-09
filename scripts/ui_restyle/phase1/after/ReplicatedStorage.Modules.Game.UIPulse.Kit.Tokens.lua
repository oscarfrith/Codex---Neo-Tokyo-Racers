-- Owns the Pulse design tokens (colour, opacity, space, type, scale, asset ids, icon cells) and their one config read; owns no instance, layout or text measurement.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens. Requires: none.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tokens = {}

local rgb = Color3.fromRGB

Tokens.Colour = {
	Slate = rgb(14, 13, 26),
	White = rgb(243, 240, 255),
	Ink = rgb(7, 6, 13),
	Pink = rgb(255, 45, 149),
	Violet = rgb(154, 61, 255),
	Cyan = rgb(34, 228, 255),
	Yellow = rgb(255, 228, 51),
	TextSecondary = rgb(217, 211, 245),
	TextMuted = rgb(185, 179, 214),
	Danger = rgb(196, 57, 75),
	ScrimTop = rgb(8, 6, 24),
	ScrimBottom = rgb(34, 14, 72),
	Black = rgb(0, 0, 0),
}

-- Tier colour appears only on TierBadge; it never marks state.
Tokens.Tier = {
	E = rgb(132, 142, 145),
	D = rgb(105, 190, 129),
	C = rgb(74, 204, 211),
	B = rgb(82, 137, 235),
	A = rgb(244, 188, 65),
	S = rgb(236, 92, 168),
}

-- Opacity, not transparency: BackgroundTransparency = 1 - value.
Tokens.Opacity = {
	Panel = 0.86,
	HairTop = 0.85,
	HairBottom = 0.22,
	Disabled = 0.40,
	Locked = 0.60,
	TabLocked = 0.45,
	ChipNeutral = 0.16,
	SegmentEmpty = 0.20,
	RankTrack = 0.30,
	GlowTile = 0.55,
	GlowButton = 0.60,
	GlowRing = 0.45,
	ScrimTop = 0.94,
	ScrimBottom = 0.85,
	ConfirmScrim = 0.66,
}

-- Design px at 1080 unless marked. TopBarGap is real px and is never scaled. The last six are dp at 844x390.
Tokens.Space = {
	Hairline = 2,
	Pad = 22,
	Gap = 10,
	TabGap = 34,
	TabUnderline = 4,
	MenuMargin = 68,
	MenuBottom = 30,
	HudMargin = 40,
	HudBottom = 28,
	TopRightTop = 40,
	TopBarGap = 12,
	ToastTopGap = 10,
	ButtonHeight = 64,
	ButtonHeightLarge = 88,
	ButtonMainMinWidth = 250,
	ButtonPadX = 22,
	IconButton = 64,
	TileWidth = 315,
	TileHeight = 242,
	TileBaseLine = 6,
	TileSelectedGrow = 1.10,
	ListWidth = 480,
	StatPanelWidth = 480,
	ListRowHeight = 96,
	BadgeLarge = 46,
	BadgeMedium = 38,
	BadgeSmall = 34,
	GlowTileRadius = 46,
	GlowButtonRadius = 42,
	GlowRingRadius = 10,
	ConfirmWidth = 650,
	ToastMaxWidth = 820,
	ToastMaxCards = 3,
	ToastGap = 6,
	TouchMin = 48,
	TouchGap = 8,
	CompactButtonDrawn = 36,
	CompactTileMinWidth = 88,
	CompactMargin = 12,
	CompactToastMaxWidth = 280,
}

-- Cap heights per text role: px at 1080 for Regular, dp at 844x390 for Compact.
Tokens.Cap = {
	Regular = {
		ScreenTitle = 56,
		SectionHead = 38,
		ButtonMain = 31,
		Button = 27,
		MenuButtonMain = 24,
		MenuButton = 20,
		TileName = 27,
		TileNameSmall = 21,
		Status = 24,
		Tab = 20,
		Value = 18,
		Label = 15,
		Body = 15,
	},
	Compact = {
		ScreenTitle = 15.4,
		SectionHead = 12.6,
		ButtonMain = 11.6,
		Button = 10.5,
		MenuButtonMain = 11.6,
		MenuButton = 10.5,
		TileName = 10.5,
		TileNameSmall = 9.7,
		Status = 10.5,
		Tab = 10.5,
		Value = 10.5,
		Label = 9.7,
		Body = 9.7,
	},
}

Tokens.Type = {
	Family = "rbxassetid://12187372847",
	FallbackFamily = "rbxasset://fonts/families/RobotoCondensed.json",
	CapRatio = 0.583,
	FallbackCapRatio = 0.607,
	BaselineShift = 0.04,
	ItalicPad = 0.2,
	MinTextSize = 14,
	MaxTextSize = 100,
	ReadyTimeout = 2,
}

-- RegularMin must be exactly 16/24 or the snap drops 1280x720 to 15/24.
Tokens.Scale = {
	RegularRefHeight = 1080,
	RegularRefWidth = 1600,
	RegularMin = 16 / 24,
	RegularMax = 2.0,
	RegularSteps = 24,
	CompactRefHeight = 390,
	CompactMin = 0.85,
	CompactMax = 1.10,
	CompactSteps = 20,
	CompactEnterHeight = 600,
	CompactEnterWidth = 1000,
	CompactLeaveHeight = 640,
	NarrowBelow = 1600,
	WideAbove = 2300,
	HudMaxAspect = 21 / 9,
	MenuMaxAspect = 2.0,
	ResizeSettle = 0.25,
}

-- "" until uploaded. Attribute names on Config.UI.Pulse.Assets equal these keys.
Tokens.Assets = {
	IconSheet = "",
	MapIconSheet = "",
	GlowSoft = "",
	GlowTight = "",
	GlowLine = "",
	Digits256 = "",
	Digits128 = "",
	DigitsPunct = "",
	GaugeRing = "",
	GaugeTicks = "",
	MinimapRing = "",
	MinimapVignette = "",
	MapPlayerArrow = "",
	SegmentStrip = "",
	ChequerCorner = "",
	TitleMark = "",
	KeyCap = "",
	MinimapRankRing = "",
	TouchControls = "",
	TouchControls2 = "",
}

Tokens.Slices = {
	GlowSoft = { Center = Rect.new(62, 62, 66, 66), Inset = 44 },
	GlowTight = { Center = Rect.new(30, 30, 34, 34), Inset = 20 },
	GlowLine = { Center = Rect.new(30, 0, 34, 64), Inset = 20 },
	KeyCap = { Center = Rect.new(20, 20, 44, 44), Inset = 0 },
}

-- {column, row} in cells of Cell px; copied from scripts/ui_restyle/assets/out/icons.json (58 glyphs).
Tokens.Icons = {
	Cell = 128,
	Glyphs = {
		garage = { 0, 0 },
		dealership = { 1, 0 },
		customise = { 2, 0 },
		race_flag = { 3, 0 },
		map = { 4, 0 },
		settings_cog = { 5, 0 },
		controls = { 6, 0 },
		gamepad = { 7, 0 },
		car = { 0, 1 },
		passenger = { 1, 1 },
		players = { 2, 1 },
		taxi = { 3, 1 },
		parcel = { 4, 1 },
		exit = { 5, 1 },
		back = { 6, 1 },
		steering_wheel = { 7, 1 },
		trophy = { 0, 2 },
		medal = { 1, 2 },
		star = { 2, 2 },
		coin = { 3, 2 },
		timer = { 4, 2 },
		loop = { 5, 2 },
		laps = { 6, 2 },
		checkpoints = { 7, 2 },
		pin = { 0, 3 },
		set_route = { 1, 3 },
		route = { 2, 3 },
		north = { 3, 3 },
		boost = { 4, 3 },
		upgrade = { 5, 3 },
		lock = { 6, 3 },
		tick = { 7, 3 },
		chevron_left = { 0, 4 },
		chevron_right = { 1, 4 },
		chevron_up = { 2, 4 },
		chevron_down = { 3, 4 },
		plus = { 4, 4 },
		minus = { 5, 4 },
		close = { 6, 4 },
		title_mark = { 7, 4 },
		warning = { 0, 5 },
		info = { 1, 5 },
		duel = { 2, 5 },
		paint = { 3, 5 },
		keycap_blank = { 4, 5 },
		dpad = { 5, 5 },
		pad_select = { 6, 5 },
		pad_start = { 7, 5 },
		pad_a = { 0, 6 },
		pad_b = { 1, 6 },
		pad_x = { 2, 6 },
		pad_y = { 3, 6 },
		pad_lb = { 4, 6 },
		pad_rb = { 5, 6 },
		pad_lt = { 6, 6 },
		pad_rt = { 7, 6 },
		drift = { 0, 7 },
		gauge = { 1, 7 },
	},
}

-- Groups whose flat name is <group name> .. <key>. Cap is handled apart (Cap<Role>, CompactCap<Role>).
local PREFIXED_GROUPS = { "Colour", "Tier", "Opacity", "Space", "Type", "Scale" }
local FLAT_TYPES = { boolean = true, number = true, string = true, Color3 = true }

local warned = {}
local function warnOnce(message)
	if warned[message] then
		return
	end
	warned[message] = true
	warn("[Pulse.Tokens] " .. message)
end

local function flattenGroup(out, prefix, group)
	if type(group) ~= "table" then
		return
	end
	for key, value in group do
		if type(key) == "string" and FLAT_TYPES[typeof(value)] then
			local name = prefix .. key
			assert(out[name] == nil, "[Pulse.Tokens] flat name collision: " .. name)
			out[name] = value
		end
	end
end

-- Pure. Covers sections 3.1 to 3.5 (the attributes of Config.UI.Pulse); Assets, Slices and Icons are not flat tokens.
function Tokens.Flatten(t: any): { [string]: boolean | number | string | Color3 }
	local out = {}
	if type(t) ~= "table" then
		return out
	end
	for _, prefix in PREFIXED_GROUPS do
		flattenGroup(out, prefix, t[prefix])
	end
	local cap = t.Cap
	if type(cap) == "table" then
		flattenGroup(out, "Cap", cap.Regular)
		flattenGroup(out, "CompactCap", cap.Compact)
	end
	return out
end

function Tokens.Asset(key: string): string?
	local value = Tokens.Assets[key]
	if value == nil then
		warnOnce("unknown asset key " .. tostring(key))
		return nil
	end
	if type(value) ~= "string" or value == "" then
		return nil
	end
	return value
end

local function frozenCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in value do
		copy[key] = frozenCopy(item)
	end
	return table.freeze(copy)
end

Tokens.Defaults = frozenCopy({
	Colour = Tokens.Colour,
	Tier = Tokens.Tier,
	Opacity = Tokens.Opacity,
	Space = Tokens.Space,
	Cap = Tokens.Cap,
	Type = Tokens.Type,
	Scale = Tokens.Scale,
	Assets = Tokens.Assets,
	Slices = Tokens.Slices,
	Icons = Tokens.Icons,
})

local function usable(value, default)
	if typeof(value) ~= typeof(default) then
		return false
	end
	if type(value) == "number" then
		return value == value and value ~= math.huge and value ~= -math.huge
	end
	return true
end

-- Only existing keys are assigned, so the group may be written while it is iterated.
local function applyGroup(folder, prefix, group)
	for key, default in group do
		local name = prefix .. key
		local value = folder:GetAttribute(name)
		if value ~= nil then
			if usable(value, default) then
				group[key] = value
			else
				warnOnce(folder:GetFullName() .. "@" .. name .. ": expected " .. typeof(default) .. ", found " .. typeof(value) .. "; default kept")
			end
		end
	end
end

-- Read once, FindFirstChild only: a missing folder means the code defaults.
local function applyConfig()
	local config = ReplicatedStorage:FindFirstChild("Config")
	local ui = config and config:FindFirstChild("UI")
	local pulse = ui and ui:FindFirstChild("Pulse")
	if not pulse then
		return
	end
	for _, prefix in PREFIXED_GROUPS do
		applyGroup(pulse, prefix, Tokens[prefix])
	end
	applyGroup(pulse, "Cap", Tokens.Cap.Regular)
	applyGroup(pulse, "CompactCap", Tokens.Cap.Compact)
	local assets = pulse:FindFirstChild("Assets")
	if assets then
		applyGroup(assets, "", Tokens.Assets)
	end
end

applyConfig()

return Tokens
