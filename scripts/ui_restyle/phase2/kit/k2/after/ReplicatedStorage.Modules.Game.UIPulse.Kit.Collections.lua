-- Owns the Pulse Tile, Rail and List (with their keyed pools), ListRow, Chip, TierBadge and the generic Pool; it does not own selection rules of a screen, money formatting, focus rules or any screen's layout.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Collections. Requires: Tokens, Metrics, Text, Surface, Input.
local Tokens = require(script.Parent.Tokens)
local Metrics = require(script.Parent.Metrics)
local Text = require(script.Parent.Text)
local Surface = require(script.Parent.Surface)
local Input = require(script.Parent.Input)

local Collections = {}

local Space = Tokens.Space
local Opacity = Tokens.Opacity
local Type = Tokens.Type

-- Design ratios (not pixels). Every length below is a token, or a token times one of these.
local COMPACT_UNIT = Space.TouchGap / Space.Pad -- general 1080 px to Compact dp factor (8 / 22)
local HALF = 0.5
local TILE_INSET = 0.8 -- tile inner margin against the panel padding (18 of 22)
local SEVEN_WIDTH = 0.75 -- a rail-of-seven cell against the standard tile width (236 of 315)
local VISUAL_TOP = 0.22 -- top of the picture box against the tile height (54 of 242)
local VISUAL_HEIGHT = 0.4 -- picture box against the tile height (96 of 242)
local BADGE_LETTER = 0.9 -- tier letter cell width against the badge height (42 of 46)
local TWO_LINES = 1.5 -- text taller than this many lines' worth is laid out as two lines
local GRID_ROWS = 3 -- cell rows a grid rail shows when its parent gives it no height
local LIST_ROWS = 5 -- rows a list shows when its parent gives it no height
local PICTURE_ASPECT = 1.5 -- a vehicle card picture is 3 wide to 2 high (the 1536 by 1024 card renders)
local PICTURE_FOCUS_X = 0.54 -- the car's centre across a card picture (it sits a little right of the middle)
local PICTURE_FOCUS_Y = 0.52 -- and down it (a little below the middle, on the floor)
local SCRIM_START = 0.35 -- how far down a full-frame picture its text scrim starts to darken
local COMPACT_TILE_WIDTH = 1.25 -- a Compact tile against the token minimum width (110 of 88); every tile of a rail is this wide
local QUARTER_TURN = 90 -- UIGradient rotation of a top to bottom gradient

---------------------------------------------------------------------------------------------------
-- Shared helpers (Kit.Controls carries the same block; the two modules may not require each other)
---------------------------------------------------------------------------------------------------

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function colourOf(role)
	local value = Tokens.Colour[role]
	if value == nil then
		error("[Pulse.Collections] unknown colour role " .. tostring(role), 3)
	end
	return value
end

local function tierColour(tier)
	local value = Tokens.Tier[tier]
	if value == nil then
		error("[Pulse.Collections] unknown tier " .. tostring(tier), 3)
	end
	return value
end

local function isCompact(ctx)
	return ctx.Class == "Compact"
end

local function isTouchy(ctx)
	return ctx.Class == "Compact" or ctx.Input == "Touch"
end

local function unit(ctx, design)
	if isCompact(ctx) then
		return design * COMPACT_UNIT
	end
	return design
end

local function textOf(value)
	if type(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

local COMMON_KEYS = { "Name", "LayoutOrder", "Visible" }

local function keySet(list)
	local set = {}
	for _, key in ipairs(COMMON_KEYS) do
		set[key] = true
	end
	for _, key in ipairs(list) do
		set[key] = true
	end
	return set
end

local function readProps(kind, keys, defaults, props)
	local state = {}
	for key, value in pairs(defaults) do
		state[key] = value
	end
	if props ~= nil then
		for key, value in pairs(props) do
			if not keys[key] then
				error(string.format("[Pulse.Collections] %s: unknown key %s", kind, tostring(key)), 3)
			end
			state[key] = value
		end
	end
	return state
end

-- Validates the whole patch before anything is stored. Returns true when a value differs.
local function mergePatch(kind, keys, state, patch)
	if type(patch) ~= "table" then
		error(string.format("[Pulse.Collections] %s.Set expects a table", kind), 3)
	end
	for key in pairs(patch) do
		if not keys[key] then
			error(string.format("[Pulse.Collections] %s: unknown key %s", kind, tostring(key)), 3)
		end
	end
	local changed = false
	for key, value in pairs(patch) do
		if state[key] ~= value then
			state[key] = value
			changed = true
		end
	end
	return changed
end

local function listen(scope, bag, signal, callback)
	local connection = scope:connect(signal, callback)
	table.insert(bag, connection)
	return connection
end

-- A bag holds connections and child components (tables with a Destroy function).
local function release(bag)
	for index = #bag, 1, -1 do
		local item = bag[index]
		bag[index] = nil
		if typeof(item) == "RBXScriptConnection" then
			item:Disconnect()
		elseif type(item) == "table" and type(item.Destroy) == "function" then
			item.Destroy()
		elseif type(item) == "table" and type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

local function applyCommon(root, state)
	put(root, "LayoutOrder", state.LayoutOrder or 0)
	put(root, "Visible", state.Visible ~= false)
end

-- A TextLabel with no background and a size lock (the text does not follow the player's Text Size
-- setting; these all sit in fixed boxes).
local function newText(parent, name)
	local object = Instance.new("TextLabel")
	object.Name = name
	object.BackgroundTransparency = 1
	object.BorderSizePixel = 0
	object.Text = ""
	object.TextWrapped = false
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextYAlignment = Enum.TextYAlignment.Center
	local lock = Instance.new("UITextSizeConstraint")
	lock.Name = "SizeLock"
	lock.MinTextSize = 1
	lock.Parent = object
	object.Parent = parent
	return object
end

local function face(object, role, ctx)
	local textSize = Text.SizeFor(role, ctx)
	put(object, "FontFace", Text.Font(role))
	put(object, "TextSize", textSize)
	put(object.SizeLock, "MaxTextSize", textSize)
	return textSize
end

local function textWidth(object)
	return math.ceil(object.TextBounds.X)
end

local function baselineShift(textSize)
	return math.floor(Type.BaselineShift * textSize + HALF)
end

local function newFrame(parent, name)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function newButton(name)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.Text = ""
	button.TextTransparency = 1
	return button
end

-- True when the parent has a width of its own. A slot anchor (zero size) has none.
local function hasWidth(parent)
	local size = parent.Size
	return size.X.Scale ~= 0 or size.X.Offset ~= 0
end

local function hasHeight(parent)
	local size = parent.Size
	return size.Y.Scale ~= 0 or size.Y.Offset ~= 0
end

-- The glow of a plate. A child always draws over its parent, so the 9-slice cannot sit inside the plate it
-- lights: it goes in a Frame named Glow, a sibling under the plate, which the caller keeps on the plate's box.
local function newGlow(root, scope, bag, kind)
	local box = newFrame(root, "Glow")
	box.Active = false
	box.ZIndex = 0
	box.Visible = false
	table.insert(bag, Surface.Glow(box, { Name = "Image", Kind = kind, Colour = "Pink" }, scope))
	return box
end

-- The base line of a tile or row: a hairline, and when selected the thick Pink to Violet line. The gradient is
-- made with the line (disabled), so selecting creates nothing.
local function newLineGradient(line)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Gradient"
	gradient.Color = ColorSequence.new(colourOf("Pink"), colourOf("Violet"))
	gradient.Enabled = false
	gradient.Parent = line
	return gradient
end

local function paintLine(line, gradient, look)
	put(gradient, "Enabled", look.Selected)
	put(line, "BackgroundColor3", colourOf(look.Selected and "White" or look.Line))
	put(line, "BackgroundTransparency", 1 - look.LineOpacity)
end

-- A picture that covers a box (PictureMode): an oversized ImageLabel in a clipping Frame named Picture, behind
-- everything else of its plate. A Crop ImageLabel alone cuts about its centre; here the car is held in view
-- (Collections._cover). The scrim is made on first use.
local function newCover(parent)
	local box = newFrame(parent, "Picture")
	box.ClipsDescendants = true
	box.ZIndex = 0
	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Parent = box
	return { Box = box, Image = image }
end

-- fit: the box already has the picture's shape, so the picture is shown whole (Fit); else it covers the box (Crop).
local function placeCover(cover, image, width, height, opacity, fit)
	local x, y, drawWidth, drawHeight = Collections._cover(width, height, PICTURE_ASPECT, PICTURE_FOCUS_X, PICTURE_FOCUS_Y)
	put(cover.Box, "Size", UDim2.fromOffset(width, height))
	put(cover.Image, "ScaleType", fit and Enum.ScaleType.Fit or Enum.ScaleType.Crop)
	put(cover.Image, "Image", image)
	put(cover.Image, "Position", UDim2.fromOffset(x, y))
	put(cover.Image, "Size", UDim2.fromOffset(drawWidth, drawHeight))
	put(cover.Image, "ImageTransparency", 1 - opacity)
	put(cover.Box, "Visible", true)
end

-- The Slate scrim over a full-frame picture: `dim` over all of it, rising to ScrimBottom at the foot, where the
-- name is. A change of dim rewrites one NumberSequence; it creates nothing.
local function shadeCover(cover, dim)
	if cover.Scrim == nil then
		local scrim = newFrame(cover.Box, "Scrim")
		scrim.BackgroundColor3 = colourOf("Slate")
		scrim.BackgroundTransparency = 0
		scrim.Size = UDim2.fromScale(1, 1)
		scrim.ZIndex = 2
		local gradient = Instance.new("UIGradient")
		gradient.Name = "Gradient"
		gradient.Rotation = QUARTER_TURN
		gradient.Parent = scrim
		cover.Scrim = scrim
		cover.Gradient = gradient
	end
	if cover.Dim ~= dim then
		cover.Dim = dim
		cover.Gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1 - dim),
			NumberSequenceKeypoint.new(SCRIM_START, 1 - dim),
			NumberSequenceKeypoint.new(1, 1 - Opacity.ScrimBottom),
		})
	end
	put(cover.Scrim, "Visible", true)
end

local function hideCover(cover)
	if cover ~= nil then
		put(cover.Box, "Visible", false)
	end
end

local function checkTilePicture(value)
	if value ~= nil and value ~= "Box" and value ~= "Full" and value ~= "Wide" then
		error("[Pulse.Collections] Tile: PictureMode is \"Box\", \"Full\" or \"Wide\", got " .. tostring(value), 3)
	end
end

local function checkRowPicture(value)
	if value ~= nil and value ~= "Square" and value ~= "Wide" then
		error("[Pulse.Collections] ListRow: PictureMode is \"Square\" or \"Wide\", got " .. tostring(value), 3)
	end
end

local function checkTierSide(value)
	if value ~= nil and value ~= "Left" and value ~= "Right" then
		error("[Pulse.Collections] ListRow: TierSide is \"Left\" or \"Right\", got " .. tostring(value), 3)
	end
end

-- Badge height: the size token on Regular; on Compact one height, the status strip less a hairline each side.
local function badgePx(ctx, design, textSize)
	if isCompact(ctx) then
		return math.max(ctx.Px(Space.CompactStatusHeight - Space.Hairline - Space.Hairline), textSize)
	end
	return math.max(ctx.Px(design), textSize)
end

local function ratingText(rating)
	return string.format("%d", math.floor(rating + HALF))
end

-- Writes text, face and box of a one-instance chip (a TextLabel with a background). Returns its width.
local function boxText(label, text, role, ctx, minHeightDesign, padDesign)
	put(label, "Text", text)
	local textSize = face(label, role, ctx)
	local height = math.max(ctx.Px(unit(ctx, minHeightDesign)), textSize)
	local pad = ctx.Px(unit(ctx, padDesign))
	local width = textWidth(label) + pad + pad
	put(label, "TextXAlignment", Enum.TextXAlignment.Center)
	return width, height
end

---------------------------------------------------------------------------------------------------
-- Pure state resolution
---------------------------------------------------------------------------------------------------

-- Pure. state: "Default" | "Selected". status: Tile status. flags: Hover, Pressed, Focused, Selectable.
-- Controller focus shows the selected look. Unaffordable stays active (it can be selected and previewed; only
-- its price is muted). Locked is active only when Selectable is passed as true; Selectable = false switches any
-- tile off.
function Collections._resolveTile(state, status, flags)
	if state ~= "Default" and state ~= "Selected" then
		error("[Pulse.Collections] unknown State " .. tostring(state), 2)
	end
	if status ~= "None" and status ~= "Owned" and status ~= "Fitted" and status ~= "Locked" and status ~= "Unaffordable" then
		error("[Pulse.Collections] unknown Status " .. tostring(status), 2)
	end
	local selected = state == "Selected" or flags.Focused == true
	local look = {
		Selected = selected,
		Fill = "Slate",
		FillOpacity = Opacity.Panel,
		Ink = "White",
		Sub = "TextSecondary",
		Line = "White",
		LineOpacity = Opacity.HairBottom,
		Glow = selected,
		Grow = selected,
		ChipFill = "White",
		ChipFillOpacity = Opacity.ChipNeutral,
		ChipInk = "White",
		PriceInk = "Yellow",
		OnLight = selected,
		BadgeDim = false,
		Lock = false,
		Opacity = 1,
		Active = true,
	}
	if selected then
		look.Fill = "White"
		look.FillOpacity = 1
		look.Ink = "Ink"
		look.Sub = "Ink"
		look.Line = "Pink"
		look.LineOpacity = 1
		look.ChipFill = "Ink"
		look.ChipFillOpacity = 1
	end
	if status == "Locked" then
		look.Active = flags.Selectable == true
		look.Opacity = Opacity.Locked
		look.Lock = true
		look.BadgeDim = true
		look.PriceInk = "TextMuted"
		return look
	end
	if status == "Unaffordable" then
		look.BadgeDim = true
		look.PriceInk = "TextMuted"
	end
	if flags.Selectable == false then
		look.Active = false
	elseif not selected then
		if flags.Pressed then
			look.FillOpacity = 1
			look.LineOpacity = Opacity.HairTop
		elseif flags.Hover then
			look.LineOpacity = Opacity.HairTop
		end
	end
	return look
end

-- Pure. Changes a resolved look for a tile whose picture fills it (PictureMode "Full") and returns it. The text is
-- always light, on the scrim; the selected tile has no White fill (it keeps the thick Pink to Violet line, the
-- growth and the glow); the neutral chips get an Ink plate. Dim is how much Slate lies over the whole picture: none
-- when selected, less under the pointer, so the selected picture is the bright one.
function Collections._overPicture(look, flags)
	look.Fill = "Slate"
	look.FillOpacity = Opacity.Panel
	look.Ink = "White"
	look.Sub = look.Selected and "White" or "TextSecondary"
	look.ChipFill = "Ink"
	look.ChipFillOpacity = Opacity.Panel
	look.ChipInk = "White"
	look.OnLight = false
	if look.Selected then
		look.Dim = 0
	elseif flags.Hover or flags.Pressed then
		look.Dim = Opacity.ChipNeutral
	else
		look.Dim = Opacity.RankTrack
	end
	return look
end

-- Pure. Changes a resolved look for a Compact (phone) tile and returns it. A Compact tile never takes the White
-- fill: with a picture it is the full-frame look (_overPicture); without one the selected tile is an opaque Slate
-- plate with light text, and keeps the thick Pink to Violet line, the growth and the glow.
function Collections._compactTile(look, flags, hasPicture)
	if hasPicture then
		return Collections._overPicture(look, flags)
	end
	if look.Selected then
		look.Fill = "Slate"
		look.FillOpacity = 1
		look.Ink = "White"
		look.Sub = "White"
		look.ChipFill = "White"
		look.ChipFillOpacity = Opacity.ChipNeutral
		look.ChipInk = "White"
	end
	look.OnLight = false
	return look
end

-- Pure. What the top row of a Compact tile shows left of its corner chip, so that nothing overlaps: returns
-- showTier, showRating, showIcon. Lengths are real px: the tile width, the corner chip (0 = none), the tier letter
-- cell (0 = no tier), the rating cell (0 = none), the icon (0 = none) and the gap between parts. The corner chip
-- always stays. When the row is too long the rating goes first, then the icon, then the tier letter.
function Collections._compactTop(width, chip, letter, rating, icon, gap)
	local room = width - (chip > 0 and chip + gap or 0)
	local hasTier, hasRating, hasIcon = letter > 0, letter > 0 and rating > 0, icon > 0
	local function fits(withTier, withRating, withIcon)
		local total = 0
		if withTier then
			total = total + letter
		end
		if withRating then
			total = total + rating
		end
		if withIcon then
			total = total + gap + icon
		end
		return total <= room
	end
	if fits(hasTier, hasRating, hasIcon) then
		return hasTier, hasRating, hasIcon
	elseif fits(hasTier, false, hasIcon) then
		return hasTier, false, hasIcon
	elseif fits(hasTier, false, false) then
		return hasTier, false, false
	end
	return false, false, false
end

-- Pure. Where a picture `aspect` wide for one high sits so that it covers a box: x, y, width, height in whole px
-- against the box. The point (focusX, focusY) of the picture is held as near the box centre as its edges allow.
function Collections._cover(boxWidth, boxHeight, aspect, focusX, focusY)
	if boxWidth <= 0 or boxHeight <= 0 then
		return 0, 0, 0, 0
	end
	local width, height = boxWidth, boxHeight
	if boxWidth > boxHeight * aspect then
		height = math.ceil(boxWidth / aspect)
	else
		width = math.ceil(boxHeight * aspect)
	end
	local x = math.clamp(math.floor(boxWidth * HALF - width * focusX + HALF), boxWidth - width, 0)
	local y = math.clamp(math.floor(boxHeight * HALF - height * focusY + HALF), boxHeight - height, 0)
	return x, y, width, height
end

-- Pure. What the top-right corner of a tile shows: text and its kind ("Price", or the ChipRightKind: "Neutral",
-- "Pink", "Cyan"); nil when nothing. ChipRightKind "Tick" is the cyan tick corner and wins over everything.
function Collections._corner(status, price, chipRight, chipRightKind)
	local right = textOf(chipRight)
	local cost = textOf(price)
	local kind = chipRightKind or "Neutral"
	if kind ~= "Neutral" and kind ~= "Pink" and kind ~= "Cyan" and kind ~= "Tick" then
		error("[Pulse.Collections] unknown ChipRightKind " .. tostring(chipRightKind), 2)
	end
	if kind == "Tick" then
		return right or "", "Tick"
	elseif status == "Owned" or status == "Fitted" then
		return right or string.upper(status), kind
	elseif cost then
		return cost, "Price"
	elseif right then
		return right, kind
	end
	return nil, nil
end

-- Pure. Keyed pool plan. previous: key -> slot. Returns the new key -> slot map, the slot of each key
-- in order, and the slot count needed. A key keeps its slot; new keys take free slots, lowest first.
function Collections._planPool(previous, slotCount, keys)
	local assign = {}
	local used = {}
	local seen = {}
	for _, key in ipairs(keys) do
		if seen[key] then
			error("[Pulse.Collections] Rail: duplicate key " .. tostring(key), 2)
		end
		seen[key] = true
		local slot = previous[key]
		if slot ~= nil then
			assign[key] = slot
			used[slot] = true
		end
	end
	local order = {}
	local nextFree = 1
	for index, key in ipairs(keys) do
		if assign[key] == nil then
			while used[nextFree] do
				nextFree = nextFree + 1
			end
			assign[key] = nextFree
			used[nextFree] = true
			if nextFree > slotCount then
				slotCount = nextFree
			end
		end
		order[index] = assign[key]
	end
	return assign, order, slotCount
end

---------------------------------------------------------------------------------------------------
-- Chip
---------------------------------------------------------------------------------------------------

local CHIP_KEYS = keySet({ "Text", "Kind", "Muted" })
local CHIP_DEFAULTS = { Text = "", Kind = "Neutral" }

-- Pure. Returns fill role, fill opacity, ink role.
function Collections._resolveChip(kind, muted)
	local fill, fillOpacity, ink
	if kind == "Neutral" then
		fill, fillOpacity, ink = "White", Opacity.ChipNeutral, "White"
	elseif kind == "Price" then
		fill, fillOpacity, ink = "Ink", 1, "Yellow"
	elseif kind == "Cyan" then
		fill, fillOpacity, ink = "Cyan", 1, "Ink"
	elseif kind == "Pink" then
		fill, fillOpacity, ink = "Pink", 1, "White"
	elseif kind == "Yellow" then
		fill, fillOpacity, ink = "Yellow", 1, "Ink"
	else
		error("[Pulse.Collections] Chip: unknown Kind " .. tostring(kind), 2)
	end
	if muted and (kind == "Neutral" or kind == "Price") then
		ink = "TextMuted"
	end
	return fill, fillOpacity, ink
end

function Collections.Chip(parent, props, scope)
	local state = readProps("Chip", CHIP_KEYS, CHIP_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false

	local root = Instance.new("Frame")
	root.Name = state.Name or "Chip"
	root.BorderSizePixel = 0
	local label = newText(root, "Label")

	local function render()
		if destroyed then
			return
		end
		local fill, fillOpacity, ink = Collections._resolveChip(state.Kind, state.Muted == true)
		local role = state.Kind == "Price" and "Value" or "Label"
		put(label, "Text", string.upper(tostring(state.Text)))
		local textSize = face(label, role, ctx)
		local height = math.max(ctx.Px(unit(ctx, Space.BadgeMedium)), textSize)
		local pad = ctx.Px(unit(ctx, Space.Gap))
		local textPx = textWidth(label)
		put(root, "Size", UDim2.fromOffset(textPx + pad + pad, height))
		put(root, "BackgroundColor3", colourOf(fill))
		put(root, "BackgroundTransparency", 1 - fillOpacity)
		put(label, "Position", UDim2.fromOffset(pad, -baselineShift(textSize)))
		put(label, "Size", UDim2.fromOffset(textPx, height))
		put(label, "TextColor3", colourOf(ink))
	end

	listen(scope, bag, label:GetPropertyChangedSignal("TextBounds"), render)
	listen(scope, bag, Text.ReadyChanged, render)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, render)
	end

	applyCommon(root, state)
	render()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if destroyed or not mergePatch("Chip", CHIP_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		render()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- TierBadge
---------------------------------------------------------------------------------------------------

local BADGE_KEYS = keySet({ "Tier", "Rating", "Size", "OnLight", "Dim" })
local BADGE_DEFAULTS = { Size = "Large" }

-- Pure. Returns the height token and the text role of a badge size.
function Collections._badgeSize(size)
	if size == "Large" then
		return Space.BadgeLarge, "Status"
	elseif size == "Medium" then
		return Space.BadgeMedium, "Tab"
	elseif size == "Small" then
		return Space.BadgeSmall, "Value"
	end
	error("[Pulse.Collections] TierBadge: unknown Size " .. tostring(size), 2)
end

function Collections.TierBadge(parent, props, scope)
	local state = readProps("TierBadge", BADGE_KEYS, BADGE_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false

	local root = Instance.new("Frame")
	root.Name = state.Name or "TierBadge"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	local letter = newText(root, "Letter")
	local rating = nil

	local render
	render = function()
		if destroyed then
			return
		end
		local tint = tierColour(state.Tier)
		local design, role = Collections._badgeSize(state.Size)
		local hair = ctx.Hair(unit(ctx, Space.Hairline))
		local opacity = state.Dim == true and Opacity.Locked or 1

		put(letter, "Text", state.Tier)
		local textSize = face(letter, role, ctx)
		local height = badgePx(ctx, design, textSize)
		local letterWidth = math.max(math.floor(height * BADGE_LETTER + HALF), textWidth(letter) + hair + hair)
		put(letter, "TextXAlignment", Enum.TextXAlignment.Center)
		put(letter, "Size", UDim2.fromOffset(letterWidth, height))
		put(letter, "BackgroundColor3", tint)
		put(letter, "BackgroundTransparency", 1 - opacity)
		put(letter, "TextColor3", colourOf("Ink"))
		put(letter, "TextTransparency", 1 - opacity)

		local width = letterWidth
		if type(state.Rating) == "number" then
			if rating == nil then
				rating = newText(root, "Rating")
				listen(scope, bag, rating:GetPropertyChangedSignal("TextBounds"), render)
			end
			local ratingWidth = boxText(rating, ratingText(state.Rating), role, ctx, design, Space.Gap)
			local onLight = state.OnLight == true
			put(rating, "Position", UDim2.fromOffset(letterWidth, 0))
			put(rating, "Size", UDim2.fromOffset(ratingWidth, height))
			put(rating, "BackgroundColor3", colourOf(onLight and "Ink" or "White"))
			put(rating, "BackgroundTransparency", 1 - opacity)
			put(rating, "TextColor3", colourOf(onLight and "White" or "Ink"))
			put(rating, "TextTransparency", 1 - opacity)
			put(rating, "Visible", true)
			width = width + ratingWidth
		elseif rating ~= nil then
			put(rating, "Visible", false)
		end
		put(root, "Size", UDim2.fromOffset(width, height))
	end

	listen(scope, bag, letter:GetPropertyChangedSignal("TextBounds"), render)
	listen(scope, bag, Text.ReadyChanged, render)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, render)
	end

	applyCommon(root, state)
	render()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if destroyed or not mergePatch("TierBadge", BADGE_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		render()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	return self
end

---------------------------------------------------------------------------------------------------
-- Tile
---------------------------------------------------------------------------------------------------

local TILE_KEYS = keySet({
	"Title",
	"Sub",
	"State",
	"Status",
	"ChipLeft",
	"ChipRight",
	"Price",
	"Image",
	"Icon",
	"Tier",
	"Rating",
	"Compact7",
	"MarkKey",
	"OnActivated",
	"ChipRightKind",
	"Selectable",
	"PictureMode",
})
local TILE_DEFAULTS = { Title = "", State = "Default", Status = "None" }

-- host (a Rail only): CellWidth() -> design width or nil, CellPx() -> real width or nil (a grid), NoGlow,
-- Activated(), Focused().
-- Returns the component, a whole-props replace function and a re-render function.
local function buildTile(parent, props, scope, host)
	local state = readProps("Tile", TILE_KEYS, TILE_DEFAULTS, props)
	checkTilePicture(state.PictureMode)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false }
	local destroyed = false
	local marked = nil

	local root = newButton(state.Name or "Tile")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	local fill = newFrame(root, "Fill")
	local line = newFrame(fill, "HairBottom")
	line.ZIndex = 2
	local lineGradient = newLineGradient(line)
	local visual = Instance.new("ImageLabel")
	visual.Name = "Visual"
	visual.BackgroundTransparency = 1
	visual.BorderSizePixel = 0
	visual.ScaleType = Enum.ScaleType.Fit
	visual.Parent = fill
	local untinted = visual.ImageColor3 -- the engine default: a picture is drawn in its own colours
	local title = newText(fill, "Title")
	title.TextYAlignment = Enum.TextYAlignment.Bottom

	local sub, chipLeft, corner, tierLetter, tierRating, lock, tick, glow = nil, nil, nil, nil, nil, nil, nil, nil
	local cover = nil -- the full-frame or wide picture, made the first time PictureMode asks for one
	if not (host and host.NoGlow) then
		glow = newGlow(root, scope, bag, "Tile")
	end

	local render

	local function textPart(name)
		local label = newText(fill, name)
		listen(scope, bag, label:GetPropertyChangedSignal("TextBounds"), function()
			render()
		end)
		return label
	end

	local function paintBox(label, fillRole, fillOpacity, inkRole, opacity)
		put(label, "BackgroundColor3", colourOf(fillRole))
		put(label, "BackgroundTransparency", 1 - fillOpacity * opacity)
		put(label, "TextColor3", colourOf(inkRole))
		put(label, "TextTransparency", 1 - opacity)
	end

	local function paintCorner(kind, look, opacity)
		if kind == "Price" then
			paintBox(corner, "Ink", 1, look.PriceInk, opacity)
		elseif kind == "Pink" then
			paintBox(corner, "Pink", 1, "White", opacity)
		elseif kind == "Cyan" then
			paintBox(corner, "Cyan", 1, "Ink", opacity)
		else
			paintBox(corner, look.ChipFill, look.ChipFillOpacity, look.ChipInk, opacity)
		end
	end

	-- The cyan tick corner: an Ink tick on a Cyan cell, against the tile's top-right corner. Returns its side.
	local function placeTick(width, opacity)
		local tickDesign = unit(ctx, Space.BadgeSmall)
		local tickPx = ctx.Px(tickDesign)
		if tick == nil then
			tick = Surface.Icon(fill, { Name = "Tick", Icon = "tick", Colour = "Ink", Size = tickDesign }, scope)
			table.insert(bag, tick)
			tick.Instance.BackgroundColor3 = colourOf("Cyan")
		else
			tick.Set({ Size = tickDesign, Visible = true })
		end
		tick.Set({ Opacity = opacity })
		put(tick.Instance, "BackgroundTransparency", 1 - opacity)
		put(tick.Instance, "Position", UDim2.fromOffset(width - tickPx, 0))
		return tickPx
	end

	local function hidePart(object)
		if object ~= nil then
			put(object, "Visible", false)
		end
	end

	-- The Compact (phone) tile, one design for every tile (API2 amendment A7). Every tile of a rail is the same
	-- width whatever its name. Top row, flush with the top edge: tier letter and rating, then the icon (the lock on
	-- a locked tile), and exactly one chip against the right edge (Collections._corner); Collections._compactTop
	-- drops the rating, then the icon, then the letter before anything overlaps. The name stands at the foot on one
	-- or two lines and ends in an ellipsis. A picture always covers the whole tile under a scrim, whatever
	-- PictureMode says. No sub-line and no left chip. look comes from Collections._compactTile: never a White fill.
	local function renderCompact(look, image)
		local pad = ctx.Px(unit(ctx, Space.Gap))
		local hair = ctx.Hair(unit(ctx, Space.Hairline))
		local opacity = look.Opacity

		local cellDesign = host and host.CellWidth and host.CellWidth() or nil
		local cellPx = host and host.CellPx and host.CellPx() or nil
		local height = ctx.Px(Space.CompactTileHeight)
		local width = cellPx or ctx.Px(cellDesign or Space.CompactTileMinWidth * COMPACT_TILE_WIDTH)
		local grow = look.Grow and ctx.Px(Space.TileBaseLine) or 0
		local fillHeight = height + grow
		put(root, "Size", UDim2.fromOffset(width, height))
		put(fill, "Position", UDim2.fromOffset(0, -grow))
		put(fill, "Size", UDim2.fromOffset(width, fillHeight))
		put(fill, "BackgroundColor3", colourOf(look.Fill))
		put(fill, "BackgroundTransparency", 1 - look.FillOpacity)
		if glow ~= nil then
			put(glow, "Position", UDim2.fromOffset(0, -grow))
			put(glow, "Size", UDim2.fromOffset(width, fillHeight))
			put(glow, "Visible", look.Glow)
		end

		local lineHeight = look.Selected and ctx.Px(Space.Hairline + Space.Hairline) or hair
		put(line, "Position", UDim2.fromOffset(0, fillHeight - lineHeight))
		put(line, "Size", UDim2.fromOffset(width, lineHeight))
		paintLine(line, lineGradient, look)

		-- Name: a fixed two-line box at the foot, the text on its bottom edge. The box never follows the text, so
		-- wrapping and the ellipsis cannot feed back into the tile's size.
		put(title, "Text", string.upper(tostring(state.Title)))
		local titleSize = face(title, "TileNameSmall", ctx)
		local titleBox = titleSize * 2
		put(title, "TextWrapped", true)
		put(title, "TextTruncate", Enum.TextTruncate.AtEnd)
		put(title, "TextXAlignment", Enum.TextXAlignment.Left)
		put(title, "Position", UDim2.fromOffset(pad, fillHeight - pad - titleBox))
		put(title, "Size", UDim2.fromOffset(math.max(0, width - pad - pad), titleBox))
		put(title, "TextColor3", colourOf(look.Ink))
		put(title, "TextTransparency", 1 - opacity)

		-- Top row. Every part is one row high (the tier letter's text size) and is measured whole: none is truncated.
		local rowRole = "Value"
		local rowHeight = Text.SizeFor(rowRole, ctx)
		local tier = textOf(state.Tier)
		local badgeOpacity = look.BadgeDim and math.min(Opacity.Locked, opacity) or opacity
		local letterWidth, ratingWidth = 0, 0
		if tier then
			tierLetter = tierLetter or textPart("TierLetter")
			put(tierLetter, "Text", tier)
			face(tierLetter, rowRole, ctx)
			letterWidth = math.max(math.floor(rowHeight * BADGE_LETTER + HALF), textWidth(tierLetter) + hair + hair)
			if type(state.Rating) == "number" then
				tierRating = tierRating or textPart("TierRating")
				ratingWidth = boxText(tierRating, ratingText(state.Rating), rowRole, ctx, Space.BadgeSmall, Space.Gap)
			end
		end

		local cornerText, cornerKind = Collections._corner(state.Status, state.Price, state.ChipRight, state.ChipRightKind)
		local showTick = cornerKind == "Tick"
		local chipWidth = 0
		if showTick then
			chipWidth = placeTick(width, opacity)
			hidePart(corner)
		else
			if tick ~= nil then
				tick.Set({ Visible = false })
			end
			if cornerText then
				corner = corner or textPart("Corner")
				chipWidth = boxText(corner, string.upper(cornerText), cornerKind == "Price" and "Value" or "Label", ctx, Space.BadgeMedium, Space.Gap)
				chipWidth = math.min(chipWidth, width)
				put(corner, "Position", UDim2.fromOffset(width - chipWidth, 0))
				put(corner, "Size", UDim2.fromOffset(chipWidth, rowHeight))
				paintCorner(cornerKind, look, opacity)
				put(corner, "Visible", true)
			else
				hidePart(corner)
			end
		end

		-- The icon: the lock on a locked tile, else the glyph of a tile that has no picture.
		local glyph = look.Lock and "lock" or (image == nil and textOf(state.Icon) or nil)
		local cell = nil
		if glyph then
			cell = Tokens.Icons.Glyphs[glyph]
			if cell == nil then
				error("[Pulse.Collections] Tile: unknown icon " .. glyph, 2)
			end
		end
		local iconSize = glyph and math.max(1, rowHeight - hair - hair) or 0

		local showTier, showRating, showIcon = Collections._compactTop(width, chipWidth, letterWidth, ratingWidth, iconSize, pad)
		local x = 0
		if showTier then
			put(tierLetter, "TextXAlignment", Enum.TextXAlignment.Center)
			put(tierLetter, "Position", UDim2.fromOffset(0, 0))
			put(tierLetter, "Size", UDim2.fromOffset(letterWidth, rowHeight))
			put(tierLetter, "BackgroundColor3", tierColour(tier))
			put(tierLetter, "BackgroundTransparency", 1 - badgeOpacity)
			put(tierLetter, "TextColor3", colourOf("Ink"))
			put(tierLetter, "TextTransparency", 1 - badgeOpacity)
			put(tierLetter, "Visible", true)
			x = letterWidth
		else
			hidePart(tierLetter)
		end
		if showRating then
			put(tierRating, "Position", UDim2.fromOffset(x, 0))
			put(tierRating, "Size", UDim2.fromOffset(ratingWidth, rowHeight))
			paintBox(tierRating, "White", 1, "Ink", badgeOpacity)
			put(tierRating, "Visible", true)
			x = x + ratingWidth
		else
			hidePart(tierRating)
		end
		if showIcon then
			local cellSize = Tokens.Icons.Cell
			put(visual, "Image", Tokens.Asset("IconSheet") or "")
			put(visual, "ImageRectOffset", Vector2.new(cell[1] * cellSize, cell[2] * cellSize))
			put(visual, "ImageRectSize", Vector2.new(cellSize, cellSize))
			put(visual, "ImageColor3", colourOf(look.Ink))
			put(visual, "ImageTransparency", 1 - opacity)
			put(visual, "Position", UDim2.fromOffset(x + pad, hair))
			put(visual, "Size", UDim2.fromOffset(iconSize, iconSize))
		end
		put(visual, "Visible", showIcon)

		if image then
			cover = cover or newCover(fill)
			placeCover(cover, image, width, fillHeight, opacity, false)
			shadeCover(cover, look.Dim)
		else
			hideCover(cover)
		end

		-- Parts only the Regular tile has (the class can change while a tile lives).
		hidePart(sub)
		hidePart(chipLeft)
		if lock ~= nil then
			lock.Set({ Visible = false })
		end
		put(root, "Active", look.Active)
	end

	render = function()
		if destroyed then
			return
		end
		flags.Selectable = state.Selectable
		local look = Collections._resolveTile(state.State, state.Status, flags)
		local image = textOf(state.Image)
		if isCompact(ctx) then
			renderCompact(Collections._compactTile(look, flags, image ~= nil), image)
			return
		end
		-- PictureMode changes a tile that has a picture, and nothing else: "Full" lays the picture over the whole
		-- tile under the text, "Wide" over its full width down to the text.
		local pictureMode = image and state.PictureMode or "Box"
		local full = pictureMode == "Full"
		local framed = full or pictureMode == "Wide"
		if full then
			look = Collections._overPicture(look, flags)
		elseif framed and not look.Selected then
			look.ChipFill = "Ink" -- the chips stand on the picture
			look.ChipFillOpacity = Opacity.Panel
		end
		local seven = state.Compact7 == true
		local inset = ctx.Px(Space.Pad * TILE_INSET)
		local hair = ctx.Hair(Space.Hairline)
		local gap = ctx.Px(Space.Gap)
		local opacity = look.Opacity

		put(title, "Text", string.upper(tostring(state.Title)))
		local titleSize = face(title, seven and "TileNameSmall" or "TileName", ctx)

		local cellDesign = host and host.CellWidth and host.CellWidth() or nil
		local cellPx = host and host.CellPx and host.CellPx() or nil
		local height = ctx.Px(Space.TileHeight)
		local width = cellPx or ctx.Px(cellDesign or (seven and Space.TileWidth * SEVEN_WIDTH or Space.TileWidth))

		local grow = 0
		if look.Grow then
			grow = ctx.Px(Space.Gap + Space.TileBaseLine)
		end
		local fillHeight = height + grow
		put(root, "Size", UDim2.fromOffset(width, height))
		put(fill, "Position", UDim2.fromOffset(0, -grow))
		put(fill, "Size", UDim2.fromOffset(width, fillHeight))
		put(fill, "BackgroundColor3", colourOf(look.Fill))
		put(fill, "BackgroundTransparency", 1 - look.FillOpacity)
		if glow ~= nil then
			put(glow, "Position", UDim2.fromOffset(0, -grow))
			put(glow, "Size", UDim2.fromOffset(width, fillHeight))
		end

		local lineHeight = look.Selected and ctx.Hair(Space.TileBaseLine) or hair
		put(line, "Position", UDim2.fromOffset(0, fillHeight - lineHeight))
		put(line, "Size", UDim2.fromOffset(width, lineHeight))
		paintLine(line, lineGradient, look)

		-- Title, bottom of the tile. The box is always two lines tall and the text sits on its bottom edge:
		-- measured in a one-line box, a wrapped name never reported its second line, so a two-word name showed
		-- its first word only (capture module_shop). It is wrapped and sized before it is measured.
		local titleBox = titleSize * 2
		put(title, "TextWrapped", true)
		put(title, "TextTruncate", Enum.TextTruncate.None)
		put(title, "TextXAlignment", Enum.TextXAlignment.Left)
		put(title, "Position", UDim2.fromOffset(inset, fillHeight - inset - titleBox))
		put(title, "Size", UDim2.fromOffset(math.max(0, width - inset - inset), titleBox))
		local lines = title.TextBounds.Y > titleSize * TWO_LINES and 2 or 1
		local titleTop = fillHeight - inset - titleSize * lines
		local twoLine = lines == 2
		local textTop = titleTop -- top of the text block (name, plus the sub-line when there is one)
		put(title, "TextColor3", colourOf(look.Ink))
		put(title, "TextTransparency", 1 - opacity)

		-- Sub-line above the title.
		local subText = textOf(state.Sub)
		if subText then
			sub = sub or textPart("Sub")
			put(sub, "Text", string.upper(subText))
			local subSize = face(sub, "Label", ctx)
			put(sub, "TextTruncate", Enum.TextTruncate.AtEnd)
			textTop = titleTop - subSize
			put(sub, "Position", UDim2.fromOffset(inset, textTop))
			put(sub, "Size", UDim2.fromOffset(math.max(0, width - inset - inset), subSize))
			put(sub, "TextColor3", colourOf(look.Sub))
			put(sub, "TextTransparency", 1 - opacity)
			put(sub, "Visible", true)
		elseif sub ~= nil then
			put(sub, "Visible", false)
		end

		-- Top-left: tier badge, then the variant or index chip.
		local edge = inset
		local x = edge
		local tier = textOf(state.Tier)
		local badgeOpacity = look.BadgeDim and math.min(Opacity.Locked, opacity) or opacity
		if tier then
			tierLetter = tierLetter or textPart("TierLetter")
			local badgeDesign, badgeRole = Collections._badgeSize("Large")
			put(tierLetter, "Text", tier)
			local badgeSize = face(tierLetter, badgeRole, ctx)
			local badgeHeight = badgePx(ctx, badgeDesign, badgeSize)
			local letterWidth = math.max(math.floor(badgeHeight * BADGE_LETTER + HALF), textWidth(tierLetter) + hair + hair)
			put(tierLetter, "TextXAlignment", Enum.TextXAlignment.Center)
			put(tierLetter, "Position", UDim2.fromOffset(x, edge))
			put(tierLetter, "Size", UDim2.fromOffset(letterWidth, badgeHeight))
			put(tierLetter, "BackgroundColor3", tierColour(tier))
			put(tierLetter, "BackgroundTransparency", 1 - badgeOpacity)
			put(tierLetter, "TextColor3", colourOf("Ink"))
			put(tierLetter, "TextTransparency", 1 - badgeOpacity)
			put(tierLetter, "Visible", true)
			x = x + letterWidth
			if type(state.Rating) == "number" then
				tierRating = tierRating or textPart("TierRating")
				local ratingWidth = boxText(tierRating, ratingText(state.Rating), badgeRole, ctx, badgeDesign, Space.Gap)
				put(tierRating, "Position", UDim2.fromOffset(x, edge))
				put(tierRating, "Size", UDim2.fromOffset(ratingWidth, badgeHeight))
				paintBox(tierRating, look.OnLight and "Ink" or "White", 1, look.OnLight and "White" or "Ink", badgeOpacity)
				put(tierRating, "Visible", true)
				x = x + ratingWidth
			elseif tierRating ~= nil then
				put(tierRating, "Visible", false)
			end
			x = x + gap
		else
			if tierLetter ~= nil then
				put(tierLetter, "Visible", false)
			end
			if tierRating ~= nil then
				put(tierRating, "Visible", false)
			end
		end

		local leftText = textOf(state.ChipLeft)
		if leftText then
			chipLeft = chipLeft or textPart("ChipLeft")
			local chipWidth, chipHeight = boxText(chipLeft, string.upper(leftText), "Label", ctx, Space.BadgeMedium, Space.Gap)
			put(chipLeft, "Position", UDim2.fromOffset(x, edge))
			put(chipLeft, "Size", UDim2.fromOffset(chipWidth, chipHeight))
			paintBox(chipLeft, look.ChipFill, look.ChipFillOpacity, look.ChipInk, opacity)
			put(chipLeft, "Visible", true)
		elseif chipLeft ~= nil then
			put(chipLeft, "Visible", false)
		end

		-- Top-right corner: price, or the owned / fitted / free-text chip.
		local cornerText, cornerKind = Collections._corner(state.Status, state.Price, state.ChipRight, state.ChipRightKind)
		local showTick = cornerKind == "Tick"
		if cornerText and not showTick then
			corner = corner or textPart("Corner")
			local price = cornerKind == "Price"
			local chipWidth, chipHeight = boxText(corner, string.upper(cornerText), price and "Value" or "Label", ctx, Space.BadgeMedium, Space.Gap)
			put(corner, "Position", UDim2.fromOffset(width - chipWidth, 0))
			put(corner, "Size", UDim2.fromOffset(chipWidth, chipHeight))
			paintCorner(cornerKind, look, opacity)
			put(corner, "Visible", true)
		elseif corner ~= nil then
			put(corner, "Visible", false)
		end

		if showTick then
			placeTick(width, opacity)
		elseif tick ~= nil then
			tick.Set({ Visible = false })
		end

		-- Picture: the card image, else a glyph from the icon sheet, else nothing (plain slate).
		local boxHeight = math.floor(height * VISUAL_HEIGHT)
		local boxTop = math.floor(height * VISUAL_TOP)
		-- A two-line name raises the text block into the picture box (capture module_shop_v2): the box then
		-- keeps its top and shrinks until the drawn picture, selected growth included, ends a gap above the
		-- text. One-line tiles are not touched.
		local pictureLimit = (twoLine and not framed) and (textTop - gap) or nil
		if pictureLimit then
			local scale = look.Selected and Space.TileSelectedGrow or 1
			local fit = math.floor((pictureLimit - boxTop - math.floor(grow * HALF)) / ((1 + scale) * HALF))
			boxHeight = math.max(0, math.min(boxHeight, fit))
		end
		local glyph = textOf(state.Icon)
		local boxWidth = boxHeight
		if framed then
			cover = cover or newCover(fill)
			boxHeight = full and fillHeight or math.max(0, textTop - gap)
			placeCover(cover, image, width, boxHeight, opacity, false)
			if full then
				shadeCover(cover, look.Dim)
			elseif cover.Scrim ~= nil then
				put(cover.Scrim, "Visible", false)
			end
		elseif image then
			boxWidth = math.max(0, width - inset - inset)
			put(visual, "Image", image)
			put(visual, "ImageRectOffset", Vector2.zero)
			put(visual, "ImageRectSize", Vector2.zero)
			put(visual, "ImageColor3", untinted)
		elseif glyph then
			local cell = Tokens.Icons.Glyphs[glyph]
			if cell == nil then
				error("[Pulse.Collections] Tile: unknown icon " .. glyph, 2)
			end
			local cellSize = Tokens.Icons.Cell
			put(visual, "Image", Tokens.Asset("IconSheet") or "")
			put(visual, "ImageRectOffset", Vector2.new(cell[1] * cellSize, cell[2] * cellSize))
			put(visual, "ImageRectSize", Vector2.new(cellSize, cellSize))
			put(visual, "ImageColor3", colourOf(look.Ink))
		else
			put(visual, "Image", "")
		end
		local centreY = boxTop + math.floor(boxHeight * HALF) + math.floor(grow * HALF)
		if framed then
			centreY = math.floor(boxHeight * HALF) -- the lock stands on the middle of the picture
		else
			hideCover(cover)
			local drawWidth, drawHeight = boxWidth, boxHeight
			if look.Selected then
				drawWidth = math.floor(boxWidth * Space.TileSelectedGrow + HALF)
				drawHeight = math.floor(boxHeight * Space.TileSelectedGrow + HALF)
			end
			put(visual, "Position", UDim2.fromOffset(math.floor((width - drawWidth) * HALF), centreY - math.floor(drawHeight * HALF)))
			put(visual, "Size", UDim2.fromOffset(drawWidth, drawHeight))
			put(visual, "ImageTransparency", 1 - opacity)
		end
		put(visual, "Visible", not framed)

		-- Lock icon over the picture.
		if look.Lock then
			local lockDesign = unit(ctx, Space.BadgeLarge)
			local lockPx = ctx.Px(lockDesign)
			if lock == nil then
				lock = Surface.Icon(fill, { Name = "Lock", Icon = "lock", Colour = look.Ink, Size = lockDesign }, scope)
				table.insert(bag, lock)
			else
				lock.Set({ Colour = look.Ink, Size = lockDesign, Visible = true })
			end
			local lockTop = centreY - math.floor(lockPx * HALF)
			if pictureLimit then
				lockTop = math.min(lockTop, pictureLimit - lockPx) -- the badge moves up rather than cover the sub-line
			end
			put(lock.Instance, "Position", UDim2.fromOffset(math.floor((width - lockPx) * HALF), lockTop))
		elseif lock ~= nil then
			lock.Set({ Visible = false })
		end

		if glow ~= nil then
			put(glow, "Visible", look.Glow)
		end
		put(root, "Active", look.Active)
	end

	local function mark()
		local key = textOf(state.MarkKey)
		if key and key ~= marked then
			marked = key
			Input.Mark(root, key)
		end
	end

	listen(scope, bag, root.MouseEnter, function()
		if ctx.Input ~= "Touch" then
			flags.Hover = true
			render()
		end
	end)
	listen(scope, bag, root.MouseLeave, function()
		flags.Hover = false
		flags.Pressed = false
		render()
	end)
	listen(scope, bag, root.MouseButton1Down, function()
		flags.Pressed = true
		render()
	end)
	listen(scope, bag, root.MouseButton1Up, function()
		flags.Pressed = false
		render()
	end)
	listen(scope, bag, root.Activated, function()
		if not root.Active then
			return
		end
		if host and host.Activated then
			host.Activated()
		end
		local callback = state.OnActivated
		if callback then
			callback()
		end
	end)
	listen(scope, bag, title:GetPropertyChangedSignal("TextBounds"), render)
	listen(scope, bag, Text.ReadyChanged, render)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, render)
	end
	Input.Focusable(root, {
		OnFocus = function(focused)
			flags.Focused = focused == true
			render()
			if flags.Focused and not destroyed and host and host.Focused then
				host.Focused()
			end
		end,
	})

	applyCommon(root, state)
	render()
	mark()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if type(patch) == "table" then
			checkTilePicture(patch.PictureMode)
		end
		if destroyed or not mergePatch("Tile", TILE_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil and marked == nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		render()
		mark()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	-- Replaces every prop (a pooled tile takes over another item). Writes only what differs.
	local function replace(nextProps)
		if destroyed then
			return
		end
		local fresh = readProps("Tile", TILE_KEYS, TILE_DEFAULTS, nextProps)
		checkTilePicture(fresh.PictureMode)
		local changed = false
		for key in pairs(TILE_KEYS) do
			if state[key] ~= fresh[key] then
				changed = true
				break
			end
		end
		if not changed then
			return
		end
		state = fresh
		if marked == nil then
			put(root, "Name", state.Name or "Tile")
		end
		applyCommon(root, state)
		render()
		mark()
	end

	return self, replace, render
end

function Collections.Tile(parent, props, scope)
	local tile = buildTile(parent, props, scope, nil)
	return tile
end

---------------------------------------------------------------------------------------------------
-- Rail
---------------------------------------------------------------------------------------------------

-- OnSelected(key) fires when the selection CHANGES (highlight, preview). OnActivated(key) fires on EVERY click,
-- tap or gamepad A on a tile, the selected one included, after any OnSelected: use it for whatever acts.
local RAIL_KEYS = keySet({ "Heading", "Count", "CellWidth", "Width", "Rows", "OnSelected", "OnActivated", "SelectOn" })

-- Pure. Does this input select a rail tile? cause is "Activate" (click, tap, gamepad A) or "Focus" (a gamepad or
-- keyboard focus move). SelectOn nil or "Focus": both select (the rail as it has always been). SelectOn
-- "Activate": focus only highlights the tile (its own focused look) and selection needs an activation, for rails
-- whose selection navigates or previews a purchase.
function Collections._railSelects(selectOn, cause)
	if cause == "Focus" then
		return selectOn ~= "Activate"
	end
	return true
end

local function checkSelectOn(value)
	if value ~= nil and value ~= "Focus" and value ~= "Activate" then
		error("[Pulse.Collections] Rail: SelectOn is \"Focus\" or \"Activate\", got " .. tostring(value), 3)
	end
end

function Collections.Rail(parent, props, scope)
	local state = readProps("Rail", RAIL_KEYS, {}, props)
	checkSelectOn(state.SelectOn)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false

	local slots = {} -- [index] = { Tile, Replace, Render, Key }
	local assign = {} -- key -> slot index
	local order = {} -- slot index of each item, in item order
	local items = {} -- key -> item
	local selected = nil
	local gridCell = nil -- real cell width of a grid rail; nil on a one-row rail
	local group = Input.FocusGroup(scope, nil)

	local root = Instance.new("Frame")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	root.Name = state.Name or "Rail"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local function headingText()
		local heading = textOf(state.Heading)
		local count = textOf(state.Count)
		if heading and count then
			return heading .. " " .. count
		end
		return heading or count or ""
	end

	-- Lanes across the scroll axis. One: the horizontal rail. More: a grid that many cells wide, scrolling
	-- vertically (the Compact car panel is 2).
	local function lanes()
		local rows = state.Rows
		if type(rows) == "number" and rows > 1 then
			return math.floor(rows)
		end
		return 1
	end

	local heading = Text.Label(root, {
		Name = "Heading",
		Text = headingText(),
		Role = "SectionHead",
		Colour = "White",
		Align = "Left",
		Shadow = true,
		Visible = headingText() ~= "",
	}, scope)
	table.insert(bag, heading)

	-- On the heading line, right of the count. Its children stand on the foot of the heading capitals, side by
	-- side; a screen mounts a Segment Tabs here.
	local headingRight = newFrame(root, "HeadingRight")
	local rightList = Instance.new("UIListLayout")
	rightList.Name = "List"
	rightList.FillDirection = Enum.FillDirection.Horizontal
	rightList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Parent = headingRight

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Scroller"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollingDirection = Enum.ScrollingDirection.X
	scroller.ScrollBarThickness = 0
	scroller.Selectable = false
	scroller.CanvasSize = UDim2.fromOffset(0, 0)
	scroller.Parent = root

	-- One glow for the whole rail, moved to the selected cell (a tile in a rail has none of its own).
	local selection = newFrame(scroller, "Selection")
	selection.ZIndex = 0
	selection.Visible = false
	local glow = Surface.Glow(selection, { Name = "Glow", Kind = "Tile", Colour = "Pink" }, scope)
	table.insert(bag, glow)

	local function metrics()
		local compact = isCompact(ctx)
		local gap = ctx.Px(unit(ctx, Space.Gap))
		if isTouchy(ctx) then
			gap = math.max(gap, Space.TouchGap)
		end
		return {
			Glow = ctx.Px(unit(ctx, Space.GlowTileRadius)),
			Grow = ctx.Px(compact and Space.TileBaseLine or (Space.Gap + Space.TileBaseLine)),
			Gap = gap,
			Cell = ctx.Px(compact and Space.CompactTileHeight or Space.TileHeight),
		}
	end

	local function layout()
		if destroyed then
			return
		end
		local m = metrics()
		local across = lanes()
		local headHeight, headGap, headWidth, foot = 0, 0, 0, 0
		local caption = headingText()
		heading.Set({ Text = caption, Visible = caption ~= "" })
		if caption ~= "" then
			local textSize, holderScale = Text.SizeFor("SectionHead", ctx)
			local caps = isCompact(ctx) and Tokens.Cap.Compact or Tokens.Cap.Regular
			headHeight = math.ceil(textSize * holderScale)
			headGap = ctx.Px(unit(ctx, Space.Gap))
			headWidth = math.ceil(heading.Instance.Size.X.Offset * holderScale) + ctx.Px(unit(ctx, Space.Pad))
			foot = math.floor((headHeight + ctx.Px(caps.SectionHead)) * HALF)
		end
		put(heading.Instance, "Position", UDim2.fromOffset(0, 0))
		put(headingRight, "Position", UDim2.fromOffset(headWidth, 0))
		put(headingRight, "Size", UDim2.fromOffset(0, foot))
		put(rightList, "Padding", UDim.new(0, m.Gap))

		-- Width: the Width prop; else the parent's (a sized slot or a panel); else, from a zero-size slot anchor,
		-- to the right edge of the safe area.
		local scaleX, offsetX = 1, 0
		if state.Width then
			scaleX, offsetX = 0, ctx.Px(state.Width)
		elseif not hasWidth(parent) then
			scaleX = 0
			offsetX = math.max(0, math.floor(ctx.Size.X) - parent.Position.X.Offset)
		end
		local rowTop = headHeight + headGap

		if across == 1 then
			if gridCell ~= nil then
				gridCell = nil
				for _, slot in ipairs(slots) do
					slot.Render()
				end
			end
			put(root, "AnchorPoint", Vector2.new(0, 1))
			put(root, "Position", UDim2.new(0, 0, 1, 0))
			put(root, "Size", UDim2.new(scaleX, offsetX, 0, rowTop + m.Grow + m.Cell))
			-- The scroller is larger than the cells by the glow radius, so the glow and the grown tile are not clipped.
			put(scroller, "ScrollingDirection", Enum.ScrollingDirection.X)
			put(scroller, "Position", UDim2.fromOffset(-m.Glow, rowTop - m.Glow))
			put(scroller, "Size", UDim2.new(scaleX, offsetX + m.Glow, 0, m.Grow + m.Cell + m.Glow + m.Glow))

			local x = m.Glow
			local y = m.Glow + m.Grow
			local selectedShown = false
			for index, slotIndex in ipairs(order) do
				local slot = slots[slotIndex]
				local instance = slot.Tile.Instance
				local cellWidth = instance.Size.X.Offset
				if index > 1 then
					x = x + m.Gap
				end
				put(instance, "Position", UDim2.fromOffset(x, y))
				if slot.Key == selected then
					selectedShown = true
					put(selection, "Position", UDim2.fromOffset(x, m.Glow))
					put(selection, "Size", UDim2.fromOffset(cellWidth, m.Grow + m.Cell))
				end
				x = x + cellWidth
			end
			put(selection, "Visible", selectedShown)
			put(scroller, "CanvasSize", UDim2.fromOffset(x + m.Glow, 0))
			return
		end

		-- Grid: `across` equal cells fill the width; the rail fills its parent's height when it has one.
		local pixelWidth = offsetX
		if scaleX ~= 0 then
			local parentSize = parent.Size
			pixelWidth = parentSize.X.Scale == 0 and parentSize.X.Offset or math.floor(root.AbsoluteSize.X)
		end
		local cell = math.max(1, math.floor((pixelWidth - (across - 1) * m.Gap) / across))
		if cell ~= gridCell then
			gridCell = cell
			for _, slot in ipairs(slots) do
				slot.Render()
			end
		end
		local pitch = m.Grow + m.Cell + m.Gap
		local fills = hasHeight(parent)
		put(root, "AnchorPoint", Vector2.new(0, 0))
		put(root, "Position", UDim2.fromOffset(0, 0))
		put(root, "Size", UDim2.new(scaleX, offsetX, fills and 1 or 0, fills and 0 or rowTop + GRID_ROWS * pitch))
		put(scroller, "ScrollingDirection", Enum.ScrollingDirection.Y)
		put(scroller, "Position", UDim2.fromOffset(-m.Glow, rowTop - m.Glow))
		put(scroller, "Size", UDim2.new(scaleX, offsetX + m.Glow + m.Glow, 1, m.Glow + m.Glow - rowTop))

		local selectedShown = false
		local count = 0
		for index, slotIndex in ipairs(order) do
			local slot = slots[slotIndex]
			local column = (index - 1) % across
			local row = math.floor((index - 1) / across)
			local x = m.Glow + column * (cell + m.Gap)
			local y = m.Glow + m.Grow + row * pitch
			put(slot.Tile.Instance, "Position", UDim2.fromOffset(x, y))
			if slot.Key == selected then
				selectedShown = true
				put(selection, "Position", UDim2.fromOffset(x, y - m.Grow))
				put(selection, "Size", UDim2.fromOffset(cell, m.Grow + m.Cell))
			end
			count = row + 1
		end
		put(selection, "Visible", selectedShown)
		put(scroller, "CanvasSize", UDim2.fromOffset(0, m.Glow + m.Glow + count * pitch))
	end

	local self = { Instance = root, HeadingRight = headingRight }

	local function setSelected(key)
		if selected == key then
			return false
		end
		local previous = selected
		selected = key
		if previous ~= nil and assign[previous] ~= nil then
			slots[assign[previous]].Tile.Set({ State = "Default" })
		end
		if key ~= nil and assign[key] ~= nil then
			slots[assign[key]].Tile.Set({ State = "Selected" })
		end
		layout()
		if key ~= nil then
			self.ScrollTo(key)
		end
		return true
	end

	-- A click, or a focus move unless SelectOn is "Activate": select, then tell the owner.
	local function choose(key)
		if destroyed or key == nil or items[key] == nil then
			return
		end
		if setSelected(key) then
			local callback = state.OnSelected
			if callback then
				callback(key)
			end
		end
	end

	local function createSlot()
		local slot = { Key = nil }
		local tile, replace, render = buildTile(scroller, { Visible = false }, scope, {
			NoGlow = true,
			CellWidth = function()
				return state.CellWidth or nil
			end,
			CellPx = function()
				return gridCell
			end,
			Activated = function()
				local key = slot.Key
				choose(key)
				local callback = state.OnActivated
				if callback and not destroyed and key ~= nil and items[key] ~= nil then
					callback(key)
				end
			end,
			Focused = function()
				if Collections._railSelects(state.SelectOn, "Focus") then
					choose(slot.Key)
				elseif not destroyed and slot.Key ~= nil then
					self.ScrollTo(slot.Key) -- highlight only: keep the focused tile in view, select nothing
				end
			end,
		})
		tile.Instance.ZIndex = 1
		slot.Tile = tile
		slot.Replace = replace
		slot.Render = render
		table.insert(bag, tile)
		listen(scope, bag, tile.Instance:GetPropertyChangedSignal("Size"), layout)
		return slot
	end

	local function tileProps(key)
		local item = items[key]
		local copy = {}
		for name, value in pairs(item) do
			if name ~= "Key" then
				copy[name] = value
			end
		end
		copy.State = key == selected and "Selected" or "Default"
		copy.Visible = true
		return copy
	end

	function self.SetItems(list)
		if destroyed then
			return
		end
		local keys = {}
		local nextItems = {}
		for index, item in ipairs(list) do
			local key = type(item) == "table" and item.Key or nil
			if type(key) ~= "string" or key == "" then
				error("[Pulse.Collections] Rail.SetItems: every item needs a string Key", 2)
			end
			keys[index] = key
			nextItems[key] = item
		end
		local nextAssign, nextOrder, count = Collections._planPool(assign, #slots, keys)
		for index = #slots + 1, count do
			slots[index] = createSlot()
		end
		assign, order, items = nextAssign, nextOrder, nextItems
		if selected ~= nil and items[selected] == nil then
			selected = nil
		end
		if selected == nil then
			for _, key in ipairs(keys) do
				if items[key].State == "Selected" then
					selected = key
					break
				end
			end
		end
		local used = {}
		for index, key in ipairs(keys) do
			local slotIndex = order[index]
			local slot = slots[slotIndex]
			used[slotIndex] = true
			slot.Key = key
			slot.Replace(tileProps(key))
			group.Add(slot.Tile.Instance, index)
		end
		for index, slot in ipairs(slots) do
			if not used[index] then
				slot.Key = nil
				slot.Tile.Set({ Visible = false })
				group.Remove(slot.Tile.Instance)
			end
		end
		layout()
	end

	function self.Select(key)
		if destroyed then
			return
		end
		if items[key] == nil then
			error("[Pulse.Collections] Rail.Select: unknown key " .. tostring(key), 2)
		end
		setSelected(key)
	end

	function self.ScrollTo(key)
		local slotIndex = assign[key]
		if destroyed or slotIndex == nil then
			return
		end
		local m = metrics()
		local instance = slots[slotIndex].Tile.Instance
		local current = scroller.CanvasPosition
		if lanes() > 1 then
			local view = scroller.AbsoluteSize.Y
			if view <= 0 then
				return
			end
			local top = instance.Position.Y.Offset - m.Grow - m.Glow
			local bottom = instance.Position.Y.Offset + instance.Size.Y.Offset + m.Glow
			local target = current.Y
			if top < target then
				target = top
			elseif bottom > target + view then
				target = bottom - view
			end
			target = math.max(0, target)
			if target ~= current.Y then
				scroller.CanvasPosition = Vector2.new(0, target)
			end
			return
		end
		local size = scroller.Size
		local view = size.X.Scale == 0 and size.X.Offset or scroller.AbsoluteSize.X
		if view <= 0 then
			return
		end
		local left = instance.Position.X.Offset - m.Glow
		local right = instance.Position.X.Offset + instance.Size.X.Offset + m.Glow
		local target = current.X
		if left < target then
			target = left
		elseif right > target + view then
			target = right - view
		end
		target = math.max(0, target)
		if target ~= current.X then
			scroller.CanvasPosition = Vector2.new(target, 0)
		end
	end

	function self.Tile(key)
		local slotIndex = assign[key]
		if slotIndex == nil then
			return nil
		end
		return slots[slotIndex].Tile
	end

	-- The heading and its count, without a Set patch: SetHeading("Wing", "2/4").
	function self.SetHeading(text, count)
		if destroyed then
			return
		end
		local nextHeading = text or false
		local nextCount = count or false
		if (state.Heading or false) == nextHeading and (state.Count or false) == nextCount then
			return
		end
		state.Heading = nextHeading
		state.Count = nextCount
		layout()
	end

	function self.Set(patch)
		if type(patch) == "table" then
			checkSelectOn(patch.SelectOn)
		end
		if destroyed or not mergePatch("Rail", RAIL_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		if patch.CellWidth ~= nil then
			for _, slot in ipairs(slots) do
				slot.Render()
			end
		end
		layout()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		group.Destroy()
		release(bag)
		root:Destroy()
	end

	listen(scope, bag, heading.Instance:GetPropertyChangedSignal("Size"), layout)
	listen(scope, bag, root:GetPropertyChangedSignal("AbsoluteSize"), function()
		if lanes() > 1 then
			layout()
		end
	end)
	listen(scope, bag, Text.ReadyChanged, layout)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, layout)
	end

	applyCommon(root, state)
	layout()
	root.Parent = parent

	return self
end

---------------------------------------------------------------------------------------------------
-- ListRow
---------------------------------------------------------------------------------------------------

local ROW_KEYS = keySet({
	"Title", "Sub", "Image", "Right", "Tier", "State", "Locked", "MarkKey", "OnActivated",
	"Chip", "ChipKind", "Height", "Columns", "Accent", "PictureMode", "TierSide",
})
local ROW_DEFAULTS = { Title = "", State = "Default" }

-- Pure. Where column `index` of `count` sits in a row: X and Width as UDim, and whether its text is right
-- aligned. With three or more columns the first is a fixed narrow one (a position number) of `first` px; the
-- others share the rest equally; the last is right aligned. Rows and a List header use the same boxes.
function Collections._columnBox(index, count, pad, gap, first)
	local lead = count >= 3 and first or 0
	if lead > 0 and index == 1 then
		return UDim.new(0, pad), UDim.new(0, lead), false
	end
	local base = pad + (lead > 0 and lead + gap or 0)
	local flexible = count - (lead > 0 and 1 or 0)
	local position = index - (lead > 0 and 2 or 1)
	local share = 1 / flexible
	local x = UDim.new(position * share, math.floor(base - position * share * (base + pad) + HALF))
	local trailing = position < flexible - 1 and gap or 0
	local width = UDim.new(share, -math.floor(share * (base + pad) + HALF) - trailing)
	return x, width, count > 1 and index == count
end

-- host (a List only): NoGlow, WidthInset() -> real px taken off the row width, Activated(), Focused(),
-- Dense() -> true when the row height has no touch-size floor (a display-only list).
-- Returns the component, a whole-props replace function and a re-render function.
local function buildRow(parent, props, scope, host)
	local state = readProps("ListRow", ROW_KEYS, ROW_DEFAULTS, props)
	checkRowPicture(state.PictureMode)
	checkTierSide(state.TierSide)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false }
	local destroyed = false
	local marked = nil

	local root = newButton(state.Name or "ListRow")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	local fill = newFrame(root, "Fill")
	fill.Size = UDim2.new(1, 0, 1, 0)
	local line = newFrame(fill, "HairBottom")
	line.ZIndex = 2
	local lineGradient = newLineGradient(line)
	local title = newText(fill, "Title")
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local picture, sub, right, tierLetter, lock, chip, accent = nil, nil, nil, nil, nil, nil, nil
	local cover = nil -- the wide picture, made the first time PictureMode asks for one
	local extra = {} -- [column index] = label, for the columns between the first and the last
	local glow = nil
	if not (host and host.NoGlow) then
		glow = newGlow(root, scope, bag, "Tile")
		glow.Size = UDim2.new(1, 0, 1, 0)
	end

	local render

	local function textPart(name)
		local label = newText(fill, name)
		listen(scope, bag, label:GetPropertyChangedSignal("TextBounds"), function()
			render()
		end)
		return label
	end

	local function hide(object)
		if object ~= nil then
			put(object, "Visible", false)
		end
	end

	-- Results and leaderboard rows: fixed column texts in place of the title, sub-line, picture and right text.
	local function renderColumns(columns, look, pad, gap)
		local opacity = look.Opacity
		local count = #columns
		local first = ctx.Px(unit(ctx, Space.BadgeLarge))
		local nameColumn = count >= 3 and 2 or 1
		hide(picture)
		hideCover(cover)
		hide(sub)
		hide(tierLetter)
		hide(chip)
		if lock ~= nil then
			lock.Set({ Visible = false })
		end
		for index = 1, count do
			local label
			if index == 1 then
				label = title
			elseif index == count then
				right = right or textPart("Right")
				label = right
			else
				label = extra[index]
				if label == nil then
					label = textPart("Column" .. index)
					extra[index] = label
				end
			end
			local x, width, alignRight = Collections._columnBox(index, count, pad, gap, first)
			put(label, "Text", string.upper(tostring(columns[index])))
			local textSize = face(label, index == nameColumn and "TileNameSmall" or "Value", ctx)
			put(label, "TextTruncate", Enum.TextTruncate.AtEnd)
			put(label, "TextXAlignment", alignRight and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left)
			put(label, "AnchorPoint", Vector2.new(0, 0))
			put(label, "Position", UDim2.new(x.Scale, x.Offset, 0, -baselineShift(textSize)))
			put(label, "Size", UDim2.new(width.Scale, width.Offset, 1, 0))
			put(label, "TextColor3", colourOf(alignRight and look.Sub or look.Ink))
			put(label, "TextTransparency", 1 - opacity)
			put(label, "Visible", true)
		end
		if count == 1 then
			hide(right)
		end
		for index, label in pairs(extra) do
			if index >= count then
				put(label, "Visible", false)
			end
		end
	end

	render = function()
		if destroyed then
			return
		end
		flags.Selectable = nil
		local look = Collections._resolveTile(state.State, state.Locked == true and "Locked" or "None", flags)
		local compact = isCompact(ctx)
		if compact then
			-- The Compact tile's rule: never the White fill. A selected row is an opaque Slate plate with light
			-- text and keeps the thick Pink to Violet base line (and the Pink left bar of an Accent row).
			look = Collections._compactTile(look, flags, false)
		end
		local opacity = look.Opacity
		local pad = ctx.Px(unit(ctx, Space.Pad))
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local hair = ctx.Hair(unit(ctx, Space.Hairline))
		local height = ctx.Px(state.Height or (compact and Space.TouchMin or Space.ListRowHeight))
		if not (host and host.Dense and host.Dense()) then
			height = math.max(height, ctx.Touch(1))
		end

		if hasWidth(parent) then
			local inset = host and host.WidthInset and host.WidthInset() or 0
			put(root, "Size", UDim2.new(1, -inset, 0, height))
		else
			put(root, "Size", UDim2.fromOffset(ctx.Px(unit(ctx, Space.ListWidth)), height))
		end
		put(fill, "BackgroundColor3", colourOf(look.Fill))
		put(fill, "BackgroundTransparency", 1 - look.FillOpacity)

		local lineHeight = hair
		if look.Selected then
			-- Compact: the Compact tile's 4 dp line (the plate no longer changes colour, the line carries it).
			lineHeight = compact and ctx.Px(Space.Hairline + Space.Hairline) or ctx.Hair(unit(ctx, Space.TileBaseLine))
		end
		put(line, "Position", UDim2.new(0, 0, 1, -lineHeight))
		put(line, "Size", UDim2.new(1, 0, 0, lineHeight))
		paintLine(line, lineGradient, look)

		-- The Pink left bar of "your row".
		if state.Accent == true then
			if accent == nil then
				accent = newFrame(fill, "Accent")
				accent.BackgroundColor3 = colourOf("Pink")
				accent.ZIndex = 2
			end
			put(accent, "Size", UDim2.new(0, ctx.Hair(unit(ctx, Space.TileBaseLine)), 1, 0))
			put(accent, "BackgroundTransparency", 1 - opacity)
			put(accent, "Visible", true)
		else
			hide(accent)
		end

		if glow ~= nil then
			put(glow, "Visible", look.Glow)
		end
		put(root, "Active", look.Active)

		local columns = state.Columns
		if type(columns) == "table" and #columns > 0 then
			renderColumns(columns, look, pad, gap)
			return
		end
		for _, label in pairs(extra) do
			put(label, "Visible", false)
		end

		-- Left: picture, then the tier letter.
		local x = pad
		local image = textOf(state.Image)
		if image and state.PictureMode == "Wide" then
			-- The whole picture in a box of its own shape, as tall as the row (the square crop cut a car's nose and
			-- tail off).
			cover = cover or newCover(fill)
			local pictureHeight = height - lineHeight
			local pictureWidth = math.floor(pictureHeight * PICTURE_ASPECT + HALF)
			placeCover(cover, image, pictureWidth, pictureHeight, opacity, true)
			hide(picture)
			x = pictureWidth + pad
		elseif image then
			if picture == nil then
				picture = Instance.new("ImageLabel")
				picture.Name = "Image"
				picture.BackgroundTransparency = 1
				picture.BorderSizePixel = 0
				picture.ScaleType = Enum.ScaleType.Crop
				picture.Parent = fill
			end
			put(picture, "Image", image)
			put(picture, "Size", UDim2.fromOffset(height, height - lineHeight))
			put(picture, "ImageTransparency", 1 - opacity)
			put(picture, "Visible", true)
			hideCover(cover)
			x = height + pad
		else
			hide(picture)
			hideCover(cover)
		end

		-- TierSide "Right": the tier letter and the sub-line leave the left and stand at the right edge (placed
		-- below, after the lock); the name is then alone between the picture and them.
		local metaRight = state.TierSide == "Right"
		local metaBadgeWidth, metaBadgeHeight = 0, 0
		local tier = textOf(state.Tier)
		if tier then
			tierLetter = tierLetter or textPart("TierLetter")
			local badgeDesign, badgeRole = Collections._badgeSize(compact and "Small" or "Medium")
			put(tierLetter, "Text", tier)
			local badgeSize = face(tierLetter, badgeRole, ctx)
			local badgeHeight = badgePx(ctx, badgeDesign, badgeSize)
			local letterWidth = math.max(math.floor(badgeHeight * BADGE_LETTER + HALF), textWidth(tierLetter) + hair + hair)
			local badgeOpacity = look.BadgeDim and math.min(Opacity.Locked, opacity) or opacity
			put(tierLetter, "TextXAlignment", Enum.TextXAlignment.Center)
			put(tierLetter, "Size", UDim2.fromOffset(letterWidth, badgeHeight))
			put(tierLetter, "BackgroundColor3", tierColour(tier))
			put(tierLetter, "BackgroundTransparency", 1 - badgeOpacity)
			put(tierLetter, "TextColor3", colourOf("Ink"))
			put(tierLetter, "TextTransparency", 1 - badgeOpacity)
			put(tierLetter, "Visible", true)
			if metaRight then
				metaBadgeWidth, metaBadgeHeight = letterWidth, badgeHeight
			else
				put(tierLetter, "AnchorPoint", Vector2.new(0, 0))
				put(tierLetter, "Position", UDim2.fromOffset(x, math.floor((height - badgeHeight) * HALF)))
				x = x + letterWidth + gap
			end
		else
			hide(tierLetter)
		end

		-- Right, from the edge inward: the lock, the chip, then the right-hand text.
		local reserve = pad
		if look.Lock then
			local lockDesign = unit(ctx, Space.BadgeSmall)
			local lockPx = ctx.Px(lockDesign)
			if lock == nil then
				lock = Surface.Icon(fill, { Name = "Lock", Icon = "lock", Colour = look.Ink, Size = lockDesign }, scope)
				table.insert(bag, lock)
			end
			lock.Set({ Colour = look.Ink, Size = lockDesign, Opacity = opacity, Visible = true })
			put(lock.Instance, "AnchorPoint", Vector2.new(1, 0))
			put(lock.Instance, "Position", UDim2.new(1, -reserve, 0, math.floor((height - lockPx) * HALF)))
			reserve = reserve + lockPx + gap
		elseif lock ~= nil then
			lock.Set({ Visible = false })
		end

		-- The sub-line is measured here: with TierSide "Right" it is part of the right-hand block.
		local subText = textOf(state.Sub)
		local subSize = 0
		if subText then
			sub = sub or textPart("Sub")
			put(sub, "Text", string.upper(subText))
			subSize = face(sub, "Label", ctx)
		end
		local subRight = metaRight and subText ~= nil
		if subRight then
			put(sub, "TextTruncate", Enum.TextTruncate.None) -- measured whole, like the right-hand text
		end

		local chipText = textOf(state.Chip)
		local chipWidth, chipHeight = 0, 0
		if chipText then
			chip = chip or textPart("Chip")
			local kind = state.ChipKind or "Neutral"
			local chipFill, chipOpacity, chipInk = Collections._resolveChip(kind, false)
			if kind == "Neutral" then
				chipFill, chipOpacity, chipInk = look.ChipFill, look.ChipFillOpacity, look.ChipInk
			end
			chipWidth, chipHeight = boxText(chip, string.upper(chipText), kind == "Price" and "Value" or "Label", ctx, Space.BadgeMedium, Space.Gap)
			put(chip, "AnchorPoint", Vector2.new(1, 0))
			put(chip, "Size", UDim2.fromOffset(chipWidth, chipHeight))
			put(chip, "BackgroundColor3", colourOf(chipFill))
			put(chip, "BackgroundTransparency", 1 - chipOpacity * opacity)
			put(chip, "TextColor3", colourOf(chipInk))
			put(chip, "TextTransparency", 1 - opacity)
			put(chip, "Visible", true)
		else
			hide(chip)
		end

		-- The right-hand block of TierSide "Right": the sub-line then the tier letter on one line, both against the
		-- right edge. A chip goes under that line when the row is tall enough for the two, else beside it as usual.
		local metaWidth, metaHeight, metaTop, chipTop = 0, 0, 0, nil
		if metaRight and (tier ~= nil or subRight) then
			local subWidth = subRight and textWidth(sub) or 0
			metaHeight = tier and metaBadgeHeight or subSize
			metaWidth = metaBadgeWidth + ((tier ~= nil and subRight) and gap or 0) + subWidth
			metaTop = math.floor((height - metaHeight) * HALF)
			if chipText and metaHeight + gap + chipHeight <= height - lineHeight then
				metaTop = math.floor((height - metaHeight - gap - chipHeight) * HALF)
				chipTop = metaTop + metaHeight + gap
				metaWidth = math.max(metaWidth, chipWidth)
			end
		end
		if chipText then
			put(chip, "Position", UDim2.new(1, -reserve, 0, chipTop or math.floor((height - chipHeight) * HALF)))
			if chipTop == nil then
				reserve = reserve + chipWidth + gap
			end
		end
		if metaWidth > 0 then
			local edge = reserve
			if tier then
				put(tierLetter, "AnchorPoint", Vector2.new(1, 0))
				put(tierLetter, "Position", UDim2.new(1, -edge, 0, metaTop))
				edge = edge + metaBadgeWidth + gap
			end
			if subRight then
				put(sub, "TextXAlignment", Enum.TextXAlignment.Right)
				put(sub, "AnchorPoint", Vector2.new(1, 0))
				put(sub, "Position", UDim2.new(1, -edge, 0, metaTop + math.floor((metaHeight - subSize) * HALF)))
				put(sub, "Size", UDim2.fromOffset(textWidth(sub), subSize))
				put(sub, "TextColor3", colourOf(look.Sub))
				put(sub, "TextTransparency", 1 - opacity)
				put(sub, "Visible", true)
			end
			reserve = reserve + metaWidth + gap
		end

		local rightText = textOf(state.Right)
		if rightText then
			right = right or textPart("Right")
			put(right, "Text", string.upper(rightText))
			local rightSize = face(right, "Value", ctx)
			local rightWidth = textWidth(right)
			put(right, "TextTruncate", Enum.TextTruncate.None)
			put(right, "TextXAlignment", Enum.TextXAlignment.Right)
			put(right, "AnchorPoint", Vector2.new(1, 0))
			put(right, "Position", UDim2.new(1, -reserve, 0, -baselineShift(rightSize)))
			put(right, "Size", UDim2.new(0, rightWidth, 1, 0))
			put(right, "TextColor3", colourOf(look.Sub))
			put(right, "TextTransparency", 1 - opacity)
			put(right, "Visible", true)
			reserve = reserve + rightWidth + gap
		else
			hide(right)
		end

		-- Middle: sub-line above the title, the pair centred on the row.
		put(title, "Text", string.upper(tostring(state.Title)))
		local titleSize = face(title, "TileNameSmall", ctx)
		if subRight then
			subSize = 0 -- the sub-line is at the right: the name is centred on its own
		end
		local top = math.floor((height - subSize - titleSize) * HALF)
		if subRight then
			-- placed above
		elseif subText then
			put(sub, "TextTruncate", Enum.TextTruncate.AtEnd)
			put(sub, "TextXAlignment", Enum.TextXAlignment.Left)
			put(sub, "AnchorPoint", Vector2.new(0, 0))
			put(sub, "Position", UDim2.fromOffset(x, top))
			put(sub, "Size", UDim2.new(1, -(x + reserve), 0, subSize))
			put(sub, "TextColor3", colourOf(look.Sub))
			put(sub, "TextTransparency", 1 - opacity)
			put(sub, "Visible", true)
		else
			hide(sub)
		end
		put(title, "TextXAlignment", Enum.TextXAlignment.Left)
		put(title, "Position", UDim2.fromOffset(x, top + subSize - baselineShift(titleSize)))
		put(title, "Size", UDim2.new(1, -(x + reserve), 0, titleSize))
		put(title, "TextColor3", colourOf(look.Ink))
		put(title, "TextTransparency", 1 - opacity)
		put(title, "Visible", true)
	end

	local function mark()
		local key = textOf(state.MarkKey)
		if key and key ~= marked then
			marked = key
			Input.Mark(root, key)
		end
	end

	listen(scope, bag, root.MouseEnter, function()
		if ctx.Input ~= "Touch" then
			flags.Hover = true
			render()
		end
	end)
	listen(scope, bag, root.MouseLeave, function()
		flags.Hover = false
		flags.Pressed = false
		render()
	end)
	listen(scope, bag, root.MouseButton1Down, function()
		flags.Pressed = true
		render()
	end)
	listen(scope, bag, root.MouseButton1Up, function()
		flags.Pressed = false
		render()
	end)
	listen(scope, bag, root.Activated, function()
		if not root.Active then
			return
		end
		if host and host.Activated then
			host.Activated()
		end
		local callback = state.OnActivated
		if callback then
			callback()
		end
	end)
	listen(scope, bag, Text.ReadyChanged, render)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, render)
	end
	Input.Focusable(root, {
		OnFocus = function(focused)
			flags.Focused = focused == true
			render()
			if flags.Focused and not destroyed and host and host.Focused then
				host.Focused()
			end
		end,
	})

	applyCommon(root, state)
	render()
	mark()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
		if type(patch) == "table" then
			checkRowPicture(patch.PictureMode)
			checkTierSide(patch.TierSide)
		end
		if destroyed or not mergePatch("ListRow", ROW_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil and marked == nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		render()
		mark()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		release(bag)
		root:Destroy()
	end

	-- Replaces every prop (a pooled row takes over another item). Writes only what differs.
	local function replace(nextProps)
		if destroyed then
			return
		end
		local fresh = readProps("ListRow", ROW_KEYS, ROW_DEFAULTS, nextProps)
		checkRowPicture(fresh.PictureMode)
		checkTierSide(fresh.TierSide)
		local changed = false
		for key in pairs(ROW_KEYS) do
			if state[key] ~= fresh[key] then
				changed = true
				break
			end
		end
		if not changed then
			return
		end
		state = fresh
		if marked == nil then
			put(root, "Name", state.Name or "ListRow")
		end
		applyCommon(root, state)
		render()
		mark()
	end

	return self, replace, render
end

function Collections.ListRow(parent, props, scope)
	local row = buildRow(parent, props, scope, nil)
	return row
end

---------------------------------------------------------------------------------------------------
-- List (a vertical keyed pool of ListRows)
---------------------------------------------------------------------------------------------------

-- OnSelected(key) and OnActivated(key): the Rail rule (selection change against every activation).
-- Dense = true (opt-in): the rows have no touch-size floor, for a display-only list nobody presses (a
-- leaderboard, a results table); give it a RowHeight, the default row height is the touch size on Compact.
local LIST_KEYS = keySet({ "RowHeight", "Width", "Header", "OnSelected", "OnActivated", "Dense" })

function Collections.List(parent, props, scope)
	local state = readProps("List", LIST_KEYS, {}, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false

	local slots = {} -- [index] = { Row, Replace, Render, Key }
	local assign = {} -- key -> slot index
	local order = {} -- slot index of each item, in item order
	local items = {} -- key -> item
	local selected = nil
	local headerLabels = {}
	local group = Input.FocusGroup(scope, nil)

	local root = Instance.new("Frame")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	root.Name = state.Name or "List"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	local header = newFrame(root, "Header")

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Scroller"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.ScrollBarThickness = 0
	scroller.Selectable = false
	scroller.CanvasSize = UDim2.fromOffset(0, 0)
	scroller.Parent = root

	-- One glow for the whole list, moved to the selected row (a row in a list has none of its own).
	local selection = newFrame(scroller, "Selection")
	selection.ZIndex = 0
	selection.Visible = false
	local glow = Surface.Glow(selection, { Name = "Glow", Kind = "Tile", Colour = "Pink" }, scope)
	table.insert(bag, glow)

	local function metrics()
		local row = ctx.Px(state.RowHeight or (isCompact(ctx) and Space.TouchMin or Space.ListRowHeight))
		if state.Dense ~= true then
			row = math.max(row, ctx.Touch(1))
		end
		return {
			Glow = ctx.Px(unit(ctx, Space.GlowTileRadius)),
			Gap = ctx.Px(unit(ctx, Space.Hairline + Space.Hairline)),
			Row = row,
		}
	end

	local function layoutHeader()
		local columns = state.Header
		local count = type(columns) == "table" and #columns or 0
		local height = 0
		if count > 0 then
			local pad = ctx.Px(unit(ctx, Space.Pad))
			local gap = ctx.Px(unit(ctx, Space.Gap))
			local first = ctx.Px(unit(ctx, Space.BadgeLarge))
			for index = 1, count do
				local label = headerLabels[index]
				if label == nil then
					label = newText(header, "Column" .. index)
					headerLabels[index] = label
				end
				local x, width, alignRight = Collections._columnBox(index, count, pad, gap, first)
				put(label, "Text", string.upper(tostring(columns[index])))
				local textSize = face(label, "Label", ctx)
				put(label, "TextTruncate", Enum.TextTruncate.AtEnd)
				put(label, "TextXAlignment", alignRight and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left)
				put(label, "Position", UDim2.new(x.Scale, x.Offset, 0, 0))
				put(label, "Size", UDim2.new(width.Scale, width.Offset, 0, textSize))
				put(label, "TextColor3", colourOf("TextMuted"))
				put(label, "Visible", true)
				height = textSize + gap
			end
		end
		for index = count + 1, #headerLabels do
			put(headerLabels[index], "Visible", false)
		end
		put(header, "Size", UDim2.new(1, 0, 0, height))
		put(header, "Visible", count > 0)
		return height
	end

	local function layout()
		if destroyed then
			return
		end
		local m = metrics()
		local headHeight = layoutHeader()

		local scaleX, offsetX = 1, 0
		if state.Width then
			scaleX, offsetX = 0, ctx.Px(state.Width)
		elseif not hasWidth(parent) then
			scaleX, offsetX = 0, ctx.Px(unit(ctx, Space.ListWidth))
		end

		-- The scroller is larger than the rows by the glow radius, so the glow of the selected row is not clipped.
		local y = m.Glow
		local selectedShown = false
		local shownHeight = 0
		for index, slotIndex in ipairs(order) do
			local slot = slots[slotIndex]
			local instance = slot.Row.Instance
			local rowHeight = instance.Size.Y.Offset
			if index > 1 then
				y = y + m.Gap
			end
			put(instance, "Position", UDim2.fromOffset(m.Glow, y))
			if slot.Key == selected then
				selectedShown = true
				put(selection, "Position", UDim2.fromOffset(m.Glow, y))
				put(selection, "Size", UDim2.new(1, -(m.Glow + m.Glow), 0, rowHeight))
			end
			y = y + rowHeight
			if index <= LIST_ROWS then
				shownHeight = y - m.Glow
			end
		end
		put(selection, "Visible", selectedShown)
		put(scroller, "CanvasSize", UDim2.fromOffset(0, y + m.Glow))

		local fills = hasHeight(parent)
		put(root, "Size", UDim2.new(scaleX, offsetX, fills and 1 or 0, fills and 0 or headHeight + shownHeight))
		put(scroller, "Position", UDim2.fromOffset(-m.Glow, headHeight - m.Glow))
		put(scroller, "Size", UDim2.new(1, m.Glow + m.Glow, 1, m.Glow + m.Glow - headHeight))
	end

	local self = { Instance = root }

	local function setSelected(key)
		if selected == key then
			return false
		end
		local previous = selected
		selected = key
		if previous ~= nil and assign[previous] ~= nil then
			slots[assign[previous]].Row.Set({ State = "Default" })
		end
		if key ~= nil and assign[key] ~= nil then
			slots[assign[key]].Row.Set({ State = "Selected" })
		end
		layout()
		if key ~= nil then
			self.ScrollTo(key)
		end
		return true
	end

	-- A click or a focus move: select, then tell the owner.
	local function choose(key)
		if destroyed or key == nil or items[key] == nil then
			return
		end
		if setSelected(key) then
			local callback = state.OnSelected
			if callback then
				callback(key)
			end
		end
	end

	local function createSlot()
		local slot = { Key = nil }
		local row, replace, render = buildRow(scroller, { Visible = false }, scope, {
			NoGlow = true,
			WidthInset = function()
				local radius = ctx.Px(unit(ctx, Space.GlowTileRadius))
				return radius + radius
			end,
			Dense = function()
				return state.Dense == true
			end,
			Activated = function()
				local key = slot.Key
				choose(key)
				local callback = state.OnActivated
				if callback and not destroyed and key ~= nil and items[key] ~= nil then
					callback(key)
				end
			end,
			Focused = function()
				choose(slot.Key)
			end,
		})
		row.Instance.ZIndex = 1
		slot.Row = row
		slot.Replace = replace
		slot.Render = render
		table.insert(bag, row)
		listen(scope, bag, row.Instance:GetPropertyChangedSignal("Size"), layout)
		return slot
	end

	local function rowProps(key)
		local item = items[key]
		local copy = {}
		for name, value in pairs(item) do
			if name ~= "Key" then
				copy[name] = value
			end
		end
		if copy.Height == nil then
			copy.Height = state.RowHeight
		end
		copy.State = key == selected and "Selected" or "Default"
		copy.Visible = true
		return copy
	end

	function self.SetItems(list)
		if destroyed then
			return
		end
		local keys = {}
		local nextItems = {}
		for index, item in ipairs(list) do
			local key = type(item) == "table" and item.Key or nil
			if type(key) ~= "string" or key == "" then
				error("[Pulse.Collections] List.SetItems: every item needs a string Key", 2)
			end
			keys[index] = key
			nextItems[key] = item
		end
		local nextAssign, nextOrder, count = Collections._planPool(assign, #slots, keys)
		for index = #slots + 1, count do
			slots[index] = createSlot()
		end
		assign, order, items = nextAssign, nextOrder, nextItems
		if selected ~= nil and items[selected] == nil then
			selected = nil
		end
		if selected == nil then
			for _, key in ipairs(keys) do
				if items[key].State == "Selected" then
					selected = key
					break
				end
			end
		end
		local used = {}
		for index, key in ipairs(keys) do
			local slotIndex = order[index]
			local slot = slots[slotIndex]
			used[slotIndex] = true
			slot.Key = key
			slot.Replace(rowProps(key))
			group.Add(slot.Row.Instance, index)
		end
		for index, slot in ipairs(slots) do
			if not used[index] then
				slot.Key = nil
				slot.Row.Set({ Visible = false })
				group.Remove(slot.Row.Instance)
			end
		end
		layout()
	end

	function self.Select(key)
		if destroyed then
			return
		end
		if items[key] == nil then
			error("[Pulse.Collections] List.Select: unknown key " .. tostring(key), 2)
		end
		setSelected(key)
	end

	function self.ScrollTo(key)
		local slotIndex = assign[key]
		if destroyed or slotIndex == nil then
			return
		end
		local view = scroller.AbsoluteSize.Y
		if view <= 0 then
			return
		end
		local m = metrics()
		local instance = slots[slotIndex].Row.Instance
		local top = instance.Position.Y.Offset - m.Glow
		local bottom = instance.Position.Y.Offset + instance.Size.Y.Offset + m.Glow
		local current = scroller.CanvasPosition.Y
		local target = current
		if top < current then
			target = top
		elseif bottom > current + view then
			target = bottom - view
		end
		target = math.max(0, target)
		if target ~= current then
			scroller.CanvasPosition = Vector2.new(0, target)
		end
	end

	function self.Row(key)
		local slotIndex = assign[key]
		if slotIndex == nil then
			return nil
		end
		return slots[slotIndex].Row
	end

	function self.Set(patch)
		if destroyed or not mergePatch("List", LIST_KEYS, state, patch) then
			return
		end
		if patch.Name ~= nil then
			put(root, "Name", patch.Name)
		end
		applyCommon(root, state)
		if patch.RowHeight ~= nil then
			for _, slot in ipairs(slots) do
				if slot.Key ~= nil then
					slot.Replace(rowProps(slot.Key))
				end
			end
		end
		if patch.Dense ~= nil then
			for _, slot in ipairs(slots) do
				slot.Render() -- the rows read Dense through their host
			end
		end
		layout()
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		group.Destroy()
		release(bag)
		root:Destroy()
	end

	listen(scope, bag, Text.ReadyChanged, layout)
	if ctx.Changed ~= nil then
		listen(scope, bag, ctx.Changed, layout)
	end

	applyCommon(root, state)
	layout()
	root.Parent = parent

	return self
end

---------------------------------------------------------------------------------------------------
-- Pool (for family views that pool something the kit has no component for)
---------------------------------------------------------------------------------------------------

-- make(index) builds item number `index`; reset(item) returns one to its idle state (hidden, still parented).
-- Take reuses a released item before it makes one. Count returns how many were made, then how many are out.
function Collections.Pool(make, reset)
	if type(make) ~= "function" or type(reset) ~= "function" then
		error("[Pulse.Collections] Pool needs a make and a reset function", 2)
	end
	local free = {}
	local out = {}
	local outCount = 0
	local made = 0
	local pool = {}

	function pool.Take()
		local item = table.remove(free)
		if item == nil then
			made = made + 1
			item = make(made)
		end
		out[item] = true
		outCount = outCount + 1
		return item
	end

	function pool.Release(item)
		if not out[item] then
			return
		end
		out[item] = nil
		outCount = outCount - 1
		reset(item)
		table.insert(free, item)
	end

	function pool.ReleaseAll()
		local list = {}
		for item in pairs(out) do
			table.insert(list, item)
		end
		for _, item in ipairs(list) do
			pool.Release(item)
		end
	end

	function pool.Count()
		return made, outCount
	end

	return pool
end

return Collections
