-- Owns the Pulse design tokens (colour, opacity, space, type, scale, asset ids, icon cells) and their one config read; owns no instance, layout or text measurement.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Tokens. Requires: Sprites.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sprites = require(script.Parent.Sprites)

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

-- Tier colour appears only on TierBadge and tier buttons (Controls.Tabs Tier items); it never marks state.
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
	-- Wave 2 (API2 2.2).
	TextShadow = 0.60,
	TouchDisabled = 0.40,
	ButtonPlate = 0.86,
	HairButtonTop = 0.85,
	HairButtonBottom = 0.22,
	Vignette = 0.90,
	RankTrackImage = 0.25,
}

-- Design px at 1080 unless marked. TopBarGap is real px and is never scaled. TouchMin to CompactToastMaxWidth and
-- every later Compact* key are dp at 844x390.
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
	-- Wave 2 (API2 2.2), design px.
	MenuTopRightTop = 67,
	RightColumnTop = 152,
	HudRightColumnTop = 186,
	RailButtonsLift = 30,
	StatusHeight = 54,
	StatusPad = 6,
	ActionTileWidth = 77,
	ActionTileHeight = 60,
	ActionGap = 8,
	HudButtonHeight = 56,
	GaugeSize = 403,
	GaugeTouchSize = 240,
	MinimapSize = 307,
	MinimapInset = 18,
	MinimapLabelBand = 52,
	RankArcWidth = 10,
	RankArcGap = 8,
	SidePanelWidth = 600,
	StatRowHeight = 48,
	StatPanelHeight = 448,
	SegmentWidth = 10,
	SegmentGap = 3,
	SegmentHeight = 10,
	FactRowHeight = 58,
	PromptWidth = 590,
	PromptHeight = 84,
	PromptLift = 330,
	KeyCapSize = 40,
	TitleMarkWidth = 34,
	TitleMarkHeight = 60,
	HeaderTabsGap = 14,
	ModalMaxWidth = 900,
	SwitchGap = 30,
	StepperWidth = 220,
	SliderHeight = 40,
	DropdownRowHeight = 56,
	TextShadowOffset = 2,
	-- Wave 2, dp.
	CompactBottom = 8,
	CompactTop = 8,
	CompactRightColumnTop = 45,
	CompactRailButtonsLift = 14,
	CompactTileHeight = 60,
	CompactStatPanelWidth = 176,
	CompactGauge = 92,
	CompactMinimap = 92,
	CompactActionTile = 32,
	CompactSidePanelWidth = 232,
	CompactHudButton = 36,
	CompactPromptLift = 112,
	CompactPromptWidth = 300,
	CompactStatusHeight = 26,
	CompactKeepOutGap = 8,
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

-- Cap heights of Kit.BigNumber roles: px at 1080 for Regular, dp at 844x390 for Compact.
Tokens.NumberCap = {
	Regular = {
		Speed = 95,
		Hero = 140,
		Position = 150,
		Timer = 62,
		Countdown = 260,
		Rank = 22,
		Small = 31,
	},
	Compact = {
		Speed = 24,
		Hero = 31,
		Position = 28,
		Timer = 17,
		Countdown = 67,
		Rank = 10,
		Small = 12,
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
	-- Regular px per dp for ctx.Dp, so touch controls keep a physical size on tablets.
	RegularDp = 1.25,
}

-- Code defaults are the uploaded ids, so the game shows images with empty or missing attributes. Attribute names on
-- Config.UI.Pulse.Assets equal these keys; an attribute set to "" gives the flat state (Tokens.Asset returns nil).
-- BEGIN GENERATED ASSETS (gen_sprites.py, from scripts/ui_restyle/assets/uploaded_assets.json; never edit by hand)
Tokens.Assets = {
	IconSheet = "rbxassetid://75923195736638",
	MapIconSheet = "rbxassetid://80578954881108",
	GlowSoft = "rbxassetid://135935339855364",
	GlowTight = "rbxassetid://117888228227601",
	GlowLine = "rbxassetid://97131611895302",
	Digits256 = "rbxassetid://117641527848974",
	Digits128 = "rbxassetid://89916985549941",
	DigitsPunct = "rbxassetid://114689344233116",
	GaugeTrack = "rbxassetid://119781443712293",
	GaugeTicks = "rbxassetid://120114645008415",
	GaugeGlow = "rbxassetid://129960207022537",
	GaugeArc = "rbxassetid://134100466725449",
	BoostArc = "rbxassetid://85006661533728",
	MinimapRing = "rbxassetid://95228721424881",
	MinimapVignette = "rbxassetid://125852027354743",
	MapPlayerArrow = "rbxassetid://75887661537180",
	RankArc = "rbxassetid://92721778595093",
	SegmentStrip = "rbxassetid://137798736993531",
	TitleSlash = "rbxassetid://72834960725330",
	ChequerCorner = "rbxassetid://126153133988621",
	KeyCap = "rbxassetid://133811090176849",
	TouchAccelerate = "rbxassetid://115016705420726",
	TouchAcceleratePressed = "rbxassetid://107490452051578",
	TouchBrake = "rbxassetid://89939196452811",
	TouchBrakePressed = "rbxassetid://131499606862418",
	TouchTurn = "rbxassetid://138576169890684",
	TouchTurnPressed = "rbxassetid://110129011146232",
	TouchDrift = "rbxassetid://104833602550371",
	TouchDriftPressed = "rbxassetid://95736832686150",
	TouchBoost = "rbxassetid://101855778919480",
	TouchBoostPressed = "rbxassetid://113577162843584",
}
-- END GENERATED ASSETS

Tokens.Slices = {
	GlowSoft = { Center = Rect.new(62, 62, 66, 66), Inset = 44 },
	GlowTight = { Center = Rect.new(30, 30, 34, 34), Inset = 20 },
	GlowLine = { Center = Rect.new(30, 0, 34, 64), Inset = 20 },
	KeyCap = { Center = Rect.new(20, 20, 44, 44), Inset = 0 },
}

-- {column, row} in cells of Cell px. Kept for Phase 1 callers; it is Sprites.Icons, which new code reads.
Tokens.Icons = {
	Cell = Sprites.Icons.Cell,
	Glyphs = Sprites.Icons.Glyphs,
}

-- Groups whose flat name is <group name> .. <key>. Cap and NumberCap are handled apart (Cap<Role>, CompactCap<Role>,
-- NumberCap<Role>, CompactNumberCap<Role>).
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

-- Pure. Covers API 3.1 to 3.5 and the API2 2.2 groups (the attributes of Config.UI.Pulse); Assets, Slices and Icons
-- are not flat tokens.
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
	local numberCap = t.NumberCap
	if type(numberCap) == "table" then
		flattenGroup(out, "NumberCap", numberCap.Regular)
		flattenGroup(out, "CompactNumberCap", numberCap.Compact)
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
	NumberCap = Tokens.NumberCap,
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
	applyGroup(pulse, "NumberCap", Tokens.NumberCap.Regular)
	applyGroup(pulse, "CompactNumberCap", Tokens.NumberCap.Compact)
	local assets = pulse:FindFirstChild("Assets")
	if assets then
		applyGroup(assets, "", Tokens.Assets)
	end
end

applyConfig()

return Tokens
