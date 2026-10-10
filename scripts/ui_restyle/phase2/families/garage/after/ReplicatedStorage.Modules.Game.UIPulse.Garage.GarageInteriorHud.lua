-- Owns the owned-garage interior HUD (the OwnedGarageInteriorHUD layer with AccessControls: access mode and invitations), PlayerGui@OwnedGarageInteriorMode, and the start of Garage.TouchCameraGuard; not the guard's logic (a fork), the desk, the browser or OwnedGarageManagementOpen.
-- Pulse UI (phase2). ReplicatedStorage.Modules.Game.UIPulse.Garage.GarageInteriorHud. Requires: Kit.Layers, Kit.Tokens, Kit.Text, Kit.Controls, Garage.TouchCameraGuard, Core.ConnectionScope.
-- New owner for Classic UI.GarageInteriorModeUI lines 10-47 and 271-278 (API2 5.7); lines 48-270 are Garage.TouchCameraGuard. Started by Garage.OwnedGarageClient; Start() -> (ok, message).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LAYER_NAME = "OwnedGarageInteriorHUD"
local ROOT_NAME = "AccessControls"
local NO_PLAYERS = "__none"
local DEFAULT_LIST_ROWS = 6 -- the rows a kit dropdown shows before it scrolls, when it is given no MaxRows

local Hud = {}
local started = false

-- Classic line 20.
function Hud._displayMode(mode)
	return string.upper((string.gsub(tostring(mode or ""), "Only", " Only")))
end

-- Classic line 273: owner inside, desk closed, no major touch menu, not a visitor.
function Hud._visible(inside, management, mobileMenu, visitor)
	return inside == true and management ~= true and mobileMenu ~= true and visitor ~= true
end

-- Classic line 24: how many rows are invited.
function Hud._inviteCount(state)
	local count = 0
	for _, row in ipairs(type(state) == "table" and type(state.InvitationRows) == "table" and state.InvitationRows or {}) do
		if type(row) == "table" and row.Invited then
			count += 1
		end
	end
	return count
end

-- Classic line 37: one option per access mode. Returns the options and the rows by option id; a row keeps the
-- server's own value in Id, which is what is sent back.
function Hud._accessOptions(state)
	local options, rows = {}, {}
	for _, mode in ipairs(type(state) == "table" and type(state.AccessModes) == "table" and state.AccessModes or {}) do
		local id = tostring(mode)
		table.insert(options, { Id = id, Text = Hud._displayMode(mode) })
		rows[id] = { Id = mode }
	end
	return options, rows
end

-- Classic line 41: one option per other player, with what a press does; "NO OTHER PLAYERS" when there are none.
function Hud._inviteOptions(state)
	local options, rows = {}, {}
	for _, item in ipairs(type(state) == "table" and type(state.InvitationRows) == "table" and state.InvitationRows or {}) do
		if type(item) == "table" then
			local id = tostring(item.UserId)
			local invited = item.Invited == true
			table.insert(options, { Id = id, Text = tostring(item.DisplayName or id) .. (invited and " - REVOKE" or " - INVITE") })
			rows[id] = { Id = item.UserId, Invited = invited }
		end
	end
	if #options == 0 then
		table.insert(options, { Id = NO_PLAYERS, Text = "NO OTHER PLAYERS" })
	end
	return options, rows
end

-- Pure. Everything of an option list that reaches the screen, as one string: two lists with the same key draw the
-- same dropdown, so the second need not be sent (sending Options closes an open list).
function Hud._optionsKey(options)
	local parts = {}
	for index, option in ipairs(options or {}) do
		parts[index] = tostring(option.Id) .. "=" .. tostring(option.Text)
	end
	return table.concat(parts, "\31")
end

-- The name of the garage the owner stands in, for the HUD heading; "" when the reply does not carry it.
function Hud._title(state)
	if type(state) ~= "table" or type(state.Properties) ~= "table" then
		return ""
	end
	local current = tostring(state.CurrentPropertyId or "")
	for _, property in ipairs(state.Properties) do
		if type(property) == "table" and tostring(property.PropertyId or "") == current then
			return string.upper(tostring(property.DisplayName or ""))
		end
	end
	return ""
end

-- Pure. Compact: are the two controls side by side? Only when both and the gap fit the width between the margins.
function Hud._sideBySide(accessWidth, inviteWidth, gap, room)
	return accessWidth + gap + inviteWidth <= room
end

-- Pure. Compact: the rows an open list may show so that it ends on the screen. `listTop` is where the list starts
-- (the foot of the lower control), `rowHeight` one list row; all real px. At least one row.
function Hud._listRows(screenHeight, listTop, rowHeight)
	if rowHeight <= 0 then
		return 1
	end
	return math.max(1, math.floor((screenHeight - listTop) / rowHeight))
end

function Hud.Start()
	if started then
		return true, "AlreadyStarted"
	end
	local pulse = script.Parent.Parent
	local kit = pulse.Kit
	local Layers = require(kit.Layers)
	local modules = ReplicatedStorage:FindFirstChild("Modules")
	local core = modules and modules:FindFirstChild("Core")
	local scopeModule = core and core:FindFirstChild("ConnectionScope")
	assert(scopeModule, "ReplicatedStorage.Modules.Core.ConnectionScope is missing")
	local scope = require(scopeModule).new()

	-- The waits Classic makes at line 5 for what this owner uses.
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes").Garage
	local remote = remotes:WaitForChild("OwnedGarageInvoke")
	local push = remotes:WaitForChild("OwnedGarageEvent")

	-- Classic line 10.
	local function publish()
		playerGui:SetAttribute("OwnedGarageInteriorMode", player:GetAttribute("OwnedGarageInside") == true)
	end

	local layer = Layers.Create(LAYER_NAME, { Frame = "Hud" })
	layer.SetVisible(false)
	local root = Instance.new("Frame")
	root.Name = ROOT_NAME
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AutomaticSize = Enum.AutomaticSize.XY
	root.Visible = false
	root.Parent = layer.Slot("TopLeftHud")

	local state = nil
	local busy = false
	local refreshing = false
	local wasVisible = false
	local accessRows, inviteRows = {}, {}
	local title, access, invite = nil, nil, nil
	local fit = function() end -- lays the two controls out for the screen class; set when they are built
	local syncing = false
	local accessKey, inviteKey = nil, nil -- the option lists the two dropdowns were last given (Hud._optionsKey)

	-- Classic line 18 drew its own label for 2.4 s; Pulse sends the same text to the shared toast.
	local function show(text, good)
		local scripts = player:FindFirstChild("PlayerScripts")
		local runtime = scripts and scripts:FindFirstChild("Runtime")
		local ui = runtime and runtime:FindFirstChild("UI")
		local notification = ui and ui:FindFirstChild("ShowTopNotification")
		if notification and notification:IsA("BindableEvent") then
			notification:Fire({ Text = tostring(text or ""), Icon = good and "tick" or "warning", Kind = good and "Good" or "Bad" }, 2.4)
		end
	end

	-- Classic line 19: the one remote call function of this owner.
	local function call(action, args)
		local ok, result = pcall(function()
			return remote:InvokeServer(action, args or {})
		end)
		if ok and type(result) == "table" then
			return result
		end
		return { Success = false, Message = "Garage access is unavailable." }
	end

	local function syncView()
		if not (access and invite) then
			return
		end
		syncing = true
		local ok, problem = pcall(function()
			local accessOptions
			accessOptions, accessRows = Hud._accessOptions(state)
			local inviteOptions
			inviteOptions, inviteRows = Hud._inviteOptions(state)
			local count = Hud._inviteCount(state)
			-- A dropdown closes its open list whenever it is given Options, so they are sent only when their
			-- content changed: else every state refresh (the one INVITE itself starts, and every push) shut it.
			local nextAccess, nextInvite = Hud._optionsKey(accessOptions), Hud._optionsKey(inviteOptions)
			if nextAccess ~= accessKey then
				accessKey = nextAccess
				access.Set({ Options = accessOptions })
			end
			access.Set({ Selected = tostring(state and state.AccessMode or "Private") })
			if nextInvite ~= inviteKey then
				inviteKey = nextInvite
				invite.Set({ Options = inviteOptions })
			end
			invite.Set({ Label = count > 0 and ("INVITE " .. count) or "INVITE", Selected = "" })
			if title then
				title.Set({ Text = Hud._title(state), Visible = Hud._title(state) ~= "" })
			end
			fit()
		end)
		syncing = false
		if not ok then
			warn("[Pulse.GarageInteriorHud] view update failed: " .. tostring(problem))
		end
	end

	-- Classic lines 23-25.
	local function applyState(nextState)
		if type(nextState) ~= "table" or nextState.Success ~= true then
			return false
		end
		state = nextState
		syncView()
		return true
	end

	-- Classic lines 26-28.
	local function refresh(reportFailure)
		if refreshing then
			return state ~= nil
		end
		refreshing = true
		local result = call("GetManagementState", {})
		refreshing = false
		if applyState(result) then
			return true
		end
		if reportFailure then
			show(result.Message or "GARAGE ACCESS UNAVAILABLE", false)
		end
		return false
	end

	-- Classic lines 30-34: one mutation in flight, stamped with the revision it was based on. Never retried.
	local function mutate(action, args, successText)
		if busy or not state then
			return false
		end
		busy = true
		args = type(args) == "table" and args or {}
		args.BaseRevision = state.Revision
		args.RequestId = HttpService:GenerateGUID(false)
		local result = call(action, args)
		busy = false
		if result.Success then
			if not applyState(result.ManagementState) then
				refresh(false)
			end
			show(successText, true)
			return true
		end
		if result.Conflict then
			refresh(false)
		end
		show(result.Message or "GARAGE ACCESS UPDATE FAILED", false)
		return false
	end

	-- Classic line 38: choosing the current mode does nothing; another mode is saved.
	local function chooseAccess(id)
		if syncing or busy or not state then
			return
		end
		local row = accessRows[id]
		if not row or row.Id == state.AccessMode then
			return
		end
		mutate("SetAccessMode", { AccessMode = row.Id }, "ACCESS MODE SAVED")
	end

	-- Classic line 42: a press invites, or revokes an invitation.
	local function chooseInvite(id)
		if syncing or busy or not state then
			return
		end
		local row = inviteRows[id]
		if not row then
			return
		end
		mutate("SetInvitation", { Action = row.Invited and "Revoke" or "Invite", TargetUserId = row.Id }, row.Invited and "INVITATION REVOKED" or "PLAYER INVITED")
	end

	-- The two controls. A kit failure here leaves the HUD without them and says so; the attribute, the visibility
	-- rule and the camera guard below do not depend on it.
	local built, problem = xpcall(function()
		local Tokens = require(kit.Tokens)
		local Text = require(kit.Text)
		local Controls = require(kit.Controls)
		local ctx = layer.Metrics
		local space = Tokens.Space
		local slot = layer.Slot("TopLeftHud")
		local column = Instance.new("UIListLayout")
		column.Name = "Layout"
		column.FillDirection = Enum.FillDirection.Vertical
		column.SortOrder = Enum.SortOrder.LayoutOrder
		column.Padding = UDim.new(0, ctx.Px(space.Gap))
		column.Parent = root
		title = Text.Label(root, { Name = "GarageTitle", Text = "", Role = "SectionHead", Align = "Left", Shadow = true, LayoutOrder = 1, Visible = false }, scope)
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.AutomaticSize = Enum.AutomaticSize.XY
		row.LayoutOrder = 2
		row.Parent = root
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.Name = "Layout"
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Padding = UDim.new(0, ctx.Px(space.Gap))
		rowLayout.Parent = row
		access = Controls.Dropdown(row, {
			Name = "Access",
			Label = "ACCESS",
			Options = { { Id = "Private", Text = "PRIVATE" } },
			Selected = "Private",
			LayoutOrder = 1,
			OnSelected = function(id)
				if syncing then
					return
				end
				chooseAccess(id)
				-- Whatever the server answered, the control shows the authoritative state again.
				syncView()
			end,
		}, scope)
		invite = Controls.Dropdown(row, {
			Name = "Invite",
			Label = "INVITE",
			Options = { { Id = NO_PLAYERS, Text = "NO OTHER PLAYERS" } },
			Selected = "",
			LayoutOrder = 2,
			OnSelected = function(id)
				if syncing then
					return
				end
				chooseInvite(id)
				-- Whatever the server answered, the control shows the authoritative state again.
				syncView()
			end,
		}, scope)
		-- Classic 36-37, 40-41 and 275: pressing a control with no state yet fetches it (and reports a failure);
		-- pressing INVITE with a state refreshes the player list.
		if access.Instance:IsA("GuiButton") then
			scope:connect(access.Instance.Activated, function()
				if busy or state then
					return
				end
				task.spawn(refresh, true)
			end)
		end
		if invite.Instance:IsA("GuiButton") then
			scope:connect(invite.Instance.Activated, function()
				if busy then
					return
				end
				task.spawn(refresh, state == nil)
			end)
		end

		-- Regular: as built (the two controls side by side, the kit's own list length). Compact: the small gap;
		-- the controls go one under the other when the two do not fit the width between the margins (a long
		-- access mode on a 568 px phone); and an open list is kept on the screen (the kit list opens downward
		-- with up to six touch-size rows, which is taller than what is left under the controls on a phone).
		local limited = false
		fit = function()
			local compact = ctx.Class == "Compact"
			local gap = ctx.Px(compact and space.CompactKeepOutGap or space.Gap)
			column.Padding = UDim.new(0, gap)
			rowLayout.Padding = UDim.new(0, gap)
			local accessSize, inviteSize = access.Instance.Size, invite.Instance.Size
			local room = ctx.Size.X - 2 * slot.Position.X.Offset
			local stacked = compact and not Hud._sideBySide(accessSize.X.Offset, inviteSize.X.Offset, gap, room)
			rowLayout.FillDirection = stacked and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
			if compact then
				local rowHeight = accessSize.Y.Offset
				local titleHeight = title.Instance.Visible and title.Instance.Size.Y.Offset + gap or 0
				local controls = stacked and (rowHeight + gap + inviteSize.Y.Offset) or rowHeight
				local rows = Hud._listRows(ctx.Size.Y, slot.Position.Y.Offset + titleHeight + controls, rowHeight)
				access.Set({ MaxRows = rows })
				invite.Set({ MaxRows = rows })
				limited = true
			elseif limited then
				access.Set({ MaxRows = DEFAULT_LIST_ROWS })
				invite.Set({ MaxRows = DEFAULT_LIST_ROWS })
				limited = false
			end
		end
		scope:connect(access.Instance:GetPropertyChangedSignal("Size"), fit)
		scope:connect(invite.Instance:GetPropertyChangedSignal("Size"), fit)
		scope:connect(slot:GetPropertyChangedSignal("Position"), fit)
		scope:connect(ctx.Changed, function(change)
			if type(change) == "table" and change.Layout then
				task.defer(fit)
			end
		end)
		fit()
	end, debug.traceback)
	if not built then
		access, invite = nil, nil
		fit = function() end
		warn("[Pulse.GarageInteriorHud] view build failed; AccessControls has no controls: " .. tostring(problem))
	end

	-- Classic lines 272-274.
	local function update()
		local visible = Hud._visible(
			player:GetAttribute("OwnedGarageInside") == true,
			playerGui:GetAttribute("OwnedGarageManagementOpen") == true,
			player:GetAttribute("MobileMajorMenuOpen") == true,
			player:GetAttribute("OwnedGarageVisitor")
		)
		root.Visible = visible
		layer.SetVisible(visible)
		if visible and not wasVisible then
			task.spawn(refresh, false)
		end
		wasVisible = visible
	end

	-- Classic line 276.
	scope:connect(player:GetAttributeChangedSignal("OwnedGarageInside"), function()
		publish()
		update()
	end)
	scope:connect(player:GetAttributeChangedSignal("MobileMajorMenuOpen"), update)
	scope:connect(player:GetAttributeChangedSignal("OwnedGarageVisitor"), update)
	scope:connect(playerGui:GetAttributeChangedSignal("OwnedGarageManagementOpen"), update)
	-- Classic line 277.
	scope:connect(push.OnClientEvent, function(message)
		if type(message) ~= "table" then
			return
		end
		if message.Type == "DriveOutResult" then
			show(message.Message, message.Success == true)
		elseif message.Type == "ManagementUpdated" and root.Visible and not busy then
			task.spawn(refresh, false)
		end
	end)

	-- The touch camera guard was part of the Classic owner (lines 48-270); it is a fork and starts here.
	local guardOk, guardMessage = require(script.Parent.TouchCameraGuard).Start()
	if not guardOk then
		return false, "TouchCameraGuard / " .. tostring(guardMessage)
	end

	-- Classic line 278.
	publish()
	update()
	Hud.Layer = layer
	started = true
	return true, "Started"
end

return Hud
