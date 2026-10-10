-- Owns the race event card drawn beside a race start prompt (title, format line, your car, your best, prize); not the prompt banner, the requests that fill it or any race state.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.World.EventCardView. Requires: Tokens, Text, Surface, Data, World.WorldPromptModel (pure text rules only).
local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Text = require(Kit.Text)
local Surface = require(Kit.Surface)
local Data = require(Kit.Data)
local Rules = require(script.Parent.WorldPromptModel)

local Space = Tokens.Space

local View = {}

-- The fact rows under the title. facts: { Mode, Tier, Rating }; best: seconds or nil; prizeText: string or nil. Pure.
function View.Rows(facts: any, best: number?, prizeText: string?, compact: boolean): { any }
	local rows = {}
	local tier = type(facts.Tier) == "string" and facts.Tier or ""
	if tier ~= "" and not compact then
		local rating = tonumber(facts.Rating)
		table.insert(rows, { Id = "You", Icon = "car", Label = "YOU", Value = rating and (tier .. " " .. tostring(math.floor(rating + 0.5))) or tier, Kind = "Text" })
	end
	if facts.Mode ~= "Race" and tier ~= "" then
		table.insert(rows, { Id = "Best", Icon = "timer", Label = "YOUR BEST", Value = Rules.TimeText(best), Kind = "Text" })
	end
	if prizeText then
		table.insert(rows, { Id = "Prize", Icon = "coin", Label = "PRIZE", Value = prizeText, Kind = "Prize" })
	end
	return rows
end

-- Card height in design units for a row count. Pure.
function View.Height(rows: number, compact: boolean): number
	if compact then
		return Space.Pad * 2 + Space.CompactStatusHeight * 2 + rows * Space.CompactActionTile
	end
	return Space.Pad * 2 + Space.ButtonHeight + Space.BadgeSmall + rows * Space.FactRowHeight
end

-- Compact card height in design units from what it really holds: the two text lines, the fact rows and the two
-- paddings, all in real pixels. The row-count formula above budgets far more than a phone row takes (the kit draws
-- a Compact fact row about 21 px high), which left the card much taller than its content. Pure.
function View.CompactHeight(textPx: number, factsPx: number, padPx: number, scale: number): number
	local total = padPx * 2 + textPx + factsPx
	if scale <= 0 then
		return total
	end
	return total / scale
end

-- Compact design widths: the panel, the title (clear of the corner chequer) and the format line. Pure.
function View.CompactWidths(): (number, number, number)
	local width = Space.CompactSidePanelWidth
	local inner = width - Space.CompactMargin * 2
	return width, inner - Space.CompactStatusHeight, inner
end

-- True when a card of heightPx hanging from slotY ends above floorY (the top of the bottom HUD band). Pure.
function View.Fits(slotY: number, heightPx: number, floorY: number): boolean
	return slotY + heightPx <= floorY
end

-- How far down its slot the card starts so that it clears something else hanging from the same corner (the
-- onboarding objective cards, on a higher gui). occupiedBottom and slotTop are screen y; 0 when nothing is there. Pure.
function View.TopOffset(occupiedBottom: number?, slotTop: number, gap: number): number
	if type(occupiedBottom) ~= "number" or occupiedBottom <= slotTop then
		return 0
	end
	return math.ceil(occupiedBottom - slotTop) + gap
end

-- "RightColumn" while the chat window shows, else "TopLeftHud" (API2 5.4, keep-out rule 3). Pure.
-- A touch phone (Compact TouchDrive) always uses "TopLeftHud": its right column is the minimap, the cash chip and
-- the radio, and the slot already starts under the chat window when one shows.
function View.SlotFor(ctx: any): string
	if ctx.Class == "Compact" and ctx.Arrangement == "TouchDrive" then
		return "TopLeftHud"
	end
	local keepOut = ctx.ChatKeepOut
	if keepOut and keepOut.Y > 0 then
		return "RightColumn"
	end
	return "TopLeftHud"
end

function View.Mount(layer: any, _model: any, scope: any): any
	local ctx = layer.Metrics
	local destroyed = false
	local compact = ctx.Class == "Compact"
	local touchPhone = compact and ctx.Arrangement == "TouchDrive"
	local slotName = View.SlotFor(ctx)
	local compactWidth, compactTitleWidth, compactLineWidth = View.CompactWidths()

	-- Compact: a wider, tighter card (CompactStatPanelWidth less the full panel padding left 132 px, and the format
	-- line ran out of the card's right edge).
	local card = Surface.Panel(layer.Slot(slotName), {
		Name = "EventCard",
		Width = compact and compactWidth or Space.StatPanelWidth,
		Height = View.Height(0, compact),
		Pad = compact and Space.CompactMargin or nil,
		Visible = false,
	}, scope)
	local content = card.Content
	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	-- Compact: both lines have a width, so a long name ends in an ellipsis inside the card.
	local title = Text.Label(content, { Name = "Title", Text = "", Role = "SectionHead", LayoutOrder = 1,
		MaxWidth = compact and compactTitleWidth or nil }, scope)
	local sub = Text.Label(content, { Name = "Sub", Text = "", Role = "Label", Colour = "TextSecondary", LayoutOrder = 2,
		MaxWidth = compact and compactLineWidth or nil }, scope)
	local facts = Data.FactList(content, { Name = "Facts", Rows = {}, LayoutOrder = 3 }, scope)

	-- The chequer sits on the card's top-right corner. Two-tone image: never tinted. No asset, no instance.
	local chequer
	local chequerImage = Tokens.Asset("ChequerCorner")
	if chequerImage then
		chequer = Instance.new("ImageLabel")
		chequer.Name = "Chequer"
		chequer.AnchorPoint = Vector2.new(1, 0)
		chequer.Position = UDim2.fromScale(1, 0)
		chequer.BackgroundTransparency = 1
		chequer.BorderSizePixel = 0
		chequer.Image = chequerImage
		chequer.ZIndex = 2
		chequer.Parent = card.Instance
	end

	local current -- facts of the showing prompt
	local entry -- the model's cache entry for it
	local shown = false
	local signature

	local function measure()
		if chequer then
			local side = ctx.Px(compact and Space.CompactStatusHeight or Space.IconButton)
			chequer.Size = UDim2.fromOffset(side, side)
		end
	end
	measure()

	local function place()
		local wanted = View.SlotFor(ctx)
		if wanted ~= slotName then
			slotName = wanted
			card.Instance.Parent = layer.Slot(wanted)
		end
	end

	local function lineHeight(role)
		local textSize, holderScale = Text.SizeFor(role, ctx)
		return math.ceil(textSize * holderScale)
	end

	local function cardHeight(rowCount)
		if not compact then
			return View.Height(rowCount, false)
		end
		return View.CompactHeight(lineHeight("SectionHead") + lineHeight("Label"), facts.Instance.Size.Y.Offset,
			ctx.Px(Space.CompactMargin), ctx.Scale)
	end

	-- A touch phone: the card hangs under the Roblox buttons (and under the chat window when it shows) and must end
	-- above the bottom HUD band, whose top is the prompt stack line; with no room it stays hidden (the banner still
	-- names the event). Everything else always has room.
	local topOffset = 0
	local function hasRoom()
		if not touchPhone then
			return true
		end
		return View.Fits(layer.Slot(slotName).Position.Y.Offset + topOffset, card.Instance.Size.Y.Offset,
			layer.Slot("PromptStack").Position.Y.Offset)
	end

	local function show()
		card.Set({ Visible = shown and hasRoom() })
	end

	-- The card starts under whatever else hangs from the top-left corner; the right column has nothing above it.
	local occupiedBottom = nil
	local function seat()
		local offset = 0
		if slotName == "TopLeftHud" then
			offset = View.TopOffset(occupiedBottom, layer.Slot(slotName).AbsolutePosition.Y, ctx.Px(Space.Gap))
		end
		topOffset = offset
		-- The Compact card is wider than the Compact right column (a small window with the chat showing): it
		-- hangs from the column's right edge so that it grows inward, never past the screen margin.
		local hangRight = compact and slotName == "RightColumn"
		local anchor = hangRight and Vector2.new(1, 0) or Vector2.zero
		local position = hangRight and UDim2.new(1, 0, 0, 0) or UDim2.fromOffset(0, offset)
		if card.Instance.AnchorPoint ~= anchor then
			card.Instance.AnchorPoint = anchor
		end
		if card.Instance.Position ~= position then
			card.Instance.Position = position
		end
	end

	local function render()
		if destroyed or not current then
			return
		end
		local text = Rules.CardText(current, entry and entry.Summary, compact)
		local best = entry and entry.Best and current.Tier and entry.Best[current.Tier] or nil
		local prizeText = nil
		if text.Prize then
			-- The shared money formatter; its first call may yield once, so this never runs in a frame step.
			local ok, formatted = pcall(Data.Money, text.Prize, false)
			prizeText = ok and formatted or nil
		end
		local rows = View.Rows(current, best, prizeText, compact)
		local parts = { text.Title, text.Sub }
		for _, row in rows do
			table.insert(parts, row.Id .. "=" .. row.Value)
		end
		local nextSignature = table.concat(parts, "|")
		if nextSignature == signature then
			return
		end
		signature = nextSignature
		title.Set({ Text = text.Title })
		sub.Set({ Text = text.Sub })
		facts.SetRows(rows)
		card.Set({ Height = cardHeight(#rows) })
		if shown then
			show()
		end
	end

	local self = { Instance = card.Instance }

	-- facts: { EventId, Mode, RouteId, Tier, Rating }.
	function self.Show(factsOfPrompt: any)
		if destroyed then
			return
		end
		current = factsOfPrompt
		entry = nil
		place()
		seat()
		render()
		shown = true
		show()
	end

	-- screenY: the bottom edge (screen y) of anything else showing in the top-left corner, or nil. Call before Show.
	function self.SetOccupiedTop(screenY: number?)
		occupiedBottom = screenY
		if shown and not destroyed then
			place()
			seat()
			show()
		end
	end

	-- entry: the model's cache entry ({ Summary, Best }); ignored when it is not for the showing event.
	function self.Update(eventKey: string, cacheEntry: any)
		if destroyed or not current or Rules.EventKey(current.EventId, current.Mode) ~= eventKey then
			return
		end
		entry = cacheEntry
		render()
	end

	function self.Hide()
		current, entry = nil, nil
		if shown then
			shown = false
			card.Set({ Visible = false })
		end
	end

	function self.Render(_reason: string?)
		render()
	end

	function self.IsShown(): boolean
		return shown
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		facts.Destroy()
		sub.Destroy()
		title.Destroy()
		card.Destroy()
	end

	scope:connect(ctx.Changed, function(change)
		if type(change) == "table" and change.Layout == false then
			return
		end
		measure()
		if shown then
			place()
			seat()
			-- The text sizes follow the scale: lay the showing card out again.
			signature = nil
			render()
		end
	end)
	if touchPhone then
		-- The slots move with the chat window and the screen; whether the card has room follows them.
		for _, name in { "TopLeftHud", "PromptStack" } do
			scope:connect(layer.Slot(name):GetPropertyChangedSignal("Position"), function()
				if not destroyed and shown then
					show()
				end
			end)
		end
	end
	return self
end

return View
