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

-- "RightColumn" while the chat window shows, else "TopLeftHud" (API2 5.4, keep-out rule 3). Pure.
function View.SlotFor(ctx: any): string
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
	local slotName = View.SlotFor(ctx)

	local card = Surface.Panel(layer.Slot(slotName), {
		Name = "EventCard",
		Width = compact and Space.CompactStatPanelWidth or Space.StatPanelWidth,
		Height = View.Height(0, compact),
		Visible = false,
	}, scope)
	local content = card.Content
	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	local title = Text.Label(content, { Name = "Title", Text = "", Role = "SectionHead", LayoutOrder = 1 }, scope)
	local sub = Text.Label(content, { Name = "Sub", Text = "", Role = "Label", Colour = "TextSecondary", LayoutOrder = 2 }, scope)
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

	local function render()
		if destroyed or not current then
			return
		end
		local text = Rules.CardText(current, entry and entry.Summary)
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
		card.Set({ Height = View.Height(#rows, compact) })
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
		render()
		if not shown then
			shown = true
			card.Set({ Visible = true })
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
		end
	end)
	return self
end

return View
