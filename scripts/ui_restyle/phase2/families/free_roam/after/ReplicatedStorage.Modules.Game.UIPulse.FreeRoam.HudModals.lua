-- Owns the three free-roam HUD modal views (Controls, Settings, Get Cash) and the ModalLayer frame that holds them; no remote, attribute or bindable: every action is a HudModel call.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.HudModals. Requires: Kit.Tokens, Kit.Metrics, Kit.Text, Kit.Surface, Kit.Controls, Kit.Collections, Kit.Data, Kit.Overlay (resolved on the first mount).
--
-- Names Classic onboarding reads (OnboardingClient 459-462, 476): DesignRoot.ModalLayer, visible exactly while a modal
-- is open, and its child Controls, visible exactly while the controls modal shows. ModalLayer is the only instance
-- made at mount; each modal is created on its first open (PC 5.1 rule 3).
-- Classic line references: D = DesktopFreeRoamHudUI, M = MobileFreeRoamHudUI.

local TweenService = game:GetService("TweenService")

-- D554-555, with M / MAP added (the full map key, FullMapUI).
local DRIVING_ROWS = { { "W", "ACCELERATE" }, { "S", "BRAKE / REVERSE" }, { "A / D", "STEER" }, { "SPACE", "DRIFT" },
	{ "SHIFT", "BOOST" }, { "R", "RESET VEHICLE" }, { "M", "MAP" } }
local FOOT_ROWS = { { "WASD", "MOVE" }, { "SHIFT", "SPRINT" }, { "SPACE", "JUMP" }, { "E", "INTERACT / ENTER VEHICLE" },
	{ "MOUSE", "CAMERA" } }
local ACCESS_OPTIONS = { "FRIENDS", "ANYONE", "NOBODY" } -- D599
local MINIMAP_OPTIONS = { "ROTATE", "NORTH UP" } -- D633
local CONTROL_MODES = { "Arrows", "Thumbstick", "Tilt" } -- M201
local PACK_COUNT = 4 -- D563
local BEST_PACK = 4 -- D568
local LAYER_ZINDEX = 10

local HudModals = {}

local kitCache
local function kit()
	if not kitCache then
		local folder = script.Parent.Parent.Kit
		kitCache = {
			Tokens = require(folder.Tokens),
			Metrics = require(folder.Metrics),
			Text = require(folder.Text),
			Surface = require(folder.Surface),
			Controls = require(folder.Controls),
			Collections = require(folder.Collections),
			Data = require(folder.Data),
			Overlay = require(folder.Overlay),
		}
	end
	return kitCache
end
function HudModals._setKit(replacement) kitCache = replacement end

local function frame(name, parent)
	local item = Instance.new("Frame")
	item.Name = name
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Parent = parent
	return item
end

local function listLayout(parent, direction, padding)
	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.FillDirection = direction
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding)
	layout.Parent = parent
	return layout
end

-- Pure: which modal shows, whether the layer shows, and the backdrop mode, from the model state (D429-473).
function HudModals._plan(state)
	local active = state.ActiveModal
	local fading = active == "Controls" and state.ControlsFading == true
	local backdrop = "Clear"
	if active == "Controls" and state.ControlsReveal then backdrop = fading and "Fading" or "Opaque" end
	return (active and not fading) and active or nil, active ~= nil, backdrop
end

-- Pure: the segment items of one settings row.
function HudModals._segments(options, lockedOf)
	local items = {}
	for _, option in ipairs(options) do
		table.insert(items, { Id = option, Text = string.upper(option), Locked = lockedOf and lockedOf(option) or nil })
	end
	return items
end

-- Pure: the height of a vertical stack of parts with `gap` between them (real pixels).
function HudModals._stack(parts, gap)
	local total = 0
	for index, height in ipairs(parts) do
		total += height + (index > 1 and gap or 0)
	end
	return total
end

-- Pure: the design Height of the modal panel that holds `content` real pixels under its title row. Overlay.Modal
-- insets the content by one pad on every side and puts one pad under the title; Surface.Panel scales Height back.
function HudModals._panelHeight(content, title, pad, scale)
	return (pad * 3 + title + content) / scale
end

-- Pure: the height the pack list may take: all of it, or what the screen leaves (never less than one row).
function HudModals._listRoom(full, row, screen, taken)
	return math.min(full, math.max(row, screen - taken))
end

-- root is the static layer's Root (DesignRoot). opts = { Player: Player?, SampleCash: number? } (gallery: no player).
function HudModals.Mount(root, model, scope, opts)
	opts = opts or {}
	local k = kit()
	local ctx = k.Metrics.Of(root)
	local compact = ctx.Class == "Compact"
	local space = k.Tokens.Space
	local px = ctx.Px
	-- The kit's 1080 px to Compact dp factor (Controls and Collections use the same one for gaps).
	local unit = compact and space.TouchGap / space.Pad or 1
	local gap = px(space.Gap * unit)
	local pad = px(space.Pad)
	-- Token request (NOTES_a): CompactModalWidth. Until it exists Compact modals use CompactPromptWidth (300 dp);
	-- Settings takes ListWidth there, as its label and segments share one row (c04a).
	local width = compact and space.CompactPromptWidth or space.ModalMaxWidth
	local rowHeight = compact and ctx.Touch(space.CompactButtonDrawn) or px(space.StatRowHeight)
	local footerHeight = ctx.Touch(compact and space.CompactButtonDrawn or space.ButtonHeight)
	local titleSize, titleScale = k.Text.SizeFor("SectionHead", ctx)
	local titleHeight = math.ceil(titleSize * (titleScale or 1))

	local layer = frame("ModalLayer", root)
	layer.BackgroundColor3 = k.Tokens.Colour.Black
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = LAYER_ZINDEX
	layer.Visible = false

	local self = { Layer = layer }
	local modals = {}
	local syncing = false
	local shownName
	local backdropMode = "Clear"
	local tween
	local kitClosing -- the modal whose own close is running: Render must not call Close on it again

	local function footer(content, order)
		local holder = frame("Footer", content)
		holder.LayoutOrder = order
		holder.Size = UDim2.new(1, 0, 0, footerHeight)
		local layout = listLayout(holder, Enum.FillDirection.Horizontal, gap)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		return holder
	end

	-- CONTROLS (D545-558) ----------------------------------------------------------------------------------------
	local function buildControls(content, own)
		listLayout(content, Enum.FillDirection.Vertical, gap)
		local columns = frame("Columns", content)
		columns.LayoutOrder = 1
		-- Compact: short rows and small caps, so the title, the seven keys and the footer fit a 320 dp high screen
		-- (rows of the touch height put DONE under the screen edge).
		local keyRow = compact and px(space.CompactStatusHeight) or rowHeight
		local capSize = compact and space.Pad or nil
		local rows = (compact and #DRIVING_ROWS or math.max(#DRIVING_ROWS, #FOOT_ROWS)) + 1
		columns.Size = UDim2.new(1, 0, 0, rows * keyRow)

		local function column(name, title, list, order)
			local holder = frame(name, columns)
			holder.LayoutOrder = order
			holder.Size = compact and UDim2.new(1, 0, 1, 0) or UDim2.new(0.5, -gap, 1, 0)
			holder.Position = (compact or order == 1) and UDim2.new() or UDim2.new(0.5, gap, 0, 0)
			listLayout(holder, Enum.FillDirection.Vertical, 0)
			local head = frame("Head", holder)
			head.LayoutOrder = 0
			head.Size = UDim2.new(1, 0, 0, keyRow)
			k.Text.Label(head, { Name = "Title", Text = title, Role = "Label", Colour = "Pink", Align = "Left" }, own)
			for index, entry in ipairs(list) do
				local row = frame("Row" .. index, holder)
				row.LayoutOrder = index
				row.Size = UDim2.new(1, 0, 0, keyRow)
				local layout = listLayout(row, Enum.FillDirection.Horizontal, gap)
				layout.VerticalAlignment = Enum.VerticalAlignment.Center
				k.Surface.KeyCap(row, { Name = "Key", Text = entry[1], Size = capSize, LayoutOrder = 1 }, own)
				k.Text.Label(row, { Name = "Action", Text = entry[2], Role = "Value", Colour = "White", Align = "Left", LayoutOrder = 2 }, own)
			end
			return holder
		end
		column("Driving", "DRIVING", DRIVING_ROWS, 1)
		-- Compact shows the driving column only: on-foot keys do not apply to a phone, and the modal is opened there
		-- only by a keyboard or gamepad player.
		if not compact then column("OnFoot", "ON FOOT", FOOT_ROWS, 2) end

		local parts = { rows * keyRow }
		if not compact then
			local hint = frame("AutoHint", content)
			hint.LayoutOrder = 2
			hint.Size = UDim2.new(1, 0, 0, rowHeight)
			k.Text.Label(hint, { Name = "HintText", Text = "Controls change automatically when entering a vehicle.", Role = "Body",
				Colour = "TextMuted", Align = "Left", Wrap = true }, own)
			table.insert(parts, rowHeight)
		end
		table.insert(parts, footerHeight)

		local done = k.Controls.Button(footer(content, 3), {
			Name = "Done", Variant = "Main", Text = "DONE", Icon = "tick",
			OnActivated = function() model.CompleteControls() end,
		}, own)
		local shownText = "DONE"
		return {
			Height = HudModals._stack(parts, gap),
			Sync = function(state)
				-- D472: NEXT during the first-drive reveal.
				local text = state.ControlsReveal and "NEXT" or "DONE"
				if text ~= shownText then
					shownText = text
					done.Set({ Text = text })
				end
			end,
		}
	end

	-- SETTINGS (D594-618, D631-635, M198-213). Rows that do nothing in Classic are not rebuilt (PC 8). ---------------
	local function buildSettings(content, own)
		listLayout(content, Enum.FillDirection.Vertical, gap)
		local syncs = {}
		local settingHeight = compact and rowHeight or (rowHeight + gap + px(space.Pad))

		local function settingRow(order, name, title, body, options, lockedOf, current, onPick)
			local row = frame(name, content)
			row.LayoutOrder = order
			local labelHeight = px(space.Pad)
			row.Size = UDim2.new(1, 0, 0, settingHeight)
			local heading = k.Text.Label(row, { Name = "Title", Text = title, Role = compact and "Label" or "Button", Colour = "White", Align = "Left" }, own)
			if compact then
				-- c04a: the label sits left of its segments on one row (a label above them made three rows taller
				-- than a phone screen).
				local line = k.Text.SizeFor("Label", ctx)
				heading.Instance.Position = UDim2.fromOffset(0, math.floor((rowHeight - line) / 2))
			end
			if body and not compact then
				local sub = frame("Sub", row)
				sub.Position = UDim2.fromOffset(0, rowHeight)
				sub.Size = UDim2.new(1, 0, 0, labelHeight)
				k.Text.Label(sub, { Name = "Body", Text = body, Role = "Body", Colour = "TextSecondary", Align = "Left" }, own)
			end
			local shown = current()
			local tabs
			tabs = k.Controls.Tabs(row, {
				Name = "Options", Style = "Segment", Tabs = HudModals._segments(options, lockedOf), Selected = shown,
				OnSelected = function(id)
					if syncing then return end
					shown = id
					onPick(id)
				end,
			}, own)
			tabs.Instance.AnchorPoint = Vector2.new(1, 0)
			tabs.Instance.Position = UDim2.fromScale(1, 0)
			table.insert(syncs, function()
				local value = current()
				-- Tabs.Select throws on an id it does not hold (a stray attribute value): keep the shown one then.
				if value ~= shown and table.find(options, value) then
					shown = value
					syncing = true
					tabs.Select(value)
					syncing = false
				end
			end)
		end

		local order = 0
		if model.GetState().Touch then
			order += 1
			-- M201. The title follows the preview (c04a); Classic reads "MOBILE CONTROLS".
			settingRow(order, "TouchControls", "TOUCH CONTROLS", nil, CONTROL_MODES, model.IsControlModeLocked,
				model.GetControlMode, model.SetControlMode)
		end
		order += 1
		settingRow(order, "MinimapMode", "MINIMAP", "How the minimap turns as you drive.", MINIMAP_OPTIONS, nil,
			model.GetMinimapMode, model.SetMinimapMode)
		order += 1
		settingRow(order, "Passengers", "PASSENGERS", "Who may ride in your vehicle.", ACCESS_OPTIONS, nil,
			model.GetPassengerAccess, model.SetPassengerAccess)

		k.Controls.Button(footer(content, order + 1), {
			Name = "Done", Variant = "Main", Text = "DONE", Icon = "tick",
			OnActivated = function() model.CloseModal() end,
		}, own)
		local parts = table.create(order, settingHeight)
		table.insert(parts, footerHeight)
		return {
			Height = HudModals._stack(parts, gap),
			Sync = function()
				for _, sync in ipairs(syncs) do sync() end
			end,
		}
	end

	-- GET CASH (D560-582). No purchase remote: every pack toasts through the model (D577). ---------------------------
	local function buildCash(content, own)
		listLayout(content, Enum.FillDirection.Vertical, gap)
		local foot = footer(content, 4)
		local parts = {}
		-- Regular: the balance has its own row. Compact: it sits in the footer beside CLOSE and the note is left out
		-- (each pack row already says NOT ENABLED), or CLOSE would be under the screen edge on a phone.
		local chipParent = foot
		if not compact then
			chipParent = frame("Balance", content)
			chipParent.LayoutOrder = 1
			chipParent.Size = UDim2.new(1, 0, 0, px(space.StatusHeight))
			table.insert(parts, px(space.StatusHeight))
		end
		local chip = k.Data.CashChip(chipParent, { Name = "BalanceChip", Compact = compact, LayoutOrder = 1 }, own)
		if opts.Player then
			-- Bind may yield once on its first use (API2 3.5); it never blocks the modal.
			own:task(function()
				local ok, message = pcall(chip.Bind, opts.Player)
				if not ok then warn("[Pulse.HudModals] cash chip bind failed: " .. tostring(message)) end
			end)
		elseif opts.SampleCash then
			chip.SetAmount(opts.SampleCash)
		end

		-- Collections.List draws rows of this height (never under the touch minimum) with two hairlines between them.
		local packDesign = compact and space.TouchMin or space.ListRowHeight
		local packHeight = math.max(px(packDesign), ctx.Touch(1))
		local packGap = px((space.Hairline + space.Hairline) * unit)
		local noteHeight = px(space.Pad)
		-- Everything in the panel but the list: the panel's own insets and title, then the rows around the list.
		local taken = pad * 3 + titleHeight + gap + footerHeight
		if not compact then
			taken += px(space.StatusHeight) + gap + noteHeight + gap
		end
		local packsHeight = HudModals._listRoom(HudModals._stack(table.create(PACK_COUNT, packHeight), packGap), packHeight,
			math.floor(ctx.Size.Y), taken)
		local packs = frame("Packs", content)
		packs.LayoutOrder = 2
		packs.Size = UDim2.new(1, 0, 0, packsHeight)
		table.insert(parts, packsHeight)
		local items = {}
		for index = 1, PACK_COUNT do
			table.insert(items, {
				Key = tostring(index), Title = "PACK " .. index, Sub = "CASH PACK",
				Chip = index == BEST_PACK and "BEST VALUE" or "NOT ENABLED", ChipKind = index == BEST_PACK and "Yellow" or "Neutral",
				-- Every press toasts (D577). The list's OnSelected fires only when the selection changes, and on a
				-- gamepad focus move, so it is not used.
				OnActivated = function() model.CashPackPressed() end,
			})
		end
		local list = k.Collections.List(packs, { Name = "PackList", RowHeight = packDesign }, own)
		list.SetItems(items)

		if not compact then
			local note = frame("Secure", content)
			note.LayoutOrder = 3
			note.Size = UDim2.new(1, 0, 0, noteHeight)
			k.Text.Label(note, { Name = "NoteText", Text = "CASH PRODUCTS ARE NOT ENABLED YET", Role = "Label", Colour = "TextSecondary", Align = "Left" }, own)
			table.insert(parts, noteHeight)
		end

		k.Controls.Button(foot, {
			Name = "Close", Variant = "Default", Text = "CLOSE", Icon = "back", LayoutOrder = 2,
			OnActivated = function() model.CloseModal() end,
		}, own)
		table.insert(parts, footerHeight)
		return { Height = HudModals._stack(parts, gap) }
	end

	local SPECS = {
		Controls = { Title = "CONTROLS", Build = buildControls },
		Settings = { Title = "SETTINGS", Build = buildSettings, CompactWidth = space.ListWidth },
		Cash = { Title = "GET CASH", Build = buildCash },
	}

	local function ensure(name)
		local entry = modals[name]
		if entry then return entry end
		local spec = SPECS[name]
		entry = {}
		modals[name] = entry
		entry.Modal = k.Overlay.Modal(layer, {
			Name = name,
			Title = spec.Title,
			Width = compact and spec.CompactWidth or width,
			Scrim = "Confirm",
			Build = function(content, own)
				entry.Parts = spec.Build(content, own)
				-- A modal with no Height gets a panel as tall as the screen (Surface.Panel fills its parent on an
				-- axis with no size), so the panel is given the height of what was just built.
				entry.Modal.Set({ Height = HudModals._panelHeight(entry.Parts.Height, titleHeight, pad, ctx.Scale) })
			end,
			-- Escape, ButtonB or the kit's own close. The model decides (D441-445: the first-drive reveal refuses);
			-- when it refuses, the modal is shown again.
			OnClose = function()
				if syncing or model.GetState().ActiveModal ~= name then return end
				kitClosing = name
				model.CloseModal()
				kitClosing = nil
				local state = model.GetState()
				if state.ActiveModal == name and not state.ControlsFading then
					syncing = true
					entry.Modal.Open()
					syncing = false
				end
			end,
		}, scope)
		return entry
	end

	function self.Render()
		local state = model.GetState()
		local name, layerVisible, backdrop = HudModals._plan(state)
		if layer.Visible ~= layerVisible then layer.Visible = layerVisible end
		if name ~= shownName then
			syncing = true
			if shownName and shownName ~= kitClosing and modals[shownName] then modals[shownName].Modal.Close() end
			shownName = name
			if name then ensure(name).Modal.Open() end
			syncing = false
		end
		if backdrop ~= backdropMode then
			backdropMode = backdrop
			if tween then
				tween:Cancel()
				tween = nil
			end
			if backdrop == "Opaque" then
				layer.BackgroundTransparency = 0 -- D471
			elseif backdrop == "Fading" then
				-- D455: the black backdrop clears while the model counts the same time.
				tween = TweenService:Create(layer, TweenInfo.new(model.ControlsFadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ BackgroundTransparency = 1 })
				tween:Play()
			else
				layer.BackgroundTransparency = 1
			end
		end
		local entry = shownName and modals[shownName]
		if entry and entry.Parts and entry.Parts.Sync then entry.Parts.Sync(state) end
	end

	function self.Destroy()
		if tween then
			tween:Cancel()
			tween = nil
		end
		for _, entry in pairs(modals) do entry.Modal.Destroy() end
		table.clear(modals)
		layer:Destroy()
	end

	return self
end

return HudModals
