-- Owns the gallery items for Kit.Overlay (Toast, Confirm, Modal); no game state, remote, profile or player attribute.
-- Pulse UI (phase1). ReplicatedStorage.Modules.Game.UIPulse.Dev.Fixtures.Overlay. Requires: Tokens, Metrics, Text, Controls, Overlay (resolved on the first mount).

local TOAST_SECONDS = 10 -- the longest a toast may show
local TOAST_REFRESH_SECONDS = 8 -- showing cards are re-sent before they expire, so a capture always finds them

local kitCache
local function kit()
	if not kitCache then
		local folder = script.Parent.Parent.Parent.Kit
		kitCache = {
			Tokens = require(folder.Tokens),
			Metrics = require(folder.Metrics),
			Text = require(folder.Text),
			Controls = require(folder.Controls),
			Overlay = require(folder.Overlay),
		}
	end
	return kitCache
end

local function checkKeys(item, allowed, patch)
	assert(type(patch) == "table", item .. " fixture expects a table")
	for key in pairs(patch) do
		if not allowed[key] then error(string.format("%s fixture: unknown key '%s'", item, tostring(key)), 3) end
	end
end

local function copy(source)
	local result = {}
	for key, value in pairs(source or {}) do result[key] = value end
	return result
end

-- A confirmation or modal covers the whole stage, whatever anchor the gallery mounted the item on.
local function stageOf(parent)
	return parent:FindFirstAncestor("Stage") or parent
end

-- The block left on the stage behind an overlay: the last result and a button that opens the overlay again.
local function statusBlock(k, host, ctx, scope, name, buttonText, onOpen)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AutomaticSize = Enum.AutomaticSize.XY
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Position = UDim2.fromOffset(ctx.Px(k.Tokens.Space.MenuMargin), ctx.Px(k.Tokens.Space.MenuMargin))

	local list = Instance.new("UIListLayout")
	list.Name = "Layout"
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, ctx.Px(k.Tokens.Space.Gap))
	list.Parent = frame

	local status = k.Text.Label(frame, { Name = "Result", Text = "OPEN", Role = "Label", Colour = "TextSecondary",
		Align = "Left", LayoutOrder = 1 }, scope)
	k.Controls.Button(frame, { Name = "Reopen", Variant = "Default", Text = buttonText, LayoutOrder = 2,
		OnActivated = onOpen }, scope)
	frame.Parent = host
	return frame, status
end

------------------------------------------------------------------------------------------------------------------------
-- Toast
------------------------------------------------------------------------------------------------------------------------

local TOAST_FIXTURE_KEYS = { Messages = true, Keep = true, Duration = true, MaxCards = true }

local function mountToast(parent, props, scope, _ctx)
	local k = kit()
	checkKeys("Overlay.Toast", TOAST_FIXTURE_KEYS, props)
	local current = copy(props)
	local alive = true
	local toast = k.Overlay.Toast(parent, { MaxCards = current.MaxCards }, scope)

	local function showFrom(first)
		local messages = current.Messages or {}
		for index = math.max(1, first), #messages do
			toast.Show(messages[index], current.Duration or TOAST_SECONDS)
		end
	end

	-- Only the messages still on screen are re-sent, so the refresh restarts timers and never moves a card.
	local function refresh()
		local messages = current.Messages or {}
		local maxCards = math.max(1, math.floor(current.MaxCards or k.Tokens.Space.ToastMaxCards))
		showFrom(#messages - maxCards + 1)
	end

	showFrom(1)
	scope:task(function()
		while alive do
			task.wait(TOAST_REFRESH_SECONDS)
			if alive and current.Keep ~= false then refresh() end
		end
	end)

	local component = { Instance = toast.Instance }
	function component.Set(patch)
		checkKeys("Overlay.Toast", TOAST_FIXTURE_KEYS, patch)
		for key, value in pairs(patch) do current[key] = value end
		if patch.MaxCards ~= nil then toast.Set({ MaxCards = patch.MaxCards }) end
		if patch.Messages ~= nil then showFrom(1) end
	end
	function component.Destroy()
		alive = false
		toast.Destroy()
	end
	return component
end

------------------------------------------------------------------------------------------------------------------------
-- Confirm
------------------------------------------------------------------------------------------------------------------------

local CONFIRM_FIXTURE_KEYS = { Title = true, Body = true, CancelText = true, ConfirmText = true }

local function mountConfirm(parent, props, scope, ctx)
	local k = kit()
	checkKeys("Overlay.Confirm", CONFIRM_FIXTURE_KEYS, props)
	local host = stageOf(parent)
	ctx = ctx or k.Metrics.Of(host)
	local current = copy(props)
	local alive = true
	local closes = 0
	local handle
	local frame, status

	-- The count proves the close runs once per opening; the attributes let a probe read it without a require.
	local function finish(result)
		handle = nil
		if not alive then return end
		closes += 1
		frame:SetAttribute("ConfirmResult", result)
		frame:SetAttribute("ConfirmCloses", closes)
		status.Set({ Text = string.format("%s (CLOSES: %d)", result, closes) })
	end

	local function open()
		if handle or not alive then return end
		frame:SetAttribute("ConfirmResult", "Open")
		handle = k.Overlay.Confirm(host, {
			Host = host,
			Title = current.Title,
			Body = current.Body,
			CancelText = current.CancelText,
			ConfirmText = current.ConfirmText,
			OnConfirm = function() finish("Confirmed") end,
			OnCancel = function() finish("Cancelled") end,
		})
	end

	frame, status = statusBlock(k, host, ctx, scope, "ConfirmFixture", "OPEN CONFIRM", open)
	frame:SetAttribute("ConfirmCloses", 0)
	open()

	local destroyed = false
	local component = { Instance = frame }
	function component.Set(patch)
		checkKeys("Overlay.Confirm", CONFIRM_FIXTURE_KEYS, patch)
		for key, value in pairs(patch) do current[key] = value end
	end
	function component.Destroy()
		if destroyed then return end
		destroyed = true
		alive = false
		local openHandle = handle
		handle = nil
		if openHandle then openHandle.Cancel() end
		frame:Destroy()
	end
	scope:add(component.Destroy)
	return component
end

------------------------------------------------------------------------------------------------------------------------
-- Modal
------------------------------------------------------------------------------------------------------------------------

local MODAL_FIXTURE_KEYS = { Title = true, Body = true, FixedHeight = true }

local function mountModal(parent, props, scope, ctx)
	local k = kit()
	checkKeys("Overlay.Modal", MODAL_FIXTURE_KEYS, props)
	local host = stageOf(parent)
	ctx = ctx or k.Metrics.Of(host)
	local space = k.Tokens.Space
	local compact = ctx.Class == "Compact"
	local current = copy(props)
	local alive = true
	local closes = 0
	local frame, status
	local modal

	-- Design sizes come from the tokens: a narrower, shorter panel on the phone presets.
	local width = if compact then space.ListWidth else space.ConfirmWidth
	local height = nil
	if current.FixedHeight then height = if compact then space.TileHeight else space.TileHeight * 2 end

	frame, status = statusBlock(k, host, ctx, scope, "ModalFixture", "OPEN MODAL", function()
		if alive and modal then
			frame:SetAttribute("ModalOpen", true)
			modal.Open()
		end
	end)
	frame:SetAttribute("ModalCloses", 0)

	modal = k.Overlay.Modal(host, {
		Title = current.Title or "MODAL",
		Width = width,
		Height = height,
		Build = function(content, buildScope)
			local list = Instance.new("UIListLayout")
			list.Name = "Layout"
			list.FillDirection = Enum.FillDirection.Vertical
			list.HorizontalAlignment = Enum.HorizontalAlignment.Left
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.Padding = UDim.new(0, ctx.Px(space.Pad))
			list.Parent = content
			k.Text.Label(content, { Name = "Copy", Text = current.Body or "", Role = "Body", Colour = "TextSecondary",
				Align = "Left", Wrap = true, MaxWidth = width - space.Pad * 2, LayoutOrder = 1 }, buildScope)
			k.Controls.Button(content, { Name = "Close", Variant = "Default", Text = "CLOSE", LayoutOrder = 2,
				OnActivated = function() modal.Close() end }, buildScope)
		end,
		OnClose = function()
			if not alive then return end
			closes += 1
			frame:SetAttribute("ModalOpen", false)
			frame:SetAttribute("ModalCloses", closes)
			status.Set({ Text = string.format("Closed (CLOSES: %d)", closes) })
		end,
	}, scope)
	frame:SetAttribute("ModalOpen", true)
	modal.Open()

	local destroyed = false
	local component = { Instance = frame }
	function component.Set(patch)
		checkKeys("Overlay.Modal", MODAL_FIXTURE_KEYS, patch)
		for key, value in pairs(patch) do current[key] = value end
		if patch.Title ~= nil then modal.Set({ Title = patch.Title }) end
	end
	function component.Destroy()
		if destroyed then return end
		destroyed = true
		alive = false
		modal.Destroy()
		frame:Destroy()
	end
	scope:add(component.Destroy)
	return component
end

------------------------------------------------------------------------------------------------------------------------
-- Items. The first state is the default; each item includes its longest strings.
------------------------------------------------------------------------------------------------------------------------

local LONG_TOAST = "Garage requests are arriving too quickly. Wait a moment before you ask for another vehicle, then try the "
	.. "garage desk again; your Cash has not been changed."
local LONG_BODY = "Blade Wing Standard is fitted to your Zephyr. Moving it here leaves the Zephyr without a wing, and it "
	.. "cannot be driven until a wing, an engine, stabilisers and boost are fitted again. You can move the part back at "
	.. "any time from Customise, Parts, Owned."

return {
	{
		Id = "Overlay.Toast",
		Frame = "Hud",
		Slot = "TopCentre",
		States = {
			{ Id = "Single", Props = { Messages = { "Route set: Showroom Loop" } } },
			{ Id = "Stack", Props = { Messages = { "Route set: Showroom Loop", "Map not available", "Taxi fare paid +$1,234" } } },
			{ Id = "Long", Props = { Messages = { "Please wait.", LONG_TOAST } } },
			{ Id = "Duplicate", Props = { Messages = { "Map not available", "Map not available", "MAP NOT AVAILABLE" } } },
			{ Id = "Overflow", Props = { Messages = { "First (replaced)", "Second", "Third", "Fourth" } } },
			{ Id = "OneCard", Props = { MaxCards = 1, Messages = { "First (replaced)", "Only the newest shows" } } },
			{ Id = "Expire", Props = { Keep = false, Duration = 2.5, Messages = { "Gone after the default time" } } },
		},
		Mount = mountToast,
	},
	{
		Id = "Overlay.Confirm",
		Frame = "Bare",
		States = {
			{ Id = "Default", Props = { Title = "Move this part?",
				Body = "Blade Wing Standard is fitted to your Zephyr. Moving it here leaves the Zephyr without a wing." } },
			{ Id = "ClassicDefaults", Props = {} },
			{ Id = "Long", Props = { Title = "Exit the championship race?", Body = LONG_BODY,
				CancelText = "KEEP RACING", ConfirmText = "EXIT RACE" } },
		},
		Mount = mountConfirm,
	},
	{
		Id = "Overlay.Modal",
		Frame = "Bare",
		States = {
			{ Id = "FixedHeight", Props = { Title = "Settings", FixedHeight = true,
				Body = "A modal dims the scene, traps focus and closes on Escape or gamepad B." } },
			{ Id = "AutoHeight", Props = { Title = "Get Cash", Body = "No height was given, so the panel takes its own." } },
			{ Id = "Long", Props = { Title = "Controls and accessibility", FixedHeight = true, Body = LONG_BODY } },
		},
		Mount = mountModal,
	},
}
