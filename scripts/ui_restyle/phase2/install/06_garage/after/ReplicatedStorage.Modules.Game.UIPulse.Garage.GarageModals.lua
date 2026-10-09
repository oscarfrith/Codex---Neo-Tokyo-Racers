-- Owns the four garage modals as views (get more cash, garage properties, move equipped module, buy vehicle); it does not own their state, the purchase call or any price: the model holds all three.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageModals. Requires: Tokens, Metrics, Text, Collections, Data, Overlay, GarageRoutes.
--
-- Replaces the hand-built modal of the Classic controller (GarageUI L154-175). Nothing is built until a modal is
-- first shown. The two confirmations use Kit.Overlay.Confirm (NO left and focused, YES right, Escape and B cancel).
local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Metrics = require(Kit.Metrics)
local Text = require(Kit.Text)
local Collections = require(Kit.Collections)
local Data = require(Kit.Data)
local Overlay = require(Kit.Overlay)
local Routes = require(script.Parent.GarageRoutes)

local GarageModals = {}

local TEXT = Routes.Text
local Space = Tokens.Space

-- Pure. The list rows of the properties modal (GarageUI L174: "OWNED - name" or "BUY $x - name"). A row for sale
-- carries OnActivated = buy(key): the purchase is sent on an activation (click, tap, gamepad A) and never by the
-- list's selection, which a gamepad or keyboard focus move changes. Building the rows calls nothing.
function GarageModals._propertyRows(rows: { any }, money: (number) -> string, buy: ((string) -> ())?): { any }
	local list = {}
	for _, row in ipairs(rows or {}) do
		local key = row.Id
		local owned = row.Owned == true
		table.insert(list, {
			Key = key,
			Title = row.DisplayName,
			Right = owned and TEXT.Owned or (string.upper(TEXT.Buy) .. " " .. money(row.PriceAmount)),
			Locked = owned,
			OnActivated = (not owned and buy ~= nil) and function()
				buy(key)
			end or nil,
		})
	end
	return list
end

-- Pure. The panel's design size: the tokens on Regular; on Compact no larger than the screen less a margin on each
-- side (Surface.Panel takes design values and does no Compact conversion, so the tokens alone ran off a phone).
function GarageModals._panelSize(compact: boolean, size: Vector2, scale: number, margin: number): (number, number)
	if not compact then
		return Space.ConfirmWidth, Space.StatPanelHeight
	end
	local divisor = scale > 0 and scale or 1
	return math.max(1, math.floor(math.min(Space.ConfirmWidth, (size.X - 2 * margin) / divisor))),
		math.max(1, math.floor(math.min(Space.StatPanelHeight, (size.Y - 2 * margin) / divisor)))
end

-- Pure. Title, body and button texts of a confirmation.
function GarageModals._confirmText(state: any, money: (number) -> string): any
	if state.Kind == "Move" then
		return {
			Title = TEXT.MoveTitle,
			Body = TEXT.MoveBodyA .. tostring(state.VehicleName) .. TEXT.MoveBodyB,
			CancelText = TEXT.No,
			ConfirmText = TEXT.Yes,
		}
	end
	-- BuyVehicle (preview c15). The price is the catalogue value the model passed; no "cash after" is worked out.
	local price = money(state.PriceAmount)
	return {
		Title = TEXT.BuyVehicleTitleA .. string.upper(tostring(state.VehicleName)) .. TEXT.BuyVehicleTitleB,
		Body = TEXT.Price .. " " .. price,
		CancelText = TEXT.Cancel,
		ConfirmText = string.upper(TEXT.Buy) .. " " .. price,
	}
end

--[[ GarageModals.Mount(root, model, scope, opts)
	root   the garage layer's root (CanonicalCanvas); the panel modal is built inside it as CanonicalGarageModal
	model  ShowCash / ShowProperties state through model.Modal(); intents BuyProperty, CloseModal, ResolveModal
	opts   { Host: GuiObject? }  gallery and tests: confirmations build inside Host and create no ScreenGui
	Returns { Sync(), Destroy() }. Sync draws model.Modal(); the screen view calls it on every render.
]]
function GarageModals.Mount(root: GuiObject, model: any, scope: any, opts: any)
	local host = opts and opts.Host or nil
	local shown: any = nil -- the model's modal table that is drawn now
	local syncing = false
	local destroyed = false
	local panel: any = nil -- Overlay.Modal: cash and properties share it
	local body: any = nil
	local list: any = nil
	local confirm: any = nil
	local trapRows = 0 -- rows the list held when the panel's focus trap was last entered
	local ctx = Metrics.Of(root)

	local function panelSize(): (number, number)
		return GarageModals._panelSize(ctx.Class == "Compact", ctx.Size, ctx.Scale, ctx.Px(Space.CompactMargin))
	end

	-- A row for sale was activated. Never reached from a selection or a focus move.
	local function buy(key: string)
		if not syncing and not destroyed then
			model.BuyProperty(key)
		end
	end

	local function money(amount: any): string
		return Data.Money(tonumber(amount) or 0, false)
	end

	local function ensurePanel()
		if panel then
			return
		end
		local width, height = panelSize()
		panel = Overlay.Modal(root, {
			Name = "CanonicalGarageModal",
			Title = TEXT.CashTitle,
			Width = width,
			Height = height,
			Scrim = "Confirm",
			CloseButton = true,
			OnClose = function()
				-- Escape, B or the X. Not forwarded while Sync itself is closing the panel.
				if not syncing then
					shown = nil
					model.CloseModal()
				end
			end,
			Build = function(content, buildScope)
				body = Text.Label(content, { Name = "Body", Text = TEXT.CashBody, Role = "Body", Wrap = true, Upper = false }, buildScope)
				-- No OnSelected: the list selects on a focus move. The purchase is each row's OnActivated.
				list = Collections.List(content, { Name = "Properties" }, buildScope)
			end,
		}, scope)
		-- The page frames are destroyed and rebuilt on every dealership <-> customise change, so a page built after
		-- this modal is a later sibling: without a ZIndex of its own the modal drew under it (Classic used 100).
		panel.Instance.ZIndex = 100
	end

	local function closeDrawn(keepPanel: boolean)
		syncing = true
		if not keepPanel and panel and panel.IsOpen() then
			panel.Close()
		end
		local open = confirm
		confirm = nil
		if open then
			open.Cancel()
		end
		syncing = false
	end

	local function sync()
		if destroyed then
			return
		end
		local state = model.Modal()
		if state == shown then
			return
		end
		-- The panel stays open across a redraw of its own content (the properties list after a purchase).
		local panelKind = state ~= nil and (state.Kind == "Cash" or state.Kind == "Properties")
		closeDrawn(panelKind)
		shown = state
		if state == nil then
			return
		end
		if panelKind then
			ensurePanel()
			local width, height = panelSize()
			panel.Set({ Title = state.Kind == "Cash" and TEXT.CashTitle or TEXT.PropertiesTitle, Width = width, Height = height })
			if not list then
				-- First use: Open builds the content.
				panel.Open()
				trapRows = 0
			end
			local rows = state.Kind == "Properties" and GarageModals._propertyRows(state.Rows, money, buy) or {}
			if body and list then
				body.Set({ Visible = state.Kind == "Cash" })
				list.Set({ Visible = state.Kind == "Properties" })
				-- An empty list first: the kit list keeps its own selection, and a redrawn list starts with none.
				list.SetItems({})
				list.SetItems(rows)
			end
			if panel.IsOpen() and #rows > trapRows then
				-- The focus trap lists the buttons present at Open: leave it, so it is entered again with the rows
				-- (else a gamepad is pulled back from every row to the X).
				syncing = true
				panel.Close()
				syncing = false
			end
			if not panel.IsOpen() then
				panel.Open()
				trapRows = #rows
			end
			return
		end
		local text = GarageModals._confirmText(state, money)
		local mine
		mine = Overlay.Confirm(root, {
			Title = text.Title,
			Body = text.Body,
			CancelText = text.CancelText,
			ConfirmText = text.ConfirmText,
			Host = host,
			OnConfirm = function()
				if confirm == mine then
					confirm = nil
				end
				if not syncing and shown == state then
					shown = nil
					model.ResolveModal(true)
				end
			end,
			OnCancel = function()
				if confirm == mine then
					confirm = nil
				end
				if not syncing and shown == state then
					shown = nil
					model.ResolveModal(false)
				end
			end,
		})
		confirm = mine
	end

	local self = {}
	self.Sync = sync

	function self.Destroy()
		if destroyed then
			return
		end
		closeDrawn(false)
		destroyed = true
		if panel then
			panel.Destroy()
			panel = nil
		end
	end

	return self
end

return GarageModals
