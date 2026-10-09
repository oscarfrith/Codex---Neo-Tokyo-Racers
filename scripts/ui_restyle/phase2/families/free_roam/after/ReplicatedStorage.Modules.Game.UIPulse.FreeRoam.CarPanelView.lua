-- Owns the My Vehicles side panel view (list on Regular, two-column grid on Compact); no remote, attribute or bindable: every action is a HudModel call.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.FreeRoam.CarPanelView. Requires: Kit.Tokens, Kit.Metrics, Kit.Text, Kit.Controls, Kit.Collections, Kit.Overlay (resolved on the first mount).
--
-- The panel is a Kit.Overlay.Modal with Side set, named CarPanel (the reserved name Classic onboarding reads at
-- OnboardingClient 475). Nothing inside it exists until the first open. Regular has the two drop-downs of
-- DesktopFreeRoamHudUI 797-805; Compact has none (API2 5.3, target c03) and keeps the model's ALL / RATING.

local SORT_OPTIONS = { { Id = "RATING", Text = "RATING" }, { Id = "PRICE", Text = "PRICE" }, { Id = "A-Z", Text = "A-Z" } }
local TIERS = { E = true, D = true, C = true, B = true, A = true, S = true }

local CarPanelView = {}

local kitCache
local function kit()
	if not kitCache then
		local folder = script.Parent.Parent.Kit
		kitCache = {
			Tokens = require(folder.Tokens),
			Metrics = require(folder.Metrics),
			Text = require(folder.Text),
			Controls = require(folder.Controls),
			Collections = require(folder.Collections),
			Overlay = require(folder.Overlay),
		}
	end
	return kitCache
end
function CarPanelView._setKit(replacement) kitCache = replacement end

local function frame(name, parent)
	local item = Instance.new("Frame")
	item.Name = name
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.Parent = parent
	return item
end

-- Pure: gives every item its own press callback. The kit's OnSelected fires only when the selection CHANGES, and the
-- CURRENT row arrives already selected, so a press on it (or a second press on any row) never reached the model.
-- A card press always asks (D746); OnActivated is the row's own press and does not fire on a focus move.
function CarPanelView._withActivation(items, onActivated)
	if onActivated then
		for _, item in ipairs(items) do
			local key = item.Key
			item.OnActivated = function() onActivated(key) end
		end
	end
	return items
end

-- Pure: model rows -> list rows (Regular). The first row is always BUY MORE (D775-777).
function CarPanelView._listItems(rows, buyMoreKey, onActivated)
	local items = { { Key = buyMoreKey, Title = "BUY MORE", Sub = "DEALERSHIP" } }
	for _, row in ipairs(rows) do
		table.insert(items, {
			Key = row.VehicleId,
			Title = row.Name,
			Sub = string.format("%d  %s", math.floor(row.Rating), row.Category),
			Image = row.Image ~= "" and row.Image or nil,
			Tier = TIERS[row.Tier] and row.Tier or nil,
			Chip = row.Selected and "CURRENT" or nil,
			ChipKind = row.Selected and "Cyan" or nil,
			State = row.Selected and "Selected" or "Default",
		})
	end
	return CarPanelView._withActivation(items, onActivated)
end

-- Pure: model rows -> tiles (Compact).
function CarPanelView._tileItems(rows, buyMoreKey, onActivated)
	local items = { { Key = buyMoreKey, Title = "BUY MORE", Icon = "plus" } }
	for _, row in ipairs(rows) do
		table.insert(items, {
			Key = row.VehicleId,
			Title = row.Name,
			Image = row.Image ~= "" and row.Image or nil,
			Tier = TIERS[row.Tier] and row.Tier or nil,
			Rating = math.floor(row.Rating),
			Status = "Owned",
			State = row.Selected and "Selected" or "Default",
		})
	end
	return CarPanelView._withActivation(items, onActivated)
end

-- Pure: the line above the footer. An empty garage says so instead of asking for a selection.
function CarPanelView._hint(loading, rowCount, category)
	if loading then return "LOADING VEHICLES..." end
	if rowCount == 0 and category == "ALL" then return "NO VEHICLES OWNED YET" end
	return "SELECT A VEHICLE TO SPAWN IT"
end

-- Pure: DESPAWN is live only with a vehicle out (D1276: Classic greys it unless the player sits in their vehicle).
function CarPanelView._canDespawn(state)
	return state.Driving == true or state.Vehicle ~= nil
end

-- Pure: category names -> drop-down options.
function CarPanelView._options(names)
	local options = {}
	for _, name in ipairs(names) do table.insert(options, { Id = name, Text = name }) end
	return options
end

-- parent is the static layer's SidePanel slot.
function CarPanelView.Mount(parent, model, scope)
	local k = kit()
	local ctx = k.Metrics.Of(parent)
	local compact = ctx.Class == "Compact"
	local space = k.Tokens.Space
	local px = ctx.Px
	local buyMoreKey = model.BuyMoreKey

	local self = {}
	local parts -- set by the first open
	local syncing = false
	local kitClosing = false -- the panel's own close is running: Render must not call Close again
	local shownOpen = false
	local shownRows, shownOptions, shownCategory, shownSort, shownHint, shownDespawn

	-- Every press of a row, selected or not (see _withActivation).
	local function onActivated(key)
		if syncing then return end
		if key == buyMoreKey then
			model.BuyMore()
		else
			model.SpawnVehicle(key)
		end
	end

	local function build(content, own)
		local built = {}
		local gap = px(space.Gap)
		local margin = compact and space.CompactMargin or space.HudMargin
		local buttonHeight = compact and ctx.Touch(space.CompactButtonDrawn) or px(space.ButtonHeight)
		local top = 0
		local bottom = buttonHeight + gap

		if not compact then
			local filters = frame("Filters", content)
			filters.Size = UDim2.new(1, 0, 0, px(space.DropdownRowHeight))
			local row = Instance.new("UIListLayout")
			row.Name = "Layout"
			row.FillDirection = Enum.FillDirection.Horizontal
			row.SortOrder = Enum.SortOrder.LayoutOrder
			row.Padding = UDim.new(0, gap)
			row.Parent = filters
			built.Category = k.Controls.Dropdown(filters, {
				Name = "Category", Label = "CATEGORY", LayoutOrder = 1,
				Options = CarPanelView._options(model.GetState().CategoryOptions), Selected = model.GetState().Category,
				OnSelected = function(id)
					if not syncing then model.SelectCategory(id) end
				end,
			}, own)
			built.Sort = k.Controls.Dropdown(filters, {
				Name = "Sort", Label = "SORT", LayoutOrder = 2, Options = SORT_OPTIONS, Selected = model.GetState().Sort,
				OnSelected = function(id)
					if not syncing then model.SelectSort(id) end
				end,
			}, own)
			top = px(space.DropdownRowHeight) + gap
			local hintHeight = px(space.Pad)
			local hint = frame("Hint", content)
			hint.AnchorPoint = Vector2.new(0, 1)
			hint.Position = UDim2.new(0, 0, 1, -(buttonHeight + gap))
			hint.Size = UDim2.new(1, 0, 0, hintHeight)
			built.Hint = k.Text.Label(hint, { Name = "HintText", Text = "SELECT A VEHICLE TO SPAWN IT", Role = "Label", Colour = "TextSecondary", Align = "Left" }, own)
			shownHint = "SELECT A VEHICLE TO SPAWN IT"
			bottom += hintHeight + gap
		end

		local holder = frame("Vehicles", content)
		holder.Position = UDim2.fromOffset(0, top)
		holder.Size = UDim2.new(1, 0, 1, -(top + bottom))
		if compact then
			built.List = k.Collections.Rail(holder, { Name = "VehicleGrid", Rows = 2 }, own)
		else
			built.List = k.Collections.List(holder, { Name = "VehicleList", RowHeight = space.ListRowHeight }, own)
		end

		local footer = frame("Footer", content)
		footer.AnchorPoint = Vector2.new(0, 1)
		footer.Position = UDim2.fromScale(0, 1)
		footer.Size = UDim2.new(1, 0, 0, buttonHeight)
		local width = (compact and space.CompactSidePanelWidth or space.SidePanelWidth) - margin - margin
		built.Despawn = k.Controls.Button(footer, {
			Name = "Despawn", Variant = "Danger", Text = "DESPAWN", Icon = "close", MinWidth = width,
			Disabled = not CarPanelView._canDespawn(model.GetState()),
			OnActivated = function() model.Despawn() end,
		}, own)
		shownDespawn = CarPanelView._canDespawn(model.GetState())
		parts = built
	end

	local modal = k.Overlay.Modal(parent, {
		Name = "CarPanel",
		Title = "MY VEHICLES",
		Width = compact and space.CompactSidePanelWidth or space.SidePanelWidth,
		Side = compact and "Right" or "Left",
		Scrim = "None",
		CloseButton = compact,
		Build = build,
		OnClose = function()
			if syncing then return end
			if not model.GetState().CarPanelOpen then return end
			kitClosing = true
			model.SetCarPanelOpen(false)
			kitClosing = false
		end,
	}, scope)
	self.Modal = modal

	function self.Render()
		local state = model.GetState()
		if state.CarPanelOpen ~= shownOpen then
			shownOpen = state.CarPanelOpen
			syncing = true
			if shownOpen then
				modal.Open()
			elseif not kitClosing then
				modal.Close()
			end
			syncing = false
		end
		if not (shownOpen and parts) then return end
		local canDespawn = CarPanelView._canDespawn(state)
		if canDespawn ~= shownDespawn then
			shownDespawn = canDespawn
			parts.Despawn.Set({ Disabled = not canDespawn })
		end
		if parts.Hint then
			local hint = CarPanelView._hint(state.RowsLoading == true, #state.Rows, state.Category)
			if hint ~= shownHint then
				shownHint = hint
				parts.Hint.Set({ Text = hint })
			end
		end
		if state.Rows ~= shownRows then
			shownRows = state.Rows
			syncing = true
			parts.List.SetItems(compact and CarPanelView._tileItems(shownRows, buyMoreKey, onActivated) or CarPanelView._listItems(shownRows, buyMoreKey, onActivated))
			syncing = false
		end
		if parts.Category and (state.CategoryOptions ~= shownOptions or state.Category ~= shownCategory) then
			shownOptions, shownCategory = state.CategoryOptions, state.Category
			syncing = true
			parts.Category.Set({ Options = CarPanelView._options(shownOptions), Selected = shownCategory })
			syncing = false
		end
		if parts.Sort and state.Sort ~= shownSort then
			shownSort = state.Sort
			syncing = true
			parts.Sort.Set({ Selected = shownSort })
			syncing = false
		end
	end

	function self.Destroy()
		modal.Destroy()
	end

	return self
end

return CarPanelView
