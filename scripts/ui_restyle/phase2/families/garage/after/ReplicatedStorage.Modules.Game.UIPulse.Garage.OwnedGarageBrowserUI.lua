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
	local compact = ctx.Class == "Compact"
	local listWidth = compact and space.CompactSidePanelWidth or space.ListWidth
	local detailWidth = compact and space.CompactPromptWidth or space.ModalMaxWidth
	local heroHeight = compact and space.CompactTileHeight or space.TileHeight
	local aboutHeight = compact and space.CompactTileHeight or (space.ListRowHeight + 2 * space.Pad)
	local factsHeight = compact and (3 * space.CompactStatusHeight + 2 * space.CompactKeepOutGap) or (3 * space.FactRowHeight + 2 * space.Pad)
	local modalWidth = compact and space.CompactPromptWidth or space.ConfirmWidth

	local rendering = false
	local view = {}

	if layer.ScrimRoot then
		Surface.Scrim(layer.ScrimRoot, { Kind = "Menu" }, scope)
	end

	-- Title and the MY GARAGES / VISIT tabs (Classic 20, 47, 69-72).
	local topLeft = layer.Slot("TopLeft")
	local header = Controls.Header(topLeft, {
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
			end,
		},
	}, scope)

	-- The status strip of every menu: display spaces of the selected garage, and Cash from leaderstats (API2 3.5).
	local cluster = Data.StatusCluster(layer.Slot("TopRight"), { Mode = "Garage", Spaces = "", ShowPlus = false }, scope)
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
		Width = listWidth,
		OnSelected = function(key)
			if rendering then
				return
			end
			model:SelectKey(key)
		end,
	}, scope)
	Input.Mark(list.Instance, "GarageList")

	-- The detail column: picture and name, description, facts.
	local detailHolder = Instance.new("Frame")
	detailHolder.Name = "DetailHolder"
	detailHolder.BackgroundTransparency = 1
	detailHolder.BorderSizePixel = 0
	detailHolder.AnchorPoint = Vector2.new(1, 0)
	detailHolder.AutomaticSize = Enum.AutomaticSize.Y
	detailHolder.Size = UDim2.fromOffset(ctx.Px(detailWidth), 0)
	detailHolder.Parent = layer.Slot("RightColumn")
	local detailLayout = Instance.new("UIListLayout")
	detailLayout.Name = "Layout"
	detailLayout.FillDirection = Enum.FillDirection.Vertical
	detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
	detailLayout.Padding = UDim.new(0, ctx.Px(space.Gap))
	detailLayout.Parent = detailHolder

	local hero = Surface.Panel(detailHolder, { Name = "GarageImage", Width = detailWidth, Height = heroHeight, LayoutOrder = 1 }, scope)
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

	local about = Surface.Panel(detailHolder, { Name = "About", Width = detailWidth, Height = aboutHeight, LayoutOrder = 2 }, scope)
	local description = Text.Label(about.Content, {
		Name = "Description",
		Text = "",
		Role = "Body",
		Colour = "TextSecondary",
		Align = "Left",
		Wrap = true,
		Upper = false,
		MaxWidth = detailWidth - 2 * space.Pad,
	}, scope)

	local factsPanel = Surface.Panel(detailHolder, { Name = "Facts", Width = detailWidth, Height = factsHeight, LayoutOrder = 3 }, scope)
	local facts = Data.FactList(factsPanel.Content, { Rows = {} }, scope)

	-- Footer: EXIT, then the main action (Classic 44-45; reserved names Exit and Enter).
	local buttons = Controls.ButtonRow(layer.Slot("BottomRight"), {
		Align = "Right",
		Buttons = {
			{
				Id = "Exit",
				Variant = "Default",
				Text = "EXIT",
				Icon = "exit",
				OnActivated = function()
					model:Close()
				end,
			},
			{
				Id = "Enter",
				Variant = "Main",
				Text = "ENTER GARAGE",
				Icon = "garage",
				OnActivated = function()
					model:Enter()
				end,
			},
		},
	}, scope)
	local enterButton = buttons.Button("Enter")
	Input.Mark(enterButton.Instance, "Enter")

	-- The status line (Classic 41, 60): Danger for a failure, Cyan for progress.
	local status = Text.Label(layer.Slot("BottomLeft"), { Name = "Status", Text = "", Role = "Label", Colour = "Danger", Align = "Left", Visible = false }, scope)
	status.Instance.AnchorPoint = Vector2.new(0, 1)

	-- The "garage full" choice (Classic 94-106), built on first open.
	local replacementList
	local replacementSlots = {}
	local modal
	modal = Overlay.Modal(layer.Root, {
		Title = "GARAGE FULL",
		Width = modalWidth,
		Scrim = "Confirm",
		Build = function(content, modalScope)
			Text.Label(content, {
				Name = "Body",
				Text = "Choose the display vehicle to replace. The replaced vehicle stays owned.",
				Role = "Body",
				Colour = "TextSecondary",
				Align = "Left",
				Wrap = true,
				Upper = false,
				MaxWidth = modalWidth - 2 * space.Pad,
				LayoutOrder = 1,
			}, modalScope)
			replacementList = Collections.List(content, {
				Width = modalWidth - 2 * space.Pad,
				LayoutOrder = 2,
				OnSelected = function(key)
					if rendering then
						return
					end
					local index = replacementSlots[key]
					if index then
						model:ChooseReplacement(index)
					end
				end,
			}, modalScope)
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

	local function layout()
		local headerHeight = header.Height()
		local gap = ctx.Px(space.Gap)
		local top = headerHeight + gap
		local rootHeight = layer.Root.AbsoluteSize.Y
		if rootHeight <= 0 then
			rootHeight = ctx.Size.Y
		end
		local reserve = compact and (ctx.Px(space.CompactBottom) + ctx.Px(space.CompactButtonDrawn)) or (ctx.Px(space.MenuBottom) + ctx.Px(space.ButtonHeight))
		local height = math.max(0, math.floor(rootHeight - topLeft.Position.Y.Offset - top - reserve - 2 * gap))
		listHolder.Position = UDim2.fromOffset(0, top)
		listHolder.Size = UDim2.fromOffset(ctx.Px(listWidth), height)
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

			local enter = snapshot.Enter
			enterButton.Set({ Visible = enter.Visible, Text = enter.Text, Disabled = not enter.Enabled })

			local line = snapshot.Status
			status.Set({ Visible = line.Visible, Text = line.Text, Colour = line.Good and "Cyan" or "Danger" })

			local replacement = snapshot.Replacement
			if replacement then
				if not modal.IsOpen() then
					modal.Open()
				end
				if replacementList then
					local slots = {}
					table.clear(replacementSlots)
					for index, slot in ipairs(replacement.Slots) do
						local key = "Slot_" .. tostring(index)
						replacementSlots[key] = index
						slots[index] = { Key = key, Title = tostring(slot.DisplayName or slot.VehicleId or ""), Right = tostring(index) }
					end
					replacementList.SetItems(slots)
				end
			elseif modal.IsOpen() then
				modal.Close()
			end
		end, debug.traceback)
		rendering = false
		if not ok then
			error(problem, 0)
		end
	end

	scope:connect(ctx.Changed, function(change)
		if type(change) == "table" and change.Layout then
			layout()
		end
	end)

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
