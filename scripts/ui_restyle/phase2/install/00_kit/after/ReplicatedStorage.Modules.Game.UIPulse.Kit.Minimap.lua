-- Owns the Pulse minimap frame: the round clip, vignette, ring, rank arc and number, north marker, player arrow and district label; not the map, its markers, the route, map state or any frame step.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.Minimap. Requires: Tokens, Sprites, Metrics, Text, Surface, BigNumber.
local Tokens = require(script.Parent.Tokens)
local Sprites = require(script.Parent.Sprites)
local Metrics = require(script.Parent.Metrics)
local Text = require(script.Parent.Text)
local Surface = require(script.Parent.Surface)
local BigNumber = require(script.Parent.BigNumber)

local Minimap = {}

local Space = Tokens.Space
local Opacity = Tokens.Opacity
local RING = Sprites.Rings
local RANK = RING.Rank

-- Reveal maths as Kit.Gauge (the two modules may not require each other). Degrees clockwise from +X; a UIGradient
-- at Rotation r shows the angles (r + 90, r + 270).
local QUANTUM = 0.5
local SEAM = 270
local PARK = 20
local LEFT_EMPTY = 90 + PARK + 90
local LEFT_FULL = SEAM + PARK + 90
local RIGHT_EMPTY = -PARK
local MASK = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.499, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})

-- rings.json, rank arc: outer radius 244 and thickness 13 in the 512 px image. The centre line of the stroke as a
-- fraction of the rank frame (Sprites carries no radius for this ring).
local RANK_MID = (244 - 13 / 2) / 512
-- Layout as fractions of the map diameter, read off previews r00 (Regular) and c02 (Compact).
local RANK_X = 0.03 -- Regular: centre of the RANK label and number, from the left edge of the frame
local RANK_LABEL_Y = -0.03
local RANK_NUMBER_Y = 0.07
local BADGE = 0.2 -- Compact: diameter of the rank badge on the arc
local NORTH = 0.09 -- diameter of the north disc
local NORTH_GLYPH = 0.06
local ARROW = 0.117
local RANK_CELLS = 3
local RANK_MAX = 999
local LABEL_ROLE = "Label"
-- The unfilled track is the arc image darkened towards Ink and nearly opaque, so it reads on a bright scene as it
-- does on the dark preview (r00). At RankTrackImage (0.25) alone it vanished over daylight ground.
local TRACK_SHADE = 0.4

local MINIMAP_KEYS = { Name = true, LayoutOrder = true, Visible = true, Size = true, Round = true, ShowRank = true,
	Label = true, OnActivated = true }

local function checkKeys(patch)
	if type(patch) ~= "table" then error("Minimap expects a table of props", 3) end
	for key in pairs(patch) do
		if not MINIMAP_KEYS[key] then error(string.format("Minimap: unknown key '%s'", tostring(key)), 3) end
	end
end

local function checkValues(values)
	if values.Size ~= nil and (type(values.Size) ~= "number" or values.Size <= 0) then
		error("Minimap: Size must be a positive design number", 3)
	end
	if values.Label ~= nil and type(values.Label) ~= "string" then error("Minimap: Label must be a string", 3) end
end

local function write(instance, property, value)
	if instance[property] ~= value then instance[property] = value end
end

local function round(value)
	return math.floor(value + 0.5)
end

local function even(value)
	local whole = round(value)
	return math.max(2, whole - whole % 2)
end

local function unitFraction(fraction)
	if type(fraction) ~= "number" or fraction ~= fraction then return 0 end
	return math.clamp(fraction, 0, 1)
end

-- Pure. As Gauge._sweep: mask rotations (left window, right window) and the quantised degrees filled.
local function sweep(startDeg, sweepDeg, fraction)
	local degrees = math.floor(unitFraction(fraction) * sweepDeg / QUANTUM + 0.5) * QUANTUM
	local angle = startDeg + degrees
	local left
	if degrees <= 0 then
		left = LEFT_EMPTY
	elseif angle < SEAM then
		left = angle + 90
	else
		left = LEFT_FULL
	end
	local right = if angle > SEAM then angle - SEAM else RIGHT_EMPTY
	return left, right, degrees
end

-- Pure. Start and sweep of the rank arc for a class (Regular: 180 over 90; Compact: 165 to 285).
local function rankArc(class)
	if class == "Compact" then return RANK.CompactFromDeg, RANK.CompactToDeg - RANK.CompactFromDeg end
	return RANK.StartDeg, RANK.SweepRegular
end

-- Pure. Degrees quantised to half a degree, in [0, 360).
local function quantise(degrees)
	if type(degrees) ~= "number" or degrees ~= degrees then return 0 end
	return (math.floor(degrees / QUANTUM + 0.5) * QUANTUM) % 360
end

-- Pure. Whole-pixel offset from the map centre of the north marker: map north is up (270) turned by the map's
-- clockwise rotation.
local function northOffset(mapRotation, radius)
	local angle = math.rad(270 + mapRotation)
	return round(math.cos(angle) * radius), round(math.sin(angle) * radius)
end

local function wholeRank(rank)
	if type(rank) ~= "number" or rank ~= rank then return 0 end
	return math.clamp(math.floor(rank + 0.5), 0, RANK_MAX)
end

Minimap._sweep = sweep
Minimap._rankArc = rankArc
Minimap._quantise = quantise
Minimap._northOffset = northOffset

local function plain(className, name, zIndex, parent)
	local instance = Instance.new(className)
	instance.Name = name
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.ZIndex = zIndex
	instance.Parent = parent
	return instance
end

local function image(name, assetKey, zIndex, parent)
	local label = plain("ImageLabel", name, zIndex, parent)
	label.Image = Tokens.Asset(assetKey) or ""
	label.ScaleType = Enum.ScaleType.Stretch
	return label
end

local function mask(target, rotation)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Mask"
	gradient.Transparency = MASK
	gradient.Rotation = rotation
	gradient.Parent = target
	return gradient
end

local function disc(name, zIndex, parent)
	local frame = plain("Frame", name, zIndex, parent)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Tokens.Colour.Ink
	frame.BackgroundTransparency = 0
	local corner = Instance.new("UICorner")
	corner.Name = "Corner"
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	return frame
end

function Minimap.New(parent, props, scope)
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "Minimap requires a GuiObject parent")
	assert(type(scope) == "table", "Minimap requires a scope")
	props = props or {}
	checkKeys(props)
	checkValues(props)

	local ctx = Metrics.Of(parent)
	local destroyed = false
	local writes = 0
	local state = {
		Name = props.Name or "Minimap",
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		Size = props.Size or (if ctx.Class == "Compact" then Space.CompactMinimap else Space.MinimapSize),
		Round = props.Round ~= false,
		ShowRank = props.ShowRank ~= false,
		Label = props.Label or "",
		OnActivated = props.OnActivated,
	}
	-- What is on screen now; the setters write only a difference.
	local shown = { Rank = 0, Fraction = 0, Left = LEFT_EMPTY, Right = RIGHT_EMPTY, Heading = 0, NorthX = -1,
		NorthY = -1, Arrow = 0 }
	local geometry = { Diameter = 0, Half = 0, Start = RANK.StartDeg, Sweep = RANK.SweepRegular }

	local root = Instance.new("TextButton")
	Metrics.Bind(root, ctx) -- parts built before the root is parented take this context, not the screen's
	root.Name = state.Name
	root.AutoButtonColor = false
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.LayoutOrder = state.LayoutOrder
	root.Selectable = false
	root.Text = ""
	root.Visible = state.Visible
	root.Active = type(state.OnActivated) == "function"
	-- In a slot the root sits on the slot's anchor (API1 8).
	if string.sub(parent.Name, 1, 4) == "Slot" then root.AnchorPoint = parent.AnchorPoint end

	-- Content keeps its identity whatever the shape: it lives in the CanvasGroup when round, in the root when not.
	local content = plain("Frame", "Content", 1, nil)
	content.ClipsDescendants = true
	content.Size = UDim2.fromScale(1, 1)
	local vignette = image("Vignette", "MinimapVignette", 2, nil)
	vignette.ImageColor3 = Tokens.Colour.Ink
	vignette.ImageTransparency = 1 - Opacity.Vignette
	vignette.Size = UDim2.fromScale(1, 1)
	local roundHolder = nil

	local ring = image("Ring", "MinimapRing", 3, root)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)

	local rankLeft = plain("Frame", "RankLeft", 4, root)
	rankLeft.ClipsDescendants = true
	local trackLeft = image("RankTrack", "RankArc", 1, rankLeft)
	trackLeft.ImageColor3 = Tokens.Colour.Ink:Lerp(Tokens.Colour.White, TRACK_SHADE)
	trackLeft.ImageTransparency = 1 - Opacity.Panel
	local fillLeft = image("RankFill", "RankArc", 2, rankLeft)
	local fillLeftMask = mask(fillLeft, LEFT_EMPTY)
	-- Built only when the arc passes 12 o'clock (Compact).
	local rankRight, trackRight, trackRightMask, fillRight, fillRightMask

	local overlay = plain("Frame", "Overlay", 5, root)
	overlay.Size = UDim2.fromScale(1, 1)

	local badge = nil -- Compact: the round Ink badge under the number
	local rankLabel = nil -- Regular: the RANK caption
	local rankNumber = BigNumber.New(root, { Name = "RankNumber", Text = "0", Role = "Rank", Colour = "White",
		Align = "Centre", MaxCells = RANK_CELLS }, scope)
	rankNumber.Instance.AnchorPoint = Vector2.new(0.5, 0.5)
	rankNumber.Instance.ZIndex = 7

	local north = disc("North", 8, root)
	local northGlyph = Surface.Icon(north, { Name = "Glyph", Icon = "north", Colour = "White",
		Size = state.Size * NORTH_GLYPH }, scope)
	northGlyph.Instance.AnchorPoint = Vector2.new(0.5, 0.5)

	local arrow = image("Arrow", "MapPlayerArrow", 9, root)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.ImageColor3 = Tokens.Colour.White

	local label = Text.RawLabel(root, LABEL_ROLE, ctx)
	label.Name = "Label"
	label.Text = string.upper(state.Label)
	label.TextColor3 = Tokens.Colour.TextSecondary
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = 9

	local function applyShape()
		local holder = root
		if state.Round then
			if not roundHolder then
				roundHolder = plain("CanvasGroup", "Round", 1, root)
				local corner = Instance.new("UICorner")
				corner.Name = "Corner"
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = roundHolder
			end
			holder = roundHolder
		end
		if roundHolder then
			write(roundHolder, "Size", UDim2.fromOffset(geometry.Diameter, geometry.Diameter))
			write(roundHolder, "Visible", state.Round)
		end
		if content.Parent ~= holder then content.Parent = holder end
		if vignette.Parent ~= holder then vignette.Parent = holder end
	end

	local function placeNorth()
		local dx, dy = northOffset(shown.Heading, geometry.Half)
		local x, y = geometry.Half + dx, geometry.Half + dy
		if x == shown.NorthX and y == shown.NorthY then return 0 end
		shown.NorthX, shown.NorthY = x, y
		north.Position = UDim2.fromOffset(x, y)
		return 1
	end

	local function applyRank()
		local left, right = sweep(geometry.Start, geometry.Sweep, shown.Fraction)
		local count = 0
		if left ~= shown.Left then
			shown.Left = left
			fillLeftMask.Rotation = left
			count += 1
		end
		if right ~= shown.Right then
			shown.Right = right
			if fillRightMask then
				fillRightMask.Rotation = right
				count += 1
			end
		end
		return count
	end

	local function applyRankVisible()
		local on = state.ShowRank
		local compact = ctx.Class == "Compact"
		write(rankLeft, "Visible", on)
		if rankRight then write(rankRight, "Visible", on and geometry.Start + geometry.Sweep > SEAM) end
		write(rankNumber.Instance, "Visible", on)
		if badge then write(badge, "Visible", on and compact) end
		if rankLabel then write(rankLabel, "Visible", on and not compact) end
	end

	local function layout()
		if destroyed then return end
		local compact = ctx.Class == "Compact"
		-- Even sides keep the shared centre, and the join of the rank windows, on a whole pixel.
		local diameter = even(ctx.Px(state.Size))
		local half = diameter / 2
		geometry.Diameter = diameter
		geometry.Half = half
		geometry.Start, geometry.Sweep = rankArc(ctx.Class)
		local centre = UDim2.fromOffset(half, half)

		write(root, "Size", UDim2.fromOffset(diameter, diameter))
		applyShape()

		local ringSide = even(diameter * RING.Minimap.FrameScale)
		write(ring, "Position", centre)
		write(ring, "Size", UDim2.fromOffset(ringSide, ringSide))

		-- The rank frame shares the map centre. Its left window runs from the left edge to the centre line and down
		-- to the height of the arc's start; the right window is the top-right quarter.
		local rankSide = even(diameter * RANK.FrameScale)
		local rankHalf = rankSide / 2
		local origin = half - rankHalf
		local rankRadius = rankSide * RANK_MID
		local cut = math.max(0, round(math.sin(math.rad(geometry.Start)) * rankRadius))
		local rankFull = UDim2.fromOffset(rankSide, rankSide)
		write(rankLeft, "Position", UDim2.fromOffset(origin, origin))
		write(rankLeft, "Size", UDim2.fromOffset(rankHalf, rankHalf + cut))
		write(trackLeft, "Size", rankFull)
		write(fillLeft, "Size", rankFull)

		local crosses = geometry.Start + geometry.Sweep > SEAM
		if crosses and not rankRight then
			rankRight = plain("Frame", "RankRight", 4, root)
			rankRight.ClipsDescendants = true
			trackRight = image("RankTrack", "RankArc", 1, rankRight)
			trackRight.ImageColor3 = Tokens.Colour.Ink:Lerp(Tokens.Colour.White, TRACK_SHADE)
			trackRight.ImageTransparency = 1 - Opacity.Panel
			trackRightMask = mask(trackRight, RIGHT_EMPTY)
			fillRight = image("RankFill", "RankArc", 2, rankRight)
			fillRightMask = mask(fillRight, shown.Right)
		end
		if rankRight then
			local _, trackEnd = sweep(geometry.Start, geometry.Sweep, 1)
			write(rankRight, "Position", UDim2.fromOffset(half, origin))
			write(rankRight, "Size", UDim2.fromOffset(rankHalf, rankHalf))
			write(trackRight, "Position", UDim2.fromOffset(-rankHalf, 0))
			write(trackRight, "Size", rankFull)
			write(trackRightMask, "Rotation", trackEnd)
			write(fillRight, "Position", UDim2.fromOffset(-rankHalf, 0))
			write(fillRight, "Size", rankFull)
		end

		-- Rank number: Regular beside the arc's start with a caption; Compact in a badge on the arc's start.
		if compact then
			if not badge then badge = disc("RankBadge", 6, root) end
			local angle = math.rad(geometry.Start)
			local x = half + round(math.cos(angle) * rankRadius)
			local y = half + round(math.sin(angle) * rankRadius)
			local side = even(diameter * BADGE)
			write(badge, "Position", UDim2.fromOffset(x, y))
			write(badge, "Size", UDim2.fromOffset(side, side))
			write(rankNumber.Instance, "Position", UDim2.fromOffset(x, y))
		else
			if not rankLabel then
				rankLabel = Text.RawLabel(root, LABEL_ROLE, ctx)
				rankLabel.Name = "RankLabel"
				rankLabel.AnchorPoint = Vector2.new(0.5, 0.5)
				rankLabel.Text = "RANK"
				rankLabel.TextColor3 = Tokens.Colour.TextSecondary
				rankLabel.TextXAlignment = Enum.TextXAlignment.Center
				rankLabel.TextYAlignment = Enum.TextYAlignment.Center
				rankLabel.ZIndex = 7
			end
			local textSize = (Text.SizeFor(LABEL_ROLE, ctx))
			local x = round(diameter * RANK_X)
			write(rankLabel, "FontFace", Text.Font(LABEL_ROLE))
			write(rankLabel, "TextSize", textSize)
			write(rankLabel, "Size", UDim2.fromOffset(diameter, textSize))
			write(rankLabel, "Position", UDim2.fromOffset(x, round(diameter * RANK_LABEL_Y)))
			write(rankNumber.Instance, "Position", UDim2.fromOffset(x, round(diameter * RANK_NUMBER_Y)))
		end
		applyRankVisible()
		applyRank()

		local northSide = even(diameter * NORTH)
		write(north, "Size", UDim2.fromOffset(northSide, northSide))
		write(northGlyph.Instance, "Position", UDim2.fromOffset(northSide / 2, northSide / 2))
		shown.NorthX, shown.NorthY = -1, -1
		placeNorth()

		local arrowSide = even(diameter * ARROW)
		write(arrow, "Position", centre)
		write(arrow, "Size", UDim2.fromOffset(arrowSide, arrowSide))

		-- The district name sits in the band under the frame; with no band (Compact) it is not shown.
		local band = if compact then 0 else ctx.Px(Space.MinimapLabelBand)
		local textSize = (Text.SizeFor(LABEL_ROLE, ctx))
		write(label, "FontFace", Text.Font(LABEL_ROLE))
		write(label, "TextSize", textSize)
		write(label, "Size", UDim2.fromOffset(diameter, textSize))
		write(label, "Position", UDim2.fromOffset(0, diameter + math.max(0, math.floor((band - textSize) / 2))))
		write(label, "Visible", band > 0 and state.Label ~= "")
	end

	local function setRank(rank, fraction)
		if destroyed then return end
		local count = 0
		local whole = wholeRank(rank)
		if whole ~= shown.Rank then
			shown.Rank = whole
			rankNumber.SetText(tostring(whole))
			count += 1
		end
		shown.Fraction = unitFraction(fraction)
		count += applyRank()
		writes += count
	end

	local function setHeading(mapRotationDegrees)
		if destroyed then return end
		local heading = quantise(mapRotationDegrees)
		if heading == shown.Heading then return end
		shown.Heading = heading
		writes += placeNorth()
	end

	local function setArrow(rotationDegrees)
		if destroyed then return end
		local rotation = quantise(rotationDegrees)
		if rotation == shown.Arrow then return end
		shown.Arrow = rotation
		arrow.Rotation = rotation
		writes += 1
	end

	local apply = {
		Name = function(value) root.Name = value end,
		LayoutOrder = function(value) root.LayoutOrder = value end,
		Visible = function(value) root.Visible = value end,
		Size = function(value)
			northGlyph.Set({ Size = value * NORTH_GLYPH })
			layout()
		end,
		Round = function() applyShape() end,
		ShowRank = function() applyRankVisible() end,
		Label = function(value)
			label.Text = string.upper(value)
			layout()
		end,
		OnActivated = function(value) root.Active = type(value) == "function" end,
	}

	local function set(patch)
		checkKeys(patch)
		checkValues(patch)
		if destroyed then return end
		for key, value in pairs(patch) do
			if state[key] ~= value then
				state[key] = value
				apply[key](value)
			end
		end
	end

	local function setLabel(text)
		set({ Label = text })
	end

	local function setRound(value)
		set({ Round = value == true })
	end

	local connections = {}

	local function destroy()
		if destroyed then return end
		destroyed = true
		for _, connection in ipairs(connections) do connection:Disconnect() end
		table.clear(connections)
		rankNumber.Destroy()
		northGlyph.Destroy()
		-- Content and the vignette may be outside the root for a moment during a shape change; destroy them by hand.
		content:Destroy()
		vignette:Destroy()
		root:Destroy()
	end

	layout()
	root.Parent = parent

	table.insert(connections, scope:connect(root.Activated, function()
		if destroyed then return end
		local callback = state.OnActivated
		if type(callback) == "function" then callback() end
	end))
	if ctx.Changed then
		table.insert(connections, scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then return end
			layout()
		end))
	end
	if Text.ReadyChanged then table.insert(connections, scope:connect(Text.ReadyChanged, layout)) end
	scope:add(destroy)

	return {
		Instance = root,
		Set = set,
		Destroy = destroy,
		Content = content,
		Overlay = overlay,
		SetRank = setRank,
		SetHeading = setHeading,
		SetArrow = setArrow,
		SetLabel = setLabel,
		SetRound = setRound,
		-- Test and probe seam: properties written by SetRank, SetHeading and SetArrow since the build.
		_writes = function() return writes end,
	}
end

return Minimap
