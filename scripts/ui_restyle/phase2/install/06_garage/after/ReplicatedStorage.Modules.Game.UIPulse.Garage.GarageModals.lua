-- Owns the four garage modals as views (get more cash, garage properties, move equipped module, buy vehicle); it does not own their state, the purchase call or any price: the model holds all three.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageModals. Requires: Tokens, Text, Collections, Data, Overlay, GarageRoutes.
--
-- Replaces the hand-built modal of the Classic controller (GarageUI L154-175). Nothing is built until a modal is
-- first shown. The two confirmations use Kit.Overlay.Confirm (NO left and focused, YES right, Escape and B cancel).
local Kit = script.Parent.Parent.Kit
local Tokens = require(Kit.Tokens)
local Text = require(Kit.Text)
local Collections = require(Kit.Collections)
local Data = require(Kit.Data)
local Overlay = require(Kit.Overlay)
local Routes = require(script.Parent.GarageRoutes)

local GarageModals = {}

local TEXT = Routes.Text
local Space = Tokens.Space

-- Pure. The list rows of the properties modal (GarageUI L174: "OWNED - name" or "BUY $x - name").
function GarageModals._propertyRows(rows: { any }, money: (number) -> string): { any }
	local list = {}
	for _, row in ipairs(rows or {}) do
		table.insert(list, {
			Key = row.Id,
			Title = row.DisplayName,
			Right = row.Owned and TEXT.Owned or (string.upper(TEXT.Buy) .. " " .. money(row.PriceAmount)),
			Locked = row.Owned == true,
		})
	end
	return list
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

	local function money(amount: any): string
		return Data.Money(tonumber(amount) or 0, false)
	end

	local function ensurePanel()
		if panel then
			return
		end
		panel = Overlay.Modal(root, {
			Name = "CanonicalGarageModal",
			Title = TEXT.CashTitle,
			Width = Space.ConfirmWidth,
			Height = Space.StatPanelHeight,
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
				list = Collections.List(content, {
					Name = "Properties",
					OnSelected = function(key)
						model.BuyProperty(key)
					end,
				}, buildScope)
			end,
		}, scope)
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
			panel.Set({ Title = state.Kind == "Cash" and TEXT.CashTitle or TEXT.PropertiesTitle })
			panel.Open()
			if body and list then
				body.Set({ Visible = state.Kind == "Cash" })
				list.Set({ Visible = state.Kind == "Properties" })
				-- An empty list first: the kit list keeps its own selection, and a redrawn list starts with none.
				list.SetItems({})
				if state.Kind == "Properties" then
					list.SetItems(GarageModals._propertyRows(state.Rows, money))
				end
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
