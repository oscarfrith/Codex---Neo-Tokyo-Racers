-- Owns the Pulse Tile, Rail (with its keyed tile pool), ListRow, Chip and TierBadge components; it does not own selection rules of a screen, money formatting, focus rules or any screen's layout.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Kit.Collections. Requires: Tokens, Metrics, Text, Surface, Input.
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
local VISUAL_HEIGHT_COMPACT = 0.3 -- the same on a Compact tile (18 of 60)
local BADGE_LETTER = 0.9 -- tier letter cell width against the badge height (42 of 46)
local TWO_LINES = 1.5 -- text taller than this many lines' worth is laid out as two lines

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

local function fadeIcon(component, transparency)
	local instance = component.Instance
	if instance:IsA("ImageLabel") then
		put(instance, "ImageTransparency", transparency)
	end
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

-- Pure. state: "Default" | "Selected". status: Tile status. flags: Hover, Pressed, Focused.
-- Controller focus shows the selected look.
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
		look.Active = false
		look.Opacity = Opacity.Locked
		look.Lock = true
		look.BadgeDim = true
		look.PriceInk = "TextMuted"
	elseif status == "Unaffordable" then
		look.Active = false
		look.BadgeDim = true
		look.PriceInk = "TextMuted"
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

-- Pure. What the top-right corner of a tile shows: text and "Price" or "Neutral"; nil when nothing.
function Collections._corner(status, price, chipRight)
	local right = textOf(chipRight)
	local cost = textOf(price)
	if status == "Owned" or status == "Fitted" then
		return right or string.upper(status), "Neutral"
	elseif cost then
		return cost, "Price"
	elseif right then
		return right, "Neutral"
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
		local opacity = state.Dim == true and Opacity.TabLocked or 1

		put(letter, "Text", state.Tier)
		local textSize = face(letter, role, ctx)
		local height = math.max(ctx.Px(unit(ctx, design)), textSize)
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
})
local TILE_DEFAULTS = { Title = "", State = "Default", Status = "None" }

-- host (a Rail only): CellWidth() -> design width or nil, NoGlow, Activated(), Focused().
-- Returns the component, a whole-props replace function and a re-render function.
local function buildTile(parent, props, scope, host)
	local state = readProps("Tile", TILE_KEYS, TILE_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false }
	local destroyed = false
	local marked = nil

	local root = newButton(state.Name or "Tile")
	local fill = newFrame(root, "Fill")
	local line = newFrame(fill, "BaseLine")
	local visual = Instance.new("ImageLabel")
	visual.Name = "Visual"
	visual.BackgroundTransparency = 1
	visual.BorderSizePixel = 0
	visual.ScaleType = Enum.ScaleType.Fit
	visual.Parent = fill
	local untinted = visual.ImageColor3 -- the engine default: a picture is drawn in its own colours
	local title = newText(fill, "Title")
	title.TextYAlignment = Enum.TextYAlignment.Bottom

	local sub, chipLeft, corner, tierLetter, tierRating, lock, glow = nil, nil, nil, nil, nil, nil, nil
	if not (host and host.NoGlow) then
		glow = Surface.Glow(fill, { Name = "Glow", Kind = "Tile", Colour = "Pink", Visible = false }, scope)
		table.insert(bag, glow)
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

	render = function()
		if destroyed then
			return
		end
		local look = Collections._resolveTile(state.State, state.Status, flags)
		local compact = isCompact(ctx)
		local seven = state.Compact7 == true
		local inset = ctx.Px(unit(ctx, Space.Pad * TILE_INSET))
		local hair = ctx.Hair(unit(ctx, Space.Hairline))
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local opacity = look.Opacity

		-- Title text first: a Compact tile sizes to its name.
		put(title, "Text", string.upper(tostring(state.Title)))
		local titleSize = face(title, (compact or seven) and "TileNameSmall" or "TileName", ctx)

		local cellDesign = host and host.CellWidth and host.CellWidth() or nil
		local width, height
		if compact then
			height = ctx.Px(Space.TouchMin + Space.CompactMargin)
			if cellDesign then
				width = ctx.Px(cellDesign)
			else
				width = math.max(ctx.Px(Space.CompactTileMinWidth), textWidth(title) + inset + inset)
			end
		else
			height = ctx.Px(Space.TileHeight)
			width = ctx.Px(cellDesign or (seven and Space.TileWidth * SEVEN_WIDTH or Space.TileWidth))
		end

		local grow = 0
		if look.Grow then
			grow = ctx.Px(compact and Space.TileBaseLine or (Space.Gap + Space.TileBaseLine))
		end
		local fillHeight = height + grow
		put(root, "Size", UDim2.fromOffset(width, height))
		put(fill, "Position", UDim2.fromOffset(0, -grow))
		put(fill, "Size", UDim2.fromOffset(width, fillHeight))
		put(fill, "BackgroundColor3", colourOf(look.Fill))
		put(fill, "BackgroundTransparency", 1 - look.FillOpacity)

		local lineHeight = look.Selected and ctx.Hair(unit(ctx, Space.TileBaseLine)) or hair
		put(line, "Position", UDim2.fromOffset(0, fillHeight - lineHeight))
		put(line, "Size", UDim2.fromOffset(width, lineHeight))
		put(line, "BackgroundColor3", colourOf(look.Line))
		put(line, "BackgroundTransparency", 1 - look.LineOpacity)

		-- Title, bottom of the tile.
		local titleTop
		if compact then
			titleTop = fillHeight - inset - titleSize
			put(title, "TextWrapped", false)
			put(title, "TextXAlignment", Enum.TextXAlignment.Center)
			put(title, "Position", UDim2.fromOffset(0, titleTop))
			put(title, "Size", UDim2.fromOffset(width, titleSize))
		else
			local lines = title.TextBounds.Y > titleSize * TWO_LINES and 2 or 1
			local titleHeight = titleSize * lines
			titleTop = fillHeight - inset - titleHeight
			put(title, "TextWrapped", true)
			put(title, "TextXAlignment", Enum.TextXAlignment.Left)
			put(title, "Position", UDim2.fromOffset(inset, titleTop))
			put(title, "Size", UDim2.fromOffset(math.max(0, width - inset - inset), titleHeight))
		end
		put(title, "TextColor3", colourOf(look.Ink))
		put(title, "TextTransparency", 1 - opacity)

		-- Sub-line above the title (Regular only).
		local subText = (not compact) and textOf(state.Sub) or nil
		if subText then
			sub = sub or textPart("Sub")
			put(sub, "Text", string.upper(subText))
			local subSize = face(sub, "Label", ctx)
			put(sub, "TextTruncate", Enum.TextTruncate.AtEnd)
			put(sub, "Position", UDim2.fromOffset(inset, titleTop - subSize))
			put(sub, "Size", UDim2.fromOffset(math.max(0, width - inset - inset), subSize))
			put(sub, "TextColor3", colourOf(look.Sub))
			put(sub, "TextTransparency", 1 - opacity)
			put(sub, "Visible", true)
		elseif sub ~= nil then
			put(sub, "Visible", false)
		end

		-- Top-left: tier badge, then the variant or index chip.
		local edge = compact and 0 or inset
		local x = edge
		local tier = textOf(state.Tier)
		local badgeOpacity = look.BadgeDim and math.min(Opacity.TabLocked, opacity) or opacity
		if tier then
			tierLetter = tierLetter or textPart("TierLetter")
			local badgeDesign, badgeRole = Collections._badgeSize(compact and "Small" or "Large")
			put(tierLetter, "Text", tier)
			local badgeSize = face(tierLetter, badgeRole, ctx)
			local badgeHeight = math.max(ctx.Px(unit(ctx, badgeDesign)), badgeSize)
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

		local leftText = (not compact) and textOf(state.ChipLeft) or nil
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
		local cornerText, cornerKind = Collections._corner(state.Status, state.Price, state.ChipRight)
		if cornerText then
			corner = corner or textPart("Corner")
			local price = cornerKind == "Price"
			local chipWidth, chipHeight = boxText(corner, string.upper(cornerText), price and "Value" or "Label", ctx, Space.BadgeMedium, Space.Gap)
			put(corner, "Position", UDim2.fromOffset(width - chipWidth, 0))
			put(corner, "Size", UDim2.fromOffset(chipWidth, chipHeight))
			if price then
				paintBox(corner, "Ink", 1, look.PriceInk, opacity)
			else
				paintBox(corner, look.ChipFill, look.ChipFillOpacity, look.ChipInk, opacity)
			end
			put(corner, "Visible", true)
		elseif corner ~= nil then
			put(corner, "Visible", false)
		end

		-- Picture: the card image, else a glyph from the icon sheet, else nothing (plain slate).
		local boxHeight = math.floor(height * (compact and VISUAL_HEIGHT_COMPACT or VISUAL_HEIGHT))
		local boxTop
		if compact then
			boxTop = math.floor((titleTop - grow - boxHeight) * HALF)
		else
			boxTop = math.floor(height * VISUAL_TOP)
		end
		local image = textOf(state.Image)
		local glyph = textOf(state.Icon)
		local boxWidth = boxHeight
		if image then
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
		local drawWidth, drawHeight = boxWidth, boxHeight
		if look.Selected then
			drawWidth = math.floor(boxWidth * Space.TileSelectedGrow + HALF)
			drawHeight = math.floor(boxHeight * Space.TileSelectedGrow + HALF)
		end
		put(visual, "Position", UDim2.fromOffset(math.floor((width - drawWidth) * HALF), centreY - math.floor(drawHeight * HALF)))
		put(visual, "Size", UDim2.fromOffset(drawWidth, drawHeight))
		put(visual, "ImageTransparency", 1 - opacity)

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
			put(lock.Instance, "Position", UDim2.fromOffset(math.floor((width - lockPx) * HALF), centreY - math.floor(lockPx * HALF)))
		elseif lock ~= nil then
			lock.Set({ Visible = false })
		end

		if glow ~= nil then
			glow.Set({ Visible = look.Glow })
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

local RAIL_KEYS = keySet({ "Heading", "Count", "CellWidth", "OnSelected" })

function Collections.Rail(parent, props, scope)
	local state = readProps("Rail", RAIL_KEYS, {}, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local destroyed = false

	local slots = {} -- [index] = { Tile, Replace, Render, Key }
	local assign = {} -- key -> slot index
	local order = {} -- slot index of each item, in item order
	local items = {} -- key -> item
	local selected = nil

	local root = Instance.new("Frame")
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
			Cell = ctx.Px(compact and (Space.TouchMin + Space.CompactMargin) or Space.TileHeight),
		}
	end

	local function layout()
		if destroyed then
			return
		end
		local m = metrics()
		local headHeight, headGap = 0, 0
		local caption = headingText()
		heading.Set({ Text = caption, Visible = caption ~= "" })
		if caption ~= "" then
			local textSize, holderScale = Text.SizeFor("SectionHead", ctx)
			headHeight = math.ceil(textSize * holderScale)
			headGap = ctx.Px(unit(ctx, Space.Gap))
		end
		put(heading.Instance, "Position", UDim2.fromOffset(0, 0))

		-- Width: the parent's, or from a zero-size slot anchor to the right edge of the safe area.
		local scaleX, offsetX = 1, 0
		if not hasWidth(parent) then
			scaleX = 0
			offsetX = math.max(0, math.floor(ctx.Size.X) - parent.Position.X.Offset)
		end
		local rowTop = headHeight + headGap
		put(root, "AnchorPoint", Vector2.new(0, 1))
		put(root, "Position", UDim2.new(0, 0, 1, 0))
		put(root, "Size", UDim2.new(scaleX, offsetX, 0, rowTop + m.Grow + m.Cell))
		-- The scroller is larger than the cells by the glow radius, so the glow and the grown tile are not clipped.
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
	end

	local self = { Instance = root }

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
		local tile, replace, render = buildTile(scroller, { Visible = false }, scope, {
			NoGlow = true,
			CellWidth = function()
				return state.CellWidth or nil
			end,
			Activated = function()
				choose(slot.Key)
			end,
			Focused = function()
				choose(slot.Key)
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
		end
		for index, slot in ipairs(slots) do
			if not used[index] then
				slot.Key = nil
				slot.Tile.Set({ Visible = false })
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
		local size = scroller.Size
		local view = size.X.Scale == 0 and size.X.Offset or scroller.AbsoluteSize.X
		if view <= 0 then
			return
		end
		local instance = slots[slotIndex].Tile.Instance
		local left = instance.Position.X.Offset - m.Glow
		local right = instance.Position.X.Offset + instance.Size.X.Offset + m.Glow
		local current = scroller.CanvasPosition.X
		local target = current
		if left < current then
			target = left
		elseif right > current + view then
			target = right - view
		end
		target = math.max(0, target)
		if target ~= current then
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

	function self.Set(patch)
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
-- ListRow
---------------------------------------------------------------------------------------------------

local ROW_KEYS = keySet({ "Title", "Sub", "Image", "Right", "Tier", "State", "Locked", "MarkKey", "OnActivated" })
local ROW_DEFAULTS = { Title = "", State = "Default" }

function Collections.ListRow(parent, props, scope)
	local state = readProps("ListRow", ROW_KEYS, ROW_DEFAULTS, props)
	local ctx = Metrics.Of(parent)
	local bag = {}
	local flags = { Hover = false, Pressed = false, Focused = false }
	local destroyed = false
	local marked = nil

	local root = newButton(state.Name or "ListRow")
	local fill = newFrame(root, "Fill")
	fill.Size = UDim2.new(1, 0, 1, 0)
	local line = newFrame(fill, "BaseLine")
	local title = newText(fill, "Title")
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local picture, sub, right, tierLetter, lock = nil, nil, nil, nil, nil
	local glow = Surface.Glow(fill, { Name = "Glow", Kind = "Tile", Colour = "Pink", Visible = false }, scope)
	table.insert(bag, glow)

	local render

	local function textPart(name)
		local label = newText(fill, name)
		listen(scope, bag, label:GetPropertyChangedSignal("TextBounds"), function()
			render()
		end)
		return label
	end

	render = function()
		if destroyed then
			return
		end
		local look = Collections._resolveTile(state.State, state.Locked == true and "Locked" or "None", flags)
		local compact = isCompact(ctx)
		local opacity = look.Opacity
		local pad = ctx.Px(unit(ctx, Space.Pad))
		local gap = ctx.Px(unit(ctx, Space.Gap))
		local hair = ctx.Hair(unit(ctx, Space.Hairline))
		local height = ctx.Px(compact and Space.TouchMin or Space.ListRowHeight)
		height = math.max(height, ctx.Touch(1))

		if hasWidth(parent) then
			put(root, "Size", UDim2.new(1, 0, 0, height))
		else
			put(root, "Size", UDim2.fromOffset(ctx.Px(unit(ctx, Space.ListWidth)), height))
		end
		put(fill, "BackgroundColor3", colourOf(look.Fill))
		put(fill, "BackgroundTransparency", 1 - look.FillOpacity)

		local lineHeight = look.Selected and ctx.Hair(unit(ctx, Space.TileBaseLine)) or hair
		put(line, "Position", UDim2.new(0, 0, 1, -lineHeight))
		put(line, "Size", UDim2.new(1, 0, 0, lineHeight))
		put(line, "BackgroundColor3", colourOf(look.Line))
		put(line, "BackgroundTransparency", 1 - look.LineOpacity)

		-- Left: picture, then the tier letter.
		local x = pad
		local image = textOf(state.Image)
		if image then
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
			x = height + pad
		elseif picture ~= nil then
			put(picture, "Visible", false)
		end

		local tier = textOf(state.Tier)
		if tier then
			tierLetter = tierLetter or textPart("TierLetter")
			local badgeDesign, badgeRole = Collections._badgeSize(compact and "Small" or "Medium")
			put(tierLetter, "Text", tier)
			local badgeSize = face(tierLetter, badgeRole, ctx)
			local badgeHeight = math.max(ctx.Px(unit(ctx, badgeDesign)), badgeSize)
			local letterWidth = math.max(math.floor(badgeHeight * BADGE_LETTER + HALF), textWidth(tierLetter) + hair + hair)
			local badgeOpacity = look.BadgeDim and math.min(Opacity.TabLocked, opacity) or opacity
			put(tierLetter, "TextXAlignment", Enum.TextXAlignment.Center)
			put(tierLetter, "Position", UDim2.fromOffset(x, math.floor((height - badgeHeight) * HALF)))
			put(tierLetter, "Size", UDim2.fromOffset(letterWidth, badgeHeight))
			put(tierLetter, "BackgroundColor3", tierColour(tier))
			put(tierLetter, "BackgroundTransparency", 1 - badgeOpacity)
			put(tierLetter, "TextColor3", colourOf("Ink"))
			put(tierLetter, "TextTransparency", 1 - badgeOpacity)
			put(tierLetter, "Visible", true)
			x = x + letterWidth + gap
		elseif tierLetter ~= nil then
			put(tierLetter, "Visible", false)
		end

		-- Right: the lock, then the right-hand text.
		local reserve = pad
		if look.Lock then
			local lockDesign = unit(ctx, Space.BadgeSmall)
			local lockPx = ctx.Px(lockDesign)
			if lock == nil then
				lock = Surface.Icon(fill, { Name = "Lock", Icon = "lock", Colour = look.Ink, Size = lockDesign }, scope)
				table.insert(bag, lock)
			else
				lock.Set({ Colour = look.Ink, Size = lockDesign, Visible = true })
			end
			put(lock.Instance, "AnchorPoint", Vector2.new(1, 0))
			put(lock.Instance, "Position", UDim2.new(1, -reserve, 0, math.floor((height - lockPx) * HALF)))
			fadeIcon(lock, 1 - opacity)
			reserve = reserve + lockPx + gap
		elseif lock ~= nil then
			lock.Set({ Visible = false })
		end

		local rightText = textOf(state.Right)
		if rightText then
			right = right or textPart("Right")
			put(right, "Text", string.upper(rightText))
			local rightSize = face(right, "Value", ctx)
			local rightWidth = textWidth(right)
			put(right, "TextXAlignment", Enum.TextXAlignment.Right)
			put(right, "AnchorPoint", Vector2.new(1, 0))
			put(right, "Position", UDim2.new(1, -reserve, 0, -baselineShift(rightSize)))
			put(right, "Size", UDim2.new(0, rightWidth, 1, 0))
			put(right, "TextColor3", colourOf(look.Sub))
			put(right, "TextTransparency", 1 - opacity)
			put(right, "Visible", true)
			reserve = reserve + rightWidth + gap
		elseif right ~= nil then
			put(right, "Visible", false)
		end

		-- Middle: sub-line above the title, the pair centred on the row.
		put(title, "Text", string.upper(tostring(state.Title)))
		local titleSize = face(title, "TileNameSmall", ctx)
		local subText = textOf(state.Sub)
		local subSize = 0
		if subText then
			sub = sub or textPart("Sub")
			put(sub, "Text", string.upper(subText))
			subSize = face(sub, "Label", ctx)
		end
		local top = math.floor((height - subSize - titleSize) * HALF)
		if subText then
			put(sub, "TextTruncate", Enum.TextTruncate.AtEnd)
			put(sub, "Position", UDim2.fromOffset(x, top))
			put(sub, "Size", UDim2.new(1, -(x + reserve), 0, subSize))
			put(sub, "TextColor3", colourOf(look.Sub))
			put(sub, "TextTransparency", 1 - opacity)
			put(sub, "Visible", true)
		elseif sub ~= nil then
			put(sub, "Visible", false)
		end
		put(title, "Position", UDim2.fromOffset(x, top + subSize - baselineShift(titleSize)))
		put(title, "Size", UDim2.new(1, -(x + reserve), 0, titleSize))
		put(title, "TextColor3", colourOf(look.Ink))
		put(title, "TextTransparency", 1 - opacity)

		glow.Set({ Visible = look.Glow })
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
		local callback = state.OnActivated
		if callback and root.Active then
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
		end,
	})

	applyCommon(root, state)
	render()
	mark()
	root.Parent = parent

	local self = { Instance = root }

	function self.Set(patch)
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

	return self
end

return Collections
