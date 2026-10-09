-- Owns the Pulse big numbers: digit and punctuation sprites laid out in a fixed pool of cells; it does not own what a number means, any formatting, any frame step or any screen layout.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Kit.BigNumber. Requires: Tokens, Sprites, Metrics, Text.
local Tokens = require(script.Parent.Tokens)
local Sprites = require(script.Parent.Sprites)
local Metrics = require(script.Parent.Metrics)
local Text = require(script.Parent.Text)

local BigNumber = {}

-- Sheet ids (API2 3.1), not pixels.
local SMALL = 128
local LARGE = 256
local HALF = 0.5
local FLAT_ROLE = "SectionHead" -- the text role of the empty-asset state

local ALIGN = {
	Left = Enum.TextXAlignment.Left,
	Centre = Enum.TextXAlignment.Center,
	Right = Enum.TextXAlignment.Right,
}

local KEYS = {
	Name = true, LayoutOrder = true, Visible = true,
	Text = true, Role = true, Colour = true, Align = true, MaxCells = true, Tight = true, Fixed = true,
}

local warned = {}
local function warnOnce(key, message)
	if warned[key] then
		return
	end
	warned[key] = true
	warn("[Pulse.BigNumber] " .. message)
end

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function round(value)
	return math.floor(value + HALF)
end

---------------------------------------------------------------------------------------------------
-- Sheet data: one glyph table per sheet id, digits and punctuation together
---------------------------------------------------------------------------------------------------

local function buildSheet(id)
	local digits = Sprites.Digits[id]
	local punct = Sprites.Punct[id]
	local glyphs = {}
	for token, glyph in pairs(digits.Glyphs) do
		glyphs[token] = {
			Asset = digits.Asset,
			X = glyph[1],
			Y = glyph[2],
			W = digits.Cell[1],
			H = digits.Cell[2],
			Advance = glyph[3],
			Origin = glyph[4],
			Digit = true,
		}
	end
	for token, glyph in pairs(punct.Glyphs) do
		glyphs[token] = {
			Asset = punct.Asset,
			X = glyph[1],
			Y = glyph[2],
			W = glyph[3],
			H = glyph[4],
			Advance = glyph[5],
			Origin = glyph[6],
			Digit = false,
		}
	end
	return {
		Id = id,
		Asset = digits.Asset,
		Cap = digits.Cap,
		Pitch = digits.Pitch,
		PitchTight = digits.PitchTight,
		CellHeight = digits.Cell[2],
		Glyphs = glyphs,
	}
end

local SHEETS = { [SMALL] = buildSheet(SMALL), [LARGE] = buildSheet(LARGE) }

-- Tokens longer than one character, longest first (KM/H, MPH, XP).
local MULTI = {}
for token in pairs(SHEETS[LARGE].Glyphs) do
	if #token > 1 then
		table.insert(MULTI, token)
	end
end
table.sort(MULTI, function(a, b)
	if #a ~= #b then
		return #a > #b
	end
	return a < b
end)

-- Fills tokens[i] and xs[i] (sheet pixels) and returns the cell count, the pen end and the list of
-- unknown characters (nil when none). Fixed digits sit centred in a pitch slot (digits.json "layout");
-- everything else is drawn at pen - originX and advances by its own advance. A space is half a pitch.
local function layoutInto(text, sheet, tight, proportional, tokens, xs)
	local pitch = tight and sheet.PitchTight or sheet.Pitch
	local glyphs = sheet.Glyphs
	local pen = 0
	local count = 0
	local unknown = nil
	local index = 1
	local length = #text
	while index <= length do
		local token = nil
		for _, multi in ipairs(MULTI) do
			if string.sub(text, index, index + #multi - 1) == multi then
				token = multi
				break
			end
		end
		if token == nil then
			token = string.sub(text, index, index)
		end
		index = index + #token
		local glyph = glyphs[token]
		if glyph ~= nil then
			count = count + 1
			tokens[count] = token
			if glyph.Digit and not proportional then
				xs[count] = pen + (pitch - glyph.W) * HALF
				pen = pen + pitch
			else
				xs[count] = pen - glyph.Origin
				pen = pen + glyph.Advance
			end
		elseif token == " " then
			pen = pen + pitch * HALF
		else
			unknown = unknown or {}
			table.insert(unknown, token)
		end
	end
	return count, pen, unknown
end

-- Pure. X and Width are sheet pixels. The fourth argument (extra to API2) gives the proportional layout
-- of Fixed = false. Unknown characters are skipped and listed in Unknown.
function BigNumber.Layout(text, sheet, tight, proportional)
	if type(text) ~= "string" then
		error("[Pulse.BigNumber] Layout: text must be a string", 2)
	end
	local data = SHEETS[sheet]
	if data == nil then
		error("[Pulse.BigNumber] Layout: unknown sheet " .. tostring(sheet), 2)
	end
	local tokens, xs = {}, {}
	local count, width, unknown = layoutInto(text, data, tight == true, proportional == true, tokens, xs)
	local cells = table.create(count)
	for index = 1, count do
		cells[index] = { Token = tokens[index], X = xs[index] }
	end
	return { Cells = cells, Width = width, Unknown = unknown }
end

-- Pure. The small sheet serves every cap height up to its own.
function BigNumber.SheetFor(capPx)
	if capPx <= SHEETS[SMALL].Cap then
		return SMALL
	end
	return LARGE
end

---------------------------------------------------------------------------------------------------
-- Component
---------------------------------------------------------------------------------------------------

local function capsOf(ctx)
	return ctx.Class == "Compact" and Tokens.NumberCap.Compact or Tokens.NumberCap.Regular
end

local function checkKeys(values)
	if type(values) ~= "table" then
		error("[Pulse.BigNumber] props must be a table", 3)
	end
	for key in pairs(values) do
		if not KEYS[key] then
			error("[Pulse.BigNumber] unknown key " .. tostring(key), 3)
		end
	end
end

-- Checks only the keys that are present, so it serves both props and a Set patch.
local function checkValues(values)
	if values.Text ~= nil and type(values.Text) ~= "string" then
		error("[Pulse.BigNumber] Text must be a string", 3)
	end
	if values.Role ~= nil and Tokens.NumberCap.Regular[values.Role] == nil then
		error("[Pulse.BigNumber] unknown Role " .. tostring(values.Role), 3)
	end
	if values.Colour ~= nil and Tokens.Colour[values.Colour] == nil then
		error("[Pulse.BigNumber] unknown colour role " .. tostring(values.Colour), 3)
	end
	if values.Align ~= nil and ALIGN[values.Align] == nil then
		error("[Pulse.BigNumber] unknown Align " .. tostring(values.Align), 3)
	end
	local maxCells = values.MaxCells
	if maxCells ~= nil and (type(maxCells) ~= "number" or maxCells < 1 or maxCells ~= math.floor(maxCells)) then
		error("[Pulse.BigNumber] MaxCells must be a whole number of at least 1", 3)
	end
end

function BigNumber.New(parent, props, scope)
	props = props or {}
	checkKeys(props)
	checkValues(props)
	if props.Role == nil then
		error("[Pulse.BigNumber] Role is required", 2)
	end
	if props.MaxCells == nil then
		error("[Pulse.BigNumber] MaxCells is required", 2)
	end

	local state = table.clone(props)
	if state.Text == nil then
		state.Text = ""
	end
	local maxCells = state.MaxCells

	-- An unknown character is an error at build (API2 3.1).
	local first = BigNumber.Layout(state.Text, LARGE, state.Tight == true, state.Fixed == false)
	if first.Unknown ~= nil then
		error("[Pulse.BigNumber] no sprite for " .. table.concat(first.Unknown, " "), 2)
	end

	local ctx = Metrics.Of(parent)
	local flat = Tokens.Asset(SHEETS[SMALL].Asset) == nil or Tokens.Asset(SHEETS[LARGE].Asset) == nil
	local destroyed = false
	local changedConnection = nil

	local root = Instance.new("Frame")
	root.Name = state.Name or "BigNumber"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0

	-- Flat state: one text label. Otherwise a pool of MaxCells image cells, never grown.
	local flatLabel = nil
	local cells = {}
	if flat then
		flatLabel = Text.RawLabel(root, FLAT_ROLE, ctx)
		flatLabel.Name = "Flat"
		flatLabel.BackgroundTransparency = 1
		flatLabel.BorderSizePixel = 0
		flatLabel.TextWrapped = false
		flatLabel.TextYAlignment = Enum.TextYAlignment.Center
		flatLabel.Size = UDim2.fromScale(1, 1)
	else
		for index = 1, maxCells do
			local cell = Instance.new("ImageLabel")
			cell.Name = "Cell" .. index
			cell.BackgroundTransparency = 1
			cell.BorderSizePixel = 0
			cell.ScaleType = Enum.ScaleType.Stretch
			cell.Visible = false
			cell.Parent = root
			cells[index] = cell
		end
	end

	-- Draw state, rewritten by measure().
	local sheet = SHEETS[LARGE]
	local scale = 1
	local rootWidth = 0
	local drawn = {} -- token -> { Image, Offset, Rect, Size }; cleared when the scale changes
	-- What each cell shows now: only differences are written.
	local cellToken = {}
	local cellX = {}
	local cellShown = {}
	-- Scratch arrays reused by every SetText.
	local tokens = {}
	local xs = {}

	local function measure()
		local capPx = ctx.Px(capsOf(ctx)[state.Role])
		sheet = SHEETS[BigNumber.SheetFor(capPx)]
		scale = capPx / sheet.Cap
		local pitch = state.Tight == true and sheet.PitchTight or sheet.Pitch
		local pitchPx = math.max(1, round(pitch * scale))
		local height = math.max(1, round(sheet.CellHeight * scale))
		rootWidth = maxCells * pitchPx
		put(root, "Size", UDim2.fromOffset(rootWidth, height))
	end

	local function drawOf(token)
		local entry = drawn[token]
		if entry == nil then
			local glyph = sheet.Glyphs[token]
			entry = {
				Image = Tokens.Asset(glyph.Asset) or "",
				Offset = Vector2.new(glyph.X, glyph.Y),
				Rect = Vector2.new(glyph.W, glyph.H),
				Size = UDim2.fromOffset(math.max(1, round(glyph.W * scale)), math.max(1, round(glyph.H * scale))),
			}
			drawn[token] = entry
		end
		return entry
	end

	-- Writes the cells whose token, place or visibility differs from what they show.
	local function applyText()
		if flat then
			put(flatLabel, "Text", state.Text)
			return
		end
		local count, width, unknown =
			layoutInto(state.Text, sheet, state.Tight == true, state.Fixed == false, tokens, xs)
		if unknown ~= nil then
			for _, character in ipairs(unknown) do
				warnOnce("unknown:" .. character, "no sprite for " .. character .. "; skipped")
			end
		end
		if count > maxCells then
			warnOnce("overflow:" .. root.Name, root.Name .. ": text needs more than MaxCells = " .. maxCells .. " cells; cut")
			count = maxCells
		end
		local align = state.Align or "Left"
		local offset = 0
		if align == "Centre" then
			offset = round((rootWidth - width * scale) * HALF)
		elseif align == "Right" then
			offset = rootWidth - round(width * scale)
		end
		for index = 1, maxCells do
			local cell = cells[index]
			if index <= count then
				local token = tokens[index]
				if cellToken[index] ~= token then
					cellToken[index] = token
					local entry = drawOf(token)
					put(cell, "Image", entry.Image)
					put(cell, "ImageRectOffset", entry.Offset)
					put(cell, "ImageRectSize", entry.Rect)
					put(cell, "Size", entry.Size)
				end
				local x = offset + round(xs[index] * scale)
				if cellX[index] ~= x then
					cellX[index] = x
					put(cell, "Position", UDim2.fromOffset(x, 0))
				end
				if cellShown[index] ~= true then
					cellShown[index] = true
					cell.Visible = true
				end
			elseif cellShown[index] == true then
				cellShown[index] = false
				cell.Visible = false
			end
		end
	end

	-- Everything: used at build, on a metrics change and when a prop other than Text changes.
	local function renderAll()
		measure()
		local colour = Tokens.Colour[state.Colour or "White"]
		if flat then
			local textSize = Text.SizeFor(FLAT_ROLE, ctx)
			put(flatLabel, "FontFace", Text.Font(FLAT_ROLE))
			put(flatLabel, "TextSize", textSize)
			local lock = flatLabel:FindFirstChild("SizeLock")
			if lock ~= nil then
				put(lock, "MaxTextSize", textSize)
			end
			put(flatLabel, "TextColor3", colour)
			put(flatLabel, "TextXAlignment", ALIGN[state.Align or "Left"])
		else
			table.clear(drawn)
			table.clear(cellToken)
			table.clear(cellX)
			for index = 1, maxCells do
				put(cells[index], "ImageColor3", colour)
			end
		end
		applyText()
	end

	local function applyCommon()
		put(root, "Name", state.Name or "BigNumber")
		put(root, "LayoutOrder", state.LayoutOrder or 0)
		put(root, "Visible", state.Visible ~= false)
	end

	applyCommon()
	renderAll()

	if ctx.Changed ~= nil then
		changedConnection = scope:connect(ctx.Changed, function(change)
			if destroyed or (type(change) == "table" and change.Layout == false) then
				return
			end
			renderAll()
		end)
	end

	root.Parent = parent

	local self = { Instance = root }

	-- Safe inside a Perf.Bind step: no lookup and no creation; an unchanged text returns at once.
	function self.SetText(text)
		if destroyed or text == state.Text then
			return
		end
		if type(text) ~= "string" then
			error("[Pulse.BigNumber] SetText expects a string", 2)
		end
		state.Text = text
		applyText()
	end

	function self.Set(patch)
		checkKeys(patch)
		checkValues(patch)
		if patch.MaxCells ~= nil and patch.MaxCells ~= maxCells then
			error("[Pulse.BigNumber] MaxCells is the pool size and cannot change", 2)
		end
		if destroyed then
			return
		end
		local textChanged = false
		local otherChanged = false
		for key, value in pairs(patch) do
			if state[key] ~= value then
				state[key] = value
				if key == "Text" then
					textChanged = true
				else
					otherChanged = true
				end
			end
		end
		if otherChanged then
			applyCommon()
			renderAll()
		elseif textChanged then
			applyText()
		end
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if changedConnection ~= nil then
			changedConnection:Disconnect()
			changedConnection = nil
		end
		root:Destroy()
	end

	return self
end

return BigNumber
