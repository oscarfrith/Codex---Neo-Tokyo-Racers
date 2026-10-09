-- Owns the Pulse owned-garage browser screen (the OwnedGarageBrowser layer, its view and its wiring to Garage.OwnedGarageBrowserModel); not the browser's state or remote calls (the model), nor the desk, the interior HUD or the entrance prompts.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.OwnedGarageBrowserUI. Requires: Kit.Layers, Kit.Tokens, Kit.Text, Kit.Surface, Kit.Controls, Kit.Collections, Kit.Data, Kit.Overlay, Kit.Input, Kit.Presence, Garage.OwnedGarageBrowserModel, Garage.GarageCompat, Core.ConnectionScope.
-- Public API kept from Classic UI.OwnedGarageBrowserUI: Start() -> (ok, message), Close(reason), IsOpen(). Started by Garage.OwnedGarageClient.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LAYER_NAME = "OwnedGarageBrowser"
local PRESENCE_SURFACE = "OwnedGarageBrowser"
local TAB_MINE = "Mine"
local TAB_VISIT = "Visit"

local Controller = {}
local started = false
local closeCurrent = function() end
local isOpenCurrent = function()
	return false
end

function Controller.Close(reason)
	closeCurrent(reason)
end

function Controller.IsOpen()
	return isOpenCurrent()
end

-- Pure. The footer row: EXIT, then the main action while the model shows it. A hidden button is left out of the
-- list (a ButtonRow keeps the width of a button that is only hidden, which left EXIT standing beside a gap).
function Controller._footerButtons(enter, onExit, onEnter)
	local list = { { Id = "Exit", Variant = "Default", Text = "EXIT", Icon = "exit", OnActivated = onExit } }
	if type(enter) == "table" and enter.Visible then
		table.insert(list, {
			Id = "Enter",
			Variant = "Main",
			Text = tostring(enter.Text or "ENTER GARAGE"),
			Icon = "garage",
			Disabled = not enter.Enabled,
			MarkKey = "Enter",
			OnActivated = onEnter,
		})
	end
	return list
end

-- Pure. Compact detail column: the heights of the picture panel and of the description panel, so that the two
-- and the facts panel (with a gap between each) end inside `available` px, above the button row. The picture and
-- the description shrink together down to `minimum`; under that the description is left out (height 0) and the
-- picture takes what is left. All values are real px. Returns pictureHeight, descriptionHeight.
function Controller._compactDetail(available, tile, facts, gap, minimum)
	local spare = available - facts - gap - gap
	if tile + tile <= spare then
		return tile, tile
	end
	local each = math.floor(spare / 2)
	if each >= minimum then
		return each, each
	end
	return math.clamp(available - facts - gap, minimum, math.max(minimum, tile)), 0
end

-- Pure. The rows of the "garage full" choice. The replacement is each row's OnActivated (click, tap, gamepad A),
-- as the Classic slot buttons were (Classic 98-103); the list has no OnSelected, because a list selects on a focus
-- move and a selection that is already set is not reported again. Building the rows calls nothing.
function Controller._replacementRows(slots, choose)
	local rows = {}
	for index, slot in ipairs(slots or {}) do
		rows[index] = {
			Key = "Slot_" .. tostring(index),
			Title = tostring(slot.DisplayName or slot.VehicleId or ""),
			Right = tostring(index),
			OnActivated = function()
				choose(index)
			end,
		}
	end
	return rows
end

-- Builds the view on `layer` over `model`. Kit components only, except the garage picture (the kit has no image
-- component; see NOTES_b). Returns {Render, Destroy}. Exposed for the gallery fixture and tests. `cashPlayer` is the
-- player whose leaderstats.Cash the status strip shows; nil (fixtures) leaves the chip unbound.
function Controller._mount(layer, model, scope, kit, cashPlayer)
	local Tokens = require(kit.Tokens)
	local Text = require(kit.Text)
	local Surface = require(kit.Surface)
	local Controls = require(kit.Controls)
	local Collections = require(kit.Collections)
	local Data = require(kit.Data)
	local Overlay = require(kit.Overlay)
	local Input = require(kit.Input)
	local Compat = require(script.Parent.GarageCompat)

	local ctx = layer.Metrics
	local space = Tokens.Space
	-- The size class is read when it is used, never kept: this view is built at start, before the screen has
	-- settled, and a class kept from then gave the Compact sizes on a desktop (capture owned_garage_browser_v1).
	local function isCompact()
		return ctx.Class == "Compact"
	end
	local function listWidth()
		return isCompact() and space.CompactSidePanelWidth or space.SidePanelWidth
	end
	local function modalWidth()
		return isCompact() and space.CompactPromptWidth or space.ConfirmWidth
	end
	local MIN_FACT_ROWS = 3 -- district, capacity, filled
	local factCount = MIN_FACT_ROWS

	local function put(instance, property, value)
		if instance[property] ~= value then
			instance[property] = value
		end
	end

	local rendering = false
	local view = {}

	if layer.ScrimRoot then
		Surface.Scrim(layer.ScrimRoot, { Kind = "Menu" }, scope)
	end

	-- Title and the MY GARAGES / VISIT tabs (Classic 20, 47, 69-72).
	local topLeft = layer.Slot("TopLeft")
	local header
	header = Controls.Header(topLeft, {
		Title = "GARAGES",
		Tabs = {
			Tabs = {
				{ Id = TAB_MINE, Text = "MY GARAGES", Icon = "garage" },
				{ Id = TAB_VISIT, Text = "VISIT", Icon = "players" },
			},
			Selected = TAB_MINE,
			OnSelected = function(id)
				if rendering then
					return
				end
				model:SetMode(id)
				-- The kit tab has switched already; the model ignores the press while it is busy and then draws
				-- nothing, so the tab is put back on the model's mode here. Select reports nothing.
				local mode = model:Snapshot().Mode == "Visit" and TAB_VISIT or TAB_MINE
				if mode ~= id then
					header.Tabs.Select(mode)
				end
			end,
		},
	}, scope)

	-- The status strip of every menu: display spaces of the selected garage, and Cash from leaderstats (API2 3.5).
	local topRight = layer.Slot("TopRight")
	local cluster = Data.StatusCluster(topRight, { Mode = "Garage", Spaces = "", ShowPlus = false }, scope)
	-- TopRight is a zero-size slot: the strip stands on the slot's anchor, so it ends at the margin.
	cluster.Instance.AnchorPoint = topRight.AnchorPoint
	if cashPlayer and cluster.Cash then
		cluster.Cash.Bind(cashPlayer)
	end

	-- The garage list (Classic 22-23, reserved name GarageList; rows keep the Classic names Garage_<id>, Visit_<id>).
	local listHolder = Instance.new("Frame")
	listHolder.Name = "ListHolder"
	listHolder.BackgroundTransparency = 1
	listHolder.BorderSizePixel = 0
	listHolder.Parent = topLeft
	local list = Collections.List(listHolder, {
		Width = listWidth(),
		OnSelected = function(key)
			if rendering then
				return
			end
			model:SelectKey(key)
		end,
	}, scope)
	Input.Mark(list.Instance, "GarageList")

	-- The detail (preview r05): picture and name across the top, description and facts side by side under it; on
	-- Compact the three are stacked. The holder and its three panels are sized and placed in code by layout():
	-- the holder ends at the right margin (the right edge of slot RightColumn) and starts level with the list.
	local rightColumn = layer.Slot("RightColumn")
	local detailHolder = Instance.new("Frame")
	detailHolder.Name = "DetailHolder"
	detailHolder.BackgroundTransparency = 1
	detailHolder.BorderSizePixel = 0
	detailHolder.AnchorPoint = Vector2.new(1, 0)
	detailHolder.Position = UDim2.fromScale(1, 0)
	detailHolder.Parent = rightColumn

	local hero = Surface.Panel(detailHolder, { Name = "GarageImage", Width = space.ListWidth, Height = space.TileHeight }, scope)
	local heroImage = Instance.new("ImageLabel")
	heroImage.Name = "Image"
	heroImage.BackgroundTransparency = 1
	heroImage.BorderSizePixel = 0
	heroImage.Size = UDim2.fromScale(1, 1)
	heroImage.ScaleType = Enum.ScaleType.Crop
	heroImage.Visible = false
	heroImage.Parent = hero.Content
	local heroLabels = Instance.new("Frame")
	heroLabels.Name = "Labels"
	heroLabels.BackgroundTransparency = 1
	heroLabels.BorderSizePixel = 0
	heroLabels.Size = UDim2.fromScale(1, 1)
	heroLabels.Parent = hero.Content
	local heroLayout = Instance.new("UIListLayout")
	heroLayout.Name = "Layout"
	heroLayout.FillDirection = Enum.FillDirection.Vertical
	heroLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	heroLayout.SortOrder = Enum.SortOrder.LayoutOrder
	heroLayout.Parent = heroLabels
	local district = Text.Label(heroLabels, { Name = "District", Text = "", Role = "Label", Colour = "TextSecondary", Align = "Left", LayoutOrder = 1 }, scope)
	local title = Text.Label(heroLabels, { Name = "GarageTitle", Text = "", Role = "SectionHead", Align = "Left", Shadow = true, LayoutOrder = 2 }, scope)

	local about = Surface.Panel(detailHolder, { Name = "About", Width = space.ListWidth, Height = space.TileHeight }, scope)
	-- Wrap with no MaxWidth: the text fills the panel content width, whatever layout() makes it.
	local description = Text.Label(about.Content, {
		Name = "Description",
		Text = "",
		Role = "Body",
		Colour = "TextSecondary",
		Align = "Left",
		Wrap = true,
		Upper = false,
	}, scope)

	local factsPanel = Surface.Panel(detailHolder, { Name = "Facts", Width = space.ListWidth, Height = space.TileHeight }, scope)
	local facts = Data.FactList(factsPanel.Content, { Rows = {} }, scope)

	-- Footer: EXIT, then the main action (Classic 44-45; reserved names Exit and Enter).
	-- Only the buttons that show are in the row; the Enter mark is the row entry's MarkKey.
	local function onExit()
		model:Close()
	end
	local function onEnter()
		model:Enter()
	end
	local buttons = Controls.ButtonRow(layer.Slot("BottomRight"), {
		Align = "Right",
		Buttons = Controller._footerButtons({ Visible = true, Enabled = true, Text = "ENTER GARAGE" }, onExit, onEnter),
	}, scope)

	-- The status line (Classic 41, 60): Danger for a failure, Cyan for progress.
	local status = Text.Label(layer.Slot("BottomLeft"), { Name = "Status", Text = "", Role = "Label", Colour = "Danger", Align = "Left", Visible = false }, scope)
	status.Instance.AnchorPoint = Vector2.new(0, 1)

	-- The "garage full" choice (Classic 94-106), built on first open.
	local MAX_REPLACEMENT_ROWS = 5 -- rows shown before the list scrolls (the default of the kit list)
	local replacementList
	local replacementBody
	local replacementHolder
	local replacementCount = 0
	local replacementKey = nil -- the slots the open modal's focus trap was entered with
	local fitModal
	local modal
	modal = Overlay.Modal(layer.Root, {
		Title = "GARAGE FULL",
		Width = modalWidth(),
		-- An explicit height, always: with none the kit panel fills its parent and the notice was screen-tall.
		-- fitModal() replaces this start value with the height of what the panel holds.
		Height = space.StatPanelHeight,
		Scrim = "Confirm",
		Build = function(content, modalScope)
			-- The body is a plain frame: without a layout the text and the list both stood at its top-left.
			local column = Instance.new("UIListLayout")
			column.Name = "Column"
			column.FillDirection = Enum.FillDirection.Vertical
			column.SortOrder = Enum.SortOrder.LayoutOrder
			column.Padding = UDim.new(0, ctx.Px(space.Gap))
			column.Parent = content
			-- Wrap with no MaxWidth: the text fills the panel content width.
			replacementBody = Text.Label(content, {
				Name = "Body",
				Text = "Choose the display vehicle to replace. The replaced vehicle stays owned.",
				Role = "Body",
				Colour = "TextSecondary",
				Align = "Left",
				Wrap = true,
				Upper = false,
				LayoutOrder = 1,
			}, modalScope)
			-- The list fills this holder, which fitModal() sizes to the rows it shows.
			replacementHolder = Instance.new("Frame")
			replacementHolder.Name = "Slots"
			replacementHolder.BackgroundTransparency = 1
			replacementHolder.BorderSizePixel = 0
			replacementHolder.LayoutOrder = 2
			replacementHolder.Size = UDim2.new(1, 0, 0, ctx.Px(space.ListRowHeight))
			replacementHolder.Parent = content
			-- No OnSelected: see _replacementRows.
			replacementList = Collections.List(replacementHolder, {}, modalScope)
			modalScope:connect(replacementBody.Instance:GetPropertyChangedSignal("AbsoluteSize"), function()
				fitModal()
			end)
		end,
		Buttons = {
			Align = "Right",
			Buttons = {
				{
					Id = "Cancel",
					Variant = "Default",
					Text = "CANCEL",
					Icon = "close",
					OnActivated = function()
						model:CancelReplacement()
					end,
				},
			},
		},
		OnClose = function()
			if rendering then
				return
			end
			model:CancelReplacement()
		end,
	}, scope)

	-- Sizes the "garage full" panel to what it holds (title row, text, up to MAX_REPLACEMENT_ROWS rows, footer),
	-- and never taller than the screen less a margin: then the list holder shrinks and the list scrolls.
	fitModal = function()
		local content = modal.Content
		if not (content and replacementList and replacementHolder and replacementBody) then
			return
		end
		local compact = isCompact()
		local pad = ctx.Px(space.Pad)
		local gap = ctx.Px(space.Gap)
		local rowHeight = math.max(ctx.Px(compact and space.TouchMin or space.ListRowHeight), ctx.Touch(1))
		local rows = math.clamp(replacementCount, 1, MAX_REPLACEMENT_ROWS)
		local listHeight = rows * rowHeight + (rows - 1) * gap
		local textHeight = replacementBody.Instance.AbsoluteSize.Y
		if textHeight <= 0 then
			textHeight = ctx.Px(space.TouchMin) -- not laid out yet: about two lines; the signal corrects it
		end
		local footer = (compact and ctx.Touch(space.CompactButtonDrawn) or ctx.Px(space.ButtonHeight)) + pad
		local chrome = 2 * pad + content.Position.Y.Offset + textHeight + gap + footer
		local room = math.max(0, ctx.Size.Y - 2 * ctx.Px(space.CompactMargin))
		local total = math.max(chrome + rowHeight, math.min(chrome + listHeight, room))
		put(replacementHolder, "Size", UDim2.new(1, 0, 0, total - chrome))
		modal.Set({ Width = modalWidth(), Height = math.floor(total / ctx.Scale) })
	end

	-- A panel sized and placed in real pixels (Surface.Panel takes design values and writes only its Size).
	local function box(panel, x, y, width, height)
		local scale = ctx.Scale
		panel.Set({ Width = math.max(1, width) / scale, Height = math.max(1, height) / scale })
		put(panel.Instance, "Position", UDim2.fromOffset(x, y))
	end

	local function layout()
		local compact = isCompact()
		local headerHeight = header.Height()
		local gap = ctx.Px(space.Gap)
		local pad = ctx.Px(space.Pad)
		local top = headerHeight + gap
		local rootHeight = layer.Root.AbsoluteSize.Y
		if rootHeight <= 0 then
			rootHeight = ctx.Size.Y
		end
		local reserve = compact and (ctx.Px(space.CompactBottom) + ctx.Px(space.CompactButtonDrawn)) or (ctx.Px(space.MenuBottom) + ctx.Px(space.ButtonHeight))
		local height = math.max(0, math.floor(rootHeight - topLeft.Position.Y.Offset - top - reserve - 2 * gap))

		-- The list column: about a third of the content width on Regular (r05).
		local listPx = ctx.Px(listWidth())
		list.Set({ Width = listWidth() })
		put(listHolder, "Position", UDim2.fromOffset(0, top))
		put(listHolder, "Size", UDim2.fromOffset(listPx, height))

		-- The detail takes what is left of the content width, right of the list; it starts level with the list
		-- and never above the right column's top, which keeps it clear of the status strip.
		local contentWidth = rightColumn.Position.X.Offset - topLeft.Position.X.Offset
		local columnGap = compact and ctx.Px(space.CompactKeepOutGap) or (pad + pad)
		local detailWidth = math.max(0, contentWidth - listPx - columnGap)
		if compact then
			detailWidth = math.min(detailWidth, ctx.Px(space.CompactPromptWidth))
		end
		local listTop = topLeft.Position.Y.Offset + top
		local detailTop = math.max(0, listTop - rightColumn.Position.Y.Offset)
		local available = math.max(0, height - (rightColumn.Position.Y.Offset + detailTop - listTop))
		local rows = math.max(MIN_FACT_ROWS, factCount)
		local detailHeight
		if compact then
			-- The stack is kept inside `available`, the height of the list beside it, which ends above the button
			-- row: at full size the facts panel lay on the buttons (844x390) and ran off the screen (568x320).
			local factsHeight = rows * ctx.Px(space.CompactStatusHeight) + 2 * ctx.Px(space.CompactKeepOutGap)
			local heroHeight, aboutHeight = Controller._compactDetail(available, ctx.Px(space.CompactTileHeight), factsHeight, gap, ctx.Px(space.CompactButtonDrawn))
			local factsTop = heroHeight + gap + (aboutHeight > 0 and aboutHeight + gap or 0)
			about.Set({ Visible = aboutHeight > 0 })
			box(hero, 0, 0, detailWidth, heroHeight)
			box(about, 0, heroHeight + gap, detailWidth, aboutHeight)
			box(factsPanel, 0, factsTop, detailWidth, factsHeight)
			detailHeight = factsTop + factsHeight
		else
			about.Set({ Visible = true })
			-- Facts take half the width, so a long value (a district name) has room beside its label.
			local lowerHeight = rows * ctx.Px(space.FactRowHeight) + pad + pad
			local factsWidth = math.floor((detailWidth - gap) / 2)
			local heroHeight = math.clamp(available - gap - lowerHeight, ctx.Px(space.ListRowHeight), ctx.Px(space.StatPanelHeight))
			box(hero, 0, 0, detailWidth, heroHeight)
			box(about, 0, heroHeight + gap, detailWidth - gap - factsWidth, lowerHeight)
			box(factsPanel, detailWidth - factsWidth, heroHeight + gap, factsWidth, lowerHeight)
			detailHeight = heroHeight + gap + lowerHeight
		end
		put(detailHolder, "Position", UDim2.new(1, 0, 0, detailTop))
		put(detailHolder, "Size", UDim2.fromOffset(detailWidth, detailHeight))

		modal.Set({ Width = modalWidth() })
		fitModal()
	end
	layout()

	local lastImage = nil
	function view.Render(_reason)
		rendering = true
		local ok, problem = xpcall(function()
			local snapshot = model:Snapshot()

			header.Tabs.Set({ Visible = snapshot.TabsVisible })
			if snapshot.TabsVisible then
				header.Tabs.Select(snapshot.Mode == "Visit" and TAB_VISIT or TAB_MINE)
			end

			local items = {}
			for index, row in ipairs(snapshot.Rows) do
				items[index] = {
					Key = row.Key,
					Title = row.Title,
					Sub = row.Sub,
					Image = Compat.Asset(row.Image),
					State = row.Selected and "Selected" or "Default",
				}
			end
			list.SetItems(items)
			for _, item in ipairs(items) do
				local component = list.Row(item.Key)
				if component then
					component.Instance.Name = item.Key
				end
			end
			if snapshot.SelectedKey then
				list.Select(snapshot.SelectedKey)
			end

			local detail = snapshot.Detail
			cluster.Set({ Spaces = detail.Spaces or "" })
			title.Set({ Text = detail.Title })
			district.Set({ Text = detail.District })
			description.Set({ Text = detail.Description })
			local image = Compat.Asset(detail.Image)
			if image ~= lastImage then
				lastImage = image
				heroImage.Image = image
				heroImage.Visible = image ~= ""
			end
			local rows = {}
			for index, fact in ipairs(detail.Facts) do
				rows[index] = { Id = fact.Id, Label = fact.Label, Value = fact.Value, Kind = "Text" }
			end
			facts.SetRows(rows)
			factCount = #rows
			layout()

			buttons.Set({ Buttons = Controller._footerButtons(snapshot.Enter, onExit, onEnter) })

			local line = snapshot.Status
			status.Set({ Visible = line.Visible, Text = line.Text, Colour = line.Good and "Cyan" or "Danger" })

			local replacement = snapshot.Replacement
			if replacement then
				if not replacementList then
					modal.Open() -- first use: Open builds the content
				end
				if replacementList then
					local rows = Controller._replacementRows(replacement.Slots, function(index)
						if not rendering then
							model:ChooseReplacement(index)
						end
					end)
					local parts = {}
					for index, row in ipairs(rows) do
						parts[index] = row.Title
					end
					local key = table.concat(parts, "\31")
					replacementCount = #rows
					replacementList.SetItems(rows)
					fitModal()
					-- The modal's focus trap lists the buttons present at Open, so it is entered after the rows
					-- exist, and again when the rows change. `rendering` is true: OnClose tells the model nothing.
					if modal.IsOpen() and key ~= replacementKey then
						modal.Close()
					end
					replacementKey = key
				end
				if not modal.IsOpen() then
					modal.Open()
				end
			else
				replacementKey = nil
				if modal.IsOpen() then
					modal.Close()
				end
			end
		end, debug.traceback)
		rendering = false
		if not ok then
			error(problem, 0)
		end
	end

	-- Deferred: the kit components and the slots answer the same signal, and layout() reads their new sizes.
	scope:connect(ctx.Changed, function(change)
		if type(change) == "table" and change.Layout then
			task.defer(layout)
		end
	end)
	scope:connect(header.Instance:GetPropertyChangedSignal("Size"), layout)
	scope:connect(rightColumn:GetPropertyChangedSignal("Position"), layout)

	function view.Destroy()
		scope:destroy()
	end
	return view
end

local function connectionScope()
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	return require(scopeModule)
end

function Controller.Start()
	if started then
		return true, "AlreadyStarted"
	end
	local pulse = script.Parent.Parent
	local kit = pulse.Kit
	local Layers = require(kit.Layers)
	local Presence = require(kit.Presence)
	local Model = require(script.Parent.OwnedGarageBrowserModel)
	local Scope = connectionScope()

	-- The waits Classic makes at lines 7-9, and no others.
	local player = Players.LocalPlayer
	player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes").Garage
	local remote = remotes:WaitForChild("OwnedGarageInvoke")
	local push = remotes:WaitForChild("OwnedGarageEvent")
	local runtimeUi = player:WaitForChild("PlayerScripts"):WaitForChild("Runtime"):WaitForChild("UI")
	local openEvent = runtimeUi:WaitForChild("OpenOwnedGarageBrowser")
	local loadingInvoke = runtimeUi:WaitForChild("LoadingTransitionInvoke")

	local layer = Layers.Create(LAYER_NAME, { Frame = "Menu", Scrim = true })
	layer.SetVisible(false)

	local scope = Scope.new()
	local view = nil
	local viewFailed = false
	local model = Model.new({
		Remotes = { OwnedGarageInvoke = remote, OwnedGarageEvent = push },
		Bindables = { LoadingTransitionInvoke = loadingInvoke },
		RuntimeUi = runtimeUi,
		Player = player,
		Workspace = Workspace,
		CanOpen = function()
			return view ~= nil
		end,
	})

	-- The view is built here, once. If a kit call fails the browser stays closed and says so, while the model keeps
	-- answering stream requests and exit prompts, which need no screen.
	local built, problem = xpcall(function()
		view = Controller._mount(layer, model, Scope.new(), kit, player)
	end, debug.traceback)
	if not built then
		view = nil
		viewFailed = true
		warn("[Pulse.OwnedGarageBrowserUI] view build failed; the browser will not open: " .. tostring(problem))
	end

	local releasePresence = nil
	local function apply(reason)
		local open = model:IsOpen()
		if open and not releasePresence then
			releasePresence = Presence.Open(PRESENCE_SURFACE, "FullMenu")
		elseif not open and releasePresence then
			releasePresence()
			releasePresence = nil
		end
		if view and (open or reason == "close") then
			local ok, renderProblem = pcall(view.Render, reason)
			if not ok and not viewFailed then
				viewFailed = true
				warn("[Pulse.OwnedGarageBrowserUI] render failed: " .. tostring(renderProblem))
			end
		end
		layer.SetVisible(open)
	end
	scope:connect(model.Changed, apply)

	closeCurrent = function(reason)
		model:Close(reason)
	end
	isOpenCurrent = function()
		return model:IsOpen()
	end

	scope:connect(openEvent.Event, function()
		model:Toggle()
	end)
	scope:connect(ProximityPromptService.PromptTriggered, function(prompt, triggeringPlayer)
		model:OnPromptTriggered(prompt, triggeringPlayer)
	end)
	scope:connect(player:GetAttributeChangedSignal("OwnedGarageInside"), function()
		model:OnInsideChanged()
	end)
	scope:connect(push.OnClientEvent, function(message)
		model:OnPush(message)
	end)

	Controller.Model = model
	Controller.Layer = layer
	started = true
	return true, "Started"
end

return Controller
