-- Owns the drawing of the in-race HUD (position, lap, timer, pips, delta, order board, reset and exit, route map) over a HUD model; no remote, bindable or attribute.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.RaceSession.RaceHudView. Requires: Tokens, Text, Surface, Controls, Collections, Data, BigNumber, Overlay, Perf, Presence.
--
-- View.Mount(layer, model, scope, options?) -> { Render, Destroy }
--   layer    the static layer (SharedInRaceHUD); options.Live is the live layer (SharedInRaceHUDLive). With no
--            Live layer (gallery, tests) everything is mounted on the one layer.
--   options  { Live: Layer?, ConfirmHost: GuiObject?, NoPresence: boolean? }
-- Static layer: position block, order board, buttons. Live layer: timer, delta chip, pips, route map and marker.

local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Text = require(Kit.Text)
local Surface = require(Kit.Surface)
local Controls = require(Kit.Controls)
local Collections = require(Kit.Collections)
local Data = require(Kit.Data)
local BigNumber = require(Kit.BigNumber)
local Overlay = require(Kit.Overlay)
local Perf = require(Kit.Perf)
local Presence = require(Kit.Presence)

local Space = Tokens.Space
local MAP_ARROW_SCALE = 1.5 -- the arrow image has more margin than the badge it replaced

local View = {}

View.BOARD_ROWS_REGULAR = 4 -- r13a: four rows round the player
View.BOARD_ROWS_COMPACT = 3 -- c08
View.MAX_PIPS = 32
View.MAX_BIG_NUMBER = 99 -- the position number has two cells

local function put(instance, property, value)
	if instance[property] ~= value then
		instance[property] = value
	end
end

-- A transparent frame that sizes to its children and stacks them. `anchored` copies the slot's anchor (API1 8).
local function holder(name, parent, direction, anchored)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.AutomaticSize = Enum.AutomaticSize.XY
	if anchored then
		frame.AnchorPoint = parent.AnchorPoint
	end
	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.FillDirection = direction
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	frame.Parent = parent
	return frame, list
end

-- One string that changes exactly when the rows do.
function View._signature(rows)
	local pieces = {}
	for _, row in ipairs(rows) do
		table.insert(pieces, tostring(row.Key))
		table.insert(pieces, row.You and "1" or "0")
		for _, text in ipairs(row.Columns) do
			table.insert(pieces, text)
		end
	end
	return table.concat(pieces, "\31")
end

function View._digits(value, maximum)
	value = tonumber(value)
	if not value then
		return "-"
	end
	return tostring(math.clamp(math.floor(value), 0, maximum))
end

function View.Mount(layer, model, scope, options)
	options = options or {}
	local live = options.Live or layer
	local ctx = layer.Metrics
	local parts = nil
	local destroyed = false
	local shown = nil
	local confirmHandle = nil
	local releasePresence = nil
	local perfHandle = nil
	-- Read by the frame step; assigned by build.
	local timer, mapArt, markerRoot = nil, nil, nil
	local markerVisible = false

	local function closeConfirm()
		local handle = confirmHandle
		if handle then
			confirmHandle = nil
			handle.Cancel()
		end
	end

	local function destroyParts()
		local old = parts
		if not old then
			return
		end
		parts = nil
		timer, mapArt, markerRoot = nil, nil, nil
		markerVisible = false
		for _, component in ipairs(old.Components) do
			component.Destroy()
		end
		for _, frame in ipairs(old.Frames) do
			frame:Destroy()
		end
	end

	local function build()
		local compact = ctx.Class == "Compact"
		local p = { Class = ctx.Class, Compact = compact, Components = {}, Frames = {} }
		local function keep(component)
			table.insert(p.Components, component)
			return component
		end
		local function frame(name, parent, direction, anchored)
			local item, list = holder(name, parent, direction, anchored)
			table.insert(p.Frames, item)
			return item, list
		end
		p.BoardRows = compact and View.BOARD_ROWS_COMPACT or View.BOARD_ROWS_REGULAR

		-- The vignette goes in the layer's scrim gui, which is ordered behind every other HUD gui; a stage layer
		-- (tests, gallery) has none and keeps it in its root.
		keep(Surface.Scrim(layer.ScrimRoot or layer.Root, { Name = "HudScrim", Kind = "Hud" }, scope))

		-- Top left: position (race) or lap (time trial), with the lap or tier line under it.
		local block = frame("LapProgress", layer.Slot("TopLeftHud"), Enum.FillDirection.Vertical, true)
		p.Head = keep(Text.Label(block, { Name = "Heading", Text = "LAP", Role = "Status", Align = "Left", Shadow = true,
			Visible = false, LayoutOrder = 1 }, scope))
		local numberRow, numberList = frame("Number", block, Enum.FillDirection.Horizontal, false)
		numberRow.LayoutOrder = 2
		numberList.VerticalAlignment = Enum.VerticalAlignment.Bottom
		p.Big = keep(BigNumber.New(numberRow, { Name = "Value", Text = "-", Role = "Position", Align = "Right", MaxCells = 2,
			LayoutOrder = 1 }, scope))
		local side = frame("Side", numberRow, Enum.FillDirection.Vertical, false)
		side.LayoutOrder = 2
		p.Suffix = keep(Text.Label(side, { Name = "Suffix", Text = "", Role = "SectionHead", Colour = "Pink", Align = "Left",
			Shadow = true, LayoutOrder = 1 }, scope))
		p.Count = keep(Text.Label(side, { Name = "Count", Text = "", Role = "Status", Colour = "TextSecondary", Align = "Left",
			Shadow = true, LayoutOrder = 2 }, scope))
		local stripRow, stripList = frame("Strip", block, Enum.FillDirection.Horizontal, false)
		stripRow.LayoutOrder = 3
		stripList.VerticalAlignment = Enum.VerticalAlignment.Center
		p.Badge = keep(Collections.TierBadge(stripRow, { Name = "Tier", Tier = "E", Size = "Small", Visible = false,
			LayoutOrder = 1 }, scope))
		p.Strip = keep(Text.Label(stripRow, { Name = "Lap", Text = "", Role = "TileName", Align = "Left", Shadow = true,
			LayoutOrder = 2 }, scope))

		-- Top centre, live: timer with the Pink underline, the lap delta chip and the checkpoint pips.
		local metric, metricList = frame("PrimaryMetric", live.Slot("TopCentreHud"), Enum.FillDirection.Vertical, true)
		metricList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		p.TimerHeading = keep(Text.Label(metric, { Name = "Heading", Text = "CURRENT LAP", Role = "Label",
			Colour = "TextSecondary", Align = "Centre", Shadow = true, LayoutOrder = 1 }, scope))
		local timerBox = Instance.new("Frame")
		timerBox.Name = "TimerBox"
		timerBox.BackgroundTransparency = 1
		timerBox.BorderSizePixel = 0
		timerBox.AutomaticSize = Enum.AutomaticSize.XY
		timerBox.LayoutOrder = 2
		timerBox.Parent = metric
		table.insert(p.Frames, timerBox)
		p.Timer = keep(BigNumber.New(timerBox, { Name = "Value", Text = "00:00.000", Role = "Timer", Align = "Centre",
			MaxCells = 9 }, scope))
		keep(Surface.Hairline(timerBox, { Name = "Underline", Edge = "Bottom", Colour = "Pink" }, scope))
		p.Delta = keep(Collections.Chip(metric, { Name = "Delta", Text = "", Kind = "Cyan", Visible = false, LayoutOrder = 3 }, scope))
		p.Pips = keep(Data.SegmentedBar(metric, { Name = "Pips", Value = 0, Segments = 1, Visible = false, LayoutOrder = 4 }, scope))

		-- Top right: the live order (race) or personal best and session laps (time trial). Rows are pooled.
		local boardWidth = compact and Space.CompactStatPanelWidth or Space.ListWidth
		local rowHeight = compact and Space.CompactStatusHeight or Space.StatRowHeight
		local board = Instance.new("Frame")
		board.Name = "SessionBoard"
		board.BackgroundTransparency = 1
		board.BorderSizePixel = 0
		board.AnchorPoint = layer.Slot("TopRight").AnchorPoint
		board.Parent = layer.Slot("TopRight")
		table.insert(p.Frames, board)
		p.Board = keep(Collections.List(board, { Name = "Rows", RowHeight = rowHeight, Width = boardWidth }, scope))

		-- Reset and exit. Icon-only on Compact (c08).
		local controls, controlsList = frame("SessionControls", layer.Slot("HudButtons"), Enum.FillDirection.Horizontal, true)
		p.Reset = keep(Controls.Button(controls, { Name = "Reset", Variant = "Default", Size = "Hud", Text = "RESET",
			Icon = "back", IconOnly = compact, LayoutOrder = 1, OnActivated = function()
				model.RequestReset()
			end }, scope))
		p.Exit = keep(Controls.Button(controls, { Name = "Exit", Variant = "Default", Size = "Hud", Text = "EXIT",
			Icon = "exit", IconOnly = compact, LayoutOrder = 2, OnActivated = function()
				model.RequestExit()
			end }, scope))

		-- Route map, live. Classic draws it on desktop only (S149); Compact has none (c08).
		if not compact and ctx.Arrangement ~= "TouchDrive" then
			local mapHolder, mapList = frame("RaceMap", live.Slot("Minimap"), Enum.FillDirection.Vertical, true)
			mapList.HorizontalAlignment = Enum.HorizontalAlignment.Center
			mapHolder.Visible = false
			p.MapHolder = mapHolder
			-- No panel behind it: the route image floats over the world with the player arrow on it.
			local mapFrame = Instance.new("Frame")
			mapFrame.Name = "MapFrame"
			mapFrame.BackgroundTransparency = 1
			mapFrame.BorderSizePixel = 0
			mapFrame.LayoutOrder = 1
			mapFrame.Parent = mapHolder
			p.MapFrame = mapFrame
			local art = Instance.new("ImageLabel")
			art.Name = "SimplifiedRaceMap"
			art.BackgroundTransparency = 1
			art.BorderSizePixel = 0
			art.ScaleType = Enum.ScaleType.Fit
			art.Size = UDim2.fromScale(1, 1)
			art.Parent = mapFrame
			p.MapArt = art
			local marker = Instance.new("ImageLabel")
			marker.Name = "PlayerMarker"
			marker.AnchorPoint = Vector2.new(0.5, 0.5)
			marker.BackgroundTransparency = 1
			marker.BorderSizePixel = 0
			marker.Image = Tokens.Asset("MapPlayerArrow") or ""
			marker.ImageColor3 = Tokens.Colour.White
			marker.ZIndex = 2
			marker.Visible = false
			marker.Parent = art
			p.Marker = marker
			p.MapLabel = keep(Text.Label(mapHolder, { Name = "EventName", Text = "", Role = "Label", Colour = "TextSecondary",
				Align = "Centre", Shadow = true, LayoutOrder = 2 }, scope))
		end

		function p.ApplyLayout()
			local gap = UDim.new(0, ctx.Px(Space.Gap))
			put(numberList, "Padding", gap)
			put(stripList, "Padding", gap)
			put(metricList, "Padding", gap)
			put(controlsList, "Padding", gap)
			put(board, "Size", UDim2.fromOffset(ctx.Px(boardWidth), ctx.Px(rowHeight) * p.BoardRows))
			if p.MapFrame then
				put(p.MapFrame, "Size", UDim2.fromOffset(ctx.Px(Space.TileWidth), ctx.Px(Space.TileHeight)))
			end
		end
		p.ApplyLayout()

		parts = p
		timer = p.Timer
		mapArt = p.MapArt
		markerRoot = p.Marker
		markerVisible = false
	end

	local function setShown(active)
		if shown == active then
			return
		end
		shown = active
		layer.SetVisible(active)
		if live ~= layer then
			live.SetVisible(active)
		end
		if not options.NoPresence then
			if active and not releasePresence then
				releasePresence = Presence.Open("RaceHud", "Race")
			elseif not active and releasePresence then
				local release = releasePresence
				releasePresence = nil
				release()
			end
		end
	end

	local function renderConfirm()
		if not model.ConfirmOpen() then
			closeConfirm()
			return
		end
		if confirmHandle or not (options.ConfirmHost or layer.Gui) then
			return
		end
		-- The shared confirmation (API2 5.5): NO left, YES right, NO focused, Escape and B cancel.
		confirmHandle = Overlay.Confirm(layer.Root, {
			Title = model.ConfirmTitle(),
			Body = model.ConfirmBody(),
			CancelText = "NO",
			ConfirmText = "YES",
			Host = options.ConfirmHost,
			OnConfirm = function()
				confirmHandle = nil
				model.ConfirmExit()
			end,
			OnCancel = function()
				confirmHandle = nil
				model.CancelExit()
			end,
		})
	end

	local function render()
		if destroyed then
			return
		end
		local active = model.IsActive()
		setShown(active)
		if not active then
			closeConfirm()
			return
		end
		local p = parts
		local race = model.Mode() == "Race"
		local target = model.LapTargetText()

		p.Head.Set({ Visible = not race })
		if race then
			p.Big.SetText(View._digits(model.Place(), View.MAX_BIG_NUMBER))
			p.Suffix.Set({ Text = model.PlaceSuffix(), Visible = true })
			p.Count.Set({ Text = "/ " .. tostring(model.ParticipantCount() or "--") })
			p.Strip.Set({ Text = "LAP " .. tostring(model.CurrentLap()) .. " / " .. target })
			p.Badge.Set({ Visible = false })
		else
			p.Big.SetText(View._digits(model.CurrentLap(), View.MAX_BIG_NUMBER))
			p.Suffix.Set({ Text = "", Visible = false })
			p.Count.Set({ Text = "/ " .. target })
			local tier = model.VehicleTier()
			if tier and Tokens.Tier[tier] then
				p.Badge.Set({ Tier = tier, Visible = true })
				p.Strip.Set({ Text = "TIER " .. tier })
			else
				p.Badge.Set({ Visible = false })
				p.Strip.Set({ Text = "" })
			end
		end

		p.TimerHeading.Set({ Text = model.TimerHeading() })
		if model.TimerSeconds() == nil then
			p.Timer.SetText(model.TimerText())
		end
		local deltaText = model.DeltaText()
		if deltaText then
			local delta = model.Delta()
			p.Delta.Set({ Text = deltaText, Kind = (delta and delta.Seconds <= 0) and "Cyan" or "Pink", Visible = true })
		else
			p.Delta.Set({ Visible = false })
		end
		local passed, count = model.Pips()
		if count > 0 then
			p.Pips.Set({ Segments = math.min(count, View.MAX_PIPS), Value = passed / count, Visible = true })
		else
			p.Pips.Set({ Visible = false })
		end

		-- An unchanged board is not handed to the list again (a position update arrives on every checkpoint).
		local rows = model.BoardRows(p.BoardRows)
		local boardKey = View._signature(rows)
		if boardKey ~= p.BoardKey then
			p.BoardKey = boardKey
			local items = {}
			for index, row in ipairs(rows) do
				items[index] = { Key = row.Key, Columns = row.Columns, Accent = row.You == true,
					State = row.You and "Selected" or "Default" }
			end
			p.Board.SetItems(items)
		end

		p.Reset.Set({ Text = model.ResetText() })
		p.Exit.Set({ Text = model.ExitText() })

		if p.MapArt then
			local image = model.MapImage()
			put(p.MapHolder, "Visible", image ~= "")
			put(p.MapArt, "Image", image)
			put(p.MapArt, "ImageTransparency", 1 - model.MapOpacity())
			local markerSize = ctx.Px(Space.Pad * MAP_ARROW_SCALE * model.MapMarkerScale())
			put(p.Marker, "Size", UDim2.fromOffset(markerSize, markerSize))
			p.MapLabel.Set({ Text = model.DisplayName() })
		end

		renderConfirm()
	end

	-- The one frame step of the live layer: the running timer and the route-map marker. No lookups, no creation.
	local function step(dt)
		if model.TimerSeconds() ~= nil then
			timer.SetText(model.TimerText())
		end
		if mapArt then
			local size = mapArt.AbsoluteSize
			local visible, x, y, heading = model.MapStep(dt, size.X, size.Y)
			if visible then
				markerRoot.Position = UDim2.fromScale(x, y)
				markerRoot.Rotation = heading
			end
			if visible ~= markerVisible then
				markerVisible = visible
				markerRoot.Visible = visible
			end
		end
	end

	build()
	perfHandle = Perf.Bind("RaceHud", live.Root, step)

	if ctx.Changed then
		scope:connect(ctx.Changed, function(change)
			if destroyed or (type(change) == "table" and change.Layout == false) then
				return
			end
			if parts and parts.Class ~= ctx.Class then
				destroyParts()
				build()
			elseif parts then
				parts.ApplyLayout()
			end
			render()
		end)
	end

	local view = {}
	view.Render = function(_reason)
		render()
	end
	view.Destroy = function()
		if destroyed then
			return
		end
		destroyed = true
		closeConfirm()
		if perfHandle then
			perfHandle.Disconnect()
			perfHandle = nil
		end
		if releasePresence then
			local release = releasePresence
			releasePresence = nil
			release()
		end
		destroyParts()
	end
	view._parts = function()
		return parts
	end
	return view
end

return View
