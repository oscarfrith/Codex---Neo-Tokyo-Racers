-- Owns the race-entry vehicle-choice page drawing (header, selected vehicle, event facts, the vehicle rail and its button row); it owns no state, calls no remote, fires no bindable and writes no attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceEntry.VehicleView. Requires: Tokens, Text, Surface, Controls, Collections, Data, Input.
--
-- Owner's review notes that bind here: no "N of M vehicles eligible" text, no Category or Sort drop-downs, the
-- rail is in the model's order (rating, highest first), the button row sits in slot RailButtons (the rail heading
-- line, 64 high), and tier badges use the tier colours (Collections.TierBadge and the tiles' own badges).
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local kit = script.Parent.Parent.Kit
local Tokens = require(kit.Tokens)
local Text = require(kit.Text)
local Surface = require(kit.Surface)
local Controls = require(kit.Controls)
local Collections = require(kit.Collections)
local Data = require(kit.Data)
local Input = require(kit.Input)

local View = {}

local Space = Tokens.Space

local function holder(name, parent)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

local function place(instance, x, y, width, height)
	put(instance, "Position", UDim2.fromOffset(x, y))
	put(instance, "Size", UDim2.fromOffset(math.max(0, width), math.max(0, height)))
end

local function moveTo(instance, x, y)
	put(instance, "Position", UDim2.fromOffset(x, y))
end

-- A tier the kit can draw (the profile may carry "--" for a vehicle with no rating summary, Classic 267).
local function knownTier(tier)
	return Tokens.Tier[tier] ~= nil
end

-- Pure. Where the focus enters when the page opens: the selected vehicle's tile, else START, else BACK.
function View._focusTarget(tileUsable, startUsable)
	if tileUsable then
		return "Tile"
	elseif startUsable then
		return "Start"
	end
	return "Back"
end

-- A scope for the bindings that live only while this page shows (Input.Bind* asks only for :add).
local function newOpenScope()
	local items = {}
	local open = {}
	function open:add(item)
		table.insert(items, item)
		return item
	end
	function open:destroy()
		for index = #items, 1, -1 do
			local item = items[index]
			items[index] = nil
			item()
		end
	end
	return open
end

function View.Mount(layer, model, scope)
	local ctx = layer.Metrics
	local topLeft = layer.Slot("TopLeft")
	local rightColumn = layer.Slot("RightColumn")
	local bottomRail = layer.Slot("BottomRail")
	local railButtons = layer.Slot("RailButtons")
	local destroyed = false
	local page = nil
	local signatures = {}
	local self = {}

	local function lineOf(role)
		local size, scale = Text.SizeFor(role, ctx)
		return math.ceil(size * (scale or 1))
	end

	local function layout()
		if destroyed or not page or not page.Shown then
			return
		end
		local compact = ctx.Class == "Compact"
		local gap = ctx.Px(Space.Gap)
		local padDesign = compact and Space.TouchGap or Space.Pad
		local pad = ctx.Px(padDesign)
		page.FactsPanel.Set({ Pad = padDesign })

		-- Event facts, in the right column.
		local factsWidth = rightColumn.Size.X.Offset
		if factsWidth <= 0 then
			factsWidth = ctx.Px(compact and Space.CompactStatPanelWidth or Space.StatPanelWidth)
		end
		local factsHeight = page.Facts.Instance.Size.Y.Offset
		if factsHeight <= 0 then
			factsHeight = page.FactCount * ctx.Px(compact and Space.StatRowHeight or Space.FactRowHeight)
		end
		-- RightColumn is a sized slot (API2 2.4): a child fills it from its top-left. Only in a zero-size slot does
		-- the holder stand on the slot's anchor (capture race_entry_vehicle: anchored, it hung left of the column).
		put(page.FactsHolder, "AnchorPoint", rightColumn.Size.X.Offset > 0 and Vector2.zero or rightColumn.AnchorPoint)
		put(page.FactsHolder, "Size", UDim2.fromOffset(factsWidth, pad + factsHeight + pad))

		-- The selected vehicle, under the header: badge, name, category.
		local headerHeight = page.Header.Height()
		local label, head = lineOf("Label"), lineOf("SectionHead")
		local lineTop = headerHeight + gap
		local badge = page.Badge.Instance.Size
		local badgeWidth = page.BadgeShown and badge.X.Offset or 0
		local nameX = badgeWidth > 0 and (badgeWidth + gap) or 0
		local nameWidth = page.Name.Instance.Size.X.Offset
		local columnLeft = rightColumn.Position.X.Offset - factsWidth - topLeft.Position.X.Offset
		place(page.Line, 0, lineTop, math.max(0, columnLeft - gap), head)
		moveTo(page.Name.Instance, nameX, 0)
		moveTo(page.Category.Instance, nameX + nameWidth + gap, math.max(0, head - label))

		-- The large picture of the selected vehicle fills what is left above the button row (Regular only).
		local buttonsTop = railButtons.Position.Y.Offset - page.Row.Instance.Size.Y.Offset - topLeft.Position.Y.Offset
		local pictureTop = lineTop + head + gap
		put(page.Picture, "Visible", not compact and page.PictureId ~= "")
		if not compact then
			place(page.Picture, 0, pictureTop, columnLeft - gap, buttonsTop - gap - pictureTop)
		end
	end

	local function watch(instance)
		scope:connect(instance:GetPropertyChangedSignal("Size"), layout)
	end

	-- Input that exists only while this page shows, on the live layer only (a gallery or test stage has no Gui):
	-- Escape and ButtonB go back as BACK does, and the focus enters the rail on the selected vehicle when a
	-- gamepad or the keyboard is in use. A focus move or A on a tile only selects (the rail's OnSelected calls
	-- model.SelectVehicle); nothing here calls model.Start, which stays on the START button alone.
	local live = layer.Gui ~= nil and RunService:IsRunning()
	local openInput = nil
	local focusBefore = nil

	local function ownsFocus(object)
		return object:IsDescendantOf(page.Header.Instance) or object:IsDescendantOf(page.Rail.Instance)
			or object:IsDescendantOf(page.Row.Instance)
	end

	local function syncInput(mine)
		if not live or not page then
			return
		end
		if mine and not openInput then
			local opened = newOpenScope()
			openInput = opened
			Input.BindBack(opened, function()
				model.Back()
			end)
			if Input.ShouldEnterFocus(ctx) then
				pcall(function()
					focusBefore = GuiService.SelectedObject
					local chosen = model.SelectedVehicle()
					local tile = (chosen ~= nil and chosen ~= "" and page.Keys and page.Keys[chosen]) and page.Rail.Tile(chosen) or nil
					local start = page.Row.Button("Start")
					local target = View._focusTarget(tile ~= nil and tile.Instance.Active and tile.Instance.Visible,
						start ~= nil and start.Instance.Active)
					local button = start
					if target == "Tile" then
						button = tile
					elseif target == "Back" then
						button = page.Row.Button("Back")
					end
					GuiService.SelectedObject = button.Instance
				end)
			end
		elseif not mine and openInput then
			local closing = openInput
			openInput = nil
			closing:destroy()
			local before = focusBefore
			focusBefore = nil
			pcall(function()
				local current = GuiService.SelectedObject
				if current and ownsFocus(current) then
					-- Back to what held the focus before this page, unless that is one of this layer's own
					-- (now hidden) pages; the page that shows next enters its own focus.
					if before and before:IsDescendantOf(game) and not before:IsDescendantOf(layer.Gui) then
						GuiService.SelectedObject = before
					else
						GuiService.SelectedObject = nil
					end
				end
			end)
		end
	end

	local function build(vehicles)
		local built = { Shown = false, BadgeShown = false, PictureId = "", FactCount = #vehicles.Facts }
		built.Header = Controls.Header(topLeft, { Name = "VehicleHeader", Title = "RACE ENTRY", Sub = vehicles.Sub }, scope)
		watch(built.Header.Instance)

		built.Line = holder("SelectedVehicle", topLeft)
		built.Badge = Collections.TierBadge(built.Line, { Name = "SelectedTier", Tier = model.Tier(), Rating = 0, Size = "Large", Visible = false }, scope)
		built.Name = Text.Label(built.Line, { Name = "SelectedName", Text = "", Role = "SectionHead" }, scope)
		built.Category = Text.Label(built.Line, { Name = "SelectedCategory", Text = "", Role = "Label", Colour = "TextSecondary" }, scope)
		watch(built.Badge.Instance)
		watch(built.Name.Instance)

		built.Picture = Instance.new("ImageLabel")
		built.Picture.Name = "VehiclePicture"
		built.Picture.BackgroundTransparency = 1
		built.Picture.BorderSizePixel = 0
		built.Picture.ScaleType = Enum.ScaleType.Fit
		built.Picture.Visible = false
		built.Picture.Parent = topLeft

		built.FactsHolder = holder("EventFacts", rightColumn)
		built.FactsPanel = Surface.Panel(built.FactsHolder, {}, scope)
		built.Facts = Data.FactList(built.FactsPanel.Content, { Name = "Facts", Rows = {} }, scope)
		watch(built.Facts.Instance)

		built.Rail = Collections.Rail(bottomRail, {
			Name = "VehicleRail",
			Heading = vehicles.Heading,
			Count = vehicles.Count,
			OnSelected = function(key)
				-- A click or a focus move. The model accepts eligible vehicles only; a refusal puts the
				-- rail back on the model's choice.
				model.SelectVehicle(key)
				local chosen = model.SelectedVehicle()
				if chosen ~= key and chosen ~= "" and built.Keys and built.Keys[chosen] then
					built.Rail.Select(chosen)
				end
			end,
		}, scope)

		built.Row = Controls.ButtonRow(railButtons, {
			Name = "VehicleButtons",
			Buttons = {
				{ Id = "Back", Variant = "Default", Text = "BACK", Icon = "back", OnActivated = function()
					model.Back()
				end },
				{ Id = "Start", Variant = "Main", Text = vehicles.StartText, Icon = "race_flag", OnActivated = function()
					model.Start()
				end },
			},
		}, scope)
		watch(built.Row.Instance)
		return built
	end

	local function show(visible)
		page.Shown = visible
		page.Header.Set({ Visible = visible })
		put(page.Line, "Visible", visible)
		put(page.FactsHolder, "Visible", visible)
		page.Rail.Set({ Visible = visible })
		page.Row.Set({ Visible = visible })
		if not visible then
			put(page.Picture, "Visible", false)
		end
	end

	local function draw(vehicles, snap)
		page.Header.Set({ Title = snap.Title, Sub = vehicles.Sub })

		-- The rail: every owned vehicle in the model's order; the ones this event does not take are Locked.
		local items, parts, keys = {}, {}, {}
		for index, row in ipairs(vehicles.Rows) do
			local tier = knownTier(row.Tier) and row.Tier or nil
			local sub = row.Eligible and row.Category or vehicles.LockedSub
			local status = row.Eligible and "None" or "Locked"
			local rating = math.floor(row.Rating)
			items[index] = {
				Key = row.VehicleId,
				Title = row.Name,
				Sub = sub,
				Tier = tier,
				Rating = rating,
				Image = row.Image ~= "" and row.Image or nil,
				Icon = "car",
				Status = status,
			}
			keys[row.VehicleId] = true
			parts[index] = table.concat({ row.VehicleId, row.Name, sub, tostring(tier), tostring(rating), row.Image, status }, "=")
		end
		local railSignature = table.concat(parts, "|")
		if signatures.Rail ~= railSignature then
			signatures.Rail = railSignature
			page.Keys = keys
			page.Rail.SetItems(items)
		end
		if vehicles.Selected and signatures.Selected ~= vehicles.SelectedId .. "@" .. railSignature then
			signatures.Selected = vehicles.SelectedId .. "@" .. railSignature
			page.Rail.Select(vehicles.SelectedId)
		end
		local heading = vehicles.Heading .. "#" .. vehicles.Count
		if signatures.Heading ~= heading then
			signatures.Heading = heading
			page.Rail.SetHeading(vehicles.Heading, vehicles.Count)
		end

		-- The selected vehicle line and picture.
		local selected = vehicles.Selected
		local badgeShown = selected ~= nil and knownTier(selected.Tier)
		page.BadgeShown = badgeShown
		if badgeShown then
			page.Badge.Set({ Tier = selected.Tier, Rating = math.floor(selected.Rating), Visible = true })
		else
			page.Badge.Set({ Visible = false })
		end
		page.Name.Set({ Text = selected and selected.Name or vehicles.EmptyText })
		page.Category.Set({ Text = selected and selected.Category or "" })
		page.PictureId = selected and selected.Image or ""
		put(page.Picture, "Image", page.PictureId)

		local rows, factParts = {}, {}
		for index, fact in ipairs(vehicles.Facts) do
			rows[index] = { Id = fact.Id, Icon = fact.Icon, Label = fact.Label, Value = fact.Value, Kind = fact.Kind }
			factParts[index] = fact.Id .. "=" .. fact.Label .. "=" .. fact.Value .. "=" .. fact.Kind
		end
		local factSignature = table.concat(factParts, "|")
		if signatures.Facts ~= factSignature then
			signatures.Facts = factSignature
			page.FactCount = #rows
			page.Facts.SetRows(rows)
		end

		page.Row.Button("Start").Set({ Text = vehicles.StartText, Disabled = not vehicles.Enabled })
	end

	function self.Render(_reason)
		if destroyed then
			return
		end
		-- Fetch first, then draw; an overtaken snapshot is not drawn.
		local snap = model.Snapshot()
		if snap.Revision ~= model.Revision() then
			return
		end
		local vehicles = (snap.Open == true and snap.Page == "Vehicles") and snap.Vehicles or nil
		if vehicles and not page then
			page = build(vehicles)
		end
		if not page then
			return
		end
		show(vehicles ~= nil)
		if vehicles then
			draw(vehicles, snap)
			layout()
		end
		syncInput(vehicles ~= nil)
	end

	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout == false then
				return
			end
			task.defer(layout)
		end)
	end

	function self.Destroy()
		if destroyed then
			return
		end
		destroyed = true
		if openInput then
			openInput:destroy()
			openInput = nil
		end
		if page then
			page.Header.Destroy()
			page.Rail.Destroy()
			page.Row.Destroy()
			page.Line:Destroy()
			page.Picture:Destroy()
			page.FactsHolder:Destroy()
		end
	end

	return self
end

return View
